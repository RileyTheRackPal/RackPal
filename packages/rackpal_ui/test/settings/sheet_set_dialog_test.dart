// File ▸ Sheet set… (`#969` DR-209 §11.208, `#312` DR-210 §11.209).
//
// The commands and the wire are asserted in `rackpal_core`'s
// `sheet_set_commands_test.dart`. What is asserted here is what only a
// widget test can see: that the file's values show in the right places,
// that LOOKING changes nothing, and that each act a person can take
// reaches the document as exactly one command, or is refused with a reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// [info] through the constructor: `ProjectInfo`'s setters are `@internal`
/// to `rackpal_core`, so only a command may write them here.
RackDocument _doc({ProjectInfo? info}) {
  final when = DateTime.utc(2026, 9, 30);
  final doc = RackDocument(
    id: const Uuid('doc-sheet-set'),
    appVersion: '0.6.60',
    createdAt: when,
    modifiedAt: when,
    meta: EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test'),
    info: info,
  );
  final seed = buildSeedRegistries();
  for (final e in seed.signalDomains.entries) {
    doc.registries.signalDomains[e.key] = e.value;
  }
  return doc;
}

Future<List<Command<RackDocument>>> _open(
  WidgetTester tester,
  RackDocument doc,
) async {
  final ran = <Command<RackDocument>>[];
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSheetSetDialog(
              context,
              doc: doc,
              onEdit: (commands) {
                ran.addAll(commands);
                for (final c in commands) {
                  c.apply(doc);
                }
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return ran;
}

/// The dialog's own list: `AlertDialog` adds a `Scrollable` of its own,
/// and most rows sit below the fold of a lazily built list.
final Finder _list = find
    .descendant(
      of: find.byKey(kSheetSetListKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// `scrollUntilVisible` stops once the row is BUILT, which in a list with
/// a cache extent can be while it is still off screen; a tap there misses.
/// So it builds the row, and `ensureVisible` then puts it on screen. It
/// scrolls DOWN only, from wherever the list is: [_top] first for a row
/// that may be above.
Future<void> _reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 100, scrollable: _list);
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Scrolls until [text] is on screen, which is the assertion that it is
/// there at all.
Future<void> _revealText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 100, scrollable: _list);
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  expect(find.text(text), findsOneWidget);
}

Future<void> _top(WidgetTester tester) async {
  await tester.drag(_list, const Offset(0, 5000));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

bool _hasFocus(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).focusNode!.hasFocus;

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();
}

/// Types into [field] and presses Enter, as a person saving a line does.
Future<void> _type(
  WidgetTester tester,
  ProjectInfoField field,
  String text,
) async {
  await _reveal(tester, projectInfoFieldKey(field));
  await tester.enterText(find.byKey(projectInfoFieldKey(field)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('the legend (#969)', () {
    testWidgets('THE SEED SHOWS AS ROWS, and looking at it saves nothing', (
      tester,
    ) async {
      final doc = _doc();
      final ran = await _open(tester, doc);

      for (final (i, r) in kLegendAbbreviations.indexed) {
        await _reveal(tester, meaningFieldKey(i));
        expect(_fieldText(tester, abbreviationFieldKey(i)), r.abbreviation);
        expect(_fieldText(tester, meaningFieldKey(i)), r.meaning);
      }
      for (final (i, n) in kLegendGeneralNotes.indexed) {
        await _reveal(tester, noteFieldKey(i));
        expect(_fieldText(tester, noteFieldKey(i)), n);
      }
      await _top(tester);
      await _reveal(tester, meaningFieldKey(0));

      // Into a field and out again, then close: the precondition that the
      // tap reached a field is that it took focus.
      await tester.tap(find.byKey(meaningFieldKey(0)));
      await tester.pump();
      expect(_hasFocus(tester, meaningFieldKey(0)), isTrue);
      await tester.tap(find.text('Sheet set'));
      await tester.pump();
      await _close(tester);

      expect(ran, isEmpty);
      expect(doc.info.legendAbbreviations, isNull, reason: 'still the seed');
      expect(doc.info.legendNotes, isNull);
    });

    testWidgets('editing a meaning is one command, and the notes stay '
        'seeded', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);

      await _reveal(tester, meaningFieldKey(0));
      await tester.enterText(find.byKey(meaningFieldKey(0)), 'rack unit');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(ran, hasLength(1));
      expect(ran.single.label, LabelKey.setLegendNotes);
      expect(
        doc.info.legendAbbreviations!.first,
        const LegendAbbreviation('RU', 'rack unit'),
      );
      expect(
        doc.info.legendAbbreviations,
        hasLength(kLegendAbbreviations.length),
      );
      expect(
        doc.info.legendNotes,
        isNull,
        reason: 'an abbreviation edit does not freeze the seeded notes',
      );
      await _top(tester);
      await _revealText(tester, "This project's own list.");
    });

    testWidgets('ADD makes an empty row and no command; typing saves it', (
      tester,
    ) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final newRow = kLegendAbbreviations.length;

      await _reveal(tester, kAddAbbreviationKey);
      await tester.tap(find.byKey(kAddAbbreviationKey));
      await tester.pump();
      expect(find.byKey(abbreviationFieldKey(newRow)), findsOneWidget);
      expect(ran, isEmpty);

      await tester.enterText(find.byKey(abbreviationFieldKey(newRow)), 'AFF');
      await tester.enterText(
        find.byKey(meaningFieldKey(newRow)),
        'above finished floor',
      );
      await _close(tester);

      expect(
        doc.info.legendAbbreviations!.last,
        const LegendAbbreviation('AFF', 'above finished floor'),
      );
    });

    testWidgets('removing a note is one command, and the rest stay', (
      tester,
    ) async {
      final doc = _doc();
      final ran = await _open(tester, doc);

      await _reveal(tester, removeNoteKey(0));
      await tester.tap(find.byKey(removeNoteKey(0)));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(doc.info.legendNotes, kLegendGeneralNotes.skip(1).toList());
      expect(_fieldText(tester, noteFieldKey(0)), kLegendGeneralNotes[1]);
    });

    testWidgets('RESTORE DEFAULTS is off while seeded, and returns to '
        'absent', (tester) async {
      final doc = _doc(
        info: ProjectInfo(
          legendAbbreviations: const [LegendAbbreviation('AFF', 'x')],
          legendNotes: const [],
        ),
      );
      final ran = await _open(tester, doc);
      await _reveal(tester, kAddNoteKey);
      expect(_fieldText(tester, abbreviationFieldKey(0)), 'AFF');
      expect(find.byKey(noteFieldKey(0)), findsNothing);

      await tester.tap(find.byKey(kRestoreLegendDefaultsKey));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(doc.info.legendAbbreviations, isNull);
      expect(doc.info.legendNotes, isNull);
      await _top(tester);
      await _reveal(tester, abbreviationFieldKey(0));
      expect(_fieldText(tester, abbreviationFieldKey(0)), 'RU');
      expect(
        tester
            .widget<TextButton>(find.byKey(kRestoreLegendDefaultsKey))
            .onPressed,
        isNull,
      );
    });
  });

  group('the title block and the cover (#312, DR-210)', () {
    ProjectInfo filled() => ProjectInfo(
      projectName: 'Whole House',
      clientName: 'Sample Client',
      siteAddress: Address(city: 'Sampleton'),
      drawnBy: 'J.S.',
    );

    testWidgets('THE FILE SHOWS IN ITS FIELDS, grouped as the set prints', (
      tester,
    ) async {
      await _open(tester, _doc(info: filled()));
      for (final (group, _) in ProjectInfoFields.groups) {
        await _revealText(tester, group);
      }
      await _top(tester);
      final shown = <ProjectInfoField, String>{
        ProjectInfoFields.projectName: 'Whole House',
        ProjectInfoFields.clientName: 'Sample Client',
        ProjectInfoFields.city: 'Sampleton',
        ProjectInfoFields.drawnBy: 'J.S.',
        ProjectInfoFields.checkedBy: '',
      };
      for (final MapEntry(key: f, value: text) in shown.entries) {
        await _reveal(tester, projectInfoFieldKey(f));
        expect(_fieldText(tester, projectInfoFieldKey(f)), text, reason: f.key);
      }
    });

    testWidgets('an edit is one command; clicking in and out sends none', (
      tester,
    ) async {
      final doc = _doc(info: filled());
      final ran = await _open(tester, doc);
      final client = projectInfoFieldKey(ProjectInfoFields.clientName);

      await _reveal(tester, client);
      await tester.tap(find.byKey(client));
      await tester.pump();
      expect(_hasFocus(tester, client), isTrue);
      await tester.tap(find.text('Sheet set'));
      await tester.pump();
      expect(ran, isEmpty, reason: 'nothing changed');

      await _type(tester, ProjectInfoFields.checkedBy, 'M.R.');
      expect(ran, hasLength(1));
      expect(ran.single.label, LabelKey.setProjectInfo);
      expect(doc.info.checkedBy, 'M.R.');
    });

    testWidgets('A CLEARED PROJECT NAME IS REFUSED, with the reason, and the '
        'name stays', (tester) async {
      final doc = _doc(info: filled());
      final ran = await _open(tester, doc);

      await _type(tester, ProjectInfoFields.projectName, '   ');

      expect(ran, isEmpty);
      expect(doc.info.projectName, 'Whole House');
      expect(find.text(kProjectNameRequired), findsOneWidget);
      expect(
        _fieldText(tester, projectInfoFieldKey(ProjectInfoFields.projectName)),
        'Whole House',
      );

      // And a real name clears the reason.
      await _type(tester, ProjectInfoFields.projectName, 'Whole House II');
      expect(doc.info.projectName, 'Whole House II');
      expect(find.text(kProjectNameRequired), findsNothing);
    });

    testWidgets('a field cleared is ABSENT, not an empty string', (
      tester,
    ) async {
      final doc = _doc(info: filled());
      await _open(tester, doc);
      await _type(tester, ProjectInfoFields.clientName, '');
      expect(doc.info.clientName, isNull);
    });

    testWidgets('TYPED AND CLOSED WITHOUT LEAVING THE FIELD is still saved', (
      tester,
    ) async {
      final doc = _doc(info: filled());
      await _open(tester, doc);
      final scope = projectInfoFieldKey(ProjectInfoFields.scopeNarrative);
      await _reveal(tester, scope);
      await tester.enterText(find.byKey(scope), 'Supply and install a rack.');
      await tester.pump();
      expect(doc.info.scopeNarrative, isNull, reason: 'precondition');

      await _close(tester);
      expect(doc.info.scopeNarrative, 'Supply and install a rack.');
    });
  });
}
