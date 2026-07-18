// The v0 -> v1 migration fixture (docs/03-architecture.md §9.2, CR-093,
// CR-094) — this milestone's own exit criterion: "one v0->v1 migration
// fixture in the golden corpus". v0 called the root envelope's `sequence`
// counter `revision` instead (the synthetic reenactment of CR-094's real,
// documented rename); `migrateV0ToV1` renames the key and bumps
// `schemaVersion`. Also covers the `minReaderVersion > kSchemaVersion`
// refusal case.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

typedef _JsonMap = Map<String, Object?>;

_JsonMap _minimalDocumentBody() => {
  'info': {'projectName': 'V0 Fixture'},
  'settings': {
    'displayUnits': 'imperial',
    'defaultRuNumbering': 'bottomUpFromOne',
    'defaultMirrorRearElevation': true,
    'sheetNumbering': 'simple',
    'deviceDesignatorFormat': '{TYPE_PREFIX}{SEP}{SEQ}',
    'portDesignatorFormat': 'J{PORT_SEQ:2}',
    'linkDesignatorFormat': 'W{SEQ:3}',
    'netNameFormat': 'N{SEQ:3}',
    'outletFieldLabelFormat': '{ROOM_ABBR}-{SERVICE}-{SEQ}',
    'outletRackLabelFormat': '{FLOOR}{SPACE}-{PANEL}{PORT:2}',
    'designatorSeparator': '-',
    'designatorPad': 0,
    'collisionPolicy': 'suffixLetter',
    'designatorBlockSize': 100,
    'ruleOverrides': <String, Object?>{},
    'familyColorOverrides': <String, Object?>{},
    'diversityFactorsByCategory': <String, Object?>{},
    'cableWasteFactor': 100,
    'defaultNetworkMedia': 'media.cat6a_futp',
    'defaultRackHeightU': 12,
    'defaultLineVolts': 120,
  },
  'locations': <String, Object?>{},
  'racks': <String, Object?>{},
  'devices': <String, Object?>{},
  'ports': <String, Object?>{},
  'nets': <String, Object?>{},
  'links': <String, Object?>{},
  'pathways': <String, Object?>{},
  'outlets': <String, Object?>{},
  'structures': <String, Object?>{},
  'circuits': <String, Object?>{},
  'sheets': <String, Object?>{},
  'notes': <String, Object?>{},
  'ackedFindings': <String, Object?>{},
  'templates': <String, Object?>{},
  'registries': {
    'signalDomains': <String, Object?>{},
    'signalFamilies': <String, Object?>{},
    'connectors': <String, Object?>{},
    'media': <String, Object?>{},
    'cableSpecs': <String, Object?>{},
    'outletTemplates': <String, Object?>{},
  },
  'revisionBlock': <Object?>[],
  'tombstones': <String, Object?>{},
  'meta': {
    'createdAt': '2025-01-01T00:00:00.000000Z',
    'updatedAt': '2025-01-01T00:00:00.000000Z',
    'updatedBy': 'v0migration',
    'localRevision': 0,
    'unknown': <String, Object?>{},
  },
};

/// A v0 file: `schemaVersion: 0`, and the root envelope's sync-cursor
/// counter spelled `"revision"` rather than v1's `"sequence"` (CR-094).
_JsonMap _v0Fixture() => {
  'generator': 'RackMate',
  'id': 'v0-migration-fixture',
  'appVersion': '0.0.9',
  'createdAt': '2025-01-01T00:00:00.000000Z',
  'modifiedAt': '2025-01-01T00:00:00.000000Z',
  'schemaVersion': 0,
  'minReaderVersion': 0,
  'revision': 5,
  'document': _minimalDocumentBody(),
};

void main() {
  group('v0 -> v1 migration fixture (CR-093, CR-094)', () {
    test('migrateToCurrent renames "revision" to "sequence"', () {
      final result = migrateToCurrent(_v0Fixture());

      expect(result, isA<Ok<MigratedDoc>>());
      final migrated = (result as Ok<MigratedDoc>).value;

      expect(migrated.raw['sequence'], 5);
      expect(migrated.raw.containsKey('revision'), isFalse);
      expect(migrated.raw['schemaVersion'], kSchemaVersion);
      expect(result.openReadOnly, isFalse);
    });

    test('end-to-end: JsonDocumentCodec.read opens a real v0 file', () {
      const jsonCodec = JsonDocumentCodec();
      final v0Bytes = Uint8List.fromList(utf8.encode(jsonEncode(_v0Fixture())));

      final result = jsonCodec.read(v0Bytes);

      expect(result, isA<Ok<RackDocument>>());
      final doc = (result as Ok<RackDocument>).value;
      expect(doc.sequence, 5);
      expect(doc.schemaVersion, kSchemaVersion);
      expect(doc.info.projectName, 'V0 Fixture');
    });
  });

  group('minReaderVersion newer than this build refuses (CR-093)', () {
    test('produces Err(NewerSchemaError) rather than opening', () {
      final raw = _v0Fixture()
        ..['minReaderVersion'] = 999
        ..['schemaVersion'] = 999;

      final result = migrateToCurrent(raw);

      expect(result, isA<Err<MigratedDoc>>());
      expect((result as Err<MigratedDoc>).error, isA<NewerSchemaError>());
    });
  });

  group('generator mismatch (CR-092)', () {
    test('produces Err(NotARackMateFileError)', () {
      final raw = _v0Fixture()..['generator'] = 'SomeOtherApp';

      final result = migrateToCurrent(raw);

      expect(result, isA<Err<MigratedDoc>>());
      expect((result as Err<MigratedDoc>).error, isA<NotARackMateFileError>());
    });
  });
}
