// PLAN-H/4: the drawn bar, and the sheet that says why there is none
// (docs/15 §8, DR-151 §11.150).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASE LAYS THE BAR AGAINST THE DRAWING
// ═══════════════════════════════════════════════════════════════════════
// Everything else here is a property of one number. The case that matters
// asserts the only thing a scale bar claims: **that laying it between two
// points on the plan measures the real distance between them.** Two pins
// exactly one bar-length apart in the building must be exactly
// `bar.lengthPt` apart on the page.
//
// It is written that way rather than by recomputing the arithmetic,
// because a test that repeats the implementation's multiplication agrees
// with it whichever direction it is wrong in.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const _ul = Uuid('ul-1');

/// 100 ft over 1000 px, so **one foot is ten pixels** and every figure
/// below is arithmetic a reader can check without a calculator.
final PlanScale _tenPxPerFoot = PlanScale(
  a: const PxPt(0, 0),
  b: const PxPt(1000, 0),
  distance: Len.fromInches(1200),
);

/// A SECOND, DELIBERATELY DIFFERENT CALIBRATION: 10 ft over 1000 px, so
/// one foot is a HUNDRED pixels.
///
/// It exists because a mutation replacing `nanometresPerPixel` with the
/// literal value the first fixture produces SURVIVED: every case was
/// calibrated the same way, so nothing could tell a bar that reads the
/// scale from one that has it baked in. A property proven by one fixture's
/// number is not proven.
final PlanScale _hundredPxPerFoot = PlanScale(
  a: const PxPt(0, 0),
  b: const PxPt(1000, 0),
  distance: Len.fromInches(120),
);

/// Stored, and unable to yield a factor.
const PlanScale _degenerate = PlanScale(
  a: PxPt(10, 10),
  b: PxPt(10, 10),
  distance: Len(36 * Len.nmPerInch),
);

PlanUnderlay _underlay({PlanScale? scale}) => PlanUnderlay(
  id: _ul,
  name: 'Level 1',
  imageMember: 'underlays/ul-1.png',
  format: PlanImageFormat.png,
  pixelWidth: 2000,
  pixelHeight: 1500,
  contentHash: 'sha256:ul',
  order: const FracIndex('a0'),
  meta: testMeta(),
  scale: scale,
);

SheetDef _sheet() => SheetSet.forRacks(
  <Rack>[testRack()],
  planUnderlays: [_underlay()],
).sheets.firstWhere((s) => s.role == SheetRole.devicePlan);

PlanSheet _build({
  PlanScale? scale,
  UnitSystem units = UnitSystem.imperial,
  List<PlanPinSubject> pins = const [],
  Map<Uuid, String> labels = const {},
}) => buildPlanSheet(
  sheet: _sheet(),
  underlay: _underlay(scale: scale),
  pins: pins,
  info: fullProjectInfo(),
  settings: ProjectSettings()..displayUnits = units,
  revisions: const <RevisionEntry>[],
  fileName: 'smith.rppj',
  issuedAt: DateTime.utc(2026, 9, 9),
  measurer: FakeMeasurer(),
  labels: labels,
);

void main() {
  group('an uncalibrated plan gets no bar and says so', () {
    /// LOAD-BEARING. G4, and the reason `#643`'s plan did not work: the
    /// person holding the print has no findings list.
    test('no scale: no bar, and the sheet prints NOT TO SCALE itself', () {
      final built = _build();

      expect(built.bar, isNull);
      expect(
        textsOf(built.scene.ops),
        contains(kPlanNotToScaleNote),
        reason: 'PLN-001 is a finding and never reaches this reader',
      );
      expect(kPlanNotToScaleNote, contains('NOT TO SCALE'));
      expect(kPlanNotToScaleNote, contains('NOT CALIBRATED'));
    });

    /// LOAD-BEARING. A stored-but-unusable scale is uncalibrated, and the
    /// bar must agree with the flag the underlay row prints.
    test('a DEGENERATE scale is uncalibrated too', () {
      final built = _build(scale: _degenerate);

      expect(built.bar, isNull);
      expect(textsOf(built.scene.ops), contains(kPlanNotToScaleNote));
      expect(
        _underlay(scale: _degenerate).isCalibrated,
        isFalse,
        reason: 'the two answers cannot disagree',
      );
    });

    test('and a calibrated plan never prints that note', () {
      final texts = textsOf(_build(scale: _tenPxPerFoot).scene.ops);
      expect(texts, isNot(contains(kPlanNotToScaleNote)));
    });
  });

  group('the bar measures the drawing', () {
    /// THE ONLY THING A SCALE BAR CLAIMS.
    ///
    /// Two pins exactly one bar-length apart in the BUILDING must be
    /// exactly `bar.lengthPt` apart on the PAGE. At ten pixels per foot a
    /// 50 ft bar is 500 image pixels, so the pins go at x = 100 and
    /// x = 600 and the assertion is that the gap between their callouts'
    /// pins equals the bar.
    test('laying the bar between two pins that far apart spans them', () {
      final built = _build(
        scale: _tenPxPerFoot,
        pins: const [
          PlanPinSubject(
            entityId: Uuid('a'),
            at: PxPt(100, 700),
            carrier: PlanPinCarrier.rack,
          ),
          PlanPinSubject(
            entityId: Uuid('b'),
            at: PxPt(600, 700),
            carrier: PlanPinCarrier.outlet,
          ),
        ],
      );

      final bar = built.bar!;
      expect(bar.label, '50 ft', reason: 'the ladder value this fit allows');

      // 500 image pixels through the sheet's own fit.
      final pageGap = 500 * built.factor.unitsToPoints;
      expect(
        bar.lengthPt,
        closeTo(pageGap, 1e-6),
        reason: 'the bar is 50 ft and so is the gap between the pins',
      );
    });

    test('the bar is drawn as four alternating segments end to end', () {
      final built = _build(scale: _tenPxPerFoot);
      final bar = built.bar!;
      // The pill rects belong to callouts; with no pins these are the
      // bar's own.
      final rects = built.scene.ops.whereType<OpRect>().toList();
      final segments = rects
          .where((r) => (r.r.height - kScaleBarHeightPt).abs() < 1e-9)
          .toList();

      expect(segments, hasLength(kScaleBarDivisions));
      for (final s in segments) {
        expect(s.r.width, closeTo(bar.lengthPt / kScaleBarDivisions, 1e-9));
      }
      // Contiguous: each starts where the last ended.
      for (var i = 1; i < segments.length; i++) {
        expect(segments[i].r.left, closeTo(segments[i - 1].r.right, 1e-9));
      }
      // ALTERNATING BLACK AND PAPER, which is what survives greyscale.
      expect(segments.first.fill?.argb, 0xFF000000);
      expect(segments[1].fill?.argb, 0xFFFFFFFF);
      expect(segments[2].fill?.argb, 0xFF000000);
    });

    test('the ends are labelled 0 and the round total', () {
      final texts = textsOf(_build(scale: _tenPxPerFoot).scene.ops);
      expect(texts, contains('0'));
      expect(texts, contains('50 ft'));
    });
  });

  group('choosing the length', () {
    PlanScaleBar? choose({
      required double available,
      UnitSystem units = UnitSystem.imperial,
      PlanScale? scale,
    }) => choosePlanScaleBar(
      underlay: _underlay(scale: scale ?? _tenPxPerFoot),
      factor: const SceneFactor(0.5),
      available: available,
      units: units,
    );

    /// AND A TIE GOES TO THE LARGER BAR, which this case pins on purpose.
    ///
    /// 0.5 pt per pixel and 10 px per foot is 5 pt per foot, so a 1000 pt
    /// area's 250 pt budget is EXACTLY 50 ft. The drawn length is a double
    /// all the way down and lands at 250.00000000000003, so a bare `<=`
    /// picked 25 ft. The budget is an aesthetic limit and the last ulp is
    /// not a decision anybody made; a bar that exactly fills it is the best
    /// bar available.
    test('the LARGEST round value that fits the budget wins, ties '
        'included', () {
      expect(choose(available: 1000)!.label, '50 ft');
      // Halve the area and the next rung down wins.
      expect(choose(available: 500)!.label, '25 ft');
    });

    /// LOAD-BEARING. §11.150.5: never refused for scale.
    test('when nothing fits, the SMALLEST is taken anyway', () {
      // A 20 pt area cannot hold even 1 ft at 5 pt per foot... it can, so
      // squeeze until it cannot: a 4 pt area's budget is 1 pt and one foot
      // is five.
      final bar = choose(available: 4)!;
      expect(bar.label, '1 ft');
      expect(
        bar.lengthPt,
        greaterThan(4 * 0.25),
        reason: 'longer than its budget, and still true',
      );
    });

    test('a metric project gets metres', () {
      final bar = choose(available: 1000, units: UnitSystem.metric)!;
      expect(bar.label, endsWith(' m'));
      expect(bar.label, isNot(contains('ft')));
    });

    test('an uncalibrated underlay chooses nothing', () {
      expect(choose(available: 1000, scale: _degenerate), isNull);
    });

    /// LOAD-BEARING, AND IT EXISTS BECAUSE A MUTATION SURVIVED.
    ///
    /// A bar that ignored the calibration entirely, using the first
    /// fixture's ratio as a literal, passed every other case in this file.
    /// Ten times the pixels per foot means a tenth of the real length in
    /// the same drawn space.
    test('the bar READS the calibration: ten times finer, ten times '
        'shorter a run', () {
      // 10 px per foot: a 250 pt budget holds 50 ft.
      expect(choose(available: 1000)!.label, '50 ft');
      // 100 px per foot: the same budget holds 5 ft.
      expect(
        choose(available: 1000, scale: _hundredPxPerFoot)!.label,
        '5 ft',
      );
    });
  });

  group('the placeholder that reached a deliverable', () {
    /// DR-151 §11.150.1. `PLAN-H/1` printed `PLAN SCALED TO FIT · SEE BAR`
    /// on a client deliverable with no bar on the page, and
    /// `unbuilt_copy_accuracy_test.dart` could not see it because it scans
    /// `rackpal_ui` and `apps/rackpal`. This is the narrow guard the sheet
    /// can carry for itself.
    test('no sheet text points at something that is not drawn', () {
      for (final scale in <PlanScale?>[null, _tenPxPerFoot]) {
        final built = _build(scale: scale);
        final texts = textsOf(built.scene.ops);
        final hasBar = built.bar != null;
        for (final text in texts) {
          if (text.toUpperCase().contains('SEE BAR')) {
            expect(
              hasBar,
              isTrue,
              reason: '"$text" is printed on a sheet with no bar',
            );
          }
        }
      }
    });
  });
}
