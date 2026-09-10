// PLAN-K/2: how many pixels a vector page is rendered at
// (DR-153 §11.152.5, discharging DR-145 §11.144.7).
//
// ═══════════════════════════════════════════════════════════════════════
// THE TWO REAL SHEET SIZES ARE THE TWO CASES THAT MATTER
// ═══════════════════════════════════════════════════════════════════════
// This project has been handed two plan sets by the trade: an 18-sheet
// ARCH D permit set and a three-page ANSI B CAD plot (DR-145 §11.144.3).
// One of them takes the target resolution and one of them cannot, and
// every other case here is a boundary around those two.
//
// AND THE ARITHMETIC IS NOT RECOMPUTED. A case that works out the
// expected width the same way the implementation does agrees with it
// whichever direction it is wrong in, so the assertions are about the
// PROPERTIES a render size has to have: inside the caps, inside the
// budget, the same shape as the page, and honest about what it did.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// ANSI B landscape in points, which is what every page of the CAD plot
/// declares.
const double kAnsiBWidthPt = 1224;
const double kAnsiBHeightPt = 792;

/// ARCH D landscape, the first real set's sheet size.
const double kArchDWidthPt = 36 * 72;
const double kArchDHeightPt = 24 * 72;

PlanRasterPlan planOrFail(double widthPt, double heightPt) {
  final plan = planRasterFor(widthPt, heightPt);
  expect(plan, isNotNull, reason: '$widthPt x $heightPt pt has no render size');
  return plan!;
}

void main() {
  group('the sheet sizes the trade actually sends', () {
    /// LOAD-BEARING. DR-153 §11.152.5's whole argument is that this page
    /// takes the target, so the sheet prints at 327 dpi.
    test('an ANSI B page renders at the full 300 dpi', () {
      final plan = planOrFail(kAnsiBWidthPt, kAnsiBHeightPt);

      expect(plan.effectiveDpi, closeTo(300, 0.001));
      expect(plan.isFullResolution, isTrue);
      expect(plan.width, 5100);
      expect(plan.height, 3300);
      expect(
        plan.pixels,
        lessThan(kPlanRasterPixelBudget),
        reason:
            'the budget must not touch the sheet size the rule was '
            'chosen for',
      );
    });

    /// LOAD-BEARING. The other real sheet, which is where the budget bites
    /// and where a refusal would have reinstated the manual step.
    test('an ARCH D page steps down instead of being refused', () {
      final plan = planOrFail(kArchDWidthPt, kArchDHeightPt);

      expect(plan.isFullResolution, isFalse);
      expect(plan.effectiveDpi, lessThan(300));
      expect(plan.pixels, lessThanOrEqualTo(kPlanRasterPixelBudget));
      expect(
        plan.pixels,
        greaterThan((kPlanRasterPixelBudget * 0.95).round()),
        reason: 'stepping down means using the budget, not retreating from it',
      );
      expect(
        plan.effectiveDpi,
        greaterThan(200),
        reason: 'a stepped-down ARCH D sheet still prints far above the laser',
      );
    });

    test('a stepped-down page keeps the shape of the page', () {
      final plan = planOrFail(kArchDWidthPt, kArchDHeightPt);
      expect(
        plan.width / plan.height,
        closeTo(kArchDWidthPt / kArchDHeightPt, 0.001),
      );
    });
  });

  group('the import caps are never handed something they would refuse', () {
    /// The rendered bytes go through `importFloorplanBytes` like any other
    /// image (DR-138 §11.137.6), so a size past its caps would be the
    /// product arguing with itself.
    test('no page any printer prints exceeds a cap', () {
      // Every ISO and ANSI size this trade uses, plus two absurd ones.
      const sizes = <List<double>>[
        [612, 792], // Letter
        [792, 1224], // ANSI B portrait
        [1224, 792], // ANSI B landscape
        [1584, 2448], // ANSI D
        [2592, 1728], // ARCH D
        [3456, 2592], // ARCH E
        [14400, 14400], // the largest box PDF allows, 200 x 200 in
        [14400, 72], // 200 in by one, a site strip
      ];
      for (final size in sizes) {
        final plan = planOrFail(size[0], size[1]);
        expect(plan.width, lessThanOrEqualTo(kMaxImagePixelDimension));
        expect(plan.height, lessThanOrEqualTo(kMaxImagePixelDimension));
        expect(plan.pixels, lessThanOrEqualTo(kMaxImagePixels));
        expect(plan.pixels, lessThanOrEqualTo(kPlanRasterPixelBudget));
        expect(plan.effectiveDpi, greaterThan(0));
      }
    });

    /// This is the invariant that lets `pdf_raster_plan.dart` carry no
    /// second guard: a branch behind the budget could never fire.
    test('the budget is inside the import cap, which is why there is only '
        'one guard', () {
      expect(kPlanRasterPixelBudget, lessThanOrEqualTo(kMaxImagePixels));
    });

    /// LOAD-BEARING. The long thin page is the one the budget does NOT
    /// catch: 200 x 1 in is 18 MP at the target and 60000 px across.
    test('a long thin page is caught by the dimension cap, not the budget', () {
      final plan = planOrFail(14400, 72);

      expect(plan.width, lessThanOrEqualTo(kMaxImagePixelDimension));
      expect(
        plan.pixels,
        lessThan(kPlanRasterPixelBudget),
        reason: 'the budget had nothing to say here; the per-side cap did',
      );
      expect(plan.isFullResolution, isFalse);
    });
  });

  group('a page with no size', () {
    test('zero, negative and non-finite are all null rather than a throw', () {
      expect(planRasterFor(0, 792), isNull);
      expect(planRasterFor(1224, 0), isNull);
      expect(planRasterFor(-1224, 792), isNull);
      expect(planRasterFor(double.nan, 792), isNull);
      expect(planRasterFor(double.infinity, 792), isNull);
    });

    /// LOAD-BEARING, AND A MUTATION FOUND IT. Deleting the early refusal
    /// looked harmless because every other case fell through the one-pixel
    /// floor anyway. **Two negatives multiply to a positive area**, so a
    /// -1224 x -792 page passes the budget check, takes a NEGATIVE dpi off
    /// the per-side cap, and comes back as a plausible 30909 x 20000
    /// raster: past the cap that had just been consulted.
    test('a page negative in BOTH directions does not defeat the caps', () {
      expect(planRasterFor(-1224, -792), isNull);
      expect(planRasterFor(-14400, -14400), isNull);
    });

    test('a page too small to hold one pixel is null, not a 0 x 0 raster', () {
      // A hundredth of a point each way: 300 dpi of that is 0.04 px.
      expect(planRasterFor(0.01, 0.01), isNull);
    });

    test('a one-point square page still renders', () {
      final plan = planOrFail(1, 1);
      expect(plan.width, greaterThanOrEqualTo(1));
      expect(plan.height, greaterThanOrEqualTo(1));
    });
  });
}
