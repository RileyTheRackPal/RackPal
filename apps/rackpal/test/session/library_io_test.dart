// `File ▸ Export device library…` and `File ▸ Import device library…`,
// as SEQUENCES (`#240`).
//
// The decisions are elsewhere: `library_import.dart` decides what an
// import brings in and what an export offers, `rmda_codec.dart` decides
// the bytes, the dialogs ask the person. What is left here is the order
// of the steps, the places one ends early, and the two things only this
// layer can be wrong about: WHICH file-dialog kind it asks for, and where
// the imported bytes land.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/library_io_actions.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/library_directory.dart';
import 'package:rackpal_core/rackpal_core.dart' hide MutableClock;
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

final p.Context _windows = p.Context(style: p.Style.windows);
final DateTime _now = DateTime.utc(2026, 8, 29, 12);
const String _root = r'C:\RackPalData';
final String _shelf = _windows.join(_root, kLibraryDirName);

TemplateBody _body(String name) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  frontU: 2,
);

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000ee'),
  appVersion: '0.4.78',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'lib'),
  info: ProjectInfo(projectName: 'Library IO'),
);

void _hold(RackDocument doc, String id, TemplateBody body) {
  doc.templates[templateSnapshotKey(TemplateId(id), 1)] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: templateContentHash(body),
    body: body,
    capturedAt: _now,
  );
}

DocumentSession _session(RackDocument doc) => DocumentSession(
  controller: DocumentController(doc, clock: MutableClock(_now)),
  context: _windows,
  recoveryEnabled: false,
);

Uint8List _rmda(String name, List<String> displayNames) => encodeRmdaBytes(
  DeviceLibraryFile(
    name: name,
    templates: [
      for (final n in displayNames)
        DeviceTemplateFile(
          templateId: TemplateId('tpl.${n.toLowerCase()}'),
          version: 1,
          contentHash: templateContentHash(_body(n)),
          body: _body(n),
        ),
    ],
  ),
);

Uint8List? _bytesAt(FakeFileStore fs, String path) {
  final content = fs.state.files[path];
  return content is Bytes ? content.value : null;
}

AtomicWriter _writer(FakeFileStore fs) =>
    AtomicWriter(fs: fs, queue: SaveQueue(), context: _windows);

void main() {
  group('export', () {
    test('a project with nothing of its own never opens a dialog', () async {
      // Asking somebody to NAME a library and then telling them there is
      // nothing to put in it wastes the one interaction, which is
      // exportPdf's rackless check arriving again.
      final doc = _doc();
      for (final e in buildSeedCatalog().entries) {
        _hold(doc, e.key, e.value);
      }
      final session = _session(doc);
      final picker = FakeFilePicker(savePaths: [r'C:\out\kit.rpda']);

      final ok = await exportDeviceLibrary(
        session: session,
        picker: picker,
        writer: _writer(FakeFileStore()),
        askForLibrary: (_) async => fail('nothing to ask about'),
        context: _windows,
      );
      expect(ok, isFalse);
      expect(picker.saveCalls, 0);
      expect(session.status, kNothingToPackStatus);
    });

    test('it asks for the LIBRARY kind, not the device one', () async {
      // A caller that forgot opens a dialog listing `*.rmdx`, which reads
      // as a broken feature rather than a wrong argument. That is M4-M1's
      // whole point, one extension further on.
      final doc = _doc()..templates.clear();
      _hold(doc, 'tpl.mine', _body('Mine'));
      final picker = FakeFilePicker(savePaths: [r'C:\out\kit.rpda']);

      await exportDeviceLibrary(
        session: _session(doc),
        picker: picker,
        writer: _writer(
          FakeFileStore(initialDirectories: <String>{'C:', r'C:\out'}),
        ),
        askForLibrary: (c) async =>
            ExportLibraryRequest(name: 'Shop Kit', selected: c),
        context: _windows,
      );
      expect(picker.dialogTypes, [FileDialogType.library]);
      expect(picker.suggestedNames, ['shop-kit.rpda']);
    });

    test(
      'the bytes on disk read back as the library that was asked for',
      () async {
        // THE ARTIFACT, NOT THE MECHANISM: what matters is that the file
        // written is one this product can import.
        final doc = _doc()..templates.clear();
        _hold(doc, 'tpl.a', _body('Amp'));
        _hold(doc, 'tpl.b', _body('Switch'));
        final fs = FakeFileStore(
          initialDirectories: <String>{'C:', r'C:\out'},
        );

        final ok = await exportDeviceLibrary(
          session: _session(doc),
          picker: FakeFilePicker(savePaths: [r'C:\out\kit.rpda']),
          writer: _writer(fs),
          askForLibrary: (c) async =>
              ExportLibraryRequest(name: 'Shop Kit', selected: c),
          context: _windows,
        );
        expect(ok, isTrue);

        final written = _bytesAt(fs, r'C:\out\kit.rpda');
        expect(written, isNotNull);
        final read = readRmdaBytes(written!);
        final lib = (read as Ok<DeviceLibraryFile>).value;
        expect(lib.name, 'Shop Kit');
        expect(lib.templates.map((t) => t.body.displayName), ['Amp', 'Switch']);
      },
    );

    test('a subset packs only what the dialog returned', () async {
      // The Advanced picker's whole point: the caller decides, and this
      // layer must not re-derive the selection from the document.
      final doc = _doc()..templates.clear();
      _hold(doc, 'tpl.a', _body('Amp'));
      _hold(doc, 'tpl.b', _body('Switch'));
      final fs = FakeFileStore(
        initialDirectories: <String>{'C:', r'C:\out'},
      );

      await exportDeviceLibrary(
        session: _session(doc),
        picker: FakeFilePicker(savePaths: [r'C:\out\kit.rpda']),
        writer: _writer(fs),
        askForLibrary: (c) async => ExportLibraryRequest(
          name: 'Just One',
          selected: [c.firstWhere((t) => t.body.displayName == 'Switch')],
        ),
        context: _windows,
      );
      final lib =
          (readRmdaBytes(_bytesAt(fs, r'C:\out\kit.rpda')!)
                  as Ok<DeviceLibraryFile>)
              .value;
      expect(lib.templates.map((t) => t.body.displayName), ['Switch']);
    });

    test('a cancelled dialog opens no file picker and says so', () async {
      final doc = _doc()..templates.clear();
      _hold(doc, 'tpl.mine', _body('Mine'));
      final session = _session(doc);
      final picker = FakeFilePicker(savePaths: [r'C:\out\kit.rpda']);

      final ok = await exportDeviceLibrary(
        session: session,
        picker: picker,
        writer: _writer(FakeFileStore()),
        askForLibrary: (_) async => null,
        context: _windows,
      );
      expect(ok, isFalse);
      expect(picker.saveCalls, 0);
      expect(session.status, kLibraryExportCancelledStatus);
    });
  });

  group('import', () {
    test('the degraded session is refused BEFORE any dialog', () async {
      // There is nowhere to put a library. Finding that out after the
      // user has picked a file and read a warning is the wasted
      // interaction this app already refuses to inflict.
      final session = _session(_doc());
      final picker = FakeFilePicker(openPaths: [r'C:\in\kit.rpda']);
      final prompts = ScriptedPrompts();

      final ok = await importDeviceLibrary(
        session: session,
        picker: picker,
        writer: _writer(FakeFileStore()),
        fs: FakeFileStore(),
        prompts: prompts,
        dataRoot: null,
        confirmImport: (_) async => fail('nothing to confirm'),
        context: _windows,
      );
      expect(ok, isFalse);
      expect(picker.openCalls, 0, reason: 'no dialog with nowhere to put it');
      expect(prompts.errors, hasLength(1));
      expect(prompts.errors.single.title, contains('unavailable'));
    });

    test('it asks for the LIBRARY kind', () async {
      final picker = FakeFilePicker(openPaths: [null]);
      await importDeviceLibrary(
        session: _session(_doc()),
        picker: picker,
        writer: _writer(FakeFileStore()),
        fs: FakeFileStore(),
        prompts: ScriptedPrompts(),
        dataRoot: _root,
        confirmImport: (_) async => true,
        context: _windows,
      );
      expect(picker.dialogTypes, [FileDialogType.library]);
    });

    test(
      'a .rpdx is refused as the wrong kind, and names the right door',
      () async {
        final rmdx = encodeRmdxBytes(
          DeviceTemplateFile(
            templateId: const TemplateId('tpl.a'),
            version: 1,
            contentHash: 'unhashed:a@1',
            body: _body('Amp'),
          ),
        );
        final fs = FakeFileStore(
          initialFiles: {r'C:\in\one.rpdx': rmdx},
          initialDirectories: <String>{'C:', r'C:\in', _root},
        );
        final prompts = ScriptedPrompts();

        final ok = await importDeviceLibrary(
          session: _session(_doc()),
          picker: FakeFilePicker(openPaths: [r'C:\in\one.rpdx']),
          writer: _writer(fs),
          fs: fs,
          prompts: prompts,
          dataRoot: _root,
          confirmImport: (_) async => fail('a refusal must not reach a prompt'),
          context: _windows,
        );
        expect(ok, isFalse);
        expect(
          prompts.errors.single.detail,
          contains('Import device template'),
          reason: 'the message names the right door, not just the refusal',
        );
      },
    );

    test('a good library is COPIED onto the shelf, byte for byte', () async {
      // Copied, not referenced: a library referenced in place lives on
      // whatever stick the user picked it from. And copied VERBATIM, not
      // re-encoded, so a hand-edited file keeps the evidence the mismatch
      // warning is about.
      final bytes = _rmda('Shop Kit', ['Amp', 'Switch']);
      final fs = FakeFileStore(
        initialFiles: {r'C:\in\kit.rpda': bytes},
        initialDirectories: <String>{'C:', r'C:\in', _root},
      );
      final session = _session(_doc());

      final ok = await importDeviceLibrary(
        session: session,
        picker: FakeFilePicker(openPaths: [r'C:\in\kit.rpda']),
        writer: _writer(fs),
        fs: fs,
        prompts: ScriptedPrompts(),
        dataRoot: _root,
        confirmImport: (preview) async {
          expect(preview.name, 'Shop Kit');
          expect(preview.templateCount, 2);
          expect(preview.hasMismatch, isFalse);
          return true;
        },
        context: _windows,
      );
      expect(ok, isTrue);
      expect(
        _bytesAt(fs, _windows.join(_shelf, 'kit.rpda')),
        bytes,
        reason: 'verbatim: re-encoding would normalise a hand-edited file',
      );
      expect(session.status, contains('Shop Kit'));
    });

    test(
      'and listLibraries then finds it, which is the join with #238',
      () async {
        final fs = FakeFileStore(
          initialFiles: {
            r'C:\in\kit.rpda': _rmda('Shop Kit', ['Amp']),
          },
          initialDirectories: <String>{'C:', r'C:\in', _root},
        );
        await importDeviceLibrary(
          session: _session(_doc()),
          picker: FakeFilePicker(openPaths: [r'C:\in\kit.rpda']),
          writer: _writer(fs),
          fs: fs,
          prompts: ScriptedPrompts(),
          dataRoot: _root,
          confirmImport: (_) async => true,
          context: _windows,
        );
        final shelf = await listLibraries(fs, _root, context: _windows);
        expect(shelf.map((l) => l.id), ['kit']);
      },
    );

    test('a cancelled confirmation copies NOTHING', () async {
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\kit.rpda': _rmda('Shop Kit', ['Amp']),
        },
        initialDirectories: <String>{'C:', r'C:\in', _root},
      );
      final session = _session(_doc());

      final ok = await importDeviceLibrary(
        session: session,
        picker: FakeFilePicker(openPaths: [r'C:\in\kit.rpda']),
        writer: _writer(fs),
        fs: fs,
        prompts: ScriptedPrompts(),
        dataRoot: _root,
        confirmImport: (_) async => false,
        context: _windows,
      );
      expect(ok, isFalse);
      expect(await listLibraries(fs, _root, context: _windows), isEmpty);
      expect(session.status, kLibraryImportCancelledStatus);
    });

    test(
      'a mismatched library still imports, with the names in the preview',
      () async {
        // AC-042 and #240 in one case: it imports WITH A BADGE, it does not
        // refuse.
        final good = _body('Amp');
        final bytes = encodeRmdaBytes(
          DeviceLibraryFile(
            name: 'Edited Kit',
            templates: [
              DeviceTemplateFile(
                templateId: const TemplateId('tpl.a'),
                version: 1,
                contentHash: templateContentHash(_body('a different body')),
                body: good,
              ),
            ],
          ),
        );
        final fs = FakeFileStore(
          initialFiles: {r'C:\in\kit.rpda': bytes},
          initialDirectories: <String>{'C:', r'C:\in', _root},
        );

        final ok = await importDeviceLibrary(
          session: _session(_doc()),
          picker: FakeFilePicker(openPaths: [r'C:\in\kit.rpda']),
          writer: _writer(fs),
          fs: fs,
          prompts: ScriptedPrompts(),
          dataRoot: _root,
          confirmImport: (preview) async {
            expect(preview.mismatched, ['Amp']);
            return true;
          },
          context: _windows,
        );
        expect(ok, isTrue, reason: 'a warning is not a refusal');
        expect(await listLibraries(fs, _root, context: _windows), hasLength(1));
      },
    );
  });
}
