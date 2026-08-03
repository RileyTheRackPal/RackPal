// M2-F PHASE 1 — the infrastructure a connect gesture needs before there is
// a connect gesture. Four things, none of them a feature:
//
//   1. the intent handler is a FIELD, so a rebuild between press and release
//      cannot swallow the click (it could, and did);
//   2. the exclusivity arbiter is load-bearing — a second gesture is refused,
//      the refusal is REPORTED, and a refused gesture's teardown does not
//      hand the canvas away from the pointer that is still holding it. Every
//      one of those terminal callbacks is attributed by the `beginDrag` token
//      it carries, so NONE of it depends on which pointer happens to lift
//      first or on how many gestures were refused;
//   3. every keyboard action is a real gated `Action`, so `Esc` can be
//      DECLINED and fall through instead of being consumed;
//   4. the sheet is hit-tested with `SymbolHitTest`, whose pin tolerance is
//      docs/05 §11.6's 12 SCREEN px — a figure that has to be converted by
//      the live zoom, not stored as a constant — and whose GLOBAL
//      pin-beats-body precedence answers a "which pin" question, not the
//      "which device" one this screen asks: a body that CONTAINS the point
//      wins, or zooming out hands every click to the nearest pin on the
//      sheet.
//
// WHY THESE ARE PINNED AT THE MECHANISM AND NOT AT THE SYMPTOM. Every one of
// them is invisible while the screen has one gesture: a rebuilt handler
// loses a click only in the window between two pointer events, a leaked
// claim only refuses the NEXT gesture, and a swallowed `Esc` only matters to
// the layer that never got it. Each test below therefore asserts the thing
// that would have to be true for the defect to be gone — handler identity, a
// second refusal after a teardown, an ancestor's counter — and only then the
// user-visible consequence.

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

/// An `Esc` binding installed ABOVE the screen, so "the screen declined the
/// key" is observable as "somebody else got it" rather than as an absence.
final class _OuterCancelIntent extends Intent {
  const _OuterCancelIntent();
}

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 9)),
    );
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  /// Mounts the screen. [outerEscapes], when given, is incremented by an
  /// `Esc` binding that sits ABOVE it — see [_OuterCancelIntent].
  Future<void> pump(WidgetTester tester, {VoidCallback? onOuterEscape}) async {
    Widget screen = SchematicCanvasScreen(
      measurer: const FakeMeasurer(),
      controller: controller,
    );
    if (onOuterEscape != null) {
      screen = Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _OuterCancelIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _OuterCancelIntent: CallbackAction<_OuterCancelIntent>(
              onInvoke: (_) {
                onOuterEscape();
                return null;
              },
            ),
          },
          child: screen,
        ),
      );
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
    // The viewport frames the sheet in a post-frame callback.
    await tester.pumpAndSettle();
  }

  List<DiagramOp> painted(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops;

  int wiresDrawn(WidgetTester tester) =>
      painted(tester).whereType<OpPolyline>().length;

  Matrix4 matrixOf(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .debugSceneToScreen!;

  /// The live scene→screen scale, read off the matrix the painter used, so
  /// the test's arithmetic and the screen's can never be measuring different
  /// zooms.
  double scaleOf(WidgetTester tester) => matrixOf(tester).storage[0];

  /// A scene point in global (screen) coordinates — the same conversion
  /// `schematic_canvas_screen_test.dart` uses.
  Offset toScreen(WidgetTester tester, DPt p) {
    final m = matrixOf(tester).storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * p.x + m[4] * p.y + m[12],
          m[1] * p.x + m[5] * p.y + m[13],
        );
  }

  RenderedSymbol symbolOf(String designator) {
    final device = deviceNamed(doc, designator);
    return reference.symbols.firstWhere((s) => s.id == device.id.v);
  }

  DPt centreOf(String designator) {
    final symbol = symbolOf(designator);
    return DPt(
      (symbol.bodyRect.left + symbol.bodyRect.right) / 2,
      (symbol.bodyRect.top + symbol.bodyRect.bottom) / 2,
    );
  }

  /// The one live `CanvasIntentHandler` the detector is pointing at RIGHT
  /// NOW. Read fresh every time deliberately: the whole subject of the first
  /// test is whether this is the same object across a rebuild.
  CanvasIntentHandler handlerOf(WidgetTester tester) => tester
      .widget<CanvasIntentDetector>(find.byType(CanvasIntentDetector))
      .handler!;

  /// ONE mouse for a whole test, reused for every hover and for the zoom.
  ///
  /// Not `tester.createGesture(...).addPointer()` per hover, which is what
  /// the sibling screen test does: that sends a `PointerAddedEvent` each
  /// time, and `MouseTracker` asserts on a second add for a device that was
  /// never removed. A real mouse is added once and then moves.
  TestPointer mouse() => TestPointer(90, PointerDeviceKind.mouse);

  /// `Ctrl`+scroll about [pivot] — the app's own zoom, not a poke at the
  /// controller, so the scale under test is one a user can actually reach.
  Future<void> zoomAbout(
    WidgetTester tester,
    TestPointer pointer,
    Offset pivot,
    double scrollDy,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.hover(pivot));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, scrollDy)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  /// An `Alt`-hover at [at], and how many wires the sheet drew because of it.
  ///
  /// THE OBSERVABLE FOR EVERY HIT-TEST CASE. §11.4's transient focus runs
  /// through the same `_deviceAt` the click does, and it draws exactly the
  /// hovered device's links — so "4 wires" means "MTX-1 was hit" and "0"
  /// means nothing was, with no reach into private state.
  Future<int> altHoverWires(
    WidgetTester tester,
    TestPointer pointer,
    Offset at,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.pumpAndSettle();
    final drawn = wiresDrawn(tester);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    return drawn;
  }

  /// An `Alt`-hover at [at], and the HUD headline it produced.
  ///
  /// The headline NAMES THE DESIGNATOR (`resolveDrawnScope`: "Alt-hover:
  /// AMP-1 · 1 hop · 3 cables"), so it identifies the device the query
  /// returned exactly, rather than by arithmetic over how many wires that
  /// device happens to have.
  Future<String?> altHoverHeadline(
    WidgetTester tester,
    TestPointer pointer,
    Offset at,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.pumpAndSettle();
    final headline = tester
        .widget<DomainFilterBar>(find.byType(DomainFilterBar))
        .headline;
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    return headline;
  }

  group('1 — the handler is a field, not a build-time construction', () {
    testWidgets('a rebuild BETWEEN press and release keeps the same handler '
        'object, so the click still lands', (tester) async {
      // THE DEFECT, exactly. `_SchematicClickHandler` was constructed inside
      // `_canvas()`, which `build` calls, and `CanvasIntentDetector` re-reads
      // `widget.handler` on every pointer event (canvas_intent.dart:164, 190,
      // 201, 218, 233) rather than capturing it at pointer-down. So a rebuild
      // between the press and the release handed `commitDrag` to an object
      // that had never seen `beginDrag`: `_start` was null, `commitDrag`
      // returned on its first line, and the click vanished with no selection,
      // no status line and nothing to see. `_onExit`'s `setState` and every
      // document epoch reach that window.
      //
      // THE IDENTITY ASSERTION IS THE POINT. "The click landed" is the
      // symptom and would pass again the moment some unrelated change made
      // the rebuild land elsewhere in the frame; `same(...)` fails the
      // instant the construction moves back inside `build`.
      await pump(tester);
      final before = handlerOf(tester);

      final press = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      // A DOCUMENT CHANGE FROM ELSEWHERE — an undo, another view — which is
      // the realistic source of a mid-press rebuild. BLK-1 is the fixture's
      // port-less device: it draws no symbol, so this cannot move the sheet
      // under the pointer and the test is about the handler and nothing else.
      final blank = deviceNamed(doc, kFixturePortlessDesignator);
      controller.run(
        RenameEntityCommand(
          targetKind: RenameTargetKind.device,
          id: blank.id,
          from: blank.name,
          to: 'RENAMED MID-PRESS',
          now: DateTime.utc(2026, 7, 28, 10),
          actor: 'test',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        handlerOf(tester),
        same(before),
        reason:
            'the detector must still be pointing at the object that '
            'received `beginDrag` — a handler built in `build()` is a new '
            'object here, and the release below would find `_start == null`',
      );

      await press.up();
      await tester.pumpAndSettle();

      // The click selected MTX-1, which `F` then proves by drawing exactly
      // its four links (§11.4; the fixture wires MTX-1 four times).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason:
            'the press+release was a click on MTX-1 and must have '
            'selected it — a swallowed click leaves nothing for `F` to focus',
      );
    });
  });

  group('2 — the exclusivity arbiter is load-bearing', () {
    testWidgets('a second gesture is REFUSED and the refusal is reported, and '
        "its teardown does not free the winner's claim", (tester) async {
      // THE THREE RULES `rack_canvas_screen.dart`'s arbiter encodes, asserted
      // in the order they can fail. The second gesture is driven through
      // `CanvasIntentDetector.handler` — the public, pointer-agnostic seam —
      // because Phase 1 has ONE pointer route and the detector's own
      // single-gesture guard means no second POINTER can deliver a
      // `beginDrag` today. That is a statement about the routing, not about
      // the arbiter: Phase 2's connect gesture is armed on a pin and arrives
      // exactly like this, which is the case the arbiter exists for. (See
      // this file's sibling `canvas_exclusivity_test.dart`, which drives the
      // rack's two REAL routes against each other.)
      await pump(tester);
      final handler = handlerOf(tester);

      // A: a real pointer, which claims the canvas.
      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      // B: a second gesture, refused. ITS OWN TOKEN — a second route mints
      // its own identity exactly as `CanvasIntentDetector` does, and that
      // token is what the teardown below is attributed by.
      final b = CanvasGestureToken();
      handler.beginDrag(
        centreOf('AMP-1'),
        const {PointerDeviceKind.mouse},
        gesture: b,
      );
      await tester.pump();
      expect(
        find.textContaining('One drag at a time'),
        findsOneWidget,
        reason:
            'a refusal is REPORTED, never silent (docs/04 §3.4) — the '
            'user pressed something and got nothing back',
      );

      // B's teardown. `CanvasIntentHandler`'s contract owes one terminal
      // callback per `beginDrag`, refused or not, and this one must be a
      // no-op: A's pointer is still physically down.
      handler.cancel(gesture: b);
      await tester.pump();

      // The status line auto-clears after its hold, which is what makes the
      // NEXT refusal observable as a new event rather than as the old one
      // still on screen.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.textContaining('One drag at a time'), findsNothing);

      // THE ASSERTION THAT MATTERS. If B's teardown had released the claim,
      // this third attempt would be GRANTED — silently, and on top of a live
      // pointer. It must be refused again.
      final c = CanvasGestureToken();
      handler.beginDrag(
        centreOf('AMP-1'),
        const {PointerDeviceKind.mouse},
        gesture: c,
      );
      await tester.pump();
      expect(
        find.textContaining('One drag at a time'),
        findsOneWidget,
        reason:
            "the winner still holds the canvas: a refused gesture's "
            'teardown may not release a claim it never took',
      );
      handler.cancel(gesture: c);
      await tester.pump();

      // And the winner is untouched by any of it — its own release still
      // resolves as the click it always was, on ITS device.
      await winner.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason:
            'MTX-1 has four links and AMP-1 has three — a refused '
            'gesture that had re-pointed the live one would show three',
      );
    });

    testWidgets('the WINNER may terminate FIRST, with a refusal still '
        'outstanding — its click still lands and its claim comes back', (
      tester,
    ) async {
      // THE ORDERING HALF, and nothing in `CanvasIntentHandler` decides it:
      // two gestures are live, and which pointer lifts first is the user's
      // business. The test above delivers the refused teardown first; this
      // one delivers the WINNER's first, which is the case a
      // pending-refusal LATCH gets exactly backwards — `_consumeRefusal()`
      // returned true for the winner's own `commitDrag`, so the click was
      // swallowed (no selection, no status line, nothing) and `_owned` stayed
      // set, deadening the sheet until the refused gesture finally tore down.
      //
      // With a token per `beginDrag` the two are disjoint lookups and the
      // order stops existing as a question.
      await pump(tester);
      final handler = handlerOf(tester);

      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      final refused = CanvasGestureToken();
      handler.beginDrag(
        centreOf('AMP-1'),
        const {PointerDeviceKind.mouse},
        gesture: refused,
      );
      await tester.pump();
      expect(find.textContaining('One drag at a time'), findsOneWidget);

      // THE WINNER LIFTS WHILE THE REFUSAL IS STILL OUTSTANDING.
      await winner.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason:
            "the winner's press+release was a click on MTX-1 and must "
            'have selected it — a refusal latch eats it instead',
      );

      // The refused gesture's owed teardown, arriving late. It must not
      // disturb anything: it never took the claim, and the claim it might
      // otherwise free now belongs to whatever comes next.
      handler.cancel(gesture: refused);
      await tester.pump();

      // Let the refusal's status line lapse, so a line found after the tap
      // below is a NEW refusal rather than that one still on screen.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.textContaining('One drag at a time'), findsNothing);

      // And the canvas is genuinely free — the winner's `commitDrag` gave it
      // back rather than leaving `_owned` set behind the swallowed click.
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('One drag at a time'),
        findsNothing,
        reason:
            'a claim left set by a swallowed terminal refuses every '
            'later press for the rest of the session',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 3, reason: 'AMP-1 (three links) is selected');
    });

    testWidgets('TWO refusals outstanding at once do not collapse into one — '
        "the second teardown still cannot free the winner's claim", (
      tester,
    ) async {
      // ONE STEP PAST WHAT A BOOL CAN HOLD. `_refusedPending` was a single
      // latch, so a second refused begin set an already-set flag: the first
      // teardown spent it and the SECOND fell through, found the winner's
      // state and ran the reset — clearing `_start`, dropping the winner's
      // click and calling `release()` under a pointer that was still
      // physically down. That is verbatim the property the test above claims
      // ("a refused gesture's teardown may not release a claim it never
      // took"), false one refusal further out.
      await pump(tester);
      final handler = handlerOf(tester);

      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      final first = CanvasGestureToken();
      final second = CanvasGestureToken();
      handler
        ..beginDrag(
          centreOf('AMP-1'),
          const {PointerDeviceKind.mouse},
          gesture: first,
        )
        ..beginDrag(
          centreOf('SW-1'),
          const {PointerDeviceKind.mouse},
          gesture: second,
        );
      await tester.pump();
      expect(find.textContaining('One drag at a time'), findsOneWidget);

      handler
        ..cancel(gesture: first)
        ..cancel(gesture: second);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // (a) the canvas is STILL the winner's — a third gesture is refused.
      final third = CanvasGestureToken();
      handler.beginDrag(
        centreOf('SW-1'),
        const {PointerDeviceKind.mouse},
        gesture: third,
      );
      await tester.pump();
      expect(
        find.textContaining('One drag at a time'),
        findsOneWidget,
        reason:
            "two refused teardowns must not add up to the winner's "
            'release — its pointer is still down',
      );
      handler.cancel(gesture: third);
      await tester.pump();

      // (b) and the winner's own release is intact.
      await winner.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason:
            'MTX-1 was clicked and selected; a reset run by the second '
            'refused teardown would have thrown that click away',
      );
    });

    testWidgets('a refusal whose teardown never arrives cannot be spent on a '
        "LATER gesture's terminal callback", (tester) async {
      // THE LATCH THAT OUTLIVES ITS OWN GESTURE. `rack_canvas_screen.dart`
      // clears `_dragRefused` as the FIRST line of `_onBeginDrag`
      // (`:1743`) for exactly this reason; the schematic's port dropped that
      // line, so a refusal recorded once and never torn down sat waiting to
      // swallow the terminal callback of an unrelated later gesture — and
      // THAT gesture's claim then leaked, refusing every press afterwards
      // with no way back but switching tabs.
      //
      // A token cannot be spent on a gesture it does not name, which is what
      // makes this hold without a clearing line at all.
      await pump(tester);
      final handler = handlerOf(tester);

      // A refusal is recorded against a live winner, and is then abandoned:
      // its owed teardown never comes.
      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();
      handler.beginDrag(
        centreOf('AMP-1'),
        const {PointerDeviceKind.mouse},
        gesture: CanvasGestureToken(),
      );
      await tester.pump();
      await winner.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // A perfectly ordinary later click. It must be granted AND it must
      // keep its own terminal callback.
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('One drag at a time'),
        findsNothing,
        reason: 'the abandoned refusal belongs to a gesture that is over',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        3,
        reason:
            'AMP-1 has three links — a stale refusal that ate this '
            "click's `commitDrag` leaves nothing selected and nothing to "
            'focus',
      );

      // And the claim really did come back, so the sheet is still live.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 4);
    });

    testWidgets("a refused gesture's own MOVES are not added to the winner's "
        'travel, so the winner is still a click', (tester) async {
      // THE SAME MISATTRIBUTION, ONCE PER FRAME INSTEAD OF ONCE PER GESTURE.
      // `updateDrag` used to be gated on "does this handler own the canvas",
      // which is true while the WINNER owns it — so a refused gesture's
      // movement accumulated into `_travelPx` and pushed the winner past the
      // 4 px click slop. The winner's release then resolved as a drag and
      // selected nothing.
      await pump(tester);
      final handler = handlerOf(tester);

      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      // The refused gesture travels far more than the 4 screen px click slop
      // (in scene units, at any zoom this test runs).
      final refused = CanvasGestureToken();
      handler
        ..beginDrag(
          centreOf('AMP-1'),
          const {PointerDeviceKind.mouse},
          gesture: refused,
        )
        ..updateDrag(centreOf('SW-1'), const DPt(400, 400), gesture: refused);
      await tester.pump();
      handler.cancel(gesture: refused);

      await winner.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason:
            "the winner's pointer never moved, so its release is a click "
            'on MTX-1 — travel belongs to the gesture that travelled',
      );
    });

    testWidgets('the claim is RELEASED, not leaked: a second gesture after a '
        'completed one is accepted, with no refusal anywhere', (tester) async {
      // THE FAILURE THE ARBITER ITSELF COULD INTRODUCE, and the one the
      // rack's own exclusivity suite says to test for explicitly: a latch
      // left stuck true refuses EVERY later interaction for the rest of the
      // session — worse than the bug it fixes, and invisible to any test
      // that performs one gesture.
      await pump(tester);

      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('One drag at a time'),
        findsNothing,
        reason: 'the first click gave the canvas back on `commitDrag`',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        3,
        reason:
            'the SECOND click really selected AMP-1 (three links) — a '
            'leaked claim would have refused it and left MTX-1 selected',
      );
    });

    testWidgets('a cancelled gesture gives the canvas back too', (
      tester,
    ) async {
      // The other terminal path. `CanvasIntentDetector` delivers `cancel`
      // (not `commitDrag`) whenever a route push or the platform takes the
      // pointer away, and a release that only happens on the happy path is a
      // leak with a longer fuse.
      await pump(tester);

      final gesture = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();

      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('One drag at a time'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 3, reason: 'AMP-1 was selectable afterwards');
    });
  });

  group('2b — the one teardown, when the document changes underneath', () {
    testWidgets('a focus scope whose device is deleted from elsewhere is '
        'dropped AND said out loud', (tester) async {
      // `_invalidateLivePreviews`, the schematic's copy of the rack's one
      // teardown. `_focused` and `_altHovered` are DEVICE IDS held across
      // frames; an undo, or an edit from another view, can delete the device
      // either of them names. The `_focused` prune already existed as an
      // inline comprehension that dropped the id and said NOTHING — a focus
      // mode ending on its own with no explanation, which is the silent
      // no-op docs/04 §3.4 forbids.
      await pump(tester);
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 4, reason: 'focus mode is live on MTX-1');

      controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
      await tester.pumpAndSettle();

      expect(
        wiresDrawn(tester),
        0,
        reason:
            'the scope named a device that is gone, so it is dropped '
            'rather than repaired — the question was about that device',
      );
      expect(
        find.textContaining('Focus cancelled'),
        findsOneWidget,
        reason:
            'the teardown NAMES what it took away (the habit '
            "`rack_canvas_screen.dart`'s own teardown has)",
      );
    });
  });

  group('2c — the canvas subtree goes away under a live pointer', () {
    testWidgets('a press whose canvas is unmounted under it does NOT commit '
        'when the finger comes up — and the sheet is not deadened either', (
      tester,
    ) async {
      // THE DEFECT PHASE 1 TRACKED, WITH THE MECHANISM IT GOT WRONG.
      // `CanvasIntentDetector` had no `dispose`, and that was written up as
      // "a widget unmounted mid-press never delivers its terminal, so the
      // claim leaks". `GestureBinding` caches the hit-test result at
      // POINTER-DOWN and keeps dispatching that pointer's move/up down the
      // cached path forever — a detached, disposed `RenderPointerListener`
      // still holds a live closure onto its `State`. So the terminal DID
      // arrive: measured, `[begin, update, update, commit]`. The claim was
      // released by that stale commit, which is exactly why nobody ever saw
      // it leak.
      //
      // What the user got instead was a COMMIT on a canvas that no longer
      // existed — here a selection at a scene point on a sheet that had
      // been replaced and put back, and with Phase 3's connect gesture
      // behind the same field a `ConnectPortsCommand` with an undo entry.
      //
      // IT IS NOT A TEST-ONLY PATH, which is why the unmount here is driven
      // by a document edit rather than by pumping a new tree. This screen
      // swaps its whole canvas subtree for `_EmptySheet` the moment
      // `scene.symbols` goes empty, and an undo — or an edit from another
      // view — can empty it while a pointer is down. One transaction, so it
      // is ONE undo entry and one call puts the sheet back.
      await pump(tester);
      final symbolBearing = kFixtureDesignators
          .where((d) => d != kFixturePortlessDesignator)
          .map((d) => deviceNamed(doc, d).id)
          .toList();

      final press = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      controller.transact(LabelKey.removeDevice, (tx) {
        for (final id in symbolBearing) {
          tx.add(RemoveDeviceCommand(id: id));
        }
      });
      await tester.pumpAndSettle();

      expect(
        find.byType(CanvasIntentDetector),
        findsNothing,
        reason:
            'the premise: with no symbol left the sheet shows the empty '
            'panel and the detector really has left the tree — without '
            'this the test would be asserting nothing',
      );

      // The sheet comes back, and with it a DIFFERENT detector, which never
      // saw the press. The pointer has been physically down throughout.
      controller.undoLast();
      await tester.pumpAndSettle();
      expect(find.byType(CanvasIntentDetector), findsOneWidget);

      await press.up();
      await tester.pumpAndSettle();

      // THE ASSERTION THAT MATTERS. The release lands on the same scene
      // point MTX-1 occupies, so a stale commit selects it and `F` draws its
      // four links. It must select NOTHING: that gesture was ended when its
      // canvas was, and this pointer is no longer routed anywhere.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        0,
        reason:
            'the press was cancelled when the sheet it was made on went '
            'away — the up that follows is not a click on the sheet that '
            'came back',
      );

      // AND THE SHEET IS NOT DEADENED. The other half of the fix: the
      // handler was told the gesture ended, so it is not still holding the
      // canvas for a pointer that is now unrouted. An ordinary click works.
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pump();
      expect(
        find.textContaining('One drag at a time'),
        findsNothing,
        reason:
            'the unmounted detector gave the route back rather than '
            'holding it for a gesture nothing can end',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        wiresDrawn(tester),
        4,
        reason: 'a fresh click selects MTX-1 and `F` focuses its four links',
      );
    });
  });

  group('3 — the actions are gated, so a declined key falls through', () {
    testWidgets('`Esc` with nothing to cancel reaches the layer ABOVE this '
        'screen; with something to cancel it does not', (tester) async {
      // THE ONLY MECHANISM THAT MAKES A LAYERED KEY POSSIBLE.
      // `Action.consumesKey` is true by default and `toKeyEventResult` maps
      // that to `handled` regardless of what the body does, so the
      // `CallbackAction` that used to sit here consumed `Esc` on every
      // frame — including the frames where `_onEscape` did nothing at all.
      // `consumesKey => false` is not the escape hatch either
      // (`skipRemainingHandlers` halts dispatch just as dead); only
      // `isActionEnabled == false` yields `ignored`.
      //
      // docs/04 §8 makes `Esc` a ladder — "cancel drag, exit mode, clear
      // selection" — and a rung can only decline it by being disabled. The
      // ancestor binding below stands in for the rung underneath this screen
      // (a dialog, the shell, and in Phase 2 the connect mode above it).
      var outer = 0;
      await pump(tester, onOuterEscape: () => outer++);

      // Nothing focused, nothing selected: this screen has no meaning for
      // `Esc`, so it must not eat it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        outer,
        1,
        reason:
            'a disabled action yields `ignored` and the event continues '
            'up the chain',
      );

      // Now give the screen something to cancel. Two rungs of its own:
      // focus first, then the selection (§11.4).
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 4, reason: 'focus mode is live');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(wiresDrawn(tester), 0, reason: 'the first Esc left focus mode');
      expect(
        outer,
        1,
        reason:
            'THIS Esc was for the screen and must NOT also fire the '
            'layer below — a key that reaches two rungs is as wrong as a '
            'key that reaches none',
      );

      // Second rung: the selection is still there, so this Esc is the
      // screen's too.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(outer, 1);

      // Third: nothing left, so it falls through again.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        outer,
        2,
        reason:
            'the selection was cleared by the previous Esc, so this one '
            "is no longer the screen's",
      );
    });

    testWidgets('the domain and focus keys still work through their gate', (
      tester,
    ) async {
      // The gate must not be a regression dressed as a fix: `1`, `` ` `` and
      // `F` are enabled whenever this screen has focus and no text field
      // does, which is every frame of ordinary use.
      await pump(tester);
      final order = schematicDomainOrder(doc.registries);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      var bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible).map((c) => c.id), [order.first]);

      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.pumpAndSettle();
      bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible), hasLength(bar.chips.length));
    });
  });

  group('4 — the hit test, in SCREEN pixels at every zoom', () {
    // MTX-1's left edge is the one used throughout: the sheet is empty for
    // ~210 diagram units to the left of it (SW-1 ends at x≈780, MTX-1 starts
    // at x≈992), so a point placed outside that edge is near exactly one pin
    // and nothing else. The pin's own drawn circle is the thing distances are
    // measured from — `symbolHitRegions` stores the real ink and the
    // tolerance is slop around it, so the test measures from the circle's
    // edge and not from its centre.
    ({DPt pin, double radius}) leftPinOfMtx() {
      final symbol = symbolOf('MTX-1');
      final port = symbol.allPorts.firstWhere(
        (p) => p.side == SymbolSide.left,
      );
      return (pin: symbolPortCentre(symbol, port), radius: port.size / 2);
    }

    /// A screen point [px] pixels to the LEFT of that pin's drawn circle.
    Offset outsideBy(WidgetTester tester, double px) {
      final target = leftPinOfMtx();
      final scale = scaleOf(tester);
      final scene = DPt(
        target.pin.x - target.radius - px / scale,
        target.pin.y,
      );
      return toScreen(tester, scene);
    }

    testWidgets('a pin is hit at 12 screen px and missed beyond it — at the '
        'framed zoom AND at ~4x it, which a constant tolerance cannot do', (
      tester,
    ) async {
      // THE MUTATION THIS IS AIMED AT. `SymbolHitTestParams.portHitTolerance`
      // is in DIAGRAM UNITS (its own doc says so) and docs/05 §11.6's figure
      // is 12 SCREEN px, so the screen must divide by the live scale. Writing
      // `portHitTolerance: 12` instead is the natural mistake and it is
      // wrong in BOTH directions, which is why both are asserted here:
      //
      //   * zoomed OUT (the framed scale, ≈0.58) 12 screen px is ≈21 diagram
      //     units, so a constant 12 makes the pin UNREACHABLE — the `hit`
      //     case below fails;
      //   * zoomed IN (≈2.5) 12 screen px is ≈5 diagram units, so a constant
      //     12 makes the pin a 29-px-wide target that swallows its
      //     surroundings — the `miss` case below fails.
      //
      // A test at one zoom level cannot see either half.
      await pump(tester);
      final pointer = mouse();

      final framed = scaleOf(tester);
      expect(
        await altHoverWires(tester, pointer, outsideBy(tester, 10)),
        4,
        reason:
            "10 screen px from the pin is inside docs/05 §11.6's 12 px, "
            'so MTX-1 is hit and Alt-hover draws its four links',
      );
      expect(
        await altHoverWires(tester, pointer, outsideBy(tester, 22)),
        0,
        reason:
            '22 screen px is outside the tolerance — the sheet is empty '
            'there and nothing may be hit',
      );

      // Zoom about the pin so it stays put on screen, then repeat the SAME
      // two screen-pixel distances.
      await zoomAbout(tester, pointer, outsideBy(tester, 0), -750);
      final zoomed = scaleOf(tester);
      expect(
        zoomed / framed,
        greaterThan(3),
        reason:
            'the second half of this test is meaningless unless the zoom '
            'really moved',
      );

      expect(
        await altHoverWires(tester, pointer, outsideBy(tester, 10)),
        4,
        reason: 'the tolerance is a SCREEN figure, so 10 px still hits',
      );
      expect(
        await altHoverWires(tester, pointer, outsideBy(tester, 22)),
        0,
        reason:
            '22 screen px is ${(22 / zoomed).toStringAsFixed(1)} diagram '
            'units at this zoom — well inside a constant 12-unit tolerance, '
            'which would wrongly report a hit',
      );
    });

    testWidgets('a pin BEATS the body it sits on, which the old reverse walk '
        'over `scene.hits` could never do', (tester) async {
      // `symbolHitRegions` emits every pin FIRST and the body LAST
      // (symbol_hit_test.dart:190-201). The walk this replaced went BACKWARDS
      // over that list under a comment claiming the opposite ordering, so it
      // met the body first and no pin was ever reachable — which is why
      // `SymbolHitTest` ranks pins and bodies in two passes.
      //
      // Observable without private state: a point 10 px OUTSIDE the body's
      // edge can only be a hit through a pin, because body regions are
      // ranked with no slop at all (strict containment).
      await pump(tester);
      expect(await altHoverWires(tester, mouse(), outsideBy(tester, 10)), 4);
    });

    /// The interior point of [symbol]'s body that lies CLOSEST to a pin
    /// belonging to some OTHER symbol — the most adversarial "which device"
    /// question this sheet can pose, computed rather than guessed.
    ///
    /// Every foreign pin centre is clamped into the body (inset, so the point
    /// is strictly inside and not on the boundary) and the nearest of those
    /// clamped points wins. On this fixture the answer is AMP-1's lower edge
    /// under DIS-1's top pin, ~26 diagram units away, which is inside the pin
    /// tolerance at any scale below ~0.47.
    DPt worstInteriorPoint(RenderedSymbol symbol) {
      const inset = 2.0;
      final r = symbol.bodyRect;
      DPt? best;
      var bestDistance = double.infinity;
      for (final other in reference.symbols) {
        if (other.id == symbol.id) continue;
        for (final port in other.allPorts) {
          final pin = symbolPortCentre(other, port);
          final inside = DPt(
            math.min(math.max(pin.x, r.left + inset), r.right - inset),
            math.min(math.max(pin.y, r.top + inset), r.bottom - inset),
          );
          final d = inside.distanceTo(pin);
          if (d < bestDistance) {
            bestDistance = d;
            best = inside;
          }
        }
      }
      return best!;
    }

    testWidgets('a point INSIDE a body resolves to that body — a neighbour '
        'pin inside the tolerance may not outrank the device under the '
        'cursor', (tester) async {
      // THE BLOCKER. `_deviceAt` used to be `testPoint(...).nodeId`, and
      // `SymbolHitTest`'s pin-beats-body precedence is GLOBAL: EVERY pin on
      // the sheet is ranked with `portHitTolerance` of slop before ANY body
      // is looked at, and bodies are ranked with none
      // (`symbol_hit_test.dart:290-320`). The tolerance is docs/05 §11.6's 12
      // SCREEN px divided by the live scale, so it grows without bound as the
      // user zooms out — ~31 diagram units two notches out of the framed
      // view, 240 at `kMinScale`, by which point it is wider than every
      // symbol in this fixture and body containment is never consulted at
      // all. A click inside AMP-1 selected DIS-1.
      //
      // THE PIN PASS IS NOT WEAKENED, and the test above is what holds that:
      // a point 10 screen px outside MTX-1's body still reaches its edge pin,
      // which is the whole reason pins outrank bodies and is what Phase 2's
      // connect gesture grabs. This asserts the other half — that the rule
      // does not reach across the sheet — and it is asserted for EVERY symbol
      // rather than for the one pair that happens to fail today.
      await pump(tester);
      final pointer = mouse();

      // Zoom out until the tolerance is comfortably wider than the gap
      // between AMP-1's lower edge and DIS-1's nearest pin. This is the app's
      // own Ctrl+scroll, so the scale under test is one a user reaches in two
      // notches.
      await zoomAbout(
        tester,
        pointer,
        tester.getCenter(find.byType(SchematicCanvasBody)),
        375,
      );
      final tolerance = 12 / scaleOf(tester);
      expect(
        tolerance,
        greaterThan(30),
        reason:
            'the test is vacuous unless the pin tolerance is wide enough '
            'to reach a neighbouring symbol',
      );

      for (final designator in kFixtureDesignators) {
        if (designator == kFixturePortlessDesignator) continue; // no symbol
        final symbol = symbolOf(designator);
        final probe = worstInteriorPoint(symbol);
        expect(
          await altHoverHeadline(tester, pointer, toScreen(tester, probe)),
          contains(designator),
          reason:
              'the pointer is strictly inside the body of $designator, '
              'so $designator is the device under it at every zoom — the pin '
              'pass exists so an EDGE PIN stays reachable, not so a '
              'neighbour ${tolerance.toStringAsFixed(0)} units away wins a '
              'click that landed on something else',
        );
      }
    });
  });
}
