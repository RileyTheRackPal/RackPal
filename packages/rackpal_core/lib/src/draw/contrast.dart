// WCAG relative luminance, and the one decision it is used for here:
// whether ink over a fill should be dark or light. DR-080 (canon §11.79).
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS THE PRODUCT'S ONE DEFINITION, AND THE CI GATE READS IT TOO
// ═════════════════════════════════════════════════════════════════════
// DR-080 §11.79.4 requires that the product NOT acquire a second
// definition of contrast, which is the mistake CR-080's font drift and
// the `family_glyph` measurement each made in their own register: one
// fact, two implementations, and nothing comparing them.
//
// For most of the project it had two anyway. `tools/pal1_check.py`
// carried its own `luminance()` from M0, and since a Dart process cannot
// call Python, this file was held to it by pinning: `contrast_test.dart`
// quotes the figure the Python printed for every colour this product
// renders. SFE-A2 (DR-122 §11.121.4) turned the arrangement round. PAL-1's
// arithmetic now lives in `pal1.dart`, which reads [relativeLuminance],
// and the Python gate asks `tool/pal1_verdicts.dart` for its verdicts and
// for the callout's [contrastRatio] instead of computing them. The pinned
// figures stay, because they are the record of what the Python said
// before it stopped saying anything.
import 'dart:math' as math;

/// WCAG 2.x contrast ratio between two packed `0xAARRGGBB` colours, from
/// 1 (identical) to 21 (black on white). Alpha is ignored, as it is in
/// [relativeLuminance].
///
/// The PAL-1 gate asks this of the plan callout's ink against the darkest
/// screened underlay sample (DR-150 §11.149.4), which is the one place a
/// ratio, rather than a luminance, decides anything.
double contrastRatio(int argbA, int argbB) {
  final a = relativeLuminance(argbA);
  final b = relativeLuminance(argbB);
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}

/// WCAG 2.x relative luminance of a packed `0xAARRGGBB` colour.
///
/// Alpha is IGNORED, deliberately. A device body is drawn opaque over the
/// rack, so the ink decision is about the fill's own colour; a
/// translucent fill would need the backdrop to answer honestly, and the
/// elevation has none to offer.
double relativeLuminance(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255.0;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// The luminance at which black ink and white ink contrast EQUALLY
/// against a fill: `sqrt(1.05 * 0.05) - 0.05`.
///
/// Not a taste threshold and not tuned. Above it, dark ink wins by WCAG's
/// own contrast formula; below it, light ink does. Naming the constant is
/// what stops the next reader treating `0.179` as somebody's preference.
const double kInkPivotLuminance = 0.17912878474779204;

/// Whether ink over [fillArgb] should be the LIGHT variant.
///
/// The only caller that matters is the device body, whose eight shipped
/// accent swatches include pure black: a fixed dark ink over that is
/// black text on a black device, which is the defect DR-080 §11.79.3
/// exists to prevent.
bool prefersLightInk(int fillArgb) =>
    relativeLuminance(fillArgb) <= kInkPivotLuminance;
