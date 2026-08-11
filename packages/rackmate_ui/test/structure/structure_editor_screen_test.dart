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

  /// The Structure body the last `Add outlet` was opened on (#158).
  Uuid? outletPickerBody;

  StructureEditorActions get actions => StructureEditorActions(
    dropEntry: DropEntryActions(
      onCommit: (line, {structureBodyId}) {
        final plan = planDropLine(
          doc: doc,
          structureBodyId: structureBodyId,
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
    // The harness records the BODY it was handed, not just the click,
    // because #158's whole point is that the picker's selection reaches
    // the gesture.
    onAddOutlet: (bodyId) {
      outletPickerOpened++;
      outletPickerBody = bodyId;
    },
    onEdit: edit,
    onSetCount: setCount,
    onEditPathways: editPathways,
    onAddPathway: addPathway,
    onRemovePathway: removePathway,
    onImportCsv: (bodyId) async {
      importCsvOpened++;
      importCsvBody = bodyId;
    },
    outlets: outletsActions,
  );

  /// M3-H/2 (#167). The Outlets tab's five gestures, applied straight to
  /// [doc] the way every other callback in this harness is: the commands
  /// are core's and this file may not reach for a `DocumentController`.
  /// `outlets_view_test.dart` drives the tab itself; this exists so the
  /// editor's own tests can reach it.
  OutletsActions get outletsActions => OutletsActions(
    onAddGang: (outletId) {
      AddGangCommand(outletId: outletId).apply(doc);
      return null;
    },
    onRemoveGang: (outletId, gangIndex) {
      RemoveGangCommand(outletId: outletId, index: gangIndex).apply(doc);
      return null;
    },
    onSetStrap: (outletId, gangIndex, width, height) {
      SetStrapSizeCommand(
        outletId: outletId,
        index: gangIndex,
        width: width,
        height: height,
      ).apply(doc);
      return null;
    },
    onSetCell: (outletId, gangIndex, cellIndex, occupant) {
      SetCellOccupantCommand(
        outletId: outletId,
        gangIndex: gangIndex,
        cellIndex: cellIndex,
        occupant: occupant,
      ).apply(doc);
      return null;
    },
    onArrange: (outletId, plan) {
      final outlet = doc.outlets[outletId];
      if (outlet == null) return 'no such outlet';
      // BACK TO FRONT, the same hazard the app's own arrange documents:
      // gangs are addressed by position and removing gang 0 renumbers
      // every one after it.
      for (var i = outlet.gangs.length - 1; i >= 0; i--) {
        RemoveGangCommand(outletId: outletId, index: i).apply(doc);
      }
      for (final strap in plan.straps) {
        AddGangCommand(
          outletId: outletId,
          width: strap.width,
          height: strap.height,
        ).apply(doc);
      }
      for (final cell in plan.cells) {
        SetCellOccupantCommand(
          outletId: outletId,
          gangIndex: cell.gangIndex,
          cellIndex: cell.cellIndex,
          occupant: cell.occupant,
        ).apply(doc);
      }
      return null;
    },
  );

  /// M3-F/2 (#160). Recorded rather than acted on: the whole import flow
  /// is the app layer's, because it opens a native file dialog and reads
  /// a file, and neither exists in `rackmate_ui`. What this surface owes
  /// is that the control is there and hands over the body it is showing.
  int importCsvOpened = 0;

  /// The Structure body the last `Import CSV…` was opened on, which is
  /// the same #158 question `Add outlet` answers: an import filed on the
  /// wrong panel puts sixty drops on the wrong sheet.
  Uuid? importCsvBody;

  /// What `apps/rackmate`'s three pathway actions do, in the shape they
  /// do them. Mirrored for [edit]'s reason: `rackmate_ui` may not depend
  /// on the app, and the harness has to be driveable without a
  /// `DocumentController`. `pathways_view_test.dart` drives the tab
  /// itself; this exists so the editor's own tests can reach the tab.
  String? editPathways(List<PathwayCellEdit> edits) {
    for (final e in edits) {
      final Command? command;
      switch (e.column) {
        // Spelled out per column for `edit`'s reason: `EntityField`'s
        // `set` is a typed closure, so `<Object?>` compiles and throws at
        // apply time.
        // THROUGH THE REFUSING BUILDER, matching the app's real path.
        // `buildSetEntityProperty` would write a duplicate designator
        // silently, and a harness that is laxer than the product tests
        // a product that does not exist (DR-026 §11.25.1).
        case PathwayColumnId.designator:
          final result = buildSetPathwayDesignator(
            doc: doc,
            pathwayId: e.pathwayId,
            to: e.value,
            now: _now,
            actor: 'editor',
          );
          if (result is SetPathwayDesignatorRefused) return result.reason;
          // Unchanged is not a refusal: nothing to push, nothing wrong.
          command = result is SetPathwayDesignatorReady ? result.command : null;
        case PathwayColumnId.name:
          command = buildSetEntityProperty<Pathway, String>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.name,
            to: e.value.trim(),
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.kind:
          final kind = PathwayKind.values
              .where((k) => pathwayKindLabel(k) == e.value.trim().toUpperCase())
              .firstOrNull;
          if (kind == null) return '"${e.value}" is not a pathway kind.';
          command = buildSetEntityProperty<Pathway, PathwayKind>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.kind,
            to: kind,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.lineVoltage:
          command = buildSetEntityProperty<Pathway, bool>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.containsLineVoltage,
            to: e.value.trim().toUpperCase() == kLineVoltageYesCell,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.media:
        case PathwayColumnId.nominalLength:
        case PathwayColumnId.notes:
        case PathwayColumnId.runs:
          return null;
      }
      if (command != null) command.apply(doc);
    }
    return null;
  }

  String? addPathway() {
    AddPathwayCommand(
      name: 'New pathway',
      order: nextPathwayOrder(doc),
      now: _now,
      actor: 'adder',
    ).apply(doc);
    return null;
  }

  String? removePathway(Uuid id) {
    RemovePathwayCommand(id: id, now: _now).apply(doc);
    return null;
  }

  /// What `apps/rackmate`'s `buildStructureMatrixAction` does, in the
  /// shape it does it: plan against the live document, refuse whole,
  /// then apply. Mirrored here for `edit`'s reason — `rackmate_ui` may
  /// not depend on the app, and the harness has to be driveable without
  /// a `DocumentController`.
  String? setCount(StructureMatrixEdit edit) {
    final plan = planMatrixCell(
      doc: doc,
      locationId: edit.locationId,
      media: edit.media,
      targetCount: edit.targetCount,
      structureBodyId: edit.structureBodyId,
      now: _now,
      actor: 'gridder',
    );
    switch (plan) {
      case MatrixCellRefused(:final reason):
        return reason;
      case MatrixCellUnchanged():
        return null;
      case MatrixCellNeedsStructure():
        return 'This project has no Structure device yet.';
      case MatrixCellReady(:final commands):
        for (final c in commands) {
          c.apply(doc);
        }
        return null;
    }
  }

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

/// The drop count the STATUS BAR is showing, which is the table's own
/// count for the body currently selected.
///
/// READ OFF THE SCREEN rather than recomputed, because the question is
/// what the editor is showing and not what a builder would return if
/// asked the same thing twice.
int _visibleDropCount(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .firstWhere((d) => RegExp(r'^\d+ drops · ').hasMatch(d));
  return int.parse(RegExp(r'^(\d+) drops').firstMatch(text)!.group(1)!);
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  // A WINDOW, NOT A PHONE. The default 800×600 test surface is smaller
  // than any window this editor opens in: `showStructureEditor` uses
  // `Dialog.fullscreen`.
  //
  // FOUND BY M3-F/2, and the finding is about the tests rather than the
  // screen. These cases asserted that three drops are all visible at
  // 600 px, and that held only because the harness passes no `onDone`,
  // so the header rendered with NO BUTTON IN IT and collapsed to 24 px.
  // Production always has `Done`, so production's header has always been
  // 48 px and has always shown one fewer row than these tests claimed.
  // Adding `Import CSV…` made the test header match production and the
  // gap became visible. Sizing the surface to a real window fixes the
  // representation rather than the assertion.
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
///
/// SCOPED TO THE LOOP'S OWN FIELD. Every editable cell on either tab is
/// a real `TextField` (that is what buys the tab order), so an unscoped
/// `find.byType(TextField)` stops meaning the quick-add bar the moment
/// there is one drop or one room on screen.
Future<void> _addLine(WidgetTester tester, String line) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(DropEntryLoop),
      matching: find.byType(TextField),
    ),
    line,
  );
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

/// The room called [name].
Uuid _roomId(_Harness h, String name) =>
    h.doc.locations.values.firstWhere((l) => l.name == name).id;

/// Switches to §4.2's grid the way a person does.
Future<void> _showMatrix(WidgetTester tester) async {
  await tester.tap(find.text(kMatrixTabLabel));
  await tester.pumpAndSettle();
}

/// The matrix the screen is drawing, with the same columns it seeds.
StructureMatrix _matrix(_Harness h) => buildStructureMatrix(
  h.doc,
  alsoColumns: kStructureMatrixSeedColumns.toSet(),
);

/// One grid cell, found the way the grid lays it out: the row keyed on
/// the room, then the Nth `TextField` in it.
///
/// A POSITIONAL FINDER AND NOT A KEY PER CELL, because the position is
/// the thing under test: a cell that wrote to the wrong column would be
/// invisible to a finder that asked for the column by name.
Finder _cell(_Harness h, Uuid locationId, MediaTypeId media) => find
    .descendant(
      of: find.byKey(ValueKey(locationId)),
      matching: find.byType(TextField),
    )
    .at(_matrix(h).columns.indexOf(media));

/// What a grid cell says on screen.
String _shows(WidgetTester tester, Finder cell) =>
    tester.widget<TextField>(cell).controller!.text;

/// Types [value] into a grid cell and commits it.
Future<void> _type(WidgetTester tester, Finder cell, String value) async {
  await tester.enterText(cell, value);
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

const MediaTypeId _cat6 = MediaTypeId('media.cat6');
const MediaTypeId _rg6 = MediaTypeId('media.rg6');

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
        // STILL ABSENT AFTER M3-E/1, and the distinction is the tab's
        // own scoping: `[ Pathways ]` LISTS AND EDITS the pathways that
        // exist and does not assign runs to them. Grouping needs a
        // command nothing has written, and the user's stated expectation
        // is that a pathway is set in the Plan view once somebody has
        // walked the run.
        'Group into pathway',
        'Renumber…',
        // `Import CSV…` LEFT THIS LIST AT M3-F/2 (#160), which is the
        // bookkeeping this test is for. `Export CSV` stays, and its
        // reason is now different from the other three: it is not
        // unbuilt-for-lack-of-a-command but UNRULED. docs/07 §5.3's
        // closing line promises the round trip and roadmap §2, the one
        // scope list, does not name it, so #653 asks for a ruling rather
        // than an afternoon.
        'Export CSV',
        // `Matrix` LEFT THIS LIST AT M3-C/3, `Pathways` at M3-E/1 and
        // `Outlets` at M3-H/2 (#167), which is the bookkeeping this test
        // is for: the day one is built the test says the others still
        // are not. THE TAB LIST IS NOW EMPTY and what remains here is
        // two button-bar controls plus one that is unruled rather than
        // unbuilt.
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

  // ══════════════════════════════════════════════════════════════════
  // M3-C/3, #149 — THE MATRIX AS A TAB
  // ══════════════════════════════════════════════════════════════════

  group('THE TAB STRIP IS FOUR TABS, and the editor opens on the first', () {
    testWidgets('AC-048: it opens in table mode', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      // The table's own header is on screen and the grid's TOTAL row is
      // not, which is the difference a person sees.
      expect(
        find.text(structureColumnHeader(StructureColumnId.media)),
        findsOneWidget,
      );
      expect(find.text(kMatrixTotalLabel), findsNothing);
    });

    testWidgets('four are offered, because four are built', (tester) async {
      // §4 draws four and the strip finally has four. `Pathways` joined
      // at M3-E/1 (#156) and `Outlets` at M3-H/2 (#167); until the
      // latter this case asserted `Outlets` was ABSENT, because a tab
      // that opens nothing is `UnbuiltView` in a different hat.
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kTableTabLabel), findsOneWidget);
      expect(find.text(kMatrixTabLabel), findsOneWidget);
      expect(find.text(kOutletsTabLabel), findsOneWidget);
      expect(find.text(kPathwaysTabLabel), findsOneWidget);
    });

    testWidgets('the Pathways tab opens a real surface', (tester) async {
      // The claim this asserts is the one the strip's own comment makes:
      // no tab here opens nothing. `PathwaysView` renders its own empty
      // state on a project with no pathways, which is a surface, not a
      // blank.
      final h = _Harness(_project());
      await _pump(tester, h);
      await tester.tap(find.text(kPathwaysTabLabel));
      await tester.pumpAndSettle();

      expect(find.byType(PathwaysView), findsOneWidget);
      expect(find.text(kAddPathwayLabel), findsOneWidget);
    });

    testWidgets('the strip is in §4 order, and Pathways did not move', (
      tester,
    ) async {
      // THE PAYOFF OF HOLDING THE SLOT. `Pathways` shipped in third
      // POSITION while occupying §4's fourth SLOT, precisely so that
      // `Outlets` arriving would not move it under the hand of anybody
      // who had learned where it was. It did not.
      final h = _Harness(_project());
      await _pump(tester, h);

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(SegmentedButton<StructureEditorTab>),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(labels, [
        kTableTabLabel,
        kMatrixTabLabel,
        kOutletsTabLabel,
        kPathwaysTabLabel,
      ]);
    });

    testWidgets('switching shows the grid and the table goes away', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kMatrixTotalLabel), findsOneWidget);
      expect(
        find.text(structureColumnHeader(StructureColumnId.media)),
        findsNothing,
      );
    });

    testWidgets('the repeat loop is NOT re-established on the second tab', (
      tester,
    ) async {
      // #149's whole instruction: "a matrix that is its own screen is a
      // second place the repeat loop has to be re-established". The same
      // widget sits above both tabs, so a line typed with the grid
      // showing lands in the grid.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.byType(DropEntryLoop), findsOneWidget);
      await _addLine(tester, 'Living Room: 3x Cat6');

      expect(_shows(tester, _cell(h, _roomId(h, 'Living Room'), _cat6)), '3');
    });

    testWidgets('and the status bar counts the same drops on both tabs', (
      tester,
    ) async {
      // ONE STATUS BAR, one set of counts, whichever view is up. The
      // exact string rather than a substring, because the band header on
      // the table tab also says "3 drops" and this is about the bar.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');
      const summary =
          '3 drops · 0 connected · 3 spare · 1 outlets · '
          '0 pathways';
      expect(find.text(summary), findsOneWidget);

      await _showMatrix(tester);
      expect(find.text(summary), findsOneWidget);
    });

    testWidgets('Ctrl+D on the matrix says so rather than doing nothing', (
      tester,
    ) async {
      // The bindings act on a TABLE cell. Saying that is docs/04 §3.4;
      // printing "put the caret in a cell first" at somebody whose caret
      // is in a grid cell would be worse than an unbound key.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kGridKeysAreTableOnly), findsOneWidget);
    });
  });

  group('THE GRID SHOWS THE DERIVATION AND NOTHING IT COUNTED ITSELF', () {
    testWidgets('every cell is the number buildStructureMatrix produced', (
      tester,
    ) async {
      // The same gate the table has, in the grid's terms: not "the cell
      // says 4", but "every cell says whatever core says it says".
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      await _addLine(tester, 'Kitchen: 1x Cat6');
      await _showMatrix(tester);

      final matrix = _matrix(h);
      expect(matrix.rows, hasLength(2));
      for (final row in matrix.rows) {
        for (var c = 0; c < matrix.columns.length; c++) {
          expect(
            _shows(tester, _cell(h, row.locationId!, matrix.columns[c])),
            '${row.counts[c]}',
            reason: '${row.title} by ${matrix.columns[c].v}',
          );
        }
      }
    });

    testWidgets('the grid total is the table drop count', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      await _showMatrix(tester);

      expect(_matrix(h).dropCount, buildStructureTable(h.doc).dropCount);
      expect(find.text(kMatrixTotalLabel), findsOneWidget);
    });

    testWidgets('an empty room is a row of zeroes, not a missing row', (
      tester,
    ) async {
      // The table omits an empty room and the grid must not: a `0` cell
      // is where a person types `2`.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await _showMatrix(tester);

      final kit = _roomId(h, 'Kitchen');
      expect(find.byKey(ValueKey(kit)), findsOneWidget);
      expect(_shows(tester, _cell(h, kit, _cat6)), '0');
    });
  });

  group('TYPING A CELL', () {
    testWidgets('0 to 2 creates two drops, and the table tab has them', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      await _type(tester, _cell(h, _roomId(h, 'Living Room'), _cat6), '2');

      expect(h.doc.links, hasLength(2));
      await tester.tap(find.text(kTableTabLabel));
      await tester.pumpAndSettle();
      expect(buildStructureTable(h.doc).groups.single.rows, hasLength(2));
    });

    testWidgets('lowering it deletes the highest-sequence spare runs', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6');
      final kept = _rows(h).take(2).map((l) => l.id).toList();
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), '2');

      expect(h.doc.links.keys, unorderedEquals(kept));
      expect(_shows(tester, _cell(h, lr, _cat6)), '2');
    });

    testWidgets('a word is refused, the cell springs back and it says why', (
      tester,
    ) async {
      // CR-017's spring-back. A cell that kept the typed text would be
      // showing something no document holds.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), 'two');

      expect(h.doc.links, hasLength(2));
      expect(_shows(tester, _cell(h, lr, _cat6)), '2');
      expect(
        find.textContaining('cannot hold fewer than no drops'),
        findsOneWidget,
      );
    });

    testWidgets('one column does not disturb the one beside it', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), '4');
      await _type(tester, _cell(h, lr, _rg6), '2');

      expect(_shows(tester, _cell(h, lr, _cat6)), '4');
      expect(_shows(tester, _cell(h, lr, _rg6)), '2');
    });
  });

  group('THE COLUMNS AND THE EMPTY STATE', () {
    testWidgets('the grid opens on §4.2 nine columns, EMT among them', (
      tester,
    ) async {
      // THIS USED TO ASSERT EIGHT with conduit excluded, because the
      // ninth column creates a `Pathway` and nothing in the build could.
      // M3-E/1 built it, so the grid opens on the wireframe's own nine.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(_matrix(h).columns, hasLength(9));
      expect(
        _matrix(h).columns.last,
        const MediaTypeId('media.conduit_emt'),
      );
    });

    testWidgets('and the EMT column is excluded from the Σ', (tester) async {
      // §4.2 in as many words: the cells are "tinted and excluded from
      // the Σ drop count (CR-109)". Conduit is not a cable, so a conduit
      // inside the Σ is one item of a total somebody orders cable from.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await _addLine(tester, 'Living Room: 1x ENT');
      await _showMatrix(tester);

      final row = _matrix(
        h,
      ).rows.firstWhere((r) => r.title == 'Living Room');
      expect(row.dropCount, 2);
      expect(row.pathwayCount, 1);
    });

    testWidgets('Media column is offered, and it is the only add path', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kAddMediaColumnLabel), findsOneWidget);
      // §4.2's wireframe also draws `+ Room`, and the loop above the
      // grid plus CR-112's panel are already two paths to that rule.
      expect(find.text('Room'), findsNothing);
    });

    testWidgets('a project with no rooms says so, and names the field', (
      tester,
    ) async {
      final h = _Harness(_project(rooms: const []));
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kNoRoomsHeadline), findsOneWidget);
      expect(find.text(kNoRoomsDetail), findsOneWidget);

      // AND THE INSTRUCTION IT GIVES IS ONE THIS SURFACE CARRIES OUT.
      // Two presses, not one: the room does not exist, so the first
      // `Enter` takes M3-C/1's offer to create it and the second commits
      // the line — which is the loop working, above a tab it knows
      // nothing about.
      await _addLine(tester, 'Attic: 2x Cat6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text(kNoRoomsHeadline), findsNothing);
      expect(h.doc.links, hasLength(2));
      expect(_shows(tester, _cell(h, _roomId(h, 'Attic'), _cat6)), '2');
    });
  });

  group('TWO STRUCTURE BODIES (M3-E/3, #158, CR-113)', () {
    /// Adds a second panel to an existing harness document.
    Uuid addSecondPanel(_Harness h) {
      final command = AddStructureCommand(
        title: 'Guest House Panel',
        designator: 'STR-2',
        now: _now,
        actor: 't',
      )..apply(h.doc);
      return command.bodyId;
    }

    testWidgets('no picker on a ONE-panel project', (tester) async {
      // The ordinary case gains no chrome. A dropdown with one entry is a
      // control that cannot be used and still has to be read past.
      final h = _Harness(_project());
      await _pump(tester, h);
      expect(find.byKey(kStructureBodyPickerKey), findsNothing);
      // The header still NAMES the body in its subtitle; what is absent
      // is the control. Asserting the text was absent would have been a
      // claim about the wrong widget, and it failed for that reason.
      expect(find.text('STR-1 · Media Panel'), findsOneWidget);
    });

    testWidgets('a picker appears the moment there are two', (tester) async {
      final h = _Harness(_project());
      addSecondPanel(h);
      await _pump(tester, h);

      expect(find.byKey(kStructureBodyPickerKey), findsOneWidget);
      // Opens on the FIRST body by designator order, never on "all".
      expect(find.text('STR-1 · Media Panel'), findsWidgets);
    });

    testWidgets("switching the picker changes which body's drops show", (
      tester,
    ) async {
      // DRIVEN THROUGH THE CONTROL rather than by calling the builder
      // with two different ids. The builder was always able to filter;
      // what did not exist was any way for a person to ask it to, and a
      // test that calls it directly would pass on the tree as it was
      // before this task.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      expect(h.doc.links, hasLength(2));

      addSecondPanel(h);
      await _pump(tester, h);
      // STR-1 is selected, so its two drops are on screen.
      expect(find.text(kNoRoomsHeadline), findsNothing);
      expect(_visibleDropCount(tester), 2);

      await tester.tap(find.byKey(kStructureBodyPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('STR-2 · Guest House Panel').last);
      await tester.pumpAndSettle();

      // STR-2 has no drops of its own. Before the picker existed the
      // table merged both bodies and would still have shown two.
      expect(_visibleDropCount(tester), 0);
    });

    testWidgets('Add outlet opens on the body the picker is showing', (
      tester,
    ) async {
      // THE ASSERTION THAT MATTERS. Before #158 this button reached a
      // planner that refused outright on a two-panel project, so the
      // gesture was dead. Now it carries the selection.
      final h = _Harness(_project());
      addSecondPanel(h);
      await _pump(tester, h);

      await tester.tap(find.text('Add outlet'));
      await tester.pumpAndSettle();

      expect(h.outletPickerOpened, 1);
      expect(
        h.outletPickerBody,
        defaultStructureBody(h.doc)!.id,
        reason: 'the picker opened on STR-1, so the outlet goes to STR-1',
      );
    });
  });
}
