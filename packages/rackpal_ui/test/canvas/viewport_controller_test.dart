// Pure Matrix4-math tests for ViewportController. These need no widget binding
// (a ChangeNotifier + Matrix4 is plain Dart), so they run as ordinary `test`s
// under `flutter test`, per the task's "no real binding where possible".
//
// The load-bearing cases, and what each actually proves about the pre/post
// multiply order the docs warn is easy to reverse:
//   * pan-at-scale-4  -> pan is a SCREEN-space pre-multiply (zoom-independent).
//   * zoom pivot invariance -> zoom is a correct scene-space pivot post-mul.
//   * zoom round-trip -> multiplicative symmetry (the weakest of the three).

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  group('ViewportController coordinate math', () {
    test('identity maps scene 1:1 to screen', () {
      final vp = ViewportController();
      expect(vp.scale, closeTo(1, 1e-12));
      final p = vp.sceneToScreen(const DPt(3, 4));
      expect(p.x, closeTo(3, 1e-12));
      expect(p.y, closeTo(4, 1e-12));
    });

    test('sceneToScreen/screenToScene round-trip after pan + zoom', () {
      final vp = ViewportController()
        ..panBy(const Offset(37, -19))
        ..zoomBy(2.5, screenPivot: const Offset(80, 60));
      const scene = DPt(123.5, -47.25);
      final round = vp.screenToScene(vp.sceneToScreen(scene));
      expect(round.x, closeTo(scene.x, 1e-6));
      expect(round.y, closeTo(scene.y, 1e-6));
    });
  });

  group('pan is a screen-space pre-multiply', () {
    test(
      'pan moves a fixed scene point by the exact screen delta at scale 4',
      () {
        final vp = ViewportController()
          // Zoom about the origin so the scene pivot is (0,0): scale becomes 4
          // with zero translation.
          ..zoomBy(4, screenPivot: Offset.zero);
        expect(vp.scale, closeTo(4, 1e-9));

        final before = vp.sceneToScreen(const DPt(5, 7));
        vp.panBy(const Offset(10, -3));
        final after = vp.sceneToScreen(const DPt(5, 7));

        // A screen-space (pre) translate moves the point by exactly the delta.
        // A post-multiply would scale the delta by the zoom (=> 40, -12): the
        // bug the docs call out.
        expect(after.x - before.x, closeTo(10, 1e-9));
        expect(after.y - before.y, closeTo(-3, 1e-9));
      },
    );

    test('same pan delta produces the same screen motion at scale 1 and 8', () {
      double motionAtScale(double s) {
        final vp = ViewportController()..zoomBy(s, screenPivot: Offset.zero);
        final before = vp.sceneToScreen(const DPt(2, 0));
        vp.panBy(const Offset(12, 0));
        return vp.sceneToScreen(const DPt(2, 0)).x - before.x;
      }

      expect(motionAtScale(1), closeTo(12, 1e-9));
      expect(motionAtScale(8), closeTo(12, 1e-9));
    });
  });

  group('zoom is a scene-space pivot post-multiply', () {
    test('the scene point under the pivot is invariant across a zoom', () {
      final vp = ViewportController()
        ..panBy(const Offset(30, -20))
        ..zoomBy(1.7, screenPivot: const Offset(50, 40));

      const pivot = Offset(123, 87);
      final sceneBefore = vp.screenToScene(DPt(pivot.dx, pivot.dy));
      vp.zoomBy(2.3, screenPivot: pivot);
      final sceneAfter = vp.screenToScene(DPt(pivot.dx, pivot.dy));

      expect(sceneAfter.x, closeTo(sceneBefore.x, 1e-6));
      expect(sceneAfter.y, closeTo(sceneBefore.y, 1e-6));
    });

    test('zoom multiplies the scale factor', () {
      final vp = ViewportController()
        ..zoomBy(3, screenPivot: const Offset(1, 1));
      expect(vp.scale, closeTo(3, 1e-9));
      vp.zoomBy(2, screenPivot: const Offset(1, 1));
      expect(vp.scale, closeTo(6, 1e-9));
    });

    test(
      'zoom in then out at the same pivot returns to the start transform',
      () {
        final vp = ViewportController()..panBy(const Offset(15, 25));
        final start = vp.transform.clone();
        vp
          ..zoomBy(3, screenPivot: const Offset(200, 150))
          ..zoomBy(1 / 3, screenPivot: const Offset(200, 150));
        for (var i = 0; i < 16; i++) {
          expect(vp.transform.storage[i], closeTo(start.storage[i], 1e-6));
        }
      },
    );
  });

  group('scale clamping', () {
    test('clamps to the upper and lower bounds', () {
      final vp = ViewportController()
        ..zoomBy(1000000000, screenPivot: Offset.zero);
      expect(vp.scale, closeTo(kMaxScale, 1e-6));
      vp.zoomBy(1e-12, screenPivot: Offset.zero);
      expect(vp.scale, closeTo(kMinScale, 1e-6));
    });

    test('the pivot stays invariant even when the zoom is clamped', () {
      final vp = ViewportController()..zoomBy(30, screenPivot: Offset.zero);
      const pivot = Offset(400, 300);
      final sceneBefore = vp.screenToScene(DPt(pivot.dx, pivot.dy));
      vp.zoomBy(1000, screenPivot: pivot); // asks well past kMaxScale.
      expect(vp.scale, closeTo(kMaxScale, 1e-6));
      final sceneAfter = vp.screenToScene(DPt(pivot.dx, pivot.dy));
      expect(sceneAfter.x, closeTo(sceneBefore.x, 1e-5));
      expect(sceneAfter.y, closeTo(sceneBefore.y, 1e-5));
    });
  });

  group('fitToContent and reset', () {
    test('fits and centres a scene box in the viewport', () {
      final vp = ViewportController()
        ..fitToContent(
          const Box.fromLtwh(0, 0, 600, 400),
          const Size(1200, 800),
        );
      // min(1200/600, 800/400) * 0.9 margin = 2 * 0.9 = 1.8.
      expect(vp.scale, closeTo(1.8, 1e-9));
      final centre = vp.sceneToScreen(const DPt(300, 200));
      expect(centre.x, closeTo(600, 1e-6));
      expect(centre.y, closeTo(400, 1e-6));
    });

    test('fitToContent guards against a degenerate box', () {
      final vp = ViewportController()
        ..fitToContent(const Box.fromLtwh(0, 0, 0, 0), const Size(800, 600));
      expect(vp.scale, closeTo(1, 1e-12));
    });

    test('reset restores the identity transform', () {
      final vp = ViewportController()
        ..panBy(const Offset(50, 50))
        ..zoomBy(4, screenPivot: const Offset(10, 10))
        ..reset();
      expect(vp.scale, closeTo(1, 1e-12));
      final p = vp.sceneToScreen(const DPt(9, 9));
      expect(p.x, closeTo(9, 1e-12));
      expect(p.y, closeTo(9, 1e-12));
    });
  });

  group('change notification', () {
    test('mutators notify listeners; no-op pan does not', () {
      final vp = ViewportController();
      var count = 0;
      vp
        ..addListener(() => count++)
        ..panBy(const Offset(1, 1))
        ..zoomBy(2, screenPivot: Offset.zero)
        ..reset();
      expect(count, 3);
      vp.panBy(Offset.zero); // no-op: must not notify.
      expect(count, 3);
    });
  });
}
