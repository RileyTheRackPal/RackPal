// M3-C/4, #150 — CR-108's outlet templates, seeded (DR-010 §11.10.1).
//
// WHAT THESE TESTS ARE FOR. `registries.outletTemplates` was `{}` in
// every document the product has ever written, while seventeen outlets
// in the shipped whole-house starter named ids inside it. These prove
// the references now resolve, that every id the seed mentions resolves
// in the registries beside it, and that DR-023's chain reaches the
// corpus's own worked label — which the planner suite has been asserting
// it CANNOT do, in as many words, since M3-C/1.
//
// The tags are cross-checked against field labels transcribed from the
// corpus rather than read out of the seed, so this is two sources
// agreeing and not one source restated.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// Field labels the corpus prints, and the template each one names.
/// Transcribed from the documents, left of the arrow in their own
/// spelling. `{ROOM_ABBR}-{SERVICE}-{SEQ}`, so the middle segment is the
/// tag DR-022 ruled on.
const Map<String, String> _workedLabels = {
  // canon §11.21 / docs/07 §8's label table — the three DR-022 names.
  'LR-TV-1': 'outlet.tv_location',
  'MBR-KEY-2': 'outlet.keypad',
  'EXT-CAM-4': 'outlet.camera',
  // docs/07 §4's own drop table.
  'LR-SPK-1': 'outlet.ceiling_speaker_pair',
  'LR-DATA-1': 'outlet.data_only',
  // docs/08 §3.8's rendered Pull Sheet.
  'KIT-AP-1': 'outlet.ap',
};

String _serviceSegment(String label) => label.split('-')[1];

void main() {
  final seeded = buildSeedOutletTemplates();

  group('the six CR-108 names and the three grades', () {
    test('nine templates, and the six the ruling names are there', () {
      // Canon §1673: "TV location · AP · Keypad · Ceiling speaker pair ·
      // Camera · Data-only, *and* with TIA-570-D Grade 1/2/3."
      expect(seeded, hasLength(9));
      expect(seeded.keys, containsAll(_workedLabels.values));
    });

    test('the ids are the ones seventeen outlets already point at', () {
      // Transcribed from `whole_house.rmpj`, not chosen here. Five of the
      // six were already in use against an empty map; `outlet.keypad` is
      // the only id this seed named first.
      expect(
        seeded.keys,
        containsAll([
          'outlet.tv_location',
          'outlet.ap',
          'outlet.camera',
          'outlet.data_only',
          'outlet.ceiling_speaker_pair',
        ]),
      );
    });

    test('every template id resolves through the seed master', () {
      // The property the seventeen dangling references did not have.
      final registries = buildSeedRegistries();
      for (final id in seeded.keys) {
        expect(
          registries.outletTemplates[id],
          isNotNull,
          reason: '$id is not in a new document',
        );
      }
    });
  });

  group("the tags are the corpus's own labels", () {
    test("each worked label's service segment is its template's tag", () {
      // DR-022 §11.21.4: authored beside the name, never derived from it.
      // "TV location" does not truncate to TV, KEY and CAM by any one
      // rule, which is why the tag is stored rather than computed.
      for (final entry in _workedLabels.entries) {
        expect(
          seeded[entry.value]!.tag,
          _serviceSegment(entry.key),
          reason: '${entry.value} must render ${entry.key}',
        );
      }
    });

    test('KEYPAD is KEY, which is the spelling canon prints', () {
      // The census found three: `MBR-KEY-2` (canon §11.21, docs/07 §8),
      // `KIT-KP-1`/`GR-KP-4` (docs/08, design-ux-schematic) and
      // `MBR-KY-2` (design-ux-schematic). Canon is normative and the
      // derived sheets are owed the edit; pinned so the next reader who
      // meets `KP` knows which way the disagreement was resolved.
      expect(seeded['outlet.keypad']!.tag, 'KEY');
    });

    test('CEILING SPEAKER PAIR is SPK, and the other two readings lose', () {
      // A three-way split. docs/07 §4's labelled table prints
      // `LR-SPK-1` in FIELD LABEL with `CLG` in the OUTLET column beside
      // it, so docs/08's `GR-CLG-1` is an outlet designation that
      // wandered into the service segment. The whole-house fixture's
      // `GR-AUD-1` loses on principle rather than on count: `AUD` is
      // `audio.analog`'s DOMAIN tag prefix, which is precisely the
      // family-shaped answer DR-022 §11.21.5 rejected.
      expect(seeded['outlet.ceiling_speaker_pair']!.tag, 'SPK');
    });

    test('no tag is a prefix collision with another tag', () {
      // `@service=` resolves by tag before name, so two templates
      // answering to one token would make the chain order-dependent.
      final tags = [
        for (final t in seeded.values)
          if (t.tag case final tag?) tag.toLowerCase(),
      ];
      expect(tags.toSet(), hasLength(tags.length));
    });

    test('THE THREE GRADES CARRY NO TAG, and that is G4', () {
      // No label in the corpus renders a grade, so there is no attested
      // word. Null is unknown (CR-114) and DR-023 falls through to the
      // media short tag rather than printing an invented `G2`.
      for (final id in [
        'outlet.tia570d_grade1',
        'outlet.tia570d_grade2',
        'outlet.tia570d_grade3',
      ]) {
        expect(seeded[id]!.tag, isNull, reason: '$id must not invent a tag');
      }
    });
  });

  group('every id a recipe mentions resolves', () {
    final registries = buildSeedRegistries();

    test('every drop media is a seeded media type', () {
      // The failure this guards is silent: an unresolved `MediaTypeId`
      // degrades to the `unknown(rawId)` placeholder and never throws
      // (I-46), so a typo here would ship as a grey label rather than an
      // error.
      for (final t in seeded.values) {
        for (final d in t.drops) {
          expect(
            registries.mediaTypes[d.media],
            isNotNull,
            reason: '${t.id} names ${d.media.v}',
          );
        }
      }
    });

    test('every drop service is a seeded signal family', () {
      for (final t in seeded.values) {
        for (final d in t.drops) {
          expect(
            registries.signalFamilies[SignalFamilyId(d.service)],
            isNotNull,
            reason: '${t.id} names ${d.service}',
          );
        }
      }
    });

    test('every count is at least one', () {
      for (final t in seeded.values) {
        for (final d in t.drops) {
          expect(d.count, greaterThan(0), reason: t.id);
        }
      }
    });
  });

  group('the recipes, censused from the corpus rather than restated', () {
    /// media id → total drops, flattening `count`.
    Map<String, int> shapeOf(String id) {
      final out = <String, int>{};
      for (final d in seeded[id]!.drops) {
        out[d.media.v] = (out[d.media.v] ?? 0) + d.count;
      }
      return out;
    }

    test('TV location is the canonical Grade 2 outlet, four drops', () {
      // docs/07 §4.3: "*TV location* → 2 × Cat6 + 2 × RG6 as one
      // `Outlet` with four `Link`s". The whole-house fixture agrees on
      // both counts and on the quad-shield coax.
      expect(shapeOf('outlet.tv_location'), {
        'media.cat6': 2,
        'media.rg6_quad': 2,
      });
    });

    test("docs/02 §6.2's fifth drop is deliberately NOT here", () {
      // The one disagreeing source: its `outlet.tv_location` adds
      // `1 × media.cat5e` for `ctl.ir_emitter` and uses `cat6a_futp`.
      // Outvoted by the fixture, docs/07 §4.3 and docs/01 §519. Asserted
      // so that adopting it later is a visible change to a stated
      // decision, not a silent one.
      final medias = [
        for (final d in seeded['outlet.tv_location']!.drops) d.media.v,
      ];
      expect(medias, isNot(contains('media.cat5e')));
      expect(medias, isNot(contains('media.cat6a_futp')));
    });

    test('one Cat6 for AP, Camera and Data only — the same recipe', () {
      // Not a copy-paste. One Cat6 to a switch is one Cat6 to a switch;
      // the name, the tag and the location fields differ. The fixture
      // writes exactly this eight times over.
      for (final id in ['outlet.ap', 'outlet.camera', 'outlet.data_only']) {
        expect(shapeOf(id), {'media.cat6': 1}, reason: id);
      }
    });

    test('a ceiling speaker pair is ONE 16/4, not two cables', () {
      // Four conductors in one jacket, pulled once. docs/08's
      // `GR-CLG-1` note: "1 `Link`, 2 `Conductor`s".
      expect(shapeOf('outlet.ceiling_speaker_pair'), {'media.16_4': 1});
    });

    test('a keypad is 22/4 with an UNDETERMINED service', () {
      // docs/07 §4's table prints `Keypad` in its SERVICE column and
      // there is no keypad family among the 55: which control bus a
      // keypad speaks is chosen with the control system, months after
      // the 22/4 is pulled.
      expect(shapeOf('outlet.keypad'), {'media.22_4': 1});
      expect(
        seeded['outlet.keypad']!.drops.single.service,
        'structure.undetermined',
      );
    });

    test("the grades transcribe docs/07 §1's table, oddity included", () {
      // Grade 3 gets a LOWER twisted-pair grade and FEWER coax than
      // Grade 2 there. That is what the document says; a silent
      // correction would make this seed disagree with its own source.
      expect(shapeOf('outlet.tia570d_grade1'), {
        'media.cat6a_futp': 1,
        'media.rg6_quad': 1,
      });
      expect(shapeOf('outlet.tia570d_grade2'), {
        'media.cat6a_futp': 2,
        'media.rg6_quad': 2,
      });
      expect(shapeOf('outlet.tia570d_grade3'), {
        'media.cat6': 2,
        'media.rg6_quad': 1,
        'media.os2': 1,
      });
    });

    test('optional fibre is omitted, required fibre is present', () {
      // A preset that ships an optional item asserts it on every outlet
      // created from it. Grades 1 and 2 mark fibre optional; Grade 3
      // marks it required.
      expect(
        shapeOf('outlet.tia570d_grade1').keys,
        isNot(contains('media.os2')),
      );
      expect(
        shapeOf('outlet.tia570d_grade2').keys,
        isNot(contains('media.os2')),
      );
      expect(shapeOf('outlet.tia570d_grade3').keys, contains('media.os2'));
    });
  });

  group('the seed is a copy, and it round-trips', () {
    test('two calls are independent — a document may edit its own', () {
      // Registries are ordinary editable stored data after the seed copy
      // (docs/03 §5.6). A shared instance would make one project's edit
      // to a template reach into another's.
      final a = buildSeedOutletTemplates();
      final b = buildSeedOutletTemplates();
      a['outlet.tv_location']!.name = 'edited';
      expect(b['outlet.tv_location']!.name, 'TV location');
      expect(a['outlet.tv_location'], isNot(same(b['outlet.tv_location'])));
    });

    test('a template with no tag writes NO tag key', () {
      // DR-022 §11.21.4's "not a migration" claim holds only if the key
      // stays absent. The three grades are the only templates that
      // exercise the absent arm.
      final tree = const JsonDocumentCodec().encodeToJsonTree(_docWith(seeded));
      final templates =
          ((tree['document']! as Map<String, Object?>)['registries']!
                  as Map<String, Object?>)['outletTemplates']!
              as Map<String, Object?>;

      final grade2 =
          templates['outlet.tia570d_grade2']! as Map<String, Object?>;
      expect(grade2.containsKey('tag'), isFalse);

      final tv = templates['outlet.tv_location']! as Map<String, Object?>;
      expect(tv['tag'], 'TV');
    });
  });
}

RackDocument _docWith(Map<String, OutletTemplate> templates) {
  final now = DateTime.utc(2026, 8, 8);
  return RackDocument(
    id: const Uuid('doc-tpl'),
    appVersion: '0.1.0',
    createdAt: now,
    modifiedAt: now,
    meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
  )..registries = Registries(outletTemplates: templates);
}
