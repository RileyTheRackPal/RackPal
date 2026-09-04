// The tier-3 pairs: the fourteen post-hoc rules (M5-G2/G3).
//
// ═══════════════════════════════════════════════════════════════════════
// "EXACTLY THIS RULE AND NOTHING ELSE" IS THE HARD PART
// ═══════════════════════════════════════════════════════════════════════
// `#300`: *"a fixture that also trips two other rules is not evidence
// about this one."* Tier 3 is where that bites, because these fourteen
// predicates all read the same document: a rack tall enough to overlap
// devices in is a rack whose weight, depth and outlet counts are also
// being watched. Every known-bad here is therefore the SMALLEST document
// that fires its rule, and the harness fails it if anything else joins in.
//
// The near-misses are the same document with one property moved back.
import 'package:rackpal_core/rackpal_core.dart';

import 'drc_fixture.dart';
import 'fixture_docs.dart';

/// Two 3 U devices one U apart: they share rack space.
RackDocument _overlap() {
  final doc = fixtureDoc(heightU: 24);
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 1, seq: 1, designator: 'A-1');
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 2, seq: 2, designator: 'A-2');
  return doc;
}

/// The same two devices, stacked exactly clear of each other.
RackDocument _stacked() {
  final doc = fixtureDoc(heightU: 24);
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 1, seq: 1, designator: 'A-1');
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 4, seq: 2, designator: 'A-2');
  return doc;
}

/// One 3 U device at U 3 of a 4 U rack: its top reaches U 5.
RackDocument _overhang() {
  final doc = fixtureDoc(heightU: 4);
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 3, seq: 1, designator: 'A-1');
  return doc;
}

/// The same device at U 2, ending exactly at the top U.
RackDocument _flush() {
  final doc = fixtureDoc(heightU: 4);
  fixturePlaceBody(doc, fixtureBody(frontU: 3), 2, seq: 1, designator: 'A-1');
  return doc;
}

/// A rack rated for 50 kg carrying 80 kg.
RackDocument _overCapacity() {
  final doc = fixtureDoc(weightCapacity: Mass.fromKilograms(50));
  fixturePlaceBody(
    doc,
    fixtureBody(frontU: 2, weight: Mass.fromKilograms(80)),
    1,
    seq: 1,
    designator: 'AMP-1',
  );
  return doc;
}

/// The same rack carrying 40 kg, which is under both the limit and the
/// 85% advisory line.
RackDocument _underCapacity() {
  final doc = fixtureDoc(weightCapacity: Mass.fromKilograms(50));
  fixturePlaceBody(
    doc,
    fixtureBody(frontU: 2, weight: Mass.fromKilograms(40)),
    1,
    seq: 1,
    designator: 'AMP-1',
  );
  return doc;
}

/// Front and rear devices at the same U whose bodies plus the 50 mm
/// cable allowance exceed the rack's usable depth.
RackDocument _tooDeep({required Len front, required Len rear}) {
  final doc = fixtureDoc(usableDepth: Len.fromMillimetres(600));
  fixturePlaceBody(
    doc,
    fixtureBody(frontU: 2, bodyDepth: front),
    1,
    seq: 1,
    designator: 'F-1',
  );
  fixturePlaceBody(
    doc,
    fixtureBody(frontU: 0, rearU: 2, bodyDepth: rear),
    1,
    seq: 2,
    designator: 'R-1',
    face: Face.rear,
  );
  return doc;
}

/// A device heavier than the limit its own body states, on front ears.
RackDocument _unsupported({required Mass weight}) {
  final doc = fixtureDoc();
  fixturePlaceBody(
    doc,
    fixtureBody(
      frontU: 2,
      weight: weight,
      maxUnsupportedMass: Mass.fromKilograms(20),
    ),
    1,
    seq: 1,
    designator: 'AMP-1',
  );
  return doc;
}

// ─────────────────────────────────────────────────────────────────────
// The cable rules need links, and a link needs a service to have a
// family. NOTE the endpoints: `OpenEndpoint` looks unlanded and is not.
// `LNK-020` counts only links carrying a `structureOrigin`, so an
// ordinary link with open ends is silent there, which is what lets these
// fixtures stay evidence about one rule.
// ─────────────────────────────────────────────────────────────────────

int _wireSeq = 0;

Link _wire(
  RackDocument doc, {
  required String media,
  required String family,
  Len? terminated,
  JacketListing? jacket,
  Uuid? pathwayId,
}) {
  _wireSeq++;
  final link = Link(
    id: fixtureId(900 + _wireSeq),
    designator: 'W001',
    media: MediaTypeId(media),
    order: FracIndex('a$_wireSeq'),
    // NOT `const`: `_homeRun` replaces element 0 to land an end, and a
    // const list is unmodifiable.
    conductors: [
      const Conductor(
        role: 'pair',
        from: OpenEndpoint('a'),
        to: OpenEndpoint('b'),
      ),
    ],
    services: [
      Service(
        id: 'svc-$_wireSeq',
        signalFamily: SignalFamilyId(family),
        netId: fixtureId(800 + _wireSeq),
      ),
    ],
    meta: fixtureMeta(),
  );
  if (terminated != null) link.terminatedLength = terminated;
  if (jacket != null) link.jacket = jacket;
  if (pathwayId != null) link.pathwayId = pathwayId;
  doc.links[link.id] = link;
  return link;
}

/// A medium that declares NO passive limit.
///
/// Thirty-one of the thirty-eight. Fixtures about something other than
/// length use one, because `LEN-002` is silent on a medium with no limit
/// and `cat6` is not such a medium: a 120 m cat6 run fires BOTH length
/// rules, which the corpus harness caught on the first run.
MapEntry<MediaTypeId, MediaTypeDef> _unlimitedMedium(RackDocument doc) =>
    doc.registries.mediaTypes.entries.firstWhere(
      (e) => e.value.maxRunLengthPassive == null,
    );

/// A short run on a medium with no limit, for fixtures that are about
/// something else entirely.
///
/// THE LENGTH IS STATED, and that is not incidental. `LEN-001` and
/// `LEN-002` both fire on an UNKNOWN length, deliberately: docs/02 §5.3
/// makes "length unknown, cannot verify" a finding rather than silence.
/// So a link with no length is not a quiet link, and four fixtures about
/// jackets and home runs were arming both length rules until this.
Link _quietWire(
  RackDocument doc, {
  JacketListing? jacket,
  Uuid? pathwayId,
}) => _wire(
  doc,
  media: _unlimitedMedium(doc).key.v,
  family: 'video.composite',
  terminated: Len.fromMillimetres(3000),
  jacket: jacket,
  pathwayId: pathwayId,
);

/// An Ethernet run of [length], on a medium that declares no passive
/// limit of its own.
///
/// NOT cat6, which declares one: at 120 m a cat6 run fires `LEN-002` as
/// well and stops being evidence about the 100 m channel.
RackDocument _ethernetRun(Len length) {
  final doc = fixtureDoc();
  _wire(
    doc,
    media: _unlimitedMedium(doc).key.v,
    family: 'net.ethernet',
    terminated: length,
  );
  return doc;
}

/// A medium that declares its own limit, FOUND rather than named: DR-020
/// makes `LEN-002` generic, and naming a row would make this a statement
/// about that row instead of about the rule.
MapEntry<MediaTypeId, MediaTypeDef> _limitedMedium(RackDocument doc) =>
    doc.registries.mediaTypes.entries.firstWhere(
      (e) => e.value.maxRunLengthPassive != null,
    );

/// A run on a limited medium, at [times] its own limit.
///
/// NOT `net.ethernet`, deliberately. The existing `LEN-002` test uses it
/// and is right to, because it scopes evaluation to one rule; here a
/// double-length Ethernet run would fire `LEN-001` as well and stop
/// being evidence about `LEN-002`.
RackDocument _limitedRun(double times) {
  final doc = fixtureDoc();
  final m = _limitedMedium(doc);
  final limit = m.value.maxRunLengthPassive!;
  _wire(
    doc,
    media: m.key.v,
    family: 'video.composite',
    terminated: Len((limit.nm * times).round()),
  );
  return doc;
}

Pathway _pathway(
  RackDocument doc, {
  required PathwayKind kind,
  required bool lineVoltage,
}) {
  final p = Pathway(
    id: fixtureId(700),
    name: 'PW-1',
    kind: kind,
    order: const FracIndex('a0'),
    meta: fixtureMeta(),
    containsLineVoltage: lineVoltage,
  );
  doc.pathways[p.id] = p;
  return p;
}

RackDocument _inPathway({
  required PathwayKind kind,
  required bool lineVoltage,
  required JacketListing jacket,
}) {
  final doc = fixtureDoc();
  final p = _pathway(doc, kind: kind, lineVoltage: lineVoltage);
  _quietWire(doc, jacket: jacket, pathwayId: p.id);
  return doc;
}

/// A home run with a structure origin, landed or not.
RackDocument _homeRun({required bool landed}) {
  final doc = fixtureDoc();
  final link = _quietWire(doc)
    ..structureOrigin = StructureOrigin(
      structureBodyId: fixtureId(600),
      outletId: fixtureId(601),
      fieldLabel: 'LR-1',
    );
  if (!landed) {
    link.conductors[0] = const Conductor(
      role: 'pair',
      from: PlaceEndpoint(description: 'wall'),
      to: PlaceEndpoint(description: 'wall'),
    );
  } else {
    final device = fixturePlaceBody(
      doc,
      fixtureBody(),
      1,
      seq: 5,
      designator: 'PP-1',
    );
    final port = Port(
      id: fixtureId(602),
      deviceId: device.id,
      designator: 'P1',
    );
    doc.ports[port.id] = port;
    link.conductors[0] = Conductor(
      role: 'pair',
      from: const PlaceEndpoint(description: 'wall'),
      to: PortEndpoint(port.id),
    );
  }
  return doc;
}

/// A circuit with one off-rack device drawing [va].
///
/// OFF-RACK ON PURPOSE: a device in the rack would consume an outlet the
/// rack does not provide and arm `PWR-003` alongside.
RackDocument _circuitLoad(int va) {
  final doc = fixtureDoc();
  final circuit = Circuit(
    id: fixtureId(500),
    designator: 'Panel A / Breaker 1',
    breakerAmps: 15,
    volts: 120,
    meta: fixtureMeta(),
  );
  doc.circuits[circuit.id] = circuit;
  const id = 'LOAD';
  doc.templates[templateKey(id, 1)] = TemplateSnapshot(
    templateId: const TemplateId(id),
    version: 1,
    contentHash: 'sha256:LOAD',
    body: TemplateBody(
      manufacturer: 'FX',
      model: id,
      displayName: 'load',
      power: PowerProfile(apparentVA: va),
    ),
    capturedAt: fixtureAt,
  );
  final device = DeviceInstance(
    id: fixtureId(501),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:LOAD',
    ),
    designator: 'AMP-1',
    name: 'load',
    placement: const OffRackPlacement(),
    meta: fixtureMeta(),
  );
  doc.devices[device.id] = device;
  final port = Port(id: fixtureId(502), deviceId: device.id, designator: 'P1')
    ..circuitId = circuit.id;
  doc.ports[port.id] = port;
  return doc;
}

/// A rack whose devices want [consumed] outlets and are offered
/// [provided].
RackDocument _outlets({required int consumed, required int provided}) {
  final doc = fixtureDoc();
  fixturePlaceBody(
    doc,
    fixtureBody(power: PowerProfile(outletsConsumed: consumed)),
    1,
    seq: 1,
    designator: 'AMP-1',
  );
  fixturePlaceBody(
    doc,
    fixtureBody(power: PowerProfile(outletsProvided: provided)),
    3,
    seq: 2,
    designator: 'PDU-1',
  );
  return doc;
}

/// A speaker run whose two ends are marked [fromLeg] and [toLeg].
///
/// `ELE-003` reads polarity off the PORT DESIGNATORS, and a conductor
/// carrying both a `+` and a `-` end is the inversion. Two ends marked
/// the same way agree; an UNMARKED pair is unknown and skipped (G4),
/// because an unlabelled terminal block is not a wiring fault.
RackDocument _speakerRun({required String fromLeg, required String toLeg}) {
  final doc = fixtureDoc();
  final device = fixturePlaceBody(
    doc,
    fixtureBody(),
    1,
    seq: 7,
    designator: 'AMP-1',
  );
  final a = Port(id: fixtureId(650), deviceId: device.id, designator: fromLeg);
  final b = Port(id: fixtureId(651), deviceId: device.id, designator: toLeg);
  doc.ports[a.id] = a;
  doc.ports[b.id] = b;
  final link = _quietWire(doc);
  link.services[0] = Service(
    id: 'svc-spk',
    signalFamily: const SignalFamilyId('audio.speaker_lowz'),
    netId: fixtureId(652),
  );
  link.conductors[0] = Conductor(
    role: 'pair',
    from: PortEndpoint(a.id),
    to: PortEndpoint(b.id),
  );
  return doc;
}

/// A switch with a [budget] W PoE budget feeding one PD drawing
/// [standard]'s ceiling.
RackDocument _poeBudget({
  required int budget,
  required PoeStandard standard,
}) {
  final doc = fixtureDoc();

  TemplateBody switchBody() => TemplateBody(
    manufacturer: 'FX',
    model: 'sw',
    displayName: 'switch',
    power: PowerProfile(poeBudgetWatts: budget),
    ports: [
      PortDef(
        key: const PortKey('p1'),
        label: 'P1',
        signalFamily: const SignalFamilyId('net.ethernet'),
        connector: const ConnectorTypeId('rj45'),
        face: Face.front,
        order: const FracIndex('a0'),
        poe: PoeSpec(role: PoeRole.pse),
      ),
    ],
  );

  TemplateBody pdBody() => TemplateBody(
    manufacturer: 'FX',
    model: 'cam',
    displayName: 'camera',
    ports: [
      PortDef(
        key: const PortKey('p1'),
        label: 'P1',
        signalFamily: const SignalFamilyId('net.ethernet'),
        connector: const ConnectorTypeId('rj45'),
        face: Face.front,
        order: const FracIndex('a0'),
        poe: PoeSpec(role: PoeRole.pd, standard: standard),
      ),
    ],
  );

  DeviceInstance install(
    String id,
    TemplateBody body,
    String designator,
    int seq,
  ) {
    doc.templates[templateKey(id, 1)] = TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      body: body,
      capturedAt: fixtureAt,
    );
    final device = DeviceInstance(
      id: fixtureId(seq),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(id),
        version: 1,
        contentHash: 'sha256:$id',
      ),
      designator: designator,
      name: body.displayName,
      placement: const OffRackPlacement(),
      meta: fixtureMeta(),
    );
    doc.devices[device.id] = device;
    return device;
  }

  final sw = install('SW', switchBody(), 'SW-1', 660);
  final cam = install('CAM', pdBody(), 'CAM-1', 661);

  const key = PortKey('p1');
  final swPort = derivePortId(sw.id, key);
  final camPort = derivePortId(cam.id, key);
  doc.ports[swPort] = Port(
    id: swPort,
    deviceId: sw.id,
    designator: 'P1',
    templatePortKey: key,
  );
  doc.ports[camPort] = Port(
    id: camPort,
    deviceId: cam.id,
    designator: 'P1',
    templatePortKey: key,
  );

  final link = _quietWire(doc);
  link.conductors[0] = Conductor(
    role: 'pair',
    from: PortEndpoint(swPort),
    to: PortEndpoint(camPort),
  );
  return doc;
}

/// The fourteen post-hoc rules' pairs.
List<DrcFixture> tier3Fixtures() => [
  DrcFixture(
    ruleId: 'RCK-001',
    kind: FixtureKind.knownBad,
    what: 'two 3 U devices one U apart share rack space',
    run: () => fromDocument(_overlap()),
  ),
  DrcFixture(
    ruleId: 'RCK-001',
    kind: FixtureKind.nearMiss,
    what: 'the same two devices stacked exactly clear',
    run: () => fromDocument(_stacked()),
  ),
  DrcFixture(
    ruleId: 'RCK-002',
    kind: FixtureKind.knownBad,
    what: 'a 3 U device at U 3 of a 4 U rack reaches U 5',
    run: () => fromDocument(_overhang()),
  ),
  DrcFixture(
    ruleId: 'RCK-002',
    kind: FixtureKind.nearMiss,
    what: 'the same device ending exactly at the top U',
    run: () => fromDocument(_flush()),
  ),
  DrcFixture(
    ruleId: 'RCK-003',
    kind: FixtureKind.knownBad,
    what: '80 kg in a rack rated for 50',
    run: () => fromDocument(_overCapacity()),
  ),
  DrcFixture(
    ruleId: 'RCK-003',
    kind: FixtureKind.nearMiss,
    what: '40 kg in the same rack, under the 85% advisory line too',
    run: () => fromDocument(_underCapacity()),
  ),
  DrcFixture(
    ruleId: 'RCK-012',
    kind: FixtureKind.knownBad,
    what: '400 mm front and 300 mm rear plus 50 mm exceeds 600 mm',
    run: () => fromDocument(
      _tooDeep(
        front: Len.fromMillimetres(400),
        rear: Len.fromMillimetres(300),
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'RCK-012',
    kind: FixtureKind.nearMiss,
    what: '300 mm and 250 mm plus 50 mm is exactly 600 mm',
    run: () => fromDocument(
      _tooDeep(
        front: Len.fromMillimetres(300),
        rear: Len.fromMillimetres(250),
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'RCK-013',
    kind: FixtureKind.knownBad,
    what: '30 kg on ears rated for 20',
    run: () => fromDocument(_unsupported(weight: Mass.fromKilograms(30))),
  ),
  DrcFixture(
    ruleId: 'RCK-013',
    kind: FixtureKind.nearMiss,
    what: 'exactly 20 kg, which is at the limit and not over it',
    run: () => fromDocument(_unsupported(weight: Mass.fromKilograms(20))),
  ),
  DrcFixture(
    ruleId: 'LEN-001',
    kind: FixtureKind.knownBad,
    what: '120 m of Ethernet, past the 100 m channel',
    run: () => fromDocument(_ethernetRun(Len.fromMillimetres(120000))),
  ),
  DrcFixture(
    ruleId: 'LEN-001',
    kind: FixtureKind.nearMiss,
    what: '100 m exactly, which is at the limit and not past it',
    run: () => fromDocument(_ethernetRun(Len.fromMillimetres(100000))),
  ),
  DrcFixture(
    ruleId: 'LEN-002',
    kind: FixtureKind.knownBad,
    what: "a run at twice its own medium's declared limit",
    run: () => fromDocument(_limitedRun(2)),
  ),
  DrcFixture(
    ruleId: 'LEN-002',
    kind: FixtureKind.nearMiss,
    what: 'the same run at exactly that limit',
    run: () => fromDocument(_limitedRun(1)),
  ),
  DrcFixture(
    ruleId: 'CODE-001',
    kind: FixtureKind.knownBad,
    what: 'a Class 2 cable in a conduit carrying line voltage',
    run: () => fromDocument(
      _inPathway(
        kind: PathwayKind.conduit,
        lineVoltage: true,
        jacket: JacketListing.cl2,
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'CODE-001',
    kind: FixtureKind.nearMiss,
    what: 'the same cable in the same conduit, with no line voltage',
    run: () => fromDocument(
      _inPathway(
        kind: PathwayKind.conduit,
        lineVoltage: false,
        jacket: JacketListing.cl2,
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'CODE-002',
    kind: FixtureKind.knownBad,
    what: 'a CM jacket in a plenum space',
    run: () => fromDocument(
      _inPathway(
        kind: PathwayKind.plenumSpace,
        lineVoltage: false,
        jacket: JacketListing.cm,
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'CODE-002',
    kind: FixtureKind.nearMiss,
    what: 'the plenum-listed CMP jacket in the same space',
    run: () => fromDocument(
      _inPathway(
        kind: PathwayKind.plenumSpace,
        lineVoltage: false,
        jacket: JacketListing.cmp,
      ),
    ),
  ),
  DrcFixture(
    ruleId: 'LNK-020',
    kind: FixtureKind.knownBad,
    what: 'a home run whose far end is still on the wall',
    run: () => fromDocument(_homeRun(landed: false)),
  ),
  DrcFixture(
    ruleId: 'LNK-020',
    kind: FixtureKind.nearMiss,
    what: 'the same run, landed on a patch panel port',
    run: () => fromDocument(_homeRun(landed: true)),
  ),
  DrcFixture(
    ruleId: 'PWR-001',
    kind: FixtureKind.knownBad,
    what: '1600 VA on a 15 A circuit, past the 1440 VA allowance',
    run: () => fromDocument(_circuitLoad(1600)),
  ),
  DrcFixture(
    ruleId: 'PWR-001',
    kind: FixtureKind.nearMiss,
    what: '1440 VA exactly, which is the allowance and not over it',
    run: () => fromDocument(_circuitLoad(1440)),
  ),
  DrcFixture(
    ruleId: 'PWR-003',
    kind: FixtureKind.knownBad,
    what: 'four outlets wanted, two provided',
    run: () => fromDocument(_outlets(consumed: 4, provided: 2)),
  ),
  DrcFixture(
    ruleId: 'PWR-003',
    kind: FixtureKind.nearMiss,
    what: 'two wanted and two provided, which is exactly enough',
    run: () => fromDocument(_outlets(consumed: 2, provided: 2)),
  ),
  DrcFixture(
    ruleId: 'ELE-003',
    kind: FixtureKind.knownBad,
    what: 'a speaker pair running + to -',
    run: () => fromDocument(_speakerRun(fromLeg: 'SP1+', toLeg: 'SP1-')),
  ),
  DrcFixture(
    ruleId: 'ELE-003',
    kind: FixtureKind.nearMiss,
    what: 'the same pair running + to +, which is in phase',
    run: () => fromDocument(_speakerRun(fromLeg: 'SP1+', toLeg: 'SP2+')),
  ),
  DrcFixture(
    ruleId: 'NET-001',
    kind: FixtureKind.knownBad,
    what: 'a 90 W bt4 camera on a switch with a 30 W budget',
    run: () => fromDocument(
      _poeBudget(budget: 30, standard: PoeStandard.btType4),
    ),
  ),
  DrcFixture(
    ruleId: 'NET-001',
    kind: FixtureKind.nearMiss,
    what: 'a 30 W at camera on the same 30 W budget, which is exactly it',
    run: () => fromDocument(_poeBudget(budget: 30, standard: PoeStandard.at)),
  ),
];
