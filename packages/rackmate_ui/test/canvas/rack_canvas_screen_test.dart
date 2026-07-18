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
// tests can aim gestures at real device rects (identity viewport at load ⇒
// scene coords == screen coords, Scaffold body pinned at the origin).
const _geo = RackGeometry(12);

Offset _centreOf(int ru, int deviceH) {
  final rect = _geo.deviceRect(ru, deviceH);
  return Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2);
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
Offset get _ampCentre => _centreOf(4, 2);
Offset get _swCentre => _centreOf(7, 1);

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

    await tester.tapAt(_ampCentre);
    await tester.pump();
    expect(_render(tester, 'dev-amp').selected, isTrue);
    expect(_render(tester, 'dev-ups').selected, isFalse);

    // A plain click replaces: selecting SW deselects AMP.
    await tester.tapAt(_swCentre);
    await tester.pump();
    expect(_render(tester, 'dev-sw').selected, isTrue);
    expect(_render(tester, 'dev-amp').selected, isFalse);

    // Click far from any device → selection clears.
    await tester.tapAt(const Offset(500, 400));
    await tester.pump();
    expect(_render(tester, 'dev-sw').selected, isFalse);
  });

  testWidgets('Ctrl+click toggles membership (add then subtract)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre); // replace-select AMP
    await tester.pump();
    await _ctrlTap(tester, _swCentre); // add SW
    expect(_render(tester, 'dev-amp').selected, isTrue);
    expect(_render(tester, 'dev-sw').selected, isTrue);

    await _ctrlTap(tester, _ampCentre); // subtract AMP
    expect(_render(tester, 'dev-amp').selected, isFalse);
    expect(_render(tester, 'dev-sw').selected, isTrue);
  });

  testWidgets('dragging a selected device moves it, snapped to a free U', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre); // AMP must be selected to be draggable
    await tester.pump();
    final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

    // Drag up 88px: AMP (U4–U5) → U8–U9 (free; SW is only U7). 88px = 4U.
    final gesture = await tester.startGesture(_ampCentre);
    await gesture.moveBy(const Offset(0, -88));
    await gesture.up();
    await tester.pump();

    final afterTop = tester.getTopLeft(_device('dev-amp')).dy;
    expect(afterTop, lessThan(beforeTop)); // moved up
    // Snapped exactly to U8's top edge (proves the inverse RU geometry ran).
    expect(afterTop, closeTo(_geo.deviceRect(8, 2).top, 0.5));
  });

  testWidgets('a move into an occupied range is refused silently', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tapAt(_ampCentre);
    await tester.pump();
    final beforeTop = tester.getTopLeft(_device('dev-amp')).dy;

    // Drag AMP (2U) down so its target would overlap UPS at U1–U2.
    final gesture = await tester.startGesture(_ampCentre);
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
    await tester.tapAt(_ampCentre);
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
    final gesture = await tester.startGesture(_ampCentre);
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

    await tester.tapAt(_ampCentre);
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
}
