// The startup scan and the three-way prompt (§9.4).
//
// The properties defended here are all about NOT LOSING WORK by being
// helpful: a recovered document is dirty until the user saves it, its
// snapshot survives until that save succeeds, and "Keep for later" really
// does mean the prompt comes back next launch.
//
// WHAT THIS FILE DOES NOT PROVE, stated so the next reader does not assume
// otherwise: the survivor here is SEEDED into `FakeFileStore.initialFiles`
// by `_crashedDisk`, so nothing below exercises the code that WRITES a
// snapshot. That half — that the bytes the autosave puts on disk decode
// back into the document that was open — is
// `autosave_scheduler_test.dart`'s "the snapshot round-trips back to the
// document it protects". Between them the loop is closed; neither alone
// closes it, and for a long time neither existed.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/autosave_scheduler.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate/src/session/document_session.dart';
import 'package:rackmate/src/session/session_controller.dart';
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _recoveryDir = r'C:\data\recovery';
const _crashedId = 'crashed-doc';

/// The session that CRASHED. Not [kTestSessionId], which is the session
/// under test — a survivor is by definition something a previous run of
/// the app left behind, and the whole point of slot keying is that the two
/// are different files.
const _crashedSessionId = 'sess-crashed';

final String _survivorSlot = recoverySlotFor(
  documentId: _crashedId,
  sessionId: _crashedSessionId,
);
final _snapshot = '$_recoveryDir\\$_survivorSlot.rmpj';
final _sidecar = '$_recoveryDir\\$_survivorSlot.json';

/// Where THIS session would file its own snapshot of the same document.
final String _liveSnapshot = testSnapshotPath(_crashedId);

const _realPath = r'C:\jobs\Smith.rmpj';

Uint8List _snapshotBytes({String projectName = 'Smith Residence'}) {
  final doc = buildBlankDocument(
    now: DateTime.utc(2026),
    appVersion: '0.1.0',
    id: const Uuid(_crashedId),
    rackId: const Uuid('crashed-rack'),
    catalog: const {},
  );
  doc.info.projectName = projectName;
  return const JsonDocumentCodec().write(doc);
}

Uint8List _sidecarBytes({
  String? realPath = _realPath,
  int? unsavedEditCount = 12,
  String? docId,
}) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'appVersion': '0.1.0',
      'displayName': 'Smith Residence',
      'docId': docId ?? _survivorSlot,
      'owner': _crashedSessionId,
      if (realPath != null) 'realPath': realPath,
      'savedAt': '2026-07-26T14:32:11.004112Z',
      'schemaVersion': kSchemaVersion,
      'sequence': 412,
      if (unsavedEditCount != null) 'unsavedEditCount': unsavedEditCount,
    }),
  ),
);

FakeFileStore _crashedDisk({
  Map<String, Uint8List>? extraFiles,
  bool withSidecar = true,
  bool withSnapshot = true,
  bool realFileExists = true,
}) => FakeFileStore(
  initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
  initialFiles: {
    if (withSnapshot) _snapshot: _snapshotBytes(),
    if (withSidecar) _sidecar: _sidecarBytes(),
    if (realFileExists) _realPath: _snapshotBytes(projectName: 'On Disk'),
    ...?extraFiles,
  },
);

Future<TestSession> _session({
  FakeFileStore? fs,
  ScriptedPrompts? prompts,
  List<String?> savePaths = const [],
  Duration pathProbeTimeout = kSessionPathProbeTimeout,
}) => buildTestSession(
  pathProbeTimeout: pathProbeTimeout,
  document: buildBlankDocument(
    now: DateTime.utc(2026),
    appVersion: '0.1.0',
    id: const Uuid('fresh-doc'),
    rackId: const Uuid('fresh-rack'),
    catalog: const {},
  ),
  fs: fs ?? _crashedDisk(),
  prompts: prompts,
  savePaths: savePaths,
);

void main() {
  group('the scan', () {
    test('offers a complete pair with the sidecar\u2019s own facts', () async {
      final t = await _session(
        prompts: ScriptedPrompts(
          recoveryChoices: [RecoveryChoice.keepForLater],
        ),
      );

      await t.services.controller.runStartupRecovery();

      final prompt = t.prompts.recoveries.single;
      expect(prompt.name, 'Smith Residence');
      // The count comes from the sidecar because after a crash there is
      // no undo stack left to consult.
      expect(prompt.count, 12);
      expect(prompt.savedAt, DateTime.utc(2026, 7, 26, 14, 32, 11, 4, 112));
    });

    test(
      'a snapshot with NO sidecar is deleted silently, never offered',
      () async {
        // It is our file, in our directory, and by construction either
        // incomplete or unattributable.
        final fs = _crashedDisk(withSidecar: false);
        final t = await _session(fs: fs);

        await t.services.controller.runStartupRecovery();

        expect(t.prompts.recoveries, isEmpty);
        expect(fs.state.files.containsKey(_snapshot), isFalse);
      },
    );

    test('a sidecar with NO snapshot is deleted silently too', () async {
      final fs = _crashedDisk(withSnapshot: false);
      final t = await _session(fs: fs);

      await t.services.controller.runStartupRecovery();

      expect(t.prompts.recoveries, isEmpty);
      expect(fs.state.files.containsKey(_sidecar), isFalse);
    });

    test('an empty recovery directory prompts nothing', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
      final t = await _session(fs: fs);
      expect(await t.services.controller.runStartupRecovery(), isFalse);
      expect(t.prompts.recoveries, isEmpty);
    });
  });

  group('interrupted snapshot writes', () {
    test('a crashed session’s .tmp files do not accumulate forever', () async {
      // Nothing in the app swept these. `AtomicWriter` removes only the
      // temps of the write it is performing, and once a pair is keyed on
      // `<docId>~<sessionId>` a dead session's paths are never written
      // again — so one partial document of up to ~600 KB was left behind
      // per crash-during-snapshot-write, growing without bound inside the
      // data root, which in portable mode is the user's USB stick.
      const stray = r'C:\data\recovery\dead-doc~sess-dead.rmpj.tmp';
      const straySidecar = r'C:\data\recovery\dead-doc~sess-dead.json.tmp';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {
          stray: _snapshotBytes(),
          straySidecar: _sidecarBytes(),
        },
      );
      final t = await _session(fs: fs);

      expect(await t.services.controller.runStartupRecovery(), isFalse);

      expect(fs.state.files.containsKey(stray), isFalse);
      expect(fs.state.files.containsKey(straySidecar), isFalse);
    });
  });

  group('Recover', () {
    test('loads the snapshot, binds it to the real path, and marks it '
        'DIRTY', () async {
      final fs = _crashedDisk();
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
      );

      expect(await t.services.controller.runStartupRecovery(), isTrue);

      expect(t.services.session.displayName, 'Smith Residence');
      expect(t.services.session.filePath, _realPath);
      // Dirty, so the user MUST explicitly save. The snapshot has not
      // been written to their file and must not read as though it had.
      expect(t.services.session.isDirty, isTrue);
      expect(t.services.session.status, contains('Recovered from'));
      expect(t.services.session.status, contains('Smith.rmpj'));
    });

    test('the snapshot SURVIVES the recovery and dies only at the next '
        'successful save', () async {
      final fs = _crashedDisk();
      final t = await _session(
        fs: fs,
        savePaths: [_realPath],
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
      );
      await t.services.controller.runStartupRecovery();

      // A crash between recovering and saving must cost nothing at all.
      expect(fs.state.files.containsKey(_snapshot), isTrue);
      expect(fs.state.files.containsKey(_sidecar), isTrue);

      expect(await t.services.controller.save(), isTrue);

      expect(fs.state.files.containsKey(_snapshot), isFalse);
      expect(fs.state.files.containsKey(_sidecar), isFalse);
    });

    test(
      'a snapshot that CANNOT BE READ says so, and keeps the pair',
      () async {
        // The one branch of the recovery flow that reported nothing. The
        // user presses "Recover" — the moment they are most anxious about
        // their work — and the app returned false with a log line: no
        // dialog, no explanation, back to the start card. Its two siblings
        // in the same file both raise something.
        final fs = _crashedDisk();
        final t = await _session(
          fs: fs,
          prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
        );
        // The scan runs first and reads the sidecar; the throw has to land
        // on the snapshot read that `_acceptRecovery` does. Deleting the
        // snapshot between scan and read is the real-world shape of this —
        // an AV scanner, a permissions change, a stick pulled.
        t.prompts.onBeforeRecoveryAnswer = () => fs.delete(_snapshot);

        expect(await t.services.controller.runStartupRecovery(), isFalse);

        expect(t.prompts.errors, hasLength(1));
        expect(t.prompts.errors.single.title, contains('could not be read'));
        expect(
          t.prompts.errors.single.detail,
          contains('Nothing has been deleted'),
        );
        // The document on screen is untouched: a failed recovery is not an
        // opened one.
        expect(t.services.session.documentId, 'fresh-doc');
      },
    );

    test('a stat that does not answer records UNKNOWN, so the next save is '
        'not refused', () async {
      // `reachable` was just confirmed true by `_existsQuietly`, so a
      // stat that then throws means "cannot tell", not "there is no
      // file". `FileBaseline.of(null)` yields `absent`, which fails the
      // next save's external-change check and accuses a sync client of a
      // modification that never happened — at the end of a recovery, of
      // all moments.
      final faults = <int, Object>{};
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {
          _snapshot: _snapshotBytes(),
          _sidecar: _sidecarBytes(),
          _realPath: _snapshotBytes(projectName: 'On Disk'),
        },
        faults: faults,
      );
      final prompts = ScriptedPrompts(
        recoveryChoices: [RecoveryChoice.recover],
      );
      final t = await _session(fs: fs, prompts: prompts);
      // After the answer, `_acceptRecovery` runs readBytes, exists, then
      // exactly one stat.
      prompts.onBeforeRecoveryAnswer = () async {
        faults[fs.operationCount + 2] = const StorageOsException(
          1231,
          'the share blinked',
        );
      };

      expect(await t.services.controller.runStartupRecovery(), isTrue);
      // THE PREMISE: the path was still judged reachable (that is the
      // `exists` at +1), and it is the STAT at +2 that did not answer.
      expect(t.services.session.filePath, _realPath);

      expect(await t.services.controller.save(), isTrue);
      expect(
        t.prompts.errors.where((e) => e.title.contains('changed on disk')),
        isEmpty,
      );
    });

    test('an unreachable realPath is BOUNDED, not waited on', () async {
      // `realPath` is an absolute path out of a sidecar, and this runs
      // inside startup. A stick whose last session had a job open on
      // \\officenas\jobs\… , carried to a machine without that share, made
      // startup wait on it — `exists` on a dead UNC path was measured at
      // 1261 ms and `DartIoFileStore.exists` probes File then Directory.
      const onDeadShare = r'\\officenas\jobs\Smith.rmpj';
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {
          _snapshot: _snapshotBytes(),
          _sidecar: _sidecarBytes(realPath: onDeadShare),
        },
        // Its `exists` future NEVER completes.
        hangingPaths: {onDeadShare},
      );
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
        pathProbeTimeout: const Duration(milliseconds: 1),
      );

      expect(await t.services.controller.runStartupRecovery(), isTrue);

      // The work is never held hostage to a path that will not answer:
      // it opens untitled and Ctrl+S routes to Save As.
      expect(t.services.session.filePath, isNull);
      expect(t.services.session.requiresSaveAs, isTrue);
      expect(t.services.session.isDirty, isTrue);
    });

    test('a real path that is GONE opens the work untitled rather than '
        'holding it hostage', () async {
      final fs = _crashedDisk(realFileExists: false);
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
      );

      await t.services.controller.runStartupRecovery();

      expect(t.services.session.filePath, isNull);
      expect(t.services.session.requiresSaveAs, isTrue);
      expect(t.services.session.isDirty, isTrue);
      expect(t.services.session.status, contains('never been saved'));
    });
  });

  group('this session’s own pair', () {
    // THE OTHER HALF OF THE SLOT INVARIANT. The tests above prove that
    // nothing this session does can reach ANOTHER session's pair; these
    // prove it can still reach its OWN. Without them, "delete the slot"
    // and "write the slot" mask each other's mutations — revert either one
    // alone and the survivor is still safe, for the wrong reason, while
    // this session's snapshot is orphaned on disk forever and is offered
    // as a phantom survivor at every future launch.
    test('is deleted by a clean shutdown', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      final t = await _session(fs: fs);
      expect(await t.services.controller.openPath(_realPath), isTrue);
      final rack = t.services.session.document.racks.values.first;
      t.services.session.controller.run(
        SetRackHeightCommand(
          id: rack.id,
          fromHeightU: rack.heightU,
          toHeightU: rack.heightU + 1,
          now: DateTime.utc(2026),
          actor: 'test',
        ),
      );
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
      expect(fs.state.files.containsKey(_liveSnapshot), isTrue);

      await t.services.controller.cleanShutdown();

      expect(fs.state.files.containsKey(_liveSnapshot), isFalse);
      expect(fs.state.files.containsKey(testSidecarPath(_crashedId)), isFalse);
    });

    test('is deleted by a successful save, with no shutdown '
        'involved', () async {
      // §9.3 step 7. It used to happen inside `DocumentStore.save`, which
      // names the bare document id; the live pair is at a slot, so the
      // sweep moved up to the layer that knows which session this is. No
      // `cleanShutdown` here on purpose — that would delete the same pair
      // for a different reason and hide a missing step 7.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      final t = await _session(fs: fs);
      await t.services.controller.openPath(_realPath);
      final rack = t.services.session.document.racks.values.first;
      t.services.session.controller.run(
        SetRackHeightCommand(
          id: rack.id,
          fromHeightU: rack.heightU,
          toHeightU: rack.heightU + 1,
          now: DateTime.utc(2026),
          actor: 'test',
        ),
      );
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

      expect(await t.services.controller.save(), isTrue);

      expect(fs.state.files.containsKey(_liveSnapshot), isFalse);
      expect(fs.state.files.containsKey(testSidecarPath(_crashedId)), isFalse);
    });

    test('and the recovery directory is left with nothing in it', () async {
      // Stated as "no file mentions this document at all", so an orphan
      // under ANY stem fails — including the bare document id a reverted
      // write would produce.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      final t = await _session(fs: fs);
      await t.services.controller.openPath(_realPath);
      final rack = t.services.session.document.racks.values.first;
      t.services.session.controller.run(
        SetRackHeightCommand(
          id: rack.id,
          fromHeightU: rack.heightU,
          toHeightU: rack.heightU + 1,
          now: DateTime.utc(2026),
          actor: 'test',
        ),
      );
      await t.services.autosave.snapshot();

      await t.services.controller.cleanShutdown();

      expect(
        fs.state.files.keys.where((k) => k.startsWith(_recoveryDir)),
        isEmpty,
      );
    });
  });

  group('Discard', () {
    test('deletes both files', () async {
      final fs = _crashedDisk();
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.discard]),
      );

      expect(await t.services.controller.runStartupRecovery(), isFalse);

      expect(fs.state.files.containsKey(_snapshot), isFalse);
      expect(fs.state.files.containsKey(_sidecar), isFalse);
      // The document on screen is untouched: discarding a snapshot is not
      // opening one.
      expect(t.services.session.documentId, 'fresh-doc');
    });
  });

  // ======================================================================
  // A SECOND INSTANCE MUST NOT OFFER — OR DISCARD — A RUNNING INSTANCE'S
  // SAFETY NET
  // ======================================================================
  // The whole flow, not just the store. Instance B is running with unsaved
  // work behind a live snapshot. Instance C launches. Its startup scan
  // used to claim B's pair and offer it, so the user met "Recover Smith
  // Residence (12 unsaved changes)?" for a document that was open and
  // being edited in another window right now — and answering "Discard",
  // which is exactly what a user who knows that window is open would
  // answer, deleted B's only copy of twenty minutes of work.
  group('a concurrently RUNNING instance', () {
    const liveSession = 'sess-live';
    final liveSlot = recoverySlotFor(
      documentId: _crashedId,
      sessionId: liveSession,
    );
    final liveSnapshot = '$_recoveryDir\\$liveSlot.rmpj';
    final liveSidecar = '$_recoveryDir\\$liveSlot.json';

    /// Instance B: open Smith.rmpj, make unsaved changes, autosave —
    /// and KEEP RUNNING. No `cleanShutdown`, and no `releaseAllLeases`,
    /// because this process has not died.
    Future<TestSession> runningWithUnsavedWork(FakeFileStore fs) async {
      final b = await buildTestSession(
        fs: fs,
        recoverySessionId: liveSession,
        document: buildBlankDocument(
          now: DateTime.utc(2026),
          appVersion: '0.1.0',
          id: const Uuid('start-doc'),
          rackId: const Uuid('start-rack'),
          catalog: const {},
        ),
      );
      expect(await b.services.controller.openPath(_realPath), isTrue);
      final rack = b.services.session.document.racks.values.first;
      b.services.session.controller.run(
        SetRackHeightCommand(
          id: rack.id,
          fromHeightU: rack.heightU,
          toHeightU: rack.heightU + 3,
          now: DateTime.utc(2026),
          actor: 'test',
        ),
      );
      expect(await b.services.autosave.snapshot(), AutosaveOutcome.written);
      expect(fs.state.files.containsKey(liveSnapshot), isTrue);
      return b;
    }

    test('is not offered as a crash survivor', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      await runningWithUnsavedWork(fs);

      final c = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.discard]),
      );
      expect(await c.services.controller.runStartupRecovery(), isFalse);

      expect(
        c.prompts.recoveries,
        isEmpty,
        reason:
            'RackMate must not describe a document that is open and being '
            'edited in another live window as a crash survivor',
      );
    });

    test('...so Discard at that prompt cannot delete its snapshot', () async {
      // The loss itself, verbatim: the prompt never appears, so the
      // scripted "Discard" is never reached and B's pair is still on disk
      // with B's own owner stamp on it.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      await runningWithUnsavedWork(fs);

      final c = await _session(
        fs: fs,
        prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.discard]),
      );
      await c.services.controller.runStartupRecovery();

      expect(fs.state.files.containsKey(liveSnapshot), isTrue);
      expect(fs.state.files.containsKey(liveSidecar), isTrue);
      final owner =
          (jsonDecode(utf8.decode(await fs.readBytes(liveSidecar)))
              as Map<String, Object?>)['owner'];
      expect(
        owner,
        liveSession,
        reason:
            'the pair must not have been CLAIMED either — a claim is what '
            'made "Discard" able to reach it in the first place',
      );
    });

    test('...and the running instance can still retire its own pair on a '
        'clean save and quit', () async {
      // The MEDIUM this used to cause on the way past: once C had
      // rewritten the owner, B's step-7 save and its clean shutdown both
      // declined on the mismatch, so a LATER ordinary launch offered a
      // recovery prompt for work that had been written to disk correctly.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {_realPath: _snapshotBytes()},
      );
      final b = await runningWithUnsavedWork(fs);

      final c = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          recoveryChoices: [RecoveryChoice.keepForLater],
        ),
      );
      await c.services.controller.runStartupRecovery();

      expect(await b.services.controller.save(), isTrue);
      await b.services.controller.cleanShutdown();

      expect(
        fs.state.files.keys.where((k) => k.contains(r'\recovery\')),
        isEmpty,
        reason:
            'B saved perfectly and quit cleanly; nothing may be left to '
            'prompt a later launch about',
      );

      // And a third, ordinary launch really is offered nothing.
      fs.releaseAllLeases();
      final d = await _session(fs: fs);
      expect(await d.services.controller.runStartupRecovery(), isFalse);
      expect(d.prompts.recoveries, isEmpty);
    });
  });

  group('Keep for later', () {
    test('leaves BOTH files exactly where they are', () async {
      final fs = _crashedDisk();
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          recoveryChoices: [RecoveryChoice.keepForLater],
        ),
      );

      expect(await t.services.controller.runStartupRecovery(), isFalse);

      // It WILL be offered again next launch. That is intentional: the
      // data is still at risk and silently forgetting it is worse than
      // one more prompt.
      expect(fs.state.files.containsKey(_snapshot), isTrue);
      expect(fs.state.files.containsKey(_sidecar), isTrue);
    });

    test('and it really is offered again on the next scan', () async {
      final fs = _crashedDisk();
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          recoveryChoices: [
            RecoveryChoice.keepForLater,
            RecoveryChoice.keepForLater,
          ],
        ),
      );

      await t.services.controller.runStartupRecovery();
      await t.services.controller.runStartupRecovery();

      expect(t.prompts.recoveries, hasLength(2));
    });

    // ==================================================================
    // "LATER" HAS TO SURVIVE THE USER GOING AND LOOKING AT THE FILE
    // ==================================================================
    // Three CONFIRMED losses, one cause: a recovery pair used to be keyed
    // on the document id alone, so the survivor and the document the user
    // then opens were THE SAME FILE — and every route that named the
    // document named the survivor too.
    //
    // THE SURVIVOR HERE IS WRITTEN BY THE PRODUCTION CODE, NOT SEEDED.
    // A hand-written fixture would have had to name the stem, which is
    // exactly the thing under test: pick the new spelling and the test
    // passes against the OLD code, because the seeded pair sits somewhere
    // the old code never wrote. So session one really runs, really
    // autosaves, and really dies; session two is a second `AppServices`
    // over the SAME FakeFileStore, which is what a relaunch is.
    group('and it survives the user opening that same document', () {
      const crashedSession = 'sess-one';
      const liveSession = 'sess-two';

      /// What session one had unsaved when it died. Captured rather than
      /// hardcoded: consecutive height changes to one rack COALESCE in the
      /// undo stack, so twelve commands are one edit. The number does not
      /// matter here — that the survivor still reports SESSION ONE's
      /// number does.
      int? crashedEditCount;

      /// Session one: open Smith.rmpj, work on it, autosave, then die
      /// without a clean shutdown. Returns the disk it left behind.
      Future<FakeFileStore> crashDuringWork() async {
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
          initialFiles: {_realPath: _snapshotBytes()},
        );
        final one = await buildTestSession(
          fs: fs,
          recoverySessionId: crashedSession,
          document: buildBlankDocument(
            now: DateTime.utc(2026),
            appVersion: '0.1.0',
            id: const Uuid('start-doc'),
            rackId: const Uuid('start-rack'),
            catalog: const {},
          ),
        );
        expect(await one.services.controller.openPath(_realPath), isTrue);
        for (var i = 0; i < 12; i++) {
          final rack = one.services.session.document.racks.values.first;
          one.services.session.controller.run(
            SetRackHeightCommand(
              id: rack.id,
              fromHeightU: rack.heightU,
              toHeightU: rack.heightU + 1,
              now: DateTime.utc(2026),
              actor: 'test',
            ),
          );
        }
        crashedEditCount = one.services.session.editsSinceSave;
        expect(crashedEditCount, isNotNull);
        expect(await one.services.autosave.snapshot(), AutosaveOutcome.written);
        // NO cleanShutdown. That is the crash — and the OS half of it is
        // that every lease session one held is dropped, while the lease
        // FILE it created stays on disk. Without this the fake would be
        // modelling a first instance that is STILL RUNNING, which the
        // relaunch is now required to leave completely alone.
        fs.releaseAllLeases();
        return fs;
      }

      /// The pair session one left, as session two must still find it.
      final survivor = testSnapshotPath(_crashedId, sessionId: crashedSession);
      final survivorSidecar = testSidecarPath(
        _crashedId,
        sessionId: crashedSession,
      );

      Future<TestSession> relaunchAndKeepForLater(FakeFileStore fs) async {
        final two = await buildTestSession(
          fs: fs,
          recoverySessionId: liveSession,
          document: buildBlankDocument(
            now: DateTime.utc(2026),
            appVersion: '0.1.0',
            id: const Uuid('fresh-doc'),
            rackId: const Uuid('fresh-rack'),
            catalog: const {},
          ),
          prompts: ScriptedPrompts(
            recoveryChoices: [RecoveryChoice.keepForLater],
          ),
        );
        expect(await two.services.controller.runStartupRecovery(), isFalse);
        expect(two.prompts.recoveries.single.count, crashedEditCount);
        return two;
      }

      void expectStillOffered(FakeFileStore fs) {
        expect(
          fs.state.files.containsKey(survivor),
          isTrue,
          reason:
              'twelve unsaved changes the user was explicitly told were '
              'kept for later',
        );
        expect(fs.state.files.containsKey(survivorSidecar), isTrue);
      }

      test('QUIT: cleanShutdown must not delete it', () async {
        final fs = await crashDuringWork();
        final two = await relaunchAndKeepForLater(fs);

        // The user opens Smith.rmpj to look at it. It carries the
        // SAME document id as the survivor, because it is the same
        // project — that is the entire trap.
        expect(await two.services.controller.openPath(_realPath), isTrue);
        expect(two.services.session.documentId, _crashedId);

        // Not dirty, so this closes with no prompt at all: no dialog, no
        // decision, nothing the user could have said no to.
        await two.chrome.requestClose();
        expect(two.chrome.destroyCalls, 1);

        expectStillOffered(fs);
      });

      test('EDIT + AUTOSAVE: this session’s snapshot must not land on '
          'top of it', () async {
        final fs = await crashDuringWork();
        final two = await relaunchAndKeepForLater(fs);
        final survivorBytes = await fs.readBytes(survivor);

        await two.services.controller.openPath(_realPath);
        final rack = two.services.session.document.racks.values.first;
        two.services.session.controller.run(
          SetRackHeightCommand(
            id: rack.id,
            fromHeightU: rack.heightU,
            toHeightU: rack.heightU - 1,
            now: DateTime.utc(2026),
            actor: 'test',
          ),
        );

        expect(await two.services.autosave.snapshot(), AutosaveOutcome.written);

        expect(
          await fs.readBytes(survivor),
          survivorBytes,
          reason:
              'the crashed session’s unsaved work, overwritten by the '
              'freshly-loaded SAVED version — by the very mechanism that '
              'exists to protect it',
        );
        // And this session's own snapshot really was written, somewhere
        // else. Without this the test would also pass if autosave had
        // simply stopped working.
        final live = testSnapshotPath(_crashedId, sessionId: liveSession);
        expect(fs.state.files.containsKey(live), isTrue);
        expect(live, isNot(survivor));
      });

      test('SAVE: the step-7 sweep must not reach it either', () async {
        final fs = await crashDuringWork();
        final two = await relaunchAndKeepForLater(fs);

        await two.services.controller.openPath(_realPath);
        final rack = two.services.session.document.racks.values.first;
        two.services.session.controller.run(
          SetRackHeightCommand(
            id: rack.id,
            fromHeightU: rack.heightU,
            toHeightU: rack.heightU - 1,
            now: DateTime.utc(2026),
            actor: 'test',
          ),
        );

        expect(await two.services.controller.save(), isTrue);

        expectStillOffered(fs);
      });

      test('and a THIRD launch still offers it, with its own edit '
          'count', () async {
        // The end-to-end promise, asserted at the surface the user meets:
        // not "a file is still on disk" but "the prompt comes back".
        final fs = await crashDuringWork();
        final two = await relaunchAndKeepForLater(fs);
        await two.services.controller.openPath(_realPath);
        await two.services.controller.cleanShutdown();

        final three = await buildTestSession(
          fs: fs,
          recoverySessionId: 'sess-three',
          prompts: ScriptedPrompts(
            recoveryChoices: [RecoveryChoice.keepForLater],
          ),
        );
        await three.services.controller.runStartupRecovery();

        expect(three.prompts.recoveries.single.count, crashedEditCount);
        expect(three.prompts.recoveries.single.name, 'Smith Residence');
      });
    });
  });

  group('multiple survivors', () {
    test('are offered one at a time, NEWEST FIRST', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {
          _snapshot: _snapshotBytes(),
          _sidecar: _sidecarBytes(),
          r'C:\data\recovery\older-doc.rmpj': _snapshotBytes(),
          r'C:\data\recovery\older-doc.json': Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'appVersion': '0.1.0',
                'displayName': 'Older Job',
                'docId': 'older-doc',
                'savedAt': '2026-07-25T09:00:00.000Z',
                'schemaVersion': kSchemaVersion,
                'sequence': 1,
              }),
            ),
          ),
        },
      );
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          recoveryChoices: [
            RecoveryChoice.keepForLater,
            RecoveryChoice.keepForLater,
          ],
        ),
      );

      await t.services.controller.runStartupRecovery();

      // Two consecutive crashes with different documents leave two pairs,
      // even though v1 is single-document.
      expect(
        t.prompts.recoveries.map((r) => r.name).toList(),
        ['Smith Residence', 'Older Job'],
      );
    });

    test(
      'Recover stops at the chosen one and leaves the rest on disk',
      () async {
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
          initialFiles: {
            _snapshot: _snapshotBytes(),
            _sidecar: _sidecarBytes(realPath: null),
            r'C:\data\recovery\older-doc.rmpj': _snapshotBytes(),
            r'C:\data\recovery\older-doc.json': Uint8List.fromList(
              utf8.encode(
                jsonEncode({
                  'appVersion': '0.1.0',
                  'displayName': 'Older Job',
                  'docId': 'older-doc',
                  'savedAt': '2026-07-25T09:00:00.000Z',
                  'schemaVersion': kSchemaVersion,
                  'sequence': 1,
                }),
              ),
            ),
          },
        );
        final t = await _session(
          fs: fs,
          prompts: ScriptedPrompts(recoveryChoices: [RecoveryChoice.recover]),
        );

        expect(await t.services.controller.runStartupRecovery(), isTrue);

        expect(t.prompts.recoveries, hasLength(1));
        expect(
          fs.state.files.containsKey(r'C:\data\recovery\older-doc.rmpj'),
          isTrue,
        );
      },
    );
  });

  group('G4', () {
    test('a sidecar with no edit count produces a prompt with none', () async {
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, _recoveryDir, 'C:'},
        initialFiles: {
          _snapshot: _snapshotBytes(),
          _sidecar: _sidecarBytes(unsavedEditCount: null),
        },
      );
      final t = await _session(
        fs: fs,
        prompts: ScriptedPrompts(
          recoveryChoices: [RecoveryChoice.keepForLater],
        ),
      );

      await t.services.controller.runStartupRecovery();

      expect(t.prompts.recoveries.single.count, isNull);
    });
  });
}
