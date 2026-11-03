// #755 — DR-080's contrast primitive, held to the figures
// `tools/pal1_check.py` printed while it still computed its own.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIRST GROUP IS THE ONLY REASON THIS FILE EXISTS
// ═════════════════════════════════════════════════════════════════════
// DR-080 §11.79.4 forbids the product acquiring a SECOND definition of
// contrast. `pal1_check.py` owned relative luminance from M0, and a Dart
// process cannot call Python, so agreement was enforced by pinning: every
// expected figure below was PRINTED BY THAT SCRIPT, not by this one, and
// is quoted to ten places.
//
// SINCE SFE-A2 THE PYTHON NO LONGER COMPUTES IT: the gate asks
// `contrast.dart` through `tool/pal1_verdicts.dart`. The pins stay, now as
// the record of what the old implementation said, so a change to the
// formula here still fails against an answer nobody derived from it.
//
// The colours pinned are the ones this product actually renders: the
// eight Okabe-Ito accent swatches `device_builder_screen.dart` offers,
// plus `RackPalette.deviceFill`. A luminance test over invented colours
// would prove the arithmetic and protect nothing.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Printed by `python tools/pal1_check.py`'s `luminance()` on
/// 2026-08-21. Do not recompute these in Dart to make a case pass; that
/// is the drift the whole file exists to prevent.
const _pinned = <String, (int, double)>{
  'black': (0xFF000000, 0.0000000000),
  'orange': (0xFFE69F00, 0.4161926832),
  'skyBlue': (0xFF56B4E9, 0.4050414218),
  'bluishGreen': (0xFF009E73, 0.2569152442),
  'yellow': (0xFFF0E442, 0.7440541760),
  'blue': (0xFF0072B2, 0.1524898013),
  'vermillion': (0xFFD55E00, 0.2215154120),
  'reddishPurple': (0xFFCC79A7, 0.2930213409),
  'deviceFill': (0xFFEFF3F8, 0.8922921747),
};

void main() {
  group('the Dart agrees with what pal1_check.py printed', () {
    for (final e in _pinned.entries) {
      final (argb, expected) = e.value;
      test('${e.key} matches the figure the Python prints', () {
        expect(relativeLuminance(argb), closeTo(expected, 1e-9));
      });
    }

    test('alpha is ignored, because a device body is drawn opaque and a '
        'translucent fill would need a backdrop to answer honestly', () {
      expect(relativeLuminance(0x00E69F00), relativeLuminance(0xFFE69F00));
    });
  });

  group('the pivot is derived, not tuned', () {
    test('it is the luminance where black and white contrast equally', () {
      // WCAG contrast is (L1 + 0.05) / (L2 + 0.05).
      const l = kInkPivotLuminance;
      expect((1.0 + 0.05) / (l + 0.05), closeTo((l + 0.05) / 0.05, 1e-9));
    });

    test('every shipped swatch lands on the side its contrast prefers', () {
      for (final e in _pinned.entries) {
        final (argb, l) = e.value;
        final darkInk = (l + 0.05) / 0.05;
        final lightInk = 1.05 / (l + 0.05);
        expect(
          prefersLightInk(argb),
          lightInk > darkInk,
          reason: '${e.key}: dark ink scores $darkInk, light $lightInk',
        );
      }
    });

    test('pure black asks for light ink, which is the swatch DR-080 was '
        'written about', () {
      expect(prefersLightInk(0xFF000000), isTrue);
    });

    test('the default body fill asks for dark ink, so an unaccented rack '
        'is unchanged', () {
      expect(prefersLightInk(const RackPalette().deviceFill), isFalse);
    });
  });

  group('contrastRatio, which the PAL-1 gate asks for the callout', () {
    // SFE-A2. Printed by `contrast()` in `tools/pal1_check.py` at
    // 85a2dc13, the last commit where the Python computed it. The first is
    // the callout's own case: black ink on the darkest screened underlay
    // sample, 192, which the gate prints as 11.54:1.
    int grey(int v) => 0xFF000000 | (v << 16) | (v << 8) | v;

    test('agrees with the figures the Python printed', () {
      expect(contrastRatio(grey(0), grey(192)), closeTo(11.5423025141, 1e-9));
      expect(contrastRatio(grey(0), grey(255)), closeTo(21.0, 1e-9));
      expect(contrastRatio(grey(64), grey(200)), closeTo(6.1971343632, 1e-9));
    });

    test('is the same either way round, and 1 for a colour on itself', () {
      expect(
        contrastRatio(grey(200), grey(64)),
        contrastRatio(grey(64), grey(200)),
      );
      expect(contrastRatio(0xFF0072B2, 0xFF0072B2), 1.0);
    });
  });

  test('Rgb.argb packs the way the draw layer reads', () {
    expect(const Rgb(0xE6, 0x9F, 0x00).argb, 0xFFE69F00);
    expect(const Rgb(0, 0, 0).argb, 0xFF000000);
    expect(const Rgb(0x12, 0x34, 0x56, a: 0x78).argb, 0x78123456);
  });
}
