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
    PlanSheet build({List<PlanPinSubject> pins = const []}) {
      final set = SheetSet.forRacks(
        <Rack>[testRack()],
        planUnderlays: [_underlay()],
      );
      return buildPlanSheet(
        sheet: set.sheets.first,
        underlay: _underlay(),
        pins: pins,
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

    /// AN END-TO-END PROPERTY, AND NOT A LOAD-BEARING CASE, WHICH A
    /// MUTATION ESTABLISHED RATHER THAN A READING.
    ///
    /// Swapping `underlayBounds` for `scene.bounds` in `plan_sheet.dart`
    /// SURVIVES this case, because `buildPlanScene` sets both to the same
    /// box. The property is real and worth pinning; what it cannot do is
    /// tell the two spellings apart, and saying so here is cheaper than
    /// the next reader assuming it can.
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

    test('two builds of one document are identical', () {
      expect(describeOps(build().scene.ops), describeOps(build().scene.ops));
    });

    test('the scene is the page, so the sheet frame is not clipped', () {
      final built = build();
      expect(built.scene.bounds.width, SheetSize.ansiBLandscape.widthPt);
      expect(built.scene.bounds.height, SheetSize.ansiBLandscape.heightPt);
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

    test('an unpinned carrier contributes nothing', () {
      final doc = _doc()..underlays[_ul] = _underlay();
      _addRack(doc);
      _addOutlet(doc, 'WP-1');

      expect(planPinsFor(doc, _ul), isEmpty);
    });
  });
}
