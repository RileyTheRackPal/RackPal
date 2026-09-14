// PLAN-H/1: the twelfth slot, the AUTO rule, and the sheet behind it
// (docs/15 §8, DR-149 §11.148).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASES ARE THE ONES ABOUT WHAT IS *NOT* EMITTED
// ═══════════════════════════════════════════════════════════════════════
// `AUTO` is not a preference (docs/15 §8): M6's exit criterion is that all
// four starters export a COMPLETE set, and the starters are byte-verified
// goldens. A plan slot that emitted on a document with no underlay, or on
// one whose underlay nobody pinned anything to, would put a sheet into
// every one of them. Three cases below assert an absence for that reason
// and they are the ones to keep if this file is ever trimmed.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const _ul = Uuid('ul-1');
const _ul2 = Uuid('ul-2');

PlanUnderlay _underlay({
  Uuid id = _ul,
  String name = 'Level 1',
  String order = 'a0',
  int width = 2000,
  int height = 1500,
}) => PlanUnderlay(
  id: id,
  name: name,
  imageMember: 'underlays/${id.v}.png',
  format: PlanImageFormat.png,
  pixelWidth: width,
  pixelHeight: height,
  contentHash: 'sha256:ul',
  order: FracIndex(order),
  meta: testMeta(),
);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-plan-sheet'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: testMeta(),
);

void _addRack(RackDocument doc, {PlanPin? pin, String id = 'rack-1'}) {
  doc.racks[Uuid(id)] = Rack(
    id: Uuid(id),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: testMeta(),
    planPin: pin,
  );
}

void _addOutlet(RackDocument doc, String key, {PlanPin? pin}) {
  doc.outlets[Uuid(key)] = Outlet(
    id: Uuid(key),
    structureBodyId: const Uuid('body-1'),
    designation: key,
    order: const FracIndex('a0'),
    meta: testMeta(),
    planPin: pin,
  );
}

PlanPin _pin(int x, int y, {Uuid on = _ul}) =>
    PlanPin(underlayId: on, at: PxPt(x, y));

void main() {
  group('which underlays earn a sheet', () {
    /// LOAD-BEARING. The whole of `AUTO`.
    test('a document with no underlay resolves exactly the set it '
        'resolved before this role existed', () {
      final doc = _doc();
      _addRack(doc);

      expect(planUnderlaysWithPins(doc), isEmpty);

      final before = SheetSet.forRacks(doc.racks.values);
      final after = SheetSet.forRacks(
        doc.racks.values,
        planUnderlays: planUnderlaysWithPins(doc),
      );
      expect(after.sheets, orderedEquals(before.sheets));
      expect(
        after.sheets.map((s) => s.role),
        isNot(contains(SheetRole.devicePlan)),
      );
    });

    /// LOAD-BEARING. docs/15 §8: one per underlay THAT CARRIES A PIN.
    test('an imported underlay nobody pinned anything to prints nothing', () {
      final doc = _doc()..underlays[_ul] = _underlay();
      _addRack(doc);

      expect(planUnderlaysWithPins(doc), isEmpty);
    });

    test('a plan carrying only the RACK is still a drawing', () {
      // It tells a stranger which room the head end is in, which is the
      // first thing they need. This is where the predicate deliberately
      // parts company with `planMeasurabilityOf`, which counts subjects
      // and never the rack.
      final doc = _doc()..underlays[_ul] = _underlay();
      _addRack(doc, pin: _pin(10, 10));

      expect(planUnderlaysWithPins(doc).map((u) => u.id), [_ul]);
      expect(
        planMeasurabilityOf(doc, doc.underlays[_ul]!).subjectPinCount,
        0,
        reason: 'the two questions differ, and so do the two answers',
      );
    });

    test('an outlet pinned on one plan does not earn the other one a '
        'sheet', () {
      final doc = _doc()
        ..underlays[_ul] = _underlay()
        ..underlays[_ul2] = _underlay(id: _ul2, name: 'Level 2', order: 'a1');
      _addOutlet(doc, 'WP-1', pin: _pin(40, 40));

      expect(planUnderlaysWithPins(doc).map((u) => u.id), [_ul]);
    });
  });

  group('the resolved set', () {
    SheetSet setWith(List<PlanUnderlay> plans) => SheetSet.forRacks(
      <Rack>[testRack()],
      planUnderlays: plans,
    );

    test('plans come FIRST and are numbered T1.nn', () {
      final set = setWith([
        _underlay(id: _ul2, name: 'Level 2', order: 'a1'),
        _underlay(),
      ]);

      expect(set.sheets.first.role, SheetRole.devicePlan);
      expect(
        set.sheets.map((s) => s.ncsId),
        orderedEquals(['T1.01', 'T1.02', 'T2.01', 'T2.02', 'T6.30']),
      );
    });

    test('the order is the USER order, not map or argument order', () {
      // `PlanUnderlay.order` then id, exactly as racks sort. The argument
      // above is deliberately reversed so an implementation that trusted
      // its input would print Level 2 first.
      final set = setWith([
        _underlay(id: _ul2, name: 'Level 2', order: 'a1'),
        _underlay(),
      ]);

      expect(
        set.sheets
            .where((s) => s.role == SheetRole.devicePlan)
            .map((s) => s.underlayName),
        orderedEquals(['Level 1', 'Level 2']),
      );
    });

    test('SHEET i OF n counts the plans', () {
      final set = setWith([_underlay()]);

      expect(set.total, 4, reason: 'one plan, two elevations, one list');
      for (final sheet in set.sheets) {
        expect(sheet.total, 4);
      }
      expect(set.sheets.map((s) => s.index), orderedEquals([1, 2, 3, 4]));
    });

    test('a plan sheet carries its underlay identity and no rack', () {
      final sheet = setWith([_underlay()]).sheets.first;

      expect(sheet.underlayId, _ul);
      expect(sheet.underlayName, 'Level 1');
      expect(sheet.rackId, isNull);
      expect(sheet.size, SheetSize.ansiBLandscape);
    });

    test('every plan id is a well-formed NCS id, so no notice is raised', () {
      final set = setWith([
        _underlay(),
        _underlay(id: _ul2, name: 'Level 2', order: 'a1'),
      ]);
      expect(set.notices, isEmpty);
      for (final sheet in set.sheets) {
        expect(isValidNcsId(sheet.ncsId), isTrue, reason: sheet.ncsId);
      }
    });
  });

  group('the sheet itself', () {
    PlanSheet build({
      List<PlanPinSubject> pins = const [],
      Map<Uuid, String> labels = const {},
    }) {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        planUnderlays: [_underlay()],
      );
      return buildPlanSheet(
        sheet: set.sheets.first,
        underlay: _underlay(),
        pins: pins,
        labels: labels,
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'smith.rmpj',
        issuedAt: DateTime.utc(2026, 9, 9),
        measurer: FakeMeasurer(),
      );
    }

    test('it draws the underlay exactly once, inside one bracket', () {
      final ops = build().scene.ops;

      expect(ops.whereType<OpImage>(), hasLength(1));
      expect(
        ops.whereType<OpSave>(),
        hasLength(1),
        reason: 'one save/transform/restore, as the elevation does',
      );
      expect(ops.whereType<OpRestore>(), hasLength(1));
    });

    /// LOAD-BEARING. docs/15 §8 forbids a printed ratio outright.
    test('the title block says NTS and never a ratio', () {
      final texts = textsOf(build().scene.ops);

      expect(texts, contains('NTS'));
      for (final text in texts) {
        expect(
          text,
          isNot(matches(RegExp(r'^1\s*:\s*\d'))),
          reason: 'a ratio between a page and a scan is not a scale',
        );
      }
    });

    test('the title block names the FLOOR, since a plan names no rack', () {
      final texts = textsOf(build().scene.ops).join(' ');

      expect(texts, contains('Level 1'));
      expect(texts, contains('DEVICE LOCATION PLAN'));
      expect(
        texts,
        isNot(contains('MASTER RACK')),
        reason: 'the rack line belongs to an elevation',
      );
    });

    test('the underlay is fitted and CENTRED, never stretched', () {
      final built = build();
      final transform = built.scene.ops.whereType<OpTransform>().last;
      final m = transform.m;

      // Uniform scale: x and y factors equal, so aspect survives.
      expect(m.entry(0, 0), closeTo(m.entry(1, 1), 1e-9));
      expect(m.entry(0, 0), closeTo(built.factor.unitsToPoints, 1e-9));

      // 2000 x 1500 into a landscape drawing area is width-bound, so the
      // drawing touches neither top nor bottom and the vertical offset is
      // strictly positive.
      expect(m.entry(1, 3), greaterThan(0));
    });

    /// AN END-TO-END PROPERTY, AND NOT A LOAD-BEARING CASE.
    ///
    /// This said that swapping `underlayBounds` for `scene.bounds` in
    /// `plan_sheet.dart` survived it, because `buildPlanScene` sets both to
    /// one box. Since `#904` the sheet fits on `planUnderlayBounds` BEFORE
    /// any scene exists, since the marks are sized from that fit, so the
    /// swap is no longer something that file can spell. The property is
    /// still real, and this is what fails the day a fit reads anything that
    /// unions in the marks.
    test('a pin dragged off the picture does not shrink the plan', () {
      final inside = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(100, 100),
            carrier: PlanPinCarrier.rack,
          ),
        ],
      );
      final strayed = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(9000, 9000),
            carrier: PlanPinCarrier.rack,
          ),
        ],
      );

      expect(
        strayed.factor.unitsToPoints,
        closeTo(inside.factor.unitsToPoints, 1e-9),
        reason: 'fitted on underlayBounds, not on the scene ink',
      );
    });

    /// LOAD-BEARING. The callouts must NOT scale with the drawing.
    ///
    /// Scene units on a plan are image pixels, so a pill inside the
    /// transform bracket would print six times larger on a 4000-pixel scan
    /// than on a 600-pixel one. The check is that the pill's height is the
    /// type size plus padding in POINTS, on a plan whose fit factor is
    /// nowhere near 1.
    test('a callout is laid out in page points, outside the bracket', () {
      final built = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(1000, 750),
            carrier: PlanPinCarrier.rack,
          ),
        ],
        labels: const {Uuid('rack-1'): 'RK-1'},
      );

      expect(
        built.factor.unitsToPoints,
        lessThan(0.5),
        reason: '2000 px into a landscape sheet is a heavy reduction',
      );
      final pill = built.scene.ops.whereType<OpRoundRect>().last;
      expect(
        pill.r.height,
        closeTo(kCalloutTextPt + kCalloutPadPt * 2, 1e-9),
        reason: 'unscaled: the pill is the same size on every plan',
      );
      expect(
        built.scene.ops.whereType<OpText>().map((o) => o.text),
        contains('RK-1'),
      );
    });

    /// LOAD-BEARING, AND IT EXISTS BECAUSE A MUTATION SURVIVED.
    ///
    /// The case above pins the pill's SIZE and says nothing about where it
    /// lands, so replacing the page mapping with raw image pixels left it
    /// green: every callout moved to the wrong part of the sheet and no
    /// assertion noticed. **A designator printed beside the wrong wall is
    /// the one failure this whole sheet exists to prevent**, so the mapping
    /// gets its own case.
    test('a pin at the centre of the image lands at the centre of the '
        'drawing', () {
      // The underlay is 2000 x 1500 and the sheet centres it, so the pixel
      // at its middle is the point at the middle of the fitted picture.
      final built = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(1000, 750),
            carrier: PlanPinCarrier.rack,
          ),
        ],
        labels: const {Uuid('rack-1'): 'RK-1'},
      );

      final layout = sheetLayoutFor(
        SheetSet.forRacks(
          <Rack>[testRack()],
          planUnderlays: [_underlay()],
        ).sheets.first,
        const <RevisionEntry>[],
      );
      final area = layout.drawingArea;
      final pill = built.scene.ops.whereType<OpRoundRect>().last.r;

      // The pill hangs off its pin by the callout offset, so it sits NEAR
      // the centre rather than on it. Well inside a tenth of the area
      // either way, and nowhere near where a raw-pixel mapping would put
      // it.
      expect(
        pill.left + pill.width / 2,
        closeTo(area.left + area.width / 2, area.width / 10),
      );
      expect(
        pill.top + pill.height / 2,
        closeTo(area.top + area.height / 2, area.height / 10),
      );
    });

    test('a pin at the image origin lands at the fitted picture corner, '
        'not at the page origin', () {
      final built = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(0, 0),
            carrier: PlanPinCarrier.rack,
          ),
        ],
        labels: const {Uuid('rack-1'): 'RK-1'},
      );
      final pill = built.scene.ops.whereType<OpRoundRect>().last.r;

      // 2000 x 1500 is width-bound on a landscape sheet, so the picture is
      // letterboxed vertically: its top edge is BELOW the drawing area's.
      final layout = sheetLayoutFor(
        SheetSet.forRacks(
          <Rack>[testRack()],
          planUnderlays: [_underlay()],
        ).sheets.first,
        const <RevisionEntry>[],
      );
      expect(
        pill.top,
        greaterThan(layout.drawingArea.top),
        reason: 'the pin is at the picture corner, not the paper corner',
      );
    });

    /// LOAD-BEARING. A pin with nothing to say gets no white box.
    test('a pin whose carrier has no designator keeps its marker and gets '
        'no pill', () {
      final built = build(
        pins: const [
          PlanPinSubject(
            entityId: Uuid('rack-1'),
            at: PxPt(1000, 750),
            carrier: PlanPinCarrier.rack,
          ),
        ],
      );

      expect(built.callouts.ops, isEmpty);
      expect(
        built.scene.ops.whereType<OpImage>(),
        hasLength(1),
        reason: 'the plan is still drawn',
      );
    });

    test('two builds of one document are identical', () {
      expect(describeOps(build().scene.ops), describeOps(build().scene.ops));
    });

    test('the scene is the page, so the sheet frame is not clipped', () {
      final built = build();
      expect(built.scene.bounds.width, SheetSize.ansiBLandscape.widthPt);
      expect(built.scene.bounds.height, SheetSize.ansiBLandscape.heightPt);
    });
  });

  /// `#904`, DR-169 §11.168.10: a printed mark is the size of the callout
  /// pill's round end, whatever the underlay's proportions.
  ///
  /// EVERY READING COMES OFF THE SHEET'S OWN OPS: a circle's radius times
  /// the bracket's scale, and a pill's height off its round rect. No case
  /// here types the production expression, which is the trap `#903` found
  /// one surface over, where five green cases re-derived the canvas's
  /// formula and proved that it divides.
  group('the printed mark', () {
    ({double mark, double pillEnd, double scale}) printed(int w, int h) {
      final underlay = _underlay(width: w, height: h);
      final built = buildPlanSheet(
        sheet: SheetSet.forRacks(
          <Rack>[testRack()],
          planUnderlays: [underlay],
        ).sheets.first,
        underlay: underlay,
        pins: [
          PlanPinSubject(
            entityId: const Uuid('outlet-1'),
            at: PxPt(w ~/ 2, h ~/ 2),
            carrier: PlanPinCarrier.outlet,
          ),
        ],
        labels: const {Uuid('outlet-1'): 'WP-1'},
        info: fullProjectInfo(),
        settings: ProjectSettings(),
        revisions: const <RevisionEntry>[],
        fileName: 'smith.rmpj',
        issuedAt: DateTime.utc(2026, 9, 14),
        measurer: FakeMeasurer(),
      );
      final ops = built.scene.ops;
      final scale = ops.whereType<OpTransform>().last.m.entry(0, 0);
      return (
        mark: ops.whereType<OpCircle>().single.radius * scale,
        pillEnd: ops.whereType<OpRoundRect>().last.r.height / 2,
        scale: scale,
      );
    }

    /// LOAD-BEARING, AND IT IS THE EXIT CRITERION.
    ///
    /// One scan size turned on its side, so the fit binds on a DIFFERENT
    /// axis for each. That is what the retired fraction could not survive:
    /// it read the longer side while the fit bound the tighter one.
    test('two plans of different proportions print the same mark', () {
      final landscape = printed(2000, 1500);
      final portrait = printed(1500, 2000);

      expect(
        (landscape.scale - portrait.scale).abs(),
        greaterThan(0.01),
        reason: 'the two fits must differ, or this case proves nothing',
      );
      expect(landscape.mark, closeTo(portrait.mark, 1e-9));
    });

    /// LOAD-BEARING. The user's rule is "the same size as the pills", so
    /// the mark is read against a pill ON THE SAME SHEET, and neither side
    /// of the comparison is a number this file wrote down.
    test('a printed mark is the size of the round end of its pill', () {
      for (final (w, h) in const [(2000, 1500), (1500, 2000), (4000, 1000)]) {
        final sheet = printed(w, h);
        expect(sheet.mark, closeTo(sheet.pillEnd, 1e-9), reason: '${w}x$h');
      }
    });
  });

  group('the pins one sheet draws', () {
    test('only this underlay, ordered by entity id', () {
      final doc = _doc()
        ..underlays[_ul] = _underlay()
        ..underlays[_ul2] = _underlay(id: _ul2, name: 'Level 2', order: 'a1');
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'b-outlet', pin: _pin(20, 20));
      _addOutlet(doc, 'a-outlet', pin: _pin(30, 30));
      _addOutlet(doc, 'z-elsewhere', pin: _pin(40, 40, on: _ul2));

      final pins = planPinsFor(doc, _ul);
      expect(
        pins.map((p) => p.entityId.v),
        orderedEquals(['a-outlet', 'b-outlet', 'rack-1']),
        reason: 'a Map iteration order must not reach a deliverable',
      );
      expect(
        pins.map((p) => p.carrier),
        orderedEquals([
          PlanPinCarrier.outlet,
          PlanPinCarrier.outlet,
          PlanPinCarrier.rack,
        ]),
      );
    });

    test('each carrier prints its OWN designator', () {
      // DR-150 §11.149.3. Not the cable's: a pinned outlet has several
      // Pull Sheet rows and a cable designator is not a function of a pin.
      final doc = _doc()..underlays[_ul] = _underlay();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'WP-1', pin: _pin(20, 20));

      final labels = planPinLabelsFor(doc, planPinsFor(doc, _ul));
      expect(labels[const Uuid('rack-1')], 'RK-1');
      expect(labels[const Uuid('WP-1')], 'WP-1');
    });

    /// LOAD-BEARING. G4: an empty pill is a white box that says nothing.
    test('a carrier with a blank designator is ABSENT from the map, never '
        'mapped to an empty string', () {
      final doc = _doc()..underlays[_ul] = _underlay();
      doc.outlets[const Uuid('blank')] = Outlet(
        id: const Uuid('blank'),
        structureBodyId: const Uuid('body-1'),
        designation: '   ',
        order: const FracIndex('a0'),
        meta: testMeta(),
        planPin: _pin(30, 30),
      );

      final labels = planPinLabelsFor(doc, planPinsFor(doc, _ul));
      expect(labels.containsKey(const Uuid('blank')), isFalse);
      expect(labels, isEmpty);
    });

    test('an unpinned carrier contributes nothing', () {
      final doc = _doc()..underlays[_ul] = _underlay();
      _addRack(doc);
      _addOutlet(doc, 'WP-1');

      expect(planPinsFor(doc, _ul), isEmpty);
    });
  });
}
