// DR-236 §11.235.4 (BRK-A/1, `#1004`): every reader of a cable's ends reads
// every conductor, not the first.
//
// THE CABLE THIS FILE EXISTS FOR is the 16/4 tapped and continued: one
// cable, an amplifier's zone 1 pair to SPK-1 and its zone 2 pair to SPK-2.
// CR-014 has always allowed it; six readers took the first conductor as the
// whole cable, on the ground that CR-014 said otherwise. Built here in the
// model directly, because no gesture writes one until BRK-A/3.
//
// AND THE CONTROL IS AS IMPORTANT: an ordinary set cable must read exactly
// as it did. Every group asserts both.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'schematic_test_document.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rackA = Uuid('rack-a');
const _rackB = Uuid('rack-b');
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

TemplateBody _ampBody() => TemplateBody(
  manufacturer: 'Test',
  model: 'amp',
  displayName: 'amp',
  frontU: 1,
  side: OccupancySide.front,
  portSets: [
    PortSetDef(key: 'z1', label: 'Zone 1', kind: SetKind.speakerPair),
    PortSetDef(key: 'z2', label: 'Zone 2', kind: SetKind.speakerPair),
  ],
  ports: [
    _pin('z1.p', 'z1', '+', PortDirection.source, 0),
    _pin('z1.n', 'z1', '-', PortDirection.source, 1),
    _pin('z2.p', 'z2', '+', PortDirection.source, 2),
    _pin('z2.n', 'z2', '-', PortDirection.source, 3),
  ],
);

TemplateBody _speakerBody() => TemplateBody(
  manufacturer: 'Test',
  model: 'spk',
  displayName: 'spk',
  frontU: 1,
  side: OccupancySide.front,
  portSets: [PortSetDef(key: 'in', label: 'In', kind: SetKind.speakerPair)],
  ports: [
    _pin('in.p', 'in', '+', PortDirection.sink, 0),
    _pin('in.n', 'in', '-', PortDirection.sink, 1),
  ],
);

void _place(
  RackDocument doc,
  Uuid id,
  String tpl,
  TemplateBody body,
  Uuid rack,
) {
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
    placement: RailPlacement(rackId: rack, ruIndex: 1, face: Face.front),
    meta: _meta(),
  );
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

/// The amplifier and both speakers; SPK-2 in [spk2Rack].
RackDocument _doc({Uuid spk2Rack = _rackA}) {
  final doc = RackDocument(
    id: const Uuid('doc-brk'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  for (final (i, rack) in [_rackA, _rackB].indexed) {
    doc.racks[rack] = Rack(
      id: rack,
      name: rack.v,
      designator: 'RK-${i + 1}',
      heightU: 24,
      order: FracIndex('a$i'),
      meta: _meta(),
    );
  }
  _place(doc, _amp, 'tpl.amp', _ampBody(), _rackA);
  _place(doc, _spk1, 'tpl.spk1', _speakerBody(), _rackA);
  _place(doc, _spk2, 'tpl.spk2', _speakerBody(), spk2Rack);
  return doc;
}

/// THE 16/4: zone 1 to SPK-1 and zone 2 to SPK-2, one cable.
Link _tapAndContinue() => Link(
  id: const Uuid('w012'),
  designator: 'W012',
  media: const MediaTypeId('media.cat6_utp'),
  order: const FracIndex('a0'),
  meta: _meta(),
  conductors: [
    Conductor(from: _at(_amp, 'z1.p'), to: _at(_spk1, 'in.p'), role: '+'),
    Conductor(from: _at(_amp, 'z1.n'), to: _at(_spk1, 'in.n'), role: '-'),
    Conductor(from: _at(_amp, 'z2.p'), to: _at(_spk2, 'in.p'), role: '+'),
    Conductor(from: _at(_amp, 'z2.n'), to: _at(_spk2, 'in.n'), role: '-'),
  ],
);

/// THE CONTROL: an ordinary set cable, zone 1 to SPK-1.
Link _ordinary() => Link(
  id: const Uuid('w001'),
  designator: 'W001',
  media: const MediaTypeId('media.cat6_utp'),
  order: const FracIndex('a0'),
  meta: _meta(),
  conductors: [
    Conductor(from: _at(_amp, 'z1.p'), to: _at(_spk1, 'in.p'), role: '+'),
    Conductor(from: _at(_amp, 'z1.n'), to: _at(_spk1, 'in.n'), role: '-'),
  ],
);

void main() {
  group('the classifier', () {
    test(
      'THE SECOND SPEAKER IN ANOTHER RACK MAKES IT A PULL, not a jumper',
      () {
        // Read off its first conductor this cable was amp-to-SPK-1, both in
        // RK-1, and dropped off the Pull Sheet as a jumper.
        final doc = _doc(spk2Rack: _rackB);
        expect(linkClassOf(doc, _tapAndContinue()), LinkClass.fieldCable);
      },
    );

    test('every end in one rack is still a jumper', () {
      expect(linkClassOf(_doc(), _tapAndContinue()), LinkClass.jumper);
    });

    test('A SET WHOSE FIRST POSITION IS OPEN classifies by the ends it '
        'landed', () {
      // Connect-what-fits (§11.8.3) left position 0 open. That coil runs
      // inside the same cable between the same two devices; it used to vote
      // the class to fieldCable because it happened to be first.
      final link = _ordinary()
        ..conductors[0] = Conductor(
          from: _at(_amp, 'z1.p'),
          to: const OpenEndpoint('no partner'),
          role: '+',
        );
      expect(linkClassOf(_doc(), link), LinkClass.jumper);
    });

    test('ONE CONDUCTOR FROM A RACK DEVICE TO NOWHERE is a field cable, as it '
        'always was', () {
      final link = Link(
        id: const Uuid('w9'),
        designator: 'W009',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        meta: _meta(),
        conductors: [
          Conductor(from: _at(_amp, 'z1.p'), to: const OpenEndpoint('coil')),
        ],
      );
      expect(linkClassOf(_doc(), link), LinkClass.fieldCable);
    });
  });

  group('the net labels', () {
    List<RenderedNetLabel> labelsOf(Link link) {
      final doc = _doc()..links[link.id] = link;
      return buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
      ).netLabels.where((l) => l.linkId == link.id).toList();
    }

    test('THE CONTROL: an ordinary set cable is two pennants, as before', () {
      expect(labelsOf(_ordinary()), hasLength(2));
    });

    test('THE 16/4 IS FOUR PENNANTS, ONE NAME: each zone pair at the '
        'amplifier, and each speaker', () {
      final labels = labelsOf(_tapAndContinue());
      expect(labels, hasLength(4));
      expect(labels.map((l) => l.netName).toSet(), hasLength(1));
    });
  });

  group('the layout', () {
    test('SPK-2 IS LAID OUT DOWNSTREAM of the amplifier that feeds it', () {
      // With an edge only for the first conductor SPK-2 had no edge at all
      // and sat in the amplifier's own layer, unconnected to its feed.
      final doc = _doc()..links[_tapAndContinue().id] = _tapAndContinue();
      final layers = buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
      ).layout.layers;
      int layerOf(Uuid id) => layers.indexWhere((l) => l.contains(id.v));
      expect(layerOf(_spk2), greaterThan(layerOf(_amp)));
      expect(layerOf(_spk1), greaterThan(layerOf(_amp)));
    });
  });
}
