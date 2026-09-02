// The connector compatibility matrix as a lookup (`#255`, `CON-001`).
//
// ═══════════════════════════════════════════════════════════════════════
// A LOOKUP TABLE, NOT A RULE EACH
// ═══════════════════════════════════════════════════════════════════════
// `#255` in its own words: *"CON-001 and SIG-002 both read it;
// duplicating the data into predicates is how the two drift apart."* So
// mating is one field on `ConnectorTypeDef` and the rules consult it.
//
// CANON AUTHORS `genderApplies` AND `contacts`; IT DOES NOT AUTHOR THIS.
// Canon §6.3's table is `id · display · genderApplies · contacts`, which
// is why `genderApplies` could land at M4-B as a pure transcription and
// why this one could not. Every row below is a judgement, so the three
// that were actually decided are pinned as their own tests rather than
// left to be inferred from the table.
//
// EMPTY IS UNKNOWN AND `CON-001` SKIPS IT (G4). Nine of the forty-nine
// are unseeded on purpose and the last test names them, so filling one in
// is what makes it fail. A rule that fired on an empty list would report
// a mating failure for every connector nobody has got to yet, which is a
// false FAIL on a half-seeded table.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// The nine ids with no mating set, and why each one has none.
///
/// Three have no connector to mate by construction and are already the
/// three `catalog_connectors.dart` exempts from footprints. Four are
/// termination or mounting systems rather than mating pairs. One is a
/// receptacle this catalogue does not seed, and one is a bus terminal.
const Map<String, String> _unseeded = <String, String>{
  'conn.unterminated': 'a cut end has no connector to mate',
  'conn.hardwired': 'a hardwired lead has no connector to mate',
  'conn.ground_lug': 'a lug takes a ring terminal or bare wire, not a mate',
  'conn.punchdown_110': 'an IDC termination, not a mating pair',
  'conn.keystone': 'a mounting standard; the INSERT mates, not the frame',
  'conn.sfp_cage': 'takes a transceiver module, which this model has not got',
  'conn.screw_terminal': 'wire under a screw',
  'conn.knx_terminal': 'a bus terminal',
  'conn.nema_l5_30p': 'its receptacle, NEMA L5-30R, is not seeded',
};

void main() {
  final registries = buildSeedRegistries();
  final connectors = registries.connectorTypes;

  group('the matrix is well formed', () {
    test('the seed has connectors at all, so the sweeps below are not '
        'passing over an empty map', () {
      expect(connectors, hasLength(greaterThan(40)));
    });

    test('every id a connector mates with is itself a registered '
        'connector', () {
      for (final def in connectors.values) {
        for (final mate in def.matesWith) {
          expect(
            connectors.containsKey(mate),
            isTrue,
            reason:
                '${def.id.v} mates ${mate.v}, which is not in the '
                'registry. CON-001 would ask a question about nothing',
          );
        }
      }
    });

    test('MATING IS SYMMETRIC: if A lists B then B lists A', () {
      final broken = <String>[];
      for (final def in connectors.values) {
        for (final mate in def.matesWith) {
          final other = connectors[mate];
          if (other == null) continue;
          if (!other.matesWith.contains(def.id)) {
            broken.add('${def.id.v} -> ${mate.v}');
          }
        }
      }
      expect(
        broken,
        isEmpty,
        reason:
            'one-way mating found: $broken. CON-001 would decide '
            'differently depending on which end the drag started at, so '
            'the same physical joint would validate two ways',
      );
    });

    test('a connector never lists the same mate twice', () {
      for (final def in connectors.values) {
        expect(
          def.matesWith.map((m) => m.v).toSet(),
          hasLength(def.matesWith.length),
          reason: def.id.v,
        );
      }
    });
  });

  group('the three calls that were actually decided', () {
    ConnectorTypeDef of(String id) => connectors[ConnectorTypeId(id)]!;

    test('PHYSICAL MATING ONLY: BNC 50 mates BNC 75, and RCA mates RCA 75', () {
      // They share a shell and they go together. The impedance mismatch
      // is a different fact and belongs to a different rule with its own
      // id and severity, which v1 does not ship. CON-001 answering "these
      // do not mate" would name the wrong defect and offer an adapter
      // that does not fix it.
      expect(
        of('conn.bnc50').matesWith,
        contains(const ConnectorTypeId('conn.bnc75')),
      );
      expect(
        of('conn.bnc75').matesWith,
        contains(const ConnectorTypeId('conn.bnc50')),
      );
      expect(
        of('conn.rca').matesWith,
        contains(const ConnectorTypeId('conn.rca75')),
      );
      expect(
        of('conn.rca75').matesWith,
        contains(const ConnectorTypeId('conn.rca')),
      );
    });

    test('PLUG AND RECEPTACLE EACH NAME THEIR COUNTERPART', () {
      for (final pair in <List<String>>[
        ['conn.iec_c13', 'conn.iec_c14'],
        ['conn.iec_c19', 'conn.iec_c20'],
        ['conn.nema_5_15p', 'conn.nema_5_15r'],
        ['conn.nema_5_20p', 'conn.nema_5_20r'],
      ]) {
        expect(
          of(pair[0]).matesWith,
          contains(ConnectorTypeId(pair[1])),
          reason: '${pair[0]} does not name ${pair[1]}',
        );
        expect(
          of(pair[1]).matesWith,
          contains(ConnectorTypeId(pair[0])),
          reason: '${pair[1]} does not name ${pair[0]}',
        );
      }
    });

    test('a 5-20R takes a 5-15P, which is the one asymmetry in the power '
        'set that is not a straight pair', () {
      expect(
        of('conn.nema_5_20r').matesWith,
        contains(const ConnectorTypeId('conn.nema_5_15p')),
      );
      expect(
        of('conn.nema_5_15r').matesWith,
        isNot(contains(const ConnectorTypeId('conn.nema_5_20p'))),
        reason: 'a 5-20P does not fit a 5-15R; the blade is turned',
      );
    });
  });

  group('what is deliberately unknown', () {
    test('exactly nine connectors have no mating set, and each is named '
        'with its reason', () {
      final empty = <String>[
        for (final def in connectors.values)
          if (def.matesWith.isEmpty) def.id.v,
      ]..sort();
      expect(
        empty,
        _unseeded.keys.toList()..sort(),
        reason:
            'the unseeded set changed. Filling one in is a deliberate '
            'act: add it to the catalogue AND delete its row here',
      );
    });

    test('everything else has one, so the table is not half-built by '
        'accident', () {
      final seeded = connectors.values.where((d) => d.matesWith.isNotEmpty);
      expect(seeded, hasLength(connectors.length - _unseeded.length));
    });
  });

  group('CR-117: the new field round-trips', () {
    test('a document carrying the seeded registry survives write(read(x))', () {
      final doc = RackDocument(
        id: const Uuid('doc-mates'),
        appVersion: '0.4.95',
        createdAt: DateTime.utc(2026, 9, 2),
        modifiedAt: DateTime.utc(2026, 9, 2),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026, 9, 2),
          updatedAt: DateTime.utc(2026, 9, 2),
          updatedBy: 'test',
        ),
      )..registries = buildSeedRegistries();

      const codec = JsonDocumentCodec();
      final first = codec.write(doc);
      final back = codec.read(first);
      expect(back, isA<Ok<RackDocument>>());
      expect(codec.write((back as Ok<RackDocument>).value), first);

      final rj45 =
          back.value.registries.connectorTypes[const ConnectorTypeId(
            'conn.rj45',
          )]!;
      expect(rj45.matesWith, [const ConnectorTypeId('conn.rj45')]);
    });

    test('an ABSENT key decodes as unknown rather than as an error, which '
        'is what keeps every file already on disk readable', () {
      const codec = JsonDocumentCodec();
      final doc = RackDocument(
        id: const Uuid('doc-old'),
        appVersion: '0.4.0',
        createdAt: DateTime.utc(2026, 9, 2),
        modifiedAt: DateTime.utc(2026, 9, 2),
        meta: EntityMeta(
          createdAt: DateTime.utc(2026, 9, 2),
          updatedAt: DateTime.utc(2026, 9, 2),
          updatedBy: 'test',
        ),
      );
      doc.registries.connectorTypes[const ConnectorTypeId(
        'conn.mystery',
      )] = const ConnectorTypeDef(
        id: ConnectorTypeId('conn.mystery'),
        displayName: 'Mystery',
      );
      final back = codec.read(codec.write(doc));
      expect(back, isA<Ok<RackDocument>>());
      final mystery = (back as Ok<RackDocument>)
          .value
          .registries
          .connectorTypes[const ConnectorTypeId('conn.mystery')]!;
      expect(mystery.matesWith, isEmpty);
    });
  });
}
