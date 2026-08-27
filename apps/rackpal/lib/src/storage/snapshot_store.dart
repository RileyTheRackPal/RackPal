// Pre-update snapshots (docs/03-architecture.md §9.3): "Pre-update
// snapshots go to <appSupport>/snapshots/<docUuid>/<sequence>.rackpal,
// pruned to the last 10."
//
// Distinct from the RECOVERY store next door, and the distinction is
// worth stating because both write a .rackpal into the data root:
//   * a RECOVERY snapshot is unsaved work rescued from a crash. There is
//     at most one per document and it is deleted the moment the work is
//     safely on disk.
//   * a PRE-UPDATE snapshot is a saved, good document captured before an
//     irreversible transformation. There are up to ten per document and
//     they survive saves.
//
// ONE REAL M1 CALL SITE, not dead code: when a document was MIGRATED on
// open (`schemaVersion` on disk was older than `kSchemaVersion`), the
// ORIGINAL bytes are snapshotted before the first save rewrites that file
// at the new version. That rewrite is irreversible for any older build the
// user might still have installed, and the migration chain is append-only
// precisely because shipped files are historical records — so the file the
// user had before we touched it is worth ten kilobytes of disk.
//
// The device-builder's "before applying a template update" call site
// belongs to M4 and is not written now.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The subdirectory of the data root holding pre-update snapshots.
const String kSnapshotsDirName = 'snapshots';

/// §9.3: "pruned to the last 10".
const int kMaxSnapshotsPerDocument = 10;

/// Writes and prunes `<dataRoot>/snapshots/<docUuid>/<sequence>.rackpal`.
final class SnapshotStore {
  SnapshotStore({
    required this.fs,
    required this.writer,
    required String dataRoot,
    p.Context? context,
    this.maxPerDocument = kMaxSnapshotsPerDocument,
  }) : context = context ?? p.context,
       root = (context ?? p.context).join(dataRoot, kSnapshotsDirName);

  final FileStore fs;
  final AtomicWriter writer;
  final p.Context context;
  final int maxPerDocument;

  /// `<dataRoot>/snapshots`.
  final String root;

  String directoryFor(String docId) => context.join(root, docId);

  String pathFor(String docId, int sequence) =>
      context.join(directoryFor(docId), '$sequence$kDocumentExtension');

  /// Stores [bytes] as `<docId>/<sequence>.rmpj`, then prunes.
  ///
  /// Failure is reported but is NEVER fatal to the operation that
  /// triggered it: a snapshot that could not be taken is a lost safety
  /// net, not a reason to refuse the user's save.
  Future<Outcome<String>> write({
    required String docId,
    required int sequence,
    required Uint8List bytes,
  }) async {
    final directory = directoryFor(docId);
    final path = pathFor(docId, sequence);
    try {
      await fs.createDirectory(directory);
      final result = await writer.write(
        paths: SavePaths.forExactTarget(path, context: context),
        bytes: bytes,
        keepBackup: false,
      );
      if (result case Err(:final error)) {
        logStorageEvent('snapshot_write_failed', {'sequence': sequence});
        return Err(error);
      }
      final pruned = await prune(docId);
      logStorageEvent('snapshot_ok', {
        'sequence': sequence,
        'bytes': bytes.length,
        'pruned': pruned,
      });
      return Ok(path);
      // A snapshot is a safety net, not the operation itself. Whatever
      // went wrong is reported as a value and never propagates into the
      // save that asked for it.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logStorageEvent('snapshot_write_failed', {'sequence': sequence});
      return Err(e);
    }
  }

  /// The sequence numbers stored for [docId], ASCENDING.
  ///
  /// Sorted NUMERICALLY, not lexically. A lexical sort makes `10` sort
  /// before `9`, so the prune would delete the newest snapshot and keep
  /// the oldest — precisely inverting the feature.
  Future<List<int>> sequencesFor(String docId) async => [
    for (final e in await _entriesFor(docId)) e.sequence,
  ];

  /// The snapshots stored for [docId] with the path each ACTUALLY has,
  /// ascending by sequence.
  ///
  /// THE PATH IS CARRIED RATHER THAN REBUILT, and after DR-015 it has to
  /// be. A snapshot written by an earlier build is `<sequence>.rackpal`;
  /// `pathFor` now spells `.rmpj`. A prune that rebuilt the name would
  /// COUNT the old file and then fail to delete it — so the ten-per-
  /// document cap would apply to the new files only, the old ones would
  /// sit in AppData forever, and the failure would be silent because a
  /// snapshot that will not delete is deliberately swallowed.
  Future<List<({int sequence, String path})>> _entriesFor(String docId) async {
    final directory = directoryFor(docId);
    if (!await fs.exists(directory)) return const [];
    final List<String> entries;
    try {
      entries = await fs.listDirectory(directory);
      // An unlistable snapshot directory means "no snapshots", which is
      // a usable answer; it must not fail the prune it was called for.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return const [];
    }
    final found = <({int sequence, String path})>[];
    for (final entry in entries) {
      final name = context.basename(entry);
      // EVERY SPELLING THIS APP HAS EVER WRITTEN (DR-015), because a
      // snapshot IS an ordinary document and the rename did not touch a
      // byte inside one.
      final ext = kDocumentExtensions.firstWhere(
        name.endsWith,
        orElse: () => '',
      );
      if (ext.isEmpty) continue;
      final parsed = int.tryParse(
        name.substring(0, name.length - ext.length),
      );
      // A file whose stem is not an integer is not one of ours; leave it.
      if (parsed != null) {
        found.add((sequence: parsed, path: context.join(directory, name)));
      }
    }
    return found..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  /// Deletes all but the newest [maxPerDocument] snapshots for [docId].
  /// Returns how many were removed.
  Future<int> prune(String docId) async {
    final stored = await _entriesFor(docId);
    if (stored.length <= maxPerDocument) return 0;
    final excess = stored.take(stored.length - maxPerDocument);
    var removed = 0;
    for (final entry in excess) {
      try {
        await fs.delete(entry.path);
        removed++;
        // A snapshot that will not delete is disk clutter, not a failure
        // of the operation that asked for the prune.
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
    }
    return removed;
  }
}
