// The connect-tier scenarios and their AC-051 pairs (M5-G2/G3).
//
// MOVED HERE FROM `connect_rules_test.dart`, unchanged in substance. The
// tables and their document builders lived beside the assertions that
// read them, which was right until the CATALOGUE needed a gate: `#302`
// requires that a registered rule without its pair fails the build, and
// the catalogue is the union of four evaluators' rules (CR-021). A gate
// whose subject is `ConnectRule.values` cannot see a catalogue row that
// no enum mentions.
//
// So the data moved and the assertions did not. `connect_rules_test.dart`
// still owns everything it asserted before and now reads its rows from
// here, and `drc_corpus.dart` reads the same rows for the catalogue gate.
// One corpus, two readers, no second copy to drift.
//
// The `connect` prefix on every symbol is not decoration: four tiers'
// scenario builders end up in one directory and `_port` means something
// different in each.

import 'package:rackpal_core/rackpal_core.dart';

final connectWhen = DateTime.utc(2026, 7, 29);
EntityMeta connectMeta() => EntityMeta(
  createdAt: connectWhen,
  updatedAt: connectWhen,
  updatedBy: 'test',
);

const connectPos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const connectAvr = Uuid('dev-avr');
const connectTv = Uuid('dev-tv');
const connectShelf = Uuid('dev-shelf');

PortDef connectPort(
  String key, {
  String? hint,
  String? label,
  int maxConnections = 1,
  String family = 'video.hdmi.2_1',
  String order = 'a0',
  PortDirection direction = PortDirection.bidirectional,
  PortTopology topology = PortTopology.p2p,
}) => PortDef(
  key: PortKey(key),
  label: label ?? key,
  designatorHint: hint,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: connectPos,
  order: FracIndex(order),
  maxConnections: maxConnections,
  direction: direction,
  topology: topology,
);

TemplateBody connectBody(List<PortDef> ports, {bool isContainer = false}) =>
    TemplateBody(
      manufacturer: 'Acme',
      model: 'T',
      displayName: 'T',
      isContainer: isContainer,
      ports: ports,
    );

/// Adds [id] with [body] under designator [designator], materialising
/// only the port keys in [materialise] — every other pin stays
/// unmaterialised, which is the normal state of a device dropped out of
/// the palette (AC-006, DR-011.1).
void connectAddDevice(
  RackDocument doc,
  Uuid id,
  String designator,
  TemplateBody body, {
  Placement placement = const OffRackPlacement(),
  Set<String> materialise = const {},
}) {
  final tplId = 'tpl.${id.v}';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: body,
    capturedAt: connectWhen,
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: designator,
    name: designator,
    placement: placement,
    meta: connectMeta(),
  );
  for (final key in materialise) {
    final pid = derivePortId(id, PortKey(key));
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: 'J${materialise.toList().indexOf(key) + 1}',
      templatePortKey: PortKey(key),
    );
  }
}

RackDocument connectDoc() => RackDocument(
  id: const Uuid('doc-cr'),
  appVersion: '0.1.0',
  createdAt: connectWhen,
  modifiedAt: connectWhen,
  meta: connectMeta(),
);

/// AVR-1 with one HDMI output, TV-1 with one HDMI input. Neither pin is
/// materialised — the state every real document is in.
///
/// NO `designatorHint` ANYWHERE. **Zero of the 727 seed-catalog ports
/// carry one** (`PortBuilder.p` never passes it), so a fixture that set
/// hints and then asserted on them would be testing a branch no shipped
/// device can reach. The `J`-numbers asserted below are the ones
/// `allocatePortDesignator` computes from the pin's template position,
/// which is what a refusal on a real document actually prints.
RackDocument connectPair({int avrMax = 1, int tvMax = 1}) {
  final doc = connectDoc();
  connectAddDevice(
    doc,
    connectAvr,
    'AVR-1',
    connectBody([connectPort('hdmi.out.1', maxConnections: avrMax)]),
  );
  connectAddDevice(
    doc,
    connectTv,
    'TV-1',
    connectBody([connectPort('hdmi.in.1', maxConnections: tvMax)]),
  );
  return doc;
}

ConnectTarget connectAvrOut(RackDocument doc) => resolveConnectTarget(
  doc,
  deviceId: connectAvr,
  portKey: 'hdmi.out.1',
)!;

ConnectTarget connectTvIn(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: connectTv, portKey: 'hdmi.in.1')!;

ConnectTarget connectPin(RackDocument doc, Uuid device, String key) =>
    resolveConnectTarget(doc, deviceId: device, portKey: key)!;

/// The seed catalog, built once — `buildSeedCatalog()` walks every
/// template on each call.
final Map<String, TemplateBody> connectSeed = buildSeedCatalog();

/// Adds a device whose template body is the REAL seed-catalog entry for
/// [catalogId] — no fixture `PortDef`s, so what is asserted is what
/// ships. Every pin stays unmaterialised, which is what placing from the
/// palette produces.
void connectSeedDevice(
  RackDocument doc,
  Uuid id,
  String catalogId,
  String designator,
) {
  final body = connectSeed[catalogId];
  if (body == null) throw StateError('seed catalog has no "$catalogId"');
  doc.templates[catalogTemplateKey(catalogId)] = TemplateSnapshot(
    templateId: TemplateId(catalogId),
    version: 1,
    contentHash: 'sha256:seed-$catalogId',
    body: body,
    capturedAt: connectWhen,
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(catalogId),
      version: 1,
      contentHash: 'sha256:seed-$catalogId',
    ),
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: connectMeta(),
  );
}

/// A `Link` carrying one conductor from [from] to [to], so a test can set
/// up an occupied port or an already-run ordered pair.
Uuid connectLink(
  RackDocument doc,
  String designator,
  Endpoint from,
  Endpoint to,
) {
  final id = Uuid('lnk-$designator');
  doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('media.hdmi'),
    order: const FracIndex('a0'),
    meta: connectMeta(),
    services: [
      Service(
        id: 'svc-1',
        signalFamily: const SignalFamilyId('video.hdmi.2_1'),
        netId: const Uuid('net-x'),
      ),
    ],
    conductors: [Conductor(from: from, to: to)],
  );
  return id;
}

/// One rule's worth of "this is how it refuses, and this is what the
/// sentence must say".
typedef ConnectRefusalCase = ({
  ConnectRule rule,
  String what,
  ConnectVerdict Function() run,
  List<String> mustName,
});

/// EVERY rule gets a row. The coverage assertion below compares this
/// list against `ConnectRule.values`.
List<ConnectRefusalCase> connectRefusals() => [
  (
    rule: ConnectRule.endpointResolves,
    what: 'the port has been tombstoned',
    mustName: ['AVR-1'],
    run: () {
      final doc = connectPair();
      final from = connectAvrOut(doc);
      doc.tombstones[from.portId] = Tombstone(
        deletedAt: connectWhen,
        entityType: 'Port',
        by: 'test',
      );
      return evaluateConnect(doc, from, connectTvIn(doc));
    },
  ),
  (
    rule: ConnectRule.hostResolves,
    what: 'the shelf the device sits on is not in the document',
    mustName: ['AVR-1'],
    run: () {
      final doc = connectPair();
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      doc.devices[connectAvr] = DeviceInstance(
        id: connectAvr,
        kind: DeviceKind.rackDevice,
        templateRef: doc.devices[connectAvr]!.templateRef,
        designator: 'AVR-1',
        name: 'AVR-1',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('dev-gone'),
          order: FracIndex('a0'),
        ),
        meta: connectMeta(),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
  (
    rule: ConnectRule.notSelf,
    what: 'both ends are the same pin',
    mustName: ['AVR-1', 'J01'],
    run: () {
      final doc = connectPair();
      final from = connectAvrOut(doc);
      return evaluateConnect(doc, from, connectAvrOut(doc));
    },
  ),
  (
    rule: ConnectRule.notDuplicatePair,
    what: 'the link already runs this exact ordered pair',
    mustName: ['AVR-1', 'TV-1', 'W001'],
    run: () {
      // maxConnections raised so TOP-003 cannot pre-empt the rule under
      // test — the existing conductor already occupies both pins.
      final doc = connectPair(avrMax: 4, tvMax: 4);
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      final id = connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      return evaluateConnect(doc, from, to, ontoLink: id);
    },
  ),
  (
    rule: ConnectRule.withinMaxConnections,
    what: 'the pin is already at its maxConnections',
    mustName: ['AVR-1', '1 of 1'],
    run: () {
      final doc = connectPair();
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        const OpenEndpoint('elsewhere'),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
];

/// One rule's worth of "and here is the case ONE PROPERTY away from that
/// refusal, which must be accepted".
typedef ConnectNearMissCase = ({
  ConnectRule rule,
  String what,
  ConnectVerdict Function() run,
});

/// ══════════════════════════════════════════════════════════════════════
/// THE HALF AC-051 SAYS GETS SKIPPED, AND IT WAS SKIPPED HERE
/// ══════════════════════════════════════════════════════════════════════
/// `#298`: *"the near-miss is the half that gets skipped and the half that
/// matters: a known-bad alone proves the rule fires, not that it
/// discriminates."* This file had a gated table of refusals from the day
/// it was written, and a coverage test making a new rule impossible to add
/// without one. It had no equivalent for the other direction: the legal
/// cases below existed, scattered, and nothing checked that every rule had
/// one.
///
/// So each row here is the matching row of [connectRefusals] with EXACTLY ONE
/// property changed, and the coverage assertion is the same shape. A rule
/// implemented as `return refused` passes every row of that table and
/// fails every row of this one.
List<ConnectNearMissCase> connectNearMisses() => [
  (
    rule: ConnectRule.endpointResolves,
    what:
        'the tombstone is for some other port and this pin is merely '
        'unmaterialised',
    run: () {
      // DR-011.1: "not yet in doc.ports" is the NORMAL state of a legal
      // target, because the connect command materialises on apply(). The
      // refusal case buries this pin; this one buries a stranger.
      final doc = connectPair();
      doc.tombstones[const Uuid('port-of-some-other-device')] = Tombstone(
        deletedAt: connectWhen,
        entityType: 'Port',
        by: 'test',
      );
      return evaluateConnect(doc, connectAvrOut(doc), connectTvIn(doc));
    },
  ),
  (
    rule: ConnectRule.hostResolves,
    what: 'the shelf IS in the document and IS a container',
    run: () {
      const shelf = Uuid('dev-shelf');
      final doc = connectPair();
      connectAddDevice(
        doc,
        shelf,
        'SHF-1',
        connectBody(const [], isContainer: true),
      );
      doc.devices[connectAvr] = DeviceInstance(
        id: connectAvr,
        kind: DeviceKind.rackDevice,
        templateRef: doc.devices[connectAvr]!.templateRef,
        designator: 'AVR-1',
        name: 'AVR-1',
        placement: const ShelfPlacement(
          hostDeviceId: shelf,
          order: FracIndex('a0'),
        ),
        meta: connectMeta(),
      );
      return evaluateConnect(doc, connectAvrOut(doc), connectTvIn(doc));
    },
  ),
  (
    rule: ConnectRule.notSelf,
    what: 'the two ends are DIFFERENT pins on the same device',
    run: () {
      // A loopback is a real cable somebody runs. Only the pin-to-ITSELF
      // case is model-illegal, and one letter separates the two.
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('a'), connectPort('b', order: 'a1')]),
      );
      return evaluateConnect(
        doc,
        connectPin(doc, connectAvr, 'a'),
        connectPin(doc, connectAvr, 'b'),
      );
    },
  ),
  (
    rule: ConnectRule.notDuplicatePair,
    what: 'the same ordered pair goes onto a FRESH link',
    run: () {
      // TOP-002 is scoped to one link, exactly as canon writes it. Two
      // cables between the same two jacks is an ordinary redundant run;
      // two conductors doing it inside one cable is the illegal state.
      final doc = connectPair(avrMax: 4, tvMax: 4);
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
  (
    rule: ConnectRule.withinMaxConnections,
    what: 'the pin declares room for one more',
    run: () {
      final doc = connectPair(avrMax: 2);
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        const OpenEndpoint('elsewhere'),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
];
