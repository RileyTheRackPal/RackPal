// `File ▸ Export device template…` and `File ▸ Import device template…`,
// as SEQUENCES (DR-101 §11.100, `#236`).
//
// The decisions are tested elsewhere: `template_import.dart`'s branches in
// core, the dialogs' copy and buttons in `rackpal_ui`. What is left here
// is the order of the steps and the places one can end early, which is
// `session_prompts.dart`'s split and the reason these run against a
// SCRIPTED answer rather than a pumped widget.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/device_template_io_actions.dart';
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal_core/rackpal_core.dart' hide MutableClock;
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

final _windows = p.Context(style: p.Style.windows);

/// The bytes at [path] in [fs], or null when nothing is there.
Uint8List? _bytesAt(FakeFileStore fs, String path) {
  final content = fs.state.files[path];
  return content is Bytes ? content.value : null;
}

final _now = DateTime.utc(2026, 8, 29, 12);

TemplateBody _body(String displayName, {String model = ''}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: displayName,
  frontU: 2,
);

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000bb'),
  appVersion: '0.4.73',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'drill'),
  info: ProjectInfo(projectName: 'IO drill'),
);

void _hold(RackDocument doc, String id, int version, TemplateBody body) {
  doc.templates[templateSnapshotKey(
    TemplateId(id),
    version,
  )] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: version,
    contentHash: 'unhashed:$id@$version',
    body: body,
    capturedAt: _now,
  );
}

Uint8List _rmdxBytes(String id, int version, TemplateBody body) =>
    encodeRmdxBytes(
      DeviceTemplateFile(
        templateId: TemplateId(id),
        version: version,
        contentHash: 'unhashed:$id@$version',
        body: body,
      ),
    );

({DocumentSession session, MutableClock clock}) _session(RackDocument doc) {
  final clock = MutableClock(_now);
  return (
    session: DocumentSession(
      controller: DocumentController(doc, clock: clock),
      context: _windows,
      recoveryEnabled: false,
    ),
    clock: clock,
  );
}

void main() {
  group('export', () {
    test('the chooser is asked BEFORE the file dialog', () async {
      // Asking where to put a file and only then which file it is wastes
      // the one interaction, which is `exportPdf`'s rackless check
      // arriving in a different order.
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX'));
      final s = _session(doc);
      final picker = FakeFilePicker(savePaths: [r'C:\out\mx.rmdx']);
      final fs = FakeFileStore();
      final order = <String>[];

      await exportDeviceTemplate(
        session: s.session,
        picker: picker,
        writer: AtomicWriter(fs: fs, queue: SaveQueue(), context: _windows),
        chooseTemplate: (rows) async {
          order.add('chooser');
          return rows.firstWhere((r) => r.id == 'tpl.mx');
        },
        context: _windows,
      );
      expect(picker.saveCalls, 1);
      expect(order, ['chooser']);
    });

    test('a cancelled chooser opens no file dialog and says so', () async {
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX'));
      final s = _session(doc);
      final picker = FakeFilePicker(savePaths: [r'C:\out\mx.rmdx']);

      final ok = await exportDeviceTemplate(
        session: s.session,
        picker: picker,
        writer: AtomicWriter(
          fs: FakeFileStore(),
          queue: SaveQueue(),
          context: _windows,
        ),
        chooseTemplate: (_) async => null,
        context: _windows,
      );
      expect(ok, isFalse);
      expect(
        picker.saveCalls,
        0,
        reason: 'no dialog for a template nobody chose',
      );
      expect(s.session.status, kTemplateExportCancelledStatus);
    });

    test(
      'it asks the dialog for the DEVICE kind, not the project one',
      () async {
        // M4-M1's whole point. A caller that forgot this opens a dialog
        // listing `*.rmpj`, which reads as a broken feature rather than a
        // wrong argument.
        final doc = _doc();
        _hold(doc, 'tpl.mx', 1, _body('MX'));
        final s = _session(doc);
        final picker = FakeFilePicker(savePaths: [r'C:\out\mx.rmdx']);

        await exportDeviceTemplate(
          session: s.session,
          picker: picker,
          writer: AtomicWriter(
            fs: FakeFileStore(),
            queue: SaveQueue(),
            context: _windows,
          ),
          chooseTemplate: (rows) async =>
              rows.firstWhere((r) => r.id == 'tpl.mx'),
          context: _windows,
        );
        expect(picker.dialogTypes, [FileDialogType.device]);
      },
    );

    test('the suggested name carries the version', () async {
      final doc = _doc();
      _hold(doc, 'tpl.mx', 3, _body('HDMI Matrix 16x16'));
      final s = _session(doc);
      final picker = FakeFilePicker(savePaths: [r'C:\out\x.rmdx']);

      await exportDeviceTemplate(
        session: s.session,
        picker: picker,
        writer: AtomicWriter(
          fs: FakeFileStore(),
          queue: SaveQueue(),
          context: _windows,
        ),
        chooseTemplate: (rows) async =>
            rows.firstWhere((r) => r.id == 'tpl.mx'),
        context: _windows,
      );
      expect(picker.suggestedNames, ['hdmi-matrix-16x16-v3.rmdx']);
    });

    test('the bytes on disk are the codec’s, and they read back', () async {
      // THE ARTIFACT, NOT THE MECHANISM: what matters is that the file
      // written is a file this product can import, so the assertion reads
      // it back through the reader rather than comparing byte arrays to
      // the encoder that produced them.
      final doc = _doc();
      _hold(doc, 'tpl.mx', 2, _body('MX', model: 'ABC-1'));
      final s = _session(doc);
      // THE DIRECTORIES ARE SEEDED, and the omission is why this test
      // failed first: `AtomicWriter` writes into a directory that has to
      // exist, and the fake models that faithfully. The three export
      // tests above pass either way, because each asserts what it names
      // and none of them looks at the disk.
      final fs = FakeFileStore(
        initialDirectories: <String>{'C:', r'C:\out'},
      );

      final ok = await exportDeviceTemplate(
        session: s.session,
        picker: FakeFilePicker(savePaths: [r'C:\out\mx.rmdx']),
        writer: AtomicWriter(fs: fs, queue: SaveQueue(), context: _windows),
        chooseTemplate: (rows) async =>
            rows.firstWhere((r) => r.id == 'tpl.mx'),
        context: _windows,
      );
      expect(ok, isTrue);

      final written = _bytesAt(fs, r'C:\out\mx.rmdx');
      expect(written, isNotNull, reason: 'the export wrote nothing');
      final read = readRmdxBytes(written!);
      expect(read, isA<Ok<DeviceTemplateFile>>());
      final file = (read as Ok<DeviceTemplateFile>).value;
      expect(file.body.displayName, 'MX');
      expect(file.body.model, 'ABC-1');
      expect(file.version, 2);
    });
  });

  group('import', () {
    test('a cancelled file dialog is SILENT', () async {
      // Unlike a cancelled export: nothing was going to change either
      // way, which is the one "nothing happened" openDocument allows.
      final s = _session(_doc());
      final ok = await importDeviceTemplate(
        session: s.session,
        controller: s.session.controller,
        picker: FakeFilePicker(openPaths: [null]),
        fs: FakeFileStore(),
        prompts: ScriptedPrompts(),
        clock: s.clock,
        confirmImport: (_) async => fail('nothing to confirm'),
      );
      expect(ok, isFalse);
      expect(s.session.status, isNot(kTemplateImportCancelledStatus));
    });

    test('it asks the dialog for the DEVICE kind', () async {
      final s = _session(_doc());
      final picker = FakeFilePicker(openPaths: [null]);
      await importDeviceTemplate(
        session: s.session,
        controller: s.session.controller,
        picker: picker,
        fs: FakeFileStore(),
        prompts: ScriptedPrompts(),
        clock: s.clock,
        confirmImport: (_) async => ImportTemplateChoice.cancel,
      );
      expect(picker.dialogTypes, [FileDialogType.device]);
    });

    test(
      'a project file is REFUSED as the wrong kind, and says which',
      () async {
        // The second half of M4-M1's dialog. Reporting a project as a
        // broken device template sends the user back to re-pick it.
        final s = _session(_doc());
        final fs = FakeFileStore(
          initialFiles: {
            r'C:\in\Smith.rmpj': Uint8List.fromList(
              utf8.encode('{"schemaVersion":2}'),
            ),
          },
        );
        final prompts = ScriptedPrompts();

        final ok = await importDeviceTemplate(
          session: s.session,
          controller: s.session.controller,
          picker: FakeFilePicker(openPaths: [r'C:\in\Smith.rmpj']),
          fs: fs,
          prompts: prompts,
          clock: s.clock,
          confirmImport: (_) async => fail('a refusal must not reach a prompt'),
        );
        expect(ok, isFalse);
        expect(prompts.errors, hasLength(1));
        expect(
          prompts.errors.single.detail,
          contains('File ▸ Open'),
          reason: 'the message has to name the right door, not just refuse',
        );
        expect(s.session.document.templates, isEmpty);
      },
    );

    test('a free id needs no question and lands as the file said', () async {
      final s = _session(_doc());
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\mx.rmdx': _rmdxBytes('tpl.mx', 3, _body('MX')),
        },
      );
      var asked = 0;

      final ok = await importDeviceTemplate(
        session: s.session,
        controller: s.session.controller,
        picker: FakeFilePicker(openPaths: [r'C:\in\mx.rmdx']),
        fs: fs,
        prompts: ScriptedPrompts(),
        clock: s.clock,
        confirmImport: (plan) async {
          asked++;
          expect(plan.collides, isFalse);
          return ImportTemplateChoice.importIt;
        },
      );
      expect(ok, isTrue);
      expect(
        asked,
        1,
        reason:
            'the confirmation still shows; the CHOICE '
            'does not',
      );
      expect(s.session.document.templates.keys, contains('tpl.mx@3'));
    });

    test('a collision reaches the prompt, and Cancel writes NOTHING', () async {
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX', model: 'MINE'));
      final s = _session(doc);
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\mx.rmdx': _rmdxBytes(
            'tpl.mx',
            1,
            _body('MX', model: 'THEIRS'),
          ),
        },
      );

      final ok = await importDeviceTemplate(
        session: s.session,
        controller: s.session.controller,
        picker: FakeFilePicker(openPaths: [r'C:\in\mx.rmdx']),
        fs: fs,
        prompts: ScriptedPrompts(),
        clock: s.clock,
        confirmImport: (plan) async {
          expect(plan.collides, isTrue);
          expect(plan.collision!.incumbentDisplayName, 'MX');
          return ImportTemplateChoice.cancel;
        },
      );
      expect(ok, isFalse);
      expect(s.session.document.templates, hasLength(1));
      expect(s.session.document.templates['tpl.mx@1']!.body.model, 'MINE');
      expect(s.session.status, kTemplateImportCancelledStatus);
    });

    test('the import is ONE undo step', () async {
      // It lands on the session's own controller, so Ctrl+Z puts it back
      // like any other edit. An import that could not be undone would be
      // the one document change with no way out.
      final s = _session(_doc());
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\mx.rmdx': _rmdxBytes('tpl.mx', 1, _body('MX')),
        },
      );

      await importDeviceTemplate(
        session: s.session,
        controller: s.session.controller,
        picker: FakeFilePicker(openPaths: [r'C:\in\mx.rmdx']),
        fs: fs,
        prompts: ScriptedPrompts(),
        clock: s.clock,
        confirmImport: (_) async => ImportTemplateChoice.importIt,
      );
      expect(s.session.document.templates, hasLength(1));
      expect(s.session.controller.undo.canUndo, isTrue);
      s.session.controller.undo.undo(s.session.document);
      expect(s.session.document.templates, isEmpty);
    });
  });
}
