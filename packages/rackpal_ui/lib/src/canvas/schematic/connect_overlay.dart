// rackpal_ui/src/canvas/schematic/connect_overlay.dart
//
// WHAT A CONNECT GESTURE LOOKS LIKE WHILE IT IS STILL A GESTURE: the pin
// under the caret, the pin a wire is armed from, and the band between them.
//
// ═════════════════════════════════════════════════════════════════════
// THIS LIVES IN `rackpal_ui` ON PURPOSE, UNLIKE ITS NEIGHBOUR
// ═════════════════════════════════════════════════════════════════════
// `wire_trace.dart` sits in this package and should not — the OKF bundle
// records it as a layering violation in waiting, because `rackpal_export`
// may never import `rackpal_ui` and therefore cannot draw a wire, which
// makes M6's interconnect sheets unbuildable until it moves.
//
// This file is the opposite case and the distinction is worth stating so
// the next reader does not "fix" it by relocating both. A caret ring and a
// rubber band are LIVE GESTURE CHROME: they exist between a keypress and a
// commit, they are never in a document, and there is no sheet on which they
// could be printed. `Stroke.scaleWithGeometry: false` says the same thing
// in the type system — this ink is measured in screen pixels, which is
// meaningless to a PDF backend.
//
// ═════════════════════════════════════════════════════════════════════
// THE BAND IS THE REAL TRACE, NOT A LINE BETWEEN TWO POINTS
// ═════════════════════════════════════════════════════════════════════
// docs/05 §7.5: the rubber band renders "as a live two-bend orthogonal
// staple — preview what you will get, not a straight line". So it is built
// by calling [orthogonalTrace] — the same function `buildDrawnWireLayer`
// routes a committed link with — rather than by a second bit of geometry
// that would agree with it only by inspection. A preview that took a
// different path from the wire it previews is the desync
// `symbol_layer.dart`'s header describes between a painter and a
// hit-tester, one layer up.
//
// WHAT IT HONESTLY CANNOT PROMISE, and the code should not pretend
// otherwise: under DR-001 the DEFAULT render of a committed link is a pair
// of net labels, not a drawn wire (canon §11.1.1). So the band previews the
// PATH the cable takes, which is what the user is choosing, and not the
// marks that will appear on an unfiltered sheet. Both are true at once and
// only the first is a gesture affordance.
//
// NO COMB INDEX. `buildDrawnWireLayer` escapes the i-th pin on a side i
// steps further out so that N links off one symbol do not overprint; a
// preview is exactly one band and has nothing to overprint against, so it
// takes the base escape. That is a statement about there being one of it,
// not a simplification of the trace.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/schematic/wire_trace.dart';

/// One pin on the sheet, named the way a document names it.
///
/// NOT A `Uuid`, and not a `Port` id. The caret exists over pins the
/// document has never materialised — AC-006 makes that the normal state of
/// a device dropped from the palette, and DR-011.1 is the ruling that ports
/// appear inside the connect command's `apply()`. So the identity that
/// works at every stage is the one the TEMPLATE and the SYMBOL both use:
/// the owning device plus the author-assigned `PortKey` (CR-051).
/// `derivePortId` turns it into a `Uuid` when a command needs one.
@immutable
final class PinRef {
  const PinRef({required this.deviceId, required this.portKey});

  /// `RenderedSymbol.id` — a device `Uuid.v`.
  final String deviceId;

  /// `SymbolPort.key` / `PortDef.key.v`.
  final String portKey;

  @override
  bool operator ==(Object other) =>
      other is PinRef && other.deviceId == deviceId && other.portKey == portKey;

  @override
  int get hashCode => Object.hash(deviceId, portKey);

  @override
  String toString() => 'PinRef($deviceId, $portKey)';
}

/// A pin resolved against a laid-out sheet: which symbol it is on, which
/// `SymbolPort` it is, and where that pin's centre landed.
@immutable
final class LocatedPin {
  const LocatedPin({
    required this.ref,
    required this.symbol,
    required this.port,
    required this.centre,
  });

  final PinRef ref;
  final RenderedSymbol symbol;
  final SymbolPort port;

  /// ABSOLUTE sheet coordinates, from `symbolPortCentre` — the one
  /// definition of where a pin is, shared with the painter and the hit
  /// test. Never re-derived here.
  final DPt centre;

  SymbolSide get side => port.side;
}

/// Every pin on [scene], in the sheet's own reading order.
///
/// `scene.symbols` is by Sugiyama layer and then top-to-bottom within a
/// layer (M2-D's op order), and `RenderedSymbol.allPorts` walks edges in
/// `SymbolSide.values` order then within-edge order. Both are already
/// deterministic, so this walk is too — which is what lets a keyboard
/// traversal be replayable and a test name a pin by index.
List<LocatedPin> locatePins(SchematicScene scene) => <LocatedPin>[
  for (final symbol in scene.symbols)
    for (final port in symbol.allPorts)
      LocatedPin(
        ref: PinRef(deviceId: symbol.id, portKey: port.key),
        symbol: symbol,
        port: port,
        centre: symbolPortCentre(symbol, port),
      ),
];

/// [ref] resolved against [scene], or null when the sheet does not draw it.
///
/// Null is REACHABLE AND NORMAL, not a defect: a caret held across a
/// document change can name a device that has been deleted, or one whose
/// template lost the port. The screen's teardown reads this returning null
/// as "say so and drop the caret" rather than as an error.
LocatedPin? locatePin(SchematicScene scene, PinRef ref) {
  for (final symbol in scene.symbols) {
    if (symbol.id != ref.deviceId) continue;
    for (final port in symbol.allPorts) {
      if (port.key != ref.portKey) continue;
      return LocatedPin(
        ref: ref,
        symbol: symbol,
        port: port,
        centre: symbolPortCentre(symbol, port),
      );
    }
    return null; // right symbol, no such pin.
  }
  return null;
}

/// docs/05 §7.3's amber "would spring back" ring: `#E69F00`, FIXED.
///
/// ═════════════════════════════════════════════════════════════════════
/// NOT A FIELD OF [ConnectOverlayStyle], AND THAT IS DR-114 MADE
/// STRUCTURAL RATHER THAN DOCUMENTARY
/// ═════════════════════════════════════════════════════════════════════
/// Every other colour this overlay draws with is a theme role the screen
/// passes in, and the argument for that is untouched: a caret, a source
/// ring, a band and a selection all mark WHERE THE USER IS or WHAT THEY
/// PICKED, and a cursor has to read against whatever theme its owner
/// chose. This one is different in kind. It states what a RULE decided.
///
/// DR-114 §11.113.2 fixes it so a verdict does not change colour between
/// the drag and the DRC mark four seconds later: docs/05 §8 gives that
/// mark `#E69F00` for `warning` and `#D55E00` for `error`, painted over
/// cables that may themselves be those hues, with SHAPE AND BADGE as the
/// discriminator rather than the hue. Under a theme role the user would
/// learn two colours for one verdict, and the one they learned first
/// would move when they changed theme.
///
/// **So there is deliberately no knob.** A `springBackArgb` parameter
/// beside the other five would be an open invitation to pass
/// `scheme.error`, which is exactly the thing ruled against. The colour
/// that is not a preference does not live in the class whose whole
/// content is preferences.
///
/// The comment this replaces refused the fixed hexes wholesale, on the
/// ground that `#F0E442` and `#E69F00` are *"PAL-1 colours belonging to
/// the signal taxonomy"*. §11.113.1 measured that: `#F0E442` is PAL-2's
/// RESERVED selection-and-focus colour and is *"never a cable"*, so the
/// candidate ring was specified in it precisely because it is reserved
/// for this. Only the second half held.
const int kSpringBackRingArgb = 0xFFE69F00;

/// The colour of a spring-back that HAS happened: `#D55E00`, FIXED.
///
/// docs/05 §7's release feedback — *"the target port flashes `#D55E00`
/// twice at 90 ms"* — and the chip's badge and rule id, which state the
/// same verdict in words.
///
/// ═════════════════════════════════════════════════════════════════════
/// TWO COLOURS FOR ONE RULE, AND THE PAIR IS NOT ARBITRARY
/// ═════════════════════════════════════════════════════════════════════
/// The corpus specifies amber for the ring and vermillion for the flash
/// without saying why, and the reason is worth writing down because it
/// is also the reason both are fixed. They are docs/05 §8's `warning` and
/// `error` hues in that order, and the order is the TENSE:
///
///  * BEFORE THE RELEASE the rule has not fired. The pin is droppable
///    (docs/05:476) and the ring is a caution about what would happen,
///    so it wears the caution colour.
///  * AFTER THE RELEASE it has fired. The cable sprang back, and the
///    flash and the chip wear the error colour — the same one the DRC
///    mark will wear on this cable the moment `[ Connect anyway ]` is
///    pressed and the finding becomes computable.
///
/// So a user who learns these two learns them once, and the second one
/// is already familiar by the time they meet the issues list.
const int kSpringBackRefusedArgb = 0xFFD55E00;

/// The colours and sizes the overlay draws with, in SCREEN pixels.
///
/// Screen pixels, not diagram units, and every field says so by being
/// consumed with `scaleWithGeometry: false`. A caret is a cursor: it must
/// be the same size to the eye at 0.05x and at 32x, exactly as docs/05
/// §11.6's 12 px snap radius is a screen figure. The one value that is NOT
/// chrome is [bandWidthPx], which is still screen-space because the band is
/// a gesture affordance rather than cable ink.
@immutable
final class ConnectOverlayStyle {
  const ConnectOverlayStyle({
    required this.caretArgb,
    required this.sourceArgb,
    required this.bandArgb,
    required this.candidateArgb,
    required this.selectionArgb,
    this.caretRadiusPx = 7,
    this.ringWidthPx = 2,
    this.bandWidthPx = 1.5,
    this.candidateRadiusPx = 3.5,
  });

  final int caretArgb;
  final int sourceArgb;
  final int bandArgb;
  final double caretRadiusPx;
  final double ringWidthPx;
  final double bandWidthPx;

  /// The ring on a pin the armed cable MAY land on.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ONE RING, NOT TWO, AND THE MISSING ONE IS A RULING NOT AN OMISSION
  /// ═══════════════════════════════════════════════════════════════════
  /// docs/05 §7 asks for two: `#F0E442` for a compatible port and amber
  /// `#E69F00` for one that "would spring back", the latter "droppable —
  /// the chip and `[ Connect anyway ]` are what handles them". Neither
  /// half of that is expressible in M2.
  ///
  /// DR-011.5 deletes `[ Connect anyway ]` FOR TIER 1: docs/02:854 gives
  /// T1's escape as "None. There is nothing to escape to", and that half
  /// still stands. The other half was a statement about M2 and has since
  /// come true: the spring-back tier IS the six T2 rules, `SIG-001`,
  /// `DIR-001`, `CON-001` and the rest, all six built in M5-D. Until they
  /// existed, drawing an amber "you may drop here but it will spring
  /// back" ring would have been inventing a verdict the model could not
  /// compute, the same fabrication G4 forbids for a value. It can compute
  /// it now, so the ring is drawn, and the reason it took three
  /// milestones is recorded here rather than deleted.
  ///
  /// THE SECOND RING HAS ARRIVED, and it is NOT a field here. See
  /// [kSpringBackRingArgb]: it is a fixed figure rather than a theme role
  /// because it states a VERDICT and not a position, and DR-114 §11.113.2
  /// makes that structural by giving it no knob. Everything in this class
  /// is chrome; the one colour that is not lives outside it.
  final int candidateArgb;

  /// Candidate rings are drawn INSIDE the pin's own glyph, not around it,
  /// so a sheet with a hundred reachable pins does not turn into a field
  /// of halos. Smaller than [caretRadiusPx] on purpose: the caret has to
  /// win the eye against them.
  final double candidateRadiusPx;

  /// The ring on a pin held in the multi-draw selection (#93, docs/05:484's
  /// "N ports selected in one bank").
  ///
  /// A THIRD RING, AND THE THIRD IS EARNED WHERE THE AMBER ONE WAS NOT.
  /// [candidateArgb]'s doc refuses a second ring because it would encode a
  /// verdict the model cannot compute. This one encodes a fact the user
  /// themselves supplied — these are the pins they picked — so there is
  /// nothing to fabricate. It is drawn whether or not a cable is armed,
  /// because unlike a candidate set the selection SURVIVES the gesture: it
  /// is what the next `W` or the next press will draw from.
  final int selectionArgb;
}

/// The overlay's display list, plus what the screen has to be able to SAY
/// about it.
@immutable
final class ConnectOverlay {
  const ConnectOverlay({
    required this.ops,
    required this.caret,
    required this.source,
    required this.band,
    this.selected = const <LocatedPin>[],
    this.bands = const <List<DPt>>[],
    this.selectedLinkPennants = const <DBox>[],
    this.springBack = const <LocatedPin>[],
  });

  /// Appended AFTER every other op in the frame — see
  /// `schematic_paint_plan.dart`'s ordering rule. There is no z-index in
  /// the IR, so the thing the user is currently doing has to be last.
  final List<DiagramOp> ops;

  /// The resolved caret pin, or null when there is none or the sheet no
  /// longer draws it.
  final LocatedPin? caret;

  /// The resolved armed source pin, likewise.
  final LocatedPin? source;

  /// The band's corner list, or empty when no wire is in flight. Published
  /// so a test can assert the PATH rather than count ops.
  final List<DPt> band;

  /// The multi-draw selection, resolved against the sheet and in the order
  /// it was given. Pins the sheet no longer draws are absent — which is
  /// how a test tells "the selection was dropped" from "the selection is
  /// held but off-sheet".
  final List<LocatedPin> selected;

  /// Every multi-draw band's corner list, in the plan's rank order —
  /// docs/05:484's "all N bands", published so a test can count them and
  /// assert their PATHS rather than count ops. Empty for a single-cable
  /// gesture, where [band] is the one that matters.
  final List<List<DPt>> bands;

  /// The selected cable's pennant boxes, as the label layer measured them.
  ///
  /// USUALLY TWO, sometimes one (a home run to the field — AC-018 leaves the
  /// far end open and it lands on no pin) and sometimes ZERO with a cable
  /// still selected, when the domain filter is hiding its family. Published
  /// so a test can assert that both ends are marked rather than counting
  /// ops, and so the zero case is observable as itself.
  final List<DBox> selectedLinkPennants;

  /// The candidates a tier-2 rule would spring back, resolved against the
  /// sheet: a SUBSET of the pins that got a ring, wearing the amber one.
  ///
  /// Published rather than left to op-counting for this file's usual
  /// reason and one sharper: the two rings differ only in ARGB, so a test
  /// that counted `OpCircle`s could not tell an amber ring from a
  /// candidate ring and would pass while the overlay drew the wrong
  /// verdict on every pin.
  final List<LocatedPin> springBack;

  bool get isEmpty => ops.isEmpty;
}

/// Builds the overlay for a caret at [caret] and a wire armed from
/// [source].
///
/// Either may be null and the four combinations are all reachable: nothing
/// (an untouched sheet), a caret alone (navigating), a source alone (armed,
/// with the caret gone because the document deleted the pin it named), and
/// both (the ordinary in-flight state).
/// [freeEnd] is where the band ends when a pointer drag has not snapped to
/// a pin — the raw cursor, in scene space. Ignored when [caret] resolves,
/// because a snapped band ends on the pin and not near it.
///
/// [candidates] are the pins the armed cable may legally land on. They are
/// drawn only while [source] is armed: a ring on every reachable pin of an
/// IDLE sheet would be permanent chrome answering a question nobody asked.
///
/// [refused] is the pin a cable JUST sprang back off, marked in
/// [kSpringBackRefusedArgb] while its chip is up, and [refusedVisible] is
/// docs/05 §7's flash: *"the target port flashes `#D55E00` twice at 90
/// ms"*, which is two periods of it being false.
///
/// UNLIKE EVERYTHING ELSE HERE IT SURVIVES THE CARET LEAVING. The band
/// retracted and the caret went with it, so without this mark the chip
/// would float beside a pin with nothing to say the chip is ABOUT that
/// pin. It is drawn at the caret's radius rather than a candidate's,
/// because it is a place the eye is being sent and not one of a field.
///
/// [springBack] are the candidates a tier-2 rule objects to (docs/05 §7.3).
/// A SUBSET OF [candidates] AND NEVER A SEPARATE POOL, because docs/05:476
/// says these pins *"remain droppable, the chip and `[ Connect anyway ]`
/// are what handles them"* — a spring-back target the cable could not
/// reach would be a tier-1 refusal wearing the wrong colour. Anything here
/// that is not also in [candidates] is silently ignored rather than drawn,
/// so a caller that got the subset relation wrong cannot put a ring on a
/// pin the commit would refuse outright.
///
/// [selected] is the multi-draw selection (#93). Unlike [candidates] it is
/// drawn on an IDLE sheet too, because it is not a derived affordance —
/// it is a thing the user built and can come back to.
///
/// [pairs] is docs/05:484's **"live preview shows all N bands"**. When it
/// is non-empty it REPLACES the single [source]→[caret] band: a multi-draw
/// has no one band, and drawing an extra one from whichever pin the user
/// happened to grab would put a cable on the sheet that the commit will
/// not make.
///
/// [selectedLink] is the cable the user has picked (#96). Like [selected]
/// and unlike [candidates] it is drawn on an IDLE sheet, because it is a
/// thing the user chose rather than an affordance derived from a gesture in
/// flight — and unlike either it is marked on PENNANTS rather than pins,
/// which is what DR-001 makes the visible representation of a link.
ConnectOverlay buildConnectOverlay({
  required SchematicScene scene,
  required ConnectOverlayStyle style,
  required double scale,
  PinRef? caret,
  PinRef? source,
  DPt? freeEnd,
  List<PinRef> candidates = const <PinRef>[],
  Set<PinRef> springBack = const <PinRef>{},
  PinRef? refused,
  bool refusedVisible = true,
  List<PinRef> selected = const <PinRef>[],
  List<(PinRef, PinRef)> pairs = const <(PinRef, PinRef)>[],
  Uuid? selectedLink,
  SchematicWireStyle wireStyle = const SchematicWireStyle(),
}) {
  final caretPin = caret == null ? null : locatePin(scene, caret);
  final sourcePin = source == null ? null : locatePin(scene, source);
  final selectedPins = <LocatedPin>[
    for (final ref in selected)
      if (locatePin(scene, ref) case final pin?) pin,
  ];
  // EMPTY IS REACHABLE WITH A LINK STILL SELECTED, and it is not a fault:
  // the domain filter can hide the cable's whole family, and both its
  // devices can be off a focused sub-graph. The selection SURVIVES that —
  // showing the domain again brings the mark back — which is why this
  // resolves to a list here rather than the screen dropping the id when it
  // cannot draw it.
  final selectedLinkPennants = <DBox>[
    if (selectedLink != null)
      for (final label in scene.netLabels)
        if (label.linkId == selectedLink) label.pennant,
  ];
  if (caretPin == null &&
      sourcePin == null &&
      refused == null &&
      selectedPins.isEmpty &&
      selectedLinkPennants.isEmpty) {
    return const ConnectOverlay(
      ops: <DiagramOp>[],
      caret: null,
      source: null,
      band: <DPt>[],
    );
  }

  // SCREEN PIXELS INTO DIAGRAM UNITS, by the live scale — the same
  // conversion `schematic_canvas_screen.dart` applies to docs/05 §11.6's 12
  // px pin tolerance, and for the same reason: a constant in diagram units
  // is 20x stricter at 20x zoom. `Stroke.scaleWithGeometry: false` handles
  // the STROKE WIDTH; the radius is geometry and has to be converted here.
  final radius = style.caretRadiusPx / scale;

  final ops = <DiagramOp>[];
  var band = const <DPt>[];
  // Accumulated INSIDE the candidate walk rather than resolved separately,
  // so what is published cannot drift from what was painted: one pass
  // decides the colour and records the pin in the same breath.
  final springBackPins = <LocatedPin>[];

  // THE SELECTED CABLE'S FLAGS, UNDER EVERYTHING — the most persistent mark
  // this overlay draws, so the bottom of its stack for the same reason the
  // pin selection sits under the candidates.
  //
  // ═══════════════════════════════════════════════════════════════════
  // A BOX, BECAUSE A PENNANT IS WHAT THERE IS TO POINT AT
  // ═══════════════════════════════════════════════════════════════════
  // Under DR-001 a committed link's default mark is a pair of net-label
  // pennants and NOT a wire — a wire exists only inside a hovered or
  // filtered scope (canon §11.1.1). So the honest selection mark is drawn
  // around what the user actually clicked and can actually see. Outlining
  // the WIRE would leave a selected cable with no mark at all on the
  // unfiltered sheet that is the product's normal state.
  //
  // BOTH FLAGS, WHICH IS §11.5's OWN RULE: *"both flags of a net show the
  // identical string and highlight together on hover"*. A selection that
  // lit one end would say the cable is half-picked.
  //
  // `pennant` IS READ, NOT REMEASURED. It is the box `net_label_layer.dart`
  // drew, apex included — see `link_hit_test.dart` on why this file and the
  // hit test both read it rather than deriving a second opinion that would
  // agree only by inspection.
  if (selectedLinkPennants.isNotEmpty) {
    final stroke = Stroke(
      argb: style.selectionArgb,
      widthPt: style.ringWidthPx,
      scaleWithGeometry: false,
    );
    // Outside the flag rather than on its outline: the pennant already has
    // a stroke of its own in the family hue, and a selection ring drawn
    // exactly on top of it would read as that stroke having changed colour
    // instead of as a mark around it.
    final pad = style.candidateRadiusPx / scale;
    for (final pennant in selectedLinkPennants) {
      ops.add(OpRect(pennant.inflate(pad), stroke: stroke));
    }
  }

  // THE SELECTION RINGS FIRST, UNDER EVEN THE CANDIDATES. The selection is
  // the most persistent of the four things drawn here — it outlives the
  // gesture, where a candidate set and a band are both born and destroyed
  // inside one — so it is the bottom of the stack and everything transient
  // reads over it.
  if (selectedPins.isNotEmpty) {
    final stroke = Stroke(
      argb: style.selectionArgb,
      widthPt: style.ringWidthPx,
      scaleWithGeometry: false,
    );
    for (final pin in selectedPins) {
      // THE CARET'S OWN RING IS SKIPPED, exactly as a candidate's is and
      // for a sharper version of the same reason: this ring and the
      // caret's are the SAME RADIUS, so drawing both puts two coincident
      // circles on one pin and the caret — drawn last — hides the one
      // underneath. The op would cost a pixel of nothing. A run is still
      // legible without it, because the caret is by definition ON the pin
      // the user is looking at and the other N-1 rings say where the run
      // reaches.
      if (pin.ref == caret) continue;
      ops.add(OpCircle(pin.centre, radius, stroke: stroke));
    }
  }

  // THE CANDIDATE RINGS NEXT, UNDER THE GESTURE. They are the field the
  // gesture is played on; the band and the two live rings are the gesture
  // itself and have to read over them.
  if (sourcePin != null && candidates.isNotEmpty) {
    final radius = style.candidateRadiusPx / scale;
    final stroke = Stroke(
      argb: style.candidateArgb,
      widthPt: style.ringWidthPx,
      scaleWithGeometry: false,
    );
    // docs/05:476: *"the SAME ring in amber `#E69F00`, no pulse."* Same
    // radius, same width, one colour apart — because the pin is equally
    // reachable and the difference is entirely what happens on release.
    // A larger or heavier amber ring would read as "more of a target",
    // which is the opposite of what it means.
    //
    // NO PULSE IS FREE HERE. §7.2's 900 ms breathing pulse on the
    // COMPATIBLE ring is not built either, so "amber, no pulse" and
    // "yellow, pulsing" currently differ by the one channel that is
    // implemented. When the pulse arrives it must skip these.
    final springBackStroke = Stroke(
      argb: kSpringBackRingArgb,
      widthPt: style.ringWidthPx,
      scaleWithGeometry: false,
    );
    for (final ref in candidates) {
      // Skip the one the caret is on: it gets the caret's own, larger ring
      // a few lines below, and two concentric circles on one pin reads as
      // a target rather than as a cursor.
      if (ref == caret) continue;
      final pin = locatePin(scene, ref);
      if (pin == null) continue;
      final warns = springBack.contains(ref);
      if (warns) springBackPins.add(pin);
      ops.add(
        OpCircle(
          pin.centre,
          radius,
          stroke: warns ? springBackStroke : stroke,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // docs/05:484's N BANDS — "live preview shows all N bands"
  // ═══════════════════════════════════════════════════════════════════
  // Each pair is drawn with `orthogonalTrace`, the same function the
  // committed wire layer routes with and the same one the single band
  // uses, for the reason this file's header gives: a preview that took a
  // different path from the wire it previews is a desync waiting to be
  // noticed by a user rather than by a test.
  //
  // NO COMB INDEX, EVEN THOUGH THERE ARE N OF THEM. `buildDrawnWireLayer`
  // escapes the i-th link on a side i steps further out so committed
  // cables do not overprint. These do not get that, and the reason is
  // that they are N bands from N DIFFERENT PINS: the comb exists for N
  // links leaving ONE pin's side at one x, and a multi-draw's bands each
  // leave their own pin at their own y. Adding a comb step here would
  // fan them apart at a spacing the committed cables will not have.
  final bandStroke = Stroke(
    argb: style.bandArgb,
    widthPt: style.bandWidthPx,
    scaleWithGeometry: false,
  );
  final bands = <List<DPt>>[];
  if (pairs.isNotEmpty) {
    final escape = wireStyle.escapeGu * kSchematicUnitsPerGrid;
    for (final (fromRef, toRef) in pairs) {
      final from = locatePin(scene, fromRef);
      final to = locatePin(scene, toRef);
      if (from == null || to == null) continue;
      final trace = orthogonalTrace(
        fromPin: from.centre,
        fromSide: from.side,
        fromEscape: escape,
        fromBody: from.symbol.bodyRect,
        toPin: to.centre,
        toSide: to.side,
        toEscape: escape,
        toBody: to.symbol.bodyRect,
      );
      ops.add(OpPolyline(trace, bandStroke));
      bands.add(trace);
      // THE LAST PAIR'S TRACE IS ALSO PUBLISHED AS `band`, so the one
      // field a test reads to assert a PATH keeps meaning "the band drawn
      // last" in both modes. [ConnectOverlay.bands] is what a multi-draw
      // test should read instead.
      band = trace;
    }
  }

  // The single band next, so the two rings sit on top of their own wire
  // rather than under it — the rings are what say "here", and a band drawn
  // over them would obscure the one pin the user is aiming at.
  //
  // SUPPRESSED ENTIRELY WHILE [pairs] IS NON-EMPTY: a multi-draw's source
  // is a RUN, and a band from the one pin the pointer happens to be over
  // would draw a cable the commit does not make.
  if (pairs.isEmpty &&
      sourcePin != null &&
      caretPin == null &&
      freeEnd != null) {
    // AN UNSNAPPED POINTER DRAG. The band still leaves the source along
    // its own edge — that half is a fact about the pin and does not
    // depend on where the cable is going — but the far end is a cursor,
    // not a jack, so there is no edge to arrive along and the trace is
    // taken as far as the escape and then run straight. Inventing a side
    // for a point in empty space would draw a corner the committed cable
    // would not have.
    final escape = wireStyle.escapeGu * kSchematicUnitsPerGrid;
    band = <DPt>[
      sourcePin.centre,
      _escapeFrom(sourcePin, escape),
      freeEnd,
    ];
    ops.add(OpPolyline(band, bandStroke));
  }
  if (sourcePin != null && caretPin != null) {
    // `escapeGu` WITHOUT THE COMB STEP — see the file header. It is also
    // the same 3 gu a net-label leader uses, so the band leaves the pin at
    // the point the committed link's own stub will.
    final escape = wireStyle.escapeGu * kSchematicUnitsPerGrid;
    band = orthogonalTrace(
      fromPin: sourcePin.centre,
      fromSide: sourcePin.side,
      fromEscape: escape,
      // BOTH BODIES, so a band aimed at a device BEHIND the source previews
      // the detour the committed cable will take rather than the straight
      // line through the symbol it used to. The free-end band above still
      // passes none, and cannot: an unsnapped pointer has no body.
      fromBody: sourcePin.symbol.bodyRect,
      toPin: caretPin.centre,
      toSide: caretPin.side,
      toEscape: escape,
      toBody: caretPin.symbol.bodyRect,
    );
    ops.add(OpPolyline(band, bandStroke));
  }

  if (sourcePin != null) {
    ops.add(
      OpCircle(
        sourcePin.centre,
        radius,
        stroke: Stroke(
          argb: style.sourceArgb,
          widthPt: style.ringWidthPx,
          scaleWithGeometry: false,
        ),
      ),
    );
  }
  if (caretPin != null) {
    ops.add(
      OpCircle(
        caretPin.centre,
        radius,
        stroke: Stroke(
          argb: style.caretArgb,
          widthPt: style.ringWidthPx,
          scaleWithGeometry: false,
        ),
      ),
    );
  }

  // THE REFUSAL MARK LAST, OVER EVERYTHING INCLUDING THE CARET. It is the
  // most recent thing that happened on this sheet, and the one the chip
  // beside it is talking about. Everything under it is an affordance; this
  // is an outcome.
  if (refused != null && refusedVisible) {
    if (locatePin(scene, refused) case final pin?) {
      ops.add(
        OpCircle(
          pin.centre,
          radius,
          stroke: const Stroke(
            argb: kSpringBackRefusedArgb,
            widthPt: 2.5,
            scaleWithGeometry: false,
          ),
        ),
      );
    }
  }

  return ConnectOverlay(
    ops: ops,
    caret: caretPin,
    source: sourcePin,
    band: band,
    selected: List<LocatedPin>.unmodifiable(selectedPins),
    bands: List<List<DPt>>.unmodifiable(bands),
    selectedLinkPennants: List<DBox>.unmodifiable(selectedLinkPennants),
    springBack: List<LocatedPin>.unmodifiable(springBackPins),
  );
}

/// [pin]'s escape point — [distance] straight out along its own edge.
///
/// The same rule `wire_trace.dart`'s private `_escapePoint` applies, and
/// deliberately not a call to it: that one is private to the router, and
/// the point here is that an UNSNAPPED band has only one real end. When
/// both ends are pins the band goes through `orthogonalTrace` instead, so
/// there is exactly one place a two-ended trace is derived.
DPt _escapeFrom(LocatedPin pin, double distance) => switch (pin.side) {
  SymbolSide.left => DPt(pin.centre.x - distance, pin.centre.y),
  SymbolSide.right => DPt(pin.centre.x + distance, pin.centre.y),
  SymbolSide.top => DPt(pin.centre.x, pin.centre.y - distance),
  SymbolSide.bottom => DPt(pin.centre.x, pin.centre.y + distance),
};

/// The pin nearest [scenePoint] within [tolerance], or null.
///
/// ═══════════════════════════════════════════════════════════════════════
/// docs/05 §11.6's MAGNET, AND WHAT IT DELIBERATELY IS NOT YET
/// ═══════════════════════════════════════════════════════════════════════
/// "Within 12 screen px the band locks to a port's glyph centre." That
/// figure is the corpus's only quantified pin-proximity number, and it is
/// the same one the screen already converts for its click target — a pin
/// you can snap to but not click would be two different pins.
///
/// SNAP IS NOT TYPE-WEIGHTED HERE, and that is one of DR-011.8's three
/// open questions rather than a shortcut. docs/05 §7.6 says an HDMI band
/// should prefer an HDMI port "even if an RJ45 port is 3 px nearer" — but
/// its example weights the CONNECTOR while compatibility is defined over
/// `signalFamily` (:473), and weighting the connector actively pushes
/// toward `SIG-001`, because RJ45-carrying-`video.hdbaset` and
/// RJ45-carrying-`net.ethernet` are the same connector and docs/05:145
/// calls them the two most dangerous ports in the taxonomy. Guessing which
/// axis it meant would bake that hazard into the gesture users perform
/// sixty times an hour.
///
/// [among] is the candidate set, so the magnet cannot pull the band onto a
/// pin the cable may not land on — which is the pointer's version of the
/// keyboard's "Tab only reaches a candidate".
///
/// ═══════════════════════════════════════════════════════════════════════
/// [preferred] IS DR-012.3, AND THE PREFERENCE IS ABSOLUTE
/// ═══════════════════════════════════════════════════════════════════════
/// docs/05 §7.6 wants an HDMI band to prefer an HDMI port "even if an RJ45
/// port is 3 px nearer", and DR-012.3 rules that the axis is the SIGNAL
/// FAMILY rather than the connector its example names — because
/// RJ45-carrying-`video.hdbaset` and RJ45-carrying-`net.ethernet` are the
/// same connector, and steering a user toward that pair is the worst
/// mistake this product can make (docs/05:145; the seed registry records
/// that the 100 W PoH can damage the switch).
///
/// The corpus gives no NUMBER — only "more than 3 px" — so rather than
/// invent a second unquantified figure the preference is lexicographic: a
/// preferred pin beats an unpreferred one ANYWHERE inside [tolerance], and
/// distance decides only within each group. The 12 screen px radius
/// already bounds how far that can reach, and `Ctrl` (which collapses
/// [tolerance] to the pin's own glyph) is the documented way to insist on
/// the other pin.
///
/// [preferred] is computed ONCE at arm time by the screen, because
/// deciding it needs `ConnectTarget.acceptsFamily` — which reads
/// `PortDef.acceptedFamilies`, a field the SCENE does not carry.
LocatedPin? snapToPin(
  SchematicScene scene,
  DPt scenePoint, {
  required double tolerance,
  required List<PinRef> among,
  Set<PinRef> preferred = const <PinRef>{},
}) {
  LocatedPin? best;
  var bestDistance = double.infinity;
  var bestPreferred = false;
  for (final ref in among) {
    final pin = locatePin(scene, ref);
    if (pin == null) continue;
    final dx = pin.centre.x - scenePoint.x;
    final dy = pin.centre.y - scenePoint.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > tolerance) continue;
    final isPreferred = preferred.contains(ref);
    // Lexicographic: the family first, the distance only within a group.
    if (best != null) {
      if (bestPreferred && !isPreferred) continue;
      if (bestPreferred == isPreferred && distance >= bestDistance) continue;
    }
    bestDistance = distance;
    bestPreferred = isPreferred;
    best = pin;
  }
  return best;
}
