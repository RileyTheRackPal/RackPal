// M3-B/1, #144 — what deleting a location costs, and the delete that
// consumes exactly that (DR-021 §11.20.1 through §11.20.4).
//
// Five claims:
//
//   1. the plan takes the SUBTREE, not the node;
//   2. it finds all NINE carriers, including `Pathway`'s two that a grep
//      for `locationId` misses and the two inside immutable objects;
//   3. it counts ENTITIES, so a four-conductor home run in one room is one
//      cable to the person reading the dialog;
//   4. the command clears exactly what the plan described, so the dialog's
//      number and the edit cannot drift;
//   5. undo restores the ORIGINAL objects, not equal ones — the byte case
//      is what proves it, since a rebuilt `Conductor` compares equal to
//      the one it replaced and encodes identically only if every field
//      came back.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _when = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-location-removal'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

Uuid _add(RackDocument doc, String name, {Uuid? parent}) => (AddLocationCommand(
  name: name,
  code: name.substring(0, 2).toUpperCase(),
  order: nextLocationOrder(doc, parentId: parent),
  parentId: parent,
  now: _when,
  actor: 'seed',
)..apply(doc)).id;

/// Puts one of every carrier in the document, all pointing at [where].
///
/// Ten references across eight entities: the device carries two (its own
/// `locationId` and its `OffRackPlacement`'s), and the pathway carries two.
/// The tenth is a floorplan showing [where] (DR-185), unreachable until
/// `SetPlanUnderlayDetailsCommand` gave `PlanUnderlay.locationId` a writer.
void _seedEveryCarrier(RackDocument doc, Uuid where) {
  doc.racks[const Uuid('rk')] = Rack(
    id: const Uuid('rk'),
    name: 'Rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: where,
  );
  doc.devices[const Uuid('dev')] = DeviceInstance(
    id: const Uuid('dev'),
    kind: DeviceKind.offRackPassive,
    templateRef: _templateRef,
    designator: 'DEV-1',
    name: 'Device',
    placement: OffRackPlacement(locationId: where, mountNote: 'on the beam'),
    meta: _meta(),
    locationId: where,
  );
  doc.structures[const Uuid('str')] = StructureBody(
    id: const Uuid('str'),
    deviceId: const Uuid('dev'),
    title: 'Rough-In',
    meta: _meta(),
    distributionDeviceLocationId: where,
  );
  doc.outlets[const Uuid('out')] = Outlet(
    id: const Uuid('out'),
    structureBodyId: const Uuid('str'),
    designation: 'GR-TV-1',
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: where,
  );
  doc.circuits[const Uuid('cir')] = Circuit(
    id: const Uuid('cir'),
    designator: 'Panel A / 14',
    breakerAmps: 20,
    volts: 120,
    meta: _meta(),
    locationId: where,
  );
  doc.pathways[const Uuid('pth')] = Pathway(
    id: const Uuid('pth'),
    name: 'B03',
    order: const FracIndex('a0'),
    meta: _meta(),
    fromLocationId: where,
    toLocationId: where,
  );
  doc.links[const Uuid('lnk')] = Link(
    id: const Uuid('lnk'),
    designator: 'W001',
    media: const MediaTypeId('media.cat6_utp'),
    meta: _meta(),
    order: const FracIndex('a0'),
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'TV wall', locationId: where),
        to: const OpenEndpoint('coiled at the panel'),
      ),
    ],
  );
  doc.underlays[const Uuid('pln')] = PlanUnderlay(
    id: const Uuid('pln'),
    name: 'Level 1',
    imageMember: 'underlays/pln.png',
    format: PlanImageFormat.png,
    pixelWidth: 600,
    pixelHeight: 400,
    contentHash: 'sha256:test',
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: where,
  );
}

void main() {
  group('planLocationRemoval', () {
    test('a location this document does not hold plans nothing', () {
      // A stale selection, or a second delete arriving after an undo.
      // Normal, and not an error.
      final plan = planLocationRemoval(_doc(), const Uuid('ghost'));

      expect(plan.isEmpty, isTrue);
      expect(plan.locationCount, 0);
      expect(plan.needsConfirmation, isFalse);
    });

    test('takes the SUBTREE, not the node (DR-021 §11.20.1)', () {
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final level = _add(doc, 'Level 1', parent: house);
      final living = _add(doc, 'Living Room', parent: level);
      final shed = _add(doc, 'Shed');

      final plan = planLocationRemoval(doc, house);

      expect(plan.locationIds, [house, level, living]);
      expect(plan.locationCount, 3);
      expect(plan.locationIds, isNot(contains(shed)));
    });

    test('a bare leaf needs no confirmation at all', () {
      // DR-013 §11.13.2's "a device carrying nothing is deleted with no
      // prompt at all", applied to the same shape of question. A
      // confirmation on every delete trains people to dismiss them.
      final doc = _doc();
      final shed = _add(doc, 'Shed');

      expect(planLocationRemoval(doc, shed).needsConfirmation, isFalse);
    });

    test('a node with children needs one even with nothing pointing at '
        'it', () {
      final doc = _doc();
      final house = _add(doc, 'Main House');
      _add(doc, 'Level 1', parent: house);

      expect(planLocationRemoval(doc, house).needsConfirmation, isTrue);
    });

    test('finds all ten carriers across eight entities', () {
      // The census DR-021 puts in the ruling, stated as a test. Two of
      // these are unreachable by a case-sensitive grep for `locationId`
      // (`Pathway.fromLocationId`, `.toLocationId`) and two live inside
      // immutable value objects.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);

      final plan = planLocationRemoval(doc, room);

      expect(
        plan.references.map((r) => r.kind).toSet(),
        LocationRefKind.values.toSet(),
        reason: 'a carrier in the enum is not being found by the plan',
      );
      expect(plan.references, hasLength(10));
      expect(plan.referenceCount, 8);
    });

    test('references into ANY node of the subtree are found, and each '
        'records which', () {
      // Not just references to the node being deleted. Revert has to put
      // the RIGHT id back, so the ref carries it.
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room', parent: house);
      doc.racks[const Uuid('rk')] = Rack(
        id: const Uuid('rk'),
        name: 'Rack',
        designator: 'RK-1',
        heightU: 42,
        order: const FracIndex('a0'),
        meta: _meta(),
        locationId: living,
      );

      final plan = planLocationRemoval(doc, house);

      expect(plan.references.single.locationId, living);
    });

    test('counts ENTITIES, so one home run in one room is one cable', () {
      // A four-conductor cable to a TV wall holds four `PlaceEndpoint`s in
      // the same room. The dialog says one, because that is what an
      // installer pulls and what occupies one row on the schedule.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      doc.links[const Uuid('lnk')] = Link(
        id: const Uuid('lnk'),
        designator: 'W001',
        media: const MediaTypeId('media.cat6_utp'),
        meta: _meta(),
        order: const FracIndex('a0'),
        conductors: [
          for (var i = 0; i < 4; i++)
            Conductor(
              from: PlaceEndpoint(description: 'TV wall', locationId: room),
              to: const OpenEndpoint('coiled'),
            ),
        ],
      );

      final plan = planLocationRemoval(doc, room);

      expect(plan.references, hasLength(4));
      expect(plan.referenceCount, 1);
    });

    test('a reference to an unrelated room is left entirely alone', () {
      final doc = _doc();
      final living = _add(doc, 'Living Room');
      final attic = _add(doc, 'Attic');
      _seedEveryCarrier(doc, attic);

      expect(planLocationRemoval(doc, living).references, isEmpty);
    });
  });

  group('RemoveLocationCommand', () {
    test('clears every reference the plan named, and takes the subtree', () {
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room', parent: house);
      _seedEveryCarrier(doc, living);

      buildRemoveLocation(doc: doc, locationId: house)!.apply(doc);

      expect(doc.locations, isEmpty);
      expect(doc.racks[const Uuid('rk')]!.locationId, isNull);
      expect(doc.devices[const Uuid('dev')]!.locationId, isNull);
      expect(
        (doc.devices[const Uuid('dev')]!.placement as OffRackPlacement)
            .locationId,
        isNull,
      );
      expect(doc.outlets[const Uuid('out')]!.locationId, isNull);
      expect(
        doc.structures[const Uuid('str')]!.distributionDeviceLocationId,
        isNull,
      );
      expect(doc.circuits[const Uuid('cir')]!.locationId, isNull);
      expect(doc.pathways[const Uuid('pth')]!.fromLocationId, isNull);
      expect(doc.pathways[const Uuid('pth')]!.toLocationId, isNull);
      expect(
        (doc.links[const Uuid('lnk')]!.conductors.first.from as PlaceEndpoint)
            .locationId,
        isNull,
      );
      expect(doc.underlays[const Uuid('pln')]!.locationId, isNull);
    });

    test('nothing is DELETED except locations (DR-021 §11.20.6)', () {
      // A cable pulled to a wall is a fact about the building and survives
      // the room being renamed out of existence. The same argument
      // `RemoveStructureCommand` makes about an outlet surviving its
      // panel.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);

      buildRemoveLocation(doc: doc, locationId: room)!.apply(doc);

      expect(doc.racks, hasLength(1));
      expect(doc.devices, hasLength(1));
      expect(doc.outlets, hasLength(1));
      expect(doc.structures, hasLength(1));
      expect(doc.circuits, hasLength(1));
      expect(doc.pathways, hasLength(1));
      expect(doc.links, hasLength(1));
      expect(doc.underlays, hasLength(1), reason: 'a plan loses its floor');
    });

    test('the fields BESIDE the cleared one survive on both immutable '
        'carriers', () {
      // Clearing an immutable value means constructing a replacement, and
      // a replacement built from scratch loses everything the original
      // carried. `mountNote` and the endpoint's `description` are the two
      // that would go silently.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);

      buildRemoveLocation(doc: doc, locationId: room)!.apply(doc);

      final placement =
          doc.devices[const Uuid('dev')]!.placement as OffRackPlacement;
      expect(placement.mountNote, 'on the beam');
      final end =
          doc.links[const Uuid('lnk')]!.conductors.first.from as PlaceEndpoint;
      expect(end.description, 'TV wall');
      expect(
        doc.links[const Uuid('lnk')]!.conductors.first.to,
        isA<OpenEndpoint>(),
      );
    });

    test('a drop whose room is cleared is still a drop, with its label', () {
      // The join to M3-B/3: G4 says the run may not vanish from the Pull
      // Sheet, so clearing the room must leave the cable, the W number and
      // the field end intact and merely roomless.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);

      buildRemoveLocation(doc: doc, locationId: room)!.apply(doc);

      final link = doc.links[const Uuid('lnk')]!;
      expect(link.designator, 'W001');
      expect(link.conductors, hasLength(1));
      expect(link.conductors.first.from, isA<PlaceEndpoint>());
    });

    test('undo restores every byte, which is the ORIGINAL objects and not '
        'equal ones (DR-021 §11.20.4)', () {
      // The property that makes delete-then-undo lossless. A rebuilt
      // `Conductor` or `OffRackPlacement` compares equal to the one it
      // replaced and encodes identically ONLY if every field came back,
      // so the byte comparison is what states it rather than a field-by-
      // field walk that could miss the one nobody thought of.
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room', parent: house);
      _seedEveryCarrier(doc, living);
      final before = _codec.write(doc);

      final cmd = buildRemoveLocation(doc: doc, locationId: house)!..apply(doc);
      expect(_codec.write(doc), isNot(orderedEquals(before)));

      cmd.revert(doc);
      expect(_codec.write(doc), orderedEquals(before));
    });

    test('redo lands in the same place as the first apply', () {
      // `Command`'s third property: apply/revert/apply is the identical
      // state a single apply reaches.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);

      final cmd = buildRemoveLocation(doc: doc, locationId: room)!..apply(doc);
      final afterFirst = _codec.write(doc);

      cmd
        ..revert(doc)
        ..apply(doc);

      expect(_codec.write(doc), orderedEquals(afterFirst));
    });

    test('revert before apply throws rather than corrupting anything', () {
      final doc = _doc();
      final room = _add(doc, 'Living Room');

      expect(
        () => buildRemoveLocation(doc: doc, locationId: room)!.revert(doc),
        throwsStateError,
      );
    });

    test('an entity that went away between the plan and the apply is not '
        'an error', () {
      // "Apply ran and it was already gone" is a legal outcome whose
      // revert is a no-op. `RemoveStructureCommand` draws the same line,
      // and `RemoveDeviceCommand` learned it from a property suite.
      final doc = _doc();
      final room = _add(doc, 'Living Room');
      _seedEveryCarrier(doc, room);
      final cmd = buildRemoveLocation(doc: doc, locationId: room)!;

      doc.racks.remove(const Uuid('rk'));
      cmd
        ..apply(doc)
        ..revert(doc);

      expect(doc.locations[room], isNotNull);
      expect(doc.racks, isEmpty);
    });

    test('buildRemoveLocation returns null for a location that is not '
        'there', () {
      expect(
        buildRemoveLocation(doc: _doc(), locationId: const Uuid('ghost')),
        isNull,
      );
    });

    test('the command carries the SAME plan the dialog would show', () {
      // DR-021 §11.20.3: one number, one source. A command that re-derived
      // its own plan could remove five rooms after a dialog said four.
      final doc = _doc();
      final house = _add(doc, 'Main House');
      _add(doc, 'Level 1', parent: house);

      final cmd = buildRemoveLocation(doc: doc, locationId: house)!;

      expect(cmd.plan.locationCount, 2);
      cmd.apply(doc);
      expect(doc.locations, isEmpty);
    });
  });
}
