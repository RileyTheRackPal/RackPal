// rackpal_core/src/persistence/pdf_raster_plan.dart — how many pixels a
// vector page is rendered at (DR-153 §11.152.5, `PLAN-K/2`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE RULE IS HERE AND THE RENDERER IS NOT, ON PURPOSE
// ═══════════════════════════════════════════════════════════════════════
// `rackpal_pdfium` turns a page into pixels and this decides how many.
// Splitting them is what keeps the decision testable on a machine with no
// native binary on it: every case below runs in the core suite, which has
// never needed anything but a Dart SDK.
//
// ═══════════════════════════════════════════════════════════════════════
// 300 DPI, AND THE NUMBER IS MEASURED AGAINST THE SHEET IT PRINTS ON
// ═══════════════════════════════════════════════════════════════════════
// DR-145 §11.144.7 left this open in terms: DR-137's *"never above the
// source's own effective resolution"* is a rule for a RASTER source, and a
// vector source has no such ceiling, so something else has to decide.
//
// `T1.01` fits the plan into 15.6 x 7.9 in of an ANSI B sheet, so the
// question is what reaches the paper:
//
//   source   ANSI B pixels        on the sheet
//   200 dpi  3400 x 2200,  7.5 MP  218 dpi
//   300 dpi  5100 x 3300, 16.8 MP  327 dpi
//   600 dpi  10200 x 6600,  67 MP  654 dpi
//
// 300 is the rung that prints above 300 on the sheet, which is where the
// laser stops being the limit. 600 cannot be the rule for both real sheet
// sizes: an ARCH D page at 600 dpi is 311 megapixels against a 120 MP cap.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE BUDGET STEPS DOWN RATHER THAN REFUSING
// ═══════════════════════════════════════════════════════════════════════
// ARCH D at 300 dpi is 78 megapixels: inside the caps, and 233 MB of BGR
// pixels in one allocation before anything encodes it. So the target is a
// target and [kPlanRasterPixelBudget] is what it yields to.
//
// **A REFUSAL HERE WOULD REINSTATE THE MANUAL STEP** for exactly the
// drawings most likely to be a whole floor, which is the failure DR-029
// spent two to three weeks buying out and DR-153 §11.152.1 ended the
// deferral over. A stepped-down page still prints far above the laser: an
// ARCH D sheet at the budget is 7745 px across, which is 496 dpi once
// `T1.01` has fitted it.
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/persistence/image_header.dart';

/// The resolution a vector page is rendered at, in dots per inch of the
/// page's own size.
const int kPlanRasterTargetDpi = 300;

/// The most pixels one rendered page may hold.
///
/// **NOT A CAP ON WHAT IS LEGAL, A CAP ON WHAT IS ASKED FOR.**
/// [kMaxImagePixels] is 120 MP and refuses an image; this is 40 MP and
/// changes the request, which is a different job. It is the point where
/// one BGR allocation is 120 MB, and it leaves ANSI B at the full 300 dpi
/// untouched: that page is 16.8 MP.
const int kPlanRasterPixelBudget = 40 * 1000 * 1000;

/// PDF points per inch, which is 72 by definition rather than by choice.
const double kPointsPerInch = 72;

/// What a page should be rendered at, and what that works out to.
@immutable
final class PlanRasterPlan {
  const PlanRasterPlan({
    required this.width,
    required this.height,
    required this.effectiveDpi,
  });

  final int width;
  final int height;

  /// The dpi actually used, which is [kPlanRasterTargetDpi] unless the
  /// budget or a cap stepped it down. Reported rather than inferred, so a
  /// caller that wants to tell somebody why a big sheet is softer than a
  /// small one has the number.
  final double effectiveDpi;

  /// Whether the target survived.
  bool get isFullResolution => effectiveDpi >= kPlanRasterTargetDpi;

  int get pixels => width * height;

  @override
  String toString() =>
      'PlanRasterPlan($width x $height at '
      '${effectiveDpi.toStringAsFixed(1)} dpi)';
}

/// The render size for a page [widthPt] by [heightPt] PDF points.
///
/// Returns null when the page has no positive size, which is a page
/// nothing can be done with. **Never returns something past
/// [kMaxImagePixelDimension] or [kMaxImagePixels]**: the rendered bytes go
/// through `importFloorplanBytes` like any other image (DR-138 §11.137.6),
/// and a plan that produced an image its own import guard refuses would be
/// a product arguing with itself.
PlanRasterPlan? planRasterFor(double widthPt, double heightPt) {
  if (!widthPt.isFinite || !heightPt.isFinite) return null;
  if (widthPt <= 0 || heightPt <= 0) return null;

  final widthIn = widthPt / kPointsPerInch;
  final heightIn = heightPt / kPointsPerInch;

  // Each constraint is expressed as the dpi it permits, and the smallest
  // wins. Written this way rather than as three nested rescalings so that
  // a fourth constraint is one more line and not one more chance to apply
  // them in the wrong order.
  var dpi = kPlanRasterTargetDpi.toDouble();

  final byBudget = _dpiForPixels(widthIn, heightIn, kPlanRasterPixelBudget);
  if (byBudget < dpi) dpi = byBudget;

  // AND THERE IS NO SECOND ARM FOR [kMaxImagePixels]. One was written here
  // and is unreachable by arithmetic: the budget is 40 MP and the import
  // cap is 120, so the budget always binds first and a guard behind it
  // could never fire. The invariant is asserted in the test rather than
  // guarded here, because a branch no state reaches is a branch every
  // later reader has to reason about.
  final longestIn = widthIn > heightIn ? widthIn : heightIn;
  final byDimension = kMaxImagePixelDimension / longestIn;
  if (byDimension < dpi) dpi = byDimension;

  // ROUNDING DOWN, AND THEN A FLOOR OF ONE PIXEL. Rounding up could put a
  // page one pixel past the cap that just decided the dpi, and a sheet
  // 1/300th of an inch across is a page with nothing on it rather than an
  // error to report from here.
  final width = (widthIn * dpi).floor();
  final height = (heightIn * dpi).floor();
  if (width < 1 || height < 1) return null;

  return PlanRasterPlan(width: width, height: height, effectiveDpi: dpi);
}

/// The dpi at which a [widthIn] by [heightIn] page fills exactly [pixels].
double _dpiForPixels(double widthIn, double heightIn, int pixels) {
  final area = widthIn * heightIn;
  if (area <= 0) return 0;
  // pixels = (w * dpi) * (h * dpi), so dpi = sqrt(pixels / area).
  return math.sqrt(pixels / area);
}
