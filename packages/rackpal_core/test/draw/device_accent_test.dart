// The shared device accent swatches (DR-080 §11.79.4, DR-098 §11.97.5).
//
// These exist because two surfaces offer the same eight colours: the
// builder's Appearance section writes `TemplateBody.accentColor`, door 1's
// inspector writes `DeviceOverrides.accentColor`. The list was private to
// the builder and is now shared, so the cases here are about the list
// being a usable OFFERING rather than about any one value.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('kDeviceAccentSwatches', () {
    test('offers eight distinct colours', () {
      // A DUPLICATE WOULD SILENTLY HALVE THE OFFERING. Both surfaces draw
      // one square per entry, so two identical entries render as two
      // squares a person cannot tell apart, and picking either produces
      // the same document. Nothing else in the tree would notice.
      expect(kDeviceAccentSwatches, hasLength(8));
      expect(
        kDeviceAccentSwatches.map((c) => c.argb).toSet(),
        hasLength(kDeviceAccentSwatches.length),
      );
    });

    test('every swatch is fully opaque', () {
      // `Rgb` has no alpha channel of its own and `argb` fills it in. A
      // translucent accent would composite against the elevation's paper
      // rather than replacing it, and the label ink is chosen from the
      // RESOLVED fill's luminance, which would then be measuring a colour
      // nobody actually sees.
      for (final c in kDeviceAccentSwatches) {
        expect(
          c.argb >> 24 & 0xFF,
          0xFF,
          reason: 'swatch ${c.argb.toRadixString(16)} is not opaque',
        );
      }
    });

    test('the ink rule copes with every one of them, including black', () {
      // DR-080 §11.79.3's finding: one of the eight is pure black, and all
      // four label inks were dark colours chosen against a near-white
      // default, so a body filled with it drew black text on black. The
      // defence is that the ink follows the resolved FILL. This asserts
      // the decision function actually answers for every swatch rather
      // than that it answers correctly for the one that caused trouble.
      final light = <bool>{
        for (final c in kDeviceAccentSwatches) prefersLightInk(c.argb),
      };
      expect(
        light,
        containsAll(<bool>[true, false]),
        reason:
            'if every swatch took the same ink the rule would be doing '
            'nothing, which is how the black one shipped invisible',
      );
      expect(
        prefersLightInk(const Rgb(0x00, 0x00, 0x00).argb),
        isTrue,
        reason: 'pure black is in the set and must take light ink',
      );
    });
  });
}
