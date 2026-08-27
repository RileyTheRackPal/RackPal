// PURE path derivation — the four names an atomic save touches, derived
// once from the one path the user chose. No I/O whatsoever, so this is
// unit-tested with Windows-shaped paths on a Linux CI runner by injecting
// a `p.Context(style: p.Style.windows)`.
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/file_store.dart';

/// The project extension, including the dot, lower-case (DR-015).
const String kDocumentExtension = '.rmpj';

/// What this app wrote before DR-015.
///
/// ═══════════════════════════════════════════════════════════════════
/// STILL OPENED, AND STILL SAVED IN PLACE
/// ═══════════════════════════════════════════════════════════════════
/// The bytes did not change — DR-015 renamed the extension and nothing
/// else — so a `.rackpal` written by any earlier build is a valid
/// project and refusing it would be a data-loss event dressed as tidiness,
/// which is the reasoning AC-042 already applied to `contentHash`.
///
/// It is listed in [kDocumentExtensions] rather than special-cased, which
/// is what makes **Save keep the name it opened**: a team that is mid-job
/// on `Smith.rackpal` presses `Ctrl+S` and gets `Smith.rackpal`, not
/// `Smith.rackpal.rmpj`. Only Save As and a never-saved document reach
/// for [kDocumentExtension]. Nothing renames a file the user did not ask
/// to rename.
const String kLegacyDocumentExtension = '.rackpal';

/// Every extension a project may already carry, **the one to append
/// first**.
///
/// [SavePaths.forTarget] appends `.first` when the chosen path ends in
/// none of these, and leaves the path alone when it ends in any of them.
const List<String> kDocumentExtensions = <String>[
  kDocumentExtension,
  kLegacyDocumentExtension,
];

/// The extension an exported PDF gets, including the dot, lower-case.
const String kPdfExtension = '.pdf';

/// Appended to the target to name the in-progress write.
const String kTempSuffix = '.tmp';

/// Appended to the target to name the one backup sibling (CR-098: ONE
/// `.bak`, and no `.history/` folder — the user's folder gains nothing
/// but the file they asked for and one backup).
const String kBackupSuffix = '.bak';

/// Windows' classic `MAX_PATH`, less the terminating NUL. Paths at or
/// below this always work; above it depends on the machine's
/// `LongPathsEnabled` policy AND on the executable manifest declaring
/// `longPathAware`, so it is treated as advisory: the pre-flight warns,
/// and the runtime error path handles the failure anyway.
const int kWindowsMaxPath = 259;

/// The four paths one atomic save touches, and nothing else. Constructed
/// through [SavePaths.forTarget] so the extension normalisation and the
/// suffix spelling happen in exactly one place.
final class SavePaths {
  const SavePaths({
    required this.target,
    required this.temp,
    required this.backup,
    required this.backupTemp,
    required this.directory,
  });

  /// Derives every path from [chosen], the path the OS save dialog
  /// returned.
  ///
  /// FORCES THE EXTENSION. The Windows save dialog hands back `Smith`
  /// when the user types `Smith`, and a project saved as an extensionless
  /// file will not reopen by double-click and will not be found by the
  /// open dialog's filter. Appending is done rather than replacing, so a
  /// deliberate `Smith.v2` becomes `Smith.v2.rmpj` and nothing the user
  /// typed is thrown away.
  ///
  /// [extensions] EXISTS SO THE PDF EXPORT SHARES THIS NORMALISATION
  /// rather than growing its own. The rule — "append unless one is already
  /// there, compared case-insensitively" — is the same rule for a `.pdf`
  /// as for a project, and it is exactly the kind of thing that drifts
  /// once there are two copies of it.
  ///
  /// A LIST RATHER THAN ONE STRING, and the difference is DR-015's whole
  /// back-compat story. `.first` is what gets appended; **every** entry
  /// counts as already-correct. So `Smith.rackpal` passes through
  /// untouched and `Ctrl+S` saves it where it lives, while a new document
  /// gets `.rmpj`. The PDF path passes a single-entry list and is
  /// therefore unaffected by the project's legacy spelling — which it
  /// would not be if this took one extension plus a shared "also accept"
  /// set.
  factory SavePaths.forTarget(
    String chosen, {
    p.Context? context,
    List<String> extensions = kDocumentExtensions,
  }) {
    final ctx = context ?? p.context;
    final has = ctx.extension(chosen).toLowerCase();
    final target = extensions.contains(has)
        ? chosen
        : '$chosen${extensions.first}';
    return SavePaths(
      target: target,
      // SAME DIRECTORY, always. Same directory means same volume, and
      // same volume is the entire reason the promote step is atomic. A
      // temp file in %TEMP% would make step 5 a cross-volume copy with no
      // atomicity at all.
      temp: '$target$kTempSuffix',
      backup: '$target$kBackupSuffix',
      backupTemp: '$target$kBackupSuffix$kTempSuffix',
      directory: ctx.dirname(target),
    );
  }

  /// Derives the sibling paths for [target] WITHOUT touching its
  /// extension — for the app's own files (`recents.json`, `prefs.json`,
  /// a recovery snapshot), whose names are ours and already exact.
  ///
  /// They get the same tmp+rename machinery for a real reason: a torn
  /// `prefs.json` would lose the user's window layout, and reusing the
  /// engine means the crash-safety tests cover these three writers for
  /// free instead of each one reinventing atomicity slightly differently.
  factory SavePaths.forExactTarget(String target, {p.Context? context}) {
    final ctx = context ?? p.context;
    return SavePaths(
      target: target,
      temp: '$target$kTempSuffix',
      backup: '$target$kBackupSuffix',
      backupTemp: '$target$kBackupSuffix$kTempSuffix',
      directory: ctx.dirname(target),
    );
  }

  /// `<dir>/<stem>.rmpj` — the file the user knows about.
  final String target;

  /// `<target>.tmp` — where the new bytes land before they are promoted.
  final String temp;

  /// `<target>.bak` — the one backup sibling.
  final String backup;

  /// `<target>.bak.tmp` — where the backup COPY lands before it is
  /// renamed into place. Its existence is what keeps a torn backup from
  /// ever being mistaken for a complete one.
  final String backupTemp;

  /// The containing directory.
  final String directory;

  /// All four derived names, longest first — the complete set CR-098
  /// permits in the user's folder, and what the I4 assertions enumerate.
  ///
  /// NOT what the `MAX_PATH` pre-flight measures. See [pathsWritten].
  List<String> get allPaths => [backupTemp, backup, temp, target];

  /// The paths a save with this [keepBackup] setting will ACTUALLY
  /// create, longest first.
  ///
  /// THE DISTINCTION IS NOT PEDANTRY. `RecentsStore`, `PrefsStore`,
  /// `RecoveryStore` and `SnapshotStore` all pass `keepBackup: false`, so
  /// `.bak` and `.bak.tmp` are never created for them — and `.bak.tmp` is
  /// EIGHT characters longer than the target. Measuring it anyway refuses
  /// those writes eight characters early: a portable stick unzipped into
  /// a folder that puts `…\RackPalData\recovery\<36-char-uuid>.rackpal`
  /// at 253 characters would be refused with `SavePathTooLong` even
  /// though the longest path it actually writes, the `.tmp` at 257, fits
  /// under the 259 limit. Recovery snapshots would then never write at
  /// all.
  List<String> pathsWritten({required bool keepBackup}) =>
      keepBackup ? allPaths : [temp, target];

  /// The length of the longest path a save with this [keepBackup] setting
  /// will actually create.
  int longestPathLength({required bool keepBackup}) => pathsWritten(
    keepBackup: keepBackup,
  ).map((path) => path.length).reduce((a, b) => a > b ? a : b);

  /// True when a path this save will actually create exceeds
  /// [kWindowsMaxPath].
  bool exceedsWindowsMaxPath({required bool keepBackup}) =>
      longestPathLength(keepBackup: keepBackup) > kWindowsMaxPath;

  /// The file name without its directory or extension — the default
  /// display name when a document carries no project name.
  String stemOf(p.Context context) => context.basenameWithoutExtension(target);

  @override
  String toString() => 'SavePaths($target)';
}

/// The (size, modified) pair recorded when a document was opened or last
/// saved. Compared against a fresh `stat` in the save pre-flight to catch
/// a file that changed underneath us.
///
/// WHY NOT A `.lock` SIBLING. A lock file would violate CR-098's "the
/// user's folder gains nothing but the file they asked for and one
/// backup", it would be left behind by every crash, and it would not
/// actually stop a cloud client. Two integers cost one stat and no
/// footprint.
@immutable
final class FileBaseline {
  const FileBaseline({required this.size, required this.modified});

  /// The baseline describing [facts], or [absent] when there is no file.
  ///
  /// ONLY FOR A `null` THAT REALLY MEANS "NOTHING IS THERE". A `stat`
  /// that answered `null` because it FAILED — a network share hiccup, an
  /// antivirus scanner holding the file for a moment — must use
  /// [unknown]: see that field for why [absent] is an accusation and
  /// [unknown] is not.
  factory FileBaseline.of(FileFacts? facts) => facts == null
      ? absent
      : FileBaseline(size: facts.size, modified: facts.modified);

  /// The baseline for a file that did not exist — a first save. A size of
  /// exactly -1 is the sentinel: no real file has one, so [isAbsent]
  /// needs no extra field.
  static final FileBaseline absent = FileBaseline(
    size: -1,
    modified: DateTime.utc(1970),
  );

  /// The baseline for a file that EXISTS but whose facts could not be
  /// read. [matches] is always true, so the next save skips its
  /// external-change check rather than failing it.
  ///
  /// ==================================================================
  /// WHY THIS EXISTS RATHER THAN REUSING [absent]
  /// ==================================================================
  /// [absent] is a POSITIVE CLAIM: "there was no file here". Compared
  /// against a file that IS there, it correctly reports a change. So
  /// using it for "the re-stat did not answer" turns an unanswered
  /// question into a false accusation: the very next Ctrl+S is refused
  /// with `SaveChangedOnDisk`, whose copy tells the user that "another
  /// program — a second copy of RackPal, or a sync client such as
  /// OneDrive or Dropbox — has written to" their file. Nothing wrote to
  /// it. Doing that repeatedly trains the user to click straight through
  /// the one prompt that will one day be real, which is the same failure
  /// the whole-millisecond comparison below exists to avoid.
  ///
  /// The honest answer to "did this file change?" when the facts are
  /// unreadable is "I cannot tell", and the conservative action for "I
  /// cannot tell" is to proceed — the check is a courtesy that catches a
  /// second writer, not a lock.
  static final FileBaseline unknown = FileBaseline(
    size: -2,
    modified: DateTime.utc(1970),
  );

  final int size;
  final DateTime modified;

  /// True when this baseline stands for "there was no file".
  bool get isAbsent => size == -1;

  /// True when this baseline stands for "the file's facts are unreadable".
  bool get isUnknown => size == -2;

  /// Whether [facts] still matches this baseline.
  ///
  /// Compared at WHOLE-MILLISECOND resolution: filesystems and the Dart
  /// `FileStat` bridge do not agree on sub-millisecond precision, and a
  /// spurious "changed on disk" prompt on every save would train the user
  /// to click straight through the one that matters.
  bool matches(FileFacts? facts) {
    // "I cannot tell" is not "it changed". See [unknown].
    if (isUnknown) return true;
    if (facts == null) return isAbsent;
    if (isAbsent) return false;
    return facts.size == size &&
        facts.modified.millisecondsSinceEpoch ==
            modified.millisecondsSinceEpoch;
  }

  @override
  bool operator ==(Object other) =>
      other is FileBaseline &&
      other.size == size &&
      other.modified.millisecondsSinceEpoch == modified.millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(size, modified.millisecondsSinceEpoch);

  @override
  String toString() => switch (this) {
    _ when isAbsent => 'FileBaseline.absent',
    _ when isUnknown => 'FileBaseline.unknown',
    _ => 'FileBaseline($size, $modified)',
  };
}
