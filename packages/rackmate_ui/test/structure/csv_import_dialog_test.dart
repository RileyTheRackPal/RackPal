// M3-F/2 (#160) and M3-F/3 (#161), docs/07 §5.1, §5.3.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS SURFACE OWES, AND WHAT IT MUST NOT DECIDE
// ═══════════════════════════════════════════════════════════════════════
// The dialog renders a derivation and contains none, the same claim the
// Structure editor makes. So the cases that matter are the ones that
// would catch it starting to decide things: a count it computed itself,
// a row it hid, a commit that went ahead without the confirm §5.3.5
// requires.
//
// The live preview is the feature, so the load-bearing case is that
// moving a dropdown changes the GRID and the COUNTS together. A surface
// that re-rendered one and not the other would show a person numbers
// that do not describe the rows above them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 10);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

RackDocument _project({bool withRoom = false}) {
  final doc = RackDocument(
    id: const Uuid('doc-import'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Media Panel',
    designator: 'STR-1',
    now: _now,
    actor: 't',
  ).apply(doc);
  if (withRoom) {
    AddLocationCommand(
      name: 'Living Room',
      code: 'LR',
      order: nextLocationOrder(doc),
      now: _now,
      actor: 't',
    ).apply(doc);
  }
  return doc;
}

CsvTable _table(String text) {
  final read = readCsv(text);
  return switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
}

final class _Seen {
  CsvImportChoice? choice;
  int cancels = 0;
}

Future<_Seen> _pump(
  WidgetTester tester,
  RackDocument doc,
  String csv,
) async {
  // A real window; see `structure_editor_screen_test.dart`'s `_pump` for
  // why 800x600 misrepresents this surface.
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final seen = _Seen();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CsvImportView(
          table: _table(csv),
          currentDoc: () => doc,
          fileName: 'smith-pull-list.csv',
          onImport: (choice) => seen.choice = choice,
          onCancel: () => seen.cancels++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return seen;
}

void main() {
  group('§5.1: every source header appears, with the guess beside it', () {
    testWidgets('a mapped header and an unmapped one both get a row', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type,Reel\nLiving Room,Cat6,R-42\n',
      );
      // EVERY header, not only the unmapped ones. Showing only the
      // strangers would hide a WRONG guess, which costs more: an
      // unmapped column asks a question, a mis-mapped one silently
      // files a length as a quantity.
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Cable Type'), findsOneWidget);
      expect(find.text('Reel'), findsOneWidget);
    });

    testWidgets('the unmapped column defaults to keeping the data', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type,Reel\nLiving Room,Cat6,R-42\n',
      );
      // §5.1 is unconditional that user data is never discarded, and
      // there is deliberately no third option offering to.
      expect(find.text(kKeepAsExtraLabel), findsOneWidget);
    });
  });

  group('§5.3: the preview grid shows the parsed result before commit', () {
    testWidgets('the counts are the plan and every row is drawn', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type,Qty\nLiving Room,Cat6,2\nAttic,Cat6,1\n',
      );
      // THE FOOTER SENTENCE EXACTLY, not a substring: `create 3` also
      // appears in the grid's own ACTION cell, and a loose finder would
      // pass on either while claiming to check the footer.
      expect(find.text('create 3 · update 0 · unchanged 0'), findsOneWidget);
      expect(find.text('Living Room'), findsWidgets);
      expect(find.text('Attic'), findsWidgets);
    });

    testWidgets('a skipped row is DRAWN, not omitted', (tester) async {
      // Omitting it would make a row vanish with only a footer number to
      // say so, and being able to see which one is the whole reason this
      // grid exists.
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type\nLiving Room,Cat6\n,Cat6\n',
      );
      expect(find.text(kSkippedWord), findsOneWidget);
      expect(
        find.text('create 1 · update 0 · unchanged 0 · skipped 1'),
        findsOneWidget,
      );
    });
  });

  group('the "will create" list, ticked, and unticking subtracts', () {
    testWidgets('a room the project lacks is listed and ticked', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(),
        'Room,Cable Type\nAttic,Cat6\n',
      );
      expect(find.text('${kRoomPrefix}Attic'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(find.text('create 1 · update 0 · unchanged 0'), findsOneWidget);
    });

    testWidgets('unticking it moves the counts, live', (tester) async {
      await _pump(
        tester,
        _project(),
        'Room,Cable Type\nAttic,Cat6\n',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      // The footer and the grid move TOGETHER, from one plan.
      expect(
        find.text('create 0 · update 0 · unchanged 0 · skipped 1'),
        findsOneWidget,
      );
      expect(find.text(kSkippedWord), findsOneWidget);
      // And it stays on the list, unticked rather than gone.
      expect(find.text('${kRoomPrefix}Attic'), findsOneWidget);
    });

    testWidgets("RJ-012's new cable type gets the same treatment", (
      tester,
    ) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type\nLiving Room,Cat6e\n',
      );
      expect(find.text('${kCablePrefix}Cat6e'), findsOneWidget);
    });
  });

  group('a blocking mapping problem disables the commit', () {
    testWidgets('a sheet with no room column cannot be imported', (
      tester,
    ) async {
      await _pump(tester, _project(), 'Widget,Gadget\na,b\n');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, kImportLabel),
      );
      // NOT a silent no-op press. §5.3's never-fail-fast is about rows;
      // a sheet that never said where anything goes is a dropdown away
      // from being importable, and the dropdown is on screen.
      expect(button.onPressed, isNull);
      expect(find.textContaining('room'), findsWidgets);
    });

    testWidgets('a complete sheet enables it', (tester) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type\nLiving Room,Cat6\n',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, kImportLabel),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('§5.3.5: the import-over-existing confirm (M3-F/3)', () {
    /// A project that already holds the drops the sheet describes.
    RackDocument withDrops() {
      final doc = _project(withRoom: true);
      final parsed = parseDropLine('Living Room: 1x Cat6 @outlet="WP-1"');
      final plan = planDropLine(
        doc: doc,
        line: parsed as DropLineParsed,
        now: _now,
        actor: 't',
      );
      for (final c in (plan as DropLinePlanReady).commands) {
        c.apply(doc);
      }
      return doc;
    }

    testWidgets('an import that only CREATES commits with no dialog', (
      tester,
    ) async {
      // Creating drops in an empty project is the ordinary February act.
      // A confirm on it is the modal people learn to dismiss without
      // reading, which is what makes the one that matters useless.
      final seen = await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cable Type\nLiving Room,Cat6\n',
      );
      await tester.tap(find.widgetWithText(FilledButton, kImportLabel));
      await tester.pumpAndSettle();
      expect(find.text(kOverwriteTitle), findsNothing);
      expect(seen.choice, isNotNull);
    });

    testWidgets('an import that UPDATES asks first, and states the count', (
      tester,
    ) async {
      final seen = await _pump(
        tester,
        withDrops(),
        'Room,Outlet,Cable Type,Status\nLiving Room,WP-1,Cat6,terminated\n',
      );
      await tester.tap(find.widgetWithText(FilledButton, kImportLabel));
      await tester.pumpAndSettle();

      expect(find.text(kOverwriteTitle), findsOneWidget);
      // THE COUNT BEFORE ANYTHING IS WRITTEN, which is #161's own
      // requirement and DR-013's rule for this class of act.
      expect(find.textContaining('1 drop'), findsOneWidget);
      expect(find.text(kUndoReassurance), findsOneWidget);
      expect(seen.choice, isNull, reason: 'nothing committed yet');
    });

    testWidgets('cancelling the confirm commits nothing', (tester) async {
      final seen = await _pump(
        tester,
        withDrops(),
        'Room,Outlet,Cable Type,Status\nLiving Room,WP-1,Cat6,terminated\n',
      );
      await tester.tap(find.widgetWithText(FilledButton, kImportLabel));
      await tester.pumpAndSettle();
      // SCOPED TO THE CONFIRM. There are two `Cancel`s on screen once it
      // opens — the import dialog's own and this one — and an unscoped
      // finder would be testing whichever the tree happened to reach.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, kCancelLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen.choice, isNull);
    });

    testWidgets('confirming it commits the choice', (tester) async {
      final seen = await _pump(
        tester,
        withDrops(),
        'Room,Outlet,Cable Type,Status\nLiving Room,WP-1,Cat6,terminated\n',
      );
      await tester.tap(find.widgetWithText(FilledButton, kImportLabel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, kOverwriteConfirmLabel),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen.choice, isNotNull);
    });
  });

  group('the shape is OFFERED, not imposed (docs/07 §5)', () {
    testWidgets('a wide sheet opens wide and says why', (tester) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cat6,RG6\nLiving Room,4,2\nAttic,1,1\n',
      );
      expect(find.textContaining('cable counts'), findsOneWidget);
      expect(find.text('create 8 · update 0 · unchanged 0'), findsOneWidget);
    });

    testWidgets('switching to long re-reads the same file', (tester) async {
      await _pump(
        tester,
        _project(withRoom: true),
        'Room,Cat6,RG6\nLiving Room,4,2\nAttic,1,1\n',
      );
      await tester.tap(find.text(kLongShapeLabel));
      await tester.pumpAndSettle();
      // No media column in the long reading of this file, so nothing
      // can be created and the button says so rather than the press
      // failing.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, kImportLabel),
            )
            .onPressed,
        isNull,
      );
    });
  });
}
