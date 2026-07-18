// Widget tests for CanvasIntentDetector: the pointer-agnostic intent plumbing
// and the pan/zoom channels. These DO exercise a real gesture pipeline, so
// they are `testWidgets`, unlike the pure-math ViewportController tests.
//
// The device-agnosticism test is the important one (AC-016 #23): the same drag
// driven by a mouse and by a touch pointer must produce a byte-identical
// begin/update/commit sequence in scene space.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

Widget _host(ViewportController vp, CanvasIntentHandler? handler) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      // Top-left so local == global coordinates for gesture positions.
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 800,
        height: 600,
        child: CanvasIntentDetector(
          viewport: vp,
          handler: handler,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _RecordingHandler implements CanvasIntentHandler {
  final List<String> log = <String>[];
  Set<PointerDeviceKind>? lastKinds;

  @override
  void beginDrag(DPt sceneStart, Set<PointerDeviceKind> sourceKinds) {
    lastKinds = sourceKinds;
    log.add('begin(${_f(sceneStart)})');
  }

  @override
  void updateDrag(DPt sceneCurrent, DPt sceneDelta) =>
      log.add('update(${_f(sceneCurrent)}|${_f(sceneDelta)})');

  @override
  void commitDrag(DPt sceneEnd) => log.add('commit(${_f(sceneEnd)})');

  @override
  void cancel() => log.add('cancel');

  static String _f(DPt p) =>
      '${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)}';
}

void main() {
  testWidgets('primary drag pans when no handler is attached', (tester) async {
    final vp = ViewportController();
    addTearDown(vp.dispose);
    await tester.pumpWidget(_host(vp, null));

    final t0x = vp.transform.storage[12];
    final t0y = vp.transform.storage[13];
    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveBy(const Offset(20, -10));
    await gesture.up();

    expect(vp.transform.storage[12] - t0x, closeTo(20, 1e-6));
    expect(vp.transform.storage[13] - t0y, closeTo(-10, 1e-6));
  });

  testWidgets('drag drives the handler identically for mouse and touch', (
    tester,
  ) async {
    Future<_RecordingHandler> drive(PointerDeviceKind kind) async {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final handler = _RecordingHandler();
      await tester.pumpWidget(_host(vp, handler));

      final gesture = await tester.startGesture(
        const Offset(200, 150),
        kind: kind,
      );
      await gesture.moveBy(const Offset(30, -5));
      await gesture.moveBy(const Offset(10, 10));
      await gesture.up();

      // The handler consumed the drag: the viewport must not have panned/zoomed.
      expect(vp.scale, closeTo(1, 1e-12));
      expect(vp.transform.storage[12], closeTo(0, 1e-12));
      expect(vp.transform.storage[13], closeTo(0, 1e-12));
      return handler;
    }

    final mouse = await drive(PointerDeviceKind.mouse);
    final touch = await drive(PointerDeviceKind.touch);

    const expected = <String>[
      'begin(200.0,150.0)',
      'update(230.0,145.0|30.0,-5.0)',
      'update(240.0,155.0|10.0,10.0)',
      'commit(240.0,155.0)',
    ];
    expect(mouse.log, expected);
    expect(touch.log, expected);
    expect(mouse.log, touch.log);

    // sourceKinds is informational only, but it is passed through.
    expect(mouse.lastKinds, contains(PointerDeviceKind.mouse));
    expect(touch.lastKinds, contains(PointerDeviceKind.touch));
  });

  testWidgets('cancelled drag fires cancel, not commit', (tester) async {
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final gesture = await tester.startGesture(const Offset(120, 120));
    await gesture.moveBy(const Offset(5, 5));
    await gesture.cancel();

    expect(handler.log.last, 'cancel');
    expect(handler.log, isNot(contains('commit(125.0,125.0)')));
  });

  testWidgets('plain mouse wheel pans the viewport', (tester) async {
    final vp = ViewportController();
    addTearDown(vp.dispose);
    await tester.pumpWidget(_host(vp, null));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(300, 300)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));

    // Plain scroll pans by -scrollDelta (down-scroll moves content up).
    expect(vp.transform.storage[12], closeTo(0, 1e-9));
    expect(vp.transform.storage[13], closeTo(-100, 1e-9));
  });

  testWidgets('trackpad pan/zoom drives pan then zoom-about-focus', (
    tester,
  ) async {
    final vp = ViewportController();
    addTearDown(vp.dispose);
    await tester.pumpWidget(_host(vp, null));

    final p = TestPointer(1, PointerDeviceKind.trackpad);
    const focus = Offset(400, 300);
    await tester.sendEventToBinding(p.panZoomStart(focus));

    // Two-finger pan 15px right (a channel separate from PointerScrollEvent).
    await tester.sendEventToBinding(
      p.panZoomUpdate(focus, pan: const Offset(15, 0)),
    );
    expect(vp.transform.storage[12], closeTo(15, 1e-6));

    // Pinch to 2x about the focus point; the focus scene point stays put.
    final sceneBefore = vp.screenToScene(const DPt(400, 300));
    await tester.sendEventToBinding(
      p.panZoomUpdate(focus, pan: const Offset(15, 0), scale: 2),
    );
    expect(vp.scale, closeTo(2, 1e-6));
    final sceneAfter = vp.screenToScene(const DPt(400, 300));
    expect(sceneAfter.x, closeTo(sceneBefore.x, 1e-4));
    expect(sceneAfter.y, closeTo(sceneBefore.y, 1e-4));

    await tester.sendEventToBinding(p.panZoomEnd());
  });
}
