// PLAN-C/6: the Plan view's six commands, their undo, and the epoch masks
// tested against a LISTENER rather than against themselves.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A LISTENER AND NOT `expect(command.touches, ...)`
// ═══════════════════════════════════════════════════════════════════════
// `expect(cmd.touches, EpochMask.structure | EpochMask.wires)` is a
// restatement of the getter: it passes for any mask the author typed and
// fails only if they typed two different things in two places. The
// property that matters is that a CONSUMER WATCHING A GIVEN EPOCH IS
// WOKEN, so the cases below subscribe through a real `DocumentController`
// and assert the counter moved.
//
// This project has the scar. DR-011.4's first implementation silently did
// nothing because `ConnectPortsCommand.touches` was `wires | meta` and the
// meta bump advanced the scene epoch past the stamp the wires listener had
// just written. Every symbol still moved, on the very commit the clause
// was about, and a `touches` assertion would have been green throughout.
//
// The negative cases matter as much: `EpochMask.rack` must NOT move when a
// rack is pinned, because pinning changes no rail, no height and no depth.
// A mask that woke everything would pass every positive assertion here.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _fixed = DateTime.utc(2026, 9, 7, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester');

const _underlayId = Uuid('0190e3c1-1111-7000-8000-000000000001');
const _otherUnderlayId = Uuid('0190e3c1-1111-7000-8000-00000000000a');
const _rackId = Uuid('0190e3c1-2222-7000-8000-000000000002');
const _locationId = Uuid('0190e3c1-3333-7000-8000-000000000003');
const _deviceId = Uuid('0190e3c1-4444-7000-8000-000000000004');
const _outletId = Uuid('0190e3c1-5555-7000-8000-000000000005');
const _bodyId = Uuid('0190e3c1-6666-7000-8000-000000000006');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

const _pin = PlanPin(underlayId: _underlayId, at: PxPt(742, 1183));
const _movedPin = PlanPin(underlayId: _underlayId, at: PxPt(900, 400));

PlanUnderlay _underlay({Uuid id = _underlayId, String order = 'a0'}) =>
    PlanUnderlay(
      id: id,
      name: 'Level 1',
      imageMember: 'underlays/$id.png',
      format: PlanImageFormat.png,
      pixelWidth: 4000,
      pixelHeight: 3000,
      contentHash: 'sha256:abcdef',
      order: FracIndex(order),
      meta: _meta(),
    );

/// A document with one underlay, one rack, one outlet and one off-rack
/// device: every pin carrier represented exactly once.
RackDocument _doc({bool withUnderlay = true}) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-000000000000'),
    appVersion: '0.6.10',
    createdAt: _fixed,
    modifiedAt: _fixed,
    meta: _meta(),
    info: ProjectInfo(projectName: 'Ashford Residence'),
  );
  if (withUnderlay) doc.underlays[_underlayId] = _underlay();
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'AV Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: _bodyId,
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.devices[_deviceId] = DeviceInstance(
    id: _deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: _templateRef,
    designator: 'SPK-1',
    name: 'Wall speaker',
    placement: const OffRackPlacement(locationId: _locationId),
    meta: _meta(),
  );
  return doc;
}

PlanPin? _pinOn(RackDocument doc, PinCarrier carrier) => switch (carrier) {
  PinCarrier.rack => doc.racks[_rackId]!.planPin,
  PinCarrier.outlet => doc.outlets[_outletId]!.planPin,
  PinCarrier.offRackDevice =>
    (doc.devices[_deviceId]!.placement as OffRackPlacement).planPin,
};

Uuid _idFor(PinCarrier carrier) => switch (carrier) {
  PinCarrier.rack => _rackId,
  PinCarrier.outlet => _outletId,
  PinCarrier.offRackDevice => _deviceId,
};

void main() {
  group('setting, moving and clearing a pin, on all three carriers', () {
    for (final carrier in PinCarrier.values) {
      test('${carrier.name}: set, then undo', () {
        final doc = _doc();
        final controller = DocumentController(doc)
          ..run(
            SetPlanPinCommand(
              carrier: carrier,
              entityId: _idFor(carrier),
              pin: _pin,
            ),
          );
        expect(_pinOn(doc, carrier), _pin);

        controller.undo.undo(doc);
        expect(_pinOn(doc, carrier), isNull);
      });

      test('${carrier.name}: move, then undo restores the OLD position and '
          'not null', () {
        // The case a `_previous`-less implementation gets wrong: undoing a
        // MOVE must put the pin back where it was, not remove it.
        final doc = _doc();
        final controller = DocumentController(doc)
          ..run(
            SetPlanPinCommand(
              carrier: carrier,
              entityId: _idFor(carrier),
              pin: _pin,
            ),
          )
          ..run(
            SetPlanPinCommand(
              carrier: carrier,
              entityId: _idFor(carrier),
              pin: _movedPin,
            ),
          );
        expect(_pinOn(doc, carrier), _movedPin);

        controller.undo.undo(doc);
        expect(_pinOn(doc, carrier), _pin);
      });

      test('${carrier.name}: clear, then undo', () {
        final doc = _doc();
        final controller = DocumentController(doc)
          ..run(
            SetPlanPinCommand(
              carrier: carrier,
              entityId: _idFor(carrier),
              pin: _pin,
            ),
          )
          ..run(
            ClearPlanPinCommand(carrier: carrier, entityId: _idFor(carrier)),
          );
        expect(_pinOn(doc, carrier), isNull);

        controller.undo.undo(doc);
        expect(_pinOn(doc, carrier), _pin);
      });
    }

    test('the OFF-RACK pin does not disturb the rest of the placement', () {
      final doc = _doc();
      DocumentController(doc).run(
        SetPlanPinCommand(
          carrier: PinCarrier.offRackDevice,
          entityId: _deviceId,
          pin: _pin,
        ),
      );
      final placement = doc.devices[_deviceId]!.placement as OffRackPlacement;
      expect(placement.planPin, _pin);
      // `locationId` remains the schedule's source of room truth and a pin
      // never replaces it (docs/15 §3.4). A longhand rebuild that forgot a
      // field would fail here.
      expect(placement.locationId, _locationId);
    });
  });

  group('the label names the act that happened', () {
    test('setPlanPin for the first pin, movePlanPin for the second', () {
      final doc = _doc();
      final first = SetPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: _rackId,
        pin: _pin,
      );
      final second = SetPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: _rackId,
        pin: _movedPin,
      );
      DocumentController(doc)
        ..run(first)
        ..run(second);

      expect(first.label, LabelKey.setPlanPin);
      expect(second.label, LabelKey.movePlanPin);
    });

    test('clearing has its own label', () {
      expect(
        ClearPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
        ).label,
        LabelKey.clearPlanPin,
      );
    });
  });

  group('A PIN NAMING AN UNDERLAY THIS DOCUMENT DOES NOT HAVE IS REFUSED', () {
    test('the write does not happen', () {
      final doc = _doc();
      DocumentController(doc).run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: const PlanPin(underlayId: _otherUnderlayId, at: PxPt(1, 2)),
        ),
      );
      expect(doc.racks[_rackId]!.planPin, isNull);
    });

    test('and a revert after that refusal THROWS rather than writing null', () {
      // The difference between "did nothing" and "did nothing but says it
      // did": a command that let `_applied` stay true here would clear a
      // pin somebody else set on undo.
      final doc = _doc();
      final cmd = SetPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: _rackId,
        pin: const PlanPin(underlayId: _otherUnderlayId, at: PxPt(1, 2)),
      )..apply(doc);
      expect(() => cmd.revert(doc), throwsStateError);
    });

    test('clearing a pin that is not there also refuses to pretend', () {
      final doc = _doc();
      final cmd = ClearPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: _rackId,
      )..apply(doc);
      expect(() => cmd.revert(doc), throwsStateError);
    });
  });

  group('underlays: add, remove and reorder', () {
    test('add, then undo', () {
      final doc = _doc(withUnderlay: false);
      final controller = DocumentController(doc)
        ..run(AddPlanUnderlayCommand(underlay: _underlay()));
      expect(doc.underlays, hasLength(1));

      controller.undo.undo(doc);
      expect(doc.underlays, isEmpty);
    });

    test('reorder, then undo', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          ReorderPlanUnderlayCommand(
            underlayId: _underlayId,
            order: const FracIndex('a5'),
          ),
        );
      expect(doc.underlays[_underlayId]!.order.v, 'a5');

      controller.undo.undo(doc);
      expect(doc.underlays[_underlayId]!.order.v, 'a0');
    });

    test('REMOVING CASCADES: every pin standing on that plan goes with it', () {
      final doc = _doc();
      final controller = DocumentController(doc);
      for (final carrier in PinCarrier.values) {
        controller.run(
          SetPlanPinCommand(
            carrier: carrier,
            entityId: _idFor(carrier),
            pin: _pin,
          ),
        );
      }
      for (final carrier in PinCarrier.values) {
        expect(_pinOn(doc, carrier), _pin, reason: carrier.name);
      }

      controller.run(RemovePlanUnderlayCommand(underlayId: _underlayId));

      expect(doc.underlays, isEmpty);
      for (final carrier in PinCarrier.values) {
        expect(
          _pinOn(doc, carrier),
          isNull,
          reason: '${carrier.name} still points at a plan that is gone',
        );
      }
    });

    test('AND THE UNDO PUTS BACK THE PLAN AND THE DOTS ON IT', () {
      final doc = _doc();
      final controller = DocumentController(doc);
      for (final carrier in PinCarrier.values) {
        controller.run(
          SetPlanPinCommand(
            carrier: carrier,
            entityId: _idFor(carrier),
            pin: _pin,
          ),
        );
      }
      controller
        ..run(RemovePlanUnderlayCommand(underlayId: _underlayId))
        ..undo.undo(doc);

      expect(doc.underlays, hasLength(1));
      for (final carrier in PinCarrier.values) {
        expect(_pinOn(doc, carrier), _pin, reason: carrier.name);
      }
    });

    test('a pin on a DIFFERENT plan is left alone by the cascade', () {
      // The discrimination the cascade has to make, and the one a
      // clear-everything implementation gets wrong.
      final doc = _doc()
        ..underlays[_otherUnderlayId] = _underlay(
          id: _otherUnderlayId,
          order: 'a1',
        );
      const otherPin = PlanPin(
        underlayId: _otherUnderlayId,
        at: PxPt(10, 20),
      );
      DocumentController(doc)
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: _pin,
          ),
        )
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.outlet,
            entityId: _outletId,
            pin: otherPin,
          ),
        )
        ..run(RemovePlanUnderlayCommand(underlayId: _underlayId));

      expect(doc.racks[_rackId]!.planPin, isNull);
      expect(doc.outlets[_outletId]!.planPin, otherPin);
    });
  });

  group('THE EPOCH MASKS, AGAINST A LISTENER', () {
    ({int structure, int wires, int rack, int sheet, int meta}) snapshot(
      DocumentController c,
    ) => (
      structure: c.epochs.structure.value,
      wires: c.epochs.wires.value,
      rack: c.epochs.rack.value,
      sheet: c.epochs.sheet.value,
      meta: c.epochs.meta.value,
    );

    test('a pin wakes structure AND wires, because it moves a length', () {
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: _pin,
        ),
      );
      final after = snapshot(controller);

      expect(after.structure, greaterThan(before.structure));
      // THE ONE THAT DR-011.4's DEFECT WOULD HAVE MISSED. A pin feeds
      // planLowerBound, which feeds a schedule row, which feeds a sheet. A
      // mask that stopped at the plan scene would leave the schedule
      // printing the old length with nothing to wake it.
      expect(
        after.wires,
        greaterThan(before.wires),
        reason: 'a consumer watching cable data was not woken by a pin',
      );
    });

    test('AND IT DOES NOT WAKE `rack`, which is the negative that makes the '
        'positives mean something', () {
      // `EpochMask.rack` means heightU, rails and depth. Pinning a rack on
      // a picture changes none of them. A command that woke everything
      // would pass every positive assertion in this group.
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: _pin,
        ),
      );

      expect(snapshot(controller).rack, before.rack);
      expect(snapshot(controller).meta, before.meta);
    });

    test('clearing a pin wakes the same two', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: _pin,
          ),
        );
      final before = snapshot(controller);

      controller.run(
        ClearPlanPinCommand(carrier: PinCarrier.rack, entityId: _rackId),
      );
      final after = snapshot(controller);

      expect(after.structure, greaterThan(before.structure));
      expect(after.wires, greaterThan(before.wires));
    });

    test('adding and removing an underlay wake structure and wires', () {
      final doc = _doc(withUnderlay: false);
      final controller = DocumentController(doc);
      var before = snapshot(controller);

      controller.run(AddPlanUnderlayCommand(underlay: _underlay()));
      var after = snapshot(controller);
      expect(after.structure, greaterThan(before.structure));
      expect(after.wires, greaterThan(before.wires));

      before = after;
      controller.run(RemovePlanUnderlayCommand(underlayId: _underlayId));
      after = snapshot(controller);
      expect(after.structure, greaterThan(before.structure));
      expect(after.wires, greaterThan(before.wires));
    });

    test('REORDERING WAKES `sheet` AND NOTHING ELSE, because it changes what '
        'is on top and no derived number at all', () {
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        ReorderPlanUnderlayCommand(
          underlayId: _underlayId,
          order: const FracIndex('a5'),
        ),
      );
      final after = snapshot(controller);

      expect(after.sheet, greaterThan(before.sheet));
      expect(after.structure, before.structure);
      expect(after.wires, before.wires);
      expect(after.rack, before.rack);
      expect(after.meta, before.meta);
    });

    test('ANTI-VACUITY: the snapshot really does move for a command that '
        'touches everything these do not', () {
      // A helper that always returned the same numbers would make every
      // negative assertion above pass. This proves the instrument moves.
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);
      controller.run(
        AddPlanUnderlayCommand(
          underlay: _underlay(
            id: _otherUnderlayId,
            order: 'a9',
          ),
        ),
      );
      expect(snapshot(controller).structure, isNot(before.structure));
    });
  });
}
