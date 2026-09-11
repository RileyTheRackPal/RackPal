// The shared fixture builder for the plan derivations.
//
// ═══════════════════════════════════════════════════════════════════════
// EXTRACTED AT `LEN-A/3`, NOT DUPLICATED
// ═══════════════════════════════════════════════════════════════════════
// `plan_length_test.dart` grew this builder for `planLowerBoundOf`, and
// `roomEstimateFor` needs ninety per cent of it: an underlay with a
// calibration, a room, a pinned rack, a rail-mounted device, a port, an
// outlet and a link between them. Copying it would give the project two
// corpora to keep in step, which is the objection `findings_view_test.dart`
// already records against duplicating AC-051's pairs.
//
// The names are public here because a fixture nobody outside the file can
// reach is not a shared fixture.
import 'package:rackpal_core/rackpal_core.dart';

final kPlanWhen = DateTime.utc(2026, 9, 8);
const kPlanUl = Uuid('ul-1');
const kPlanUl2 = Uuid('ul-2');

EntityMeta planMeta() =>
    EntityMeta(createdAt: kPlanWhen, updatedAt: kPlanWhen, updatedBy: 'test');

const kPlanTemplateRef = TemplateRef(
  templateId: TemplateId('tpl.x'),
  version: 1,
  contentHash: 'sha256:tpl.x',
);

/// 36 inches over 100 pixels: `PLAN-F/1`'s own example, so one pixel is
/// 0.36 in and the arithmetic below is readable.
const kUsableScale = PlanScale(
  a: PxPt(0, 0),
  b: PxPt(100, 0),
  distance: Len(36 * Len.nmPerInch),
);

/// Stored and unable to yield a factor: two coincident points.
const kDegenerateScale = PlanScale(
  a: PxPt(10, 10),
  b: PxPt(10, 10),
  distance: Len(36 * Len.nmPerInch),
);

Len inches(num n) => Len((n * Len.nmPerInch).round());

PlanPin planPin(int x, int y, {Uuid on = kPlanUl}) =>
    PlanPin(underlayId: on, at: PxPt(x, y));

final class PlanDoc {
  PlanDoc()
    : doc = RackDocument(
        id: const Uuid('doc-plan-len'),
        appVersion: 'test',
        createdAt: kPlanWhen,
        modifiedAt: kPlanWhen,
        meta: planMeta(),
      );

  final RackDocument doc;
  int _seq = 0;

  Uuid _mint(String prefix) => Uuid('$prefix-${_seq++}');

  Uuid underlay({Uuid id = kPlanUl, PlanScale? scale = kUsableScale}) {
    doc.underlays[id] = PlanUnderlay(
      id: id,
      name: 'Level 1',
      imageMember: 'underlays/$id.png',
      format: PlanImageFormat.png,
      pixelWidth: 2000,
      pixelHeight: 1500,
      contentHash: 'sha256:ul',
      order: const FracIndex('a0'),
      meta: planMeta(),
      scale: scale,
    );
    return id;
  }

  Uuid room(
    String name, {
    Len? riseAllowance,
    List<PxPt>? outline,
    Uuid outlineOn = kPlanUl,
  }) {
    final id = _mint('loc');
    doc.locations[id] = Location(
      id: id,
      kind: LocationKind.room,
      name: name,
      code: 'RM',
      order: FracIndex('a$_seq'),
      meta: planMeta(),
      riseAllowance: riseAllowance,
      planOutline: outline == null
          ? null
          : RoomOutline(underlayId: outlineOn, vertices: outline),
    );
    return id;
  }

  Uuid rack(String designator, {PlanPin? pin}) {
    final id = _mint('rack');
    doc.racks[id] = Rack(
      id: id,
      name: designator,
      designator: designator,
      heightU: 42,
      order: FracIndex('a$_seq'),
      meta: planMeta(),
      planPin: pin,
    );
    return id;
  }

  Uuid outlet(String designation, {PlanPin? pin, Uuid? locationId}) {
    final id = _mint('outlet');
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: const Uuid('structure-1'),
      designation: designation,
      order: FracIndex('a$_seq'),
      meta: planMeta(),
      locationId: locationId,
      planPin: pin,
    );
    return id;
  }

  /// A rail-mounted device in [rackId], so its endpoint resolves to a rack.
  Uuid rackDevice(String designator, Uuid rackId) {
    final id = _mint('dev');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: kPlanTemplateRef,
      designator: designator,
      name: designator,
      placement: RailPlacement(rackId: rackId, ruIndex: 1, face: Face.rear),
      meta: planMeta(),
    );
    return id;
  }

  Uuid offRackDevice(String designator, {PlanPin? pin, Uuid? locationId}) {
    final id = _mint('dev');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.offRackPassive,
      templateRef: kPlanTemplateRef,
      designator: designator,
      name: designator,
      placement: OffRackPlacement(locationId: locationId, planPin: pin),
      meta: planMeta(),
    );
    return id;
  }

  Uuid port(Uuid deviceId, String designator) {
    final id = _mint('port');
    doc.ports[id] = Port(id: id, deviceId: deviceId, designator: designator);
    return id;
  }

  Link link({
    required Endpoint from,
    required Endpoint to,
    Uuid? outletId,
    String? fieldLabel,
  }) {
    final id = _mint('link');
    final l = Link(
      id: id,
      designator: 'W0$_seq',
      media: const MediaTypeId('media.cat6a_futp'),
      order: FracIndex('a$_seq'),
      meta: planMeta(),
      conductors: [Conductor(from: from, to: to)],
      structureOrigin: fieldLabel == null
          ? null
          : StructureOrigin(
              structureBodyId: const Uuid('structure-1'),
              outletId: outletId,
              fieldLabel: fieldLabel,
            ),
    );
    doc.links[id] = l;
    return l;
  }
}
