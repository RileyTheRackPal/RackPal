// File ▸ Sheet set… (`#969`, DR-209 §11.208).
//
// The command and the wire are asserted in `rackpal_core`'s
// `sheet_set_commands_test.dart`. What is asserted here is what only a
// widget test can see: that the seed shows as rows, that LOOKING at it
// changes nothing, and that each act a person can take reaches the
// document as exactly one command.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// [info] through the constructor: `ProjectInfo`'s legend setters are
/// `@internal` to `rackpal_core`, so only a command may write them here.
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
/// and the notes sit below the fold of a lazily built list.
final Finder _list = find
    .descendant(
      of: find.byKey(kSheetSetListKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// `scrollUntilVisible` stops once the row is BUILT, which in a list with
/// a cache extent can be while it is still off screen; a tap there misses.
/// So it builds the row, and `ensureVisible` then puts it on screen.
Future<void> _reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 100, scrollable: _list);
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('THE SEED SHOWS AS ROWS, and looking at it saves nothing', (
    tester,
  ) async {
    final doc = _doc();
    final ran = await _open(tester, doc);

    for (final (i, r) in kLegendAbbreviations.indexed) {
      expect(_fieldText(tester, abbreviationFieldKey(i)), r.abbreviation);
      expect(_fieldText(tester, meaningFieldKey(i)), r.meaning);
    }
    for (final (i, n) in kLegendGeneralNotes.indexed) {
      await _reveal(tester, noteFieldKey(i));
      expect(_fieldText(tester, noteFieldKey(i)), n);
    }
    // Back to the top: the first row is above, and unbuilt.
    await tester.drag(_list, const Offset(0, 2000));
    await tester.pumpAndSettle();

    // Into a field and out again, then close: the precondition that the
    // tap reached a field is that it took focus.
    await tester.tap(find.byKey(meaningFieldKey(0)));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(meaningFieldKey(0)))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.text('Legend (T0.01): abbreviations'));
    await tester.pump();
    await _close(tester);

    expect(ran, isEmpty);
    expect(doc.info.legendAbbreviations, isNull, reason: 'still the seed');
    expect(doc.info.legendNotes, isNull);
  });

  testWidgets('editing a meaning is one command, and the notes stay seeded', (
    tester,
  ) async {
    final doc = _doc();
    final ran = await _open(tester, doc);

    await tester.enterText(find.byKey(meaningFieldKey(0)), 'rack unit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(ran, hasLength(1));
    expect(ran.single.label, LabelKey.setLegendNotes);
    expect(
      doc.info.legendAbbreviations!.first,
      const LegendAbbreviation(
        'RU',
        'rack unit',
      ),
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
    expect(find.text("This project's own list."), findsOneWidget);
  });

  testWidgets('ADD makes an empty row and no command; typing saves it', (
    tester,
  ) async {
    final doc = _doc();
    final ran = await _open(tester, doc);
    final newRow = kLegendAbbreviations.length;

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
      const LegendAbbreviation(
        'AFF',
        'above finished floor',
      ),
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

  testWidgets('RESTORE DEFAULTS is off while seeded, and returns to absent', (
    tester,
  ) async {
    final doc = _doc(
      info: ProjectInfo(
        legendAbbreviations: const [LegendAbbreviation('AFF', 'x')],
        legendNotes: const [],
      ),
    );
    final ran = await _open(tester, doc);
    expect(_fieldText(tester, abbreviationFieldKey(0)), 'AFF');
    await tester.drag(_list, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Add note'), findsOneWidget, reason: 'scrolled down');
    expect(find.byKey(noteFieldKey(0)), findsNothing);
    await tester.drag(_list, const Offset(0, 600));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kRestoreLegendDefaultsKey));
    await tester.pumpAndSettle();

    expect(ran, hasLength(1));
    expect(doc.info.legendAbbreviations, isNull);
    expect(doc.info.legendNotes, isNull);
    expect(_fieldText(tester, abbreviationFieldKey(0)), 'RU');
    expect(
      tester
          .widget<TextButton>(find.byKey(kRestoreLegendDefaultsKey))
          .onPressed,
      isNull,
    );
  });
}
