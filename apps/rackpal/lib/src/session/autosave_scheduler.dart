// Autosave (docs/03-architecture.md §9.4).
//
// ==================================================================
// THE ONE RULE THAT OUTRANKS EVERYTHING ELSE IN THIS FILE
// ==================================================================
// NEVER AUTOSAVE OVER THE USER'S FILE. Not on the timer, not on blur, not
// on close, not on accepting a recovery snapshot. "CAD users expect
// explicit saves and will file a bug the first time an autosave clobbers
// something." The ONLY writer of `<target>.rppj` is an explicit user
// Save or Save As — which is enforced structurally rather than by
// intention: this class holds no `SavePaths` for the user's document and
// cannot construct one. It calls `RecoveryStore.write`, which writes into
// the app's own data root under a uuid name, and nothing else.
//
// ==================================================================
// TWO TRIGGERS, AND A SUPPRESSION THAT IS NOT A TIMER
// ==================================================================
// §9.4: every 30 s AND on window blur. The two coincide constantly — a
// user who alt-tabs at second 29 would otherwise write ~600 KB twice in
// under a second — so a snapshot is skipped when one was ALREADY WRITTEN
// AT THIS `stateId`, however long ago.
//
// IT USED TO EXPIRE AFTER 2 SECONDS, AND THAT WAS A DEFECT. The dirty
// check cannot help here: a recovery snapshot is not a save, so a
// document left dirty stays dirty against disk forever. A user who
// edited and then walked away therefore had the SAME ~600 KB snapshot
// rewritten on every 30 s tick, indefinitely, for as long as the app was
// open. §10.12(b) rules autosave to run when the user is working and not
// when they are idle; keying on the state id alone is what makes that
// true, and it still covers the blur-plus-tick case the 2 s window was
// written for.
//
// ==================================================================
// SERIALIZATION IS OFF-THREAD (CR-099), AND SINGLE-FLIGHT
// ==================================================================
// The snapshot goes through the same two-phase encode as an explicit
// save — tree on the main isolate, bytes in `Isolate.run` — because
// nobody is waiting, so the transfer cost is free and the UI must not
// hitch. It is enqueued on the SAME `SaveQueue` as explicit saves, so a
// 30 s tick can never interleave two renames with a save the user is
// watching.
//
// ==================================================================
// THE TWO-PHASE RULE APPLIES TO THE SIDECAR TOO, NOT JUST THE BYTES
// ==================================================================
// `serializeSnapshot` captures the controller and its state id
// synchronously and only then awaits. Every field of the SIDECAR — the
// document id, the real path, the sequence, the display name, the edit
// count — used to be read AFTER that await, from `session.*`, which is
// live. The 30 s timer fires while document A is open; during the isolate
// round-trip the user completes Ctrl+O and `_adopt` swaps in document B;
// the write then files A's BYTES under B's id, B's path and B's edit
// count. The result is a snapshot that lies about which project it is and
// clobbers whatever B had, while A's unsaved work is filed under an id
// nothing will ever look for. Everything the sidecar needs is therefore
// captured in the same synchronous window as the bytes.
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/timers.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// §9.4: "Every 30 s".
const Duration kAutosaveInterval = Duration(seconds: 30);

// `kAutosaveDebounce` (2 s) USED TO LIVE HERE AND IS DELETED. Suppression
// now keys on the state id alone, which is time-independent and strictly
// stronger — see `_snapshot`. A duration that no longer gates anything is
// the stored-and-ignored config this codebase keeps finding and removing.

/// Why a snapshot did not happen. Returned rather than logged-and-
/// forgotten so the tests can assert the skip REASON, not merely that a
/// write did not occur — "it skipped because it was clean" and "it
/// skipped because the queue was busy" are different bugs when one of
/// them is wrong.
enum AutosaveOutcome {
  /// A snapshot pair was written.
  written,

  /// The document matches what is on disk. Nothing to protect.
  notDirty,

  /// Nothing has changed since the last snapshot: it was taken at this
  /// exact `stateId`, so another would be byte-identical. Time-independent
  /// — an idle document never re-writes the same bytes.
  debounced,

  /// An explicit save is in flight. It will make the snapshot redundant.
  busy,

  /// The app cannot write to its data folder this session.
  disabled,

  /// The write was attempted and failed. Already logged.
  failed,
}

/// Writes recovery snapshots on a timer and on window blur.
final class AutosaveScheduler {
  AutosaveScheduler({
    required this.session,
    required this.store,
    required this.recovery,
    required this.appVersion,
    this.clock = const SystemClock(),
    this.periodicTimerFactory = productionPeriodicTimerFactory,
    this.interval = kAutosaveInterval,
    this.isQueueBusy,
    this.onOutcome,
  });

  final DocumentSession session;
  final DocumentStore store;
  final RecoveryStore recovery;

  /// Recorded in the sidecar so a future build can refuse a snapshot it
  /// cannot read without first parsing 600 KB of it.
  final String appVersion;

  /// Injected, like everywhere else in this project — a sidecar's
  /// `savedAt` is byte-comparable in tests because of it.
  final Clock clock;

  final PeriodicTimerFactory periodicTimerFactory;
  final Duration interval;

  /// Whether an explicit save is in flight. Null means "cannot tell",
  /// which is treated as not busy.
  final bool Function()? isQueueBusy;

  /// Called with the result of EVERY [snapshot] attempt.
  ///
  /// THE REASON THIS EXISTS IS [AutosaveOutcome.failed], which had no
  /// consumer anywhere in `lib/`. `session.recoveryEnabled` is fixed at
  /// startup from whether the data root was writable, so a root that
  /// becomes unwritable AFTER launch — the volume fills, the portable
  /// stick's write-protect switch is flipped, an admin policy revokes
  /// write access, the folder is deleted — made every snapshot fail with
  /// nothing anywhere to notice: the timer callback dropped the result,
  /// `guardDiscard`'s forced pre-dialog snapshot dropped it too, and
  /// `logStorageEvent` went to a null sink because nothing in production
  /// calls `setStorageLogSink`. The user worked for hours believing the
  /// 30 s snapshot was protecting them.
  ///
  /// It is a hook rather than a field the shell polls because BOTH
  /// triggers are `void` callbacks with no caller to await them; a hook is
  /// the only place a result from the timer can reach anything at all.
  final void Function(AutosaveOutcome)? onOutcome;

  CancellableTimer? _timer;

  /// The most recent snapshot started by the timer or by a blur.
  ///
  /// EXPOSED rather than fired-and-forgotten because both triggers are
  /// `void` callbacks with no caller to await them — which makes the
  /// write invisible to a test and un-awaitable at shutdown. Keeping the
  /// future is the difference between "a snapshot was requested" and "a
  /// snapshot is on disk", and only the second one is worth asserting.
  Future<AutosaveOutcome> get pending => _pending;
  Future<AutosaveOutcome> _pending = Future.value(AutosaveOutcome.notDirty);

  int? _lastSnapshotStateId;
  bool _running = false;

  /// True while the periodic timer is installed.
  bool get isRunning => _timer != null;

  /// How many snapshot pairs this scheduler has written. Test-only
  /// observability.
  int get snapshotCount => _snapshotCount;
  int _snapshotCount = 0;

  /// Starts the 30 s timer.
  ///
  /// A NO-OP WHEN RECOVERY IS DISABLED, and that is the whole degraded
  /// mode: no timer, no writes, no repeated failures against a folder
  /// that is not going to become writable. The user is told once, by a
  /// persistent status-bar warning, rather than every 30 seconds.
  void start() {
    if (!session.recoveryEnabled || _timer != null) return;
    _timer = periodicTimerFactory(interval, () => _pending = snapshot());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// §9.4's second trigger.
  void onWindowBlurred() => _pending = snapshot();

  /// Writes a snapshot if one is owed.
  ///
  /// [force] bypasses the debounce but NOT the dirty check — used at the
  /// close prompt, where the user may walk away from a modal dialog for
  /// an hour and the 30 s guarantee stops meaning anything.
  Future<AutosaveOutcome> snapshot({bool force = false}) async {
    final outcome = await _snapshot(force: force);
    // EVERY outcome, not just the failures: a `written` after a `failed`
    // is what tells the shell the data root came back and the warning can
    // come down. See [onOutcome].
    onOutcome?.call(outcome);
    return outcome;
  }

  Future<AutosaveOutcome> _snapshot({required bool force}) async {
    if (!session.recoveryEnabled) return AutosaveOutcome.disabled;
    if (!session.isDirty) return AutosaveOutcome.notDirty;
    // Re-entrancy: the timer can fire while an earlier snapshot is still
    // serializing. The SaveQueue would serialise them correctly, but
    // queueing a second copy of the same bytes is pure waste.
    if (_running) return AutosaveOutcome.busy;
    if (!force && (isQueueBusy?.call() ?? false)) return AutosaveOutcome.busy;

    final now = clock.nowUtc();
    // NOTHING NEW TO PROTECT: the last snapshot was taken at this exact
    // `stateId`, so a second one would be byte-identical.
    //
    // THE ELAPSED-TIME CLAUSE THAT USED TO BE HERE WAS THE BUG. It read
    // `_lastSnapshotStateId == stateId && now.difference(last) < debounce`,
    // so the suppression EXPIRED after 2 s while the reason for it did
    // not. A document left dirty and idle — the user edits, then goes to
    // lunch — therefore re-wrote the SAME ~600 KB snapshot on every 30 s
    // tick, indefinitely. The dirty check above cannot catch it: a
    // recovery snapshot is not a save, so the document stays dirty
    // against disk forever.
    //
    // Keying on the state id ALONE is strictly stronger and still covers
    // the case the 2 s window was written for — blur and the timer
    // coinciding, which must not thrash a large write. `force` continues
    // to bypass this (the close prompt, where the user may sit in a modal
    // for an hour), and it still cannot bypass the dirty check.
    if (!force && _lastSnapshotStateId == session.document.stateId) {
      return AutosaveOutcome.debounced;
    }

    _running = true;
    try {
      // ================================================================
      // ONE SYNCHRONOUS WINDOW. NOTHING BELOW THIS COMMENT MAY AWAIT
      // UNTIL THE SIDECAR IS BUILT.
      // ================================================================
      // See the file header. `session.*` is live, and the document can be
      // replaced during the isolate round-trip; a sidecar assembled from
      // it afterwards describes a DIFFERENT document than the bytes it is
      // paired with. The document is captured once, here, and every field
      // is read off that capture.
      final controller = session.controller;
      final document = controller.doc;
      final filePath = session.filePath;
      final sidecar = RecoverySidecar(
        docId: recoverySlotFor(
          documentId: document.id.v,
          sessionId: recovery.sessionId,
        ),
        realPath: filePath,
        sequence: document.sequence,
        savedAt: now,
        // Built from the CAPTURED document and path rather than read off
        // `session.displayName`, which is a live getter over both.
        displayName: displayNameFor(
          projectName: document.info.projectName,
          filePath: filePath,
          context: session.context,
        ),
        unsavedEditCount: controller.editsSinceSave,
        appVersion: appVersion,
        schemaVersion: document.schemaVersion,
      );
      // ---------------- the synchronous window ends here ---------------

      // The same two-phase split as the save path: the state id and the
      // JSON tree are taken synchronously inside `serializeSnapshot`, and
      // only plain data crosses the isolate boundary.
      final snapshot = await store.serializeSnapshot(controller);
      final result = await recovery.write(
        sidecar: sidecar,
        documentBytes: snapshot.bytes,
      );
      if (result case Err()) return AutosaveOutcome.failed;
      _lastSnapshotStateId = snapshot.stateId;
      _snapshotCount++;
      return AutosaveOutcome.written;
      // A snapshot is a safety net. Whatever went wrong taking one must
      // never propagate into the timer, the blur handler or the close
      // path — all three of which have something more important to do.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('autosave_failed');
      return AutosaveOutcome.failed;
    } finally {
      _running = false;
    }
  }

  /// Forgets the suppression state. Called when the document is replaced,
  /// so a new document's first snapshot is not suppressed by the previous
  /// one's state id.
  void reset() {
    _lastSnapshotStateId = null;
  }
}
