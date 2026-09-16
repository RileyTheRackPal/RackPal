// Recovery snapshots (docs/03-architecture.md §9.4).
//
// ==================================================================
// THE ONE RULE THAT OUTRANKS EVERYTHING ELSE HERE
// ==================================================================
// NEVER AUTOSAVE OVER THE USER'S FILE. "CAD users expect explicit saves
// and will file a bug the first time an autosave clobbers something." A
// snapshot goes to the app's own data root under a uuid name. The ONLY
// writer of <target>.rppj is an explicit user Save or Save As.
//
// ==================================================================
// CR-096 — RECOVERY FILES ARE NEVER AUTO-ATTACHED TO A CRASH REPORT
// ==================================================================
// A recovery file is a COMPLETE PROJECT containing the client's name and
// site address. Crash reporting is not built in this pass, but the
// STRUCTURAL guarantee is, because it is cheaper to make the file
// unreachable than to remember not to attach it:
//   * the recovery directory is named in exactly ONE file — this one —
//     and `test/storage/storage_layering_test.dart` RULE 3 asserts that;
//   * this class exposes `scan` / `write` / `delete` and NO bulk-read,
//     no "collect everything", no bundle method — and the second half is
//     asserted too, by the CR-096 group in
//     `test/storage/recovery_store_test.dart`, which INVENTORIES the
//     public members of this class and of the two values `scan` returns.
//     That group used to assert that two method tear-offs were non-null,
//     which is a tautology: adding a `readAll()` here broke the guarantee
//     and left the suite green.
// A future diagnostics path therefore cannot reach a recovery file by
// accident; it would have to add an API, in this file, on purpose — and
// adding one fails a test that points back at this paragraph.
//
// ==================================================================
// WRITE ORDER IS LOAD-BEARING
// ==================================================================
// A write RETIRES the previous sidecar first, then writes and renames
// the snapshot into place, then writes the new sidecar. Therefore "a
// sidecar exists" IMPLIES "its snapshot is complete AND is the one this
// sidecar describes" — the second half is what the retire step buys, and
// without it a failure between the two writes leaves a NEW snapshot
// paired with a STALE sidecar, which `scan()` cannot tell from a healthy
// pair. On deletion the order is the same — sidecar first, then snapshot
// — so a half-deleted pair is never offered back to the user either.
//
// Startup then has two mechanical rules, both testable with the fake:
//   * snapshot present, no sidecar -> an interrupted snapshot. Delete
//     silently. It is our file, in our directory, and by construction
//     either incomplete or unattributable.
//   * sidecar present, no snapshot -> delete the sidecar.
//
// ==================================================================
// AND A THIRD RULE THAT OUTRANKS BOTH: A LIVE PAIR IS NOT OURS TO TOUCH
// ==================================================================
// Nothing prevents a second instance of this app, and both of the rules
// above are stated as if this process were the only one that had ever
// written here. It is not. Instance B is running with twenty minutes of
// unsaved work behind `recovery/<doc>~<B>.rppj`; instance C launches
// and its scan used to CLAIM that pair and OFFER it — describing live
// in-flight work as a crash survivor, and turning the user's entirely
// reasonable "Discard" into the deletion of a running instance's only
// safety net. The same scan could also delete B's snapshot as an
// "orphan" if it happened to run inside B's write window.
//
// So every session takes a [FileLease] on `<dataRoot>/sessions/<id>.lease`
// (see [RecoveryStore.beginSession]) and the scan asks the KERNEL, not a
// clock, whether the session that wrote a pair still exists. A lease is
// released by the operating system when its process ends, however it
// ends, so "that session is gone" is a fact. Anything a live foreign
// session owns is left completely alone: not claimed, not offered, not
// deleted, not swept.
//
// A HEARTBEAT WOULD HAVE BEEN WRONG, and it is worth saying why, because
// it is the obvious design. Any "the sidecar was touched less than N
// seconds ago" rule withholds a survivor from precisely the user who
// crashed and relaunched immediately — the single most common way this
// feature is ever exercised.
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The subdirectory of the data root holding recovery snapshots.
///
/// NAMED HERE AND NOWHERE ELSE (CR-096). See the file header.
const String kRecoveryDirName = 'recovery';

/// The subdirectory of the data root holding one lease file per RUNNING
/// instance of the app.
///
/// DELIBERATELY NOT INSIDE [kRecoveryDirName]. A lease says which
/// PROCESSES are alive; it is not a recovery artefact, it holds no user
/// data at all, and mixing a file with different lifetime rules in beside
/// the pairs is how a sweep eventually eats one. Keeping it out also means
/// the recovery directory's contents are exactly what they have always
/// been.
const String kLiveSessionDirName = 'sessions';

/// A live session's lease file extension.
const String kLeaseExtension = '.lease';

/// Snapshots carry the ordinary document extension because they ARE
/// ordinary documents — a recovered file must open in any build.
///
/// Which means DR-015 and DR-179 renamed this too, and that the SCAN has
/// to know every spelling. A recovery pair exists only across a crash, so
/// the one window in which a `.rmpj` snapshot meets a `.rppj` build is
/// exactly the window this feature exists for: the user's last build died with
/// unsaved work and they installed this one before reopening. Recognising
/// only the current spelling would orphan the sidecar, and `scan` deletes
/// orphans silently — a crash recovery lost without a word, which is the
/// failure mode AC-042 calls a data-loss event dressed as tidiness.
const String kSnapshotExtension = kDocumentExtension;

/// Every spelling a snapshot on disk may have. Written as
/// [kSnapshotExtension]; recognised as any of these.
const List<String> kSnapshotExtensions = kDocumentExtensions;

/// The sidecar's extension.
const String kSidecarExtension = '.json';

/// What separates the document id from the session id in a recovery slot.
///
/// `~` CANNOT OCCUR IN A UUID, which is the property that matters: a stem
/// containing it is a slot written by the current scheme, and a stem
/// without one is a bare document id written by an earlier build.
///
/// DECLARED IN THIS FILE, not in the session layer that composes it,
/// because this store has to be able to recognise ITS OWN slots — see
/// [RecoveryStore.delete]. `recoverySlotFor` in
/// `session/document_session.dart` builds them and carries the reasoning
/// for why a snapshot belongs to a session's work on a document rather
/// than to the document.
const String kRecoverySlotSeparator = '~';

/// The sidecar written beside every recovery snapshot.
///
/// §9.4 specifies four fields; there are six here, and the two additions
/// are not decoration:
///
///  * `unsavedEditCount` — the REQUIRED message "Recover Smith Residence
///    (12 unsaved changes)?" cannot be rendered from the specified four.
///    After a crash there is no undo stack left to consult, and
///    `sequence` is a lifetime counter, not a since-save delta. Inventing
///    the number would violate G4; storing it is one integer. It is
///    nullable, and a null means the prompt OMITS the count rather than
///    guessing one.
///  * `appVersion` / `schemaVersion` — let a future build refuse a
///    snapshot it cannot read without first parsing 600 KB of it.
///  * `owner` — which RUNNING PROCESS this pair belongs to. See
///    [RecoveryStore.delete]; without it a save in one instance of the
///    app deletes another instance's safety net.
final class RecoverySidecar {
  const RecoverySidecar({
    required this.docId,
    required this.sequence,
    required this.savedAt,
    required this.displayName,
    required this.appVersion,
    required this.schemaVersion,
    this.realPath,
    this.unsavedEditCount,
    this.owner,
  });

  /// The pair's KEY, and the file stem of both of its files.
  ///
  /// This store treats it as opaque: it joins it to the recovery directory
  /// and adds an extension, and never parses it. What goes in it is the
  /// caller's decision, and the session layer's decision is
  /// `<documentUuid>~<sessionUuid>` — see `recoverySlotFor` in
  /// `session/document_session.dart` for the three ways the bare document
  /// uuid lost a user's work. A stem with no `~` in it is a pair written
  /// by a build that predates that, and is still scanned and offered
  /// normally.
  final String docId;

  /// Where the document lives on disk. ABSENT means it was never saved,
  /// in which case recovering opens it as untitled and Ctrl+S routes to
  /// Save As.
  final String? realPath;

  /// `RackDocument.sequence` at snapshot time.
  final int sequence;

  final DateTime savedAt;

  /// What the prompt calls it.
  final String displayName;

  /// How many edits stood between the snapshot and the last save. NULL
  /// means unknown, and the prompt must then omit the count entirely
  /// rather than substitute a plausible number (G4).
  final int? unsavedEditCount;

  final String appVersion;
  final int schemaVersion;

  /// The [RecoveryStore.sessionId] of the process that wrote this pair.
  ///
  /// NULL means "written by a build that did not record one", which is
  /// treated as unowned and therefore deletable — the conservative choice
  /// for a field that has to survive an upgrade.
  final String? owner;

  RecoverySidecar withOwner(String owner) => RecoverySidecar(
    docId: docId,
    realPath: realPath,
    sequence: sequence,
    savedAt: savedAt,
    displayName: displayName,
    unsavedEditCount: unsavedEditCount,
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    owner: owner,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'appVersion': appVersion,
    'displayName': displayName,
    'docId': docId,
    if (owner != null) 'owner': owner,
    if (realPath != null) 'realPath': realPath,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'sequence': sequence,
    if (unsavedEditCount != null) 'unsavedEditCount': unsavedEditCount,
  };

  static RecoverySidecar? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final docId = raw['docId'];
    final savedAt = raw['savedAt'];
    final displayName = raw['displayName'];
    if (docId is! String || docId.isEmpty) return null;
    if (savedAt is! String) return null;
    if (displayName is! String) return null;
    final parsedSavedAt = DateTime.tryParse(savedAt);
    if (parsedSavedAt == null) return null;
    final realPath = raw['realPath'];
    final sequence = raw['sequence'];
    final unsaved = raw['unsavedEditCount'];
    final appVersion = raw['appVersion'];
    final schemaVersion = raw['schemaVersion'];
    final owner = raw['owner'];
    return RecoverySidecar(
      docId: docId,
      realPath: realPath is String ? realPath : null,
      sequence: sequence is int ? sequence : 0,
      savedAt: parsedSavedAt.toUtc(),
      displayName: displayName,
      unsavedEditCount: unsaved is int ? unsaved : null,
      appVersion: appVersion is String ? appVersion : '',
      schemaVersion: schemaVersion is int ? schemaVersion : kSchemaVersion,
      owner: owner is String && owner.isNotEmpty ? owner : null,
    );
  }
}

/// A complete, offerable survivor found by [RecoveryStore.scan].
final class RecoverySurvivor {
  const RecoverySurvivor({required this.sidecar, required this.snapshotPath});

  final RecoverySidecar sidecar;

  /// The full path of the snapshot, ready to read. Only ever produced
  /// for a pair that passed the completeness rules.
  final String snapshotPath;
}

/// What [RecoveryStore.scan] found and cleaned up.
final class RecoveryScanResult {
  const RecoveryScanResult({
    required this.survivors,
    required this.orphanedSnapshots,
    required this.orphanedSidecars,
    this.skippedLive = 0,
    this.sweptStrays = 0,
  });

  /// Complete pairs, NEWEST FIRST — the order the prompt offers them in.
  final List<RecoverySurvivor> survivors;

  /// Snapshots with no sidecar: interrupted writes, deleted silently.
  final int orphanedSnapshots;

  /// Sidecars with no snapshot: interrupted deletes, deleted silently.
  final int orphanedSidecars;

  /// Files belonging to ANOTHER LIVE INSTANCE that this scan left
  /// completely alone. Counted rather than merely skipped, because "the
  /// scan found nothing" and "the scan found a running sibling's work and
  /// correctly refused to touch it" are different facts and only one of
  /// them means recovery had nothing to do.
  final int skippedLive;

  /// Interrupted-write `.tmp` files removed from the recovery directory.
  ///
  /// Nothing else sweeps them. `AtomicWriter` only ever removes the temps
  /// of the write it is performing, and once a pair is keyed on
  /// `<docId>~<sessionId>` a dead session's slot is never written again —
  /// so before this counter existed, every crash during a snapshot write
  /// left up to ~600 KB of partial document in the app's own data root
  /// permanently, which in portable mode is the user's USB stick.
  final int sweptStrays;
}

/// Writes, scans and deletes recovery snapshots.
final class RecoveryStore {
  RecoveryStore({
    required this.fs,
    required this.writer,
    required String dataRoot,
    p.Context? context,
    String? sessionId,
    this.enabled = true,
  }) : context = context ?? p.context,
       sessionId = sessionId ?? newEntityId().v,
       directory = (context ?? p.context).join(dataRoot, kRecoveryDirName),
       sessionsDirectory = (context ?? p.context).join(
         dataRoot,
         kLiveSessionDirName,
       );

  final FileStore fs;
  final AtomicWriter writer;
  final p.Context context;

  /// FALSE IN THE DEGRADED SESSION, and it is the difference between "out
  /// of document persistence is disabled" and "…disabled except for the
  /// one file nobody remembered".
  ///
  /// ==================================================================
  /// WHY A FLAG HERE RATHER THAN AN `if` AT THE CALL SITE
  /// ==================================================================
  /// The degraded session builds this store anyway — `SessionController`
  /// calls [delete] on every clean shutdown, and a null here would be a
  /// null check on all of those call sites. So the store exists, pointed
  /// at a root that does not work, and EVERY method has to be safe there.
  /// [delete], [scan] and [readSnapshot] already were, because they only
  /// read or remove. [beginSession] was not: it ran unconditionally from
  /// the composition root and created `<dataRoot>/sessions/` plus a
  /// `.lease` file inside a root the app had just told the user it was not
  /// writing to.
  ///
  /// AND THE WORST SHAPE OF IT WAS THE RELATIVE PATH. When
  /// `applicationSupportDirectory()` throws, `DataRootUnusable` carries
  /// `attemptedPath: ''` — the honest answer, because the lookup is what
  /// failed and there is no directory to name. `p.join('', 'sessions')` is
  /// the RELATIVE string `sessions`, which `Directory('sessions').create()`
  /// resolves against the PROCESS'S CURRENT DIRECTORY. The one code path
  /// whose entire premise is "we cannot write anywhere safe" was writing
  /// into whatever folder the app happened to be launched from.
  ///
  /// Put on the store rather than at the call site so there is ONE place
  /// that knows, and so a method added later inherits the guard instead of
  /// needing a new `if` somebody has to remember.
  final bool enabled;

  /// Identifies THIS RUNNING PROCESS. Minted per instance, never
  /// persisted anywhere but inside a sidecar, and injected in tests so
  /// "two instances" is a thing a test can actually construct.
  final String sessionId;

  /// `<dataRoot>/recovery`.
  final String directory;

  /// `<dataRoot>/sessions` — one lease file per RUNNING instance.
  final String sessionsDirectory;

  /// This process's own lease, once [beginSession] has taken it.
  FileLease? _lease;

  /// What [_isLiveElsewhere] has already established, so one scan asks the
  /// filesystem once per session rather than once per file.
  ///
  /// ONLY THE `false` ENTRIES SURVIVE A SCAN. A session id is a
  /// per-process uuid, so one established as DEAD can never come back and
  /// caching that saves re-creating and re-deleting its lease file. LIVE
  /// is a statement about right now: the other instance may quit between
  /// two scans, and a stale `true` would withhold a survivor that has
  /// since become recoverable. [scan] drops them on entry.
  final Map<String, bool> _liveness = <String, bool>{};

  String snapshotPathFor(String docId) =>
      context.join(directory, '$docId$kSnapshotExtension');

  String sidecarPathFor(String docId) =>
      context.join(directory, '$docId$kSidecarExtension');

  /// Where the lease file for [sessionId] lives.
  String leasePathFor(String sessionId) =>
      context.join(sessionsDirectory, '$sessionId$kLeaseExtension');

  /// Announces that THIS PROCESS IS ALIVE, by taking a [FileLease] no
  /// other instance can take while this one runs.
  ///
  /// Called once, from the composition root, before anything scans. See
  /// the file header for what it buys: a concurrent launch can tell this
  /// session's live snapshot from a crashed session's leftovers, and
  /// therefore does not offer the user the chance to discard work that is
  /// being edited in another window right now.
  ///
  /// A FAILURE HERE IS DEGRADED, NOT FATAL, AND IT IS REPORTED. Recovery
  /// still works for this instance; what is lost is the ability of ANOTHER
  /// instance to see this one, which is exactly the pre-fix behaviour.
  /// Refusing to start over it would be a much worse trade.
  ///
  /// A DISABLED STORE TAKES NO LEASE AND CREATES NO DIRECTORY. There is
  /// nothing for another instance to be told about — this session writes
  /// no snapshot at all — so the lease would protect nothing and cost the
  /// one write the degraded session is defined by not making. It is
  /// reported rather than skipped in silence; see [enabled].
  Future<void> beginSession() async {
    if (!enabled) {
      logStorageEvent('recovery_disabled');
      return;
    }
    if (!await _livenessDirectoryReady()) return;
    _lease = await fs.acquireLease(leasePathFor(sessionId));
    if (_lease == null) logStorageEvent('recovery_lease_unavailable');
  }

  /// Makes sure [sessionsDirectory] exists, because ITS ABSENCE IS AN
  /// ANSWER and the wrong one.
  ///
  /// [FileStore.acquireLease] answers `null` for every failure, including
  /// "the parent directory is not there" — and `null` otherwise means
  /// "somebody live holds this". So probing a lease inside a directory
  /// that does not exist reports EVERY session as running, and a scan that
  /// believes that offers the user nothing at all: the survivor from the
  /// crash they just relaunched to recover from is silently withheld.
  ///
  /// When the directory cannot be created the answer is "no session is
  /// live", logged, which is the pre-lease behaviour. That is the right
  /// way round: a data root that will not take a directory will not take
  /// a recovery snapshot either, so nothing is writing live pairs into it
  /// — while the alternative would disable recovery entirely and say
  /// nothing.
  Future<bool> _livenessDirectoryReady() async {
    if (_livenessReady case final bool known) return known;
    // A DISABLED STORE NEVER CREATES IT. "No session is live" is the right
    // answer for the same reason the catch below gives it: nothing is
    // writing live pairs into a root that does not work, so there is
    // nothing to protect and nothing to be protected from. The difference
    // is that this branch does not have to touch the disk to find out.
    if (!enabled) return _livenessReady = false;
    try {
      await fs.createDirectory(sessionsDirectory);
      return _livenessReady = true;
      // The degraded session points every store at a root that does not
      // work. That is not an error here — it is the documented mode.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('recovery_lease_unavailable');
      return _livenessReady = false;
    }
  }

  bool? _livenessReady;

  /// Gives up this process's lease and removes its file. Called on clean
  /// shutdown.
  ///
  /// The lease is released by the OS anyway when the process ends, so this
  /// exists for the FILE: leaving one behind per crashed run would grow a
  /// directory of dead leases, and each of them costs the next launch's
  /// scan an open. A crashed run's lease is swept by the first scan that
  /// finds it unlocked.
  Future<void> endSession() async {
    final lease = _lease;
    _lease = null;
    if (lease == null) return;
    await lease.release();
    await _deleteIfPresent(leasePathFor(sessionId));
  }

  /// Writes a snapshot and its sidecar, in that order.
  ///
  /// Both go through [AtomicWriter] with `keepBackup: false`: a snapshot
  /// is already a backup, and a `.bak` of a backup would just double the
  /// footprint of a directory the user never sees.
  Future<Outcome<void>> write({
    required RecoverySidecar sidecar,
    required Uint8List documentBytes,
  }) async {
    // A DISABLED STORE WRITES NOTHING, AND SAYS SO. Not a live path today
    // — `DocumentSession.recoveryEnabled` is false in a degraded session
    // and `AutosaveScheduler` answers `disabled` without reaching here —
    // but the first statement below is `fs.createDirectory(directory)`,
    // which is exactly the unconditional write into an unusable root that
    // [beginSession] used to make. A future caller must not be able to
    // reintroduce it by finding this method reachable.
    if (!enabled) {
      logStorageEvent('recovery_disabled');
      return Err(
        StateError('Recovery is disabled: the data root is not writable.'),
      );
    }

    // GUARDED, because this method's whole signature promises a value.
    // `createDirectory` is the one call here that does not go through
    // `AtomicWriter` (which never throws), and it fails for real: a full
    // volume, a data root whose permissions changed mid-session, a stick
    // pulled out. Unguarded it becomes an unhandled future in the 30 s
    // autosave timer — the safety net stops existing and nothing says so.
    // Found by the fault-injection sweep in recovery_store_test.dart, not
    // by reading.
    try {
      await fs.createDirectory(directory);
    } on Object catch (e) {
      logStorageEvent('recovery_directory_failed');
      return Err(e);
    }

    // ==================================================================
    // STEP 0: RETIRE THE PREVIOUS SIDECAR *BEFORE* THE SNAPSHOT MOVES.
    // ==================================================================
    // A sidecar describes ONE set of bytes. The snapshot write below
    // REPLACES the previous snapshot at the same path, so the moment it
    // promotes, the old sidecar describes bytes that no longer exist —
    // and if this call then fails before the new sidecar lands, the disk
    // holds a NEW snapshot paired with a STALE sidecar. `scan()` sees a
    // matched pair, counts zero orphans, and the prompt offers
    // "Recover Smith (3 unsaved changes) from 10:00" for bytes that are
    // actually 47 edits from 11:00. A user who reasonably judges that
    // stale and discards it has just thrown away the newer work.
    //
    // The worse variant is worse than wrong copy: if a Save As happened
    // between the two snapshots, the stale sidecar's `realPath` points at
    // the OLD file, so recovering binds the new document's bytes to the
    // old path — and the user's next Ctrl+S overwrites a different
    // project.
    //
    // Deleting first makes the failure mode an ORPHANED SNAPSHOT, which
    // `scan()` already deletes silently and which can never be
    // mis-attributed. IT COSTS NOTHING REAL: the old snapshot's bytes are
    // destroyed by the promote below either way, so the only thing this
    // gives up is a sidecar that was about to become a lie.
    await _deleteIfPresent(sidecarPathFor(sidecar.docId));

    final snapshot = await writer.write(
      paths: SavePaths.forExactTarget(
        snapshotPathFor(sidecar.docId),
        context: context,
      ),
      bytes: documentBytes,
      keepBackup: false,
    );
    if (snapshot case Err(:final error)) {
      logStorageEvent('recovery_snapshot_failed');
      return Err(error);
    }

    // SECOND, and only now. A sidecar on disk is this store's promise
    // that its snapshot is complete; writing it first would make that
    // promise before it was true.
    final sidecarWrite = await writer.write(
      paths: SavePaths.forExactTarget(
        sidecarPathFor(sidecar.docId),
        context: context,
      ),
      bytes: _encodeSidecar(sidecar.withOwner(sessionId)),
      keepBackup: false,
    );
    if (sidecarWrite case Err(:final error)) {
      // The snapshot is now an orphan — and, because step 0 retired the
      // previous sidecar, GENUINELY an orphan rather than a new snapshot
      // wearing an old label. The next scan deletes it silently, because
      // a snapshot with no sidecar cannot be attributed to a document or
      // a time and must never be offered.
      logStorageEvent('recovery_sidecar_failed');
      return Err(error);
    }

    logStorageEvent('recovery_snapshot_ok', {
      'bytes': documentBytes.length,
      'hasRealPath': sidecar.realPath != null,
      'sequence': sidecar.sequence,
    });
    return const Ok<void>(null);
  }

  /// Deletes a document's snapshot pair — SIDECAR FIRST — unless the pair
  /// belongs to ANOTHER RUNNING INSTANCE of the app.
  ///
  /// Called at step 7 of a successful explicit save, and on clean exit
  /// (which INCLUDES an explicit "Don't Save" at the close prompt: that
  /// is a clean exit, and offering to recover work the user just told us
  /// to throw away is worse than losing it).
  ///
  /// ==================================================================
  /// WHY OWNERSHIP IS CHECKED AT ALL
  /// ==================================================================
  /// Nothing in this app prevents a second instance — there is no
  /// single-instance mutex in `apps/rackpal/lib` or in the Windows
  /// runner — and `atomic_writer.dart`'s external-change check explicitly
  /// anticipates "two instances of the app". The recovery directory is
  /// SHARED STATE keyed on document id, and `SaveQueue`, the thing that
  /// makes concurrent writers safe, is a per-process object that does not
  /// span processes.
  ///
  /// So: instance A and B both have Smith.rppj open. B has twenty
  /// minutes of unsaved work protected by `recovery/<docId>.rppj`. A
  /// saves — a save with nothing to do with B — and step 7 removed B's
  /// sidecar and snapshot. B's work then had no safety net at all, and
  /// nothing anywhere said so. The same happened when A simply quit.
  ///
  /// ==================================================================
  /// WHAT THIS FIXES, AND WHAT IT HONESTLY DOES NOT
  /// ==================================================================
  /// FIXES: a pair stamped with another process's [sessionId] is never
  /// deleted here. B's snapshot survives A's save and A's exit.
  ///
  /// The user's own Recover / Discard choices still work, because [scan]
  /// CLAIMS every survivor it offers — a pair the user was shown is a pair
  /// this process may act on. It offers only pairs whose writing session
  /// is GONE, which is why claiming one is now safe rather than merely
  /// necessary.
  ///
  /// A NOTE THAT USED TO BE HERE HAS BEEN DELETED BECAUSE IT WAS FALSE.
  /// It said the two instances still share one snapshot PATH, so A's
  /// autosave overwrites B's snapshot bytes. They do not: `AutosaveScheduler`
  /// builds the sidecar's key from `recoverySlotFor(documentId,
  /// recovery.sessionId)`, so two instances holding one document write to
  /// two different stems and neither can touch the other's bytes. Leaving
  /// the sentence in understated the fix and pointed the next reader at a
  /// risk that no longer exists — while the clause that WAS still live
  /// (A scanning and claiming B's pair) read as a subordinate afterthought
  /// to it. That one is fixed too, by the lease: see [scan].
  ///
  /// ==================================================================
  /// THE SECOND OWNERSHIP RULE: OUR OWN SLOT IS ALWAYS OURS
  /// ==================================================================
  /// The sidecar's `owner` is REWRITABLE — [_claim] rewrites it, and a
  /// concurrent launch used to rewrite it on a live pair. Once that had
  /// happened, the instance that actually wrote the pair could never
  /// retire it: its own step-7 save and its clean shutdown both landed on
  /// the guard above and declined, so a recovery prompt was offered on a
  /// later launch for work that had been saved perfectly.
  ///
  /// A SLOT, unlike an owner field, cannot be rewritten by anybody: it is
  /// the file name, and `<docId>~<sessionId>` names the session that wrote
  /// it. So a pair filed under this process's own slot is this process's
  /// to delete whatever the sidecar says — which is a strictly narrower
  /// statement than the old guard was making, and it is the true one.
  Future<void> delete(String docId) async {
    final existing = await _readSidecar(docId);
    if (existing != null &&
        existing.owner != null &&
        existing.owner != sessionId &&
        !_isOwnSlot(docId)) {
      // Not ours to throw away. Reported, never silent (§12.4: the event
      // code carries no path and no name).
      logStorageEvent('recovery_delete_skipped_foreign');
      return;
    }
    // Sidecar first: an interrupted delete then leaves an orphaned
    // SNAPSHOT, which scan() removes silently. The reverse order would
    // leave an orphaned SIDECAR pointing at nothing, which is the shape a
    // half-finished write also has — indistinguishable, and one of them
    // would deserve to be offered.
    await _deleteIfPresent(sidecarPathFor(docId));
    // EVERY SPELLING, not just the one this build writes (DR-015).
    // "Discard" that left a legacy snapshot behind would re-offer the
    // same crash at every launch, and the user would have no way to make
    // the prompt stop.
    for (final ext in kSnapshotExtensions) {
      await _deleteIfPresent(context.join(directory, '$docId$ext'));
    }
  }

  /// Scans the recovery directory, pairs sidecars with snapshots, deletes
  /// the unpaired, and returns the survivors newest first.
  ///
  /// SAFE TO AWAIT AT STARTUP, unlike the recents probe. The data root is
  /// always local — either app support or the `data/` directory beside
  /// the executable — and this reads a handful of small JSON sidecars
  /// from it. There is no network path here to hang on.
  Future<RecoveryScanResult> scan() async {
    // "Live" is a statement about the instant this scan runs. See
    // [_liveness].
    _liveness.removeWhere((_, live) => live);

    // BEFORE THE EARLY RETURN BELOW, and that placement is the whole
    // point. A run that crashed with a CLEAN document left a lease and
    // nothing else — no snapshot, no sidecar, no stray — so on an
    // installation that has never had a recovery directory at all, the
    // early return would skip the sweep forever and the sessions
    // directory would grow by one file per crash. Measured on a real
    // build: with the sweep after the early return, a killed run's lease
    // was still there on the next launch.
    await _sweepDeadLeases();

    if (!await fs.exists(directory)) {
      return const RecoveryScanResult(
        survivors: [],
        orphanedSnapshots: 0,
        orphanedSidecars: 0,
      );
    }

    final List<String> entries;
    try {
      entries = await fs.listDirectory(directory);
      // An unreadable recovery directory must not stop the app starting.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('recovery_scan_failed');
      return const RecoveryScanResult(
        survivors: [],
        orphanedSnapshots: 0,
        orphanedSidecars: 0,
      );
    }

    // SLOT → THE PATH THE SNAPSHOT ACTUALLY HAS. Not rebuilt from
    // `snapshotPathFor`, because after DR-015 a snapshot on disk may be
    // spelled `.rackpal` while this build writes `.rmpj` — and a scan
    // that rebuilt the name would offer a survivor whose bytes it cannot
    // read, then fail to delete it on Discard.
    final snapshotPaths = <String, String>{};
    final sidecarIds = <String>{};
    final strays = <String>[];
    for (final entry in entries) {
      final name = context.basename(entry);
      // `.tmp` FIRST: `<slot>.rmpj.tmp` is not a snapshot, and
      // classifying it as one would delete a live write in progress.
      final snapshotExt = name.endsWith(kTempSuffix)
          ? ''
          : kSnapshotExtensions.firstWhere(name.endsWith, orElse: () => '');
      if (name.endsWith(kTempSuffix)) {
        strays.add(entry);
      } else if (snapshotExt.isNotEmpty) {
        snapshotPaths[name.substring(0, name.length - snapshotExt.length)] =
            entry;
      } else if (name.endsWith(kSidecarExtension)) {
        sidecarIds.add(
          name.substring(0, name.length - kSidecarExtension.length),
        );
      }
      // Anything else in this directory is not ours to interpret and is
      // left strictly alone.
    }

    var skippedLive = 0;

    var orphanedSnapshots = 0;
    for (final id in snapshotPaths.keys.toSet().difference(sidecarIds)) {
      // NOT NECESSARILY AN INTERRUPTED WRITE. `write` retires the previous
      // sidecar BEFORE it moves the snapshot, so a live instance in the
      // middle of a snapshot looks exactly like this from outside. Before
      // the lease, a concurrent launch could delete a running instance's
      // snapshot mid-write and call it housekeeping.
      if (await _isLiveElsewhere(_sessionOfSlot(id))) {
        skippedLive++;
        continue;
      }
      await _deleteIfPresent(snapshotPaths[id]!);
      orphanedSnapshots++;
    }

    var orphanedSidecars = 0;
    final survivors = <RecoverySurvivor>[];
    for (final id in sidecarIds) {
      // ==================================================================
      // THE LIVE-PAIR RULE, AND IT COMES BEFORE EVERYTHING ELSE.
      // ==================================================================
      // A pair written by a session that is STILL RUNNING is that
      // session's safety net for work being edited in another window right
      // now. Offering it describes live in-flight work as a crash
      // survivor, and the user's "Discard" — an entirely reasonable answer
      // to that prompt — deletes the only copy of it. So: not claimed, not
      // offered, not deleted, not counted as an orphan.
      if (await _isLiveElsewhere(_sessionOfSlot(id))) {
        skippedLive++;
        continue;
      }
      if (!snapshotPaths.containsKey(id)) {
        await _deleteIfPresent(sidecarPathFor(id));
        orphanedSidecars++;
        continue;
      }
      final sidecar = await _readSidecar(id);
      if (sidecar == null) {
        // A sidecar we cannot parse cannot name a document or a time, so
        // its snapshot cannot be honestly offered. Both go. `delete`'s
        // ownership guard cannot help here — there is no readable owner —
        // so it falls through to the delete, which is right: an
        // unparseable sidecar is not offerable by anyone.
        await delete(id);
        orphanedSidecars++;
        continue;
      }
      // THE SECOND LIVENESS CHECK, and it is not redundant. The stem names
      // the session that WROTE the pair; `owner` names the session that
      // last CLAIMED it. A survivor from a crashed run that a still-running
      // instance has already claimed and offered to its user belongs to
      // that instance's Recover / Discard decision, not to ours.
      if (await _isLiveElsewhere(sidecar.owner)) {
        skippedLive++;
        continue;
      }
      // CLAIM IT. A pair this scan is about to OFFER is a pair whose
      // Recover / Discard the user is about to decide, and `delete`'s
      // ownership guard would otherwise refuse to act on that decision —
      // "Discard" would leave the pair on disk to be offered again next
      // launch. Claiming rewrites only the sidecar, atomically, with
      // every displayed field unchanged.
      final claimed = await _claim(id, sidecar);
      survivors.add(
        RecoverySurvivor(
          sidecar: claimed,
          snapshotPath: snapshotPaths[id]!,
        ),
      );
    }

    // ==================================================================
    // THE INTERRUPTED-WRITE SWEEP, WHICH NOTHING ELSE PERFORMS.
    // ==================================================================
    // `AtomicWriter` sweeps only the temps of the write it is currently
    // doing (step 8), and it sweeps them by PATH. While a pair was filed
    // under the bare document id that was enough — the next session's
    // autosave of the same document wrote the identical paths and cleared
    // whatever was there. A slot carries a per-process uuid, so a dead
    // session's paths are never written again and its `.tmp` files became
    // unreachable by every cleanup path in the app: one partial document
    // of up to ~600 KB per crash-during-snapshot-write, accumulating
    // forever inside the data root — which in portable mode is the user's
    // USB stick.
    var sweptStrays = 0;
    for (final stray in strays) {
      if (await _isLiveElsewhere(_sessionOfSlot(_slotOfArtifact(stray)))) {
        skippedLive++;
        continue;
      }
      if (await _deleteIfPresent(stray)) sweptStrays++;
    }

    survivors.sort((a, b) => b.sidecar.savedAt.compareTo(a.sidecar.savedAt));

    if (survivors.isNotEmpty ||
        orphanedSnapshots > 0 ||
        orphanedSidecars > 0 ||
        skippedLive > 0 ||
        sweptStrays > 0) {
      logStorageEvent('recovery_scan', {
        'survivors': survivors.length,
        'orphanedSnapshots': orphanedSnapshots,
        'orphanedSidecars': orphanedSidecars,
        'skippedLive': skippedLive,
        'sweptStrays': sweptStrays,
      });
    }

    return RecoveryScanResult(
      survivors: survivors,
      orphanedSnapshots: orphanedSnapshots,
      orphanedSidecars: orphanedSidecars,
      skippedLive: skippedLive,
      sweptStrays: sweptStrays,
    );
  }

  /// True when [sessionId] names ANOTHER process that is running right
  /// now.
  ///
  /// Answered by the kernel: a lease we can take is a lease nobody holds,
  /// and a lease nobody holds belongs to a process that has ended. A stale
  /// lease file found that way is removed on the spot, so the directory
  /// does not accumulate one per crashed run.
  ///
  /// THIS SESSION IS NOT "SOMEBODY ELSE", and every caller means the
  /// question that way. Our own pairs are ours to offer, to sweep and to
  /// retire; it is another instance's that must be left untouched.
  ///
  /// `null` / empty — a pair written by a build that recorded no session —
  /// is NOT live. That is the same conservative default the sidecar's
  /// `owner` field already documents: unowned means deletable, which is
  /// the answer that lets an upgrade still clean up after itself.
  Future<bool> _isLiveElsewhere(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return false;
    if (sessionId == this.sessionId) return false;
    final cached = _liveness[sessionId];
    if (cached != null) return cached;
    if (!await _livenessDirectoryReady()) return _liveness[sessionId] = false;
    final path = leasePathFor(sessionId);
    final lease = await fs.acquireLease(path);
    if (lease == null) return _liveness[sessionId] = true;
    await lease.release();
    await _deleteIfPresent(path);
    return _liveness[sessionId] = false;
  }

  /// Removes the lease file of every session that is no longer running.
  ///
  /// [_isLiveElsewhere] already deletes the ones it is asked about, but it
  /// is only ever asked about sessions that left a recovery artefact
  /// behind. A run that crashed with a clean document left a lease and
  /// nothing else.
  Future<void> _sweepDeadLeases() async {
    if (!await _livenessDirectoryReady()) return;
    final List<String> entries;
    try {
      entries = await fs.listDirectory(sessionsDirectory);
      // A sessions directory we cannot list is untidy, never fatal.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return;
    }
    for (final entry in entries) {
      final name = context.basename(entry);
      if (!name.endsWith(kLeaseExtension)) continue;
      // `_isLiveElsewhere` deletes the file when it finds it unlocked, and
      // answers false without touching the disk for our own id.
      await _isLiveElsewhere(
        name.substring(0, name.length - kLeaseExtension.length),
      );
    }
  }

  /// The session half of a `<docId>~<sessionId>` slot, or null for a bare
  /// document id written by a build that predates slots.
  String? _sessionOfSlot(String slot) {
    final i = slot.lastIndexOf(kRecoverySlotSeparator);
    if (i < 0 || i == slot.length - 1) return null;
    return slot.substring(i + 1);
  }

  /// The slot a recovery FILE belongs to: `<slot>.rmpj.tmp` and
  /// `<slot>.json.tmp` both answer `<slot>`.
  String _slotOfArtifact(String path) {
    var name = context.basename(path);
    for (final suffix in [
      kTempSuffix,
      ...kSnapshotExtensions,
      kSidecarExtension,
    ]) {
      if (name.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
      }
    }
    return name;
  }

  /// True when [docId] is a slot THIS session wrote. See [delete].
  bool _isOwnSlot(String docId) =>
      docId.endsWith('$kRecoverySlotSeparator$sessionId');

  /// Reads a survivor's document bytes.
  ///
  /// Deliberately takes ONE survivor. There is no "read them all" method,
  /// and adding one would be the first step towards a diagnostics bundle
  /// that ships a client's site address (CR-096).
  Future<Uint8List> readSnapshot(RecoverySurvivor survivor) =>
      fs.readBytes(survivor.snapshotPath);

  /// Re-stamps [sidecar] as belonging to this process, so the user's
  /// Recover / Discard decision on it can be carried out.
  ///
  /// A FAILED CLAIM IS NOT FATAL AND IS NOT SILENT. The survivor is still
  /// offered — the user can still recover their work, which is the whole
  /// point — but a later [delete] will decline it and it will be offered
  /// again next launch. Refusing to offer a recoverable snapshot because
  /// its bookkeeping could not be updated would be a far worse trade.
  Future<RecoverySidecar> _claim(String docId, RecoverySidecar sidecar) async {
    if (sidecar.owner == sessionId) return sidecar;
    final claimed = sidecar.withOwner(sessionId);
    final result = await writer.write(
      paths: SavePaths.forExactTarget(sidecarPathFor(docId), context: context),
      bytes: _encodeSidecar(claimed),
      keepBackup: false,
    );
    if (result case Err()) {
      logStorageEvent('recovery_claim_failed');
      return sidecar;
    }
    return claimed;
  }

  Uint8List _encodeSidecar(RecoverySidecar sidecar) => Uint8List.fromList(
    utf8.encode(
      const JsonEncoder.withIndent('  ').convert(sidecar.toJson()),
    ),
  );

  Future<RecoverySidecar?> _readSidecar(String docId) async {
    try {
      final raw = jsonDecode(
        utf8.decode(await fs.readBytes(sidecarPathFor(docId))),
      );
      return RecoverySidecar.fromJson(raw);
      // Unreadable or malformed is the same answer: not offerable.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  /// Returns whether a file was actually removed — which is what lets the
  /// stray sweep report a number it checked rather than a number it
  /// intended.
  Future<bool> _deleteIfPresent(String path) async {
    try {
      if (!await fs.exists(path)) return false;
      await fs.delete(path);
      return true;
      // Cleanup that fails leaves a file the next scan will try again on.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return false;
    }
  }
}
