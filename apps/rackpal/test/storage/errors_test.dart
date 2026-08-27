// The errno mapping table, exhaustively. Pure, so no filesystem is
// needed and both platform tables are asserted from either CI runner.
//
// THE errno-3 DISAMBIGUATION IS THE POINT OF THIS FILE. Windows reports
// an over-long path as ERROR_PATH_NOT_FOUND — the SAME code as a missing
// directory. Without the parentDirExists flag, the user who typed a
// 280-character filename is told "that folder does not exist" about a
// folder they are looking at in Explorer.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/storage/errors.dart';

void main() {
  group('osErrorToCategory — Windows', () {
    StorageFailure map(
      int errno, {
      bool parentDirExists = true,
      bool targetIsReadOnly = false,
    }) => osErrorToCategory(
      errno,
      isWindows: true,
      parentDirExists: parentDirExists,
      targetIsReadOnly: targetIsReadOnly,
    );

    test('errno 3 with the parent PRESENT means the path is too long', () {
      expect(map(kWinErrorPathNotFound), StorageFailure.pathTooLong);
    });

    test('errno 3 with the parent ABSENT means the directory is gone', () {
      expect(
        map(kWinErrorPathNotFound, parentDirExists: false),
        StorageFailure.directoryMissing,
      );
    });

    test('errno 2 distinguishes a missing FILE from a missing FOLDER', () {
      // Measured: deleting a missing file gives 2, writing into a missing
      // directory gives 3. The pair is what makes the two messages
      // different sentences.
      expect(map(kWinErrorFileNotFound), StorageFailure.fileMissing);
      expect(
        map(kWinErrorFileNotFound, parentDirExists: false),
        StorageFailure.directoryMissing,
      );
    });

    test('errno 5 splits on the read-only attribute', () {
      // Same code for "you may not write here" and "this file is marked
      // read-only". The pre-flight stat is what tells them apart, and the
      // two deserve different copy: one offers Save As, the other cannot
      // be fixed by the user at all.
      expect(map(kWinErrorAccessDenied), StorageFailure.permissionDenied);
      expect(
        map(kWinErrorAccessDenied, targetIsReadOnly: true),
        StorageFailure.readOnlyTarget,
      );
    });

    test('errno 32 is a lock — the antivirus case', () {
      expect(map(kWinErrorSharingViolation), StorageFailure.locked);
    });

    test('every network code is UNREACHABLE, never missing', () {
      // This is §9.5's "a temporarily unmounted network drive must not
      // evict the entry", stated as a rule about errno rather than as a
      // hope. Only `unreachable` reaches the recents-eviction decision as
      // "do not evict".
      for (final errno in [
        kWinErrorBadNetPath,
        kWinErrorNetNameDeleted,
        kWinErrorNoNetwork,
      ]) {
        expect(map(errno), StorageFailure.unreachable, reason: 'errno $errno');
      }
    });

    test('errno 112 is a full disk', () {
      expect(map(kWinErrorDiskFull), StorageFailure.diskFull);
    });

    test('an unknown code is UNKNOWN, not a guess', () {
      expect(map(9999), StorageFailure.unknown);
    });
  });

  group('osErrorToCategory — POSIX', () {
    StorageFailure map(
      int errno, {
      bool parentDirExists = true,
      bool targetIsReadOnly = false,
    }) => osErrorToCategory(
      errno,
      isWindows: false,
      parentDirExists: parentDirExists,
      targetIsReadOnly: targetIsReadOnly,
    );

    test('ENOENT splits on the parent, same as Windows', () {
      expect(map(kPosixEnoent), StorageFailure.fileMissing);
      expect(
        map(kPosixEnoent, parentDirExists: false),
        StorageFailure.directoryMissing,
      );
    });

    test('EACCES and EROFS both split on the read-only attribute', () {
      expect(map(kPosixEacces), StorageFailure.permissionDenied);
      expect(
        map(kPosixEacces, targetIsReadOnly: true),
        StorageFailure.readOnlyTarget,
      );
      expect(map(kPosixErofs), StorageFailure.permissionDenied);
    });

    test('ENOSPC and ENAMETOOLONG map to their Windows twins', () {
      expect(map(kPosixEnospc), StorageFailure.diskFull);
      expect(map(kPosixEnametoolong), StorageFailure.pathTooLong);
    });

    test('POSIX does NOT reuse the Windows codes', () {
      // errno 3 on POSIX is ESRCH ("no such process"), which is not a
      // filesystem answer at all. Sharing the table between platforms
      // would silently turn it into "path too long".
      expect(map(kWinErrorPathNotFound), StorageFailure.unknown);
      expect(map(kWinErrorSharingViolation), StorageFailure.unknown);
      expect(map(kWinErrorDiskFull), StorageFailure.unknown);
    });
  });

  group('every StorageFailure is reachable from some errno', () {
    // A category nothing maps to is a category whose copy is never shown,
    // which means it was never reviewed either.
    test('Windows covers all but one', () {
      final reached = <StorageFailure>{
        for (final errno in [
          kWinErrorFileNotFound,
          kWinErrorPathNotFound,
          kWinErrorAccessDenied,
          kWinErrorSharingViolation,
          kWinErrorBadNetPath,
          kWinErrorDiskFull,
          9999,
        ])
          osErrorToCategory(errno, isWindows: true, parentDirExists: true),
        osErrorToCategory(
          kWinErrorPathNotFound,
          isWindows: true,
          parentDirExists: false,
        ),
        osErrorToCategory(
          kWinErrorAccessDenied,
          isWindows: true,
          parentDirExists: true,
          targetIsReadOnly: true,
        ),
      };
      expect(reached, containsAll(StorageFailure.values));
    });
  });
}
