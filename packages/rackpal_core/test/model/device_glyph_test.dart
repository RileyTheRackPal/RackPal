// DR-059 (canon §11.58): the device glyph, its category defaults, and the
// override-slot semantics of a null. Board #201, M4-D/3.
//
// THE GATE THAT MATTERS is the first group: the default table is checked
// against `kCatalogCategoryOrder` in BOTH directions, so it cannot drift
// from the list the palette groups by. docs/06 §3.1 spent four milestones
// spelling eight categories against a catalog shipping nine, which is
// exactly the drift a second list produces.
//
// Nothing here asserts what a glyph LOOKS like, and that is still the
// split: the 17 vector marks live in `device_glyph_art.dart` with their
// own cases (#752), and the elevation's placement in
// `device_layer_glyph_test.dart` (#753). §11.58.7 sequenced the artwork
// with M4-K; DR-083 §11.82.3 corrected that, because `panel_layer.dart`
// does not exist and DR-080 made the elevation the first surface.
//
// WHAT THIS FILE NOW GATES THAT IT DID NOT is the last group: every one
// of the 17 marks must be REACHABLE from the seeded catalog. The case
// above it, "every template resolves to a mark", passed for weeks while
// 48 templates resolved to nine marks and eight were drawn by nothing
// (DR-084). An existence assertion cannot see a collapse.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body({String category = kCatVideo, DeviceGlyph? glyph}) =>
    TemplateBody(
      manufacturer: 'Generic',
      model: 'MTX-8',
      displayName: 'HDMI Matrix 8x8',
      category: category,
      frontU: 4,
      glyph: glyph,
    );

void main() {
  group('the default table and the palette agree, in both directions', () {
    test('every category the palette groups by has a default mark', () {
      expect(
        kCatalogCategoryOrder.toSet().difference(
          kCategoryDefaultGlyph.keys.toSet(),
        ),
        isEmpty,
        reason:
            'a category with no default draws no mark at all, and the '
            'palette would group templates the builder cannot describe',
      );
    });

    test('the table claims no category the palette does not have', () {
      expect(
        kCategoryDefaultGlyph.keys.toSet().difference(
          kCatalogCategoryOrder.toSet(),
        ),
        isEmpty,
        reason:
            'a default for a category nobody ships is a spelling mistake '
            'that looks like coverage',
      );
    });

    test('there are NINE categories, not the eight docs/06 §3.1 used to '
        'spell: the constant is the source of truth', () {
      expect(kCatalogCategoryOrder, hasLength(9));
      expect(kCatalogCategoryOrder, contains(kCatField));
    });

    test('every one of the 48 seeded templates resolves to a mark', () {
      final unresolved = [
        for (final e in buildSeedCatalog().entries)
          if (effectiveGlyph(e.value.glyph, e.value.category) ==
              DeviceGlyph.none)
            e.key,
      ];

      expect(
        unresolved,
        isEmpty,
        reason:
            'the set was censused against these 48; one that falls '
            'through to `none` means a category was missed',
      );
    });
  });

  group('null is an override slot, not a G4 unknown', () {
    test('an untouched template inherits its category default, which is '
        'why nothing may read the raw field', () {
      expect(_body().glyph, isNull, reason: 'the author chose nothing');
      expect(
        effectiveGlyph(_body().glyph, kCatVideo),
        DeviceGlyph.matrix,
        reason: 'and still draws a mark',
      );
    });

    test('an explicit choice wins over the category', () {
      final b = _body(category: kCatAudio, glyph: DeviceGlyph.processor);

      expect(effectiveGlyph(b.glyph, b.category), DeviceGlyph.processor);
    });

    test('an explicit `none` is NOT the same as unchosen: it draws nothing '
        'on purpose, and the category does not override it', () {
      final b = _body(category: kCatAudio, glyph: DeviceGlyph.none);

      expect(effectiveGlyph(b.glyph, b.category), DeviceGlyph.none);
      expect(
        effectiveGlyph(null, kCatAudio),
        DeviceGlyph.amplifier,
        reason: 'while unchosen in the same category does not',
      );
    });

    test('an unrecognised category answers `none` rather than guessing, '
        'because a wrong picture is worse than no picture', () {
      expect(
        effectiveGlyph(null, 'Something A User Typed'),
        DeviceGlyph.none,
      );
    });
  });

  group('the set is capped, and the cap is the point', () {
    test('is 17 marks plus none, against 50 templates in 9 categories: '
        'a mark drawn 1U tall on a photocopy cannot carry 40 distinctions', () {
      expect(DeviceGlyph.values, hasLength(18));
      expect(DeviceGlyph.values.first, DeviceGlyph.none);
    });

    test('several catalog ids share one silhouette, which is the cap doing '
        'its job rather than a gap in it', () {
      // F04..F08 are five different speakers and one picture. THAT is the
      // cap working. What was NOT the cap working is the state DR-084
      // ended, where all EIGHTEEN field devices shared one picture
      // because none of them authored a glyph.
      final field = buildSeedCatalog().entries.where(
        (e) => e.value.category == kCatField,
      );
      expect(field, hasLength(19));

      final marks = {
        for (final e in field) effectiveGlyph(e.value.glyph, e.value.category),
      };
      expect(
        marks,
        hasLength(6),
        reason:
            'DR-084 authored these: display (F01-F03, F12), speaker '
            '(F04-F08), camera (F09), source (F10), antenna (F11, F17) '
            'and control (F13-F16, F18). Before it, all 18 answered '
            '`display` and a speaker drew a screen on a stand',
      );
      expect(
        {
          for (final e in field)
            if (e.key.startsWith('F0') &&
                int.parse(e.key.substring(1)) >= 4 &&
                int.parse(e.key.substring(1)) <= 8)
              effectiveGlyph(e.value.glyph, e.value.category),
        },
        {DeviceGlyph.speaker},
        reason: 'five speakers, one silhouette: the cap doing its job',
      );
    });
  });

  group('DR-084: the seeded catalog authors its own marks', () {
    test('EVERY mark is reachable from the seeded catalog, which is the '
        'assertion that would have caught the collapse', () {
      final drawn = {
        for (final e in buildSeedCatalog().values)
          effectiveGlyph(e.glyph, e.category),
      };
      final unreachable = DeviceGlyph.values
          .where((g) => g != DeviceGlyph.none && !drawn.contains(g))
          .toList();

      expect(
        unreachable,
        isEmpty,
        reason:
            'AN EXISTENCE ASSERTION CANNOT SEE A COLLAPSE. The case above '
            'this one asserts every template resolves to a mark, and it '
            'passed while 48 templates resolved to NINE marks and eight '
            'were drawn by nothing. This counts the RANGE, which is the '
            'number a person looking at an elevation would count',
      );
      expect(drawn, hasLength(17));
    });

    test('a template only authors a glyph when it DIFFERS from its '
        'category default, so the other 22 stay byte-identical', () {
      final wrong = [
        for (final e in buildSeedCatalog().entries)
          if (e.value.glyph != null &&
              e.value.glyph == kCategoryDefaultGlyph[e.value.category])
            e.key,
      ];

      expect(
        wrong,
        isEmpty,
        reason:
            'json_codec writes `glyph` whenever it is non-null, so a '
            'template authoring its own default gains a key and moves '
            'bytes for nothing (DR-084 §11.83.4)',
      );
    });
  });
}
