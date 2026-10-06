// DR-236 §11.235.2 (BRK-A/2, `#1005`): a set's conductors appended to an
// existing cable.
//
// THE CASE THIS FILE EXISTS FOR is `append then undo is byte-identical`.
// The command creates the ports the second speaker's pins need and adds
// conductors to a cable that already has some; a revert that left one port
// or one conductor behind would be a cable that is not the one the person
// had, saved to disk (CR-117).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rack = Uuid('rack-a');
const _amp = Uuid('amp');
const _spk1 = Uuid('spk-1');
const _spk2 = Uuid('spk-2');
const _w001 = Uuid('w001');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _pin(
  String key,
  String set,
  String role,
  PortDirection dir,
  int i, {
  String family = 'audio.speaker_lowz',
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.screw_terminal'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _pos,
  order: FracIndex('a${i.toString().padLeft(2, '0')}'),
  direction: dir,
  setKey: set,
  setRole: role,
);

TemplateBody _body(String model, List<String> sets, List<PortDef> ports) =>
    TemplateBody(
      manufacturer: 'Test',
      model: model,
      displayName: model,
      frontU: 1,
      side: OccupancySide.front,
      portSets: [
        for (final s in sets)
          PortSetDef(key: s, label: '$s pair', kind: SetKind.speakerPair),
      ],
      ports: ports,
    );

void _place(
  RackDocument doc,
  Uuid id,
  TemplateBody body, {
  bool materialise = true,
}) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    body: body,
    capturedAt: _when,
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: id.v.toUpperCase(),
    name: id.v,
    placement: const RailPlacement(rackId: _rack, ruIndex: 1, face: Face.front),
    meta: _meta(),
  );
  if (!materialise) return;
  for (final p in body.ports) {
    final pid = derivePortId(id, p.key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: '${id.v.toUpperCase()}-${p.key.v}',
      templatePortKey: p.key,
    );
  }
}

Endpoint _at(Uuid device, String key) =>
    PortEndpoint(derivePortId(device, PortKey(key)));

/// The amplifier, SPK-1 and SPK-2 (whose ports nobody has created yet),
/// and W001 from zone 1 to SPK-1. [zone2Family] is zone 2's family.
RackDocument _doc({String zone2Family = 'audio.speaker_lowz'}) {
  final doc = RackDocument(
    id: const Uuid('doc-append'),
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
    heightU: 24,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  _place(
    doc,
    _amp,
    _body(
      'amp',
      ['z1', 'z2'],
      [
        _pin('z1.p', 'z1', '+', PortDirection.source, 0),
        _pin('z1.n', 'z1', '-', PortDirection.source, 1),
        _pin('z2.p', 'z2', '+', PortDirection.source, 2, family: zone2Family),
        _pin('z2.n', 'z2', '-', PortDirection.source, 3, family: zone2Family),
      ],
    ),
  );
  TemplateBody speaker(String family) => _body(
    'spk',
    ['in'],
    [
      _pin('in.p', 'in', '+', PortDirection.sink, 0, family: family),
      _pin('in.n', 'in', '-', PortDirection.sink, 1, family: family),
    ],
  );
  _place(doc, _spk1, speaker('audio.speaker_lowz'));
  _place(doc, _spk2, speaker(zone2Family), materialise: false);
  doc.links[_w001] = Link(
    id: _w001,
    designator: 'W001',
    media: const MediaTypeId('media.speaker_16_4'),
    order: const FracIndex('a0'),
    meta: _meta(),
    services: [
      Service(
        id: 'svc-1',
        signalFamily: const SignalFamilyId('audio.speaker_lowz'),
        netId: const Uuid('net-1'),
      ),
    ],
    conductors: [
      Conductor(from: _at(_amp, 'z1.p'), to: _at(_spk1, 'in.p'), role: '+'),
      Conductor(from: _at(_amp, 'z1.n'), to: _at(_spk1, 'in.n'), role: '-'),
    ],
  );
  return doc;
}

AppendSetResult _plan(
  RackDocument doc, {
  Uuid from = _amp,
  String fromSet = 'z2',
  Uuid to = _spk2,
  String toSet = 'in',
}) => planAppendSetToLink(
  doc,
  linkId: _w001,
  fromDeviceId: from,
  fromSetKey: fromSet,
  toDeviceId: to,
  toSetKey: toSet,
);

List<int> _bytes(RackDocument doc) => const JsonDocumentCodec().write(doc);

void main() {
  test('zone 2 to SPK-2 CONTINUES W001: four conductors, one cable', () {
    final doc = _doc();
    final ready = _plan(doc) as AppendSetReady;
    expect(ready.plan.pairs, hasLength(2), reason: 'what tier 2 is asked');
    expect(ready.command.apply(doc), isTrue);
    expect(doc.links, hasLength(1), reason: 'no new cable');
    final link = doc.links[_w001]!;
    expect(link.conductors, hasLength(4));
    expect(
      (link.conductors.last.to as PortEndpoint).portId,
      derivePortId(_spk2, const PortKey('in.n')),
    );
    expect(
      doc.ports.containsKey(derivePortId(_spk2, const PortKey('in.p'))),
      isTrue,
      reason: "SPK-2's pins are created to land on",
    );
  });

  test('APPEND THEN UNDO IS BYTE-IDENTICAL (CR-117), ports and all', () {
    final doc = _doc();
    final before = _bytes(doc);
    final command = (_plan(doc) as AppendSetReady).command..apply(doc);
    expect(_bytes(doc), isNot(before));
    command.revert(doc);
    expect(_bytes(doc), before);
  });

  test('a set on a device the cable does NOT reach cannot continue it', () {
    final refused = _plan(
      _doc(),
      from: _spk2,
      fromSet: 'in',
      to: _amp,
      toSet: 'z2',
    );
    expect(refused, isA<AppendSetRefused>());
    expect((refused as AppendSetRefused).message, contains('does not reach'));
  });

  test("A SET OF ANOTHER FAMILY IS ITS OWN CABLE (the implementer's "
      'default)', () {
    final refused = _plan(_doc(zone2Family: 'audio.line_bal'));
    expect(refused, isA<AppendSetRefused>());
    expect(
      (refused as AppendSetRefused).message,
      contains('carries audio.speaker_lowz'),
    );
  });

  test('TIER 1 REFUSES AS FOR ANY SET: SPK-1 is already full', () {
    final refused = _plan(_doc(), to: _spk1);
    expect(refused, isA<AppendSetRefused>());
    expect((refused as AppendSetRefused).ruleId, startsWith('TOP-'));
  });

  test('a home run is one conductor by shape and is not continued', () {
    final doc = _doc();
    doc.links[_w001]!.structureOrigin = StructureOrigin(
      structureBodyId: const Uuid('sb-1'),
      outletId: const Uuid('ol-1'),
      fieldLabel: 'LR-01',
    );
    final refused = _plan(doc);
    expect(refused, isA<AppendSetRefused>());
    expect((refused as AppendSetRefused).message, contains('home run'));
  });

  test('a refused plan writes nothing', () {
    final doc = _doc();
    final before = _bytes(doc);
    _plan(doc, to: _spk1);
    expect(_bytes(doc), before);
  });
}
