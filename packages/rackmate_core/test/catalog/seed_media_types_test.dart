// M3-C/6, #582 — canon §6.5's shipped cable types, seeded (DR-010
// §11.10.1).
//
// WHAT THESE TESTS ARE FOR. docs/07 §5.1 asks for exactly one of them by
// name: "Every target above resolves ... a CI assertion enforces it for
// every `media.*` ... appearing in any document". That assertion did not
// exist and could not have passed, because `Registries.mediaTypes` was
// empty in every document the product has ever written. The alias block
// is transcribed here from the doc rather than read out of the code, so
// this is a cross-check of two sources and not a restatement of one.
//
// The rest pin the three things a later reader would otherwise have to
// re-derive: that 34 rows means 38 types, that thirty absent lengths are
// G4 and not thirty gaps, and that adding `shortTag`/`aliases` did not
// move any existing document's bytes.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// docs/07 §5.1's synonym block, transcribed. Left of the arrow, in the
/// doc's own spelling and order.
const Map<String, List<String>> _docs07Synonyms = {
  'media.cat6': ['cat6', 'cat-6', 'c6', 'cat6 utp'],
  'media.cat6a_futp': ['cat6a', 'c6a', 'f/utp'],
  'media.cat5e': ['cat5e', 'c5e', 'cat5'],
  'media.rg6': ['rg6', 'rg-6', 'coax'],
  'media.rg6_quad': ['rg6q', 'quad shield'],
  'media.16_2': ['16/2', '16-2', 'spkr 16/2'],
  'media.16_4': ['16/4', '16-4'],
  'media.14_2': ['14/2', '14-2'],
  'media.14_4': ['14/4', '14-4'],
  'media.22_4': ['22/4', 'control', 'keypad'],
  'media.22_2': ['22/2'],
  'media.os2': ['os2', 'smf', 'single mode'],
  'media.conduit_ent': ['conduit', 'smurf', 'ent'],
};

void main() {
  final seeded = buildSeedMediaTypes();

  group('the shipped table', () {
    test("is 38 media types, not canon §6.5's 34 ROWS", () {
      // THE COUNT THAT IS EASY TO GET WRONG, and the reason it is stated
      // as a test: four rows carry two ids each on one line, joined by
      // `·`. Reading the table as 34 types silently drops `media.14_4`,
      // `media.22_2`, `media.om4` and `media.conduit_ent` — and docs/07
      // §5.1 resolves synonyms to three of those four.
      expect(seeded, hasLength(38));
    });

    test('splits all four of the paired rows into two distinct types', () {
      // docs/07 §5.1 states the cost of folding them: "mapping `14/4` to
      // a 16 AWG media type changes the gauge and the footage rollup".
      for (final pair in const [
        ['media.14_2', 'media.14_4'],
        ['media.22_2', 'media.22_4'],
        ['media.om3', 'media.om4'],
        ['media.conduit_emt', 'media.conduit_ent'],
      ]) {
        final a = seeded[MediaTypeId(pair[0])];
        final b = seeded[MediaTypeId(pair[1])];
        expect(a, isNotNull, reason: '${pair[0]} is missing');
        expect(b, isNotNull, reason: '${pair[1]} is missing');
        expect(a!.displayName, isNot(b!.displayName));
        expect(a.shortTag, isNot(b.shortTag));
      }
    });

    test('every entry is keyed by its own id', () {
      // A transcription slip that copies a row and edits the display name
      // but not the id would otherwise silently drop a type.
      for (final e in seeded.entries) {
        expect(e.key, e.value.id);
      }
    });

    test('carries a short tag on all 38, because canon has no blank in '
        'that column', () {
      final missing = [
        for (final d in seeded.values)
          if (d.shortTag == null || d.shortTag!.isEmpty) d.id.v,
      ];
      expect(missing, isEmpty);
    });

    test('is deterministic across calls', () {
      final a = buildSeedMediaTypes();
      final b = buildSeedMediaTypes();
      expect(a.keys.toList(), b.keys.toList());
    });
  });

  group("docs/07 §5.1's synonym block — the CI assertion the doc asks for", () {
    test('every target in the block resolves to a seeded media type', () {
      // The sentence this discharges reads "Every target above resolves
      // in `assets/catalog/registries.json`". That file has never
      // existed; DR-010 §11.10.1 made the master seeded Dart, so THIS is
      // where the claim becomes true.
      final unresolved = [
        for (final id in _docs07Synonyms.keys)
          if (!seeded.containsKey(MediaTypeId(id))) id,
      ];
      expect(unresolved, isEmpty);
    });

    test('every synonym the doc lists is carried by its target', () {
      final wrong = <String>[];
      for (final e in _docs07Synonyms.entries) {
        final def = seeded[MediaTypeId(e.key)]!;
        for (final alias in e.value) {
          if (!def.aliases.contains(alias)) wrong.add('${e.key} lacks $alias');
        }
      }
      expect(wrong, isEmpty);
    });

    test('and carries NO synonym the doc does not list, so the table is '
        'transcribed rather than extended', () {
      // The failure this guards is invention by symmetry:
      // `media.cat6_futp` looks like it should have `c6s`, and
      // `media.conduit_emt` like it should have `emt`. Neither is in the
      // source. RJ-009 is the corpus's own answer to an unanticipated
      // spelling — an unmatched import value creates a new user media
      // type, never a rejected row.
      final extra = <String>[];
      for (final d in seeded.values) {
        final allowed = _docs07Synonyms[d.id.v] ?? const <String>[];
        for (final alias in d.aliases) {
          if (!allowed.contains(alias)) extra.add('${d.id.v} invents $alias');
        }
      }
      expect(extra, isEmpty);
    });

    test('no synonym is claimed by two media types', () {
      // docs/07 §5.1: "a wrong target here is a silent data-quality
      // failure, not a loud one". An alias owned twice makes resolution
      // order decide what cable an installer pulls.
      final owner = <String, String>{};
      final clashes = <String>[];
      for (final d in seeded.values) {
        for (final alias in d.aliases) {
          final prior = owner[alias];
          if (prior != null) {
            clashes.add('$alias claimed by $prior and ${d.id.v}');
          }
          owner[alias] = d.id.v;
        }
      }
      expect(clashes, isEmpty);
    });

    test("the four media in §4.3's worked drop line are all reachable", () {
      // `Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4`. Asserted
      // against the DATA rather than through a resolver, because the
      // resolver is #147 and this is what it will have to resolve
      // against. Lower-cased on the way in, which is the only
      // normalisation the block's own spellings require.
      for (final token in const ['cat6', 'rg6', '16/4', '22/4']) {
        final hit = seeded.values.where((d) => d.aliases.contains(token));
        expect(hit, hasLength(1), reason: '$token resolves to ${hit.length}');
      }
    });
  });

  group('max channel length is transcribed, never estimated (G4, CR-114)', () {
    test('exactly the seven a standard fixes carry a length', () {
      // TIA-568's 100 m balanced-twisted-pair channel on the four Cat
      // grades, AES3's 100 m, ANSI E1.11's 1200 m, KNX TP1's 1000 m.
      //
      // `media.os2` is NOT among them and is the near miss worth naming:
      // canon gives it `10–40 km`, which is a range across singlemode
      // optics rather than a figure a standard fixes.
      final withLength = [
        for (final d in seeded.values)
          if (d.maxRunLengthPassive != null) d.id.v,
      ]..sort();
      expect(withLength, [
        'media.aes_110',
        'media.cat5e',
        'media.cat6',
        'media.cat6_futp',
        'media.cat6a_futp',
        'media.dmx_120',
        'media.knx_tp1',
      ]);
    });

    test('the hedged rows are ABSENT rather than rounded', () {
      // Canon writes `~150 m` for RG6, `100 m+` for mic cable,
      // `gauge/length table` for 16/2, `long` for 22/4. A `Len` holding
      // 150 m would print an exact figure on a termination schedule an
      // installer buys cable from, and the tilde — the whole content of
      // the hedge — would be gone.
      for (final id in const [
        'media.rg6',
        'media.mic_stp',
        'media.16_2',
        'media.22_4',
        'media.hdmi_passive',
        'media.cresnet_18_22',
      ]) {
        expect(
          seeded[MediaTypeId(id)]!.maxRunLengthPassive,
          isNull,
          reason: '$id has a hedged length in canon and must stay unknown',
        );
      }
    });

    test('nothing carries an active-run length, which is a gap and not a '
        'zero', () {
      // Canon §6.5 has one `Max channel` column. `maxRunLengthActive` is
      // a separate M0 field with no source column, so it stays null on
      // all 38 rather than being filled from the passive one.
      expect(
        seeded.values.where((d) => d.maxRunLengthActive != null),
        isEmpty,
      );
    });
  });

  group('isPathwayOnly — conduit is not a cable (CR-109, M3-E/1)', () {
    test('exactly the three canon §6.5 marks carry the flag', () {
      // EXACTLY, not "at least". A fourth would silently stop creating
      // `Link`s for a medium somebody pulls, and a missing one would put
      // a port on a smurf tube — CR-109's own rejected alternative,
      // "which produces a port you can wire an HDMI cable into".
      expect(
        seeded.values.where((d) => d.isPathwayOnly).map((d) => d.id.v).toSet(),
        {'media.conduit_emt', 'media.conduit_ent', 'media.pull_string'},
      );
    });

    test('and every cable is false, including the ones that sound like '
        'conduit', () {
      // `media.innerduct` and friends do not exist, but the failure this
      // guards is a future medium named for where it goes rather than
      // what it is. 35 of 38 is the arithmetic.
      expect(seeded.values.where((d) => !d.isPathwayOnly), hasLength(35));
    });

    test('the flag is not yet READ, and that is a stated gap', () {
      // Seeding is half of CR-109. The drop line and the matrix still
      // make `Link`s out of conduit, which docs/07 §5.2 shows the
      // importer must not do. This case exists so the day a planner
      // branches on the flag, somebody deletes it deliberately rather
      // than discovering the product had two behaviours for one medium.
      final conduit = seeded[const MediaTypeId('media.conduit_ent')]!;
      expect(conduit.isPathwayOnly, isTrue);
      expect(
        conduit.aliases,
        contains('conduit'),
        reason:
            'a drop line saying `1x conduit` still resolves to this '
            'medium and still makes a Link today',
      );
    });
  });

  group('what a new document gets', () {
    test('buildSeedRegistries now carries the media types', () {
      expect(buildSeedRegistries().mediaTypes, hasLength(38));
    });

    test("ProjectSettings' default network media resolves, which it never "
        'did before', () {
      // `media.cat6a_futp` has been the shipped default since M0 and
      // pointed at nothing.
      expect(
        buildSeedRegistries().mediaTypes[ProjectSettings().defaultNetworkMedia],
        isNotNull,
      );
    });

    test('jacketOptions is empty on all 38, because canon gives it no '
        'column', () {
      // Declared rather than left to be discovered: §6.5 names
      // `availableJackets[]` in its field list and prints no column for
      // it, so there is nothing to transcribe and nothing reads it.
      expect(
        seeded.values.where((d) => d.jacketOptions.isNotEmpty),
        isEmpty,
      );
    });
  });
}
