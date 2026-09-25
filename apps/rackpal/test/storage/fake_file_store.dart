// The test double that the entire crash-safety story rests on.
//
// Four things make it more than a map of paths to bytes, and each exists
// because a specific claim in atomic_writer.dart is otherwise unprovable:
//
//  1. AN IMMUTABLE [FsState] AND A JOURNAL OF PURE [FsOp] VALUES.
//     `FsState.apply(op)` is a pure function, so the state at any PREFIX
//     of the journal can be reconstructed by a fold. Every prefix is a
//     possible instant of a power cut, which is how "a crash at any step
//     leaves the previous good file" becomes ~14 mechanical assertions
//     instead of a sentence in a comment.
//
//  2. CONTENT MODELLED AS `Bytes | Indeterminate`.
//     Between an `add` and a `flush` the bytes on disk are SOME PREFIX of
//     the buffer — possibly empty, possibly all of it, and nothing may
//     assume which. Modelling that honestly is what makes the mutation
//     signal unambiguous: "write straight to the target" produces a
//     prefix where the target is `Indeterminate`, and the invariant check
//     fails with the exact op index.
//
//  3. PER-OPERATION FAULT INJECTION WITH A REAL ERRNO.
//     `FakeFileStore(faults: {7: StorageOsException(32)})` fails the
//     seventh operation the way a real antivirus lock does. This is the
//     capability `package:file`'s MemoryFileSystem cannot provide and the
//     single strongest reason this fake is hand-written.
//
//  4. A PAGE CACHE. Every path is either COMMITTED (its bytes are on the
//     medium) or not, and [FakeFileStore.replayPrefixAfterPowerLoss]
//     turns every uncommitted path into `Indeterminate`. Without this the
//     journal replay models a PROCESS KILL only: it replays each op as
//     individually atomic AND durable, so "power loss" in the crash
//     test's header was a word rather than a modelled case, and a save
//     path that never fsynced would sail through every assertion.
//
//     THE MODELLED ASSUMPTIONS, stated so they can be argued with:
//       * A `rename` and a `delete` are METADATA and are modelled as
//         durable immediately (NTFS journals them). This is the
//         CONSERVATIVE choice for the invariant, not a convenient one: if
//         the rename were also lost, the target would still hold the
//         previous good bytes and I1 would hold trivially. Modelling it
//         as durable is what makes "promote lands, data does not" — the
//         actual torn-file scenario — reachable in the model.
//       * `flush()` is the durability point (see FileSink's contract).
//         `close()` writes what is still buffered and commits nothing.
//       * `writeBytes` and `copy` commit their destination, matching the
//         `flush: true` and the explicit commit in `DartIoFileStore`.
//
// It is kept honest by `file_store_contract_test.dart`, which runs one
// shared suite against BOTH this and `DartIoFileStore`. Without that, the
// forty crash assertions would be testing a fiction. Durability itself is
// the one part of the contract that suite CANNOT observe — nothing short
// of cutting power can — so what is proven mechanically is the ORDERING,
// and the real sink's fsync is held by a source gate in
// `storage_layering_test.dart`.
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';

// --- Content -----------------------------------------------------------

/// What is at a path in the model.
sealed class FileContent {
  const FileContent();
}

/// Exactly these bytes.
@immutable
final class Bytes extends FileContent {
  const Bytes(this.value);

  final Uint8List value;

  @override
  bool operator ==(Object other) =>
      other is Bytes && _sameBytes(other.value, value);

  @override
  int get hashCode => Object.hashAll(value);

  @override
  String toString() => 'Bytes(${value.length})';
}

/// SOME UNKNOWN PREFIX of up to [maxBytes] bytes — the honest state of a
/// file between an `add` and the `flush` that settles it. Any claim about
/// its content is a claim the operating system never made.
@immutable
final class Indeterminate extends FileContent {
  const Indeterminate(this.maxBytes);

  final int maxBytes;

  @override
  bool operator ==(Object other) =>
      other is Indeterminate && other.maxBytes == maxBytes;

  @override
  int get hashCode => maxBytes;

  @override
  String toString() => 'Indeterminate(<=$maxBytes)';
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// --- Operations --------------------------------------------------------

/// One journalled mutation. Every variant carries everything
/// [FsState.apply] needs, so replay is a pure fold with no hidden state.
sealed class FsOp {
  const FsOp();
}

final class MkDir extends FsOp {
  const MkDir(this.path);
  final String path;
  @override
  String toString() => 'MkDir($path)';
}

/// `openWrite` truncated the path to empty and took a handle.
///
/// A DELIBERATE PESSIMISM, recorded rather than left to be discovered:
/// `DartIoFileStore`'s sink opens LAZILY (that is what preserves the
/// measured deferred-error behaviour), so on a real disk the path still
/// holds its previous bytes until the first flush or close. The model
/// empties it immediately. Both states are covered by I3, which makes no
/// claim about `.tmp` or `.bak.tmp` at all, and the model's version is
/// the harsher of the two — so nothing the invariant asserts is weakened
/// by the difference.
final class SinkOpen extends FsOp {
  const SinkOpen(this.handle, this.path);
  final int handle;
  final String path;
  @override
  String toString() => 'SinkOpen(#$handle, $path)';
}

/// Bytes were handed to the sink. The file is now indeterminate.
final class SinkAdd extends FsOp {
  const SinkAdd(this.handle, this.path, this.bufferedLength);
  final int handle;
  final String path;
  final int bufferedLength;
  @override
  String toString() => 'SinkAdd(#$handle, $path, $bufferedLength)';
}

/// The buffer reached the disk AND was committed to the medium. This is
/// the durability point — see [FileSink.flush].
final class SinkFlush extends FsOp {
  const SinkFlush(this.handle, this.path, this.settled);
  final int handle;
  final String path;
  final Uint8List settled;
  @override
  String toString() => 'SinkFlush(#$handle, $path)';
}

/// The handle was released, after writing anything still buffered.
///
/// SETTLES THE CONTENT BUT COMMITS NOTHING. Closing a descriptor does not
/// push the file's pages to the device. [wroteBufferedBytes] records
/// whether this close actually put new bytes in the cache: a close that
/// followed a [SinkFlush] with an empty buffer changes nothing on disk
/// and must not un-commit a path that is already durable.
final class SinkClose extends FsOp {
  const SinkClose(
    this.handle,
    this.path,
    this.settled, {
    required this.wroteBufferedBytes,
  });
  final int handle;
  final String path;
  final Uint8List settled;
  final bool wroteBufferedBytes;
  @override
  String toString() => 'SinkClose(#$handle, $path)';
}

/// A one-shot write began: the destination is truncated and indeterminate.
final class WriteBegin extends FsOp {
  const WriteBegin(this.path, this.length);
  final String path;
  final int length;
  @override
  String toString() => 'WriteBegin($path, $length)';
}

/// A one-shot write completed.
final class WriteEnd extends FsOp {
  const WriteEnd(this.path, this.settled);
  final String path;
  final Uint8List settled;
  @override
  String toString() => 'WriteEnd($path)';
}

/// A copy began. The DESTINATION is indeterminate from here until
/// [CopyEnd] — which is the modelled fact that makes a plain
/// `copy(target, bak)` fail the backup invariant, and therefore the whole
/// argument for the `.bak.tmp` intermediate.
final class CopyBegin extends FsOp {
  const CopyBegin(this.to, this.length);
  final String to;
  final int length;
  @override
  String toString() => 'CopyBegin($to, $length)';
}

final class CopyEnd extends FsOp {
  const CopyEnd(this.to, this.content);
  final String to;
  final FileContent content;
  @override
  String toString() => 'CopyEnd($to)';
}

/// ATOMIC by construction — this is the one operation whose all-or-nothing
/// behaviour the design depends on, and `file_store_contract_test.dart`
/// proves the real filesystem agrees.
final class Renamed extends FsOp {
  const Renamed(this.from, this.to);
  final String from;
  final String to;
  @override
  String toString() => 'Renamed($from -> $to)';
}

final class Deleted extends FsOp {
  const Deleted(this.path);
  final String path;
  @override
  String toString() => 'Deleted($path)';
}

/// Every path an op names.
///
/// EXHAUSTIVE BY CONSTRUCTION: a new [FsOp] that forgets to appear here
/// will not compile, which is what lets a test ask "did this code touch
/// anything under that directory?" without maintaining its own copy of
/// the op list.
List<String> pathsOf(FsOp op) => switch (op) {
  MkDir(:final path) => [path],
  SinkOpen(:final path) => [path],
  SinkAdd(:final path) => [path],
  SinkFlush(:final path) => [path],
  SinkClose(:final path) => [path],
  WriteBegin(:final path) => [path],
  WriteEnd(:final path) => [path],
  CopyBegin(:final to) => [to],
  CopyEnd(:final to) => [to],
  Renamed(:final from, :final to) => [from, to],
  Deleted(:final path) => [path],
};

// --- State -------------------------------------------------------------

/// An immutable filesystem snapshot. [apply] is pure, which is the entire
/// basis of journal-prefix replay.
final class FsState {
  FsState({
    Map<String, FileContent>? files,
    Set<String>? directories,
    Map<int, String>? openHandles,
    Set<String>? uncommitted,
  }) : files = UnmodifiableMapView(Map.of(files ?? const {})),
       directories = UnmodifiableSetView(Set.of(directories ?? const {})),
       openHandles = UnmodifiableMapView(Map.of(openHandles ?? const {})),
       uncommitted = UnmodifiableSetView(Set.of(uncommitted ?? const {}));

  final Map<String, FileContent> files;
  final Set<String> directories;

  /// Sink handles currently open, and the path each writes to. Windows
  /// refuses to rename a file another handle holds open (errno 32), and
  /// this is what lets the fake reproduce that.
  final Map<int, String> openHandles;

  /// Paths whose bytes are in the page cache but have NOT been committed
  /// to the medium. A power cut here loses them; a process kill does not.
  /// See [FakeFileStore.replayPrefixAfterPowerLoss].
  final Set<String> uncommitted;

  /// This state as it would be found after the power was cut at this
  /// instant: every uncommitted path's content becomes indeterminate,
  /// because nothing ever asked the device to write those blocks.
  FsState afterPowerLoss() => FsState(
    files: {
      for (final e in files.entries)
        e.key: uncommitted.contains(e.key)
            ? Indeterminate(switch (e.value) {
                Bytes(:final value) => value.length,
                Indeterminate(:final maxBytes) => maxBytes,
              })
            : e.value,
    },
    directories: directories,
    // Nothing is open after a power cut, and nothing is pending.
    openHandles: const {},
  );

  FsState apply(FsOp op) {
    final nextFiles = Map<String, FileContent>.of(files);
    final nextDirs = Set<String>.of(directories);
    final nextHandles = Map<int, String>.of(openHandles);
    final nextUncommitted = Set<String>.of(uncommitted);

    switch (op) {
      case MkDir(:final path):
        // Directory creation is metadata: journalled, durable.
        nextDirs.add(path);
      case SinkOpen(:final handle, :final path):
        nextFiles[path] = Bytes(Uint8List(0));
        nextHandles[handle] = path;
        // The truncation itself is not committed either.
        nextUncommitted.add(path);
      case SinkAdd(:final path, :final bufferedLength):
        nextFiles[path] = Indeterminate(bufferedLength);
        nextUncommitted.add(path);
      case SinkFlush(:final path, :final settled):
        nextFiles[path] = Bytes(settled);
        // THE DURABILITY POINT.
        nextUncommitted.remove(path);
      case SinkClose(
        :final handle,
        :final path,
        :final settled,
        :final wroteBufferedBytes,
      ):
        nextFiles[path] = Bytes(settled);
        nextHandles.remove(handle);
        // A close that wrote bytes put them in the CACHE and stopped
        // there. A close with nothing left buffered changes nothing, so a
        // path already committed by `flush()` stays committed.
        if (wroteBufferedBytes) nextUncommitted.add(path);
      case WriteBegin(:final path, :final length):
        nextFiles[path] = Indeterminate(length);
        nextUncommitted.add(path);
      case WriteEnd(:final path, :final settled):
        nextFiles[path] = Bytes(settled);
        // `writeBytes` commits (flush: true).
        nextUncommitted.remove(path);
      case CopyBegin(:final to, :final length):
        nextFiles[to] = Indeterminate(length);
        nextUncommitted.add(to);
      case CopyEnd(:final to, :final content):
        nextFiles[to] = content;
        // `copy` commits its destination — see FileStore.copy.
        nextUncommitted.remove(to);
      case Renamed(:final from, :final to):
        final content = nextFiles.remove(from);
        if (content != null) {
          nextFiles[to] = content;
        } else {
          nextFiles.remove(to);
        }
        // THE RENAME IS METADATA AND IS DURABLE; THE DATA IT POINTS AT
        // CARRIES ITS OWN DURABILITY ACROSS. This one line is the whole
        // torn-file scenario: promote an uncommitted tmp and the TARGET
        // is now uncommitted, so a power cut leaves the name the user
        // knows pointing at blocks nobody ever wrote.
        if (nextUncommitted.remove(from)) {
          nextUncommitted.add(to);
        } else {
          nextUncommitted.remove(to);
        }
      case Deleted(:final path):
        nextFiles.remove(path);
        nextUncommitted.remove(path);
    }

    return FsState(
      files: nextFiles,
      directories: nextDirs,
      openHandles: nextHandles,
      uncommitted: nextUncommitted,
    );
  }

  @override
  String toString() =>
      'FsState(${files.entries.map((e) => '${e.key}=${e.value}'
          '${uncommitted.contains(e.key) ? ' UNCOMMITTED' : ''}').join(', ')})';
}

// --- The store ---------------------------------------------------------

final class _FakeSink implements FileSink {
  _FakeSink(this._store, this.handle, this.path);

  final FakeFileStore _store;
  final int handle;
  final String path;
  final BytesBuilder _buffer = BytesBuilder();
  bool closed = false;

  /// How many bytes have been added since the last [flush]. A [close]
  /// with nothing pending puts no new bytes in the cache and therefore
  /// cannot un-commit a path `flush` already made durable.
  int _pendingSinceFlush = 0;

  @override
  void add(Uint8List bytes) {
    _buffer.add(bytes);
    _pendingSinceFlush += bytes.length;
    // NOTE: the journal records this SYNCHRONOUSLY and the content becomes
    // indeterminate immediately, matching `IOSink.add`'s own fire-and-
    // forget contract.
    _store._record(SinkAdd(handle, path, _buffer.length));
  }

  @override
  Future<void> flush() async {
    _store
      .._maybeFail('flush')
      // THE DEFERRED ERROR. `openWrite` accepted a bad path without a
      // murmur (measured); this is where it surfaces, as errno 3. The
      // contract test caught this being missing — the fake had been
      // silently succeeding where NTFS fails, which would have made two of
      // the crash test's interruption points imaginary.
      .._requireParent(path)
      .._record(SinkFlush(handle, path, _buffer.toBytes()));
    _pendingSinceFlush = 0;
  }

  @override
  Future<void> close() async {
    _store
      .._maybeFail('close')
      .._requireParent(path);
    closed = true;
    _store._record(
      SinkClose(
        handle,
        path,
        _buffer.toBytes(),
        wroteBufferedBytes: _pendingSinceFlush > 0,
      ),
    );
    _pendingSinceFlush = 0;
  }
}

final class _FakeLease implements FileLease {
  _FakeLease(this._store, this.path);

  final FakeFileStore _store;
  final String path;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _store._leases.remove(path);
  }
}

/// An in-memory [FileStore] with a replayable journal and injectable
/// faults.
final class FakeFileStore implements FileStore {
  FakeFileStore({
    Map<String, Uint8List>? initialFiles,
    Set<String>? initialDirectories,
    this.faults = const {},
    this.hangingPaths = const {},
    this.readOnlyPaths = const {},
    this.undeletablePaths = const {},
    this.windowsSemantics = true,
    Map<String, int>? failRenamesTo,
    this.failReadsOf = const {},
    DateTime? clock,
  }) : failRenamesTo = Map.of(failRenamesTo ?? const {}),
       _clock = clock ?? DateTime.utc(2026, 7, 26, 14, 32, 11) {
    _state = FsState(
      files: {
        for (final e in (initialFiles ?? const <String, Uint8List>{}).entries)
          e.key: Bytes(e.value),
      },
      directories: initialDirectories ?? const {},
    );
    _initial = _state;
  }

  /// Throw this exception on the operation with this index. Indices count
  /// EVERY mutating or observing call in submission order, starting at 0,
  /// which is what lets a test sweep `for (var k = 0; k < n; k++)`.
  final Map<int, Object> faults;

  /// Paths whose `exists` future NEVER completes — an unreachable network
  /// share. Used to prove that nothing on the startup path awaits one.
  final Set<String> hangingPaths;

  /// Paths reported as read-only by [stat].
  final Set<String> readOnlyPaths;

  /// Whether rename reproduces Windows' sharing semantics (errno 32 when
  /// the source is held open by another handle). POSIX permits it.
  final bool windowsSemantics;

  /// Destination path -> how many renames onto it fail with errno 32
  /// before one succeeds. Models a real-time antivirus scanner holding a
  /// just-created file for a moment.
  ///
  /// Targeted BY PATH rather than by operation index on purpose: the
  /// retry budget is a property of the promote step, and a test that had
  /// to first discover the promote's numeric index would be testing its
  /// own arithmetic as much as the engine.
  final Map<String, int> failRenamesTo;

  /// Paths whose `delete` always fails with errno 32.
  ///
  /// The same modelled fact as [failRenamesTo] — a scanner or an indexer
  /// holding ONE file open — and targeted by path for the same reason. It
  /// exists because a best-effort delete that FAILED is the only way a
  /// caller reaches its next write with the file it just tried to retire
  /// still on disk, and that state is the only one some `keepBackup:
  /// false` arguments are observable from at all.
  ///
  /// NOT MEASURED AGAINST THE REAL FILESYSTEM, unlike the open-handle
  /// rename this mirrors (`rename-open-source => errno 32` in
  /// file_store_contract_test.dart): reproducing it needs a second handle
  /// opened without `FILE_SHARE_DELETE`, which POSIX has no equivalent of.
  /// Nothing under test reads the errno — every caller of a best-effort
  /// delete only cares THAT it failed — so the number here is colour, and
  /// the modelled fact is "this delete does not happen".
  final Set<String> undeletablePaths;

  /// Path -> the exception `readBytes` throws for it, AFTER `stat` and
  /// `exists` have answered normally.
  ///
  /// The state `DocumentStore.open`'s `_classifyOpen` exists for and no
  /// test reached until #947: a file that was there a moment ago and then
  /// could not be read. A share dropping mid-read, a file deleted between
  /// the check and the read, a permission change, another program's lock.
  /// Targeted by path for [failRenamesTo]'s reason: an op index would make
  /// the test depend on how many calls `open` makes first.
  final Map<String, Object> failReadsOf;

  final DateTime _clock;

  late FsState _state;
  late FsState _initial;
  final List<FsOp> _journal = [];
  final List<String> _calls = [];
  int _nextHandle = 0;
  int _opIndex = 0;

  /// The state as it is right now.
  FsState get state => _state;

  /// The state before any operation ran — the `s0` a replay folds from.
  FsState get initialState => _initial;

  /// Every mutation, in order.
  List<FsOp> get journal => List.unmodifiable(_journal);

  /// Every store method INVOKED, by name, in order — `exists`, `delete`,
  /// `rename`, `stat`, ... including the ones that then threw.
  ///
  /// [journal] records EFFECTS; this records ATTEMPTS, and the two differ
  /// in exactly one place: where a guard decided not to make a call. A
  /// `delete if present` whose existence check was deleted still leaves an
  /// empty journal — the delete throws errno 2 and the caller swallows it —
  /// so the journal cannot tell the guarded code from the unguarded code.
  /// This can.
  List<String> get calls => List.unmodifiable(_calls);

  /// How many store operations have been invoked. The domain of [faults].
  int get operationCount => _opIndex;

  /// Replays the first [count] journal entries onto [initialState].
  /// THE WHOLE POINT OF THIS CLASS.
  ///
  /// Models a PROCESS KILL: Task Manager, `WM_QUERYENDSESSION` with no
  /// grace, a segfault. The operating system is still running, so
  /// everything in its page cache still reaches the disk.
  FsState replayPrefix(int count) =>
      _journal.take(count).fold(_initial, (s, op) => s.apply(op));

  /// The same prefix, but the POWER WAS CUT rather than the process
  /// killed: anything that reached only the page cache is gone.
  ///
  /// This is a strictly harsher instant than [replayPrefix] and it is the
  /// one that catches a save path which renames without committing first.
  FsState replayPrefixAfterPowerLoss(int count) =>
      replayPrefix(count).afterPowerLoss();

  /// Clears the journal and [calls] and re-bases [initialState] on the
  /// current state, so a second save can be replayed independently of the
  /// first.
  void resetJournal() {
    _journal.clear();
    _calls.clear();
    _initial = _state;
  }

  void _record(FsOp op) {
    _journal.add(op);
    _state = _state.apply(op);
  }

  void _maybeFail(String what) {
    // RECORDED BEFORE THE FAULT: an operation that was invoked and then
    // threw was still invoked, and "was this call made at all" is the
    // question [calls] exists to answer.
    _calls.add(what);
    final index = _opIndex++;
    final fault = faults[index];
    if (fault != null) {
      Error.throwWithStackTrace(fault, StackTrace.current);
    }
  }

  void _requireFile(String path) {
    if (!_state.files.containsKey(path)) {
      throw StorageOsException(
        windowsSemantics ? 2 : 2,
        'no such file: $path',
      );
    }
  }

  void _requireParent(String path) {
    final parent = _parentOf(path);
    if (parent != null && !_state.directories.contains(parent)) {
      throw StorageOsException(
        windowsSemantics ? 3 : 2,
        'no such directory: $parent',
      );
    }
  }

  static String? _parentOf(String path) {
    final slash = path.lastIndexOf(RegExp(r'[\\/]'));
    if (slash <= 0) return null;
    return path.substring(0, slash);
  }

  @override
  Future<bool> exists(String path) async {
    _maybeFail('exists');
    if (hangingPaths.contains(path)) {
      // Never completes. Anything that awaits this on the startup path
      // hangs the app, which is exactly what the test asserts does not
      // happen.
      return Completer<bool>().future;
    }
    return _state.files.containsKey(path) || _state.directories.contains(path);
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    _maybeFail('readBytes');
    if (failReadsOf[path] case final fault?) {
      Error.throwWithStackTrace(fault, StackTrace.current);
    }
    _requireFile(path);
    final content = _state.files[path]!;
    return switch (content) {
      Bytes(:final value) => value,
      // Reading an un-flushed file in the model is a test bug, not a
      // filesystem behaviour worth simulating. Say so loudly.
      Indeterminate() => throw StateError(
        'readBytes($path) on indeterminate content — the model cannot '
        'invent bytes the OS never committed',
      ),
    };
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _maybeFail('writeBytes');
    _requireParent(path);
    if (readOnlyPaths.contains(path)) {
      throw const StorageOsException(5, 'read-only');
    }
    // TWO ops on purpose: a one-shot write is not atomic either, and
    // modelling it as one op would quietly promise something false. The
    // document path does not use this — it goes through AtomicWriter.
    _record(WriteBegin(path, bytes.length));
    _record(WriteEnd(path, Uint8List.fromList(bytes)));
  }

  @override
  Future<FileSink> openWrite(String path) async {
    _maybeFail('openWrite');
    // DELIBERATELY DOES NOT VALIDATE THE PATH. Measured on Windows:
    // openWrite into a missing directory does NOT throw — the error is
    // deferred to flush/close. The fake reproduces the deferral, which is
    // what the contract test pins down and what makes the crash test's
    // two interruption points real.
    final handle = _nextHandle++;
    _record(SinkOpen(handle, path));
    return _FakeSink(this, handle, path);
  }

  @override
  Future<void> rename(String from, String to) async {
    _maybeFail('rename');
    final remaining = failRenamesTo[to] ?? 0;
    if (remaining > 0) {
      failRenamesTo[to] = remaining - 1;
      throw const StorageOsException(32, 'antivirus holds the source');
    }
    _requireFile(from);
    if (windowsSemantics && _state.openHandles.containsValue(from)) {
      // Measured: renaming a source another process holds open fails with
      // ERROR_SHARING_VIOLATION. This is what antivirus does.
      throw const StorageOsException(32, 'source is open');
    }
    if (windowsSemantics && _state.openHandles.containsValue(to)) {
      throw const StorageOsException(5, 'destination is open');
    }
    if (readOnlyPaths.contains(to)) {
      throw const StorageOsException(5, 'destination is read-only');
    }
    _requireParent(to);
    // ONE op: rename REPLACES the destination atomically. The contract
    // test proves the real filesystem does the same.
    _record(Renamed(from, to));
  }

  @override
  Future<void> copy(String from, String to) async {
    _maybeFail('copy');
    _requireFile(from);
    _requireParent(to);
    if (readOnlyPaths.contains(to)) {
      throw const StorageOsException(5, 'destination is read-only');
    }
    final content = _state.files[from]!;
    final length = switch (content) {
      Bytes(:final value) => value.length,
      Indeterminate(:final maxBytes) => maxBytes,
    };
    // A copy TEARS if interrupted. Two ops.
    _record(CopyBegin(to, length));
    _record(CopyEnd(to, content));
  }

  @override
  Future<void> delete(String path) async {
    _maybeFail('delete');
    _requireFile(path);
    if (undeletablePaths.contains(path)) {
      throw const StorageOsException(32, 'a handle is open on the file');
    }
    _record(Deleted(path));
  }

  @override
  Future<void> createDirectory(String path) async {
    _maybeFail('createDirectory');
    // Recursive: every ancestor comes into existence too.
    final segments = path.split(RegExp(r'[\\/]'));
    var accumulated = '';
    for (var i = 0; i < segments.length; i++) {
      accumulated = i == 0 ? segments[i] : '$accumulated\\${segments[i]}';
      if (accumulated.isNotEmpty) _record(MkDir(accumulated));
    }
    _record(MkDir(path));
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    _maybeFail('listDirectory');
    if (!_state.directories.contains(path)) {
      throw StorageOsException(
        windowsSemantics ? 3 : 2,
        'no such directory: $path',
      );
    }
    return [
      for (final file in _state.files.keys)
        if (_parentOf(file) == path) file,
    ];
  }

  /// Paths a live holder currently has a lease on.
  ///
  /// A test that wants "another instance of RackPal is running right now"
  /// takes a lease on that instance's path and simply does not release it
  /// — which is exactly what the real store's kernel-held lock models, and
  /// is the only way an in-process suite can construct two instances.
  final Set<String> _leases = <String>{};

  /// MODELS A PROCESS DYING: every lease it held is dropped by the
  /// kernel, and every lease FILE it created is still on disk.
  ///
  /// This is the only way an in-process suite can construct "instance one
  /// crashed". Without it, a `TestSession` built to play the crashed
  /// instance goes on holding its lease for the rest of the test and the
  /// relaunch correctly refuses to touch its pair — the fake would be
  /// modelling a first instance that is still running, which is a
  /// different scenario with a different right answer.
  void releaseAllLeases() => _leases.clear();

  /// The same thing for ONE process, when a test needs two instances and
  /// only one of them to die.
  void releaseLease(String path) => _leases.remove(path);

  @override
  Future<FileLease?> acquireLease(String path) async {
    _maybeFail('acquireLease');
    if (_leases.contains(path)) return null;
    // The real implementation answers `null` for a directory that is not
    // there, because `File.open` throws and every failure is "no lease".
    final parent = _parentOf(path);
    if (parent != null && !_state.directories.contains(parent)) return null;
    if (!_state.files.containsKey(path)) {
      // `FileMode.append` creates the file. Modelled with the ordinary
      // one-shot write ops so the journal stays a complete account of
      // what is on disk.
      _record(WriteBegin(path, 0));
      _record(WriteEnd(path, Uint8List(0)));
    }
    _leases.add(path);
    return _FakeLease(this, path);
  }

  @override
  Future<FileFacts?> stat(String path) async {
    _maybeFail('stat');
    final content = _state.files[path];
    if (content == null) return null;
    final size = switch (content) {
      Bytes(:final value) => value.length,
      Indeterminate(:final maxBytes) => maxBytes,
    };
    return FileFacts(
      size: size,
      modified: _clock,
      readOnly: readOnlyPaths.contains(path),
    );
  }
}
