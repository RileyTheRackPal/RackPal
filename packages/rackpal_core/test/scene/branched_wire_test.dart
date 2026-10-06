// DR-236 §11.235.5 (BRK-A/5, `#1008`): a drawn wire for a cable that reaches
// three devices is a trunk and a branch, the user's choice.
//
// THE CASE THIS FILE EXISTS FOR is `the branch's pill is SPK-2's ink`. The
// pill loop read `ends[i]` beside `pillAt[i]`, which matched while a cable
// had two ends. A branch's pill belongs to a LATER end, and `ends[2]` is the
// amplifier's zone 2 pair: read that way, SPK-2's pill would have been
// counted as the amplifier's ink, and DR-232 places a device by its own.
//
// Rendered through pdfium and looked at on the real A04 and two F05s before
// this file was written: the trunk to SPK-1, the dot, the branch to SPK-2
// with its pill, and the amplifier's second pair joined into the trunk.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'schematic_test_document.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _amp = Uuid('amp');
const _spk1 = Uuid('spk-1');
const _spk2 = Uuid('spk-2');
const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _pin(String key, String set, String role, PortDirection dir, int i) =>
    PortDef(
      key: PortKey(key),
      label: key.toUpperCase(),
      connector: const ConnectorTypeId('conn.screw_terminal'),
      signalFamily: const SignalFamilyId('audio.speaker_lowz'),
      face: Face.rear,
      position: _pos,
      order: FracIndex('a${i.toString().padLeft(2, '0')}'),
      direction: dir,
      setKey: set,
      setRole: role,
    );

void _place(RackDocument doc, Uuid id, List<String> sets, List<PortDef> ps) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    body: TemplateBody(
      manufacturer: 'Test',
      model: id.v,
      displayName: id.v,
      frontU: 1,
      side: OccupancySide.front,
      portSets: [
        for (final s in sets)
          PortSetDef(key: s, label: s, kind: SetKind.speakerPair),
      ],
      ports: ps,
    ),
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
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  for (final p in ps) {
    final pid = derivePortId(id, p.key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: p.key.v.toUpperCase(),
      templatePortKey: p.key,
    );
  }
}

Endpoint _at(Uuid device, String key) =>
    PortEndpoint(derivePortId(device, PortKey(key)));

const _w = Uuid('w012');

/// The amplifier, two speakers, and W012: zone 1 to SPK-1 and, when
/// [continued], zone 2 to SPK-2.
RackDocument _doc({bool continued = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-branch'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  _place(
    doc,
    _amp,
    ['z1', 'z2'],
    [
      _pin('z1.p', 'z1', '+', PortDirection.source, 0),
      _pin('z1.n', 'z1', '-', PortDirection.source, 1),
      _pin('z2.p', 'z2', '+', PortDirection.source, 2),
      _pin('z2.n', 'z2', '-', PortDirection.source, 3),
    ],
  );
  for (final s in [_spk1, _spk2]) {
    _place(
      doc,
      s,
      ['in'],
      [
        _pin('in.p', 'in', '+', PortDirection.sink, 0),
        _pin('in.n', 'in', '-', PortDirection.sink, 1),
      ],
    );
  }
  doc.links[_w] = Link(
    id: _w,
    designator: 'W012',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    conductors: [
      Conductor(from: _at(_amp, 'z1.p'), to: _at(_spk1, 'in.p'), role: '+'),
      Conductor(from: _at(_amp, 'z1.n'), to: _at(_spk1, 'in.n'), role: '-'),
      if (continued) ...[
        Conductor(from: _at(_amp, 'z2.p'), to: _at(_spk2, 'in.p'), role: '+'),
        Conductor(from: _at(_amp, 'z2.n'), to: _at(_spk2, 'in.n'), role: '-'),
      ],
    ],
  );
  return doc;
}

DrawnWireLayer _layer(RackDocument doc) => buildDrawnWireLayer(
  scene: buildFixtureScene(doc),
  doc: doc,
  linkIds: {_w},
  measurer: const FakeMeasurer(),
  palette: const SchematicPalette(),
);

void main() {
  test(
    'THE CONTROL: a cable between two devices is one trace, no junction',
    () {
      final layer = _layer(_doc(continued: false));
      expect(layer.wires.single.junctions, isEmpty);
      expect(layer.ops.whereType<OpPolyline>(), hasLength(1));
      expect(layer.ops.whereType<OpCircle>(), isEmpty);
    },
  );

  test('THE 16/4 IS A TRUNK, A JOINER AND A BRANCH, with one junction dot '
      'and a pill at every end', () {
    final layer = _layer(_doc());
    final wire = layer.wires.single;
    expect(layer.ops.whereType<OpPolyline>(), hasLength(3));
    expect(wire.junctions, hasLength(1));
    expect(wire.ends, hasLength(3), reason: 'amp, SPK-1 and SPK-2');
    final dot = layer.ops.whereType<OpCircle>().single;
    expect(dot.center, wire.junctions.single);
    expect(dot.fill?.argb, wire.style.argb);
  });

  test("THE BRANCH'S PILL IS SPK-2's INK, not the amplifier's", () {
    final layer = _layer(_doc());
    final spk2 = layer.endInk[_spk2.v];
    expect(spk2, isNotNull, reason: 'SPK-2 draws an end of its own');
    expect(
      spk2!.contains(layer.wires.single.ends.last),
      isTrue,
      reason: "its pill's anchor is in its own ink",
    );
  });

  test('AN ADAPTER AND A JUNCTION NEVER SHARE A POINT', () {
    final doc = _doc();
    doc.links[_w]!.inlineAdapters.add(
      InlineAdapter(
        fromConnector: const ConnectorTypeId('conn.screw_terminal'),
        toConnector: const ConnectorTypeId('conn.screw_terminal'),
      ),
    );
    final layer = _layer(doc);
    final bowtie = layer.ops.whereType<OpPath>().singleWhere(
      (op) => op.p.commands.length == 7,
    );
    final tip = bowtie.p.commands[1] as LineTo;
    expect(DPt(tip.x, tip.y), isNot(layer.wires.single.junctions.single));
  });

  group('T0.01 (DR-208 §11.207.1)', () {
    List<String> texts(LegendBlock b) =>
        b.ops.whereType<OpText>().map((t) => t.text).toList();

    test('no branch printed, no dot row', () {
      final block = conventionsBlock(statuses: const [], hatchedPassive: false);
      expect(texts(block), isNot(contains(kLegendJunctionMeaning)));
    });

    test('a printed branch: the dot and its meaning', () {
      final signal = _layer(_doc()).wires.single.style;
      final block = conventionsBlock(
        statuses: const [],
        hatchedPassive: false,
        junction: signal,
      );
      expect(texts(block), contains(kLegendJunctionMeaning));
      expect(block.ops.whereType<OpCircle>(), hasLength(1));
    });
  });
}
