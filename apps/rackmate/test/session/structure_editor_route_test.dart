// M3-C/2, #148 — `Project ▸ Structured wiring…` reaches the editor, and
// what is typed into it lands in the real document.
//
// WHY THIS FILE EXISTS SEPARATELY FROM THE WIDGET TESTS. Those drive
// `StructureEditorScreen` against a harness that stands in for the app.
// This drives the APP: the real menu, the real `DocumentController`, the
// real clock and actor, and the real undo stack. A perfect wiring nothing
// opens is the shape M2-F found on `doc.ports` and M3-A/1 found on
// `StructureBody` — a mechanism no gesture reaches — and it is the shape
// this project has produced twice.
//
// IT ALSO PINS WHAT LEFT. `Add drops…` and `Add outlet…` were on the
// Project menu only until this editor existed; both said so in their own
// doc comments. A test that only checked the new item would let one of
// them quietly survive as a second route to the same surface.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate/src/session/structure_edit_actions.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session_fakes.dart';

final _when = DateTime.utc(2026, 8, 8);

/// A REAL BLANK PROJECT, not `buildDemoRackDocument`. The demo document
/// leaves `registries` at its empty default, so `Cat6` resolves to no
/// media type and every quick-add line is refused: the editor would be
/// reachable and useless, and a test driving it would prove the wrong
/// thing. `buildBlankDocument` is what `File ▸ New` produces, seeded the
/// DR-010 way.
RackDocument _project({List<(String, String)> rooms = const []}) {
  final doc = buildBlankDocument(now: _when, appVersion: '0.1.0');
  for (final (name, code) in rooms) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _when,
      actor: 'test',
    ).apply(doc);
  }
  return doc;
}

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

  /// The editor's quick-add field, and not the palette's search box one
  /// tab behind it.
  final quickAdd = find.descendant(
    of: find.byType(StructureEditorScreen),
    matching: find.byType(TextField),
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Structured wiring…'));
    await tester.pumpAndSettle();
  }

  testWidgets('Project ▸ Structured wiring… opens the editor (AC-048)', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    expect(find.byType(StructureEditorScreen), findsOneWidget);
    // AC-048: it OPENS IN TABLE MODE. The columns are the proof, and
    // they are there before a single drop exists.
    for (final id in kStructureDefaultColumns) {
      expect(find.text(structureColumnHeader(id)), findsOneWidget);
    }
  });

  testWidgets('the two temporary items it replaces are gone', (tester) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.text('Locations…'), findsOneWidget);
    // CR-110'S OWN WORDS. The ruling names this item, and a menu that
    // paraphrases a ruling is a menu the corpus cannot be searched for.
    expect(find.text('Structured wiring…'), findsOneWidget);
    expect(find.text('Add drops…'), findsNothing);
    expect(find.text('Add outlet…'), findsNothing);
  });

  testWidgets('a line typed there lands in the real document', (tester) async {
    // THE WHOLE ROUND TRIP: menu, quick-add bar, real controller. It also
    // pins that the app's actor reaches `EntityMeta`, which is the defect
    // `DropEntryActions.onCommit` exists to prevent — the preview plans
    // with `actor: 'preview'` and those values must never be the ones
    // that land.
    final built = await buildTestApp(
      measurer,
      document: _project(rooms: [('Living Room', 'LR')]),
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final doc = built.session.services.session.document;

    await openEditor(tester);
    expect(doc.structures, isEmpty, reason: 'a new project has no body');

    // SCOPED TO THE EDITOR. The rack tab's palette search is a
    // `TextField` too, and it is still in the tree behind this dialog.
    await tester.enterText(quickAdd, 'Living Room: 2x Cat6, 1x RG6');
    await tester.pumpAndSettle();

    // TWO PRESSES OF ONE KEY, AND THAT IS THE DESIGN. A blank project has
    // no Structure device, so the first `Enter` takes the panel's offer
    // and creates one; the line is kept, not cleared, so the second
    // `Enter` commits it. `Enter` is the only commit and a refusal never
    // costs the typing, which is `drop_entry_panel.dart`'s whole loop.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(doc.structures, hasLength(1));
    expect(buildStructureTable(doc).dropCount, 0);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(buildStructureTable(doc).dropCount, 3);
    expect(
      doc.links.values.map((l) => l.meta.updatedBy),
      isNot(contains('preview')),
    );
  });

  testWidgets('and the table it is typed into shows the rows', (tester) async {
    final built = await buildTestApp(
      measurer,
      document: _project(rooms: [('Kitchen', 'KIT')]),
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    expect(find.text(kNoDropsHeadline), findsOneWidget);

    await tester.enterText(quickAdd, 'Kitchen: 2x Cat6');
    await tester.pumpAndSettle();
    // The first press creates the Structure body, the second commits.
    // See the previous test.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The band, and the empty state gone: the editor rebuilt on the live
    // document rather than on the one it opened with.
    expect(find.text('KITCHEN (KIT)'), findsOneWidget);
    expect(find.text(kNoDropsHeadline), findsNothing);
  });

  testWidgets('Add outlet opens the template picker over it (DR-024)', (
    tester,
  ) async {
    final built = await buildTestApp(measurer, document: _project());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();

    await openEditor(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add outlet'));
    await tester.pumpAndSettle();

    expect(find.byType(OutletTemplatePicker), findsOneWidget);
    // The nine seeded templates are what it offers (CR-108, M3-C/4).
    expect(find.text('TV location'), findsOneWidget);
  });

  group('a typed cell is a Command on the real undo stack', () {
    /// A project with a Structure body and three drops in one room, made
    /// through the real commands rather than by hand.
    (RackDocument, List<Uuid>) seeded() {
      final doc = _project(rooms: [('Living Room', 'LR')]);
      AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: _when,
        actor: 'test',
      ).apply(doc);
      final parsed = parseDropLine('Living Room: 3x Cat6') as DropLineParsed;
      final plan =
          planDropLine(doc: doc, line: parsed, now: _when, actor: 'test')
              as DropLinePlanReady;
      for (final c in plan.commands) {
        c.apply(doc);
      }
      return (doc, doc.links.keys.toList());
    }

    testWidgets('editing a label undoes as ONE step', (tester) async {
      final (doc, linkIds) = seeded();
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;

      final edit = buildStructureEditAction(controller: controller);
      final before = doc.links[linkIds.first]!.structureOrigin!.fieldLabel;
      expect(
        edit([
          StructureCellEdit(
            linkId: linkIds.first,
            column: StructureColumnId.fieldLabel,
            value: 'LR-TV-1',
          ),
        ]),
        isNull,
      );

      expect(doc.links[linkIds.first]!.structureOrigin!.fieldLabel, 'LR-TV-1');
      // ONE FIELD WRITE READS AS "edit", which is the label the corpus
      // already chose for a single property (LabelKey.setEntityProperty).
      expect(controller.undo.undoLabelKey, LabelKey.setEntityProperty.name);

      controller.undoLast();
      expect(doc.links[linkIds.first]!.structureOrigin!.fieldLabel, before);
    });

    testWidgets('a bulk edit undoes as one step and reports itself as one', (
      tester,
    ) async {
      final (doc, linkIds) = seeded();
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;

      final edit = buildStructureEditAction(controller: controller);
      expect(
        edit([
          for (final id in linkIds)
            StructureCellEdit(
              linkId: id,
              column: StructureColumnId.roughIn,
              value: roughInLabel(RoughInStatus.pulled),
            ),
        ]),
        isNull,
      );

      expect(
        doc.links.values.map((l) => l.roughInStatus),
        everyElement(RoughInStatus.pulled),
      );
      // AND IT NAMES ITSELF AS A FILL, not as an edit: an Edit menu
      // offering "Undo edit" for something that moved three rows names a
      // third of what it is about to take back.
      expect(controller.undo.undoLabelKey, LabelKey.fillCells.name);

      controller.undoLast();
      expect(
        doc.links.values.map((l) => l.roughInStatus),
        everyElement(RoughInStatus.planned),
      );
    });

    testWidgets('a batch that collides applies NONE of itself', (tester) async {
      final (doc, linkIds) = seeded();
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;

      final edit = buildStructureEditAction(controller: controller);
      final before = [
        for (final id in linkIds) doc.links[id]!.structureOrigin!.fieldLabel,
      ];
      final depth = controller.undo.depth;

      final refusal = edit([
        StructureCellEdit(
          linkId: linkIds[0],
          column: StructureColumnId.fieldLabel,
          value: 'LR-A',
        ),
        StructureCellEdit(
          linkId: linkIds[1],
          column: StructureColumnId.fieldLabel,
          // Collides with the edit above and NOT with the document, which
          // is the case only `alsoUsedLabels` can see.
          value: 'LR-A',
        ),
      ]);

      expect(refusal, contains('LR-A'));
      expect(
        [for (final id in linkIds) doc.links[id]!.structureOrigin!.fieldLabel],
        before,
      );
      // NOTHING WAS PUSHED EITHER. A refused batch that still cost an
      // undo step would make the next Ctrl+Z do nothing visible.
      expect(controller.undo.depth, depth);
    });
  });

  group('the as-built columns (M3-J/3, DR-020 §11.19.2(5))', () {
    /// A body with [count] drops in one room, through the real commands.
    (RackDocument, List<Uuid>) job(int count) {
      final doc = _project(rooms: [('Living Room', 'LR')]);
      AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: _when,
        actor: 'test',
      ).apply(doc);
      final parsed =
          parseDropLine('Living Room: ${count}x Cat6') as DropLineParsed;
      final plan =
          planDropLine(doc: doc, line: parsed, now: _when, actor: 'test')
              as DropLinePlanReady;
      for (final c in plan.commands) {
        c.apply(doc);
      }
      return (
        doc,
        buildStructureTable(
          doc,
        ).groups.single.rows.map((r) => r.linkId).toList(),
      );
    }

    testWidgets('a length is whole units, and 62.5 is refused', (
      tester,
    ) async {
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.terminatedLength,
            value: '62',
          ),
        ]),
        isNull,
      );
      expect(doc.links[ids.first]!.terminatedLength, const Len(62 * 304800000));

      // AND THE REFUSAL IS CORE'S SENTENCE, so the rule has one voice.
      final refusal = edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.terminatedLength,
          value: '62.5',
        ),
      ]);
      expect(refusal, contains('whole feet'));
      expect(doc.links[ids.first]!.terminatedLength, const Len(62 * 304800000));
    });

    testWidgets('a splice count keeps 0 and cleared apart', (tester) async {
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      expect(doc.links[ids.first]!.spliceCount, isNull);
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.spliceCount,
          value: '0',
        ),
      ]);
      expect(
        doc.links[ids.first]!.spliceCount,
        0,
        reason: 'somebody looked and there are none (DR-020 §11.19.2(3))',
      );
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.spliceCount,
          value: '',
        ),
      ]);
      expect(doc.links[ids.first]!.spliceCount, isNull);
    });

    testWidgets('a certificate needs a result to identify (G4)', (
      tester,
    ) async {
      // `TestResult` requires `pass`, so accepting a certificate on an
      // untested cable would mean writing a verdict nobody gave, on the
      // one column whose whole purpose is to be evidence.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      final refusal = edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.certificateId,
          value: 'C-0001',
        ),
      ]);
      expect(refusal, contains('Record the test result first'));
      expect(doc.links[ids.first]!.test, isNull);

      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.testResult,
          value: kTestPassCell,
        ),
      ]);
      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.certificateId,
            value: 'C-0001',
          ),
        ]),
        isNull,
      );
      expect(doc.links[ids.first]!.test!.certificateId, 'C-0001');
    });

    testWidgets('re-testing a failed run keeps its certificate', (
      tester,
    ) async {
      // Changing the verdict is not the same act as re-certifying, so the
      // tester's own recorded evidence rides along.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.testResult,
          value: kTestFailCell,
        ),
      ]);
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.certificateId,
          value: 'C-0007',
        ),
      ]);
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.testResult,
          value: kTestPassCell,
        ),
      ]);

      expect(doc.links[ids.first]!.test!.pass, isTrue);
      expect(doc.links[ids.first]!.test!.certificateId, 'C-0007');
    });

    testWidgets('FIELD TERM can go back to unknown (M3-J/1)', (tester) async {
      // The whole reason the field is nullable: `unterminated` is a
      // DECISION and a drop at rough-in has no answer. A control that
      // could not return to unknown would make the second state
      // unreachable once anybody guessed.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.fieldTerm,
          value: terminationLabel(TerminationType.keystone),
        ),
      ]);
      expect(
        doc.links[ids.first]!.structureOrigin!.terminationField,
        TerminationType.keystone,
      );

      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.fieldTerm,
          value: kUnknownCell,
        ),
      ]);
      expect(doc.links[ids.first]!.structureOrigin!.terminationField, isNull);
    });

    testWidgets('closing out sixty runs costs three gestures, not sixty '
        'inspector visits', (tester) async {
      // THE MEASUREMENT THE BRIEF ASKS FOR, in the shape M3-C/1 took its
      // own: "the ergonomics are the feature, not the columns", and "a
      // tally that costs an inspector visit per cable has not shipped".
      //
      // WHAT IT CAN AND CANNOT MEASURE. It cannot time a person. What it
      // can measure is how many EDIT GESTURES the surface demands to
      // close out sixty runs, which is the part the design controls.
      final (doc, ids) = job(60);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final edit = buildStructureEditAction(controller: controller);

      var gestures = 0;
      String? apply(StructureColumnId column, String value) {
        gestures++;
        return edit([
          for (final id in ids)
            StructureCellEdit(linkId: id, column: column, value: value),
        ]);
      }

      // Three fills over sixty rows: everything is tested, everything was
      // landed on the same day, and the crew is the same crew.
      expect(apply(StructureColumnId.testResult, kTestPassCell), isNull);
      expect(apply(StructureColumnId.terminatedAt, '2026-08-08'), isNull);
      expect(apply(StructureColumnId.installedBy, 'Kelly'), isNull);

      expect(gestures, 3);
      expect(doc.links, hasLength(60));
      for (final id in ids) {
        expect(doc.links[id]!.test!.pass, isTrue);
        expect(doc.links[id]!.terminatedAt, DateTime.utc(2026, 8, 8));
        expect(doc.links[id]!.installedBy, 'Kelly');
      }
      // THREE UNDO STEPS FOR THREE GESTURES, not 180 for 180 writes. Each
      // fill is one `LabelKey.fillCells` transaction, so backing out "we
      // marked them all tested" is one keystroke.
      expect(controller.undo.depth, 3);
      controller.undoLast();
      expect(doc.links[ids.first]!.installedBy, isNull);
      expect(
        doc.links[ids.first]!.test!.pass,
        isTrue,
        reason: 'one gesture came back, not all three',
      );
    });
  });
}
