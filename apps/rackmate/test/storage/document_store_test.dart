// DocumentStore: the open error surface and the §9.3 save sequence's
// steps 6, 7 and 8.
//
// The two assertions that carry the most weight:
//   * an EDIT DURING THE SERIALIZE AWAIT does not get marked saved. The
//     serializer is gated by a Completer, a real edit is committed while
//     the save is in flight, and the document must still read dirty
//     afterwards. Reverting `markSavedAt(captured)` to `markSaved()`
//     fails it.
//   * a FAILED SAVE DOES NOT DELETE THE RECOVERY SNAPSHOT. Step 7 runs
//     only after step 5 landed the new bytes, so a crash between them
//     costs nothing.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/document_store.dart';
import 'package:rackmate/src/storage/errors.dart';
import 'package:rackmate/src/storage/recents_store.dart';
import 'package:rackmate/src/storage/recovery_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';
import 'package:rackmate/src/storage/serialization.dart';
import 'package:rackmate_core/rackmate_core.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _jobs = r'C:\jobs';
final _paths = SavePaths.forTarget(r'C:\jobs\Smith', context: _windows);

const _codec = JsonDocumentCodec();
final _fixed = DateTime.utc(2026, 7, 18, 9);
const _rackId = Uuid('doc-rack-1');
const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'seed');

RackDocument _doc({String id = '0190e3c1-0000-7000-8000-000000000000'}) {
  final doc = RackDocument(
    id: Uuid(id),
    appVersion: '0.1.0',
    createdAt: _fixed,
    modifiedAt: _fixed,
    meta: _meta(),
    info: ProjectInfo(projectName: 'Smith Residence'),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'AV Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return doc;
}

AddDeviceCommand _addDevice({Uuid? id, int ruIndex = 1}) => AddDeviceCommand(
  id: id,
  kind: DeviceKind.rackDevice,
  templateRef: _templateRef,
  designator: 'DEV-1',
  name: 'Device 1',
  placement: RailPlacement(rackId: _rackId, ruIndex: ruIndex, face: Face.front),
  now: _fixed,
  actor: 'tester',
);

final class _Made {
  _Made(this.fs, this.store, this.recovery);
  final FakeFileStore fs;
  final DocumentStore store;
  final RecoveryStore recovery;
}

_Made _make({
  Map<String, Uint8List>? files,
  Set<String>? dirs,
  Serializer? serializer,
  Deserializer? deserializer,
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: {'C:', _dataRoot, _jobs, ...?dirs},
  );
  final writer = AtomicWriter(
    fs: fs,
    queue: SaveQueue(),
    context: _windows,
    delay: (_) async {},
  );
  final recovery = RecoveryStore(
    fs: fs,
    writer: writer,
    dataRoot: _dataRoot,
    context: _windows,
  );
  return _Made(
    fs,
    DocumentStore(
      fs: fs,
      writer: writer,
      recovery: recovery,
      serializer: serializer ?? inlineSerializer,
      deserializer: deserializer ?? inlineDeserializer,
      context: _windows,
    ),
    recovery,
  );
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('open — the error surface, every named case', () {
    test('a good file opens', () async {
      final made = _make(
        files: {_paths.target: _codec.write(_doc())},
      );
      final result = await made.store.open(_paths.target);

      expect(result, isA<Ok<OpenedDocument>>());
      final opened = (result as Ok<OpenedDocument>).value;
      expect(opened.document.info.projectName, 'Smith Residence');
      expect(opened.path, _paths.target);
      expect(opened.openReadOnly, isFalse);
      expect(opened.migratedFromSchemaVersion, isNull);
      expect(
        opened.originalBytes,
        isNull,
        reason:
            'no migration ran, so holding a redundant copy of the '
            'bytes for the whole session would be waste',
      );
      expect(opened.baseline.isAbsent, isFalse);
    });

    test('a MISSING file whose DIRECTORY is reachable reports '
        'OpenNotFound', () async {
      final made = _make();
      final result = await made.store.open(_paths.target);

      final error = (result as Err<OpenedDocument>).error;
      expect(error, isA<OpenNotFound>());
      expect((error as OpenNotFound).backup, isNull);
      expect(
        shouldEvictOnOpenFailure(error as OpenError),
        isTrue,
        reason:
            'definitive: the folder is right there and the file is '
            'not',
      );
    });

    test('a file on an UNREACHABLE drive is NOT reported as missing — '
        'and its recents entry survives', () async {
      // THE §9.5 UNMOUNTED-DRIVE RULE, at the one line where it has
      // teeth. Measured: `stat` on a dead UNC path answers negatively
      // WITHOUT throwing, so it is indistinguishable from a deleted file
      // unless the directory is checked too. Report OpenNotFound here and
      // a sleeping NAS silently costs the user their recents entry.
      final made = _make();
      final result = await made.store.open(
        r'\\NAS\jobs\Smith.rmpj',
      );

      final error = (result as Err<OpenedDocument>).error;
      expect(
        error,
        isA<OpenUnreachable>(),
        reason:
            'the directory did not answer either, so "not there" is '
            'not something we know',
      );
      expect(
        shouldEvictOnOpenFailure(error as OpenError),
        isFalse,
        reason:
            'a temporarily unmounted network drive must not evict '
            'the entry',
      );
    });

    test('A MISSING FILE WITH A .bak PRESENT OFFERS THE BACKUP', () async {
      // Without this, the `.bak` is decoration: it exists and nothing
      // ever offers it. This is the UI half of the crash-safety story,
      // and it also covers a user who deleted the wrong file.
      final made = _make(
        files: {_paths.backup: _codec.write(_doc())},
      );
      final result = await made.store.open(_paths.target);

      final error = (result as Err<OpenedDocument>).error as OpenNotFound;
      expect(error.backup, isNotNull);
      expect(error.backup!.path, _paths.backup);
      expect(error.backup!.size, greaterThan(0));
    });

    test('a CORRUPT file reports OpenCorrupt — and offers the .bak', () async {
      // THIS is where the .bak earns its existence.
      final made = _make(
        files: {
          _paths.target: _bytes(
            '{"generator":"RackMate","schemaVersion":2,'
            '"minReaderVersion":2,"document":{',
          ),
          _paths.backup: _codec.write(_doc()),
        },
      );
      final result = await made.store.open(_paths.target);

      final error = (result as Err<OpenedDocument>).error;
      expect(error, isA<OpenCorrupt>());
      expect((error as OpenCorrupt).backup, isNotNull);
    });

    test('a corrupt file with NO .bak still reports honestly', () async {
      final made = _make(
        files: {_paths.target: _bytes('not json at all')},
      );
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenCorrupt>());
      expect((error as OpenCorrupt).backup, isNull);
    });

    test('NOT A RACKMATE FILE reports the foreign generator', () async {
      final made = _make(
        files: {
          _paths.target: _bytes(
            '{"generator":"SomeOtherApp","schemaVersion":2,'
            '"minReaderVersion":2,"document":{}}',
          ),
        },
      );
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenNotARackMateFile>());
      expect(
        (error as OpenNotARackMateFile).generator,
        'SomeOtherApp',
        reason:
            'shown so the user can tell "wrong file" from "damaged '
            'file"',
      );
    });

    test('a ZIP gets its own message, not the generic one', () async {
      final made = _make(
        files: {
          _paths.target: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2]),
        },
      );
      expect(
        ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error,
        isA<OpenZipContainer>(),
      );
    });

    test('a NEWER SCHEMA is REFUSED, naming both versions', () async {
      // No "open anyway" escape hatch anywhere downstream: opening would
      // silently discard data this build cannot model, which turns a
      // refusal into a corruption.
      final made = _make(
        files: {
          _paths.target: _bytes(
            '{"generator":"RackMate","schemaVersion":${kSchemaVersion + 1},'
            '"minReaderVersion":${kSchemaVersion + 1},"document":{}}',
          ),
        },
      );
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenNewerSchema>());
      expect(
        (error as OpenNewerSchema).minReaderVersion,
        kSchemaVersion + 1,
      );
      expect(error.supportedSchemaVersion, kSchemaVersion);
    });

    test('a newer schemaVersion this build CAN read opens READ-ONLY', () async {
      final raw =
          jsonDecode(utf8.decode(_codec.write(_doc())))! as Map<String, Object?>
            ..['schemaVersion'] = kSchemaVersion + 1;
      final made = _make(
        files: {_paths.target: _bytes(jsonEncode(raw))},
      );

      final opened =
          ((await made.store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(
        opened.openReadOnly,
        isTrue,
        reason:
            'editable in memory, still autosaved to a recovery '
            'snapshot — blocked from OVERWRITING, not from working',
      );
    });

    test('TOO LARGE is refused with both numbers', () async {
      final made = _make(files: {_paths.target: Uint8List(4096)});
      final store = DocumentStore(
        fs: made.fs,
        writer: AtomicWriter(fs: made.fs, queue: SaveQueue()),
        recovery: made.recovery,
        serializer: inlineSerializer,
        deserializer: (bytes) async => parseDocumentJsonTree(
          bytes,
          limits: const JsonLimits(maxBytes: 128),
        ),
        context: _windows,
      );

      final error =
          ((await store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenTooLarge>());
      expect((error as OpenTooLarge).bytes, 4096);
      expect(error.limit, 128);
    });

    test('TOO DEEPLY NESTED is refused BEFORE jsonDecode — a stack '
        'overflow would take the process down', () async {
      final made = _make(
        files: {
          _paths.target: _bytes('${'[' * 100000}1${']' * 100000}'),
        },
      );
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenTooDeeplyNested>());
      expect((error as OpenTooDeeplyNested).limit, kMaxJsonDepth);
    });

    test('a MIGRATED file retains its original bytes for the pre-update '
        'snapshot', () async {
      // The first save will rewrite this file at v2, which is
      // irreversible for any older build the user still has installed.
      final v1 =
          jsonDecode(utf8.decode(_codec.write(_doc())))! as Map<String, Object?>
            ..['schemaVersion'] = 1
            ..['minReaderVersion'] = 1;
      final bytes = _bytes(jsonEncode(v1));
      final made = _make(files: {_paths.target: bytes});

      final opened =
          ((await made.store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(opened.migratedFromSchemaVersion, 1);
      expect(
        opened.originalBytes,
        equals(bytes),
        reason:
            'byte-identical, so the snapshot really is what the user '
            'had before we touched it',
      );
    });
  });

  test('a file whose migration chain cannot reach this build is REFUSED, '
      'and offers the .bak', () async {
    // `"schemaVersion": -1` from a mangled byte or a merge artefact
    // clears the minReaderVersion gate and finds no migration, so the
    // chain stops where it started. Before, that came back as Ok and the
    // envelope was decoded and adopted as a healthy document — read/write,
    // with a pre-update snapshot minted for it, and the next save writing
    // it back out still stamped -1.
    //
    // The surfacing is deliberately `OpenCorrupt`: for the reachable case
    // the file IS damaged, and OpenCorrupt is the one error that offers
    // the sibling `.bak` — which is exactly what the user wants here.
    final root =
        jsonDecode(utf8.decode(_codec.write(_doc())))! as Map<String, Object?>
          ..['schemaVersion'] = -1
          ..['minReaderVersion'] = -1;
    final made = _make(
      files: {
        _paths.target: Uint8List.fromList(utf8.encode(jsonEncode(root))),
        _paths.backup: _codec.write(_doc()),
      },
    );

    final result = await made.store.open(_paths.target);

    final error = (result as Err<OpenedDocument>).error;
    expect(error, isA<OpenCorrupt>());
    expect(
      (error as OpenCorrupt).detail,
      contains('UnmigratableSchemaError'),
      reason:
          'the diagnostics channel has to be able to tell an unmigratable '
          'envelope from a truncated one',
    );
    expect(error.backup, isNotNull);
  });

  group('THE OPEN PATH NEVER COMPLETES WITH AN ERROR', () {
    // `open` and `decodeBytes` are awaited from `unawaited(...)` in the
    // shell and from a `CallbackAction.onInvoke` that discards its
    // future, and `main()` installs no `PlatformDispatcher.onError`, no
    // `FlutterError.onError` and no `runZonedGuarded`. So an error
    // escaping here is not a crash the user can report — it is Ctrl+O
    // doing NOTHING AT ALL: no dialog, no log, no crash.
    //
    // The unguarded line was `final tree = await deserializer(bytes)`,
    // sitting outside every try in the file.

    test('a deserializer that THROWS an Exception is reported, not '
        'escaped', () async {
      final made = _make(
        files: {_paths.target: _codec.write(_doc())},
        deserializer: (_) async => throw const StorageOsException(112),
      );

      final result = await made.store.open(_paths.target);

      expect(result, isA<Err<OpenedDocument>>());
      expect((result as Err<OpenedDocument>).error, isA<OpenUnexpected>());
    });

    test('a deserializer that throws an ERROR is reported too', () async {
      // `Isolate.run` is the production deserializer: the SPAWN can fail
      // under memory pressure, and an `OutOfMemoryError` decoding a file
      // near the 64 MB cap is an Error that no `on Exception` clause in
      // the chain catches.
      final made = _make(
        files: {_paths.target: _codec.write(_doc())},
        deserializer: (_) async => throw const OutOfMemoryError(),
      );

      final result = await made.store.open(_paths.target);

      expect(result, isA<Err<OpenedDocument>>());
      final error = (result as Err<OpenedDocument>).error;
      expect(error, isA<OpenUnexpected>());
      expect((error as OpenUnexpected).cause, isA<OutOfMemoryError>());
      expect(
        error.path,
        _paths.target,
        reason: 'the dialog has to be able to name the file',
      );
    });

    test('and the same guard covers decodeBytes, which the starter card '
        'and the .bak fallback both go through', () async {
      final made = _make(
        deserializer: (_) async => throw StateError('isolate would not spawn'),
      );

      final result = await made.store.decodeBytes(
        path: null,
        bytes: _codec.write(_doc()),
      );

      expect(result, isA<Err<OpenedDocument>>());
      expect((result as Err<OpenedDocument>).error, isA<OpenUnexpected>());
    });
  });

  group('save — §9.3 steps 6, 7 and 8', () {
    test('writes the document and marks exactly the written state '
        'saved', () async {
      final made = _make();
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());

      final result = await made.store.save(
        controller: controller,
        paths: _paths,
      );

      expect(result, isA<Ok<SavedFile>>());
      final saved = (result as Ok<SavedFile>).value;
      expect(controller.isDirty, isFalse);
      expect(saved.savedStateId, controller.doc.stateId);
      expect(saved.bytesWritten, greaterThan(0));

      // Byte-identical round trip through the store (CR-117).
      final reopened = await made.store.open(_paths.target);
      expect(reopened, isA<Ok<OpenedDocument>>());
      expect(
        _codec.write((reopened as Ok<OpenedDocument>).value.document),
        equals(await made.fs.readBytes(_paths.target)),
      );
    });

    test('STEP 7 — a successful save deletes the recovery snapshot', () async {
      final made = _make();
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());

      await made.recovery.write(
        sidecar: RecoverySidecar(
          docId: controller.doc.id.v,
          sequence: 1,
          savedAt: _fixed,
          displayName: 'Smith Residence',
          appVersion: '0.1.0',
          schemaVersion: kSchemaVersion,
        ),
        documentBytes: _codec.write(controller.doc),
      );
      expect(
        made.fs.state.files.containsKey(
          made.recovery.snapshotPathFor(controller.doc.id.v),
        ),
        isTrue,
      );

      await made.store.save(controller: controller, paths: _paths);

      expect(
        made.fs.state.files.containsKey(
          made.recovery.snapshotPathFor(controller.doc.id.v),
        ),
        isFalse,
      );
      expect(
        made.fs.state.files.containsKey(
          made.recovery.sidecarPathFor(controller.doc.id.v),
        ),
        isFalse,
      );
    });

    test('STEP 7 ORDERING — the snapshot is deleted only AFTER the new '
        'bytes are at the target', () async {
      final made = _make();
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());
      await made.recovery.write(
        sidecar: RecoverySidecar(
          docId: controller.doc.id.v,
          sequence: 1,
          savedAt: _fixed,
          displayName: 'Smith',
          appVersion: '0.1.0',
          schemaVersion: kSchemaVersion,
        ),
        documentBytes: _codec.write(controller.doc),
      );
      made.fs.resetJournal();

      await made.store.save(controller: controller, paths: _paths);

      final promoteAt = made.fs.journal.indexWhere(
        (op) => op is Renamed && op.to == _paths.target,
      );
      final snapshotDeletedAt = made.fs.journal.indexWhere(
        (op) =>
            op is Deleted &&
            op.path == made.recovery.snapshotPathFor(controller.doc.id.v),
      );

      expect(promoteAt, greaterThanOrEqualTo(0));
      expect(
        snapshotDeletedAt,
        greaterThan(promoteAt),
        reason:
            'invariant I5: deleting the snapshot before the document '
            'is safely on disk opens a window where a crash loses '
            'everything',
      );
    });

    test('A FAILED SAVE LEAVES THE DOCUMENT DIRTY AND ITS SNAPSHOT '
        'INTACT', () async {
      final made = _make(dirs: const {});
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());
      final docId = controller.doc.id.v;

      await made.recovery.write(
        sidecar: RecoverySidecar(
          docId: docId,
          sequence: 1,
          savedAt: _fixed,
          displayName: 'Smith',
          appVersion: '0.1.0',
          schemaVersion: kSchemaVersion,
        ),
        documentBytes: _codec.write(controller.doc),
      );

      // Save to a directory that is not there.
      final elsewhere = SavePaths.forTarget(
        r'E:\unplugged\Smith',
        context: _windows,
      );
      final result = await made.store.save(
        controller: controller,
        paths: elsewhere,
      );

      expect((result as Err<SavedFile>).error, isA<SaveDirectoryMissing>());
      expect(
        controller.isDirty,
        isTrue,
        reason: 'nothing was written, so nothing may be marked saved',
      );
      expect(
        made.fs.state.files.containsKey(made.recovery.snapshotPathFor(docId)),
        isTrue,
        reason: 'the unsaved work still needs its safety net',
      );
    });

    test('EDIT DURING THE SERIALIZE AWAIT is not marked saved', () async {
      // The mutation test for `markSavedAt(captured)`. Revert it to
      // `markSaved()` and this fails: the later edit would be declared
      // written, its recovery snapshot deleted, and a crash would take it
      // with nothing to recover from.
      final gate = Completer<void>();
      final made = _make(
        serializer: (tree) async {
          await gate.future;
          return encodeJsonTreeBytes(tree);
        },
      );

      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice(id: const Uuid('dev-a')));

      final saving = made.store.save(controller: controller, paths: _paths);

      // The user keeps working while the isolate churns.
      controller.run(_addDevice(id: const Uuid('dev-b'), ruIndex: 5));

      gate.complete();
      final result = await saving;
      expect(result, isA<Ok<SavedFile>>());

      expect(
        controller.isDirty,
        isTrue,
        reason:
            'dev-b was never serialized; declaring it saved would '
            'lose it at the next crash',
      );
      expect(controller.editsSinceSave, 1);

      // ...and the bytes on disk really do lack the late edit.
      final onDisk = await made.store.open(_paths.target);
      expect(
        (onDisk as Ok<OpenedDocument>).value.document.devices.keys.map(
          (u) => u.v,
        ),
        ['dev-a'],
      );
    });

    test('a save to a locked target reports SaveLocked and keeps the '
        'old file', () async {
      final made = _make(files: {_paths.target: _bytes('old bytes here')});
      made.fs.failRenamesTo[_paths.target] = 99;

      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());

      final result = await made.store.save(
        controller: controller,
        paths: _paths,
      );

      expect((result as Err<SavedFile>).error, isA<SaveLocked>());
      expect(controller.isDirty, isTrue);
      expect(
        await made.fs.readBytes(_paths.target),
        _bytes('old bytes here'),
      );
    });

    test('the external-change check refuses to overwrite a file that '
        'moved underneath us', () async {
      final made = _make(files: {_paths.target: _codec.write(_doc())});
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());

      final result = await made.store.save(
        controller: controller,
        paths: _paths,
        expected: FileBaseline(size: 1, modified: _ancient),
      );

      final error = (result as Err<SavedFile>).error;
      expect(error, isA<SaveChangedOnDisk>());
      expect((error as SaveChangedOnDisk).found, isNotNull);
      expect(controller.isDirty, isTrue);
    });
  });

  group('serializeSnapshot', () {
    test('captures the state id alongside the bytes', () async {
      final made = _make();
      final controller = DocumentController(_doc(), clock: FixedClock(_fixed))
        ..run(_addDevice());

      final snapshot = await made.store.serializeSnapshot(controller);
      expect(snapshot.stateId, controller.doc.stateId);
      expect(snapshot.bytes, equals(_codec.write(controller.doc)));
    });
  });

  group('decodeBytes — the same path for snapshots, starters and .bak', () {
    test('decoding bytes with no path still classifies errors', () async {
      final made = _make();
      final result = await made.store.decodeBytes(
        path: null,
        bytes: _bytes('{"generator":"Nope"}'),
      );
      expect(
        (result as Err<OpenedDocument>).error,
        isA<OpenNotARackMateFile>(),
      );
    });

    test('a starter opened with a null path has an ABSENT baseline', () async {
      final made = _make();
      final result = await made.store.decodeBytes(
        path: null,
        bytes: _codec.write(_doc()),
      );
      final opened = (result as Ok<OpenedDocument>).value;
      expect(opened.path, isNull);
      expect(
        opened.baseline.isAbsent,
        isTrue,
        reason:
            'nothing on disk to compare against, so the first save '
            'skips the external-change check',
      );
    });
  });
}

final _ancient = DateTime.utc(2020);
