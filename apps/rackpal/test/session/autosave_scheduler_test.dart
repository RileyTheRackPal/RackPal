// The 30 s timer, the blur trigger, and the rule that outranks both.
//
// NOTHING HERE SLEEPS. The periodic timer is manual and the clock is
// manual, so "30 s elapsed" is a function call and "less than 2 s have
// passed" is a fact rather than a race.
//
// TWO THINGS THIS FILE USED TO ASSERT ONLY IN ITS TITLES:
//
//  * THE SNAPSHOT'S CONTENT. Every test here checked
//    `fs.state.files.containsKey(_snapshot)` and stopped. Replacing
//    `documentBytes: snapshot.bytes` with `Uint8List(snapshot.bytes.length)`
//    wrote 600 KB of zeros under a perfectly correct sidecar and the whole
//    suite stayed green: the prompt still offered the recovery, and
//    pressing Recover failed to decode. The group at the end of this file
//    decodes what was written back into a document.
//  * THE 30 SECONDS. `expect(timer.duration, kAutosaveInterval)` compared
//    the production constant to itself, so `Duration(minutes: 30)` passed
//    every test in this suite while the guaranteed loss window grew
//    sixtyfold. The numbers are pinned to literals now.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/app_services.dart';
import 'package:rackpal/src/session/autosave_scheduler.dart';
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/storage/data_root.dart';

import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _target = r'C:\jobs\Smith.rppj';

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
  DataRoot? dataRoot,
  List<String?> savePaths = const [],
}) => buildTestSession(
  document: buildBlankDocument(
    now: DateTime.utc(2026),
    appVersion: '0.1.0',
    id: const Uuid('autosave-doc'),
    rackId: const Uuid('autosave-rack'),
    catalog: const {},
  ),
  dataRoot: dataRoot,
  savePaths: savePaths,
);

/// The snapshot and sidecar paths for the fixture document.
///
/// SLOT-KEYED, not document-keyed: `<docId>~<sessionId>`. See
/// `recoverySlotFor` — a snapshot belongs to a session's work on a
/// document, not to the document, and keying it on the document alone was
/// three separate ways to destroy a user's unsaved work.
final String _snapshot = testSnapshotPath('autosave-doc');
final String _sidecar = testSidecarPath('autosave-doc');

void main() {
  group('the rule that outranks everything else', () {
    test('THE USER\u2019S FILE IS NEVER WRITTEN BY AUTOSAVE', () async {
      final t = await _session(savePaths: [_target]);
      await t.services.controller.save();
      final saved = await t.fs.readBytes(_target);

      _edit(t.services.session.controller);
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

      // The ONLY writer of <target>.rmpj is an explicit Save or Save
      // As. Not the timer, not blur, not close, not recovery.
      expect(await t.fs.readBytes(_target), saved);
      expect(t.fs.state.files.containsKey(_snapshot), isTrue);
    });
  });

  group('triggers', () {
    test('the periodic timer writes a snapshot when dirty', () async {
      final t = await _session();
      _edit(t.services.session.controller);

      // The shell starts the timer; `buildTestSession` does not mount the
      // shell, so it is started explicitly here.
      t.services.autosave.start();
      // AGAINST THE LITERAL, not against `kAutosaveInterval`. Comparing
      // the timer's duration to the very constant that configured it is
      // an assertion that cannot fail; §9.4's number is pinned in "the
      // numbers §9.4 specifies" below and repeated here so that this test
      // notices a scheduler that installs some OTHER duration too.
      expect(t.periodicTimers.pending.single.duration, kAutosaveInterval);
      expect(
        t.periodicTimers.pending.single.duration,
        const Duration(
          seconds: 30,
        ),
      );

      t.periodicTimers.tick();
      expect(await t.services.autosave.pending, AutosaveOutcome.written);

      expect(t.fs.state.files.containsKey(_snapshot), isTrue);
    });

    test('a clean document writes nothing', () async {
      final t = await _session();
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.notDirty);
      expect(t.fs.state.files.containsKey(_snapshot), isFalse);
    });

    test('window blur is the second trigger', () async {
      final t = await _session();
      _edit(t.services.session.controller);

      t.chrome.blur();
      expect(await t.services.autosave.pending, AutosaveOutcome.written);

      expect(t.services.autosave.snapshotCount, 1);
    });
  });

  group('the numbers §9.4 specifies', () {
    // PINNED TO LITERALS, the way `kMinWindowWidth` and
    // `kPortableMarkerFileName` already are elsewhere in this suite. Every
    // trigger in this file is a manual `tick()` or a direct `snapshot()`
    // call, so no test here would notice the interval changing — the loss
    // window is not observable from a suite whose clock never runs.
    test('the timer interval is THIRTY SECONDS — the guaranteed loss '
        'window', () {
      expect(
        kAutosaveInterval,
        const Duration(seconds: 30),
        reason:
            '§9.4 says every 30 s. This is the maximum amount of work a '
            'crash can take, and it is the whole promise of the feature.',
      );
    });

    test('there is NO time-based debounce constant to get wrong', () {
      // This used to assert `kAutosaveDebounce == 2 s`, pinning a value
      // whose entire job was to expire — and expiring is what let an idle
      // dirty document rewrite itself every 30 s. Suppression now keys on
      // the state id alone, so there is no duration to tune, and the
      // group above proves the behaviour directly rather than by pinning
      // a number that stands in for it.
      expect(kAutosaveInterval, const Duration(seconds: 30));
    });
  });

  group('the debounce', () {
    test(
      'a second snapshot at the SAME stateId within 2 s is skipped',
      () async {
        final t = await _session();
        _edit(t.services.session.controller);

        expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
        // Blur and the timer coincide constantly; alt-tabbing must not
        // thrash a ~600 KB write.
        expect(await t.services.autosave.snapshot(), AutosaveOutcome.debounced);
        expect(t.services.autosave.snapshotCount, 1);
      },
    );

    test('...but a NEW edit is written even inside the window', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      _edit(t.services.session.controller);

      // The debounce keys on the state id as well as the clock: new work
      // is new work however recently the last snapshot ran.
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
    });

    test(
      '...and an IDLE dirty document never re-writes the same bytes, '
      'however long it sits (§10.12b)',
      () async {
        final t = await _session();
        _edit(t.services.session.controller);
        expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

        // THE REGRESSION THIS GUARDS. This test used to assert the
        // OPPOSITE — "the same state is written again once 2 s have
        // passed" — because suppression carried an elapsed-time clause
        // that expired while the reason for it did not. The dirty check
        // cannot catch this: a recovery snapshot is not a save, so the
        // document stays dirty against disk forever. The user edits, goes
        // to lunch, and the 30 s timer rewrites an identical ~600 KB
        // snapshot every tick for an hour.
        for (var tick = 0; tick < 120; tick++) {
          t.clock.advance(kAutosaveInterval);
          expect(
            await t.services.autosave.snapshot(),
            AutosaveOutcome.debounced,
            reason: 'tick $tick rewrote an unchanged document',
          );
        }
        expect(t.services.autosave.snapshotCount, 1);

        // ...and real work still lands immediately, so the suppression
        // has not simply been turned into a mute.
        _edit(t.services.session.controller);
        expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
        expect(t.services.autosave.snapshotCount, 2);
      },
    );

    test('force bypasses the debounce but NOT the dirty check', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      expect(
        await t.services.autosave.snapshot(force: true),
        AutosaveOutcome.written,
      );

      t.services.session.controller.undoLast();
      expect(t.services.session.isDirty, isFalse);
      expect(
        await t.services.autosave.snapshot(force: true),
        AutosaveOutcome.notDirty,
      );
    });
  });

  group('the sidecar', () {
    test('carries the six fields the prompt and a future build need', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      final raw =
          jsonDecode(utf8.decode(await t.fs.readBytes(_sidecar)))
              as Map<String, Object?>;

      expect(raw['docId'], testSlot('autosave-doc'));
      expect(raw['displayName'], 'Untitled');
      // The REQUIRED "(12 unsaved changes)" cannot be rendered from
      // §9.4's four specified fields — after a crash there is no undo
      // stack left to consult.
      expect(raw['unsavedEditCount'], 1);
      // THE BUILD'S VERSION, NOT THE DOCUMENT'S — and the difference is
      // the point of the field. `buildBlankDocument` above is given
      // '0.1.0' deliberately, so a literal here that happened to match it
      // would pass while asserting the wrong thing. A recovery sidecar
      // records WHICH BUILD WROTE IT, because that is what a future
      // version needs in order to know how to read it.
      //
      // Read from `kAppVersion` rather than transcribed, for the reason
      // `version_parity_test.dart` exists: this literal was '0.1.0' and
      // broke on the first release bump, which is a test failing over a
      // fact that had not changed.
      expect(raw['appVersion'], kAppVersion);
      expect(raw['schemaVersion'], kSchemaVersion);
      expect(raw['savedAt'], t.clock.nowUtc().toIso8601String());
      // Never saved, so no realPath — which is what makes a recovered
      // copy open untitled with Ctrl+S routed to Save As.
      expect(raw.containsKey('realPath'), isFalse);
    });

    test('records the real path once the document has one', () async {
      final t = await _session(savePaths: [_target]);
      await t.services.controller.save();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      final raw =
          jsonDecode(utf8.decode(await t.fs.readBytes(_sidecar)))
              as Map<String, Object?>;
      expect(raw['realPath'], _target);
      expect(raw['displayName'], 'Smith');
    });

    test('the SNAPSHOT is complete before the sidecar exists', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      // "A sidecar exists" IMPLIES "its snapshot is complete". The
      // journal ordering is what makes that a fact rather than a hope.
      final ops = t.fs.journal.map((o) => o.toString()).toList();
      final snapshotPromoted = ops.indexWhere(
        (o) => o.contains('-> $_snapshot'),
      );
      final sidecarPromoted = ops.indexWhere(
        (o) => o.contains('-> $_sidecar'),
      );
      expect(snapshotPromoted, greaterThanOrEqualTo(0));
      expect(sidecarPromoted, greaterThan(snapshotPromoted));
    });
  });

  group('the degraded session', () {
    test('never starts a timer and never writes', () async {
      final t = await _session(
        dataRoot: const DataRootUnusable(
          attemptedPath: r'D:\RackPal\data',
          portable: true,
          cause: 'read-only',
        ),
      );
      _edit(t.services.session.controller);

      t.services.autosave.start();

      expect(t.services.autosave.isRunning, isFalse);
      expect(
        await t.services.autosave.snapshot(),
        AutosaveOutcome.disabled,
      );
      expect(t.periodicTimers.pending, isEmpty);
      // The user is told ONCE, by a persistent status-bar warning, rather
      // than every 30 seconds by a failing write.
      expect(t.services.degradedWarning.value, contains('Portable mode'));
    });

    test('documents still open and save normally', () async {
      final t = await _session(
        dataRoot: const DataRootUnusable(
          attemptedPath: r'C:\locked',
          portable: false,
          cause: 'access denied',
        ),
        savePaths: [_target],
      );
      _edit(t.services.session.controller);

      expect(await t.services.controller.save(), isTrue);
      expect(t.fs.state.files.containsKey(_target), isTrue);
    });
  });

  // ====================================================================
  // A SAFETY NET THAT STOPS WORKING MUST SAY SO
  // ====================================================================
  // `session.recoveryEnabled` is fixed at startup from whether the data
  // root was writable, and `disableRecovery()` has no caller. So when the
  // root became unwritable AFTER launch — the volume fills, the portable
  // stick's write-protect switch is flipped, an admin policy revokes
  // write access, the folder is deleted — every snapshot took the
  // `AutosaveOutcome.failed` branch and NOTHING anywhere looked at it:
  // the timer callback dropped the result, `guardDiscard`'s forced
  // pre-dialog snapshot dropped it too, and `logStorageEvent` went to a
  // null sink because `setStorageLogSink` has no production call site.
  // The user worked for hours believing the 30 s snapshot was protecting
  // them, the machine crashed, and there was no survivor to offer.
  group('a mid-session failure', () {
    /// Makes the next snapshot fail the way a write-protected stick does:
    /// the target exists and refuses writes.
    Future<Set<String>> lockTheSnapshot(FakeFileStore fs) async {
      final readOnly = <String>{_snapshot};
      await fs.createDirectory(kTestRecoveryDir);
      await fs.writeBytes(_snapshot, Uint8List.fromList([1]));
      return readOnly;
    }

    test('raises a warning the shell can see', () async {
      final readOnly = <String>{};
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        readOnlyPaths: readOnly,
      );
      final t = await buildTestSession(
        fs: fs,
        document: buildBlankDocument(
          now: DateTime.utc(2026),
          appVersion: '0.1.0',
          id: const Uuid('autosave-doc'),
          rackId: const Uuid('autosave-rack'),
          catalog: const {},
        ),
      );
      // Healthy at startup — this is the case a startup-time check
      // cannot catch.
      expect(t.services.degradedWarning.value, isNull);
      readOnly.addAll(await lockTheSnapshot(fs));

      _edit(t.services.session.controller);
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.failed);

      expect(
        t.services.degradedWarning.value,
        contains('Autosave has stopped working'),
      );
    });

    test('and takes it back down when the folder comes back', () async {
      // A stale warning about a folder that is writable again is its own
      // kind of lie, and the one that teaches a user to ignore the banner.
      final readOnly = <String>{};
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        readOnlyPaths: readOnly,
      );
      final t = await buildTestSession(
        fs: fs,
        document: buildBlankDocument(
          now: DateTime.utc(2026),
          appVersion: '0.1.0',
          id: const Uuid('autosave-doc'),
          rackId: const Uuid('autosave-rack'),
          catalog: const {},
        ),
      );
      readOnly.addAll(await lockTheSnapshot(fs));
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();
      expect(t.services.degradedWarning.value, isNotNull);

      readOnly.clear();
      t.clock.advance(const Duration(seconds: 30));
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

      expect(t.services.degradedWarning.value, isNull);
    });

    test('does NOT overwrite the startup warning', () async {
      // A degraded session's autosave answers `disabled` and never
      // fails — but if it ever did, replacing "RackPal cannot write to
      // its data folder" with "autosave has stopped working" would be a
      // downgrade in information.
      final t = await _session(
        dataRoot: const DataRootUnusable(
          attemptedPath: r'D:\RackPal\RackPalData',
          portable: true,
          cause: 'read-only',
        ),
      );
      _edit(t.services.session.controller);

      expect(await t.services.autosave.snapshot(), AutosaveOutcome.disabled);

      expect(t.services.degradedWarning.value, contains('Portable mode'));
    });
  });

  // ====================================================================
  // THE TWO-PHASE RULE APPLIES TO THE SIDECAR, NOT JUST THE BYTES
  // ====================================================================
  group('the document cannot change under the sidecar', () {
    test('a document swapped DURING the serialize is not what the sidecar '
        'describes', () async {
      // The 30 s timer fires while document A is open and dirty; during
      // the isolate round-trip the user completes Ctrl+O and `_adopt`
      // swaps in document B. Reading `session.*` after the await filed A's
      // BYTES under B's id, B's path and B's edit count: a snapshot that
      // lies about which project it is AND clobbers whatever B had, while
      // A's unsaved work is filed under an id nothing will ever look for.
      late final TestSession t;
      var swapped = false;
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
      t = await buildTestSession(
        fs: fs,
        document: buildBlankDocument(
          now: DateTime.utc(2026),
          appVersion: '0.1.0',
          id: const Uuid('doc-a'),
          rackId: const Uuid('rack-a'),
          catalog: const {},
        ),
        serializer: (tree) async {
          // Exactly the window: the tree is captured, the bytes are not
          // back yet, and the user finishes an Open.
          if (!swapped) {
            swapped = true;
            t.services.session.adopt(
              controller: DocumentController(
                buildBlankDocument(
                  now: DateTime.utc(2026),
                  appVersion: '0.1.0',
                  id: const Uuid('doc-b'),
                  rackId: const Uuid('rack-b'),
                  catalog: const {},
                ),
              ),
              filePath: r'C:\jobs\B.rppj',
              openReadOnly: false,
              baseline: FileBaseline.absent,
            );
          }
          return inlineSerializer(tree);
        },
      );
      _edit(t.services.session.controller);

      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
      expect(swapped, isTrue, reason: 'the swap must really have happened');

      // A's bytes, under A's slot, with no realPath — A was never saved.
      final sidecar =
          jsonDecode(utf8.decode(await fs.readBytes(testSidecarPath('doc-a'))))
              as Map<String, Object?>;
      expect(sidecar['docId'], testSlot('doc-a'));
      expect(sidecar.containsKey('realPath'), isFalse);
      expect(
        fs.state.files.containsKey(testSnapshotPath('doc-b')),
        isFalse,
        reason: 'B had nothing to snapshot and must not be given A’s bytes',
      );
    });
  });

  // ====================================================================
  // SINGLE FLIGHT \u2014 TWO GUARDS, NEITHER OF WHICH WAS COVERED
  // ====================================================================
  // A group with this name held "reset forgets the previous document's
  // debounce" and "stop cancels the timer" \u2014 neither of which touches
  // single flight \u2014 and `AutosaveOutcome.busy` appeared nowhere in the
  // test tree at all. All three of these mutations survived:
  //
  //   * delete `if (_running) return AutosaveOutcome.busy;`
  //   * delete `if (!force && (isQueueBusy?.call() ?? false)) return busy;`
  //   * drop `isQueueBusy: () => queue.busy` from `buildAppServices`
  //
  // and the group name told the next reader it was covered. The cost is a
  // redundant ~600 KB serialize queued behind an explicit save the user is
  // watching \u2014 the stall the flags exist to prevent \u2014 plus `busy` and
  // `notDirty` becoming indistinguishable, which
  // `AutosaveOutcome`'s own doc comment says are different bugs.
  group('single flight', () {
    /// A session whose FIRST serialize blocks until the returned completer
    /// is completed \u2014 the isolate round-trip, held open.
    Future<({TestSession t, Completer<void> gate})>
    sessionWithHeldSerialize() async {
      final gate = Completer<void>();
      var held = false;
      final t = await buildTestSession(
        document: buildBlankDocument(
          now: DateTime.utc(2026),
          appVersion: '0.1.0',
          id: const Uuid('autosave-doc'),
          rackId: const Uuid('autosave-rack'),
          catalog: const {},
        ),
        serializer: (tree) async {
          if (!held) {
            held = true;
            await gate.future;
          }
          return inlineSerializer(tree);
        },
      );
      return (t: t, gate: gate);
    }

    test('a SECOND snapshot while one is still serializing answers busy, '
        'and does not write', () async {
      final made = await sessionWithHeldSerialize();
      final t = made.t;
      _edit(t.services.session.controller);

      // In flight: `_running` is set before the serialize is awaited.
      final first = t.services.autosave.snapshot();

      expect(
        await t.services.autosave.snapshot(),
        AutosaveOutcome.busy,
        reason:
            'without the re-entrancy guard the 30 s tick queues a second '
            'copy of the SAME bytes behind the one already in flight',
      );

      made.gate.complete();
      expect(await first, AutosaveOutcome.written);
      expect(
        t.services.autosave.snapshotCount,
        1,
        reason: 'one snapshot, not two',
      );
    });

    test('...and the reason is BUSY, not notDirty \u2014 the document really '
        'was dirty', () async {
      // The distinction `AutosaveOutcome`'s doc comment is about: "it
      // skipped because it was clean" and "it skipped because the queue
      // was busy" are different bugs when one of them is wrong.
      final made = await sessionWithHeldSerialize();
      final t = made.t;
      _edit(t.services.session.controller);

      final first = t.services.autosave.snapshot();
      expect(t.services.session.isDirty, isTrue);
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.busy);

      made.gate.complete();
      await first;
    });

    test('AN EXPLICIT SAVE IN FLIGHT SUPPRESSES THE TIMER \u2014 through the '
        'real wiring', () async {
      // `buildAppServices` passes `isQueueBusy: () => queue.busy`, and
      // that argument is the whole mechanism. The queue reached here is
      // the SAME object every explicit save enqueues on: it is read off
      // the writer the document store uses.
      final t = await _session();
      final queue = t.services.autosave.store.writer.queue;
      final gate = Completer<void>();
      final occupied = queue.add(() => gate.future);
      expect(queue.busy, isTrue, reason: 'the premise');

      _edit(t.services.session.controller);

      // The busy check is synchronous, so the answer is decided during
      // this call. Releasing the queue immediately afterwards is what
      // makes a scheduler that IGNORED the flag fail here in milliseconds
      // instead of deadlocking behind its own queue and failing by
      // timeout thirty seconds later.
      final outcome = t.services.autosave.snapshot();
      gate.complete();
      await occupied;

      expect(
        await outcome,
        AutosaveOutcome.busy,
        reason:
            'a 30 s tick must not pile a redundant ~600 KB serialize '
            'behind a save the user is watching',
      );
      expect(t.fs.state.files.containsKey(_snapshot), isFalse);
    });

    test('...but FORCE goes through anyway, because the close prompt '
        'cannot wait', () async {
      // `guardDiscard` forces a snapshot before showing the dialog. If a
      // busy queue suppressed that one too, the pre-dialog safety net
      // would be missing exactly when the user is about to answer
      // "Don't Save".
      final t = await _session();
      final queue = t.services.autosave.store.writer.queue;
      final gate = Completer<void>();
      final occupied = queue.add(() => gate.future);

      _edit(t.services.session.controller);
      final forced = t.services.autosave.snapshot(force: true);
      gate.complete();
      await occupied;

      expect(await forced, AutosaveOutcome.written);
      expect(t.fs.state.files.containsKey(_snapshot), isTrue);
    });
  });

  group('the timer\u2019s lifecycle', () {
    // These two were under "single flight" and are not about it.
    test('reset forgets the previous document\u2019s debounce', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      await t.services.controller.newDocument();
      _edit(t.services.session.controller);

      // A new document's first snapshot must not be suppressed by timing
      // that has nothing to do with it.
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);
    });

    test('stop cancels the timer', () async {
      final t = await _session();
      t.services.autosave.start();
      expect(t.services.autosave.isRunning, isTrue);

      t.services.autosave.stop();

      expect(t.services.autosave.isRunning, isFalse);
      expect(t.periodicTimers.pending, isEmpty);
    });
  });

  // ====================================================================
  // WHAT IS ACTUALLY IN THE FILE
  // ====================================================================
  // Every other test in this suite asserts `containsKey(_snapshot)`. That
  // is satisfied by a file of the right NAME containing anything at all —
  // zeros, yesterday's document, another project. The recovery feature's
  // entire job is that the bytes come back, so the bytes are what these
  // tests look at.
  group('the snapshot round-trips back to the document it protects', () {
    test('THE BYTES ON DISK DECODE INTO THE DOCUMENT THAT WAS OPEN, '
        'INCLUDING THE EDIT THAT MADE IT DIRTY', () async {
      final t = await _session();
      _edit(t.services.session.controller);
      final live = t.services.session.controller.doc;
      final editedHeight = live.racks.values.single.heightU;

      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

      final onDisk = await t.fs.readBytes(_snapshot);
      expect(onDisk, isNotEmpty);

      // 1. It is a RackPal document, and it decodes.
      final tree = await inlineDeserializer(onDisk);
      expect(
        tree,
        isA<Ok<JsonMap>>(),
        reason:
            'a snapshot that does not parse is a recovery prompt the '
            'user accepts and then watches fail',
      );
      final decoded = readFromJsonTree((tree as Ok<JsonMap>).value);
      expect(decoded, isA<Ok<RackDocument>>());
      final recovered = (decoded as Ok<RackDocument>).value;

      // 2. It is THIS document...
      expect(recovered.id, live.id);
      expect(recovered.sequence, live.sequence);
      // 3. ...at the state the sidecar claims, edit included. The rack was
      //    one U shorter than the blank document's; a stale snapshot or a
      //    zero-filled one cannot produce this number.
      expect(
        recovered.racks.values.single.heightU,
        editedHeight,
        reason:
            'the unsaved edit is the ONLY thing the snapshot exists to '
            'protect',
      );
    });

    test('...and byte-for-byte it is exactly what serializing the live '
        'document produces', () async {
      // The tightest available statement of "the snapshot is the
      // document", and it rests on CR-117: the same document serializes
      // to the same bytes.
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();

      final fresh = await t.services.autosave.store.serializeSnapshot(
        t.services.session.controller,
      );

      expect(
        await t.fs.readBytes(_snapshot),
        orderedEquals(fresh.bytes),
        reason:
            'the snapshot on disk is not this document. It could be the '
            'right length and still be zeros, or another project.',
      );
    });

    test('a SECOND autosave replaces the bytes rather than leaving the '
        'first ones behind', () async {
      // The stale-snapshot shape: the sidecar refreshes, the 600 KB does
      // not, and the user recovers work from two edits ago.
      final t = await _session();
      _edit(t.services.session.controller);
      await t.services.autosave.snapshot();
      final first = await t.fs.readBytes(_snapshot);

      _edit(t.services.session.controller);
      expect(await t.services.autosave.snapshot(), AutosaveOutcome.written);

      final second = await t.fs.readBytes(_snapshot);
      expect(second, isNot(orderedEquals(first)));

      final decoded =
          readFromJsonTree(
                (await inlineDeserializer(second) as Ok<JsonMap>).value,
              )
              as Ok<RackDocument>;
      expect(
        decoded.value.racks.values.single.heightU,
        t.services.session.controller.doc.racks.values.single.heightU,
      );
    });
  });

  group('the recovery directory is where snapshots go', () {
    test('and it is named <dataRoot>/recovery', () async {
      final t = await _session();
      expect(
        t.services.controller.recovery.directory,
        t.context.join(kTestDataRoot, kRecoveryDirName),
      );
    });
  });
}
