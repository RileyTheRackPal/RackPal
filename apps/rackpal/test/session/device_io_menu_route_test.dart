// #947. The device library and device template imports, driven from the
// real File menu.
//
// The first line-coverage measurement (2026-09-24) found that the
// `LibraryIo` and `DeviceTemplateIo` members the shell calls had never
// run: every existing test called `importDeviceLibrary` or
// `importDeviceTemplate` directly. A route proved by calling its handler
// has never been proved reachable, and #943's first real menu test found a
// defect behind exactly that gap. So each case here starts at `File`, and
// the failure cases go down the same route, because what a user is told
// when an import fails is only worth anything if the menu reaches it.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/library_directory.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _libraryPath = r'C:\jobs\Shop Kit.rpda';
const _templatePath = r'C:\jobs\Amp.rpdx';

TemplateBody _body(String name) =>
    TemplateBody(manufacturer: 'Acme', model: name, displayName: name)
      ..frontU = 1;

Uint8List _library() => encodeRmdaBytes(
  DeviceLibraryFile(
    name: 'Shop Kit',
    templates: [
      for (final n in ['Amp', 'Switch'])
        DeviceTemplateFile(
          templateId: TemplateId('tpl.${n.toLowerCase()}'),
          version: 1,
          contentHash: templateContentHash(_body(n)),
          body: _body(n),
        ),
    ],
  ),
);

Uint8List _template() => encodeRmdxBytes(
  DeviceTemplateFile(
    templateId: const TemplateId('tpl.route-amp'),
    version: 1,
    contentHash: templateContentHash(_body('Route Amp')),
    body: _body('Route Amp'),
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

  /// Mounts the real app over [files], answers the open picker with
  /// [path], and chooses [item] from the File menu.
  Future<({FakeFileStore fs, TestSession session})> runFromFileMenu(
    WidgetTester tester, {
    required String item,
    required String path,
    required Map<String, Uint8List> files,
    Map<String, Object> failReadsOf = const {},
  }) async {
    final fs = FakeFileStore(
      initialFiles: files,
      initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      failReadsOf: failReadsOf,
    );
    final built = await buildTestApp(measurer, fs: fs, openPaths: [path]);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
    return (fs: fs, session: built.session);
  }

  String shelved(String name) => p.windows.join(
    libraryDirectoryPath(kTestDataRoot, context: p.windows),
    name,
  );

  group('File ▸ Import device library…', () {
    testWidgets('confirmed, the library lands on the shelf byte for byte', (
      tester,
    ) async {
      final bytes = _library();
      final run = await runFromFileMenu(
        tester,
        item: 'Import device library…',
        path: _libraryPath,
        files: {_libraryPath: bytes},
      );

      expect(find.text('Import device library'), findsOneWidget);
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      final landed = run.fs.state.files[shelved('Shop Kit.rpda')];
      expect(landed, isA<Bytes>(), reason: 'the menu reached the import');
      expect((landed! as Bytes).value, bytes);
      expect(find.byType(AlertDialog), findsNothing, reason: 'no error');
    });

    testWidgets('a file over the size cap is refused before it is read, '
        'and nothing is shelved', (tester) async {
      final run = await runFromFileMenu(
        tester,
        item: 'Import device library…',
        path: _libraryPath,
        files: {_libraryPath: Uint8List(kMaxDocumentBytes + 1)},
      );

      expect(
        find.textContaining(
          'larger or more deeply nested than an import may '
          'be',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing has been added to your libraries'),
        findsOneWidget,
      );
      expect(run.fs.calls, isNot(contains('readBytes')));
      expect(
        run.fs.state.files.keys.where((k) => k.contains(kLibraryDirName)),
        isEmpty,
      );
    });

    testWidgets('a file that cannot be READ says so, and nothing is '
        'shelved', (tester) async {
      final run = await runFromFileMenu(
        tester,
        item: 'Import device library…',
        path: _libraryPath,
        files: {_libraryPath: _library()},
        failReadsOf: {_libraryPath: const StorageOsException(32)},
      );

      expect(find.text('That library could not be read'), findsOneWidget);
      expect(
        run.fs.state.files.keys.where((k) => k.contains(kLibraryDirName)),
        isEmpty,
      );
    });
  });

  group('File ▸ Import device template…', () {
    testWidgets('confirmed, the template enters the open project', (
      tester,
    ) async {
      final run = await runFromFileMenu(
        tester,
        item: 'Import device template…',
        path: _templatePath,
        files: {_templatePath: _template()},
      );

      expect(find.text('Import device template'), findsOneWidget);
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(
        run.session.services.session.document.templates.keys,
        contains(
          templateSnapshotKey(const TemplateId('tpl.route-amp'), 1),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing, reason: 'no error');
    });

    testWidgets('a file that cannot be READ says so, and the project is '
        'untouched', (tester) async {
      final run = await runFromFileMenu(
        tester,
        item: 'Import device template…',
        path: _templatePath,
        files: {_templatePath: _template()},
        failReadsOf: {_templatePath: const StorageOsException(5)},
      );
      final templates = run.session.services.session.document.templates.keys;

      expect(find.text('That file could not be read'), findsOneWidget);
      expect(
        templates,
        isNot(
          contains(templateSnapshotKey(const TemplateId('tpl.route-amp'), 1)),
        ),
      );
    });
  });
}
