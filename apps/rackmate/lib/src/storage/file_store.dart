// THE filesystem seam. Every byte this app writes to or reads from a disk
// goes through this interface, and there are exactly two implementations:
// `DartIoFileStore` (io_file_store.dart — the only file in the repository
// that touches `dart:io`'s filesystem classes) and `FakeFileStore`
// (test/storage/fake_file_store.dart — a pure, immutable-state, journaling
// model). One shared contract suite runs against BOTH, so the fake cannot
// drift into fiction.
//
// WHY THIS AND NOT `package:file`. `MemoryFileSystem` is good work and is
// already in pubspec.lock transitively via flutter_test. It is not used
// here for three reasons:
//  1. It is not in the §10.1 dependency table. Promoting a transitive
//     dev-tree package to a production dependency is how build breakages
//     arrive.
//  2. Its surface is ~40 operations. This layer needs ten. A contract test
//     over the ten is complete; a contract test over the forty would be
//     aspirational, and an aspirational contract test is how a fake drifts.
//  3. It cannot inject "fail the k-th operation with PathAccessException
//     errno 32". That single capability is what turns "a crash at any step
//     leaves the previous good file" from a sentence in a design document
//     into a mechanically checked property.
//
// WHY `openWrite` IS SEPARATE FROM `writeBytes`. Measured on Windows:
// `File.openWrite` into a MISSING DIRECTORY does not throw. The error is
// deferred and surfaces from `flush`/`close` as a `PathNotFoundException`.
// Collapsing the two into one `writeBytes` would erase two of the
// interruption points the crash test enumerates, and would let the fake be
// quietly wrong about deferred errors — the exact class of bug the
// contract test exists to catch.
import 'dart:typed_data';

/// What a `stat` answers. Deliberately narrow: three facts, all of which
/// something in this layer actually branches on.
final class FileFacts {
  const FileFacts({
    required this.size,
    required this.modified,
    required this.readOnly,
  });

  /// Length in bytes.
  final int size;

  /// Last-modified time, UTC. Half of the external-change baseline the
  /// save pre-flight compares against (the other half is [size]).
  final DateTime modified;

  /// True when the file's mode has no owner-write bit.
  ///
  /// Measured on Windows: a read-only file reports mode `0x8124`
  /// (`r--r--r--`) and a writable one `0x81b6` (`rw-rw-rw-`), so the test
  /// is `mode & 0x80 == 0`. Detected in the save pre-flight, BEFORE any
  /// bytes are written, so the user gets "this file is read-only" rather
  /// than a half-finished save and a raw errno.
  final bool readOnly;

  @override
  String toString() =>
      'FileFacts(size: $size, modified: $modified, readOnly: $readOnly)';
}

/// A streaming write handle. Three operations, kept separate because each
/// is a distinct interruption point in the atomic save.
///
/// ==================================================================
/// [flush] MEANS COMMITTED TO THE MEDIUM, NOT "HANDED TO THE OS"
/// ==================================================================
/// This is the contract's sharpest edge and the one that was wrong. The
/// obvious implementation of a streaming sink is `dart:io`'s `IOSink`,
/// and `IOSink.flush()` waits only for the bytes to reach `write(2)` — it
/// never calls `FlushFileBuffers`/`fsync`. Under a real power cut that is
/// not enough: NTFS journals the directory entry a `rename` produces
/// while the source file's DATA EXTENTS are still only in the page cache,
/// so the promote lands and the promoted file holds pre-write garbage.
/// The user opens their project and gets a corrupt-file dialog, with a
/// `.bak` holding the version from BEFORE the save that appeared to
/// succeed.
///
/// So [flush] is specified as the DURABILITY POINT and both
/// implementations must honour it. `FakeFileStore` models a page cache
/// and treats a path written but not flushed as indeterminate after a
/// power loss; `DartIoFileStore` writes through a `RandomAccessFile` and
/// calls its `flush()`, which is `FlushFileBuffers` on Windows.
///
/// HONESTY NOTE, because this cannot be measured from a unit test: the
/// contract suite pins everything OBSERVABLE about these two calls, and
/// durability is not observable without cutting power. What IS proven
/// mechanically is the ORDERING — `atomic_writer_crash_test.dart` replays
/// every journal prefix under power-loss semantics and fails if the
/// commit does not precede the promote. That the real sink's [flush]
/// really does `fsync` is held by a source-level gate in
/// `storage_layering_test.dart`, which is a grep and is labelled as one.
abstract interface class FileSink {
  /// Buffers [bytes]. Whether any of them have reached the disk yet is
  /// UNDEFINED until [flush] returns — which is precisely why the fake
  /// models post-`add` content as indeterminate rather than as the full
  /// buffer.
  void add(Uint8List bytes);

  /// Writes everything buffered and COMMITS IT TO THE MEDIUM. After this
  /// returns the file's content is exactly what was added, and it
  /// survives a power loss. See the class comment.
  Future<void> flush();

  /// Writes anything still buffered and releases the handle. On Windows
  /// this is what lets a subsequent rename of this path succeed.
  ///
  /// MAKES NO DURABILITY PROMISE. Closing a file descriptor does not
  /// commit its pages, and a sink whose bytes must survive a power cut
  /// has to [flush] first. This is deliberately NOT belt-and-braces: it
  /// is what makes the `flush()` in the atomic writer's step 3
  /// load-bearing rather than decorative.
  Future<void> close();
}

/// A LIVENESS TOKEN: an exclusive claim on a path that dies with the
/// process holding it.
///
/// ==================================================================
/// WHAT THIS IS FOR, AND WHY NOTHING CHEAPER WORKS
/// ==================================================================
/// Nothing prevents a second instance of RackMate. The recovery directory
/// is shared state between them, and a startup scan has to answer one
/// question it previously could not: is this snapshot pair the leftovers
/// of a CRASHED session, or the live safety net of a session that is
/// running right now? Offering the second one describes in-flight work as
/// a crash survivor, and "Discard" at that prompt deletes a running
/// instance's only copy of twenty minutes of unsaved work.
///
/// Every cheaper answer is a timing heuristic, and all of them fail the
/// case that matters most: an application that crashed and was relaunched
/// five seconds later looks exactly like one that is still running. A
/// heartbeat with a liveness window withholds precisely the survivor the
/// user relaunched to get back.
///
/// An OS lease has no such window. The lock is released by the KERNEL
/// when the holding process ends — cleanly, by a kill, or by a power cut
/// — so "the previous session is gone" is a fact rather than an estimate.
/// A TOKEN, not a callback. `one_member_abstracts` would have this be a
/// bare `Future<void> Function()`, which throws away the two things that
/// make it useful: the type names what is being held, and the two
/// implementations (a `RandomAccessFile` lock and the fake's registry
/// entry) each carry their own state behind it.
// ignore: one_member_abstracts
abstract interface class FileLease {
  /// Gives the claim up. Idempotent.
  Future<void> release();
}

/// The eleven operations this persistence layer needs from a filesystem.
/// Nothing else may be added without a matching contract-test assertion —
/// an operation the contract does not pin down is an operation the fake is
/// free to model incorrectly.
abstract interface class FileStore {
  /// True when a file or directory exists at [path].
  ///
  /// MUST NOT THROW for an unreachable network path. Measured: `exists`
  /// on a dead UNC path returned `false` after 1261 ms rather than
  /// throwing — which is why nothing on the startup path may await it.
  Future<bool> exists(String path);

  /// Reads the whole file. Used for documents, sidecars and the small
  /// JSON stores.
  Future<Uint8List> readBytes(String path);

  /// Writes [bytes] in one shot, creating or truncating, and COMMITS them
  /// to the medium before returning. For SMALL files only — the document
  /// save path uses [openWrite] so its interruption points stay visible.
  Future<void> writeBytes(String path, Uint8List bytes);

  /// Opens a streaming write handle, creating or truncating.
  ///
  /// Errors are DEFERRED — this call succeeding says nothing about
  /// whether the path is writable. See the file header.
  Future<FileSink> openWrite(String path);

  /// Renames [from] to [to], REPLACING [to] if it exists.
  ///
  /// Measured on Windows: `File.renameSync` over an existing destination
  /// succeeds and the destination takes the source's bytes. This is what
  /// makes the atomic save's promote step a single operation, and it is
  /// why the backup step does not need to clear the target out of the way
  /// first.
  Future<void> rename(String from, String to);

  /// Copies [from] to [to], replacing [to] if it exists, and COMMITS the
  /// destination to the medium before returning.
  ///
  /// The commit is not fussiness. The one caller is the backup step, and
  /// its destination is `<target>.bak.tmp` — which is renamed to
  /// `<target>.bak` moments later. An uncommitted copy plus a journalled
  /// rename is precisely how a TORN `.bak` is produced, and a torn `.bak`
  /// that happens to parse as valid JSON is the silent corruption vector
  /// the whole copy-to-a-temp-then-rename dance exists to prevent (I2).
  Future<void> copy(String from, String to);

  /// Deletes the file at [path]. Throws if it does not exist — callers
  /// that mean "delete if present" check [exists] first, so a missing
  /// file is never confused with a permission failure.
  Future<void> delete(String path);

  /// Creates the directory at [path] and every missing parent. A no-op
  /// when it already exists.
  Future<void> createDirectory(String path);

  /// The full paths of the entries directly inside [path]. Order is
  /// unspecified; callers sort.
  Future<List<String>> listDirectory(String path);

  /// [FileFacts] for [path], or `null` when nothing is there.
  ///
  /// Returns `null` rather than throwing for the missing case, because
  /// "is there a file here" is a question the save pre-flight and the
  /// recovery scan both ask constantly and neither treats as an error.
  Future<FileFacts?> stat(String path);

  /// Takes an exclusive [FileLease] on [path], creating the file if it is
  /// not there. `null` means SOMEBODY LIVE ALREADY HOLDS IT.
  ///
  /// NEVER THROWS. Every failure — a missing parent directory, a
  /// permission refusal, a filesystem with no locking at all — answers
  /// `null`, which the recovery scan reads as "cannot prove this session
  /// is gone" and therefore leaves the pair strictly alone. That is the
  /// conservative direction: the only way to lose a user's snapshot is to
  /// mistake a live session for a dead one, and no failure here can
  /// produce that mistake.
  ///
  /// THE EXCLUSION IS BOTH CROSS-PROCESS AND IN-PROCESS. Cross-process is
  /// the point; in-process is what makes the two implementations agree,
  /// because a POSIX `fcntl` lock is held per PROCESS and would happily
  /// hand a second lease to the same one.
  Future<FileLease?> acquireLease(String path);
}
