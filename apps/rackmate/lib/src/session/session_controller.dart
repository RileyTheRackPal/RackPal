// New / Open / Save / Save As / Close, and the startup recovery flow.
//
// ==================================================================
// ONE IMPLEMENTATION OF "MAY I REPLACE THE CURRENT DOCUMENT?"
// ==================================================================
// [guardDiscard] is called from FOUR places: the window's close button
// (and Alt+F4, and the taskbar menu), `Ctrl+N`, `Ctrl+O`, and opening a
// recent file. The start card's four starter projects will be the fifth.
// All of them run the identical prompt and the identical post-choice
// sequence, so they cannot drift — which matters because the branch that
// is easiest to get subtly wrong is the same in all five: a SAVE THAT
// FAILED MUST ABORT THE WHOLE OPERATION, not fall through to discarding
// the document.
//
// ==================================================================
// THE CLOSE PATH'S ONE UNFORGIVABLE BUG, WRITTEN DOWN SO IT STAYS FIXED
// ==================================================================
// If the drive is unplugged or the file is locked when the user picks
// "Save" at the close prompt, this returns to the editor with the error
// dialog and the document still dirty and still snapshotted. Closing
// anyway would be the single worst thing this layer can do, and it is
// exactly what a `switch` that forgets to check the save's result does.
//
// ==================================================================
// A FORCED SNAPSHOT BEFORE THE CLOSE PROMPT
// ==================================================================
// The close prompt is the moment a user walks away from the machine. The
// 30 s timer guarantees at most 30 s of loss; a modal dialog can sit for
// an hour. The snapshot is cheap, runs off-thread, and is deleted on both
// Save and Don't Save, so it costs nothing on either common path.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackmate/src/session/autosave_scheduler.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate/src/session/document_session.dart';
import 'package:rackmate/src/session/file_error_presenter.dart';
import 'package:rackmate/src/session/file_picker.dart';
import 'package:rackmate/src/session/session_prompts.dart';
import 'package:rackmate/src/session/starter_projects.dart';
import 'package:rackmate/src/storage/document_store.dart';
import 'package:rackmate/src/storage/errors.dart';
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate/src/storage/prefs_store.dart';
import 'package:rackmate/src/storage/recents_store.dart';
import 'package:rackmate/src/storage/recovery_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';
import 'package:rackmate/src/storage/snapshot_store.dart';
import 'package:rackmate/src/storage/storage_log.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The out-of-document stores, absent as a group when the data root is
/// unusable.
///
/// ONE NULLABLE FIELD RATHER THAN FIVE, because they fail together: if
/// the data root could not be created or written to, none of recents,
/// prefs, snapshots or the snapshot store has anywhere to go. Bundling
/// them means the degraded mode is one branch instead of five, and the
/// branch reads as what it is.
final class OutOfDocumentStores {
  const OutOfDocumentStores({
    required this.recents,
    required this.prefs,
    required this.snapshots,
    required this.dataRootPath,
    required this.portable,
  });

  final RecentsStore recents;
  final PrefsStore prefs;
  final SnapshotStore snapshots;
  final String dataRootPath;
  final bool portable;
}

/// How long any probe of a path THE USER CHOSE is given before it is
/// treated as unanswered.
///
/// The same number as `kRecentsProbeTimeout` and for the same measured
/// reason: `exists` on an unreachable UNC path took 1261 ms and returned
/// false without throwing. Two of the paths this controller probes are
/// absolute values that arrived from somewhere else — a recovery
/// sidecar's `realPath` and `prefs.json`'s `lastSaveDirectory` — and both
/// can name a share this machine cannot reach. One is on the startup
/// path; the other is between Ctrl+O and the dialog appearing.
const Duration kSessionPathProbeTimeout = Duration(milliseconds: 500);

/// Runs the file lifecycle for the one open document (CR-119: v1 is
/// single-document, single-window).
final class SessionController {
  SessionController({
    required this.session,
    required this.store,
    required this.recovery,
    required this.picker,
    required this.prompts,
    required this.autosave,
    required this.fs,
    required this.appVersion,
    this.stores,
    this.clock = const SystemClock(),
    this.starterLoader = loadStarterAssetFromBundle,
    this.newDocumentId = newEntityId,
    this.pathProbeTimeout = kSessionPathProbeTimeout,
    p.Context? context,
  }) : context = context ?? p.context;

  final DocumentSession session;
  final DocumentStore store;
  final RecoveryStore recovery;
  final FilePicker picker;
  final SessionPrompts prompts;
  final AutosaveScheduler autosave;
  final FileStore fs;
  final String appVersion;
  final Clock clock;
  final p.Context context;

  /// Reads a bundled starter's bytes. Injected so the session tests can
  /// supply the four assets without a Flutter asset bundle.
  final StarterAssetLoader starterLoader;

  /// Mints the fresh document id a starter copy is given. Injected for
  /// the same reason the clock is: a test that asserts "two copies do not
  /// share a recovery path" needs to know what the ids were.
  final Uuid Function() newDocumentId;

  /// The bound on every probe of a user-supplied absolute path. See
  /// [kSessionPathProbeTimeout]. Injected so a test can prove the bound
  /// exists without waiting for it.
  final Duration pathProbeTimeout;

  /// Null in the degraded session. See [OutOfDocumentStores].
  final OutOfDocumentStores? stores;

  /// The bytes the current document had on disk BEFORE this build
  /// migrated it, held only until the first save writes over them.
  ///
  /// §9.3's pre-update snapshot, with its one real M1 call site: the
  /// first save of a migrated file rewrites it at a schema version an
  /// older build the user may still have installed cannot read. That is
  /// irreversible, and the migration chain is append-only precisely
  /// because shipped files are historical records — so the file as it was
  /// is worth ten kilobytes of disk.
  Uint8List? _pendingMigrationBytes;
  int? _pendingMigrationFromVersion;

  /// `sequence` AS RECORDED IN [_pendingMigrationBytes], captured the
  /// moment the document was adopted and never moved afterwards.
  ///
  /// ==================================================================
  /// WHY THIS IS NOT `session.document.sequence` AT SAVE TIME
  /// ==================================================================
  /// The pre-update snapshot's file name is `<sequence>.rackmate` (§9.3),
  /// and a file name is a claim about its CONTENT. The bytes are the
  /// PRE-migration original; `doc.sequence` advances on every commit, so
  /// the two diverge the instant the user edits before saving. Filing the
  /// v1 original of a document whose live sequence has reached 3 under
  /// `3.rackmate` names a state that never existed at that version — and
  /// `SnapshotStore.prune` sorts numerically on exactly that stem to pick
  /// which of the last ten to discard, so the retention window was
  /// ordered by a number that identified nothing.
  ///
  /// Migrations run on the RAW root envelope and none of them touches
  /// `sequence` (`rackmate_core/src/persistence/migrations.dart`), so the
  /// freshly-decoded document's sequence IS the one in the original bytes
  /// — which is why this can be captured here rather than re-parsing
  /// ~600 KB of JSON at save time.
  int? _pendingMigrationSequence;

  /// The slot of a survivor the user RECOVERED, held until their next
  /// successful save makes it redundant.
  ///
  /// §9.4: the snapshot is not deleted at the moment of recovery, so a
  /// crash between recovering and saving costs nothing at all. It used to
  /// be swept by step 7 purely because the survivor and the live document
  /// happened to share a path; now that they do not (see
  /// [recoverySlotFor]), the slot has to be remembered and retired
  /// explicitly — otherwise a recovered snapshot would be offered again on
  /// every subsequent launch, forever.
  String? _recoveredSlot;

  /// The target whose `.bak` this session must NOT refresh. See
  /// [_openBackup].
  String? _backupSuppressedFor;

  /// Called after the document is replaced, so the shell can rebuild the
  /// canvas against the new controller.
  void Function()? onDocumentReplaced;

  /// Where THIS session files the live document's recovery snapshot.
  ///
  /// Not the bare document id. See [recoverySlotFor] for the three ways
  /// that lost work.
  String get recoverySlot => recoverySlotFor(
    documentId: session.documentId,
    sessionId: recovery.sessionId,
  );

  // --- The shared guard -------------------------------------------------

  /// "May I replace / close the current document?"
  ///
  /// Returns true when the caller may proceed. False means the user
  /// cancelled, OR a save they asked for did not succeed — the two are
  /// deliberately the same answer, because both mean "do not throw this
  /// document away".
  Future<bool> guardDiscard() async {
    if (!session.isDirty) return true;

    // BEFORE the dialog. See the file header.
    await autosave.snapshot(force: true);

    final choice = await prompts.confirmDiscard(
      documentName: session.displayName,
      editCount: session.editsSinceSave,
    );
    switch (choice) {
      case UnsavedChangesChoice.save:
        return save();
      case UnsavedChangesChoice.dontSave:
        // An explicit "Don't Save" IS a clean exit for this document.
        // Offering to recover work the user just told us to throw away is
        // worse than losing it.
        //
        // THIS SESSION'S SLOT, and no other. A survivor from an earlier
        // run is work the user has NOT told us to throw away — they were
        // asked about it separately, at launch, and may well have said
        // "Keep for later".
        await recovery.delete(recoverySlot);
        return true;
      case UnsavedChangesChoice.cancel:
        return false;
    }
  }

  // --- New --------------------------------------------------------------

  /// `Ctrl+N`.
  Future<bool> newDocument() async {
    if (!await guardDiscard()) return false;
    final document = buildBlankDocument(
      now: clock.nowUtc(),
      appVersion: appVersion,
    );
    _adopt(
      document: document,
      filePath: null,
      openReadOnly: false,
      baseline: FileBaseline.absent,
      originalBytes: null,
      migratedFrom: null,
      status: null,
    );
    return true;
  }

  // --- Starters ---------------------------------------------------------

  /// Opens one of docs/04 §9's four starter projects as an UNTITLED COPY.
  ///
  /// THE FIFTH CALLER OF [guardDiscard], which is why that function was
  /// written to be shared: picking a starter replaces the current
  /// document exactly as `Ctrl+N` and `Ctrl+O` do, and must ask the same
  /// question in the same words.
  ///
  /// The copy has NO `filePath` — so `Ctrl+S` routes to Save As and the
  /// user names it — and a FRESH document id, so two copies of the same
  /// starter can never share a recovery snapshot path. It is NOT marked
  /// dirty: nothing has been lost if the user closes it again, because
  /// the original is still in the application bundle.
  Future<bool> openStarter(StarterProject starter) async {
    if (!await guardDiscard()) return false;

    final Uint8List bytes;
    try {
      bytes = await starterLoader(starter.assetPath);
      // A starter that will not load is a broken BUILD, not a broken
      // user file — but it still reaches the user as a dialog rather
      // than as a crash, because "never silently do nothing" does not
      // have an exception for our own mistakes.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('starter_asset_missing');
      await prompts.showFileError(
        FileErrorView(
          title: 'That sample project is missing from this build.',
          detail:
              '${starter.title} could not be loaded from the application '
              'bundle. Nothing has changed. Reinstalling RackMate should '
              'restore it.',
          actions: const [
            FileErrorAction(
              id: FileErrorActionId.ok,
              label: 'OK',
              isPrimary: true,
            ),
          ],
        ),
      );
      return false;
    }

    final decoded = await store.decodeBytes(
      path: null,
      bytes: bytes,
      asNewDocumentId: newDocumentId().v,
    );
    if (decoded case Err(:final error)) {
      await _reportOpenError(error);
      return false;
    }

    _adoptOpened(
      (decoded as Ok<OpenedDocument>).value,
      baseline: FileBaseline.absent,
      status:
          '${starter.title} opened as a new project. It has not been '
          'saved anywhere yet — use Save As to name it.',
    );
    return true;
  }

  // --- Open -------------------------------------------------------------

  /// `Ctrl+O`. Runs the guard, then the native dialog.
  ///
  /// THE GUARD RUNS FIRST, before the dialog, so a user who realises
  /// mid-dialog that they have unsaved work is not asked about it
  /// afterwards — and so cancelling the file dialog cannot leave a save
  /// half-decided.
  Future<bool> openDocument() async {
    if (!await guardDiscard()) return false;
    final chosen = await picker.pickOpen(
      initialDirectory: await _initialDirectory(),
    );
    // A cancelled dialog is not a failure and reports nothing. It is the
    // one "nothing happened" this layer allows, because the user is the
    // one who made it happen.
    if (chosen == null) return false;
    return openPath(chosen, alreadyGuarded: true);
  }

  /// Opens [path], guarding the current document first unless the caller
  /// already did.
  Future<bool> openPath(String path, {bool alreadyGuarded = false}) async {
    if (!alreadyGuarded && !await guardDiscard()) return false;

    final result = await store.open(path);
    if (result case Ok(:final value)) {
      _adoptOpened(value);
      await _pushRecent();
      return true;
    }
    final error = (result as Err<OpenedDocument>).error;
    if (error is! OpenError) {
      // `DocumentStore.open` only ever produces `OpenError`s. Reaching
      // here would be a bug in the store rather than a bad file, so it is
      // rethrown into the §12.1 programmer-error channel rather than
      // silently swallowed.
      throw StateError('DocumentStore.open returned a non-OpenError: $error');
    }

    // §9.5's lazy pruning, as a rule about error CATEGORIES rather than a
    // hope: only a genuinely-missing file whose directory was confirmed
    // reachable is evicted. Every network error and every permission
    // error leaves the entry alone.
    final evicted =
        shouldEvictOnOpenFailure(error) && await _evictFromRecents(path);

    final pressed = await prompts.showFileError(
      describeOpenError(
        error,
        context: context,
        now: clock.nowUtc(),
        // The dialog used to assert "RackMate has removed it from the
        // recent list" unconditionally, in three cases where nothing had
        // been removed: a degraded session, where `stores` is null and the
        // null-aware call is a no-op; a path picked from File ▸ Open that
        // was never in the list; and a `recents.json` write that failed,
        // because `RecentsStore.save` discards its `Outcome`. A message
        // about the user's data that is casually false is how a user
        // learns to distrust every other message this app shows.
        recentEntryRemoved: evicted,
      ),
    );
    if (pressed == FileErrorActionId.openBackup) {
      final backup = backupOf(error);
      if (backup != null) {
        return _openBackup(
          backup,
          forPath: path,
          // WHICH OF THE TWO ERRORS BROUGHT US HERE MATTERS TO THE
          // BASELINE. `backupOf` answers for both `OpenCorrupt` (the file
          // is there and was read; it is damaged) and `OpenNotFound` (the
          // file is genuinely gone, and the `.bak` beside it is all that
          // is left). Those are opposite facts about whether a file
          // exists, and the baseline the next save compares against is
          // exactly a statement about that.
          targetExists: error is OpenCorrupt,
        );
      }
    }
    return false;
  }

  /// Loads `<target>.bak` AS `<target>`, marked unsaved.
  ///
  /// The user's next Save writes it back over the damaged or missing
  /// file. THE RECOVERY IS COMPLETED BY AN EXPLICIT ACTION, never
  /// silently — which is also why the baseline is re-read from the target
  /// rather than left absent: an absent baseline would make that next
  /// save trip the external-change check on a file the user was just
  /// told about.
  ///
  /// ==================================================================
  /// THAT NEXT SAVE MUST NOT REFRESH THE `.bak`
  /// ==================================================================
  /// Step 4 of the atomic save copies WHATEVER IS AT THE TARGET into
  /// `<target>.bak`. On every other path that is exactly right — the file
  /// at the target is the previous good version. Here it is the DAMAGED
  /// one, and the `.bak` beside it is the only readable copy of the
  /// project in existence: it is what the user was just rescued by.
  ///
  /// So the sequence was: open Smith.rackmate, get "the file appears to be
  /// damaged", press "Open the backup", edit, press Ctrl+S — and step 4
  /// copied the truncated Smith.rackmate over the good Smith.rackmate.bak
  /// BEFORE the promote. The good backup was destroyed by the save that
  /// was supposed to repair the damage. If the promote then failed —
  /// antivirus holding the file through all three retries, the drive
  /// pulled, the volume full — both on-disk copies were unreadable.
  ///
  /// Suppressing the backup for THIS ONE SAVE leaves the `.bak` holding
  /// the last good version, which is precisely what invariant I6 wants it
  /// to hold. It is scoped to the one target and cleared the moment that
  /// save succeeds, so the following save backs up normally — by then the
  /// target really is a good file, because this build wrote it.
  Future<bool> _openBackup(
    BackupFacts backup, {
    required String forPath,
    required bool targetExists,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await fs.readBytes(backup.path);
      // A backup that will not read is reported honestly rather than
      // looping back into the same dialog.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      await prompts.showFileError(
        FileErrorView(
          title: 'The backup could not be read either.',
          detail:
              'RackMate found ${backup.path} but could not read it. Both '
              'the project and its backup are unreadable.',
          actions: const [
            FileErrorAction(
              id: FileErrorActionId.ok,
              label: 'OK',
              isPrimary: true,
            ),
          ],
        ),
      );
      return false;
    }

    final decoded = await store.decodeBytes(path: forPath, bytes: bytes);
    if (decoded case Err(:final error)) {
      await _reportOpenError(error);
      return false;
    }
    final opened = (decoded as Ok<OpenedDocument>).value;
    _adoptOpened(
      opened,
      // THREE ANSWERS, NOT TWO.
      //
      //  * The target is GONE (`OpenNotFound`): `absent` is the truth,
      //    and it is load-bearing — if something restores the file
      //    between this open and the user's next save, they must be asked
      //    before it is overwritten.
      //  * The target is THERE and stat answered: its real facts.
      //  * The target is THERE and stat did not answer: `unknown`.
      //    `FileBaseline.of(null)` would give `absent`, which is a
      //    POSITIVE CLAIM that there is no file — false here, and it
      //    makes the next save fail the external-change check and accuse
      //    OneDrive or a second copy of RackMate of a modification that
      //    never happened. That trains the user to click through the one
      //    prompt that will one day be real.
      baseline: targetExists
          ? _baselineOf(await _statQuietly(forPath))
          : FileBaseline.absent,
      status:
          'Opened the backup of ${context.basename(forPath)}. It has not '
          'been written back — save to replace the damaged file.',
      markDirty: true,
    );
    // See this method's doc comment. Set AFTER `_adoptOpened`, because
    // `_adopt` clears it: this is a property of the file the session was
    // just pointed at, not of the session.
    //
    // NORMALISED THROUGH `SavePaths.forTarget`, which is what the save
    // will compare against. A file opened without the standard extension
    // — the user double-clicked `Smith.rackmate.old`, or a share handed
    // back an odd name — would otherwise produce a target string that
    // never matches, and the suppression would silently not happen on the
    // one path where it matters.
    _backupSuppressedFor = SavePaths.forTarget(
      forPath,
      context: context,
    ).target;
    return true;
  }

  // --- Save -------------------------------------------------------------

  /// `Ctrl+S`.
  ///
  /// Routes to Save As when there is no path yet, AND when the document
  /// opened read-only — a file this build only partly understands must
  /// not be overwritten by it, but the user must never be blocked from
  /// keeping their work.
  Future<bool> save() {
    if (session.requiresSaveAs) return saveAs();
    return _writeTo(
      SavePaths.forTarget(session.filePath!, context: context),
      expected: session.baseline,
    );
  }

  /// `Ctrl+Shift+S`.
  Future<bool> saveAs() async {
    final suggestion = session.openReadOnly
        // §9.2 case 3. The copy carries EVERYTHING THIS BUILD MODELS —
        // which is not everything the newer build wrote, because the codec
        // preserves only a literal `unknown` sub-object at four places and
        // discards every other key it does not know. The original file is
        // left untouched, so nothing is lost from IT; the copy is a copy
        // of what this build understood. `ReadOnlyBanner.message` says so
        // in those words, and used to say the opposite.
        ? copySuggestionFor(session.displayName)
        : defaultSaveName(session.displayName);
    final chosen = await picker.pickSave(
      suggestedName: suggestion,
      initialDirectory: await _initialDirectory(),
    );
    if (chosen == null) return false;
    // ==================================================================
    // THE DOCUMENT ID IS NOT RE-MINTED HERE, AND THAT IS A DECISION
    // ==================================================================
    // `DocumentStore.decodeBytes` takes `asNewDocumentId` because two
    // copies sharing an id would (a) share a recovery snapshot path and
    // (b) put two files on disk claiming to be the same document. A Save
    // As does produce a second file with this document's id, so (b) is
    // real.
    //
    // (a) IS NOT, ANY MORE: a snapshot is filed under
    // `<docId>~<sessionId>` (see [recoverySlotFor]), and v1 is
    // single-document and single-window, so two files with one id can
    // never map to one live snapshot — the sidecar's `realPath` records
    // which file each survivor came from. `session_controller_test.dart`
    // walks the exact scenario the review described and asserts the
    // survivor is untouched.
    //
    // (b) is left standing deliberately, because the only way to fix it
    // costs more than it buys. `RackDocument.id` is final and
    // `DocumentController` holds ONE document for its lifetime with the
    // undo stack replaying against it, so re-identifying means encode →
    // re-decode → a NEW controller — i.e. every Save As silently throws
    // away the user's undo history. Trading a routine operation's undo
    // stack for an identity nothing in v1 reads is the worse defect. The
    // residual is one shared `snapshots/<docId>/` directory for pre-update
    // snapshots of two files, which collides only if both were migrated
    // from an older schema at the same `sequence`.
    final paths = SavePaths.forTarget(chosen, context: context);
    // NO external-change check on a Save As: the user just picked this
    // path in a dialog that already asked about overwriting, and a
    // baseline from a DIFFERENT file would refuse for the wrong reason.
    final saved = await _writeTo(paths);
    if (saved) await _rememberSaveDirectory(paths.directory);
    return saved;
  }

  Future<bool> _writeTo(SavePaths paths, {FileBaseline? expected}) async {
    // ==================================================================
    // THE PRE-UPDATE SNAPSHOT GOES BEFORE THE WRITE, NOT AFTER IT.
    // ==================================================================
    // §9.3's pre-update snapshot insures against an IRREVERSIBLE
    // transformation: the first save of a migrated file rewrites it at a
    // schema version an older build the user may still have installed
    // cannot read. Taking that insurance AFTER the promote left two ways
    // to lose the only surviving copy of the file as the user had it — a
    // crash in the window between the two, and a snapshot write that
    // simply failed. The original bytes live in RAM and nowhere else
    // until this runs, so it runs first.
    final preUpdate = await _snapshotMigratedOriginal();

    final result = await store.save(
      controller: session.controller,
      paths: paths,
      expected: expected,
      // See [_openBackup]: after a `.bak` fallback the file at the target
      // is the DAMAGED one, and backing it up over the good `.bak` would
      // destroy the copy that just rescued the user.
      keepBackup: paths.target != _backupSuppressedFor,
    );

    if (result case Ok(:final value)) {
      // §9.3 steps 7 and 8, the parts that belong above the writer.
      //
      // STEP 7 IS HERE AND NOT IN `DocumentStore` ANY MORE. The store
      // deletes `recovery/<docId>`, which was correct only while the slot
      // and the document id were the same string. This session's live
      // snapshot is at `recovery/<docId>~<sessionId>`, and a survivor from
      // an earlier run is at a slot with a different session in it, so the
      // sweep has to name the slot. The store's own call still runs and is
      // still right for what it can reach: a pair written by a build that
      // predates slots.
      await recovery.delete(recoverySlot);
      final recovered = _recoveredSlot;
      if (recovered != null) {
        // The work is on disk now, which is the condition §9.4 makes the
        // recovered snapshot redundant on.
        await recovery.delete(recovered);
        _recoveredSlot = null;
      }
      // The write-back succeeded, so the target is no longer the damaged
      // file and the NEXT save must refresh the `.bak` normally.
      if (paths.target == _backupSuppressedFor) _backupSuppressedFor = null;
      session.recordSave(
        value,
        status: describeSaveSuccess(
          backupUpdated: value.backupUpdated,
          backupAttempted: value.backupAttempted,
          preUpdateSnapshot: preUpdate,
        ),
      );
      await _pushRecent();
      return true;
    }

    final error = (result as Err<SavedFile>).error;
    if (error is! SaveError) {
      throw StateError('DocumentStore.save returned a non-SaveError: $error');
    }
    final pressed = await prompts.showFileError(
      describeSaveError(error, context: context),
    );
    switch (pressed) {
      case FileErrorActionId.saveAs:
        return saveAs();
      case FileErrorActionId.retry:
        return _writeTo(paths, expected: expected);
      case FileErrorActionId.overwrite:
        // The user has been shown that the file changed underneath them
        // and has chosen to replace it. Dropping the baseline is what
        // makes the second attempt actually go through.
        return _writeTo(paths);
      default:
        // The document stays dirty and its recovery snapshot stays on
        // disk. Nothing about a refused save is silent.
        return false;
    }
  }

  // --- Close ------------------------------------------------------------

  /// The `onWindowClose` handler. `setPreventClose(true)` means nothing
  /// has happened yet and this decides.
  Future<void> requestClose({required Future<void> Function() destroy}) async {
    if (!await guardDiscard()) return;
    await cleanShutdown();
    await destroy();
  }

  /// Everything that must reach disk before the process ends.
  Future<void> cleanShutdown() async {
    autosave.stop();
    // §9.4: "Delete the snapshot on clean save and on clean exit." A
    // successful save at the close prompt already deleted it; this covers
    // the not-dirty and the Don't-Save paths, and costs two `exists` calls
    // when there is nothing there.
    //
    // ==================================================================
    // THIS SESSION'S SLOT ONLY, AND THAT IS THE WHOLE FIX
    // ==================================================================
    // This line used to read `recovery.delete(session.documentId)`, which
    // destroyed a "Keep for later" survivor the moment the user opened the
    // same document and quit — no prompt, no dirty flag, no report, and
    // they had been told explicitly that the work was kept. The document
    // id is shared between the survivor and the live document; the SLOT is
    // not, because it carries the session that wrote it.
    await recovery.delete(recoverySlot);
    // AND STOP CLAIMING TO BE ALIVE. The OS drops the lease when the
    // process ends whatever happens; this removes the FILE, so the
    // sessions directory does not accumulate one dead lease per run.
    await recovery.endSession();
    await onCleanShutdown?.call();
  }

  /// Hook for the shell's debounced writers (window geometry), which must
  /// flush before the process ends or the user's last resize is lost
  /// every single session.
  Future<void> Function()? onCleanShutdown;

  // --- Startup recovery -------------------------------------------------

  /// §9.4's startup scan and prompt.
  ///
  /// Survivors are offered ONE AT A TIME, newest first. "Keep for later"
  /// advances to the next; "Recover" opens the chosen one and leaves the
  /// rest on disk for the next launch. Two survivors are possible after
  /// two consecutive crashes even though v1 is single-document.
  Future<bool> runStartupRecovery() async {
    if (!session.recoveryEnabled) return false;
    final scan = await recovery.scan();
    for (final survivor in scan.survivors) {
      final choice = await prompts.confirmRecovery(
        documentName: survivor.sidecar.displayName,
        savedAt: survivor.sidecar.savedAt,
        unsavedEditCount: survivor.sidecar.unsavedEditCount,
      );
      switch (choice) {
        case RecoveryChoice.recover:
          if (await _acceptRecovery(survivor)) return true;
        case RecoveryChoice.discard:
          await recovery.delete(survivor.sidecar.docId);
        case RecoveryChoice.keepForLater:
          // Left on disk deliberately. It WILL be offered again next
          // launch: the data is still at risk, and silently forgetting it
          // is worse than one more prompt.
          continue;
      }
    }
    return false;
  }

  Future<bool> _acceptRecovery(RecoverySurvivor survivor) async {
    final Uint8List bytes;
    try {
      bytes = await recovery.readSnapshot(survivor);
      // A snapshot that will not read is a lost safety net, not a reason
      // to fail the launch it was found during — but it IS reported. The
      // user pressed "Recover"; returning false with only a log line put
      // them back on the start card with no dialog and no explanation, at
      // the exact moment they were most anxious about their work. Both
      // sibling failures in this file already raise something: the `.bak`
      // that will not read, and the snapshot that will not decode four
      // lines below.
      //
      // NOTHING IS DELETED HERE. A pair we could not read is a pair we
      // cannot judge, and the next launch's scan may well manage it — an
      // antivirus scanner holding a handle, or a permissions change,
      // both pass.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('recovery_read_failed');
      await prompts.showFileError(
        FileErrorView(
          title: 'That recovered copy could not be read.',
          detail:
              'RackMate found the recovered copy of '
              '${survivor.sidecar.displayName} but could not read it back. '
              'It may be held open by another program, or the folder '
              'RackMate keeps it in may have become unreadable. Nothing '
              'has been deleted, and RackMate will offer it again next '
              'time it starts.',
          actions: const [
            FileErrorAction(
              id: FileErrorActionId.ok,
              label: 'OK',
              isPrimary: true,
            ),
          ],
        ),
      );
      return false;
    }

    final realPath = survivor.sidecar.realPath;
    // A snapshot whose real file has moved or is on a share that is not
    // answering opens as UNTITLED with a suggested name, and Ctrl+S
    // routes to Save As. The work is never held hostage to a path.
    //
    // BOUNDED, because `realPath` is an ABSOLUTE PATH FROM A SIDECAR and
    // this runs inside the startup sequence. It can be `\\officenas\jobs\…`
    // written on a machine that could reach that share, carried to one
    // that cannot; `exists` on a dead UNC path was measured at 1261 ms
    // and `DartIoFileStore.exists` probes File then Directory, so the
    // unbounded version is ~2.5 s against a 1.2 s cold-start budget. This
    // is the same rule the recents design was built around, applied to the
    // one startup path that had escaped it.
    final reachable = realPath != null && await _existsQuietly(realPath);

    final decoded = await store.decodeBytes(
      path: reachable ? realPath : null,
      bytes: bytes,
    );
    if (decoded case Err(:final error)) {
      await _reportOpenError(error);
      return false;
    }

    final opened = (decoded as Ok<OpenedDocument>).value;
    final at = survivor.sidecar.savedAt.toLocal();
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    _adoptOpened(
      opened,
      // `unknown` rather than `absent` when the stat does not answer: the
      // file was just confirmed to exist, so "there is no file" would be a
      // false positive claim that fails the next save's external-change
      // check. `absent` is still correct in the unreachable branch, where
      // there genuinely is no file to compare against.
      baseline: reachable
          ? _baselineOf(await _statQuietly(realPath))
          : FileBaseline.absent,
      status: reachable
          ? 'Recovered from $hh:$mm. Not yet written to '
                '${context.basename(realPath)}.'
          : 'Recovered from $hh:$mm. This project has never been saved.',
      // THE SNAPSHOT IS NOT DELETED HERE. It is retired by the user's next
      // successful explicit save, so a crash between recovering and saving
      // costs nothing at all.
      markDirty: true,
    );
    // After `_adoptOpened`, which clears it — see [_recoveredSlot].
    _recoveredSlot = survivor.sidecar.docId;
    return true;
  }

  // --- Recents ----------------------------------------------------------

  /// The stored list, with NO reachability probe. Nothing on the startup
  /// path may stat a recent file: `exists` on a dead UNC path was
  /// measured at 1261 ms, and ten of those is ten times the entire
  /// cold-start budget.
  Future<List<RecentEntry>> loadRecents() async =>
      await stores?.recents.load() ?? const [];

  /// The bounded probe, run when the menu is OPENED.
  Future<Map<String, RecentEntryState>> probeRecents(
    List<RecentEntry> entries,
  ) async => await stores?.recents.probe(entries) ?? const {};

  /// Removes [path] from recents and REPORTS WHETHER IT WORKED.
  ///
  /// `RecentsStore.remove` returns the list it computed, not the list on
  /// disk: it awaits `save`, which awaits `AtomicWriter.write` and drops
  /// the `Outcome` entirely. A read-only or full data root therefore
  /// leaves `recents.json` unchanged while every in-process caller
  /// believes the entry is gone. Re-reading is what turns the dialog's
  /// claim into something that was checked — one small local read, on a
  /// path that has already put a modal on screen.
  Future<bool> _evictFromRecents(String path) async {
    final recents = stores?.recents;
    // The degraded session. Nothing was removed because there is nowhere
    // to remove it from.
    if (recents == null) return false;
    final key = recents.canonicalKey(path);
    final before = await recents.load();
    // It was never in the list — File ▸ Open on a path the user typed or
    // browsed to. Nothing to remove, and nothing to claim.
    if (!before.any((e) => recents.canonicalKey(e.path) == key)) return false;
    await recents.remove(path);
    final after = await recents.load();
    final gone = !after.any((e) => recents.canonicalKey(e.path) == key);
    if (!gone) logStorageEvent('recents_eviction_unconfirmed');
    return gone;
  }

  Future<void> _pushRecent() async {
    final path = session.filePath;
    if (path == null) return;
    await stores?.recents.push(
      RecentEntry(
        path: path,
        displayName: session.displayName,
        lastOpened: clock.nowUtc(),
      ),
    );
  }

  /// Records the directory of a successful Save As — IN MEMORY AND ON
  /// DISK, and the first half is not optional.
  ///
  /// ==================================================================
  /// TWO PLACES HOLD THIS, AND ONLY ONE OF THEM FEEDS THE DIALOG
  /// ==================================================================
  /// `prefs.json` is what survives the session; [_lastSaveDirectory] is
  /// what [_initialDirectory] hands to `picker.pickSave` and
  /// `picker.pickOpen`. This used to write only the first, and
  /// [_lastSaveDirectory] moved in exactly one place — the startup seed —
  /// so a user who saved into `C:\jobs` got the dialog back at the
  /// STARTUP directory on their very next Save As, and again on every
  /// Open, for the whole session. The stored value was correct and
  /// nothing read it until the next launch.
  ///
  /// The in-memory write happens FIRST and unconditionally: the degraded
  /// session has no `prefs.json` to write to, and "remember where I just
  /// saved" is still the right behaviour there for as long as the process
  /// lives.
  Future<void> _rememberSaveDirectory(String directory) async {
    _lastSaveDirectory = directory;
    final prefs = stores?.prefs;
    if (prefs == null) return;
    await prefs.save(
      (await prefs.load()).copyWith(lastSaveDirectory: directory),
    );
  }

  /// The folder the native dialog opens in, or null to let the OS decide.
  ///
  /// ==================================================================
  /// A STORED ABSOLUTE PATH IS NOT HANDED TO A NATIVE DIALOG UNCHECKED
  /// ==================================================================
  /// `prefs.json` travels with a portable installation, so
  /// `lastSaveDirectory` can be a value recorded on a DIFFERENT machine.
  /// For a nonexistent local path the dialog degrades cleanly —
  /// `SHCreateItemFromParsingName` fails and `file_dialog_channel.cpp`
  /// simply does not call `SetFolder`, which is a deliberate best-effort
  /// there. For a UNC share such as `\\officenas\jobs` it does not: that
  /// call runs on the platform thread and blocks on the network timeout,
  /// so the user presses Ctrl+O on the new machine and the window freezes
  /// for seconds before any dialog appears.
  ///
  /// So the value is probed first, with the same bound the recents design
  /// uses, and dropped if it does not answer. Dropped IN MEMORY: the next
  /// successful Save As records a fresh one, and rewriting `prefs.json`
  /// from a dialog-open is a side effect nobody asked for.
  Future<String?> _initialDirectory() async {
    final directory = _lastSaveDirectory;
    if (directory == null) return null;
    if (await _existsQuietly(directory)) return directory;
    // Never silently: the dialog opening somewhere else is a visible
    // change and this is why it happened.
    logStorageEvent('save_directory_unreachable');
    _lastSaveDirectory = null;
    return null;
  }

  /// [_initialDirectory], for the PDF export dialog.
  ///
  /// Exposed rather than duplicated so the export dialog opens where the
  /// last document save did — including the bounded probe that stops a
  /// stored UNC path freezing the window (see [_initialDirectory]). A
  /// second "where should the dialog open" answer is a second place for
  /// that probe to be forgotten.
  Future<String?> exportInitialDirectory() => _initialDirectory();

  String? _lastSaveDirectory;

  /// Seeds the save dialog's starting folder from `prefs.json`. Called
  /// once at startup; a failure simply leaves the OS to pick.
  // ignore: use_setters_to_change_properties
  void seedLastSaveDirectory(String? directory) =>
      _lastSaveDirectory = directory;

  // --- Adoption ---------------------------------------------------------

  void _adoptOpened(
    OpenedDocument opened, {
    FileBaseline? baseline,
    String? status,
    bool markDirty = false,
  }) {
    _adopt(
      document: opened.document,
      filePath: opened.path,
      openReadOnly: opened.openReadOnly,
      baseline: baseline ?? opened.baseline,
      originalBytes: opened.originalBytes,
      migratedFrom: opened.migratedFromSchemaVersion,
      status: status,
      markDirty: markDirty,
    );
  }

  void _adopt({
    required RackDocument document,
    required String? filePath,
    required bool openReadOnly,
    required FileBaseline baseline,
    required Uint8List? originalBytes,
    required int? migratedFrom,
    required String? status,
    bool markDirty = false,
  }) {
    _pendingMigrationBytes = originalBytes;
    _pendingMigrationFromVersion = migratedFrom;
    // Captured HERE, before the user can edit — see the field.
    _pendingMigrationSequence = originalBytes == null
        ? null
        : document.sequence;
    // Both are properties of THE DOCUMENT THAT WAS OPEN, not of the
    // session, so replacing the document clears them. The two callers that
    // want them set do so immediately after calling this.
    _backupSuppressedFor = null;
    _recoveredSlot = null;
    session.adopt(
      controller: DocumentController(document, clock: clock),
      filePath: filePath,
      openReadOnly: openReadOnly,
      baseline: baseline,
      status: status,
    );
    if (markDirty) session.markUnsavedRecovery();
    // A new document must not inherit the previous one's debounce window,
    // or its very first snapshot could be suppressed by timing that has
    // nothing to do with it.
    autosave
      ..reset()
      ..start();
    onDocumentReplaced?.call();
  }

  /// §9.3's pre-update snapshot, at its one real M1 call site.
  ///
  /// Called BEFORE the write it insures against — see [_writeTo].
  ///
  /// THE PENDING BYTES ARE CLEARED ONLY ON SUCCESS. They used to be
  /// cleared two lines before the `await`, and the returned `Outcome` was
  /// dropped on the floor, so a data root that was full or unwritable
  /// produced: no snapshot, no retry ever, a `pre_update_snapshot` log
  /// line claiming one had been taken, and a bare "Saved." on screen. The
  /// user was never told that the safety net for an irreversible
  /// transformation had not existed. Keeping the bytes means the NEXT
  /// save tries again; they are ~600 KB and they are the only copy of the
  /// file as the user had it.
  Future<PreUpdateSnapshotState> _snapshotMigratedOriginal() async {
    final bytes = _pendingMigrationBytes;
    final from = _pendingMigrationFromVersion;
    final sequence = _pendingMigrationSequence;
    if (bytes == null || from == null || sequence == null) {
      // Nothing was migrated, so there is nothing to insure and nothing
      // to report. This is the overwhelmingly common path.
      return PreUpdateSnapshotState.notNeeded;
    }
    final snapshots = stores?.snapshots;
    if (snapshots == null) {
      // The degraded session. `describeDegradedPersistence` names
      // autosave, recents and window position; it cannot name THIS,
      // because it is written once at startup and this only matters for a
      // document that turned out to need migrating. So it is reported
      // here, on the save it applies to.
      logStorageEvent('pre_update_snapshot_unavailable', {
        'fromSchemaVersion': from,
      });
      return PreUpdateSnapshotState.failed;
    }
    final result = await snapshots.write(
      docId: session.documentId,
      // THE SEQUENCE THE BYTES CARRY, not the live document's. See
      // [_pendingMigrationSequence].
      sequence: sequence,
      bytes: bytes,
    );
    if (result case Err()) {
      logStorageEvent('pre_update_snapshot_failed', {
        'fromSchemaVersion': from,
        'bytes': bytes.length,
      });
      return PreUpdateSnapshotState.failed;
    }
    // Once only, and only now: the second save has nothing new to
    // preserve, and ten identical copies of the pre-migration file would
    // push the nine genuinely different ones out of the pruned window.
    _pendingMigrationBytes = null;
    _pendingMigrationFromVersion = null;
    _pendingMigrationSequence = null;
    logStorageEvent('pre_update_snapshot', {
      'fromSchemaVersion': from,
      'bytes': bytes.length,
    });
    return PreUpdateSnapshotState.kept;
  }

  /// One place the decode-side `OpenError`s reach the user from, so the
  /// three routes into a decode — File ▸ Open, the `.bak` fallback and a
  /// recovery snapshot — cannot describe the same failure differently.
  Future<void> _reportOpenError(Object error) async {
    if (error is! OpenError) {
      throw StateError('decodeBytes returned a non-OpenError: $error');
    }
    await prompts.showFileError(
      describeOpenError(error, context: context, now: clock.nowUtc()),
    );
  }

  /// The baseline for a file that IS THERE but whose stat did not answer.
  ///
  /// `FileBaseline.of(null)` is `absent`, which is a POSITIVE CLAIM that
  /// there is no file. At the two call sites below the file was just
  /// confirmed to exist, so the honest answer to a failed stat is
  /// "unknown", which the next save's external-change check treats as
  /// "no reason to refuse" rather than as evidence of tampering.
  FileBaseline _baselineOf(FileFacts? facts) =>
      facts == null ? FileBaseline.unknown : FileBaseline.of(facts);

  Future<FileFacts?> _statQuietly(String path) async {
    try {
      return await fs.stat(path).timeout(pathProbeTimeout);
      // "cannot tell" is answered as "no facts", which routes every
      // caller to its own conservative branch rather than to a crash. A
      // TIMEOUT lands here too, and means the same thing.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  Future<bool> _existsQuietly(String path) async {
    try {
      return await fs.exists(path).timeout(pathProbeTimeout);
      // A path whose existence cannot be determined — including one that
      // did not answer inside [pathProbeTimeout] — is treated as ABSENT:
      // the recovered document then opens untitled rather than bound to a
      // file it may not be able to write.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return false;
    }
  }
}
