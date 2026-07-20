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

  group('RackGeometry inverse — heightForTopEdgeY', () {
    // docs/04 §4.1's third way to change height: drag the rack's own top
    // edge. A different direction from ruIndexForTopY, which snaps a
    // DEVICE and clamps to the current heightU — the very quantity this
    // one solves for.

    test('the identity case: the top edge where it already is returns the '
        'current height', () {
      for (final heightU in [1, 12, 24, 42, 60]) {
        expect(RackGeometry(heightU).heightForTopEdgeY(0), heightU);
      }
    });

    test('dragging the top edge UP (negative Y) grows the rack, one U per '
        'unitsPerRu', () {
      const geo = RackGeometry(24);
      const u = RackGeometry.unitsPerRu;

      expect(geo.heightForTopEdgeY(-u), 25);
      expect(geo.heightForTopEdgeY(-3 * u), 27);
      expect(geo.heightForTopEdgeY(-18 * u), 42);
    });

    test('dragging the top edge DOWN (positive Y) shrinks the rack', () {
      const geo = RackGeometry(24);
      const u = RackGeometry.unitsPerRu;

      expect(geo.heightForTopEdgeY(u), 23);
      expect(geo.heightForTopEdgeY(3 * u), 21);
      expect(geo.heightForTopEdgeY(23 * u), 1);
    });

    test('snaps to the nearest whole U at the half-way point', () {
      const geo = RackGeometry(24);
      const u = RackGeometry.unitsPerRu;

      expect(geo.heightForTopEdgeY(0.4 * u), 24);
      expect(geo.heightForTopEdgeY(0.6 * u), 23);
      expect(geo.heightForTopEdgeY(-0.6 * u), 25);
    });

    test("clamps to CR-038's [1, 60] at both ends", () {
      const geo = RackGeometry(24);

      expect(geo.heightForTopEdgeY(100000), 1);
      expect(geo.heightForTopEdgeY(-100000), 60);
    });

    test('honours explicit bounds when the caller narrows them', () {
      const geo = RackGeometry(24);

      expect(geo.heightForTopEdgeY(-100000, maxHeightU: 30), 30);
      expect(geo.heightForTopEdgeY(100000, minHeightU: 6), 6);
    });

    test('round-trips against yOfBoundary for every reachable height', () {
      // yOfBoundary(k) is the Y of the k-th boundary from the bottom, so
      // the top edge of a k-U rack sits at exactly that Y. Feeding it back
      // must return k — this is the proof the drag readout and the
      // committed height cannot disagree.
      for (final current in [1, 12, 24, 60]) {
        final geo = RackGeometry(current);
        for (var k = 1; k <= 60; k++) {
          expect(
            geo.heightForTopEdgeY(geo.yOfBoundary(k)),
            k,
            reason: 'current=$current k=$k',
          );
        }
      }
    });
  });

  group('RackGeometry value equality', () {
    // Once heightU becomes mutable, every rebuild allocates a fresh
    // RackGeometry — so any `geo != old.geo` repaint check is only
    // meaningful if equality is by value.
    //
    // Every instance here comes from [_fresh] rather than a `const`
    // literal, deliberately: const literals are CANONICALISED, so
    // `identical(const RackGeometry(42), const RackGeometry(42))` is true
    // and every assertion below would pass on reference equality alone —
    // exactly the vacuous test this group exists to avoid. Taking the
    // height as a parameter is also what stops the analyzer suggesting
    // `const` back in.

    test('two geometries of the same height are equal and hash alike', () {
      expect(_fresh(24), _fresh(24));
      expect(_fresh(24).hashCode, _fresh(24).hashCode);
      expect({_fresh(24), _fresh(24)}, hasLength(1));
    });

    test('different heights are not equal', () {
      expect(_fresh(24), isNot(_fresh(25)));
      expect(_fresh(24) != _fresh(12), isTrue);
    });

    test('a freshly allocated geometry equals the identical one it '
        'replaces', () {
      // The exact shape of the repaint check: an old geometry held by a
      // painter versus a new one built this frame from an unchanged model.
      final held = _fresh(42);
      final rebuilt = _fresh(42);

      expect(
        identical(held, rebuilt),
        isFalse,
        reason: 'if these were canonicalised, the next assertion would '
            'prove nothing about value equality',
      );
      expect(
        held != rebuilt,
        isFalse,
        reason: 'a value type without == turns a targeted repaint into an '
            'unconditional one',
      );
    });
  });
}

/// A genuinely new [RackGeometry] instance — never canonicalised. See the
/// equality group's own comment for why that matters.
RackGeometry _fresh(int heightU) => RackGeometry(heightU);
