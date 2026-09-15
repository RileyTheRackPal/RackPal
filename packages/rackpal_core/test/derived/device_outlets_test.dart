// DR-171 (canon §11.170): outlet counts are read off ports and cords.
//
// THE ARTIFACT IS THE COUNT A RACK WOULD SHOW, per device, for each of
// §11.170.4's clauses, and the shipped catalogue measured against the
// census DR-171 was ruled on. Every case builds a real document and asks
// `PortLandings.of` for its cords, because a resolution fed a hand-built
// landing set would prove the arithmetic and not the reading of the graph.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 9, 14);

EntityMeta _meta() =>
    EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test');

PortDef _power(String key, PortPowerRole role, int order) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.nema_5_15p'),
  signalFamily: const SignalFamilyId('power.ac_branch'),
  face: Face.rear,
  order: FracIndex('a${order.toString().padLeft(3, '0')}'),
  power: PortPowerSpec(role: role),
);

PortDef _poePd() => PortDef(
  key: const PortKey('lan.poe'),
  label: 'PoE',
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: const FracIndex('z000'),
  poe: PoeSpec(role: PoeRole.pd),
);

PortDef _plain(String key, String family) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  order: const FracIndex('m000'),
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Test',
  model: 'dev',
  displayName: 'dev',
  frontU: 1,
  side: OccupancySide.front,
  ports: ports,
);

/// A document holding one device of [body], with one cord from each of
/// [wired] (template port keys on that device) to an open end.
({RackDocument doc, DeviceInstance device}) _placed(
  TemplateBody body, {
  List<String> wired = const [],
}) {
  final doc = RackDocument(
    id: const Uuid('doc-outlets'),
    appVersion: 'test',
    createdAt: _at,
    modifiedAt: _at,
    meta: _meta(),
    info: ProjectInfo(projectName: 'outlets'),
    registries: buildSeedRegistries(),
  );
  doc.templates['dev@1'] = TemplateSnapshot(
    templateId: const TemplateId('dev'),
    version: 1,
    contentHash: 'unhashed:dev@1',
    body: body,
    capturedAt: _at,
  );
  final device = DeviceInstance(
    id: const Uuid('dev-1'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('dev'),
      version: 1,
      contentHash: 'unhashed:dev@1',
    ),
    designator: 'DEV-1',
    name: 'dev',
    placement: const StagedPlacement(),
    meta: _meta(),
  );
  doc.devices[device.id] = device;
  var n = 0;
  for (final key in wired) {
    n++;
    final port = Port(
      id: Uuid('port-$n'),
      deviceId: device.id,
      designator: key,
      templatePortKey: PortKey(key),
    );
    doc.ports[port.id] = port;
    final linkId = Uuid('link-$n');
    doc.links[linkId] = Link(
      id: linkId,
      designator: 'W00$n',
      media: const MediaTypeId('media.cat6_utp'),
      order: FracIndex('a$n'),
      meta: _meta(),
      conductors: [
        Conductor(from: PortEndpoint(port.id), to: const OpenEndpoint('coil')),
      ],
    );
  }
  return (doc: doc, device: device);
}

DeviceOutlets _resolve(TemplateBody body, {List<String> wired = const []}) {
  final placed = _placed(body, wired: wired);
  return resolveDeviceOutlets(
    placed.device,
    bodyFor(placed.device, placed.doc.templates),
    PortLandings.of(placed.doc),
  );
}

void main() {
  group('provided is capacity: outlet ports, whatever is plugged in', () {
    test('a PDU provides one outlet per outlet port', () {
      final body = _body([
        _power('ac.in', PortPowerRole.inlet, 0),
        for (var i = 1; i <= 8; i++) _power('out.$i', PortPowerRole.outlet, i),
      ]);
      expect(_resolve(body).provided, 8);
    });

    test('and cords landing on its outlets do not change it', () {
      final body = _body([
        for (var i = 1; i <= 8; i++) _power('out.$i', PortPowerRole.outlet, i),
      ]);
      expect(_resolve(body, wired: ['out.1', 'out.2']).provided, 8);
    });

    test('a power port with no role is neither an outlet nor an inlet', () {
      // `P01`'s ground and `F18`'s bonding lug are the shipped shape.
      final outlets = _resolve(_body([_plain('ground', 'power.bonding')]));
      expect(outlets.provided, 0);
      expect(outlets.consumed, 0);
      expect(outlets.consumedFromPorts, isFalse);
    });
  });

  group('consumed, clause 3: nothing wired, so one per inlet, and it says '
      'so', () {
    test('an unwired amplifier is charged its one inlet', () {
      final outlets = _resolve(
        _body([_power('ac.in', PortPowerRole.inlet, 0)]),
      );
      expect(outlets.consumed, 1);
      expect(outlets.consumedFromPorts, isTrue);
    });

    test('a redundant-supply switch with nothing wired is charged two', () {
      final outlets = _resolve(
        _body([
          _power('psu.1', PortPowerRole.inlet, 0),
          _power('psu.2', PortPowerRole.inlet, 1),
        ]),
      );
      expect(outlets.consumed, 2);
      expect(outlets.consumedFromPorts, isTrue);
    });

    test('a device with ports and no inlet consumes a measured zero and '
        'assumes nothing', () {
      // `F13`, the bus-powered keypad: it draws watts and eats no outlet.
      final outlets = _resolve(_body([_plain('bus', 'ctl.cresnet')]));
      expect(outlets.consumed, 0);
      expect(outlets.consumedFromPorts, isFalse);
    });
  });

  group('consumed, clause 1: the cords drawn are the answer', () {
    test('one cord to one of two inlets counts one, not two', () {
      final outlets = _resolve(
        _body([
          _power('psu.1', PortPowerRole.inlet, 0),
          _power('psu.2', PortPowerRole.inlet, 1),
        ]),
        wired: ['psu.1'],
      );
      expect(outlets.consumed, 1, reason: 'the drawing says one cord');
      expect(outlets.consumedFromPorts, isFalse);
    });

    test('a cord wins over a PoE run on the same device', () {
      final outlets = _resolve(
        _body([_power('ac.in', PortPowerRole.inlet, 0), _poePd()]),
        wired: ['ac.in', 'lan.poe'],
      );
      expect(outlets.consumed, 1);
      expect(outlets.consumedFromPorts, isFalse);
    });
  });

  group('consumed, clause 2: powered over its data run', () {
    test('a PoE camera with its run drawn consumes nothing', () {
      final outlets = _resolve(
        _body([_power('dc.in', PortPowerRole.inlet, 0), _poePd()]),
        wired: ['lan.poe'],
      );
      expect(outlets.consumed, 0);
      expect(outlets.consumedFromPorts, isFalse);
    });

    test('and the same camera unwired is charged its barrel jack', () {
      // §11.170.2's own example the other way round: the jack is on the
      // chassis, and until a run says otherwise it will want an outlet.
      final outlets = _resolve(
        _body([_power('dc.in', PortPowerRole.inlet, 0), _poePd()]),
      );
      expect(outlets.consumed, 1);
      expect(outlets.consumedFromPorts, isTrue);
    });
  });

  group('unknown is what G4 says it is', () {
    test('a template that does not resolve knows nothing', () {
      final placed = _placed(_body([_power('ac.in', PortPowerRole.inlet, 0)]));
      final outlets = resolveDeviceOutlets(
        placed.device,
        null,
        PortLandings.of(placed.doc),
      );
      expect(outlets.provided, isNull);
      expect(outlets.consumed, isNull);
    });

    test('a template with no ports at all says nothing, and is not a '
        'measured zero', () {
      // AC-049 lets a template be saved before its ports are entered. An
      // empty list cannot tell a blank panel from an amplifier nobody has
      // described, and `outlets 0/0` with no superscript is the
      // fabrication `totals.dart` was rewritten to stop.
      final outlets = _resolve(_body(const []));
      expect(outlets.provided, isNull);
      expect(outlets.consumed, isNull);
      expect(outlets.consumedFromPorts, isFalse);
    });

    test('an end whose port is not in the document lands nowhere', () {
      final placed = _placed(
        _body([_power('ac.in', PortPowerRole.inlet, 0)]),
        wired: ['ac.in'],
      );
      placed.doc.ports.clear();
      final outlets = resolveDeviceOutlets(
        placed.device,
        bodyFor(placed.device, placed.doc.templates),
        PortLandings.of(placed.doc),
      );
      expect(outlets.consumed, 1);
      expect(
        outlets.consumedFromPorts,
        isTrue,
        reason: 'an unresolvable end is not evidence that a cord was drawn',
      );
    });
  });

  group('the shipped catalogue, against the census DR-171 was ruled on', () {
    final catalog = buildSeedCatalog();

    test('the four power templates provide what they stated', () {
      expect(outletPortCount(catalog['P01']!), 24);
      expect(outletPortCount(catalog['P02']!), 16);
      expect(outletPortCount(catalog['P03']!), 10);
      expect(outletPortCount(catalog['P04']!), 6);
    });

    test('the six that stated 0 against an inlet have that inlet to count', () {
      for (final id in ['F09', 'F11', 'F12', 'F16', 'V06', 'V07']) {
        expect(inletPortCount(catalog[id]!), 1, reason: id);
      }
    });

    test('the V06 receiver is fed down its HDBaseT run once it is drawn', () {
      // A ROLE VARIANT, not one of the 51 seed templates the census read.
      final rx = buildSeedRoleVariants()['V06:receiver']!;
      final pd = rx.ports.firstWhere((p) => p.poe?.role == PoeRole.pd);
      expect(_resolve(rx).consumed, 1, reason: 'undrawn, it wants its jack');
      expect(_resolve(rx, wired: [pd.key.v]).consumed, 0);
    });
  });
}
