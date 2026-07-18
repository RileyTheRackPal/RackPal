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

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
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

Widget _app() => MaterialApp(
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

// Demo front-face devices: UPS-1 @U1 (2U), AMP-1 @U4 (2U), SW-1 @U7 (1U).
Offset _ampCentre(WidgetTester tester) => _centreOf(tester, 4, 2);
Offset _swCentre(WidgetTester tester) => _centreOf(tester, 7, 1);

Future<void> _ctrlTap(WidgetTester tester, Offset at) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tapAt(at);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

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
}
