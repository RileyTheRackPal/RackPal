// rackpal_core/src/draw/scene/schematic_scene.dart — pure Dart.
//
// The document → schematic display list. It projects a `RackDocument` onto
// the abstract graph `sugiyama.dart` lays out, then composes one
// `DiagramScene` from `symbol_layer.dart`'s fragments — the schematic's
// counterpart to `scene_builder.dart`, and it follows that file's
// conventions deliberately: absolute hits, LOCAL per-entity fragments
// bracketed by `OpSave`/`OpTransform`/`OpRestore`, ink bounds measured from
// the ops actually emitted.
//
// ── WHAT IS IN THIS SCENE, AND WHAT IS NOT ──────────────────────────────
// IN: the symbols — the whole of Sugiyama phases 0–3's product (canon
// §11.1.3: "These place the SYMBOLS, and symbol placement is required in
// both idioms") — and, since M2-D, THE NET LABELS.
//
// The labels are not an addition to the drawing; under DR-001 they ARE the
// drawing of a Link. Every Link renders by default as a pair of net labels,
// one stub off each of its two pins, and a drawn orthogonal polyline is not
// the default rendering of a Link on an unfiltered sheet (canon §11.1.1).
// The geometry lives in `net_label_layer.dart`, which this file composes
// exactly as it composes `symbol_layer.dart` — with one difference stated
// where it is registered below: a SYMBOL fragment is local and bracketed by
// a translate, a DOMAIN fragment is absolute and is not.
//
// NOT IN, and none of it is an oversight:
//   * DRAWN WIRES — phase 4, `drawn` mode only (DR-001 §11.1.1). Reached by
//     a domain filter, `Alt`-hover or focus, none of which exists yet. The
//     per-domain fragments this file registers are what let M2-E switch one
//     domain to `drawn` without rebuilding the other seven.
//   * CHANNEL ROUTING, THE CROSSING SWEEP, HOP ARCS, JUNCTION STAGGERING —
//     out of v1 scope entirely (canon §11.1.3 items 1–5).
//   * LOD TIERING, bank collapse to vector pins, connector glyphs, header
//     metadata and badges — `symbol_layer.dart`'s own deferral list, which
//     this file does not extend or work around.
//
// ── THE ONE SCALE ANCHOR, DERIVED AND NOT INVENTED ──────────────────────
// `symbol_layer.dart` deliberately left `gu` unconverted, because
// "converting gu to diagram points needs the sheet's scale anchor, which
// the schematic scene builder has not been written yet". This is that
// builder, so the anchor is settled here, once, and DERIVED through the
// existing chain rather than as a new constant:
//
//   1 gu   = kGridUnit = Len(2_500_000) = 2.5 mm exactly   (CR-004)
//   1 diagram unit = 1 PDF point = 1/72 in                 (CR-007)
//   => [kSchematicUnitsPerGrid] = pointsForLen(kGridUnit)  ≈ 7.0866
//
// It goes through `units/print_units.dart` for the reason that file's own
// header gives — "NOTHING ANYWHERE ELSE MAY HARDCODE 126 OR 72" — so a
// change to `kGridUnit` moves the symbol, the pin pitch and the layout
// gutter together instead of desynchronising them.
//
// THE SCHEMATIC IS THEREFORE DRAWN AT 1:1 PHYSICAL, unlike the rack
// elevation's 22:126 reduction (`rack_geometry.dart`). That is not a second
// convention smuggled in: docs/05 §3 states the symbol in millimetres —
// "header band, height 6 gu", "DESIGNATOR (3.5 mm cap)" — so `gu` is a
// physical pitch there in a way `22 units per RU` never was, and a sheet
// that needs to fit is scaled by `draw/sheet/drawing_scale.dart`, which is
// the one place a ratio may be applied.
//
// ── WHICH DEVICES GET A SYMBOL ──────────────────────────────────────────
// A device is drawn iff its resolved `TemplateBody` declares at least one
// `PortDef`. A symbol IS its pins (docs/05 §3: "A symbol is a body
// rectangle with a header band and pins on its four edges"), and a device
// with no ports — a blank panel, a vent, a shelf — can carry no Link, so a
// pinless box on the wiring drawing would be furniture.
//
// THE TEST IS THE TEMPLATE, NOT `doc.ports`. Ports are LAZILY MATERIALISED
// (AC-006): an AVR nobody has wired yet has zero rows in `doc.ports` and
// must still appear on the schematic, or the drawing would show devices
// appearing as they are cabled. Placement is not a filter either — a
// `StagedPlacement` device with ports still wires, which is AC-018's
// design-intent case.
//
// Devices that fail the test are COUNTED, in
// [SchematicScene.unsymbolisedDeviceIds], never silently dropped — the same
// discipline as `RackScene.unlabelledDeviceIds`.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart'
    show hostRackOf, templateKeyFor;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/net_label_layer.dart';
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/scene/sugiyama.dart';
import 'package:rackpal_core/src/draw/scene/symbol_hit_test.dart';
import 'package:rackpal_core/src/draw/scene/symbol_layer.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/sheet.dart';
import 'package:rackpal_core/src/model/structure_body.dart' show SheetEdge;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/constants.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/print_units.dart';
import 'package:rackpal_core/src/units/pt.dart';
import 'package:vector_math/vector_math_64.dart';

/// Diagram units (PDF points) per schematic grid unit — see the file
/// header. Not a literal anywhere else in the repository.
final double kSchematicUnitsPerGrid = pointsForLen(kGridUnit);

/// The symbol figures docs/05 §3 states, in the grid units it states them
/// in, plus the layout knobs.
///
/// EVERY FIELD HERE IS A CITATION EXCEPT [portSizeGu], which is called out
/// as a choice below. Keeping them in `gu` rather than in diagram units is
/// what lets [buildSchematicScene] size a symbol in exact integers and hand
/// the SAME integers to the layout — a symbol that is 20 gu wide occupies
/// 20 gu of the sheet, and the two cannot drift.
@immutable
final class SchematicMetrics {
  const SchematicMetrics({
    this.headerHeightGu = 6,
    this.pinPitchGu = kPinPitch,
    this.portSizeGu = 1,
    this.minBodyWidthGu = 20,
    this.minBodyHeightGu = 16,
    this.headerTextPadGu = 8,
    this.sideLabelPadGu = 12,
    this.layout = const SugiyamaParams(),
  });

  /// docs/05 §3's ASCII figure: "header band, height 6 gu".
  final int headerHeightGu;

  /// §3: "Top and bottom pins distribute across the width at 2 gu pitch".
  /// `kPinPitch` (units/constants.dart) is that 2.
  final int pinPitchGu;

  /// The pin circle's diameter. A STATED CHOICE — §3 draws the pin as a
  /// connector glyph and gives it no size. 1 gu makes the circle straddle
  /// the body edge by half a gu and leaves a clear gu between two pins at
  /// the 2 gu pitch, which is the smallest value that keeps adjacent pins
  /// visually separate. Recorded as a choice so it is not read as a figure
  /// out of the corpus.
  final int portSizeGu;

  /// §3's sizing formula: `width = max(20gu, …)`.
  final int minBodyWidthGu;

  /// §3: `height = 6gu + (max(leftPins, rightPins) + 1) × 2gu`, minimum
  /// 16 gu.
  final int minBodyHeightGu;

  /// §3: `textWidth(designator + name) + 8gu`.
  final int headerTextPadGu;

  /// §3: `maxLeftLabel + maxRightLabel + 12gu`.
  final int sideLabelPadGu;

  /// Phases 0–3's own knobs.
  final SugiyamaParams layout;
}

/// The fragment key under which [SchematicScene] registers one domain's
/// net-label sub-picture — `domain:video.digital`.
///
/// NAMESPACED, because `DiagramScene.fragments` is one flat `Map<String,
/// …>` shared with the per-device symbol fragments, whose keys are
/// `DeviceInstance.id.v` UUIDs. A UUID contains no colon, so the prefix
/// cannot collide with one; `schematic_scene_test.dart` asserts that
/// rather than trusting it.
String domainFragmentKey(SignalDomainId domain) => 'domain:${domain.v}';

/// The fragment key for label ops whose domain did not resolve.
///
/// A KEY, BUT NOT A DOMAIN. It is registered in `DiagramScene.fragments`
/// so that every op in the scene belongs to exactly one fragment — an
/// invariant `schematic_scene_test.dart` asserts by arithmetic, and one a
/// replay-by-fragment consumer needs in order to draw the whole sheet.
/// It is deliberately NOT a ninth entry in
/// [SchematicScene.domainFragments], which is typed by `SignalDomainId`:
/// minting a fake id would put a ninth chip in the domain filter bar and
/// a ninth swatch in the legend for something no `Service` can resolve
/// to, which is the same mistake `seed_registries.dart` refused when it
/// left PAL-2's reserved yellow out of the eight. `?` cannot collide with
/// a real id — those are dotted lowercase — and cannot collide with a
/// device UUID either.
const String kUnresolvedDomainFragmentKey = 'domain:?';

/// The output of [buildSchematicScene].
@immutable
final class SchematicScene {
  const SchematicScene({
    required this.scene,
    required this.symbols,
    required this.positions,
    required this.layers,
    required this.netLabels,
    required this.domainFragments,
    required this.unresolvedDomainFragment,
    required this.unsymbolisedDeviceIds,
    required this.unnamedLinkIds,
    required this.unlabelledLinkIds,
    required this.underGlyphedFamilyIds,
    required this.reversedLinkIds,
    required this.nonForwardLinkIds,
    required this.crossings,
    required this.layout,
    required this.symbolTier,
  });

  /// The one composed display list. `fragmentFor(deviceId.v)` → that
  /// symbol's LOCAL fragment, exactly as `RackScene` does for a device.
  final DiagramScene scene;

  /// Every drawn symbol, positioned absolutely, in the scene's own op
  /// order: by layer, then top to bottom within the layer. The display
  /// list therefore reads the way the sheet does.
  final List<RenderedSymbol> symbols;

  /// Each drawn device's symbol origin in INTEGER grid units — what
  /// `SheetItem.position` persists (CR-004, CR-012). Looked up, not
  /// iterated; [layers] is the ordered view.
  final Map<Uuid, Pt> positions;

  /// Device ids by Sugiyama layer, each layer top to bottom.
  final List<List<Uuid>> layers;

  /// Every drawn net label, in the scene's own op order (by domain, then
  /// by link). What M2-E's hover, focus and filter read instead of
  /// re-deriving pennant geometry — see [RenderedNetLabel].
  final List<RenderedNetLabel> netLabels;

  /// Each signal domain's label sub-picture, as an op range into
  /// `scene.ops`, and registered in `scene.fragments` under
  /// [domainFragmentKey] so `fragmentFor` reaches it too.
  ///
  /// THE WHOLE REASON THE LABEL OPS ARE ORDERED THE WAY THEY ARE. A domain
  /// filter switches ONE domain to `drawn` (DR-001 §11.1.1); with a
  /// per-domain sub-picture it rebuilds that one and replays seven, and
  /// without one it rebuilds all eight on every filter click.
  /// The layout this scene was placed by, so a caller can hand it back
  /// (DR-076 §11.75.2).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A VALUE, NOT A CACHE, AND THE DIFFERENCE IS WHOSE JOB IT IS
  /// ═══════════════════════════════════════════════════════════════════
  /// Measured at 3,600 links, re-deriving this is ~50 ms of a 144 ms
  /// build, and the two label measurements it needs walk every symbol.
  /// DR-011.4 already rules that committing a link must not re-lay-out
  /// the sheet, so a wire edit reusing it is that clause kept rather than
  /// re-derived.
  ///
  /// WHEN IT IS SAFE TO REUSE IS NOT A QUESTION THIS TYPE CAN ANSWER.
  /// §11.75.2 keys it on the `structure` epoch, which every command
  /// already declares; handing it back after a device was added would
  /// place symbols by a stale map. The holder decides; this only carries.
  final SugiyamaLayout layout;

  /// The half of this scene a `wires` change cannot move, so a caller can
  /// hand it back (DR-076 §11.75.2). See [SchematicSymbolTier], which
  /// carries the same "the holder decides, this only carries" contract
  /// [layout] does — and which contains that layout.
  final SchematicSymbolTier symbolTier;

  final Map<SignalDomainId, IntRange> domainFragments;

  /// The label ops whose domain did not resolve, or `null` when there are
  /// none. Deliberately NOT a ninth entry in [domainFragments] — see
  /// `NetLabelLayerBuild.unresolvedRange`.
  final IntRange? unresolvedDomainFragment;

  /// Devices this scene does NOT draw, because their template declares no
  /// ports — see the file header. Empty is the normal case for a wired
  /// project and non-empty is normal too (every rack has blanks).
  ///
  /// It exists so a caller can SAY so. A schematic that silently omits a
  /// device is indistinguishable from one that lost it.
  final List<Uuid> unsymbolisedDeviceIds;

  /// Links whose net name did not resolve, drawn with the unknown token.
  /// See `NetLabelLayerBuild.unnamedLinkIds`.
  final List<Uuid> unnamedLinkIds;

  /// Links that got no label at either end. See
  /// `NetLabelLayerBuild.unlabelledLinkIds`.
  final List<Uuid> unlabelledLinkIds;

  /// Families drawn with a glyph that may be the wrong one, because no
  /// model field selects a domain's `glyph` from its `glyphAlt` and two
  /// domains carry a third shape with nowhere to live at all. See
  /// `signal_style.dart`'s header; DR-010 §11.10.4 keeps the fix out of
  /// scope, so this is the count that keeps it from being silent (G4).
  final List<SignalFamilyId> underGlyphedFamilyIds;

  /// Links phase 0 turned around to break a cycle (docs/05 §10.2: "Reversed
  /// edges are flagged and still render their arrowhead at the true sink").
  /// Nothing draws an arrowhead yet; the flag is produced now so the stage
  /// that does is not re-deriving it.
  final List<Uuid> reversedLinkIds;

  /// Links that do not run left-to-right in the final layering because a
  /// rule or a pin overrode the graph — see
  /// [SugiyamaLayout.nonForwardEdgeIds].
  final List<Uuid> nonForwardLinkIds;

  /// Edge crossings in the chosen ordering. Phase 2's objective.
  final int crossings;
}

/// Everything a `wires` change cannot move (DR-076 §11.75.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE PREFIX OF THE DISPLAY LIST, AND WHY IT IS A PREFIX
/// ═══════════════════════════════════════════════════════════════════════
/// `buildSchematicScene` emits every symbol and then every net label, in
/// that order and for a reason the label stage states: a pennant must not
/// be overpainted by a body it sits beside, and the IR has no z-index. So
/// the symbol half is a contiguous run at the head of `ops`, and a rebuild
/// that only needs new labels can keep it whole rather than re-emitting it.
///
/// Measured at 3,600 links: this half is the majority of the build and
/// 49,860 of its 78,660 ops, BEFORE a single cable exists. It is also
/// domain-independent, which is why AC-008's per-domain split cannot reach
/// it and why §11.75.1 calls that remedy the smaller half.
///
/// WHAT INVALIDATES IT IS THE CALLER'S QUESTION, exactly as with
/// [SchematicScene.layout]: §11.75.2 keys it on `structure` and `meta`,
/// which every command already declares. Handing back a tier built before
/// a device was added draws a sheet missing that device, and nothing in
/// here could tell.
///
/// ONE STALENESS IT DOES CARRY, STATED RATHER THAN HIDDEN. [layout]'s
/// `reversedEdgeIds` and `nonForwardEdgeIds` describe the EDGES that
/// existed when it ran, so a link added under a reused tier appears in
/// neither. Censused at the time of writing: nothing in `lib/` reads
/// `SchematicScene.reversedLinkIds` or `nonForwardLinkIds` — the only
/// callers are two tests — so this costs no drawing today. It is written
/// down because the first consumer to appear inherits it silently.
@immutable
final class SchematicSymbolTier {
  const SchematicSymbolTier({
    required this.ops,
    required this.fragments,
    required this.symbols,
    required this.layers,
    required this.positions,
    required this.unsymbolisedDeviceIds,
    required this.minTextPt,
    required this.bounds,
    required this.layout,
  });

  /// The symbol ops, in scene order, each bracketed by its own
  /// save/transform/restore exactly as a whole build emits them.
  final List<DiagramOp> ops;

  /// Symbol fragments only, keyed by `DeviceInstance.id.v`. The domain
  /// fragments belong to the label half and are added by the scene build.
  final Map<String, IntRange> fragments;

  final List<RenderedSymbol> symbols;
  final List<List<Uuid>> layers;
  final Map<Uuid, Pt> positions;
  final List<Uuid> unsymbolisedDeviceIds;

  /// The smallest text the SYMBOLS emit. The labels lower it further.
  final double minTextPt;

  /// The symbols' union, or null when there are none. The label ink is
  /// unioned in by the scene build.
  final DBox? bounds;

  final SugiyamaLayout layout;
}

/// Builds [SchematicSymbolTier] — the layout and every symbol, with no
/// label in it (DR-076 §11.75.2).
///
/// Split out of [buildSchematicScene] rather than duplicated: the scene
/// build calls this when it is handed no tier to reuse, so there is one
/// symbol path and a held tier cannot drift from a fresh one.
SchematicSymbolTier buildSchematicSymbolTier({
  required RackDocument doc,
  required TextMeasurer measurer,
  SchematicPalette palette = const SchematicPalette(),
  SchematicMetrics metrics = const SchematicMetrics(),
  NetLabelStyle netLabelStyle = const NetLabelStyle(),
  Map<Uuid, Pt> holdAt = const <Uuid, Pt>{},
  SugiyamaLayout? reuseLayout,
  Map<Uuid, Set<String>> expandedBanks = const <Uuid, Set<String>>{},
  bool pinnedPositionsOnly = false,
}) {
  final upg = kSchematicUnitsPerGrid;
  final pinned = _holdOrPin(
    doc,
    holdAt,
    pinnedPositionsOnly: pinnedPositionsOnly,
  );

  // ── which devices get a symbol (see the file header) ─────────────────
  final candidates = doc.devices.values.toList()
    ..sort((a, b) => a.id.v.compareTo(b.id.v));
  // A LIST, not a map keyed by the device: this file's determinism rests
  // on never iterating a hash container (see `sugiyama.dart`'s header,
  // rule 2), and a `Map<DeviceInstance, …>` would be exactly that.
  final drawable = <({DeviceInstance device, TemplateBody body})>[];
  final unsymbolised = <Uuid>[];
  for (final device in candidates) {
    final body = doc.templates[templateKeyFor(device.templateRef)]?.body;
    if (body == null || body.ports.isEmpty) {
      unsymbolised.add(device.id);
      continue;
    }
    drawable.add((device: device, body: body));
  }

  // ── the graph's edges ────────────────────────────────────────────────
  //
  // BEFORE the nodes, and that ordering is load-bearing: docs/05 §10.2
  // phase 1 forces off-rack DESTINATIONS to the last layer, and whether a
  // device is a destination is a fact about its links.
  final deviceOfPort = <Uuid, Uuid>{};
  final portDefOfPort = <Uuid, PortDef>{};
  for (final port in doc.ports.values) {
    deviceOfPort[port.id] = port.deviceId;
    final key = port.templatePortKey;
    if (key == null) continue;
    final device = doc.devices[port.deviceId];
    if (device == null) continue;
    final body = doc.templates[templateKeyFor(device.templateRef)]?.body;
    if (body == null) continue;
    for (final def in body.ports) {
      if (def.key == key) {
        portDefOfPort[port.id] = def;
        break;
      }
    }
  }

  final drawnIds = <String>{for (final d in drawable) d.device.id.v};
  final links = doc.links.values.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });
  final edges = <LayoutEdge>[];
  final feeds = <String>{};
  for (final link in links) {
    final edge = _edgeFor(link, deviceOfPort, portDefOfPort, drawnIds);
    if (edge == null) continue;
    edges.add(edge);
    feeds.add(edge.from);
  }

  // ── the graph's nodes ────────────────────────────────────────────────
  final drawn = <_Candidate>[];
  for (final entry in drawable) {
    drawn.add(
      _measureCandidate(
        doc: doc,
        device: entry.device,
        body: entry.body,
        measurer: measurer,
        metrics: metrics,
        pinnedAt: pinned[entry.device.id],
        isDestination: !feeds.contains(entry.device.id.v),
        expandedBanks: expandedBanks[entry.device.id] ?? const <String>{},
      ),
    );
  }

  // ── phases 0–3 ───────────────────────────────────────────────────────
  //
  // ═════════════════════════════════════════════════════════════════════
  // HELD, WHEN A CALLER CAN PROVE NOTHING STRUCTURAL MOVED (DR-076)
  // ═════════════════════════════════════════════════════════════════════
  // Measured at 3,600 links: this phase is ~50 ms of a 144 ms build, and
  // it is pure over (nodes, edges, params). DR-011.4 already rules that
  // committing a link must NOT re-lay-out the sheet, so a wire edit
  // holding the layout is that clause expressed as a cache key rather
  // than re-derived every frame.
  //
  // THE CALLER OWNS THE INVALIDATION AND THIS FUNCTION DOES NOT GUESS.
  // §11.75.2 keys it on the `structure` epoch, which every command
  // already declares; a `reuseLayout` handed in after a device was added
  // would place symbols by a stale map, and no test here could tell —
  // which is exactly why the key lives where the epochs are and the
  // parameter stays dumb.
  //
  // THE TWO MEASUREMENTS ABOVE ARE SKIPPED WITH IT, deliberately:
  // `labelGutterGu` and `labelNodeGapGu` feed nothing but this call's
  // params, and both walk every symbol measuring text.
  final SugiyamaLayout layout;
  if (reuseLayout != null) {
    layout = reuseLayout;
  } else {
    // ── the gutter the LABELS need, before the layout that reserves it ───
    //
    // THE ONE PLACE M2-D REACHES BACK INTO M2-C'S LAYOUT, and it is not an
    // optimisation: `SugiyamaParams.layerGutterGu`'s 12 gu was sized when
    // the channel between two layers held nothing, and under DR-001 it holds
    // the drawing. Two facing pennants run to roughly 28 gu on the shipped
    // figures, so at 12 gu the two flags of every forward link would
    // overprint — see `netLabelGutterGu`, which measures it rather than
    // guessing, and `net_label_layer_test.dart`'s overlap assertion, which
    // is what caught it.
    //
    // MAX, NEVER REPLACE. A caller who widened the gutter deliberately keeps
    // their figure; the labels only ever ask for more.
    final labelGutterGu = netLabelGutterGu(
      doc: doc,
      symbols: [for (final c in drawn) c.geometry],
      measurer: measurer,
      unitsPerGrid: upg,
      style: netLabelStyle,
    );

    // ── and the room the VERTICAL combs need (#96-H) ─────────────────────
    //
    // THE SAME REACH-BACK, ON THE OTHER AXIS, and it closes the half the
    // gutter above deliberately left open. `nodeGapGu`'s 4 gu was sized when
    // the space between two stacked symbols held air; a top/bottom comb grows
    // into it, so a symbol below another was being placed into the room the
    // one above was labelling. That is what the field reported as net labels
    // drawing over devices.
    //
    // IT COULD NOT BE DONE UNTIL THE COMB WAS BOUNDED. `netLabelGutterGu`'s
    // doc carried the objection: an unbounded comb would have made a 48-port
    // switch ask for 48 lanes of clearance and pushed every node gap on the
    // sheet into the hundreds. #96-H caps it at `ceil(widest / pitch)`, so
    // the worst case is a small number and the trade is worth making.
    //
    // MAX, NEVER REPLACE — the same rule as the gutter, for the same reason.
    final labelNodeGapGu = netLabelNodeGapGu(
      doc: doc,
      symbols: [for (final c in drawn) c.geometry],
      measurer: measurer,
      unitsPerGrid: upg,
      style: netLabelStyle,
    );
    layout = layoutSugiyama(
      nodes: [for (final c in drawn) c.node],
      edges: edges,
      params: SugiyamaParams(
        layerGutterGu: math.max(metrics.layout.layerGutterGu, labelGutterGu),
        nodeGapGu: math.max(metrics.layout.nodeGapGu, labelNodeGapGu),
        maxOrderingSweeps: metrics.layout.maxOrderingSweeps,
        priorityIterations: metrics.layout.priorityIterations,
      ),
    );
  }

  // ── the display list ─────────────────────────────────────────────────
  final byId = <String, _Candidate>{for (final c in drawn) c.device.id.v: c};
  final ops = <DiagramOp>[];
  final fragments = <String, IntRange>{};
  final symbols = <RenderedSymbol>[];
  final layers = <List<Uuid>>[];
  var minText = double.infinity;
  DBox? bounds;

  for (final layer in layout.layers) {
    final row = <Uuid>[];
    for (final id in layer) {
      final candidate = byId[id]!;
      final at = layout.positions[id]!;
      final symbol = candidate.geometry.movedTo(
        DPt(at.gx * upg, at.gy * upg),
      );
      final built = buildSymbolLayer(
        symbol,
        palette: palette,
        measurer: measurer,
      );

      final origin = symbol.bodyRect.topLeft;
      ops
        ..add(const OpSave())
        ..add(OpTransform(Matrix4.translationValues(origin.x, origin.y, 0)));
      final localStart = ops.length;
      ops.addAll(built.ops);
      final localEnd = ops.length;
      ops.add(const OpRestore());

      // The fragment is the LOCAL ops only, exactly as `scene_builder`
      // registers a device's: the wrapping translate stays in `scene.ops`
      // for a whole-scene replay (a PDF page, `BoundsCanvas`) but a widget
      // that positions the fragment itself must not re-apply it.
      fragments[id] = IntRange(localStart, localEnd);
      symbols.add(symbol);
      row.add(candidate.device.id);
      minText = math.min(minText, built.minTextPt);
      final ink = built.inkBounds?.shift(origin.x, origin.y);
      final box = ink == null ? symbol.bodyRect : symbol.bodyRect.union(ink);
      bounds = bounds == null ? box : bounds.union(box);
    }
    layers.add(List<Uuid>.unmodifiable(row));
  }

  return SchematicSymbolTier(
    ops: ops,
    fragments: fragments,
    symbols: symbols,
    layers: layers,
    positions: <Uuid, Pt>{
      for (final c in drawn)
        if (layout.positions[c.device.id.v] case final p?) c.device.id: p,
    },
    unsymbolisedDeviceIds: unsymbolised,
    minTextPt: minText,
    bounds: bounds,
    layout: layout,
  );
}

/// Lays out [doc]'s schematic and builds its display list.
///
/// DETERMINISTIC (CR-013 as amended by DR-001). Calling this twice on the
/// same document produces byte-identical ops; so does calling it on a
/// document whose entities were inserted in a different order. Both are
/// asserted in `schematic_scene_test.dart`.
///
/// **NO CACHE LIVES HERE, BUT THERE IS AN INCREMENTAL PATH**, and this doc
/// said otherwise until the full-tree review (`#934`). It was written when
/// "full recompute is perfectly stable and the invalidation bookkeeping
/// costs more than it saves" (docs/03 §5.2) was the whole story. DR-076
/// then measured 96 ms a frame at 3,600 links and added [reuseLayout] and
/// [reuseSymbols]: this function still holds no state, and the CALLER, who
/// owns the epochs, decides what may be carried over. A caller that passes
/// neither gets the full recompute, byte for byte.
///
/// [measurer] is injected per CR-081/AC-016 #13 and does real work — docs/05
/// §3's width formula is a text measurement, and nothing here guesses a
/// width from a character count.
/// [netLabelStyle] tunes the stubs. It has no `enabled` flag and there is
/// no way to ask for a scene without them: DR-001 makes the labels the
/// DEFAULT render of a Link, not an option over one, and a boolean here
/// would be the "Draw all / Auto / Label all" toggle §11.5 deletes — "a
/// global override that fights the filter is a second source of truth for
/// the same question". `drawn` mode arrives as a FILTER SCOPE, not as a
/// flag on this function.
/// [holdAt] freezes the listed devices where a PREVIOUS layout put them —
/// DR-011.4's "creating a link does not re-lay-out the sheet". See its own
/// doc below; a caller that passes nothing gets exactly the behaviour this
/// function has always had.
SchematicScene buildSchematicScene({
  required RackDocument doc,
  required TextMeasurer measurer,
  SchematicPalette palette = const SchematicPalette(),
  SchematicMetrics metrics = const SchematicMetrics(),
  NetLabelStyle netLabelStyle = const NetLabelStyle(),
  Map<Uuid, Pt> holdAt = const <Uuid, Pt>{},
  SugiyamaLayout? reuseLayout,
  SchematicSymbolTier? reuseSymbols,

  /// Per device, the bank keys the user has expanded (`#801`).
  ///
  /// PASSED TO THE TIER, WHICH MEANS IT INVALIDATES THE SYMBOL CACHE. A
  /// `reuseSymbols` built under a different expansion is a stale symbol,
  /// and the caller that reuses one has to rebuild the tier when this
  /// changes. `schematic_canvas_screen.dart` bumps its scene epoch for
  /// exactly this reason.
  Map<Uuid, Set<String>> expandedBanks = const <Uuid, Set<String>>{},

  /// Honour only the stored positions of PINNED symbols, and lay out the
  /// rest (DR-225 §11.224.3).
  ///
  /// THE CANVAS NEVER PASSES THIS. Since DR-187 every symbol a user has
  /// touched carries a stored position, pinned or not, and the canvas lays
  /// out by all of them so the sheet does not move between sessions. An
  /// interconnect sheet draws a SUBSET of the devices, and laying a subset
  /// out by the whole sheet's stored positions prints the screen's
  /// arrangement with every other domain's devices cut out, gaps included;
  /// a pin is the one position the user asked to keep.
  bool pinnedPositionsOnly = false,
}) {
  final upg = kSchematicUnitsPerGrid;
  final tier =
      reuseSymbols ??
      buildSchematicSymbolTier(
        doc: doc,
        measurer: measurer,
        palette: palette,
        metrics: metrics,
        netLabelStyle: netLabelStyle,
        holdAt: holdAt,
        reuseLayout: reuseLayout,
        expandedBanks: expandedBanks,
        pinnedPositionsOnly: pinnedPositionsOnly,
      );
  final layout = tier.layout;
  final symbols = tier.symbols;
  final layers = tier.layers;
  final unsymbolised = tier.unsymbolisedDeviceIds;
  // COPIED, because the labels are appended to both and a tier handed
  // back a second time must be the same tier it was the first time.
  final ops = <DiagramOp>[...tier.ops];
  final fragments = <String, IntRange>{...tier.fragments};
  var minText = tier.minTextPt;
  var bounds = tier.bounds;

  // ── the net labels (DR-001's default render) ─────────────────────────
  //
  // AFTER every symbol, so a pennant is never overpainted by a body it
  // sits beside — the display list is painted in order and there is no
  // z-index in the IR. It also keeps the symbol fragments' ranges exactly
  // where M2-C put them, so a caller holding `fragmentFor(deviceId)` sees
  // no change from this stage.
  final labelLayer = buildNetLabelLayer(
    doc: doc,
    symbols: symbols,
    measurer: measurer,
    palette: palette,
    unitsPerGrid: upg,
    style: netLabelStyle,
  );
  final labelBase = ops.length;
  ops.addAll(labelLayer.ops);

  // A DOMAIN FRAGMENT IS ABSOLUTE, unlike the symbol fragments above: its
  // ops belong to many symbols at once, so there is no local frame they
  // could share and no bracketing translate to exclude. The range is the
  // ops themselves, shifted into scene coordinates by the symbol ops that
  // precede them.
  final domainFragments = <SignalDomainId, IntRange>{};
  for (final entry in labelLayer.domainRanges.entries) {
    final range = IntRange(
      labelBase + entry.value.start,
      labelBase + entry.value.end,
    );
    domainFragments[entry.key] = range;
    fragments[domainFragmentKey(entry.key)] = range;
  }
  final unresolvedRange = labelLayer.unresolvedRange;
  final unresolvedFragment = unresolvedRange == null
      ? null
      : IntRange(
          labelBase + unresolvedRange.start,
          labelBase + unresolvedRange.end,
        );
  if (unresolvedFragment != null) {
    fragments[kUnresolvedDomainFragmentKey] = unresolvedFragment;
  }

  if (labelLayer.inkBounds case final ink?) {
    bounds = bounds == null ? ink : bounds.union(ink);
  }
  minText = math.min(minText, labelLayer.minTextPt);

  final scene = DiagramScene(
    ops: ops,
    bounds: bounds ?? const DBox.fromLtwh(0, 0, 0, 0),
    hits: symbolHitRegions(symbols),
    // `RackTextSizes.type` is the port label, the smallest size
    // `buildSymbolLayer` can emit — the honest floor for an empty sheet.
    minTextSizePt: minText.isFinite ? minText : RackTextSizes.type,
    fragments: fragments,
  );

  return SchematicScene(
    scene: scene,
    symbols: List<RenderedSymbol>.unmodifiable(symbols),
    positions: Map<Uuid, Pt>.unmodifiable(tier.positions),
    layers: List<List<Uuid>>.unmodifiable(layers),
    netLabels: labelLayer.labels,
    domainFragments: Map<SignalDomainId, IntRange>.unmodifiable(
      domainFragments,
    ),
    unresolvedDomainFragment: unresolvedFragment,
    unsymbolisedDeviceIds: List<Uuid>.unmodifiable(unsymbolised),
    unnamedLinkIds: labelLayer.unnamedLinkIds,
    unlabelledLinkIds: labelLayer.unlabelledLinkIds,
    underGlyphedFamilyIds: labelLayer.underGlyphedFamilyIds,
    reversedLinkIds: List<Uuid>.unmodifiable(<Uuid>[
      for (final id in layout.reversedEdgeIds) Uuid(id),
    ]),
    nonForwardLinkIds: List<Uuid>.unmodifiable(<Uuid>[
      for (final id in layout.nonForwardEdgeIds) Uuid(id),
    ]),
    crossings: layout.crossings,
    layout: layout,
    symbolTier: tier,
  );
}

/// One device that will be drawn, with its size resolved.
@immutable
final class _Candidate {
  const _Candidate(this.device, this.geometry, this.node);

  final DeviceInstance device;

  /// Built at the ORIGIN. The absolute symbol is `geometry.movedTo(…)`
  /// once the layout has spoken — the ops are local, so a move is free.
  final RenderedSymbol geometry;

  final LayoutNode node;
}

/// Sizes one symbol and turns it into a [LayoutNode]. The sizing itself is
/// [sizeSymbolForBody]'s; this adds only what a LAYOUT needs and a preview
/// does not (sort key, anchor, pin).
///
/// docs/05 §3's sizing formula, evaluated in INTEGER grid units:
///
///   width  = max(20gu, textWidth(designator + name) + 8gu,
///                maxLeftLabel + maxRightLabel + 12gu), rounded up to 2 gu
///   height = 6gu + (max(leftPins, rightPins) + 1) × 2gu, minimum 16 gu
///
/// `buildSymbolGeometry` applies the pin terms itself in diagram units; the
/// same terms are evaluated here in gu so that the box the layout reserves
/// and the box the symbol draws are the same box. A test asserts they agree
/// rather than trusting that the two transcriptions match.
typedef SizedSymbol = ({RenderedSymbol geometry, int widthGu, int heightGu});

/// docs/05 §3's symbol sizing, for ONE body, with no sheet around it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// PUBLIC BECAUSE THE DEVICE BUILDER DRAWS THE SAME SYMBOL
/// ═══════════════════════════════════════════════════════════════════════
/// This was the first two thirds of [_measureCandidate], which needed a
/// whole `RackDocument` and a `DeviceInstance` to reach it. The builder's
/// symbol preview (`#228`) has neither: it holds a [TemplateBody] that has
/// never been placed and may never be saved.
///
/// The alternative was for the preview to re-derive the width and height
/// itself, and this file already says what that costs — the gu terms here
/// and the diagram-unit terms inside `buildSymbolGeometry` are *"the two
/// transcriptions"* a test exists to keep in agreement. A third
/// transcription in `rackpal_ui`, where no such test could reach it, is
/// exactly the preview-only drawing CR-086 forbids and `#229` was written
/// to prevent.
///
/// So the split is by INPUT, not by behaviour: everything derivable from a
/// body plus a measurer is here, and everything needing the document (sort
/// key, anchor, pinned position) stays with the caller.
SizedSymbol sizeSymbolForBody({
  required String id,
  required String designator,
  required String name,
  required TemplateBody body,
  required TextMeasurer measurer,
  SchematicMetrics metrics = const SchematicMetrics(),
  // ═════════════════════════════════════════════════════════════════════
  // DEFAULTS TO TRUE SINCE `#801`, AND THE SEAM TEST IS WHY
  // ═════════════════════════════════════════════════════════════════════
  // CR-103 collapses banks over eight "on first layout AND in the symbol
  // preview", which is both of this function's callers. It defaulted to
  // `false` while the canvas half was unbuilt, so the sheet path opted in
  // and the preview path opted in and the DEFAULT was a third behaviour
  // neither used.
  //
  // `symbol_sizing_seam_test.dart` reproduces every symbol in the
  // 300-link fixture through this function and compares it to the scene,
  // and it calls it WITHOUT the flag. That test is the guard against the
  // preview and the sheet drifting apart (`#229`, CR-086), so the value
  // it exercises has to be the value the sheet uses. With the default at
  // `false` the seam held only while two call sites remembered to say
  // `true`, which is the arrangement the test exists to forbid.
  //
  // The per-bank opt-out is `BankDef.collapseInSymbol`, which is where
  // CR-103 puts "a bank that must always show every pin". This parameter
  // is now for exercising the uncollapsed path, not for choosing a
  // product behaviour.
  bool collapseBanks = true,

  /// Bank keys this device has had EXPANDED by the user, which collapse
  /// skips (`#801`, CR-103's "may be collapsed by the user at any time").
  Set<String> expandedBanks = const {},
}) {
  final upg = kSchematicUnitsPerGrid;

  // FIXED_ORDER (docs/05 §3): a device's ports are real hardware and the
  // template's declared order is the drawing's order. `buildSymbolGeometry`
  // requires them pre-sorted; the key breaks a duplicated `order`.
  final ports = portsInDeclaredOrder(body.ports);

  // ONE EDGE ASSIGNMENT, SHARED WITH THE BUILDER. This used to re-derive
  // each port's side here and let `buildSymbolGeometry` derive it again;
  // that was survivable while the two loops did the same arithmetic, and
  // stopped being survivable the moment collapse existed. A sizer counting
  // 48 ports while the builder draws one pin reserves 24 pitches of empty
  // edge, and nothing would have reported it.
  final edges = layOutSymbolEdges(
    ports: ports,
    banks: body.banks,
    collapseBanks: collapseBanks,
    expandedBanks: expandedBanks,
  );

  var left = 0;
  var right = 0;
  var top = 0;
  var bottom = 0;
  var widestLeftLabel = 0.0;
  var widestRightLabel = 0.0;
  // The top/bottom edges' widest label is the DEPTH of the strip the body
  // must reserve inside itself, because those labels are turned a quarter
  // turn (#96-A) and now read INWARD (RenderedSymbol.labelBandTop). Their
  // advance width therefore runs down the page, not across it.
  var widestTopLabel = 0.0;
  var widestBottomLabel = 0.0;
  final labelStyle = rackText(
    RackTextSizes.type,
    _measurePalette.portLabel,
    TextAnchor.midLeft,
  );
  for (final side in SymbolSide.values) {
    for (final entry in edges[side]!) {
      // `entry.label`, not `port.label`: a collapsed bank measures the
      // `SFP[1..48]` it actually draws, which is wider than any one of the
      // pin labels it replaced and would otherwise under-reserve the body.
      final width = entry.label.isEmpty
          ? 0.0
          : measurer.measureText(entry.label, labelStyle).advanceWidth;
      switch (side) {
        case SymbolSide.left:
          left++;
          widestLeftLabel = math.max(widestLeftLabel, width);
        case SymbolSide.right:
          right++;
          widestRightLabel = math.max(widestRightLabel, width);
        case SymbolSide.top:
          top++;
          widestTopLabel = math.max(widestTopLabel, width);
        case SymbolSide.bottom:
          bottom++;
          widestBottomLabel = math.max(widestBottomLabel, width);
      }
    }
  }

  final designatorWidth = measurer
      .measureText(
        designator,
        rackText(
          RackTextSizes.designator,
          _measurePalette.designator,
          TextAnchor.topLeft,
        ),
      )
      .advanceWidth;
  final nameWidth = name.isEmpty
      ? 0.0
      : measurer
            .measureText(
              name,
              rackText(
                RackTextSizes.name,
                _measurePalette.name,
                TextAnchor.topRight,
              ),
            )
            .advanceWidth;

  final widthGu = _roundUpToEven(
    math.max(
      metrics.minBodyWidthGu.toDouble(),
      math.max(
        (designatorWidth + nameWidth) / upg + metrics.headerTextPadGu,
        math.max(
          (widestLeftLabel + widestRightLabel) / upg + metrics.sideLabelPadGu,
          // `+ 2`, matching `buildSymbolGeometry`'s
          // `maxEdge + 2 * kPinRunInsetPitches` — a whole clear pitch at
          // each end of the run rather than §3's half. The two
          // transcriptions are asserted to agree; see this function's
          // header.
          ((math.max(top, bottom) + 2) * metrics.pinPitchGu).toDouble(),
        ),
      ),
    ),
  );
  // ONE GAP, ONE RUN, ONE GAP — the leading gap `_labelPoint` leaves before
  // the text, the run itself, and the same gap again so the deepest label
  // does not finish flush against the header band below it. Zero for an
  // edge with no labelled pins, which is most edges.
  double band(double widest) => widest <= 0 ? 0.0 : widest + 2 * kPortLabelGap;
  final bandTop = band(widestTopLabel);
  final bandBottom = band(widestBottomLabel);

  // THE LAYOUT NODE HAS TO KNOW TOO. `heightGu` is what Sugiyama reserves
  // and `buildSymbolGeometry` is what draws; a band added to one and not
  // the other is a symbol overlapping its neighbour by exactly the strip
  // it just reserved. This function's own header says the two
  // transcriptions are asserted to agree.
  final baseHeightGu = math.max(
    metrics.minBodyHeightGu,
    metrics.headerHeightGu + (math.max(left, right) + 1) * metrics.pinPitchGu,
  );
  // CEILED, and the direction matters: `LayoutNode.heightGu` is a whole
  // number of grid units, so the reserved box rounds UP to at least the
  // drawn one. Rounding down would let Sugiyama pack two symbols a
  // fraction of a unit closer than they draw, which is an overlap nothing
  // reports.
  final heightGu = baseHeightGu + ((bandTop + bandBottom) / upg).ceil();

  final geometry = buildSymbolGeometry(
    id: id,
    designator: designator,
    name: name,
    ports: ports,
    banks: body.banks,
    headerHeight: metrics.headerHeightGu * upg,
    portSize: metrics.portSizeGu * upg,
    portPitch: metrics.pinPitchGu * upg,
    minBodyWidth: widthGu * upg,
    // The bands are added by `buildSymbolGeometry` on TOP of this floor —
    // see its own note on why they are not absorbed into it — so the floor
    // handed over here is the header-and-side-pins part alone.
    minBodyHeight: baseHeightGu * upg,
    labelBandTop: bandTop,
    labelBandBottom: bandBottom,
    collapseBanks: collapseBanks,
    expandedBanks: expandedBanks,
  );

  return (geometry: geometry, widthGu: widthGu, heightGu: heightGu);
}

_Candidate _measureCandidate({
  required RackDocument doc,
  required DeviceInstance device,
  required TemplateBody body,
  required TextMeasurer measurer,
  required SchematicMetrics metrics,
  required Pt? pinnedAt,
  required bool isDestination,
  required Set<String> expandedBanks,
}) {
  final sized = sizeSymbolForBody(
    id: device.id.v,
    designator: device.designator,
    name: device.name,
    body: body,
    measurer: measurer,
    metrics: metrics,
    // CR-103's "first layout" IS THIS CALL (`#801`). `collapseBanks` is
    // not passed: `sizeSymbolForBody` defaults to collapsing now, and
    // saying `true` here would restore the arrangement where the seam
    // holds only while two call sites agree. See that parameter's note.
    expandedBanks: expandedBanks,
  );
  return _Candidate(
    device,
    sized.geometry,
    LayoutNode(
      id: device.id.v,
      sortKey: _sortKeyFor(doc, device),
      widthGu: sized.widthGu,
      heightGu: sized.heightGu,
      anchor: _anchorFor(doc, device, isDestination: isDestination),
      pinnedAt: pinnedAt,
    ),
  );
}

/// The palette used ONLY to build a `TextStyleSpec` for measurement.
///
/// A measurement never depends on colour, and threading the caller's
/// palette through the sizing pass would suggest it did. The specs the
/// scene actually draws with are built inside `buildSymbolLayer` from the
/// palette the caller passed.
const _measurePalette = SchematicPalette();

/// docs/05 §3: the width is "rounded up to 2 gu".
int _roundUpToEven(double gu) {
  final ceiling = gu.ceil();
  return ceiling.isEven ? ceiling : ceiling + 1;
}

/// docs/05 §10.1/§10.2: "**Initial order and final tie-break are `ruIndex`,
/// then UUID**", which "makes the schematic read roughly top-to-bottom in
/// rack order, so cross-referencing between the elevation and the Schematic
/// is near-automatic".
///
/// THREE READINGS ARE MADE EXPLICIT HERE rather than left to the next
/// reader:
///
///   * DESCENDING `ruIndex`. A rack's U index counts from the BOTTOM
///     (CR-025) and a sheet reads from the TOP, so "top-to-bottom in rack
///     order" means U42 first. Sorting ascending would put the schematic in
///     exactly the reverse of the elevation, which is the one thing the
///     rule exists to prevent.
///   * RACK FIRST. §10 says "rack order" and a project has several racks,
///     so the rack's own `order` (its LexoRank, the sequence the elevation
///     sheets print in) precedes the U index. Devices in no rack sort after
///     every device in one — they are the off-rack destinations phase 1
///     pushes to the last layer anyway.
///   * A DEVICE WITH NO `ruIndex` — shelf-placed, 0U-channel, staged —
///     sorts at the BOTTOM of its rack rather than being excluded. It has a
///     rack but no rail position, and the bottom is where a shelf occupant
///     reads.
String _sortKeyFor(RackDocument doc, DeviceInstance device) {
  final rackId = hostRackOf(device, doc.devices);
  if (rackId == null) return '1|${device.id.v}';
  final rack = doc.racks[rackId];
  final rackKey = rack == null ? '' : rack.order.v;
  final placement = device.placement;
  final ru = placement is RailPlacement ? placement.ruIndex : 0;
  // Fixed width, so the comparison is numeric in effect as well as
  // lexicographic. `kMaxRackHeightU` is 60 (CR-038); five digits is room to
  // spare and one place the padding is stated.
  final descending = (99999 - ru).toString().padLeft(5, '0');
  return '0|$rackKey|${rackId.v}|$descending|${device.id.v}';
}

/// docs/05 §10.2 phase 1's two forced placements.
///
/// A Structure device goes to layer 0, or to the LAST layer when its body
/// says `sheetEdge == right` (CR-072) — it renders as a bank of off-page
/// flags on that edge, which is what makes it obvious in the PDF which home
/// runs are unused. Off-rack destinations — displays, speakers, keypads —
/// go to the last layer.
///
/// A structure device whose `StructureBody` is missing from the document
/// falls to the LEFT edge, which is `SheetEdge`'s own default (CR-072) and
/// therefore not a guess about the missing body's contents.
///
/// ── "DESTINATION" IS A WORD WITH TEETH ──────────────────────────────────
/// §10.2 forces off-rack DESTINATIONS right, and [isDestination] is what
/// makes that more than a synonym for "off-rack": a wall plate that feeds a
/// projector is off-rack and is not a destination, and pushing it to the
/// last layer would drag every edge it sources backwards across the sheet.
/// So an off-rack device that FEEDS something keeps its graph layer.
///
/// The Structure device's anchor is NOT conditioned that way, and the
/// difference is deliberate: CR-072 is a ruling about one device, not an
/// inference from its links, and a Structure device always feeds something
/// — that is what a home-run field is. Conditioning it on out-degree would
/// mean the rule never fired.
LayerAnchor _anchorFor(
  RackDocument doc,
  DeviceInstance device, {
  required bool isDestination,
}) {
  if (device.kind == DeviceKind.structure) {
    final bodyId = device.structureBodyId;
    final body = bodyId == null ? null : doc.structures[bodyId];
    return body != null && body.sheetEdge == SheetEdge.right
        ? LayerAnchor.last
        : LayerAnchor.first;
  }
  if (device.placement is OffRackPlacement && isDestination) {
    return LayerAnchor.last;
  }
  return LayerAnchor.none;
}

/// The stored symbol positions on the document's schematic sheet.
///
/// ═══════════════════════════════════════════════════════════════════════
/// EVERY STORED POSITION IS READ NOW, PINNED OR NOT (DR-187 §11.186.3)
/// ═══════════════════════════════════════════════════════════════════════
/// This said *"ONLY `pinned` ITEMS ARE READ ... honouring an unpinned one
/// would freeze the first layout the document ever received and make every
/// recompute a no-op"*, and that was right until the user asked for
/// exactly that freeze: a sheet whose symbols stop moving when a device is
/// added. **The freeze is the feature.** What the two states still mean is
/// what `Tidy sheet` does with them: it re-flows an unpinned symbol and
/// clears its stored position, and it never touches a pinned one (CR-068).
///
/// Nothing WRITES an unpinned position until the first edit that would
/// re-flow the sheet (§11.186.2), so a document nobody has edited still has
/// no items and still lays out from scratch.
///
/// The schematic sheet is resolved as the lowest-id `SheetKind.schematic`
/// entry. There is exactly one in practice (CR-073, DR-004, AC-037) and
/// `Sheet` deliberately does not enforce that structurally, so the tie-break
/// is stated rather than left to map order.
/// [storedSymbolPositions] widened by [holdAt] — DR-011.4's freeze,
/// expressed in the mechanism the layout already has.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A HOLD IS NOT A PIN, AND THE DIFFERENCE IS WHERE IT LIVES
/// ═══════════════════════════════════════════════════════════════════════
/// `SheetItem.pinned` is AUTHORED STATE: the user moved a symbol, the
/// document records it, and it survives save/load (CR-068). [holdAt] is a
/// caller's own memory of where this very function put those symbols last
/// time — it is never written anywhere and never leaves the session.
///
/// That distinction was the whole of DR-011.4's argument, and **DR-187
/// §11.186.1 has since overruled its conclusion** (canon §12.38): the
/// positions ARE written to the document now, because a session-only hold
/// loses the arrangement when the project is reopened. The hold remains,
/// and is still never written anywhere: it is what keeps the sheet still
/// between the edit and the write, and what a document with no items at all
/// lays out from.
///
/// THE DOCUMENT WINS ON A CONFLICT. A stored position is a decision the
/// document records; a held position is the last thing that happened to be
/// on screen. Where both name a device, the document governs, which also
/// means a caller cannot accidentally strand a symbol away from the place
/// its own file says it belongs.
Map<Uuid, Pt> _holdOrPin(
  RackDocument doc,
  Map<Uuid, Pt> holdAt, {
  required bool pinnedPositionsOnly,
}) {
  final stored = storedSymbolPositions(doc, pinnedOnly: pinnedPositionsOnly);
  if (holdAt.isEmpty) return stored;
  if (stored.isEmpty) return holdAt;
  return <Uuid, Pt>{...holdAt, ...stored};
}

/// Every position the schematic sheet stores, pinned or not
/// (DR-187 §11.186.3), or only the pinned ones when [pinnedOnly]
/// (DR-225 §11.224.3: an interconnect sheet keeps a lock and nothing else).
///
/// PUBLIC, because the freeze that writes them has to know which symbols
/// already have one: it records the rest and leaves these alone.
Map<Uuid, Pt> storedSymbolPositions(
  RackDocument doc, {
  bool pinnedOnly = false,
}) {
  Sheet? chosen;
  for (final sheet in doc.sheets.values) {
    if (sheet.kind != SheetKind.schematic) continue;
    if (chosen == null || sheet.id.v.compareTo(chosen.id.v) < 0) {
      chosen = sheet;
    }
  }
  if (chosen == null) return const <Uuid, Pt>{};

  final items = chosen.items.values.toList()
    ..sort((a, b) => a.id.v.compareTo(b.id.v));
  final out = <Uuid, Pt>{};
  for (final item in items) {
    if (pinnedOnly && !item.pinned) continue;
    // First item wins if a document somehow carries two for one device: a
    // stated rule beats whichever the map happened to yield.
    out.putIfAbsent(item.targetId, () => item.position);
  }
  return out;
}

/// The directed edge [link] contributes, or `null` when it contributes
/// none.
///
/// ── DIRECTION IS THE MODEL'S, NOT AN INFERENCE ──────────────────────────
/// A `Link`'s direction is its first conductor's `from → to`. CR-014 fixes
/// each conductor at exactly two ends and every conductor of one cable
/// shares the same pair of physical ends, so the first conductor speaks for
/// the link — the same reading `derived/link_class.dart` takes, and for the
/// same reason. `PortDirection` is NOT consulted: it drives the ARROWHEAD
/// in `symbol_layer.dart`, and a graph that re-derived direction from it
/// would be a second answer to a question the model already answers through
/// `Ctrl+Shift+R` (docs/05 §9's `Reverse direction`).
///
/// `null` in three cases, none of them an error:
///   * an end that is not a `PortEndpoint`, or a port this document does not
///     contain — a home run to the field has no device to lay out
///     (AC-018's `PlaceEndpoint`/`OpenEndpoint`);
///   * an end on a device with no symbol (see the file header);
///   * both ends on ONE device — a loop-through is a real cable and says
///     nothing whatever about layering.
LayoutEdge? _edgeFor(
  Link link,
  Map<Uuid, Uuid> deviceOfPort,
  Map<Uuid, PortDef> portDefOfPort,
  Set<String> drawnIds,
) {
  if (link.conductors.isEmpty) return null;
  final conductor = link.conductors.first;
  final from = _portOf(conductor.from);
  final to = _portOf(conductor.to);
  if (from == null || to == null) return null;

  final fromDevice = deviceOfPort[from];
  final toDevice = deviceOfPort[to];
  if (fromDevice == null || toDevice == null) return null;
  if (fromDevice == toDevice) return null;
  if (!drawnIds.contains(fromDevice.v)) return null;
  if (!drawnIds.contains(toDevice.v)) return null;

  // docs/05 §10.2 phase 0's bias: "the real cycles are AVR↔display eARC and
  // matrix loop-throughs, so bias the heuristic to reverse edges whose
  // family declares a return channel". `PortDef.returnChannel` is that
  // declaration and it is the only field in the model that makes one.
  final declaresReturn =
      portDefOfPort[from]?.returnChannel != null ||
      portDefOfPort[to]?.returnChannel != null;

  return LayoutEdge(
    id: link.id.v,
    from: fromDevice.v,
    to: toDevice.v,
    preferReversed: declaresReturn,
  );
}

Uuid? _portOf(Endpoint endpoint) =>
    endpoint is PortEndpoint ? endpoint.portId : null;
