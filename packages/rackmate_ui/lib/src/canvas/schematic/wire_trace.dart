// rackmate_ui/src/canvas/schematic/wire_trace.dart
//
// THE WHOLE v1 ROUTER. A deterministic per-link orthogonal staircase, and
// nothing else (canon §11.1.3: "The **deterministic per-link orthogonal
// trace** used in `drawn` mode: a layer-ordered staircase with a fixed bend
// budget, no channel allocation. Deterministic, same input ⇒ byte-identical
// display list. This is the whole v1 router.").
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS NOT HERE, AND IS NOT COMING HERE
// ═════════════════════════════════════════════════════════════════════
// canon §11.1.3 items 1–5, verbatim in effect:
//   1. INTERVAL-GRAPH CHANNEL ROUTING — v1.2, gated on evidence.
//   2. TRACK ORDERING / CHANNEL ASSIGNMENT — v1.2, with #1. It is the
//      same code.
//   3. THE BENTLEY–OTTMANN CROSSING SWEEP — never, unless #1 lands.
//   4. HOP ARCS — never, unless #1 lands. Crossings render as plain
//      crossovers in v1, which is a ruling and not an omission.
//   5. JUNCTION STAGGERING — never.
// There is therefore NO sweep, NO crossing count, NO conflict resolution
// and NO global state of any kind in this file. Every trace is a pure
// function of ONE link's two published pin geometries. If a future change
// finds itself comparing two links to place either of them, that is item 2
// arriving by the back door and it belongs in v1.2.
//
// THERE IS ALSO NO LINK-COUNT BRANCH, and adding one would reintroduce the
// silent degradation §10.1 named as draw-every-wire's worst property
// (DR-001, canon §11.1.1: render mode "is never persisted, never a
// `ProjectSettings` field" and "there is no density term in it").
//
// ═════════════════════════════════════════════════════════════════════
// THE GEOMETRY IS READ, NEVER RE-DERIVED
// ═════════════════════════════════════════════════════════════════════
// Every pin centre comes from `SchematicScene.netLabels`
// (`RenderedNetLabel.pinCentre`), which M2-D publishes for exactly this
// reason — `symbol_layer.dart`'s own header records what re-derivation
// cost last time: "the painter and the hit-tester each computed a pin
// centre and disagreed by half a pin for as long as nobody compared them".
// So a drawn wire starts at the same point the label's leader starts at,
// by construction rather than by agreement.
//
// ═════════════════════════════════════════════════════════════════════
// THE COMB, WHICH IS A STATED CHOICE AND NOT CHANNEL ALLOCATION
// ═════════════════════════════════════════════════════════════════════
// Eight links leaving one symbol's right edge for eight symbols in the
// next layer would, with a single escape distance, turn at the SAME x —
// eight vertical runs drawn on top of each other, which is worse than the
// crossings v1 accepts. The fix taken here is the one `net_label_layer`
// already took for the identical problem on top/bottom pins: THE i-TH PIN
// ON A SIDE ESCAPES i STEPS FURTHER OUT. It is a per-link function of one
// pin's own index on its own symbol — no global allocation, no ordering
// pass, no conflict detection — so it is not item 2 above wearing a
// disguise, and it is stated as a CHOICE because docs/05 gives no figure
// for it.
//
// WHAT THE COMB DOES NOT DO, said plainly so nobody reads more into it:
// two links leaving DIFFERENT symbols in one layer can still share a
// corridor and overlap, and two links on ONE pin still escape identically.
// Both are the accepted v1 behaviour — "crossings render as plain
// crossovers" — not defects this file failed to catch.
//
// ═════════════════════════════════════════════════════════════════════
// THE BEND BUDGET IS FIXED AT FOUR, AND [maxBends] IS THE ASSERTION
// ═════════════════════════════════════════════════════════════════════
// Two escapes plus at most two turns. `wire_trace_test.dart` asserts it
// over every link of the 300-link fixture rather than trusting the case
// analysis in [orthogonalTrace].

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// The largest number of corners any [orthogonalTrace] may contain — canon
/// §11.1.3's "fixed bend budget", made checkable.
///
/// Four: one turn as each end leaves its pin, and at most two more in the
/// staircase between them. A route that needs a fifth is a route that
/// wanted channel allocation.
const int kMaxTraceBends = 4;

/// The figures a drawn wire is built from, in the units each is naturally
/// stated in — LAYOUT distances in grid units (so they track `kGridUnit`
/// like every other schematic dimension) and TYPE sizes in diagram units.
///
/// EVERY FIELD IS A STATED CHOICE. docs/05 specifies the tag pill's
/// CONTENT (§4.4) and the render mode that shows it (§11.1.1) and gives no
/// figure for any distance here, so — unlike `SchematicMetrics`, where
/// every field but one is a citation — nothing below is transcribed from
/// the corpus. They are gathered in one type so a reader can see that.
@immutable
final class SchematicWireStyle {
  const SchematicWireStyle({
    this.escapeGu = 3,
    this.combStepGu = 2,
    this.tagSizePt = RackTextSizes.type,
    this.tagPadGu = 0.5,
    this.fillAlpha = 31,
    this.outlineWidthPt = kMinSignalStrokePt,
  });

  /// How far a wire leaves its pin before it may turn.
  ///
  /// The same 3 gu `NetLabelStyle.leaderGu` gives a net-label leader, and
  /// deliberately so: `drawn` and `netLabels` are two renderings of one
  /// Link (DR-001), and a wire that left its pin by a different distance
  /// than its own label's stub would make the two modes disagree about
  /// where the connection starts.
  final double escapeGu;

  /// The comb step — see the file header. `kPinPitch` is the 2 gu at
  /// which left/right pins are spaced, so consecutive pins' corridors are
  /// exactly as far apart as the pins themselves.
  final double combStepGu;

  /// The tag pill's type size. `RackTextSizes.type`, the size
  /// `symbol_layer` gives a pin label and `net_label_layer` gives its
  /// family token — which also keeps `DiagramScene.minTextSizePt` where
  /// M2-C and M2-D left it, so switching a domain to `drawn` cannot move
  /// the legibility trigger (docs/08 §6.2).
  final double tagSizePt;

  /// Inset of the pill's text from its own outline.
  final double tagPadGu;

  /// Alpha of the pill fill, 0–255. docs/05 §11.5 fixes the net-label
  /// pennant at "the domain colour at 12% with a full-strength outline";
  /// the tag pill is the same object in the other mode and takes the same
  /// treatment, 12% of 255 = 30.6 → 31. Baked into the fill colour, NEVER
  /// an opacity layer: the `saveLayer` ban applies hardest on a per-frame
  /// path (§11.2), and this is one.
  final int fillAlpha;

  /// The pill outline's width. Full-strength COLOUR at a hairline width,
  /// for `NetLabelStyle.outlineWidthPt`'s reason: the WEIGHT channel is
  /// carried by the wire itself, and outlining the pill at the family's
  /// weight too would say the same thing twice.
  final double outlineWidthPt;
}

/// One link's drawn rendering: where the wire runs, and what encodes it.
@immutable
final class DrawnWire {
  const DrawnWire({
    required this.linkId,
    required this.style,
    required this.points,
    required this.ends,
  });

  final Uuid linkId;

  /// The four channels (`signal_style.dart`), resolved ONCE per link by
  /// M2-D and read here. Never re-resolved: `resolveSignalStyle` is the
  /// only place a channel may be decided, and a second call site is how a
  /// wire and its own label end up different colours.
  final SignalStyle style;

  /// The wire, corner to corner, ABSOLUTE. Always ≥ 2 points; every
  /// consecutive pair is axis-aligned.
  final List<DPt> points;

  /// The escape point at each end — where the wire has cleared its pin and
  /// the tag pill is centred. One entry for a one-ended link (AC-018's
  /// home runs to the field), two otherwise.
  final List<DPt> ends;

  /// The number of corners in [points]. Never above [kMaxTraceBends].
  int get bends => points.length - 2;
}

/// [buildDrawnWireLayer]'s output.
@immutable
final class DrawnWireLayer {
  const DrawnWireLayer({
    required this.ops,
    required this.wires,
    required this.unroutableLinkIds,
  });

  /// ABSOLUTE-coordinate ops. Unlike a symbol fragment these carry sheet
  /// coordinates and replay with no bracketing translate, exactly as a
  /// domain's net-label run does — a wire belongs to two symbols at once
  /// and there is no local frame it could share.
  final List<DiagramOp> ops;

  final List<DrawnWire> wires;

  /// Links in the requested scope that got NO wire, because neither end
  /// landed on a drawn pin. Counted rather than dropped, for the reason
  /// `NetLabelLayerBuild.unlabelledLinkIds` is counted: a drawing that
  /// silently omits a connection is indistinguishable from one that lost
  /// it.
  final List<Uuid> unroutableLinkIds;
}

/// The orthogonal staircase between two pins.
///
/// [fromPin]/[toPin] are pin centres and [fromSide]/[toSide] the edges they
/// sit on; [fromEscape]/[toEscape] are the distances each end travels
/// straight out before it may turn (the comb — see the file header).
///
/// ── THE THREE CASES, AND WHY THEY ARE THREE ─────────────────────────────
/// A pin's escape direction is fixed by its edge: left/right pins escape
/// HORIZONTALLY, top/bottom pins VERTICALLY (`symbol_layer.dart`'s edge
/// rule). That gives exactly three shapes, and no fourth is reachable:
///
///   * BOTH HORIZONTAL — a Z with a vertical corridor at the x-midpoint of
///     the two escape points. The midpoint is arithmetic, not allocated:
///     it moves with the comb, so two links off adjacent pins get two
///     corridors without anything having compared them.
///   * BOTH VERTICAL — the same shape rotated: a horizontal corridor at
///     the y-midpoint.
///   * MIXED — an L. One corner, at the intersection of the horizontal
///     end's row and the vertical end's column, which is the only corner
///     that lets each end arrive along its own axis.
///
/// Collinear runs are collapsed by [_simplify], so a straight connection is
/// two points rather than six sitting on one line — a difference the eye
/// cannot see and a golden can.
List<DPt> orthogonalTrace({
  required DPt fromPin,
  required SymbolSide fromSide,
  required double fromEscape,
  required DPt toPin,
  required SymbolSide toSide,
  required double toEscape,
}) {
  final p = _escapePoint(fromPin, fromSide, fromEscape);
  final q = _escapePoint(toPin, toSide, toEscape);
  final pHorizontal = _isHorizontal(fromSide);
  final qHorizontal = _isHorizontal(toSide);

  final middle = <DPt>[];
  if (pHorizontal && qHorizontal) {
    final mx = (p.x + q.x) / 2;
    middle
      ..add(DPt(mx, p.y))
      ..add(DPt(mx, q.y));
  } else if (!pHorizontal && !qHorizontal) {
    final my = (p.y + q.y) / 2;
    middle
      ..add(DPt(p.x, my))
      ..add(DPt(q.x, my));
  } else if (pHorizontal) {
    middle.add(DPt(q.x, p.y));
  } else {
    middle.add(DPt(p.x, q.y));
  }

  return _simplify(<DPt>[fromPin, p, ...middle, q, toPin]);
}

/// Builds the `drawn`-mode layer for [linkIds] over [scene]'s published
/// geometry.
///
/// [linkIds] is THE SCOPE and this function has no opinion about how it was
/// chosen — a soloed domain, an `Alt`-hover or a focused selection all
/// arrive here as a set of ids (canon §11.1.1's three rows). That is what
/// keeps the render-mode rule in one place (`schematic_filter.dart`) rather
/// than half of it here.
///
/// DETERMINISM. Links are walked in `(order, id)` — `schematic_scene.dart`'s
/// own link order — and no hash container is iterated for anything but a
/// lookup. Same document and same scope ⇒ byte-identical ops.
DrawnWireLayer buildDrawnWireLayer({
  required SchematicScene scene,
  required RackDocument doc,
  required Set<Uuid> linkIds,
  required TextMeasurer measurer,
  required SchematicPalette palette,
  SchematicWireStyle style = const SchematicWireStyle(),
}) {
  if (linkIds.isEmpty) {
    return const DrawnWireLayer(
      ops: <DiagramOp>[],
      wires: <DrawnWire>[],
      unroutableLinkIds: <Uuid>[],
    );
  }

  final upg = kSchematicUnitsPerGrid;

  // The comb index: the i-th pin on a side of one symbol. Built from
  // `RenderedSymbol.ports`, which is the SAME ordered list `symbol_layer`
  // laid the pins out from, so index i here is pin i there.
  final combIndex = <String, int>{};
  final symbolOf = <String, RenderedSymbol>{};
  for (final symbol in scene.symbols) {
    symbolOf[symbol.id] = symbol;
    for (final side in SymbolSide.values) {
      final ports = symbol.ports[side] ?? const <SymbolPort>[];
      for (var i = 0; i < ports.length; i++) {
        combIndex['${symbol.id} ${ports[i].key}'] = i;
      }
    }
  }

  // The label geometry, bucketed by link. Both of a link's stubs carry the
  // same `linkId` (§11.5: "both flags of a net show the identical string"),
  // so this is the pair of ends, in the order M2-D emitted them — conductor
  // order, from then to.
  final endsOf = <Uuid, List<RenderedNetLabel>>{};
  for (final label in scene.netLabels) {
    if (!linkIds.contains(label.linkId)) continue;
    endsOf.putIfAbsent(label.linkId, () => <RenderedNetLabel>[]).add(label);
  }

  final scoped = doc.links.values.where((l) => linkIds.contains(l.id)).toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });

  final ops = <DiagramOp>[];
  final wires = <DrawnWire>[];
  final unroutable = <Uuid>[];
  final sizer = _PillSizer(measurer: measurer, style: style, unitsPerGrid: upg);

  for (final link in scoped) {
    final ends = endsOf[link.id] ?? const <RenderedNetLabel>[];
    if (ends.isEmpty) {
      unroutable.add(link.id);
      continue;
    }

    double escapeOf(RenderedNetLabel end) {
      final i = combIndex['${end.deviceId} ${end.portKey}'] ?? 0;
      return (style.escapeGu + style.combStepGu * i) * upg;
    }

    final signal = ends.first.style;
    final List<DPt> points;
    final List<DPt> pillAt;
    if (ends.length == 1) {
      // ONE END IS STILL A WIRE. A home run to the field (AC-018's
      // `PlaceEndpoint`/`OpenEndpoint`) has one pin and one direction, and
      // drawing nothing for it would hide a run that exists — the same
      // ruling `net_label_layer` takes when it labels the one end it has.
      final end = ends.first;
      final tail = _escapePoint(end.pinCentre, end.side, escapeOf(end));
      points = <DPt>[end.pinCentre, tail];
      pillAt = <DPt>[tail];
    } else {
      final a = ends[0];
      final b = ends[1];
      points = orthogonalTrace(
        fromPin: a.pinCentre,
        fromSide: a.side,
        fromEscape: escapeOf(a),
        toPin: b.pinCentre,
        toSide: b.side,
        toEscape: escapeOf(b),
      );
      pillAt = <DPt>[
        _escapePoint(a.pinCentre, a.side, escapeOf(a)),
        _escapePoint(b.pinCentre, b.side, escapeOf(b)),
      ];
    }

    // THE FOUR CHANNELS ON ONE STROKE: hue is `argb`, dash is `dash`,
    // weight is `widthPt`. Every one of them is the value
    // `resolveSignalStyle` returned — applied, never re-derived
    // (`SignalStyle`'s own rule).
    //
    // BOTH CR-082 KNOBS ARE NAMED, and `draw_source_gate_test.dart`
    // requires it: a stroke that sets one and inherits the other has not
    // decided whether its width scales. A cable trace SCALES (CR-082:
    // "Cable traces, symbol outlines and rack rails scale") and takes the
    // ordinary 0.5 pt signal floor, not the 0.25 pt furniture one.
    ops.add(
      OpPolyline(
        List<DPt>.unmodifiable(points),
        Stroke(
          argb: signal.argb,
          widthPt: signal.widthPt,
          dash: signal.dash,
          // Both values happen to equal the defaults, and both are kept
          // EXPLICIT anyway (hence the ignores) for `draw_source_gate_test
          // .dart`'s reason: the two CR-082 knobs are orthogonal, and a
          // stroke that inherits them has not decided. This one is a CABLE
          // TRACE, the first noun in CR-082's own sentence — "Cable
          // traces, symbol outlines and rack rails scale" — and it takes
          // the ordinary 0.5 pt signal floor, not the 0.25 pt one only
          // sheet furniture opts into.
          // ignore: avoid_redundant_argument_values
          scaleWithGeometry: true,
          // Kept explicit for the reason stated immediately above: the two
          // CR-082 knobs are decided together or not at all.
          // ignore: avoid_redundant_argument_values
          hairlineFloor: false,
        ),
      ),
    );

    // §11.1.1: "an orthogonal polyline with a tag pill at each end".
    for (final at in pillAt) {
      ops.addAll(sizer.pillOps(_tagTextFor(link, signal), at, signal, palette));
    }

    wires.add(
      DrawnWire(
        linkId: link.id,
        style: signal,
        points: List<DPt>.unmodifiable(points),
        ends: List<DPt>.unmodifiable(pillAt),
      ),
    );
  }

  return DrawnWireLayer(
    ops: List<DiagramOp>.unmodifiable(ops),
    wires: List<DrawnWire>.unmodifiable(wires),
    unroutableLinkIds: List<Uuid>.unmodifiable(unroutable),
  );
}

/// The tag pill's text.
///
/// canon §4.4 states the pill as `W042 · HDMI · 25 ft` — designator, type,
/// LENGTH. Two of the three are facts this document holds; the third is
/// not. AC-024's three length fields arrive with the Structure editor in
/// M3, and every freshly-drawn link has all three null, so the term is
/// OMITTED rather than filled with a guess or with a `—` that would read as
/// a measured zero (G4, CR-114). When lengths exist the term is appended
/// here and nothing else moves.
///
/// The type half is `SignalStyle.tag`, not `displayName`: `HDMI 2.0
/// (18 Gbps)` does not fit a pill, and `signal_style.dart` already records
/// that `shortTag` is the pill's token.
String _tagTextFor(Link link, SignalStyle style) =>
    '${link.designator} $kSignalTagSeparator ${style.tag}';

/// A pin centre pushed [distance] straight out of its body.
///
/// AWAY FROM THE BODY, always — the same geometric rule `net_label_layer`
/// reads out of §11.5's figure. It is true by construction for every pin
/// because §3's edge rule puts sinks on the left edge and sources on the
/// right.
DPt _escapePoint(DPt pin, SymbolSide side, double distance) => switch (side) {
  SymbolSide.left => DPt(pin.x - distance, pin.y),
  SymbolSide.right => DPt(pin.x + distance, pin.y),
  SymbolSide.top => DPt(pin.x, pin.y - distance),
  SymbolSide.bottom => DPt(pin.x, pin.y + distance),
};

bool _isHorizontal(SymbolSide side) =>
    side == SymbolSide.left || side == SymbolSide.right;

/// Drops duplicate and REDUNDANT points.
///
/// Not cosmetic: the bend budget is asserted on `points.length`, and a
/// route that is geometrically straight must not count as four bends
/// because the case analysis emitted four collinear points. Comparison is
/// exact rather than epsilon-based — every coordinate here is either a
/// published pin centre or an average of two of them, so "the same x" is a
/// bit-exact question, and an epsilon would make the display list depend on
/// a tolerance nobody chose.
///
/// ── COLLINEAR IS NOT THE SAME AS REDUNDANT, AND THE FIRST VERSION OF
///    THIS FUNCTION GOT IT WRONG ─────────────────────────────────────────
/// It dropped `b` from `(a, b, c)` whenever all three shared an axis. That
/// is right when `b` lies BETWEEN its neighbours and wrong when it lies
/// outside them, because outside them the path DOUBLES BACK and `b` is the
/// turn. Dropping it deleted the escape: a wire whose partner sat behind
/// its own pin then left the pin backwards, straight through the body it
/// had just come out of, and no assertion about orthogonality or bend count
/// could see it — the result was still orthogonal and shorter.
///
/// IT WAS FOUND BY MUTATION TESTING, not by reading: flipping
/// [_escapePoint]'s right-edge direction to run INTO the body survived the
/// whole suite, because this function erased the evidence in every
/// configuration. The between-test below is what makes an escape survive
/// exactly when it is doing something, and `wire_trace_test.dart`'s "a wire
/// leaves its pin AWAY from its own body" is what kills that mutation now.
List<DPt> _simplify(List<DPt> points) {
  final out = <DPt>[];
  for (final p in points) {
    if (out.isNotEmpty && out.last == p) continue;
    if (out.length >= 2) {
      final a = out[out.length - 2];
      final b = out.last;
      final straightX = a.x == b.x && b.x == p.x && _between(a.y, b.y, p.y);
      final straightY = a.y == b.y && b.y == p.y && _between(a.x, b.x, p.x);
      if (straightX || straightY) out.removeLast();
    }
    out.add(p);
  }
  // A wire whose two ends coincide exactly — a loop-through drawn on one
  // pin — would collapse to a single point, which `drawPolyline` cannot
  // render. Two identical points draw nothing either, but they keep every
  // consumer's `points.length >= 2` invariant true.
  if (out.length == 1) out.add(out.first);
  return out;
}

/// Whether [b] lies on the closed segment between [a] and [c].
///
/// Inclusive at both ends, so a `b` that coincides with a neighbour is
/// redundant rather than a zero-length doubling-back.
bool _between(double a, double b, double c) =>
    (a <= b && b <= c) || (c <= b && b <= a);

/// Measures and emits one tag pill.
///
/// A class rather than three free functions because the measurement and the
/// emission share a `TextStyleSpec` that must be the SAME object in both —
/// measuring with one spec and drawing with another is how a box ends up
/// the wrong size for its own text.
final class _PillSizer {
  _PillSizer({
    required this.measurer,
    required this.style,
    required this.unitsPerGrid,
  });

  final TextMeasurer measurer;
  final SchematicWireStyle style;
  final double unitsPerGrid;

  List<DiagramOp> pillOps(
    String text,
    DPt centre,
    SignalStyle signal,
    SchematicPalette palette,
  ) {
    final spec = rackText(
      style.tagSizePt,
      palette.netLabelText,
      TextAnchor.midCenter,
    );
    final pad = style.tagPadGu * unitsPerGrid;
    final width = measurer.measureText(text, spec).advanceWidth + pad * 2;
    // The pill's height is its type size plus the same pad top and bottom,
    // measured from the size rather than from the font's own metrics: the
    // two backends agree on `sizePt` exactly and on ascent/descent only up
    // to their font tables, and a pill that is a different height on screen
    // than on paper is a screen/print parity defect.
    final height = style.tagSizePt + pad * 2;
    final box = DBox.fromLtwh(
      centre.x - width / 2,
      centre.y - height / 2,
      width,
      height,
    );
    // Radius half the height: a stadium, which is what "pill" means and
    // what distinguishes it at a glance from the net-label pennant's
    // pentagon. The two modes have to be tellable apart.
    final radius = height / 2;
    return <DiagramOp>[
      OpRoundRect(
        box,
        Radii.circular(radius),
        fill: Fill(_withAlpha(signal.argb, style.fillAlpha)),
        stroke: Stroke(
          argb: signal.argb,
          widthPt: style.outlineWidthPt,
          // Explicit for the same reason as the trace above, and with the
          // same answer: a pill is diagram geometry drawn beside the wire,
          // so it scales with it rather than staying a constant number of
          // screen pixels while the drawing zooms out from under it.
          // ignore: avoid_redundant_argument_values
          scaleWithGeometry: true,
          // Kept explicit for the reason stated immediately above: the two
          // CR-082 knobs are decided together or not at all.
          // ignore: avoid_redundant_argument_values
          hairlineFloor: false,
        ),
      ),
      OpText(text, centre, spec),
    ];
  }
}

/// [argb] with its alpha replaced — the 12% fill, BAKED INTO THE COLOUR.
///
/// Never a `saveLayer`: docs/05 §11.2 bans an opacity layer on this path by
/// name, and the drawn wires are the one thing on the sheet that is rebuilt
/// when a filter changes.
int _withAlpha(int argb, int alpha) =>
    (math.max(0, math.min(255, alpha)) << 24) | (argb & 0x00FFFFFF);
