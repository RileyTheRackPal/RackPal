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
import 'package:rackpal_core/rackpal_core.dart';
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

    test('the plate outline is DR-042 s 2.75 x 4.5 in, exactly', () {
      expect(PlateGeometry.plateWidth1Gang.nm, 69_850_000);
      expect(PlateGeometry.plateHeight.nm, 114_300_000);
    });

    test('every figure is an exact integer count of nanometres', () {
      // CR-001's whole point, and 11.41.4's: the inch is exact, so
      // 11/4, 9/2 and 29/16 of one are too, and no double appears
      // between a ruling and a rendered plate. A margin that came out
      // odd would mean a figure had been rounded somewhere upstream.
      expect((PlateGeometry.plateWidth1Gang.nm - 33_340_000) % 2, 0);
      expect((PlateGeometry.plateHeight.nm - 66_680_000) % 2, 0);
      expect(PlateGeometry.edgeMarginX.nm, 18_255_000);
      expect(PlateGeometry.edgeMarginY.nm, 23_810_000);
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
      // DR-042 adds two more: an opening has to fit inside its plate.
      expect(
        PlateGeometry.openingWidth.nm,
        lessThan(PlateGeometry.plateWidth1Gang.nm),
      );
      expect(
        PlateGeometry.openingHeight.nm,
        lessThan(PlateGeometry.plateHeight.nm),
      );
    });

    test('THE EDGE MARGIN IS INVARIANT ACROSS GANG COUNTS (DR-042)', () {
      // This is the case that carries DR-042 rather than either
      // measurement carrying itself. The margin holds only if the
      // outline formula AND the pitch are both right, and it drifts with
      // the gang count if either is wrong, so it is evidence about the
      // pair. Change one figure and this reads red while every
      // single-figure assertion above stays green.
      for (var n = 1; n <= 4; n++) {
        final plate = PlateGeometry(n);
        expect(
          plate.openingAt(0).left,
          _about(
            plate.bounds.left +
                PlateGeometry.unitsForLen(
                  PlateGeometry.edgeMarginX,
                ),
          ),
          reason: 'left margin on a $n-gang plate',
        );
        expect(
          plate.bounds.right - plate.openingAt(n - 1).right,
          _about(plate.openingAt(0).left - plate.bounds.left),
          reason: 'right margin differs from left on a $n-gang plate',
        );
      }
    });

    test('an N-gang plate is 2.75 + (N-1) x 1.8125 inches wide', () {
      // Derived from the two measured figures rather than tabulated, so
      // a plate width can never drift from the pitch beside it.
      const inch = 25_400_000;
      for (final (n, inches) in const [
        (1, 2.75),
        (2, 4.5625),
        (3, 6.375),
        (4, 8.1875),
      ]) {
        expect(
          PlateGeometry.plateWidthFor(n).nm,
          (inches * inch).round(),
          reason: '$n-gang plate width',
        );
      }
      expect(PlateGeometry.plateWidthFor(0).nm, 0);
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
      final widths = <double>[];
      final heights = <double>[];
      for (final (w, h) in const [(1, 1), (1, 2), (1, 3), (2, 2), (2, 3)]) {
        for (final box in plate.cellsOf(0, Strap(width: w, height: h))) {
          widths.add(box.width);
          heights.add(box.height);
        }
      }
      // ONE size, across all five shipped parts. This is the property
      // DR-007 forbade any dimensioned rendering without, and it is
      // asserted over the drawing rather than over the constant.
      //
      // TO A TOLERANCE AND NOT BY IDENTITY. `DBox` stores corners, so
      // `height` is `(top + h) - top`, which is not bit-identical to `h`
      // for every `top` a centred grid produces: this case caught a
      // 64.0 against a 64.00000000000003, one ULP apart. The CLAIM is
      // that the cells are one size; double bit-equality is not the
      // claim, and CR-001 is why the exactness that matters lives in the
      // `Len` constants above rather than out here in diagram space.
      for (final w in widths) {
        expect(w, _about(widths.first));
      }
      for (final h in heights) {
        expect(h, _about(heights.first));
      }
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
      // NOT ZERO SINCE DR-042. The origin is the plate's corner, and
      // there is 18.255 mm of real plastic before the first hole. This
      // case asserted `_about(0)` while the outline was unmeasured and
      // the drawing was openings-relative.
      expect(
        three.openingAt(0).left,
        _about(PlateGeometry.unitsForLen(PlateGeometry.edgeMarginX)),
      );
      expect(
        three.openingAt(0).top,
        _about(PlateGeometry.unitsForLen(PlateGeometry.edgeMarginY)),
      );
    });

    test('neighbouring openings do not overlap, and the web is 12.7 mm', () {
      const two = PlateGeometry(2);
      final web = two.openingAt(1).left - two.openingAt(0).right;
      expect(web, greaterThan(0));
      // 46.0375 - 33.34 = 12.6975 mm of plastic between neighbours. The
      // arithmetic that refuted a 22 mm gang pitch, as a drawn distance.
      expect(web, _about(12.6975 * PlateGeometry.unitsPerMillimetre));
    });

    test('bounds is the PLATE and every opening sits inside it', () {
      // `bounds` changed meaning at DR-042: it was the openings' extent
      // while the outline was an unruled "about", and it is the plate
      // now. The property that survives the change is the one worth
      // asserting: nothing is drawn outside the part.
      const three = PlateGeometry(3);
      expect(three.bounds.left, _about(0));
      expect(
        three.bounds.width,
        _about(PlateGeometry.unitsForLen(PlateGeometry.plateWidthFor(3))),
      );
      for (var g = 0; g < 3; g++) {
        final opening = three.openingAt(g);
        expect(opening.left, greaterThan(three.bounds.left));
        expect(opening.right, lessThan(three.bounds.right));
        expect(opening.top, greaterThan(three.bounds.top));
        expect(opening.bottom, lessThan(three.bounds.bottom));
      }
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
