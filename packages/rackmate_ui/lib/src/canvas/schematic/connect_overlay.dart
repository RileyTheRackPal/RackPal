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
    this.caretRadiusPx = 7,
    this.ringWidthPx = 2,
    this.bandWidthPx = 1.5,
  });

  final int caretArgb;
  final int sourceArgb;
  final int bandArgb;
  final double caretRadiusPx;
  final double ringWidthPx;
  final double bandWidthPx;
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

  bool get isEmpty => ops.isEmpty;
}

/// Builds the overlay for a caret at [caret] and a wire armed from
/// [source].
///
/// Either may be null and the four combinations are all reachable: nothing
/// (an untouched sheet), a caret alone (navigating), a source alone (armed,
/// with the caret gone because the document deleted the pin it named), and
/// both (the ordinary in-flight state).
ConnectOverlay buildConnectOverlay({
  required SchematicScene scene,
  required ConnectOverlayStyle style,
  required double scale,
  PinRef? caret,
  PinRef? source,
  SchematicWireStyle wireStyle = const SchematicWireStyle(),
}) {
  final caretPin = caret == null ? null : locatePin(scene, caret);
  final sourcePin = source == null ? null : locatePin(scene, source);
  if (caretPin == null && sourcePin == null) {
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

  // The band FIRST, so the two rings sit on top of their own wire rather
  // than under it — the rings are what say "here", and a band drawn over
  // them would obscure the one pin the user is aiming at.
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
  );
}
