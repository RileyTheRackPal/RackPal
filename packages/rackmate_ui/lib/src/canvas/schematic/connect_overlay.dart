// rackmate_ui/src/canvas/schematic/connect_overlay.dart
//
// WHAT A CONNECT GESTURE LOOKS LIKE WHILE IT IS STILL A GESTURE: the pin
// under the caret, the pin a wire is armed from, and the band between them.
//
// ═════════════════════════════════════════════════════════════════════
// THIS LIVES IN `rackmate_ui` ON PURPOSE, UNLIKE ITS NEIGHBOUR
// ═════════════════════════════════════════════════════════════════════
// `wire_trace.dart` sits in this package and should not — the OKF bundle
// records it as a layering violation in waiting, because `rackmate_export`
// may never import `rackmate_ui` and therefore cannot draw a wire, which
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
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/schematic/wire_trace.dart';

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
      other is PinRef &&
      other.deviceId == deviceId &&
      other.portKey == portKey;

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
  /// DR-011.5 deletes `[ Connect anyway ]`: docs/02:854 gives T1's escape
  /// as "None. There is nothing to escape to", and docs/02 governs. And
  /// the spring-back tier IS the six T2 rules — `SIG-001`, `DIR-001`,
  /// `CON-001` and the rest — every one of them deferred to M5
  /// (docs/09:299). So this build knows exactly two states for a pin: the
  /// cable may land on it, or a tier-1 rule refuses it outright. Drawing
  /// an amber "you may drop here but it will spring back" ring would be
  /// inventing a verdict the model cannot compute, which is the same
  /// fabrication G4 forbids for a value.
  ///
  /// The second ring arrives with M5's validation, and with a colour taken
  /// from the same place the first tier's is.
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
/// [selected] is the multi-draw selection (#93). Unlike [candidates] it is
/// drawn on an IDLE sheet too, because it is not a derived affordance —
/// it is a thing the user built and can come back to.
ConnectOverlay buildConnectOverlay({
  required SchematicScene scene,
  required ConnectOverlayStyle style,
  required double scale,
  PinRef? caret,
  PinRef? source,
  DPt? freeEnd,
  List<PinRef> candidates = const <PinRef>[],
  List<PinRef> selected = const <PinRef>[],
  SchematicWireStyle wireStyle = const SchematicWireStyle(),
}) {
  final caretPin = caret == null ? null : locatePin(scene, caret);
  final sourcePin = source == null ? null : locatePin(scene, source);
  final selectedPins = <LocatedPin>[
    for (final ref in selected)
      if (locatePin(scene, ref) case final pin?) pin,
  ];
  if (caretPin == null && sourcePin == null && selectedPins.isEmpty) {
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
    for (final ref in candidates) {
      // Skip the one the caret is on: it gets the caret's own, larger ring
      // a few lines below, and two concentric circles on one pin reads as
      // a target rather than as a cursor.
      if (ref == caret) continue;
      final pin = locatePin(scene, ref);
      if (pin == null) continue;
      ops.add(OpCircle(pin.centre, radius, stroke: stroke));
    }
  }

  // The band next, so the two rings sit on top of their own wire rather
  // than under it — the rings are what say "here", and a band drawn over
  // them would obscure the one pin the user is aiming at.
  if (sourcePin != null && caretPin == null && freeEnd != null) {
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
    ops.add(
      OpPolyline(
        band,
        Stroke(
          argb: style.bandArgb,
          widthPt: style.bandWidthPx,
          scaleWithGeometry: false,
        ),
      ),
    );
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
      toPin: caretPin.centre,
      toSide: caretPin.side,
      toEscape: escape,
    );
    ops.add(
      OpPolyline(
        band,
        Stroke(
          argb: style.bandArgb,
          widthPt: style.bandWidthPx,
          scaleWithGeometry: false,
        ),
      ),
    );
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

  return ConnectOverlay(
    ops: ops,
    caret: caretPin,
    source: sourcePin,
    band: band,
    selected: List<LocatedPin>.unmodifiable(selectedPins),
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
