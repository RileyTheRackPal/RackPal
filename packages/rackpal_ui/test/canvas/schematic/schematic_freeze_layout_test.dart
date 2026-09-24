// `#914`, DR-187 §11.186.2 — the edit that would re-flow the sheet is the
// one that records where everything was.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CONTROL IS HALF THIS FILE, BECAUSE "NOTHING MOVED" PASSES VACUOUSLY
// ═══════════════════════════════════════════════════════════════════════
// A test that mounts a screen, deletes a device and asserts the survivors
// are where they were proves nothing until somebody has measured that the
// same deletion on an unfrozen document MOVES them. Every claim here is
// therefore paired: the frozen document and the identical control, same
// fixture, same edit, one difference.
//
// `sheet_layout_commands_test.dart` in core covers what the command does
// to the document. This file covers the half only a mounted screen can get
// wrong: that the map handed to it is the layout that was on SCREEN before
// the edit, and not the one the rebuild has just produced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 9, 22, 9)),
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasScreen(
            measurer: const FakeMeasurer(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<Uuid, Pt> stored(RackDocument d) => {
    for (final item in schematicSheetOf(d)?.items.values ?? const <SheetItem>[])
      item.targetId: item.position,
  };

  /// The same fixture and the same edit, with nothing mounted over it: the
  /// control every claim below is measured against.
  ({Map<Uuid, Pt> before, Map<Uuid, Pt> after, Uuid removed}) unfrozen() {
    final control = buildSchematicTestDocument();
    final before = buildFixtureScene(control).positions;
    final gone = deviceNamed(control, 'MTX-1').id;
    RemoveDeviceCommand(id: gone).apply(control);
    return (
      before: before,
      after: buildFixtureScene(control).positions,
      removed: gone,
    );
  }

  testWidgets('OPENING THE SCHEMATIC WRITES NOTHING, which is the half the '
      'ruling is strict about (§11.186.2)', (tester) async {
    await pump(tester);

    expect(
      doc.sheets,
      isEmpty,
      reason: 'a document nobody has edited carries no items at all',
    );
    expect(controller.undo.undoLabelKey, isNull);
  });

  // `#933`. The freeze is for an edit that would re-flow THIS sheet. A
  // rack's RU numbering and rear mirroring are drawn on the Rack view and
  // nowhere here, and until they stopped declaring `style` each toggle
  // wrote every symbol's position into the file. Both fields are driven,
  // because either one alone would leave the other free to regress.
  for (final (label, edit) in <(String, Command<RackDocument> Function(Rack))>[
    (
      'RU numbering',
      (r) => SetEntityPropertyCommand<Rack, RuNumbering>(
        id: r.id,
        field: RackField.ruNumbering,
        from: r.ruNumbering,
        to: r.ruNumbering == RuNumbering.topDown
            ? RuNumbering.bottomUpFromOne
            : RuNumbering.topDown,
        now: DateTime.utc(2026, 9, 23),
        actor: 'test',
      ),
    ),
    (
      'rear mirroring',
      (r) => SetEntityPropertyCommand<Rack, bool>(
        id: r.id,
        field: RackField.mirrorRearElevation,
        from: r.mirrorRearElevation,
        to: !r.mirrorRearElevation,
        now: DateTime.utc(2026, 9, 23),
        actor: 'test',
      ),
    ),
  ]) {
    testWidgets('a rack $label toggle freezes nothing: it is not drawn on '
        'this sheet', (tester) async {
      await pump(tester);
      expect(doc.racks, isNotEmpty, reason: 'the fixture must have a rack');

      controller.run(edit(doc.racks.values.first));
      await tester.pumpAndSettle();

      expect(
        doc.sheets,
        isEmpty,
        reason:
            'a display preference of the Rack view is no occasion to '
            'store where the schematic symbols are',
      );
      expect(
        controller.undo.undoLabelKey,
        isNotNull,
        reason: 'the edit itself did land, so the silence is not vacuous',
      );
    });
  }

  testWidgets('the control MOVES things, so the claims below are not '
      'vacuous', (tester) async {
    final c = unfrozen();
    final survivors = c.before.keys.where((id) => id != c.removed);

    expect(survivors, isNotEmpty);
    expect(
      survivors.where((id) => c.after[id] != c.before[id]),
      isNotEmpty,
      reason: 'deleting MTX-1 re-flows the unfrozen sheet',
    );
  });

  testWidgets('A STRUCTURAL EDIT RECORDS THE LAYOUT THAT WAS ON SCREEN, not '
      'the one the rebuild produced', (tester) async {
    final c = unfrozen();
    await pump(tester);

    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();

    final held = stored(doc);
    expect(held, isNotEmpty);
    for (final id in c.before.keys.where((id) => id != c.removed)) {
      expect(
        held[id],
        c.before[id],
        reason: 'symbol $id was frozen at the post-edit position',
      );
    }
  });

  testWidgets('and the symbols then STAY THERE, which is the whole point of '
      'the exercise', (tester) async {
    final c = unfrozen();
    await pump(tester);

    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();

    final after = buildFixtureScene(doc).positions;
    for (final id in c.before.keys.where((id) => id != c.removed)) {
      expect(after[id], c.before[id], reason: 'symbol $id drifted');
    }
    expect(
      after.keys.where((id) => c.after[id] != c.before[id]),
      isNotEmpty,
      reason: 'the control moved these and the frozen sheet did not',
    );
  });

  testWidgets('ONE undo takes back the edit AND the arrangement it wrote, '
      'because a consequence is not a second edit', (tester) async {
    // THE DEFECT THIS REPLACED. Written as a second `run()` after the
    // commit, the freeze was its own entry: the first Ctrl+Z took the
    // arrangement back and LEFT THE DELETION, so undoing one device took
    // two presses and the first one visibly scrambled the sheet.
    // `schematic_remedy_test.dart` and `schematic_remedy_dr128_test.dart`
    // both failed on it, in the words "ONE undo takes back the device AND
    // the cable".
    await pump(tester);
    final before = doc.devices.length;

    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();
    expect(doc.devices, hasLength(before - 1));
    expect(stored(doc), isNotEmpty, reason: 'the freeze landed');
    expect(
      controller.undo.undoLabelKey,
      LabelKey.removeDevice.name,
      reason: 'the first child names the entry, not the consequence',
    );

    controller.undoLast();
    await tester.pumpAndSettle();

    expect(doc.devices, hasLength(before), reason: 'one press, device back');
    expect(
      doc.sheets,
      isEmpty,
      reason: 'and the document is exactly the one that existed before',
    );
    expect(controller.undo.canUndo, isFalse);
  });

  testWidgets('A SECOND EDIT ON A FROZEN SHEET LEAVES NO SECOND ENTRY, so '
      'the undo stack is not one freeze per keystroke (DR-156)', (
    tester,
  ) async {
    await pump(tester);

    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();
    final frozen = stored(doc);

    final second = deviceNamed(doc, 'SW-1').id;
    controller.run(RemoveDeviceCommand(id: second));
    await tester.pumpAndSettle();

    expect(controller.undo.undoLabelKey, LabelKey.removeDevice.name);
    for (final entry in frozen.entries) {
      if (entry.key == second) continue;
      expect(stored(doc)[entry.key], entry.value);
    }
  });

  // ═══════════════════════════════════════════════════════════════════
  // `Tidy sheet` (DR-187 §11.186.3 and §11.186.7, `#920`)
  // ═══════════════════════════════════════════════════════════════════
  // The way back out of the freeze, and the reason the freeze is safe to
  // ship at all. It lives on the domain filter bar for now, which is the
  // schematic's only existing chrome; §11.186.7 moves it to the context
  // menu when `#918`'s drag gives that menu its other reasons to exist.
  //
  // TWO CONTROLS SAY "Tidy sheet" once the dialog is up, the bar's and
  // the confirm's, so every finder below names the BUTTON TYPE as well as
  // the words. A bare `find.text` here would tap whichever the tree
  // happened to reach first and pass either way.
  Finder barButton() => find.widgetWithText(TextButton, 'Tidy sheet');
  Finder confirmButton() => find.widgetWithText(FilledButton, 'Tidy sheet');

  testWidgets('THE BUTTON IS DISABLED WITH NOTHING TO TIDY, so it can never '
      'be the control that did nothing', (tester) async {
    await pump(tester);

    expect(barButton(), findsOneWidget);
    expect(
      tester.widget<TextButton>(barButton()).onPressed,
      isNull,
      reason: 'an untouched sheet stores no position',
    );
  });

  testWidgets('a frozen sheet enables it, and the CONFIRM STATES THE COUNT '
      'that will move', (tester) async {
    await pump(tester);
    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();

    final owed = stored(doc).length;
    expect(owed, greaterThan(1));
    expect(tester.widget<TextButton>(barButton()).onPressed, isNotNull);

    await tester.tap(barButton());
    await tester.pumpAndSettle();

    expect(find.text('Tidy $owed symbols?'), findsOneWidget);
  });

  testWidgets('Cancel changes NOTHING, which is the whole point of asking', (
    tester,
  ) async {
    await pump(tester);
    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();
    final frozen = stored(doc);

    await tester.tap(barButton());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(stored(doc), frozen);
    expect(controller.undo.undoLabelKey, LabelKey.removeDevice.name);
  });

  testWidgets('CONFIRMING HANDS THE SHEET BACK TO THE LAYOUT, and the symbols '
      'land where an unfrozen document would have put them', (tester) async {
    final c = unfrozen();
    await pump(tester);
    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();

    await tester.tap(barButton());
    await tester.pumpAndSettle();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(stored(doc), isEmpty);
    expect(controller.undo.undoLabelKey, LabelKey.tidySheet.name);
    // THE CONTROL AGAIN: these are the positions the same deletion
    // produces with nothing frozen, so a tidy has genuinely undone the
    // freeze rather than merely deleted some rows.
    expect(buildFixtureScene(doc).positions, c.after);
  });

  testWidgets('A PINNED SYMBOL SURVIVES A TIDY (CR-068), which is the one '
      'thing pinning still means', (tester) async {
    await pump(tester);
    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();

    final kept = deviceNamed(doc, 'AMP-1').id;
    final where = stored(doc)[kept];
    expect(where, isNotNull);
    controller.run(
      SetSymbolPinnedCommand(
        positions: {kept: where!},
        pinned: true,
        now: DateTime.utc(2026, 9, 22, 9),
        actor: 'test',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(barButton());
    await tester.pumpAndSettle();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(stored(doc).keys, [kept]);
    expect(stored(doc)[kept], where);
  });

  testWidgets('and ONE undo puts the arrangement back, so a tidy pressed by '
      'accident costs one keystroke', (tester) async {
    await pump(tester);
    controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'MTX-1').id));
    await tester.pumpAndSettle();
    final frozen = stored(doc);

    await tester.tap(barButton());
    await tester.pumpAndSettle();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();
    expect(stored(doc), isEmpty);

    controller.undoLast();
    await tester.pumpAndSettle();

    expect(stored(doc), frozen);
  });
}
