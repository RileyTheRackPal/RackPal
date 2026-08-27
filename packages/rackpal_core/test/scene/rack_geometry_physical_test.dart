// THE HORIZONTAL AXIS IS PHYSICAL NOW, AND THIS IS THE CORE-SIDE PROOF.
//
// =====================================================================
// WHAT CHANGED AND WHY
// =====================================================================
// `RackGeometry.railWidth` was 20 diagram units of declared "legibility
// chrome", following docs/04 §2.1's "20 px each at z1.0". The RU ruler is
// chrome too and that is harmless — it sits OUTSIDE the mounting panel and
// is a dimensionless annotation gutter. A rail is not: it sits INSIDE the
// 19 in panel, so [RackGeometry.openingWidth] — and with it every
// full-width device body — was derived from it.
//
// At 22 units per RU, 20 units is 1.59 in of equivalent, so the drawn
// clear opening was 19 − 2 × 1.59 = 15.82 in against a real EIA-19 opening
// of 17.75 in. Every device on the elevation was 11% narrow horizontally
// while the vertical axis and the overall panel width were exact — and the
// milestone's claim is "dimensionally correct against a physical tape
// measure at true scale".
//
// `railWidth` is now derived from the real 0.625 in flange.
//
// =====================================================================
// WHY THIS FILE EXISTS SEPARATELY FROM THE PDF GATE
// =====================================================================
// A MUTATION SAID SO. Reverting `railWidth` to 20 is caught by
// `rackpal_export/test/elevation_true_scale_test.dart` — the tape-measure
// gate — and by NOTHING in `rackpal_core` or `rackpal_ui`, because both
// of those reference the geometry symbolically. The physical property is a
// property of `rack_geometry.dart`, so it deserves an assertion that does
// not need a PDF to state it.
//
// EVERY EXPECTATION HERE IS A LITERAL. Nothing reads `unitsPerRu`,
// `railWidth` or `unitsForLen`; the conversions are spelled out from
// 44_450_000 nm per U and 25_400_000 nm per inch.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Exactly one rack unit, in nanometres (EIA-310: 1 U = 1.75 in).
const int _nmPerU = 44_450_000;

/// Exactly one inch, in nanometres.
const int _nmPerInch = 25_400_000;

/// Diagram units per inch, from the ONE scale anchor: 22 units per RU
/// divided by 1.75 in per RU.
const double _unitsPerInch = 22 / 1.75;

void main() {
  test('the U pitch is exactly 1.75 in — the anchor everything else '
      'derives from', () {
    expect(_nmPerU / _nmPerInch, closeTo(1.75, 1e-12));
    expect(
      const RackGeometry(1).rackHeight,
      closeTo(_unitsPerInch * 1.75, 1e-9),
    );
  });

  test('the mounting panel is exactly 19 in (EIA-19)', () {
    expect(
      RackGeometry.panelWidth / _unitsPerInch,
      closeTo(19, 1e-9),
    );
  });

  test('THE CLEAR OPENING IS EXACTLY 17.75 in, not 15.82', () {
    // The assertion the rail-width change exists for. 15.82 in is what a
    // 20-unit rail produced, and it is 11% narrow.
    expect(
      RackGeometry.openingWidth / _unitsPerInch,
      closeTo(17.75, 1e-9),
    );
    expect(
      RackGeometry.openingWidth / _unitsPerInch,
      isNot(closeTo(15.82, 0.05)),
    );
  });

  test('each rail flange is exactly 0.625 in — and 19 − 2 × 0.625 = 17.75 '
      'FALLS OUT rather than being asserted twice', () {
    expect(RackGeometry.railWidth / _unitsPerInch, closeTo(0.625, 1e-9));
    expect(
      (RackGeometry.panelWidth - 2 * RackGeometry.railWidth) / _unitsPerInch,
      closeTo(19 - 2 * 0.625, 1e-9),
    );
  });

  test('a FULL-WIDTH device body is the whole clear opening', () {
    // The property every device on the sheet inherits.
    final rect = const RackGeometry(42).deviceRect(1, 1);
    expect(rect.width / _unitsPerInch, closeTo(17.75, 1e-9));
  });

  test('a HALF-WIDTH device is half of it, exactly', () {
    final half = const RackGeometry(42).deviceRect(1, 1, spanTwelfths: 6);
    expect(half.width / _unitsPerInch, closeTo(17.75 / 2, 1e-9));
  });

  test('the RU RULER is deliberately NOT physical, and sits outside the '
      'panel', () {
    // Stated as an assertion so the distinction between the two kinds of
    // chrome is checked rather than remembered. The ruler is an annotation
    // gutter; nothing a reader scales off depends on it, and the elevation
    // sheet says so in `kScaleAppliesNote`.
    expect(RackGeometry.rulerWidth, 28);
    expect(const RackGeometry(42).railLeft, RackGeometry.rulerWidth);
    expect(
      const RackGeometry(42).openingLeft,
      closeTo(RackGeometry.rulerWidth + RackGeometry.railWidth, 1e-9),
    );
  });

  test('the vertical axis was ALREADY exact, and still is', () {
    for (final heightU in <int>[1, 12, 42, 45, 60]) {
      expect(
        RackGeometry(heightU).rackHeight / _unitsPerInch,
        closeTo(heightU * 1.75, 1e-9),
        reason: '${heightU}U',
      );
    }
  });
}
