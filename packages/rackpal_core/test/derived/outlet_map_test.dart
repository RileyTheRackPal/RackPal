// AC-026's outlet map (M6-F5 `#340`, DR-219 §11.218.2): a row per outlet
// with a cord drawn to it, then each provider's free count, then how many
// devices are charged an outlet per inlet because nothing is drawn.
//
// ON WHOLE HOUSE, with cords drawn by hand: the starter has four outlet
// providers (two PDUs, the sequencer, the UPS) and no cord to any of them.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DeviceInstance _device(RackDocument doc, String designator) =>
    doc.devices.values.firstWhere((d) => d.designator == designator);

PortDef _port(RackDocument doc, DeviceInstance d, PortPowerRole role, int i) =>
    bodyFor(
      d,
      doc.templates,
    )!.ports.where((p) => isPowerPortWithRole(p, role)).elementAt(i);

final _at = DateTime.utc(2026, 10);

/// Draws a cord from [provider]'s outlet [outlet] to [device]'s first
/// inlet, creating the two Port entities a landing creates.
void _cord(
  RackDocument doc,
  String provider,
  int outlet,
  String device,
  String cord,
) {
  final pdu = _device(doc, provider);
  final dev = _device(doc, device);
  final from = Uuid('port-$provider-$outlet');
  final to = Uuid('port-$device-in');
  doc.ports[from] = Port(
    id: from,
    deviceId: pdu.id,
    designator: 'J$outlet',
    templatePortKey: _port(doc, pdu, PortPowerRole.outlet, outlet).key,
  );
  doc.ports[to] = Port(
    id: to,
    deviceId: dev.id,
    designator: 'J0',
    templatePortKey: _port(doc, dev, PortPowerRole.inlet, 0).key,
  );
  final id = Uuid('link-$cord');
  doc.links[id] = Link(
    id: id,
    designator: cord,
    media: const MediaTypeId('media.iec_c13'),
    order: FracIndex('z$cord'),
    meta: EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test'),
    conductors: [Conductor(from: PortEndpoint(from), to: PortEndpoint(to))],
  );
}

void main() {
  test('THE PREMISE: four providers, no cords, every device counted from '
      'its ports', () {
    final map = buildOutletMap(_wholeHouse());
    expect(map.providers.map((p) => p.device.designator), [
      'PDU-1',
      'PDU-2',
      'SEQ-1',
      'UPS-1',
    ]);
    expect(map.providers.every((p) => p.assignments.isEmpty), isTrue);
    expect(map.undrawnDevices, greaterThan(0));
  });

  test('A DRAWN CORD IS A ROW: outlet, device, inlet, cord; and the free '
      'count moves', () {
    final doc = _wholeHouse();
    final before = buildOutletMap(doc);
    _cord(doc, 'PDU-1', 2, 'AMP-1', 'P001');
    _cord(doc, 'PDU-1', 0, 'NAS-1', 'P002');
    final map = buildOutletMap(doc);
    final pdu = map.providers.firstWhere((p) => p.device.designator == 'PDU-1');
    final amp = _device(doc, 'AMP-1');
    expect(
      [
        for (final a in pdu.assignments)
          (a.outletLabel, a.device?.designator, a.inletLabel, a.cord),
      ],
      [
        // IN THE TEMPLATE'S OUTLET ORDER, not the order they were drawn.
        (
          _port(doc, _device(doc, 'PDU-1'), PortPowerRole.outlet, 0).label,
          'NAS-1',
          _port(doc, _device(doc, 'NAS-1'), PortPowerRole.inlet, 0).label,
          'P002',
        ),
        (
          _port(doc, _device(doc, 'PDU-1'), PortPowerRole.outlet, 2).label,
          'AMP-1',
          _port(doc, amp, PortPowerRole.inlet, 0).label,
          'P001',
        ),
      ],
    );
    expect(pdu.assignedCount, 2);
    expect(pdu.freeCount, pdu.outletCount - 2);
    // THE SAME FACTS PWR-003 READS: two devices now have a cord drawn, so
    // two fewer are counted from their ports.
    expect(map.undrawnDevices, before.undrawnDevices - 2);
  });

  test('the section: rows, a free line per provider, the undrawn line, '
      'and the two empty statements', () {
    final doc = _wholeHouse();
    _cord(doc, 'PDU-1', 2, 'AMP-1', 'P001');
    final map = buildOutletMap(doc);
    final section = outletMapSection(doc, map);
    expect(section.rows, hasLength(1));
    expect(section.rows.single[0], 'PDU-1');
    expect(section.rows.single[2], 'AMP-1');
    expect(section.rows.single[4], 'P001');
    expect(section.rows.single[5], 'RK-1');
    expect(
      section.notes.first,
      'PDU-1: 1 of 24 outlets assigned, 23 free.',
    );
    expect(section.notes.last, contains('counted as one outlet per inlet'));

    expect(
      outletMapSection(_wholeHouse(), buildOutletMap(_wholeHouse())).empty,
      kNoOutletCordsText,
    );
    expect(
      outletMapSection(
        doc,
        const OutletMap(providers: [], undrawnDevices: 0),
      ).empty,
      kNoOutletProvidersText,
    );
  });
}
