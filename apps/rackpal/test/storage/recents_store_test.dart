// Recents: the cap, the case-insensitive dedup, and — the part that
// actually matters — the LAZY PRUNING rules.
//
// The headline test is `a hung UNC entry does not block startup`. Its
// fake has a path whose `exists` future NEVER completes, so any code that
// awaits it at startup makes this test TIME OUT rather than fail politely.
// That is the correct signal for a bug measured at 1261 ms per dead entry
// against a 1.2 s cold-start budget.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/recents_store.dart';

import 'atomicity.dart';
import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _recents = r'C:\data\recents.json';

final _at = DateTime.utc(2026, 7, 26, 14);

RecentEntry _entry(String path, {String? name, int minute = 0}) => RecentEntry(
  path: path,
  displayName: name ?? _windows.basenameWithoutExtension(path),
  lastOpened: _at.add(Duration(minutes: minute)),
);

Uint8List _json(Object? value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

({RecentsStore store, FakeFileStore fs}) _make({
  Map<String, Uint8List>? files,
  Set<String> hangingPaths = const {},
  // The probe TIMEOUT is the behaviour under test, not the duration. A
  // 1 ms budget exercises the identical code path in no wall time, so
  // nothing in this suite sleeps for half a second per hung entry.
  Duration probeTimeout = const Duration(milliseconds: 1),
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: const {'C:', _dataRoot},
    hangingPaths: hangingPaths,
  );
  return (
    store: RecentsStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: _dataRoot,
      context: _windows,
      probeTimeout: probeTimeout,
    ),
    fs: fs,
  );
}

void main() {
  group('load', () {
    test('a missing file is an empty list, not an error', () async {
      final made = _make();
      expect(await made.store.load(), isEmpty);
    });

    test('an UNPARSEABLE file is an empty list, not an error', () async {
      // Refusing to start because a convenience list is corrupt would be
      // absurd. It is a warning, and it is logged.
      final made = _make(
        files: {_recents: Uint8List.fromList(utf8.encode('{ not json'))},
      );
      expect(await made.store.load(), isEmpty);
    });

    test('ONE malformed row does not cost the user the other nine', () async {
      final made = _make(
        files: {
          _recents: _json({
            'version': 1,
            'entries': [
              {
                'path': r'C:\a.rmpj',
                'displayName': 'A',
                'lastOpened': _at.toIso8601String(),
              },
              {'displayName': 'no path at all'},
              {
                'path': r'C:\b.rmpj',
                'displayName': 'B',
                'lastOpened': _at.toIso8601String(),
              },
              {
                'path': r'C:\c.rmpj',
                'displayName': 'C',
                'lastOpened': 'not a date',
              },
            ],
          }),
        },
      );
      final loaded = await made.store.load();
      expect(loaded.map((e) => e.displayName), ['A', 'B']);
    });

    test('LOAD PERFORMS NO STAT. None. Ever.', () async {
      // The startup path renders the menu straight from this file. A
      // single `exists` here is 1261 ms per dead network entry.
      final made = _make(
        files: {
          _recents: _json({
            'version': 1,
            'entries': [
              for (var i = 0; i < 10; i++)
                {
                  'path': '\\\\\\\\NAS\\\\jobs\\\\p$i.rmpj',
                  'displayName': 'P$i',
                  'lastOpened': _at.toIso8601String(),
                },
            ],
          }),
        },
      );
      final before = made.fs.operationCount;
      final loaded = await made.store.load();
      expect(loaded, hasLength(10));
      // exists(recents.json) + readBytes(recents.json) and nothing more.
      expect(
        made.fs.operationCount - before,
        2,
        reason: 'load() must touch the recents file and NOTHING else',
      );
    });
  });

  group('push', () {
    test('puts the newest at the top', () async {
      final made = _make();
      await made.store.push(_entry(r'C:\jobs\A.rmpj'));
      final list = await made.store.push(_entry(r'C:\jobs\B.rmpj'));
      expect(list.map((e) => e.path), [
        r'C:\jobs\B.rmpj',
        r'C:\jobs\A.rmpj',
      ]);
    });

    test('deduplicates CASE-INSENSITIVELY on Windows', () async {
      // C:\Jobs and c:\jobs are the same directory there. Showing both
      // would be a bug the user cannot explain.
      final made = _make();
      await made.store.push(_entry(r'C:\Jobs\Smith.rmpj'));
      final list = await made.store.push(
        _entry(r'c:\jobs\smith.RMPJ', name: 'Smith'),
      );
      expect(list, hasLength(1));
      expect(list.single.path, r'c:\jobs\smith.RMPJ');
    });

    test('normalises away . and .. before comparing', () async {
      final made = _make();
      await made.store.push(_entry(r'C:\jobs\Smith.rmpj'));
      final list = await made.store.push(
        _entry(r'C:\jobs\other\..\Smith.rmpj', name: 'Smith'),
      );
      expect(list, hasLength(1));
    });

    test('caps at ten, dropping the oldest', () async {
      final made = _make();
      for (var i = 0; i < 14; i++) {
        await made.store.push(_entry('C:\\jobs\\p$i.rmpj', minute: i));
      }
      final list = await made.store.load();
      expect(list, hasLength(kMaxRecentEntries));
      expect(list.first.path, r'C:\jobs\p13.rmpj');
      expect(list.last.path, r'C:\jobs\p4.rmpj');
    });

    group('the file it writes is atomic', () {
      // The old test asserted only that `recents.json.tmp` and
      // `recents.json.bak` were absent afterwards. A plain
      // `fs.writeBytes(path, bytes)` satisfies both — it never creates a
      // `.tmp` at all — so the AtomicWriter could be removed from
      // `RecentsStore.save` and the suite stayed green while a crash
      // mid-write went from "the previous good list survives" to "the
      // list is truncated JSON". And the `.bak` half could not observe
      // `keepBackup` either: this fixture starts with no recents.json, so
      // `backupAttempted = keepBackup && targetExisted` is false whatever
      // the flag says.

      test('recents.json is never partially written at any instant', () async {
        final made = _make();
        await made.store.push(_entry(r'C:\jobs\A.rmpj'));

        expectAtomicWrite(
          made.fs,
          target: _recents,
          expected: await made.fs.readBytes(_recents),
          what: 'recents.json',
        );
        expectNoWorkingFiles(made.fs, target: _recents);
      });

      test('and neither is the SECOND push, which overwrites it', () async {
        final made = _make();
        await made.store.push(_entry(r'C:\jobs\A.rmpj'));
        final previous = await made.fs.readBytes(_recents);
        // Re-base: the replay below is the second write alone.
        made.fs.resetJournal();

        await made.store.push(_entry(r'C:\jobs\B.rmpj', minute: 5));

        expectAtomicWrite(
          made.fs,
          target: _recents,
          previous: previous,
          expected: await made.fs.readBytes(_recents),
          what: 'recents.json',
        );
      });

      test('NO .bak — and this fixture can actually tell', () async {
        final made = _make();
        await made.store.push(_entry(r'C:\jobs\A.rmpj'));
        // The target exists now, so step 4 would run if the flag allowed
        // it.
        await made.store.push(_entry(r'C:\jobs\B.rmpj', minute: 5));

        expect(
          made.fs.state.files.keys.where((f) => f.endsWith('.bak')),
          isEmpty,
          reason:
              'keepBackup: false — a .bak of a convenience list is pure '
              'footprint, rewritten on every open and every save',
        );
        expect(made.fs.state.files.keys, [_recents]);
      });
    });

    test('the persisted shape is stable and versioned', () async {
      final made = _make();
      await made.store.push(_entry(r'C:\jobs\Smith.rmpj', name: 'Smith'));

      final raw =
          jsonDecode(
                utf8.decode(await made.fs.readBytes(_recents)),
              )!
              as Map<String, Object?>;
      expect(raw['version'], kRecentsFormatVersion);
      final entries = raw['entries']! as List<Object?>;
      final first = entries.single! as Map<String, Object?>;
      expect(first.keys.toList(), [
        'displayName',
        'lastOpened',
        'path',
        // Additive and optional — see the re-anchoring group below. The
        // absolute `path` is unchanged and is still what every reader,
        // including an older build, uses.
        kRecentsRelativeKey,
        kRecentsAnchorVolumeKey,
      ]);
      expect(first['path'], r'C:\jobs\Smith.rmpj');
      expect(first[kRecentsAnchorVolumeKey], r'C:\');
    });
  });

  group('PORTABLE RE-ANCHORING — a stick that changed drive letter', () {
    // The flagship portable workflow keeps the projects ON THE STICK.
    // Absolute entries then die permanently the first time it mounts
    // under a different letter: every row probes unreachable and renders
    // dimmed forever, with no route back. The recents feature is 100%
    // dead in exactly the deliverable portable mode exists for, and it
    // fails quietly enough that nobody reports it.

    ({RecentsStore store, FakeFileStore fs}) storeRootedAt(
      String root, {
      Map<String, Uint8List>? files,
    }) {
      final fs = FakeFileStore(
        initialFiles: files,
        initialDirectories: {'C:', 'E:', 'F:', root},
      );
      return (
        store: RecentsStore(
          fs: fs,
          writer: AtomicWriter(
            fs: fs,
            queue: SaveQueue(),
            context: _windows,
            delay: (_) async {},
          ),
          dataRoot: root,
          context: _windows,
        ),
        fs: fs,
      );
    }

    const onE = r'E:\RackPal\RackPalData';
    const onF = r'F:\RackPal\RackPalData';

    test('an entry on the stick survives the remount', () async {
      final wrote = storeRootedAt(onE);
      await wrote.store.push(_entry(r'E:\Jobs\Smith.rmpj', name: 'Smith'));
      final bytes = await wrote.fs.readBytes(
        _windows.join(onE, kRecentsFileName),
      );

      // The same stick, same file, next machine — where it mounted as F:.
      final read = storeRootedAt(
        onF,
        files: {_windows.join(onF, kRecentsFileName): bytes},
      );
      final loaded = await read.store.load();

      expect(loaded.single.path, r'F:\Jobs\Smith.rmpj');
      expect(loaded.single.displayName, 'Smith');
    });

    test('an entry on the HOST is left absolute — it did not move', () async {
      final wrote = storeRootedAt(onE);
      await wrote.store.push(_entry(r'C:\Users\alice\Smith.rmpj'));
      final bytes = await wrote.fs.readBytes(
        _windows.join(onE, kRecentsFileName),
      );

      final stored =
          (jsonDecode(utf8.decode(bytes))! as Map<String, Object?>)['entries']!
              as List<Object?>;
      expect(
        (stored.single! as Map<String, Object?>).containsKey(
          kRecentsRelativeKey,
        ),
        isFalse,
        reason:
            r'a cross-volume "relative" path is ..\..\.. nonsense '
            'that re-anchors onto the wrong drive',
      );

      final read = storeRootedAt(
        onF,
        files: {_windows.join(onF, kRecentsFileName): bytes},
      );
      expect(
        (await read.store.load()).single.path,
        r'C:\Users\alice\Smith.rmpj',
        reason:
            'a project that lives on some other machine stays exactly as '
            'unreachable as it was — that part was already right',
      );
    });

    test('NOTHING changes when the volume did not change — the installed '
        'build is untouched', () async {
      final wrote = storeRootedAt(onE);
      await wrote.store.push(_entry(r'E:\Jobs\Smith.rmpj'));
      final bytes = await wrote.fs.readBytes(
        _windows.join(onE, kRecentsFileName),
      );

      final read = storeRootedAt(
        onE,
        files: {_windows.join(onE, kRecentsFileName): bytes},
      );
      expect((await read.store.load()).single.path, r'E:\Jobs\Smith.rmpj');
    });

    test('drive-letter case is not a move', () async {
      final wrote = storeRootedAt(onE);
      await wrote.store.push(_entry(r'E:\Jobs\Smith.rmpj'));
      final bytes = await wrote.fs.readBytes(
        _windows.join(onE, kRecentsFileName),
      );

      final read = storeRootedAt(
        r'e:\RackPal\RackPalData',
        files: {
          _windows.join(r'e:\RackPal\RackPalData', kRecentsFileName): bytes,
        },
      );
      expect(
        (await read.store.load()).single.path,
        r'E:\Jobs\Smith.rmpj',
        reason: r'E:\ and e:\ are one drive on Windows',
      );
    });

    test('an entry written by an OLDER build, with no anchor, still '
        'loads', () async {
      // Forward compatibility in the direction that matters: the two keys
      // are optional, and a file that predates them must not be discarded.
      final read = storeRootedAt(
        onF,
        files: {
          _windows.join(onF, kRecentsFileName): _json({
            'version': 1,
            'entries': [
              {
                'path': r'E:\Jobs\Smith.rmpj',
                'displayName': 'Smith',
                'lastOpened': _at.toIso8601String(),
              },
            ],
          }),
        },
      );
      expect((await read.store.load()).single.path, r'E:\Jobs\Smith.rmpj');
    });
  });

  group('the bounded probe — run on MENU OPEN, never at startup', () {
    test('a hung UNC entry does not block, and is NOT removed', () async {
      const dead = r'\\NAS\jobs\Smith.rmpj';
      final made = _make(
        files: {
          _recents: _json({
            'version': 1,
            'entries': [
              {
                'path': dead,
                'displayName': 'Smith',
                'lastOpened': _at.toIso8601String(),
              },
              {
                'path': r'C:\jobs\Local.rmpj',
                'displayName': 'Local',
                'lastOpened': _at.toIso8601String(),
              },
            ],
          }),
          r'C:\jobs\Local.rmpj': Uint8List(4),
        },
        hangingPaths: {dead},
      );

      final entries = await made.store.load();
      expect(entries, hasLength(2));

      final states = await made.store.probe(entries);

      expect(
        states[dead],
        RecentEntryState.checking,
        reason:
            'a probe that never answered is UNKNOWN — dimmed but '
            'still clickable, never a verdict',
      );
      expect(states[r'C:\jobs\Local.rmpj'], RecentEntryState.ok);

      // NOTHING was removed. The probe has no side effect on the stored
      // list at all — that is the structural half of "a temporarily
      // unmounted network drive must not evict the entry".
      expect(await made.store.load(), hasLength(2));
    });

    test('ten dead entries all resolve, none removed', () async {
      final dead = {
        for (var i = 0; i < 10; i++) '\\\\\\\\NAS\\\\p$i.rmpj',
      };
      final made = _make(
        files: {
          _recents: _json({
            'version': 1,
            'entries': [
              for (final path in dead)
                {
                  'path': path,
                  'displayName': 'P',
                  'lastOpened': _at.toIso8601String(),
                },
            ],
          }),
        },
        hangingPaths: dead,
      );

      final entries = await made.store.load();
      final states = await made.store.probe(entries);

      expect(states.values, everyElement(RecentEntryState.checking));
      expect(await made.store.load(), hasLength(10));
    });

    test('a genuinely missing local file probes as unreachable — but is '
        'STILL not removed', () async {
      final made = _make(
        files: {
          _recents: _json({
            'version': 1,
            'entries': [
              {
                'path': r'C:\jobs\Deleted.rmpj',
                'displayName': 'D',
                'lastOpened': _at.toIso8601String(),
              },
            ],
          }),
        },
      );
      final states = await made.store.probe(await made.store.load());
      expect(states[r'C:\jobs\Deleted.rmpj'], RecentEntryState.unreachable);
      expect(
        await made.store.load(),
        hasLength(1),
        reason:
            'even a definitive miss is only rendered, never acted on '
            '— removal happens when the USER clicks it and the open fails',
      );
    });
  });

  group('shouldEvictOnOpenFailure — the ONLY route to removal', () {
    test('a confirmed missing file evicts', () {
      // `OpenNotFound` is only ever constructed after the DIRECTORY was
      // confirmed reachable, which is what makes it definitive.
      expect(
        shouldEvictOnOpenFailure(const OpenNotFound(r'C:\a.rmpj')),
        isTrue,
      );
    });

    test('an unreachable location does NOT evict — the unmounted-drive '
        'rule', () {
      expect(
        shouldEvictOnOpenFailure(const OpenUnreachable(r'\\NAS\a.rmpj')),
        isFalse,
      );
    });

    test('nothing else evicts', () {
      final keep = <OpenError>[
        const OpenPermissionDenied('x'),
        const OpenLocked('x'),
        const OpenPathTooLong('x', length: 300),
        const OpenCorrupt('x', detail: 'truncated'),
        const OpenTooLarge('x', bytes: 1, limit: 0),
        const OpenTooDeeplyNested('x', depth: 99, limit: 64),
        const OpenNotARackPalFile('x'),
        const OpenZipContainer('x'),
        const OpenNewerSchema(
          'x',
          minReaderVersion: 3,
          supportedSchemaVersion: 2,
        ),
        const OpenUnexpected('x', cause: 'e', stackTrace: StackTrace.empty),
      ];
      for (final error in keep) {
        expect(
          shouldEvictOnOpenFailure(error),
          isFalse,
          reason:
              '${error.runtimeType} must not evict: the file is right '
              "there, and forgetting it takes away the user's only route "
              'back to it — including the "open the backup" path',
        );
      }
    });
  });

  test('remove drops exactly one entry, case-insensitively', () async {
    final made = _make();
    await made.store.push(_entry(r'C:\jobs\A.rmpj'));
    await made.store.push(_entry(r'C:\jobs\B.rmpj'));

    final list = await made.store.remove(r'c:\JOBS\a.RMPJ');
    expect(list.map((e) => e.path), [r'C:\jobs\B.rmpj']);
  });
}
