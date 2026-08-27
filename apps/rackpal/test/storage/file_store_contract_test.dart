// ONE contract suite, run against BOTH `FakeFileStore` and
// `DartIoFileStore`. Without this, the ~40 crash assertions in
// atomic_writer_crash_test.dart are testing a fiction — a fake that
// quietly disagrees with NTFS proves nothing about NTFS.
//
// EVERY ASSERTION HERE WAS MEASURED ON THIS MACHINE, not remembered.
// The probe output, verbatim:
//
//   rename-over-existing     => ok, destination takes the source's bytes,
//                               source is gone
//   openWrite-missing-dir    => did NOT throw synchronously
//   flush (missing dir)      => PathNotFoundException, errno 3
//   close (missing dir)      => PathNotFoundException, errno 3
//   write-missing-dir        => errno 3   (ERROR_PATH_NOT_FOUND)
//   readonly-mode            => 0x8124    (r--r--r--)
//   writable-mode            => 0x81b6    (rw-rw-rw-)
//   write-readonly           => errno 5   (ERROR_ACCESS_DENIED)
//   rename-onto-readonly     => errno 5
//   rename-open-source       => errno 32  (ERROR_SHARING_VIOLATION)
//   delete-missing           => errno 2   (ERROR_FILE_NOT_FOUND)
//   stat-missing             => FileSystemEntityType.notFound
//
// ONE CORRECTION TO THE DESIGN'S CLAIMED MEASUREMENTS, recorded rather
// than quietly dropped: a read of an unreachable UNC path returned errno
// 3 on this machine, not errno 53, and `exists` on it answered in 0 ms
// rather than 1261 ms — the host name failed to resolve instantly here.
// The 53/64/1231 network codes remain in the mapping table because they
// are the documented Windows codes for a share that resolves but does not
// answer, but this suite does NOT claim to have reproduced them, and no
// test asserts them against a real filesystem.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/io_file_store.dart';

import 'fake_file_store.dart';

Uint8List _b(List<int> v) => Uint8List.fromList(v);

/// Both implementations must satisfy every assertion in here.
///
/// `setUpStore` yields a store and a directory that already exists.
/// `errnoOf` pulls the code out of whatever the implementation throws —
/// `dart:io` throws `FileSystemException`, the fake throws
/// `StorageOsException`, and the two-level `.osError.errorCode` shape is
/// the contract between them.
void runFileStoreContract(
  String name, {
  required Future<({FileStore fs, String root})> Function() setUpStore,
  required Future<void> Function() tearDownStore,
  required bool realFilesystem,
}) {
  group('FileStore contract — $name', () {
    late FileStore fs;
    late String root;

    setUp(() async {
      final made = await setUpStore();
      fs = made.fs;
      root = made.root;
    });

    tearDown(tearDownStore);

    String at(String leaf) => '$root${Platform.pathSeparator}$leaf';

    test('a written file exists, reads back, and stats', () async {
      await fs.writeBytes(at('a.bin'), _b([1, 2, 3]));

      expect(await fs.exists(at('a.bin')), isTrue);
      expect(await fs.readBytes(at('a.bin')), _b([1, 2, 3]));

      final facts = await fs.stat(at('a.bin'));
      expect(facts, isNotNull);
      expect(facts!.size, 3);
      expect(facts.readOnly, isFalse);
    });

    test('stat of a missing path is NULL, not a throw', () async {
      // "Is there a file here" is a question the save pre-flight and the
      // recovery scan ask constantly and neither treats as an error.
      expect(await fs.stat(at('nope.bin')), isNull);
      expect(await fs.exists(at('nope.bin')), isFalse);
    });

    test('RENAME REPLACES AN EXISTING DESTINATION', () async {
      // The single most load-bearing fact in the whole design: it is why
      // the promote step is one operation, and why the backup step does
      // not have to clear the target out of the way first.
      await fs.writeBytes(at('src.bin'), _b([0xAA]));
      await fs.writeBytes(at('dst.bin'), _b([0xBB, 0xBB, 0xBB]));

      await fs.rename(at('src.bin'), at('dst.bin'));

      expect(await fs.readBytes(at('dst.bin')), _b([0xAA]));
      expect(await fs.exists(at('src.bin')), isFalse);
    });

    test('copy replaces an existing destination', () async {
      await fs.writeBytes(at('c1.bin'), _b([1, 1]));
      await fs.writeBytes(at('c2.bin'), _b([2, 2, 2, 2]));

      await fs.copy(at('c1.bin'), at('c2.bin'));

      expect(await fs.readBytes(at('c2.bin')), _b([1, 1]));
      expect(await fs.exists(at('c1.bin')), isTrue);
    });

    test('openWrite / add / flush / close round-trips', () async {
      final sink = await fs.openWrite(at('s.bin'));
      sink
        ..add(_b([1, 2]))
        ..add(_b([3]));
      await sink.flush();
      await sink.close();

      expect(await fs.readBytes(at('s.bin')), _b([1, 2, 3]));
    });

    test(
      'close() ALONE still writes the buffered bytes — it just does not '
      'commit them',
      () async {
        // BOTH HALVES MATTER, and they are different claims.
        //
        // The OBSERVABLE half is here: a caller that never flushes still
        // gets its bytes, so `close()` is not a trap.
        //
        // The UNOBSERVABLE half is durability. `close()` makes no such
        // promise and `flush()` does, which is what makes the atomic
        // writer's step-3 `flush()` load-bearing rather than decoration.
        // Nothing short of cutting power can tell the two apart from a
        // unit test, so this suite does not pretend to: the ordering
        // consequence is proven against the fake's page-cache model in
        // atomic_writer_crash_test.dart, and that the real sink's flush
        // is a genuine fsync is held by RULE 7 in
        // storage_layering_test.dart, which is a grep and says so.
        final sink = await fs.openWrite(at('noflush.bin'));
        sink.add(_b([7, 8, 9]));
        await sink.close();

        expect(await fs.readBytes(at('noflush.bin')), _b([7, 8, 9]));
      },
    );

    test('flush() then close() writes each byte exactly once', () async {
      // The regression a buffered, RandomAccessFile-backed sink invites:
      // draining on flush AND again on close doubles the content. Cheap
      // to get wrong, silent when wrong, and fatal to every file.
      final sink = await fs.openWrite(at('twice.bin'));
      sink.add(_b([1, 2, 3]));
      await sink.flush();
      await sink.close();

      expect(await fs.readBytes(at('twice.bin')), _b([1, 2, 3]));
    });

    test('bytes added AFTER a flush still land', () async {
      final sink = await fs.openWrite(at('after.bin'));
      sink.add(_b([1]));
      await sink.flush();
      sink.add(_b([2]));
      await sink.flush();
      sink.add(_b([3]));
      await sink.close();

      expect(await fs.readBytes(at('after.bin')), _b([1, 2, 3]));
    });

    test('close() with nothing added at all creates an EMPTY file', () async {
      // `openWrite` is specified as creating-or-truncating, and the
      // lazily-opened sink must not quietly turn that into a no-op.
      await fs.writeBytes(at('empty.bin'), _b([9, 9, 9]));
      final sink = await fs.openWrite(at('empty.bin'));
      await sink.close();

      expect(await fs.readBytes(at('empty.bin')), _b([]));
    });

    test('openWrite TRUNCATES an existing file', () async {
      await fs.writeBytes(at('t.bin'), _b([9, 9, 9, 9, 9]));
      final sink = await fs.openWrite(at('t.bin'));
      sink.add(_b([1]));
      await sink.flush();
      await sink.close();

      expect(await fs.readBytes(at('t.bin')), _b([1]));
    });

    test('openWrite into a MISSING DIRECTORY does not throw '
        'synchronously — the error is DEFERRED to flush/close', () async {
      // Measured. This is why `openWrite` is a separate FileStore method
      // from `writeBytes`: collapsing them would erase two of the
      // interruption points the crash test enumerates.
      final missing = at('nodir${Platform.pathSeparator}x.bin');

      final sink = await fs.openWrite(missing);
      sink.add(_b([1, 2, 3]));

      var deferred = false;
      try {
        await sink.flush();
        await sink.close();
        // Any failure proves the point; the specific type is asserted
        // separately below.
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {
        deferred = true;
      }
      expect(
        deferred,
        isTrue,
        reason:
            'the failure must surface from flush/close, not from '
            'openWrite',
      );
    });

    test('writing into a missing directory reports a path error', () async {
      final missing = at('nodir2${Platform.pathSeparator}x.bin');
      Object? thrown;
      try {
        await fs.writeBytes(missing, _b([1]));
        // The point is the errno, asserted immediately below.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
      // Measured on Windows: ERROR_PATH_NOT_FOUND. POSIX: ENOENT.
      expect(errnoOf(thrown!), Platform.isWindows ? 3 : 2);
    });

    test('deleting a missing file throws — so "delete if present" must '
        'check first', () async {
      Object? thrown;
      try {
        await fs.delete(at('ghost.bin'));
        // The errno is asserted next.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
      // Measured: ERROR_FILE_NOT_FOUND (2), NOT ERROR_PATH_NOT_FOUND (3).
      // The distinction is what `osErrorToCategory` uses to tell "the
      // file is gone" from "the folder is gone".
      expect(errnoOf(thrown!), 2);
    });

    test('createDirectory is recursive and idempotent', () async {
      final deep = at(
        'x${Platform.pathSeparator}y'
        '${Platform.pathSeparator}z',
      );
      await fs.createDirectory(deep);
      await fs.createDirectory(deep);
      expect(await fs.exists(deep), isTrue);

      await fs.writeBytes('$deep${Platform.pathSeparator}f.bin', _b([7]));
      expect(
        await fs.readBytes('$deep${Platform.pathSeparator}f.bin'),
        _b([7]),
      );
    });

    test('listDirectory returns the direct children', () async {
      final dir = at('listme');
      await fs.createDirectory(dir);
      await fs.writeBytes('$dir${Platform.pathSeparator}one.bin', _b([1]));
      await fs.writeBytes('$dir${Platform.pathSeparator}two.bin', _b([2]));

      final entries = await fs.listDirectory(dir);
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.split(Platform.pathSeparator).last).toSet(),
        {'one.bin', 'two.bin'},
      );
    });

    test('listDirectory of a missing directory throws', () async {
      Object? thrown;
      try {
        await fs.listDirectory(at('nosuchdir'));
        // Presence is the assertion; the errno varies with the platform.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
    });

    // ==================================================================
    // LEASES — THE LIVENESS PRIMITIVE THE RECOVERY SCAN RESTS ON
    // ==================================================================
    // `RecoveryStore.scan` decides whether a snapshot pair belongs to a
    // CRASHED session or to one that is running right now, and gets it
    // wrong in the second direction by deleting a live instance's only
    // safety net. There is no timing heuristic that answers that
    // correctly — an app that crashed and was relaunched five seconds
    // later looks exactly like one that is still running — so the answer
    // comes from a lock the kernel releases when a process ends. These
    // four assertions are the whole contract the scan relies on.
    test('a lease can be taken, and is exclusive while it is held', () async {
      final first = await fs.acquireLease(at('a.lease'));
      expect(first, isNotNull);

      expect(
        await fs.acquireLease(at('a.lease')),
        isNull,
        reason:
            'a second holder must be refused, or a concurrent launch '
            'cannot tell a running instance from a crashed one',
      );

      await first!.release();
    });

    test('...and is available again once it is released', () async {
      final first = await fs.acquireLease(at('b.lease'));
      await first!.release();

      final second = await fs.acquireLease(at('b.lease'));
      expect(
        second,
        isNotNull,
        reason:
            'this is how a crashed session is recognised: its lease is no '
            'longer held, so it can be taken',
      );
      await second!.release();
    });

    test('release is idempotent', () async {
      final lease = await fs.acquireLease(at('c.lease'));
      await lease!.release();
      await lease.release();
      final again = await fs.acquireLease(at('c.lease'));
      expect(again, isNotNull);
      await again!.release();
    });

    test(
      'a lease CREATES its file, and does not truncate an existing one',
      () async {
        await fs.writeBytes(at('d.lease'), _b([1, 2, 3]));
        final lease = await fs.acquireLease(at('d.lease'));
        expect(lease, isNotNull);
        await lease!.release();

        expect(
          await fs.readBytes(at('d.lease')),
          _b([1, 2, 3]),
          reason:
              'truncating is a write into another process’s state for no '
              'benefit — the handle exists only to carry the lock',
        );
        expect(await fs.exists(at('e.lease')), isFalse);
        final made = await fs.acquireLease(at('e.lease'));
        await made!.release();
        expect(await fs.exists(at('e.lease')), isTrue);
      },
    );

    test('a lease in a directory that does not exist is REFUSED, not '
        'thrown', () async {
      // Every failure is `null`, and the caller reads `null` as "cannot
      // prove that session is gone". `RecoveryStore` therefore creates the
      // sessions directory before it probes anything, because otherwise
      // every session would read as running and no survivor would ever be
      // offered.
      expect(await fs.acquireLease(at('nosuchdir/f.lease')), isNull);
    });

    if (realFilesystem && Platform.isWindows) {
      test('WINDOWS: a lease is a REAL OS LOCK, not just an in-process '
          'flag', () async {
        // THE ASSERTION THE OTHER LEASE TESTS CANNOT MAKE. `DartIoFileStore`
        // also keeps a process-wide set of leased paths, because a POSIX
        // `fcntl` lock is held per process and would hand a second lease to
        // the same one — so "a second acquire is refused" would still pass
        // if the `lock()` call were deleted entirely, and cross-process
        // exclusion is the ONLY property the recovery scan actually needs.
        //
        // This bypasses the set and asks the kernel directly, the way a
        // second instance of RackPal does. Measured against the running
        // build: errno 33, "another process has locked a portion of the
        // file".
        final lease = await fs.acquireLease(at('os.lease'));
        expect(lease, isNotNull);

        final second = await File(at('os.lease')).open(mode: FileMode.append);
        Object? thrown;
        try {
          await second.lock();
          // Presence is the assertion; the errno is checked below.
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          thrown = e;
        }
        await second.close();
        await lease!.release();

        expect(
          thrown,
          isNotNull,
          reason:
              'without a real lock, a second instance of the app would '
              'read a running instance’s session as dead and offer its '
              'live snapshot as a crash survivor',
        );
        expect(errnoOf(thrown!), kWinErrorLockViolation);
      }, testOn: 'windows');

      test('WINDOWS: renaming a source another handle holds open fails '
          'with errno 32', () async {
        // This is exactly what real-time antivirus does to a file we have
        // just created, and it is the entire justification for the
        // promote step's retry budget.
        final sink = await fs.openWrite(at('held.bin'));
        sink.add(_b([1]));
        await sink.flush();

        Object? thrown;
        try {
          await fs.rename(at('held.bin'), at('held2.bin'));
          // ignore: avoid_catches_without_on_clauses — errno next.
        } catch (e) {
          thrown = e;
        }
        await sink.close();

        expect(thrown, isNotNull);
        expect(errnoOf(thrown!), kWinErrorSharingViolation);
      }, testOn: 'windows');

      test('WINDOWS: a read-only file reports mode 0x8124 and refuses a '
          'write with errno 5', () async {
        await fs.writeBytes(at('ro.bin'), _b([1]));
        Process.runSync('attrib', ['+R', at('ro.bin')]);
        addTearDown(() => Process.runSync('attrib', ['-R', at('ro.bin')]));

        final facts = await fs.stat(at('ro.bin'));
        expect(
          facts!.readOnly,
          isTrue,
          reason:
              'the owner-write bit test (mode & 0x80) is what the '
              'save pre-flight uses to catch this before writing',
        );

        Object? thrown;
        try {
          await fs.writeBytes(at('ro.bin'), _b([2]));
          // ignore: avoid_catches_without_on_clauses — errno next.
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isNotNull);
        expect(errnoOf(thrown!), kWinErrorAccessDenied);
      }, testOn: 'windows');

      test('WINDOWS: renaming ONTO a read-only destination fails with '
          'errno 5', () async {
        await fs.writeBytes(at('src2.bin'), _b([1]));
        await fs.writeBytes(at('ro2.bin'), _b([2]));
        Process.runSync('attrib', ['+R', at('ro2.bin')]);
        addTearDown(() => Process.runSync('attrib', ['-R', at('ro2.bin')]));

        Object? thrown;
        try {
          await fs.rename(at('src2.bin'), at('ro2.bin'));
          // ignore: avoid_catches_without_on_clauses — errno next.
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isNotNull);
        expect(errnoOf(thrown!), kWinErrorAccessDenied);
      }, testOn: 'windows');
    }
  });
}

void main() {
  // --- THE FAKE ------------------------------------------------------
  runFileStoreContract(
    'FakeFileStore',
    setUpStore: () async {
      const root = r'C:\root';
      final fs = FakeFileStore(initialDirectories: {'C:', root});
      return (fs: fs as FileStore, root: root);
    },
    tearDownStore: () async {},
    realFilesystem: false,
  );

  // --- THE REAL ONE, in a real temp directory ------------------------
  //
  // The ONLY place in this layer's unit tests that touches a disk, and it
  // exists solely to prove the fake is not fiction. It carries none of
  // the crash assertions.
  Directory? temp;
  runFileStoreContract(
    'DartIoFileStore',
    setUpStore: () async {
      temp = await Directory.systemTemp.createTemp('rackpal_contract');
      return (fs: const DartIoFileStore() as FileStore, root: temp!.path);
    },
    tearDownStore: () async {
      final dir = temp;
      temp = null;
      if (dir != null && dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    },
    realFilesystem: true,
  );

  group('errnoOf', () {
    test('reads the code off a dart:io FileSystemException', () {
      const exception = FileSystemException(
        'x',
        'y',
        OSError('denied', kWinErrorAccessDenied),
      );
      expect(errnoOf(exception), kWinErrorAccessDenied);
    });

    test('reads the code off the fake exception', () {
      expect(
        errnoOf(const StorageOsException(kWinErrorSharingViolation)),
        kWinErrorSharingViolation,
      );
    });

    test('a non-OS error has no code — which is a legitimate answer, not '
        'an exception', () {
      expect(errnoOf(StateError('not a filesystem problem')), isNull);
      expect(errnoOf(const FormatException('bad json')), isNull);
    });

    test('a FileSystemException with no osError has no code', () {
      expect(errnoOf(const FileSystemException('x')), isNull);
    });
  });
}
