// The recent-files list (docs/03-architecture.md §9.5): a JSON list in the
// data root, NOT shared_preferences — structured metadata is the wrong
// shape for prefs.
//
// ==================================================================
// THE STARTUP RULE, AND THE MEASUREMENT BEHIND IT
// ==================================================================
// `existsSync` on an unreachable UNC path took 1261 ms on this machine
// and returned false WITHOUT throwing. Ten dead entries would be 12.6
// seconds of frozen startup against a 1.2 s cold-start budget. So:
//
//   1. The menu renders IMMEDIATELY from recents.json. NOTHING on the
//      startup path stats a recent file. Ever.
//   2. When the menu is OPENED, a bounded background probe runs — all
//      entries concurrently, each with a 500 ms timeout. An entry that
//      has not answered renders as `checking` (dimmed, still clickable);
//      one that answered "missing" renders as `unreachable`. NOTHING is
//      removed by the probe.
//   3. An entry is REMOVED only when the user clicks it and the open
//      fails with a DEFINITIVE not-found after the directory itself was
//      confirmed reachable.
//
// §9.5's "prune missing files lazily — a temporarily unmounted network
// drive must not evict the entry" is thereby a rule about errno rather
// than a hope: errno 53/64/1231 and any timeout mean "temporarily
// unavailable" and the entry STAYS.
//
// ==================================================================
// THE PORTABLE CASE, AND THE HALF OF IT ABSOLUTE PATHS CANNOT COVER
// ==================================================================
// A stick moved between machines has entries pointing at
// C:\Users\alice\..., which are simply unreachable — they degrade to a
// dimmed row and never crash or block. That is the right answer for a
// project that lives on the HOST.
//
// It is the wrong answer for the flagship portable workflow, where the
// projects live on the STICK: E:\Jobs\Smith.rackmate. Plug that stick
// into a machine where it mounts as F: and every absolute entry probes
// as unreachable and renders dimmed FOREVER, with no route back. The
// recents feature is then 100% dead in exactly the deliverable portable
// mode exists for — and it degrades quietly, so nobody files it.
//
// So an entry whose path is on THE SAME VOLUME AS THE DATA ROOT is
// persisted twice: the absolute path, and a path relative to the data
// root together with the volume that root was on at the time. On load,
// the absolute path is used UNLESS the data root's volume has changed
// since — which happens only when the whole installation moved, and is
// exactly when re-anchoring is right. In an installed build the data
// root's volume never changes, so this is inert.
//
// Both keys are OPTIONAL and additive: an older build reads the file and
// sees the absolute paths it already understood.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/errors.dart';
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate/src/storage/save_paths.dart';
import 'package:rackmate/src/storage/storage_log.dart';

/// The file name inside the data root.
const String kRecentsFileName = 'recents.json';

/// §9.5 does not give a number; ten is the desktop convention and is what
/// fits a menu without a scrollbar.
const int kMaxRecentEntries = 10;

/// The on-disk schema version for recents.json, independent of the
/// document schema — this file has its own life cycle.
///
/// STILL 1 after the re-anchoring keys were added, deliberately: they are
/// two OPTIONAL keys on an entry, the loader has always skipped keys it
/// does not know, and nothing anywhere gates on this number. Bumping it
/// would be a version change that no reader could act on, which is worse
/// than not bumping it.
const int kRecentsFormatVersion = 1;

/// The entry key holding the path relative to the data root. Written only
/// when the entry is on the same volume as the data root.
const String kRecentsRelativeKey = 'relativeToDataRoot';

/// The entry key holding the data root's volume at the time the entry was
/// written (`E:\`, or `\\server\share\`). Comparing it against the
/// CURRENT data root's volume is what tells "the stick was remounted
/// under a different letter" from "nothing moved".
const String kRecentsAnchorVolumeKey = 'anchorVolume';

/// How long a single reachability probe is given before the entry is
/// rendered as `checking`. Bounded because the alternative is measured at
/// 1261 ms per dead entry.
const Duration kRecentsProbeTimeout = Duration(milliseconds: 500);

/// One remembered file.
final class RecentEntry {
  const RecentEntry({
    required this.path,
    required this.displayName,
    required this.lastOpened,
  });

  /// ABSOLUTE, always. A relative entry would resolve against whatever
  /// the working directory happened to be.
  final String path;

  /// What the menu shows — `ProjectInfo.projectName` when the document
  /// has one, else the file stem. Stored rather than derived so the menu
  /// needs no disk access to render.
  final String displayName;

  /// UTC.
  final DateTime lastOpened;

  Map<String, Object?> toJson() => <String, Object?>{
    'displayName': displayName,
    'lastOpened': lastOpened.toUtc().toIso8601String(),
    'path': path,
  };

  static RecentEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final displayName = raw['displayName'];
    final lastOpened = raw['lastOpened'];
    if (path is! String || path.isEmpty) return null;
    if (displayName is! String) return null;
    if (lastOpened is! String) return null;
    final parsed = DateTime.tryParse(lastOpened);
    if (parsed == null) return null;
    return RecentEntry(
      path: path,
      displayName: displayName,
      lastOpened: parsed.toUtc(),
    );
  }

  @override
  String toString() => 'RecentEntry($displayName)';
}

/// What a bounded probe learned about one entry.
enum RecentEntryState {
  /// The file answered and is there.
  ok,

  /// The probe has not answered yet (or timed out). Dimmed, STILL
  /// CLICKABLE — a slow network share is not a broken entry.
  checking,

  /// The probe answered and the file is not there.
  unreachable,
}

/// Reads and writes `recents.json`.
///
/// Every write goes through [AtomicWriter] with `keepBackup: false`, so a
/// crash mid-write leaves the previous good copy and the crash-safety
/// tests cover this file for free rather than it reinventing tmp+rename.
final class RecentsStore {
  RecentsStore({
    required this.fs,
    required this.writer,
    required String dataRoot,
    p.Context? context,
    this.maxEntries = kMaxRecentEntries,
    this.probeTimeout = kRecentsProbeTimeout,
  }) : context = context ?? p.context,
       dataRoot = dataRoot,
       path = (context ?? p.context).join(dataRoot, kRecentsFileName);

  final FileStore fs;
  final AtomicWriter writer;
  final p.Context context;
  final int maxEntries;
  final Duration probeTimeout;

  /// The directory `recents.json` lives in — and the anchor a portable
  /// entry is stored relative to. See the file header.
  final String dataRoot;

  /// The full path of `recents.json`.
  final String path;

  /// Loads the list.
  ///
  /// AN UNPARSEABLE OR MISSING FILE IS A WARNING, NOT AN ERROR: the app
  /// starts with empty recents and logs it. Refusing to start because a
  /// convenience list is corrupt would be absurd.
  ///
  /// Does NOT stat any entry. See the file header.
  Future<List<RecentEntry>> load() async {
    try {
      if (!await fs.exists(path)) return const [];
      final raw = jsonDecode(utf8.decode(await fs.readBytes(path)));
      if (raw is! Map) {
        logStorageEvent('recents_malformed', {'reason': 0});
        return const [];
      }
      final entries = raw['entries'];
      if (entries is! List) {
        logStorageEvent('recents_malformed', {'reason': 1});
        return const [];
      }
      final parsed = <RecentEntry>[];
      for (final e in entries) {
        final entry = _decodeEntry(e);
        // A single malformed row is skipped, not fatal. One bad entry
        // must not cost the user the other nine.
        if (entry != null) parsed.add(entry);
      }
      return parsed.take(maxEntries).toList();
      // Anything at all here means "no usable recents", which is a
      // perfectly good answer for a convenience list.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('recents_unreadable');
      return const [];
    }
  }

  /// Records [entry] at the top, deduplicated, capped, and persisted.
  ///
  /// Dedup is by [canonicalKey], so `C:\Jobs\Smith.rackmate` and
  /// `c:\jobs\..\jobs\smith.RACKMATE` are one entry on Windows.
  Future<List<RecentEntry>> push(RecentEntry entry) async {
    final current = await load();
    final key = canonicalKey(entry.path);
    final next = <RecentEntry>[
      entry,
      ...current.where((e) => canonicalKey(e.path) != key),
    ].take(maxEntries).toList();
    await save(next);
    return next;
  }

  /// Removes the entry for [entryPath], if present.
  ///
  /// CALLED ONLY FROM THE ONE PLACE §9.5's lazy-pruning rule permits: the
  /// user clicked the entry, the open failed, and [shouldEvictOnOpenFailure]
  /// agreed the failure was definitive.
  Future<List<RecentEntry>> remove(String entryPath) async {
    final key = canonicalKey(entryPath);
    final next = (await load())
        .where((e) => canonicalKey(e.path) != key)
        .toList();
    await save(next);
    return next;
  }

  /// Overwrites the file with [entries].
  Future<void> save(List<RecentEntry> entries) async {
    final json = const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'entries': [for (final e in entries.take(maxEntries)) _encodeEntry(e)],
      'version': kRecentsFormatVersion,
    });
    await writer.write(
      paths: SavePaths.forExactTarget(path, context: context),
      bytes: Uint8List.fromList(utf8.encode(json)),
      keepBackup: false,
    );
  }

  /// The absolute form, plus the re-anchoring pair when the entry shares
  /// the data root's volume. See the file header.
  Map<String, Object?> _encodeEntry(RecentEntry entry) {
    final json = entry.toJson();
    final relative = _relativeToDataRoot(entry.path);
    if (relative != null) {
      json[kRecentsRelativeKey] = relative;
      json[kRecentsAnchorVolumeKey] = context.rootPrefix(dataRoot);
    }
    return json;
  }

  /// The stored entry, RE-ANCHORED when — and only when — the data root's
  /// volume has changed since it was written.
  ///
  /// The absolute path wins in every other case, including when there is
  /// no relative form at all. That is what keeps an installed build's
  /// behaviour bit-for-bit unchanged: its data root never moves volume,
  /// so this branch is never taken.
  RecentEntry? _decodeEntry(Object? raw) {
    final entry = RecentEntry.fromJson(raw);
    if (entry == null || raw is! Map) return entry;

    final relative = raw[kRecentsRelativeKey];
    final anchorVolume = raw[kRecentsAnchorVolumeKey];
    if (relative is! String || anchorVolume is! String) return entry;

    final currentVolume = context.rootPrefix(dataRoot);
    if (_sameVolume(anchorVolume, currentVolume)) return entry;

    logStorageEvent('recents_reanchored');
    return RecentEntry(
      path: context.normalize(context.join(dataRoot, relative)),
      displayName: entry.displayName,
      lastOpened: entry.lastOpened,
    );
  }

  /// [entryPath] expressed relative to [dataRoot], or null when the two
  /// are not on the same volume.
  ///
  /// A cross-volume "relative" path would be `..\..\..` nonsense that
  /// re-anchors onto the wrong drive, so the volume check is not an
  /// optimisation — it is the correctness condition.
  String? _relativeToDataRoot(String entryPath) {
    if (!context.isAbsolute(entryPath) || !context.isAbsolute(dataRoot)) {
      return null;
    }
    if (!_sameVolume(
      context.rootPrefix(entryPath),
      context.rootPrefix(dataRoot),
    )) {
      return null;
    }
    return context.relative(entryPath, from: dataRoot);
  }

  /// Volume comparison, case-insensitive on Windows for the same reason
  /// [canonicalKey] is: `E:\` and `e:\` are one drive there.
  bool _sameVolume(String a, String b) => context.style == p.Style.windows
      ? a.toLowerCase() == b.toLowerCase()
      : a == b;

  /// The comparison key for deduplication.
  ///
  /// Case-INSENSITIVE on Windows, because `C:\Jobs` and `c:\jobs` are the
  /// same directory there and showing both would be a bug the user cannot
  /// explain. Case-sensitive elsewhere, because on Linux they are genuinely
  /// two files.
  String canonicalKey(String raw) {
    final normalized = context.normalize(raw);
    return context.style == p.Style.windows
        ? normalized.toLowerCase()
        : normalized;
  }

  /// Probes every entry for reachability, bounded.
  ///
  /// RUN ON MENU OPEN, NEVER AT STARTUP. Each probe gets [probeTimeout];
  /// one that has not answered is reported as [RecentEntryState.checking],
  /// which renders dimmed but still clickable. Nothing is removed here —
  /// this function has no side effects on the stored list at all, which is
  /// the structural half of "a temporarily unmounted network drive must
  /// not evict the entry".
  Future<Map<String, RecentEntryState>> probe(
    List<RecentEntry> entries,
  ) async {
    final results = <String, RecentEntryState>{};
    await Future.wait([
      for (final entry in entries)
        _probeOne(entry).then((state) => results[entry.path] = state),
    ]);
    return results;
  }

  Future<RecentEntryState> _probeOne(RecentEntry entry) async {
    try {
      final exists = await fs
          .exists(entry.path)
          .timeout(probeTimeout, onTimeout: () => throw TimeoutException(''));
      return exists ? RecentEntryState.ok : RecentEntryState.unreachable;
      // A probe that threw or timed out tells us nothing definitive, and
      // "nothing definitive" must render as `checking` rather than as a
      // verdict (G4).
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return RecentEntryState.checking;
    }
  }
}

/// Whether an open failure is DEFINITIVE enough to evict the recents
/// entry.
///
/// PURE, so the rule is unit-tested exhaustively rather than inferred
/// from behaviour. Only a genuinely-missing file whose DIRECTORY was
/// reachable earns eviction. Every network error, every permission error
/// and every timeout means "temporarily unavailable" and the entry stays
/// — that is §9.5's unmounted-drive requirement, stated as a rule about
/// error categories rather than as an intention.
bool shouldEvictOnOpenFailure(OpenError error) => switch (error) {
  // The directory was reachable and the file genuinely is not there.
  // `OpenNotFound` is only ever constructed after that confirmation.
  OpenNotFound() => true,
  OpenUnreachable() => false,
  OpenPermissionDenied() => false,
  // The file is right there and opened. It is a bad file, not a missing
  // one, and forgetting it would take away the user's only route back to
  // it (including the "open the backup" path).
  OpenCorrupt() => false,
  OpenTooLarge() => false,
  OpenTooDeeplyNested() => false,
  OpenNotARackMateFile() => false,
  OpenZipContainer() => false,
  OpenNewerSchema() => false,
  OpenUnexpected() => false,
};
