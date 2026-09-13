// DR-160 §11.159 — what removing a plate or a panel takes, and the
// commands that take it. Board `#877`.
//
// FOUND BY `#872`'s REACHABILITY GATE. `RemoveOutletCommand` and
// `RemoveStructureCommand` shipped at M3-A/1 with real reverts and nine
// test constructions between them, and nothing in `lib/` constructed
// either. `structure_commands_test.dart` already proves the three
// `Command` contract properties on both; what is new here is the CASCADE,
// which is where a removal gets its opportunities to be wrong:
//
//   * the count the dialog states and the set the edit removes are one
//     object (§11.159.5);
//   * a plate takes its home runs because they cannot be re-homed
//     (§11.159.2);
//   * a panel takes its plates and its home runs because they cannot
//     exist without it (§11.159.3);
//   * and undo puts every one of them back with the SAME ids (DR-013
//     §11.13.4).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 9, 13);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _bodyA = Uuid('body-a');
const _bodyB = Uuid('body-b');
const _deviceA = Uuid('device-a');
const _deviceB = Uuid('device-b');

/// `P1` carries two drops and a floorplan pin, `P2` carries one, `P3` is
/// bare. `Q1` belongs to the OTHER panel and exists to catch a plan that
/// collects by document rather than by body.
const _p1 = Uuid('outlet-p1');
const _p2 = Uuid('outlet-p2');
const _p3 = Uuid('outlet-p3');
const _q1 = Uuid('outlet-q1');

void _body(RackDocument doc, Uuid bodyId, Uuid deviceId, String designator) {
  doc.devices[deviceId] = DeviceInstance(
    id: deviceId,
    templateRef: kStructureTemplateRef,
    designator: designator,
    name: designator,
    kind: DeviceKind.structure,
    placement: const OffRackPlacement(),
    meta: _meta(),
    structureBodyId: bodyId,
  );
  doc.structures[bodyId] = StructureBody(
    id: bodyId,
    deviceId: deviceId,
    title: designator,
    meta: _meta(),
  );
}

void _outlet(
  RackDocument doc,
  Uuid id,
  Uuid bodyId, {
  required String order,
  bool pinned = false,
}) {
  doc.outlets[id] = Outlet(
    id: id,
    structureBodyId: bodyId,
    designation: id.v,
    order: FracIndex(order),
    meta: _meta(),
    planPin: pinned
        ? const PlanPin(underlayId: Uuid('plan-1'), at: PxPt(10, 20))
        : null,
  );
}

/// One home run out of [bodyId], landing on [outletId] or on no box.
///
/// [netId] is shared deliberately in one test: `netToRemoveWith` asks the
/// SURVIVORS, so two drops on one net must both decline to take it.
void _drop(
  RackDocument doc,
  Uuid linkId, {
  required Uuid bodyId,
  Uuid? outletId,
  Uuid? netId,
}) {
  final net = netId ?? Uuid('net-${linkId.v}');
  doc.nets[net] = Net(
    id: net,
    name: 'N-${linkId.v}',
    signalFamily: const SignalFamilyId('data.ethernet'),
    meta: _meta(),
  );
  doc.links[linkId] = Link(
    id: linkId,
    designator: 'W-${linkId.v}',
    media: const MediaTypeId('media.cat6'),
    order: const FracIndex('a0'),
    meta: _meta(),
    conductors: [
      const Conductor(
        from: OpenEndpoint('field'),
        to: OpenEndpoint('r'),
      ),
    ],
    services: [
      Service(
        id: 's1',
        signalFamily: const SignalFamilyId('data.ethernet'),
        netId: net,
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: bodyId,
      outletId: outletId,
      fieldLabel: 'FL-${linkId.v}',
    ),
  );
}

({RackDocument doc, DocumentController controller}) _fixture() {
  final doc = RackDocument(
    id: const Uuid('doc-877'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-160'),
    registries: buildSeedRegistries(),
  );

  _body(doc, _bodyA, _deviceA, 'STR-1');
  _body(doc, _bodyB, _deviceB, 'STR-2');

  _outlet(doc, _p1, _bodyA, order: 'a0', pinned: true);
  _outlet(doc, _p2, _bodyA, order: 'a1');
  _outlet(doc, _p3, _bodyA, order: 'a2');
  _outlet(doc, _q1, _bodyB, order: 'a0');

  _drop(doc, const Uuid('w1'), bodyId: _bodyA, outletId: _p1);
  _drop(doc, const Uuid('w2'), bodyId: _bodyA, outletId: _p1);
  _drop(doc, const Uuid('w3'), bodyId: _bodyA, outletId: _p2);
  // A ceiling speaker: no box at all (DR-046, `#718`).
  _drop(doc, const Uuid('w4'), bodyId: _bodyA);
  _drop(doc, const Uuid('w5'), bodyId: _bodyB, outletId: _q1);

  return (
    doc: doc,
    controller: DocumentController(doc, clock: FixedClock(_when)),
  );
}

Set<String> _linkIds(Iterable<DropRemoval> drops) => {
  for (final drop in drops) drop.linkId.v,
};

void main() {
  group('planOutletRemoval — the number the dialog says', () {
    test('it counts the drops on THIS plate and no other', () {
      final plan = planOutletRemoval(_fixture().doc, _p1);

      expect(plan.cableCount, 2);
      expect(_linkIds(plan.drops), {'w1', 'w2'});
    });

    test('membership is the outletId, so a sibling plate keeps its own', () {
      final plan = planOutletRemoval(_fixture().doc, _p2);

      expect(_linkIds(plan.drops), {'w3'});
      expect(
        _linkIds(plan.drops),
        isNot(contains('w4')),
        reason:
            'a boxless drop out of the same panel names no plate, so it '
            'belongs to none of them',
      );
    });

    test('a BARE plate is not asked about', () {
      // DR-013 §11.13.2's last sentence, applied by §11.159.5: a prompt
      // for a consequence-free delete is the nag that teaches people to
      // click through prompts.
      final plan = planOutletRemoval(_fixture().doc, _p3);

      expect(plan.cableCount, 0);
      expect(plan.hasPlanPin, isFalse);
      expect(plan.needsConfirmation, isFalse);
    });

    test('but a PIN alone makes it asked about, with no cables at all', () {
      // The clause the boolean exists for. Somebody walked the site and
      // dotted the floorplan; `plan_length.dart` derives a length from
      // that dot and it goes inside the outlet.
      final f = _fixture();
      f.doc.links.remove(const Uuid('w1'));
      f.doc.links.remove(const Uuid('w2'));

      final plan = planOutletRemoval(f.doc, _p1);
      expect(plan.cableCount, 0);
      expect(plan.hasPlanPin, isTrue);
      expect(plan.needsConfirmation, isTrue);
    });

    test('an outlet this document does not hold plans NOTHING', () {
      // Reachable and normal: a stale selection, or a second delete
      // arriving after an undo.
      final plan = planOutletRemoval(_fixture().doc, const Uuid('gone'));

      expect(plan.isEmpty, isTrue);
      expect(plan.needsConfirmation, isFalse);
      expect(plan, OutletRemovalPlan.none);
    });

    test('each drop carries its OWN net answer', () {
      final plan = planOutletRemoval(_fixture().doc, _p1);

      expect(
        plan.drops.map((d) => d.netId?.v),
        ['net-w1', 'net-w2'],
        reason: 'every net this application creates belongs to one link',
      );
    });

    test('and a SHARED net is taken by neither, which is the survivors '
        'rule', () {
      final f = _fixture();
      // A hand-edited file: two links naming one net. `netToRemoveWith`
      // must decline for both, leaving the net ORPHANED rather than
      // leaving a surviving service pointing at nothing.
      _drop(
        f.doc,
        const Uuid('w6'),
        bodyId: _bodyA,
        outletId: _p2,
        netId: const Uuid('net-shared'),
      );
      _drop(
        f.doc,
        const Uuid('w7'),
        bodyId: _bodyA,
        outletId: _p2,
        netId: const Uuid('net-shared'),
      );

      final plan = planOutletRemoval(f.doc, _p2);
      final shared = plan.drops.where((d) => d.linkId.v != 'w3');

      expect(shared, hasLength(2));
      expect(shared.every((d) => d.netId == null), isTrue);
    });
  });

  group('planStructureRemoval — plates, cables and pins', () {
    test('it collects every plate on THIS body', () {
      final plan = planStructureRemoval(_fixture().doc, _bodyA);

      expect(plan.outletCount, 3);
      expect(
        {for (final p in plan.outletPlans) p.outletId.v},
        {
          'outlet-p1',
          'outlet-p2',
          'outlet-p3',
        },
      );
      expect(
        {for (final p in plan.outletPlans) p.outletId.v},
        isNot(contains('outlet-q1')),
      );
    });

    test('the cable count spans the plates AND the drops no plate carried', () {
      final plan = planStructureRemoval(_fixture().doc, _bodyA);

      // w1, w2 on P1; w3 on P2; w4 boxless. w5 is the other panel's.
      expect(plan.cableCount, 4);
      expect(_linkIds(plan.otherDrops), {'w4'});
    });

    test('the two sets are DISJOINT, so nothing is counted twice', () {
      final plan = planStructureRemoval(_fixture().doc, _bodyA);
      final plated = <String>{
        for (final p in plan.outletPlans) ..._linkIds(p.drops),
      };

      expect(plated.intersection(_linkIds(plan.otherDrops)), isEmpty);
      expect(plated.length + plan.otherDrops.length, plan.cableCount);
    });

    test("a drop naming a plate on ANOTHER body is still this body's to "
        'take', () {
      // The hand-edited case, and the reason the field is not called
      // `boxless`: the set is what is left over, not what a person
      // stated. `StructureOrigin.structureBodyId` is non-nullable, so
      // this cable cannot survive its panel whatever box it names.
      final f = _fixture();
      _drop(f.doc, const Uuid('w8'), bodyId: _bodyA, outletId: _q1);

      final plan = planStructureRemoval(f.doc, _bodyA);
      expect(_linkIds(plan.otherDrops), {'w4', 'w8'});
    });

    test('it counts the PINNED plates separately from the plates', () {
      final plan = planStructureRemoval(_fixture().doc, _bodyA);

      expect(plan.outletCount, 3);
      expect(plan.pinnedOutletCount, 1);
    });

    test('it names the paired device', () {
      final plan = planStructureRemoval(_fixture().doc, _bodyA);
      expect(plan.deviceId, _deviceA);
    });

    test('and reports NULL for a body whose pairing is already broken', () {
      // A plan that asserted the 1:1 pairing would throw on a
      // hand-edited file at the moment somebody was trying to get rid of
      // the damage.
      final f = _fixture();
      f.doc.devices.remove(_deviceA);

      expect(planStructureRemoval(f.doc, _bodyA).deviceId, isNull);
    });

    test('an EMPTY panel is still asked about, unlike an empty plate', () {
      // Where this plan departs from `OutletRemovalPlan`, and from
      // `DeviceRemovalPlan` and `LocationRemovalPlan` (§11.159.5).
      final f = _fixture();
      for (final id in ['w1', 'w2', 'w3', 'w4']) {
        f.doc.links.remove(Uuid(id));
      }
      f.doc.outlets.removeWhere((_, o) => o.structureBodyId == _bodyA);

      final plan = planStructureRemoval(f.doc, _bodyA);
      expect(plan.cableCount, 0);
      expect(plan.outletCount, 0);
      expect(plan.needsConfirmation, isTrue);
    });

    test('a body this document does not hold plans NOTHING', () {
      final plan = planStructureRemoval(_fixture().doc, const Uuid('gone'));

      expect(plan.isEmpty, isTrue);
      expect(plan.needsConfirmation, isFalse);
      expect(plan, StructureRemovalPlan.none);
    });
  });

  group('addOutletRemoval — §11.159.2, the plate takes its home runs', () {
    test('the plate and its cables go, and a sibling keeps its own', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, _p1)),
      );

      expect(f.doc.outlets.containsKey(_p1), isFalse);
      expect(f.doc.links.keys.map((k) => k.v), isNot(contains('w1')));
      expect(f.doc.links.keys.map((k) => k.v), isNot(contains('w2')));
      expect(f.doc.outlets.containsKey(_p2), isTrue);
      expect(f.doc.links.containsKey(const Uuid('w3')), isTrue);
      expect(
        f.doc.links.containsKey(const Uuid('w4')),
        isTrue,
        reason: 'a boxless drop out of the same panel names no plate',
      );
    });

    test('the nets go with their cables and no other', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, _p1)),
      );

      expect(f.doc.nets.containsKey(const Uuid('net-w1')), isFalse);
      expect(f.doc.nets.containsKey(const Uuid('net-w2')), isFalse);
      expect(f.doc.nets.containsKey(const Uuid('net-w3')), isTrue);
    });

    test('ONE undo entry for the whole gesture, named for the gesture', () {
      final f = _fixture();
      final before = f.controller.undo.depth;
      f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, _p1)),
      );

      expect(f.controller.undo.depth, before + 1);
    });

    test('undo puts the plate and every cable back with the SAME ids', () {
      // DR-013 §11.13.4, which DR-160 §11.159.7 binds this gesture to:
      // anything less makes delete-then-undo a lossy round trip through
      // the entities CR-117's byte gate is about.
      final f = _fixture();
      final outlet = f.doc.outlets[_p1];
      final link = f.doc.links[const Uuid('w1')];

      f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, _p1)),
      );
      f.controller.undo.undo(f.doc);

      expect(identical(f.doc.outlets[_p1], outlet), isTrue);
      expect(identical(f.doc.links[const Uuid('w1')], link), isTrue);
      expect(f.doc.links, hasLength(5));
      expect(
        f.doc.outlets[_p1]!.planPin,
        isNotNull,
        reason: 'the pin travels inside the outlet, so undo brings it back',
      );
    });

    test('redo lands identically', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, _p1)),
      );
      f.controller.undo.undo(f.doc);
      f.controller.undo.redo(f.doc);

      expect(f.doc.outlets.containsKey(_p1), isFalse);
      expect(f.doc.links, hasLength(3));
    });

    test('an EMPTY plan adds nothing and leaves no undo entry', () {
      final f = _fixture();
      final depth = f.controller.undo.depth;
      final changed = f.controller.transact(
        LabelKey.removeOutlet,
        (tx) => addOutletRemoval(tx, planOutletRemoval(f.doc, const Uuid('x'))),
      );

      expect(changed, isFalse);
      expect(f.controller.undo.depth, depth);
      expect(f.doc.outlets, hasLength(4));
    });
  });

  group('addStructureRemoval — §11.159.3, the panel takes all of it', () {
    test('the body, the device, every plate and every drop out of it', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(tx, planStructureRemoval(f.doc, _bodyA)),
      );

      expect(f.doc.structures.containsKey(_bodyA), isFalse);
      expect(
        f.doc.devices.containsKey(_deviceA),
        isFalse,
        reason: 'neither half of the pairing is valid alone',
      );
      expect(f.doc.outlets.keys.map((k) => k.v), ['outlet-q1']);
      expect(f.doc.links.keys.map((k) => k.v), ['w5']);
    });

    test('the OTHER panel is untouched', () {
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(tx, planStructureRemoval(f.doc, _bodyA)),
      );

      expect(f.doc.structures.containsKey(_bodyB), isTrue);
      expect(f.doc.devices.containsKey(_deviceB), isTrue);
    });

    test('NO OUTLET IS LEFT NAMING A BODY THAT IS GONE', () {
      // The invariant §11.159.3 is built on: `Outlet.structureBodyId` is
      // non-nullable and final, so a surviving outlet on a removed body
      // is a reference that can never be repaired.
      final f = _fixture();
      f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(tx, planStructureRemoval(f.doc, _bodyA)),
      );

      for (final outlet in f.doc.outlets.values) {
        expect(f.doc.structures.containsKey(outlet.structureBodyId), isTrue);
      }
      for (final link in f.doc.links.values) {
        if (link.structureOrigin case final origin?) {
          expect(f.doc.structures.containsKey(origin.structureBodyId), isTrue);
        }
      }
    });

    test('ONE undo entry, and it restores all of it with the same ids', () {
      final f = _fixture();
      final body = f.doc.structures[_bodyA];
      final device = f.doc.devices[_deviceA];
      final outlet = f.doc.outlets[_p1];
      final link = f.doc.links[const Uuid('w4')];
      final before = f.controller.undo.depth;

      f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(tx, planStructureRemoval(f.doc, _bodyA)),
      );
      expect(f.controller.undo.depth, before + 1);

      f.controller.undo.undo(f.doc);

      expect(identical(f.doc.structures[_bodyA], body), isTrue);
      expect(identical(f.doc.devices[_deviceA], device), isTrue);
      expect(identical(f.doc.outlets[_p1], outlet), isTrue);
      expect(identical(f.doc.links[const Uuid('w4')], link), isTrue);
      expect(f.doc.outlets, hasLength(4));
      expect(f.doc.links, hasLength(5));
      expect(f.doc.nets, hasLength(5));
    });

    test('an EMPTY panel still removes the body and the device', () {
      final f = _fixture();
      f.doc.outlets.removeWhere((_, o) => o.structureBodyId == _bodyA);
      f.doc.links.removeWhere(
        (_, l) => l.structureOrigin?.structureBodyId == _bodyA,
      );

      final changed = f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(tx, planStructureRemoval(f.doc, _bodyA)),
      );

      expect(changed, isTrue);
      expect(f.doc.structures.containsKey(_bodyA), isFalse);
      expect(f.doc.devices.containsKey(_deviceA), isFalse);
    });

    test('an EMPTY plan adds nothing and leaves no undo entry', () {
      final f = _fixture();
      final depth = f.controller.undo.depth;
      final changed = f.controller.transact(
        LabelKey.removeStructure,
        (tx) => addStructureRemoval(
          tx,
          planStructureRemoval(f.doc, const Uuid('x')),
        ),
      );

      expect(changed, isFalse);
      expect(f.controller.undo.depth, depth);
      expect(f.doc.structures, hasLength(2));
    });
  });
}
