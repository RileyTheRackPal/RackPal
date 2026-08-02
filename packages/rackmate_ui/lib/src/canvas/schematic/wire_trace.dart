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
// THE DETOUR, WHICH IS ALSO NOT CHANNEL ALLOCATION
// ═════════════════════════════════════════════════════════════════════
// The staircase's corridor is the MIDPOINT of the two escape points, and a
// midpoint lies outside both bodies only while the two ends escape TOWARDS
// each other — a source on a right edge feeding a sink on a left edge
// further right. That is what Sugiyama's layering produces and it is what
// the three cases in [orthogonalTrace] were written against.
//
// A BACKWARD EDGE breaks the assumption, and there is nothing exotic about
// one: an AVR's HDMI input fed by a matrix that sits to its RIGHT is a
// backward edge, and so is its output feeding something to its left. The
// field sent a screenshot of what that drew. The corridor landed BETWEEN
// the two escapes instead of beyond them, so the wire left its pin, turned
// straight back around and ran across the face of its own symbol — over the
// header band, over the pin labels that had just been moved inside for
// exactly this reason, and out the other side. Two of them on one pin row
// read as one line drawn through the device.
//
// So a route that would cut a body it TERMINATES ON is replaced by one that
// goes around it: out to the escape, along a lane clear of both bodies, and
// back in. WHICH SIDE THE LANE RUNS DOWN IS THE HALF OF ITS OWN BODY THE PIN
// SITS IN — port 01 of a switch leaves by the left, port 48 by the right, so
// the fan is symmetric and no cable crosses more than half the symbol it is
// leaving ([_prefersLowLane], which records the two rules that came before
// it and why each failed). A mixed pair gets no choice at all, because a top
// or bottom pin can only be met from the side it escapes to.
//
// IT IS STILL A PURE FUNCTION OF ONE LINK, and that is the whole of why it
// is not item 1 or 2 above. The only new inputs are THE TWO BODIES THIS
// LINK'S OWN ENDS SIT ON. No third symbol is consulted, no other link is
// compared, nothing is reserved — two backward links can still pick the
// same lane and run along it together, exactly as two forward links can
// still share a corridor. Stopping THAT is what channel allocation is for,
// and it is v1.2.
//
// THE BUDGET DOES NOT MOVE, because the lane REPLACES the corridor rather
// than being added to it: two escapes and two turns, which is the four the
// staircase already spends in its own worst case.
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
    this.maxCombLanes = 6,
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

  /// The hard ceiling on the escape comb — how many corridors one edge may
  /// spread its wires across, however many pins it has.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// SIX, WHICH IS `NetLabelStyle.maxCombLanes`, AND THE SAME JUDGEMENT
  /// ═══════════════════════════════════════════════════════════════════
  /// The file header's comb was UNBOUNDED: the i-th pin escaped i steps,
  /// for any i. That is fine on the eight-link example it was written
  /// against and unreadable on a 30-port switch, where the field found it
  /// — a staircase two dozen steps tall climbing off the sheet, which is
  /// the identical defect `NetLabelStyle.maxCombLanes` capped for the
  /// label comb and which survived here because the cap was written where
  /// the report came from rather than where the pattern was.
  ///
  /// THE FIGURE IS COPIED DELIBERATELY, not derived. The two combs measure
  /// different things — that one stacks pennants against the pin pitch,
  /// this one spaces corridors — so there is no formula to share, only the
  /// judgement about how tall a staircase a person will follow. Two
  /// renderings of one `Link` (DR-001) climbing to different heights would
  /// be the modes disagreeing about the drawing, which is the thing
  /// [escapeGu] is already kept equal to `leaderGu` to prevent.
  ///
  /// AND IT COSTS SOMETHING, stated rather than hidden: pins six apart
  /// share a corridor, so two wires can run parallel on the same line for
  /// part of their path. The header already accepts that for two links
  /// leaving different symbols; this extends it to one symbol's wide edge,
  /// and the wires stay tellable apart by hue, dash and weight.
  final int maxCombLanes;
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

  /// The escape point at each end — where the wire has cleared its pin, and
  /// where the tag pill is ANCHORED. Not where the pill is centred: it
  /// hangs outboard from here, `_PillSizer.pillOps` says why. One entry for
  /// a one-ended link (AC-018's home runs to the field), two otherwise.
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
    this.inkBounds,
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

  /// Everything this layer paints — every trace corner and every pill box —
  /// or null when it paints nothing.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// PUBLISHED BECAUSE THE SHEET GROUND WAS BEING SIZED WITHOUT IT
  /// ═══════════════════════════════════════════════════════════════════
  /// `buildSchematicPaintPlan` sizes its ground off `scene.bounds`, which
  /// is the NET-LABEL scene's ink and knows nothing about a layer built
  /// after it. That was survivable while every wire ran between two
  /// escape points and stayed well inside the pennants' envelope. It stopped
  /// being survivable when wires started routing AROUND bodies and pills
  /// started hanging outboard of their anchors: on the 300-link fixture,
  /// 26 wires reached past the ground and were painted on the margin
  /// outside the paper, which is what the field reported as wires going off
  /// the canvas.
  ///
  /// GEOMETRY, NOT STROKED INK, and the difference is stated rather than
  /// left to be discovered. `BoundsCanvas` would add half a stroke width to
  /// every shape and re-measure every pill's text to do it — a second full
  /// pass over the ops, sixty times a second, to gain a quarter of a point.
  /// The consumer inflates this by `kSheetGroundMarginGu`, eight grid units,
  /// which is two orders of magnitude more than the widest stroke here.
  final DBox? inkBounds;
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
///
/// ── AND THE FOURTH SHAPE, WHICH IS NOT A FOURTH CASE ────────────────────
/// All three above put their corridor at the MIDPOINT of the two escapes,
/// which is beyond both of them on a forward edge and BETWEEN them on a
/// backward one — see the file header. Pass [fromBody] and [toBody] and a
/// route that would cut either of them is replaced by the detour: the same
/// staircase with its corridor moved out past both bodies instead of split
/// between them. Omit them and the caller gets the bare staircase, which is
/// what a drag preview over a free-floating cursor has to have.
List<DPt> orthogonalTrace({
  required DPt fromPin,
  required SymbolSide fromSide,
  required double fromEscape,
  required DPt toPin,
  required SymbolSide toSide,
  required double toEscape,
  DBox? fromBody,
  DBox? toBody,
}) {
  final p = _escapePoint(fromPin, fromSide, fromEscape);
  final q = _escapePoint(toPin, toSide, toEscape);

  final direct = _simplify(<DPt>[
    fromPin,
    p,
    ..._staircase(p, fromSide, q, toSide),
    q,
    toPin,
  ]);
  if (fromBody == null || toBody == null) return direct;
  if (!_cutsEither(direct, fromBody, toBody)) return direct;

  final around = _simplify(<DPt>[
    fromPin,
    p,
    ..._detour(
      p,
      fromSide,
      fromBody,
      q,
      toSide,
      toBody,
      // AT LEAST AS FAR OUT AS EITHER ESCAPE, which is not decoration. A
      // lane INSIDE one end's own escape point would be met by that end
      // travelling back inward, and the whole defect being fixed here is a
      // wire that travels back inward. Taking the larger of the two also
      // carries the comb into the lane, so two backward links off different
      // pins detour at different heights — the same way, and for the same
      // reason, that the corridor inherits it.
      clearance: math.max(fromEscape, toEscape),
    ),
    q,
    toPin,
  ]);
  // THE DETOUR IS NOT ALWAYS AVAILABLE: two symbols that overlap in the
  // lane's own axis can leave every route through one of them. Falling back
  // to the direct staircase draws the shorter of two flawed wires rather
  // than the longer one, and says so here instead of pretending the case
  // cannot arise.
  return _cutsEither(around, fromBody, toBody) ? direct : around;
}

/// The three cases of the doc comment above, and nothing else.
List<DPt> _staircase(DPt p, SymbolSide fromSide, DPt q, SymbolSide toSide) {
  final pHorizontal = _isHorizontal(fromSide);
  final qHorizontal = _isHorizontal(toSide);
  if (pHorizontal && qHorizontal) {
    final mx = (p.x + q.x) / 2;
    return <DPt>[DPt(mx, p.y), DPt(mx, q.y)];
  }
  if (!pHorizontal && !qHorizontal) {
    final my = (p.y + q.y) / 2;
    return <DPt>[DPt(p.x, my), DPt(q.x, my)];
  }
  // MIXED: the one corner that lets each end arrive along its own axis.
  final corner = pHorizontal ? DPt(q.x, p.y) : DPt(p.x, q.y);
  return <DPt>[corner];
}

/// The same staircase with its corridor moved clear of BOTH bodies this
/// link terminates on.
///
/// ── THE MIXED PAIR IS THE ONE WORTH READING TWICE ───────────────────────
/// It comes out of the two-horizontal formula unchanged, which does not
/// look right until you follow it: `[(p.x, lane), (q.x, lane)]` reaches the
/// VERTICAL end along its own column and the HORIZONTAL end along the
/// lane, and the horizontal end's last leg is then its own escape stub,
/// which runs the right way by construction. So the L becomes a Z rather
/// than a fourth shape, and [_simplify] takes it back to three bends
/// because the vertical end's escape point now sits ON its own column.
List<DPt> _detour(
  DPt p,
  SymbolSide fromSide,
  DBox fromBody,
  DPt q,
  SymbolSide toSide,
  DBox toBody, {
  required double clearance,
}) {
  final hull = fromBody.union(toBody);
  final pHorizontal = _isHorizontal(fromSide);
  final qHorizontal = _isHorizontal(toSide);

  if (!pHorizontal && !qHorizontal) {
    final lane = _nearerHalf(
      low: hull.left - clearance,
      high: hull.right + clearance,
      pAt: p.x,
      pMid: (fromBody.left + fromBody.right) / 2,
      pSpan: fromBody.width,
      qAt: q.x,
      qMid: (toBody.left + toBody.right) / 2,
      qSpan: toBody.width,
    );
    return <DPt>[DPt(lane, p.y), DPt(lane, q.y)];
  }

  final double lane;
  if (pHorizontal && qHorizontal) {
    lane = _nearerHalf(
      low: hull.top - clearance,
      high: hull.bottom + clearance,
      pAt: p.y,
      pMid: (fromBody.top + fromBody.bottom) / 2,
      pSpan: fromBody.height,
      qAt: q.y,
      qMid: (toBody.top + toBody.bottom) / 2,
      qSpan: toBody.height,
    );
  } else {
    // NO CHOICE HERE: the vertical end escapes to one side of its own body
    // and can only be met from that side, so the lane is decided by the pin
    // rather than by anything else.
    lane = (pHorizontal ? toSide : fromSide) == SymbolSide.top
        ? hull.top - clearance
        : hull.bottom + clearance;
  }
  return <DPt>[DPt(p.x, lane), DPt(q.x, lane)];
}

/// Whether the lane belongs on the LOW side of the two bodies — left when
/// they are compared across x, top when across y.
///
/// ═════════════════════════════════════════════════════════════════════
/// A PIN LEAVES BY ITS OWN NEAREST CORNER, AND THAT IS THE WHOLE RULE
/// ═════════════════════════════════════════════════════════════════════
/// Port 01 of a 48-port switch goes round the left; port 48 goes round the
/// right. The fan is symmetric, no cable crosses more than half the symbol
/// it is leaving, and the answer is stable per pin — it depends on that
/// pin's own position in its own body and on nothing else, so two adjacent
/// ports cannot disagree however their partners are placed.
///
/// ── TWO RULES CAME BEFORE THIS AND BOTH FAILED IN THE FIELD ──────────
/// FIRST, the shorter lane: whichever the two ends travelled less to reach,
/// which works out to "go round whichever side the pair's mean position is
/// nearer". At scale the two costs sit within a few per cent of each other,
/// so the choice flipped between adjacent ports on nothing but where each
/// one's partner happened to sit. Cables that plainly belonged together
/// left in opposite directions and met head-on along a shared comb lane.
///
/// SECOND, the direction of flow: source towards sink. That fixed the
/// flip-flopping — Sugiyama lays sources left of sinks, so a family's cables
/// came out unanimous — and unanimous was the next defect. Every run off the
/// switch turned the SAME way, so the ones on the far side dragged a wire
/// across the whole 48-port body to get there. The field sent a screenshot
/// of each of these in turn.
///
/// Both were rules about the PAIR. This one is about the PIN, which is why
/// it splits the fan where the others aligned it.
///
/// ── WHEN THE TWO PINS DISAGREE ──────────────────────────────────
/// One lane serves both ends, so two pins in opposite halves of their own
/// bodies cannot both be satisfied. THE WIDER BODY WINS: spanning more of
/// this axis is exactly what makes going the wrong way expensive, and the
/// big symbol is the one whose fan a reader is trying to follow. A 48-port
/// switch therefore decides against a two-port field device every time.
///
/// Equal spans fall through to the direction the cable FLOWS — source
/// towards sink, `pAt` and `qAt` being read in conductor order. Flow is the
/// tie-break rather than the rule now, and it is still the right tie-break:
/// two symmetrical symbols have no nearer corner to offer and the signal
/// does.
bool _prefersLowLane({
  required double pAt,
  required double pMid,
  required double pSpan,
  required double qAt,
  required double qMid,
  required double qSpan,
}) {
  final pLow = pAt < pMid;
  final qLow = qAt < qMid;
  if (pLow == qLow) return pLow;
  if (pSpan != qSpan) return pSpan > qSpan ? pLow : qLow;
  return qAt < pAt;
}

/// [_prefersLowLane] resolved to the lane coordinate itself.
double _nearerHalf({
  required double low,
  required double high,
  required double pAt,
  required double pMid,
  required double pSpan,
  required double qAt,
  required double qMid,
  required double qSpan,
}) =>
    _prefersLowLane(
      pAt: pAt,
      pMid: pMid,
      pSpan: pSpan,
      qAt: qAt,
      qMid: qMid,
      qSpan: qSpan,
    )
    ? low
    : high;

/// Whether any segment of [points] passes through the INTERIOR of either
/// body.
bool _cutsEither(List<DPt> points, DBox a, DBox b) {
  for (var i = 1; i < points.length; i++) {
    if (_cuts(points[i - 1], points[i], a)) return true;
    if (_cuts(points[i - 1], points[i], b)) return true;
  }
  return false;
}

/// Whether the axis-aligned segment [a]–[b] enters [body]'s interior.
///
/// STRICTLY the interior, and the strictness is load-bearing rather than
/// fussy: every pin sits exactly ON its body's edge (`symbolPortCentre`),
/// so a wire's own escape stub runs along that edge line and would count as
/// a crossing under any inclusive test — which would send every wire on the
/// sheet down the detour path.
bool _cuts(DPt a, DPt b, DBox body) {
  if (a.y == b.y) {
    if (a.y <= body.top || a.y >= body.bottom) return false;
    return math.max(a.x, b.x) > body.left && math.min(a.x, b.x) < body.right;
  }
  if (a.x <= body.left || a.x >= body.right) return false;
  return math.max(a.y, b.y) > body.top && math.min(a.y, b.y) < body.bottom;
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
      // ═══════════════════════════════════════════════════════════════
      // WRAPPED, NOT UNBOUNDED — and it was unbounded until the field
      // sent a screenshot of it.
      // ═══════════════════════════════════════════════════════════════
      // This read `= i`, so the i-th pin escaped i comb steps. On a
      // 30-port switch with 24 cables that is a staircase 24 steps tall,
      // climbing clear of the symbol and off the top of the sheet — the
      // exact defect `net_label_layer` had capped at six two commits
      // earlier, sitting untouched in the OTHER layer because the cap was
      // written where the defect had been reported rather than where the
      // rule lived.
      //
      // THE CEILING IS SHARED; THE DERIVATION IS NOT, and the difference is
      // worth stating because reaching for `combLaneCount` here is the
      // obvious move and it is wrong. That function derives how many lanes
      // an edge NEEDS from how wide a pennant is against the pin pitch —
      // `ceil((widest + gap) / pitch)`. An escape distance has no width to
      // compare: every wire leaving this edge is one stroke, so that
      // formula returns 1 and puts every wire on one corridor. What this
      // edge needs is one lane per pin, bounded. Only the BOUND is common,
      // and `NetLabelStyle.maxCombLanes` is where the figure is argued.
      //
      // THE COST, STATED. Pins six apart now share an escape lane, so two
      // wires can run parallel on the same corridor for part of their
      // path. That is the accepted v1 behaviour this file's header already
      // names — "two links leaving DIFFERENT symbols in one layer can
      // still share a corridor and overlap" — extended to two links on one
      // symbol, and it is the trade the ceiling buys: a shared corridor is
      // two wires you can still follow by hue and dash, and a 24-step
      // staircase is a sheet you cannot read at all.
      final lanes = math.min(
        style.maxCombLanes,
        math.max(1, ports.length),
      );
      for (var i = 0; i < ports.length; i++) {
        combIndex['${symbol.id} ${ports[i].key}'] = i % lanes;
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
  // ═══════════════════════════════════════════════════════════════════
  // THE PILLS ARE HELD BACK UNTIL EVERY WIRE IS DRAWN
  // ═══════════════════════════════════════════════════════════════════
  // They used to be appended inside the loop, right after their own wire —
  // so link N+1's TRACE landed after link N's PILL and painted over it.
  // With one wire per link and two pills each that is a line through a net
  // name on almost every flag of a busy sheet, which is what the field
  // reported as labels rendering under the wires.
  //
  // It is 96-I's defect exactly, in the other layer and for the same
  // reason: ops appended per-item paint in item order, and per-item order
  // is not paint order. `net_label_layer` answered it by holding leaders,
  // pennants and text in three lists and flushing them in paint order;
  // this is the same answer with two.
  //
  // NO DOMAIN FLUSH IS NEEDED HERE, and that is the one difference worth
  // naming. A drawn-wire layer is built for ONE scope and appended whole
  // by `buildSchematicPaintPlan`; it is not sliced into per-domain
  // `IntRange`s the filter replays, so holding ops to the end of the
  // layer cannot break a fragment the way it would there.
  final pills = <DiagramOp>[];
  final wires = <DrawnWire>[];
  final unroutable = <Uuid>[];
  final sizer = _PillSizer(measurer: measurer, style: style, unitsPerGrid: upg);

  // Accumulated as the ops are made, never by walking them afterwards —
  // see [DrawnWireLayer.inkBounds].
  DBox? ink;
  void grow(DBox box) => ink = ink == null ? box : ink!.union(box);

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
    final List<SymbolSide> pillSide;
    if (ends.length == 1) {
      // ONE END IS STILL A WIRE. A home run to the field (AC-018's
      // `PlaceEndpoint`/`OpenEndpoint`) has one pin and one direction, and
      // drawing nothing for it would hide a run that exists — the same
      // ruling `net_label_layer` takes when it labels the one end it has.
      final end = ends.first;
      final tail = _escapePoint(end.pinCentre, end.side, escapeOf(end));
      points = <DPt>[end.pinCentre, tail];
      pillAt = <DPt>[tail];
      pillSide = <SymbolSide>[end.side];
    } else {
      final a = ends[0];
      final b = ends[1];
      points = orthogonalTrace(
        fromPin: a.pinCentre,
        fromSide: a.side,
        fromEscape: escapeOf(a),
        // THE BODIES THIS LINK'S OWN ENDS SIT ON, and no others — the file
        // header on why that keeps the detour a per-link function. Null is
        // reachable and means the same thing it means everywhere else here:
        // the sheet does not draw that symbol, so route without it.
        fromBody: symbolOf[a.deviceId]?.bodyRect,
        toPin: b.pinCentre,
        toSide: b.side,
        toEscape: escapeOf(b),
        toBody: symbolOf[b.deviceId]?.bodyRect,
      );
      pillAt = <DPt>[
        _escapePoint(a.pinCentre, a.side, escapeOf(a)),
        _escapePoint(b.pinCentre, b.side, escapeOf(b)),
      ];
      pillSide = <SymbolSide>[a.side, b.side];
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

    for (final point in points) {
      grow(DBox.fromCorners(point, point));
    }

    // §11.1.1: "an orthogonal polyline with a tag pill at each end".
    for (var i = 0; i < pillAt.length; i++) {
      final pillRun = sizer.pillOps(
        _tagTextFor(link, signal),
        pillAt[i],
        pillSide[i],
        signal,
        palette,
      );
      pills.addAll(pillRun);
      // The pill's own box, read back off the op rather than re-derived:
      // its text is anchored `midCenter` INSIDE that box, so the box is the
      // whole of what a pill contributes.
      for (final op in pillRun) {
        if (op is OpRoundRect) grow(op.r);
      }
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

  // EVERY TRACE, THEN EVERY PILL. See the declaration of `pills`.
  ops.addAll(pills);

  return DrawnWireLayer(
    ops: List<DiagramOp>.unmodifiable(ops),
    wires: List<DrawnWire>.unmodifiable(wires),
    unroutableLinkIds: List<Uuid>.unmodifiable(unroutable),
    inkBounds: ink,
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

  /// [anchor] is the escape point, and the pill hangs OUTBOARD of it along
  /// [side] rather than being centred on it.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// CENTRED ON THE ESCAPE PUT HALF THE PILL BACK INSIDE THE SYMBOL
  /// ═══════════════════════════════════════════════════════════════════
  /// [SchematicWireStyle.escapeGu] is 3 gu and a pill reading
  /// `W053 · VID·HD21` is several times that wide, so a pill centred on the
  /// escape point straddled the body edge and painted its inner half over
  /// the port label — and it is painted LAST, so it won. The field's
  /// screenshot showed `HDMI IN 1` reading as `MI IN 1`.
  ///
  /// Anchoring the pill's NEAR EDGE at the escape point is the rule
  /// `net_label_layer._pennantBox` already uses for the pennant at the end
  /// of a leader, and taking the same one here is DR-001's point rather
  /// than a coincidence: `drawn` and `netLabels` are two renderings of ONE
  /// Link, so the flag naming it belongs in the same place in both.
  ///
  /// THE EXTENT IS PER-AXIS because the pill is always horizontal: it is
  /// the WIDTH that runs along a left/right escape and the HEIGHT that runs
  /// along a top/bottom one. Using width for all four would push a
  /// top-edge pill a whole text run clear of a symbol it was never near.
  List<DiagramOp> pillOps(
    String text,
    DPt anchor,
    SymbolSide side,
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
    final centre = switch (side) {
      SymbolSide.left => DPt(anchor.x - width / 2, anchor.y),
      SymbolSide.right => DPt(anchor.x + width / 2, anchor.y),
      SymbolSide.top => DPt(anchor.x, anchor.y - height / 2),
      SymbolSide.bottom => DPt(anchor.x, anchor.y + height / 2),
    };
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
        fill: Fill(
          compositeOver(signal.argb, style.fillAlpha, palette.bodyFill),
        ),
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
