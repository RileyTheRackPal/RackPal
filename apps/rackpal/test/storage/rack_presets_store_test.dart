// #561, DR-176 §11.175.3: `rack_presets.json` beside `prefs.json`, read and
// written the way `prefs_store_test.dart` holds `PrefsStore` to.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/rack_presets_store.dart';
import 'package:rackpal_core/rackpal_core.dart';

import 'atomicity.dart';
import 'fake_file_store.dart';

final _windows = p.Context(style: p.Style.windows);
const _dataRoot = r'C:\data';
const _file = r'C:\data\rack_presets.json';

({RackPresetsStore store, FakeFileStore fs}) _make({
  Map<String, Uint8List>? files,
}) {
  final fs = FakeFileStore(
    initialFiles: files,
    initialDirectories: const {'C:', _dataRoot},
  );
  return (
    store: RackPresetsStore(
      fs: fs,
      writer: AtomicWriter(
        fs: fs,
        queue: SaveQueue(),
        context: _windows,
        delay: (_) async {},
      ),
      dataRoot: _dataRoot,
      context: _windows,
    ),
    fs: fs,
  );
}

RackPreset _mine(String slug) => RackPreset(
  id: '$kUserPresetIdPrefix$slug',
  displayName: 'Mine $slug',
  heightU: 30,
  formFactor: RackFormFactor.floorEnclosure,
  widthClass: RackWidthClass.eia19,
  railType: RailType.squareCageNut,
  usableDepth: Len.fromInches(28),
  weightCapacity: Mass.fromKilograms(300),
);

void main() {
  group('RackPresetsStore', () {
    test(
      'a missing file is no presets and nothing hidden, not an error',
      () async {
        final read = await _make().store.load();
        expect(read.presets, isEmpty);
        expect(read.hiddenSeedIds, isEmpty);
      },
    );

    test('an unparseable file is no presets, so it can never stop the app '
        'starting', () async {
      final made = _make(
        files: {_file: Uint8List.fromList(utf8.encode('{{{'))},
      );
      final read = await made.store.load();
      expect(read.presets, isEmpty);
      expect(made.store.current.presets, isEmpty);
    });

    test('round-trips your presets and the seeded ids you hid', () async {
      final made = _make();
      await made.store.save(
        UserRackPresets(
          presets: [_mine('a'), _mine('b')],
          hiddenSeedIds: const {'credenzaBay8U'},
        ),
      );

      final loaded = await _make(
        files: {_file: await made.fs.readBytes(_file)},
      ).store.load();
      expect(loaded.presets.map((p) => p.id), [
        '${kUserPresetIdPrefix}a',
        '${kUserPresetIdPrefix}b',
      ]);
      expect(loaded.presets.first.usableDepth, Len.fromInches(28));
      expect(loaded.hiddenSeedIds, {'credenzaBay8U'});
    });

    test(
      'current is what the last save decided, before any read-back',
      () async {
        final made = _make();
        await made.store.save(UserRackPresets(presets: [_mine('a')]));
        expect(made.store.current.presets.single.id, '${kUserPresetIdPrefix}a');
      },
    );

    group('is written atomically', () {
      test(
        'rack_presets.json is never partially written at any instant',
        () async {
          final made = _make();
          await made.store.save(UserRackPresets(presets: [_mine('a')]));

          expectAtomicWrite(
            made.fs,
            target: _file,
            expected: await made.fs.readBytes(_file),
            what: 'rack_presets.json',
          );
          expect(made.fs.state.files.keys, [_file]);
        },
      );

      test('and neither is a second save over an existing file, which is '
          'what every rename or hide does', () async {
        final made = _make();
        await made.store.save(UserRackPresets(presets: [_mine('a')]));
        final previous = await made.fs.readBytes(_file);
        made.fs.resetJournal();

        await made.store.save(
          UserRackPresets(
            presets: [_mine('a')],
            hiddenSeedIds: const {'wallBox6U'},
          ),
        );

        expectAtomicWrite(
          made.fs,
          target: _file,
          previous: previous,
          expected: await made.fs.readBytes(_file),
          what: 'rack_presets.json',
        );
        expect(
          made.fs.state.files.keys,
          [_file],
          reason: 'keepBackup: false, so no backup file is left beside it',
        );
      });
    });

    test(
      'the persisted file is versioned, under the key prefs.json uses',
      () async {
        final made = _make();
        await made.store.save(const UserRackPresets());
        final raw =
            jsonDecode(utf8.decode(await made.fs.readBytes(_file)))!
                as Map<String, Object?>;
        expect(raw['version'], kUserRackPresetsFormatVersion);
      },
    );
  });
}
