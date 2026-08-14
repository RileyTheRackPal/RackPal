// M4-B (board #173): `ConnectorTypeDef.pitch` and `.genderApplies`, both
// documented since M0 and declared by neither the Dart nor the codec
// until now.
//
// The two are authored on OPPOSITE principles and these tests hold each
// to its own: `genderApplies` is complete because canon §6.3 authors it
// for every id, and `pitch` is deliberately sparse because
// docs/catalog/seed-devices.md §5.2 states one for fourteen ids and
// inventing the rest is G4 breakage that reaches paper (AC-032).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// docs/catalog/seed-devices.md §5.2's Pitch column, transcribed. THIRTEEN
/// ROWS NAMING FOURTEEN IDS: `conn.rca` / `conn.rca75` share a row.
///
/// This map is the test's own copy of the corpus, deliberately: it is a
/// second source, so a value edited in `catalog_connectors.dart` alone
/// fails here rather than agreeing with itself. Two documents agreeing is
/// not verification; a document and an independent transcription of the
/// authority is closer.
const _statedPitchMm = <String, double>{
  'conn.hdmi_a': 19,
  'conn.rj45': 17,
  'conn.rca': 11,
  'conn.rca75': 11,
  'conn.xlr3': 27,
  'conn.f_type': 13,
  'conn.bnc75': 14,
  'conn.de9': 34,
  'conn.3_5mm_trs': 10,
  'conn.iec_c14': 30,
  'conn.nema_5_15r': 38,
  'conn.euroblock_3': 15,
  'conn.binding_post': 20,
  'conn.lc_duplex': 14,
};

/// Ids that INHERIT a pitch from a connector sharing their physical
/// shell, mapped to the id they inherit from (DR-057 §11.56.2). Every
/// pairing here is one `assets/catalog/sources.md` already makes for the
/// FOOTPRINT, so this ruling reuses an existing documented derivation
/// rather than adding a second kind.
///
/// Held as a relation and not as six more numbers, deliberately: the
/// test below asserts each inheritor EQUALS its source, so re-authoring
/// `conn.xlr3`'s pitch drags `conn.xlr5` with it or fails. Six duplicated
/// literals would silently drift apart, which is the whole failure mode
/// a shared-shell rule invites.
const _sharedShell = <String, String>{
  'conn.3_5mm_ts': 'conn.3_5mm_trs',
  'conn.xlr5': 'conn.xlr3',
  'conn.iec_c13': 'conn.iec_c14',
  'conn.nema_5_15p': 'conn.nema_5_15r',
  'conn.nema_5_20p': 'conn.nema_5_15r',
  'conn.nema_5_20r': 'conn.nema_5_15r',
};

/// Canon §6.3's "Gender applies" column, transcribed. Every id the
/// registry ships appears in exactly one of these two sets, which the
/// completeness test below asserts.
const _genderApplies = <String>{
  'conn.bnc75',
  'conn.bnc50',
  'conn.f_type',
  'conn.rca',
  'conn.rca75',
  'conn.hd15',
  'conn.mini_din4',
  'conn.xlr3',
  'conn.xlr5',
  'conn.rj45',
  'conn.lc_duplex',
  'conn.sc',
  'conn.st',
  'conn.de9',
  'conn.euroblock_2',
  'conn.euroblock_3',
  'conn.euroblock_5',
  'conn.phoenix_4',
  'conn.binding_post',
  'conn.banana',
  'conn.speakon_nl4',
  'conn.iec_c13',
  'conn.iec_c14',
  'conn.iec_c19',
  'conn.iec_c20',
  'conn.nema_5_15p',
  'conn.nema_5_15r',
  'conn.nema_5_20p',
  'conn.nema_5_20r',
  'conn.nema_l5_30p',
  'conn.barrel_dc',
};

const _genderDoesNotApply = <String>{
  'conn.hdmi_a',
  'conn.hdmi_c',
  'conn.hdmi_d',
  'conn.dp',
  'conn.mini_dp',
  'conn.usb_c',
  'conn.3_5mm_ts',
  'conn.3_5mm_trs',
  'conn.6_35mm_trs',
  'conn.jis_f05',
  'conn.sfp_cage',
  'conn.screw_terminal',
  'conn.knx_terminal',
  'conn.punchdown_110',
  'conn.keystone',
  'conn.hardwired',
  'conn.ground_lug',
  'conn.unterminated',
};

void main() {
  final conns = buildSeedConnectorFootprints();

  group('genderApplies is COMPLETE, because canon §6.3 authors it', () {
    test('canon covers every shipped connector and nothing else', () {
      final shipped = conns.keys.map((k) => k.v).toSet();
      final transcribed = {..._genderApplies, ..._genderDoesNotApply};
      expect(
        transcribed.difference(shipped),
        isEmpty,
        reason: 'canon §6.3 names ids the registry does not ship',
      );
      expect(
        shipped.difference(transcribed),
        isEmpty,
        reason:
            'the registry ships ids canon §6.3 does not rule on — a new '
            'connector needs a gender-applies answer before it ships, '
            'or CON-002 silently declines to evaluate for it',
      );
    });

    test('every connector carries canon §6.3 answer', () {
      for (final entry in conns.entries) {
        final id = entry.key.v;
        expect(
          entry.value.genderApplies,
          _genderApplies.contains(id),
          reason: '$id disagrees with canon §6.3',
        );
      }
    });

    test('the split is not vacuous in either direction', () {
      // A transcription that had drifted to all-true or all-false would
      // pass the per-id test above only if BOTH sets had drifted with it,
      // so this pins the shape against the registry rather than against
      // the constants.
      final trues = conns.values.where((c) => c.genderApplies).length;
      expect(trues, _genderApplies.length);
      expect(conns.length - trues, _genderDoesNotApply.length);
      expect(trues, greaterThan(0));
      expect(conns.length - trues, greaterThan(0));
    });

    test('CR-059 re-audit: a jack and a jack are both female', () {
      // The bug CR-059 exists to fix, expressed as the thing that must
      // now be expressible. The old five-value enum had `jack` and `plug`
      // as synonyms of `female` and `male`, so CON-002's "both ends the
      // same gender" never fired for jack+jack. With three values there
      // is one spelling per fact, and `conn.rj45` is a connector the rule
      // must evaluate for.
      expect(Gender.values, hasLength(3));
      expect(Gender.values, containsAll([Gender.male, Gender.female]));
      expect(conns[const ConnectorTypeId('conn.rj45')]!.genderApplies, isTrue);
      // And a connector the rule must NOT evaluate for, or every HDMI
      // run in the catalog reports a false CON-002.
      expect(
        conns[const ConnectorTypeId('conn.hdmi_a')]!.genderApplies,
        isFalse,
      );
    });
  });

  group('pitch is DELIBERATELY SPARSE', () {
    test('every stated pitch matches §5.2 exactly', () {
      for (final entry in _statedPitchMm.entries) {
        final def = conns[ConnectorTypeId(entry.key)];
        expect(def, isNotNull, reason: '${entry.key} is not in the registry');
        expect(
          def!.pitch,
          Len.fromMillimetres(entry.value),
          reason: '${entry.key} does not match docs/catalog §5.2',
        );
      }
    });

    test('a shared shell inherits its partner exactly, not a copy', () {
      for (final entry in _sharedShell.entries) {
        final inheritor = conns[ConnectorTypeId(entry.key)];
        final source = conns[ConnectorTypeId(entry.value)];
        expect(inheritor, isNotNull, reason: '${entry.key} is not shipped');
        expect(source, isNotNull, reason: '${entry.value} is not shipped');
        expect(
          source!.pitch,
          isNotNull,
          reason:
              '${entry.value} must carry a stated pitch for ${entry.key} '
              'to inherit one',
        );
        expect(
          inheritor!.pitch,
          source.pitch,
          reason:
              '${entry.key} shares a shell with ${entry.value} and must '
              'carry the same pitch (DR-057 §11.56.2)',
        );
      }
    });

    test('NOTHING ELSE HAS A PITCH, which is the assertion that matters', () {
      // The failure this guards is not a wrong number, it is a plausible
      // one: somebody fills in `conn.usb_c` from a formula because the
      // remaining nulls look like an oversight. They are not, and DR-057
      // §11.56.3 makes them permanent. An added pitch arrives with a row
      // in docs/catalog §5.2 and an entry above, or it does not arrive.
      final invented = <String>[];
      for (final entry in conns.entries) {
        final id = entry.key.v;
        if (entry.value.pitch != null &&
            !_statedPitchMm.containsKey(id) &&
            !_sharedShell.containsKey(id)) {
          invented.add(id);
        }
      }
      expect(
        invented,
        isEmpty,
        reason:
            'these carry a pitch the corpus does not state: $invented. A '
            'guessed pitch draws a rear panel wrong to scale on the one '
            'view that gets taped inside the rack door (G4, AC-032).',
      );
    });

    test('a connector with no panel cutout has no pitch, for one reason', () {
      // `pitch == null` has TWO causes and M4-K must tell them apart:
      // unauthored (unknown, and it falls back to `footprintWidth +
      // gutter` per DR-057 §11.56.4) versus no cutout at all (these
      // three, which are SKIPPED, because a hardwired lead occupies no
      // panel width and a fallback would reserve space for nothing).
      // The distinction is `kFootprintExemptConnectors`, already drawn
      // for footprints and reused rather than re-invented.
      for (final id in kFootprintExemptConnectors) {
        final def = conns[ConnectorTypeId(id)];
        expect(def, isNotNull);
        expect(def!.pitch, isNull, reason: '$id has no cutout to space');
        expect(def.footprintWidth, isNull);
      }
    });
  });

  group('the codec carries both, without moving the format', () {
    test('a pitched, gendered connector round-trips', () {
      final doc = _docWith(
        ConnectorTypeDef(
          id: const ConnectorTypeId('conn.probe'),
          displayName: 'Probe',
          footprintWidth: Len.fromMillimetres(10),
          footprintHeight: Len.fromMillimetres(10),
          pitch: Len.fromMillimetres(14),
          genderApplies: true,
        ),
      );
      const codec = JsonDocumentCodec();
      final back = codec.read(codec.write(doc));
      final def = switch (back) {
        Ok(:final value) =>
          value.registries.connectorTypes[const ConnectorTypeId('conn.probe')],
        Err() => null,
      };
      expect(def, isNotNull);
      expect(def!.pitch, Len.fromMillimetres(14));
      expect(def.genderApplies, isTrue);
    });

    test('an UNAUTHORED connector writes neither key', () {
      // CR-117: `registries` is serialized into every document, so a key
      // written unconditionally would appear in every connector entry of
      // every file already on disk and break `write(read(bytes)) ==
      // bytes` for files a user cannot regenerate. This is why
      // `kSchemaVersion` does not move.
      final doc = _docWith(
        const ConnectorTypeDef(
          id: ConnectorTypeId('conn.probe'),
          displayName: 'Probe',
        ),
      );
      final tree = const JsonDocumentCodec().encodeToJsonTree(doc);
      // `registries` is nested under `document`, and `connectorTypes`
      // serializes under the wire name `connectors`. Both are file-shape
      // gotchas this repo has tripped over before, so they are spelled
      // out here rather than reached for with a helper.
      final document = tree['document']! as Map<String, Object?>;
      final registries = document['registries']! as Map<String, Object?>;
      final connectors = registries['connectors']! as Map<String, Object?>;
      final probe = connectors['conn.probe']! as Map<String, Object?>;
      expect(probe.containsKey('pitchNm'), isFalse);
      expect(probe.containsKey('genderApplies'), isFalse);
    });
  });
}

RackDocument _docWith(ConnectorTypeDef def) {
  final doc = RackDocument(
    id: const Uuid('doc-connector-fields-test'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      updatedBy: 'seed',
    ),
  );
  doc.registries.connectorTypes[def.id] = def;
  return doc;
}
