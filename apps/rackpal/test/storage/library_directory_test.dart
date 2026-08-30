// `#238`: the third storage location docs/06 §7.1 has always named and
// nothing has ever built.
//
// THE CASES THAT MATTER ARE THE ABSENCES. Listing files in a directory is
// not where this goes wrong. It goes wrong when the directory is not
// there, or cannot be read, or is being written to while it is read, and
// in every one of those the required behaviour is the same: **an empty
// shelf and a working palette**, because `buildPlaceableTemplates` reads
// the document and the seed and neither lives here (DR-102 §11.101.3).
//
// A session that lost its libraries and kept its documents is degraded.
// A session that refused to start because a folder was missing is broken,
// and `DataRootUnusable`'s own header already took that position for
// every other store.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/library_directory.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _root = r'C:\RackPalData';
final String _libs = _windows.join(_root, kLibraryDirName);

Uint8List _bytes(int n) => Uint8List(n);

FakeFileStore _fs(Map<String, Uint8List> files, {bool withDir = true}) =>
    FakeFileStore(
      initialFiles: files,
      initialDirectories: <String>{'C:', _root, if (withDir) _libs},
    );

void main() {
  group('where it lives', () {
    test('it is one directory under the data root', () {
      expect(
        libraryDirectoryPath(_root, context: _windows),
        r'C:\RackPalData\libraries',
      );
    });

    test('so portable mode is settled by the root it is handed', () {
      // No branch here, and that is the point: `resolveDataRoot` answers
      // portable-versus-installed once at startup and every store takes
      // the answer. A second decision in this file is a second thing to
      // keep true.
      expect(
        libraryDirectoryPath(r'E:\RackPal\RackPalData', context: _windows),
        r'E:\RackPal\RackPalData\libraries',
      );
    });
  });

  group('an empty shelf is not a failure', () {
    test('a directory that does not exist lists nothing', () async {
      // It does not exist until somebody imports a library. Creating it
      // eagerly would put an empty folder on a stick to record that the
      // user has never used a feature.
      final fs = _fs(const {}, withDir: false);
      expect(await listLibraries(fs, _root, context: _windows), isEmpty);
    });

    test('a directory that throws on read lists nothing', () async {
      // The degraded case, one level down from DataRootUnusable. The
      // palette must keep working.
      final fs = FakeFileStore(
        initialDirectories: <String>{'C:', _root, _libs},
        faults: <int, Object>{0: const FormatException('the share blinked')},
      );
      expect(await listLibraries(fs, _root, context: _windows), isEmpty);
    });
  });

  group('what it lists, and what it ignores', () {
    test('it finds .rmda and ignores everything else', () async {
      final fs = _fs({
        _windows.join(_libs, 'shop.rmda'): _bytes(120),
        _windows.join(_libs, 'notes.txt'): _bytes(10),
        _windows.join(_libs, 'Smith.rmpj'): _bytes(10),
        _windows.join(_libs, 'device.rmdx'): _bytes(10),
      });
      final found = await listLibraries(fs, _root, context: _windows);
      expect(found.map((l) => l.id), ['shop']);
    });

    test(
      'the extension match is case-insensitive; the id keeps its case',
      () async {
        // Windows is case-insensitive and a library named `.RMDA` by a
        // spreadsheet-minded person is the same file. The ID keeps what
        // the user typed, because that is what they will look for.
        final fs = _fs({_windows.join(_libs, 'ShopKit.RMDA'): _bytes(9)});
        final found = await listLibraries(fs, _root, context: _windows);
        expect(found.single.id, 'ShopKit');
      },
    );

    test('it is sorted by id, not by the filesystem', () async {
      // A list whose order changes between launches is the kind of thing
      // nobody reports and everybody notices.
      final fs = _fs({
        _windows.join(_libs, 'zebra.rmda'): _bytes(1),
        _windows.join(_libs, 'alpha.rmda'): _bytes(1),
        _windows.join(_libs, 'mike.rmda'): _bytes(1),
      });
      final found = await listLibraries(fs, _root, context: _windows);
      expect(found.map((l) => l.id), ['alpha', 'mike', 'zebra']);
    });

    test('it carries the size and mtime, which is what #240 needs', () async {
      // Not the contents. Parsing is #239's and the codec does not
      // exist; what a caller can decide from this is whether to read the
      // file at all, which is exactly what #237's cap acts on.
      final fs = _fs({_windows.join(_libs, 'shop.rmda'): _bytes(4096)});
      final found = await listLibraries(fs, _root, context: _windows);
      expect(found.single.sizeBytes, 4096);
      expect(found.single.modified, isA<DateTime>());
      expect(found.single.path, _windows.join(_libs, 'shop.rmda'));
    });

    test(
      'a file that vanishes between listing and stat is one row absent',
      () async {
        // A projection of a directory somebody else can be writing to.
        // `placeable_templates.dart` takes the same position on a missing
        // snapshot: one row absent, not a crash.
        //
        // THE FAULT IS ARMED BY INDEX AND THE ROW IS NOT NAMED. Operation
        // 0 is the listing and operation 1 is the first `stat`, so this
        // fails exactly one of the two without depending on which order
        // the fake enumerates in. Asserting WHICH id survived would be
        // asserting the fake's enumeration order, which is not a property
        // of anything.
        final fs = FakeFileStore(
          initialFiles: {
            _windows.join(_libs, 'gone.rmda'): _bytes(1),
            _windows.join(_libs, 'here.rmda'): _bytes(1),
          },
          initialDirectories: <String>{'C:', _root, _libs},
          faults: <int, Object>{1: const FormatException('it moved')},
        );
        final found = await listLibraries(fs, _root, context: _windows);
        expect(
          found,
          hasLength(1),
          reason: 'one stat failed, so one row is absent and none crashes',
        );
      },
    );
  });

  group('what this file does NOT do', () {
    test('it hands back no parsed library, because #239 owns that', () async {
      // Stated as a test so the split is visible rather than only
      // commented. A service that returned parsed libraries today would
      // have had to invent a second decoder or block on the codec.
      final fs = _fs({_windows.join(_libs, 'shop.rmda'): _bytes(3)});
      final found = await listLibraries(fs, _root, context: _windows);
      expect(found.single, isA<LibraryFile>());
      expect(
        found.single.toString(),
        contains('shop'),
        reason: 'the row identifies a file, not a set of templates',
      );
    });
  });
}
