// After an export is saved: Open and Show in folder (M6-I4, `#355`,
// CR-100's "Open in system viewer", docs/08 §8.3), asked for and never
// done unasked.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rackpal/src/session/export_controller.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal_ui/rackpal_ui.dart' show buildDemoRackDocument;

import 'session_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('win32OpenFile', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kFileDialogChannel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kFileDialogChannel, null);
    });

    test('a PDF goes down the channel as openFile', () async {
      expect(await win32OpenFile(r'C:\jobs\smith.PDF'), isTrue);
      expect(calls.single.method, 'openFile');
      expect(calls.single.arguments, {'path': r'C:\jobs\smith.PDF'});
    });

    test('ANYTHING ELSE NEVER REACHES IT: "open" runs a program when handed '
        'one', () async {
      for (final path in [
        r'C:\Windows\System32\cmd.exe',
        r'C:\jobs\x.pdf.lnk',
      ]) {
        expect(await win32OpenFile(path), isFalse, reason: path);
      }
      expect(calls, isEmpty);
    });
  });

  group('the status line after a save', () {
    test('carries Open and Show in folder, which open the written file and '
        'its folder', () async {
      final opened = <String>[];
      final revealed = <String>[];
      final session = await buildTestSession(
        document: buildDemoRackDocument(),
        savePaths: <String?>[r'C:\jobs\smith'],
        fileOpener: (path) async {
          opened.add(path);
          return true;
        },
        folderRevealer: (folder) async {
          revealed.add(folder);
          return true;
        },
      );
      expect(await session.services.export.exportPdf(), isTrue);
      final actions = session.services.session.statusActions;
      expect(actions.map((a) => a.label), [
        kExportOpenLabel,
        kExportShowInFolderLabel,
      ]);
      expect(opened, isEmpty, reason: 'nothing is opened unasked');

      actions[0].onPressed();
      actions[1].onPressed();
      await Future<void>.delayed(Duration.zero);
      expect(opened, [r'C:\jobs\smith.pdf']);
      expect(revealed, [r'C:\jobs']);
    });

    test('a viewer that will not open it is said, naming the file', () async {
      final session = await buildTestSession(
        document: buildDemoRackDocument(),
        savePaths: <String?>[r'C:\jobs\smith'],
        fileOpener: (_) async => false,
      );
      await session.services.export.exportPdf();
      session.services.session.statusActions.first.onPressed();
      await Future<void>.delayed(Duration.zero);
      expect(
        session.services.session.status,
        exportOpenFailedStatus('smith.pdf'),
      );
    });

    test('A SECOND EXPORT OPENS ITS OWN FILE, though its status '
        'reads the same', () async {
      final opened = <String>[];
      final session = await buildTestSession(
        document: buildDemoRackDocument(),
        savePaths: <String?>[r'C:\jobs\smith', r'C:\jobs\smith-rev-b'],
        fileOpener: (path) async {
          opened.add(path);
          return true;
        },
      );
      expect(await session.services.export.exportPdf(), isTrue);
      final first = session.services.session.status;
      expect(await session.services.export.exportPdf(), isTrue);
      expect(session.services.session.status, first, reason: 'precondition');
      session.services.session.statusActions.first.onPressed();
      await Future<void>.delayed(Duration.zero);
      expect(opened, [r'C:\jobs\smith-rev-b.pdf']);
    });

    test('the next status clears them', () async {
      final session = await buildTestSession(
        document: buildDemoRackDocument(),
        savePaths: <String?>[r'C:\jobs\smith'],
      );
      await session.services.export.exportPdf();
      session.services.session.setStatus('Saved.');
      expect(session.services.session.statusActions, isEmpty);
    });
  });
}
