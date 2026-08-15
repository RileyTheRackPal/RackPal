// DR-060 §11.59's gate: the alias seed, and the two-registry resolution
// it exists to serve.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS FILE IS FOR, AND WHY IT IS NOT A LIST OF EXPECTED PAIRS
// ═════════════════════════════════════════════════════════════════════
// The temptation with seeded vocabulary is a table of "token → id" rows
// copied out of the ruling. That test passes for as long as someone
// keeps two lists in step and tells you nothing the ruling did not
// already say. `assert the artifact, not the mechanism`.
//
// So the properties below are the ones a DSL user would notice breaking:
//
//   (a) NO TOKEN IS AMBIGUOUS. `resolveSignalFamilyToken` walks a map
//       and returns the first hit, so two families sharing an alias
//       would resolve by SEED ORDER, silently, and a reorder of the
//       catalog would change what `hdbt` means. Determinism is an
//       invariant in this repository; a first-hit walk over a
//       non-unique key is how it gets lost.
//   (b) EVERY SEEDED ALIAS RESOLVES TO THE FAMILY THAT DECLARES IT.
//       An alias that is shadowed by an earlier step of the chain is
//       dead data that reads as live, which is the exact defect
//       §11.59.5 removed `hdbt` from the connector table for.
//   (c) THE THIRTEEN-STEP PATH'S TOKENS ALL LAND. docs/06 §9.1 is what
//       the milestone's exit criterion is measured against, so its
//       vocabulary is checked against the registry rather than against
//       a second copy of itself.
//   (d) `c13` AND `c14` DISAGREE ABOUT THE CONNECTOR AND AGREE ABOUT
//       THE FAMILY, which is the case that killed the first draft of
//       the ruling and the reason the two registries answer separately.
//   (e) AN AMBIGUOUS TOKEN REFUSES. `xlr` names four families and the
//       resolver must decline rather than pick, because null is unknown
//       and never estimated (G4, CR-114).

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  final registries = buildSeedRegistries();
  final families = registries.signalFamilies;
  final connectors = registries.connectorTypes;

  group('the alias seed is unambiguous (DR-060 §11.59.4)', () {
    test('no two signal families declare the same alias', () {
      final owner = <String, String>{};
      final clashes = <String>[];
      for (final f in families.values) {
        for (final a in f.aliases) {
          final key = normaliseMediaToken(a);
          final prior = owner[key];
          if (prior != null) {
            clashes.add('"$a" on both $prior and ${f.id.v}');
          }
          owner[key] = f.id.v;
        }
      }
      expect(
        clashes,
        isEmpty,
        reason:
            'a first-hit walk over a duplicated '
            "alias resolves by seed order, so the catalog's ORDER would "
            'silently decide what the token means',
      );
    });

    test('no two connector types declare the same alias', () {
      final owner = <String, String>{};
      final clashes = <String>[];
      for (final c in connectors.values) {
        for (final a in c.aliases) {
          final key = normaliseMediaToken(a);
          final prior = owner[key];
          if (prior != null) clashes.add('"$a" on both $prior and ${c.id.v}');
          owner[key] = c.id.v;
        }
      }
      expect(clashes, isEmpty);
    });

    test("no family alias is some OTHER family's id, tag or tail", () {
      // Shadowing in the other direction: an alias that duplicates a
      // token the later steps already resolve is harmless when it is
      // the SAME family and a silent override when it is not.
      final problems = <String>[];
      for (final f in families.values) {
        for (final a in f.aliases) {
          final hit = resolveSignalFamilyToken(registries, a);
          if (hit == null || hit.id != f.id) {
            problems.add(
              '"$a" declared on ${f.id.v} resolves to '
              '${hit?.id.v ?? 'nothing'}',
            );
          }
        }
      }
      expect(problems, isEmpty);
    });
  });

  group('the chain still answers what it answered before (DR-025)', () {
    // §11.59.4 puts aliases at the HEAD of the chain, so the risk this
    // group covers is a new alias stealing a token the old three steps
    // already resolved correctly.
    test('shortTag, id tail and displayName all still land', () {
      expect(
        resolveSignalFamilyToken(registries, 'hbt')?.id.v,
        'video.hdbaset',
        reason: 'shortTag',
      );
      expect(
        resolveSignalFamilyToken(registries, 'hdbaset')?.id.v,
        'video.hdbaset',
        reason: 'id tail',
      );
      expect(
        resolveSignalFamilyToken(registries, 'avoip')?.id.v,
        'video.avoip',
        reason: 'id tail',
      );
      expect(
        resolveSignalFamilyToken(registries, 'dante')?.id.v,
        'audio.dante',
        reason: 'id tail',
      );
      expect(
        resolveSignalFamilyToken(registries, 'ethernet')?.id.v,
        'net.ethernet',
        reason: 'id tail',
      );
      expect(
        resolveSignalFamilyToken(registries, 'S-Video')?.id.v,
        'video.svideo',
        reason: 'displayName, and it normalises',
      );
    });
  });

  group('docs/06 §9.1, the thirteen steps the exit criterion measures', () {
    // Each row is one step's token and what the walkthrough says it
    // must produce. The FAMILY half and the CONNECTOR half are asserted
    // separately because §11.59.4 resolves them separately.
    const path = <String, (String?, String)>{
      // token   : (family or null when the token names no family, connector)
      'hdmi': ('video.hdmi.2_0', 'conn.hdmi_a'),
      'hdbt': ('video.hdbaset', 'conn.rj45'),
      'ir35': ('ctl.ir_emitter', 'conn.3_5mm_ts'),
      'rj45': ('net.ethernet', 'conn.rj45'),
      'de9': ('ctl.rs232', 'conn.de9'),
      'c14': ('power.ac_iec', 'conn.iec_c14'),
    };

    for (final row in path.entries) {
      final token = row.key;
      final want = row.value;
      test('"$token" resolves as the walkthrough types it', () {
        final family = resolveSignalFamilyToken(registries, token);
        expect(family?.id.v, want.$1, reason: 'family half of "$token"');

        // The connector half: a named connector wins, and the family's
        // default fills in only when the token named none.
        final named = resolveConnectorToken(registries, token);
        final resolved = named?.id ?? family?.defaultConnector;
        expect(resolved?.v, want.$2, reason: 'connector half of "$token"');
      });
    }

    test('the whole 68-port vocabulary resolves to something', () {
      // Step 8 reuses `hdmi`, steps 9 and 12 reuse `ir35`; the set is
      // what is distinct across the thirteen.
      for (final token in path.keys) {
        expect(
          resolveSignalFamilyToken(registries, token),
          isNotNull,
          reason: '"$token" is typed in docs/06 §9.1 and must resolve',
        );
      }
    });
  });

  group('a default connector loses to a named one (§11.59.4)', () {
    // THE CASE THAT KILLED THE FIRST DRAFT. A rack PDU has C13 outlets
    // and a C14 inlet. Both are `power.ac_iec`, because CR-058 makes
    // inlet/outlet a `PortPowerSpec.role` rather than a family. One
    // first-hit chain would have given both the family's default
    // connector, `conn.iec_c14`, and authored every outlet on every
    // power strip in the catalog with an inlet.
    test('c13 and c14 share a family and differ in connector', () {
      final c13Family = resolveSignalFamilyToken(registries, 'c13');
      final c14Family = resolveSignalFamilyToken(registries, 'c14');
      expect(c13Family?.id.v, 'power.ac_iec');
      expect(c14Family?.id.v, c13Family?.id.v, reason: 'same family');

      expect(resolveConnectorToken(registries, 'c13')?.id.v, 'conn.iec_c13');
      expect(resolveConnectorToken(registries, 'c14')?.id.v, 'conn.iec_c14');

      // And the family's own default is the C14, which is exactly why
      // the C13 must come from the connector table and not from here.
      expect(c13Family?.defaultConnector.v, 'conn.iec_c14');
    });
  });

  group('unknown is unknown, never estimated (G4 / CR-114)', () {
    test('xlr names a connector and refuses to name a family', () {
      // An XLR3 carries audio.line_bal, audio.mic, audio.aes3 or
      // ctl.dmx512. The token does not say which, so the family half
      // comes back null and the port is created with the cell blank.
      expect(resolveConnectorToken(registries, 'xlr')?.id.v, 'conn.xlr3');
      expect(resolveSignalFamilyToken(registries, 'xlr'), isNull);
    });

    test('euro2 names a connector and refuses to name a family', () {
      // Low-Z speaker or constant-voltage; guessing puts 70 V on an
      // 8 ohm run.
      expect(
        resolveConnectorToken(registries, 'euro2')?.id.v,
        'conn.euroblock_2',
      );
      expect(resolveSignalFamilyToken(registries, 'euro2'), isNull);
    });

    test('a token in neither registry answers null on both halves', () {
      expect(resolveSignalFamilyToken(registries, 'flugelbinder'), isNull);
      expect(resolveConnectorToken(registries, 'flugelbinder'), isNull);
    });

    test('an empty token answers null rather than the first entry', () {
      expect(resolveSignalFamilyToken(registries, '   '), isNull);
      expect(resolveConnectorToken(registries, ''), isNull);
    });
  });

  group('hdbt left the connector table (§11.59.5)', () {
    test('conn.rj45 no longer claims hdbt', () {
      expect(
        connectors[const ConnectorTypeId('conn.rj45')]!.aliases,
        isNot(contains('hdbt')),
      );
    });

    test('and rj45 stayed, because the grid PRINTS aliases.first', () {
      // `portConnectorShortLabel` renders `aliases.first.toUpperCase()`
      // in the port grid's CONN column and footer. Deleting this entry
      // would turn every RJ45 cell M4-E shipped into a display name,
      // which no test of the alias set itself would have noticed.
      expect(
        portConnectorShortLabel(
          registries,
          const ConnectorTypeId('conn.rj45'),
        ),
        'RJ45',
      );
    });
  });
}
