// THE DEGRADED SESSION WRITES NOTHING. NOT "almost nothing".
//
// ==================================================================
// WHAT THIS IS FOR
// ==================================================================
// `DataRootUnusable` is a first-class outcome, not an error path: a
// read-only USB stick in portable mode and a locked-down corporate profile
// both produce it, and the ruling is that the app STARTS with
// out-of-document persistence DISABLED and says so in the status bar.
// There is no silent fallback to %APPDATA%, because writing the client's
// file paths onto a machine the user deliberately chose not to touch is
// the precise thing portable mode exists to prevent.
//
// The defect this file pins: `recovery.beginSession()` was called
// unconditionally from the composition root, so the degraded session
// created `<dataRoot>/sessions/` and a `.lease` file inside a root the app
// had just declared unusable and told the user it was not writing to.
//
// AND THE WORST SHAPE OF IT WAS THE EMPTY ROOT. When
// `applicationSupportDirectory()` throws — the locked-down or corrupted
// profile, which is the case `DataRootUnusable` exists for —
// `attemptedPath` is `''`, because the lookup is what failed and there is
// no directory to name. `p.join('', 'sessions')` is the RELATIVE string
// `sessions`, and `Directory('sessions').create(recursive: true)` resolves
// that against the PROCESS'S CURRENT DIRECTORY. For a build launched from
// Explorer that is the install folder, or the portable folder on the
// stick. The one code path whose entire premise is "we cannot write
// anywhere safe" was the one writing outside the data root.
//
// THE ASSERTIONS ARE DIFFS, NOT ABSENCE CHECKS. `expect(files, isEmpty)`
// would pass on a fake nobody wired up. Every case below records the
// fake's whole state before `buildAppServices` and compares it after, and
// the last test in the file runs the SAME comparison over a HEALTHY root
// and requires it to be non-empty — so a fixture that silently stopped
// exercising the wiring fails instead of going quietly green.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/atomic_writer.dart';
import 'package:rackmate/src/storage/data_root.dart';
import 'package:rackmate/src/storage/recovery_store.dart';
import 'package:rackmate_core/rackmate_core.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

final _windows = p.Context(style: p.Style.windows);

/// What a run touched: paths created or written that were not there
/// before.
typedef Touched = ({Set<String> directories, Set<String> files});

Touched _diff(FsState before, FsState after) => (
  directories: after.directories.difference(before.directories),
  files: after.files.keys.toSet().difference(before.files.keys.toSet()),
);

/// Asserts a run touched nothing at all.
///
/// The two sets are checked SEPARATELY rather than as one record: Dart's
/// `Set` does not override `==`, so a record holding two of them compares
/// by identity and `expect(touched, (directories: {}, files: {}))` passes
/// for nobody and fails for everybody. Found the direct way, by writing
/// it and watching every case fail with "Expected: {} Actual: {}".
void expectTouchedNothing(Touched touched, {String? reason}) {
  expect(touched.directories, isEmpty, reason: reason);
  expect(touched.files, isEmpty, reason: reason);
}

/// A store over [fs] in the state the composition root builds it in for a
/// degraded session: pointed at a root that does not work, and disabled.
RecoveryStore _degradedStore(FakeFileStore fs, {required String dataRoot}) =>
    RecoveryStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: dataRoot,
      context: _windows,
      sessionId: 'sess-a',
      enabled: false,
    );

void main() {
  group('the composition root, over a data root that is unusable', () {
    // The two shapes `DataRootUnusable` really takes, both named in
    // `resolveDataRoot`.
    const cases = <(String, DataRootUnusable)>[
      (
        // `applicationSupportDirectory()` threw. There is no path to name.
        'the support lookup failed and named no path',
        DataRootUnusable(
          attemptedPath: '',
          portable: false,
          cause: 'SHGetKnownFolderPath returned E_FAIL',
        ),
      ),
      (
        // The read-only stick: a real path, and the app has just told the
        // user it is not writing there.
        'the portable root exists but is not writable',
        DataRootUnusable(
          attemptedPath: r'E:\RackMate\RackMateData',
          portable: true,
          cause: 'access denied',
        ),
      ),
    ];

    for (final (name, root) in cases) {
      test('writes NOTHING when $name', () async {
        final fs = FakeFileStore(
          initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
        );
        final before = fs.state;

        final t = await buildTestSession(fs: fs, dataRoot: root);

        expectTouchedNothing(
          _diff(before, fs.state),
          reason:
              'a session that has told the user it cannot write anywhere '
              'safe must not create a directory or a file anywhere — '
              'least of all a lease under a relative `sessions` path, '
              'which lands in whatever folder the app was launched from',
        );
        // And the session really is the degraded one, so the assertion
        // above is about the right branch.
        expect(t.services.startupWarning, isNotNull);
        expect(t.services.session.recoveryEnabled, isFalse);
      });
    }
  });

  group('RecoveryStore.enabled', () {
    test('a disabled store takes no lease and creates no directory', () async {
      final fs = FakeFileStore(initialDirectories: {'C:'});
      final store = _degradedStore(fs, dataRoot: '');
      final before = fs.state;

      await store.beginSession();

      expectTouchedNothing(_diff(before, fs.state));
      // The relative path is still the thing that would have been
      // written. Named here so a reader can see what the guard is for.
      expect(store.sessionsDirectory, 'sessions');
    });

    test('...and endSession over it is a no-op rather than a throw', () async {
      final fs = FakeFileStore(initialDirectories: {'C:'});
      final store = _degradedStore(fs, dataRoot: '');
      final before = fs.state;

      await store.beginSession();
      await store.endSession();

      expectTouchedNothing(_diff(before, fs.state));
    });

    test('a disabled store refuses to write, and does not create the '
        'recovery directory doing it', () async {
      // NOT A LIVE PATH TODAY — `AutosaveScheduler` answers `disabled`
      // without calling here — but `write`'s first statement is
      // `createDirectory(directory)`, the same unconditional write into an
      // unusable root that the lease was. A future caller must not be able
      // to reintroduce it by finding this method reachable.
      final fs = FakeFileStore(initialDirectories: {'C:'});
      final store = _degradedStore(fs, dataRoot: r'E:\RackMateData');
      final before = fs.state;

      final result = await store.write(
        sidecar: RecoverySidecar(
          docId: 'doc-1~sess-a',
          sequence: 1,
          savedAt: DateTime.utc(2026),
          displayName: 'Smith',
          appVersion: '0.1.0',
          schemaVersion: kSchemaVersion,
        ),
        documentBytes: Uint8List.fromList(const [1, 2, 3]),
      );

      expect(result, isA<Err<void>>());
      expectTouchedNothing(_diff(before, fs.state));
    });

    test('a disabled store still ANSWERS the read-shaped calls, which is '
        'why it exists at all', () async {
      // `SessionController` calls `delete` on every clean shutdown and
      // `scan` is gated upstream; both must be safe over a root that does
      // not work, because the alternative is a null check at every call
      // site. Safe means "answers without writing", not "throws".
      final fs = FakeFileStore(initialDirectories: {'C:'});
      final store = _degradedStore(fs, dataRoot: '');
      final before = fs.state;

      await store.delete('doc-1~sess-a');
      final scan = await store.scan();

      expect(scan.survivors, isEmpty);
      expect(scan.skippedLive, 0);
      expectTouchedNothing(_diff(before, fs.state));
    });
  });

  test('THE VACUITY GUARD — a HEALTHY root does take the lease', () async {
    // Everything above asserts an empty diff, and an empty diff is what a
    // fixture that stopped calling anything also produces. This is the
    // same measurement over the same wiring with the root the app can
    // actually use, and it must be non-empty: the sessions directory and
    // this process's `.lease` are exactly what the degraded session is
    // required NOT to create.
    final fs = FakeFileStore(
      initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
    );
    final before = fs.state;

    await buildTestSession(fs: fs);

    final touched = _diff(before, fs.state);
    expect(
      touched.directories,
      contains(_windows.join(kTestDataRoot, 'sessions')),
      reason:
          'the healthy session announces itself, or the tests above '
          'are measuring a fixture that does nothing',
    );
    expect(
      touched.files,
      contains(_windows.join(kTestDataRoot, 'sessions', 'sess-a.lease')),
    );
  });
}
