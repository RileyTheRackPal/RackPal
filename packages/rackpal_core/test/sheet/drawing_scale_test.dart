// draw/sheet/drawing_scale.dart — THE exit-criterion machinery.
//
// Two things are proved here, and they are different things:
//
//   1. THE ARITHMETIC. A rack drawn at 1:n lands on the paper at exactly
//      `heightU · 44_450_000 · 72 / 25_400_000 / n` points. Every
//      expectation is computed in the test from those literals and from
//      NOTHING the production code returns.
//
//   2. THE HONESTY. The label the title block prints is `1:n` only when
//      the drawing is genuinely at 1:n, and `NTS` otherwise — including
//      the worked counter-example docs/08 §5.2 gives itself, 1:8.34.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

// ── literals, restated here so the expectations do not import them ───────
const int _nmPerRackUnit = 44450000;
const int _nmPerInch = 25400000;
const int _nmEia19Panel = 482600000;
const double _pointsPerInch = 72;

/// PDF points of paper for [rackUnits] rack units at ratio `1:[n]`,
/// computed from literals alone.
double _paperPointsForRu(int rackUnits, int n) =>
    rackUnits * _nmPerRackUnit * _pointsPerInch / _nmPerInch / n;

void main() {
  group('the two regimes are distinct and mutually invertible', () {
    test('points per rack unit at 1:1 is 126.0', () {
      expect(pointsPerRackUnit, 126.0);
    });

    test('the scene factor at 1:n is 126 / (unitsPerRu · n)', () {
      // The rack scene arrives at the sheet already reduced by
      // unitsPerRu:126 — this is the conversion the whole file exists for.
      for (final n in kStandardScaleDenominators) {
        expect(
          sceneFactorForRatio(PhysicalRatio.oneOver(n)).unitsToPoints,
          closeTo(126.0 / (RackGeometry.unitsPerRu * n), 1e-12),
        );
      }
    });

    test('scene factor and physical ratio round-trip', () {
      for (final n in kStandardScaleDenominators) {
        final ratio = PhysicalRatio.oneOver(n);
        final back = physicalRatioForSceneFactor(sceneFactorForRatio(ratio));
        expect(back.k, closeTo(ratio.k, 1e-15));
      }
    });

    test('a scene factor is NOT a physical ratio — they differ by 126/22', () {
      // The single most likely way this exporter could ship a lie is to
      // feed the fit factor of §6.2 straight into the ratio field of §5.2.
      // At 1:8 the two numbers are 0.716 and 0.125; confusing them prints
      // "1:1.4" on a sheet drawn at 1:8.
      final factor = sceneFactorForRatio(PhysicalRatio.oneOver(8));
      expect(factor.unitsToPoints, closeTo(0.71590909, 1e-6));
      expect(physicalRatioForSceneFactor(factor).k, closeTo(0.125, 1e-12));
      expect(
        factor.unitsToPoints / physicalRatioForSceneFactor(factor).k,
        closeTo(126.0 / 22.0, 1e-9),
      );
    });
  });

  group('the label honesty rule (docs/08 section 5.2)', () {
    test('exactly 1:8 prints "1:8"', () {
      expect(nearestStandardDenominator(PhysicalRatio.oneOver(8)), 8);
      expect(
        DrawingScale.fitted(
          sceneFactorForRatio(PhysicalRatio.oneOver(8)),
        ).label,
        '1:8',
      );
    });

    test('1:8.34 prints NTS — the worked counter-example in the doc', () {
      // |1/8.34 − 1/8| = 0.0051, which an ABSOLUTE 2% reading would accept.
      // The relative reading rejects it at 4.08%, which is what the same
      // sentence demands ("never print 1:8 on a sheet drawn at 1:8.34").
      final k = PhysicalRatio.oneOver(8.34);
      expect((k.k - 0.125).abs(), lessThan(0.02), reason: 'absolute: passes');
      expect(nearestStandardDenominator(k), isNull, reason: 'relative: fails');
      expect(DrawingScale.fitted(sceneFactorForRatio(k)).label, 'NTS');
      expect(DrawingScale.fitted(sceneFactorForRatio(k)).isToScale, isFalse);
    });

    test('1:8.1 — 1.25% off — is NEAR 1:8 and still prints NTS', () {
      // ==================================================================
      // THE FIX FOR THE FALLBACK THAT PRINTED A RATIO IT WAS NOT DRAWN AT.
      // ==================================================================
      // `nearestStandardDenominator` answers 8 — 1:8.1 is inside §5.2's 2%
      // window — and that used to BE the label. It is not a label any more:
      // a drawing at 1:8.1 is not a drawing at 1:8, and the only honest
      // thing to print on it is NTS.
      expect(nearestStandardDenominator(PhysicalRatio.oneOver(8.1)), 8);
      expect(standardDenominatorDrawnAt(PhysicalRatio.oneOver(8.1)), isNull);
      expect(
        DrawingScale.fitted(
          sceneFactorForRatio(PhysicalRatio.oneOver(8.1)),
        ).label,
        'NTS',
      );
    });

    test('1:97.95 — 1.99%, just inside the window — prints NTS, not '
        '"1:96"', () {
      // ==================================================================
      // THE REPRODUCED HIGH FINDING, AS A LITERAL.
      // ==================================================================
      // A 60 U rack (CR-038's maximum) carrying one tall device with a long
      // `name` drops the elevation fit off the standard-ratio path, and the
      // old `fitted` labelled the result from the 2% window: `SCALE 1:96`
      // on a sheet drawn at 1:97.95. An integrator laying a 1/8"=1'-0" rule
      // on it reads 105.000 in of rack as 102.907 in — two inches short of
      // a closet opening.
      //
      // The arithmetic of that misreading, from literals:
      const realInches = 60 * 1.75; // 60 U at 1.75 in
      const drawnDenominator = 97.9523;
      const paperInches = realInches / drawnDenominator;
      expect(paperInches * 96, closeTo(102.907, 0.001));
      expect(realInches - paperInches * 96, greaterThan(2));

      // ...and the label that made it possible is gone.
      final k = PhysicalRatio.oneOver(drawnDenominator);
      expect(nearestStandardDenominator(k), 96, reason: 'still a near miss');
      expect(DrawingScale.fitted(sceneFactorForRatio(k)).label, 'NTS');
      expect(DrawingScale.fitted(sceneFactorForRatio(k)).isToScale, isFalse);
    });

    test('NO ratio in the 2% window around ANY standard denominator is '
        'labelled with it', () {
      // The window is swept rather than sampled: every standard `n`, at
      // both edges of §5.2's tolerance and just inside it.
      for (final n in kStandardScaleDenominators) {
        for (final drift in <double>[0.9805, 0.995, 1.005, 1.0195]) {
          final k = PhysicalRatio((1 / n) * drift);
          expect(
            DrawingScale.fitted(sceneFactorForRatio(k)).label,
            'NTS',
            reason: '1:$n drawn ${drift}x',
          );
        }
      }
    });

    test('a factor that IS a standard one survives the float round trip', () {
      // The counterpart risk: a tolerance tight enough to reject 1.99% must
      // still accept the exact article, whose `k` has been through
      // `× 126/22` and `÷ 126/22`.
      for (final n in kStandardScaleDenominators) {
        expect(
          DrawingScale.fitted(DrawingScale.standard(n).sceneFactor).label,
          '1:$n',
          reason: '1:$n did not recognise itself',
        );
      }
    });

    test('1:8.2 — 2.5% off — prints NTS', () {
      expect(nearestStandardDenominator(PhysicalRatio.oneOver(8.2)), isNull);
    });

    test('the tolerance boundary is 2% relative, on both sides', () {
      const target = 0.125; // 1/8
      expect(
        nearestStandardDenominator(const PhysicalRatio(target * 1.019)),
        8,
        reason: '1.9% over',
      );
      expect(
        nearestStandardDenominator(const PhysicalRatio(target * 1.021)),
        isNull,
        reason: '2.1% over',
      );
      expect(
        nearestStandardDenominator(const PhysicalRatio(target * 0.981)),
        8,
        reason: '1.9% under',
      );
      expect(
        nearestStandardDenominator(const PhysicalRatio(target * 0.979)),
        isNull,
        reason: '2.1% under',
      );
    });

    test('every standard denominator labels itself', () {
      for (final n in kStandardScaleDenominators) {
        expect(DrawingScale.standard(n).label, '1:$n');
        expect(DrawingScale.standard(n).physicalRatio.k, closeTo(1 / n, 1e-15));
      }
    });

    test('DrawingScale.standard cannot lie: its factor comes FROM its '
        'denominator', () {
      // There is no constructor taking a factor and a label independently,
      // which is the shape the section 5.2 prohibition actually needs. The
      // best a caller can do is ask for a standard ratio, and then the
      // drawn size follows from the number printed.
      final scale = DrawingScale.standard(8);
      expect(
        RackGeometry.unitsPerRu * scale.sceneFactor.unitsToPoints,
        closeTo(_paperPointsForRu(1, 8), 1e-9),
      );
    });
  });

  group('a sheet nobody may scale off says so (DrawingScale.notice)', () {
    test('a sheet AT a standard ratio carries no notice', () {
      for (final n in kStandardScaleDenominators) {
        expect(DrawingScale.standard(n).notice, isNull, reason: '1:$n');
      }
    });

    test('a NEAR MISS names the ratio it is not, because that is the '
        'dangerous one', () {
      // Nobody lays a 1:96 rule on a sheet drawn at 1:150. Everybody would
      // on one drawn at 1:97.95, which is why the near miss is the case the
      // message has to spell out.
      final notice = DrawingScale.fitted(
        sceneFactorForRatio(PhysicalRatio.oneOver(97.9523)),
      ).notice;

      expect(notice, isNotNull);
      expect(notice, contains('NOT TO SCALE'));
      expect(notice, contains('1:97.95'));
      expect(notice, contains('2%'));
      expect(notice, contains('1:96'));
      expect(notice, contains('graphic scale bar'));
    });

    test('a ratio nowhere near a standard one says so without naming one', () {
      final notice = DrawingScale.fitted(
        sceneFactorForRatio(PhysicalRatio.oneOver(150)),
      ).notice;

      expect(notice, contains('1:150.00'));
      expect(notice, contains('not a standard ratio'));
      expect(notice, isNot(contains('within')));
    });

    test('the degenerate NTS of a table sheet does not divide by zero', () {
      // `equipment_sheet.dart` asks for NTS with a zero factor.
      final notice = DrawingScale.fitted(const SceneFactor(0)).notice;
      expect(notice, contains('NOT TO SCALE'));
      expect(notice, isNot(contains('Infinity')));
      expect(notice, isNot(contains('NaN')));
    });
  });

  group('THE SHIPPED FIT, on a real ANSI B portrait elevation', () {
    // ====================================================================
    // THIS GROUP USED TO EXERCISE A FUNCTION NOTHING SHIPPED.
    // ====================================================================
    // It called `chooseDrawingScale(rackWidth x rackHeight, layout
    // .drawingArea)` — a helper with ZERO production callers, because
    // `elevation_sheet.dart`'s `_fitElevation` does the denominator walk
    // itself against the real scene's INK extent (RU ruler + panel + load
    // gutter + inflated print type) inside `elevationAreaOf(drawingArea)`,
    // which is 90 pt shorter. Two implementations of the exit criterion's
    // own arithmetic, and the tested one was the dead one.
    //
    // They disagreed, and both suites passed anyway. The old test here
    // said `chooseFor(60).denominator == 8` under the comment "the claim
    // 'NTS never fires for a legal elevation' is only worth making if the
    // worst case is checked"; `elevation_sheet_test.dart` said the same 60
    // U rack lands at 1:10. The shipped answer is 1:10, so what stood in
    // this file was a false statement about the deliverable, protected by
    // seven green tests.
    //
    // `chooseDrawingScale` is deleted. What remains valuable here is the
    // PHYSICAL ARITHMETIC — paper points from the nanometre literals — and
    // that is now asserted against the drawing the exporter actually
    // emits.

    ElevationSheet elevation(int heightU) {
      final rack = testRack(heightU: heightU);
      final set = SheetSet.forRacks(<Rack>[rack]);
      return buildElevationSheet(
        sheet: set.sheets.firstWhere(
          (s) => s.role == SheetRole.rackElevationFront,
        ),
        rack: rack,
        devices: const <DeviceInstance>[],
        templates: const <String, TemplateSnapshot>{},
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'smith.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        measurer: FakeMeasurer(),
      );
    }

    /// The chassis's drawn height on paper, in points — the number an
    /// integrator puts a rule against.
    double drawnRackHeightPt(ElevationSheet sheet) =>
        sheet.rackScene.chassisBounds.height *
        sheet.scale.sceneFactor.unitsToPoints;

    /// The rectangle the elevation is really fitted into.
    final area = elevationAreaOf(
      SheetLayout.resolve(
        geometry: const SheetGeometry(SheetSize.ansiBPortrait),
        revisionRowCount: 1,
      ).drawingArea,
    );

    test('a 45 U rack is drawn at 1:8, and measures 708.75 pt = 9.84375 in '
        'on the paper', () {
      // docs/08 §6.1 claims 9.84 in. Reproduced from the nanometre
      // literals, and then confirmed against what the EXPORTER draws.
      expect(_paperPointsForRu(45, 8), 708.75);
      expect(_paperPointsForRu(45, 8) / _pointsPerInch, 9.84375);

      final sheet = elevation(45);
      expect(sheet.scale.label, '1:8');
      expect(drawnRackHeightPt(sheet), closeTo(708.75, 1e-9));
      expect(drawnRackHeightPt(sheet) / _pointsPerInch, closeTo(9.84375, 1e-9));
    });

    test('a 42 U rack — the rack named in the exit criterion — is drawn '
        '661.5 pt tall', () {
      expect(_paperPointsForRu(42, 8), 661.5);

      final sheet = elevation(42);
      expect(sheet.scale.denominator, 8);
      expect(drawnRackHeightPt(sheet), closeTo(661.5, 1e-9));
    });

    test('EVERY legal height is drawn at EXACTLY the ratio its title block '
        'prints', () {
      // The exit criterion, swept: for each rack height the exporter emits
      // a sheet, and the chassis on that sheet measures
      // `heightU x 44_450_000 x 72 / 25_400_000 / n` points for the `n` the
      // SCALE field carries. Nothing here reads `unitsPerRu`,
      // `pointsForLen` or `sceneFactor` to build the expectation.
      for (final heightU in <int>[1, 2, 4, 6, 12, 24, 42, 45, 57, 60]) {
        final sheet = elevation(heightU);
        final n = sheet.scale.denominator;
        expect(n, isNotNull, reason: '${heightU}U reported NTS');
        expect(
          drawnRackHeightPt(sheet),
          closeTo(_paperPointsForRu(heightU, n!), 1e-9),
          reason: '${heightU}U at ${sheet.scale.label}',
        );
        // ...and it is INSIDE the rectangle it was fitted to, which is the
        // claim the ratio is only meaningful alongside.
        expect(sheet.fit.fits, isTrue, reason: '${heightU}U overruns');
      }
    });

    test('the tallest legal rack (60 U, CR-038) needs 1:10 — 1:8 does NOT '
        'fit, and the old test here said it did', () {
      // The reproduced false assertion. 60 U at 1:8 is 945.0 pt of chassis
      // alone; the rectangle the elevation is fitted into is shorter than
      // that, so 1:8 cannot be the answer however the raw drawing area
      // measures. Stated from literals on both sides.
      expect(_paperPointsForRu(60, 8), 945.0);
      expect(
        area.height,
        lessThan(945.0),
        reason: 'the elevation area is what 1:8 has to fit inside',
      );
      expect(_paperPointsForRu(60, 10), 756.0);
      expect(756.0, lessThan(area.height));

      final sheet = elevation(60);
      expect(sheet.scale.label, '1:10');
      expect(drawnRackHeightPt(sheet), closeTo(756.0, 1e-9));
    });

    test('a short rack is drawn LARGER, and it is the WIDTH that stops '
        'it', () {
      // 4 U at 1:1 is 504 pt tall, which fits the area vertically — so a
      // fit that only looked at HEIGHT would answer 1:1, the largest scale
      // there is. The EIA-19 panel ALONE is 1368 pt wide at full size
      // against a 690 pt area, so the width rules 1:1 out on its own. The
      // shipped fit must be checking both axes to get past that.
      final sheet = elevation(4);
      expect(sheet.scale.denominator, greaterThan(1));
      expect(sheet.scale.denominator, lessThan(8));

      // Spelled out from literals, so the reason is checkable rather than
      // asserted: the vertical axis alone would have allowed 1:1...
      expect(_paperPointsForRu(4, 1), 504.0);
      expect(504.0, lessThan(area.height));
      // ...and the horizontal axis alone rules it out, because the EIA-19
      // panel really is 1368 pt at full size.
      expect(pointsForLen(const Len(_nmEia19Panel)), 1368.0);
      expect(1368.0, greaterThan(area.width));

      // ...and the ink the exporter EMITTED at the chosen ratio is inside
      // the area on both axes, measured on the emitted scene.
      final s = sheet.scale.sceneFactor.unitsToPoints;
      final bounds = sheet.rackScene.scene.bounds;
      expect(bounds.width * s, lessThanOrEqualTo(area.width));
      expect(bounds.height * s, lessThanOrEqualTo(area.height));
      // The rack is WIDER than it is tall at 4 U, which is why width is
      // the binding constraint here and not an incidental one.
      expect(bounds.width, greaterThan(bounds.height));
    });
  });

  group('the graphic scale bar', () {
    test('one foot at 1:8 draws 108.0 pt (1.5 in) long', () {
      expect(
        graphicScaleBarPoints(PhysicalRatio.oneOver(8)),
        closeTo(108, 1e-9),
      );
      expect(
        graphicScaleBarPoints(PhysicalRatio.oneOver(8)) / _pointsPerInch,
        closeTo(1.5, 1e-9),
      );
    });

    test('the bar length is 12 · 72 / n for every standard ratio', () {
      for (final n in kStandardScaleDenominators) {
        expect(
          graphicScaleBarPoints(PhysicalRatio.oneOver(n)),
          closeTo(12 * _pointsPerInch / n, 1e-9),
        );
      }
    });

    test('a multi-foot bar scales linearly', () {
      expect(
        graphicScaleBarPoints(PhysicalRatio.oneOver(8), feet: 5),
        closeTo(540, 1e-9),
      );
    });
  });

  group('the section 6.2 legibility check', () {
    test('rack text at 1:8 falls UNDER the 6 pt hard floor — which is why '
        'annotation must not shrink with the drawing', () {
      // RackTextSizes.type is 8 diagram units; at 1:8 that is 5.73 pt of
      // paper. This is a real, reported finding about the current scene,
      // not a hypothetical: it is the reason a print type scale is on the
      // elevation stage's list.
      final report = checkLegibility(
        sceneMinTextSizePt: RackTextSizes.type,
        scale: sceneFactorForRatio(PhysicalRatio.oneOver(8)),
      );
      expect(report.paperTextPt, closeTo(5.727, 0.001));
      expect(report.meetsHardFloor, isFalse);
      expect(report.notice, contains('legibility floor'));
    });

    test('comfortably large text produces no notice at all', () {
      final report = checkLegibility(
        sceneMinTextSizePt: 12,
        scale: const SceneFactor(1),
      );
      expect(report.meetsHardFloor, isTrue);
      expect(report.meetsSoftFloor, isTrue);
      expect(report.notice, isNull);
    });

    test('between the hard and soft floors, the notice says so without '
        'claiming illegibility', () {
      final report = checkLegibility(
        sceneMinTextSizePt: 6.5,
        scale: const SceneFactor(1),
      );
      expect(report.meetsHardFloor, isTrue);
      expect(report.meetsSoftFloor, isFalse);
      expect(report.notice, contains('preferred'));
    });

    test('the floors are the ones the doc names', () {
      expect(kMinPrintPt, 6.0);
      expect(kSoftPrintPt, 7.0);
    });
  });

  group('fitSceneFactor is the fitScale of section 6.2', () {
    test('takes the smaller of the two axis ratios', () {
      final factor = fitSceneFactor(
        const DBox.fromLtwh(0, 0, 200, 100),
        availableWidth: 400,
        availableHeight: 150,
      );
      expect(factor.unitsToPoints, closeTo(1.5, 1e-12));
    });

    test('an EMPTY content box does not produce an infinite factor', () {
      // `_fitElevation`'s refinement pass feeds this the emitted scene's
      // bounds. A degenerate axis must mean "this axis does not
      // constrain", not "divide by zero" — an infinite factor would be
      // multiplied into every coordinate on the sheet.
      for (final box in <DBox>[
        const DBox.fromLtwh(0, 0, 0, 0),
        const DBox.fromLtwh(0, 0, 200, 0),
        const DBox.fromLtwh(0, 0, 0, 100),
      ]) {
        final factor = fitSceneFactor(
          box,
          availableWidth: 100,
          availableHeight: 100,
        );
        expect(factor.unitsToPoints.isFinite, isTrue, reason: '$box');
        expect(factor.unitsToPoints, greaterThan(0), reason: '$box');
      }
    });

    test('a box far too big for the area shrinks to fit it exactly', () {
      // The property the deleted `chooseDrawingScale` fallback was tested
      // for, kept where the code that still runs it lives.
      final factor = fitSceneFactor(
        const DBox.fromLtwh(0, 0, 100000, 100000),
        availableWidth: 100,
        availableHeight: 100,
      );
      expect(100000 * factor.unitsToPoints, closeTo(100, 1e-9));
      expect(DrawingScale.fitted(factor).label, 'NTS');
    });
  });
}
