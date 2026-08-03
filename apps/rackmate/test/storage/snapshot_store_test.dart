// Pre-update snapshots, pruned to the last ten.
//
// The assertion worth stating up front is the NUMERIC sort. Sorting
// `<sequence>.rmpj` names lexically makes "10" sort before "9", so
// the prune would delete the NEWEST snapshot and keep the oldest —
// precisely inverting the feature, and silently, because ten files would
// still be there afterwards.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/snapshot_store.dart';
import 'package:rackmate_core/rackmate_core.dart';

import 'atomicity.dart';
import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _first = r'C:\data\snapshots\doc-1\1.rmpj';

({SnapshotStore store, FakeFileStore fs}) _make({
  Map<String, Uint8List>? files,
  Set<String>? dirs,
  int maxPerDocument = kMaxSnapshotsPerDocument,
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: {'C:', _dataRoot, ...?dirs},
  );
  return (
    store: SnapshotStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: _dataRoot,
      context: _windows,
      maxPerDocument: maxPerDocument,
    ),
    fs: fs,
  );
}

/// [n] bytes whose content depends on [fill], so two snapshots of the same
/// size are not byte-identical.
Uint8List _bytes(int n, {int fill = 1}) =>
    Uint8List.fromList(List<int>.filled(n, fill));

void main() {
  test('a snapshot lands at snapshots/<docId>/<sequence>.rmpj', () async {
    final made = _make();
    final result = await made.store.write(
      docId: 'doc-1',
      sequence: 412,
      bytes: _bytes(32),
    );

    expect(result, isA<Ok<String>>());
    expect(
      (result as Ok<String>).value,
      r'C:\data\snapshots\doc-1\412.rmpj',
    );
    expect(
      made.fs.state.files.containsKey(r'C:\data\snapshots\doc-1\412.rmpj'),
      isTrue,
    );
  });

  test('writing twelve leaves TEN, and the two LOWEST sequences are the '
      'ones that went', () async {
    final made = _make();
    for (var i = 1; i <= 12; i++) {
      await made.store.write(docId: 'doc-1', sequence: i, bytes: _bytes(4));
    }

    final remaining = await made.store.sequencesFor('doc-1');
    expect(remaining, hasLength(kMaxSnapshotsPerDocument));
    expect(remaining, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
  });

  test('snapshots written before DR-015 are still counted AND still '
      'pruned (#170)', () async {
    // ── A CAP THAT ONLY APPLIES TO NEW FILES IS NOT A CAP ────────────
    // `pathFor` now spells `.rmpj`. A prune that rebuilt the name from it
    // would COUNT the ten `.rackmate` snapshots an earlier build left —
    // so the cap reads as already-met — and then fail to delete them,
    // silently, because a snapshot that will not delete is deliberately
    // swallowed. The old files would sit in AppData forever and the new
    // ones would pile up behind them.
    final made = _make(
      files: {
        for (var i = 1; i <= 10; i++)
          p.Context(style: p.Style.windows).join(
            _dataRoot,
            'snapshots',
            'doc-1',
            '$i.rackmate',
          ): _bytes(
            4,
          ),
      },
      dirs: {
        p.Context(
          style: p.Style.windows,
        ).join(_dataRoot, 'snapshots', 'doc-1'),
      },
    );

    expect(
      await made.store.sequencesFor('doc-1'),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      reason: 'legacy snapshots are invisible to the cap',
    );

    // Two more in the CURRENT spelling takes it to twelve, so the prune
    // must remove the two oldest — both of which are legacy files.
    for (final sequence in [11, 12]) {
      await made.store.write(
        docId: 'doc-1',
        sequence: sequence,
        bytes: _bytes(4),
      );
    }

    expect(
      await made.store.sequencesFor('doc-1'),
      [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      reason:
          'the two oldest were legacy-spelled, and the prune rebuilt '
          'their paths with the new extension instead of using the one '
          'it found on disk',
    );
    expect(
      made.fs.state.files.keys.where((k) => k.endsWith('1.rackmate')),
      isEmpty,
      reason: 'they are gone from disk, not merely from the listing',
    );
  });

  test('THE SORT IS NUMERIC — sequencesFor returns ascending INTEGERS, '
      'not ascending strings', () async {
    // "10" < "9" lexically. A lexical sort would return
    // [1, 10, 100, 101, ..., 11, 2, 3, 9] and the prune would then delete
    // whatever happened to sort first — keeping the NEWEST-numbered
    // snapshots and throwing away the oldest, which is the feature
    // exactly inverted. Ten files would still be on disk afterwards, so
    // nothing would look wrong.
    final made = _make(maxPerDocument: 1000);
    for (final sequence in [105, 9, 1, 100, 11, 2, 10, 3, 104]) {
      await made.store.write(
        docId: 'doc-1',
        sequence: sequence,
        bytes: _bytes(4),
      );
    }

    expect(
      await made.store.sequencesFor('doc-1'),
      [1, 2, 3, 9, 10, 11, 100, 104, 105],
      reason:
          'numeric order. A lexical sort gives '
          '[1, 10, 100, 104, 105, 11, 2, 3, 9].',
    );
  });

  test('...and the prune therefore drops the two NUMERICALLY lowest', () async {
    final made = _make();
    for (final sequence in [1, 2, 3, 9, 10, 11, 100, 101, 102, 103, 104, 105]) {
      await made.store.write(
        docId: 'doc-1',
        sequence: sequence,
        bytes: _bytes(4),
      );
    }

    expect(
      await made.store.sequencesFor('doc-1'),
      // EXACT, not a containsAll. Under a lexical sort this comes back as
      // [2, 3, 9, 11, 100, 101, 102, 103, 104, 105] — still ten files,
      // still containing every three-digit sequence, and wrong.
      [3, 9, 10, 11, 100, 101, 102, 103, 104, 105],
    );
  });

  test('snapshots are per-document — one project does not evict '
      "another's", () async {
    final made = _make();
    for (var i = 1; i <= 12; i++) {
      await made.store.write(docId: 'doc-a', sequence: i, bytes: _bytes(4));
    }
    await made.store.write(docId: 'doc-b', sequence: 1, bytes: _bytes(4));

    expect(await made.store.sequencesFor('doc-a'), hasLength(10));
    expect(await made.store.sequencesFor('doc-b'), [1]);
  });

  test('a file whose stem is not an integer is not ours, and is left '
      'alone', () async {
    final made = _make(
      files: {
        r'C:\data\snapshots\doc-1\notes.rmpj': _bytes(4),
        r'C:\data\snapshots\doc-1\1.rmpj': _bytes(4),
      },
      dirs: {r'C:\data\snapshots', r'C:\data\snapshots\doc-1'},
    );

    expect(await made.store.sequencesFor('doc-1'), [1]);
    await made.store.prune('doc-1');
    expect(
      made.fs.state.files.containsKey(
        r'C:\data\snapshots\doc-1\notes.rmpj',
      ),
      isTrue,
    );
  });

  test(
    'sequencesFor a document with no directory is empty, not a throw',
    () async {
      final made = _make();
      expect(await made.store.sequencesFor('never-snapshotted'), isEmpty);
      expect(await made.store.prune('never-snapshotted'), 0);
    },
  );

  test('prune under the cap removes nothing', () async {
    final made = _make(maxPerDocument: 3);
    await made.store.write(docId: 'd', sequence: 1, bytes: _bytes(4));
    await made.store.write(docId: 'd', sequence: 2, bytes: _bytes(4));
    expect(await made.store.prune('d'), 0);
    expect(await made.store.sequencesFor('d'), [1, 2]);
  });

  group('snapshots are written atomically', () {
    // The old single test here asserted only that no `.tmp` or `.bak`
    // remained afterwards — which is exactly what a plain
    // `fs.writeBytes(path, bytes)` produces, so it passed with the
    // AtomicWriter removed while the one copy of the user's file as it
    // existed BEFORE an irreversible schema migration became tearable by
    // any interruption. See `atomicity.dart`.

    test(
      'a FIRST snapshot is never partially written at any instant',
      () async {
        final made = _make();
        await made.store.write(docId: 'doc-1', sequence: 1, bytes: _bytes(32));

        expectAtomicWrite(
          made.fs,
          target: _first,
          expected: _bytes(32),
          what: 'the pre-update snapshot',
        );
        expectNoWorkingFiles(made.fs, target: _first);
      },
    );

    test('and neither is an OVERWRITE — the previous snapshot is never a '
        'gap and never half-replaced', () async {
      final made = _make();
      await made.store.write(docId: 'doc-1', sequence: 1, bytes: _bytes(32));
      // Re-base, so the replay below is the second write alone.
      made.fs.resetJournal();

      await made.store.write(
        docId: 'doc-1',
        sequence: 1,
        bytes: _bytes(48, fill: 2),
      );

      expectAtomicWrite(
        made.fs,
        target: _first,
        previous: _bytes(32),
        expected: _bytes(48, fill: 2),
        what: 'the pre-update snapshot',
      );
    });

    test('NO .bak — even when the target already exists', () async {
      // The flag is only observable when there is something to back up.
      // Against the old fixture, where the target never pre-existed,
      // `keepBackup: false` and `keepBackup: true` produced identical
      // filesystems: `AtomicWriter` computes
      // `backupAttempted = keepBackup && targetExisted`.
      final made = _make();
      await made.store.write(docId: 'doc-1', sequence: 1, bytes: _bytes(32));
      await made.store.write(
        docId: 'doc-1',
        sequence: 1,
        bytes: _bytes(48, fill: 2),
      );

      expect(
        made.fs.state.files.keys.where((f) => f.endsWith('.bak')),
        isEmpty,
        reason:
            'a .bak of a snapshot is a backup of a backup, and it would '
            'silently double what the ten-per-document cap costs',
      );
      expectNoWorkingFiles(made.fs, target: _first);
    });
  });
}
