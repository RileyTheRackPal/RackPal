// docs/04-rack-editor.md §4.1 rule 4's cost column. Today's demo document
// has no links at all, so the shrink modal will truthfully read 0 — these
// tests build the links the document does not yet have, so the helper is
// real code proved correct now rather than code that first runs when M2
// wiring lands.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.link-count'),
  version: 1,
  contentHash: 'sha256:link-count',
);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-link-count'),
  appVersion: '0.1.0',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: _meta(),
);

Uuid _device(RackDocument doc, String designator) {
  final id = Uuid('dev-$designator');
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: _templateRef,
    designator: designator,
    name: 'Device $designator',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  return id;
}

Uuid _port(RackDocument doc, Uuid deviceId, String key) {
  final id = Uuid('port-${deviceId.v}-$key');
  doc.ports[id] = Port(
    id: id,
    deviceId: deviceId,
    designator: key,
  );
  return id;
}

/// Adds a link whose conductors run between the given endpoint pairs.
void _link(RackDocument doc, String designator, List<(Endpoint, Endpoint)> cs) {
  final id = Uuid('link-$designator');
  doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('media.cat6a_futp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    conductors: [for (final (f, t) in cs) Conductor(from: f, to: t)],
  );
}

void main() {
  test('a device with no materialised ports counts zero', () {
    final doc = _doc();
    final dev = _device(doc, 'A');

    expect(linkCountForDevice(doc, dev), 0);
  });

  test('a device with ports but no links counts zero', () {
    final doc = _doc();
    final dev = _device(doc, 'A');
    _port(doc, dev, 'J01');

    expect(linkCountForDevice(doc, dev), 0);
  });

  test('counts a link landing on the device from either conductor end', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final b = _device(doc, 'B');
    final aPort = _port(doc, a, 'J01');
    final bPort = _port(doc, b, 'J01');
    _link(doc, 'W001', [(PortEndpoint(aPort), PortEndpoint(bPort))]);

    expect(linkCountForDevice(doc, a), 1);
    expect(linkCountForDevice(doc, b), 1);
  });

  test('counts a multi-conductor link ONCE — one physical cable, one '
      'cost (RJ-016)', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final b = _device(doc, 'B');
    final a1 = _port(doc, a, 'J01');
    final a2 = _port(doc, a, 'J02');
    final b1 = _port(doc, b, 'J01');
    final b2 = _port(doc, b, 'J02');
    // A 4-conductor speaker cable, two of whose conductors touch A.
    _link(doc, 'W001', [
      (PortEndpoint(a1), PortEndpoint(b1)),
      (PortEndpoint(a2), PortEndpoint(b2)),
    ]);

    expect(linkCountForDevice(doc, a), 1);
  });

  test('counts distinct links separately', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final b = _device(doc, 'B');
    final aPort = _port(doc, a, 'J01');
    final bPort = _port(doc, b, 'J01');
    _link(doc, 'W001', [(PortEndpoint(aPort), PortEndpoint(bPort))]);
    _link(doc, 'W002', [(PortEndpoint(aPort), PortEndpoint(bPort))]);
    _link(doc, 'W003', [(PortEndpoint(bPort), PortEndpoint(aPort))]);

    expect(linkCountForDevice(doc, a), 3);
  });

  test('a link between two OTHER devices is not counted', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final b = _device(doc, 'B');
    final c = _device(doc, 'C');
    _port(doc, a, 'J01');
    final bPort = _port(doc, b, 'J01');
    final cPort = _port(doc, c, 'J01');
    _link(doc, 'W001', [(PortEndpoint(bPort), PortEndpoint(cPort))]);

    expect(linkCountForDevice(doc, a), 0);
  });

  test('unbound endpoints resolve to no device and are never counted '
      '(AC-018/B1)', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final aPort = _port(doc, a, 'J01');
    // A home run pulled to a place, and a coil left open — both are real,
    // schedulable link ends that belong to no device.
    _link(doc, 'W001', [
      (
        PortEndpoint(aPort),
        const PlaceEndpoint(description: 'projector shelf, beam 3'),
      ),
    ]);
    _link(doc, 'W002', [
      (
        const OpenEndpoint('coil in the J-hook'),
        const PlaceEndpoint(description: 'ceiling'),
      ),
    ]);

    expect(
      linkCountForDevice(doc, a),
      1,
      reason: 'W001 lands on A at one end; W002 lands on nothing at all',
    );
  });

  test('a link referencing a port id that is not materialised counts '
      'nothing rather than throwing', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    _port(doc, a, 'J01');
    _link(doc, 'W001', [
      (
        const PortEndpoint(Uuid('port-that-was-never-materialised')),
        const OpenEndpoint('x'),
      ),
    ]);

    expect(linkCountForDevice(doc, a), 0);
  });

  test('an unknown device id counts zero rather than throwing', () {
    expect(linkCountForDevice(_doc(), const Uuid('nope')), 0);
  });

  test('reading link counts never mutates the document', () {
    final doc = _doc();
    final a = _device(doc, 'A');
    final aPort = _port(doc, a, 'J01');
    _link(doc, 'W001', [(PortEndpoint(aPort), const OpenEndpoint('x'))]);
    final portCount = doc.ports.length;
    final linkCount = doc.links.length;

    linkCountForDevice(doc, a);

    expect(doc.ports, hasLength(portCount));
    expect(doc.links, hasLength(linkCount));
    expect(doc.links.values.single.conductors, hasLength(1));
  });
}
