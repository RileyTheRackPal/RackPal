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

/// A square room, and the same room with one corner pulled out so a
/// reshape is a real change rather than a rewrite of the same value.
final _outline = RoomOutline(
  underlayId: _underlayId,
  vertices: const [
    PxPt(100, 100),
    PxPt(400, 100),
    PxPt(400, 300),
    PxPt(100, 300),
  ],
);
final _reshaped = RoomOutline(
  underlayId: _underlayId,
  vertices: const [
    PxPt(100, 100),
    PxPt(500, 100),
    PxPt(400, 300),
    PxPt(100, 300),
  ],
);

/// 100 pixels spanning a 36 inch door: `PLAN-F/1`'s own example, and the
/// numbers are chosen so the factor is a round 9,144,000 nm per pixel.
const _scale = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(200, 100),
  distance: Len(36 * Len.nmPerInch),
);

/// The same wall measured again, half a pixel-span shorter, so a
/// recalibration changes the factor rather than merely the object.
const _recalibrated = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(300, 100),
  distance: Len(36 * Len.nmPerInch),
);

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
  // The room `_locationId` names. It was referenced by the off-rack
  // placement below and never existed as an entity until `LEN-A/2` needed
  // somewhere to put an outline.
  doc.locations[_locationId] = Location(
    id: _locationId,
    kind: LocationKind.room,
    name: 'Great Room',
    code: 'GR',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
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

  group('calibration, the writer PlanScale did not have', () {
    test('sets the scale, and undo returns the plan to UNCALIBRATED', () {
      // Not "to a 1:1 scale" and not "to an empty PlanScale": the model
      // says null IS the uncalibrated state and never acquires a guessed
      // value (G4, docs/15 §3.1), so an undo has exactly one right answer.
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(SetPlanScaleCommand(underlayId: _underlayId, scale: _scale));
      expect(doc.underlays[_underlayId]!.scale, _scale);
      expect(doc.underlays[_underlayId]!.isCalibrated, isTrue);

      controller.undo.undo(doc);
      expect(doc.underlays[_underlayId]!.scale, isNull);
      expect(doc.underlays[_underlayId]!.isCalibrated, isFalse);
    });

    test('recalibrating, then undoing, restores the OLD scale and not '
        'null', () {
      // The case a `_previous`-less implementation gets wrong, and it is
      // the same shape the pin's move/undo case protects one group up.
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(SetPlanScaleCommand(underlayId: _underlayId, scale: _scale))
        ..run(
          SetPlanScaleCommand(
            underlayId: _underlayId,
            scale: _recalibrated,
          ),
        );
      expect(doc.underlays[_underlayId]!.scale, _recalibrated);

      controller.undo.undo(doc);
      expect(doc.underlays[_underlayId]!.scale, _scale);
    });

    test('calibratePlan the first time, recalibratePlan the second', () {
      final doc = _doc();
      final first = SetPlanScaleCommand(
        underlayId: _underlayId,
        scale: _scale,
      );
      final second = SetPlanScaleCommand(
        underlayId: _underlayId,
        scale: _recalibrated,
      );
      DocumentController(doc)
        ..run(first)
        ..run(second);

      expect(first.label, LabelKey.calibratePlan);
      expect(second.label, LabelKey.recalibratePlan);
    });

    test('replacing an UNUSABLE scale is still recalibration', () {
      // The label names what HAPPENED, not what the previous value was
      // worth. An underlay carrying two coincident points is calibrated as
      // far as the document is concerned and useless as far as a length
      // is concerned, and deciding the word from the value's usability
      // would name the act by a property of the data.
      final doc = _doc();
      const degenerate = PlanScale(
        a: PxPt(100, 100),
        b: PxPt(100, 100),
        distance: Len(36 * Len.nmPerInch),
      );
      expect(degenerate.isUsable, isFalse);
      final second = SetPlanScaleCommand(
        underlayId: _underlayId,
        scale: _scale,
      );
      DocumentController(doc)
        ..run(
          SetPlanScaleCommand(underlayId: _underlayId, scale: degenerate),
        )
        ..run(second);

      expect(second.label, LabelKey.recalibratePlan);
    });

    test('an underlay this document does not have is a NO-OP whose revert '
        'throws rather than pretending', () {
      final doc = _doc(withUnderlay: false);
      final command = SetPlanScaleCommand(
        underlayId: _underlayId,
        scale: _scale,
      )..apply(doc);
      expect(doc.underlays, isEmpty, reason: 'nothing to write onto');
      expect(() => command.revert(doc), throwsStateError);
    });

    test('THE FACTOR IS DERIVED AND NEVER STORED, so what round-trips is '
        'the two points and the typed distance', () {
      // CR-001: a ratio cannot be an integer and no floating-point length
      // is stored, so the command carries exactly what the user supplied.
      final doc = _doc();
      DocumentController(
        doc,
      ).run(SetPlanScaleCommand(underlayId: _underlayId, scale: _scale));
      final stored = doc.underlays[_underlayId]!.scale!;

      expect(stored.a, const PxPt(100, 100));
      expect(stored.b, const PxPt(200, 100));
      expect(stored.distance.nm, 36 * Len.nmPerInch);
      expect(stored.nanometresPerPixel, 9144000.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-156 §11.155.2: THE UNDO STACK, WHICH IS THE ARTIFACT
  // ═══════════════════════════════════════════════════════════════════
  // Every case in this file that checks a label reads `command.label`,
  // which is correct after `apply` and is EXACTLY WHY NOTHING CAUGHT
  // `#866`. What a person sees is `UndoStack.undoLabelKey`, and for the
  // whole life of these three commands it reported the FIRST half of each
  // pair: the transaction read its label before the closure that applies
  // the command had run.
  //
  // House style says assert the artifact and not the mechanism. These are
  // the artifact.
  group('DR-156: the Edit menu reads the label the document decided', () {
    test('A PIN MOVE REPORTS `movePlanPin`, not `setPlanPin`', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: _pin,
          ),
        );
      expect(
        controller.undo.undoLabelKey,
        LabelKey.setPlanPin.name,
        reason: 'the first pin is a set, and always reported correctly',
      );

      controller.run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: const PlanPin(underlayId: _underlayId, at: PxPt(40, 50)),
        ),
      );

      expect(controller.undo.undoLabelKey, LabelKey.movePlanPin.name);
    });

    test('A REDRAWN OUTLINE REPORTS `reshapeRoomOutline`', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
        );
      expect(controller.undo.undoLabelKey, LabelKey.drawRoomOutline.name);

      controller.run(
        SetRoomOutlineCommand(locationId: _locationId, outline: _reshaped),
      );

      expect(controller.undo.undoLabelKey, LabelKey.reshapeRoomOutline.name);
    });

    test('A RECALIBRATION REPORTS `recalibratePlan`', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlanScaleCommand(underlayId: _underlayId, scale: _scale),
        );
      expect(controller.undo.undoLabelKey, LabelKey.calibratePlan.name);

      controller.run(
        SetPlanScaleCommand(underlayId: _underlayId, scale: _recalibrated),
      );

      expect(controller.undo.undoLabelKey, LabelKey.recalibratePlan.name);
    });

    test('AND A CALLER THAT NAMES THE ACT STILL WINS, which is what keeps '
        'a bulk operation from being named after its first row', () {
      // The null is "nobody named this", not "always ask the child". A
      // transaction whose caller chose a label keeps it however many
      // children it has and whatever they would have said.
      final doc = _doc();
      final controller = DocumentController(doc)
        ..transact(LabelKey.importCsv, (tx) {
          tx.add(
            SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
          );
        });

      expect(
        controller.undo.undoLabelKey,
        LabelKey.importCsv.name,
        reason: 'a single child does not override a caller who named it',
      );
    });

    test('THE FIRST SURVIVING CHILD NAMES IT, and a REFUSED one is not a '
        'child by then (`#863` and `#866` composing)', () {
      // ═══════════════════════════════════════════════════════════════
      // THREE CHILDREN, AND THE MIDDLE ONE IS THE POINT
      // ═══════════════════════════════════════════════════════════════
      // Two children were not enough: the first draft of this case had a
      // refusal then one real command, so `children.first` and
      // `children.last` were the SAME object and a mutation swapping them
      // SURVIVED. Nothing in the repository pinned which end names a
      // transaction, and the two-child case is real — the rack canvas
      // stacks a library copy under an add and is named after the add.
      //
      // So: a refusal, then a draw, then a clear. The refusal must not
      // name it, and the DRAW must, not the clear.
      final doc = _doc();
      final controller = DocumentController(doc)
        ..transact(null, (tx) {
          tx
            // Refuses: no such underlay.
            ..add(
              SetPlanPinCommand(
                carrier: PinCarrier.rack,
                entityId: _rackId,
                pin: const PlanPin(
                  underlayId: Uuid('ul-gone'),
                  at: PxPt(1, 1),
                ),
              ),
            )
            ..add(
              SetRoomOutlineCommand(
                locationId: _locationId,
                outline: _outline,
              ),
            )
            ..add(ClearRoomOutlineCommand(locationId: _locationId));
        });

      expect(
        controller.undo.undoLabelKey,
        LabelKey.drawRoomOutline.name,
        reason: 'the first SURVIVING child, not the refusal and not the last',
      );
    });
  });

  group('the room outline: draw, reshape and clear (`LEN-A/2`)', () {
    test('draws a shape where there was none, and the label says so', () {
      final doc = _doc();
      final command = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      )..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, _outline);
      expect(command.label, LabelKey.drawRoomOutline);
    });

    test('reshaping carries the OTHER label, decided from the document '
        'rather than by the caller', () {
      // `setPlanPin`/`movePlanPin`'s reasoning: "Undo Reshape Room" in
      // front of somebody who has just drawn their first outline names an
      // act they did not perform.
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      ).apply(doc);
      final second = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _reshaped,
      )..apply(doc);

      expect(second.label, LabelKey.reshapeRoomOutline);
      expect(doc.locations[_locationId]!.planOutline, _reshaped);
    });

    test('revert puts the previous shape back, and null back on a first '
        'draw', () {
      final doc = _doc();
      final first = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      )..apply(doc);
      final second = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _reshaped,
      )..apply(doc);
      expect(doc.locations[_locationId]!.planOutline, _reshaped);

      second.revert(doc);
      expect(doc.locations[_locationId]!.planOutline, _outline);

      first.revert(doc);
      expect(doc.locations[_locationId]!.planOutline, isNull);
    });

    test('clearing takes it off and revert brings it back', () {
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      ).apply(doc);
      final clear = ClearRoomOutlineCommand(locationId: _locationId)
        ..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, isNull);
      expect(clear.label, LabelKey.clearRoomOutline);
      clear.revert(doc);
      expect(doc.locations[_locationId]!.planOutline, _outline);
    });

    test('clearing nothing is not a done thing, so a later revert THROWS '
        'rather than writing a null over whatever is there by then', () {
      final doc = _doc();
      final clear = ClearRoomOutlineCommand(locationId: _locationId)
        ..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, isNull);
      expect(() => clear.revert(doc), throwsStateError);
    });
  });

  group('THE THREE REFUSALS, which are why this is not a table row', () {
    test('an outline naming an underlay this document does not have', () {
      // `SetPlanPinCommand`'s refusal, word for word one entity over: a
      // dangling reference in a drawing is what DR-021's cascade spends a
      // ruling avoiding.
      final doc = _doc(withUnderlay: false);
      final command = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      )..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, isNull);
      expect(() => command.revert(doc), throwsStateError);
    });

    test('a location this document does not have', () {
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: const Uuid('0190e3c1-9999-7000-8000-000000000099'),
        outline: _outline,
      ).apply(doc);

      expect(doc.locations, hasLength(1));
    });

    test('AND A SHAPE THE PRODUCT COULD NOT MEASURE, which is the one '
        'the decoder deliberately does NOT refuse', () {
      // The distinction `SetRoomOutlineCommand`'s header draws.
      // `room_outline_test.dart` proves a two-vertex outline READS,
      // because CR-093 is about tolerating somebody else's file. This is
      // the product's own writer, and authoring a polygon it has already
      // said it cannot measure would put a degenerate shape in a document
      // with nobody to blame for it.
      final doc = _doc();
      final command = SetRoomOutlineCommand(
        locationId: _locationId,
        outline: RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(10, 10), PxPt(20, 20)],
        ),
      )..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, isNull);
      expect(() => command.revert(doc), throwsStateError);
    });
  });

  group('removing an underlay takes the outlines drawn on it', () {
    test('the outline is cleared and revert puts it back', () {
      // The obligation `room_outline_test.dart` made explicit: without
      // this, a document can carry an outline whose underlay is gone, and
      // the stamp is the only thing then standing between that file and
      // an older build deleting the drawing on save.
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      ).apply(doc);
      final remove = RemovePlanUnderlayCommand(underlayId: _underlayId)
        ..apply(doc);

      expect(doc.locations[_locationId]!.planOutline, isNull);
      remove.revert(doc);
      expect(doc.locations[_locationId]!.planOutline, _outline);
    });

    test('and it names the room in `affects`, so a listener scoped to '
        'that entity is woken', () {
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      ).apply(doc);
      final remove = RemovePlanUnderlayCommand(underlayId: _underlayId)
        ..apply(doc);

      expect(remove.affects, contains(_locationId));
    });

    test('an outline drawn on a DIFFERENT underlay is untouched', () {
      // The negative that makes the positive mean something: a removal
      // that cleared every outline would pass the case above.
      final doc = _doc()..underlays[_otherUnderlayId] = _underlay();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: RoomOutline(
          underlayId: _otherUnderlayId,
          vertices: _outline.vertices,
        ),
      ).apply(doc);

      RemovePlanUnderlayCommand(underlayId: _underlayId).apply(doc);

      expect(
        doc.locations[_locationId]!.planOutline?.underlayId,
        _otherUnderlayId,
      );
    });
  });

  group('DR-021: the outline dies with its room, and nothing new is owed', () {
    test('removing the location takes its outline, and undo brings both '
        'back', () {
      // ASSERTED RATHER THAN ASSUMED. The outline is a FIELD on
      // `Location`, so the cascade already carries it and
      // `RemoveLocationCommand` keeps *"the SAME objects, not equivalent
      // ones"*. That is a reason to believe it works, not evidence.
      final doc = _doc();
      SetRoomOutlineCommand(
        locationId: _locationId,
        outline: _outline,
      ).apply(doc);

      final remove = RemoveLocationCommand(
        plan: planLocationRemoval(doc, _locationId),
      )..apply(doc);

      expect(doc.locations[_locationId], isNull);
      remove.revert(doc);
      expect(doc.locations[_locationId]!.planOutline, _outline);
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

    test('AN OUTLINE WAKES `wires`, THOUGH NOTHING READS IT YET', () {
      // THE ONE MASK ON THIS PAGE WHOSE CONSUMER DOES NOT EXIST.
      // `LEN-A/3` builds the derivation; today an outline changes no
      // length, so `wires` wakes a listener over a number that has not
      // moved.
      //
      // That is deliberate and the asymmetry is the argument: a spurious
      // wake costs a redraw, and a missed wake ships a stale length, which
      // is DR-011.4's defect. Shipping `structure` alone would be correct
      // today and would put the burden on `LEN-A/3` to remember.
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
      );
      final after = snapshot(controller);

      expect(after.structure, greaterThan(before.structure));
      expect(
        after.wires,
        greaterThan(before.wires),
        reason: 'an outline feeds the same chain a pin feeds',
      );
    });

    test('and it does NOT wake `rack` or `meta`, which is the negative '
        'that makes the positive mean something', () {
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
      );

      expect(snapshot(controller).rack, before.rack);
      expect(snapshot(controller).meta, before.meta);
    });

    test('clearing an outline wakes the same two', () {
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
        );
      final before = snapshot(controller);

      controller.run(ClearRoomOutlineCommand(locationId: _locationId));
      final after = snapshot(controller);

      expect(after.structure, greaterThan(before.structure));
      expect(after.wires, greaterThan(before.wires));
    });

    test('A REFUSED OUTLINE WAKES NOTHING AT ALL, which is the assertion '
        'this case was originally written as (`#863`, DR-156 §11.155.1)', () {
      // ═══════════════════════════════════════════════════════════════
      // UN-INVERTED 2026-09-12, ON ITS OWN INSTRUCTIONS
      // ═══════════════════════════════════════════════════════════════
      // `LEN-A/2` set out to assert exactly this and found the opposite,
      // so it shipped the case asserting the DEFECT with a comment saying
      // what would retire it: *"when a refusal stops reaching the stack,
      // this case fails and whoever fixed it inverts it to the assertion
      // it was originally written as."* It came due. `bool apply` landed,
      // `TxnScope.add` began dropping a child that returned false, and
      // this was the one case in the repository that failed.
      //
      // **A TEST THAT ASSERTS AN ABSENCE NAMES ITS DUE DATE**, and this
      // is the cleanest instance the practice has: the due date was a
      // ruling ID, the ruling landed, and the test failed on the commit
      // that made it wrong rather than being found by a person.
      final doc = _doc(withUnderlay: false);
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetRoomOutlineCommand(locationId: _locationId, outline: _outline),
      );
      final after = snapshot(controller);

      expect(
        doc.locations[_locationId]!.planOutline,
        isNull,
        reason: 'the refusal itself works: nothing was written',
      );
      expect(
        after.structure,
        before.structure,
        reason: 'a refusal changed nothing, so nothing was invalidated',
      );
      expect(after.wires, before.wires);
      expect(
        controller.undo.canUndo,
        isFalse,
        reason: 'and it left no entry for Ctrl+Z to land on',
      );
    });

    test('AND A REFUSAL DOES NOT COME BETWEEN A PERSON AND THEIR LAST REAL '
        'EDIT, which is what the defect actually cost', () {
      // ═══════════════════════════════════════════════════════════════
      // THE ARTIFACT, WHICH THE CASE ABOVE CANNOT REACH
      // ═══════════════════════════════════════════════════════════════
      // An empty stack is a weak proof: it says a refusal added nothing
      // when there was nothing to add it to. The shape that cost
      // somebody their work is a real edit, THEN a refusal, THEN
      // `Ctrl+Z` — which used to throw `StateError: revert called before
      // apply()` and take the undo stack with it, leaving the real edit
      // unreachable.
      final doc = _doc();
      final controller = DocumentController(doc)
        ..run(
          SetPlanPinCommand(
            carrier: PinCarrier.rack,
            entityId: _rackId,
            pin: _pin,
          ),
        );
      expect(doc.racks[_rackId]!.planPin, isNotNull, reason: 'the real edit');

      // A pin naming an underlay this document does not have. Reachable
      // by a stale reference: an underlay removed between a gesture and
      // its commit.
      controller.run(
        SetPlanPinCommand(
          carrier: PinCarrier.rack,
          entityId: _rackId,
          pin: const PlanPin(underlayId: Uuid('ul-gone'), at: PxPt(1, 1)),
        ),
      );

      controller.undo.undo(doc);

      expect(
        doc.racks[_rackId]!.planPin,
        isNull,
        reason: 'one Ctrl+Z reached the real edit rather than throwing',
      );
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

    test('a calibration wakes structure AND wires, on the same chain a '
        'pin runs', () {
      // A scale turns a pixel distance into a Len, which feeds
      // planLowerBound, which feeds a schedule row, which feeds a sheet:
      // the identical chain a pin runs, so the identical mask. A mask
      // that stopped at the plan would redraw the picture and leave the
      // schedule printing the old length, which is DR-011.4's defect.
      final doc = _doc();
      final controller = DocumentController(doc);
      final before = snapshot(controller);

      controller.run(
        SetPlanScaleCommand(underlayId: _underlayId, scale: _scale),
      );
      final after = snapshot(controller);

      expect(after.structure, greaterThan(before.structure));
      expect(after.wires, greaterThan(before.wires));
      // NOT `rack`: a calibration changes no rail, no height and no
      // depth. NOT `sheet`: `T1.01` does not exist and the pin commands
      // feed the same future sheet without it, so adding it here would
      // leave two commands on one chain disagreeing (PLAN-F/2 revisits).
      expect(after.rack, before.rack);
      expect(after.sheet, before.sheet);
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
