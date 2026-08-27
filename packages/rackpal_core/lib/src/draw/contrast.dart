// WCAG relative luminance, and the one decision it is used for here:
// whether ink over a fill should be dark or light. DR-080 (canon §11.79).
//
// ═════════════════════════════════════════════════════════════════════
// THERE IS ALREADY AN AUTHORITY FOR THIS AND IT IS NOT DART
// ═════════════════════════════════════════════════════════════════════
// `tools/pal1_check.py`'s `luminance()` has computed this project's
// luminances since M0, and the PAL-1 gate runs it on every push. DR-080
// §11.79.4 requires that the product NOT acquire a second definition of
// contrast, which is the mistake CR-080's font drift and the
// `family_glyph` measurement each made in their own register: one fact,
// two implementations, and nothing comparing them.
//
// A Dart process cannot call that Python, so the agreement is enforced
// the only way left: `contrast_test.dart` pins the value of every colour
// this product actually renders against the figure `pal1_check.py`
// produces for it, quoted in the case. Change either side and the case
// fails. That is weaker than sharing code and it is stated rather than
// glossed.
//
// WORTH KNOWING: `pal1_check.py`'s own header says it must be ported to a
// conformance test in `rackpal_core` at M0 and kept as the authority
// thereafter, and it names the file it expects. THAT PORT DOES NOT
// EXIST: no such test is anywhere in the tree and the gate has been the
// Python alone for the whole project. The name is deliberately not
// repeated here, because `draw_source_gate_test.dart` reads production
// comments and fails any that cite a test file which is missing — a
// reader following a dead reference cannot tell an unwritten gate from a
// deleted one, and it caught this very paragraph on its first run.
//
// This file is NOT that port and does not pretend to be: PAL-1 is a rule
// about signal family PAIRS, and this is one scalar it happens to share.
import 'dart:math' as math;

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
