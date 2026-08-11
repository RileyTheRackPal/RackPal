// M3-H/2 (#167). The plate drawing DR-038 unblocked and DR-041 supplied
// the figures for.
//
// MOST OF THIS ASSERTS SYMMETRY RATHER THAN CONSTANTS, deliberately. The
// property DR-007 §11.7.8 change 2 cares about is that the grid is
// CENTRED in the opening, and a test pinning "cell 0's top is 3.34 mm"
// would pass just as happily on a renderer that anchored to the top edge
// and happened to have the right first row. The margins-are-equal
// assertions fail on that renderer and pass on this one, which is the
// whole of `assert-the-artifact-not-the-mechanism`.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// Diagram units are doubles derived through one scale factor, so
/// comparisons are to within a unit's rounding rather than exact.
Matcher _about(double expected) => closeTo(expected, 1e-6);

void main() {
  const plate = PlateGeometry(1);

  group('the figures are the ones the rulings state', () {
    test('the cell is DR-028 s front nose, exactly', () {
      expect(PlateGeometry.cellWidth.nm, 14_500_000);
      expect(PlateGeometry.cellHeight.nm, 16_000_000);
    });

    test('the opening and both pitches are DR-041 s measurements', () {
      expect(PlateGeometry.openingWidth.nm, 33_340_000);
      expect(PlateGeometry.openingHeight.nm, 66_680_000);
      expect(PlateGeometry.cellPitchX.nm, 15_950_000);
      expect(PlateGeometry.cellPitchY.nm, 22_000_000);
    });

    test('the gang pitch is 1.8125 in exactly, with no rounding in it', () {
      // 29/16 in through nmPerInch. The point of the expression is that
      // it is exact in integers; if somebody rewrites it as 46.04 mm this
      // reads red.
      expect(PlateGeometry.gangPitch.nm, 46_037_500);
    });

    test('every figure sits inside the inequality DR-041 refuted 22 mm on', () {
      // The check that killed a wrong reading before it reached the code:
      // a pitch cannot be smaller than the thing it separates.
      expect(
        PlateGeometry.gangPitch.nm,
        greaterThan(PlateGeometry.openingWidth.nm),
      );
      // Two cells and one horizontal pitch must fit across the opening.
      expect(
        PlateGeometry.cellPitchX.nm + PlateGeometry.cellWidth.nm,
        lessThanOrEqualTo(PlateGeometry.openingWidth.nm),
      );
      // Three cells and two vertical pitches must fit down it.
      expect(
        2 * PlateGeometry.cellPitchY.nm + PlateGeometry.cellHeight.nm,
        lessThanOrEqualTo(PlateGeometry.openingHeight.nm),
      );
      // And a cell cannot be wider than its own pitch, or the noses
      // collide.
      expect(
        PlateGeometry.cellWidth.nm,
        lessThanOrEqualTo(PlateGeometry.cellPitchX.nm),
      );
      expect(
        PlateGeometry.cellHeight.nm,
        lessThanOrEqualTo(PlateGeometry.cellPitchY.nm),
      );
    });
  });

  group('the grid is CENTRED in the opening, not anchored to an edge', () {
    test('a 1-port strap sits in the middle, which is the whole of '
        'change 2', () {
      final opening = plate.openingAt(0);
      final cell = plate.cellAt(0, Strap(width: 1, height: 1), 0)!;
      // A renderer laying out from the top edge draws this jack at the
      // top, "and that is simply not what the part looks like".
      expect(cell.top - opening.top, _about(opening.bottom - cell.bottom));
      expect(cell.left - opening.left, _about(opening.right - cell.right));
    });

    test('a 2-port strap has equal plastic above and below the pair', () {
      final opening = plate.openingAt(0);
      final strap = Strap(width: 1, height: 2);
      final cells = plate.cellsOf(0, strap);
      expect(
        cells.first.top - opening.top,
        _about(opening.bottom - cells.last.bottom),
      );
    });

    test('a 3-port strap is still centred, and nearly fills the span', () {
      final opening = plate.openingAt(0);
      final cells = plate.cellsOf(0, Strap(width: 1, height: 3));
      final margin = cells.first.top - opening.top;
      expect(margin, _about(opening.bottom - cells.last.bottom));
      // 3.34 mm of plastic top and bottom, which is what "only the
      // 3-port fills it" means quantitatively.
      expect(margin, _about(3.34 * PlateGeometry.unitsPerMillimetre));
    });

    test('a 2-wide strap is centred horizontally too', () {
      final opening = plate.openingAt(0);
      final cells = plate.cellsOf(0, Strap(width: 2, height: 3));
      expect(
        cells[0].left - opening.left,
        _about(opening.right - cells[1].right),
      );
    });
  });

  group('no width- or height-dependent term, which is DR-038 as code', () {
    test('every cell is the same size on every strap', () {
      final sizes = <String>{};
      for (final (w, h) in const [(1, 1), (1, 2), (1, 3), (2, 2), (2, 3)]) {
        for (final box in plate.cellsOf(0, Strap(width: w, height: h))) {
          sizes.add('${box.width}x${box.height}');
        }
      }
      // ONE size, across all five shipped parts. This is the property
      // DR-007 forbade any dimensioned rendering without, and it is
      // asserted over the drawing rather than over the constant.
      expect(sizes, hasLength(1));
    });

    test('a column keeps its pitch whatever the strap width', () {
      final narrow = plate.cellsOf(0, Strap(width: 1, height: 3));
      final wide = plate.cellsOf(0, Strap(width: 2, height: 3));
      final narrowStep = narrow[1].top - narrow[0].top;
      // cells 0 and 2 of a 2-wide are the same COLUMN, one row apart.
      final wideStep = wide[2].top - wide[0].top;
      expect(wideStep, _about(narrowStep));
    });

    test('cells are laid out row-major, top-left first', () {
      final cells = plate.cellsOf(0, Strap(width: 2, height: 3));
      expect(cells[1].left, greaterThan(cells[0].left));
      expect(cells[2].top, greaterThan(cells[0].top));
      expect(cells[0].top, _about(cells[1].top));
    });

    test('a cell index the strap does not have returns null, not a clamp', () {
      // Clamping would draw a keystone on top of another one.
      expect(plate.cellAt(0, Strap(width: 2, height: 3), 6), isNull);
      expect(plate.cellAt(0, Strap(width: 1, height: 1), -1), isNull);
    });
  });

  group('multi-gang plates', () {
    test('gang 0 is leftmost and each is one gang pitch further right', () {
      const three = PlateGeometry(3);
      final step = three.openingAt(1).left - three.openingAt(0).left;
      expect(three.openingAt(2).left - three.openingAt(1).left, _about(step));
      expect(three.openingAt(0).left, _about(0));
    });

    test('neighbouring openings do not overlap, and the web is 12.7 mm', () {
      const two = PlateGeometry(2);
      final web = two.openingAt(1).left - two.openingAt(0).right;
      expect(web, greaterThan(0));
      // 46.0375 - 33.34 = 12.6975 mm of plastic between neighbours. The
      // arithmetic that refuted a 22 mm gang pitch, as a drawn distance.
      expect(web, _about(12.6975 * PlateGeometry.unitsPerMillimetre));
    });

    test('bounds spans every opening and nothing more', () {
      const three = PlateGeometry(3);
      expect(three.bounds.left, _about(0));
      expect(three.bounds.right, _about(three.openingAt(2).right));
      expect(three.bounds.height, _about(three.openingAt(0).height));
    });

    test('a plate with no gangs draws nothing', () {
      expect(const PlateGeometry(0).bounds.width, _about(0));
    });
  });

  group('the scale is one factor and nothing introduces a second', () {
    test('every dimension goes through unitsForLen', () {
      expect(
        PlateGeometry.unitsForLen(PlateGeometry.cellWidth),
        _about(14.5 * PlateGeometry.unitsPerMillimetre),
      );
      final cell = plate.cellAt(0, Strap(width: 1, height: 1), 0)!;
      expect(
        cell.width,
        _about(PlateGeometry.unitsForLen(PlateGeometry.cellWidth)),
      );
    });
  });
}
