// Orchestrates opening and saving a document. THE ONLY CLASS THAT KNOWS A
// DOCUMENT LIVES IN A FILE — everything below it deals in bytes and paths,
// and everything above it deals in a document and a session. Swapping this
// for a `RemoteDocumentStore` later touches one class, which is what the
// cloud-ready goal actually costs.
//
// The full §9.3 sequence, and where each step happens:
//   1. Snapshot the document to a plain JSON tree     — here, synchronously
//   2. Serialize off-thread (Isolate.run)             — here, via Serializer
//   3. Write the tmp, flush, close                    — AtomicWriter step 3
//   4. Produce the backup (copy + rename)             — AtomicWriter step 4
//   5. Promote (rename tmp -> target)                 — AtomicWriter step 5
//   6. markSavedAt(capturedStateId)                   — here
//   7. Delete this document's recovery snapshot       — here
//   8. Push to recents; re-baseline                   — here (+ the sweep,
//                                                       AtomicWriter)
//
// Steps 6 and 7 are here and not in the writer because the writer must not
// know what a document is. Their ORDER relative to step 5 is the point: the
// snapshot is deleted only after the new bytes are unambiguously at the
// target (invariant I5), so a crash between them costs nothing.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/errors.dart';
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate/src/storage/recovery_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';
import 'package:rackmate/src/storage/serialization.dart';
import 'package:rackmate/src/storage/storage_log.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// A document that came off a disk.
final class OpenedDocument {
  const OpenedDocument({
    required this.document,
    required this.path,
    required this.baseline,
    required this.openReadOnly,
    required this.originalBytes,
    required this.migratedFromSchemaVersion,
  });

  final RackDocument document;

  /// Where it came from. Null for a starter project or a recovered
  /// snapshot opened as an untitled copy.
  final String? path;

  /// The (size, modified) the next save's external-change check compares
  /// against.
  final FileBaseline baseline;

  /// True when the file's `schemaVersion` is newer than this build's but
  /// its `minReaderVersion` is still satisfied. The document is fully
  /// editable in memory and still autosaves to a recovery snapshot — the
  /// user is blocked from OVERWRITING, not from working. Ctrl+S routes to
  /// Save As.
  final bool openReadOnly;

  /// The exact bytes read. Retained ONLY when [migratedFromSchemaVersion]
  /// is non-null, for the pre-update snapshot; null otherwise, because
  /// holding a redundant ~600 KB for the whole session would be waste.
  final Uint8List? originalBytes;

  /// The `schemaVersion` the file was stored at, when that was OLDER than
  /// this build's. Non-null means the first save will rewrite the file at
  /// a version an older build cannot read — which is what earns the
  /// pre-update snapshot.
  final int? migratedFromSchemaVersion;
}

/// A document that reached a disk.
final class SavedFile {
  const SavedFile({
    required this.paths,
    required this.baseline,
    required this.savedStateId,
    required this.bytesWritten,
    required this.backupAttempted,
    required this.backupUpdated,
  });

  final SavePaths paths;
  final FileBaseline baseline;

  /// The `stateId` that was actually serialized. The caller has already
  /// passed this to `markSavedAt`; it is echoed so a UI can assert on it.
  final int savedStateId;

  final int bytesWritten;

  /// Whether a backup was attempted at all. False for a first save — see
  /// `WriteReceipt.backupAttempted` for why the status line needs the
  /// difference.
  final bool backupAttempted;

  /// False when the `.bak` could not be refreshed. The save SUCCEEDED.
  /// Surfaces as a status line, never a dialog, and never silence.
  final bool backupUpdated;
}

/// Opens and saves `.rackmate` documents.
final class DocumentStore {
  DocumentStore({
    required this.fs,
    required this.writer,
    required this.recovery,
    this.codec = const JsonDocumentCodec(),
    this.serializer = isolateSerializer,
    this.deserializer = isolateDeserializer,
    p.Context? context,
    this.isWindows = true,
  }) : context = context ?? p.context;

  final FileStore fs;
  final AtomicWriter writer;
  final RecoveryStore recovery;
  final JsonDocumentCodec codec;
  final Serializer serializer;
  final Deserializer deserializer;
  final p.Context context;
  final bool isWindows;

  // --- OPEN ------------------------------------------------------------

  /// Reads and decodes the document at [path].
  ///
  /// Every expected failure is a value (CR-093). The import-hardening
  /// limits run inside [deserializer], BEFORE `jsonDecode`, because a
  /// deeply nested file is a process death rather than an exception.
  Future<Outcome<OpenedDocument>> open(String path) async {
    final Uint8List bytes;
    final FileFacts? facts;
    try {
      facts = await fs.stat(path);
      if (facts == null) {
        // "NOT THERE" AND "CANNOT TELL" ARE DIFFERENT ANSWERS, and this
        // is the one place the difference has teeth. Measured: `stat` and
        // `exists` on an unreachable UNC path both answer NEGATIVELY
        // without throwing — so a disconnected network drive is
        // indistinguishable from a deleted file at this line alone.
        //
        // `OpenNotFound` is the ONLY OpenError that
        // `shouldEvictOnOpenFailure` acts on, so reporting it here
        // unconditionally would silently drop a recents entry for a file
        // that is perfectly fine and merely on a share that is asleep —
        // exactly the eviction §9.5 forbids. Confirming the DIRECTORY is
        // reachable first is what makes the not-found definitive.
        if (!await _existsQuietly(context.dirname(path))) {
          return Err(OpenUnreachable(path));
        }
        return Err(
          OpenNotFound(path, backup: await _backupFactsFor(path)),
        );
      }
      bytes = await fs.readBytes(path);
    } on Object catch (e, st) {
      return Err(await _classifyOpen(path, e, st));
    }

    return decodeBytes(path: path, bytes: bytes, facts: facts);
  }

  /// Decodes [bytes] that came from [path].
  ///
  /// Separate from [open] so a recovery snapshot, a bundled starter asset
  /// and a `.bak` all reach the identical decode-and-classify path — one
  /// implementation means the error surface cannot differ between the
  /// route the user usually takes and the routes they take on a bad day.
  Future<Outcome<OpenedDocument>> decodeBytes({
    required String? path,
    required Uint8List bytes,
    FileFacts? facts,
    String? asNewDocumentId,
  }) async {
    final label = path ?? '';

    // THE DESERIALIZER CALL IS GUARDED, AND THAT IS NOT BELT-AND-BRACES.
    // `deserializer` is `Isolate.run` in production. Everything INSIDE it
    // comes back as an `Err` value (CR-093), but the spawn itself can
    // fail — under memory pressure `Isolate.run` throws rather than
    // answering — and an `OutOfMemoryError` decoding a file near the
    // 64 MB cap is an Error that no `on Exception` clause anywhere in the
    // chain catches. Unguarded, that completes this future with an error
    // which propagates out of `decodeBytes`, out of `open`, out of
    // `openPath`, and into an `unawaited(...)` in the shell: the user
    // presses Ctrl+O or clicks a recent file and NOTHING HAPPENS AT ALL.
    // No dialog, no log, no crash. "Never silently do nothing" has no
    // exception for our own infrastructure failing.
    final Outcome<JsonMap> tree;
    try {
      tree = await deserializer(bytes);
    } on Object catch (e, st) {
      return Err(OpenUnexpected(label, cause: e, stackTrace: st));
    }
    if (tree case Err(:final error)) {
      return Err(await _classifyDecode(label, error));
    }
    final raw = (tree as Ok<JsonMap>).value;

    // A COPY GETS A NEW IDENTITY, AND IT HAS TO HAPPEN HERE.
    // `RackDocument.id` is final, so the only place it can be changed is
    // the raw envelope, before the typed decode. The caller that needs
    // this is the start card: a starter asset is opened as an UNTITLED
    // COPY, and two copies sharing a document id would share a recovery
    // snapshot path (`recovery/<docUuid>.rackmate`) — so recovering one
    // would offer the other's work — and, once both were saved, two
    // different files on disk would claim to be the same document.
    if (asNewDocumentId != null) raw[kKeyId] = asNewDocumentId;

    // Read the stored schemaVersion BEFORE the migration chain rewrites
    // it — after `readFromJsonTree` the envelope says kSchemaVersion and
    // the fact that a migration ran is gone.
    final storedSchemaVersion = raw[kKeySchemaVersion];

    final decoded = readFromJsonTree(raw);
    if (decoded case Err(:final error)) {
      return Err(await _classifyDecode(label, error));
    }
    final ok = decoded as Ok<RackDocument>;

    final migratedFrom =
        storedSchemaVersion is int && storedSchemaVersion < kSchemaVersion
        ? storedSchemaVersion
        : null;

    logStorageEvent('open_ok', {
      'bytes': bytes.length,
      'readOnly': ok.openReadOnly,
      'migratedFrom': migratedFrom ?? -1,
    });

    return Ok(
      OpenedDocument(
        document: ok.value,
        path: path,
        baseline: FileBaseline.of(facts),
        openReadOnly: ok.openReadOnly,
        // Retained only when it will actually be used — see the field.
        originalBytes: migratedFrom == null ? null : bytes,
        migratedFromSchemaVersion: migratedFrom,
      ),
    );
  }

  // --- SAVE ------------------------------------------------------------

  /// Saves [controller]'s document to [paths].
  ///
  /// STEPS 1 AND 2 ARE THE REASON THIS METHOD EXISTS RATHER THAN THE
  /// CALLER JUST HANDING BYTES TO THE WRITER. `capturedStateId` and the
  /// JSON tree are taken synchronously, with NOTHING awaited between
  /// them, and the id is what step 6 marks saved. Marking `doc.stateId`
  /// saved after the await would clear the dirty flag for edits made
  /// during it — edits that were never written, and whose recovery
  /// snapshot step 7 is about to delete.
  /// [keepBackup] false suppresses step 4 for THIS SAVE ONLY. It has
  /// exactly one caller and one reason: after the `.bak` fallback the file
  /// at the target is the DAMAGED one, and step 4 copies whatever is at
  /// the target over `<target>.bak` — which is the good version the user
  /// was just rescued by. See `SessionController._openBackup`.
  Future<Outcome<SavedFile>> save({
    required DocumentController controller,
    required SavePaths paths,
    FileBaseline? expected,
    bool keepBackup = true,
  }) async {
    // ---- STEP 1: SNAPSHOT. Do not insert an await between these two. --
    final capturedStateId = controller.doc.stateId;
    final tree = codec.encodeToJsonTree(controller.doc);
    final docId = controller.doc.id.v;
    // -------------------------------------------------------------------

    // ---- STEP 2: SERIALIZE OFF-THREAD (AC-006, CR-099). ---------------
    final Uint8List bytes;
    try {
      bytes = await serializer(tree);
    } on Object catch (e, st) {
      // A serializer failure is a programmer error, not an expected
      // outcome: the tree came from our own encoder moments ago.
      return Err(
        SaveUnexpected(
          paths: paths,
          step: 2,
          cause: e,
          stackTrace: st,
        ),
      );
    }

    // ---- STEPS 3-5 and the step-8 sweep. ------------------------------
    final written = await writer.write(
      paths: paths,
      bytes: bytes,
      expected: expected,
      keepBackup: keepBackup,
    );
    if (written case Err(:final error)) {
      // A FAILED SAVE MUST LEAVE THE DOCUMENT DIRTY. Nothing below runs:
      // the state id is not marked saved and the recovery snapshot is not
      // deleted, so the user's unsaved work still has both a dirty flag
      // and a snapshot behind it.
      return Err(error);
    }
    final receipt = (written as Ok<WriteReceipt>).value;

    // ---- STEP 6: the state that was WRITTEN goes clean. ---------------
    controller.markSavedAt(capturedStateId);

    // ---- STEP 7: only now is the snapshot redundant. ------------------
    // KEYED ON THE BARE DOCUMENT ID, which is a pair written by a build
    // that predates recovery SLOTS. The live session's own snapshot is at
    // `<docId>~<sessionId>` and is retired by `SessionController._writeTo`,
    // which is the only layer that knows which session it is — see
    // `recoverySlotFor`. This call is the legacy sweep, and it is
    // ownership-guarded, so it cannot reach another instance's pair.
    await recovery.delete(docId);

    // Step 8's recents push and title update belong to the session layer,
    // which owns the display name; the baseline it needs is in the
    // receipt.
    return Ok(
      SavedFile(
        paths: receipt.paths,
        baseline: receipt.baseline,
        savedStateId: capturedStateId,
        bytesWritten: receipt.bytesWritten,
        backupAttempted: receipt.backupAttempted,
        backupUpdated: receipt.backupUpdated,
      ),
    );
  }

  /// Serializes the controller's document without writing it — for the
  /// recovery snapshot and the pre-update snapshot, which need the same
  /// two-phase split but none of the save path's ceremony.
  ///
  /// Returns the bytes AND the state id they correspond to, so the caller
  /// can record an honest `unsavedEditCount` in the sidecar.
  Future<({Uint8List bytes, int stateId})> serializeSnapshot(
    DocumentController controller,
  ) async {
    // Same rule as [save]: no await between these two lines.
    final capturedStateId = controller.doc.stateId;
    final tree = codec.encodeToJsonTree(controller.doc);
    return (bytes: await serializer(tree), stateId: capturedStateId);
  }

  // --- Error classification --------------------------------------------

  Future<OpenError> _classifyOpen(
    String path,
    Object error,
    StackTrace stackTrace,
  ) async {
    final errno = errnoOf(error);
    if (errno == null) {
      return OpenUnexpected(path, cause: error, stackTrace: stackTrace);
    }
    final parent = context.dirname(path);
    final parentExists = await _existsQuietly(parent);
    final category = osErrorToCategory(
      errno,
      isWindows: isWindows,
      parentDirExists: parentExists,
    );
    return switch (category) {
      // ONLY reached when the directory itself was confirmed reachable —
      // which is exactly the condition recents eviction requires.
      StorageFailure.fileMissing => OpenNotFound(
        path,
        backup: await _backupFactsFor(path),
      ),
      StorageFailure.directoryMissing ||
      StorageFailure.unreachable => OpenUnreachable(path),
      StorageFailure.permissionDenied ||
      StorageFailure.readOnlyTarget => OpenPermissionDenied(path),
      StorageFailure.pathTooLong ||
      StorageFailure.locked ||
      StorageFailure.diskFull ||
      StorageFailure.unknown => OpenUnexpected(
        path,
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }

  Future<OpenError> _classifyDecode(String path, Object error) async =>
      switch (error) {
        DocumentTooLargeError(:final bytes, :final limit) => OpenTooLarge(
          path,
          bytes: bytes,
          limit: limit,
        ),
        JsonTooDeeplyNestedError(:final depth, :final limit) =>
          OpenTooDeeplyNested(path, depth: depth, limit: limit),
        UnsupportedZipContainerError() => OpenZipContainer(path),
        NotARackMateFileError(:final generator) => OpenNotARackMateFile(
          path,
          generator: generator,
        ),
        NewerSchemaError(
          :final minReaderVersion,
          :final supportedSchemaVersion,
        ) =>
          OpenNewerSchema(
            path,
            minReaderVersion: minReaderVersion,
            supportedSchemaVersion: supportedSchemaVersion,
          ),
        // Everything else that got this far is a file that IS a RackMate
        // file and is damaged: a truncated write, a bad sector, a merge
        // conflict marker. This is where the .bak earns its existence.
        _ => OpenCorrupt(
          path,
          detail: error.toString(),
          backup: await _backupFactsFor(path),
        ),
      };

  /// What is known about a sibling `.bak`, or null when there is none.
  ///
  /// Called on BOTH the not-found and the corrupt paths, because those
  /// are the two moments a backup is worth anything. Without this the
  /// `.bak` is decoration: it exists, and nothing ever offers it.
  Future<BackupFacts?> _backupFactsFor(String path) async {
    if (path.isEmpty) return null;
    final backupPath = '$path$kBackupSuffix';
    try {
      final facts = await fs.stat(backupPath);
      if (facts == null) return null;
      return BackupFacts(
        path: backupPath,
        modified: facts.modified,
        size: facts.size,
      );
      // A missing or unreadable `.bak` is not an error — it is the
      // common case. Answering "there is no backup" is always safe.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  Future<bool> _existsQuietly(String path) async {
    try {
      return await fs.exists(path);
      // A directory whose existence we cannot determine is treated as
      // ABSENT, which routes errno 3 to "unreachable" rather than to
      // "path too long" — the conservative choice, since an unreachable
      // location must never evict a recents entry.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return false;
    }
  }
}
