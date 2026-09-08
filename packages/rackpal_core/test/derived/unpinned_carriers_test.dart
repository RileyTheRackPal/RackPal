// PLAN-E/4: what the unpinned strip lists (DR-142 §11.141, DR-140 §11.139).
//
// EVERY FIXTURE HERE IS BUILT SO THE TWO PLAUSIBLE ANSWERS DIFFER, which
// is this chapter's brief in one line. A count that counts the wrong thing
// passes on a document where the wrong thing and the right thing are the
// same number, and the status bar that read `0 pathways` had a test
// pinning `pathwayCount, 1` on a two-pathway document.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 8);
const _ul1 = Uuid('ul-1');
const _ul2 = Uuid('ul-2');
const _level1 = Uuid('loc-l1');
const _level2 = Uuid('loc-l2');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

PlanUnderlay _underlay(Uuid id, {Uuid? locationId}) => PlanUnderlay(
  id: id,
  name: 'plan ${id.v}',
  locationId: locationId,
  imageMember: 'underlays/${id.v}.png',
  format: PlanImageFormat.png,
  pixelWidth: 600,
  pixelHeight: 400,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: _meta(),
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.underlays[_ul1] = _underlay(_ul1, locationId: _level1);
  for (final entry in const [(_level1, 'Level 1'), (_level2, 'Level 2')]) {
    doc.locations[entry.$1] = Location(
      id: entry.$1,
      kind: LocationKind.floor,
      name: entry.$2,
      code: entry.$2.replaceAll(' ', ''),
      order: const FracIndex('a0'),
      meta: _meta(),
    );
  }
  return doc;
}

void _addRack(RackDocument doc, String id, {Uuid? at, PlanPin? pin}) {
  doc.racks[Uuid(id)] = Rack(
    id: Uuid(id),
    name: 'rack $id',
    designator: id.toUpperCase(),
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: at,
    planPin: pin,
  );
}

void _addOutlet(RackDocument doc, String id, {Uuid? at, PlanPin? pin}) {
  doc.outlets[Uuid(id)] = Outlet(
    id: Uuid(id),
    structureBodyId: const Uuid('body-1'),
    designation: id.toUpperCase(),
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: at,
    planPin: pin,
  );
}

/// An off-rack device with both of its location fields set to [at], which
/// is the state the model requires and the fix in `AddDeviceCommand`
/// produces.
void _addDevice(RackDocument doc, String id, {Uuid? at, PlanPin? pin}) =>
    _putDevice(doc, id, placementAt: at, instanceAt: at, pin: pin);

/// The general form, so one case can build the disagreement `PLAN-E/2`
/// used to produce and no other case has to think about it.
void _putDevice(
  RackDocument doc,
  String id, {
  Uuid? placementAt,
  Uuid? instanceAt,
  PlanPin? pin,
}) {
  doc.devices[Uuid(id)] = DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.offRackPassive,
    templateRef: const TemplateRef(
      templateId: TemplateId('F1'),
      version: 1,
      contentHash: 'sha256:test-F1',
    ),
    designator: id.toUpperCase(),
    name: 'device $id',
    placement: OffRackPlacement(locationId: placementAt, planPin: pin),
    meta: _meta(),
    locationId: instanceAt,
  );
}

/// A device on rails, which has no pin field and is therefore not a
/// carrier at all.
void _addRackedDevice(RackDocument doc, String id) {
  doc.devices[Uuid(id)] = DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('F1'),
      version: 1,
      contentHash: 'sha256:test-F1',
    ),
    designator: id.toUpperCase(),
    name: 'device $id',
    placement: const RailPlacement(
      rackId: Uuid('rk-1'),
      ruIndex: 1,
      face: Face.front,
    ),
    meta: _meta(),
  );
}

PlanPin _pinOn(Uuid underlayId) =>
    PlanPin(underlayId: underlayId, at: const PxPt(10, 10));

void main() {
  group('the count', () {
    test('COUNTS CARRIERS AND NOT DEVICES, which DR-140 is the whole of', () {
      final doc = _doc();
      _addDevice(doc, 'd-1', at: _level1);
      _addDevice(doc, 'd-2', at: _level1);
      _addDevice(doc, 'd-3', at: _level1);
      _addRack(doc, 'rk-1', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      // THREE DEVICES AND ONE RACK, so the two answers differ. A strip
      // built from `doc.devices` alone says 3 here and passes every
      // fixture that has no rack, which is the trap this chapter's brief
      // names in the status bar that read "0 pathways".
      expect(strip.count, 4);
      expect(
        strip.rows.map((r) => r.carrier),
        contains(PinCarrier.rack),
        reason: 'the one carrier whose absence costs every length (PLN-003)',
      );
    });

    test('is rows only: an unlocated carrier is not added to it', () {
      final doc = _doc();
      _addDevice(doc, 'd-1', at: _level1);
      _addDevice(doc, 'd-2');

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      // Two answers to two questions, as `PathwayTable` carries two.
      expect(strip.count, 1);
      expect(strip.unlocatedCount, 1);
    });
  });

  group('unpinned', () {
    test('a pinned carrier is not listed', () {
      final doc = _doc();
      _addDevice(doc, 'd-1', at: _level1, pin: _pinOn(_ul1));
      _addDevice(doc, 'd-2', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.map((r) => r.designator), ['D-2']);
    });

    test(
      'MEANS NO PIN AT ALL: a carrier pinned on another plan of the same '
      'room is not listed here',
      () {
        // DR-142 §11.141.2, and the alternative reading is not a wrong
        // row, it is a destructive gesture: a carrier holds ONE `planPin`,
        // so dragging this row out would MOVE the pin off `ul-2` while
        // presenting itself as adding something.
        final doc = _doc();
        doc.underlays[_ul2] = _underlay(_ul2, locationId: _level1);
        _addDevice(doc, 'd-1', at: _level1, pin: _pinOn(_ul2));

        final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

        expect(strip.count, 0);
        expect(strip.unlocatedCount, 0);
      },
    );
  });

  group('the location filter', () {
    test('a carrier in another KNOWN room is excluded and not unlocated', () {
      final doc = _doc();
      _addDevice(doc, 'd-1', at: _level1);
      _addDevice(doc, 'd-2', at: _level2);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.map((r) => r.designator), ['D-1']);
      // NOT unlocated. `Level 2` is a known room and that plan lists it;
      // reporting it as unknown here would count it twice over a project.
      expect(strip.unlocatedCount, 0);
    });

    test(
      'an underlay with NO location has no filter, so it lists everything '
      'unpinned and reports nothing unknown',
      () {
        // A site plan depicts no room, which the model calls perfectly
        // ordinary. Listing nothing would report ZERO on a plan with
        // nothing pinned; joining its null to a carrier's null is the
        // unknown-equals-unknown match G4 forbids.
        final doc = _doc();
        doc.underlays[_ul2] = _underlay(_ul2);
        _addDevice(doc, 'd-1', at: _level1);
        _addDevice(doc, 'd-2', at: _level2);
        _addDevice(doc, 'd-3');

        final strip = unpinnedCarriersFor(doc, doc.underlays[_ul2]!);

        expect(strip.rows.map((r) => r.designator), ['D-1', 'D-2', 'D-3']);
        expect(
          strip.unlocatedCount,
          0,
          reason: 'nothing is filtered out, so nothing is missing from rows',
        );
      },
    );

    test(
      'a device whose two location fields DISAGREE is placed by the '
      'placement, which is the field beside the pin',
      () {
        // The legacy shape `PLAN-E/2` produced (DR-142 §11.141.5): a
        // placement saying `Level 1` and an instance saying nothing. The
        // writer is fixed, and a project saved by that build is still on
        // somebody's disk.
        final doc = _doc();
        _putDevice(doc, 'd-1', placementAt: _level1);

        final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

        expect(strip.rows.map((r) => r.designator), ['D-1']);
        expect(strip.unlocatedCount, 0);
      },
    );
  });

  group('what is not a carrier at all', () {
    test('a rail-placed device has no pin field and is absent', () {
      final doc = _doc();
      _addRackedDevice(doc, 'd-1');
      _addDevice(doc, 'd-2', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.map((r) => r.designator), ['D-2']);
      expect(
        strip.unlocatedCount,
        0,
        reason: 'a racked device is not an unlocated carrier, it is not one',
      );
    });
  });

  group('the order', () {
    test('is rack, then outlets, then devices, each band by designator', () {
      final doc = _doc();
      _addDevice(doc, 'd-2', at: _level1);
      _addOutlet(doc, 'o-2', at: _level1);
      _addRack(doc, 'rk-1', at: _level1);
      _addOutlet(doc, 'o-1', at: _level1);
      _addDevice(doc, 'd-1', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.map((r) => r.designator), [
        'RK-1',
        'O-1',
        'O-2',
        'D-1',
        'D-2',
      ]);
    });

    test('does not depend on insertion order, which is what disk changes', () {
      // `Map` iteration is insertion order, so a document reopened from a
      // file enumerates differently from the one just built. Without the
      // sort the same project produces two different strips.
      final forward = _doc();
      _addDevice(forward, 'd-1', at: _level1);
      _addDevice(forward, 'd-2', at: _level1);
      _addOutlet(forward, 'o-1', at: _level1);

      final backward = _doc();
      _addOutlet(backward, 'o-1', at: _level1);
      _addDevice(backward, 'd-2', at: _level1);
      _addDevice(backward, 'd-1', at: _level1);

      expect(
        unpinnedCarriersFor(forward, forward.underlays[_ul1]!).rows,
        unpinnedCarriersFor(backward, backward.underlays[_ul1]!).rows,
      );
    });
  });

  group('a row', () {
    test('names the writer a drag out of it would use', () {
      final doc = _doc();
      _addRack(doc, 'rk-1', at: _level1);
      _addOutlet(doc, 'o-1', at: _level1);
      _addDevice(doc, 'd-1', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.map((r) => r.carrier), [
        PinCarrier.rack,
        PinCarrier.outlet,
        PinCarrier.offRackDevice,
      ]);
    });

    test('carries a null name for an outlet, which has no such field', () {
      // G4: an empty string would read as "named, with nothing in it".
      final doc = _doc();
      _addOutlet(doc, 'o-1', at: _level1);
      _addRack(doc, 'rk-1', at: _level1);

      final strip = unpinnedCarriersFor(doc, doc.underlays[_ul1]!);

      expect(strip.rows.firstWhere((r) => r.designator == 'O-1').name, isNull);
      expect(
        strip.rows.firstWhere((r) => r.designator == 'RK-1').name,
        'rack rk-1',
      );
    });
  });
}
