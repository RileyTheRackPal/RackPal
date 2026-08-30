// `#240`'s two dialogs, driven by real taps.
//
// The branches are core's and are tested there. What is left here is that
// the picker defaults the way the user asked ("pack everything, with an
// Advanced picker"), that the mismatch warning names the templates rather
// than counting them, and that AC-042's warning does not take the button
// away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

TemplateBody _body(String name, {int ports = 4, int banks = 1}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  frontU: 2,
  banks: [
    for (var i = 0; i < banks; i++)
      BankDef(
        key: 'b$i',
        label: 'Bank $i',
        abbr: 'B$i',
        order: FracIndex('a$i'),
      ),
  ],
  ports: [
    for (var i = 0; i < ports; i++)
      PortDef(
        key: PortKey('p$i'),
        label: 'P$i',
        order: FracIndex('a$i'),
        connector: const ConnectorTypeId('conn.hdmi_a'),
        signalFamily: const SignalFamilyId('video.hdmi.2_0'),
        face: Face.rear,
        position: const PanelPosition(
          ruOffset: 0,
          xTwelfth: 0,
          xFineNm: Len.zero,
          yFineNm: Len.zero,
        ),
      ),
  ],
);

DeviceTemplateFile _t(String name) => DeviceTemplateFile(
  templateId: TemplateId('tpl.${name.toLowerCase()}'),
  version: 1,
  contentHash: 'unhashed:x@1',
  body: _body(name),
);

Future<T?> _open<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) show,
) async {
  T? popped;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => popped = await show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  group('the export dialog', () {
    testWidgets('everything is ticked on open, which IS "pack all"', (
      tester,
    ) async {
      // Starting empty would make the common case a select-all click and
      // would pose the question the disclosure exists to avoid.
      await _open(
        tester,
        (c) => showExportLibrary(
          c,
          candidates: [_t('Amp'), _t('Switch'), _t('Panel')],
        ),
      );
      expect(find.text('3 templates, all of them'), findsOneWidget);
    });

    testWidgets('the picker is hidden until asked for', (tester) async {
      await _open(
        tester,
        (c) => showExportLibrary(c, candidates: [_t('Amp'), _t('Switch')]),
      );
      expect(find.text('Choose templates…'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);

      await tester.tap(find.text('Choose templates…'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(find.text('Pack all'), findsOneWidget);
    });

    testWidgets('unticking one narrows the summary', (tester) async {
      await _open(
        tester,
        (c) => showExportLibrary(
          c,
          candidates: [_t('Amp'), _t('Switch'), _t('Panel')],
        ),
      );
      await tester.tap(find.text('Choose templates…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(find.text('2 templates of 3'), findsOneWidget);
    });

    testWidgets('the seed exclusion is EXPLAINED, not silent', (tester) async {
      // Somebody counting rows in the palette and rows here would
      // otherwise be missing 48 with no way to know why.
      await _open(tester, (c) => showExportLibrary(c, candidates: [_t('Amp')]));
      expect(
        find.textContaining('48 shipped archetypes are not included'),
        findsOneWidget,
      );
    });

    testWidgets('Export is refused on an empty selection', (tester) async {
      await _open(
        tester,
        (c) => showExportLibrary(c, candidates: [_t('Amp')]),
      );
      await tester.tap(find.text('Choose templates…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amp'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'a library with no templates is a file nobody meant to make',
      );
    });

    testWidgets('Export is refused on a blank name', (tester) async {
      await _open(
        tester,
        (c) => showExportLibrary(c, candidates: [_t('Amp')]),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'the manifest has one field and it cannot be empty',
      );
    });

    testWidgets('it pops the name and the ticked subset', (tester) async {
      ExportLibraryRequest? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => got = await showExportLibrary(
                  context,
                  candidates: [_t('Amp'), _t('Switch')],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Shop Kit');
      await tester.tap(find.text('Choose templates…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();

      expect(got?.name, 'Shop Kit');
      expect(got?.selected.map((t) => t.body.displayName), ['Switch']);
    });
  });

  group('the import dialog', () {
    testWidgets('it says the inert-data sentence, in full', (tester) async {
      await _open(
        tester,
        (c) => showImportLibraryConfirm(
          c,
          preview: const LibraryImportPreview(
            name: 'Shop Kit',
            templateCount: 2,
            mismatched: [],
            unverifiable: 0,
          ),
        ),
      );
      expect(find.text(kInertDataNotice), findsOneWidget);
      expect(find.text('Shop Kit'), findsOneWidget);
      expect(find.text('2 templates'), findsOneWidget);
    });

    testWidgets('a clean library shows no warning', (tester) async {
      await _open(
        tester,
        (c) => showImportLibraryConfirm(
          c,
          preview: const LibraryImportPreview(
            name: 'Kit',
            templateCount: 1,
            mismatched: [],
            unverifiable: 1,
          ),
        ),
      );
      expect(find.textContaining('been edited'), findsNothing);
      expect(
        find.text('1 template'),
        findsOneWidget,
        reason: 'singular, because `1 templates` shipped once already',
      );
    });

    testWidgets('AC-042: a mismatch NAMES the templates and keeps Import', (
      tester,
    ) async {
      // `#240` in its own words: an archive whose hashes do not match
      // "imports WITH A BADGE, it does not refuse".
      await _open(
        tester,
        (c) => showImportLibraryConfirm(
          c,
          preview: const LibraryImportPreview(
            name: 'Edited Kit',
            templateCount: 3,
            mismatched: ['Amp', 'Switch'],
            unverifiable: 0,
          ),
        ),
      );
      expect(
        find.text(libraryMismatchWarning(const ['Amp', 'Switch'])),
        findsOneWidget,
      );
      expect(find.text('· Amp'), findsOneWidget);
      expect(find.text('· Switch'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'a warning that disabled the button would be a refusal',
      );
    });

    test('the warning is plural-safe, asserted as whole strings', () {
      // `1 templates` shipped once already, under green `contains`
      // assertions that could not see grammar.
      expect(
        libraryMismatchWarning(const ['Amp']),
        startsWith('One template in this library has been edited'),
      );
      expect(
        libraryMismatchWarning(const ['Amp', 'Switch']),
        startsWith('2 templates in this library have been edited'),
      );
    });

    testWidgets('dismissing is a cancel', (tester) async {
      bool? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => got = await showImportLibraryConfirm(
                  context,
                  preview: const LibraryImportPreview(
                    name: 'Kit',
                    templateCount: 1,
                    mismatched: [],
                    unverifiable: 0,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(got, isFalse);
    });
  });
}
