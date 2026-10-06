// DR-238 (canon §11.237, `#1002`): a captive cord is part of its device, and
// T6.30 does not list it.
//
// THE CASE THIS FILE EXISTS FOR is the real catalogue's: an A02 amplifier's
// own NEMA 5-15P lead into a P04 PDU's 5-15R outlet. T6.30 listed it as a
// cord to buy, beside an A03's detachable IEC cord that somebody really
// does buy. Only the second belongs in the table.
//
// AND IT STAYS A POWER CORD: off the Pull Sheet, on the outlet map. Only the
// bought-by-the-piece count moves, and the footage note says where it went.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rack = Uuid('rack-1');

/// One rack holding [devices], each a seed template, with every port its
/// template declares created as `<device>.<key>`.
RackDocument _doc(Map<String, String> devices) {
  final doc = RackDocument(
    id: const Uuid('doc-captive'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'rack',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  final catalog = buildSeedCatalog();
  var ru = 1;
  devices.forEach((id, tpl) {
    final body = catalog[tpl]!;
    doc.templates['$tpl@1'] = TemplateSnapshot(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
      body: body,
      capturedAt: _when,
    );
    doc.devices[Uuid(id)] = DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(tpl),
        version: 1,
        contentHash: 'sha256:$tpl',
      ),
      designator: id.toUpperCase(),
      name: id,
      placement: RailPlacement(rackId: _rack, ruIndex: ru, face: Face.front),
      meta: _meta(),
    );
    ru += 4;
    for (final def in body.ports) {
      final portId = Uuid('$id.${def.key.v}');
      doc.ports[portId] = Port(
        id: portId,
        deviceId: Uuid(id),
        designator: '${id.toUpperCase()}-${def.key.v}',
        templatePortKey: def.key,
      );
    }
  });
  return doc;
}

int _seq = 0;

/// A cord from [from] to [to], `<device>.<key>` each, or to a place.
void _cord(
  RackDocument doc,
  String from, {
  String? to,
  String? place,
  int feet = 6,
}) {
  _seq++;
  final id = Uuid('cord-$_seq');
  doc.links[id] = Link(
    id: id,
    designator: 'W${_seq.toString().padLeft(3, '0')}',
    media: const MediaTypeId('media.cat6_utp'),
    order: FracIndex('a${_seq.toString().padLeft(4, '0')}'),
    meta: _meta(),
    cutLength: Len(feet * 12 * Len.nmPerInch),
    conductors: [
      Conductor(
        from: PortEndpoint(Uuid(from)),
        to: to != null
            ? PortEndpoint(Uuid(to))
            : PlaceEndpoint(description: place!),
      ),
    ],
  );
}

/// The A02's captive cord and the A03's detachable one, both into PDUs.
RackDocument _amps() {
  final doc = _doc({'a02': 'A02', 'a03': 'A03', 'p04': 'P04', 'p01': 'P01'});
  _cord(doc, 'a02.ac.in', to: 'p04.out.1', feet: 3);
  _cord(doc, 'a03.ac.in', to: 'p01.c13.1');
  return doc;
}

void main() {
  test("AN A02's OWN LEAD IS NOT IN T6.30; an A03's detachable cord is", () {
    final doc = _amps();
    final rollup = buildJumperRollup(doc);
    expect(rollup.quantity, 1);
    expect(
      rollup.lines.single.length,
      const Len(6 * 12 * Len.nmPerInch),
      reason: "the A03's 6 ft cord, not the A02's 3 ft lead",
    );
  });

  test('BOTH ARE STILL POWER CORDS; only the captive one is flagged', () {
    final schedule = buildSchedule(_amps());
    expect(
      [for (final r in schedule.rows) (r.linkClass, r.isCaptiveCord)],
      unorderedEquals([
        (LinkClass.powerCord, true),
        (LinkClass.powerCord, false),
      ]),
    );
  });

  test('ONE COUNT READ TWICE: the footage note agrees with the table, and '
      'says where the captive cord went', () {
    final doc = _amps();
    final schedule = buildSchedule(doc);
    final footage = cableFootageOf(schedule, doc: doc);
    expect(
      footage.excludedJumpers + footage.excludedPowerCords,
      jumperRollupOf(schedule).quantity,
    );
    expect(footage.excludedCaptiveCords, 1);
    expect(
      footageSection(footage, UnitSystem.imperial).notes,
      contains(
        'Not footage: 1 power cord, bought by the piece; 1 captive cord, '
        'part of its device.',
      ),
    );
  });

  test('A CAPTIVE LEAD TO A WALL RECEPTACLE is captive too', () {
    final doc = _doc({'a02': 'A02'});
    _cord(doc, 'a02.ac.in', place: 'receptacle behind the TV');
    expect(buildJumperRollup(doc).quantity, 0);
    expect(buildCableFootage(doc).excludedCaptiveCords, 1);
  });
}
