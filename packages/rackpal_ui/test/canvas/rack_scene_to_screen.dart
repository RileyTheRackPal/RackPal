// Scene → screen for the rack canvas, THROUGH THE LIVE VIEWPORT (`#710`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS
// ═══════════════════════════════════════════════════════════════════════
// Ten test files turned a scene rect into a tap position by adding the
// canvas's top-left corner:
//
//     _canvasOrigin(tester) + Offset(rect.left, rect.top)
//
// That is only correct while the viewport is the identity transform, and
// it read as though it were about the canvas's POSITION rather than about
// its ZOOM AND PAN. When `#710` made the screen frame the whole rack on
// first sight, 66 cases failed at once — not because the behaviour was
// wrong, but because every one of them had quietly hard-coded a camera.
//
// Going through the same `ViewportController` the canvas paints with
// makes them framing-agnostic: the next change to the opening view costs
// nothing here. It is also simply what the production code does, so a
// test aiming at a device is now aiming with the same arithmetic the
// screen used to draw it.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The canvas's live top-left in screen space — the palette panel sits to
/// its left, so scene (0, 0) is not the Scaffold body's origin.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CanvasIntentDetector));

/// The viewport the rack canvas is currently painting through.
ViewportController rackViewport(WidgetTester tester) =>
    tester.renderObject<RenderRackCanvas>(find.byType(RackCanvasBody)).viewport;

/// Where scene point ([x], [y]) is on screen right now.
Offset sceneToScreen(WidgetTester tester, double x, double y) {
  final p = rackViewport(tester).sceneToScreen(DPt(x, y));
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

/// [scene] as a screen point — the drop-in for `canvasOrigin(tester) +
/// scene`, which is the shape this replaced in nine files.
Offset scenePoint(WidgetTester tester, Offset scene) =>
    sceneToScreen(tester, scene.dx, scene.dy);

/// The inverse: a GLOBAL screen point as a scene point. For the tests that
/// recover a device's rack unit from where its box actually rendered.
Offset sceneOf(WidgetTester tester, Offset global) {
  final local = global - canvasOrigin(tester);
  final p = rackViewport(tester).screenToScene(DPt(local.dx, local.dy));
  return Offset(p.x, p.y);
}

/// The screen-space centre of the [deviceH]U device occupying [ru].
Offset centreOfRu(
  WidgetTester tester,
  RackGeometry geo,
  int ru,
  int deviceH,
) {
  final rect = geo.deviceRect(ru, deviceH);
  return sceneToScreen(
    tester,
    (rect.left + rect.right) / 2,
    (rect.top + rect.bottom) / 2,
  );
}

/// The screen top-left a [deviceH]U device sitting at [ru] would have.
Offset topLeftOfRu(
  WidgetTester tester,
  RackGeometry geo,
  int ru, [
  int deviceH = 1,
]) {
  final rect = geo.deviceRect(ru, deviceH);
  return sceneToScreen(tester, rect.left, rect.top);
}

/// The screen-space drag delta that moves the pointer by ([dx], [dy]) in
/// SCENE units.
///
/// THE DRAG TESTS SPOKE IN SCENE UNITS AND PASSED THEM AS PIXELS. `moveBy(
/// Offset(0, -88))` means "four rack units up" and was only ever true at
/// zoom 1. It reads as a pixel measurement and is not one, which is why
/// eight drag cases failed the moment the opening view stopped being the
/// identity transform.
Offset sceneDelta(WidgetTester tester, double dx, double dy) {
  final s = rackViewport(tester).scale;
  return Offset(dx * s, dy * s);
}

/// A point on empty canvas, clear of the rack, for the "click the canvas
/// to focus it" step every keyboard test opens with.
///
/// TAKEN FROM THE CANVAS'S OWN BOX rather than from a scene coordinate:
/// the rack is now framed and centred, so a fixed offset that used to
/// land on empty space can land on a device. The bottom-left corner is
/// outside a centred rack at any framing this screen produces.
Offset emptyCanvasPoint(WidgetTester tester) {
  final box = tester.getRect(find.byType(CanvasIntentDetector));
  return Offset(box.left + 12, box.bottom - 12);
}
