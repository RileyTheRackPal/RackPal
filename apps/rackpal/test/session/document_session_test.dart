// The window title, the display name, and the dirty bit that both read.
//
// ALL PURE, so `*Smith Residence — RackPal` is checked without a window
// manager and `C:\jobs\Smith.rmpj` is checked on a Linux CI runner.
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';

final _windows = p.Context(style: p.Style.windows);

const Uuid _rackId = Uuid('rack-1');

RackDocument _doc({String projectName = ''}) {
  final now = DateTime.utc(2026);
  final doc = buildBlankDocument(
    now: now,
    appVersion: '0.1.0',
    id: const Uuid('doc-1'),
    rackId: _rackId,
    catalog: const {},
  );
  doc.info.projectName = projectName;
  return doc;
}

DocumentSession _session({
  String projectName = '',
  String? filePath,
  bool openReadOnly = false,
}) => DocumentSession(
  controller: DocumentController(_doc(projectName: projectName)),
  context: _windows,
  filePath: filePath,
  openReadOnly: openReadOnly,
);

/// One real edit through a real command, so the dirty bit moves the way it
/// moves in the app rather than by poking `stateId`.
void _edit(DocumentController controller) {
  final rack = controller.doc.racks.values.first;
  controller.run(
    SetRackHeightCommand(
      id: rack.id,
      fromHeightU: rack.heightU,
      toHeightU: rack.heightU - 1,
      now: DateTime.utc(2026),
      actor: 'test',
    ),
  );
}

void main() {
  group('displayNameFor', () {
    test('prefers the project name', () {
      expect(
        displayNameFor(
          projectName: 'Smith Residence',
          filePath: r'C:\jobs\smith-v3.rmpj',
          context: _windows,
        ),
        'Smith Residence',
      );
    });

    test('falls back to the file stem', () {
      expect(
        displayNameFor(
          projectName: '   ',
          filePath: r'C:\jobs\smith-v3.rmpj',
          context: _windows,
        ),
        'smith-v3',
      );
    });

    test('falls back to Untitled', () {
      expect(
        displayNameFor(projectName: null, filePath: null, context: _windows),
        'Untitled',
      );
    });
  });

  group('windowTitleFor', () {
    test('a clean document carries no marker', () {
      expect(
        windowTitleFor(
          displayName: 'Smith Residence',
          isDirty: false,
          readOnly: false,
        ),
        'Smith Residence — RackPal',
      );
    });

    test('a dirty document is marked with * — the Windows convention, and '
        'pronounceable by a screen reader', () {
      expect(
        windowTitleFor(
          displayName: 'Smith Residence',
          isDirty: true,
          readOnly: false,
        ),
        '*Smith Residence — RackPal',
      );
    });

    test('read-only is stated in the title, because it changes what Ctrl+S '
        'does', () {
      expect(
        windowTitleFor(
          displayName: 'Smith',
          isDirty: true,
          readOnly: true,
        ),
        '*Smith (read-only) — RackPal',
      );
    });
  });

  group('DocumentSession', () {
    test('isDirty forwards to the controller and moves on a real edit', () {
      final session = _session();
      expect(session.isDirty, isFalse);
      expect(session.windowTitle, 'Untitled — RackPal');

      _edit(session.controller);

      expect(session.isDirty, isTrue);
      expect(session.windowTitle, '*Untitled — RackPal');
    });

    test('CR-094: undoing back to the save point reads CLEAN again', () {
      final session = _session();
      _edit(session.controller);
      expect(session.isDirty, isTrue);

      session.controller.undoLast();

      // This is the property the whole `stateIdBefore`/`stateIdAfter`
      // machinery exists for, and it is user-visible HERE: a monotonic
      // counter would prompt "save changes?" for a document byte-identical
      // to the one on disk.
      expect(session.isDirty, isFalse);
      expect(session.windowTitle, 'Untitled — RackPal');
    });

    test('a change notification reaches Flutter listeners', () {
      final session = _session();
      var notifications = 0;
      session.addListener(() => notifications++);

      _edit(session.controller);

      // `DocumentController.changes` is a pure-Dart `SimpleNotifier`,
      // because core must not import Flutter. This is the adapter, and
      // this is the assertion that it is wired.
      expect(notifications, greaterThan(0));
    });

    test('editsSinceSave counts real edits', () {
      final session = _session();
      expect(session.editsSinceSave, 0);

      _edit(session.controller);
      expect(session.editsSinceSave, 1);

      // A DIFFERENT command, deliberately: two consecutive height changes
      // coalesce into one undo entry inside the merge window, which is
      // correct behaviour and would make this test about coalescing
      // rather than about counting.
      final rack = session.document.racks.values.first;
      session.controller.run(
        SetEntityPropertyCommand<Rack, String>(
          id: rack.id,
          field: RackField.designator,
          from: rack.designator,
          to: 'RK-7',
          now: DateTime.utc(2026),
          actor: 'test',
        ),
      );
      expect(session.editsSinceSave, 2);
    });

    test('requiresSaveAs when there is no path', () {
      expect(_session().requiresSaveAs, isTrue);
      expect(
        _session(filePath: r'C:\jobs\Smith.rmpj').requiresSaveAs,
        isFalse,
      );
    });

    test('requiresSaveAs when the file opened READ-ONLY, however saved it '
        'already is', () {
      // A file this build only partly understands must not be overwritten
      // by it — but the user must never be blocked from keeping work.
      final session = _session(
        filePath: r'C:\jobs\Smith.rmpj',
        openReadOnly: true,
      );
      expect(session.requiresSaveAs, isTrue);
    });

    test('recordSave clears read-only, because the bytes on disk are now '
        'ours', () {
      final session = _session(
        filePath: r'C:\jobs\Smith.rmpj',
        openReadOnly: true,
      );
      expect(session.requiresSaveAs, isTrue);

      session.recordSave(
        SavedFileFixture.at(r'C:\jobs\Copy.rmpj'),
        status: 'Saved.',
      );

      expect(session.openReadOnly, isFalse);
      expect(session.filePath, r'C:\jobs\Copy.rmpj');
      expect(session.status, 'Saved.');
    });

    test('markUnsavedRecovery makes a freshly-decoded document dirty', () {
      final session = _session();
      expect(session.isDirty, isFalse);

      session.markUnsavedRecovery();

      // A recovered snapshot has NOT been written to the user's file. If
      // it read clean, the close prompt would let it go silently — which
      // is the exact loss the snapshot existed to prevent.
      expect(session.isDirty, isTrue);
      // ...and the count is genuinely unknown, so it is omitted (G4)
      // rather than filled in from a stack that no longer exists.
      expect(session.editsSinceSave, isNull);
    });

    test('adopt swaps the controller and re-subscribes', () {
      final session = _session();
      final replacement = DocumentController(_doc(projectName: 'Jones'));

      session.adopt(
        controller: replacement,
        filePath: r'C:\jobs\Jones.rmpj',
        openReadOnly: false,
        baseline: FileBaseline.absent,
      );

      expect(session.displayName, 'Jones');
      var notifications = 0;
      session.addListener(() => notifications++);
      _edit(replacement);
      expect(
        notifications,
        greaterThan(0),
        reason: 'the NEW controller must be the one being listened to',
      );
    });

    test('disableRecovery is one-way and notifies once', () {
      final session = _session();
      expect(session.recoveryEnabled, isTrue);
      var notifications = 0;

      session
        ..addListener(() => notifications++)
        ..disableRecovery()
        ..disableRecovery();

      expect(session.recoveryEnabled, isFalse);
      expect(notifications, 1);
    });
  });

  group('the default project name is treated as NO name', () {
    test('kDefaultProjectName still matches core’s own default', () {
      // If core ever changes its default, this fails here rather than
      // silently retitling every window "Untitled Project".
      expect(ProjectInfo().projectName, kDefaultProjectName);
    });

    test('a file stem beats it', () {
      expect(
        displayNameFor(
          projectName: kDefaultProjectName,
          filePath: r'C:\jobs\Smith.rmpj',
          context: _windows,
        ),
        'Smith',
      );
    });

    test('and with no file it falls all the way to Untitled', () {
      expect(
        displayNameFor(
          projectName: kDefaultProjectName,
          filePath: null,
          context: _windows,
        ),
        'Untitled',
      );
    });
  });

  group('copySuggestionFor', () {
    test('a read-only document saves as "<name> (copy).rmpj"', () {
      expect(
        copySuggestionFor('Smith Residence'),
        'Smith Residence (copy).rmpj',
      );
    });
  });
}

/// A minimal `SavedFile`, built here rather than by running a real save,
/// because these tests are about the session's bookkeeping and not about
/// the writer.
abstract final class SavedFileFixture {
  static SavedFile at(String target) => SavedFile(
    paths: SavePaths.forTarget(target, context: _windows),
    baseline: FileBaseline(size: 10, modified: _epoch),
    savedStateId: 1,
    bytesWritten: 10,
    backupAttempted: false,
    backupUpdated: false,
  );
}

final DateTime _epoch = DateTime.utc(2026, 7, 26, 14, 32);
