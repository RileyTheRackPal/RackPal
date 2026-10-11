// THE one `dart:io` filesystem implementation of [FileStore].
//
// This is the ONLY file in the repository permitted to construct `File` or
// `Directory`, and `apps/rackpal/test/storage/storage_layering_test.dart`
// asserts it — the same grep-gate pattern as the existing `no_print_test`
// and `no_flutter_import_test`. Everything above this file is testable
// without a disk precisely because everything above this file cannot reach
// one.
//
// It adds no PRODUCT logic. It translates, and it lets every
// `FileSystemException` propagate unchanged so the callers upstream can
// read the real `osError.errorCode` — mapping errnos into product meaning
// is errors.dart's job, and doing it here would hide the number from the
// place that can disambiguate it.
//
// THE ONE THING IT DOES BEYOND TRANSLATING is honour the seam's
// DURABILITY contract: `FileSink.flush`, `writeBytes` and `copy` all
// commit to the medium before returning. `dart:io` gives that away for
// free in exactly one of the three (`writeAsBytes(flush: true)`); the
// other two need a `RandomAccessFile.flush()` that the obvious spellings
// do not perform. See the sink below and `file_store.dart`'s contract.
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal/src/storage/file_store.dart';

/// The owner-write bit in a POSIX-style mode. Windows reports `0x8124`
/// (`r--r--r--`) for a read-only file and `0x81b6` (`rw-rw-rw-`) for a
/// writable one, both measured, so this single test works on all three
/// desktop platforms.
const int kOwnerWriteBit = 0x80;

/// A [FileSink] over a `RandomAccessFile` rather than an `IOSink`.
///
/// ==================================================================
/// WHY NOT `File.openWrite()`, WHICH IS THE OBVIOUS SPELLING
/// ==================================================================
/// Because `IOSink.flush()` IS NOT AN fsync. It waits for the buffered
/// bytes to reach `RandomAccessFile.writeFrom` — a `write(2)` — and stops
/// there. The bytes are in the OS page cache and nothing has asked the
/// device to commit them.
///
/// That is fatal for exactly one operation in this app, and it happens to
/// be the highest-stakes one. The atomic save writes `<target>.tmp`,
/// closes it, and renames it over `<target>`. On NTFS the rename's
/// directory-entry update goes through the metadata journal, which
/// survives a power cut; the tmp's data extents do not. Cut power a
/// second after a 600 KB save "completes" and the reboot leaves
/// `Smith.rppj` pointing at extents that still hold zeros or stale
/// blocks — a TORN file at the name the user knows, with the `.bak`
/// holding the version from before the save. Invariant I1 says the target
/// is always exactly OLD or exactly NEW; that is the direct violation.
///
/// `RandomAccessFile.flush()` is the missing call: `FlushFileBuffers` on
/// Windows, `fsync` elsewhere.
///
/// TWO PROPERTIES OF `openWrite` ARE PRESERVED DELIBERATELY:
///
///  * THE OPEN IS LAZY, so an unwritable path still fails from
///    flush/close rather than from `openWrite` — the measured deferral
///    that `file_store_contract_test.dart` pins and that two of the crash
///    test's interruption points depend on.
///  * `close()` still writes anything left buffered, so a caller that
///    never flushes still gets its bytes. It just does not get
///    durability, which is what makes step 3's `flush()` load-bearing.
final class _IoFileSink implements FileSink {
  _IoFileSink(this._path);

  final String _path;

  /// `copy: false` matches `IOSink.add`'s own zero-copy behaviour: the
  /// atomic writer hands over bytes it does not touch again.
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  RandomAccessFile? _handle;

  // `FileMode.write` — the same mode `File.openWrite()` defaults to, so
  // the sharing and truncation semantics the contract suite measured are
  // unchanged.
  Future<RandomAccessFile> _open() async =>
      _handle ??= await File(_path).open(mode: FileMode.write);

  @override
  void add(Uint8List bytes) => _buffer.add(bytes);

  @override
  Future<void> flush() async {
    final handle = await _open();
    await _drain(handle);
    // THE DURABILITY POINT. Not decoration — see the class comment.
    await handle.flush();
  }

  @override
  Future<void> close() async {
    final handle = await _open();
    try {
      await _drain(handle);
    } finally {
      _handle = null;
      await handle.close();
    }
  }

  Future<void> _drain(RandomAccessFile handle) async {
    if (_buffer.isEmpty) return;
    await handle.writeFrom(_buffer.takeBytes());
  }
}

/// Every path THIS PROCESS currently holds a lease on.
///
/// PROCESS-WIDE ON PURPOSE, and not a field on the store: a lease is a
/// statement about the operating-system process, and `DartIoFileStore` is
/// a `const` value that anything may construct a second copy of.
///
/// It also closes the one place where the two implementations would
/// otherwise disagree. On Windows a byte-range lock is enforced per
/// HANDLE, so a second `lock()` inside this process already fails; on
/// Linux and macOS `fcntl` locks are held per PROCESS and the second call
/// SUCCEEDS. Without this set the contract suite would have to assert two
/// different behaviours, and the recovery scan would treat this session's
/// own lease as abandoned on every platform but one.
final Set<String> _processLeases = <String>{};

final class _IoFileLease implements FileLease {
  _IoFileLease(this._path, this._handle);

  final String _path;
  final RandomAccessFile _handle;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _processLeases.remove(_path);
    try {
      await _handle.unlock();
      // Releasing a lease must never fail the shutdown it is part of; the
      // close below drops the lock anyway, and process exit drops it even
      // if that fails too.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
    try {
      await _handle.close();
      // Same reason as the unlock above: process exit closes the handle
      // and drops the lock regardless, so a failure here changes nothing
      // and must not take a clean shutdown down with it.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
  }
}

/// [FileStore] over the real filesystem.
final class DartIoFileStore implements FileStore {
  const DartIoFileStore();

  @override
  // `avoid_slow_async_io` prefers the *Sync variants because they are
  // faster. They are also BLOCKING, and the measurement that drove this
  // whole design is `existsSync` on a dead UNC path taking 1261 ms — on
  // the UI isolate that is a frozen window. Async is the deliberate
  // choice here and everywhere else in this class.
  Future<bool> exists(String path) async =>
      // Same reason as the comment above: blocking here would freeze
      // the window on an unreachable network path.
      // ignore: avoid_slow_async_io
      await File(path).exists() || await Directory(path).exists();

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      File(path).writeAsBytes(bytes, flush: true);

  @override
  Future<FileSink> openWrite(String path) async => _IoFileSink(path);

  @override
  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  @override
  Future<void> copy(String from, String to) async {
    await File(from).copy(to);
    // `File.copy` is `CopyFileEx`, which leaves the destination in the
    // page cache. The one caller renames this destination into `.bak`
    // straight afterwards, so an uncommitted copy plus a journalled
    // rename is exactly how a TORN backup is produced (I2).
    await _commit(to);
  }

  @override
  Future<void> delete(String path) => File(path).delete();

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<List<String>> listDirectory(String path) async {
    final entries = <String>[];
    await for (final entity in Directory(path).list()) {
      entries.add(entity.path);
    }
    return entries;
  }

  /// Asks the OS to commit [path]'s already-written bytes to the medium.
  ///
  /// Opened in append mode purely to obtain a WRITE handle: `flush` is
  /// `FlushFileBuffers` on Windows and `fsync` elsewhere, and both refuse
  /// a read-only handle. Nothing is appended — the buffer is empty and
  /// the file's length is untouched. `FileMode.append` would CREATE a
  /// missing file, which is why this is private and is only ever called
  /// on a path that was just written.
  Future<void> _commit(String path) async {
    final handle = await File(path).open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  /// See [FileStore.acquireLease].
  ///
  /// `FileMode.append` rather than `FileMode.write` for one reason: the
  /// second TRUNCATES, and truncating a file another live instance is
  /// holding its lease on is a write into another process's state for no
  /// benefit at all. Nothing is ever appended — the handle exists only to
  /// carry the lock.
  ///
  /// `lock()`'s DEFAULT is `FileLock.exclusive`, which is the
  /// NON-BLOCKING exclusive lock — it throws when somebody else holds it
  /// rather than waiting. That default is load-bearing and is why no
  /// argument is passed: `FileLock.blockingExclusive` would hang the
  /// startup scan for as long as the other instance runs, which from the
  /// user's side is forever.
  @override
  Future<FileLease?> acquireLease(String path) async {
    if (_processLeases.contains(path)) return null;
    RandomAccessFile? handle;
    try {
      handle = await File(path).open(mode: FileMode.append);
      await handle.lock();
      // EVERY failure is "no lease", never a throw — see the contract.
      // A lock another process holds, a directory that is not there, a
      // filesystem that refuses locking: all of them mean the caller must
      // not assume the other session is gone.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (handle != null) {
        try {
          await handle.close();
          // A handle we could not even close is a handle the process exit
          // will close. Nothing here may mask the acquisition failure that
          // brought us into this block.
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {}
      }
      return null;
    }
    _processLeases.add(path);
    return _IoFileLease(path, handle);
  }

  @override
  Future<FileFacts?> stat(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type == FileSystemEntityType.notFound) return null;
    return FileFacts(
      size: stat.size,
      modified: stat.modified.toUtc(),
      readOnly: stat.mode & kOwnerWriteBit == 0,
    );
  }
}
