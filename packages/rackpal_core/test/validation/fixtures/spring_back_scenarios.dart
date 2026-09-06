// The spring-back tier's scenarios and their AC-051 pairs (M5-G2/G3).
//
// ═════════════════════════════════════════════════════════════════════
// THREE IDS IN HERE NAMED NOTHING THAT SHIPS, UNTIL DR-128
// ═════════════════════════════════════════════════════════════════════
// `conn.xlr3_f`, `video.hdmi` and `audio.analog_bal`. The real ones are
// `conn.xlr3`, `video.hdmi.2_0` and `audio.line_bal`, and every case
// still passed on the ghosts because the predicates that read them
// compare ids directly: a fixture family only has to differ from the
// other end, not to exist.
//
// `CON-001` is the one where it mattered. It reads the REGISTRY, and
// `_connectorsDoNotMate` skips entirely when the FROM connector is
// unknown (the G4 branch, `#255`). So a ghost exercises the real limb or
// the unknown limb depending on which END it lands on, and a fixture can
// move between "this rule fired" and "this rule was skipped" without its
// author noticing. Here it landed on the TO end, so the known-bad was
// asserting that HDMI does not mate with a typo.
//
// Found while building DR-128's `CON-001` remedy, whose own first draft
// invented `conn.xlr3_m` and was caught by its own "this is not vacuous"
// test. `spring_back_rules_test.dart` now censuses both id kinds against
// the seeded registries, so the next one fails on sight.
//
// MOVED HERE FROM `spring_back_rules_test.dart`, unchanged in substance,
// for the reason `connect_scenarios.dart` gives: `#302`'s gate is over
// the CATALOGUE, and a coverage test driven by `SpringBackRule.values`
// cannot see a catalogue row no enum mentions. The assertions stayed
// where they were; only the data moved.

import 'package:rackpal_core/rackpal_core.dart';

final springBackWhen = DateTime.utc(2026, 9, 3);
const springBackA = Uuid('dev-a');
const springBackB = Uuid('dev-b');

EntityMeta springBackMeta() => EntityMeta(
  createdAt: springBackWhen,
  updatedAt: springBackWhen,
  updatedBy: 'test',
);

const springBackPos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef springBackPort(
  String key,
  String family, {
  PortDirection dir = PortDirection.source,
  String connector = 'conn.rj45',
  List<String> accepts = const [],
  ReturnChannel? returnChannel,
  // FOUR BY DEFAULT so a scenario never trips `TOP-003` by accident: this
  // tier's cases are about the SIGNAL, and a pin that filled up would
  // refuse at tier 1 before any of them ran. A caller testing an
  // occupancy path passes 1.
  int maxConnections = 4,
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: springBackPos,
  order: const FracIndex('a0'),
  direction: dir,
  returnChannel: returnChannel,
  acceptedFamilies: [for (final f in accepts) SignalFamilyId(f)],
  maxConnections: maxConnections,
);

/// Two devices, one port each, so every case below is exactly the pair
/// under test with nothing else able to fire.
/// [fromIsBypassed] MATERIALISES the source port with `lowZBypass` set
/// (DR-131 §11.130.4). It has to materialise: the bypass is a fact about
/// this installed speaker, so `ELE-006` reads it off `doc.ports` rather
/// than off the template, and a fixture that only declares a `PortDef`
/// cannot express it. Every other case here leaves ports unmaterialised
/// and is unaffected.
RackDocument springBackPair(
  PortDef fromPort,
  PortDef toPort, {
  bool toIsPassthrough = false,
  bool fromIsBypassed = false,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-t2'),
    appVersion: '0.5.22',
    createdAt: springBackWhen,
    modifiedAt: springBackWhen,
    meta: springBackMeta(),
  )..registries = buildSeedRegistries();
  springBackAdd(doc, springBackA, 'SRC-1', fromPort, isPassthrough: false);
  springBackAdd(
    doc,
    springBackB,
    'DST-1',
    toPort,
    isPassthrough: toIsPassthrough,
  );
  if (fromIsBypassed) {
    final id = derivePortId(springBackA, fromPort.key);
    doc.ports[id] = Port(
      id: id,
      deviceId: springBackA,
      designator: 'SRC-1.p',
      templatePortKey: fromPort.key,
      lowZBypass: true,
    );
  }
  return doc;
}

void springBackAdd(
  RackDocument doc,
  Uuid id,
  String designator,
  PortDef port, {
  required bool isPassthrough,
}) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    body: TemplateBody(
      manufacturer: 'Acme',
      model: designator,
      displayName: designator,
      isPassthrough: isPassthrough,
      ports: [port],
    ),
    capturedAt: springBackWhen,
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
    meta: springBackMeta(),
  );
}

SpringBackVerdict springBackRun(RackDocument doc) => evaluateSpringBack(
  doc,
  resolveConnectTarget(doc, deviceId: springBackA, portKey: 'p')!,
  resolveConnectTarget(doc, deviceId: springBackB, portKey: 'p')!,
);

typedef SpringBackCase = ({
  SpringBackRule rule,
  String what,
  RackDocument Function() doc,
});

/// One known-bad per rule. The coverage test below compares this against
/// `SpringBackRule.values`.
List<SpringBackCase> springBackChips() => [
  (
    rule: SpringBackRule.hdbasetIntoEthernet,
    what: 'HDBaseT lands on a terminating Ethernet port',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdbaset'),
      springBackPort('p', 'net.ethernet', dir: PortDirection.sink),
    ),
  ),
  (
    rule: SpringBackRule.irEmitterIntoReceiver,
    what: 'an IR emitter output lands on an IR receiver jack',
    doc: () => springBackPair(
      springBackPort('p', 'ctl.ir_emitter', connector: 'conn.3_5mm_ts'),
      springBackPort(
        'p',
        'ctl.ir_receiver',
        dir: PortDirection.sink,
        connector: 'conn.3_5mm_ts',
      ),
    ),
  ),
  (
    rule: SpringBackRule.speakerImpedanceMismatch,
    what: 'a constant-voltage line meets a low-Z speaker',
    doc: () => springBackPair(
      springBackPort('p', 'audio.speaker_cv', connector: 'conn.euroblock_2'),
      springBackPort(
        'p',
        'audio.speaker_lowz',
        dir: PortDirection.sink,
        connector: 'conn.euroblock_2',
      ),
    ),
  ),
  (
    rule: SpringBackRule.directionMismatch,
    what: 'both ends are outputs',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
    ),
  ),
  (
    rule: SpringBackRule.familyNotAccepted,
    what: 'the sink does not accept the source family',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
      springBackPort(
        'p',
        'audio.line_bal',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
      ),
    ),
  ),
  // `conn.xlr3`, AND IT USED TO READ `conn.xlr3_f`, WHICH DOES NOT EXIST.
  // The case still fired, because a ghost id is not in `conn.hdmi_a`'s
  // `matesWith` list and neither is any other made-up string: the test
  // was asserting that HDMI does not mate with a typo. `CON-001` reads
  // the REGISTRY, and a fixture that names a connector the registry has
  // never heard of is exercising the G4 unknown branch of some rules and
  // the real branch of others, depending on which end it lands on. Found
  // while building DR-128's remedy, whose own first draft made the same
  // mistake and was caught by its own "this is not vacuous" test.
  (
    rule: SpringBackRule.connectorsDoNotMate,
    what: 'the connectors do not mate and no adapter is declared',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
      springBackPort(
        'p',
        'video.hdmi.2_0',
        dir: PortDirection.sink,
        connector: 'conn.xlr3',
        accepts: ['video.hdmi.2_0'],
      ),
    ),
  ),
];

/// One known-good near-miss per rule, ONE PROPERTY from its bad case.
List<SpringBackCase> springBackNearMisses() => [
  (
    rule: SpringBackRule.hdbasetIntoEthernet,
    what:
        'the Ethernet port is on a PASSTHROUGH, so the joint is a patch '
        'panel and the switch question is a path question (DR-113)',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdbaset'),
      springBackPort('p', 'net.ethernet', dir: PortDirection.sink),
      toIsPassthrough: true,
    ),
  ),
  // THE ROW MOVED TO THE CASE THE RULE USED TO GET WRONG (DR-126
  // §11.125). It read "the far end is an emitter port too, which is what
  // an IR connecting block offers", and that is still true and still
  // clears. This one is worth more: an emitter head reaching a
  // television, a matrix, an AVR or a cable box is what an IR system IS,
  // and until the eleven device inputs were re-familied every one of them
  // sprang the wire back with the words "destroys the emitter".
  //
  // ONE ROW PER RULE IS THIS TABLE'S OWN INVARIANT, gated two tests down,
  // so this is a swap and not an addition. The wider sweep, over the
  // shipped catalogue rather than ports a fixture wrote, lives in
  // `catalog/ir_family_split_test.dart`, which is where it can actually
  // see a mis-familied port.
  //
  // NOTE THE `accepts`. Without it `SIG-002` fires instead and the pair
  // still springs back, which is exactly what happened on the first run
  // of this row: silencing `DIR-003` alone would have changed the
  // sentence and nothing else.
  (
    rule: SpringBackRule.irEmitterIntoReceiver,
    what:
        'the far end is a passive device input, which is where an emitter '
        'head is supposed to go (DR-126)',
    doc: () => springBackPair(
      springBackPort('p', 'ctl.ir_emitter', connector: 'conn.3_5mm_ts'),
      springBackPort(
        'p',
        'ctl.ir_direct',
        dir: PortDirection.sink,
        connector: 'conn.3_5mm_ts',
        accepts: ['ctl.ir_emitter'],
      ),
    ),
  ),
  (
    rule: SpringBackRule.speakerImpedanceMismatch,
    what: 'both ends are constant voltage',
    doc: () => springBackPair(
      springBackPort('p', 'audio.speaker_cv', connector: 'conn.euroblock_2'),
      springBackPort(
        'p',
        'audio.speaker_cv',
        dir: PortDirection.sink,
        connector: 'conn.euroblock_2',
      ),
    ),
  ),
  (
    rule: SpringBackRule.directionMismatch,
    what: 'both ends declare a return channel, which is eARC working',
    doc: () => springBackPair(
      springBackPort(
        'p',
        'video.hdmi.2_0',
        connector: 'conn.hdmi_a',
        returnChannel: ReturnChannel.eArc,
      ),
      springBackPort(
        'p',
        'video.hdmi.2_0',
        connector: 'conn.hdmi_a',
        returnChannel: ReturnChannel.eArc,
      ),
    ),
  ),
  (
    rule: SpringBackRule.familyNotAccepted,
    what: 'the sink DECLARES the source family in acceptedFamilies',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
      springBackPort(
        'p',
        'audio.line_bal',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
        accepts: ['video.hdmi.2_0'],
      ),
    ),
  ),
  (
    rule: SpringBackRule.connectorsDoNotMate,
    what: 'the connectors mate',
    doc: () => springBackPair(
      springBackPort('p', 'video.hdmi.2_0', connector: 'conn.hdmi_a'),
      springBackPort(
        'p',
        'video.hdmi.2_0',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
        accepts: ['video.hdmi.2_0'],
      ),
    ),
  ),
];
