// rackmate_core/src/draw/sheet/drawing_scale.dart — pure Dart.
//
// THE scale engine (docs/08-pdf-export.md §6.2 fit, §5.2 the reported
// ratio). This is the exit criterion's machinery: "elevations are
// dimensionally correct against a physical tape measure at true scale".
//
// ─────────────────────────────────────────────────────────────────────────
// TWO DIFFERENT NUMBERS, WHICH IS WHY THERE ARE TWO TYPES
// ─────────────────────────────────────────────────────────────────────────
// docs/08 §6.2's `fitScale(content, avail)` returns a factor that converts
// DIAGRAM UNITS to PDF POINTS. docs/08 §5.2's `k`, the thing the title block
// prints as `1:n`, is a PHYSICAL ratio: paper length ÷ real-world length.
//
// They are NOT the same number and never were. `RackGeometry.unitsPerRu` is
// 22 diagram units per RU while one RU is `pointsForLen(kRackUnit)` = 126.0
// pt of paper at full size, so the rack scene arrives at the sheet already
// reduced by 22/126. The two quantities differ by 126/22 = 5.7273x. Feeding
// `fitScale`'s output straight into the title block prints "1:1.4" on a
// sheet drawn at 1:8 — a lie of exactly the kind §5.2 forbids in its own
// words ("NEVER print 1:8 on a sheet drawn at 1:8.34 — someone will scale
// off it").
//
// So they are two distinct extension types over `double`. Neither is
// assignable to the other, and neither is assignable from a bare `double`:
// the compiler now enforces what a comment could only ask for.
//
// ─────────────────────────────────────────────────────────────────────────
// THE SCALE IS CHOSEN, NOT MEASURED — AND THIS FILE DOES NOT CHOOSE IT
// ─────────────────────────────────────────────────────────────────────────
// The choice walks [kStandardScaleDenominators] and takes the LARGEST SCALE
// (i.e. the SMALLEST denominator `n`) for which the drawing fits both axes
// of the area. Because the factor is then DERIVED FROM `n`
// ([DrawingScale.standard]), `k` is exactly `1/n` and "1:n" is true at 0%
// error rather than merely within tolerance.
//
// THE WALK ITSELF LIVES IN `elevation_sheet.dart`'s `_fitElevation`, AND
// THERE IS EXACTLY ONE OF IT. This file used to also export a
// `chooseDrawingScale(content, availableWidth, availableHeight)` that did
// the same walk against a FIXED content box. It had zero production
// callers — `_fitElevation` cannot use it, because the elevation's content
// CHANGES with the candidate scale (`RackTypeScale` inflates annotation as
// the drawing shrinks), so a one-shot fit against one content box would be
// fitting a drawing nobody emits. Two implementations of the exit
// criterion's own arithmetic, one of them unreachable, and seven tests
// guarding the unreachable one: two of those tests asserted a property
// that is FALSE of the shipped path (that a 60 U rack fits at 1:8 — it
// needs 1:10, because the elevation is fitted against the RU ruler, the
// load gutter and the inflated print type inside `elevationAreaOf`, which
// is 90 pt shorter than the raw drawing area), and both suites passed at
// the same time. So the dead one is gone and its tests now run the shipped
// fit.
//
// NOTE ON THE PHRASING, because the design brief for this stage says
// "picks the largest n ... for which the elevation fits" and that is a slip:
// a larger `n` is a SMALLER drawing, so "largest n that fits" would always
// be 96 (the tiniest). The intended reading — and what is implemented — is
// the largest SCALE that fits, i.e. the smallest `n`. Recorded rather than
// silently reinterpreted.
//
// ─────────────────────────────────────────────────────────────────────────
// A LABEL NAMES THE RATIO THE SHEET WAS DRAWN AT, OR IT SAYS `NTS`
// ─────────────────────────────────────────────────────────────────────────
// [DrawingScale.fitted] takes an ARBITRARY factor — a fit, not a choice —
// and it may name `1:n` only when the drawing genuinely IS at `1:n`
// ([standardDenominatorDrawnAt], a float round-trip tolerance and nothing
// wider). Anything else is `NTS`, which is what `NTS` is for.
//
// THIS USED TO BE THE 2% WINDOW AND THAT WAS A LIE GENERATOR. Deriving the
// label from the factor through a 2% predicate lets a sheet drawn at
// 1:97.95 print `SCALE 1:96`; an integrator laying a 1/8"=1'-0" rule on
// 105.000 in of rack then reads 102.907 in, and mis-sizes the closet by two
// inches. Reproduced end to end before the change, and now a named test.
// §5.2's own sentence forbids exactly this ("NEVER print 1:8 on a sheet
// drawn at 1:8.34 — someone will scale off it"); 1:8.34 is 4% off and
// 1:97.95 is 1.99%, but the difference between them is how big the lie is,
// not whether it is one.
//
// `NTS` is therefore a REACHABLE production path, not a theoretical one:
// see the reachability note in `elevation_sheet.dart`'s `_fitElevation`.
//
// ─────────────────────────────────────────────────────────────────────────
// THE 2% PREDICATE SURVIVES AS A WARNING, AND IT IS RELATIVE
// ─────────────────────────────────────────────────────────────────────────
// §5.2's 2% still does real work — it is what makes [DrawingScale.notice]
// able to say "drawn at 1:97.95, WITHIN 2% OF 1:96". A near-miss is the
// dangerous case precisely because it is plausible: nobody lays a 1:96 rule
// on a sheet drawn at 1:150, and everybody would on one drawn at 1:97.95.
//
// And it is RELATIVE, not absolute. §5.2 reads "the nearest standard ratio
// if |k − 1/n| < 2%"; read as an ABSOLUTE difference that is wrong, and the
// same sentence's own worked counter-example proves it: 1/8.34 = 0.11990
// against 1/8 = 0.125 is an absolute difference of 0.0051 — comfortably
// under 0.02 — so the absolute reading would call 1:8.34 a match for the
// very "1:8" the sentence forbids. Implemented as
// `(k − 1/n).abs() / (1/n) < 0.02`, with 1:8.34 as a named test case.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/scene/rack_geometry.dart';
import 'package:rackmate_core/src/units/constants.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/print_units.dart';

/// DIAGRAM UNITS → PDF POINTS. The factor a composed sheet scene applies to
/// a rack scene with one `OpTransform`.
///
/// Deliberately not a bare `double` and deliberately not interchangeable
/// with [PhysicalRatio] — see the file header.
extension type const SceneFactor(double unitsToPoints) {
  /// [units] diagram units expressed in PDF points under this factor.
  double points(double units) => units * unitsToPoints;
}

/// PAPER LENGTH ÷ REAL-WORLD LENGTH — the `k` docs/08 §5.2's title block
/// reports as `1:n`. At 1:8, `k == 0.125`.
extension type const PhysicalRatio(double k) {
  /// The exact ratio for a `1:[denominator]` scale.
  factory PhysicalRatio.oneOver(num denominator) =>
      PhysicalRatio(1 / denominator);
}

/// The standard drawing ratios docs/08 §5.2 permits the title block to
/// name. Ascending, i.e. LARGEST SCALE FIRST — `elevation_sheet.dart`'s
/// `_fitElevation` walks this in order and takes the first that fits.
const List<int> kStandardScaleDenominators = <int>[
  1,
  2,
  4,
  8,
  10,
  16,
  20,
  24,
  32,
  48,
  64,
  96,
];

/// docs/08 §5.2's 2%, applied as a RELATIVE tolerance — see the file header
/// for why the absolute reading is refuted by the doc's own example.
///
/// A NEAR-MISS PREDICATE, NOT A LABELLING ONE. Being inside this window is
/// what makes a non-standard ratio DANGEROUS (a reader will believe the
/// nearby standard rule), which is why it drives [DrawingScale.notice] and
/// never [DrawingScale.label].
const double kStandardRatioTolerance = 0.02;

/// How far a ratio may sit from `1/n` and still be said to BE `1/n`.
///
/// This is float noise and nothing else: [sceneFactorForRatio] and
/// [physicalRatioForSceneFactor] multiply and divide by `126/22`, so a
/// round trip through the two lands a few ULPs from where it started.
/// 1e-9 of relative error on a 105 in rack is 1e-7 in — eleven orders of
/// magnitude finer than a tape measure resolves, and seven orders inside
/// [kStandardRatioTolerance], so nothing a human could scale off can hide
/// in it.
const double kExactRatioTolerance = 1e-9;

/// §6.2's hard legibility floor, in points of paper.
const double kMinPrintPt = 6;

/// §6.2's preferred floor, in points of paper.
const double kSoftPrintPt = 7;

/// PDF points of paper per rack unit at 1:1 — `pointsForLen(kRackUnit)`,
/// which is 126.0 exactly. The bridge between the two regimes.
double get pointsPerRackUnit => pointsForLen(kRackUnit);

/// The [SceneFactor] that draws a rack scene at physical ratio [ratio].
///
/// `sceneFactor = k · pointsPerRackUnit / unitsPerRu`, i.e. at 1:n it is
/// `126 / (22·n)`.
SceneFactor sceneFactorForRatio(PhysicalRatio ratio) =>
    SceneFactor(ratio.k * pointsPerRackUnit / RackGeometry.unitsPerRu);

/// The physical ratio a rack scene drawn at [factor] actually lands on.
/// Exact inverse of [sceneFactorForRatio].
PhysicalRatio physicalRatioForSceneFactor(SceneFactor factor) => PhysicalRatio(
  factor.unitsToPoints * RackGeometry.unitsPerRu / pointsPerRackUnit,
);

/// docs/08 §6.2's `fitScale`, in this file's units: the largest
/// [SceneFactor] at which [content] fits an [availableWidth] ×
/// [availableHeight] area.
///
/// A zero or negative extent on an axis means that axis does not constrain
/// (an empty scene cannot be "too wide"), rather than producing an infinite
/// or negative factor.
SceneFactor fitSceneFactor(
  DBox content, {
  required double availableWidth,
  required double availableHeight,
}) {
  final byWidth = content.width > 0
      ? availableWidth / content.width
      : double.infinity;
  final byHeight = content.height > 0
      ? availableHeight / content.height
      : double.infinity;
  final fit = math.min(byWidth, byHeight);
  return SceneFactor(fit.isFinite ? fit : 1.0);
}

/// The standard denominator [ratio] is CLOSE ENOUGH TO BE MISTAKEN FOR —
/// within [kStandardRatioTolerance] — or `null` when it is nowhere near one.
///
/// NOT A LABEL SOURCE. A sheet drawn at 1:97.95 answers `96` here and still
/// prints `NTS`; what this drives is [DrawingScale.notice], which names the
/// near miss so a reader is warned off the rule they would otherwise reach
/// for. See the file header.
int? nearestStandardDenominator(PhysicalRatio ratio) {
  for (final n in kStandardScaleDenominators) {
    final target = 1 / n;
    if ((ratio.k - target).abs() / target < kStandardRatioTolerance) return n;
  }
  return null;
}

/// The standard denominator [ratio] ACTUALLY IS, or `null` when the drawing
/// is not at a standard ratio at all.
///
/// The whole distance between this and [nearestStandardDenominator] is the
/// distance between a fact and a resemblance, and only the fact may reach
/// the title block.
int? standardDenominatorDrawnAt(PhysicalRatio ratio) {
  for (final n in kStandardScaleDenominators) {
    final target = 1 / n;
    if ((ratio.k - target).abs() / target <= kExactRatioTolerance) return n;
  }
  return null;
}

/// A drawing scale plus the label the title block is allowed to print for
/// it (docs/08 §5.2).
///
/// The two constructors are the whole honesty mechanism.
/// [DrawingScale.standard] DERIVES its factor from the denominator, so its
/// label cannot be a lie.
/// [DrawingScale.fitted] derives its label from the factor through
/// [standardDenominatorDrawnAt], which names `1:n` only for a drawing that
/// IS at `1:n` — everything else is `NTS`. There is no constructor that
/// accepts a factor and a label independently, and no path that rounds a
/// drawn ratio up to a nearby printable one — that is the shape §5.2's
/// prohibition needs.
@immutable
final class DrawingScale {
  const DrawingScale._(this.sceneFactor, this.denominator);

  /// A sheet drawn at exactly `1:[denominator]`.
  factory DrawingScale.standard(int denominator) {
    assert(
      kStandardScaleDenominators.contains(denominator),
      'DrawingScale.standard: $denominator is not a standard ratio '
      '(docs/08-pdf-export.md §5.2)',
    );
    return DrawingScale._(
      sceneFactorForRatio(PhysicalRatio.oneOver(denominator)),
      denominator,
    );
  }

  /// A sheet drawn at an arbitrary fitted [factor]. Labelled `1:n` only
  /// when the drawing IS at `1:n`; otherwise `NTS`.
  factory DrawingScale.fitted(SceneFactor factor) => DrawingScale._(
    factor,
    standardDenominatorDrawnAt(physicalRatioForSceneFactor(factor)),
  );

  /// Diagram units → PDF points.
  final SceneFactor sceneFactor;

  /// The `n` in `1:n`, or `null` when the sheet must print `NTS`.
  final int? denominator;

  /// Paper ÷ reality, always the truth about what was drawn.
  PhysicalRatio get physicalRatio => physicalRatioForSceneFactor(sceneFactor);

  /// What the title block's SCALE field prints.
  String get label => denominator == null ? 'NTS' : '1:$denominator';

  /// Whether a reader may scale off this sheet.
  bool get isToScale => denominator != null;

  /// A one-line notice for the export summary when a reader may NOT scale
  /// off this sheet, or `null` when they may.
  ///
  /// ───────────────────────────────────────────────────────────────────
  /// WHY THIS EXISTS AT ALL
  /// ───────────────────────────────────────────────────────────────────
  /// [isToScale] shipped with no production reader: the export summary
  /// carried the legibility notice and nothing else, so an `NTS` elevation
  /// reached the user as an ordinary "Exported 3 sheets". The one thing a
  /// sheet that cannot be scaled off most needs to do is SAY SO, and the
  /// notice list is the non-gating channel that already exists for it
  /// (CR-023, G3 — nothing blocks the bytes).
  ///
  /// The near-miss wording is the point of the message rather than a
  /// decoration: a sheet drawn at 1:97.95 is dangerous BECAUSE a 1:96 rule
  /// looks like it belongs on it.
  String? get notice {
    if (isToScale) return null;
    const tail =
        'Do not scale off it — measure against the 1 ft graphic scale bar.';
    final k = physicalRatio.k;
    if (k <= 0 || !k.isFinite) return 'This sheet is NOT TO SCALE. $tail';
    final drawn = (1 / k).toStringAsFixed(2);
    final near = nearestStandardDenominator(physicalRatio);
    if (near == null) {
      return 'This sheet is NOT TO SCALE: drawn at 1:$drawn, which is not a '
          'standard ratio. $tail';
    }
    final window = (kStandardRatioTolerance * 100).toStringAsFixed(0);
    return 'This sheet is NOT TO SCALE: drawn at 1:$drawn — within $window% '
        'of 1:$near but NOT 1:$near. $tail';
  }

  @override
  bool operator ==(Object other) =>
      other is DrawingScale &&
      other.sceneFactor.unitsToPoints == sceneFactor.unitsToPoints &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(sceneFactor.unitsToPoints, denominator);

  @override
  String toString() =>
      'DrawingScale($label, sceneFactor: ${sceneFactor.unitsToPoints})';
}

/// The paper length, in points, of [feet] feet of reality at [ratio] — the
/// drawn length of a graphic scale bar.
///
/// At 1:8 one foot is `864 · 0.125 = 108.0` pt (1.5 in). This is the
/// drafting answer to §5.2's "someone will scale off it": the bar is
/// self-verifying against a tape measure even when the ratio field says
/// `NTS`.
double graphicScaleBarPoints(PhysicalRatio ratio, {int feet = 1}) =>
    pointsForLen(Len(kFoot.nm * feet)) * ratio.k;

/// The outcome of docs/08 §6.2's legibility check for one sheet.
///
/// Reported in the export summary; NEVER a gate (CR-022, G3 — "nothing
/// blocks the bytes").
@immutable
final class LegibilityReport {
  const LegibilityReport({
    required this.sceneMinTextSizePt,
    required this.paperTextPt,
  });

  /// `DiagramScene.minTextSizePt` — the smallest text the scene emitted, in
  /// its own diagram units.
  final double sceneMinTextSizePt;

  /// That same text's size on paper, after the drawing scale.
  final double paperTextPt;

  bool get meetsHardFloor => paperTextPt >= kMinPrintPt;
  bool get meetsSoftFloor => paperTextPt >= kSoftPrintPt;

  /// A one-line notice for the export summary, or `null` when the sheet is
  /// comfortably legible.
  String? get notice {
    if (meetsSoftFloor) return null;
    final size = paperTextPt.toStringAsFixed(2);
    return meetsHardFloor
        ? 'Smallest text on this sheet is $size pt — below the preferred '
              '${kSoftPrintPt.toStringAsFixed(0)} pt.'
        : 'Smallest text on this sheet is $size pt — below the '
              '${kMinPrintPt.toStringAsFixed(0)} pt legibility floor.';
  }

  @override
  String toString() =>
      'LegibilityReport(scene: $sceneMinTextSizePt, paper: $paperTextPt)';
}

/// Applies [scale] to a scene's smallest emitted text size.
LegibilityReport checkLegibility({
  required double sceneMinTextSizePt,
  required SceneFactor scale,
}) => LegibilityReport(
  sceneMinTextSizePt: sceneMinTextSizePt,
  paperTextPt: scale.points(sceneMinTextSizePt),
);
