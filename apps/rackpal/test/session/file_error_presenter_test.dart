// The ten named failure conditions, each with its own copy.
//
// PURE TESTS OVER PURE FUNCTIONS. No widget tree, no disk — which is the
// point of putting the presenter in its own file: the copy for "the drive
// is unplugged mid-save" is otherwise only reachable by unplugging a
// drive mid-save.
//
// TWO PROPERTIES ARE ASSERTED OF EVERY VARIANT, not only of the
// interesting ones, because the failure this file exists to prevent is a
// variant that compiles and says nothing useful:
//   * every view has a non-empty title and detail and at least one
//     action;
//   * every FAILED SAVE carries the reassurance line, because "is my work
//     gone?" is the question the user actually has and no errno answers
//     it.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_ui/rackpal_ui.dart' show FileErrorView;

final _windows = p.Context(style: p.Style.windows);
final _paths = SavePaths.forTarget(
  r'C:\jobs\Smith.rmpj',
  context: _windows,
);
final _unc = SavePaths.forTarget(
  r'\\NAS\jobs\Smith.rmpj',
  context: _windows,
);
// LOCAL times, deliberately: `describeBackupTime` renders a wall clock,
// because the user reads a clock rather than a UTC instant. Building the
// fixtures in UTC would make this suite pass or fail depending on the CI
// runner's timezone, which is exactly the kind of test nobody trusts.
final _now = DateTime(2026, 7, 26, 16);
final _backup = BackupFacts(
  path: r'C:\jobs\Smith.rmpj.bak',
  modified: DateTime(2026, 7, 26, 14, 7),
  size: 4096,
);

FileErrorView _save(SaveError e, {int? bytes}) =>
    describeSaveError(e, context: _windows, documentBytes: bytes);

FileErrorView _open(OpenError e, {bool recentEntryRemoved = false}) =>
    describeOpenError(
      e,
      context: _windows,
      now: _now,
      recentEntryRemoved: recentEntryRemoved,
    );

List<String> _ids(FileErrorView v) => [for (final a in v.actions) a.id];

/// One instance of every `SaveError` variant. The sweep below is only
/// meaningful because this list is complete, and it stays complete
/// because `SaveError` is sealed and the presenter would not compile
/// against a variant it had no branch for.
final List<SaveError> _allSaveErrors = [
  SaveDirectoryMissing(_paths),
  SaveReadOnlyTarget(_paths),
  SaveChangedOnDisk(
    paths: _paths,
    expected: FileBaseline.absent,
    found: FileFacts(
      size: 10,
      modified: DateTime.utc(2026, 7, 26, 15),
      readOnly: false,
    ),
  ),
  SavePathTooLong(paths: _paths, length: 264),
  SaveDiskFull(paths: _paths, step: 3),
  SaveUnreachable(paths: _unc, step: 3),
  SaveLocked(paths: _paths, step: 5),
  SavePermissionDenied(paths: _paths, step: 3),
  SaveUnexpected(
    paths: _paths,
    step: 3,
    cause: 'boom',
    stackTrace: StackTrace.empty,
  ),
];

/// One instance of every `OpenError` variant.
final List<OpenError> _allOpenErrors = [
  const OpenNotFound(r'C:\jobs\Smith.rmpj'),
  OpenNotFound(r'C:\jobs\Smith.rmpj', backup: _backup),
  const OpenUnreachable(r'\\NAS\jobs\Smith.rmpj'),
  const OpenPermissionDenied(r'C:\jobs\Smith.rmpj'),
  const OpenLocked(r'C:\jobs\Smith.rmpj'),
  const OpenPathTooLong(r'C:\jobs\Smith.rmpj', length: 274),
  const OpenTooLarge(
    r'C:\jobs\huge.rmpj',
    bytes: 199229440,
    limit: 67108864,
  ),
  const OpenTooDeeplyNested(
    r'C:\jobs\deep.rmpj',
    depth: 100000,
    limit: 64,
  ),
  const OpenNotARackPalFile(
    r'C:\photos\holiday-photos.json',
    generator: 'Blender',
  ),
  const OpenZipContainer(r'C:\jobs\archive.rmpj'),
  const OpenNewerSchema(
    r'C:\jobs\Smith.rmpj',
    minReaderVersion: 3,
    supportedSchemaVersion: 2,
  ),
  const OpenCorrupt(r'C:\jobs\Smith.rmpj', detail: 'unexpected token'),
  OpenCorrupt(
    r'C:\jobs\Smith.rmpj',
    detail: 'unexpected token',
    backup: _backup,
  ),
  const OpenUnexpected(
    r'C:\jobs\Smith.rmpj',
    cause: 'boom',
    stackTrace: StackTrace.empty,
  ),
];

void main() {
  group('every variant is describable', () {
    test('no SaveError ships without copy or a way out', () {
      for (final error in _allSaveErrors) {
        final view = _save(error);
        expect(view.title, isNotEmpty, reason: '$error');
        expect(view.detail, isNotEmpty, reason: '$error');
        expect(view.actions, isNotEmpty, reason: '$error');
        // The question the user actually has.
        expect(
          view.reassurance,
          'Your changes are safe and still open.',
          reason: 'a FAILED SAVE must say the work is not gone: $error',
        );
      }
    });

    test('no OpenError ships without copy or a way out', () {
      for (final error in _allOpenErrors) {
        final view = _open(error);
        expect(view.title, isNotEmpty, reason: '$error');
        expect(view.detail, isNotEmpty, reason: '$error');
        expect(view.actions, isNotEmpty, reason: '$error');
      }
    });

    test('the dismiss action is always the least destructive one', () {
      for (final error in _allSaveErrors) {
        // "Overwrite" must never be what pressing Esc means.
        expect(
          _save(error).dismissActionId,
          isNot(FileErrorActionId.overwrite),
          reason: '$error',
        );
      }
    });
  });

  group('case 1 — a disconnected network drive', () {
    test('names the location and offers Save As / Try again / Cancel', () {
      final view = _save(SaveUnreachable(paths: _unc, step: 3));
      expect(view.title, contains(r'\\NAS\jobs\Smith.rmpj'));
      expect(view.title, contains('not available right now'));
      expect(_ids(view), [
        FileErrorActionId.saveAs,
        FileErrorActionId.retry,
        FileErrorActionId.cancel,
      ]);
    });

    test('and on OPEN it says the recents entry was kept', () {
      final view = _open(const OpenUnreachable(r'\\NAS\jobs\Smith.rmpj'));
      expect(view.detail, contains('LEFT in your recent list'));
    });
  });

  group('a file another program has locked, on open (DR-198)', () {
    test('names the lock, the usual holders and the remedy, with OK only', () {
      final view = _open(const OpenLocked(r'C:\jobs\Smith.rmpj'));
      expect(view.title, 'Smith.rmpj is in use by another program.');
      expect(view.detail, contains('OneDrive, Dropbox, antivirus'));
      expect(view.detail, contains('then open it again'));
      expect(view.detail, contains('Nothing was changed on disk'));
      expect(
        view.detail,
        isNot(contains('does not have a specific explanation')),
        reason: 'the sentence DR-198 replaced',
      );
      expect(_ids(view), [FileErrorActionId.ok]);
    });
  });

  group('a path too long for Windows, on open (DR-200)', () {
    test('states the length AND the limit, the one save states, OK only', () {
      final view = _open(
        const OpenPathTooLong(r'C:\jobs\Smith.rmpj', length: 274),
      );
      expect(view.title, "Smith.rmpj's path is too long for Windows.");
      expect(view.detail, contains('274 characters'));
      expect(view.detail, contains('the limit is $kWindowsMaxPath'));
      expect(view.detail, contains('then open it again'));
      expect(view.detail, isNot(contains('does not have a specific')));
      expect(_ids(view), [FileErrorActionId.ok]);
    });
  });

  group('case 2 — a read-only file', () {
    test('says so, and deliberately offers NO "clear the flag" button', () {
      final view = _save(SaveReadOnlyTarget(_paths));
      expect(view.title, contains('Smith.rmpj is read-only'));
      // Silently clearing the read-only attribute on a file somebody
      // marked protected is not ours to do.
      expect(_ids(view), [FileErrorActionId.saveAs, FileErrorActionId.cancel]);
      expect(view.detail, contains('will not clear that attribute'));
    });
  });

  group('case 4 — disk full', () {
    test('states how much is needed when the size is known', () {
      final view = _save(
        SaveDiskFull(paths: _paths, step: 3),
        bytes: 601233,
      );
      expect(view.detail, contains('0.6 MB'));
    });

    test('G4: omits the number when the size is NOT known', () {
      final view = _save(SaveDiskFull(paths: _paths, step: 3));
      expect(view.detail, isNot(contains('MB')));
    });
  });

  group('case 5 — a path too long for Windows', () {
    test('states both numbers, because "too long" alone is unactionable', () {
      final view = _save(SavePathTooLong(paths: _paths, length: 264));
      expect(view.detail, contains('264 characters'));
      expect(view.detail, contains('$kWindowsMaxPath'));
    });
  });

  group('case 6 — a newer schema, refused', () {
    test('states both versions and offers NO escape hatch', () {
      final view = _open(
        const OpenNewerSchema(
          r'C:\jobs\Smith.rmpj',
          minReaderVersion: 3,
          supportedSchemaVersion: 2,
        ),
      );
      expect(view.detail, contains('reader version 3'));
      expect(view.detail, contains('version 2'));
      // An "open anyway" would turn a refusal into a corruption: the
      // fields this build cannot model would be silently dropped by the
      // first save.
      expect(_ids(view), [FileErrorActionId.ok]);
    });
  });

  group('case 7 — not a RackPal file', () {
    test('quotes the generator it actually found', () {
      final view = _open(
        const OpenNotARackPalFile(
          r'C:\photos\holiday-photos.json',
          generator: 'Blender',
        ),
      );
      expect(view.detail, contains('holiday-photos.json'));
      expect(view.detail, contains('Blender'));
    });

    test('a zip archive gets its own, more useful sentence', () {
      final view = _open(const OpenZipContainer(r'C:\jobs\archive.rmpj'));
      expect(view.title, contains('zip archive'));
    });
  });

  group('case 8 — a corrupt file, and the .bak that earns its existence', () {
    test('WITH a backup, offers to open it and states when it was made', () {
      final view = _open(
        OpenCorrupt(
          r'C:\jobs\Smith.rmpj',
          detail: 'unexpected token',
          backup: _backup,
        ),
      );
      expect(view.detail, contains('14:07 today'));
      expect(_ids(view), [
        FileErrorActionId.openBackup,
        FileErrorActionId.cancel,
      ]);
      // The recovery is completed by an EXPLICIT action, never silently.
      expect(view.detail, contains('nothing is replaced until you say so'));
    });

    test('WITHOUT a backup, says so rather than offering a dead button', () {
      final view = _open(
        const OpenCorrupt(r'C:\jobs\Smith.rmpj', detail: 'bad'),
      );
      expect(_ids(view), [FileErrorActionId.ok]);
      expect(view.detail, contains('no backup'));
    });
  });

  group('case 9 — the file is gone but the backup is not', () {
    test('offers the backup', () {
      final view = _open(
        OpenNotFound(r'C:\jobs\Smith.rmpj', backup: _backup),
      );
      expect(view.title, contains('not there any more'));
      expect(_ids(view), [
        FileErrorActionId.openBackup,
        FileErrorActionId.cancel,
      ]);
    });

    test('without one, states that the entry was removed and why — WHEN '
        'it was', () {
      final view = _open(
        const OpenNotFound(r'C:\jobs\Smith.rmpj'),
        recentEntryRemoved: true,
      );
      expect(view.detail, contains('removed it from the recent list'));
      expect(view.detail, contains('the folder it was in answered'));
    });

    test('and says NOTHING about the recent list when nothing was '
        'removed', () {
      // Three ways the old unconditional sentence was false: a degraded
      // session with no recents store at all; a path picked from File ▸
      // Open that was never in the list; and a `recents.json` write that
      // failed, because `RecentsStore.save` discards its `Outcome`. A
      // claim about the user's data that is casually untrue is how a user
      // learns to disbelieve the messages that matter.
      final view = _open(const OpenNotFound(r'C:\jobs\Smith.rmpj'));
      expect(view.detail, isNot(contains('recent list')));
      // The part that is true regardless still has to be there.
      expect(view.detail, contains('moved, renamed or deleted'));
    });
  });

  group('the external-change check', () {
    test('offers Overwrite, Save As and Cancel, in that order', () {
      final view = _save(
        SaveChangedOnDisk(
          paths: _paths,
          expected: FileBaseline.absent,
          found: FileFacts(
            size: 10,
            modified: DateTime.utc(2026),
            readOnly: false,
          ),
        ),
      );
      expect(_ids(view), [
        FileErrorActionId.overwrite,
        FileErrorActionId.saveAs,
        FileErrorActionId.cancel,
      ]);
      expect(view.detail, contains('OneDrive'));
    });

    test('a file that vanished says so instead', () {
      final view = _save(
        SaveChangedOnDisk(
          paths: _paths,
          expected: FileBaseline(size: 10, modified: _fixed),
          found: null,
        ),
      );
      expect(view.detail, contains('no longer there'));
    });
  });

  group('the two non-dialog reports', () {
    test('a save that worked says so, once', () {
      expect(describeSaveSuccess(backupUpdated: true), 'Saved.');
    });

    test('a save whose BACKUP failed still succeeded, and still reports', () {
      // Never a dialog — the save worked. Never silence either.
      expect(
        describeSaveSuccess(backupUpdated: false),
        'Saved. The backup copy could not be updated.',
      );
    });

    test('the degraded session names what is off and what still works', () {
      final installed = describeDegradedPersistence(portable: false);
      expect(installed, contains('Autosave is off'));
      expect(installed, contains('still open and save normally'));

      final portable = describeDegradedPersistence(portable: true);
      expect(portable, contains('Portable mode'));
      expect(portable, contains('still open and save normally'));
    });
  });

  group('describeBackupTime', () {
    test('says "today" for today', () {
      expect(
        describeBackupTime(DateTime(2026, 7, 26, 14, 7), now: _now),
        '14:07 today',
      );
    });

    test('gives the date otherwise', () {
      expect(
        describeBackupTime(DateTime(2026, 7, 24, 14, 7), now: _now),
        '14:07 on 2026-07-24',
      );
    });
  });

  group('backupOf', () {
    // #945 deleted `offersBackup`, which nothing in the product called; the
    // session decides with `backupOf` (session_controller.dart). That test
    // also held `backupOf`'s only assertion, so this restores it, and
    // widens it to the cases the deleted one covered through the other.
    test('returns the .bak for the two cases a backup can help with, and '
        'nothing otherwise', () {
      expect(
        backupOf(OpenNotFound(r'C:\a.rmpj', backup: _backup)),
        same(_backup),
      );
      expect(
        backupOf(OpenCorrupt(r'C:\a.rmpj', detail: 'x', backup: _backup)),
        same(_backup),
      );
      expect(backupOf(const OpenNotFound(r'C:\a.rmpj')), isNull);
      expect(backupOf(const OpenUnreachable(r'C:\a.rmpj')), isNull);
    });
  });
}

final DateTime _fixed = DateTime.utc(2026, 7, 26, 12);
