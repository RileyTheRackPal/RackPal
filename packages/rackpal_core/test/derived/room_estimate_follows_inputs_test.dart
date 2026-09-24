// A room's plan estimate follows its inputs (DR-191 §11.190, board #926).
//
// Until DR-191 the figure was written only when an outline was closed or
// reshaped, so the order a person worked in decided whether it ever
// appeared. These cases make the edits in the OTHER order, through a real
// `DocumentController`, and read the room back after each edit and each
// undo: the artifact is the stored figure, not a call count.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/plan_doc.dart';

const _square = <PxPt>[
  PxPt(100, 100),
  PxPt(400, 100),
  PxPt(400, 300),
  PxPt(100, 300),
];

/// A room outlined on a calibrated plan, with one run landed in an
/// UNPINNED rack: every input but the pin, which is the order docs/21 used
/// to have to warn about.
({PlanDoc d, Uuid room, Uuid rack}) _outlinedFirst() {
  final d = PlanDoc()..underlay();
  final room = d.room('Great Room', outline: _square);
  final rack = d.rack('RK-1');
  final dev = d.rackDevice('PP-1', rack);
  d.link(
    from: PortEndpoint(d.port(dev, 'J01')),
    to: PlaceEndpoint(locationId: room, description: 'TV wall'),
    outletId: d.outlet('WP-1', locationId: room),
    fieldLabel: 'RUN-1',
  );
  return (d: d, room: room, rack: rack);
}

Location _loc(PlanDoc d, Uuid id) => d.doc.locations[id]!;

SetPlanPinCommand _pinRack(Uuid rack) => SetPlanPinCommand(
  carrier: PinCarrier.rack,
  entityId: rack,
  pin: planPin(0, 0),
);

void main() {
  test('pinning the rack AFTER the outline fills the figure', () {
    final f = _outlinedFirst();
    final c = DocumentController(f.d.doc);
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, isNull);

    c.run(_pinRack(f.rack));

    // 500 px at 0.36 in per px: the room_estimate_test figure.
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, inches(180));
    expect(
      _loc(f.d, f.room).estimatedRunLengthOrigin,
      RunLengthOrigin.computedFromPlan,
    );
  });

  test('ONE undo takes back the pin AND the figure it produced', () {
    final f = _outlinedFirst();
    final c = DocumentController(f.d.doc)..run(_pinRack(f.rack));
    // THE PRECONDITION. Without it this case passes on a controller that
    // never computed anything, because null is also what undo restores.
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, isNotNull);

    c.undoLast();

    expect(f.d.doc.racks[f.rack]!.planPin, isNull);
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, isNull);
    expect(_loc(f.d, f.room).estimatedRunLengthOrigin, isNull);
    // And the Edit menu names the act, not its consequence.
    c.redoLast();
    expect(c.undo.undoLabelKey, LabelKey.setPlanPin.name);
  });

  test(
    'a plan figure whose rack is UNPINNED is cleared, not left standing',
    () {
      final f = _outlinedFirst();
      final c = DocumentController(f.d.doc)..run(_pinRack(f.rack));
      expect(_loc(f.d, f.room).estimatedRunLengthFromRack, isNotNull);

      c.run(ClearPlanPinCommand(carrier: PinCarrier.rack, entityId: f.rack));

      expect(_loc(f.d, f.room).estimatedRunLengthFromRack, isNull);
      expect(_loc(f.d, f.room).estimatedRunLengthOrigin, isNull);
    },
  );

  test('a TYPED figure is never touched, in either direction', () {
    final f = _outlinedFirst();
    final c = DocumentController(f.d.doc)
      ..run(
        SetRoomEstimateCommand.typed(locationId: f.room, length: inches(600)),
      )
      ..run(_pinRack(f.rack));
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, inches(600));
    expect(_loc(f.d, f.room).estimatedRunLengthOrigin, RunLengthOrigin.typed);

    c.run(ClearPlanPinCommand(carrier: PinCarrier.rack, entityId: f.rack));
    expect(_loc(f.d, f.room).estimatedRunLengthFromRack, inches(600));
  });

  test('MOVING the rack moves the figure with it', () {
    final f = _outlinedFirst();
    // From (0, 0) the farthest corner is (400, 300): 500 px. From (0, 300)
    // it is (400, 100): sqrt(400^2 + 200^2), about 447.2 px, which is
    // 161.0 inches at 0.36 in per px. To the inch, because the figure is
    // not a whole number of them and the point is that it MOVED.
    DocumentController(f.d.doc)
      ..run(_pinRack(f.rack))
      ..run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: f.rack,
          pin: planPin(0, 300),
        ),
      );

    expect(
      _loc(f.d, f.room).estimatedRunLengthFromRack!.nm,
      closeTo(inches(161).nm, inches(0.5).nm),
    );
  });

  group('planEstimateGapOf names the one missing input', () {
    test('rack not pinned', () {
      final f = _outlinedFirst();
      expect(
        planEstimateGapOf(f.d.doc, _loc(f.d, f.room)),
        PlanEstimateGap.rackNotPinned,
      );
    });

    test('rack pinned on a DIFFERENT plan', () {
      final f = _outlinedFirst();
      f.d.underlay(id: kPlanUl2);
      f.d.doc.racks[f.rack]!.planPin = planPin(0, 0, on: kPlanUl2);
      expect(
        planEstimateGapOf(f.d.doc, _loc(f.d, f.room)),
        PlanEstimateGap.rackOnAnotherPlan,
      );
    });

    test(
      'no run landed, not calibrated, no outline, and none once it derives',
      () {
        final bare = PlanDoc()..underlay(scale: null);
        final noOutline = bare.room('Hall');
        final outlined = bare.room('Den', outline: _square);
        expect(
          planEstimateGapOf(bare.doc, bare.doc.locations[noOutline]!),
          PlanEstimateGap.noOutline,
        );
        expect(
          planEstimateGapOf(bare.doc, bare.doc.locations[outlined]!),
          PlanEstimateGap.notCalibrated,
        );

        final cal = PlanDoc()..underlay();
        final lonely = cal.room('Den', outline: _square);
        expect(
          planEstimateGapOf(cal.doc, cal.doc.locations[lonely]!),
          PlanEstimateGap.noLandedRun,
        );

        final f = _outlinedFirst();
        DocumentController(f.d.doc).run(_pinRack(f.rack));
        expect(planEstimateGapOf(f.d.doc, _loc(f.d, f.room)), isNull);
      },
    );
  });
}
