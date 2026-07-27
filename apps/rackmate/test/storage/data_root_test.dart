// The portable seam. Four cases, all against `FakeFileStore` with a
// `p.Style.windows` context, so they run green on a Linux CI runner.
//
// The assertion that matters most is CASE 2's "the app-support stub was
// called ZERO times". That is the mechanical form of "portable mode
// writes nothing outside the folder beside the executable", and it is the
// assertion that fails the day someone adds a "just in case" lookup to
// the portable branch.
//
// IT IS NOT, AND IS NOT CLAIMED TO BE, "the app leaves nothing on the
// host". The Windows file dialog still records `rackmate.exe` and the last
// folder browsed in HKCU; `test/session/registry_claim_test.dart` is where
// that is stated and gated. This file is about the DATA ROOT only.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackmate/src/storage/data_root.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);

const _exeDir = r'D:\RackMate';
const _marker = r'D:\RackMate\portable.txt';
final String _portableRoot = _windows.join(_exeDir, kPortableDataDirName);
const _appSupport = r'C:\Users\rriley\AppData\Roaming\RackMate';

/// The three names a Flutter Windows Release build puts INSIDE
/// `<exeDir>\data`. Used to make the bundle-collision assertion concrete
/// rather than abstract.
const _flutterBundleContents = {'app.so', 'icudtl.dat', 'flutter_assets'};

void main() {
  group('resolveDataRoot', () {
    test('CASE 1 — no marker: the root is application support', () async {
      final fs = FakeFileStore(initialDirectories: const {'D:', _exeDir});
      var appSupportCalls = 0;

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async {
          appSupportCalls++;
          return _appSupport;
        },
        context: _windows,
      );

      expect(root, isA<DataRootReady>());
      final ready = root as DataRootReady;
      expect(ready.path, _appSupport);
      expect(ready.portable, isFalse);
      expect(appSupportCalls, 1);
    });

    test(r'CASE 2 — marker present: the root is <exeDir>\data, AND '
        'path_provider is NEVER consulted', () async {
      final fs = FakeFileStore(
        initialFiles: {_marker: _bytes('')},
        initialDirectories: const {'D:', _exeDir},
      );
      var appSupportCalls = 0;

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async {
          appSupportCalls++;
          return _appSupport;
        },
        context: _windows,
      );

      expect(root, isA<DataRootReady>());
      final ready = root as DataRootReady;
      expect(ready.path, _portableRoot);
      expect(ready.portable, isTrue);
      expect(
        fs.state.directories,
        contains(_portableRoot),
        reason: 'the data directory must be created',
      );

      // THE "NOTHING OUTSIDE OUR OWN FOLDER" ASSERTION.
      // `getApplicationSupportDirectory`
      // on Windows calls SHGetKnownFolderPath — read-only, but calling it
      // at all is the first step towards writing there, and this is the
      // test that fails if someone ever does.
      expect(
        appSupportCalls,
        0,
        reason: 'portable mode must not touch the host profile at all',
      );
    });

    test('CASE 3 — marker present but the data directory is not '
        'writable: UNUSABLE, with NO silent fallback', () async {
      // A read-only USB stick. Falling back to %APPDATA% here would write
      // the client's file paths onto a machine the user deliberately
      // chose not to touch — the precise thing portable mode exists to
      // prevent.
      final fs = FakeFileStore(
        initialFiles: {_marker: _bytes('')},
        initialDirectories: const {'D:', _exeDir},
        readOnlyPaths: {
          _windows.join(_portableRoot, kWritableProbeFileName),
        },
      );
      var appSupportCalls = 0;

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async {
          appSupportCalls++;
          return _appSupport;
        },
        context: _windows,
      );

      expect(root, isA<DataRootUnusable>());
      final unusable = root as DataRootUnusable;
      expect(unusable.attemptedPath, _portableRoot);
      expect(unusable.portable, isTrue);
      expect(
        appSupportCalls,
        0,
        reason:
            'a failed portable root must NOT silently become a '
            'non-portable one',
      );
    });

    test('CASE 4 — the marker is a SIGNAL, not a config file: any '
        'content at all still means portable', () async {
      for (final content in <String>[
        '',
        '\uFEFF',
        'true',
        'false',
        'portable=no',
        'x' * 4096,
      ]) {
        final fs = FakeFileStore(
          initialFiles: {_marker: _bytes(content)},
          initialDirectories: const {'D:', _exeDir},
        );
        final root = await resolveDataRoot(
          fs: fs,
          executableDirectory: _exeDir,
          applicationSupportDirectory: () async => _appSupport,
          context: _windows,
        );

        expect(
          (root as DataRootReady).portable,
          isTrue,
          reason:
              'content ${content.length} chars: PRESENCE is the '
              'signal. Parsing the file is how a marker quietly becomes '
              'a configuration system — including a "portable=no" that '
              'would silently disable the mode the user asked for.',
        );
      }
    });

    test('an unwritable application-support directory degrades the same '
        'way — one code path for both', () async {
      final fs = FakeFileStore(
        initialDirectories: const {'D:', _exeDir},
        readOnlyPaths: {
          _windows.join(_appSupport, kWritableProbeFileName),
        },
      );

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async => _appSupport,
        context: _windows,
      );

      // A locked-down corporate profile. Autosave, recents and window
      // position go off for the session; documents still open and save
      // normally, because those write to the user's chosen directory.
      expect(root, isA<DataRootUnusable>());
      expect((root as DataRootUnusable).portable, isFalse);
    });

    test('the write probe leaves nothing behind', () async {
      final fs = FakeFileStore(initialDirectories: const {'D:', _exeDir});
      await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async => _appSupport,
        context: _windows,
      );

      expect(
        fs.state.files.keys.where((f) => f.contains(kWritableProbeFileName)),
        isEmpty,
        reason:
            'a probe file left in the data root would be a trace, and '
            'would accumulate one per launch',
      );
    });

    test('the marker file name is the shipped contract', () {
      // The portable ZIP is built against this string. Changing it
      // silently turns every existing portable stick back into an
      // installed app writing to %APPDATA%.
      expect(kPortableMarkerFileName, 'portable.txt');
    });
  });

  group('THE PORTABLE ROOT MUST NOT BE THE FLUTTER ASSET BUNDLE', () {
    // `<exeDir>\data` is where `flutter::DartProject project(L"data")`
    // puts app.so, icudtl.dat and flutter_assets/. Writing recovery
    // snapshots there means the normal way to update a portable build —
    // unzip a new release over the folder — REPLACES the directory and
    // destroys every snapshot in it, including one holding work from a
    // crash minutes earlier.

    test('main.cpp names the bundle directory, and the writable root is '
        'NOT it', () {
      // Read from the real source rather than hard-coded, so this fails
      // whichever end someone changes. Two files have to agree, and
      // neither can be trusted to remember the other.
      final source = File('windows/runner/main.cpp').readAsStringSync();
      final match = RegExp(
        r'DartProject\s+\w+\s*\(\s*L"([^"]+)"\s*\)',
      ).firstMatch(source);

      expect(
        match,
        isNotNull,
        reason:
            'windows/runner/main.cpp no longer declares a DartProject '
            'the way this assertion reads it — the collision guard has '
            'gone blind and must be repaired, not deleted',
      );
      final bundleDirName = match!.group(1);
      expect(bundleDirName, 'data', reason: 'the measured Flutter default');

      expect(
        kPortableDataDirName,
        isNot(bundleDirName),
        reason:
            'the portable data root would land inside the Flutter asset '
            'bundle: recovery snapshots, recents and prefs intermixed '
            'with app.so and flutter_assets/, and wiped by the next '
            'unzip-over-the-folder update',
      );
    });

    test('a portable session writes NOTHING inside the asset bundle', () async {
      // The gap the original CASE 2 had: its fixture seeded only {'D:',
      // exeDir}, so `createDirectory` invented a clean directory instead
      // of landing in a populated one, and the collision was invisible.
      // This one seeds the bundle for real.
      final bundleDir = _windows.join(_exeDir, 'data');
      final fs = FakeFileStore(
        initialFiles: {
          _marker: _bytes(''),
          for (final name in _flutterBundleContents)
            _windows.join(bundleDir, name): _bytes('program bytes'),
        },
        initialDirectories: {'D:', _exeDir, bundleDir},
      );

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async => _appSupport,
        context: _windows,
      );

      expect((root as DataRootReady).path, _portableRoot);

      // Every path the resolution touched, including the write probe.
      final touched = fs.journal.expand(pathsOf).toSet();
      expect(
        touched,
        isNotEmpty,
        reason: 'a resolution that journalled nothing proves nothing',
      );
      expect(
        touched.where((path) => _windows.isWithin(bundleDir, path)),
        isEmpty,
        reason:
            'out-of-document state written into the AOT snapshot '
            'directory is destroyed by the next unzip-over-the-folder '
            'update — silently, and after the crash it was meant to '
            'survive',
      );

      // ...and the program files are exactly as they were.
      for (final name in _flutterBundleContents) {
        expect(
          fs.state.files[_windows.join(bundleDir, name)],
          isNotNull,
          reason: '$name must be untouched',
        );
      }
    });
  });

  group('resolveDataRoot NEVER THROWS — the app always starts', () {
    // path_provider's Windows implementation itself calls
    // `directory.create(recursive: true)` on %APPDATA%\<Company>\<Product>
    // and throws `MissingPlatformDirectoryException` when
    // SHGetKnownFolderPath answers E_INVALIDARG/E_FAIL. Awaited outside
    // the guard, that throw propagated out of `main()` and `runApp` was
    // never reached: a dead Win32 window and no error.
    test('a THROWING application-support lookup degrades instead of '
        'killing startup', () async {
      final fs = FakeFileStore(initialDirectories: const {'D:', _exeDir});

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async =>
            throw const FileSystemException(
              'Could not get application support directory',
            ),
        context: _windows,
      );

      expect(
        root,
        isA<DataRootUnusable>(),
        reason:
            'an installed app on a locked-down or corrupted profile must '
            'degrade to a no-persistence session with an honest warning, '
            'not fail to launch',
      );
      final unusable = root as DataRootUnusable;
      expect(unusable.portable, isFalse);
      expect(unusable.cause, isA<FileSystemException>());
    });

    test('an Error, not just an Exception, degrades the same way', () async {
      // `on Exception` would walk straight past this one.
      final fs = FakeFileStore(initialDirectories: const {'D:', _exeDir});

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async => throw StateError('no profile'),
        context: _windows,
      );

      expect(root, isA<DataRootUnusable>());
      expect((root as DataRootUnusable).cause, isA<StateError>());
    });

    test('a failing PORTABLE probe still never consults the profile',
        () async {
      // The portable branch already had a guard; this pins that widening
      // the non-portable one did not accidentally add a fallback.
      final fs = FakeFileStore(
        initialFiles: {_marker: _bytes('')},
        initialDirectories: const {'D:', _exeDir},
        readOnlyPaths: {
          _windows.join(_portableRoot, kWritableProbeFileName),
        },
      );
      var appSupportCalls = 0;

      final root = await resolveDataRoot(
        fs: fs,
        executableDirectory: _exeDir,
        applicationSupportDirectory: () async {
          appSupportCalls++;
          return _appSupport;
        },
        context: _windows,
      );

      expect(root, isA<DataRootUnusable>());
      expect(appSupportCalls, 0);
    });
  });
}

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);
