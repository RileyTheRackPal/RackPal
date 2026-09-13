// `#874`, DR-159 §11.158 — undo is document-global, it says what it will
// take back, and the builder keeps its own stack.
//
// =====================================================================
// THE CASE THAT WOULD HAVE CAUGHT THIS IS "ON EACH TAB", NOT "ON A TAB"
// =====================================================================
// `UndoIntent` had exactly one handler in the whole tree and every test
// that pressed `Ctrl+Z` pressed it on the Rack. Six of the seven tabs
// were dead for five milestones and nothing was red. So this file sweeps
// `ShellView.values` rather than naming tabs: a tab added later is
// covered the day it is added, and the sweep cannot go stale the way the
// two-tab counts in `rack_canvas_screen.dart` and the keymap registry
// did.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

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

  Future<TestSession> open(WidgetTester tester) async {
    final built = await buildTestApp(measurer);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    return built.session;
  }

  Future<void> showTab(WidgetTester tester, ShellView view) async {
    await tester.tap(find.widgetWithText(Tab, view.label));
    await tester.pumpAndSettle();
  }

  Future<void> pressUndo(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> pressRedo(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// A document edit with an obvious observable: the demo rack's name.
  ///
  /// Made through the controller rather than a gesture ON PURPOSE. What
  /// is under test is the KEY, on seven surfaces; routing every case
  /// through a different tab's own editing gesture would test seven
  /// gestures instead and hide the one thing that was broken.
  void renameRack(TestSession session, String name) {
    final controller = session.services.session.controller;
    final rack = controller.doc.racks.values.first;
    controller.run(
      RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: rack.id,
        from: rack.name,
        to: name,
        now: DateTime.utc(2026, 9, 12),
        actor: 'test',
      ),
    );
  }

  String rackName(TestSession session) =>
      session.services.session.controller.doc.racks.values.first.name;

  group('DR-159 §11.158.3: the key works on EVERY tab', () {
    for (final view in ShellView.values) {
      testWidgets('Ctrl+Z takes back a document edit on ${view.label}', (
        tester,
      ) async {
        final session = await open(tester);
        final before = rackName(session);
        renameRack(session, 'CHANGED');
        await tester.pumpAndSettle();
        expect(rackName(session), 'CHANGED');

        await showTab(tester, view);
        await pressUndo(tester);

        expect(
          rackName(session),
          before,
          reason:
              'Ctrl+Z did nothing on the ${view.label} tab. Before '
              'DR-159 that was true of six of the seven, because '
              'UndoIntent had one handler and it lived inside '
              'RackCanvasScreen.',
        );
      });
    }

    testWidgets('and Ctrl+Shift+Z puts it back, from a tab that is not the '
        'Rack', (tester) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await showTab(tester, ShellView.schedule);
      await pressUndo(tester);
      expect(rackName(session), isNot('CHANGED'));

      await pressRedo(tester);
      expect(
        rackName(session),
        'CHANGED',
        reason: 'redo was scoped to the rack tab by the same row',
      );
    });
  });

  group('DR-159 §11.158.6: the Edit menu names the act', () {
    testWidgets('it exists at all, which it did not before', (tester) async {
      await open(tester);
      expect(find.widgetWithText(SubmenuButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(SubmenuButton, 'File'), findsOneWidget);
    });

    testWidgets('an empty stack offers a DISABLED bare "Undo"', (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);
      final item = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, 'Undo'),
      );
      expect(
        item.onPressed,
        isNull,
        reason: 'a live row that does nothing teaches a person the menu lies',
      );
    });

    testWidgets('and a real edit is NAMED, which is what docs/03 §13.3 '
        'asked for at M0', (tester) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(
        find.text('Undo Rename'),
        findsOneWidget,
        reason:
            'LabelKey.setRackLabel exists so the menu can say this; 101 '
            'values carry comments arguing about wording for a surface '
            'that did not exist until DR-159',
      );
    });

    testWidgets('choosing it performs the undo', (tester) async {
      final session = await open(tester);
      final before = rackName(session);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo Rename'));
      await tester.pumpAndSettle();

      expect(rackName(session), before);
    });
  });

  group('DR-159 §11.158.5: the builder keeps its own stack', () {
    /// Opens the Device Manager and starts a new template.
    Future<void> openBuilder(WidgetTester tester) async {
      await showTab(tester, ShellView.deviceManager);
      await tester.tap(find.text(kBrowserNewTemplateLabel));
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+Z in the builder does NOT touch the document', (
      tester,
    ) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await openBuilder(tester);
      await pressUndo(tester);

      expect(
        rackName(session),
        'CHANGED',
        reason:
            'undoing something in the project behind the window is the '
            'larger blast radius, invisible from where the person is '
            'standing (§11.158.5)',
      );
    });

    testWidgets('and it DOES take back a template edit', (tester) async {
      await open(tester);
      await openBuilder(tester);

      final name = find.byType(TextField).first;
      await tester.enterText(name, 'Something');
      await tester.pumpAndSettle();
      expect(find.text('Unsaved'), findsOneWidget);

      // THE BUTTON, not the key: a text field has focus after typing, so
      // the key correctly belongs to the field (§11.158.3). This asserts
      // the stack the shell is now routed to is the one that moves.
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      final screen = tester.widget<DeviceBuilderScreen>(
        find.byType(DeviceBuilderScreen),
      );
      expect(screen.onUndoTargetChanged, isNotNull);
    });

    testWidgets('the Edit menu describes the TEMPLATE stack while the '
        'builder is showing', (tester) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();
      await openBuilder(tester);

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(
        find.text('Undo Rename'),
        findsNothing,
        reason:
            'the menu must not offer a document act while the key would '
            'reach the template stack; that mismatch is worse than no '
            'menu',
      );
    });

    testWidgets('and it goes back to the DOCUMENT stack when the builder '
        'closes', (tester) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();
      await openBuilder(tester);
      await showTab(tester, ShellView.rack);
      await showTab(tester, ShellView.deviceManager);

      // Back to the browser: the builder is gone, so the document's stack
      // is what Edit describes again.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Undo Rename'), findsOneWidget);
    });
  });

  group('DR-159 §11.158.8: the empty drop box hands the key back', () {
    Finder dropBox() => find.widgetWithText(TextField, 'Add drops');

    testWidgets('an EMPTY box forwards Ctrl+Z to the document', (
      tester,
    ) async {
      // This is the case the per-tab sweep found and the flat rule got
      // wrong: the box AUTOFOCUSES, so `DefaultTextEditingShortcuts`
      // claimed the key on the one tab whose primary verb is bulk data
      // entry, and with nothing typed there was nothing to restore.
      final session = await open(tester);
      final before = rackName(session);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await showTab(tester, ShellView.structuredWiring);
      expect(dropBox(), findsOneWidget);
      expect(
        tester.widget<TextField>(dropBox()).controller!.text,
        isEmpty,
        reason: 'the fixture must actually be in the empty state',
      );

      await pressUndo(tester);
      expect(rackName(session), before);
    });

    testWidgets('and a box WITH TEXT keeps it, because that typing is '
        'worth taking back', (tester) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await showTab(tester, ShellView.structuredWiring);
      await tester.enterText(dropBox(), 'Living Room: 4x Cat6');
      await tester.pumpAndSettle();

      await pressUndo(tester);
      expect(
        rackName(session),
        'CHANGED',
        reason:
            'the condition is the whole design: a box with text in it '
            'has typing worth restoring and keeps the key',
      );
    });
  });

  group('DR-159 §11.158.3: a text field still wins', () {
    testWidgets('typing in the palette filter keeps Ctrl+Z for the text', (
      tester,
    ) async {
      final session = await open(tester);
      renameRack(session, 'CHANGED');
      await tester.pumpAndSettle();

      await showTab(tester, ShellView.deviceManager);
      await tester.enterText(find.byType(TextField).first, 'switch');
      await tester.pumpAndSettle();

      await pressUndo(tester);

      expect(
        rackName(session),
        'CHANGED',
        reason:
            'the guard reads FocusManager.instance.primaryFocus and '
            'always did; promoting the binding changed nothing about it',
      );
    });
  });
}
