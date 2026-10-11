// The atomic save engine (docs/03-architecture.md §9.3) and the
// single-flight queue every writer in this layer shares.
//
// ============================================================
// THE INVARIANT, STATED PRECISELY — this is what the tests check
// ============================================================
// For every instant during a save of a document whose previous good bytes
// are OLD and whose new bytes are NEW:
//
//   I1. <target>.rppj EXISTS and its content is exactly OLD or exactly
//       NEW. Never partial, never indeterminate, never absent.
//       (Weakened for a FIRST save, where "OLD" is "the file is not
//       there"; the crash test parameterises over both.)
//   I2. <target>.rppj.bak, if present, is exactly OLD or a complete
//       older version. Never partial.
//   I3. <target>.rppj.tmp and <target>.rppj.bak.tmp may be absent,
//       empty, partial or complete. No claim is made about them.
//   I4. No file exists in the user's directory other than those four
//       names (CR-098).
//   I5. The recovery snapshot is deleted only AFTER I1 holds with NEW.
//   I6. At completion, .bak holds OLD.
//
// I1 AND I2 HOLD UNDER POWER LOSS, NOT MERELY UNDER A PROCESS KILL. The
// difference is not academic and it is where this engine was wrong. A
// process kill leaves the OS running, so everything in its page cache
// still reaches the disk; a power cut does not. NTFS journals the
// directory-entry update a `rename` makes, so a promote of a tmp whose
// data extents were never committed lands a valid NAME over invalid
// BYTES: `Smith.rppj` opens as corrupt, and the `.bak` beside it
// holds the version from BEFORE the save that appeared to succeed.
//
// The fix is one word in the seam's contract — `FileSink.flush()` and
// `FileStore.copy()` COMMIT, they do not merely write — and the proof is
// mechanical: `FakeFileStore` models a page cache, and the crash suite
// replays every journal prefix under power-loss semantics as well as
// under a kill.
//
// ============================================================
// A DELIBERATE, DOCUMENTED DEVIATION FROM §9.3's STEP 4
// ============================================================
// §9.3 step 4 says: rename <target> to <target>.bak. Step 5 then renames
// the tmp into place. BETWEEN THOSE TWO STEPS, <target>.rppj DOES NOT
// EXIST. A hard kill in that window leaves the user's folder with no file
// at the name they know: they open Explorer and their job is gone, sitting
// next to something called `Smith.rppj.bak` that Windows will not open
// on a double-click. So §9.3's own stated guarantee — "a crash at any step
// leaves either the previous good file, or the previous good file plus a
// .tmp" — is literally false under a rename-based step 4.
//
// This engine keeps the GUARANTEE and changes the MECHANISM: step 4 copies
// target -> bak.tmp and then renames bak.tmp -> bak. The target is present
// at every instant, and the .bak still lands atomically.
//
// The naive `copy target -> bak` is ALSO rejected, and for a sharper
// reason: an interrupted copy leaves a TORN .bak. A torn .bak that happens
// to parse as valid JSON is a silent corruption vector — the user opens
// their backup after a crash and gets a plausible-looking project with
// half their devices missing. Copy-to-a-temp-then-rename means a .bak that
// exists is always complete.
//
// Step 5 does not need step 4 to clear the way: `File.rename` REPLACES an
// existing destination on Windows (measured). The contract test pins that.
//
// COST: one extra read + write of ~600 KB per save of an existing file,
// plus two `FlushFileBuffers` calls (the tmp and the backup copy).
// Listed as a risk to measure against the 150 ms p95 budget; the fallback
// if it blows the budget is to back up less often, which weakens the
// BACKUP rather than the crash invariant. The tmp's commit is NOT on that
// list — it is the one thing here that cannot be traded away, because
// without it a save that reports success can still be lost entirely.
import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What a successful [AtomicWriter.write] produced.
final class WriteReceipt {
  const WriteReceipt({
    required this.paths,
    required this.baseline,
    required this.bytesWritten,
    required this.backupAttempted,
    required this.backupUpdated,
    required this.sweptStrays,
  });

  final SavePaths paths;

  /// The (size, modified) of the file just written — the baseline the
  /// NEXT save's external-change check compares against.
  ///
  /// [FileBaseline.unknown] when the post-promote re-stat could not
  /// answer. NEVER [FileBaseline.absent]: the file is unquestionably
  /// there, and claiming otherwise makes the next save accuse a sync
  /// client of a modification that never happened.
  final FileBaseline baseline;

  final int bytesWritten;

  /// Whether step 4 ran at all — false for a FIRST save (there was
  /// nothing to copy) and for the app's own small JSON stores
  /// (`keepBackup: false`).
  ///
  /// SEPARATE FROM [backupUpdated] BECAUSE THE STATUS LINE WOULD
  /// OTHERWISE LIE. "Saved. The backup copy could not be updated." is
  /// true and useful after an overwrite whose `.bak` failed; after the
  /// very first save of a new file it is a report of a failure that never
  /// happened, and a status line that cries wolf on every new document is
  /// one nobody reads by the time it matters.
  final bool backupAttempted;

  /// False when the backup could not be produced. The save still
  /// SUCCEEDED — a `.bak` that could not be refreshed is not a reason to
  /// refuse to write the user's document. Surfaces as a status line
  /// ("Saved. The backup copy could not be updated."), never a dialog,
  /// and never silence.
  final bool backupUpdated;

  /// How many stale `.tmp` / `.bak.tmp` siblings from an earlier
  /// interrupted save were cleaned up.
  final int sweptStrays;
}

/// How many times the promote step retries, and how long it waits.
///
/// MEASURED JUSTIFICATION: renaming a source file that another process
/// holds open fails with errno 32 (`ERROR_SHARING_VIOLATION`). Real-time
/// antivirus opens a file the instant it is created, which is exactly the
/// file we are about to rename. Three tries with backoff is the standard
/// mitigation. It is a HEURISTIC, not a guarantee — but under this
/// engine's ordering an exhausted retry budget is SAFE: the target is
/// still the previous good file, so the user retries rather than loses
/// anything.
const List<Duration> kPromoteRetryBackoff = [
  Duration(milliseconds: 50),
  Duration(milliseconds: 150),
  Duration(milliseconds: 400),
];

/// Runs asynchronous work strictly one at a time, in submission order.
///
/// EVERY writer in this layer shares one instance: explicit saves, the
/// autosave snapshot, recents and prefs. Without it, a 30 s autosave
/// firing mid-save can interleave two renames over the same paths and
/// produce a stray file (I4) or promote the wrong bytes (I1). With it,
/// the interleaving is impossible by construction rather than by timing
/// luck.
final class SaveQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// True while anything is queued or running. The autosave scheduler
  /// reads this to skip a snapshot rather than pile one up behind an
  /// explicit save the user is watching.
  bool get busy => _pending > 0;

  /// Enqueues [action], resolving with its result once every previously
  /// enqueued action has finished.
  Future<T> add<T>(Future<T> Function() action) {
    _pending++;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (e, st) {
        // The queue must survive a failing member: a wedged queue would
        // silently disable saving for the rest of the session, which is
        // the worst possible failure mode for this class.
        completer.completeError(e, st);
      } finally {
        _pending--;
      }
    });
    return completer.future;
  }
}

/// The atomic save engine. Filesystem only: it knows nothing of dialogs,
/// windows, documents or Flutter, which is why the whole crash-safety
/// story is testable with no UI and no disk.
///
/// Also serves the recovery snapshot, recents and prefs writers via
/// `keepBackup: false`, so those three get the crash-safety tests for
/// free instead of each reinventing tmp+rename slightly differently.
final class AtomicWriter {
  AtomicWriter({
    required this.fs,
    required this.queue,
    p.Context? context,
    this.retryBackoff = kPromoteRetryBackoff,
    this.delay = Future.delayed,
    this.isWindows = true,
  }) : context = context ?? p.context;

  final FileStore fs;
  final SaveQueue queue;
  final p.Context context;
  final List<Duration> retryBackoff;

  /// How the promote retry waits. Injected so no test in this layer ever
  /// sleeps — a grep test asserts there is no `Future.delayed` in the
  /// storage test tree.
  final Future<void> Function(Duration) delay;

  /// Which errno table [osErrorToCategory] should consult. Injected
  /// rather than read from `Platform` so a Windows-shaped failure is
  /// testable on a Linux CI runner.
  final bool isWindows;

  /// Writes [bytes] to `paths.target` atomically.
  ///
  /// [expected] is the baseline captured at open or at the last save; the
  /// pre-flight refuses when the file on disk no longer matches it. Pass
  /// `null` to skip the check (a Save As to a brand-new name, or an
  /// explicit Overwrite after the user was asked).
  ///
  /// [keepBackup] false skips step 4 entirely — right for the app's own
  /// small JSON stores, which are cheap to regenerate and would double
  /// their write cost for nothing.
  Future<Outcome<WriteReceipt>> write({
    required SavePaths paths,
    required Uint8List bytes,
    FileBaseline? expected,
    bool keepBackup = true,
  }) => queue.add(
    () => _write(
      paths: paths,
      bytes: bytes,
      expected: expected,
      keepBackup: keepBackup,
    ),
  );

  /// [write] never throws (CR-093): every failure, including one nobody
  /// anticipated, comes back as an `Err`. The fine-grained handlers below
  /// classify the failures that have specific copy; this outer guard
  /// exists so that a filesystem doing something genuinely novel still
  /// reaches the user as a reported refusal rather than as an unhandled
  /// future that silently loses their save.
  Future<Outcome<WriteReceipt>> _write({
    required SavePaths paths,
    required Uint8List bytes,
    required FileBaseline? expected,
    required bool keepBackup,
  }) async {
    try {
      return await _writeGuarded(
        paths: paths,
        bytes: bytes,
        expected: expected,
        keepBackup: keepBackup,
      );
    } on Object catch (e, st) {
      return Err(_classify(e, st, paths, step: -1, keepBackup: keepBackup));
    }
  }

  Future<Outcome<WriteReceipt>> _writeGuarded({
    required SavePaths paths,
    required Uint8List bytes,
    required FileBaseline? expected,
    required bool keepBackup,
  }) async {
    // --- STEP 0: PRE-FLIGHT. One stat, no writes. -------------------
    final SaveError? preflight;
    final bool targetExisted;
    try {
      preflight = await _preflight(paths, expected, keepBackup: keepBackup);
      targetExisted = preflight == null && await fs.stat(paths.target) != null;
    } on Object catch (e, st) {
      // A pre-flight that cannot even ask the questions is itself the
      // answer: an unplugged drive fails `exists` before it fails
      // anything else, and it must arrive as SaveUnreachable rather than
      // as an unhandled exception.
      return Err(_classify(e, st, paths, step: 0, keepBackup: keepBackup));
    }
    if (preflight != null) return Err(preflight);

    // --- STEP 3: WRITE THE TMP. -------------------------------------
    // (Steps 1 and 2 — snapshot the document, serialize off-thread — are
    // the caller's; this engine receives finished bytes precisely so it
    // has nothing to do with the document object graph.)
    //
    // openWrite / add / flush / close are kept as four separate calls
    // because openWrite's errors are DEFERRED (measured: writing into a
    // missing directory does not throw from openWrite, it surfaces from
    // flush/close). Collapsing them into one writeBytes would hide two of
    // the interruption points the invariant test enumerates.
    //
    // THE flush() IS THE DURABILITY POINT AND IS LOAD-BEARING. This note
    // used to say the opposite — that `close()` settles the content, so
    // removing the flush was not a behavioural change and no test caught
    // it. That was true of the old `IOSink`-backed sink and it was the
    // bug: `IOSink.flush()` waits for `write(2)` and never asks the device
    // to commit, so a power cut a second after this "completed" left NTFS
    // with a journalled rename pointing at data extents nobody had
    // written — a torn `<target>.rppj`, which is invariant I1's
    // direct negation.
    //
    // `FileSink.flush()` is now specified as an fsync and `close()`
    // promises no durability at all. Deleting this line is therefore a
    // real behavioural change, and TEST A's power-loss sweep in
    // atomic_writer_crash_test.dart fails when it goes: the promoted
    // target replays as `Indeterminate`.
    FileSink? open;
    try {
      final sink = await fs.openWrite(paths.temp);
      open = sink;
      sink.add(bytes);
      await sink.flush();
      await sink.close();
      open = null;
    } on Object catch (e, st) {
      // THE HANDLE MUST BE RELEASED EVEN THOUGH THE WRITE FAILED. This
      // was found by the fault-injection sweep rather than by reasoning:
      // a `flush` that throws leaves the sink open, and on Windows an
      // open handle makes every subsequent rename of that path fail with
      // ERROR_SHARING_VIOLATION — so ONE failed save would poison every
      // save for the rest of the session, and the tmp could not even be
      // swept. `atomic_writer_crash_test.dart`'s "the queue is not
      // wedged" assertion is what caught it.
      if (open != null) {
        try {
          await open.close();
          // Closing a sink whose write already failed will often fail
          // too. Nothing here may mask the original error.
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {}
      }
      // The partial .tmp is garbage, and on the disk-full path it is
      // occupying the very space the user needs. Sweep it best-effort;
      // never let the sweep mask the original error either.
      await _deleteIfPresent(paths.temp);
      return Err(_classify(e, st, paths, step: 3, keepBackup: keepBackup));
    }

    // --- STEP 4: PRODUCE THE BACKUP. Best-effort. -------------------
    var backupUpdated = false;
    final backupAttempted = keepBackup && targetExisted;
    if (backupAttempted) {
      try {
        await fs.copy(paths.target, paths.backupTemp);
        await fs.rename(paths.backupTemp, paths.backup);
        backupUpdated = true;
      } on Object catch (_) {
        // A read-only .bak, or a volume that filled between the tmp write
        // and here. THIS DOES NOT FAIL THE SAVE. The user's document is
        // what matters and it is about to be written correctly; refusing
        // to save because the backup could not be refreshed would be
        // strictly worse than saving without one. Reported, never silent.
        await _deleteIfPresent(paths.backupTemp);
        logStorageEvent('backup_update_failed', {'step': 4});
      }
    }

    // --- STEP 5: PROMOTE. -------------------------------------------
    final promoteError = await _promoteWithRetry(paths, keepBackup: keepBackup);
    if (promoteError != null) {
      // The target is STILL the previous good file. That is the entire
      // point of producing the backup by copy rather than by rename.
      //
      // ==========================================================
      // THE .tmp STAYS. DELETING IT HERE DESTROYS THE ONLY DURABLE
      // COPY OF THE USER'S WORK.
      // ==========================================================
      // Steps 0-4 all succeeded, so `<target>.tmp` holds a COMPLETE,
      // committed copy of the new bytes. The promote is the only thing
      // that failed — antivirus holding the file, a permission flicker.
      // At this exact instant the tmp can be the only durable copy in
      // existence: the user opened the file, worked for 20 seconds (the
      // 30 s autosave has not fired and the window never blurred, so
      // there is NO recovery snapshot), and hit Ctrl+S. Sweeping the tmp
      // means an error dialog goes up and a power cut or a force-kill
      // from there loses the work outright.
      //
      // Keeping it costs nothing that matters. It is one of the four
      // names CR-098 permits (I4), invariant I3 makes no claim about it,
      // and the next successful save of this target sweeps it at step 8.
      // A recoverable stray beats an unrecoverable absence.
      //
      // The STEP 3 failure path above still deletes its tmp, and that is
      // the right call there: those bytes are a partial write, worth
      // nothing, and on the disk-full path they occupy the very space the
      // user needs.
      logStorageEvent('promote_failed_tmp_retained', {
        'bytes': bytes.length,
      });
      return Err(promoteError);
    }

    // --- STEP 8 (the filesystem half): sweep and re-baseline. --------
    // Steps 6 (markSavedAt) and 7 (delete the recovery snapshot) belong
    // to the caller, which owns the document and the recovery store. They
    // are sequenced there, in DocumentStore.
    final swept = await _sweepStrays(paths);
    // Best-effort: the bytes ARE on disk. Failing the save because the
    // re-stat afterwards did not answer would throw away a write that
    // succeeded.
    //
    // AND WHEN IT DOES NOT ANSWER, THE BASELINE IS `unknown`, NOT
    // `absent`. `FileBaseline.of(null)` means "there was no file", which
    // is a POSITIVE CLAIM and a false one: the promote just succeeded, so
    // there certainly is a file. Recording absent makes the user's very
    // next Ctrl+S fail `FileBaseline.matches` and be refused with
    // `SaveChangedOnDisk` — a dialog that asserts a second copy of
    // RackPal or a sync client wrote to their file when nothing did.
    // Reachable for real: `FileStat.stat` answers notFound on a network
    // share hiccup, and an antivirus scanner can briefly hold a file it
    // has just seen renamed.
    FileFacts? facts;
    try {
      facts = await fs.stat(paths.target);
      // The bytes ARE on disk; nothing that happens after that may turn a
      // successful save into a failure.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      facts = null;
    }
    // A `null` with no throw carries the same amount of knowledge as a
    // throw: the file is there — we renamed it into place — and stat will
    // not say what it is.
    final baseline = facts == null
        ? FileBaseline.unknown
        : FileBaseline.of(facts);
    if (facts == null) logStorageEvent('save_restat_unavailable', {'step': 8});

    logStorageEvent('save_ok', {
      'bytes': bytes.length,
      'backupAttempted': backupAttempted,
      'backupUpdated': backupUpdated,
      'swept': swept,
      ...pathShape(paths.target, context: context),
    });

    return Ok(
      WriteReceipt(
        paths: paths,
        baseline: baseline,
        bytesWritten: bytes.length,
        backupAttempted: backupAttempted,
        backupUpdated: backupUpdated,
        sweptStrays: swept,
      ),
    );
  }

  /// Step 0. Everything that can be known before a single byte moves.
  Future<SaveError?> _preflight(
    SavePaths paths,
    FileBaseline? expected, {
    required bool keepBackup,
  }) async {
    // MAX_PATH first: it is pure arithmetic and costs nothing.
    //
    // MEASURED AGAINST WHAT THIS SAVE WILL ACTUALLY WRITE, not against
    // all four names. A `keepBackup: false` writer never creates
    // `.bak.tmp`, and that name is eight characters longer than the
    // target — see `SavePaths.pathsWritten`.
    if (isWindows && paths.exceedsWindowsMaxPath(keepBackup: keepBackup)) {
      return SavePathTooLong(
        paths: paths,
        length: paths.longestPathLength(keepBackup: keepBackup),
      );
    }

    if (!await fs.exists(paths.directory)) {
      return SaveDirectoryMissing(paths);
    }

    final facts = await fs.stat(paths.target);
    if (facts != null && facts.readOnly) {
      // Caught here rather than at openWrite so nothing on disk has
      // changed when we tell the user. There is deliberately no "make it
      // writable and retry" button downstream: silently clearing the
      // read-only attribute on a file somebody marked protected is not
      // ours to do.
      return SaveReadOnlyTarget(paths);
    }

    if (expected != null && !expected.matches(facts)) {
      // Two instances of the app, or a OneDrive/Dropbox client syncing
      // underneath us. NOT in §9.3 — added deliberately, because nothing
      // else in this design stands between that and silently destroying
      // someone's work. Costs one stat and adds no file to the folder.
      return SaveChangedOnDisk(
        paths: paths,
        expected: expected,
        found: facts,
      );
    }

    return null;
  }

  /// Step 5, with the antivirus retry budget.
  Future<SaveError?> _promoteWithRetry(
    SavePaths paths, {
    required bool keepBackup,
  }) async {
    for (var attempt = 0; attempt <= retryBackoff.length; attempt++) {
      try {
        await fs.rename(paths.temp, paths.target);
        return null;
      } on Object catch (e, st) {
        final error = _classify(e, st, paths, step: 5, keepBackup: keepBackup);
        final retryable = error is SaveLocked || error is SavePermissionDenied;
        if (!retryable || attempt == retryBackoff.length) {
          logStorageEvent('promote_failed', {
            'step': 5,
            'attempts': attempt + 1,
          });
          return error;
        }
        await delay(retryBackoff[attempt]);
      }
    }
    // Unreachable: the loop either returns null on success or returns the
    // error on the final attempt.
    return null;
  }

  /// Step 8's sweep: a `.tmp` or `.bak.tmp` left by an EARLIER interrupted
  /// save of this same document. Best-effort — a stray we cannot remove is
  /// untidy, not dangerous, and must never fail a save that worked.
  Future<int> _sweepStrays(SavePaths paths) async {
    var swept = 0;
    for (final stray in [paths.temp, paths.backupTemp]) {
      if (await _deleteIfPresent(stray)) swept++;
    }
    return swept;
  }

  Future<bool> _deleteIfPresent(String path) async {
    try {
      if (!await fs.exists(path)) return false;
      await fs.delete(path);
      return true;
      // Best-effort cleanup: whatever went wrong here must not replace
      // the error the caller is actually reporting.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return false;
    }
  }

  /// Turns a thrown filesystem error into the specific [SaveError] the UI
  /// has copy for. The errno tables live in errors.dart; this only
  /// supplies the two facts that disambiguate them.
  SaveError _classify(
    Object error,
    StackTrace stackTrace,
    SavePaths paths, {
    required int step,
    required bool keepBackup,
  }) {
    final errno = errnoOf(error);
    if (errno == null) {
      return SaveUnexpected(
        paths: paths,
        step: step,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    final category = osErrorToCategory(
      errno,
      isWindows: isWindows,
      // At this point we are inside a failing save whose pre-flight
      // already confirmed the directory existed, so errno 3 can only mean
      // length. Passing `true` is the disambiguation, not an assumption.
      parentDirExists: true,
    );
    return switch (category) {
      StorageFailure.diskFull => SaveDiskFull(paths: paths, step: step),
      StorageFailure.unreachable => SaveUnreachable(paths: paths, step: step),
      StorageFailure.locked => SaveLocked(paths: paths, step: step),
      StorageFailure.pathTooLong => SavePathTooLong(
        paths: paths,
        length: paths.longestPathLength(keepBackup: keepBackup),
      ),
      StorageFailure.directoryMissing ||
      StorageFailure.fileMissing => SaveDirectoryMissing(paths),
      StorageFailure.readOnlyTarget => SaveReadOnlyTarget(paths),
      StorageFailure.permissionDenied => SavePermissionDenied(
        paths: paths,
        step: step,
      ),
      StorageFailure.unknown => SaveUnexpected(
        paths: paths,
        step: step,
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }
}

/// Pulls the OS error code out of a thrown filesystem error.
///
/// Deliberately duck-typed rather than `is FileSystemException`: this file
/// must stay `dart:io`-free (io_file_store.dart is the only file allowed
/// to import it), and the fake throws its own equivalent. Both expose the
/// same two-level `osError.errorCode` shape, which is the actual contract.
int? errnoOf(Object error) {
  if (error is StorageOsException) return error.errorCode;
  try {
    // Dynamic on purpose: this file must stay `dart:io`-free, so it
    // cannot name `FileSystemException` to type the access. The shape
    // `.osError.errorCode` IS the contract, and both `dart:io` and the
    // fake honour it.
    final osError = (error as dynamic).osError;
    if (osError == null) return null;
    // Same reason as above.
    // ignore: avoid_dynamic_calls
    final code = osError.errorCode;
    return code is int ? code : null;
    // Anything that does not have `.osError.errorCode` simply is not an
    // OS error, which is a legitimate answer and not an exceptional one.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
}

/// The fake filesystem's stand-in for `dart:io`'s `FileSystemException`.
///
/// Declared HERE rather than in the test tree because production code
/// reads [errorCode] off it — [errnoOf] recognises it by type, which is
/// what lets the crash tests inject a real errno without this file
/// importing `dart:io`.
final class StorageOsException implements Exception {
  const StorageOsException(this.errorCode, [this.message = '']);

  final int errorCode;
  final String message;

  @override
  String toString() => 'StorageOsException($errorCode): $message';
}
