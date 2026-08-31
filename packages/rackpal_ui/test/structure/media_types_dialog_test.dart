// The media-type editor's surface (`#247`, RJ-012, DR-107 §11.106.1).
//
// The COMMANDS are asserted in `rackpal_core`'s
// `media_type_merge_test.dart`, including the one that matters most: that
// the loser's id survives nowhere in the serialised document. What is
// asserted here is what a widget test can see and that one cannot -- that
// the dialog names the damage before doing it, that it refuses a merge
// with nothing to merge into, and that the id is shown and cannot be
// typed over.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const _cat6e = MediaTypeId('media.cat6e');
const _typo = MediaTypeId('media.cat_6e_riser');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 8, 31),
  updatedAt: DateTime.utc(2026, 8, 31),
  updatedBy: 'test',
);

RackDocument _doc({int links = 0, bool second = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-media-ui'),
    appVersion: '0.4.90',
    createdAt: DateTime.utc(2026, 8, 31),
    modifiedAt: DateTime.utc(2026, 8, 31),
    meta: _meta(),
  );
  doc.registries.mediaTypes[_cat6e] = const MediaTypeDef(
    id: _cat6e,
    displayName: 'Cat6e',
    shortTag: 'C6',
  );
  if (second) {
    doc.registries.mediaTypes[_typo] = const MediaTypeDef(
      id: _typo,
      displayName: 'Cat 6e riser',
    );
  }
  for (var i = 0; i < links; i++) {
    final id = Uuid('link-$i');
    doc.links[id] = Link(
      id: id,
      designator: 'W00$i',
      media: _typo,
      order: FracIndex('a$i'),
      meta: _meta(),
    );
  }
  return doc;
}

/// The `Merge into...` button ON THE ROW FOR [name].
///
/// NOT `find.text('Merge into...').last`, which the first draft used and
/// which pressed the wrong row: the list sorts case-insensitively, and
/// `'cat 6e riser'` precedes `'cat6e'` because a space sorts before `6`.
/// A positional finder that cannot say WHICH row is the failure this
/// repository keeps re-finding.
Finder _mergeOn(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.widgetWithText(TextButton, 'Merge into...'),
);

/// Likewise for `Edit`.
Finder _editOn(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.widgetWithText(TextButton, 'Edit'),
);

Future<List<Command<RackDocument>>> _open(
  WidgetTester tester,
  RackDocument doc,
) async {
  final ran = <Command<RackDocument>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMediaTypesDialog(
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

void main() {
  group('the list says what a person needs to tell two types apart', () {
    testWidgets('every type shows its id, because that is what a typo makes '
        'different', (tester) async {
      await _open(tester, _doc(links: 3));
      expect(find.textContaining('media.cat6e'), findsOneWidget);
      expect(find.textContaining('media.cat_6e_riser'), findsOneWidget);
    });

    testWidgets('and how many places use it', (tester) async {
      await _open(tester, _doc(links: 3));
      expect(find.textContaining('3 uses'), findsOneWidget);
      expect(find.textContaining('not used'), findsOneWidget);
    });

    testWidgets('an empty registry says where media types come from rather '
        'than showing an empty box', (tester) async {
      final doc = _doc(second: false);
      doc.registries.mediaTypes.clear();
      await _open(tester, doc);
      expect(find.textContaining('Structure CSV import'), findsOneWidget);
    });
  });

  group('a merge names the damage before it does it', () {
    testWidgets('the confirmation counts the references it will repoint', (
      tester,
    ) async {
      await _open(tester, _doc(links: 4));
      await tester.tap(_mergeOn('Cat 6e riser'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('repoints 4 references'),
        findsOneWidget,
        reason:
            'a confirmation that cannot say how many is asking for a '
            'signature on a blank page',
      );
      expect(find.textContaining('One Ctrl+Z'), findsOneWidget);
    });

    testWidgets('a type nothing uses says so instead of counting to zero', (
      tester,
    ) async {
      await _open(tester, _doc());
      await tester.tap(_mergeOn('Cat6e'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nothing in this project uses'),
        findsOneWidget,
      );
    });

    testWidgets('Merge stays disabled until a target is picked', (
      tester,
    ) async {
      await _open(tester, _doc(links: 2));
      await tester.tap(_mergeOn('Cat 6e riser'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Merge'))
            .onPressed,
        isNull,
      );
      // The TARGET tile inside the merge sheet, not the row behind it.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.widgetWithText(ListTile, 'Cat6e'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Merge'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('picking a target emits a MergeMediaTypesCommand naming both '
        'ends the right way round', (tester) async {
      final doc = _doc(links: 2);
      final ran = await _open(tester, doc);
      await tester.tap(_mergeOn('Cat 6e riser'));
      await tester.pumpAndSettle();
      // The TARGET tile inside the merge sheet, not the row behind it.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.widgetWithText(ListTile, 'Cat6e'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      final cmd = ran.single as MergeMediaTypesCommand;
      expect(cmd.winner, _cat6e);
      expect(cmd.loser, _typo, reason: 'the row you pressed is the LOSER');
      expect(doc.registries.mediaTypes.containsKey(_typo), isFalse);
    });

    testWidgets('with only one type there is nothing to merge into, and the '
        'button says so by being disabled', (tester) async {
      await _open(tester, _doc(second: false));
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Merge into...'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('an edit changes the label and shows the id it cannot change', () {
    testWidgets('the id is displayed with the reason it is fixed', (
      tester,
    ) async {
      await _open(tester, _doc());
      await tester.tap(_editOn('Cat6e'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fixed at creation'), findsOneWidget);
      expect(find.textContaining('every cable run'), findsOneWidget);
    });

    testWidgets('the trade tag helper says empty means UNKNOWN, because G4 '
        'never lets a blank read as a measured value', (tester) async {
      await _open(tester, _doc());
      await tester.tap(_editOn('Cat6e'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Leave empty if unknown'), findsOneWidget);
    });

    testWidgets('saving a new name emits an EditMediaTypeCommand and the id '
        'is untouched', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await tester.tap(_editOn('Cat6e'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Cat 6e (riser)');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      final cmd = ran.single as EditMediaTypeCommand;
      expect(cmd.from.id, cmd.to.id, reason: 'the id is frozen at creation');
      expect(cmd.to.displayName, 'Cat 6e (riser)');
    });

    testWidgets('an empty name is refused rather than saved as a blank', (
      tester,
    ) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await tester.tap(_editOn('Cat6e'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(ran, isEmpty);
    });
  });
}
