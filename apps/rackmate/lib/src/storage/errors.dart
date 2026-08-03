// Every expected failure of this layer is a VALUE, not an exception
// (CR-093, extended from core's migration boundary to the whole file
// layer). Two sealed hierarchies, so the analyzer — not discipline —
// guarantees no case ships without copy: adding a variant and forgetting
// to describe it is a COMPILE ERROR at the presenter's exhaustive switch.
//
// The residual `unexpected` variant is deliberate and is not a
// catch-all-and-shrug. It carries the original error and stack so the
// §12.1 programmer-error channel can surface it as the bug it is. Expected
// outcomes are values; genuine bugs are crashes; the split is the point.
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';

// --- The OS error codes, measured on Windows rather than remembered ----

/// `ERROR_FILE_NOT_FOUND`.
const int kWinErrorFileNotFound = 2;

/// `ERROR_PATH_NOT_FOUND`. Windows ALSO reports an over-long path with
/// this code — see [osErrorToCategory], where the disambiguation lives.
const int kWinErrorPathNotFound = 3;

/// `ERROR_ACCESS_DENIED`. Measured for: writing to a read-only file,
/// renaming ONTO a read-only destination, and renaming onto a destination
/// another process holds open.
const int kWinErrorAccessDenied = 5;

/// `ERROR_SHARING_VIOLATION`. Measured: renaming a source file that
/// another process holds open. This is exactly what real-time antivirus
/// does to a file we have just written, which is why the promote step
/// retries.
const int kWinErrorSharingViolation = 32;

/// `ERROR_LOCK_VIOLATION`. Measured against the running build: a second
/// process asking for a byte-range lock another process already holds.
/// That refusal IS the recovery scan's liveness answer — see
/// [FileStore.acquireLease] — so it is the one errno in this table that a
/// caller reads as information rather than as a failure.
const int kWinErrorLockViolation = 33;

/// `ERROR_BAD_NETUNAME` / network path not found. Measured on an
/// unreachable UNC path.
const int kWinErrorBadNetPath = 53;

/// `ERROR_NETNAME_DELETED`.
const int kWinErrorNetNameDeleted = 64;

/// `ERROR_DISK_FULL`.
const int kWinErrorDiskFull = 112;

/// `ERROR_NO_NET_OR_BAD_PATH`.
const int kWinErrorNoNetwork = 1231;

/// POSIX `ENOENT`.
const int kPosixEnoent = 2;

/// POSIX `EACCES`.
const int kPosixEacces = 13;

/// POSIX `EROFS` — read-only filesystem.
const int kPosixErofs = 30;

/// POSIX `ENOSPC`.
const int kPosixEnospc = 28;

/// POSIX `ENAMETOOLONG`.
const int kPosixEnametoolong = 36;

/// POSIX `EHOSTDOWN` / stale network mount, the closest POSIX analogue of
/// Windows' network errors.
const int kPosixEstale = 116;

// --- The neutral categories the two hierarchies are built from ---------

/// What an OS error MEANS, independent of platform and of whether it
/// happened during an open or a save. [osErrorToCategory] is the one
/// place a raw errno turns into one of these.
enum StorageFailure {
  /// The containing directory is not there.
  directoryMissing,

  /// The file itself is not there, but its directory is.
  fileMissing,

  /// The target exists and is marked read-only.
  readOnlyTarget,

  /// Permission refused for a reason other than the read-only attribute.
  permissionDenied,

  /// Another process holds the file open.
  locked,

  /// The volume is full.
  diskFull,

  /// The path exceeds what this machine's Windows configuration accepts.
  pathTooLong,

  /// A network location that is not answering. TEMPORARY by assumption —
  /// nothing may be evicted from recents on the strength of this.
  unreachable,

  /// Nothing in the table matched.
  unknown,
}

/// Maps a raw OS error code to its product meaning.
///
/// PURE, so it is exhaustively unit-tested without a filesystem, and
/// so the mapping table is reviewable in one place rather than smeared
/// across catch blocks.
///
/// [parentDirExists] IS LOAD-BEARING, not a nicety. Windows reports an
/// over-long path as `ERROR_PATH_NOT_FOUND` — the SAME code as a genuinely
/// missing directory. Without this flag the user who typed a 280-character
/// filename is told "that folder does not exist" about a folder they are
/// looking at in Explorer. One extra stat buys the difference between a
/// correct message and a maddening one.
StorageFailure osErrorToCategory(
  int errno, {
  required bool isWindows,
  required bool parentDirExists,
  bool targetIsReadOnly = false,
}) {
  if (isWindows) {
    return switch (errno) {
      kWinErrorFileNotFound =>
        parentDirExists
            ? StorageFailure.fileMissing
            : StorageFailure.directoryMissing,
      kWinErrorPathNotFound =>
        parentDirExists
            // The directory is right there, so "path not found" cannot mean
            // what it says. On Windows the remaining meaning is length.
            ? StorageFailure.pathTooLong
            : StorageFailure.directoryMissing,
      kWinErrorAccessDenied =>
        targetIsReadOnly
            ? StorageFailure.readOnlyTarget
            : StorageFailure.permissionDenied,
      kWinErrorSharingViolation => StorageFailure.locked,
      kWinErrorBadNetPath ||
      kWinErrorNetNameDeleted ||
      kWinErrorNoNetwork => StorageFailure.unreachable,
      kWinErrorDiskFull => StorageFailure.diskFull,
      _ => StorageFailure.unknown,
    };
  }
  return switch (errno) {
    kPosixEnoent =>
      parentDirExists
          ? StorageFailure.fileMissing
          : StorageFailure.directoryMissing,
    kPosixEacces || kPosixErofs =>
      targetIsReadOnly
          ? StorageFailure.readOnlyTarget
          : StorageFailure.permissionDenied,
    kPosixEnospc => StorageFailure.diskFull,
    kPosixEnametoolong => StorageFailure.pathTooLong,
    kPosixEstale => StorageFailure.unreachable,
    _ => StorageFailure.unknown,
  };
}

// --- Save --------------------------------------------------------------

/// Why a save did not happen. Sealed: the presenter switches
/// exhaustively, so a new variant without copy will not compile.
sealed class SaveError {
  const SaveError();

  /// Which of the atomic save's numbered steps failed. Reported in the
  /// structured log (as an int, never a path) and used by the tests to
  /// pin down exactly where an injected fault landed.
  int get step;
}

/// Pre-flight: the containing directory is gone (an unplugged drive, a
/// deleted folder, a stale shortcut).
final class SaveDirectoryMissing extends SaveError {
  const SaveDirectoryMissing(this.paths);

  final SavePaths paths;

  @override
  int get step => 0;
}

/// Pre-flight: the target file exists and is marked read-only. Caught
/// BEFORE anything is written, so nothing on disk changed.
final class SaveReadOnlyTarget extends SaveError {
  const SaveReadOnlyTarget(this.paths);

  final SavePaths paths;

  @override
  int get step => 0;
}

/// Pre-flight: the file changed on disk since it was opened or last saved.
/// Two instances of the app, or a cloud client syncing underneath us.
/// Nothing else in this design catches that.
final class SaveChangedOnDisk extends SaveError {
  const SaveChangedOnDisk({
    required this.paths,
    required this.expected,
    required this.found,
  });

  final SavePaths paths;

  /// The (size, modified) recorded at open or at the last successful save.
  final FileBaseline expected;

  /// What is actually there now. `null` when the file has been deleted.
  final FileFacts? found;

  @override
  int get step => 0;
}

/// Pre-flight: the derived paths exceed the Windows `MAX_PATH` budget.
final class SavePathTooLong extends SaveError {
  const SavePathTooLong({required this.paths, required this.length});

  final SavePaths paths;

  /// The longest of the four derived paths, in characters.
  final int length;

  @override
  int get step => 0;
}

/// The volume filled up while writing the temporary file. Nothing in the
/// user's folder changed; the partial `.tmp` is swept.
final class SaveDiskFull extends SaveError {
  const SaveDiskFull({required this.paths, required this.step});

  final SavePaths paths;

  @override
  final int step;
}

/// The location stopped answering mid-save (a disconnected network drive).
final class SaveUnreachable extends SaveError {
  const SaveUnreachable({required this.paths, required this.step});

  final SavePaths paths;

  @override
  final int step;
}

/// Another process holds a file we need to rename. Antivirus, a backup
/// agent, or a second copy of the app. Reported only after the promote
/// step's retries are exhausted.
final class SaveLocked extends SaveError {
  const SaveLocked({required this.paths, required this.step});

  final SavePaths paths;

  @override
  final int step;
}

/// Permission refused for a reason other than the read-only attribute.
final class SavePermissionDenied extends SaveError {
  const SavePermissionDenied({required this.paths, required this.step});

  final SavePaths paths;

  @override
  final int step;
}

/// Nothing in the table matched. Carries the original error and stack for
/// the programmer-error channel — this is a bug report, not a user
/// message with a shrug in it.
final class SaveUnexpected extends SaveError {
  const SaveUnexpected({
    required this.paths,
    required this.step,
    required this.cause,
    required this.stackTrace,
  });

  final SavePaths paths;

  @override
  final int step;

  final Object cause;
  final StackTrace stackTrace;
}

// --- Open --------------------------------------------------------------

/// Why a document did not open.
sealed class OpenError {
  const OpenError();

  /// The path that was being opened. Shown in the error DIALOG, which is
  /// the user's own screen — never written to a log (§12.4).
  String get path;
}

/// There is no file at that path, and its directory is reachable.
final class OpenNotFound extends OpenError {
  const OpenNotFound(this.path, {this.backup});

  @override
  final String path;

  /// The sibling `.bak`, when one is there. This is what turns the
  /// residual hard-kill window (and a user who deleted the wrong file)
  /// from data loss into one extra click. Without this the `.bak` is
  /// decoration.
  final BackupFacts? backup;
}

/// A network location that is not answering. NOT a reason to forget the
/// file: the recents entry stays.
final class OpenUnreachable extends OpenError {
  const OpenUnreachable(this.path);

  @override
  final String path;
}

/// The OS refused to read it.
final class OpenPermissionDenied extends OpenError {
  const OpenPermissionDenied(this.path);

  @override
  final String path;
}

/// Import hardening: over the byte cap.
final class OpenTooLarge extends OpenError {
  const OpenTooLarge(this.path, {required this.bytes, required this.limit});

  @override
  final String path;

  final int bytes;
  final int limit;
}

/// Import hardening: nested deeper than the cap. Refused BEFORE
/// `jsonDecode`, which is the only place it can be refused — see
/// rackmate_core's json_limits.dart.
final class OpenTooDeeplyNested extends OpenError {
  const OpenTooDeeplyNested(
    this.path, {
    required this.depth,
    required this.limit,
  });

  @override
  final String path;

  final int depth;
  final int limit;
}

/// Valid JSON, but not a RackMate project — the `generator` tag is
/// missing or foreign.
final class OpenNotARackMateFile extends OpenError {
  const OpenNotARackMateFile(this.path, {this.generator});

  @override
  final String path;

  /// Whatever the root `generator` key actually held. Shown so the user
  /// can tell "I picked the wrong file" from "my file is damaged".
  final Object? generator;
}

/// The file begins with the ZIP magic number. Its own case, with its own
/// copy, because "that is a zip archive" is a far more useful sentence
/// than "that is not a RackMate file".
final class OpenZipContainer extends OpenError {
  const OpenZipContainer(this.path);

  @override
  final String path;
}

/// The file demands a reader newer than this build. REFUSED, with no
/// "open anyway" escape hatch — opening it would silently discard data
/// this build cannot model, which turns a refusal into a corruption.
final class OpenNewerSchema extends OpenError {
  const OpenNewerSchema(
    this.path, {
    required this.minReaderVersion,
    required this.supportedSchemaVersion,
  });

  @override
  final String path;

  final int minReaderVersion;
  final int supportedSchemaVersion;
}

/// Damaged or truncated. THIS is where the `.bak` earns its existence.
final class OpenCorrupt extends OpenError {
  const OpenCorrupt(this.path, {required this.detail, this.backup});

  @override
  final String path;

  /// The parse failure, for the diagnostics channel. Not shown verbatim.
  final String detail;

  /// The sibling `.bak`, when one is there.
  final BackupFacts? backup;
}

/// Nothing in the table matched.
final class OpenUnexpected extends OpenError {
  const OpenUnexpected(
    this.path, {
    required this.cause,
    required this.stackTrace,
  });

  @override
  final String path;

  final Object cause;
  final StackTrace stackTrace;
}

/// What is known about a sibling `.bak` at the moment an open failed —
/// enough for "a backup saved at 14:07 today is available", and no more.
final class BackupFacts {
  const BackupFacts({
    required this.path,
    required this.modified,
    required this.size,
  });

  final String path;
  final DateTime modified;
  final int size;
}
