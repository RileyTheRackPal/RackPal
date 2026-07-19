// Widget tests for the M1 command-routed editing loop wired into
// RackCanvasScreen: click-to-select, Ctrl+click toggle, click-empty clear,
// drag-to-move (real MoveDeviceCommand + RU snap), Delete (real
// RemoveDeviceCommand), and Ctrl+Z/Ctrl+Shift+Z undo/redo — including that
// undo restores BOTH the document and the selection.
//
// These drive real gestures/keys against the screen's own DocumentController
// and SelectionController; correctness is observed through the on-screen
// device render objects (position + the `selected` chrome flag), never by
// reaching into private state. Geometry is reconstructed with a matching
// RackGeometry(12) since the screen's demo rack is 12U.
//
// COORDINATE NOTE (M1 catalog/palette stage): the screen now lays out a
// 280 px palette panel + a 1 px divider to the LEFT of the canvas (see
// rack_canvas_screen.dart's `build`), so the canvas's own top-left is no
// longer the Scaffold body's origin. Every gesture/expectation below is
// expressed in SCENE coordinates and translated through `_canvasOrigin`
// (the live top-left of the `CanvasIntentDetector`) rather than assuming
// screen == scene, which is what let this file survive that layout change
// unchanged in spirit.

import 'package:flutter/gestures.dart'
    show kDoubleTapMinTime, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

// The screen's demo rack is 12U; these mirror its device placements so the
// tests can aim gestures at real device rects.
const _geo = RackGeometry(12);

/// The canvas's live top-left in screen space — the palette panel now sits
/// to its left, so scene (0, 0) is no longer the Scaffold body's origin.
Offset _canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CanvasIntentDetector));

Offset _centreOf(WidgetTester tester, int ru, int deviceH) {
  final rect = _geo.deviceRect(ru, deviceH);
  final scene = Offset(
    (rect.left + rect.right) / 2,
    (rect.top + rect.bottom) / 2,
  );
  return _canvasOrigin(tester) + scene;
}

/// The screen top-left a 1U device sitting at [ru] would have — used by
/// the caret tests to check WHERE a newly placed device landed, without
/// needing to know its (freshly-minted, unpredictable) entity id.
Offset _topLeftOf1U(WidgetTester tester, int ru) {
  final rect = _geo.deviceRect(ru, 1);
  return _canvasOrigin(tester) + Offset(rect.left, rect.top);
}

Finder _device(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byType(DeviceBox),
);

// The leaf render object (not the FocusableActionDetector's MouseRegion that
// sits above it), located by its own deviceId getter.
RenderDeviceBox _render(WidgetTester tester, String id) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().firstWhere(
      (r) => r.deviceId == id,
    );

Widget _app({Clock clock = const SystemClock()}) => MaterialApp(
  home: Scaffold(
    body: RackCanvasScreen(measurer: _FakeMeasurer(), clock: clock),
  ),
);

// Demo front-face devices: UPS-1 @U1 (2U), AMP-1 @U4 (2U), SW-1 @U7 (1U).
Offset _ampCentre(WidgetTester tester) => _centreOf(tester, 4, 2);
Offset _swCentre(WidgetTester tester) => _centreOf(tester, 7, 1);

/// The canvas's own [FocusNode] does not stay in a widget-test-visible
/// spot, so tests confirm "the canvas has focus" indirectly, by observing
/// keyboard actions actually taking effect (a click on empty canvas already
/// grabs focus via `_handleClick`/`CanvasIntentDetector`'s existing
/// `_onBeginDrag`, matching production use — a real user always clicks the
/// canvas at least once before typing at it).
Future<void> _focusCanvas(WidgetTester tester) async {
  await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 400));
  await tester.pump();
}

Future<void> _ctrlTap(WidgetTester tester, Offset at) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tapAt(at);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// Searches the palette for [query] and returns the on-screen centre of
/// the matching row's `ListTile` — the drag-from-palette tests' arm point
/// (docs/04 §3.1 step 1: "pointer down on a palette row").
Future<Offset> _paletteRowCentre(
  WidgetTester tester,
  String query,
  String listTileText,
) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
  final row = find.widgetWithText(ListTile, listTileText);
  expect(row, findsOneWidget);
  return tester.getCenter(row);
}

/// Every palette-drag test's initial pointer-down ALSO reaches the row's
/// pre-existing `GestureDetector.onDoubleTap` recognizer (the `Listener`
/// arming the drag never consumes the pointer, by design — see
/// device_palette_panel.dart's header). That recognizer starts its own
/// internal "is a second tap coming?" timer on every down, which the test
/// binding requires to have fired (or been cancelled) before a test ends.
/// A plain drag/cancel test never produces a second tap, so this flushes
/// that unrelated internal timer past `kDoubleTapTimeout` at the end of
/// each such test — a widget-test-environment detail, not anything this
/// stage's own code needs to manage in production.
Future<void> _settleDoubleTapRecognizer(WidgetTester tester) =>
    tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

void main() {
  testWidgets('clicking a device selects it; clicking empty canvas clears', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre(tester));
    await tester.pump();
    expect(_render(tester, 'dev-amp').selected, isTrue);
    expect(_render(tester, 'dev-ups').selected, isFalse);

    // A plain click replaces: selecting SW deselects AMP.
    await tester.tapAt(_swCentre(tester));
    await tester.pump();
    expect(_render(tester, 'dev-sw').selected, isTrue);
    expect(_render(tester, 'dev-amp').selected, isFalse);

    // Click far from any device (well inside the canvas, past the
    // palette) → selection clears.
    await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 400));
    await tester.pump();
    expect(_render(tester, 'dev-sw').selected, isFalse);
  });

  testWidgets('Ctrl+click toggles membership (add then subtract)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre(tester)); // replace-select AMP
    await tester.pump();
    await _ctrlTap(tester, _swCentre(tester)); // add SW
    expect(_render(tester, 'dev-amp').selected, isTrue);
    expect(_render(tester, 'dev-sw').selected, isTrue);

    await _ctrlTap(tester, _ampCentre(tester)); // subtract AMP
    expect(_render(tester, 'dev-amp').selected, isFalse);
    expect(_render(tester, 'dev-sw').selected, isTrue);
  });

  testWidgets('dragging a selected device moves it, snapped to a free U', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre(tester)); // AMP must be selected to drag
    await tester.pump();
    final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

    // Drag up 88px: AMP (U4–U5) → U8–U9 (free; SW is only U7). 88px = 4U.
    final gesture = await tester.startGesture(_ampCentre(tester));
    await gesture.moveBy(const Offset(0, -88));
    await gesture.up();
    await tester.pump();

    final afterTop = tester.getTopLeft(_device('dev-amp')).dy;
    expect(afterTop, lessThan(beforeTop)); // moved up
    // Snapped exactly to U8's top edge (proves the inverse RU geometry ran).
    expect(
      afterTop,
      closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(8, 2).top, 0.5),
    );
  });

  testWidgets('a move into an occupied range is refused silently', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre(tester));
    await tester.pump();
    final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

    // Drag AMP (2U) down so its target would overlap UPS at U1–U2.
    final gesture = await tester.startGesture(_ampCentre(tester));
    await gesture.moveBy(const Offset(0, 66)); // ~3U down → U1-ish, occupied
    await gesture.up();
    await tester.pump();

    // Refused: the device stays exactly where it was.
    expect(
      tester.getTopLeft(_device('dev-amp')).dy,
      closeTo(beforeTop, 0.5),
    );
  });

  testWidgets('Delete removes the selection; Ctrl+Z restores device AND '
      'selection; then move+undo restores the ruIndex', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    // Select + delete.
    await tester.tapAt(_ampCentre(tester));
    await tester.pump();
    expect(_device('dev-amp'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_device('dev-amp'), findsNothing);

    // Ctrl+Z restores the whole device and the selection it had.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_device('dev-amp'), findsOneWidget);
    expect(_render(tester, 'dev-amp').selected, isTrue);

    // Now a move, then undo, restores the original ruIndex (position).
    final originalTop = tester.getTopLeft(_device('dev-amp')).dy;
    final gesture = await tester.startGesture(_ampCentre(tester));
    await gesture.moveBy(const Offset(0, -88));
    await gesture.up();
    await tester.pump();
    expect(tester.getTopLeft(_device('dev-amp')).dy, lessThan(originalTop));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      tester.getTopLeft(_device('dev-amp')).dy,
      closeTo(originalTop, 0.5),
    );
  });

  testWidgets('Ctrl+Shift+Z redoes an undone delete', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre(tester));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_device('dev-amp'), findsNothing);

    // Undo brings it back…
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_device('dev-amp'), findsOneWidget);

    // …Ctrl+Shift+Z deletes it again.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_device('dev-amp'), findsNothing);
  });

  group('palette placement (docs/09-roadmap.md M1 checklist #6)', () {
    testWidgets('double-clicking a palette row adds a real device to the '
        'rack and selects it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      // X01 (Blank Panel, 1U) is a small, unambiguous row to search for.
      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.pumpAndSettle();

      final row = find.widgetWithText(ListTile, 'Blank Panel, 1U');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();

      final afterCount = tester.widgetList(find.byType(DeviceBox)).length;
      expect(afterCount, beforeCount + 1);

      // The new device is the sole selection (docs/04 §3.1 step 6).
      final selected = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where((r) => r.selected)
          .toList();
      expect(selected, hasLength(1));
    });

    testWidgets('placing then undoing removes the placed device', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'Blank Panel, 1U');
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList(find.byType(DeviceBox)).length,
        beforeCount + 1,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(tester.widgetList(find.byType(DeviceBox)).length, beforeCount);
    });
  });

  group('insertion caret + quick-add at the caret (docs/04 §3.2/§3.4)', () {
    testWidgets("arrow keys move the caret; quick-add places at the "
        "caret's position (not lowest-free-U), and the caret advances "
        'past it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester); // canvas focus + empty selection

      // The demo rack's free front-face 1U slots are U3, U6, U8..U12 (UPS-1
      // @U1-2, AMP-1 @U4-5, SW-1 @U7 occupy the rest). The caret's smart
      // default is the LOWEST free 1U slot, U3 — pressing Up 3 times moves
      // it to U6, a DIFFERENT free slot, so placing there rather than at
      // U3 (which stays free) is proof the caret — not the lowest-free-U
      // fallback — drove this placement.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // Quick-add via the SEARCH BOX Enter path — the one new trigger this
      // stage adds. Typing focuses the search field, which takes Flutter
      // focus AWAY from the canvas; this is exactly the scenario
      // `_placeFromCatalog`'s `stickyCaret` deviation exists for.
      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final u6Top = _topLeftOf1U(tester, 6);
      final matchingU6 = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where(
            (r) => (r.localToGlobal(Offset.zero) - u6Top).distance < 0.5,
          )
          .toList();
      expect(
        matchingU6,
        hasLength(1),
        reason: "the newly placed device should sit at U6, the caret's "
            'moved-to position',
      );

      // U3 (the lowest-free-U fallback position) must remain untouched —
      // if the fallback had fired instead, THIS is where the device would
      // have landed.
      final u3Top = _topLeftOf1U(tester, 3);
      final matchingU3 = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where(
            (r) => (r.localToGlobal(Offset.zero) - u3Top).distance < 0.5,
          )
          .toList();
      expect(matchingU3, isEmpty);

      // "the caret advances past it" (docs/04 §3.2). The just-placed
      // device is now the sole selection (docs/04 §3.1 step 6, pre-
      // existing behaviour) — the caret conceptually doesn't exist while
      // something is selected (docs/04 §3.4), so clear the selection first
      // (click empty canvas, which also keeps canvas focus) exactly as a
      // keyboard-and-mouse user naturally would between placements; this
      // reactivates the caret at its ADVANCED position rather than
      // silently falling back to lowest-free-U for this next placement.
      await _focusCanvas(tester);
      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // U6 (this placement's 1U) + 1 = U7 — occupied by SW-1, so this
      // placement fails loudly rather than silently colliding, which is
      // itself the proof the caret really did advance to U7 (a lowest-
      // free-U fallback would have quietly succeeded at U3 instead).
      // Shown twice on purpose (the status line AND a SnackBar both
      // display a placement failure — see `_placeFromCatalog`), hence
      // `findsWidgets` rather than `findsOneWidget` here.
      expect(find.textContaining('Occupied by SW-1'), findsWidgets);
    });

    testWidgets('Home/End move the caret to U1 / the rack top when nothing '
        'is selected', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final u12Top = _topLeftOf1U(tester, 12);
      final atU12 = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where(
            (r) => (r.localToGlobal(Offset.zero) - u12Top).distance < 0.5,
          )
          .toList();
      expect(atU12, hasLength(1));
    });
  });

  group('keyboard nudge with a selection (docs/04 §3.4)', () {
    testWidgets('Up/Down nudge the selected device by 1U', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_swCentre(tester)); // select SW-1 (U7, 1U)
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-sw')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(8, 1).top, 0.5),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-sw')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(6, 1).top, 0.5),
      );
    });

    testWidgets('PgUp/PgDn nudge by 10U, clamped to the rack extent', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_swCentre(tester)); // SW-1 at U7 (1U)
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      // U7 + 10 = U17, clamped to the 12U rack's top (maxRuIndexFor(1)=12).
      expect(
        tester.getTopLeft(_device('dev-sw')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(12, 1).top, 0.5),
      );
    });

    testWidgets('Home/End nudge the selection to its lowest/highest '
        'fitting position', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(_ampCentre(tester)); // AMP-1, 2U
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      // Highest fitting position for a 2U device in a 12U rack: U11-U12.
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(11, 2).top, 0.5),
      );
    });

    testWidgets('a nudge into an occupied range shakes and reports '
        '"Blocked by X" without moving the device', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // AMP-1 (U4-5, 2U) down one U lands it at U3-U4 (free) …
      await tester.tapAt(_ampCentre(tester));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final afterFirstMove = tester.getTopLeft(_device('dev-amp')).dy;
      expect(
        afterFirstMove,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(3, 2).top, 0.5),
      );

      // … but one MORE U down targets U2-U3, which overlaps UPS-1's U1-U2.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(afterFirstMove, 0.5), // unchanged — never silently stops
      );
      expect(find.textContaining('Blocked by UPS-1'), findsOneWidget);
    });

    testWidgets(
      'two nudges LESS than the merge window apart coalesce into one '
      'undo entry (docs/03 §5.4\'s "arrow-key nudges")',
      (tester) async {
        // A `FixedClock` (the previous version of this test) always
        // returns the SAME instant, so `UndoStack.push`'s merge check
        // (`now.difference(top.at) < mergeWindow`) always compared `0 <
        // mergeWindow` — true for ANY positive window, even an absurd one.
        // `MutableClock` lets this test advance a REAL duration between
        // the two nudges, so it actually exercises the 400ms boundary
        // rather than merely never having a nonzero delta to fail on.
        final clock = MutableClock(DateTime.utc(2026, 7, 18));
        await tester.pumpWidget(_app(clock: clock));
        await tester.pump();

        await tester.tapAt(_swCentre(tester)); // SW-1, U7, 1U
        await tester.pump();
        final originalTop = tester.getTopLeft(_device('dev-sw')).dy;

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        // Real elapsed time, but still comfortably inside the 400ms merge
        // window.
        clock.advance(const Duration(milliseconds: 200));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(
          tester.getTopLeft(_device('dev-sw')).dy,
          closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(9, 1).top, 0.5),
        );

        // Both nudges landed inside the merge window — a SINGLE undo must
        // revert BOTH steps at once, landing back at the ORIGINAL U7, not
        // U8.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          tester.getTopLeft(_device('dev-sw')).dy,
          closeTo(originalTop, 0.5),
        );
      },
    );

    testWidgets(
      'two nudges MORE than the merge window apart produce two separate '
      'undo entries',
      (tester) async {
        final clock = MutableClock(DateTime.utc(2026, 7, 18));
        await tester.pumpWidget(_app(clock: clock));
        await tester.pump();

        await tester.tapAt(_swCentre(tester)); // SW-1, U7, 1U
        await tester.pump();
        final originalTop = tester.getTopLeft(_device('dev-sw')).dy;

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        final afterFirstNudge = tester.getTopLeft(_device('dev-sw')).dy;
        expect(
          afterFirstNudge,
          closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(8, 1).top, 0.5),
        );

        // Past the 400ms merge window — the second nudge must start a NEW
        // undo entry rather than coalescing into the first.
        clock.advance(const Duration(milliseconds: 500));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(
          tester.getTopLeft(_device('dev-sw')).dy,
          closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(9, 1).top, 0.5),
        );

        // A FIRST undo reverts ONLY the second nudge (U8 -> U9 undone),
        // landing back at U8 — proving the two nudges are two SEPARATE
        // entries, not one coalesced move.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          tester.getTopLeft(_device('dev-sw')).dy,
          closeTo(afterFirstNudge, 0.5),
        );

        // A SECOND undo reverts the first nudge too, landing back at the
        // ORIGINAL U7 — confirming there really were two entries.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(
          tester.getTopLeft(_device('dev-sw')).dy,
          closeTo(originalTop, 0.5),
        );
      },
    );
  });

  group('drag from palette to rails (docs/04 §3.1, added this stage)', () {
    // Demo rack occupancy recap (front face): UPS-1 @U1-U2, AMP-1 @U4-U5,
    // SW-1 @U7 — free front 1U slots are U3, U6, U8..U12.

    testWidgets('dragging a palette row into a free U commits a real '
        'device there, becomes the sole selection, and announces it', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      final rowCentre = await _paletteRowCentre(
        tester,
        'Blank Panel',
        'Blank Panel, 1U',
      );

      // Arm + lift (past the 4px slop) + cross into the canvas widget, then
      // refine onto U3's exact centre (a free 1U front slot) before
      // releasing.
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(320, 0));
      await tester.pump();
      await gesture.moveTo(_centreOf(tester, 3, 1));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final afterCount = tester.widgetList(find.byType(DeviceBox)).length;
      expect(afterCount, beforeCount + 1);

      // Landed exactly at U3 (the RU the last live evaluation snapped to).
      final matchingU3 = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where(
            (r) =>
                (r.localToGlobal(Offset.zero) - _topLeftOf1U(tester, 3))
                    .distance <
                0.5,
          )
          .toList();
      expect(matchingU3, hasLength(1));

      // Sole selection (docs/04 §3.1 step 6) + status announcement.
      final selected = tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .where((r) => r.selected)
          .toList();
      expect(selected, hasLength(1));
      expect(find.textContaining('Placed'), findsWidgets);
      expect(find.textContaining('U3'), findsWidgets);

      // The source row is no longer dimmed once the drag has ended.
      final stillDimmed = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.widgetWithText(ListTile, 'Blank Panel, 1U'),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity == 0.40);
      expect(stillDimmed, isEmpty);
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('dragging onto an occupied range blocks the drop -- release '
        'is a no-op, with a reason chip that persists 1.2s', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      final rowCentre = await _paletteRowCentre(
        tester,
        'Blank Panel',
        'Blank Panel, 1U',
      );

      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(320, 0));
      await tester.pump();
      // AMP-1 occupies U4-U5 (front) -- aim at U4's centre.
      await gesture.moveTo(_centreOf(tester, 4, 1));
      await tester.pump();

      expect(find.textContaining('Occupied by AMP-1'), findsWidgets);

      await gesture.up();
      await tester.pump();

      // Blocked release is a no-op: no device added.
      expect(tester.widgetList(find.byType(DeviceBox)).length, beforeCount);
      // The reason chip persists immediately after the blocked release...
      expect(find.textContaining('Occupied by AMP-1'), findsWidgets);

      // ...and clears once the 1.2s linger elapses.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.textContaining('Occupied by AMP-1'), findsNothing);
    });

    testWidgets('Esc cancels a palette drag cleanly -- no command runs and '
        'the source row un-dims', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      final rowCentre = await _paletteRowCentre(
        tester,
        'Blank Panel',
        'Blank Panel, 1U',
      );

      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(320, 0));
      await tester.pump();
      await gesture.moveTo(_centreOf(tester, 3, 1)); // a perfectly valid spot
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // The row is no longer dimmed -- the cancel took effect immediately,
      // before the pointer was ever released.
      final stillDimmed = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.widgetWithText(ListTile, 'Blank Panel, 1U'),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity == 0.40);
      expect(stillDimmed, isEmpty);

      // Releasing the still-down pointer now does nothing -- Esc already
      // unsubscribed it from the global pointer router.
      await gesture.up();
      await tester.pump();
      expect(tester.widgetList(find.byType(DeviceBox)).length, beforeCount);
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('releasing outside the canvas entirely is a no-op (no '
        'Staging Bin exists -- SCOPE DECISION)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      final rowCentre = await _paletteRowCentre(
        tester,
        'Blank Panel',
        'Blank Panel, 1U',
      );

      // Past the 4px slop (lifted) but staying well inside the 280px
      // palette panel -- never crosses into the canvas widget's bounds.
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tester.widgetList(find.byType(DeviceBox)).length, beforeCount);
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('the cursor card floats at the pointer before canvas entry, '
        'and the source row dims to 40%', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final rowCentre = await _paletteRowCentre(
        tester,
        'Blank Panel',
        'Blank Panel, 1U',
      );

      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30)); // past slop, still in palette
      await tester.pump();

      // Two "Blank Panel, 1U" texts now exist: the palette row's own title
      // AND the floating cursor card's copy of the same display name.
      expect(find.text('Blank Panel, 1U'), findsNWidgets(2));

      final dimmed = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.widgetWithText(ListTile, 'Blank Panel, 1U'),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity == 0.40);
      expect(dimmed, isNotEmpty);

      await gesture.up(); // clean up -- outside canvas, so a plain no-op.
      await tester.pump();
      await _settleDoubleTapRecognizer(tester);
    });
  });
}
