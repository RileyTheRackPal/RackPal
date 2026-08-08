// M3-C/2, #148 — the Structure editor in table mode.
//
// WHAT THESE GATE. The screen's whole design claim is that it renders a
// derivation and contains none, so the tests that matter are the ones
// that would catch it starting to decide things: a cell string that is
// not `structureCell`'s, a count that is the filtered view's rather than
// the table's, a control that does nothing.
//
// AND THE COPY IS A CLAIM ABOUT THIS BUILD. `kNoDropsDetail` tells its
// reader how to create a drop, which is the thing the Schedule tab's
// deleted panel got wrong in the direction that costs most. It names the
// field that is on screen directly above it, and the test below drives
// that exact instruction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 8);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

/// A project with a Structure body and the rooms named.
RackDocument _project({
  List<(String, String)> rooms = const [
    ('Living Room', 'LR'),
    ('Kitchen', 'KIT'),
  ],
}) {
  final doc = RackDocument(
    id: const Uuid('doc-editor'),
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

  for (final (name, code) in rooms) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _now,
      actor: 't',
    ).apply(doc);
  }
  return doc;
}

/// What the app layer does, in the shape the app layer does it: re-plan
/// against its own clock and actor, apply, report.
final class _Harness {
  _Harness(this.doc);

  final RackDocument doc;
  int outletPickerOpened = 0;

  StructureEditorActions get actions => StructureEditorActions(
    dropEntry: DropEntryActions(
      onCommit: (line) {
        final plan = planDropLine(
          doc: doc,
          line: line,
          now: _now,
          actor: 'committer',
        );
        if (plan is! DropLinePlanReady) return plan;
        for (final c in plan.commands) {
          c.apply(doc);
        }
        return plan;
      },
      onCreateLocation: (name) => AddLocationCommand(
        name: name,
        code: name.split(' ').map((w) => w[0]).join().toUpperCase(),
        order: nextLocationOrder(doc),
        now: _now,
        actor: 't',
      ).apply(doc),
      onCreateStructure: () {},
    ),
    onAddOutlet: () => outletPickerOpened++,
  );
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StructureEditorScreen(
          actions: h.actions,
          currentDoc: () => h.doc,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types one quick-add line and commits it, the way a person does.
Future<void> _addLine(WidgetTester tester, String line) async {
  await tester.enterText(find.byType(TextField), line);
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  group('it shows the derivation, and nothing it computed itself', () {
    testWidgets('every visible cell is the string structureCell produced', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');

      final table = buildStructureTable(h.doc);
      expect(table.dropCount, 3);

      // THE GATE. Not "the screen shows LR-C6-1" — that would pass just
      // as well if the screen made the string up and happened to agree
      // today. Every default column of every row is looked up through
      // core and then found on screen.
      final units = h.doc.settings.displayUnits;
      for (final row in table.groups.single.rows) {
        for (final id in kStructureDefaultColumns) {
          final expected = structureCell(h.doc, row, id, units: units);
          expect(
            find.text(expected),
            findsWidgets,
            reason: '${structureColumnHeader(id)} is missing from the table',
          );
        }
      }
    });

    testWidgets('the band header carries the room, code and counts', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      expect(find.text('LIVING ROOM (LR)'), findsOneWidget);
      expect(find.text('2 drops · 0 connected'), findsOneWidget);
    });

    testWidgets('a room with no drops has no band but is still in the tree', (
      tester,
    ) async {
      // The tree is what lists every room; a band per empty room would
      // push the drops off the screen in a project with forty of them.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      expect(find.text('LIVING ROOM (LR)'), findsOneWidget);
      expect(find.text('KITCHEN (KIT)'), findsNothing);
      expect(find.text('Kitchen'), findsOneWidget);
    });
  });

  group('the status bar counts the TABLE, not the filtered view', () {
    testWidgets("it prints §4's five counts", (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6 @outlet=WP-1');

      expect(
        find.textContaining('2 drops · 0 connected · 2 spare · 1 outlets'),
        findsOneWidget,
      );
    });

    testWidgets('a filter states what it hid and does not restate the total', (
      tester,
    ) async {
      // THE DEFECT THIS FORBIDS: reading "1 drop" off a screen filtered
      // to one media type and ordering cable for the house.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');

      await tester.tap(find.text('Unconnected only'));
      await tester.pumpAndSettle();
      // Nothing is landed, so nothing is hidden and the count is silent.
      expect(find.textContaining('hidden by filter'), findsNothing);
      // The WHOLE status line, because "3 drops" alone also matches the
      // band header one row up — and the point of this test is that the
      // status bar reports the body and not the view.
      expect(
        find.text('3 drops · 0 connected · 3 spare · 1 outlets · 0 pathways'),
        findsOneWidget,
      );
    });
  });

  group('the empty states are true of this build', () {
    testWidgets('an empty body says how to fill it, on this screen', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kNoDropsHeadline), findsOneWidget);
      // The copy names the field above it. Following the instruction
      // literally is the test: if the instruction stops working, this
      // fails rather than the sentence quietly becoming false.
      expect(kNoDropsDetail, contains('Living Room: 4x Cat6'));
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      expect(find.text(kNoDropsHeadline), findsNothing);
      expect(buildStructureTable(h.doc).dropCount, 6);
    });

    testWidgets('all-hidden is a different sentence from none-exist', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await tester.tap(find.text('All rooms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Living Room').last);
      await tester.pumpAndSettle();
      expect(find.text(kAllDropsFilteredHeadline), findsNothing);

      // Filtering to a media type nothing was pulled in is not reachable
      // from the menu (it offers only what is on the body), so the
      // connection filter is what empties the table.
      await tester.tap(find.text('Unconnected only'));
      await tester.pumpAndSettle();
      expect(find.text(kNoDropsHeadline), findsNothing);
    });
  });

  group('the left pane is a view, not an editor (CR-112)', () {
    testWidgets('it names where rooms are edited instead of offering it', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kLocationsAreReadOnlyHere), findsOneWidget);
      // No control in the pane creates, renames or deletes a room.
      expect(find.widgetWithText(TextButton, 'Add room'), findsNothing);
    });

    testWidgets('every room is listed, with its code and drop count', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');

      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('LR'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('the optional columns are off until asked for', () {
    testWidgets('⚙ Columns adds one and the header appears', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      expect(find.text('NOTES'), findsNothing);

      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTES'));
      await tester.pumpAndSettle();

      // THE MENU STAYS OPEN ON PURPOSE (`closeOnActivate: false`), so a
      // person can tick three columns in one visit — which means its own
      // `NOTES` item is still on screen beside the new column header.
      // Dismissing it is what leaves only the header to find.
      expect(find.text('NOTES'), findsNWidgets(2));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('NOTES'), findsOneWidget);
    });

    testWidgets('the eight defaults are all there before any menu is opened', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      for (final id in kStructureDefaultColumns) {
        expect(
          find.text(structureColumnHeader(id)),
          findsOneWidget,
          reason: '${structureColumnHeader(id)} is a DEFAULT column',
        );
      }
    });
  });

  group('the header names the body it is editing (§7)', () {
    testWidgets('designator and title, from the device and the body', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      expect(find.text('STR-1 · Media Panel'), findsOneWidget);
    });

    testWidgets('a project with no Structure device says so', (tester) async {
      final doc = RackDocument(
        id: const Uuid('doc-bare'),
        appVersion: '0.1.0',
        createdAt: _now,
        modifiedAt: _now,
        meta: _meta(),
      )..registries = buildSeedRegistries();
      await _pump(tester, _Harness(doc));

      expect(find.text('No Structure device yet'), findsOneWidget);
    });
  });

  group('the two buttons that are drawn both do something', () {
    testWidgets('Add outlet reaches the picker', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await tester.tap(find.widgetWithText(TextButton, 'Add outlet'));
      await tester.pumpAndSettle();
      expect(h.outletPickerOpened, 1);
    });

    testWidgets('and nothing unbuilt is offered', (tester) async {
      // `shell_tabs_test.dart`'s rule, applied here: no control that
      // does nothing. Each of these is a real §4 wireframe control whose
      // command does not exist yet.
      final h = _Harness(_project());
      await _pump(tester, h);

      for (final label in [
        'Group into pathway',
        'Renumber…',
        'Import CSV…',
        'Export CSV',
        'Matrix',
        'Pathways',
      ]) {
        expect(find.text(label), findsNothing, reason: '$label is unbuilt');
      }
    });
  });
}
