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
import 'package:rackmate/src/session/structure_matrix_actions.dart';
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

    testWidgets('a bulk SERVICE set is one undo, and both fields come back', (
      tester,
    ) async {
      // DR-025 §11.24.5's fast path. THE ARTIFACT IS WHAT ONE Ctrl+Z
      // TAKES BACK: asserting three commands were built would pass on a
      // build that ran them as three transactions, which is the thing a
      // person would actually complain about.
      final (doc, linkIds) = seeded();
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;

      final hdbaset = signalFamilyCellLabel(
        doc.registries.signalDomains[doc
            .registries
            .signalFamilies[const SignalFamilyId('video.hdbaset')]!
            .domain]!,
        doc.registries.signalFamilies[const SignalFamilyId('video.hdbaset')]!,
      );

      final edit = buildStructureEditAction(controller: controller);
      expect(
        edit([
          for (final id in linkIds)
            StructureCellEdit(
              linkId: id,
              column: StructureColumnId.service,
              value: hdbaset,
            ),
        ]),
        isNull,
      );

      Set<String> families() => {
        for (final l in doc.links.values)
          for (final s in l.services) s.signalFamily.v,
      };
      Set<String> nets() => {
        for (final n in doc.nets.values) n.signalFamily.v,
      };
      expect(families(), {'video.hdbaset'});
      expect(nets(), {'video.hdbaset'}, reason: '§11.24.6, both halves');
      expect(controller.undo.undoLabelKey, LabelKey.fillCells.name);

      controller.undoLast();
      expect(families(), {'structure.undetermined'});
      expect(
        nets(),
        {'structure.undetermined'},
        reason: 'one undo restores BOTH, or the revert is half a revert',
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

    testWidgets('ROUTED and CUT are typed into, on the same parser (M3-D/2)', (
      tester,
    ) async {
      // The three lengths were one enterable column and two read-only
      // ones for a milestone, which was a task boundary rather than a
      // control decision (#585's own comment says so). All three now go
      // through `parseLengthCell`, so a person tabbing across the row
      // meets one rule and not three.
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
            column: StructureColumnId.routedLength,
            value: '80',
          ),
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.cutLength,
            value: '92',
          ),
        ]),
        isNull,
      );
      expect(doc.links[ids.first]!.routedLength, const Len(80 * 304800000));
      expect(doc.links[ids.first]!.cutLength, const Len(92 * 304800000));

      // ONE UNDO FOR THE PAIR, because one gesture wrote both. The batch
      // is what `LabelKey.fillCells` is for.
      built.session.services.session.controller.undoLast();
      expect(doc.links[ids.first]!.routedLength, isNull);
      expect(doc.links[ids.first]!.cutLength, isNull);

      // AND THE REFUSAL IS THE SAME SENTENCE the as-built column gives.
      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.cutLength,
            value: '92.5',
          ),
        ]),
        contains('whole feet'),
      );
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

    testWidgets('RACK TERM writes the RACK end, and does not refuse itself '
        '(DR-046, `#711`)', (tester) async {
      // THE DEFECT: the column was editable, in the default eight, and
      // offered the whole `TerminationType` menu, while
      // `buildStructureEditAction` had an arm for the field end only. So
      // the cell drew an ENABLED dropdown and answered every pick with
      // "That column cannot be typed into." on every line, which is what
      // the user reported.
      //
      // WHY NO TEST SAW IT, and why this one lives in the app package.
      // `structure_editor_screen_test.dart` stubs `onEdit` with its own
      // reimplementation, and that stub HAD a rack arm, under a comment
      // asserting "the app has handled both ends since this ruling". The
      // harness was more capable than the product and the suite was green
      // against the fake. `buildStructureEditAction` lives here and
      // `rackmate_ui` may not import it, so this is where a test can
      // reach the real thing.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final edit = buildStructureEditAction(controller: controller);

      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.rackTerm,
            value: terminationLabel(TerminationType.punchdown),
          ),
        ]),
        isNull,
        reason: 'a legal pick from the column’s own menu is not a refusal',
      );
      final origin = doc.links[ids.first]!.structureOrigin!;
      expect(origin.terminationRack, TerminationType.punchdown);
      expect(
        origin.terminationField,
        isNull,
        reason:
            'DR-046 split the ends: writing the rack end must not touch '
            'the field end, which is the defect the split removed',
      );

      // IT CLEARS BACK TO UNKNOWN like its neighbour, for M3-J/1's
      // reason: nobody having decided how this end is finished is a real
      // state, not a value.
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.rackTerm,
          value: kUnknownCell,
        ),
      ]);
      expect(doc.links[ids.first]!.structureOrigin!.terminationRack, isNull);

      // AND THE REFUSAL NAMES THE END. One arm serves both columns now,
      // so the sentence has to say which one answered.
      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.rackTerm,
            value: 'BANANA',
          ),
        ]),
        contains('rack termination'),
      );
    });

    testWidgets('the two ends are set independently, in one gesture', (
      tester,
    ) async {
      // The pair DR-046 exists for: a run punched down at the panel and
      // keystoned at the wall is the ordinary case, and it was unsayable
      // while one of the two columns could not be written.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final edit = buildStructureEditAction(controller: controller);

      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.fieldTerm,
            value: terminationLabel(TerminationType.keystone),
          ),
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.rackTerm,
            value: terminationLabel(TerminationType.punchdown),
          ),
        ]),
        isNull,
      );
      final origin = doc.links[ids.first]!.structureOrigin!;
      expect(origin.terminationField, TerminationType.keystone);
      expect(origin.terminationRack, TerminationType.punchdown);

      // ONE UNDO FOR THE PAIR, because one gesture wrote both.
      controller.undoLast();
      final reverted = doc.links[ids.first]!.structureOrigin!;
      expect(reverted.terminationField, isNull);
      expect(reverted.terminationRack, isNull);
    });

    testWidgets('CLASS asserts, AUTO hands back, and both undo (DR-067, '
        '`#712`)', (tester) async {
      // THE COLUMN DR-008 HAD BEEN WAITING FOR SINCE ITS OWN RULING.
      // `SetLinkClassCommand` and `ClearLinkClassOverrideCommand` were
      // complete in core with undo, and no surface in the product called
      // either: a class could be classified and never asserted.
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final edit = buildStructureEditAction(controller: controller);

      expect(doc.links[ids.first]!.linkClassLocked, isFalse);

      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.linkClass,
            value: linkClassLabel(LinkClass.jumper),
          ),
        ]),
        isNull,
      );
      expect(doc.links[ids.first]!.linkClass, LinkClass.jumper);
      expect(
        doc.links[ids.first]!.linkClassLocked,
        isTrue,
        reason:
            'the pin is the half that makes the assertion outrank the '
            'classifier; writing the value alone would be inert',
      );

      // AUTO IS THE OTHER COMMAND, not a value. It drops the pin and
      // leaves the stored class where it was, inert, which is what
      // `link_class_commands.dart` argues for at length.
      expect(
        edit([
          StructureCellEdit(
            linkId: ids.first,
            column: StructureColumnId.linkClass,
            value: kLinkClassAutoCell,
          ),
        ]),
        isNull,
      );
      expect(doc.links[ids.first]!.linkClassLocked, isFalse);
      expect(
        doc.links[ids.first]!.linkClass,
        LinkClass.jumper,
        reason: 'clearing drops the lock and does not rewrite the value',
      );

      // AND HANDING IT BACK IS ITS OWN UNDO STEP, because it was its own
      // gesture. One Ctrl+Z restores the pin rather than skipping past
      // the override entirely.
      controller.undoLast();
      expect(doc.links[ids.first]!.linkClassLocked, isTrue);
      controller.undoLast();
      expect(doc.links[ids.first]!.linkClassLocked, isFalse);
    });

    testWidgets('AUTO on an unpinned run costs no undo step', (tester) async {
      // The state a fill-down lands in: `AUTO` down a column where most
      // rows were never pinned must apply to the ones that were and
      // charge nothing for the rest. Neither command builder checks this,
      // so the action does.
      final (doc, ids) = job(3);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final edit = buildStructureEditAction(controller: controller);
      final before = controller.undo.depth;

      expect(
        edit([
          for (final id in ids)
            StructureCellEdit(
              linkId: id,
              column: StructureColumnId.linkClass,
              value: kLinkClassAutoCell,
            ),
        ]),
        isNull,
      );
      expect(controller.undo.depth, before, reason: 'nothing was pinned');

      // Setting the same class twice is likewise nothing the second time.
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.linkClass,
          value: linkClassLabel(LinkClass.powerCord),
        ),
      ]);
      final afterFirst = controller.undo.depth;
      edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.linkClass,
          value: linkClassLabel(LinkClass.powerCord),
        ),
      ]);
      expect(controller.undo.depth, afterFirst);
    });

    testWidgets('a class the column does not offer is refused, and the '
        'refusal names AUTO', (tester) async {
      final (doc, ids) = job(1);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final edit = buildStructureEditAction(
        controller: built.session.services.session.controller,
      );

      // `UNDETERMINED` is what the SHEET prints for a classifier that
      // could not tell. It is a fact about a document, not a choice, and
      // a column that accepted it would let a person assert an unknown.
      final refusal = edit([
        StructureCellEdit(
          linkId: ids.first,
          column: StructureColumnId.linkClass,
          value: 'UNDETERMINED',
        ),
      ]);
      // THE WHOLE SENTENCE, not a `contains`. A green `contains` over a
      // line reading "1 ports" has shipped in this project before, and a
      // refusal is copy: the only way to know it reads as English is to
      // write down what it says.
      expect(
        refusal,
        '"UNDETERMINED" is not a class. Use one of: AUTO, FIELD CABLE, '
        'JUMPER, POWER CORD, INTERNAL.',
      );
      expect(doc.links[ids.first]!.linkClassLocked, isFalse);
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

  // ══════════════════════════════════════════════════════════════════
  // M3-C/3, #149 — THE MATRIX TAB, THROUGH THE REAL CONTROLLER
  // ══════════════════════════════════════════════════════════════════

  group('the matrix reaches the document (M3-C/3)', () {
    /// The room called [name] in [doc].
    Uuid roomId(RackDocument doc, String name) =>
        doc.locations.values.firstWhere((l) => l.name == name).id;

    testWidgets('a cell creates drops through the real undo stack', (
      tester,
    ) async {
      final doc = _project(rooms: const [('Living Room', 'LR')]);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller;
      final set = buildStructureMatrixAction(controller: controller);

      // A blank project has no Structure device, and the grid says so
      // rather than creating one behind the person using it.
      expect(
        set(
          StructureMatrixEdit(
            locationId: roomId(doc, 'Living Room'),
            media: const MediaTypeId('media.cat6'),
            targetCount: 4,
          ),
        ),
        kMatrixNeedsStructure,
      );
      expect(doc.links, isEmpty);

      controller.run(
        AddStructureCommand(
          title: 'Rough-In',
          designator: 'STR-1',
          now: _when,
          actor: 'test',
        ),
      );
      final before = controller.undo.depth;

      expect(
        set(
          StructureMatrixEdit(
            locationId: roomId(doc, 'Living Room'),
            media: const MediaTypeId('media.cat6'),
            targetCount: 4,
          ),
        ),
        isNull,
      );

      expect(doc.links, hasLength(4));
      // FOUR CABLES AND ONE PLATE ARE ONE UNDO STEP, because the unit a
      // person undoes is the cell.
      expect(controller.undo.depth, before + 1);
      expect(controller.undo.undoLabelKey, LabelKey.addDrops.name);

      controller.undoLast();
      expect(doc.links, isEmpty);
      expect(doc.outlets, isEmpty);
    });

    testWidgets('and lowering it says "remove drops", not "add"', (
      tester,
    ) async {
      // Opposite acts on the same grid. A person who typed the wrong
      // number needs the Edit menu to say which direction it will go.
      final doc = _project(rooms: const [('Living Room', 'LR')]);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller
        ..run(
          AddStructureCommand(
            title: 'Rough-In',
            designator: 'STR-1',
            now: _when,
            actor: 'test',
          ),
        );
      final set = buildStructureMatrixAction(controller: controller);
      StructureMatrixEdit cell(int n) => StructureMatrixEdit(
        locationId: roomId(doc, 'Living Room'),
        media: const MediaTypeId('media.cat6'),
        targetCount: n,
      );

      expect(set(cell(4)), isNull);
      expect(set(cell(1)), isNull);

      expect(doc.links, hasLength(1));
      expect(controller.undo.undoLabelKey, LabelKey.removeDrops.name);

      // And the three that went come back together.
      controller.undoLast();
      expect(doc.links, hasLength(4));
    });

    testWidgets('a cell that already says that costs no undo step', (
      tester,
    ) async {
      // Tabbing across a row commits every cell it passes. A no-op that
      // produced a transaction would cost an undo step per keystroke.
      final doc = _project(rooms: const [('Living Room', 'LR')]);
      final built = await buildTestApp(measurer, document: doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final controller = built.session.services.session.controller
        ..run(
          AddStructureCommand(
            title: 'Rough-In',
            designator: 'STR-1',
            now: _when,
            actor: 'test',
          ),
        );
      final set = buildStructureMatrixAction(controller: controller);
      StructureMatrixEdit cell(int n) => StructureMatrixEdit(
        locationId: roomId(doc, 'Living Room'),
        media: const MediaTypeId('media.cat6'),
        targetCount: n,
      );

      expect(set(cell(2)), isNull);
      final depth = controller.undo.depth;
      expect(set(cell(2)), isNull);
      expect(controller.undo.depth, depth);
    });

    testWidgets('the tab strip is on the real editor and opens on Table', (
      tester,
    ) async {
      final built = await buildTestApp(
        measurer,
        document: _project(rooms: const [('Living Room', 'LR')]),
      );
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      await openEditor(tester);

      expect(find.text(kTableTabLabel), findsOneWidget);
      expect(find.text(kMatrixTabLabel), findsOneWidget);
      expect(find.text(kMatrixTotalLabel), findsNothing);

      await tester.tap(find.text(kMatrixTabLabel));
      await tester.pumpAndSettle();
      expect(find.text(kMatrixTotalLabel), findsOneWidget);
    });
  });
}
