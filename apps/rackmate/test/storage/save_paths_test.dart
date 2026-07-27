// Pure path derivation. Every case runs with a Windows-style
// `p.Context`, so this whole file is green on a Linux CI runner despite
// asserting backslashes and drive letters throughout.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';

final _windows = p.Context(style: p.Style.windows);
final _posix = p.Context(style: p.Style.posix);

void main() {
  group('SavePaths.forTarget derives four siblings in ONE directory', () {
    test('the happy path', () {
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.rackmate',
        context: _windows,
      );

      expect(paths.target, r'C:\jobs\Smith.rackmate');
      expect(paths.temp, r'C:\jobs\Smith.rackmate.tmp');
      expect(paths.backup, r'C:\jobs\Smith.rackmate.bak');
      expect(paths.backupTemp, r'C:\jobs\Smith.rackmate.bak.tmp');
      expect(paths.directory, r'C:\jobs');
    });

    test('all four are in the SAME directory — same volume, so the '
        'promote rename is atomic', () {
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.rackmate',
        context: _windows,
      );
      for (final path in paths.allPaths) {
        expect(
          _windows.dirname(path),
          paths.directory,
          reason:
              'a temp file on another volume makes step 5 a '
              'cross-volume copy with no atomicity at all',
        );
      }
    });

    test('the extension is FORCED when the save dialog returns a bare '
        'name', () {
      // Measured behaviour of the Windows save dialog: type "Smith", get
      // "Smith". An extensionless project will not reopen on a
      // double-click and the open dialog's filter will not show it.
      final paths = SavePaths.forTarget(r'C:\jobs\Smith', context: _windows);
      expect(paths.target, r'C:\jobs\Smith.rackmate');
      expect(paths.temp, r'C:\jobs\Smith.rackmate.tmp');
    });

    test('a deliberate other extension is APPENDED TO, not replaced', () {
      // "Smith.v2" is something the user typed on purpose. Replacing the
      // extension would silently throw away part of the name they chose.
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.v2',
        context: _windows,
      );
      expect(paths.target, r'C:\jobs\Smith.v2.rackmate');
    });

    test('the extension check is case-insensitive', () {
      expect(
        SavePaths.forTarget(
          r'C:\jobs\Smith.RACKMATE',
          context: _windows,
        ).target,
        r'C:\jobs\Smith.RACKMATE',
      );
      expect(
        SavePaths.forTarget(
          r'C:\jobs\Smith.RackMate',
          context: _windows,
        ).target,
        r'C:\jobs\Smith.RackMate',
      );
    });

    test('a name that merely CONTAINS the word is still given the '
        'extension', () {
      expect(
        SavePaths.forTarget(r'C:\jobs\rackmate', context: _windows).target,
        r'C:\jobs\rackmate.rackmate',
      );
    });

    test('POSIX paths derive identically', () {
      final paths = SavePaths.forTarget('/home/j/Smith', context: _posix);
      expect(paths.target, '/home/j/Smith.rackmate');
      expect(paths.backupTemp, '/home/j/Smith.rackmate.bak.tmp');
      expect(paths.directory, '/home/j');
    });

    test('forExactTarget leaves the name alone — for OUR files', () {
      final paths = SavePaths.forExactTarget(
        r'C:\data\recents.json',
        context: _windows,
      );
      expect(paths.target, r'C:\data\recents.json');
      expect(paths.temp, r'C:\data\recents.json.tmp');
    });

    test('stemOf strips both directory and extension', () {
      expect(
        SavePaths.forTarget(
          r'C:\jobs\Smith Residence.rackmate',
          context: _windows,
        ).stemOf(_windows),
        'Smith Residence',
      );
    });
  });

  group('the MAX_PATH pre-flight measures the LONGEST sibling THIS SAVE '
      'WILL ACTUALLY WRITE', () {
    /// A target that is exactly [target] characters long.
    SavePaths pathsOfLength(int target) => SavePaths.forTarget(
      r'C:\jobs\'
      '${'x' * (target - r'C:\jobs\'.length - '.rackmate'.length)}',
      context: _windows,
    );

    test('a target that fits but whose .bak.tmp does not is refused when a '
        'backup IS kept', () {
      // The eight characters ".bak.tmp" are the whole point: measuring
      // the target alone would let a save start and then fail at step 4.
      final paths = pathsOfLength(259);

      expect(paths.target.length, 259);
      expect(
        paths.longestPathLength(keepBackup: true),
        259 + '.bak.tmp'.length,
      );
      expect(paths.exceedsWindowsMaxPath(keepBackup: true), isTrue);
    });

    test('...and is ALLOWED when no backup will be written', () {
      // RecentsStore, PrefsStore, RecoveryStore and SnapshotStore all pass
      // keepBackup: false, so `.bak` and `.bak.tmp` are never created for
      // them. Measuring names that will never exist refuses those writes
      // eight characters early — and a recovery snapshot that never
      // writes is a safety net that silently is not there.
      final paths = pathsOfLength(255);

      expect(paths.temp.length, 259, reason: 'the .tmp exactly fits');
      expect(paths.backupTemp.length, greaterThan(259));

      expect(paths.exceedsWindowsMaxPath(keepBackup: false), isFalse);
      expect(
        paths.longestPathLength(keepBackup: false),
        paths.temp.length,
        reason: 'the .tmp is the longest name a keepBackup:false save makes',
      );

      // The same paths under the backup-keeping writer are still refused,
      // so this is a narrowing of scope and not a loosening of the limit.
      expect(paths.exceedsWindowsMaxPath(keepBackup: true), isTrue);
    });

    test('a keepBackup:false save whose OWN .tmp is too long is still '
        'refused', () {
      final paths = pathsOfLength(259);
      expect(paths.exceedsWindowsMaxPath(keepBackup: false), isTrue);
      expect(
        paths.longestPathLength(keepBackup: false),
        259 + '.tmp'.length,
      );
    });

    test('a comfortably short path does not trip it either way', () {
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.rackmate',
        context: _windows,
      );
      expect(paths.exceedsWindowsMaxPath(keepBackup: true), isFalse);
      expect(paths.exceedsWindowsMaxPath(keepBackup: false), isFalse);
      expect(
        paths.longestPathLength(keepBackup: true),
        paths.backupTemp.length,
      );
      expect(paths.longestPathLength(keepBackup: false), paths.temp.length);
    });

    test('allPaths is ordered longest first', () {
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.rackmate',
        context: _windows,
      );
      for (var i = 1; i < paths.allPaths.length; i++) {
        expect(
          paths.allPaths[i].length,
          lessThanOrEqualTo(paths.allPaths[i - 1].length),
        );
      }
    });

    test('pathsWritten omits exactly the two backup names', () {
      final paths = SavePaths.forTarget(
        r'C:\jobs\Smith.rackmate',
        context: _windows,
      );
      expect(paths.pathsWritten(keepBackup: true), paths.allPaths);
      expect(paths.pathsWritten(keepBackup: false), [
        paths.temp,
        paths.target,
      ]);
    });
  });

  group('FileBaseline — the external-change check', () {
    final at = DateTime.utc(2026, 7, 26, 14, 32, 11, 4);

    test('matches identical facts', () {
      final facts = FileFacts(size: 601233, modified: _fixed, readOnly: false);
      expect(
        FileBaseline(size: 601233, modified: _fixed).matches(facts),
        isTrue,
      );
    });

    test('a different SIZE is a change', () {
      final facts = FileFacts(size: 999, modified: _fixed, readOnly: false);
      expect(
        FileBaseline(size: 601233, modified: _fixed).matches(facts),
        isFalse,
      );
    });

    test('a different TIME is a change', () {
      final facts = FileFacts(
        size: 601233,
        modified: at.add(const Duration(minutes: 1)),
        readOnly: false,
      );
      expect(
        FileBaseline(size: 601233, modified: at).matches(facts),
        isFalse,
      );
    });

    test('SUB-MILLISECOND drift is NOT a change', () {
      // Filesystems and the Dart FileStat bridge do not agree on
      // sub-millisecond precision. A spurious "changed on disk" prompt on
      // every single save would train the user to click straight through
      // the one that matters.
      final facts = FileFacts(
        size: 601233,
        modified: at.add(const Duration(microseconds: 400)),
        readOnly: false,
      );
      expect(
        FileBaseline(size: 601233, modified: at).matches(facts),
        isTrue,
      );
    });

    test('absent matches only a missing file', () {
      expect(FileBaseline.absent.matches(null), isTrue);
      expect(
        FileBaseline.absent.matches(
          FileFacts(size: 0, modified: _fixed, readOnly: false),
        ),
        isFalse,
        reason:
            'a first save must refuse if something appeared at the '
            'name in the meantime',
      );
    });

    test('a present baseline never matches a deleted file', () {
      expect(
        FileBaseline(size: 10, modified: _fixed).matches(null),
        isFalse,
      );
    });

    test('FileBaseline.of round-trips facts', () {
      final facts = FileFacts(size: 42, modified: _fixed, readOnly: true);
      final baseline = FileBaseline.of(facts);
      expect(baseline.size, 42);
      expect(baseline.matches(facts), isTrue);
      expect(FileBaseline.of(null).isAbsent, isTrue);
    });

    group('unknown — "I cannot tell" is not "it changed"', () {
      // The distinction that was missing: `absent` is a POSITIVE CLAIM
      // that there was no file, and using it for an unreadable stat makes
      // the next save accuse a sync client of a modification that never
      // happened — and offer Overwrite, training the user to click
      // through the one prompt that will one day be real.
      test('matches ANY facts, so the next save skips the check rather '
          'than failing it', () {
        expect(
          FileBaseline.unknown.matches(
            FileFacts(size: 601233, modified: _fixed, readOnly: false),
          ),
          isTrue,
        );
        expect(FileBaseline.unknown.matches(null), isTrue);
      });

      test('is NOT absent, and absent is NOT unknown', () {
        // Both are sentinels with negative sizes; conflating them is the
        // exact bug. `isAbsent` must be an equality test, not `size < 0`.
        expect(FileBaseline.unknown.isUnknown, isTrue);
        expect(FileBaseline.unknown.isAbsent, isFalse);
        expect(FileBaseline.absent.isAbsent, isTrue);
        expect(FileBaseline.absent.isUnknown, isFalse);
        expect(FileBaseline.unknown, isNot(FileBaseline.absent));
      });

      test('absent still refuses when a file appeared underneath', () {
        // Guards the guard: widening `matches` must not have weakened the
        // first-save protection.
        expect(
          FileBaseline.absent.matches(
            FileFacts(size: 1, modified: _fixed, readOnly: false),
          ),
          isFalse,
        );
      });

      test('reads as itself in a diagnostic', () {
        expect(FileBaseline.unknown.toString(), 'FileBaseline.unknown');
        expect(FileBaseline.absent.toString(), 'FileBaseline.absent');
      });
    });
  });
}

final _fixed = DateTime.utc(2026, 7, 26, 14, 32, 11);
