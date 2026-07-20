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

  testWidgets('a second pointer-down while a drag is routed is IGNORED — '
      'one begin, one commit, and no interleaving', (tester) async {
    // THE CONTRACT, asserted at the level that owns it. `commitDrag`'s doc
    // promises "exactly one of commitDrag/cancel per beginDrag" and that no
    // second `beginDrag` arrives before one of them — which is what lets a
    // handler (re)initialise its whole per-drag state in `beginDrag` without
    // a concurrency check of its own. Without this guard the second contact
    // silently re-pointed `_dragPointer` at itself: the handler got a second
    // `beginDrag` mid-gesture, and the FIRST pointer's up then matched
    // nothing, so neither `commitDrag` nor `cancel` ever fired for it and
    // whatever it had armed was orphaned for the rest of the session.
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    await a.moveBy(const Offset(20, 0));

    // A whole second gesture, start to finish, INSIDE the first one.
    final b = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await b.moveBy(const Offset(9, 9));
    await b.up();

    expect(
      handler.log,
      <String>['begin(100.0,100.0)', 'update(120.0,100.0|20.0,0.0)'],
      reason: 'the second pointer contributed nothing at all — not a begin, '
          'not an update, not a commit',
    );

    await a.moveBy(const Offset(10, 0));
    await a.up();

    expect(handler.log.where((e) => e.startsWith('begin')), hasLength(1));
    expect(handler.log.where((e) => e.startsWith('commit')), hasLength(1));
    expect(handler.log.last, 'commit(130.0,100.0)');
    expect(handler.log, isNot(contains('cancel')));
  });

  testWidgets('a second pointer that STAYS DOWN still cannot preempt the '
      'live gesture: the first keeps its route to the very last update', (
    tester,
  ) async {
    // THE OTHER HALF OF THE PIN, and the one the deferral could plausibly
    // break. The test above proves a second gesture that starts AND finishes
    // inside the first contributes nothing; this proves the same while B is
    // still physically on the glass for the whole of A's gesture — which is
    // the state the deferral map now holds, and therefore the state in which
    // a careless "adopt it" would re-point the route mid-drag and orphan A's
    // preview exactly as the original bug did.
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(500, 400), pointer: 2);

    // B moves REPEATEDLY while A is live. Not one of these may reach the
    // handler, and none may divert A's route.
    await b.moveBy(const Offset(40, 40));
    await a.moveBy(const Offset(20, 0));
    await b.moveBy(const Offset(40, 40));
    await a.moveBy(const Offset(10, 0));

    expect(
      handler.log,
      <String>[
        'begin(100.0,100.0)',
        'update(120.0,100.0|20.0,0.0)',
        'update(130.0,100.0|10.0,0.0)',
      ],
      reason: "B is deferred, not routed: A's updates are contiguous and "
          'B contributed none of them',
    );

    await a.up();
    // A committed at its OWN last position, uncontaminated by B.
    expect(handler.log[3], 'commit(130.0,100.0)');
    expect(handler.log.where((e) => e.startsWith('commit')), hasLength(1));

    await b.up();
    await tester.pump();
  });

  testWidgets('a deferred second pointer is ADOPTED when the route falls '
      'free — it is not dead for the rest of its life', (tester) async {
    // THE REGRESSION THE GUARD ITSELF INTRODUCED. `_dragPointer` is only ever
    // assigned on pointer-DOWN, and a refused pointer's down is already
    // spent — so a pointer dropped outright could never be routed again. A
    // scrubs, B lands, A lifts and frees the route, and B — still on the
    // glass — dragged and released into a dead zone: its events matched
    // neither `_dragPointer` nor `_panPointer`, so no begin, no update, no
    // commit, no click. The single-gesture rule is about not running two
    // gestures AT ONCE; it was never a reason to blackhole the second one
    // after the first has properly ended.
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    await a.moveBy(const Offset(20, 0));

    final b = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await b.moveBy(const Offset(10, 10)); // deferred: tracked, not routed
    expect(
      handler.log.where((e) => e.startsWith('begin')),
      hasLength(1),
      reason: 'still exactly one live gesture',
    );

    await a.up();

    // A's commit came first and B's begin came after it — never interleaved,
    // and B begins where the finger ACTUALLY is (510,410), not where it
    // landed (500,400), because its moves were tracked while it waited.
    expect(handler.log.sublist(2), <String>[
      'commit(120.0,100.0)',
      'begin(510.0,410.0)',
    ]);

    // And from here B is an ordinary routed gesture, in full.
    await b.moveBy(const Offset(0, -30));
    await b.up();
    expect(handler.log.sublist(4), <String>[
      'update(510.0,380.0|0.0,-30.0)',
      'commit(510.0,380.0)',
    ]);
    expect(handler.log, isNot(contains('cancel')));
  });

  testWidgets('a deferred pointer that lifts before adoption is forgotten '
      'cleanly — no begin, and therefore no commit or cancel owed to it', (
    tester,
  ) async {
    // The contract is "exactly one of commitDrag/cancel PER beginDrag", not
    // one per pointer. A pointer that was never begun must leave with
    // nothing, and — the part worth pinning — must not linger in the
    // deferral map to be adopted by a LATER gesture's end, which would fire
    // a `beginDrag` for a finger that is no longer touching anything.
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(500, 400), pointer: 2);
    await b.up(); // gone before A ever ends
    await a.up();

    expect(handler.log, <String>['begin(100.0,100.0)', 'commit(100.0,100.0)']);
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
