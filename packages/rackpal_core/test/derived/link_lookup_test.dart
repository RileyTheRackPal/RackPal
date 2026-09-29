// #96 — which cables land on one jack, and which `Net` may go with a link.
//
// The two questions a cable delete has to answer before it can run, and
// neither of them existed. Four claims:
//
//   1. `linksOnPort` answers from the CONDUCTORS, so it is right on a pin
//      the net-label layer never draws — the `R` of an atomic stereo pair;
//   2. a link touching one jack twice is still ONE cable;
//   3. `netToRemoveWith` asks the SURVIVORS, exactly as `planDeviceRemoval`
//      does, so a shared net is not taken out from under a living link;
//   4. `RemoveLinkCommand` with a null `netId` removes the link ALONE, and
//      its revert is still lossless.

import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 2);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _src = Uuid('dev-src');
const _sink = Uuid('dev-sink');

/// A stereo pair, so the `R`-with-no-pennant case is reachable.
///
/// `atomicConnect` takes `PortSetDef`'s default of true — the same default
/// all 17 seed sets take — which is what makes ONE connect gesture land a
/// conductor on both members.
PortDef _port(String key, {required String order, String? setKey}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.rca'),
  signalFamily: const SignalFamilyId('audio.line_unbal'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  bankKey: 'io',
  setKey: setKey,
);

TemplateBody _body(String model) => TemplateBody(
  manufacturer: 'Demo',
  model: model,
  displayName: model,
  banks: [
    BankDef(key: 'io', label: 'IO', abbr: 'IO', order: const FracIndex('a0')),
  ],
  portSets: [
    PortSetDef(key: 'st', label: 'Stereo pair', kind: SetKind.stereoPair),
  ],
  ports: [
    _port('l', order: 'a0001', setKey: 'st'),
    _port('r', order: 'a0002', setKey: 'st'),
    _port('spare', order: 'a0003'),
  ],
);

void _addDevice(RackDocument doc, Uuid id, String designator) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: _body(designator),
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// Two devices joined by ONE atomic stereo cable — one `Link`, two
/// `Conductor`s, four pins.
({RackDocument doc, DocumentController controller, Uuid linkId}) _fixture() {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: '96-B'),
    registries: buildSeedRegistries(),
  );
  _addDevice(doc, _src, 'SRC-1');
  _addDevice(doc, _sink, 'SNK-1');
  final controller = DocumentController(doc, clock: FixedClock(_when));

  final planned = planAtomicConnect(
    doc,
    fromDeviceId: _src,
    fromSetKey: 'st',
    toDeviceId: _sink,
    toSetKey: 'st',
  );
  final command = buildAtomicConnectCommand(
    doc: doc,
    plan: (planned! as AtomicConnectReady).plan,
    signalFamily: const SignalFamilyId('audio.line_unbal'),
    media: const MediaTypeId('media.rca'),
    now: _when,
    actor: 'test',
  );
  controller.run(command);
  return (doc: doc, controller: controller, linkId: command.id);
}

Uuid _pin(Uuid device, String key) => derivePortId(device, PortKey(key));

void main() {
  group('the fixture is one cable across two pins per end', () {
    test('one Link, two Conductors, four materialised Ports', () {
      final f = _fixture();
      expect(f.doc.links, hasLength(1));
      expect(f.doc.links[f.linkId]!.conductors, hasLength(2));
      expect(f.doc.ports, hasLength(4));
    });
  });

  group('linksOnPort reads conductors, not what was drawn', () {
    test('finds the cable on the FIRST conductor pin', () {
      final f = _fixture();
      expect(linksOnPort(f.doc, _pin(_src, 'l')), <Uuid>[f.linkId]);
    });

    test('finds the same cable on R, which no pennant is drawn for', () {
      // THE WHOLE REASON THIS FUNCTION EXISTS. `net_label_layer.dart`
      // labels `conductors.first` and nothing else, so a scene lookup
      // reports this pin free. It carries a conductor.
      final f = _fixture();
      expect(linksOnPort(f.doc, _pin(_src, 'r')), <Uuid>[f.linkId]);
      expect(portConductorCount(f.doc, _pin(_src, 'r')), 1);
    });

    test('a pin with no cable, and one the document never materialised, '
        'both answer empty', () {
      final f = _fixture();
      expect(linksOnPort(f.doc, _pin(_src, 'spare')), isEmpty);
      expect(f.doc.ports.containsKey(_pin(_src, 'spare')), isFalse);
    });

    test('a link touching one jack twice is reported once', () {
      // A loopback is unreachable through a command (TOP-001 refuses it)
      // and reachable from a hand-edited file, which is exactly the corpus
      // `portConductorCount` says it must not under-count. It counts ENDS
      // and answers 2; this counts CABLES and must answer 1.
      final f = _fixture();
      final port = _pin(_src, 'spare');
      f.doc.ports[port] = Port(
        id: port,
        deviceId: _src,
        designator: 'J09',
        templatePortKey: const PortKey('spare'),
      );
      const loop = Uuid('link-loop');
      f.doc.links[loop] = Link(
        id: loop,
        designator: 'W099',
        media: const MediaTypeId('media.rca'),
        order: const FracIndex('a9999'),
        meta: _meta(),
        conductors: [
          Conductor(from: PortEndpoint(port), to: PortEndpoint(port)),
        ],
        services: const [],
      );
      expect(portConductorCount(f.doc, port), 2);
      expect(linksOnPort(f.doc, port), <Uuid>[loop]);
    });
  });

  group('netToRemoveWith asks the survivors', () {
    test('an exclusively-referenced net may go', () {
      final f = _fixture();
      final net = f.doc.links[f.linkId]!.services.first.netId;
      expect(net, isNotNull);
      expect(netToRemoveWith(f.doc, f.linkId), net);
    });

    test('a net a second link still names may NOT', () {
      final f = _fixture();
      final net = f.doc.links[f.linkId]!.services.first.netId!;
      const other = Uuid('link-other');
      f.doc.links[other] = Link(
        id: other,
        designator: 'W098',
        media: const MediaTypeId('media.rca'),
        order: const FracIndex('a9998'),
        meta: _meta(),
        conductors: [
          Conductor(
            from: PortEndpoint(_pin(_src, 'l')),
            to: const OpenEndpoint('field'),
          ),
        ],
        services: [
          Service(
            id: 'svc-x',
            signalFamily: const SignalFamilyId('audio.line_unbal'),
            netId: net,
          ),
        ],
      );
      expect(netToRemoveWith(f.doc, f.linkId), isNull);
    });

    test('a link with no service, and a link that is not there, both give '
        'null', () {
      final f = _fixture();
      const bare = Uuid('link-bare');
      f.doc.links[bare] = Link(
        id: bare,
        designator: 'W097',
        media: const MediaTypeId('media.rca'),
        order: const FracIndex('a9997'),
        meta: _meta(),
        conductors: [
          Conductor(
            from: PortEndpoint(_pin(_src, 'l')),
            to: const OpenEndpoint('field'),
          ),
        ],
        services: const [],
      );
      expect(netToRemoveWith(f.doc, bare), isNull);
      expect(netToRemoveWith(f.doc, const Uuid('nope')), isNull);
    });
  });

  group('RemoveLinkCommand honours a null netId', () {
    test('removes the link and LEAVES the net', () {
      final f = _fixture();
      final net = f.doc.links[f.linkId]!.services.first.netId!;
      f.controller.run(RemoveLinkCommand(id: f.linkId, netId: null));
      expect(f.doc.links, isEmpty);
      expect(f.doc.nets.containsKey(net), isTrue);
    });

    test('and undo restores the link without duplicating the net', () {
      final f = _fixture();
      final net = f.doc.links[f.linkId]!.services.first.netId!;
      final nets = f.doc.nets.length;
      f.controller.run(RemoveLinkCommand(id: f.linkId, netId: null));
      f.controller.undo.undo(f.doc);
      expect(f.doc.links.containsKey(f.linkId), isTrue);
      expect(f.doc.nets, hasLength(nets));
      expect(f.doc.nets.containsKey(net), isTrue);
    });

    test('affects omits the net it was told not to touch', () {
      final f = _fixture();
      final command = RemoveLinkCommand(id: f.linkId, netId: null);
      expect(command.affects, <Uuid>[f.linkId]);
    });

    test('delete then undo is byte-identical, net taken or not', () {
      // APPLIED AND REVERTED DIRECTLY, not through the controller, which
      // advances `doc.sequence` — envelope bookkeeping that is SUPPOSED to
      // move. This is how `command_roundtrip_test` states the same
      // property. Both arms, because the null case restores one fewer
      // object and a lossless revert has to be lossless either way.
      const codec = JsonDocumentCodec();
      for (final takeNet in <bool>[true, false]) {
        final f = _fixture();
        final before = utf8.decode(codec.write(f.doc));
        final command = RemoveLinkCommand(
          id: f.linkId,
          netId: takeNet ? netToRemoveWith(f.doc, f.linkId) : null,
        );
        // The mid-point assertion is what stops this passing vacuously: a
        // command that did nothing at all would revert to `before` too.
        final applied = command..apply(f.doc);
        expect(utf8.decode(codec.write(f.doc)), isNot(before));
        applied.revert(f.doc);
        expect(
          utf8.decode(codec.write(f.doc)),
          before,
          reason: 'takeNet=$takeNet',
        );
      }
    });
  });
}
