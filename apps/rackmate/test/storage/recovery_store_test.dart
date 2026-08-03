// Recovery snapshots. The two interesting properties are ORDERING and
// the pairing rules that fall out of it:
//
//   snapshot written FIRST, sidecar SECOND  =>  "a sidecar exists"
//                                               IMPLIES "its snapshot is
//                                               complete"
//   sidecar deleted FIRST, snapshot SECOND  =>  a half-deleted pair is
//                                               never offered
//
// Both are asserted directly against the fake's journal, so a reordering
// fails loudly rather than producing a rare, unreproducible "RackMate
// offered me a recovery that was half a file".
//
// AND THE THIRD PROPERTY, WHICH USED TO BE ASSERTED BY NOTHING AT ALL:
// the snapshot's CONTENT. Every content check in this repo was
// `hasLength(64)`, so `bytes: Uint8List(documentBytes.length)` — 600 KB of
// zeros under a perfectly correct sidecar — passed the entire suite. The
// prompt would still say "Recover Smith Residence (12 unsaved changes)?",
// and pressing Recover would fail to decode. The write/read tests below
// therefore compare BYTES, and `_doc` is seeded so that two documents of
// the same length are not equal.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/recovery_store.dart';
import 'package:rackmate_core/rackmate_core.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _recoveryDir = r'C:\data\recovery';

final _at = DateTime.utc(2026, 7, 26, 14, 32, 11);

RecoverySidecar _sidecar(
  String docId, {
  String? realPath,
  int? unsavedEditCount = 12,
  String displayName = 'Smith Residence',
  int minute = 0,
}) => RecoverySidecar(
  docId: docId,
  realPath: realPath,
  sequence: 412,
  savedAt: _at.add(Duration(minutes: minute)),
  displayName: displayName,
  unsavedEditCount: unsavedEditCount,
  appVersion: '0.1.0',
  schemaVersion: kSchemaVersion,
);

({RecoveryStore store, FakeFileStore fs}) _make({
  Map<String, Uint8List>? files,
  Set<String>? dirs,
  String sessionId = 'session-A',
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: {'C:', _dataRoot, ...?dirs},
  );
  return (
    store: _storeOver(fs, sessionId: sessionId),
    fs: fs,
  );
}

/// A second [RecoveryStore] over the SAME filesystem — a second instance
/// of the app, which is a thing nothing in this product prevents.
RecoveryStore _storeOver(FakeFileStore fs, {required String sessionId}) =>
    RecoveryStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: _dataRoot,
      context: _windows,
      sessionId: sessionId,
    );

/// [n] bytes of document, whose CONTENT depends on [seed] as well as on
/// [n].
///
/// It used to be `List<int>.filled(n, 0x7B)`, which made any two documents
/// of the same size byte-identical — so "the snapshot is the document"
/// could never have been asserted more strongly than "the snapshot is the
/// right size" even if someone had tried.
Uint8List _doc(int n, {int seed = 1}) => Uint8List.fromList([
  for (var i = 0; i < n; i++) (i * 31 + seed * 97) % 256,
]);

void main() {
  group('write', () {
    test(
      'produces a snapshot and a sidecar in the recovery directory',
      () async {
        final made = _make();
        final result = await made.store.write(
          sidecar: _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj'),
          documentBytes: _doc(64),
        );

        expect(result, isA<Ok<void>>());
        expect(
          made.fs.state.files.containsKey(r'C:\data\recovery\doc-1.rmpj'),
          isTrue,
        );
        expect(
          made.fs.state.files.containsKey(r'C:\data\recovery\doc-1.json'),
          isTrue,
        );
      },
    );

    test('THE SNAPSHOT IS THE DOCUMENT — byte for byte, not merely the '
        'right length', () async {
      // The only content assertion this store ever had was
      // `hasLength(64)`. Under it, `bytes: Uint8List(documentBytes.length)`
      // in `write` passes: the sidecar is still correct, `scan()` still
      // offers the pair, the prompt still says "Recover Smith Residence
      // (12 unsaved changes)?" — and the 600 KB the user is being offered
      // are zeros. The feature whose only job is not losing work loses all
      // of it, silently.
      final made = _make();
      final document = _doc(64);

      await made.store.write(
        sidecar: _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj'),
        documentBytes: document,
      );

      // Through the API the recovery flow actually uses: scan, then read
      // the survivor it offers.
      final survivor = (await made.store.scan()).survivors.single;
      expect(
        await made.store.readSnapshot(survivor),
        orderedEquals(document),
        reason:
            'the bytes offered back to the user must be the bytes that '
            'were handed in',
      );
      // ...and the raw file agrees, so this is not an artefact of the
      // read path handing back what the write path remembered.
      expect(
        await made.fs.readBytes(r'C:\data\recovery\doc-1.rmpj'),
        orderedEquals(document),
      );
    });

    test('...and a DIFFERENT document of the same length would not pass '
        'that assertion', () {
      // Guards the guard. `_doc` used to be a constant fill, under which
      // the test above degrades back into `hasLength`.
      expect(_doc(64), isNot(orderedEquals(_doc(64, seed: 2))));
      expect(_doc(64, seed: 2), hasLength(64));
    });

    test('THE SNAPSHOT LANDS BEFORE THE SIDECAR', () async {
      // Load-bearing: "a sidecar exists" is this store's promise that its
      // snapshot is complete. Writing the sidecar first would make that
      // promise before it was true, and a crash in between would offer
      // the user a truncated project.
      final made = _make();
      await made.store.write(
        sidecar: _sidecar('doc-1'),
        documentBytes: _doc(64),
      );

      final snapshotAt = made.fs.journal.indexWhere(
        (op) => op is Renamed && op.to == r'C:\data\recovery\doc-1.rmpj',
      );
      final sidecarAt = made.fs.journal.indexWhere(
        (op) => op is Renamed && op.to == r'C:\data\recovery\doc-1.json',
      );

      expect(snapshotAt, greaterThanOrEqualTo(0));
      expect(sidecarAt, greaterThan(snapshotAt));
    });

    test('at every prefix, a sidecar present implies a COMPLETE '
        'snapshot', () async {
      final made = _make();
      final document = _doc(64);
      await made.store.write(
        sidecar: _sidecar('doc-1'),
        documentBytes: document,
      );

      for (var k = 0; k <= made.fs.journal.length; k++) {
        final state = made.fs.replayPrefix(k);
        final sidecar = state.files[r'C:\data\recovery\doc-1.json'];
        if (sidecar is Bytes && sidecar.value.isNotEmpty) {
          final snapshot = state.files[r'C:\data\recovery\doc-1.rmpj'];
          expect(
            snapshot,
            isA<Bytes>(),
            reason:
                'prefix $k: a sidecar is on disk but its snapshot is '
                '$snapshot — the startup scan would offer half a file',
          );
          // COMPLETE means "these bytes", not "this many bytes".
          expect(
            (snapshot! as Bytes).value,
            orderedEquals(document),
            reason: 'prefix $k: the snapshot is not the document',
          );
        }
      }
    });

    test("a recovery snapshot NEVER writes to the user's file", () async {
      // The one rule that outranks everything else in this store. CAD
      // users expect explicit saves and will file a bug the first time an
      // autosave clobbers something.
      final made = _make(
        files: {r'C:\jobs\Smith.rmpj': _doc(8)},
        dirs: {r'C:\jobs'},
      );
      await made.store.write(
        sidecar: _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj'),
        documentBytes: _doc(999),
      );

      expect(
        (made.fs.state.files[r'C:\jobs\Smith.rmpj']! as Bytes).value,
        orderedEquals(_doc(8)),
        reason: "the user's file must be byte-for-byte untouched",
      );
      for (final op in made.fs.journal) {
        final touched = switch (op) {
          SinkOpen(:final path) => path,
          Renamed(:final to) => to,
          CopyEnd(:final to) => to,
          WriteEnd(:final path) => path,
          Deleted(:final path) => path,
          _ => null,
        };
        expect(
          touched,
          isNot(startsWith(r'C:\jobs')),
          reason: 'op $op reached outside the recovery directory',
        );
      }
    });

    group('no .bak is produced — a backup of a backup is pure footprint', () {
      // `AtomicWriter` only runs step 4 when `keepBackup && targetExisted`.
      // A fixture whose target does not pre-exist therefore CANNOT observe
      // the flag: the old single test wrote once into an empty filesystem,
      // so flipping both `keepBackup: false` arguments in
      // `RecoveryStore.write` to `true` left it green while the recovery
      // directory silently doubled in size on every autosave after the
      // first. Each test below arranges the one state in which one
      // specific `keepBackup: false` becomes observable.

      test('the SNAPSHOT write: a second autosave overwrites an existing '
          'snapshot', () async {
        final made = _make();
        await made.store.write(
          sidecar: _sidecar('doc-1'),
          documentBytes: _doc(64),
        );
        // The target now exists, so step 4 would run if the flag said so.
        await made.store.write(
          sidecar: _sidecar('doc-1', minute: 30),
          documentBytes: _doc(96),
        );

        expect(
          made.fs.state.files.keys.where((f) => f.endsWith('.bak')),
          isEmpty,
          reason:
              'a .bak of a 600 KB snapshot, refreshed every 30 seconds, '
              'is the recovery directory at double size for nothing',
        );
        expect(
          made.fs.state.files.keys.toSet(),
          {
            r'C:\data\recovery\doc-1.rmpj',
            r'C:\data\recovery\doc-1.json',
          },
          reason: 'exactly the pair, and nothing else',
        );
      });

      test('the SIDECAR write: the retire failed, so its target is still '
          'there', () async {
        // Step 0 retires the previous sidecar BEFORE the snapshot moves,
        // and that delete is best-effort — so the only state in which the
        // sidecar write meets an existing target is the one where the
        // retire failed. An antivirus handle on a 400-byte JSON file is
        // exactly how that happens.
        const sidecarPath = r'C:\data\recovery\doc-1.json';
        final fs = FakeFileStore(
          initialDirectories: const {'C:', _dataRoot, _recoveryDir},
          undeletablePaths: const {sidecarPath},
        );
        final store = _storeOver(fs, sessionId: 'session-A');

        await store.write(sidecar: _sidecar('doc-1'), documentBytes: _doc(64));
        await store.write(
          sidecar: _sidecar('doc-1', minute: 30),
          documentBytes: _doc(96),
        );

        expect(
          fs.state.files.containsKey(sidecarPath),
          isTrue,
          reason: 'the premise: the retire really did fail',
        );
        expect(
          fs.state.files.keys.where((f) => f.endsWith('.bak')),
          isEmpty,
        );
      });

      test("the CLAIM write: scan() rewrites another session's sidecar in "
          'place', () async {
        final made = _make(dirs: {_recoveryDir});
        final crashed = _storeOver(made.fs, sessionId: 'session-that-died');
        await crashed.write(
          sidecar: _sidecar('doc-1'),
          documentBytes: _doc(64),
        );

        await made.store.scan();

        expect(
          made.fs.state.files.keys.where((f) => f.endsWith('.bak')),
          isEmpty,
          reason:
              'claiming rewrites the sidecar over itself; a .bak of it '
              'would be an orphan nothing ever reads or removes',
        );
      });
    });

    group('A NEW SNAPSHOT IS NEVER LEFT WEARING AN OLD LABEL', () {
      // The sequence: autosave #1 writes S1 + C1 (10:00, 3 unsaved edits,
      // realPath A). Autosave #2 promotes S2 (11:00, 47 edits) over S1
      // successfully — and THEN the sidecar write fails: disk full after
      // the 600 KB snapshot took the last space, an AV lock, a permission
      // change. Nothing rolls S2 back.
      //
      // With the old ordering the disk held S2 + C1, which `scan()` reads
      // as a healthy matched pair. The user is offered "Recover Smith
      // (3 unsaved changes) from 10:00" for bytes that are 47 edits from
      // 11:00, and may reasonably discard it as stale. If a Save As
      // happened between the two, C1's realPath points at the OLD file —
      // so recovering binds the new document's bytes to the old path and
      // the next Ctrl+S overwrites a different project.

      /// The first autosave's pair, as a seed for a fresh store — so the
      /// SECOND write's operation indices start at 0 and the fault sweep
      /// is arithmetic-free.
      Future<Map<String, Uint8List>> afterFirstAutosave() async {
        final made = _make();
        await made.store.write(
          sidecar: _sidecar(
            'doc-1',
            realPath: r'C:\jobs\A.rmpj',
            unsavedEditCount: 3,
          ),
          documentBytes: _doc(64),
        );
        return {
          for (final e in made.fs.state.files.entries)
            if (e.value case Bytes(:final value)) e.key: value,
        };
      }

      ({RecoveryStore store, FakeFileStore fs}) secondAutosaveStore(
        Map<String, Uint8List> seed, {
        Map<int, Object> faults = const {},
      }) {
        final fs = FakeFileStore(
          initialFiles: seed,
          initialDirectories: const {'C:', _dataRoot, _recoveryDir},
          faults: faults,
        );
        return (
          store: RecoveryStore(
            fs: fs,
            writer: AtomicWriter(
              fs: fs,
              queue: SaveQueue(),
              context: _windows,
              delay: (_) async {},
            ),
            dataRoot: _dataRoot,
            context: _windows,
          ),
          fs: fs,
        );
      }

      Future<void> writeSecondAutosave(RecoveryStore store) => store.write(
        sidecar: _sidecar(
          'doc-1',
          realPath: r'C:\jobs\B.rmpj',
          unsavedEditCount: 47,
          minute: 60,
        ),
        documentBytes: _doc(96),
      );

      test('a failure ANYWHERE in the second write leaves an orphan, '
          'never a mis-attributed pair', () async {
        final seed = await afterFirstAutosave();

        final probe = secondAutosaveStore(seed);
        await writeSecondAutosave(probe.store);
        final operationCount = probe.fs.operationCount;
        expect(operationCount, greaterThan(4));

        for (var k = 0; k < operationCount; k++) {
          final made = secondAutosaveStore(
            seed,
            // Disk full — the concrete case: the 600 KB snapshot took the
            // last of the space and the sidecar has nowhere to go.
            faults: {k: const StorageOsException(112)},
          );
          await writeSecondAutosave(made.store);

          for (final survivor in (await made.store.scan()).survivors) {
            final bytes = await made.store.readSnapshot(survivor);
            // 47 edits at 11:00 for B describes the SECOND document; 3
            // edits at 10:00 for A describes the first. Any other
            // combination is the bug. Compared as BYTES, not as lengths:
            // the two documents here differ in content as well as size,
            // and a sidecar attached to the wrong bytes is the whole
            // subject of this group.
            final expected = survivor.sidecar.unsavedEditCount == 47
                ? _doc(96)
                : _doc(64);
            expect(
              bytes,
              orderedEquals(expected),
              reason:
                  'fault at op $k: the startup prompt would offer a '
                  '${bytes.length}-byte snapshot described as '
                  '${survivor.sidecar.unsavedEditCount} unsaved changes at '
                  '${survivor.sidecar.savedAt}, bound to '
                  '${survivor.sidecar.realPath} — and the next Ctrl+S '
                  'writes those bytes over THAT path',
            );
          }
        }
      });

      test(
        'the previous sidecar is retired BEFORE the snapshot moves',
        () async {
          // The direct ordering assertion, so the property above cannot be
          // satisfied by luck.
          final seed = await afterFirstAutosave();
          final made = secondAutosaveStore(seed);
          await writeSecondAutosave(made.store);

          final sidecarRetired = made.fs.journal.indexWhere(
            (op) => op is Deleted && op.path == r'C:\data\recovery\doc-1.json',
          );
          final snapshotPromoted = made.fs.journal.indexWhere(
            (op) => op is Renamed && op.to == r'C:\data\recovery\doc-1.rmpj',
          );

          expect(
            sidecarRetired,
            greaterThanOrEqualTo(0),
            reason:
                'the old sidecar describes bytes the promote below is about '
                'to destroy, so it is a lie from that instant on',
          );
          expect(snapshotPromoted, greaterThan(sidecarRetired));
        },
      );

      test(
        'a clean second write still ends with a matched, CURRENT pair',
        () async {
          // Guards the guard: retiring the sidecar must not have turned the
          // happy path into a permanent orphan.
          final seed = await afterFirstAutosave();
          final made = secondAutosaveStore(seed);
          await writeSecondAutosave(made.store);

          final scan = await made.store.scan();
          expect(scan.survivors, hasLength(1));
          expect(scan.orphanedSnapshots, 0);
          expect(scan.orphanedSidecars, 0);
          expect(scan.survivors.single.sidecar.unsavedEditCount, 47);
          expect(scan.survivors.single.sidecar.realPath, r'C:\jobs\B.rmpj');
          expect(
            await made.store.readSnapshot(scan.survivors.single),
            orderedEquals(_doc(96)),
            reason: "the SECOND autosave's document, not the first",
          );
        },
      );
    });
  });

  group('a snapshot written before DR-015 (#170)', () {
    // ── THE ONE WINDOW THIS FEATURE EXISTS FOR IS THE ONE THE RENAME
    //    BREAKS ────────────────────────────────────────────────────
    // A recovery pair is only on disk across a crash. So a `.rackmate`
    // snapshot meets a `.rmpj` build in exactly one situation: the user's
    // previous build died with unsaved work and they installed this one
    // before reopening. Recognise only the current spelling and the
    // sidecar becomes an orphan — which `scan` deletes SILENTLY, taking
    // the crash recovery with it and saying nothing.
    ({RecoveryStore store, FakeFileStore fs}) legacyPair() => _make(
      files: {
        r'C:\data\recovery\doc-1.rackmate': _doc(64),
        r'C:\data\recovery\doc-1.json': Uint8List.fromList(
          utf8.encode(jsonEncode(_sidecar('doc-1').toJson())),
        ),
      },
      dirs: {_recoveryDir},
    );

    test('is offered, and offered with the path it ACTUALLY has', () async {
      final made = legacyPair();
      final scan = await made.store.scan();
      expect(
        scan.survivors,
        hasLength(1),
        reason:
            'a crash survivor written by the previous build was '
            'dropped by the build the user upgraded to',
      );
      expect(
        scan.survivors.single.snapshotPath,
        r'C:\data\recovery\doc-1.rackmate',
        reason:
            'the path was REBUILT from the current extension, so '
            'Recover would read a file that is not there',
      );
      // And its bytes are reachable, which the path alone does not prove.
      expect(
        await made.store.readSnapshot(scan.survivors.single),
        isNotNull,
      );
    });

    test('and DISCARD really removes it, so the prompt stops', () async {
      // `delete` rebuilding the name would leave the pair half-deleted:
      // sidecar gone, snapshot behind. The next launch sees an orphaned
      // snapshot and sweeps it, so the user is not re-prompted forever —
      // but the failure is still a Discard that did not discard, and the
      // sweep only tidies because the sidecar happened to go first.
      final made = legacyPair();
      await made.store.delete('doc-1');
      expect(
        made.fs.state.files.keys.where((k) => k.contains('doc-1')),
        isEmpty,
        reason: 'Discard left part of the pair on disk',
      );
    });
  });

  group('delete', () {
    test('THE SIDECAR GOES FIRST', () async {
      // Reversed, an interrupted delete would leave an orphaned SIDECAR
      // pointing at nothing — the same shape a half-finished WRITE has,
      // indistinguishable, and one of those two deserves to be offered.
      final made = _make(
        files: {
          r'C:\data\recovery\doc-1.rmpj': _doc(64),
          r'C:\data\recovery\doc-1.json': Uint8List.fromList(
            utf8.encode(jsonEncode(_sidecar('doc-1').toJson())),
          ),
        },
        dirs: {_recoveryDir},
      );
      await made.store.delete('doc-1');

      final deletes = made.fs.journal.whereType<Deleted>().toList();
      expect(deletes.map((d) => d.path), [
        r'C:\data\recovery\doc-1.json',
        r'C:\data\recovery\doc-1.rmpj',
      ]);
    });

    test('deleting a document with no snapshot NEVER CALLS delete at '
        'all', () async {
      // The journal alone cannot see this. `FakeFileStore.exists` does not
      // journal, and `delete` on a missing path throws errno 2 which
      // `_deleteIfPresent` swallows without journalling — so an empty
      // journal is equally consistent with the existence guard being
      // present and with it having been deleted. The two differ only in
      // whether the call was MADE, which is what `fs.calls` records.
      //
      // file_store_contract_test.dart exists in part to establish the
      // premise: 'deleting a missing file throws — so "delete if present"
      // must check first'. This is the assertion that the check is there.
      final made = _make(dirs: {_recoveryDir});

      await made.store.delete('never-snapshotted');

      expect(
        made.fs.calls,
        isNot(contains('delete')),
        reason:
            'the guard is gone: `delete` was invoked on a path that was '
            'not there, and only the unconditional catch hid it. Narrow '
            'that catch and this becomes a thrown exception on every '
            'clean shutdown of a never-snapshotted document.',
      );
      expect(
        made.fs.calls.where((c) => c == 'exists'),
        hasLength(1 + kSnapshotExtensions.length),
        reason:
            'one existence check for the sidecar and one for each '
            'spelling a snapshot may have (DR-015), and no delete',
      );
      expect(made.fs.journal, isEmpty);
    });

    group("A SAVE IN ONE INSTANCE MUST NOT DELETE ANOTHER'S SAFETY NET", () {
      // Nothing in this product prevents a second instance — there is no
      // single-instance mutex in apps/rackmate/lib or in the Windows
      // runner — and the recovery directory is shared state keyed on
      // document id that nothing arbitrates. `SaveQueue`'s single-flight
      // guarantee is a per-PROCESS object and does not span processes.

      test("instance A's save leaves instance B's pair alone", () async {
        final made = _make(dirs: {_recoveryDir});
        final b = _storeOver(made.fs, sessionId: 'session-B');

        // B has twenty minutes of unsaved work behind a snapshot.
        await b.write(
          sidecar: _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj'),
          documentBytes: _doc(600),
        );

        // A saves Smith.rmpj — a save with nothing to do with B — and
        // step 7 asks the recovery store to retire the snapshot.
        await made.store.delete('doc-1');

        expect(
          made.fs.state.files.containsKey(r'C:\data\recovery\doc-1.rmpj'),
          isTrue,
          reason:
              "twenty minutes of B's work, with no safety net at all and "
              'nothing anywhere saying so',
        );
        expect(
          made.fs.state.files.containsKey(r'C:\data\recovery\doc-1.json'),
          isTrue,
        );
      });

      test('...and the same holds for a clean shutdown', () async {
        // `SessionController.cleanShutdown` calls the identical method.
        final made = _make(dirs: {_recoveryDir});
        final b = _storeOver(made.fs, sessionId: 'session-B');
        await b.write(sidecar: _sidecar('doc-1'), documentBytes: _doc(600));

        await made.store.delete('doc-1');

        expect((await b.scan()).survivors, hasLength(1));
      });

      test('a store still deletes its OWN pair', () async {
        // Guards the guard: the ordinary step-7 cleanup must still work,
        // or every save leaves a stale snapshot behind and the startup
        // prompt fires on work that was saved perfectly.
        final made = _make(dirs: {_recoveryDir});
        await made.store.write(
          sidecar: _sidecar('doc-1'),
          documentBytes: _doc(64),
        );

        await made.store.delete('doc-1');

        expect(
          made.fs.state.files.keys.where((f) => f.contains('doc-1')),
          isEmpty,
        );
      });

      test('an UNOWNED pair — written by a build with no owner field — is '
          'deletable', () async {
        // The upgrade path. Refusing to delete a pair that predates the
        // field would leave a snapshot that nothing can ever clear, and
        // the startup prompt would fire forever.
        final made = _make(
          files: {
            r'C:\data\recovery\doc-1.rmpj': _doc(64),
            r'C:\data\recovery\doc-1.json': Uint8List.fromList(
              utf8.encode(
                jsonEncode(
                  _sidecar('doc-1').toJson()..remove('owner'),
                ),
              ),
            ),
          },
          dirs: {_recoveryDir},
        );

        await made.store.delete('doc-1');

        expect(
          made.fs.state.files.keys.where((f) => f.contains('doc-1')),
          isEmpty,
        );
      });

      test("the user's Discard still works on another session's pair, "
          'because scan CLAIMS what it offers', () async {
        // The pair a crashed session left behind is owned by a session id
        // that will never run again. If the ownership guard applied to it
        // blindly, "Discard" would silently do nothing and the same
        // prompt would return at every launch, forever.
        final made = _make(dirs: {_recoveryDir});
        final crashed = _storeOver(made.fs, sessionId: 'session-that-died');
        await crashed.write(
          sidecar: _sidecar('doc-1'),
          documentBytes: _doc(64),
        );

        final scan = await made.store.scan();
        expect(scan.survivors, hasLength(1));
        expect(scan.survivors.single.sidecar.owner, 'session-A');
        expect(
          scan.survivors.single.sidecar.unsavedEditCount,
          12,
          reason: 'claiming must not disturb anything the prompt displays',
        );

        await made.store.delete(scan.survivors.single.sidecar.docId);

        expect(
          made.fs.state.files.keys.where((f) => f.contains('doc-1')),
          isEmpty,
        );
      });

      test('claiming is a no-op when the pair is already ours', () async {
        final made = _make(dirs: {_recoveryDir});
        await made.store.write(
          sidecar: _sidecar('doc-1'),
          documentBytes: _doc(64),
        );
        made.fs.resetJournal();

        await made.store.scan();

        expect(
          made.fs.journal.whereType<Renamed>(),
          isEmpty,
          reason: 'a scan of our own pair must not rewrite anything',
        );
      });
    });
  });

  group('scan', () {
    test('an absent recovery directory yields nothing and does not '
        'throw', () async {
      final made = _make();
      final result = await made.store.scan();
      expect(result.survivors, isEmpty);
    });

    test('a complete pair is a survivor with its sidecar intact', () async {
      final made = _make(dirs: {_recoveryDir});
      await made.store.write(
        sidecar: _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj'),
        documentBytes: _doc(64),
      );

      final result = await made.store.scan();
      expect(result.survivors, hasLength(1));
      final survivor = result.survivors.single;
      expect(survivor.sidecar.displayName, 'Smith Residence');
      expect(survivor.sidecar.realPath, r'C:\jobs\Smith.rmpj');
      expect(survivor.sidecar.unsavedEditCount, 12);
      expect(await made.store.readSnapshot(survivor), orderedEquals(_doc(64)));
    });

    test('a SNAPSHOT WITH NO SIDECAR is deleted silently', () async {
      // An interrupted write. It is our file, in our directory, and by
      // construction either incomplete or unattributable, so there is
      // nothing to ask the user about.
      final made = _make(
        files: {r'C:\data\recovery\orphan.rmpj': _doc(64)},
        dirs: {_recoveryDir},
      );

      final result = await made.store.scan();
      expect(result.survivors, isEmpty);
      expect(result.orphanedSnapshots, 1);
      expect(
        made.fs.state.files.containsKey(r'C:\data\recovery\orphan.rmpj'),
        isFalse,
      );
    });

    test('a SIDECAR WITH NO SNAPSHOT is deleted silently', () async {
      final made = _make(
        files: {
          r'C:\data\recovery\orphan.json': Uint8List.fromList(
            utf8.encode(jsonEncode(_sidecar('orphan').toJson())),
          ),
        },
        dirs: {_recoveryDir},
      );

      final result = await made.store.scan();
      expect(result.survivors, isEmpty);
      expect(result.orphanedSidecars, 1);
      expect(
        made.fs.state.files.containsKey(r'C:\data\recovery\orphan.json'),
        isFalse,
      );
    });

    test('an UNPARSEABLE sidecar takes its snapshot with it', () async {
      // A sidecar that cannot name a document or a time cannot honestly
      // describe its snapshot, so the pair cannot be offered.
      final made = _make(
        files: {
          r'C:\data\recovery\bad.rmpj': _doc(64),
          r'C:\data\recovery\bad.json': Uint8List.fromList(
            utf8.encode('{ not json'),
          ),
        },
        dirs: {_recoveryDir},
      );

      final result = await made.store.scan();
      expect(result.survivors, isEmpty);
      expect(made.fs.state.files, isEmpty);
    });

    test('multiple survivors come back NEWEST FIRST', () async {
      // Possible after two consecutive crashes, even though v1 is
      // single-document. The prompt offers them one at a time, newest
      // first.
      final made = _make(dirs: {_recoveryDir});
      await made.store.write(
        sidecar: _sidecar('older', displayName: 'Older'),
        documentBytes: _doc(8),
      );
      await made.store.write(
        sidecar: _sidecar('newer', displayName: 'Newer', minute: 30),
        documentBytes: _doc(8),
      );

      final result = await made.store.scan();
      expect(
        result.survivors.map((s) => s.sidecar.displayName),
        ['Newer', 'Older'],
      );
    });

    test('files that are not ours are left strictly alone', () async {
      final made = _make(
        files: {r'C:\data\recovery\README.txt': _doc(4)},
        dirs: {_recoveryDir},
      );
      final result = await made.store.scan();
      expect(result.survivors, isEmpty);
      expect(
        made.fs.state.files.containsKey(r'C:\data\recovery\README.txt'),
        isTrue,
      );
    });
  });

  // ======================================================================
  // A LIVE INSTANCE'S PAIR IS NOT A CRASH SURVIVOR
  // ======================================================================
  // The two-instance loss, reached through the SCAN rather than through
  // `delete`. Instance B is running with unsaved work behind a live
  // snapshot; instance C launches and its startup scan used to claim that
  // pair — rewriting the sidecar's owner to C — and offer it. Two things
  // then went wrong at once: RackMate described work being edited in
  // another window right now as a crash survivor, and the user's
  // "Discard" — an entirely reasonable answer to that prompt — deleted a
  // RUNNING instance's only safety net.
  group('a RUNNING instance’s pair', () {
    /// Instance B: a second store over the same disk that has announced
    /// itself alive and has NOT died. Its lease is held for the rest of
    /// the test, which is what a running process does.
    Future<RecoveryStore> liveInstance(
      FakeFileStore fs, {
      String sessionId = 'sess-B',
    }) async {
      final b = _storeOver(fs, sessionId: sessionId);
      await b.beginSession();
      return b;
    }

    test('is NOT offered — live in-flight work is not a crash '
        'survivor', () async {
      final made = _make(dirs: {_recoveryDir});
      final b = await liveInstance(made.fs);
      await b.write(
        sidecar: _sidecar('shared-doc~sess-B'),
        documentBytes: _doc(64),
      );

      final scan = await made.store.scan();

      expect(
        scan.survivors,
        isEmpty,
        reason:
            'offering it describes a document that is open and being '
            'edited in another live window as a crash survivor',
      );
      expect(scan.skippedLive, greaterThan(0));
    });

    test('is not CLAIMED either, so its owner can still retire it', () async {
      // The MEDIUM this scenario used to cause on the way past. Once C had
      // rewritten the sidecar's owner, B's own step-7 save and its clean
      // shutdown both hit the ownership guard and declined — so a later
      // launch offered a recovery prompt for work that had been saved
      // perfectly.
      final made = _make(dirs: {_recoveryDir});
      final b = await liveInstance(made.fs);
      await b.write(
        sidecar: _sidecar('shared-doc~sess-B'),
        documentBytes: _doc(64),
      );

      await made.store.scan();

      await b.delete('shared-doc~sess-B');
      expect(
        made.fs.state.files.keys.where((f) => f.contains('shared-doc')),
        isEmpty,
        reason:
            "B's own save and clean shutdown must still be able to "
            'retire the pair B wrote',
      );
    });

    test('...and even if the owner field HAD been rewritten, the SLOT is '
        'still proof of who wrote it', () async {
      // Belt and braces, and it is the narrower, truer rule: a sidecar's
      // `owner` is rewritable by anybody, but `<docId>~<sessionId>` is the
      // file name and nobody can rewrite it.
      final made = _make(dirs: {_recoveryDir});
      final b = _storeOver(made.fs, sessionId: 'sess-B');
      await b.write(
        sidecar: _sidecar('shared-doc~sess-B'),
        documentBytes: _doc(64),
      );
      // A concurrent launch that got there first, before the lease existed
      // — or one whose liveness probe could not answer.
      final c = _storeOver(made.fs, sessionId: 'sess-C');
      await c.scan();

      await b.delete('shared-doc~sess-B');

      expect(
        made.fs.state.files.keys.where((f) => f.contains('shared-doc')),
        isEmpty,
      );
    });

    test('its SNAPSHOT is not swept as an orphan mid-write', () async {
      // `write` retires the previous sidecar BEFORE it moves the snapshot,
      // so a live instance in the middle of a snapshot looks from outside
      // exactly like an interrupted write. A concurrent launch used to
      // delete it and call that housekeeping.
      final made = _make(
        files: {r'C:\data\recovery\shared-doc~sess-B.rmpj': _doc(64)},
        dirs: {_recoveryDir},
      );
      await liveInstance(made.fs);

      final scan = await made.store.scan();

      expect(scan.orphanedSnapshots, 0);
      expect(
        made.fs.state.files.containsKey(
          r'C:\data\recovery\shared-doc~sess-B.rmpj',
        ),
        isTrue,
      );
    });

    test('a crashed run that left no pair still has its lease swept', () async {
      // Nothing else would ever ask about that session: it crashed with a
      // clean document, so there is no snapshot, no sidecar and no stray
      // naming it. Without this sweep the sessions directory grows by one
      // file per crash for the life of the installation.
      // NO RECOVERY DIRECTORY. That is the case this is really about: an
      // installation that has never crashed with unsaved work has no
      // `recovery/` at all, so a sweep placed after `scan`'s early return
      // would never run and the leases would pile up forever. Measured on
      // a real build before it was moved.
      final made = _make();
      await liveInstance(made.fs, sessionId: 'sess-gone');
      await liveInstance(made.fs, sessionId: 'sess-still-here');

      // ONE of the two processes dies. Its lease is dropped by the kernel;
      // the FILE it wrote stays, exactly as after a crash.
      made.fs.releaseLease(r'C:\data\sessions\sess-gone.lease');

      await made.store.scan();

      expect(
        made.fs.state.files.containsKey(r'C:\data\sessions\sess-gone.lease'),
        isFalse,
      );
      expect(
        made.fs.state.files.containsKey(
          r'C:\data\sessions\sess-still-here.lease',
        ),
        isTrue,
        reason: 'a RUNNING instance’s lease is what makes it visible',
      );
    });

    test('but ONCE THAT INSTANCE IS GONE the same pair is offered', () async {
      // The other half, and the reason this cannot be a timing heuristic:
      // a user who crashed and relaunched five seconds later must still be
      // offered their work. The lease answers from the kernel, so "gone"
      // is a fact and not an estimate — there is no window at all.
      final made = _make(dirs: {_recoveryDir});
      final b = await liveInstance(made.fs);
      await b.write(
        sidecar: _sidecar('shared-doc~sess-B'),
        documentBytes: _doc(64),
      );
      expect((await made.store.scan()).survivors, isEmpty);

      // B's process ends. The kernel drops its lease; the lease FILE it
      // wrote is still there, exactly as after a crash.
      made.fs.releaseAllLeases();

      final scan = await made.store.scan();
      expect(scan.survivors, hasLength(1));
      expect(scan.survivors.single.sidecar.owner, 'session-A');
      expect(
        made.fs.state.files.containsKey(r'C:\data\sessions\sess-B.lease'),
        isFalse,
        reason: 'a dead session’s lease file is litter and is swept',
      );
    });
  });

  // ======================================================================
  // INTERRUPTED-WRITE STRAYS
  // ======================================================================
  // Nothing else sweeps these. `AtomicWriter` removes only the temps of
  // the write it is performing, and once a pair is keyed on
  // `<docId>~<sessionId>` a dead session's paths are never written again —
  // so every crash during a snapshot write left up to ~600 KB of partial
  // document in the data root permanently, which in portable mode is the
  // user's USB stick.
  group('.tmp strays in the recovery directory', () {
    test('a dead session’s interrupted write is swept', () async {
      final made = _make(
        files: {
          r'C:\data\recovery\dead-doc~sess-dead.rmpj.tmp': _doc(600),
          r'C:\data\recovery\dead-doc~sess-dead.json.tmp': _doc(40),
        },
        dirs: {_recoveryDir},
      );

      final scan = await made.store.scan();

      expect(scan.sweptStrays, 2);
      expect(
        made.fs.state.files.keys.where((f) => f.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('a stray is NOT mistaken for a snapshot or a sidecar', () async {
      // `<slot>.rmpj.tmp` classified as a snapshot would be counted as
      // an orphan and would drag its real pair's bookkeeping with it.
      final made = _make(
        files: {r'C:\data\recovery\dead~sess-dead.rmpj.tmp': _doc(8)},
        dirs: {_recoveryDir},
      );

      final scan = await made.store.scan();

      expect(scan.orphanedSnapshots, 0);
      expect(scan.orphanedSidecars, 0);
      expect(scan.sweptStrays, 1);
    });

    test('a LIVE instance’s in-flight tmp is left alone', () async {
      final made = _make(
        files: {r'C:\data\recovery\shared~sess-B.rmpj.tmp': _doc(600)},
        dirs: {_recoveryDir},
      );
      final b = _storeOver(made.fs, sessionId: 'sess-B');
      await b.beginSession();

      final scan = await made.store.scan();

      expect(scan.sweptStrays, 0);
      expect(
        made.fs.state.files.containsKey(
          r'C:\data\recovery\shared~sess-B.rmpj.tmp',
        ),
        isTrue,
        reason:
            'those bytes are a write that is happening right now, in '
            'another process',
      );
    });

    test('anything that is not a .tmp is still left strictly alone', () async {
      final made = _make(
        files: {r'C:\data\recovery\README.txt': _doc(4)},
        dirs: {_recoveryDir},
      );

      final scan = await made.store.scan();

      expect(scan.sweptStrays, 0);
      expect(
        made.fs.state.files.containsKey(r'C:\data\recovery\README.txt'),
        isTrue,
      );
    });
  });

  group('the sidecar carries what the prompt actually needs', () {
    test('round-trips through JSON', () {
      final original = _sidecar('doc-1', realPath: r'C:\jobs\Smith.rmpj');
      final parsed = RecoverySidecar.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(parsed, isNotNull);
      expect(parsed!.docId, 'doc-1');
      expect(parsed.realPath, r'C:\jobs\Smith.rmpj');
      expect(parsed.displayName, 'Smith Residence');
      expect(parsed.sequence, 412);
      expect(parsed.unsavedEditCount, 12);
      expect(parsed.savedAt, _at);
      expect(parsed.schemaVersion, kSchemaVersion);
    });

    test('realPath is ABSENT — never null — for a never-saved '
        'document', () {
      final json = _sidecar('doc-1').toJson();
      expect(
        json.containsKey('realPath'),
        isFalse,
        reason:
            'absent-key-not-null, the same rule the document format '
            'follows',
      );
      expect(RecoverySidecar.fromJson(json)!.realPath, isNull);
    });

    test('unsavedEditCount is OMITTED when unknown, so the prompt omits '
        'the number rather than guessing (G4)', () {
      final json = _sidecar('doc-1', unsavedEditCount: null).toJson();
      expect(json.containsKey('unsavedEditCount'), isFalse);
      expect(RecoverySidecar.fromJson(json)!.unsavedEditCount, isNull);
    });

    test('a sidecar missing a required field parses to null, not to a '
        'half-built object', () {
      expect(RecoverySidecar.fromJson(<String, Object?>{}), isNull);
      expect(
        RecoverySidecar.fromJson(<String, Object?>{'docId': 'x'}),
        isNull,
      );
      expect(
        RecoverySidecar.fromJson(<String, Object?>{
          'docId': 'x',
          'displayName': 'y',
          'savedAt': 'not a date',
        }),
        isNull,
      );
      expect(RecoverySidecar.fromJson('a string'), isNull);
    });
  });

  group('CR-096 — the store exposes no bulk-read or bundle method', () {
    // ==================================================================
    // WHAT WAS HERE BEFORE COULD NOT FAIL.
    // ==================================================================
    // `expect(made.store.scan, isNotNull); expect(made.store.readSnapshot,
    // isNotNull);` — a tear-off of an instance method on a non-null
    // receiver is never null, so both assertions were tautologies and the
    // body checked nothing about the ABSENCE of anything. Adding
    //
    //   Future<List<Uint8List>> readAll() async =>
    //       [for (final s in (await scan()).survivors) await readSnapshot(s)];
    //
    // to `RecoveryStore` broke the exact structural guarantee the test
    // named — that a future diagnostics path cannot reach a complete
    // project containing the client's name and site address — and the test
    // stayed green.
    //
    // Absence is not observable from Dart at runtime (there is no mirror
    // in a Flutter test), so it is asserted where it IS observable: the
    // source. The public API surface of the three types that can carry a
    // recovery file is INVENTORIED and pinned. Adding any public member to
    // any of them fails here, which is the point — it forces whoever adds
    // it to read this comment first.
    //
    // The grep half of the guarantee — that the recovery DIRECTORY is
    // named in exactly one file — is RULE 3 in storage_layering_test.dart.

    final source = File(
      'lib/src/storage/recovery_store.dart',
    ).readAsStringSync();

    test('RecoveryStore has exactly these public members', () {
      expect(
        publicMembersOf(source, 'RecoveryStore'),
        unorderedEquals({
          // Collaborators and the resolved paths.
          'fs', 'writer', 'context', 'sessionId', 'directory',
          'sessionsDirectory',
          'snapshotPathFor', 'sidecarPathFor', 'leasePathFor',
          // FALSE IN THE DEGRADED SESSION, and it REMOVES reach rather
          // than adding any: a disabled store writes nothing at all, so
          // this cannot be the member that grows the surface CR-096
          // narrows. `test/session/degraded_session_test.dart` is where
          // its behaviour is pinned.
          'enabled',
          // The three operations CR-096 permits...
          'write', 'delete', 'scan',
          // ...and the one read, which takes ONE survivor.
          'readSnapshot',
          // The liveness lifecycle. NEITHER OF THESE READS A RECOVERY
          // FILE: `beginSession` takes a lock on an empty file under
          // `<dataRoot>/sessions`, `endSession` gives it back. They are on
          // this class because it is the one that has to tell a crashed
          // session's leftovers from a running instance's live safety net
          // — see the file header's third startup rule.
          'beginSession', 'endSession',
        }),
        reason:
            'A recovery file is a COMPLETE PROJECT containing the client '
            'name and site address. If this list grew, say why in the '
            'file header first — a "collect everything" or "bundle" method '
            'here is one refactor away from a diagnostics attachment.',
      );
    });

    test('readSnapshot takes ONE survivor and returns ONE document', () {
      expect(
        RegExp(
          r'Future<Uint8List>\s+readSnapshot\(\s*RecoverySurvivor\s+\w+\s*\)',
        ).hasMatch(source),
        isTrue,
        reason:
            'the signature is the guarantee: a caller that wants every '
            'snapshot has to write the loop itself, in this file, on '
            'purpose',
      );
    });

    test('nothing scan() hands back carries bytes', () {
      // The other route to a bulk read: leave the API shape alone and put
      // the document into the value `scan` already returns for every
      // survivor. `RecoveryScanResult` would then BE the bundle.
      expect(
        publicMembersOf(source, 'RecoverySurvivor'),
        unorderedEquals({'sidecar', 'snapshotPath'}),
      );
      expect(
        publicMembersOf(source, 'RecoveryScanResult'),
        unorderedEquals({
          'survivors',
          'orphanedSnapshots',
          'orphanedSidecars',
          // Two COUNTS, and counts cannot carry a project. They exist
          // because "the scan found nothing" and "the scan found a running
          // sibling's work and correctly refused to touch it" are
          // different facts, and because the stray sweep must report a
          // number it checked.
          'skippedLive',
          'sweptStrays',
        }),
      );
      expect(
        source,
        isNot(contains('Uint8List> survivors')),
        reason: 'survivors are paths and metadata, never content',
      );
    });

    test('...and the inventory itself can fail', () {
      // GUARDS THE GUARD, and it is the assertion that matters most here:
      // a parser that quietly returned an empty set would make all three
      // tests above vacuous in exactly the way the old ones were. This
      // runs it over a class that HAS the bulk method the finding named.
      const mutant = '''
final class RecoveryStore {
  RecoveryStore({required this.fs});
  final FileStore fs;
  final String _private = 'x';
  String snapshotPathFor(String docId) => context.join(directory, docId);
  Future<Uint8List> readSnapshot(RecoverySurvivor s) => fs.readBytes(s.p);
  Future<List<Uint8List>> readAll() async =>
      [for (final s in (await scan()).survivors) await readSnapshot(s)];
}
''';
      expect(
        publicMembersOf(mutant, 'RecoveryStore'),
        unorderedEquals({'fs', 'snapshotPathFor', 'readSnapshot', 'readAll'}),
        reason:
            'the parser must SEE readAll, or the pinned inventory above '
            'proves nothing',
      );
    });
  });
}

// --- The source inventory ----------------------------------------------

/// Every PUBLIC member declared directly on [className] in [source]:
/// fields, getters and methods. The constructor is excluded (its name is
/// the class name and it declares no API of its own).
///
/// A small brace/paren walker rather than a regex, because a regex over
/// Dart declarations either misses a member or invents one, and a gate
/// that misses a member is a gate that does not exist. It is exercised
/// against a known-bad class by the last test in the group above.
Set<String> publicMembersOf(String source, String className) {
  final body = _classBody(_stripStrings(_stripComments(source)), className);

  final members = <String>[];
  final head = StringBuffer();
  var headClosed = false;
  var depth = 0;
  var paren = 0;

  void flush() {
    final text = head.toString();
    final names = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').allMatches(text);
    if (names.isNotEmpty) members.add(names.last[0]!);
    head.clear();
    headClosed = false;
  }

  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (depth == 0 && paren == 0) {
      // The HEAD is everything before the declaration turns into a
      // parameter list, a body, an initialiser or an initialiser list.
      if (c == '(' || c == '{' || c == '=' || c == ':') {
        headClosed = true;
      } else if (c == ';') {
        flush();
        continue;
      } else if (!headClosed) {
        head.write(c);
      }
    }
    if (c == '(') {
      paren++;
    } else if (c == ')') {
      paren--;
    } else if (paren == 0 && c == '{') {
      depth++;
    } else if (paren == 0 && c == '}') {
      depth--;
      if (depth == 0) flush();
    }
  }

  return {
    for (final name in members)
      if (!name.startsWith('_') && name != className) name,
  };
}

String _classBody(String source, String className) {
  final declaration = RegExp('class\\s+$className\\b').firstMatch(source);
  expect(declaration, isNotNull, reason: 'no class $className in the source');
  final open = source.indexOf('{', declaration!.end);
  expect(open, greaterThan(-1));
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('unbalanced braces in class $className');
}

/// Comments FIRST: they are full of apostrophes ("the caller's decision")
/// and would otherwise open a string literal that never closes.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

/// String literals carry braces and parens that are not structure.
String _stripStrings(String source) => source
    .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
    .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""');
