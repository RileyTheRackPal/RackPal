// #947. `Import CSV…`, driven from the Structure editor's own button.
//
// `commitCsvImport` was split out of `runCsvImport` so the write path
// could be tested without a file or a dialog (csv_import_actions_test.dart
// says so), and it is. The cost was that `runCsvImport`, the function the
// button calls and the only one that reads the file, had never run: the
// first line-coverage measurement (2026-09-24) found all of it uncovered.
// So these start at the button, over the fake disk, and read what the
// user is shown.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

final _when = DateTime.utc(2026, 9, 25);
const _csvPath = r'C:\jobs\pull list.csv';

/// A blank project with one Structure body and the room the sheet names.
RackDocument _project() {
  final doc = buildBlankDocument(now: _when, appVersion: '0.1.0');
  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _when,
    actor: 'test',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _when,
    actor: 'test',
  ).apply(doc);
  return doc;
}

Uint8List _csv() => Uint8List.fromList(
  utf8.encode(
    'Room,Outlet,Cable Type,Qty\n'
    'Living Room,WP-1,Cat6,2\n',
  ),
);

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

  /// Mounts the app, opens the Structure editor and presses Import CSV….
  Future<RackDocument> pressImportCsv(
    WidgetTester tester, {
    Map<String, Object> failReadsOf = const {},
  }) async {
    final built = await buildTestApp(
      measurer,
      document: _project(),
      fs: FakeFileStore(
        initialFiles: {_csvPath: _csv()},
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        failReadsOf: failReadsOf,
      ),
      openPaths: [_csvPath],
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ShellView.structuredWiring.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kImportCsvLabel));
    await tester.pumpAndSettle();
    return built.session.services.session.document;
  }

  testWidgets('Import CSV… reads the file and the confirmed rows become '
      'drops', (tester) async {
    final doc = await pressImportCsv(tester);
    expect(buildStructureTable(doc).dropCount, 0, reason: 'the precondition');

    expect(find.text(kCsvImportTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, kImportLabel));
    await tester.pumpAndSettle();

    expect(buildStructureTable(doc).dropCount, 2);
  });

  testWidgets('a file another program holds open says so, and nothing is '
      'imported', (tester) async {
    final doc = await pressImportCsv(
      tester,
      failReadsOf: {_csvPath: const StorageOsException(32)},
    );

    expect(find.text(kCsvImportTitle), findsNothing);
    expect(
      find.textContaining('That file could not be read'),
      findsOneWidget,
    );
    expect(buildStructureTable(doc).dropCount, 0);
  });

  testWidgets('a store that fails with an ERROR, not an Exception, is '
      'reported the same way rather than escaping', (tester) async {
    // `FileStore.readBytes` declares no typed failure, and
    // `import_guard.dart` catches `on Object` for exactly that reason,
    // citing THIS file as already doing the same. It caught `on
    // Exception`, so an `Error` from the store left `runCsvImport`
    // entirely and reached the shell's handler unreported.
    final doc = await pressImportCsv(
      tester,
      failReadsOf: {_csvPath: StateError('the store gave up')},
    );

    expect(
      find.textContaining('That file could not be read'),
      findsOneWidget,
    );
    expect(buildStructureTable(doc).dropCount, 0);
  });
}
