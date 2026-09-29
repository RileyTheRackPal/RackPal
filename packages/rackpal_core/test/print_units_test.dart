// units/print_units.dart — THE nanometre → point chain the exit criterion
// stands on.
//
// Every expectation below is a LITERAL a reviewer can check against a
// ruler or a spec sheet. Nothing here is computed by the code under test
// and then compared to itself.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('the constants the chain is built from', () {
    test('are exactly the values docs/02 and docs/08 name', () {
      // If any of these three moves, every number on every sheet moves.
      // They are asserted here so that movement is a red suite rather than
      // a quietly wrong drawing.
      expect(kRackUnit.nm, 44450000, reason: '1 U = 44.45 mm exactly');
      expect(Len.nmPerInch, 25400000, reason: '1 in = 25.4 mm exactly');
      expect(kPdfPointsPerInch, 72.0, reason: 'PDF user space is 1/72 in');
      expect(kFoot.nm, 304800000, reason: '1 ft = 12 in');
    });
  });

  group('pointsForLen', () {
    test('one rack unit is EXACTLY 126.0 pt at full size', () {
      // 44_450_000 · 72 / 25_400_000 = 3_200_400_000 / 25_400_000 = 126.
      // Both operands and the quotient are exactly representable, so this
      // is `==`, not `closeTo`. A tolerance here would hide the very drift
      // the file exists to prevent.
      expect(pointsForLen(kRackUnit), 126.0);
    });

    test('one rack unit is 1.75 in — the figure on the rack spec sheet', () {
      expect(pointsForLen(kRackUnit) / 72.0, 1.75);
    });

    test('one inch is exactly 72 pt', () {
      expect(pointsForLen(const Len(25400000)), 72.0);
    });

    test('the EIA-19 panel width is exactly 1368.0 pt (19 in)', () {
      expect(pointsForLen(const Len(482600000)), 1368.0);
      expect(pointsForLen(const Len(482600000)) / 72.0, 19.0);
    });

    test('a 45 U rack is 78.75 in tall at full size', () {
      // docs/08 §6.1's own worked figure, reproduced independently.
      expect(pointsForLen(Len(kRackUnit.nm * 45)) / 72.0, 78.75);
    });

    test('one foot is exactly 864 pt', () {
      expect(pointsForLen(kFoot), 864.0);
    });

    test('is linear and signed', () {
      expect(pointsForLen(const Len(0)), 0.0);
      expect(pointsForLen(const Len(-25400000)), -72.0);
    });
  });
}
