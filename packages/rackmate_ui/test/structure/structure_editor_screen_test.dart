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
import 'package:flutter/services.dart';
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
    onEdit: edit,
  );

  /// What `apps/rackmate`'s `buildStructureEditAction` does, in the
  /// shape it does it: plan the whole batch, refuse it whole, then
  /// apply. Mirrored here rather than imported because `rackmate_ui`
  /// may not depend on the app, and because the harness has to be
  /// driveable without a `DocumentController`.
  String? edit(List<StructureCellEdit> edits) {
    final commands = <Command>[];
    final claimedLabels = <String>{};

    for (final e in edits) {
      switch (e.column) {
        // THE TWO ARE SPELLED OUT RATHER THAN SHARING A BRANCH, and it
        // is not verbosity: `EntityField`'s `set` is a typed closure, so
        // building the command through `<Object?>` compiles and then
        // throws `(Link, String) => void is not a subtype of (Link,
        // Object?) => void` at apply time. The concrete type parameter is
        // what keeps the closure callable.
        case StructureColumnId.fieldLabel:
          final field = buildSetStructureOriginProperty<String>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.fieldLabel,
            to: e.value.trim(),
            now: _now,
            actor: 'editor',
            alsoUsedLabels: claimedLabels,
          );
          switch (field) {
            case SetStructureOriginRefused(:final reason):
              return reason;
            case SetStructureOriginUnchanged():
              break;
            case SetStructureOriginReady(:final command):
              commands.add(command);
              claimedLabels.add(e.value.trim());
          }
        case StructureColumnId.rackLabel:
          final rack = buildSetStructureOriginProperty<String?>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.rackLabel,
            to: e.value,
            now: _now,
            actor: 'editor',
          );
          switch (rack) {
            case SetStructureOriginRefused(:final reason):
              return reason;
            case SetStructureOriginUnchanged():
              break;
            case SetStructureOriginReady(:final command):
              commands.add(command);
          }
        case StructureColumnId.roughIn:
          final status = RoughInStatus.values
              .where((s) => roughInLabel(s) == e.value.trim().toUpperCase())
              .firstOrNull;
          if (status == null) return '"${e.value}" is not a rough-in status.';
          final c = buildSetEntityProperty<Link, RoughInStatus>(
            doc: doc,
            id: e.linkId,
            field: LinkField.roughInStatus,
            to: status,
            now: _now,
            actor: 'editor',
          );
          if (c != null) commands.add(c);
        case StructureColumnId.notes:
          final c = buildSetEntityProperty<Link, String?>(
            doc: doc,
            id: e.linkId,
            field: LinkField.notes,
            to: e.value.trim().isEmpty ? null : e.value.trim(),
            now: _now,
            actor: 'editor',
          );
          if (c != null) commands.add(c);
        case _:
          return 'That column cannot be typed into.';
      }
    }
    for (final c in commands) {
      c.apply(doc);
    }
    return null;
  }
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

/// The drops IN THE ORDER THE TABLE DRAWS THEM.
///
/// NOT `doc.links.values`, which is map insertion order and does NOT
/// match: `buildSchedule` sorts by `Link.order` then id, so the two
/// disagree the moment one line creates more than one drop. Every
/// assertion about "the row above" reads its order from here, because
/// reading it off anything but the table would be testing a different
/// table.
List<Link> _rows(_Harness h) => [
  for (final row in buildStructureTable(h.doc).groups.single.rows)
    h.doc.links[row.linkId]!,
];

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
      // SCROLLED TO FIRST. The menu grew past one screen when M3-J/3
      // added the as-built group and two more columns, and a `tap` on an
      // item below the fold hits whatever is drawn there instead.
      await tester.ensureVisible(find.text('NOTES'));
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

    testWidgets('the as-built group is ONE switch, not seven ticks', (
      tester,
    ) async {
      // DR-020 §11.19.2(5) pictures somebody closing out sixty runs who
      // "needs one table with a length column they tab down". Making them
      // reach that table through seven menu entries would put the cost
      // back in a different place.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      for (final id in kStructureAsBuiltColumns) {
        expect(find.text(structureColumnHeader(id)), findsNothing);
      }

      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kAsBuiltColumnsLabel));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      for (final id in kStructureAsBuiltColumns) {
        expect(
          find.text(structureColumnHeader(id)),
          findsOneWidget,
          reason: '${structureColumnHeader(id)} is in the as-built set',
        );
      }
      // And off again, because a switch that only goes one way is a trap
      // on a table this wide.
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kAsBuiltColumnsLabel));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('SPLICES'), findsNothing);
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

  group('inline editing is the primary path (§4.1)', () {
    /// The cell holding [value], by what is in its box.
    ///
    /// BY CONTENT AND NOT BY POSITION, because position is what these
    /// tests are least sure of and least interested in: an index into
    /// the visible columns would silently point at a different cell the
    /// day an optional column is turned on.
    Finder cellHolding(String value) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == value,
      description: 'a table cell reading "$value"',
    );

    testWidgets('typing a field label writes it through a Command', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      final linkId = h.doc.links.values.single.id;
      final before = h.doc.links[linkId]!.structureOrigin!.fieldLabel;

      await tester.enterText(cellHolding(before), 'LR-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(h.doc.links[linkId]!.structureOrigin!.fieldLabel, 'LR-1');
      // And the table followed, because it re-derived rather than
      // caching what it drew. The CELL, not `find.text`: the quick-add
      // bar's "just added" tail says the old label too, which is correct
      // of it — it reports what that line produced at the time.
      expect(cellHolding('LR-1'), findsOneWidget);
    });

    testWidgets('a duplicate label is REFUSED, and the cell goes back', (
      tester,
    ) async {
      // CR-113: unique project-wide across all Structure bodies. The
      // defect this forbids is two rows an installer cannot tell apart,
      // written silently through the ordinary edit path.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      final links = h.doc.links.values.toList();
      final first = links[0].structureOrigin!.fieldLabel;
      final second = links[1].structureOrigin!.fieldLabel;

      await tester.enterText(cellHolding(second), first);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        links[1].structureOrigin!.fieldLabel,
        second,
        reason: 'the write was refused, so the document did not move',
      );
      // THE SENTENCE IS ON SCREEN AND STAYS. A refusal that put the old
      // value back and said nothing would read as typing that vanished.
      expect(find.textContaining(first), findsWidgets);
      expect(find.textContaining('already'), findsWidgets);
    });

    testWidgets('ROUGH-IN is a dropdown over the five real values', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final linkId = h.doc.links.values.single.id;
      expect(h.doc.links[linkId]!.roughInStatus, RoughInStatus.planned);

      await tester.tap(find.text('PLANNED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PULLED').last);
      await tester.pumpAndSettle();

      expect(h.doc.links[linkId]!.roughInStatus, RoughInStatus.pulled);
    });

    testWidgets('a derived column is not typed into at all', (tester) async {
      // MEDIA names a registry entry. A text box that accepted `Cat6a`
      // into a `MediaTypeId` would be worse than a cell that cannot be
      // typed into, which is what `structureColumnIsEditable` says.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      final editable = kStructureDefaultColumns
          .where(structureColumnIsEditable)
          .toList();
      expect(editable, [
        StructureColumnId.fieldLabel,
        StructureColumnId.rackLabel,
        StructureColumnId.roughIn,
      ]);
      // Two text boxes on the row (the third editable default is the
      // dropdown), plus the quick-add field above the table.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('an empty NOTES box lands as unknown, never as an empty '
        'string (G4)', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final link = h.doc.links.values.single;

      expect(
        h.edit([
          StructureCellEdit(
            linkId: link.id,
            column: StructureColumnId.notes,
            value: 'coiled above the ceiling',
          ),
        ]),
        isNull,
      );
      expect(link.notes, 'coiled above the ceiling');

      expect(
        h.edit([
          StructureCellEdit(
            linkId: link.id,
            column: StructureColumnId.notes,
            value: '   ',
          ),
        ]),
        isNull,
      );
      expect(link.notes, isNull, reason: 'not the empty string');
    });

    testWidgets('a batch is ALL or NOTHING, and says which row stopped it', (
      tester,
    ) async {
      // This is the shape fill-down and paste both take. A batch that
      // wrote the good rows and reported the bad one would leave a
      // person to work out which rows moved.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');
      final links = h.doc.links.values.toList();
      final before = links.map((l) => l.structureOrigin!.fieldLabel).toList();

      final refusal = h.edit([
        StructureCellEdit(
          linkId: links[0].id,
          column: StructureColumnId.fieldLabel,
          value: 'LR-A',
        ),
        StructureCellEdit(
          linkId: links[1].id,
          column: StructureColumnId.fieldLabel,
          // COLLIDES WITH THE EDIT ABOVE, not with the document. Only
          // `alsoUsedLabels` can see this, which is why the batch is
          // planned as a batch.
          value: 'LR-A',
        ),
      ]);

      expect(refusal, isNotNull);
      expect(
        links.map((l) => l.structureOrigin!.fieldLabel),
        before,
        reason: 'the first edit must not have been applied either',
      );
    });
  });

  group('the grid operations #148 names', () {
    Finder cellHolding(String value) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == value,
      description: 'a table cell reading "$value"',
    );

    testWidgets('TAB ORDER IS THE WIDGET ORDER, with no binding for it', (
      tester,
    ) async {
      // The claim the design rests on: because every editable cell is a
      // real control rather than a label that becomes one, Flutter's own
      // traversal already walks them. If this fails, the cells stopped
      // being real controls and `kKeymap` owes a `Tab` row.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final labels = _rows(
        h,
      ).map((l) => l.structureOrigin!.fieldLabel).toList();

      await tester.tap(cellHolding(labels.first));
      await tester.pumpAndSettle();
      final first = primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocus, isNot(first));
      expect(primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('Ctrl+D fills ROUGH-IN down, which is the gesture that '
        'earns the key', (tester) async {
      // "Everything from here down is pulled" is what a person does
      // walking a job, and a status is legal to repeat where a label is
      // not — see the refusal beside this.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);

      expect(
        h.edit([
          StructureCellEdit(
            linkId: links[0].id,
            column: StructureColumnId.roughIn,
            value: roughInLabel(RoughInStatus.pulled),
          ),
        ]),
        isNull,
      );
      await tester.pumpAndSettle();

      // The second row's status cell. Clicking it is what puts the caret
      // there; `Esc` closes the menu the click opened without choosing.
      await tester.tap(find.text(roughInLabel(RoughInStatus.planned)).last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(links[1].roughInStatus, RoughInStatus.pulled);
    });

    testWidgets('and it REFUSES to fill a rack label down (CR-113)', (
      tester,
    ) async {
      // THE CASE THAT LOOKS LIKE A BUG AND IS THE FEATURE. Rack labels
      // are unique where set, so filling one down would put two rows on
      // one panel position. The refusal comes from the same builder a
      // typed cell goes through, so the grid operation cannot route
      // around it — which is the whole reason `onEdit` takes a list of
      // edits rather than writing values itself.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);

      expect(
        h.edit([
          StructureCellEdit(
            linkId: links[0].id,
            column: StructureColumnId.rackLabel,
            value: 'PP1-01',
          ),
        ]),
        isNull,
      );
      await tester.pumpAndSettle();

      // Row two's rack-label cell is empty, so it cannot be found by
      // content: reach it from the label cell beside it, one `Tab` away.
      await tester.tap(cellHolding(links[1].structureOrigin!.fieldLabel));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(links[1].structureOrigin!.rackLabel, isNull);
      expect(find.textContaining('unique where set'), findsOneWidget);
    });

    testWidgets('Ctrl+D on the first row says why it did nothing', (
      tester,
    ) async {
      // docs/04 §3.4: never silently do nothing. A grid operation that
      // declined without a reason is indistinguishable from an unbound
      // key.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final first = _rows(h).first.structureOrigin!.fieldLabel;

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kNothingAboveToFill), findsOneWidget);
    });

    testWidgets('Ctrl+D with no caret says where to put one', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kNoCaretForFill), findsOneWidget);
    });

    testWidgets('Ctrl+V pastes tab-separated cells from the caret', (
      tester,
    ) async {
      // docs/07 §5: the contractor's pull list arrives as a spreadsheet,
      // and a person with one open will try this before they go looking
      // for an importer.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);
      final first = links[0].structureOrigin!.fieldLabel;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'LR-A\tPP1-01\nLR-B\tPP1-02'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      // TWO COLUMNS AND TWO ROWS, from one keystroke.
      expect(links[0].structureOrigin!.fieldLabel, 'LR-A');
      expect(links[0].structureOrigin!.rackLabel, 'PP1-01');
      expect(links[1].structureOrigin!.fieldLabel, 'LR-B');
      expect(links[1].structureOrigin!.rackLabel, 'PP1-02');
    });

    testWidgets('a paste taller than the table creates nothing and says so', (
      tester,
    ) async {
      // THE DEFECT THIS FORBIDS: inventing cables from a spreadsheet.
      // Each would need a room, a media type and a label nobody chose.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final before = h.doc.links.length;
      final first = _rows(h).first.structureOrigin!.fieldLabel;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'LR-A\nLR-B\nLR-C'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(h.doc.links, hasLength(before));
      expect(
        _rows(h).first.structureOrigin!.fieldLabel,
        first,
        reason: 'the rows that WOULD have fitted are not written either',
      );
      expect(find.text(kPasteOverruns(3, 1)), findsOneWidget);
    });
  });
}
