// rackpal_core/src/units/print_units.dart — pure Dart.
//
// THE physical unit conversion for print, and nothing else: nanometres to
// PDF points. Two constants and two functions.
//
// WHY THIS FILE EXISTS AT ALL, stated once because it is the load-bearing
// arithmetic of the whole exporter. The exit criterion is "elevations are
// dimensionally correct against a physical tape measure at true scale". A
// tape measure reads inches; a PDF viewer reads points; the model stores
// nanometres. There is therefore exactly one chain that has to be right:
//
//   kRackUnit          = Len(44_450_000) nm          [units/constants.dart]
//   Len.nmPerInch      =     25_400_000 nm           [units/len.dart]
//   points per inch    =             72.0            [here]
//   => points per RU   = 44_450_000 * 72 / 25_400_000
//                      = 3_200_400_000 / 25_400_000
//                      = 126.0 EXACTLY  (1 U = 1.75 in)
//
// Every step is exactly representable in IEEE-754 doubles (the numerator and
// denominator are both integers well under 2^53 and the quotient is an
// integer), so `pointsForLen(kRackUnit)` is 126.0 with no epsilon anywhere.
// `print_units_test.dart` asserts that with `==`, not `closeTo`.
//
// NOTHING ANYWHERE ELSE MAY HARDCODE 126 OR 72. That is the entire point of
// putting this in its own file: a typo in `kRackUnit` must move the drawing,
// the ruler, the scale bar and the printed ratio TOGETHER rather than
// desynchronising them silently. If you find yourself writing `126` or
// `/ 72` in a sheet builder, call [pointsForLen] instead.
//
// NOT TO BE CONFUSED WITH the DiagramCanvas boundary's "1 diagram unit = 1
// PDF point" (CR-007). That identity holds at the canvas, but the RACK SCENE
// is drawn at `RackGeometry.unitsPerRu = 22` diagram units per RU, i.e. at a
// built-in 22:126 reduction. Converting between the two regimes is
// `draw/sheet/drawing_scale.dart`'s job, and it is the single most likely
// place this exporter could print a ratio it is not drawn at.

import 'package:rackpal_core/src/units/len.dart';

/// PDF user-space points per inch. The PDF default user space unit is
/// 1/72 in (PDF 32000-1 §8.3.2.3), which is also `PdfPageFormat.inch` in
/// the `pdf` package — asserted equal by `page_sizes_test.dart` in
/// `rackpal_export`, which is the only place both constants are visible.
const double kPdfPointsPerInch = 72;

/// One foot, exactly — the reality length a graphic scale bar measures.
const Len kFoot = Len(12 * Len.nmPerInch);

/// Converts a physical [Len] to PDF points at 1:1 (full size).
///
/// `pointsForLen(kRackUnit) == 126.0` and `pointsForLen(Len(482_600_000))
/// == 1368.0` (the EIA-19 panel width), both exactly.
double pointsForLen(Len l) => l.nm * kPdfPointsPerInch / Len.nmPerInch;

/// The inverse of [pointsForLen], rounded to the nearest nanometre.
///
/// Only for turning a measured paper distance back into a physical one (a
/// diagnostic direction — the drawing pipeline never needs it). Rounding is
/// lossy by construction: not every point value lands on an integer
/// nanometre.
Len lenForPoints(double points) =>
    Len((points * Len.nmPerInch / kPdfPointsPerInch).round());
