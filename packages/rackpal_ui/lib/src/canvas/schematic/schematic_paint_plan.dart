// rackpal_ui/src/canvas/schematic/schematic_paint_plan.dart
//
// ONE FRAME OF THE SCHEMATIC, AS ONE DISPLAY LIST.
//
// ═════════════════════════════════════════════════════════════════════
// WHY EVERYTHING GOES THROUGH ONE LIST, INCLUDING THE BACKGROUND
// ═════════════════════════════════════════════════════════════════════
// The schematic canvas that was deleted at `c5669a9` painted its
// background fill IGNORING its own paint offset while the symbols DID get
// offset — so the sheet ground covered the toolbar and one box appeared to
// float over it. Twelve consecutive `fix:` commits never touched that line,
// because a background drawn beside the content does not look like part of
// the content until you compare their transforms.
//
// The structural answer taken here is not "remember the offset in two
// places". It is that THERE IS ONLY ONE PLACE: the sheet ground is
// [SchematicPaintPlan.ops]`.first`, an ordinary `OpRect` in the same
// display list as every symbol and every wire, replayed by the same
// `replay()` call inside the same transform. A background that ignored the
// paint offset is not a bug this file can have; it would have to be drawn
// by code that does not exist. `render_schematic_canvas_test.dart` asserts
// both halves — that the ground is op zero, and that the one transform
// carries the offset.
//
// ═════════════════════════════════════════════════════════════════════
// THE PERFORMANCE CONTRACT M2-D WROTE DOWN, HONOURED LITERALLY
// ═════════════════════════════════════════════════════════════════════
// `net_label_layer.dart`'s header: "M2-E replays seven domains' label runs
// unchanged and rebuilds only the eighth." That is not a metaphor here.
// Every out-of-scope domain contributes `scene.fragmentFor('domain:<id>')`
// — a `sublist` of the ALREADY BUILT `DiagramScene.ops`, whose elements are
// the identical `DiagramOp` INSTANCES M2-D emitted. No op is copied, no
// text is re-measured, no colour is re-resolved. `schematic_paint_plan_test
// .dart` asserts it with `identical`, because "we did not rebuild it" is
// exactly the kind of claim that rots into a comment.
//
// Only the soloed domain's run is replaced, by `wire_trace.dart`'s
// staircases. `Alt`-hover and focus do not replace anything at all — see
// `DrawnScope.replacesDomainRun`.
//
// ═════════════════════════════════════════════════════════════════════
// A SYMBOL FRAGMENT IS LOCAL; A DOMAIN FRAGMENT IS ABSOLUTE
// ═════════════════════════════════════════════════════════════════════
// M2-D's distinction, and the one thing a composer of these fragments has
// to get right. `schematic_scene.dart` brackets each symbol's ops with
// `OpSave`/`OpTransform(translate)`/`OpRestore` in the WHOLE-scene op list,
// but `fragmentFor(deviceId)` deliberately hands back the LOCAL ops
// without that bracket, "so a widget that positions the fragment itself
// must not re-apply it". This file positions them itself, from the
// published `RenderedSymbol.bodyRect.topLeft`, and re-emits the bracket. A
// domain run carries sheet coordinates already and gets none.

import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_filter.dart';
import 'package:vector_math/vector_math_64.dart';

/// Clear space, in grid units, between the outermost ink and the edge of
/// the painted sheet ground. A stated choice: enough that a pennant or a
/// tag pill at the extreme edge is not flush against the paper.
const double kSheetGroundMarginGu = 8;

/// One frame's replay list, plus what the screen has to be able to SAY
/// about it.
///
/// Immutable and rebuilt whole on every change. That is deliberate and it
/// is the second half of the `c5669a9` post-mortem: the deleted canvas
/// guarded every render-object setter with `identical()` against a `final
/// List` that was mutated in place, so `updateRenderObject` could never
/// mark anything needing paint and no `setState` reached the screen. A
/// value that is never mutated makes `identical` mean what the setter
/// assumes it means.
@immutable
final class SchematicPaintPlan {
  const SchematicPaintPlan({
    required this.ops,
    required this.mode,
    required this.scope,
    required this.replayedDomainRuns,
    required this.rebuiltDomainRuns,
    required this.hiddenDomainRuns,
    required this.drawnWires,
    required this.unroutableLinkIds,
    required this.ground,
  });

  /// The whole frame, ground first. Replayed by exactly one `replay()`.
  final List<DiagramOp> ops;

  /// canon §11.1.1's derived value for the sheet as a whole: `drawn` when
  /// any scope is in `drawn`, `netLabels` otherwise.
  final SheetRenderMode mode;

  /// The one live scope, or null on an unfiltered sheet with no hover and
  /// no focus.
  final DrawnScope? scope;

  /// How many domain label runs were replayed BYTE-FOR-BYTE out of the
  /// already-built scene. The number M2-D's contract is about.
  final int replayedDomainRuns;

  /// How many were replaced by drawn wires. Zero or one, never more —
  /// `drawn` needs "exactly one" domain (§11.1.1).
  final int rebuiltDomainRuns;

  /// How many were dropped by the filter — see `schematic_filter.dart`'s
  /// header on Hide versus the unmeasured Ghost.
  final int hiddenDomainRuns;

  final List<DrawnWire> drawnWires;

  /// Links in scope that could not be routed. See
  /// [DrawnWireLayer.unroutableLinkIds].
  final List<Uuid> unroutableLinkIds;

  /// The painted sheet ground, in scene coordinates — what the viewport is
  /// framed against on first layout.
  final DBox ground;

  /// This plan with [overlayOps] appended, and everything else shared.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE SPLIT THIS CLASS ALREADY DESCRIBED, MADE USABLE (`#705`)
  /// ═══════════════════════════════════════════════════════════════════
  /// `buildSchematicPaintPlan`'s own note says it: the base is a pure
  /// projection of `(scene, doc, filter, scope)` and the connect overlay
  /// is a projection of the SCREEN's transient state, a caret and an
  /// armed pin. The two were nonetheless built together, so moving the
  /// caret one pin rebuilt every symbol and every net label in the
  /// document: 7,155 ops on the 300-link fixture, 78,660 at headroom.
  ///
  /// With this, the screen memoises the base and splices the overlay,
  /// which is a list copy rather than a layout. Every field below the ops
  /// is shared rather than recomputed, because every one of them is a
  /// fact about the BASE: a caret ring cannot change which links are
  /// unroutable or how big the ground is.
  SchematicPaintPlan withOverlay(List<DiagramOp> overlayOps) {
    if (overlayOps.isEmpty) return this;
    return SchematicPaintPlan(
      ops: List<DiagramOp>.unmodifiable([...ops, ...overlayOps]),
      mode: mode,
      scope: scope,
      replayedDomainRuns: replayedDomainRuns,
      rebuiltDomainRuns: rebuiltDomainRuns,
      hiddenDomainRuns: hiddenDomainRuns,
      drawnWires: drawnWires,
      unroutableLinkIds: unroutableLinkIds,
      ground: ground,
    );
  }
}

/// Composes one frame.
///
/// PURE, and takes no `BuildContext`, no viewport and no widget: it is the
/// whole of "what does this sheet look like right now", so it can be
/// asserted on directly instead of through pixels. `[groundArgb]` and
/// `[palette]` arrive from the theme, which is the only reason this
/// function knows a colour at all.
SchematicPaintPlan buildSchematicPaintPlan({
  required SchematicScene scene,
  required RackDocument doc,
  required SchematicViewFilter filter,
  required DrawnScope? scope,
  required TextMeasurer measurer,
  required SchematicPalette palette,
  required int groundArgb,
  SchematicWireStyle wireStyle = const SchematicWireStyle(),
  List<DiagramOp> overlayOps = const <DiagramOp>[],
}) {
  final ops = <DiagramOp>[];

  // ── the wires, BUILT FIRST AND EMITTED LATER ─────────────────────────
  //
  // ═══════════════════════════════════════════════════════════════════
  // THE GROUND HAS TO KNOW HOW BIG THE DRAWING IS BEFORE IT IS PAINTED
  // ═══════════════════════════════════════════════════════════════════
  // Built here, appended further down in paint order (see the note there,
  // which is about WHERE they land in the list and is unchanged). The
  // split exists because the ground is op ZERO and was sized from
  // `scene.bounds` alone — the NET-LABEL scene's ink, which knows nothing
  // about a layer built after it.
  //
  // That held while every wire ran between two escape points, inside the
  // envelope the pennants had already staked out. It stopped holding when
  // wires began routing AROUND bodies and pills began hanging outboard of
  // their anchors: on the 300-link fixture 26 wires reached past the
  // ground and were painted on the margin outside the paper. The field
  // reported it as wires going off the canvas, and that is exactly what it
  // was — ink with no sheet under it.
  //
  // A PLAN THAT PAINTS A MARK OUTSIDE ITS OWN GROUND IS THE BUG, not the
  // mark. The router places wires where they are legible; the paper is
  // what has to accommodate them.
  var wires = const DrawnWireLayer(
    ops: <DiagramOp>[],
    wires: <DrawnWire>[],
    unroutableLinkIds: <Uuid>[],
  );
  if (scope != null && scope.linkIds.isNotEmpty) {
    wires = buildDrawnWireLayer(
      scene: scene,
      doc: doc,
      linkIds: scope.linkIds,
      measurer: measurer,
      palette: palette,
      style: wireStyle,
    );
  }

  // ── the sheet ground, op ZERO ────────────────────────────────────────
  //
  // See the file header. It is in the list, not beside it.
  final margin = kSheetGroundMarginGu * kSchematicUnitsPerGrid;
  final ink = wires.inkBounds == null
      ? scene.scene.bounds
      : scene.scene.bounds.union(wires.inkBounds!);
  final ground = ink.inflate(margin);
  ops.add(OpRect(ground, fill: Fill(groundArgb)));

  // ── the symbols, each from its own LOCAL fragment ────────────────────
  //
  // In `scene.symbols` order, which is the scene's own op order — by
  // Sugiyama layer, then top to bottom within the layer — so the sheet
  // paints in the order it reads.
  for (final symbol in scene.symbols) {
    if (!scene.scene.fragments.containsKey(symbol.id)) continue;
    final origin = symbol.bodyRect.topLeft;
    ops
      ..add(const OpSave())
      ..add(OpTransform(Matrix4.translationValues(origin.x, origin.y, 0)))
      ..addAll(scene.scene.fragmentFor(symbol.id).ops)
      ..add(const OpRestore());
  }

  var replayed = 0;
  var rebuilt = 0;
  var hidden = 0;
  final replacedDomain = scope != null && scope.replacesDomainRun
      ? filter.soloedDomain
      : null;

  // ── the wires, BEFORE the labels ─────────────────────────────────────
  //
  // ═══════════════════════════════════════════════════════════════════
  // THIS ORDER IS THE REVERSE OF THE ONE M2-E SHIPPED, AND ON PURPOSE
  // ═══════════════════════════════════════════════════════════════════
  // The wires used to be emitted last, on the reasoning that "the thing
  // the user asked to see has to be emitted last" — which reads well and
  // is wrong about WHICH marks it puts a wire on top of.
  //
  // A SCOPED DOMAIN'S WIRES REPLACE ITS OWN LABELS (see `replacedDomain`
  // below: that run is skipped, not drawn under). So a wire can never
  // cross the flags of the cable it belongs to. The only pennants in its
  // path belong to the OTHER seven domains — marks the user did not ask
  // to change and still has to read.
  //
  // Text on top is the drafting convention and it is the right way round
  // here for a legibility reason rather than a stylistic one: a wire
  // interrupted by a small flag is still obviously a wire, and a flag with
  // a line through its net name is not readable at all. One of those
  // failures costs nothing and the other costs the name.
  //
  // THE HIGHLIGHT STILL HIGHLIGHTS. Alt-hover and focus work because the
  // wires are INK THAT WAS NOT THERE, not because they are topmost; a
  // handful of small pennants over a long staircase does not stop it
  // reading as new.
  //
  // WHAT THIS DOES NOT DO, so nobody reads more into it than it does: the
  // pennant fill is `NetLabelStyle.fillAlpha` = 31/255, about 12%, so a
  // wire still shows THROUGH a flag's body. What the reorder guarantees is
  // that the flag's OUTLINE and its TEXT — both opaque — land on top of
  // the wire rather than under it. That is the legibility win. It is not a
  // knockout halo, and adding one would be a real design (it has to be
  // deterministic to survive the byte-identical exit criterion) rather
  // than a tweak.
  //
  // BUILT ABOVE, WHERE THE GROUND CAN SEE ITS SIZE — only the append is
  // here. That is the one thing this note used to be able to assume and
  // now cannot: build order and paint order are different questions.
  ops.addAll(wires.ops);

  // ── the label runs, one contiguous sub-picture per domain ────────────
  //
  // Ascending domain id — `schematicDomainOrder`'s order and M2-D's — so
  // the n-th chip in the bar governs the n-th run.
  for (final domain in schematicDomainOrder(doc.registries)) {
    final range = scene.domainFragments[domain];
    if (range == null) continue; // no link of this domain on the sheet.
    if (domain == replacedDomain) {
      rebuilt++;
      continue; // its wires are appended below, in place of its labels.
    }
    if (!filter.shows(domain)) {
      hidden++;
      continue;
    }
    // THE REPLAY. `fragmentFor` sublists the built scene; the elements are
    // M2-D's own op instances. Nothing here rebuilds a label.
    ops.addAll(scene.scene.fragmentFor(domainFragmentKey(domain)).ops);
    replayed++;
  }

  // The stubs whose family did not resolve to a domain. Not a ninth chip —
  // see `SchematicViewFilter.showsUnresolved`.
  if (filter.showsUnresolved &&
      scene.scene.fragments.containsKey(kUnresolvedDomainFragmentKey)) {
    ops.addAll(scene.scene.fragmentFor(kUnresolvedDomainFragmentKey).ops);
  }

  // ── the gesture in flight, after absolutely everything ───────────────
  //
  // LAST, for the reason the labels are last and the wires are under them:
  // the display list is painted in order, there is no z-index in the IR,
  // and the thing the user is DOING right now has to be on top of the thing
  // they are doing it to. A caret ring behind a symbol body is a cursor
  // the user cannot see.
  //
  // PASSED IN, NOT BUILT HERE, and that is deliberate. This function is a
  // pure projection of (scene, doc, filter, scope); the connect overlay is
  // a projection of the SCREEN's transient state — a caret, an armed pin —
  // which has no business in this signature. `schematic_canvas_screen.dart`
  // builds it and hands over the ops.
  ops.addAll(overlayOps);

  return SchematicPaintPlan(
    ops: List<DiagramOp>.unmodifiable(ops),
    mode: scope == null ? SheetRenderMode.netLabels : SheetRenderMode.drawn,
    scope: scope,
    replayedDomainRuns: replayed,
    rebuiltDomainRuns: rebuilt,
    hiddenDomainRuns: hidden,
    drawnWires: wires.wires,
    unroutableLinkIds: wires.unroutableLinkIds,
    ground: ground,
  );
}
