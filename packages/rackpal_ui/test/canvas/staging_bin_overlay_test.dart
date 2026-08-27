// Widget tests for the Staging Bin chip (docs/04-rack-editor.md §3.1's
// escape hatch: "Dragging outside any rack shows the ghost at 40 % with a
// `Release to add to Staging Bin` chip") and for its lifecycle inside
// `RackCanvasScreen`.
//
// The feature shipped with NO tests at all, and with three defects that a
// test of any kind would have caught: a leaked `OverlayEntry` (`dispose`
// removed the palette, move and resize overlays but not this one, and so
// did `Esc`), a `Material` inserted into the root overlay with no
// `Positioned` so it stretched across the whole window, and copy promising
// a Staging Bin the build cannot deliver.
//
// Every drag below is a REAL `TestGesture` down/moveTo/up through the
// screen's own global pointer router. Nothing calls an internal method:
// what is under test is precisely that the gesture wiring inserts and
// removes the entry at the right moments.

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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

Widget _app() => MaterialApp(
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

/// See rack_canvas_screen_test.dart's copy: the palette row's pointer-down
/// also reaches a double-tap recognizer whose internal timer the binding
/// requires to have fired before a test ends.
Future<void> _settleDoubleTapRecognizer(WidgetTester tester) =>
    tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

Future<Offset> _paletteRowCentre(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'Blank Panel');
  await tester.pumpAndSettle();
  final row = find.widgetWithText(ListTile, 'Blank Panel, 1U');
  expect(row, findsOneWidget);
  return tester.getCenter(row);
}

Offset _canvasCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(CanvasIntentDetector));

Finder get _chip => find.byKey(StagingBinOverlay.chipKey);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('the chip appears exactly while the drag is outside the canvas', () {
    testWidgets('out of bounds shows it, back in hides it, back out shows '
        'it again', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(_chip, findsNothing, reason: 'no drag in flight');

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);

      // Armed but under the 4px slop: still a click, not a drag.
      await gesture.moveBy(const Offset(0, 2));
      await tester.pump();
      expect(_chip, findsNothing, reason: 'a 2px twitch is not a drag');

      // Past the slop, still inside the 280px palette panel — outside the
      // canvas, which is what the chip is about.
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(_chip, findsOneWidget);

      // Into the canvas: the ghost takes over and the chip goes away —
      // entry and all, so nothing is left listening for a repaint.
      await gesture.moveTo(_canvasCentre(tester));
      await tester.pump();
      expect(_chip, findsNothing, reason: 'over the rack, the ghost speaks');
      expect(find.byType(StagingBinOverlay), findsNothing);

      // Back out again: it returns. (The controller's phase machine goes
      // dragging -> lifted here, which is the transition the overlay reads.)
      await gesture.moveTo(rowCentre + const Offset(0, 32));
      await tester.pump();
      expect(_chip, findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(_chip, findsNothing, reason: 'the drag is over');
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('it names the device being dragged, and says releasing here '
        'will NOT place it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      // docs/09-roadmap.md M1: "an empty Schedule tab that explains it is
      // coming is a lie". A chip reading "Release to add to Staging Bin"
      // over a build where release adds nothing is the same lie, so the
      // copy states the refusal AND names its subject.
      expect(
        find.descendant(
          of: _chip,
          matching: find.textContaining('Blank Panel, 1U'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _chip, matching: find.textContaining('not')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: _chip,
          matching: find.text('Release to add to Staging Bin'),
        ),
        findsNothing,
        reason: 'the build cannot honour that promise; it must not make it',
      );

      await gesture.up();
      await tester.pump();
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('it is a CHIP anchored to the cursor, not a full-screen '
        'panel', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      final cursor = rowCentre + const Offset(0, 30);
      final rect = tester.getRect(_chip);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

      // It shipped with no `Positioned` at all, so its Material filled the
      // window: 1600x1000 of opaque elevated surface flashing over the app
      // on every drag that left the canvas.
      expect(rect.width, lessThan(screen.width / 2));
      expect(rect.height, lessThan(100));

      // THE ANCHOR, IN LITERALS. This used to read `cursor.dx +
      // StagingBinOverlay.cursorOffset.dx` — the same constant the widget's
      // own `Positioned` reads — so the assertion and the production code
      // moved together for every value, `Offset(0, 0)` and
      // `Offset(-9999, -9999)` included, and pinned no position at all.
      expect(rect.topLeft.dx, closeTo(cursor.dx + 16, 0.5));
      expect(rect.topLeft.dy, closeTo(cursor.dy + 64, 0.5));

      // …and the PROPERTY those numbers exist for, checked against the real
      // widget rather than restated as a comment: `cursorOffset`'s doc says
      // it clears the 40px `_CursorCard` at `cursor + (16, 16)`. That card
      // is on screen right now, during this same phase, so the two rects can
      // simply be compared. `Offset(16, 16)` — the collision the constant is
      // there to prevent — fails here as well as above.
      final card = tester.getRect(find.byKey(kDragCursorCardKey));
      expect(
        card.topLeft,
        within(distance: 0.5, from: cursor + const Offset(16, 16)),
        reason: 'the fixture assumes the card sits where its doc says',
      );
      expect(
        rect.overlaps(card),
        isFalse,
        reason: 'the chip is drawn over the cursor card: $rect vs $card',
      );
      expect(
        rect.top,
        greaterThanOrEqualTo(card.bottom),
        reason: 'the chip sits BELOW the card, not beside or above it',
      );

      await gesture.up();
      await tester.pump();
      await _settleDoubleTapRecognizer(tester);
    });
  });

  group('lifecycle: the entry is never orphaned', () {
    testWidgets('Esc during an outside-the-canvas drag removes it', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(_chip, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_chip, findsNothing);
      // AND the ENTRY is gone, not merely rendering nothing. `Esc` resets
      // the controller, which alone makes the chip's builder return an
      // empty box — so an assertion about the chip cannot tell "removed"
      // from "still mounted, drawing nothing". `_cancelPaletteDrag` removed
      // the palette drag overlay and left this one in the root overlay,
      // outliving the gesture that created it.
      expect(
        find.byType(StagingBinOverlay),
        findsNothing,
        reason: 'the OverlayEntry itself must leave with the drag',
      );

      await gesture.up();
      await tester.pump();
      await _settleDoubleTapRecognizer(tester);
    });

    testWidgets('disposing the screen MID-DRAG leaves no orphaned '
        'OverlayEntry', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(_chip, findsOneWidget);

      // Pump a completely different tree: `RackCanvasScreen.dispose` runs
      // with the drag still in flight. The entry lives in the ROOT overlay,
      // so a leaked one would still be mounted — and, because it holds the
      // disposed `DragPreviewController` as an `AnimatedBuilder` animation,
      // its next rebuild would throw "A DragPreviewController was used
      // after being disposed".
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
      );
      await tester.pump();

      expect(_chip, findsNothing);
      expect(find.byType(StagingBinOverlay), findsNothing);
      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pump();
      await _settleDoubleTapRecognizer(tester);
    });
  });

  group('releasing outside the canvas refuses, and SAYS SO', () {
    testWidgets('no device is added, and the status line reports it rather '
        'than silently doing nothing', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      final before = tester.widgetList(find.byType(DeviceBox)).length;

      final rowCentre = await _paletteRowCentre(tester);
      final gesture = await tester.startGesture(rowCentre);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tester.widgetList(find.byType(DeviceBox)).length, before);
      expect(_chip, findsNothing);
      expect(find.byType(StagingBinOverlay), findsNothing);

      // "Never silently do nothing" — a refused action reports. The chip
      // said releasing here would not place the device; this is the same
      // claim at the moment of release, where the chip is already gone.
      expect(
        find.textContaining('Blank Panel, 1U was not placed'),
        findsOneWidget,
      );
      expect(find.textContaining('Staging Bin'), findsOneWidget);

      await _settleDoubleTapRecognizer(tester);
    });
  });

  group('StagingBinOverlay in isolation', () {
    testWidgets('renders nothing at all when no drag is engaged — no chip, '
        'and no stray Material of its OWN', (tester) async {
      final controller = DragPreviewController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StagingBinOverlay(controller: controller)),
        ),
      );

      // Scoped to the overlay's own subtree. This used to read
      // `expect(find.byType(Material).evaluate().length, greaterThan(0))`
      // over the WHOLE pumped tree, where `MaterialApp` + `Scaffold` always
      // supply one — so it held for any implementation of this widget and
      // could only have failed if Flutter stopped building a Material.
      Finder overlayMaterials() => find.descendant(
        of: find.byType(StagingBinOverlay),
        matching: find.byType(Material),
      );

      expect(_chip, findsNothing);
      expect(
        overlayMaterials(),
        findsNothing,
        reason: 'the full-window Material this widget shipped with is back',
      );
      expect(
        tester.getSize(find.byType(StagingBinOverlay)),
        Size.zero,
        reason: 'an idle overlay occupies no space at all',
      );

      // THE CONTROL that stops the three assertions above from being a
      // tautology about a widget that renders nothing under every condition:
      // the same finder, the same tree, one engaged drag later.
      controller
        ..arm(
          subjectId: 'x01',
          deviceH: 1,
          face: Face.front,
          displayName: 'Blank Panel, 1U',
          badge: '1U',
          sourceKinds: const {PointerDeviceKind.mouse},
        )
        ..updateCursorGlobal(const Offset(300, 300))
        ..lift();
      await tester.pump();

      expect(_chip, findsOneWidget);
      expect(overlayMaterials(), findsOneWidget);
    });

    testWidgets('renders nothing while the drag is INSIDE the canvas', (
      tester,
    ) async {
      final controller = DragPreviewController();
      addTearDown(controller.dispose);
      controller
        ..arm(
          subjectId: 'x01',
          deviceH: 1,
          face: Face.front,
          displayName: 'Blank Panel, 1U',
          badge: '1U',
          sourceKinds: const {PointerDeviceKind.mouse},
        )
        ..updateCursorGlobal(const Offset(100, 100))
        ..lift()
        ..enterCanvas();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StagingBinOverlay(controller: controller)),
        ),
      );

      expect(_chip, findsNothing, reason: 'phase is dragging, not lifted');
    });

    testWidgets('renders nothing until a cursor position is known', (
      tester,
    ) async {
      final controller = DragPreviewController();
      addTearDown(controller.dispose);
      controller
        ..arm(
          subjectId: 'x01',
          deviceH: 1,
          face: Face.front,
          displayName: 'Blank Panel, 1U',
          badge: '1U',
          sourceKinds: const {PointerDeviceKind.mouse},
        )
        ..lift();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StagingBinOverlay(controller: controller)),
        ),
      );

      // `arm` clears the cursor, so a lifted drag can briefly have none.
      // Anchoring to a null cursor would put the chip at the origin.
      expect(_chip, findsNothing);
    });
  });
}
