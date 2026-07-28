// DR-008 §11.8.1's jumper rule, and the "undetermined is not fieldCable"
// contract that goes with it.
//
// The case this file exists for is `two field ends do not make a jumper`.
// Both ends of a wall-to-wall home run resolve to a null rack, and the
// obvious implementation — compare the two racks for equality — reports
// null == null and classifies it as a jumper. A jumper is excluded from the
// Pull Sheet by default, so that bug DELETES A REAL PULL FROM THE SHEET AN
// INSTALLER WORKS FROM, silently, on the runs most likely to be long and
// expensive. Every other test here is cheap; that one is the reason.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 28);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rackA = Uuid('rack-a');
const _rackB = Uuid('rack-b');

/// Two racks, and devices placed per [placements] — `null` means the device
/// is off-rack. Each device gets exactly one port, keyed `<id>.p`.
RackDocument _doc(Map<String, Uuid?> placements) {
  final doc = RackDocument(
    id: const Uuid('doc-lc'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  for (final rackId in [_rackA, _rackB]) {
    doc.racks[rackId] = Rack(
      id: rackId,
      name: rackId.v,
      designator: rackId == _rackA ? 'RK-1' : 'RK-2',
      heightU: 24,
      order: FracIndex(rackId == _rackA ? 'a0' : 'a1'),
      meta: _meta(),
    );
  }
  placements.forEach((name, rackId) {
    final id = Uuid(name);
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('tpl.x'),
        version: 1,
        contentHash: 'sha256:tpl.x',
      ),
      designator: name.toUpperCase(),
      name: name,
      placement: rackId == null
          ? const OffRackPlacement()
          : RailPlacement(rackId: rackId, ruIndex: 1, face: Face.front),
      meta: _meta(),
    );
    doc.ports[Uuid('$name.p')] = Port(
      id: Uuid('$name.p'),
      deviceId: id,
      designator: '${name.toUpperCase()}-P1',
      templatePortKey: const PortKey('p'),
    );
  });
  return doc;
}

Link _link(Endpoint from, Endpoint to) => Link(
  id: const Uuid('lnk'),
  designator: 'W001',
  media: const MediaTypeId('media.cat6_utp'),
  order: const FracIndex('a0'),
  meta: _meta(),
)..conductors.add(Conductor(from: from, to: to));

Endpoint _port(String device) => PortEndpoint(Uuid('$device.p'));
Endpoint _field(String what) => PlaceEndpoint(description: what);

void main() {
  group('DR-008 §11.8.1 — a jumper is both ends in the same rack', () {
    test('both ends in ONE rack is a jumper', () {
      final doc = _doc({'a': _rackA, 'b': _rackA});
      expect(linkClassOf(doc, _link(_port('a'), _port('b'))), LinkClass.jumper);
    });

    test('ends in DIFFERENT racks is a fieldCable', () {
      final doc = _doc({'a': _rackA, 'b': _rackB});
      expect(
        linkClassOf(doc, _link(_port('a'), _port('b'))),
        LinkClass.fieldCable,
        reason:
            'a run between two racks is pulled through the building and '
            'belongs on the Pull Sheet',
      );
    });

    test('rack to field is a fieldCable', () {
      final doc = _doc({'a': _rackA});
      expect(
        linkClassOf(doc, _link(_port('a'), _field('projector shelf, beam 3'))),
        LinkClass.fieldCable,
      );
    });

    test('TWO FIELD ENDS DO NOT MAKE A JUMPER', () {
      final doc = _doc({});
      expect(
        linkClassOf(
          doc,
          _link(_field('beam 3'), _field('great room, west wall')),
        ),
        LinkClass.fieldCable,
        reason:
            'both ends resolve to a NULL rack, so a bare rack-equality test '
            'reports null == null and calls this a jumper. Jumpers are '
            'excluded from the Pull Sheet by default, so that bug silently '
            'deletes a real wall-to-wall pull from the sheet the installer '
            'works from',
      );
    });

    test('length is irrelevant — DR-008 struck that limb', () {
      final doc = _doc({'a': _rackA, 'b': _rackA});
      final long = _link(_port('a'), _port('b'))
        ..cutLength = Len.fromMillimetres(9000);
      expect(
        linkClassOf(doc, long),
        LinkClass.jumper,
        reason:
            'a 9 m service loop that begins and ends in one rack is still '
            'not something anybody pulls through a wall',
      );
    });
  });

  group('undetermined is an answer, and it is not fieldCable', () {
    test('a port that is not materialised gives null, not a guess', () {
      final doc = _doc({'a': _rackA});
      expect(
        linkClassOf(doc, _link(_port('a'), _port('ghost'))),
        isNull,
        reason:
            'defaulting this to fieldCable asserts a pull nobody has '
            'established; defaulting it to jumper hides it. G4: count it',
      );
    });

    test('a device that is off-rack gives null', () {
      final doc = _doc({'a': _rackA, 'b': null});
      expect(linkClassOf(doc, _link(_port('a'), _port('b'))), isNull);
    });

    test('a link with no conductors gives null', () {
      final doc = _doc({'a': _rackA});
      final bare = Link(
        id: const Uuid('lnk'),
        designator: 'W001',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      expect(linkClassOf(doc, bare), isNull);
    });
  });

  group('rackOfEndpoint', () {
    test('walks a SHELF CHAIN to the rack that ultimately hosts it', () {
      // The two-hop case, and the reason `rackOfEndpoint` defers to
      // `hostRackOf` instead of reading `placement.rackId` itself: a device
      // on a shelf has no rack of its own, and its host may be shelved too.
      // A one-hop implementation returns null here and the link silently
      // becomes UNDETERMINED — dropping a real in-rack jumper into the
      // "cannot classify" bucket.
      final doc = _doc({'host': _rackA, 'mid': _rackA});
      doc.devices[const Uuid('mid')] = DeviceInstance(
        id: const Uuid('mid'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.x'),
          version: 1,
          contentHash: 'sha256:tpl.x',
        ),
        designator: 'MID',
        name: 'mid',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('host'),
          order: FracIndex('a0'),
        ),
        meta: _meta(),
      );
      expect(rackOfEndpoint(doc, _port('mid')), _rackA);
    });

    test('a shelf chain that never reaches a rack resolves to null', () {
      final doc = _doc({'orphan': null});
      doc.devices[const Uuid('orphan')] = DeviceInstance(
        id: const Uuid('orphan'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.x'),
          version: 1,
          contentHash: 'sha256:tpl.x',
        ),
        designator: 'ORPHAN',
        name: 'orphan',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('missing-host'),
          order: FracIndex('a0'),
        ),
        meta: _meta(),
      );
      expect(rackOfEndpoint(doc, _port('orphan')), isNull);
    });

    test('resolves a rail-placed port to its rack', () {
      final doc = _doc({'a': _rackB});
      expect(rackOfEndpoint(doc, _port('a')), _rackB);
    });

    test('a field end and an open end both resolve to no rack', () {
      final doc = _doc({});
      expect(rackOfEndpoint(doc, _field('beam 3')), isNull);
      expect(rackOfEndpoint(doc, const OpenEndpoint('J-hook')), isNull);
    });
  });
}
