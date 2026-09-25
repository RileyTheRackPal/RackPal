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
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/recents_store.dart';
import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';

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
  Map<String, Object> failReadsOf = const {},
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: {'C:', _dataRoot, _jobs, ...?dirs},
    failReadsOf: failReadsOf,
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
      final made = _make(files: {_paths.target: _codec.write(_doc())});
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
      final result = await made.store.open(r'\\NAS\jobs\Smith.rmpj');

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
      final made = _make(files: {_paths.backup: _codec.write(_doc())});
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
            '{"generator":"RackPal","schemaVersion":2,'
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
      final made = _make(files: {_paths.target: _bytes('not json at all')});
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenCorrupt>());
      expect((error as OpenCorrupt).backup, isNull);
    });

    test('NOT A RACKPAL FILE reports the foreign generator', () async {
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
      expect(error, isA<OpenNotARackPalFile>());
      expect(
        (error as OpenNotARackPalFile).generator,
        'SomeOtherApp',
        reason:
            'shown so the user can tell "wrong file" from "damaged '
            'file"',
      );
    });

    test('SIX BYTES OF ZIP SIGNATURE IS A DAMAGED FILE, NOT A FOREIGN '
        'ONE, and this expectation moved at PLAN-B', () async {
      // It used to expect `OpenZipContainer`, when that state meant "this
      // file begins with PK and we do not read zip". DR-019 §11.18.2(1)
      // makes a zip an ordinary `.rmpj`, so the two outcomes separated:
      // an archive with entries but no `document.json` is FOREIGN, and an
      // archive with no entries at all is DAMAGED. Six bytes has no
      // central directory, so it is the second, and it is the one that
      // earns a `.bak` offer.
      final made = _make(
        files: {
          _paths.target: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2]),
        },
      );
      expect(
        ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error,
        isA<OpenContainerUnreadable>(),
      );
    });

    test('AND A REAL PROJECT WITH A BINARY MEMBER OPENS, which is what '
        'stops the case above from reading as "zip is refused"', () async {
      final made = _make(
        files: {
          _paths.target: writeContainerBytes(_codec.write(_doc()), {
            'underlays/level-1.png': Uint8List.fromList(
              List<int>.generate(512, (i) => i % 256),
            ),
          }),
        },
      );
      final opened = await made.store.open(_paths.target);
      expect(opened, isA<Ok<OpenedDocument>>());
      expect(
        (opened as Ok<OpenedDocument>).value.members,
        contains('underlays/level-1.png'),
      );
    });

    test('a NEWER SCHEMA is REFUSED, naming both versions', () async {
      // No "open anyway" escape hatch anywhere downstream: opening would
      // silently discard data this build cannot model, which turns a
      // refusal into a corruption.
      final made = _make(
        files: {
          _paths.target: _bytes(
            '{"generator":"RackPal","schemaVersion":${kSchemaVersion + 1},'
            '"minReaderVersion":${kSchemaVersion + 1},"document":{}}',
          ),
        },
      );
      final error =
          ((await made.store.open(_paths.target)) as Err<OpenedDocument>).error;
      expect(error, isA<OpenNewerSchema>());
      expect((error as OpenNewerSchema).minReaderVersion, kSchemaVersion + 1);
      expect(error.supportedSchemaVersion, kSchemaVersion);
    });

    test('a newer schemaVersion this build CAN read opens READ-ONLY', () async {
      final raw =
          jsonDecode(utf8.decode(_codec.write(_doc())))! as Map<String, Object?>
            ..['schemaVersion'] = kSchemaVersion + 1;
      final made = _make(files: {_paths.target: _bytes(jsonEncode(raw))});

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
        files: {_paths.target: _bytes('${'[' * 100000}1${']' * 100000}')},
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

  // ═══════════════════════════════════════════════════════════════════
  // A FILE THAT WAS THERE, AND THEN COULD NOT BE READ (#947)
  // ═══════════════════════════════════════════════════════════════════
  // Every case above fails before the read: the file is absent, or it
  // reads and does not decode. `_classifyOpen` is the branch for a read
  // that THROWS after `stat` said the file was there, and the first
  // coverage measurement (2026-09-24) found it had never run. Each case
  // is an OS error with a real Windows errno, thrown by the fake's
  // per-path read fault, and asserted on what the user is told and on
  // whether the recents entry survives, which is the part with teeth.
  group('open: a read that FAILS after the file was found', () {
    Future<OpenError> openFailingWith(
      Object fault, {
      Map<String, Uint8List> alsoFiles = const {},
    }) async {
      final made = _make(
        files: {_paths.target: _codec.write(_doc()), ...alsoFiles},
        failReadsOf: {_paths.target: fault},
      );
      final result = await made.store.open(_paths.target);
      return (result as Err<OpenedDocument>).error as OpenError;
    }

    test(
      'ACCESS DENIED (5) is a permission error, and the entry stays',
      () async {
        final error = await openFailingWith(const StorageOsException(5));
        expect(error, isA<OpenPermissionDenied>());
        expect(
          shouldEvictOnOpenFailure(error),
          isFalse,
          reason: 'the file is there; the user may yet be given access',
        );
      },
    );

    test('a file DELETED between the check and the read (2) is not found, '
        'and still offers the .bak', () async {
      final error = await openFailingWith(
        const StorageOsException(2),
        alsoFiles: {_paths.backup: _codec.write(_doc())},
      );
      expect(error, isA<OpenNotFound>());
      expect(
        (error as OpenNotFound).backup?.path,
        _paths.backup,
        reason:
            'the classifier builds its own OpenNotFound, and a .bak it '
            'forgot to look up is a recovery the user is never offered',
      );
      expect(shouldEvictOnOpenFailure(error), isTrue);
    });

    test('a share that DROPS mid-read (64) is unreachable, NOT missing, so '
        'the entry survives', () async {
      // §9.5's unmounted-drive rule again, one line further down: a read
      // that fails because the network name went away must not be
      // reported as a deleted file, or a sleeping NAS costs the user
      // their recents entry.
      final error = await openFailingWith(const StorageOsException(64));
      expect(error, isA<OpenUnreachable>());
      expect(shouldEvictOnOpenFailure(error), isFalse);
    });

    test('a failure with NO errno is unexpected, and still an answer rather '
        'than a throw', () async {
      final error = await openFailingWith(StateError('not an OS error'));
      expect(error, isA<OpenUnexpected>());
      expect(shouldEvictOnOpenFailure(error), isFalse);
    });
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
      expect(await made.fs.readBytes(_paths.target), _bytes('old bytes here'));
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

  // THE PLAN VIEW'S LAST MACHINE-CHECKABLE CLAUSE (`#943`), at the boundary
  // it names. "`write(read(bytes)) == bytes` holds on the zip path across a
  // write, a reopen and a second write, and a project with no underlay
  // writes bytes identical to what the plain-JSON path writes today."
  //
  // THE HALVES WERE PROVEN APART AND NEVER TOGETHER. The codec's three-step
  // trip runs over JSON alone (`plan_serialization_test.dart`), and the
  // container's runs over a hand-written JSON string and a ramp of bytes
  // standing in for a PNG (`container_determinism_test.dart`). Neither is a
  // PROJECT: a real underlay, its real image and source PDF as members,
  // saved and reopened through `DocumentStore`, which is the path a person
  // takes with File ▸ Save and File ▸ Open. That composition is what this
  // group runs, and every comparison is of the FILE ON DISK.
  group('CR-117 on the zip path, through the store (the Plan view clause)', () {
    const underlayId = Uuid('0190e3c1-1111-7000-8000-000000000001');
    const imageMember = 'underlays/$underlayId.png';
    const sourceMember = 'sources/$underlayId.pdf';

    /// A real PNG, not bytes that merely sit where one would: the member is
    /// what a floorplan import actually stores.
    Uint8List png() {
      final image = img.Image(width: 40, height: 30);
      for (var y = 0; y < 30; y++) {
        for (var x = 0; x < 40; x++) {
          image.setPixelRgb(x, y, x * 6, y * 8, 120);
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    /// The document half: an underlay that is calibrated, rendered from a
    /// PDF page, and turned, so every optional field the plan carries is on
    /// the wire.
    RackDocument withPlan() {
      final doc = _doc();
      doc.underlays[underlayId] = PlanUnderlay(
        id: underlayId,
        name: 'Level 1',
        imageMember: imageMember,
        format: PlanImageFormat.png,
        pixelWidth: 40,
        pixelHeight: 30,
        contentHash: 'sha256:level-1',
        order: const FracIndex('a0'),
        meta: _meta(),
        scale: const PlanScale(
          a: PxPt(2, 3),
          b: PxPt(38, 3),
          distance: Len(3_657_600_000),
        ),
        sourcePage: const PlanSourcePage(
          member: sourceMember,
          pageIndex: 0,
          contentHash: 'sha256:source',
        ),
      );
      return doc;
    }

    Map<String, Uint8List> members() => {
      imageMember: png(),
      sourceMember: Uint8List.fromList(utf8.encode('%PDF-1.7\n%stand-in\n')),
    };

    test(
      'a write, a reopen and a second write leave the file identical',
      () async {
        final made = _make();

        // Write.
        final first = await made.store.save(
          controller: DocumentController(withPlan(), clock: FixedClock(_fixed)),
          paths: _paths,
          members: members(),
        );
        expect(first, isA<Ok<SavedFile>>());
        final firstBytes = await made.fs.readBytes(_paths.target);
        expect(
          looksLikeZip(firstBytes),
          isTrue,
          reason: 'a project carrying a floorplan is a container',
        );

        // Reopen, and write again from what the reopen produced, never from
        // the originals: that is what catches a writer that is deterministic
        // only on the object it has just been handed.
        Future<Uint8List> reopenAndSave() async {
          final opened =
              ((await made.store.open(_paths.target)) as Ok<OpenedDocument>)
                  .value;
          expect(opened.document.underlays[underlayId]?.scale, isNotNull);
          final saved = await made.store.save(
            controller: DocumentController(
              opened.document,
              clock: FixedClock(_fixed),
            ),
            paths: _paths,
            members: opened.members,
          );
          expect(saved, isA<Ok<SavedFile>>());
          return made.fs.readBytes(_paths.target);
        }

        expect(await reopenAndSave(), firstBytes);
        // And once more, because two is a coincidence.
        expect(await reopenAndSave(), firstBytes);
      },
    );

    test('the members come back byte for byte, and no extra one', () async {
      final made = _make();
      final sent = members();
      await made.store.save(
        controller: DocumentController(withPlan(), clock: FixedClock(_fixed)),
        paths: _paths,
        members: sent,
      );

      final opened =
          ((await made.store.open(_paths.target)) as Ok<OpenedDocument>).value;
      expect(opened.members.keys.toSet(), sent.keys.toSet());
      for (final entry in sent.entries) {
        expect(opened.members[entry.key], entry.value, reason: entry.key);
      }
    });

    test(
      'a project with no underlay writes exactly the plain-JSON bytes',
      () async {
        final made = _make();
        final doc = _doc();
        final plain = _codec.write(doc);

        await made.store.save(
          controller: DocumentController(doc, clock: FixedClock(_fixed)),
          paths: _paths,
        );

        final written = await made.fs.readBytes(_paths.target);
        expect(
          looksLikeZip(written),
          isFalse,
          reason: 'no member, no container: the file every build has written',
        );
        expect(written, plain);
      },
    );
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
      expect((result as Err<OpenedDocument>).error, isA<OpenNotARackPalFile>());
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
