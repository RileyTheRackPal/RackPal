// `#241`: the shelf, decoded. `#238` listed files and `#239` decoded
// bytes; this is the join, and the cases that matter are the ones where
// the join fails.
//
// THE PROPERTY UNDER TEST IS THAT ONE BAD FILE COSTS ONE LIBRARY. DR-103
// §11.102.7 rules that a `.rmda` which will not decode comes back as a
// row carrying its fault rather than as an absence, and the reason it is
// a row is that the user put a file in a folder and needs to be told
// which one is not working. A test that only checked the happy path
// would pass against an implementation that dropped the whole shelf on
// the first malformed byte.
//
// AND IT IS NOT AC-042. A hash mismatch loads and is badged; that is
// `library_import_test.dart`'s. What lands here is a file yielding NO
// templates at all, which has nothing to badge.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart' show StorageOsException;
import 'package:rackpal/src/storage/library_directory.dart';
import 'package:rackpal/src/storage/library_shelf.dart';
import 'package:rackpal_core/rackpal_core.dart';

import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _root = r'C:\RackPalData';
final String _libs = _windows.join(_root, kLibraryDirName);

String _path(String name) => _windows.join(_libs, name);

TemplateBody _body(String name) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  frontU: 1,
);

DeviceTemplateFile _entry(
  String id, {
  String name = 'Thing',
  int version = 1,
}) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: version,
  contentHash: 'sha256:whatever',
  body: _body(name),
);

/// A real `.rmda`, through the real encoder. Nothing here hand-rolls the
/// bytes: a fixture written by hand agrees with itself and not with the
/// codec, which is how a format test comes to pass against a reader
/// nothing else in the product can use.
Uint8List _rmda(String name, List<DeviceTemplateFile> templates) =>
    encodeRmdaBytes(DeviceLibraryFile(name: name, templates: templates));

FakeFileStore _fs(Map<String, Uint8List> files) => FakeFileStore(
  initialFiles: files,
  initialDirectories: <String>{'C:', _root, _libs},
);

Future<List<ShelfLibrary>> _shelf(
  FakeFileStore fs, {
  int maxBytes = kMaxDocumentBytes,
}) => loadLibraryShelf(fs, _root, context: _windows, maxBytes: maxBytes);

void main() {
  group('an empty shelf, which is every degraded case', () {
    test('no library directory means no libraries and no error', () async {
      final fs = FakeFileStore(
        initialDirectories: <String>{'C:', _root},
      );
      expect(await _shelf(fs), isEmpty);
    });

    test('a directory holding no .rmda reads as empty', () async {
      final fs = _fs({_path('notes.txt'): Uint8List(4)});
      expect(await _shelf(fs), isEmpty);
    });
  });

  group('what a loaded library carries', () {
    test('the manifest name and the entries, under the file s id', () async {
      final fs = _fs({
        _path('shop-kit.rmda'): _rmda('Shop Kit', [
          _entry('tpl.amp', name: 'Amp'),
          _entry('tpl.matrix', name: 'Matrix'),
        ]),
      });
      final shelf = await _shelf(fs);
      expect(shelf, hasLength(1));
      final library = shelf.single.library!;
      // THE ID IS THE FILE AND THE NAME IS THE MANIFEST. Two facts, and
      // the whole reason `LoadedLibrary` exists beside `DeviceLibraryFile`.
      expect(library.id, 'shop-kit');
      expect(library.name, 'Shop Kit');
      expect(library.templates.map((t) => t.body.displayName), [
        'Amp',
        'Matrix',
      ]);
      expect(shelf.single.fault, isNull);
      expect(shelf.single.loaded, isTrue);
    });

    test('two libraries whose manifests agree stay two libraries', () async {
      // The collapse DR-102 §11.101.4 refuses, at the shelf rather than
      // at the template: both call themselves `Shop Kit` and they cannot
      // both be one file.
      final fs = _fs({
        _path('mine.rmda'): _rmda('Shop Kit', [_entry('tpl.a')]),
        _path('theirs.rmda'): _rmda('Shop Kit', [_entry('tpl.b')]),
      });
      final shelf = await _shelf(fs);
      expect(shelf.map((e) => e.id), ['mine', 'theirs']);
      expect(shelf.map((e) => e.library!.name), ['Shop Kit', 'Shop Kit']);
    });

    test(
      'shelf order is the directory listing s order, sorted by id',
      () async {
        final fs = _fs({
          _path('zulu.rmda'): _rmda('Z', [_entry('tpl.z')]),
          _path('alpha.rmda'): _rmda('A', [_entry('tpl.a')]),
          _path('mike.rmda'): _rmda('M', [_entry('tpl.m')]),
        });
        expect((await _shelf(fs)).map((e) => e.id), ['alpha', 'mike', 'zulu']);
      },
    );
  });

  group('one bad file costs one library (DR-103 §11.102.7)', () {
    test(
      'a file that is not JSON is a fault, and its neighbours load',
      () async {
        final fs = _fs({
          _path('good.rmda'): _rmda('Good', [_entry('tpl.a')]),
          _path('junk.rmda'): Uint8List.fromList(
            utf8.encode('not json at all'),
          ),
          _path('also-good.rmda'): _rmda('Also', [_entry('tpl.b')]),
        });
        final shelf = await _shelf(fs);
        expect(shelf.map((e) => e.id), ['also-good', 'good', 'junk']);
        expect(shelf.map((e) => e.loaded), [true, true, false]);
        expect(shelf.firstWhere((e) => e.id == 'junk').fault, isNotNull);
      },
    );

    test(
      'a .rmdx renamed to .rmda names the WRONG FILE, not a shape',
      () async {
        // `rmda_codec.dart` checks `kind` before `schemaVersion` for
        // exactly this: the two formats are structurally close enough that
        // a shape error would report the wrong file as the right file from
        // the wrong era.
        final fs = _fs({
          _path('device.rmda'): encodeRmdxBytes(_entry('tpl.amp')),
        });
        final shelf = await _shelf(fs);
        expect(shelf.single.loaded, isFalse);
        expect(shelf.single.fault, isA<NotADeviceLibraryError>());
      },
    );

    test('a newer schemaVersion is refused, carrying both numbers', () async {
      final tree = rmdaToJsonTree(
        DeviceLibraryFile(name: 'Future', templates: [_entry('tpl.a')]),
      )..['schemaVersion'] = kRmdaSchemaVersion + 1;
      final fs = _fs({
        // `jsonEncode`, not the canonical encoder, which the barrel
        // deliberately does not export. The reader takes any JSON; the
        // canonical form is a WRITE convention (CR-117) and asserting it
        // is `rmda_codec_test.dart`'s.
        _path('future.rmda'): Uint8List.fromList(utf8.encode(jsonEncode(tree))),
      });
      final fault = (await _shelf(fs)).single.fault;
      expect(fault, isA<NewerRmdaSchemaError>());
      // THE ERROR OBJECT, NOT A RENDERED STRING, so `#242`'s tooltip can
      // say which version rather than repeating a sentence written here.
      expect(
        (fault! as NewerRmdaSchemaError).storedSchemaVersion,
        kRmdaSchemaVersion + 1,
      );
    });

    test('a library over the cap is a fault and is never read', () async {
      // AC-058/D8, and the ordering is the point: the cap is asked of
      // `stat` BEFORE `readBytes` allocates, which is `#237`'s whole
      // finding. A cap enforced after the read has bounded nothing.
      final big = _rmda('Big', [
        for (var i = 0; i < 40; i++) _entry('tpl.$i', name: 'Device $i'),
      ]);
      final fs = _fs({_path('big.rmda'): big});
      final shelf = await _shelf(fs, maxBytes: big.length - 1);
      expect(shelf.single.loaded, isFalse);
      expect(shelf.single.fault, isA<DocumentTooLargeError>());
      expect(fs.calls, isNot(contains('readBytes')));
    });

    test('a library exactly at the cap still loads', () async {
      final bytes = _rmda('Snug', [_entry('tpl.a')]);
      final fs = _fs({_path('snug.rmda'): bytes});
      expect((await _shelf(fs, maxBytes: bytes.length)).single.loaded, isTrue);
    });
  });

  group('the read that throws', () {
    test(
      'a file that vanishes between listing and reading is a fault',
      () async {
        // A shelf is a directory somebody else can be writing to. This
        // must not take the palette down, which is `library_directory.dart`'s
        // position one level up.
        // PROBED, NOT GUESSED. The fault map is keyed on the operation
        // INDEX, and that index moves whenever anything before it grows a
        // call: `listDirectory`, then one `stat` per file for the listing,
        // then a second `stat` for the cap, then the read. The call
        // sequence is asserted below rather than assumed, so a change to
        // that order fails here loudly instead of silently retargeting the
        // fault at an operation this test was not about.
        final faulted = FakeFileStore(
          initialFiles: {
            _path('gone.rmda'): _rmda('G', [_entry('tpl.a')]),
          },
          initialDirectories: <String>{'C:', _root, _libs},
          faults: <int, Object>{3: const StorageOsException(2)},
        );
        final shelf = await _shelf(faulted);
        expect(faulted.calls, ['listDirectory', 'stat', 'stat', 'readBytes']);
        expect(shelf.single.loaded, isFalse);
        expect(shelf.single.fault, isA<StorageOsException>());
      },
    );
  });

  group('loadedLibrariesOf', () {
    test('it drops the faults and keeps shelf order', () async {
      final fs = _fs({
        _path('a.rmda'): _rmda('A', [_entry('tpl.a')]),
        _path('b.rmda'): Uint8List.fromList(utf8.encode('{')),
        _path('c.rmda'): _rmda('C', [_entry('tpl.c')]),
      });
      final loaded = loadedLibrariesOf(await _shelf(fs));
      expect(loaded.map((l) => l.id), ['a', 'c']);
    });

    test('an all-broken shelf yields an empty list, not a throw', () async {
      final fs = _fs({_path('b.rmda'): Uint8List.fromList(utf8.encode('{'))});
      expect(loadedLibrariesOf(await _shelf(fs)), isEmpty);
    });
  });

  group('the shelf feeds the palette (DR-102 §11.101.3)', () {
    // The join this whole chapter exists for, asserted end to end rather
    // than inferred: bytes on a shelf become tagged palette rows.
    test(
      'a loaded library becomes tagged rows in buildPlaceableTemplates',
      () async {
        final fs = _fs({
          _path('shop-kit.rmda'): _rmda('Shop Kit', [
            _entry('tpl.amp', name: 'Amp'),
          ]),
        });
        final doc = RackDocument(
          id: const Uuid('doc-241'),
          appVersion: '0.4.0',
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
          meta: EntityMeta(
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            updatedBy: 'test',
          ),
        );
        final rows = buildPlaceableTemplates(
          doc,
          libraries: loadedLibrariesOf(await _shelf(fs)),
        );
        expect(rows, hasLength(1));
        expect(rows.single.body.displayName, 'Amp');
        expect(rows.single.library?.libraryId, 'shop-kit');
        expect(rows.single.library?.libraryName, 'Shop Kit');
        expect(rows.single.documentKey, isNull);
      },
    );
  });
}
