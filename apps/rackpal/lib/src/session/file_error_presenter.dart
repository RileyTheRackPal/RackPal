// Every expected storage failure, turned into a sentence the user can act
// on. THE EXHAUSTIVE SWITCH IS THE MECHANISM: `SaveError` and `OpenError`
// are sealed, so adding a variant without copy for it is a COMPILE ERROR
// here rather than a shrug at runtime. That is the whole reason those
// hierarchies are sealed at all.
//
// PURE. No I/O, no BuildContext, no Flutter beyond the value objects it
// builds — so all ten of §9's named failure conditions are unit-tested by
// asserting on strings, with no widget tree and no disk.
//
// ==================================================================
// THE PATH IS IN THE MESSAGE. THE PATH IS NOT IN THE LOG.
// ==================================================================
// §12.4 forbids logging file paths, client names and site addresses;
// `logStorageEvent` enforces that by type. This file does the opposite on
// purpose: a dialog that says "could not save to \\NAS\jobs\Smith" is the
// sentence that tells the user which of their three shares is down, and
// it is displayed on their own screen rather than written to a file that
// travels. Two surfaces, two rules.
//
// ==================================================================
// WHAT IS DELIBERATELY ABSENT FROM THE BUTTON SETS
// ==================================================================
//  * `OpenNewerSchema` has NO "open anyway". The refusal exists because
//    opening would silently discard data this build cannot model, so an
//    escape hatch would convert a refusal into a corruption.
//  * `SaveReadOnlyTarget` has NO "make it writable and retry". Clearing
//    the read-only attribute on a file somebody marked protected is not
//    ours to do.
//  * A failed save NEVER offers "close anyway". Losing the document
//    because the drive was unplugged is the single worst thing this layer
//    could do.
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The stable ids [FileErrorView] actions carry. Strings rather than an
/// enum because `FileErrorAction` lives in `rackpal_ui`, which must not
/// know what a save is; these constants keep the two ends spelled the
/// same in exactly one place.
abstract final class FileErrorActionId {
  static const String ok = 'ok';
  static const String cancel = 'cancel';
  static const String saveAs = 'saveAs';
  static const String retry = 'retry';
  static const String overwrite = 'overwrite';
  static const String openBackup = 'openBackup';
}

const FileErrorAction _cancel = FileErrorAction(
  id: FileErrorActionId.cancel,
  label: 'Cancel',
);
const FileErrorAction _ok = FileErrorAction(
  id: FileErrorActionId.ok,
  label: 'OK',
  isPrimary: true,
);
const FileErrorAction _saveAs = FileErrorAction(
  id: FileErrorActionId.saveAs,
  label: 'Save As…',
  isPrimary: true,
);
const FileErrorAction _retry = FileErrorAction(
  id: FileErrorActionId.retry,
  label: 'Try again',
);
const FileErrorAction _openBackup = FileErrorAction(
  id: FileErrorActionId.openBackup,
  label: 'Open the backup',
  isPrimary: true,
);

/// The reassurance line on every failed save. It answers the question the
/// user actually has, which no errno ever does.
const String _stillOpen = 'Your changes are safe and still open.';

String _name(String path, p.Context context) =>
    path.isEmpty ? 'the file' : context.basename(path);

String _megabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 10) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}

/// `14:07 today` / `14:07 on 2026-07-24` — enough to tell the user
/// whether the backup is worth opening, and no more.
String describeBackupTime(DateTime modified, {required DateTime now}) {
  final local = modified.toLocal();
  final today = now.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  if (sameDay) return '$hh:$mm today';
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$hh:$mm on ${local.year}-$mo-$d';
}

/// Copy for a save that did not happen.
///
/// [documentBytes] is how big the pending write is, used only by the
/// disk-full case so the message can say how much space is needed rather
/// than "not enough space" with no number.
FileErrorView describeSaveError(
  SaveError error, {
  required p.Context context,
  int? documentBytes,
}) {
  return switch (error) {
    SaveDirectoryMissing(:final paths) => FileErrorView(
      title: 'Could not save ${_name(paths.target, context)}',
      detail:
          'The folder ${paths.directory} is not there any more. It may be '
          'on a drive that has been disconnected, or it may have been '
          'moved or renamed.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _retry, _cancel],
    ),

    // Caught in the pre-flight, before a single byte moved.
    SaveReadOnlyTarget(:final paths) => FileErrorView(
      title:
          '${_name(paths.target, context)} is read-only, so RackPal '
          'cannot save over it.',
      detail:
          'The file is marked read-only on disk. RackPal will not clear '
          'that attribute for you — somebody set it deliberately. Save a '
          'copy under a different name, or clear the read-only flag in '
          'Windows and try again.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _cancel],
    ),

    // Two instances of the app, or a cloud client syncing underneath us.
    // Nothing else in this design stands between that and silently
    // destroying somebody's work.
    SaveChangedOnDisk(:final paths, :final found) => FileErrorView(
      title:
          '${_name(paths.target, context)} has changed on disk since you '
          'opened it.',
      detail: found == null
          ? 'The file is no longer there. Another program may have moved '
                'or deleted it. Saving will write a new file at '
                '${paths.target}.'
          : 'Another program — a second copy of RackPal, or a sync '
                'client such as OneDrive or Dropbox — has written to '
                '${paths.target}. Overwriting replaces whatever is there '
                'now with what is on your screen.',
      reassurance: _stillOpen,
      actions: const [
        FileErrorAction(
          id: FileErrorActionId.overwrite,
          label: 'Overwrite',
        ),
        _saveAs,
        _cancel,
      ],
    ),

    SavePathTooLong(:final length) => FileErrorView(
      title: 'That folder path is too long for Windows.',
      detail:
          'The file and its temporary sibling would be $length characters '
          'and the limit is $kWindowsMaxPath. Choose a shorter folder or a '
          'shorter file name.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _cancel],
    ),

    // Reached at step 3, before anything in the user's folder changed.
    SaveDiskFull(:final paths) => FileErrorView(
      title:
          'There is not enough space to save '
          '${_name(paths.target, context)}.',
      detail: documentBytes == null
          ? 'The volume holding ${paths.directory} is full.'
          : 'The volume holding ${paths.directory} is full. About '
                '${_megabytes(documentBytes)} is needed.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _retry, _cancel],
    ),

    SaveUnreachable(:final paths) => FileErrorView(
      title:
          'Could not save to ${paths.target} — that location is not '
          'available right now.',
      detail:
          'The drive or network share is not answering. RackPal has not '
          'changed anything there, and it has NOT removed the file from '
          'your recent list: a share that is asleep is not a share that '
          'is gone.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _retry, _cancel],
    ),

    SaveLocked(:final paths) => FileErrorView(
      title: '${_name(paths.target, context)} is in use by another program.',
      detail:
          'Antivirus, a backup agent or a second copy of RackPal is '
          'holding the file open. RackPal already retried three times. '
          'The file on disk is untouched and is still your last good '
          'version.',
      reassurance: _stillOpen,
      actions: const [_retry, _saveAs, _cancel],
    ),

    SavePermissionDenied(:final paths) => FileErrorView(
      title: 'Windows refused to write ${_name(paths.target, context)}.',
      detail:
          'You do not have permission to write to ${paths.directory}. '
          'Save somewhere you own, or ask whoever administers this '
          'machine for write access to that folder.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _cancel],
    ),

    // The residual branch. NOT a shrug: it carries the original error and
    // stack for the §12.1 programmer-error channel, and it still tells
    // the user the two things they need — nothing was destroyed, and here
    // is another way out.
    SaveUnexpected(:final paths, :final step) => FileErrorView(
      title: 'Could not save ${_name(paths.target, context)}.',
      detail:
          'Something went wrong at step $step of the save that RackPal '
          'does not have a specific explanation for. The file on disk is '
          'unchanged.',
      reassurance: _stillOpen,
      actions: const [_saveAs, _retry, _cancel],
    ),
  };
}

/// Copy for a document that did not open.
///
/// [now] is injected so "14:07 today" is deterministic in tests rather
/// than depending on when the suite runs.
/// [recentEntryRemoved] is whether the caller CONFIRMED an entry left the
/// recent list. It is not "whether eviction was attempted": in a degraded
/// session there is no list, a path from File ▸ Open was never in one, and
/// `RecentsStore.save` can fail without telling anyone. The sentence about
/// the recent list appears only when the removal was checked and happened.
FileErrorView describeOpenError(
  OpenError error, {
  required p.Context context,
  required DateTime now,
  bool recentEntryRemoved = false,
}) {
  return switch (error) {
    // Case 9 of the error surface: the residual hard-kill window, and the
    // user who deleted the wrong file. WITHOUT THIS BRANCH THE `.bak` IS
    // DECORATION — it exists and nothing ever offers it.
    OpenNotFound(:final path, :final backup) =>
      backup == null
          ? FileErrorView(
              title: '${_name(path, context)} is not there any more.',
              detail:
                  'Nothing is at $path. It may have been moved, renamed or '
                  'deleted.'
                  '${recentEntryRemoved ? ' RackPal has removed it from the '
                            'recent list, because the folder it was in answered '
                            'and the file is genuinely gone.' : ''}',
              actions: const [_ok],
            )
          : FileErrorView(
              title:
                  '${_name(path, context)} is not there any more, but a '
                  'backup is.',
              detail:
                  'RackPal keeps one backup beside every saved file. The '
                  'one for this project was saved at '
                  '${describeBackupTime(backup.modified, now: now)}. '
                  'Opening it loads that version; it is not written back '
                  'until you save.',
              actions: const [_openBackup, _cancel],
            ),

    OpenUnreachable(:final path) => FileErrorView(
      title: 'That location is not available right now.',
      detail:
          'RackPal could not reach $path. The file may be on a drive or '
          'network share that is disconnected. It has been LEFT in your '
          'recent list, so it will be there when the share comes back.',
      actions: const [_ok],
    ),

    OpenPermissionDenied(:final path) => FileErrorView(
      title: 'Windows refused to read ${_name(path, context)}.',
      detail:
          'You do not have permission to read $path. Ask whoever '
          'administers this machine, or copy the file somewhere you own.',
      actions: const [_ok],
    ),

    // Import hardening. Refused BEFORE the JSON is parsed.
    OpenTooLarge(:final path, :final bytes, :final limit) => FileErrorView(
      title: '${_name(path, context)} is too large to open.',
      detail:
          'That file is ${_megabytes(bytes)}. RackPal opens projects up '
          'to ${_megabytes(limit)}. A rack project is normally well under '
          'a megabyte, so a file this size is very unlikely to be one.',
      actions: const [_ok],
    ),

    OpenTooDeeplyNested(:final path, :final limit) => FileErrorView(
      title: '${_name(path, context)} is nested too deeply.',
      detail:
          'The JSON in that file nests more than $limit levels deep. A '
          'RackPal project nests about eight, so this is not one — and '
          'parsing it would put the app at risk rather than open '
          'anything.',
      actions: const [_ok],
    ),

    // Its own case with its own copy, because "that is a zip archive" is
    // a far more useful sentence than "that is not a RackPal file".
    OpenZipContainer(:final path) => FileErrorView(
      title:
          '${_name(path, context)} is a zip archive, not a RackPal '
          'project.',
      detail:
          'The file begins with the ZIP signature. RackPal projects are '
          'plain JSON. If the project is inside the archive, extract it '
          'first and open the `.rmpj` file.',
      actions: const [_ok],
    ),

    OpenNotARackPalFile(:final path, :final generator) => FileErrorView(
      title: 'That is not a RackPal file.',
      detail: generator == null
          ? '${_name(path, context)} is valid JSON but does not contain a '
                'RackPal project.'
          : '${_name(path, context)} says it was written by "$generator", '
                'not by RackPal.',
      actions: const [_ok],
    ),

    // NO "open anyway". See the file header.
    OpenNewerSchema(
      :final path,
      :final minReaderVersion,
      :final supportedSchemaVersion,
    ) =>
      FileErrorView(
        title:
            '${_name(path, context)} was saved by a newer version of '
            'RackPal.',
        detail:
            'It needs reader version $minReaderVersion and this build is '
            'version $supportedSchemaVersion. Update RackPal to open '
            'this file. RackPal will not open it partially: everything '
            'this build could not understand would be silently dropped '
            'the first time you saved.',
        actions: const [_ok],
      ),

    // Case 8. THIS is where the `.bak` earns its existence.
    OpenCorrupt(:final path, :final backup) =>
      backup == null
          ? FileErrorView(
              title:
                  '${_name(path, context)} could not be read — the file '
                  'appears to be damaged.',
              detail:
                  'The file is there and RackPal could read its bytes, but '
                  'they are not a complete RackPal project. There is no '
                  'backup beside it to fall back on.',
              actions: const [_ok],
            )
          : FileErrorView(
              title:
                  '${_name(path, context)} could not be read — the file '
                  'appears to be damaged.',
              detail:
                  'A backup saved at '
                  '${describeBackupTime(backup.modified, now: now)} is '
                  'available. Opening it loads that version as this '
                  'project, marked unsaved — your next Save writes it back '
                  'over the damaged file, so nothing is replaced until you '
                  'say so.',
              actions: const [_openBackup, _cancel],
            ),

    OpenUnexpected(:final path) => FileErrorView(
      title: 'Could not open ${_name(path, context)}.',
      detail:
          'Something went wrong that RackPal does not have a specific '
          'explanation for. Nothing was changed on disk.',
      actions: const [_ok],
    ),
  };
}

/// What became of §9.3's pre-update snapshot on a save.
///
/// THREE STATES AND NOT A BOOL, because "there was nothing to preserve"
/// and "there was something to preserve and we failed" must not produce
/// the same status line. The first is every save of every ordinary
/// document; the second is a save that has just performed an irreversible
/// rewrite with no insurance behind it.
enum PreUpdateSnapshotState {
  /// The document was not migrated on open. Nothing to insure.
  notNeeded,

  /// The file as it was before this build rewrote it is on disk.
  kept,

  /// The copy could not be written — the data root is unusable, full, or
  /// permission-denied. The save still happened; the user is told.
  failed,
}

/// The status line for a save that SUCCEEDED.
///
/// A save that worked must never raise a dialog, and a save whose backup
/// could not be refreshed must never be silent. That is the entire job of
/// this function, and it is why `WriteReceipt` carries the two backup
/// flags at all.
///
/// [backupAttempted] IS WHY THERE ARE TWO FLAGS AND NOT ONE. A FIRST save
/// produces no `.bak` because there was nothing to copy, and reporting
/// that as "the backup copy could not be updated" would cry wolf on every
/// new document — which is precisely how a status line stops being read
/// by the time it carries something real.
///
/// [preUpdateSnapshot] REPORTS THE LOUDER OF THE TWO when both went
/// wrong. A missing `.bak` is one lost copy of a file that is still
/// perfectly readable; a missing pre-update snapshot means the only
/// version of the document that an older RackPal could still open has
/// just been overwritten and not kept anywhere.
String describeSaveSuccess({
  required bool backupUpdated,
  bool backupAttempted = true,
  PreUpdateSnapshotState preUpdateSnapshot = PreUpdateSnapshotState.notNeeded,
}) {
  if (preUpdateSnapshot == PreUpdateSnapshotState.failed) {
    return 'Saved — but RackPal could not keep a copy of this file as it '
        'was before this version updated it. Older versions of RackPal '
        'can no longer open it.';
  }
  return !backupAttempted || backupUpdated
      ? 'Saved.'
      : 'Saved. The backup copy could not be updated.';
}

/// The persistent warning for a session whose data root is unusable.
///
/// The SAME sentence for a locked-down corporate profile and for a
/// read-only USB stick in portable mode, because it is the same degraded
/// mode and there is one code path for both.
String describeDegradedPersistence({required bool portable}) => portable
    ? 'Portable mode: RackPal cannot write to its data folder. Autosave, '
          'recent files, window position and the copy kept before a file '
          'is updated to a newer format are off for this session. Your '
          'projects still open and save normally.'
    : 'Autosave is off — RackPal cannot write to its data folder. Recent '
          'files, window position and the copy kept before a file is '
          'updated to a newer format are off too. Your projects still open '
          'and save normally.';

/// The warning shown when autosave STOPS WORKING mid-session.
///
/// Distinct from [describeDegradedPersistence], which describes a session
/// that never had persistence: this one describes one that HAD it and lost
/// it, which is the case the user is least likely to suspect. It happens
/// for real — the volume fills, the portable stick's write-protect switch
/// is flipped, an admin policy revokes write access, the folder is
/// deleted — and until this existed it was completely silent, because
/// `AutosaveOutcome.failed` had no consumer anywhere in `lib/`.
const String kAutosaveStoppedWarning =
    'Autosave has stopped working — RackPal can no longer write to its '
    'data folder, so unsaved work is no longer being protected. Save your '
    'project somewhere you can write to.';

/// Whether an open failure is one the app should describe by opening a
/// sibling backup rather than by stopping.
bool offersBackup(OpenError error) => switch (error) {
  OpenNotFound(:final backup) => backup != null,
  OpenCorrupt(:final backup) => backup != null,
  _ => false,
};

/// The `.bak` an [OpenError] pointed at, or null.
BackupFacts? backupOf(OpenError error) => switch (error) {
  OpenNotFound(:final backup) => backup,
  OpenCorrupt(:final backup) => backup,
  _ => null,
};
