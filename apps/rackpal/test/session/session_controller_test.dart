// New / Open / Save / Save As / Close, against a fake disk.
//
// THE BRANCH THIS FILE EXISTS FOR is the one that costs a user their
// work: a save that FAILED must abort whatever asked for it, and must
// never fall through to discarding the document. It is asserted at the
// close prompt, at Ctrl+N and at Ctrl+O separately, because those are
// three call sites of one function and the whole argument for that
// function being shared is that they cannot then drift.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/data_root.dart';
import 'package:rackpal/src/storage/recents_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _target = r'C:\jobs\Smith.rmpj';

const _other = r'C:\jobs\Jones.rmpj';

/// `recents.json` inside the fake data root.
const _recentsPath = r'C:\data\recents.json';

/// A real, decodable `.rmpj` on the fake disk.
Uint8List _documentBytes({String projectName = 'Jones Loft'}) {
  final doc = buildBlankDocument(
    now: DateTime.utc(2026),
    appVersion: '0.1.0',
    id: const Uuid('on-disk-doc'),
    rackId: const Uuid('on-disk-rack'),
    catalog: const {},
  );
  doc.info.projectName = projectName;
  return const JsonDocumentCodec().write(doc);
}

/// One real edit through a real command.
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

Future<TestSession> _session({
  List<String?> savePaths = const [],
  List<String?> openPaths = const [],
  ScriptedPrompts? prompts,
  FakeFileStore? fs,
}) => buildTestSession(
  document: buildBlankDocument(
    now: DateTime.utc(2026),
    appVersion: '0.1.0',
    id: const Uuid('session-doc'),
    rackId: const Uuid('session-rack'),
    catalog: const {},
  ),
  fs: fs,
  savePaths: savePaths,
  openPaths: openPaths,
  prompts: prompts,
);

/// A fake disk whose `recents.json` already holds ONE entry for [path].
///
/// Seeding the LIST rather than saving a document is what makes the
/// eviction tests meaningful: the entry under test and the path being
/// opened have to be the same string, or `remove` is a no-op and the
/// assertion passes for the wrong reason.
FakeFileStore _diskWithRecent(String path) => FakeFileStore(
  initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
  initialFiles: {
    _recentsPath: Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'entries': [
            {
              'path': path,
              'displayName': 'Seeded',
              'lastOpened': '2026-07-26T00:00:00.000Z',
            },
          ],
        }),
      ),
    ),
  },
);

void main() {
  group('Save', () {
    test('an untitled document routes Ctrl+S to Save As', () async {
      final t = await _session(savePaths: [_target]);
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isTrue);

      expect(t.picker.saveCalls, 1);
      expect(t.services.session.filePath, _target);
      expect(t.services.session.isDirty, isFalse);
      expect(t.services.session.status, 'Saved.');
      expect(t.fs.state.files.containsKey(_target), isTrue);
    });

    test('a cancelled Save As leaves the document exactly as it was', () async {
      final t = await _session(savePaths: [null]);
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isFalse);

      // A cancelled dialog is the one "nothing happened" this layer
      // allows without reporting, because the user made it happen.
      expect(t.services.session.isDirty, isTrue);
      expect(t.services.session.filePath, isNull);
      expect(t.prompts.errors, isEmpty);
    });

    test('Save As ONTO AN EXISTING FILE does not trip the external-change '
        'check', () async {
      // THE MUTATION THIS EXISTS FOR: passing `expected: session.baseline`
      // into a Save As. The baseline describes the file the document CAME
      // FROM, so saving as a different existing file refuses with "Jones
      // has changed on disk since you opened it" — nonsense, because the
      // user just picked it in a dialog that already asked about
      // overwriting. Every earlier Save As test saved a never-saved
      // document to a fresh path, where an absent baseline matches an
      // absent file and the bug is invisible.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          // DIFFERENT LENGTHS, deliberately. The fake reports one clock
          // for every file, so `size` is the only half of the baseline
          // that can differ — two same-length project names would make
          // the two files' baselines identical and hide the bug.
          _target: _documentBytes(projectName: 'Smith'),
          _other: _documentBytes(projectName: 'Jones Loft Residence'),
        },
      );
      final t = await _session(fs: fs, savePaths: [_other]);
      expect(await t.services.controller.openPath(_target), isTrue);
      _edit(t.services.session.controller);

      expect(await t.services.controller.saveAs(), isTrue);

      expect(t.prompts.errors, isEmpty);
      expect(t.services.session.filePath, _other);
    });

    test('the suggested name is "<name>.rmpj"', () async {
      final t = await _session(savePaths: [_target]);
      await t.services.controller.save();
      expect(t.picker.suggestedNames.single, 'Untitled.rmpj');
    });

    test('a second save writes the same path with no dialog', () async {
      final t = await _session(savePaths: [_target]);
      _edit(t.services.session.controller);
      await t.services.controller.save();

      _edit(t.services.session.controller);
      expect(await t.services.controller.save(), isTrue);

      expect(t.picker.saveCalls, 1, reason: 'no second dialog');
      expect(t.services.session.isDirty, isFalse);
    });

    test(
      'the extension is forced when the dialog returns a bare name',
      () async {
        // The Windows save dialog hands back `Smith` when the user types
        // `Smith`, and a project saved without the extension will not
        // reopen by double-click.
        final t = await _session(savePaths: [r'C:\jobs\Smith']);
        expect(await t.services.controller.save(), isTrue);
        expect(t.services.session.filePath, _target);
      },
    );

    test(
      'a saved document is pushed to recents under its display name',
      () async {
        final t = await _session(savePaths: [_target]);
        await t.services.controller.save();

        final recents = await t.services.controller.loadRecents();
        expect(recents.single.path, _target);
        expect(recents.single.displayName, 'Smith');
      },
    );

    test(
      'a FAILED save reports, stays dirty, and keeps the file untouched',
      () async {
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, 'C:'},
          // No C:\jobs — the pre-flight refuses before a byte moves.
        );
        final t = await _session(savePaths: [_target], fs: fs);
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isFalse);

        expect(t.prompts.errors, hasLength(1));
        expect(t.prompts.errors.single.title, contains('Could not save'));
        expect(t.services.session.isDirty, isTrue);
        expect(fs.state.files.containsKey(_target), isFalse);
      },
    );

    test('"Try again" on a failed save retries the SAME path', () async {
      final fs = FakeFileStore(initialDirectories: {kTestDataRoot, 'C:'});
      final t = await _session(
        savePaths: [_target],
        fs: fs,
        prompts: ScriptedPrompts(
          errorActions: [FileErrorActionId.retry, FileErrorActionId.cancel],
        ),
      );

      expect(await t.services.controller.save(), isFalse);

      // Two attempts, two reports: the retry really re-ran the write
      // rather than returning the first attempt's answer.
      expect(t.prompts.errors, hasLength(2));
      expect(t.picker.saveCalls, 1);
    });

    test('"Save As…" on a failed save opens the dialog again', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, 'C:', r'C:\other'},
      );
      final t = await _session(
        savePaths: [_target, r'C:\other\Smith.rmpj'],
        fs: fs,
        prompts: ScriptedPrompts(errorActions: [FileErrorActionId.saveAs]),
      );

      expect(await t.services.controller.save(), isTrue);
      expect(t.picker.saveCalls, 2);
      expect(t.services.session.filePath, r'C:\other\Smith.rmpj');
    });
  });

  group('the external-change check', () {
    test('refuses when the file changed underneath us, and Overwrite '
        'proceeds', () async {
      final t = await _session(
        savePaths: [_target],
        prompts: ScriptedPrompts(errorActions: [FileErrorActionId.overwrite]),
      );
      await t.services.controller.save();

      // Another program writes the file. Nothing else in this design
      // stands between that and silently destroying somebody's work.
      await t.fs.writeBytes(_target, Uint8List.fromList([1, 2, 3]));
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isTrue);
      expect(t.prompts.errors, hasLength(1));
      expect(t.prompts.errors.single.title, contains('changed on disk'));
    });

    test('Cancel at that prompt leaves BOTH the document and the file '
        'alone', () async {
      final t = await _session(savePaths: [_target]);
      await t.services.controller.save();

      final foreign = Uint8List.fromList([1, 2, 3]);
      await t.fs.writeBytes(_target, foreign);
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isFalse);
      expect(t.services.session.isDirty, isTrue);
      expect(await t.fs.readBytes(_target), foreign);
    });
  });

  group('Open', () {
    test('opens a real file and adopts it', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_other: _documentBytes()},
      );
      final t = await _session(openPaths: [_other], fs: fs);

      expect(await t.services.controller.openDocument(), isTrue);

      expect(t.services.session.filePath, _other);
      expect(t.services.session.displayName, 'Jones Loft');
      expect(t.services.session.isDirty, isFalse);
    });

    test('a cancelled Open dialog changes nothing', () async {
      final t = await _session(openPaths: [null]);
      final before = t.services.session.controller;
      expect(await t.services.controller.openDocument(), isFalse);
      expect(t.services.session.controller, same(before));
    });

    test('the guard runs BEFORE the dialog', () async {
      final t = await _session(
        openPaths: [_other],
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.cancel],
        ),
      );
      _edit(t.services.session.controller);

      expect(await t.services.controller.openDocument(), isFalse);

      expect(t.prompts.discardPrompts, hasLength(1));
      expect(
        t.picker.openCalls,
        0,
        reason: 'cancelling the guard must not show a file dialog',
      );
    });

    test('a missing file with a REACHABLE directory IS evicted from its '
        'own recents entry', () async {
      final fs = _diskWithRecent(_other);
      final t = await _session(fs: fs);
      expect(await t.services.controller.loadRecents(), hasLength(1));

      await t.services.controller.openPath(_other);

      // §9.5's lazy pruning, stated as a rule about error categories:
      // this is the ONE failure definitive enough to forget an entry.
      expect(t.prompts.errors.single.title, contains('not there any more'));
      expect(await t.services.controller.loadRecents(), isEmpty);
    });

    test(
      '...and the dialog only CLAIMS the removal when it happened',
      () async {
        final fs = _diskWithRecent(_other);
        final t = await _session(fs: fs);

        await t.services.controller.openPath(_other);

        expect(
          t.prompts.errors.single.detail,
          contains('removed it from the recent list'),
        );
      },
    );

    test('nor when the removal DID NOT REACH DISK', () async {
      // `RecentsStore.remove` returns the list it COMPUTED: it awaits
      // `save`, which awaits `AtomicWriter.write` and discards the
      // `Outcome` entirely. A read-only or full data root leaves
      // recents.json unchanged, the entry is still there next launch, and
      // every in-process caller believes otherwise. The only way to know
      // is to read it back.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          _recentsPath: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'version': 1,
                'entries': [
                  {
                    'path': _other,
                    'displayName': 'Seeded',
                    'lastOpened': '2026-07-26T00:00:00.000Z',
                  },
                ],
              }),
            ),
          ),
        },
        readOnlyPaths: {_recentsPath},
      );
      final t = await _session(fs: fs);

      await t.services.controller.openPath(_other);

      expect(t.prompts.errors.single.title, contains('not there any more'));
      expect(
        t.prompts.errors.single.detail,
        isNot(contains('recent list')),
        reason:
            'the entry will still be in the menu next launch; saying it '
            'was removed is a claim the app never checked',
      );
      // THE PREMISE: the write really did fail.
      expect(await t.services.controller.loadRecents(), hasLength(1));
    });

    test('a path that was never IN the list is not claimed to have been '
        'removed', () async {
      // File ▸ Open on a path the user browsed to that was deleted a
      // moment ago. The old copy asserted the removal unconditionally,
      // telling the user RackPal had taken it out of a list it was never
      // in — a claim about their data that is casually untrue.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
      final t = await _session(fs: fs);

      await t.services.controller.openPath(_other);

      expect(t.prompts.errors.single.title, contains('not there any more'));
      expect(
        t.prompts.errors.single.detail,
        isNot(contains('recent list')),
      );
    });

    test('and neither is one in a DEGRADED session, where there is no '
        'list at all', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
      final t = await buildTestSession(
        fs: fs,
        dataRoot: const DataRootUnusable(
          attemptedPath: r'C:\locked',
          portable: false,
          cause: 'access denied',
        ),
      );

      await t.services.controller.openPath(_other);

      expect(
        t.prompts.errors.single.detail,
        isNot(contains('recent list')),
      );
    });

    test('an UNREACHABLE location does NOT evict ITS OWN entry', () async {
      // THE SEEDED ENTRY MUST BE THE PATH BEING OPENED. An earlier
      // version of this test recorded a DIFFERENT path in recents, so the
      // eviction call was a no-op whatever the rule said — inverting
      // `shouldEvictOnOpenFailure(OpenUnreachable)` to `true` left it
      // green. The mutation sweep found that; reading it did not.
      const onDeadShare = r'\\NAS\jobs\Smith.rmpj';
      final fs = _diskWithRecent(onDeadShare);
      final t = await _session(fs: fs);
      expect(await t.services.controller.loadRecents(), hasLength(1));

      // A share that is asleep answers negatively without throwing, which
      // is indistinguishable from a deleted file at the stat alone — so
      // the DIRECTORY has to be checked, and an absent directory means
      // "unreachable" rather than "gone".
      await t.services.controller.openPath(onDeadShare);

      expect(t.prompts.errors.single.title, contains('not available'));
      expect(
        await t.services.controller.loadRecents(),
        hasLength(1),
        reason: 'a temporarily unmounted drive must not evict an entry',
      );
    });

    test('a file that is not a RackPal project is refused honestly', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          r'C:\jobs\photos.rmpj': Uint8List.fromList(
            utf8.encode('{"generator":"Blender"}'),
          ),
        },
      );
      final t = await _session(fs: fs);

      expect(
        await t.services.controller.openPath(r'C:\jobs\photos.rmpj'),
        isFalse,
      );
      expect(
        t.prompts.errors.single.title,
        'That is not a RackPal file.',
      );
    });
  });

  group('the .bak fallback', () {
    test('a corrupt file offers its backup, which opens DIRTY', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          _target: Uint8List.fromList(utf8.encode('{"tru')),
          '$_target$kBackupSuffix': _documentBytes(projectName: 'Recovered'),
        },
      );
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          errorActions: [FileErrorActionId.openBackup],
        ),
      );

      expect(await t.services.controller.openPath(_target), isTrue);

      expect(t.services.session.displayName, 'Recovered');
      // It loads AS the target, so the user's next Save writes it back
      // over the damaged file — an explicit action, never silent.
      expect(t.services.session.filePath, _target);
      expect(t.services.session.isDirty, isTrue);
      expect(t.services.session.status, contains('has not been written'));
    });

    test('and the baseline is re-read, so the next save does not trip the '
        'external-change check', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          _target: Uint8List.fromList(utf8.encode('{"tru')),
          '$_target$kBackupSuffix': _documentBytes(projectName: 'Recovered'),
        },
      );
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          errorActions: [FileErrorActionId.openBackup],
        ),
      );
      await t.services.controller.openPath(_target);

      expect(await t.services.controller.save(), isTrue);
      expect(
        t.prompts.errors.where((e) => e.title.contains('changed on disk')),
        isEmpty,
      );
    });

    // ==================================================================
    // THE SAVE THAT REPAIRS THE FILE MUST NOT DESTROY WHAT REPAIRED IT
    // ==================================================================
    // Step 4 copies WHATEVER IS AT THE TARGET into `<target>.bak`. Here
    // the target is the DAMAGED file and the `.bak` is the only readable
    // copy of the project in existence — the one the user was just
    // rescued by. The whole flow was: "the file appears to be damaged" →
    // "Open the backup" → edit → Ctrl+S → the truncated file is copied
    // over the good backup BEFORE the promote.
    group('the write-back', () {
      /// A corrupt target with a good `.bak` beside it.
      FakeFileStore damagedDisk() => FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          _target: Uint8List.fromList(utf8.encode('{"tru')),
          '$_target$kBackupSuffix': _documentBytes(projectName: 'Recovered'),
        },
      );

      Future<TestSession> recoveredFromBackup(FakeFileStore fs) async {
        final t = await _session(
          fs: fs,
          prompts: ScriptedPrompts(
            errorActions: [FileErrorActionId.openBackup],
          ),
        );
        expect(await t.services.controller.openPath(_target), isTrue);
        return t;
      }

      test('does NOT copy the damaged file over the good backup', () async {
        final fs = damagedDisk();
        final good = await fs.readBytes('$_target$kBackupSuffix');
        final t = await recoveredFromBackup(fs);
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isTrue);

        expect(
          await fs.readBytes('$_target$kBackupSuffix'),
          good,
          reason:
              'the backup that just rescued the user, replaced by the '
              'truncated file it rescued them FROM. If the promote then '
              'failed, both on-disk copies would be unreadable.',
        );
        // And the repair really happened: the target is a readable
        // project again.
        expect(await t.services.controller.openPath(_target), isTrue);
        expect(t.services.session.displayName, 'Recovered');
      });

      test('and the NEXT save backs up normally again', () async {
        // Suppression is scoped to the one save that repairs the file. By
        // the second save the target is a good file — this build wrote
        // it — so the `.bak` must start tracking it again, or the user
        // silently has no backup for the rest of the session.
        final fs = damagedDisk();
        final t = await recoveredFromBackup(fs);
        _edit(t.services.session.controller);
        expect(await t.services.controller.save(), isTrue);
        final firstWriteBack = await fs.readBytes(_target);

        _edit(t.services.session.controller);
        expect(await t.services.controller.save(), isTrue);

        expect(
          await fs.readBytes('$_target$kBackupSuffix'),
          firstWriteBack,
          reason: 'the .bak must hold the previous good version (I6)',
        );
      });

      test('a stat that does not answer records UNKNOWN, not ABSENT', () async {
        // `FileBaseline.of(null)` is `absent`, which is a POSITIVE CLAIM
        // that there is no file. The file was just READ — it is damaged,
        // not missing — so a stat that throws (a network hiccup, an AV
        // scanner holding the handle) means "cannot tell", and recording
        // "not there" makes the very next Ctrl+S refuse with a dialog
        // blaming a sync client for a change nobody made.
        final faults = <int, Object>{};
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
          initialFiles: {
            _target: Uint8List.fromList(utf8.encode('{"tru')),
            '$_target$kBackupSuffix': _documentBytes(projectName: 'Recovered'),
          },
          faults: faults,
        );
        final prompts = ScriptedPrompts(
          errorActions: [FileErrorActionId.openBackup],
        );
        final t = await _session(fs: fs, prompts: prompts);
        // Inside the dialog, arm a fault for the stat that follows the
        // backup read: `_openBackup` does readBytes, then decode (no fs
        // ops), then exactly one stat.
        prompts.onBeforeErrorAnswer = () async {
          faults[fs.operationCount + 1] = const StorageOsException(
            1231,
            'the share blinked',
          );
        };

        expect(await t.services.controller.openPath(_target), isTrue);
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isTrue);
        expect(
          t.prompts.errors.where((e) => e.title.contains('changed on disk')),
          isEmpty,
        );
      });

      test('but a target that is GONE records ABSENT, and a file that '
          'reappears still stops the save', () async {
        // `backupOf` answers for BOTH `OpenCorrupt` and `OpenNotFound`,
        // and those are opposite facts about whether the file exists.
        // Blanket `unknown` here would silently overwrite a file somebody
        // restored from a backup between the open and the save.
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
          initialFiles: {
            '$_target$kBackupSuffix': _documentBytes(projectName: 'Recovered'),
          },
        );
        final t = await _session(
          fs: fs,
          prompts: ScriptedPrompts(
            errorActions: [FileErrorActionId.openBackup],
          ),
        );
        expect(await t.services.controller.openPath(_target), isTrue);

        // Somebody restores the file from a network backup.
        await fs.writeBytes(_target, _documentBytes(projectName: 'Restored'));
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isFalse);
        expect(
          t.prompts.errors.last.title,
          contains('changed on disk'),
        );
      });

      test('and an ORDINARY save still refreshes the backup', () async {
        // The control. Without it, "suppress the backup" could be wired
        // to every save and this group would still be green.
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
          initialFiles: {_target: _documentBytes(projectName: 'Good')},
        );
        final t = await _session(fs: fs);
        expect(await t.services.controller.openPath(_target), isTrue);
        final before = await fs.readBytes(_target);
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isTrue);

        expect(await fs.readBytes('$_target$kBackupSuffix'), before);
      });
    });
  });

  // ====================================================================
  // §9.3's PRE-UPDATE SNAPSHOT — INSURANCE AGAINST AN IRREVERSIBLE WRITE
  // ====================================================================
  // The first save of a MIGRATED file rewrites it at a schema version an
  // older RackPal the user may still have installed cannot read. The
  // original bytes live in RAM and nowhere else until this snapshot runs.
  // It used to run AFTER the promote, discard its `Outcome`, and clear
  // the pending bytes two lines before the `await` — so a data root that
  // was full or unwritable produced no snapshot, no retry ever, a log
  // line claiming success, and a bare "Saved." on screen.
  group('the pre-update snapshot', () {
    /// [_documentBytes] re-stamped as a v1 file, which is what makes
    /// `decodeBytes` report `migratedFromSchemaVersion` and retain the
    /// original bytes.
    Uint8List v1Bytes() {
      final raw =
          jsonDecode(utf8.decode(_documentBytes(projectName: 'Legacy')))
              as Map<String, Object?>;
      raw['schemaVersion'] = 1;
      raw['minReaderVersion'] = 1;
      return Uint8List.fromList(utf8.encode(jsonEncode(raw)));
    }

    FakeFileStore diskWithV1({Set<String>? readOnly}) => FakeFileStore(
      initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      initialFiles: {_target: v1Bytes()},
      readOnlyPaths: readOnly ?? const {},
    );

    /// Where the pre-update snapshot of the currently open document lands.
    ///
    /// [sequence] IS THE ONE THE PRESERVED BYTES CARRY — the document's
    /// sequence at OPEN time — and every call site captures it before the
    /// first edit for that reason. This helper used to read
    /// `session.document.sequence` at call time, which is the live value:
    /// it moves on every commit, so a v1 original preserved from a
    /// document the user had edited three times was filed as
    /// `3.rmpj`, a name that describes neither its content nor its
    /// schema version. `SnapshotStore.prune` sorts numerically on exactly
    /// that stem, so the "last 10" window was ordered by a number that
    /// identified nothing.
    String snapshotPathFor(TestSession t, int sequence) =>
        t.services.controller.stores!.snapshots.pathFor(
          t.services.session.documentId,
          sequence,
        );

    /// Makes [path] refuse writes, the way a full volume or a
    /// write-protected stick does.
    Future<void> lock(
      FakeFileStore fs,
      Set<String> readOnly,
      String path,
      p.Context context,
    ) async {
      await fs.createDirectory(context.dirname(path));
      await fs.writeBytes(path, Uint8List.fromList([1]));
      readOnly.add(path);
    }

    test('is taken BEFORE the irreversible write, not after it', () async {
      // A crash in the window between the promote and the snapshot loses
      // the pre-migration original permanently — which is precisely the
      // irreversibility this feature exists to insure against.
      final fs = diskWithV1();
      final t = await _session(fs: fs);
      expect(await t.services.controller.openPath(_target), isTrue);
      final atOpen = t.services.session.document.sequence;
      _edit(t.services.session.controller);
      final snapshot = snapshotPathFor(t, atOpen);
      fs.resetJournal();

      expect(await t.services.controller.save(), isTrue);

      final ops = fs.journal.map((o) => o.toString()).toList();
      final snapshotLanded = ops.indexWhere((o) => o.contains('-> $snapshot'));
      final targetLanded = ops.indexWhere((o) => o.contains('-> $_target'));
      expect(snapshotLanded, greaterThanOrEqualTo(0));
      expect(targetLanded, greaterThan(snapshotLanded));
      expect(t.services.session.status, 'Saved.');
    });

    test('...and it is filed under the sequence ITS OWN BYTES carry, not '
        'the live document’s', () async {
      // `<sequence>.rmpj` is a claim about content. The bytes are the
      // PRE-migration original; the live sequence advances on every commit
      // and had already moved by the time the save ran. Filing a v1
      // original as `3.rmpj` names a state that never existed at that
      // version — and `SnapshotStore.prune` orders the "last 10" window by
      // exactly this stem.
      final fs = diskWithV1();
      final t = await _session(fs: fs);
      expect(await t.services.controller.openPath(_target), isTrue);
      final atOpen = t.services.session.document.sequence;
      _edit(t.services.session.controller);
      _edit(t.services.session.controller);
      _edit(t.services.session.controller);
      final live = t.services.session.document.sequence;
      expect(
        live,
        greaterThan(atOpen),
        reason: 'without a divergence this test asserts nothing',
      );

      expect(await t.services.controller.save(), isTrue);

      final written = snapshotPathFor(t, atOpen);
      expect(
        fs.state.files.containsKey(written),
        isTrue,
        reason: 'the preserved bytes are the ones from $atOpen',
      );
      expect(
        fs.state.files.containsKey(snapshotPathFor(t, live)),
        isFalse,
        reason:
            'a file named for the live sequence would describe a state '
            'that never existed at schema version 1',
      );
      // And the content really is the original, so the name and the bytes
      // now agree.
      final kept =
          jsonDecode(utf8.decode(await fs.readBytes(written)))
              as Map<String, Object?>;
      expect(kept['schemaVersion'], 1);
      expect(kept['sequence'], atOpen);
    });

    test('is only taken ONCE — the second save has nothing new', () async {
      final fs = diskWithV1();
      final t = await _session(fs: fs);
      await t.services.controller.openPath(_target);
      _edit(t.services.session.controller);
      await t.services.controller.save();
      fs.resetJournal();

      _edit(t.services.session.controller);
      await t.services.controller.save();

      expect(
        fs.journal.where((o) => o.toString().contains('snapshots')),
        isEmpty,
        reason:
            'ten identical copies would push the nine genuinely different '
            'ones out of the pruned window',
      );
    });

    test('a FAILURE is reported to the user, not logged and dropped', () async {
      final readOnly = <String>{};
      final fs = diskWithV1(readOnly: readOnly);
      final t = await _session(fs: fs);
      await t.services.controller.openPath(_target);
      final atOpen = t.services.session.document.sequence;
      _edit(t.services.session.controller);
      // Occupy the snapshot's own path with a read-only file: the volume
      // filled, an admin policy landed, the stick was write-protected.
      await lock(fs, readOnly, snapshotPathFor(t, atOpen), t.context);

      // The SAVE still succeeds. The user asked for it, and refusing
      // would be worse than saving without the insurance.
      expect(await t.services.controller.save(), isTrue);

      expect(
        t.services.session.status,
        contains('could not keep a copy of this file as it was'),
        reason:
            'the only version an older RackPal could open has just been '
            'overwritten and not kept anywhere. "Saved." is a lie.',
      );
      expect(t.services.session.status, contains('Older versions'));
    });

    test(
      '...and the NEXT save retries it, because the bytes were kept',
      () async {
        final readOnly = <String>{};
        final fs = diskWithV1(readOnly: readOnly);
        final t = await _session(fs: fs);
        await t.services.controller.openPath(_target);
        final atOpen = t.services.session.document.sequence;
        _edit(t.services.session.controller);
        await lock(fs, readOnly, snapshotPathFor(t, atOpen), t.context);
        await t.services.controller.save();

        // The stick is unlocked / space is freed.
        readOnly.clear();
        _edit(t.services.session.controller);
        // THE SAME PATH AS THE FIRST ATTEMPT. The retry preserves the same
        // bytes, so it must name them the same way — a retry that moved to
        // the live sequence would leave the failed attempt's read-only
        // placeholder behind and file the original under a second, equally
        // wrong number.
        final retried = snapshotPathFor(t, atOpen);
        expect(await t.services.controller.save(), isTrue);

        expect(t.services.session.status, 'Saved.');
        // The bytes really are the PRE-migration original, not a re-encode
        // of what is in memory now — which is the whole point of holding
        // them rather than clearing the pending state on failure.
        final kept =
            jsonDecode(utf8.decode(await fs.readBytes(retried)))
                as Map<String, Object?>;
        expect(kept['schemaVersion'], 1);
        expect(kept['minReaderVersion'], 1);
      },
    );

    test(
      'the DEGRADED session says so too, on the save it applies to',
      () async {
        // `describeDegradedPersistence` is written once at startup and
        // cannot know that a document opened later would need migrating.
        final fs = diskWithV1();
        final t = await buildTestSession(
          fs: fs,
          dataRoot: const DataRootUnusable(
            attemptedPath: r'D:\RackPal\RackPalData',
            portable: true,
            cause: 'read-only',
          ),
        );
        await t.services.controller.openPath(_target);
        _edit(t.services.session.controller);

        expect(await t.services.controller.save(), isTrue);

        expect(
          t.services.session.status,
          contains('could not keep a copy of this file as it was'),
        );
      },
    );

    test('an ORDINARY save says nothing about it at all', () async {
      // The control: a document that was never migrated must not carry a
      // warning about insurance it never needed.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_target: _documentBytes()},
      );
      final t = await _session(fs: fs);
      await t.services.controller.openPath(_target);
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isTrue);
      expect(t.services.session.status, 'Saved.');
    });
  });

  group('New', () {
    test('replaces the document with a blank one carrying a rack', () async {
      final t = await _session();
      final before = t.services.session.controller;

      expect(await t.services.controller.newDocument(), isTrue);

      expect(t.services.session.controller, isNot(same(before)));
      expect(t.services.session.filePath, isNull);
      expect(t.services.session.isDirty, isFalse);
      // Ctrl+N must not land the user on a panel explaining there is no
      // way to add a rack.
      expect(t.services.session.document.racks, hasLength(1));
      expect(
        t.services.session.document.racks.values.single.heightU,
        kBlankProjectRackHeightU,
      );
    });

    test('the guard cancels it', () async {
      final t = await _session(
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.cancel],
        ),
      );
      _edit(t.services.session.controller);
      final before = t.services.session.controller;

      expect(await t.services.controller.newDocument(), isFalse);
      expect(t.services.session.controller, same(before));
    });

    test('"Don\u2019t Save" at the guard proceeds AND deletes the recovery '
        'snapshot', () async {
      final t = await _session(
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.dontSave],
        ),
      );
      _edit(t.services.session.controller);
      // The forced snapshot the guard takes before the dialog.
      final docId = t.services.session.documentId;

      expect(await t.services.controller.newDocument(), isTrue);

      // An explicit "Don't Save" IS a clean exit for that document.
      // Offering to recover work the user just told us to throw away is
      // worse than losing it.
      final remaining = t.fs.state.files.keys.where(
        (k) => k.contains(docId),
      );
      expect(remaining, isEmpty);
    });

    test('"Save" at the guard that FAILS aborts the New', () async {
      final fs = FakeFileStore(initialDirectories: {kTestDataRoot, 'C:'});
      final t = await _session(
        fs: fs,
        savePaths: [_target],
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.save],
          errorActions: [FileErrorActionId.cancel],
        ),
      );
      _edit(t.services.session.controller);
      final before = t.services.session.controller;

      expect(await t.services.controller.newDocument(), isFalse);

      // THE BRANCH THIS WHOLE FILE EXISTS FOR.
      expect(t.services.session.controller, same(before));
      expect(t.services.session.isDirty, isTrue);
    });
  });

  group('Close', () {
    test('a clean document closes without a prompt', () async {
      final t = await _session();
      await t.chrome.requestClose();
      expect(t.prompts.discardPrompts, isEmpty);
      expect(t.chrome.destroyCalls, 1);
    });

    test(
      'a dirty document prompts, and Cancel keeps the window open',
      () async {
        final t = await _session(
          prompts: ScriptedPrompts(
            discardChoices: [UnsavedChangesChoice.cancel],
          ),
        );
        _edit(t.services.session.controller);

        await t.chrome.requestClose();

        expect(t.prompts.discardPrompts, hasLength(1));
        expect(t.chrome.destroyCalls, 0);
      },
    );

    test(
      'a FAILED save at the close prompt does NOT close the window',
      () async {
        final fs = FakeFileStore(initialDirectories: {kTestDataRoot, 'C:'});
        final t = await _session(
          fs: fs,
          savePaths: [_target],
          prompts: ScriptedPrompts(
            discardChoices: [UnsavedChangesChoice.save],
            errorActions: [FileErrorActionId.cancel],
          ),
        );
        _edit(t.services.session.controller);

        await t.chrome.requestClose();

        // "Closing anyway would be the single worst bug this layer can
        // have." The document is still dirty, still open, still snapshotted.
        expect(t.chrome.destroyCalls, 0);
        expect(t.services.session.isDirty, isTrue);
        expect(t.prompts.errors, hasLength(1));
      },
    );

    test('the close prompt states the edit count', () async {
      final t = await _session(
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.cancel],
        ),
      );
      _edit(t.services.session.controller);

      await t.chrome.requestClose();

      expect(t.prompts.discardPrompts.single.editCount, 1);
      expect(t.prompts.discardPrompts.single.name, 'Untitled');
    });

    test('a snapshot is FORCED before the dialog is shown', () async {
      final t = await _session(
        prompts: ScriptedPrompts(
          discardChoices: [UnsavedChangesChoice.cancel],
        ),
      );
      _edit(t.services.session.controller);

      await t.chrome.requestClose();

      // The close prompt is the moment a user walks away from the
      // machine: the 30 s timer guarantees at most 30 s of loss, and a
      // modal dialog can sit for an hour.
      expect(t.services.autosave.snapshotCount, 1);
    });

    test(
      'a successful save at the close prompt closes and cleans up',
      () async {
        final t = await _session(
          savePaths: [_target],
          prompts: ScriptedPrompts(
            discardChoices: [UnsavedChangesChoice.save],
          ),
        );
        _edit(t.services.session.controller);
        final docId = t.services.session.documentId;

        await t.chrome.requestClose();

        expect(t.chrome.destroyCalls, 1);
        expect(t.fs.state.files.containsKey(_target), isTrue);
        expect(
          t.fs.state.files.keys.where((k) => k.contains(docId)),
          isEmpty,
          reason: 'the snapshot goes at step 7 of a successful save',
        );
      },
    );
  });

  group('read-only documents', () {
    test('Ctrl+S on a newer-schema file routes to Save As with a "(copy)" '
        'name', () async {
      final t = await _session(savePaths: [r'C:\jobs\Smith (copy).rmpj']);
      t.services.session.adopt(
        controller: t.services.session.controller,
        filePath: _target,
        openReadOnly: true,
        baseline: FileBaseline.absent,
      );

      expect(await t.services.controller.save(), isTrue);

      expect(t.picker.saveCalls, 1);
      expect(t.picker.suggestedNames.single, 'Smith (copy).rmpj');
      // No longer read-only, because these bytes are ours.
      expect(t.services.session.openReadOnly, isFalse);
    });

    // ================================================================
    // THE BANNER'S CLAIM, ASSERTED AGAINST THE BYTES IT IS ABOUT
    // ================================================================
    // `ReadOnlyBanner.message` used to say "It is open read-only so
    // nothing in it is lost. Save a copy to keep your changes." — which
    // together tell the user the copy carries the newer build's data.
    // It does not: the only forward-compat passthrough in the codec is a
    // literal `unknown` sub-object at four places, and every entity
    // decoder reads the keys it knows and discards the rest. CR-093's
    // "unknown fields preserved for a subsequent Save As" is NOT
    // implemented. The old test asserted the opposite in a COMMENT and
    // never looked at a byte.
    test('a Save As copy does NOT carry the newer build’s unmodelled '
        'keys — and the banner no longer says it does', () async {
      final future =
          jsonDecode(utf8.decode(_documentBytes())) as Map<String, Object?>;
      // A newer build's file: same schema version this build reads, plus
      // a root key it has never heard of.
      future['siteSurvey'] = {'photos': 12, 'notes': 'north wall'};
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          _target: Uint8List.fromList(utf8.encode(jsonEncode(future))),
        },
      );
      final t = await _session(fs: fs, savePaths: [_other]);
      expect(await t.services.controller.openPath(_target), isTrue);
      _edit(t.services.session.controller);

      expect(await t.services.controller.saveAs(), isTrue);

      final copy =
          jsonDecode(utf8.decode(await fs.readBytes(_other)))
              as Map<String, Object?>;
      expect(
        copy.containsKey('siteSurvey'),
        isFalse,
        reason:
            'THE PREMISE. If this ever becomes true, preservation has '
            'been implemented and ReadOnlyBanner.message must go back to '
            'promising it — in the same commit.',
      );
      // The original is untouched, which is the half of the message that
      // IS true and is what the copy now says.
      expect(
        jsonDecode(utf8.decode(await fs.readBytes(_target))),
        future,
      );
      expect(
        ReadOnlyBanner.message,
        isNot(contains('nothing in it is lost')),
        reason: 'a false reassurance about data loss is worse than none',
      );
      expect(
        ReadOnlyBanner.message,
        contains('only contain the parts this version understands'),
      );
      expect(
        ReadOnlyBanner.message,
        contains('left exactly as it is'),
      );
    });
  });

  // ====================================================================
  // A STORED ABSOLUTE PATH IS NOT HANDED TO A NATIVE DIALOG UNCHECKED
  // ====================================================================
  // `prefs.json` travels with a portable installation, so
  // `lastSaveDirectory` can be a value recorded on a DIFFERENT machine.
  // A UNC one goes straight into `SHCreateItemFromParsingName` on the
  // platform thread, and the window freezes for seconds before any dialog
  // appears.
  group('the remembered save directory', () {
    /// `prefs.json` holding [directory] as `lastSaveDirectory`.
    FakeFileStore diskWithSaveDirectory(
      String directory, {
      Set<String> hanging = const {},
    }) => FakeFileStore(
      initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      initialFiles: {
        r'C:\data\prefs.json': Uint8List.fromList(
          utf8.encode(
            jsonEncode({'version': 1, 'lastSaveDirectory': directory}),
          ),
        ),
      },
      hangingPaths: hanging,
    );

    test('is used when it is really there', () async {
      final fs = diskWithSaveDirectory(kTestJobsDir);
      final t = await _session(fs: fs, openPaths: [null]);

      await t.services.controller.openDocument();

      expect(t.picker.initialDirectories.single, kTestJobsDir);
    });

    test('a DEAD UNC share is not passed to the dialog', () async {
      const deadShare = r'\\officenas\jobs';
      final fs = diskWithSaveDirectory(deadShare, hanging: {deadShare});
      final t = await buildTestSession(
        fs: fs,
        openPaths: [null],
        pathProbeTimeout: const Duration(milliseconds: 1),
      );

      await t.services.controller.openDocument();

      expect(
        t.picker.initialDirectories.single,
        isNull,
        reason:
            'the OS picks a folder instead — which is a visible change, '
            'and infinitely better than a frozen window',
      );
    });

    test('a directory that is simply GONE is dropped too, and not '
        're-probed', () async {
      final fs = diskWithSaveDirectory(r'C:\gone');
      final t = await _session(fs: fs, openPaths: [null, null]);

      await t.services.controller.openDocument();
      await t.services.controller.openDocument();

      expect(t.picker.initialDirectories, [null, null]);
    });

    test('a successful Save As MOVES IT — in this session, not only in '
        'prefs.json', () async {
      // `_rememberSaveDirectory` used to write `prefs.json` and stop
      // there, while the field the dialog is actually seeded from moved in
      // exactly one place: the startup seed. So a user who saved into
      // C:\jobs got the dialog back at the STARTUP directory on their very
      // next Save As, and on every Open, for the whole session — the
      // stored value was correct and nothing read it until the next
      // launch.
      const startup = r'C:\old';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, startup, 'C:'},
        initialFiles: {
          r'C:\data\prefs.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({'version': 1, 'lastSaveDirectory': startup}),
            ),
          ),
        },
      );
      final t = await _session(
        fs: fs,
        savePaths: [r'C:\jobs\A.rmpj', r'C:\jobs\B.rmpj'],
      );

      expect(await t.services.controller.saveAs(), isTrue);
      expect(await t.services.controller.saveAs(), isTrue);

      expect(
        t.picker.initialDirectories,
        [startup, kTestJobsDir],
        reason:
            'the SECOND dialog must open where the first save actually '
            'went',
      );
      // ...and it still reaches disk, so the next launch agrees.
      expect(
        (await t.services.controller.stores!.prefs.load()).lastSaveDirectory,
        kTestJobsDir,
      );
    });

    test('...and an Open dialog opened afterwards agrees with it', () async {
      const startup = r'C:\old';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, startup, 'C:'},
        initialFiles: {
          r'C:\data\prefs.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({'version': 1, 'lastSaveDirectory': startup}),
            ),
          ),
        },
      );
      final t = await _session(
        fs: fs,
        savePaths: [r'C:\jobs\A.rmpj'],
        openPaths: [null],
      );

      expect(await t.services.controller.saveAs(), isTrue);
      await t.services.controller.openDocument();

      expect(t.picker.initialDirectories, [startup, kTestJobsDir]);
    });

    test('a WINDOW MOVE after a Save As does not revert it', () async {
      // THE DEFECT A TEST-ONLY WRITER WAS HIDING. `AppServices.prefs` was
      // documented as the live prefs that stop a geometry write clobbering
      // `lastSaveDirectory`, and it had zero writers anywhere in `lib/` —
      // the only assignment in the repository was one line in
      // `window_chrome_test.dart`. So in production the geometry recorder
      // wrote the STARTUP snapshot back over prefs.json 500 ms after the
      // user nudged the window, and the directory they had just saved into
      // was gone.
      const startup = r'C:\old';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, startup, 'C:'},
        initialFiles: {
          r'C:\data\prefs.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({'version': 1, 'lastSaveDirectory': startup}),
            ),
          ),
        },
      );
      final t = await _session(fs: fs, savePaths: [r'C:\jobs\A.rmpj']);

      /// `prefs.json` READ AS BYTES, never through `PrefsStore.load`.
      ///
      /// Found by mutation: `load()` refreshes the store's live value, so
      /// a test that reads through it between the Save As and the window
      /// move performs the very repair whose absence is the defect — and
      /// the mutation "stop updating the live value on save" survived.
      Future<Object?> storedDirectory() async =>
          (jsonDecode(utf8.decode(await fs.readBytes(r'C:\data\prefs.json')))
              as Map<String, Object?>)['lastSaveDirectory'];

      expect(await t.services.controller.saveAs(), isTrue);
      expect(await storedDirectory(), kTestJobsDir);

      // The user moves the window. The debounced geometry write follows.
      t.services.geometry!.onGeometryChanged();
      await t.services.geometry!.flush();

      expect(
        await storedDirectory(),
        kTestJobsDir,
        reason:
            'a geometry write must record geometry, and nothing else. It '
            'used to put the whole startup snapshot back.',
      );
      final after = await t.services.controller.stores!.prefs.load();
      expect(after.window, isNotNull, reason: 'and it still records that');
    });
  });

  group('recents', () {
    test('nothing on the startup path stats an entry', () async {
      // `exists` on a dead UNC path was measured at 1261 ms. Ten of those
      // is ten times the whole cold-start budget.
      const dead = r'\\NAS\jobs\Ghost.rmpj';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {
          r'C:\data\recents.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'version': 1,
                'entries': [
                  {
                    'path': dead,
                    'displayName': 'Ghost',
                    'lastOpened': '2026-07-26T00:00:00.000Z',
                  },
                ],
              }),
            ),
          ),
        },
        // Its `exists` future NEVER completes.
        hangingPaths: {dead},
      );
      final t = await _session(fs: fs);

      // The load returns without ever awaiting the hanging path.
      final entries = await t.services.controller.loadRecents();
      expect(entries.single.displayName, 'Ghost');
    });

    test('the menu-open probe reports `checking` for a hung entry rather '
        'than removing it', () async {
      const dead = r'\\NAS\jobs\Ghost.rmpj';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        hangingPaths: {dead},
      );
      final t = await _session(fs: fs);
      final entries = [
        RecentEntry(
          path: dead,
          displayName: 'Ghost',
          lastOpened: DateTime.utc(2026),
        ),
      ];

      final states = await t.services.controller.probeRecents(entries);

      expect(states[dead], RecentEntryState.checking);
    });
  });
}
