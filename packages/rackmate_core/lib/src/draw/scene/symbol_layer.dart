// rackmate_core/src/draw/scene/symbol_layer.dart — pure Dart.
//
// The schematic device SYMBOL, built as `DiagramOp`s (docs/05-schematic-
// editor.md §3: "It is drawn by `symbol_layer.dart` in `rackmate_core/draw/`
// and replayed by both backends"; CR-071, CR-086). It arrived in this
// package by relocation: the code was written under
// `rackmate_ui/canvas/schematic/symbol.dart`, where it took a
// `FlutterDiagramCanvas` and painted immediate-mode. A symbol that only a
// widget can draw cannot print, which is exactly what CR-086 forbids — so
// it now builds a [LayerBuild] like every other layer under `scene/`
// (rack_layer, device_layer) and `rackmate_export` can drive it without
// ever seeing `rackmate_ui`.
//
// COORDINATES: like device_layer, the fragment is built in the symbol's own
// LOCAL space — body top-left at (0, 0). The symbol's absolute position on
// the sheet lives in [RenderedSymbol.bodyRect] and is applied by whatever
// composes the fragment (a wrapping translate, exactly as scene_builder
// brackets a device fragment). Building it local is also what makes the ops
// position-independent, so moving a symbol never rebuilds them.
//
// ONE PORT-CENTRE FUNCTION, AND WHY THAT MATTERS: [symbolPortCentreLocal]
// (and its absolute sibling [symbolPortCentre]) is the single definition of
// where a pin sits. The pre-relocation code had two — the painter centred
// each port circle ON the body edge while the hit-tester placed it half a
// port OUTSIDE the edge and dropped the along-edge half-pitch — so every
// port's clickable zone was offset from its drawn circle by
// `(size/2, size/2)`. Both callers now derive from this one function.
//
// Sharing a definition is not on its own a proof, because a test that
// compares one caller against the shared function is comparing the function
// to itself — that is how the offset above survived for as long as it did.
// So the guarantee is carried by ONE named test, `symbol_hit_test_test.dart`'s
// "every pin the layer DRAWS is on its body edge, and is hittable exactly
// there": it replays `buildSymbolLayer`'s ops for the drawn circle centres,
// checks each against docs/05 §3's edge rule read off `bodyRect`, and then
// probes `SymbolHitTest.testPoint` at those points. Painter, spec and
// hit-tester, three derivations, one assertion. Nothing else in either suite
// compares the painter with the hit-tester.
//
// SCOPE, stated honestly (cf. rack_layer/device_layer's own scope notes).
// FAITHFUL to docs/05 §3: edge assignment by signal role (inputs left,
// outputs right, control/network top, AC power bottom); header band with a
// hairline rule under it; designator in the header; direction arrows that
// point INTO a sink and AWAY from a source; top/bottom pins distributed
// across the width, centred.
// DEFERRED and NOT drawn — flagged, not silently omitted:
//   * §3's gu-denominated sizing formula (`width = max(20gu, textWidth(…) +
//     8gu, …)`, `height = 6gu + (maxSidePins + 1) × 2gu`, minimum 16 gu).
//     The SHAPE of the height/width formulas is honoured here, but in
//     caller-supplied units, not in `kGridUnit`/`kPinPitch` (units/
//     constants.dart) — converting gu to diagram points needs the sheet's
//     scale anchor, which the schematic scene builder has not been written
//     yet. Nothing here invents a second scale (G4).
//   * Bank collapse (`kBankCollapseThreshold`), vector pins and bracketed
//     `IN[1..8]` labels (CR-103).
//   * Header metadata (`2RU · U14–U15 · REAR`) and the 📌/⚠/👁 badges.
//   * `lodLevel` tiering — the symbol draws one way at every zoom for now.
//   * Connector glyphs (◈/◎/⌂/▭9/⊐) and bus-weight stubs.
// Wires, net labels and the router are M2 and live nowhere in this file.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/bounds_canvas.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/path.dart';
import 'package:rackmate_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackmate_core/src/draw/scene/rack_style.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:vector_math/vector_math_64.dart';

/// Gap (diagram units) between a pin's centre and its label.
const double _kPortLabelGap = 5;

/// Inset (diagram units) of the header's designator from the body edge.
/// Matches `device_layer.dart`'s `_pad` so the two layers' text insets do
/// not visibly disagree.
const double _kHeaderPad = 4;

/// Fraction of a pin's size used for its direction arrowhead.
const double _kArrowScale = 0.3;

// ── the symbol's resolved geometry ───────────────────────────────────────

/// One pin's resolved position on a symbol edge.
///
/// [offset] is the distance ALONG [side]'s edge, measured to the pin's
/// CENTRE: from the bottom of the header band for [SymbolSide.left] /
/// [SymbolSide.right], and from the body's left edge for [SymbolSide.top] /
/// [SymbolSide.bottom]. There is exactly one reading of it — see
/// [symbolPortCentreLocal].
@immutable
final class SymbolPort {
  const SymbolPort({
    required this.key,
    required this.label,
    required this.side,
    required this.offset,
    required this.size,
    required this.direction,
    required this.family,
    this.bankKey,
  });

  /// `PortDef.key.v` — the stable author-assigned join (CR-051), never a
  /// UUID.
  final String key;

  /// `PortDef.label` — what is actually drawn beside the pin. The
  /// pre-relocation code drew `'P${port.id}'` instead, which is where the
  /// screen's `Pin1`/`Pout1` boxes came from.
  final String label;

  final SymbolSide side;
  final double offset;
  final double size;
  final PortDirection direction;
  final SignalFamilyId family;

  /// `PortDef.bankKey` — the PRESENTATION grouping this pin belongs to
  /// (CR-055), or null when it belongs to none.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// PUBLISHED BECAUSE A GESTURE NEEDS IT, NOT BECAUSE THE PAINTER DOES
  /// ═══════════════════════════════════════════════════════════════════
  /// Nothing here draws a bank. Bank COLLAPSE — the vector pin with a
  /// bracketed `IN[1..8]` label — is on this file's own deferral list and
  /// on `schematic_scene.dart`'s, and it stays there. The one thing
  /// `bankKey` was used for was choosing a pin's EDGE
  /// ([symbolSideForPort]), and that consumed the bank without ever
  /// letting a caller see it.
  ///
  /// docs/05:484's multi-draw is "with N ports selected in ONE BANK,
  /// dragging to a target bank" — so a surface that cannot ask which bank
  /// a pin is in cannot offer the gesture at all. 257 of the catalog's
  /// ports declare a bank, so the data is there; only the answer was
  /// missing.
  final String? bankKey;

  @override
  bool operator ==(Object other) =>
      other is SymbolPort &&
      other.key == key &&
      other.label == label &&
      other.side == side &&
      other.offset == offset &&
      other.size == size &&
      other.direction == direction &&
      other.family == family &&
      other.bankKey == bankKey;

  @override
  int get hashCode =>
      Object.hash(key, label, side, offset, size, direction, family, bankKey);

  @override
  String toString() =>
      'SymbolPort($key, ${side.name}, offset: $offset, ${direction.name})';
}

/// A symbol whose geometry has been resolved: where its body sits on the
/// sheet, how tall its header band is, and which pins landed on which edge.
///
/// [bodyRect] is ABSOLUTE (sheet coordinates). The ops built from it by
/// [buildSymbolLayer] are LOCAL — see the file header.
@immutable
final class RenderedSymbol {
  const RenderedSymbol({
    required this.id,
    required this.designator,
    required this.name,
    required this.bodyRect,
    required this.headerHeight,
    required this.ports,
  });

  /// The owning entity's id (a device `Uuid.v` in practice), used as the
  /// scene fragment key and reported by `SymbolHitTest` point queries.
  final String id;

  /// `DeviceInstance.designator` — "MTX-1". Stored at allocation and never
  /// recomputed (CR-041/CR-048).
  final String designator;

  /// Free-text instance name; may be empty.
  final String name;

  /// Absolute body rect on the sheet.
  final DBox bodyRect;

  /// Height of the header band, measured down from [bodyRect]'s top edge.
  final double headerHeight;

  /// Pins grouped by the edge they landed on. Every [SymbolSide] key is
  /// present (possibly with an empty list) so callers never null-check.
  ///
  /// UNMODIFIABLE, and that is load-bearing rather than tidy. [movedTo]
  /// hands the SAME map to the copy — the pins are expressed in local
  /// space and a move cannot change them, so copying would be waste — which
  /// means a growable list here would let `moved.ports[left]!.removeLast()`
  /// silently mutate the original AND every `SymbolHitTest` already built
  /// over it (it holds a bare `List<RenderedSymbol>`). That is the
  /// painter/hit-tester desync this file's header says the pairing exists
  /// to close, re-entering through aliasing.
  /// [buildSymbolGeometry] freezes both the map and its lists; a caller
  /// constructing a [RenderedSymbol] directly is expected to do the same.
  final Map<SymbolSide, List<SymbolPort>> ports;

  /// Every pin, in edge order (left, right, top, bottom) then within-edge
  /// order — a deterministic flat walk for hit-testing and tests.
  Iterable<SymbolPort> get allPorts sync* {
    for (final side in SymbolSide.values) {
      yield* ports[side] ?? const <SymbolPort>[];
    }
  }

  /// The same symbol with its body's TOP-LEFT moved to [topLeft], keeping
  /// its size, header and pins.
  ///
  /// Moving is a whole-value replacement rather than a mutable `bodyRect`
  /// because everything else about the symbol — every pin offset, every
  /// built op — is expressed in LOCAL space and is therefore unchanged by
  /// a move. A settable rect invites a caller to move the body while some
  /// other cache still holds the old absolute pin positions, which is the
  /// class of desync this file exists to close.
  RenderedSymbol movedTo(DPt topLeft) => RenderedSymbol(
    id: id,
    designator: designator,
    name: name,
    bodyRect: DBox.fromLtwh(
      topLeft.x,
      topLeft.y,
      bodyRect.width,
      bodyRect.height,
    ),
    headerHeight: headerHeight,
    ports: ports,
  );

  /// Value equality, like every other type in this pair ([SymbolPort],
  /// [SchematicPalette], `SymbolHitTestParams`, `SymbolHitResult`). Without
  /// it `s.movedTo(const DPt(0, 0)) == s` is false with every field equal,
  /// and any cache keyed on a symbol never hits.
  @override
  bool operator ==(Object other) =>
      other is RenderedSymbol &&
      other.id == id &&
      other.designator == designator &&
      other.name == name &&
      other.bodyRect == bodyRect &&
      other.headerHeight == headerHeight &&
      _portsEquality.equals(other.ports, ports);

  @override
  int get hashCode => Object.hash(
    id,
    designator,
    name,
    bodyRect,
    headerHeight,
    _portsEquality.hash(ports),
  );

  @override
  String toString() =>
      'RenderedSymbol($id, $designator, $bodyRect, '
      '${allPorts.length} ports)';
}

/// Deep equality for [RenderedSymbol.ports] — the map's lists must compare
/// by content, not by identity, or `==` would be identity again in disguise.
const _portsEquality = MapEquality<SymbolSide, List<SymbolPort>>(
  values: ListEquality<SymbolPort>(),
);

/// Packed-ARGB colours for one symbol rendering. Same convention as
/// [RackPalette]: never a Flutter `Color`, so `rackmate_ui` can hand in a
/// theme-derived palette while all geometry stays here.
@immutable
final class SchematicPalette {
  const SchematicPalette({
    this.headerFill = 0xFFE8E8E8,
    this.headerRule = 0xFF9CA3AF,
    this.bodyFill = 0xFFFFFFFF,
    this.bodyStroke = 0xFF334155,
    this.portStroke = 0xFF334155,
    this.portFill = 0xFFFFFFFF,
    this.designator = 0xFF0F172A,
    this.name = 0xFF334155,
    this.portLabel = 0xFF475569,
    this.netLabelText = 0xFF0F172A,
  });

  /// Header band background. The pre-relocation code declared this and then
  /// filled the header with the BODY colour, so the band was invisible.
  final int headerFill;

  /// The hairline rule under the header band (docs/05 §3's ASCII figure).
  final int headerRule;

  final int bodyFill;
  final int bodyStroke;
  final int portStroke;
  final int portFill;
  final int designator;
  final int name;
  final int portLabel;

  /// The NET NAME inside a net-label pennant (`net_label_layer.dart`).
  ///
  /// INK, NOT THE DOMAIN HUE, and that is the point of it being a palette
  /// entry rather than a colour the label layer derives. Under DR-001 the
  /// net name is the primary visual identity of a connection (canon
  /// §11.1.5), it is what the reader is actually reading, and hue is
  /// already carried by the leader, the pennant outline, the pennant fill
  /// and the family token. Tinting the name as well would push the one run
  /// that has to be legible off maximum contrast — `pwr` would print it at
  /// `#000000` on white and `net` at `#009E73`, i.e. the same string
  /// legible to different degrees depending on which domain it belongs to.
  final int netLabelText;

  @override
  bool operator ==(Object other) =>
      other is SchematicPalette &&
      other.headerFill == headerFill &&
      other.headerRule == headerRule &&
      other.bodyFill == bodyFill &&
      other.bodyStroke == bodyStroke &&
      other.portStroke == portStroke &&
      other.portFill == portFill &&
      other.designator == designator &&
      other.name == name &&
      other.portLabel == portLabel &&
      other.netLabelText == netLabelText;

  @override
  int get hashCode => Object.hashAll([
    headerFill,
    headerRule,
    bodyFill,
    bodyStroke,
    portStroke,
    portFill,
    designator,
    name,
    portLabel,
    netLabelText,
  ]);
}

// ── edge assignment (docs/05 §3) ─────────────────────────────────────────

/// The [BankDef.symbolSide] value that means "the author did not choose" —
/// i.e. the field's own constructor default (template.dart:569). Named here
/// so the one place that reads it says WHY it is comparing against `left`
/// rather than leaving a bare literal for the next reader to misread as a
/// preference for the input edge. See [symbolSideForPort].
const SymbolSide kUndeclaredSymbolSide = SymbolSide.left;

/// The edge [port] belongs on.
///
/// PRECEDENCE, highest first:
///  1. [bank]'s author-declared [BankDef.symbolSide], when it says
///     something (see below). `BankDef` is the PRESENTATION grouping
///     (template.dart: "Drives symbol edges, brackets, collapse", CR-055):
///     an author who put a bank on the right edge has made a decision, and
///     a rule that derives the edge from the signal family alone silently
///     throws that decision away — the value survives the seed catalog, the
///     codec round-trip and the Device Builder, and then never reaches the
///     drawing.
///  2. Otherwise docs/05 §3: **"Inputs left, outputs right, control and
///     network top, AC power bottom."**
///
/// WHAT "SAYS SOMETHING" MEANS, and why it is not a guess.
/// [BankDef.symbolSide] is non-nullable and defaults to [SymbolSide.left]
/// (template.dart:569), so the model cannot distinguish "the author chose
/// left" from "nobody chose anything" — the seed catalog leaves it at the
/// default on every bank it does not care about, and every catalog output
/// bank is one of those. Treating the default as a decision would put every
/// device OUTPUT on the input edge, which contradicts §3. So a bank whose
/// side is still the default falls through to the family rule, and any
/// other value is honoured. That is a reading of an ambiguous model, stated
/// here rather than hidden: making the field nullable is the real fix and
/// belongs with a model + codec change, not in the drawing layer (G4 — this
/// file does not invent facts the model cannot express).
///
/// Signal ROLE wins over direction, because that is the whole point of the
/// rule — control routes to a gutter above the signal plane, and power
/// falls to the PDU below it, so neither ever crosses an A/V wire. Role is
/// read from the dotted `SignalFamilyId` namespace the seed catalog
/// authors (`audio.` / `ctl.` / `net.` / `power.` / `rf.` / `video.`,
/// catalog/catalog_*.dart).
///
/// TWO READINGS MADE EXPLICIT rather than left to the next reader:
///   * §3 says "AC power bottom". The whole `power.` namespace goes bottom
///     here, including `power.dc_low` and `power.bonding` — they are power,
///     not signal, and the rule's stated purpose is a single clean power
///     comb at the bottom.
///   * §3 says "Bidirectional ports sit on the side matching their dominant
///     direction". No `PortDef` field expresses dominant direction, and
///     inventing one would be a fabricated fact (G4). So
///     [PortDirection.bidirectional], [PortDirection.busNode] and
///     [PortDirection.passive] fall deterministically to the INPUT edge,
///     which is also `BankDef.symbolSide`'s own default.
///
/// The pre-relocation code had this exactly backwards — sources left, sinks
/// right — and dumped every non-directional port on TOP regardless of
/// family, so control, power and passive A/V all shared the control gutter.
SymbolSide symbolSideForPort(PortDef port, {BankDef? bank}) {
  if (bank != null && bank.symbolSide != kUndeclaredSymbolSide) {
    return bank.symbolSide;
  }
  final family = port.signalFamily.v;
  if (_inNamespace(family, 'power')) return SymbolSide.bottom;
  if (_inNamespace(family, 'ctl') || _inNamespace(family, 'net')) {
    return SymbolSide.top;
  }
  return switch (port.direction) {
    // A device INPUT is a sink: signal flows into it.
    PortDirection.sink => SymbolSide.left,
    // A device OUTPUT is a source.
    PortDirection.source => SymbolSide.right,
    PortDirection.bidirectional ||
    PortDirection.busNode ||
    PortDirection.passive => SymbolSide.left,
  };
}

bool _inNamespace(String family, String ns) =>
    family == ns || family.startsWith('$ns.');

// ── geometry ─────────────────────────────────────────────────────────────

/// Resolves [ports] onto the four edges and sizes the body, returning the
/// symbol placed with its top-left at [origin].
///
/// [minBodyWidth] / [minBodyHeight] are floors, not the final size: the
/// body grows to fit whichever edge carries the most pins, mirroring the
/// SHAPE of docs/05 §3's formulas
/// (`height = header + (max(leftPins, rightPins) + 1) × pitch`, and the
/// same for width across the top/bottom edges) in caller-supplied units —
/// see the file header on why gu is not converted here.
///
/// Pin ORDER within a side is the iteration order of [ports], which the
/// caller must supply already sorted by `PortDef.order`: §3's `FIXED_ORDER`
/// ruling — "a device's ports are real hardware and you cannot reorder the
/// XLR jacks on an amp to make a drawing prettier".
///
/// [banks] is the owning `TemplateBody.banks` list. Pass it: without it
/// every `PortDef.bankKey` on the template resolves to nothing and each
/// author-declared [BankDef.symbolSide] is silently discarded (see
/// [symbolSideForPort]). It defaults to empty only so a caller with a bare
/// port list — a test fixture, a template fragment — can still build a
/// symbol; that path falls back to the family rule for every pin. Duplicate
/// bank keys resolve to the FIRST entry, matching `PortBuilder`'s own "first
/// use wins" rule for bank creation.
RenderedSymbol buildSymbolGeometry({
  required String id,
  required String designator,
  required Iterable<PortDef> ports,
  required double headerHeight,
  required double portSize,
  required double portPitch,
  String name = '',
  Iterable<BankDef> banks = const [],
  double minBodyWidth = 0,
  double minBodyHeight = 0,
  DPt origin = const DPt(0, 0),
}) {
  final byKey = <String, BankDef>{};
  for (final bank in banks) {
    byKey.putIfAbsent(bank.key, () => bank);
  }

  final bySide = <SymbolSide, List<PortDef>>{
    for (final side in SymbolSide.values) side: <PortDef>[],
  };
  for (final port in ports) {
    final key = port.bankKey;
    bySide[symbolSideForPort(port, bank: key == null ? null : byKey[key])]!.add(
      port,
    );
  }

  final nLeft = bySide[SymbolSide.left]!.length;
  final nRight = bySide[SymbolSide.right]!.length;
  final nTop = bySide[SymbolSide.top]!.length;
  final nBottom = bySide[SymbolSide.bottom]!.length;

  final maxSide = math.max(nLeft, nRight);
  final maxEdge = math.max(nTop, nBottom);

  final height = math.max(
    minBodyHeight,
    headerHeight + (maxSide + 1) * portPitch,
  );
  final width = math.max(minBodyWidth, (maxEdge + 1) * portPitch);

  final resolved = <SymbolSide, List<SymbolPort>>{
    for (final side in SymbolSide.values) side: <SymbolPort>[],
  };
  for (final side in SymbolSide.values) {
    final defs = bySide[side]!;
    // Left/right pins hang below the header, one per pitch slot, centred in
    // their slot. Top/bottom pins distribute across the body width and are
    // centred as a group (§3: "Top and bottom pins distribute across the
    // width at 2 gu pitch, centred").
    final start = (side == SymbolSide.top || side == SymbolSide.bottom)
        ? (width - defs.length * portPitch) / 2
        : 0.0;
    for (var i = 0; i < defs.length; i++) {
      final def = defs[i];
      resolved[side]!.add(
        SymbolPort(
          key: def.key.v,
          label: def.label,
          side: side,
          offset: start + (i + 0.5) * portPitch,
          size: portSize,
          direction: def.direction,
          family: def.signalFamily,
          bankKey: def.bankKey,
        ),
      );
    }
  }

  return RenderedSymbol(
    id: id,
    designator: designator,
    name: name,
    bodyRect: DBox.fromLtwh(origin.x, origin.y, width, height),
    headerHeight: headerHeight,
    // Frozen, map and lists both — see [RenderedSymbol.ports] on why an
    // aliased growable list would re-open the painter/hit-tester desync.
    ports: Map<SymbolSide, List<SymbolPort>>.unmodifiable({
      for (final side in SymbolSide.values)
        side: List<SymbolPort>.unmodifiable(resolved[side]!),
    }),
  );
}

/// [port]'s centre in [symbol]'s LOCAL space (body top-left at the origin).
/// THE definition — see the file header.
DPt symbolPortCentreLocal(RenderedSymbol symbol, SymbolPort port) {
  final w = symbol.bodyRect.width;
  final h = symbol.bodyRect.height;
  return switch (port.side) {
    SymbolSide.left => DPt(0, symbol.headerHeight + port.offset),
    SymbolSide.right => DPt(w, symbol.headerHeight + port.offset),
    SymbolSide.top => DPt(port.offset, 0),
    SymbolSide.bottom => DPt(port.offset, h),
  };
}

/// [port]'s centre in ABSOLUTE sheet space — [symbolPortCentreLocal]
/// translated by [RenderedSymbol.bodyRect]'s top-left. What hit-testing
/// queries against, and what a composed scene's translate reproduces.
DPt symbolPortCentre(RenderedSymbol symbol, SymbolPort port) {
  final local = symbolPortCentreLocal(symbol, port);
  return DPt(local.x + symbol.bodyRect.left, local.y + symbol.bodyRect.top);
}

// ── the layer ────────────────────────────────────────────────────────────

/// Builds [symbol]'s LOCAL-coordinate fragment: header band, hairline rule,
/// body outline, designator, optional instance name, then every pin
/// (circle, direction arrowhead, label).
///
/// [measurer] is injected per CR-081/AC-016 #13 and does real work: the
/// instance name is drawn only if it MEASURES narrow enough to sit beside
/// the designator in the header, the same "only if it fits" discipline
/// `device_layer` applies at `LodLevel.block`. Nothing here guesses a text
/// width from a character count.
LayerBuild buildSymbolLayer(
  RenderedSymbol symbol, {
  required SchematicPalette palette,
  required TextMeasurer measurer,
}) {
  final ops = <DiagramOp>[];
  final sizes = <double>[];

  final width = symbol.bodyRect.width;
  final height = symbol.bodyRect.height;
  final body = DBox.fromLtwh(0, 0, width, height);
  final header = DBox.fromLtwh(0, 0, width, symbol.headerHeight);

  // Body fill first, then the header band over it, so the band reads as
  // part of one rectangle rather than a floating strip.
  ops
    ..add(OpRect(body, fill: Fill(palette.bodyFill)))
    ..add(OpRect(header, fill: Fill(palette.headerFill)))
    // Hairline rule under the header (§3's figure). Square corners
    // throughout: §3 fixes the body corner radius at 0 because "rounded
    // reads as flowchart".
    //
    // ── BOTH CR-082 KNOBS, STATED, BECAUSE THIS IS THE ONE PLACE THEY
    //    DISAGREE ──────────────────────────────────────────────────────
    // This was `Stroke(..., hairlineFloor: true)` with `scaleWithGeometry`
    // left at its `true` default, written when the two backends branched
    // on `hairlineFloor` ALONE and it therefore meant BOTH "use the
    // 0.25 pt print floor" AND "keep the width constant on the device".
    // Splitting the two (`_applyStroke`/`_strokePaint`) silently changed
    // what this line means, and it is the only production `Stroke` in the
    // repository where the flags disagree, so it was the only one that
    // moved.
    //
    // The split behaviour is the CORRECT one and it is now explicit.
    // CR-082: "Cable traces, SYMBOL OUTLINES and rack rails scale; UI
    // chrome, selection halos and hit slop are constant in screen pixels."
    // This rule is drawn in the symbol's LOCAL coordinates, one op away
    // from the body outline that has always scaled — a header rule that
    // stayed 1 device-pixel while the box around it grew with zoom would
    // read as a different weight at every zoom level, and would print
    // differently again inside a scaled sheet bracket. So it SCALES.
    // `hairlineFloor: true` is kept for what it now means alone: a rule
    // may legitimately print finer than the 0.5 pt signal floor.
    ..add(
      OpLine(
        DPt(0, symbol.headerHeight),
        DPt(width, symbol.headerHeight),
        Stroke(
          argb: palette.headerRule,
          widthPt: 1,
          hairlineFloor: true,
          // The default, spelled out on purpose: this is the one site
          // where the two knobs disagree, and "it inherited the default"
          // is what let the rewrite change this line's meaning without
          // anyone noticing. `draw_source_gate_test.dart` requires it.
          // ignore: avoid_redundant_argument_values
          scaleWithGeometry: true,
        ),
      ),
    )
    ..add(OpRect(body, stroke: Stroke(argb: palette.bodyStroke, widthPt: 1)));

  // ── header text ──────────────────────────────────────────────────────
  final designatorStyle = rackText(
    RackTextSizes.designator,
    palette.designator,
    TextAnchor.topLeft,
  );
  ops.add(
    OpText(
      symbol.designator,
      const DPt(_kHeaderPad, _kHeaderPad),
      designatorStyle,
    ),
  );
  sizes.add(RackTextSizes.designator);

  if (symbol.name.isNotEmpty) {
    final nameStyle = rackText(
      RackTextSizes.name,
      palette.name,
      TextAnchor.topRight,
    );
    final designatorWidth = measurer
        .measureText(symbol.designator, designatorStyle)
        .advanceWidth;
    final nameWidth = measurer.measureText(symbol.name, nameStyle).advanceWidth;
    // Right-aligned in the header, but only when it clears the designator
    // with a pad's gap. Otherwise it is dropped rather than overprinted.
    if (designatorWidth + _kHeaderPad + nameWidth <= width - 2 * _kHeaderPad) {
      ops.add(
        OpText(symbol.name, DPt(width - _kHeaderPad, _kHeaderPad), nameStyle),
      );
      sizes.add(RackTextSizes.name);
    }
  }

  // ── pins ─────────────────────────────────────────────────────────────
  for (final port in symbol.allPorts) {
    final centre = symbolPortCentreLocal(symbol, port);

    ops.add(
      OpCircle(
        centre,
        port.size / 2,
        fill: Fill(palette.portFill),
        stroke: Stroke(argb: palette.portStroke, widthPt: 1),
      ),
    );

    // Direction arrowhead — INTO the body for a sink, AWAY for a source
    // (§3's KEY: "► direction arrow on the stub — into body = sink, away =
    // source"). Drawn ONLY when the direction actually says which way the
    // signal runs: bidirectional/busNode/passive get no arrow rather than
    // an invented one.
    final angle = _arrowAngle(port);
    if (angle != null) {
      final t = port.size * _kArrowScale;
      ops
        ..add(const OpSave())
        ..add(
          OpTransform(
            Matrix4.translationValues(centre.x, centre.y, 0)..rotateZ(angle),
          ),
        )
        ..add(
          OpPath(
            DiagramPath([
              MoveTo(-t / 2, -t / 2),
              LineTo(t / 2, 0),
              LineTo(-t / 2, t / 2),
              const ClosePath(),
            ]),
            fill: Fill(palette.portStroke),
          ),
        )
        ..add(const OpRestore());
    }

    if (port.label.isNotEmpty) {
      ops.add(
        OpText(
          port.label,
          _labelPoint(centre, port.side),
          rackText(
            RackTextSizes.type,
            palette.portLabel,
            _labelAnchor(port.side),
            rotationRad: _labelRotation(port.side),
          ),
        ),
      );
      sizes.add(RackTextSizes.type);
    }
  }

  // INK BOUNDS, and why this layer in particular must report them: unlike
  // `device_layer`, a symbol deliberately draws OUTSIDE the rect it was
  // sized to. Every pin circle is centred ON the body edge, so it hangs
  // `port.size / 2` past it on all four sides, and top/bottom port labels
  // sit `_kPortLabelGap` plus a whole TEXT RUN beyond that. A composer that
  // unioned `bodyRect` alone would compute a page box several units too
  // small on each side and scale-to-fit would then clip half of every
  // outermost pin and the whole of the top/bottom labels. Measured from the
  // ops actually emitted (`BoundsCanvas`), so it cannot drift out of step
  // with what is drawn.
  //
  // A TEXT RUN, WHERE IT USED TO SAY AN ASCENT, and the change is #96-A
  // rather than a correction: before the quarter turn a top/bottom label
  // reached one ASCENT past the gap, and now it reaches its full ADVANCE
  // WIDTH — "AUD OUT 12" instead of about eight units. This sentence is the
  // only place that figure is described, but it is not the place it is
  // COMPUTED: `inkBoundsOf` measures the rotated hull through
  // `BoundsCanvas`, which multiplies the run's box by the same rotation the
  // backends apply. So the symbol grew a lot taller and nothing here had to
  // learn by how much.
  return (
    ops: ops,
    minTextPt: sizes.isEmpty ? double.infinity : sizes.reduce(math.min),
    inkBounds: inkBoundsOf(ops, measurer: measurer),
  );
}

/// Rotation (radians, positive = clockwise per `DiagramCanvas.rotate`) for
/// [port]'s arrowhead, whose untransformed apex points along +x — or `null`
/// when the port declares no flow direction.
double? _arrowAngle(SymbolPort port) {
  // Angle that makes the apex point INTO the body from [port]'s edge.
  final into = switch (port.side) {
    SymbolSide.left => 0.0, // +x
    SymbolSide.right => math.pi, // -x
    SymbolSide.top => math.pi / 2, // +y (down)
    SymbolSide.bottom => -math.pi / 2, // -y (up)
  };
  return switch (port.direction) {
    PortDirection.sink => into,
    PortDirection.source => into + math.pi,
    PortDirection.bidirectional ||
    PortDirection.busNode ||
    PortDirection.passive => null,
  };
}

/// Where [side]'s pin label sits relative to the pin centre.
///
/// Side labels go INSIDE the body and top/bottom labels OUTSIDE it, which
/// is what docs/05 §3's worked 16-port figure draws: `J01  IN 1 ‹ATV-1›`
/// reads inside the left wall while `J17`/`J18` sit above the top edge and
/// `J20  IEC C14` below the bottom one. The pre-relocation code put the
/// side labels outside, i.e. in the gutter the router needs for wires.
DPt _labelPoint(DPt centre, SymbolSide side) => switch (side) {
  SymbolSide.left => DPt(centre.x + _kPortLabelGap, centre.y),
  SymbolSide.right => DPt(centre.x - _kPortLabelGap, centre.y),
  SymbolSide.top => DPt(centre.x, centre.y - _kPortLabelGap),
  SymbolSide.bottom => DPt(centre.x, centre.y + _kPortLabelGap),
};

/// How far [side]'s pin label is turned — #96-A.
///
/// ═══════════════════════════════════════════════════════════════════════
/// TOP AND BOTTOM LABELS RAN INTO EACH OTHER, AND THE GEOMETRY SAYS WHY
/// ═══════════════════════════════════════════════════════════════════════
/// Pins on the top and bottom edges are spaced along X, one `portPitch`
/// apart ([buildSymbolGeometry]: `start + (i + 0.5) * portPitch`). Their
/// labels ran along X too, so any label WIDER THAN ONE PITCH overlapped its
/// neighbour — and "AUD OUT 12" at `RackTextSizes.type` is several pitches
/// wide. The left and right edges were never affected, and not by luck:
/// there the pins are spaced along Y while the text runs along X, so the
/// two axes are perpendicular and the labels cannot collide however long
/// they get.
///
/// Turning the top/bottom labels a quarter turn restores exactly that
/// perpendicularity. It is the fix the user proposed on finding the defect,
/// and it is the same fix the geometry implies.
///
/// ═══════════════════════════════════════════════════════════════════════
/// BOTH EDGES TURN THE SAME WAY, WHICH IS NOT THE SAME AS SYMMETRICALLY
/// ═══════════════════════════════════════════════════════════════════════
/// Both get `-pi / 2`, so both READ BOTTOM-TO-TOP — the drafting convention
/// for vertical lettering, and the reason a reader tilts their head once for
/// a sheet rather than once per edge. Mirroring the bottom edge to `+pi / 2`
/// would make its labels read top-to-bottom and put two reading directions
/// on one symbol.
///
/// The two edges still differ, but in the ANCHOR rather than the angle: see
/// [_labelAnchor], where `midLeft` and `midRight` are what send each edge's
/// text AWAY from the body while both keep the one reading direction.
///
/// `-pi / 2` and not `+pi / 2`: positive is clockwise in a Y-down frame, so
/// the negative quarter turn is the one that climbs. `text_rotation_test
/// .dart` pins that on `BoundsCanvas` and `pdf_text_rotation_test.dart` on
/// paper, both in the commit before this one.
double _labelRotation(SymbolSide side) => switch (side) {
  SymbolSide.left || SymbolSide.right => 0,
  SymbolSide.top || SymbolSide.bottom => -math.pi / 2,
};

/// Which end of the run sits at [_labelPoint].
///
/// LEFT AND RIGHT are unchanged: the label reads INTO the body from its pin,
/// so a left-edge pin anchors the run's left end and a right-edge pin its
/// right end.
///
/// TOP AND BOTTOM read in the rotated frame, where the run advances UP the
/// page (see [_labelRotation]). A top-edge label must extend further up,
/// away from the body below it, so the anchor is the run's START —
/// `midLeft`. A bottom-edge label must extend further DOWN, so with the same
/// upward reading direction the anchor has to be the run's END —
/// `midRight`. One angle, two anchors, and both labels point away from the
/// symbol.
TextAnchor _labelAnchor(SymbolSide side) => switch (side) {
  SymbolSide.left => TextAnchor.midLeft,
  SymbolSide.right => TextAnchor.midRight,
  SymbolSide.top => TextAnchor.midLeft,
  SymbolSide.bottom => TextAnchor.midRight,
};
