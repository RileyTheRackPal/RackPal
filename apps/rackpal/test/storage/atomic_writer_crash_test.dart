// THIS FILE IS WHERE "a crash at any step leaves the previous good file"
// stops being decoration.
//
// TEST A — JOURNAL-PREFIX REPLAY. Models a HARD KILL: power loss, Task
// Manager, `WM_QUERYENDSESSION` with no grace. One successful save is run,
// its journal captured, and then the invariant is asserted at EVERY
// PREFIX of that journal. Each prefix is a possible instant of the cut.
//
// TEST B — FAULT INJECTION. Models an EXCEPTION: an antivirus lock, a full
// disk, a drive pulled out. The k-th operation throws a real errno, the
// engine's own error handling and retries run to completion, and the
// invariant plus the returned error plus "still dirty" plus "the queue is
// not wedged" are all asserted.
//
// Test A proves ORDERING. Test B proves RECOVERY. Neither touches a disk,
// neither sleeps, and neither kills a process.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);

const _dir = r'C:\jobs';
final _paths = SavePaths.forTarget(r'C:\jobs\Smith', context: _windows);

final _old = Uint8List.fromList(List<int>.generate(64, (i) => i));
final _next = Uint8List.fromList(List<int>.generate(96, (i) => 200 - i));

AtomicWriter _writerFor(FakeFileStore fs) => AtomicWriter(
  fs: fs,
  queue: SaveQueue(),
  context: _windows,
  // NOTHING SLEEPS. The retry backoff is injected as a no-op, so the
  // retry logic still runs its full three attempts in zero wall time.
  delay: (_) async {},
);

FakeFileStore _fs({
  required bool targetExists,
  Map<int, Object> faults = const {},
}) => FakeFileStore(
  initialFiles: {if (targetExists) _paths.target: _old},
  initialDirectories: {_dir, 'C:'},
  faults: faults,
);

// --- The invariant, as executable assertions ---------------------------

/// Asserts I1-I4 (and I6 when [atEnd]) over one replayed state.
///
/// [where] names the prefix so a failure points at the exact op index and
/// the op that follows it, rather than at "something in the save".
void expectSaveInvariant(
  FsState state, {
  required bool firstSave,
  required bool atEnd,
  required String where,
}) {
  final target = state.files[_paths.target];
  final backup = state.files[_paths.backup];

  // --- I1: the target is never partial and never absent. ---------------
  if (firstSave && !atEnd) {
    // For a FIRST save there is no OLD, so the target may legitimately be
    // absent — but if it is present it must still be one of the two
    // complete values, never a torn one.
    if (target != null) {
      expect(
        target,
        anyOf(Bytes(_old), Bytes(_next)),
        reason: 'I1 violated at $where: target is $target',
      );
    }
  } else {
    expect(
      target,
      isNotNull,
      reason:
          'I1 violated at $where: <target>.rppj DOES NOT EXIST. '
          'A hard kill here leaves the user opening Explorer to find '
          'their job gone.',
    );
    expect(
      target,
      anyOf(Bytes(_old), Bytes(_next)),
      reason:
          'I1 violated at $where: target is $target — neither the '
          'previous good bytes nor the new ones',
    );
  }

  // --- I2: a .bak that exists is COMPLETE. -----------------------------
  // A torn .bak that happens to parse as valid JSON is a silent
  // corruption vector: the user opens their backup after a crash and gets
  // a plausible project with half their devices missing.
  if (backup != null) {
    expect(
      backup,
      isA<Bytes>(),
      reason: 'I2 violated at $where: .bak is $backup — a PARTIAL backup',
    );
    expect(
      backup,
      anyOf(Bytes(_old), Bytes(_next)),
      reason:
          'I2 violated at $where: .bak holds something that was '
          'never a complete version',
    );
  }

  // --- I4: exactly four names, ever. (CR-098) --------------------------
  const allowed = {'Smith.rppj'};
  for (final path in state.files.keys) {
    final name = _windows.basename(path);
    final stem = name
        .replaceAll('.bak.tmp', '')
        .replaceAll('.bak', '')
        .replaceAll('.tmp', '');
    expect(
      allowed,
      contains(stem),
      reason:
          "I4 violated at $where: stray file $name in the user's "
          'folder',
    );
  }

  // --- I6: at completion the .bak holds OLD. ---------------------------
  if (atEnd && !firstSave) {
    expect(
      state.files[_paths.target],
      Bytes(_next),
      reason:
          'the save completed but the target does not hold the new '
          'bytes',
    );
    expect(
      state.files[_paths.backup],
      Bytes(_old),
      reason:
          'I6 violated: the .bak must hold the PREVIOUS version. If '
          'it holds the new one, steps 4 and 5 are the wrong way round '
          'and the backup is worthless.',
    );
    expect(
      state.files.containsKey(_paths.temp),
      isFalse,
      reason: 'the tmp was not swept',
    );
    expect(
      state.files.containsKey(_paths.backupTemp),
      isFalse,
      reason: 'the bak.tmp was not swept',
    );
  }
}

void main() {
  group('TEST A — the invariant holds at EVERY journal prefix', () {
    for (final firstSave in [false, true]) {
      final label = firstSave ? 'first save' : 'overwrite';

      test(
        '$label: every one of the prefixes is a survivable instant',
        () async {
          final fs = _fs(targetExists: !firstSave);
          final result = await _writerFor(fs).write(
            paths: _paths,
            bytes: _next,
          );
          expect(result, isA<Ok<WriteReceipt>>());

          final journal = fs.journal;
          expect(
            journal,
            isNotEmpty,
            reason: 'a save that journalled nothing proves nothing',
          );

          for (var k = 0; k <= journal.length; k++) {
            expectSaveInvariant(
              fs.replayPrefix(k),
              firstSave: firstSave,
              atEnd: k == journal.length,
              where:
                  'prefix $k/${journal.length}'
                  '${k < journal.length ? ' (next: ${journal[k]})' : ''}',
            );
          }
        },
      );
    }

    test(
      'the journal actually contains the ordering the design claims',
      () async {
        // Guards the guard: an engine that journalled nothing, or that
        // journalled in some other shape, would sail through the prefix
        // sweep vacuously.
        final fs = _fs(targetExists: true);
        await _writerFor(fs).write(paths: _paths, bytes: _next);

        final ops = fs.journal;
        int indexWhere(bool Function(FsOp) test) => ops.indexWhere(test);

        final tmpSettled = indexWhere(
          (op) => op is SinkClose && op.path == _paths.temp,
        );
        final bakTmpCopied = indexWhere(
          (op) => op is CopyEnd && op.to == _paths.backupTemp,
        );
        final bakPromoted = indexWhere(
          (op) => op is Renamed && op.to == _paths.backup,
        );
        final targetPromoted = indexWhere(
          (op) => op is Renamed && op.to == _paths.target,
        );

        expect(tmpSettled, greaterThanOrEqualTo(0));
        expect(bakTmpCopied, greaterThan(tmpSettled));
        expect(bakPromoted, greaterThan(bakTmpCopied));
        expect(targetPromoted, greaterThan(bakPromoted));

        // THE DELIBERATE DEVIATION FROM §9.3, asserted directly: the target
        // is never the SOURCE of a rename, because that is the step that
        // would make it briefly vanish.
        expect(
          ops.whereType<Renamed>().where((op) => op.from == _paths.target),
          isEmpty,
          reason:
              'renaming the target away is what §9.3 step 4 says and it '
              'is what leaves the user with no file at the name they know',
        );

        // ...and the backup is never written in place, only renamed into
        // place, so it can never be torn.
        expect(
          ops.whereType<CopyBegin>().where((op) => op.to == _paths.backup),
          isEmpty,
          reason: 'a direct copy onto .bak leaves a torn backup',
        );
      },
    );

    test('POWER LOSS, not just a process kill: every prefix survives the '
        'page cache going with it', () async {
      // TEST A above models a HARD KILL — the OS keeps running, so
      // everything in its page cache still reaches the disk. That is a
      // strictly weaker instant than a power cut, and the difference is
      // exactly where a save that never fsyncs hides: NTFS journals the
      // directory entry the promote produces while the tmp's data extents
      // are still only in the cache, so the rename lands on blocks nobody
      // ever wrote. `Smith.rmpj` is then torn — I1 violated — and the
      // `.bak` beside it holds the version from BEFORE the save that
      // appeared to succeed.
      for (final firstSave in [false, true]) {
        final fs = _fs(targetExists: !firstSave);
        final result = await _writerFor(fs).write(paths: _paths, bytes: _next);
        expect(result, isA<Ok<WriteReceipt>>());

        for (var k = 0; k <= fs.journal.length; k++) {
          expectSaveInvariant(
            fs.replayPrefixAfterPowerLoss(k),
            firstSave: firstSave,
            atEnd: k == fs.journal.length,
            where:
                '${firstSave ? 'first save' : 'overwrite'}: POWER LOSS at '
                'prefix $k/${fs.journal.length}'
                '${k < fs.journal.length ? ' (next: ${fs.journal[k]})' : ''}',
          );
        }
      }
    });

    test('the tmp is COMMITTED before it is promoted, and the backup copy '
        'before it is renamed', () async {
      // Guards the guard, the same way the ordering test above does: the
      // power-loss sweep would pass vacuously against an engine that
      // committed nothing if the model ever stopped distinguishing the
      // two. These are the two commit points, asserted directly.
      final fs = _fs(targetExists: true);
      await _writerFor(fs).write(paths: _paths, bytes: _next);
      final ops = fs.journal;

      final tmpCommitted = ops.indexWhere(
        (op) => op is SinkFlush && op.path == _paths.temp,
      );
      final targetPromoted = ops.indexWhere(
        (op) => op is Renamed && op.to == _paths.target,
      );
      expect(tmpCommitted, greaterThanOrEqualTo(0));
      expect(
        targetPromoted,
        greaterThan(tmpCommitted),
        reason:
            'promoting bytes that were never committed is the torn-file '
            'scenario in one line',
      );

      // ...and the close that follows the flush adds nothing, so it
      // cannot un-commit what the flush made durable.
      final closes = ops.whereType<SinkClose>().where(
        (op) => op.path == _paths.temp,
      );
      expect(closes, hasLength(1));
      expect(closes.single.wroteBufferedBytes, isFalse);

      // The backup path has the same shape: the copy commits its
      // destination, and only then is it renamed into place (I2).
      final bakTmpDone = ops.indexWhere(
        (op) => op is CopyEnd && op.to == _paths.backupTemp,
      );
      final bakPromoted = ops.indexWhere(
        (op) => op is Renamed && op.to == _paths.backup,
      );
      expect(bakTmpDone, greaterThanOrEqualTo(0));
      expect(bakPromoted, greaterThan(bakTmpDone));
    });

    test('a SECOND save over the result is equally survivable', () async {
      final fs = _fs(targetExists: true);
      final writer = _writerFor(fs);
      await writer.write(paths: _paths, bytes: _next);

      // Re-base so the second save replays against "the first save's
      // output is now OLD".
      fs.resetJournal();
      final third = Uint8List.fromList(List<int>.generate(48, (i) => i * 3));
      final result = await writer.write(paths: _paths, bytes: third);
      expect(result, isA<Ok<WriteReceipt>>());

      for (var k = 0; k <= fs.journal.length; k++) {
        final state = fs.replayPrefix(k);
        final target = state.files[_paths.target];
        expect(
          target,
          isNotNull,
          reason: 'I1 at prefix $k of the SECOND save',
        );
        expect(
          target,
          anyOf(Bytes(_next), Bytes(third)),
          reason: 'I1 at prefix $k of the SECOND save: $target',
        );
      }
    });
  });

  group('TEST B — fault injection at every operation', () {
    // Each entry: an errno, and the SaveError the engine must report.
    final faultCases = <String, ({Object fault, Type expected})>{
      'antivirus holds the file (errno 32)': (
        fault: const StorageOsException(kWinErrorSharingViolation),
        expected: SaveLocked,
      ),
      'disk full (errno 112)': (
        fault: const StorageOsException(kWinErrorDiskFull),
        expected: SaveDiskFull,
      ),
      'network drive vanished (errno 53)': (
        fault: const StorageOsException(kWinErrorBadNetPath),
        expected: SaveUnreachable,
      ),
      'permission denied (errno 5)': (
        fault: const StorageOsException(kWinErrorAccessDenied),
        expected: SavePermissionDenied,
      ),
    };

    for (final entry in faultCases.entries) {
      test('${entry.key}: at every op, the invariant survives and EVERY '
          'outcome is asserted', () async {
        // ================================================================
        // BOTH BRANCHES, AND A COVERAGE FLOOR.
        // ================================================================
        // The classification assertion used to sit inside
        // `if (result case Err(...))`, so for every fault that landed on a
        // best-effort path — step 4's copy/rename, `_sweepStrays`,
        // `_deleteIfPresent`, the step-8 re-stat, all of them swallowed by
        // design — the loop asserted NOTHING about that k at all. The half
        // of the test its name promised silently skipped, and nothing
        // recorded how often. A refactor that moved more work onto
        // best-effort paths would have shrunk classification coverage
        // towards zero with no visible signal.
        //
        // Now: an `Err` must be the SPECIFIC error and must have left the
        // previous good file; an `Ok` must be a save that genuinely
        // happened. And `classified` is counted, so a sweep in which
        // nothing reached the classifier fails — the same "a vacuous scan
        // proves nothing" guard the layering rules use.

        // How many operations a clean save takes, so the sweep covers
        // all of them and nothing beyond.
        final probe = _fs(targetExists: true);
        await _writerFor(probe).write(paths: _paths, bytes: _next);
        final operationCount = probe.operationCount;
        expect(operationCount, greaterThan(4));

        var classified = 0;
        var bestEffort = 0;

        for (var k = 0; k < operationCount; k++) {
          final fs = _fs(
            targetExists: true,
            faults: {k: entry.value.fault},
          );
          final writer = _writerFor(fs);
          final result = await writer.write(paths: _paths, bytes: _next);

          // The invariant holds at every prefix of a FAILED save too —
          // that is the whole promise.
          for (var j = 0; j <= fs.journal.length; j++) {
            expectSaveInvariant(
              fs.replayPrefix(j),
              firstSave: false,
              atEnd: false,
              where: 'fault at op $k, prefix $j',
            );
          }

          switch (result) {
            case Err(:final error):
              classified++;
              expect(
                error.runtimeType,
                entry.value.expected,
                reason: 'fault at op $k produced ${error.runtimeType}',
              );
              expect(
                fs.state.files[_paths.target],
                Bytes(_old),
                reason:
                    'fault at op $k was REFUSED, so the user must still '
                    'have exactly the file they had — every Err in this '
                    'engine happens at or before the promote',
              );
            case Ok():
              bestEffort++;
              // The fault landed somewhere the engine swallows on
              // purpose: step 4's backup, a sweep, the re-stat. An `Ok`
              // is a POSITIVE CLAIM that the document was written, so it
              // is checked as one rather than skipped.
              expect(
                fs.state.files[_paths.target],
                Bytes(_next),
                reason:
                    'fault at op $k reported SUCCESS. A save that says '
                    'it worked and did not is the worst outcome this '
                    'layer has: the user closes the file believing it is '
                    'on disk.',
              );
          }

          // THE QUEUE MUST NOT BE WEDGED. A failed save that disabled
          // saving for the rest of the session would be the single worst
          // bug this layer can have.
          final retry = await writer.write(paths: _paths, bytes: _next);
          expect(
            retry,
            isA<Ok<WriteReceipt>>(),
            reason:
                'after a fault at op $k the engine refused to work '
                'again',
          );
        }

        // MEASURED, and therefore TIGHT: 6 or 7 of the 12 operations reach
        // the classifier today, depending on the errno (32 and 5 are
        // retried at the promote and one of them then succeeds). A floor
        // of 6 is one swallowed fault away from failing, which is what a
        // coverage floor is for — a loose one is decoration.
        expect(
          classified,
          greaterThan(5),
          reason:
              'only $classified of $operationCount faults reached the '
              'classifier. The rest were swallowed by a best-effort path, '
              'so this sweep is no longer testing what its name says.',
        );
        expect(
          bestEffort,
          greaterThan(0),
          reason:
              'and the Ok branch must be reached too, or its assertion is '
              'the one that proves nothing',
        );
      });
    }

    test(
      'a failed save leaves the previous good file EXACTLY intact',
      () async {
        // Fail the promote rename on every attempt, including the retries.
        final probe = _fs(targetExists: true);
        await _writerFor(probe).write(paths: _paths, bytes: _next);

        final fs = _fs(
          targetExists: true,
          faults: {
            for (var k = 0; k < probe.operationCount + 8; k++)
              if (k >= 4)
                k: const StorageOsException(kWinErrorSharingViolation),
          },
        );
        final result = await _writerFor(fs).write(paths: _paths, bytes: _next);

        expect(result, isA<Err<WriteReceipt>>());
        expect(
          fs.state.files[_paths.target],
          Bytes(_old),
          reason: 'the user must still have exactly what they had',
        );
      },
    );

    test('the promote step retries an antivirus lock and recovers inside '
        'the budget', () async {
      // Three failures is exactly the budget (one attempt plus three
      // retries), so this must succeed.
      final fs = FakeFileStore(
        initialFiles: {_paths.target: _old},
        initialDirectories: {_dir},
        failRenamesTo: {_paths.target: 3},
      );
      final result = await _writerFor(fs).write(paths: _paths, bytes: _next);

      expect(
        result,
        isA<Ok<WriteReceipt>>(),
        reason: 'three consecutive AV locks are inside the retry budget',
      );
      expect(fs.state.files[_paths.target], Bytes(_next));
    });

    test('a promote that never unlocks reports SaveLocked and leaves the '
        'old file intact', () async {
      final fs = FakeFileStore(
        initialFiles: {_paths.target: _old},
        initialDirectories: {_dir},
        // One more than the budget.
        failRenamesTo: {_paths.target: 4},
      );
      final result = await _writerFor(fs).write(paths: _paths, bytes: _next);

      final error = (result as Err<WriteReceipt>).error;
      expect(error, isA<SaveLocked>());
      expect((error as SaveLocked).step, 5);
      expect(
        fs.state.files[_paths.target],
        Bytes(_old),
        reason:
            'an exhausted retry budget must still be SAFE — that is '
            'the whole reason the backup is a copy and not a rename',
      );
      expect(
        fs.state.files[_paths.temp],
        Bytes(_next),
        reason:
            'THE .tmp MUST SURVIVE A FAILED PROMOTE. Steps 0-4 all '
            'succeeded, so it holds a complete, committed copy of the new '
            'bytes — and at this instant it can be the ONLY durable copy '
            'in existence: 20 seconds of work, the 30 s autosave has not '
            'fired, the window never blurred, so there is no recovery '
            'snapshot. Sweeping it here means a power cut or a force-kill '
            'from the error dialog loses the work outright. It is one of '
            "the four names CR-098 permits in the user's folder, I3 makes "
            'no claim about it, and the next successful save sweeps it at '
            'step 8.',
      );
    });

    test('and the retained tmp is swept by the NEXT successful save', () async {
      // The other half of the bargain: keeping the tmp must not leave a
      // stray behind forever (I4).
      final fs = FakeFileStore(
        initialFiles: {_paths.target: _old},
        initialDirectories: {_dir},
        failRenamesTo: {_paths.target: 4},
      );
      final writer = _writerFor(fs);

      expect(
        await writer.write(paths: _paths, bytes: _next),
        isA<Err<WriteReceipt>>(),
      );
      expect(fs.state.files.containsKey(_paths.temp), isTrue);

      final second = await writer.write(paths: _paths, bytes: _next);
      expect(second, isA<Ok<WriteReceipt>>());
      expect(fs.state.files.containsKey(_paths.temp), isFalse);
      expect(fs.state.files.containsKey(_paths.backupTemp), isFalse);
    });
  });

  group('the pre-flight refuses before anything moves', () {
    test('a missing directory is caught with ZERO writes', () async {
      final fs = FakeFileStore(initialDirectories: const {'C:'});
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
      );

      expect((result as Err<WriteReceipt>).error, isA<SaveDirectoryMissing>());
      expect(
        fs.journal,
        isEmpty,
        reason: 'the pre-flight must not have written anything',
      );
    });

    test('a read-only target is caught with ZERO writes', () async {
      final fs = FakeFileStore(
        initialFiles: {_paths.target: _old},
        initialDirectories: {_dir},
        readOnlyPaths: {_paths.target},
      );
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
      );

      expect((result as Err<WriteReceipt>).error, isA<SaveReadOnlyTarget>());
      expect(fs.journal, isEmpty);
      expect(fs.state.files[_paths.target], Bytes(_old));
    });

    test('a file that changed on disk is refused, not overwritten', () async {
      final fs = _fs(targetExists: true);
      // The baseline says 999 bytes; the file is 64. Two instances of the
      // app, or a cloud client that synced underneath us.
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
        expected: FileBaseline(size: 999, modified: DateTime.utc(2020)),
      );

      final error = (result as Err<WriteReceipt>).error;
      expect(error, isA<SaveChangedOnDisk>());
      expect(fs.journal, isEmpty);
      expect(
        fs.state.files[_paths.target],
        Bytes(_old),
        reason: 'the whole point is that the other version survives',
      );
    });

    test('a matching baseline passes the external-change check', () async {
      final fs = _fs(targetExists: true);
      final facts = await fs.stat(_paths.target);
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
        expected: FileBaseline.of(facts),
      );
      expect(result, isA<Ok<WriteReceipt>>());
    });

    test('an over-long path is refused before any I/O', () async {
      final long = SavePaths.forTarget(
        r'C:\jobs\'
        '${'x' * 300}',
        context: _windows,
      );
      final fs = FakeFileStore(initialDirectories: {_dir});
      final result = await _writerFor(fs).write(paths: long, bytes: _next);

      final error = (result as Err<WriteReceipt>).error;
      expect(error, isA<SavePathTooLong>());
      expect((error as SavePathTooLong).length, greaterThan(259));
      expect(fs.journal, isEmpty);
    });

    test('a keepBackup:false writer is NOT refused for a .bak.tmp it will '
        'never create', () async {
      // RecentsStore, PrefsStore, RecoveryStore and SnapshotStore all pass
      // keepBackup: false. Measuring `.bak.tmp` for them refuses eight
      // characters early — and per the mid-session finding, a recovery
      // snapshot that never writes tells nobody.
      final stem = 'x' * (255 - r'C:\jobs\'.length - '.rppj'.length);
      final tight = SavePaths.forTarget(
        r'C:\jobs\'
        '$stem',
        context: _windows,
      );
      expect(tight.temp.length, 259);
      expect(tight.backupTemp.length, greaterThan(259));

      final fs = FakeFileStore(initialDirectories: {_dir, 'C:'});
      final result = await _writerFor(fs).write(
        paths: tight,
        bytes: _next,
        keepBackup: false,
      );

      expect(
        result,
        isA<Ok<WriteReceipt>>(),
        reason: 'nothing this save writes exceeds MAX_PATH',
      );
      expect(fs.state.files[tight.target], Bytes(_next));

      // The identical paths under a backup-keeping writer are still
      // refused, so the check was narrowed in scope, not loosened.
      final withBackup = await _writerFor(
        FakeFileStore(initialDirectories: {_dir, 'C:'}),
      ).write(paths: tight, bytes: _next);
      expect((withBackup as Err<WriteReceipt>).error, isA<SavePathTooLong>());
    });
  });

  group('the post-promote re-baseline never fabricates a change', () {
    test('a re-stat that cannot answer yields UNKNOWN, not ABSENT', () async {
      // `FileBaseline.absent` is a positive claim that there was no file.
      // Recording it here — where the promote has just succeeded, so
      // there certainly IS one — makes the very next Ctrl+S fail the
      // external-change check and tell the user that "another program — a
      // second copy of RackPal, or a sync client such as OneDrive or
      // Dropbox — has written to" their file. Nothing wrote to it.
      final probe = _fs(targetExists: true);
      await _writerFor(probe).write(paths: _paths, bytes: _next);

      // The LAST stat of a clean save is the step-8 re-baseline.
      final restatIndex = probe.operationCount - 1;
      final fs = _fs(
        targetExists: true,
        faults: {restatIndex: const StorageOsException(kWinErrorBadNetPath)},
      );
      final result = await _writerFor(fs).write(paths: _paths, bytes: _next);

      expect(
        result,
        isA<Ok<WriteReceipt>>(),
        reason: 'a re-stat that failed must not fail a save that worked',
      );
      final receipt = (result as Ok<WriteReceipt>).value;
      expect(receipt.baseline.isUnknown, isTrue);
      expect(receipt.baseline.isAbsent, isFalse);
      expect(fs.state.files[_paths.target], Bytes(_next));
    });

    test('and the NEXT save with that baseline is not refused', () async {
      // The consequence, end to end. This is the assertion the comment at
      // the re-stat used to claim without it being true.
      final probe = _fs(targetExists: true);
      await _writerFor(probe).write(paths: _paths, bytes: _next);

      final fs = _fs(
        targetExists: true,
        faults: {
          probe.operationCount - 1: const StorageOsException(
            kWinErrorBadNetPath,
          ),
        },
      );
      final writer = _writerFor(fs);
      final first = await writer.write(paths: _paths, bytes: _next);
      final baseline = (first as Ok<WriteReceipt>).value.baseline;

      final third = Uint8List.fromList(List<int>.filled(24, 7));
      final second = await writer.write(
        paths: _paths,
        bytes: third,
        expected: baseline,
      );

      expect(
        second,
        isA<Ok<WriteReceipt>>(),
        reason:
            'an unanswered question is not evidence of a change, and '
            'accusing a sync client that did nothing trains the user to '
            'click through the one prompt that will one day be real',
      );
      expect(fs.state.files[_paths.target], Bytes(third));
    });
  });

  group('the backup is best-effort and never fails the save', () {
    test('a read-only .bak still lets the document save', () async {
      final fs = FakeFileStore(
        initialFiles: {_paths.target: _old},
        initialDirectories: {_dir},
        readOnlyPaths: {_paths.backup},
      );
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
      );

      expect(result, isA<Ok<WriteReceipt>>());
      final receipt = (result as Ok<WriteReceipt>).value;
      expect(
        receipt.backupUpdated,
        isFalse,
        reason:
            'the caller must be able to say "Saved. The backup copy '
            'could not be updated." — reported, never silent',
      );
      expect(fs.state.files[_paths.target], Bytes(_next));
      expect(
        fs.state.files.containsKey(_paths.backupTemp),
        isFalse,
        reason: 'the torn bak.tmp must be swept',
      );
    });

    test('keepBackup: false produces no .bak at all', () async {
      final fs = _fs(targetExists: true);
      await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
        keepBackup: false,
      );
      expect(fs.state.files.containsKey(_paths.backup), isFalse);
      expect(fs.state.files[_paths.target], Bytes(_next));
    });
  });

  group('stray sweeping and the single-flight queue', () {
    // THE SWEEP IS ONLY OBSERVABLE ON THE PATHS THIS SAVE DOES NOT
    // OTHERWISE TOUCH. An ordinary overwrite consumes `<target>.tmp`
    // (it writes and promotes it) and consumes `<target>.bak.tmp` (step 4
    // creates and renames it), so a test using that shape proves nothing
    // about the sweep at all — it passes with the sweep deleted. Both
    // cases below are ones where a stale sibling genuinely SURVIVES the
    // save unless something removes it.
    test('a stale .bak.tmp survives a FIRST save (step 4 is skipped) '
        'unless the sweep removes it', () async {
      final fs = FakeFileStore(
        // No target: this is a first save, so the backup step never runs
        // and never renames the stale bak.tmp away.
        initialFiles: {
          _paths.backupTemp: Uint8List.fromList([4, 5]),
        },
        initialDirectories: {_dir},
      );
      final result = await _writerFor(fs).write(paths: _paths, bytes: _next);

      expect(result, isA<Ok<WriteReceipt>>());
      expect(
        fs.state.files.containsKey(_paths.backupTemp),
        isFalse,
        reason:
            'a torn backup copy from an interrupted earlier save '
            "would otherwise sit in the user's folder forever (I4)",
      );
      expect((result as Ok<WriteReceipt>).value.sweptStrays, 1);
    });

    test('a stale .bak.tmp survives a keepBackup:false save unless the '
        'sweep removes it', () async {
      // This is the recents / prefs / snapshot shape.
      final fs = FakeFileStore(
        initialFiles: {
          _paths.target: _old,
          _paths.backupTemp: Uint8List.fromList([4, 5]),
        },
        initialDirectories: {_dir},
      );
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
        keepBackup: false,
      );

      expect(result, isA<Ok<WriteReceipt>>());
      expect(fs.state.files.containsKey(_paths.backupTemp), isFalse);
      expect((result as Ok<WriteReceipt>).value.sweptStrays, 1);
    });

    test('an ordinary overwrite leaves neither sibling behind', () async {
      final fs = FakeFileStore(
        initialFiles: {
          _paths.target: _old,
          _paths.temp: Uint8List.fromList([1, 2, 3]),
          _paths.backupTemp: Uint8List.fromList([4, 5]),
        },
        initialDirectories: {_dir},
      );
      final result = await _writerFor(fs).write(
        paths: _paths,
        bytes: _next,
      );

      expect(result, isA<Ok<WriteReceipt>>());
      expect(fs.state.files.containsKey(_paths.temp), isFalse);
      expect(fs.state.files.containsKey(_paths.backupTemp), isFalse);
    });

    test('two concurrent writes to the same paths do not interleave', () async {
      // Without the single-flight queue, an explicit save and a 30 s
      // autosave firing together produce two overlapping tmp+rename
      // sequences over the same four names. They share ONE `.tmp`, so the
      // second writer's promote finds its temp file already renamed away
      // by the first — and the second save FAILS, silently, having been
      // reported as started.
      final fs = _fs(targetExists: true);
      final writer = _writerFor(fs);
      final a = Uint8List.fromList(List<int>.filled(32, 0xAA));
      final b = Uint8List.fromList(List<int>.filled(48, 0xBB));

      final results = await Future.wait([
        writer.write(paths: _paths, bytes: a),
        writer.write(paths: _paths, bytes: b),
      ]);

      // BOTH must succeed. This is the assertion the queue exists for:
      // an autosave that quietly eats a user's explicit save, or vice
      // versa, is exactly the kind of bug that never reproduces.
      for (var i = 0; i < results.length; i++) {
        expect(
          results[i],
          isA<Ok<WriteReceipt>>(),
          reason: 'write #$i failed: two writers shared one .tmp',
        );
      }

      // The last writer wins cleanly, and NOTHING is left behind.
      expect(fs.state.files[_paths.target], anyOf(Bytes(a), Bytes(b)));
      expect(fs.state.files.containsKey(_paths.temp), isFalse);
      expect(fs.state.files.containsKey(_paths.backupTemp), isFalse);

      // I6 across a pair of saves: the .bak must hold the version that
      // was on disk before the LAST save, never the one the last save
      // just wrote.
      expect(
        fs.state.files[_paths.backup],
        anyOf(Bytes(_old), Bytes(a), Bytes(b)),
      );
      expect(
        fs.state.files[_paths.backup],
        isNot(fs.state.files[_paths.target]),
        reason:
            'a .bak identical to the target is not a backup of '
            'anything',
      );

      // And no prefix of the combined journal ever saw a partial target.
      for (var k = 0; k <= fs.journal.length; k++) {
        final target = fs.replayPrefix(k).files[_paths.target];
        expect(
          target,
          isNotNull,
          reason: 'I1 at combined prefix $k: target vanished',
        );
        expect(
          target,
          isA<Bytes>(),
          reason: 'I1 at combined prefix $k: target is $target',
        );
      }
    });

    test('the queue reports busy while work is outstanding', () async {
      final queue = SaveQueue();
      expect(queue.busy, isFalse);
      final future = queue.add(() async => 1);
      expect(queue.busy, isTrue);
      await future;
      expect(queue.busy, isFalse);
    });

    test('a throwing member does not wedge the queue', () async {
      final queue = SaveQueue();
      await expectLater(
        queue.add<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(await queue.add(() async => 42), 42);
      expect(queue.busy, isFalse);
    });
  });
}
