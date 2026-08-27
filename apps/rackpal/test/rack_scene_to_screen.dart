// Scene → screen for the rack canvas, THROUGH THE LIVE VIEWPORT (`#710`).
//
// A DELIBERATE SECOND COPY. The canonical one is
// `packages/rackpal_ui/test/canvas/rack_scene_to_screen.dart`; this file
// is the two functions the shell's own tests need. It cannot be shared:
// the helper takes a `WidgetTester`, so it depends on `flutter_test`, and
// the only way one package's test code reaches another's is through
// `lib/` — which would put a dev dependency into `rackpal_ui`'s shipped
// dependency graph to save fifteen lines here.
//
// Keep the two in step. If the arithmetic below ever disagrees with the
// canonical file, the canonical file is right.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The canvas's live top-left in screen space.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CanvasIntentDetector));

/// The viewport the rack canvas is currently painting through.
ViewportController rackViewport(WidgetTester tester) =>
    tester.renderObject<RenderRackCanvas>(find.byType(RackCanvasBody)).viewport;

/// Where scene point ([x], [y]) is on screen right now.
///
/// The screen frames the whole rack on first sight, so scene (0, 0) is no
/// longer the canvas's corner and adding a scene offset to that corner
/// aims at nothing in particular.
Offset sceneToScreen(WidgetTester tester, double x, double y) {
  final p = rackViewport(tester).sceneToScreen(DPt(x, y));
  return canvasOrigin(tester) + Offset(p.x, p.y);
}
