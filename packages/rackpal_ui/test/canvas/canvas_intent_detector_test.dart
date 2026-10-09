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
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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

  /// Every token this handler has been handed, in call order — so a test can
  /// assert that a gesture's `update`/`commit`/`cancel` carry the SAME token
  /// its `beginDrag` did, and that a later gesture carries a different one.
  /// That is the property `CanvasGestureToken` exists for; without it an
  /// arbitrating handler cannot tell whose terminal callback it just got.
  final List<CanvasGestureToken> tokens = <CanvasGestureToken>[];

  @override
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  }) {
    lastKinds = sourceKinds;
    tokens.add(gesture);
    log.add('begin(${_f(sceneStart)})');
  }

  @override
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  }) {
    tokens.add(gesture);
    log.add('update(${_f(sceneCurrent)}|${_f(sceneDelta)})');
  }

  @override
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture}) {
    tokens.add(gesture);
    log.add('commit(${_f(sceneEnd)})');
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    tokens.add(gesture);
    log.add('cancel');
  }

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
      reason:
          'the second pointer contributed nothing at all — not a begin, '
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
      reason:
          "B is deferred, not routed: A's updates are contiguous and "
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

  testWidgets('every call of ONE gesture carries ONE token, and the next '
      'gesture carries a different one', (tester) async {
    // THE PROPERTY AN ARBITRATING HANDLER STANDS ON. `CanvasIntentHandler`
    // orders nothing between two gestures' terminal callbacks, so a handler
    // that can REFUSE a begin (the schematic's, while another route holds the
    // canvas) is owed teardowns for both the begin it took and the begin it
    // refused — and with no identity on the callback it has to guess which is
    // which. Every guess loses something: a pending-refusal latch eats the
    // winner's own release, an owner-first latch frees the winner's claim
    // under a pointer that is still down, and a bool cannot count past one.
    //
    // So this asserts what the detector owes: one token per `beginDrag`,
    // repeated verbatim on that gesture's `updateDrag` and its terminal, and
    // never reused by the next gesture.
    final vp = ViewportController();
    addTearDown(vp.dispose);
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final a = await tester.startGesture(const Offset(100, 100));
    await a.moveBy(const Offset(20, 0));
    await a.up();
    expect(handler.log, hasLength(3));
    final first = handler.tokens.toSet();
    expect(
      first,
      hasLength(1),
      reason:
          'begin, update and commit are one gesture and must be told '
          'apart from any other by ONE identity',
    );

    final b = await tester.startGesture(const Offset(300, 300));
    await b.up();
    expect(handler.log, hasLength(5));
    expect(
      handler.tokens.sublist(3).toSet(),
      hasLength(1),
      reason: 'the second gesture is also internally consistent',
    );
    expect(
      handler.tokens.sublist(3).first,
      isNot(same(first.single)),
      reason:
          'a token is minted per gesture — a reused one would let a '
          "stale terminal be mistaken for the live gesture's",
    );
  });

  group('unmounted under a live pointer', () {
    // AN UNMOUNTED DETECTOR IS NOT SILENT — IT IS WORSE THAN SILENT, and
    // the obvious reading of this defect is the wrong one.
    //
    // "A `Listener` that has left the tree receives no more events, so the
    // gesture stalls with its terminal never delivered" is how this was
    // first written up. `GestureBinding` caches the hit-test result AT
    // POINTER-DOWN and dispatches every later move/up/cancel for that
    // pointer against the cached path — it never re-tests, and a detached,
    // disposed render object on that path still holds a live closure onto
    // the `State`. Measured before the fix: `[begin, update]` at the
    // unmount, and `[begin, update, update, commit]` once the finger came
    // up. The gesture did not stall. It COMMITTED, out of a widget that
    // had left the tree.
    //
    // That is also why the leaked exclusivity claim this was first scoped
    // for is not what these tests assert: the stale `commitDrag` released
    // it on the way past, which is exactly why nobody ever saw it.
    //
    // Reachable without a test harness: the schematic swaps its whole
    // canvas subtree for the empty-sheet panel when `scene.symbols` goes
    // empty, which an undo from another view can do under a live pointer.
    // `schematic_gesture_infrastructure_test.dart` drives exactly that.

    testWidgets("the routed gesture gets its cancel, and the engine's stale "
        'move and up reach NOBODY', (tester) async {
      // BOTH HALVES, AND NEITHER IS SUFFICIENT ALONE. Delivering `cancel`
      // without unrouting the pointer leaves the stale `commitDrag` to
      // arrive after it; unrouting without delivering `cancel` leaves the
      // handler holding per-drag state for a gesture that now really will
      // never speak again.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final handler = _RecordingHandler();
      await tester.pumpWidget(_host(vp, handler));

      final a = await tester.startGesture(const Offset(100, 100));
      await a.moveBy(const Offset(20, 0));
      expect(handler.log, <String>[
        'begin(100.0,100.0)',
        'update(120.0,100.0|20.0,0.0)',
      ]);

      // The detector leaves the tree with the pointer still down.
      await tester.pumpWidget(const SizedBox.shrink());

      expect(handler.log, <String>[
        'begin(100.0,100.0)',
        'update(120.0,100.0|20.0,0.0)',
        'cancel',
      ]);
      expect(
        handler.tokens.last,
        same(handler.tokens.first),
        reason:
            'the terminal is attributed to the begin it belongs to, or '
            "an arbitrating handler cannot tell it from another gesture's",
      );

      // THE ASSERTION THE PROBE ABOVE IS ABOUT. The engine keeps dispatching
      // this pointer down its cached hit path; not one of those events may
      // reach the handler, because the gesture is over.
      await a.moveBy(const Offset(30, 0));
      await a.up();
      await tester.pump();
      expect(
        handler.log,
        hasLength(3),
        reason:
            'an unrouted pointer matches no branch: no second update, '
            'and above all no commit for a release on a canvas that is gone',
      );
    });

    testWidgets('a DEFERRED pointer is owed nothing — the contract is one '
        'terminal per beginDrag, not per pointer', (tester) async {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final handler = _RecordingHandler();
      await tester.pumpWidget(_host(vp, handler));

      final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
      // B is refused a `beginDrag` and merely remembered (the deferral map).
      final b = await tester.startGesture(const Offset(500, 400), pointer: 2);
      await b.moveBy(const Offset(10, 10));
      expect(handler.log.where((e) => e.startsWith('begin')), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        handler.log,
        <String>['begin(100.0,100.0)', 'cancel'],
        reason:
            'exactly ONE cancel — B never received a beginDrag, so it '
            'is owed no terminal and inventing one would describe a '
            'gesture the handler has never heard of',
      );

      await a.up();
      await b.up();
      await tester.pump();
      expect(handler.log, hasLength(2));
    });

    testWidgets('an idle detector owes nothing, and neither does one whose '
        'gesture already ended', (tester) async {
      // THE OTHER HALF, and the one a careless "always cancel on dispose"
      // gets wrong: a second terminal for a gesture that already committed
      // reaches a handler which has torn its state down and — on the rack,
      // whose adapter drops the token — would run that teardown a second
      // time against whatever gesture came next.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final handler = _RecordingHandler();
      await tester.pumpWidget(_host(vp, handler));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(handler.log, isEmpty);

      final vp2 = ViewportController();
      addTearDown(vp2.dispose);
      final handler2 = _RecordingHandler();
      await tester.pumpWidget(_host(vp2, handler2));
      final a = await tester.startGesture(const Offset(100, 100));
      await a.up();
      expect(handler2.log, <String>[
        'begin(100.0,100.0)',
        'commit(100.0,100.0)',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        handler2.log,
        hasLength(2),
        reason:
            'the gesture ended on its own terms; the unmount adds no '
            'second terminal to it',
      );
    });
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

  // ── a Windows pinch (`#1037`) ──────────────────────────────────────────
  //
  // The Windows embedder drives `onPointerPanZoom*` from DirectManipulation,
  // and hands over DM's CONTENT TRANSFORM as-is: `pan` is that transform's
  // translation column. DM scales its content about a centre of its own
  // choosing, so a pure pinch arrives with `pan = (1 - scale) * centre`:
  // translation that only exists to hold DM's centre still. Applied as a
  // real pan and then zoomed about the cursor on top, the pinch had two
  // pivots and drifted off toward the canvas origin.
  //
  // The streams below are built the way the embedder builds them: position
  // fixed at the gesture's start, `pan` cumulative from that start.

  Offset dmPan(Offset centre, double scale) => centre * (1 - scale);

  for (final (name, centre) in <(String, Offset)>[
    ('DM centred on the cursor', const Offset(400, 300)),
    ('DM centred somewhere else', const Offset(520, 260)),
  ]) {
    testWidgets('a Windows pinch zooms about the cursor ($name)', (
      tester,
    ) async {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      await tester.pumpWidget(_host(vp, null));

      final p = TestPointer(1, PointerDeviceKind.trackpad);
      const cursor = Offset(400, 300);
      final sceneUnderCursor = vp.screenToScene(const DPt(400, 300));
      await tester.sendEventToBinding(p.panZoomStart(cursor));
      for (final s in <double>[1.25, 1.5, 2]) {
        await tester.sendEventToBinding(
          p.panZoomUpdate(cursor, pan: dmPan(centre, s), scale: s),
        );
      }
      await tester.sendEventToBinding(p.panZoomEnd());

      expect(vp.scale, closeTo(2, 1e-6));
      final after = vp.sceneToScreen(sceneUnderCursor);
      expect(
        Offset(after.x, after.y),
        offsetMoreOrLessEquals(cursor, epsilon: 1e-4),
        reason:
            'what was under the cursor when the pinch began is still '
            'under it when the pinch ends',
      );
    });
  }

  testWidgets('a pinch latches its gesture, and the next gesture pans again', (
    tester,
  ) async {
    final vp = ViewportController();
    addTearDown(vp.dispose);
    await tester.pumpWidget(_host(vp, null));

    final p = TestPointer(1, PointerDeviceKind.trackpad);
    const cursor = Offset(400, 300);
    await tester.sendEventToBinding(p.panZoomStart(cursor));
    // Pans first, which DM can report before it has recognised the pinch.
    await tester.sendEventToBinding(
      p.panZoomUpdate(cursor, pan: const Offset(10, 0)),
    );
    expect(vp.transform.storage[12], closeTo(10, 1e-6));
    await tester.sendEventToBinding(
      p.panZoomUpdate(cursor, pan: const Offset(30, 20), scale: 2),
    );
    // Back at scale 1 inside the same gesture: still a pinch, so its
    // translation is still DM's and still not a pan.
    await tester.sendEventToBinding(
      p.panZoomUpdate(cursor, pan: const Offset(60, 40)),
    );
    await tester.sendEventToBinding(p.panZoomEnd());
    expect(vp.scale, closeTo(1, 1e-6));
    expect(
      vp.transform.storage[12],
      closeTo(10, 1e-6),
      reason: 'only the pan from before the pinch was recognised moved it',
    );
    expect(vp.transform.storage[13], closeTo(0, 1e-6));

    // A fresh gesture is a two-finger pan again.
    await tester.sendEventToBinding(p.panZoomStart(cursor));
    await tester.sendEventToBinding(
      p.panZoomUpdate(cursor, pan: const Offset(0, 25)),
    );
    await tester.sendEventToBinding(p.panZoomEnd());
    expect(vp.transform.storage[13], closeTo(25, 1e-6));
  });

  // ── the secondary button (CR-102, `#231`/`#232`) ──────────────────────
  //
  // Right-drag is reserved for the context menu, "a platform expectation on
  // desktop". Until the three doors were built nothing bound it, so the
  // secondary button fell through to `beginDrag` like any other and armed a
  // marquee on empty canvas and a MOVE on an already-selected device.
  //
  // THESE LIVE HERE AND NOT ON THE SCREEN, and the reason is worth the
  // paragraph. The screen-level version of this case CANNOT FAIL: opening
  // the menu is itself a modal route that swallows the subsequent pointer
  // moves, so a right-drag does not move a device whether or not the button
  // is consumed. Two drafts of it passed with the fix reverted before that
  // was noticed. The property is about the DETECTOR, and this is the only
  // level at which it can be observed.

  testWidgets('a secondary press NEVER reaches the handler', (tester) async {
    final vp = ViewportController();
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final g = await tester.startGesture(
      const Offset(100, 100),
      buttons: kSecondaryButton,
    );
    await g.moveTo(const Offset(300, 220));
    await g.up();
    await tester.pumpAndSettle();

    expect(
      handler.log,
      isEmpty,
      reason: 'the secondary button must not begin, update or commit a drag',
    );
  });

  testWidgets('a secondary press is reported to onSecondaryTap, in BOTH '
      'scene and global coordinates', (tester) async {
    final vp = ViewportController();
    final seen = <(DPt, Offset)>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 800,
            height: 600,
            child: CanvasIntentDetector(
              viewport: vp,
              handler: _RecordingHandler(),
              onSecondaryTap: (scene, global) => seen.add((scene, global)),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    final g = await tester.startGesture(
      const Offset(120, 140),
      buttons: kSecondaryButton,
    );
    await g.up();
    await tester.pumpAndSettle();

    expect(seen, hasLength(1));
    // The host is top-left aligned, so local == global here, and the
    // viewport is identity until something pans it.
    expect(seen.single.$2, const Offset(120, 140));
    expect(
      seen.single.$1.x,
      closeTo(vp.screenToScene(const DPt(120, 140)).x, 1e-9),
    );
  });

  testWidgets('a view with NO context menu still gets no drag from it', (
    tester,
  ) async {
    // The callback is optional and the consumption is not conditional on it.
    // A view with nothing bound wants right-click to do NOTHING, not to arm
    // a marquee.
    final vp = ViewportController();
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final g = await tester.startGesture(
      const Offset(50, 50),
      buttons: kSecondaryButton,
    );
    await g.moveTo(const Offset(400, 400));
    await g.up();
    await tester.pumpAndSettle();

    expect(handler.log, isEmpty);
  });

  testWidgets('the PRIMARY button still routes a drag, so the guard is not '
      'swallowing everything', (tester) async {
    // The vacuity check on the three cases above: if the button test were
    // wrong in the other direction they would all pass over a detector that
    // routes nothing at all.
    final vp = ViewportController();
    final handler = _RecordingHandler();
    await tester.pumpWidget(_host(vp, handler));

    final g = await tester.startGesture(const Offset(100, 100));
    await g.moveTo(const Offset(300, 220));
    await g.up();
    await tester.pumpAndSettle();

    expect(handler.log, isNotEmpty);
  });
}
