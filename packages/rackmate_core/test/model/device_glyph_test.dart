// DR-059 (canon §11.58): the device glyph, its category defaults, and the
// override-slot semantics of a null. Board #201, M4-D/3.
//
// THE GATE THAT MATTERS is the first group: the default table is checked
// against `kCatalogCategoryOrder` in BOTH directions, so it cannot drift
// from the list the palette groups by. docs/06 §3.1 spent four milestones
// spelling eight categories against a catalog shipping nine, which is
// exactly the drift a second list produces.
//
// Nothing here asserts what a glyph LOOKS like. There are no paths yet:
// the 17 vector marks are M4-K's (§11.58.7), and a test pinning artwork
// that does not exist would be asserting a mechanism nobody built.
import 'package:rackmate_core/rackmate_core.dart';
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
    test('is 17 marks plus none, against 48 templates in 9 categories: '
        'a mark drawn 1U tall on a photocopy cannot carry 40 distinctions', () {
      expect(DeviceGlyph.values, hasLength(18));
      expect(DeviceGlyph.values.first, DeviceGlyph.none);
    });

    test('several catalog ids share one silhouette, which is the cap doing '
        'its job rather than a gap in it', () {
      // F04..F08 are five different speakers and one picture.
      final field = buildSeedCatalog().entries.where(
        (e) => e.value.category == kCatField,
      );

      expect(field, hasLength(18));
      expect(
        {
          for (final e in field)
            effectiveGlyph(e.value.glyph, e.value.category),
        },
        hasLength(1),
        reason:
            'none of the 18 has authored a glyph yet, so all 18 currently '
            'take the category default, which is why the picker on the FORM '
            'matters more in this category than anywhere else (see the note '
            'on kCategoryDefaultGlyph)',
      );
    });
  });
}
