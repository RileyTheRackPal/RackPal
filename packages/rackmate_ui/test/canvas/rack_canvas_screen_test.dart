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

/// Whether [id] is currently rendering as a MOVE-DRAG source — docs/04 §3.3
/// step 1's 30 % in-place fade.
///
/// `RenderDeviceBox`'s boolean `dragSource` flag became the nullable
/// `fadeOpacity` when §3.6's compaction preview needed the same in-place
/// fade at 25 % ("current positions dimmed to 25%"): two booleans would have
/// needed a precedence rule between them for a combination that cannot
/// happen. These tests therefore ask about the drag's specific opacity
/// rather than "is it faded at all", which keeps them able to tell the two
/// features apart.
bool _isDragSource(WidgetTester tester, String id) =>
    _render(tester, id).fadeOpacity == RenderDeviceBox.dragSourceOpacity;

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
  // A REALISTIC WINDOW, required as of the rack-configuration stage. The
  // screen's layout is now `Row(palette 280 | canvas | inspector 320)`
  // (docs/04 §1's four columns), so the default 800x600 test surface leaves
  // the canvas ~198 logical pixels — narrower than the rack's own 267-unit
  // scene width, and narrow enough that `_focusCanvas`'s click at (300, 400)
  // would land on the INSPECTOR rather than the canvas. docs/04 §1 itself
  // treats anything below 1080px as the (unbuilt) tablet collapse case, so
  // 800x600 was never a supported size for this screen; the tests now say
  // so explicitly rather than depending on a default that happened to work
  // while there were only two columns.
  //
  // Every gesture in this file is already expressed relative to
  // `_canvasOrigin`, so widening the window changes no expectation.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

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

  testWidgets('a move into an occupied range does not move the device', (
    tester,
  ) async {
    // The refusal itself (the device does not move). What the user SEES
    // while and after being refused — the live reason chip, the blocked
    // ghost, the 1.2s linger — is asserted by the §3.3 group at the bottom
    // of this file; this case pins the document-level outcome on its own so
    // a regression in the feedback layer can't mask a regression in the
    // refusal.
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
    await tester.pump(const Duration(milliseconds: 1300)); // drain the linger
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

    testWidgets('double-clicking the 0U-vertical PDU row adds NO device and '
        'says why (AC-044)', (tester) async {
      // P01 is `frontU: 0, rearU: 0, side: zeroUVertical`. The quick-add
      // path used to resolve `deviceH = 0`, pass every range guard
      // vacuously, commit a RailPlacement on the REAR face and announce
      // "Placed PDU-1 at RK-1 U3, rear." — for a device `scene_builder`
      // then declined to draw, so nothing appeared, nothing could be
      // clicked, and the invisible device became the sole selection.
      await tester.pumpWidget(_app());
      await tester.pump();

      final beforeCount = tester.widgetList(find.byType(DeviceBox)).length;

      await tester.enterText(find.byType(TextField), 'Rack PDU');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(
        ListTile,
        'Rack PDU, 0U vertical, 24-outlet',
      );
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList(find.byType(DeviceBox)).length,
        beforeCount,
        reason: 'no device may be placed for a template with no rail '
            'footprint',
      );
      // "Never silently do nothing" — the refusal reaches the user, and it
      // names the real reason rather than blaming rack space.
      expect(find.textContaining('0U occupant'), findsWidgets);
      expect(find.textContaining('No 0U free'), findsNothing);
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

      // SCOPED, NOT COUNTED. This assertion used to read
      // `findsNWidgets(2)` — the palette row's own title plus the floating
      // cursor card's copy of the same display name — and it broke the
      // moment the Staging Bin chip started rendering that string a third
      // time. Relaxing it to 3 would have "fixed" it while proving strictly
      // less: a bare count says nothing about WHICH widgets carry the name,
      // so it passes just as happily when the cursor card stops showing it
      // and some fourth surface starts. Each of the two the step actually
      // claims is now asserted where it lives.
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Blank Panel, 1U'),
        ),
        findsOneWidget,
        reason: 'the palette row keeps its title while its device is lifted',
      );
      expect(
        find.descendant(
          of: find.byKey(kDragCursorCardKey),
          matching: find.text('Blank Panel, 1U'),
        ),
        findsOneWidget,
        reason: 'docs/04 §3.1 step 2: the cursor card names the device',
      );
      // The card floats AT the pointer, which is the other half of this
      // test's own name and was never actually asserted.
      final cardTopLeft = tester.getTopLeft(find.byKey(kDragCursorCardKey));
      expect(cardTopLeft.dx, closeTo(rowCentre.dx + 16, 0.5));
      expect(cardTopLeft.dy, closeTo(rowCentre.dy + 30 + 16, 0.5));

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

  group('moving a placed device, with live feedback (docs/04 §3.3)', () {
    // Demo rack occupancy recap (front face): UPS-1 @U1-U2, AMP-1 @U4-U5,
    // SW-1 @U7 -- free front 1U slots are U3, U6, U8..U12.
    //
    // Every case below drives a REAL down/moveBy/up (or sendKeyEvent)
    // sequence through `CanvasIntentDetector`, never an internal method:
    // what is being tested is precisely that the gesture wiring produces
    // the feedback, so short-circuiting the gesture would test nothing.

    /// Selects AMP-1 (a 2U device at U4-U5 -- move-drag requires the device
    /// to already be selected) and presses the pointer on it, returning the
    /// live gesture.
    Future<TestGesture> grabAmp(WidgetTester tester) async {
      await tester.tapAt(_ampCentre(tester));
      await tester.pump();
      return tester.startGesture(_ampCentre(tester));
    }

    testWidgets('the source device fades to 30% IN PLACE past the 4px '
        'threshold, and returns to full opacity on release (step 1)', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await grabAmp(tester);
      await tester.pump();

      // Pointer down, no movement at all: still a potential click.
      expect(_isDragSource(tester, 'dev-amp'), isFalse);

      // A real move event, but UNDER the 4px slop -- "Nothing until 4 px of
      // movement, so a click still means show details" (§3.1 step 1, which
      // §3.3 step 1 reuses verbatim). This must arm nothing: no fade, no
      // ghost chrome.
      await gesture.moveBy(const Offset(0, -2));
      await tester.pump();
      expect(
        _isDragSource(tester, 'dev-amp'),
        isFalse,
        reason: 'a 2px twitch is a click, not a drag',
      );
      expect(find.text('U4-U5'), findsNothing); // no RU-range chip yet

      await gesture.moveBy(const Offset(0, -86)); // total 88 = 4U up -> U8-U9
      await tester.pump();

      // Past the threshold: the source is now the 30%-opacity vacated-U
      // placeholder, and it has NOT itself moved -- the ghost is what
      // follows the cursor.
      final render = _render(tester, 'dev-amp');
      expect(render.fadeOpacity, RenderDeviceBox.dragSourceOpacity);
      // ...and that flag actually reaches the PIXELS: the whole device is
      // composited through one `saveLayer` carrying 30% alpha. Asserted at
      // the paint level, not just as state, so a regression that stopped
      // honouring the flag in `paint()` cannot pass this test.
      expect(
        render,
        paints..something((symbol, args) {
          if (symbol != #saveLayer) return false;
          final paint = args[1] as Paint;
          return (paint.color.a - RenderDeviceBox.dragSourceOpacity).abs() <
              1 / 255;
        }),
      );
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(4, 2).top, 0.5),
        reason: 'the source stays put mid-drag, showing the vacated U',
      );
      // No OTHER device is dimmed -- this is a per-device flag, not a
      // canvas-wide one.
      expect(_isDragSource(tester, 'dev-ups'), isFalse);
      expect(_isDragSource(tester, 'dev-sw'), isFalse);

      await gesture.up();
      await tester.pump();

      expect(_isDragSource(tester, 'dev-amp'), isFalse);
      // ...and the move really did commit, at the previewed U8.
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(8, 2).top, 0.5),
      );
    });

    testWidgets('the live RU-range chip tracks the snapped target U while '
        'dragging (step 3, shared with §3.1)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await grabAmp(tester);
      await gesture.moveBy(const Offset(0, -88)); // 4U up: U4-U5 -> U8-U9
      await tester.pump();
      expect(find.text('U8-U9'), findsOneWidget);

      // Drag one more U up and the chip re-snaps -- proof it is recomputed
      // per frame from the live evaluation, not captured once at grab.
      await gesture.moveBy(const Offset(0, -22));
      await tester.pump();
      expect(find.text('U9-U10'), findsOneWidget);
      expect(find.text('U8-U9'), findsNothing);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('dragging onto an occupied range shows the reason chip LIVE '
        '(mid-drag), and release is a no-op with the chip persisting 1.2s '
        '(step 3)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await grabAmp(tester);
      final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

      // 3U down: AMP (2U) would land at U1-U2, straight onto UPS-1.
      await gesture.moveBy(const Offset(0, 66));
      await tester.pump();

      // THE HEART OF THIS STAGE: the conflict is reported DURING the drag,
      // before any release -- the exact feedback move-drag previously had
      // none of. Wording is `findBlockingOccupant`'s, i.e. identical to
      // what the palette drag and the keyboard nudge report.
      expect(find.textContaining('Occupied by UPS-1'), findsWidgets);

      await gesture.up();
      await tester.pump();

      // Blocked release is a no-op...
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(beforeTop, 0.5),
      );
      // ...the source is immediately back to full opacity (the pointer is
      // up; only the ghost/chip linger)...
      expect(_isDragSource(tester, 'dev-amp'), isFalse);
      // ...the chip persists right after the blocked release...
      expect(find.textContaining('Occupied by UPS-1'), findsWidgets);

      // ...and clears once the 1.2s linger elapses.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.textContaining('Occupied by UPS-1'), findsNothing);
    });

    testWidgets('Esc mid-drag reverts: no command runs, the device returns '
        'to full opacity at its original U, and the later pointer-up '
        'cannot resurrect the move (step 4)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final gesture = await grabAmp(tester);
      final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

      // A perfectly VALID target (U8-U9 is free) -- so if anything commits,
      // it is because Esc failed, not because the drop was refused anyway.
      await gesture.moveBy(const Offset(0, -88));
      await tester.pump();
      expect(_isDragSource(tester, 'dev-amp'), isTrue);
      expect(find.text('U8-U9'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Immediately, before the pointer is even released: full opacity, no
      // ghost chrome, device untouched.
      expect(_isDragSource(tester, 'dev-amp'), isFalse);
      expect(find.text('U8-U9'), findsNothing);
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(beforeTop, 0.5),
      );

      // The pointer is still physically down and `CanvasIntentDetector`
      // will still deliver moveBy/up for it -- neither may revive the
      // cancelled move.
      await gesture.moveBy(const Offset(0, -22));
      await tester.pump();
      expect(_isDragSource(tester, 'dev-amp'), isFalse);

      await gesture.up();
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(beforeTop, 0.5),
        reason: 'Esc reverted; the pointer-up must commit nothing',
      );

      // Nothing was ever committed, so undo has nothing of this drag to
      // revert -- the device stays exactly where it started.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(beforeTop, 0.5),
      );
    });

    testWidgets('a device never blocks itself: dragging within its own '
        'occupied range is evaluated as a VALID drop', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // AMP-1 occupies U4-U5. Nudging it up ONE U targets U5-U6, which
      // OVERLAPS its own current U5 -- a self-collision the shared
      // `findBlockingOccupant(exceptId:)` must exclude. (This is the case
      // the deleted `_rangeFreeOnFace` also had to special-case; it is
      // pinned here because consolidating onto the core query is exactly
      // where such an exclusion could have been dropped.)
      final gesture = await grabAmp(tester);
      await gesture.moveBy(const Offset(0, -22)); // 1U up -> U5-U6
      await tester.pump();

      expect(find.text('U5-U6'), findsOneWidget);
      expect(find.textContaining('Occupied by'), findsNothing);

      await gesture.up();
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(5, 2).top, 0.5),
      );
    });

    testWidgets("a new move-drag started during the previous one's 1.2s "
        "blocked linger is not torn down by that previous drag's timer", (
      tester,
    ) async {
      // Regression coverage for a real bug found while wiring this up: the
      // blocked-release `Timer` is keyed to no particular drag, so if a
      // second drag begins inside the 1.2s window, the FIRST drag's timer
      // would still fire and `reset()` the shared controller out from under
      // it -- clearing the live evaluation mid-gesture, which (because the
      // commit gates on `isDragging`) turns the second drag's release into
      // a silent no-op. `_armMovePreview` now cancels it on arm.
      await tester.pumpWidget(_app());
      await tester.pump();

      // Drag 1: blocked (AMP -> U1-U2, onto UPS-1), released.
      final blockedDrag = await grabAmp(tester);
      await blockedDrag.moveBy(const Offset(0, 66));
      await tester.pump();
      await blockedDrag.up();
      await tester.pump();
      expect(find.textContaining('Occupied by UPS-1'), findsWidgets);

      // Drag 2 begins only 300ms later -- well inside drag 1's linger.
      await tester.pump(const Duration(milliseconds: 300));
      final secondDrag = await grabAmp(tester);
      await secondDrag.moveBy(const Offset(0, -88)); // -> U8-U9, free
      await tester.pump();
      expect(find.text('U8-U9'), findsOneWidget);

      // Cross the instant drag 1's timer WOULD have fired at.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(
        _isDragSource(tester, 'dev-amp'),
        isTrue,
        reason: "the stale timer must not end the second drag's preview",
      );
      expect(find.text('U8-U9'), findsOneWidget);

      // ...and the second drag still commits normally.
      await secondDrag.up();
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-amp')).dy,
        closeTo(_canvasOrigin(tester).dy + _geo.deviceRect(8, 2).top, 0.5),
      );
    });

    testWidgets('dragging an UNSELECTED device arms no preview and moves '
        'nothing (select first, then drag)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // Select AMP, then drag SW-1 -- which is NOT selected.
      await tester.tapAt(_ampCentre(tester));
      await tester.pump();
      final swBefore = tester.getTopLeft(_device('dev-sw')).dy;

      final gesture = await tester.startGesture(_swCentre(tester));
      await gesture.moveBy(const Offset(0, -66));
      await tester.pump();

      expect(_isDragSource(tester, 'dev-sw'), isFalse);
      expect(find.textContaining('U'), findsWidgets); // (ruler labels exist)
      expect(_isDragSource(tester, 'dev-amp'), isFalse);

      await gesture.up();
      await tester.pump();
      expect(
        tester.getTopLeft(_device('dev-sw')).dy,
        closeTo(swBefore, 0.5),
      );
    });
  });
}
