// Round-trip tests for the RU-index ⇄ scene-Y conversion (rack_geometry.dart).
// The whole reason the inverse is written as the algebraic inverse of the
// forward `deviceRect`/`yTopOfU` (rather than docs/04 §3.1's literal
// top-origin spelling) is so the two directions provably cannot drift — this
// file is that proof.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('RackGeometry inverse — ruIndexForTopY', () {
    test('forward-then-inverse is the identity for every valid ruIndex', () {
      for (final heightU in [1, 12, 42, 60]) {
        final geo = RackGeometry(heightU);
        for (var deviceH = 1; deviceH <= heightU; deviceH++) {
          final maxRu = heightU - deviceH + 1;
          for (var ru = 1; ru <= maxRu; ru++) {
            final top = geo.deviceRect(ru, deviceH).top;
            expect(
              geo.ruIndexForTopY(top, deviceH),
              ru,
              reason: 'heightU=$heightU deviceH=$deviceH ru=$ru top=$top',
            );
          }
        }
      }
    });

    test('the cursor spelling round-trips at a placed device centre', () {
      const geo = RackGeometry(12);
      const deviceH = 2;
      for (var ru = 1; ru <= 12 - deviceH + 1; ru++) {
        final rect = geo.deviceRect(ru, deviceH);
        final centreY = (rect.top + rect.bottom) / 2;
        expect(geo.ruIndexForCursorY(centreY, deviceH), ru);
      }
    });

    test('snaps to the nearest U within half a unit of a boundary', () {
      const geo = RackGeometry(12);
      const deviceH = 1;
      final topOf5 = geo.deviceRect(5, deviceH).top;
      const u = RackGeometry.unitsPerRu;
      // A little above the U5 top edge still snaps to U5…
      expect(geo.ruIndexForTopY(topOf5 - 0.4 * u, deviceH), 5);
      // …but past the half-way point it snaps to the next U up (U6).
      expect(geo.ruIndexForTopY(topOf5 - 0.6 * u, deviceH), 6);
    });

    test('clamps below U1 and above the top-most fitting index', () {
      const geo = RackGeometry(12);
      const deviceH = 2; // max index = 11
      // Way below the rack (large Y) → clamps to U1.
      expect(geo.ruIndexForTopY(10000, deviceH), 1);
      // Above the rack top (negative Y) → clamps to the highest fit.
      expect(geo.ruIndexForTopY(-10000, deviceH), 11);
      expect(geo.maxRuIndexFor(deviceH), 11);
    });

    test('a rack-tall device yields a legal (non-inverted) clamp', () {
      const geo = RackGeometry(12);
      expect(geo.maxRuIndexFor(12), 1);
      expect(geo.ruIndexForTopY(0, 12), 1);
      // Even an over-tall device does not produce an inverted clamp range.
      expect(geo.maxRuIndexFor(20), 1);
      expect(geo.ruIndexForTopY(500, 20), 1);
    });
  });
}
