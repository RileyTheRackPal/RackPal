// DR-011.5 and docs/02-data-model.md §5.1 — the five tier-1 topology
// rules, and the two properties that make them worth having.
//
// THE FIRST is that a refusal SAYS SOMETHING. docs/02 §5's tier table
// gives T1's escape as "None. There is nothing to escape to." — so the
// sentence the user gets is the whole of their recourse, and "TOP-003" on
// its own sends them hunting through a rack for which of forty ports is
// full. The refusal table below is driven off `ConnectRule.values`, so a
// sixth rule added without a sentence FAILS here rather than shipping a
// silent spring-back.
//
// THE SECOND is that the ORDER is fixed. Two rules can fire on one
// gesture, and which one is reported decides what the user does next:
// told "this port is full" for a wire they dropped back on its own pin,
// they go looking for a port to free that they never needed to free. The
// order is `ConnectRule`'s declaration order and the pair tests below pin
// every adjacent step of it.
//
// WHAT IS NOT HERE. The six tier-2 rules (`SIG-001`, `SIG-002`,
// `DIR-001`, `DIR-003`, `CON-001`, `ELE-006`) are deferred to M5 and must
// NOT refuse — a T2 condition quietly implemented as a T1 refusal makes
// the product unable to draw a mistake, which CR-017 and G2 exist to
// prevent. `a legal pair is accepted` covers the case that would break
// first.
//
// AND ONE HONEST GAP: `TOP-005` is a PLACEMENT rule. A connect gesture
// can only ever OBSERVE a broken shelf chain, never create one, so what
// is tested here is the precondition — the connect refuses to write a
// cable into an already-model-illegal region. Nothing in the placement
// command set enforces `TOP-005` at the point the state is created; that
// is a real gap and it belongs to whoever ships shelf placement, not to
// this file.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 29);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _avr = Uuid('dev-avr');
const _tv = Uuid('dev-tv');
const _shelf = Uuid('dev-shelf');

PortDef _port(
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
  position: _pos,
  order: FracIndex(order),
  maxConnections: maxConnections,
  direction: direction,
  topology: topology,
);

TemplateBody _body(List<PortDef> ports, {bool isContainer = false}) =>
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
void _addDevice(
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
    capturedAt: _when,
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
    meta: _meta(),
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

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-cr'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
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
RackDocument _pair({int avrMax = 1, int tvMax = 1}) {
  final doc = _doc();
  _addDevice(
    doc,
    _avr,
    'AVR-1',
    _body([_port('hdmi.out.1', maxConnections: avrMax)]),
  );
  _addDevice(
    doc,
    _tv,
    'TV-1',
    _body([_port('hdmi.in.1', maxConnections: tvMax)]),
  );
  return doc;
}

ConnectTarget _avrOut(RackDocument doc) => resolveConnectTarget(
  doc,
  deviceId: _avr,
  portKey: 'hdmi.out.1',
)!;

ConnectTarget _tvIn(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: _tv, portKey: 'hdmi.in.1')!;

ConnectTarget _pin(RackDocument doc, Uuid device, String key) =>
    resolveConnectTarget(doc, deviceId: device, portKey: key)!;

/// The seed catalog, built once — `buildSeedCatalog()` walks every
/// template on each call.
final Map<String, TemplateBody> _seed = buildSeedCatalog();

/// Adds a device whose template body is the REAL seed-catalog entry for
/// [catalogId] — no fixture `PortDef`s, so what is asserted is what
/// ships. Every pin stays unmaterialised, which is what placing from the
/// palette produces.
void _seedDevice(
  RackDocument doc,
  Uuid id,
  String catalogId,
  String designator,
) {
  final body = _seed[catalogId];
  if (body == null) throw StateError('seed catalog has no "$catalogId"');
  doc.templates[catalogTemplateKey(catalogId)] = TemplateSnapshot(
    templateId: TemplateId(catalogId),
    version: 1,
    contentHash: 'sha256:seed-$catalogId',
    body: body,
    capturedAt: _when,
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
    meta: _meta(),
  );
}

/// A `Link` carrying one conductor from [from] to [to], so a test can set
/// up an occupied port or an already-run ordered pair.
Uuid _link(
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
    meta: _meta(),
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
typedef _Refusal = ({
  ConnectRule rule,
  String what,
  ConnectVerdict Function() run,
  List<String> mustName,
});

/// EVERY rule gets a row. The coverage assertion below compares this
/// list against `ConnectRule.values`.
List<_Refusal> _refusals() => [
  (
    rule: ConnectRule.endpointResolves,
    what: 'the port has been tombstoned',
    mustName: ['AVR-1'],
    run: () {
      final doc = _pair();
      final from = _avrOut(doc);
      doc.tombstones[from.portId] = Tombstone(
        deletedAt: _when,
        entityType: 'Port',
        by: 'test',
      );
      return evaluateConnect(doc, from, _tvIn(doc));
    },
  ),
  (
    rule: ConnectRule.hostResolves,
    what: 'the shelf the device sits on is not in the document',
    mustName: ['AVR-1'],
    run: () {
      final doc = _pair();
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      doc.devices[_avr] = DeviceInstance(
        id: _avr,
        kind: DeviceKind.rackDevice,
        templateRef: doc.devices[_avr]!.templateRef,
        designator: 'AVR-1',
        name: 'AVR-1',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('dev-gone'),
          order: FracIndex('a0'),
        ),
        meta: _meta(),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
  (
    rule: ConnectRule.notSelf,
    what: 'both ends are the same pin',
    mustName: ['AVR-1', 'J01'],
    run: () {
      final doc = _pair();
      final from = _avrOut(doc);
      return evaluateConnect(doc, from, _avrOut(doc));
    },
  ),
  (
    rule: ConnectRule.notDuplicatePair,
    what: 'the link already runs this exact ordered pair',
    mustName: ['AVR-1', 'TV-1', 'W001'],
    run: () {
      // maxConnections raised so TOP-003 cannot pre-empt the rule under
      // test — the existing conductor already occupies both pins.
      final doc = _pair(avrMax: 4, tvMax: 4);
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      final id = _link(
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
      final doc = _pair();
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      _link(
        doc,
        'W001',
        PortEndpoint(from.portId),
        const OpenEndpoint('elsewhere'),
      );
      return evaluateConnect(doc, from, to);
    },
  ),
];

void main() {
  group('resolveConnectTarget — the join that did not exist', () {
    test('resolves a pin the document has NOT materialised', () {
      final doc = _pair();
      final t = _avrOut(doc);
      expect(t.deviceId, _avr);
      expect(t.deviceDesignator, 'AVR-1');
      expect(t.portKey, const PortKey('hdmi.out.1'));
      expect(t.signalFamily, const SignalFamilyId('video.hdmi.2_1'));
      expect(t.effectiveMaxConnections, 1);
      expect(t.direction, PortDirection.bidirectional);
      expect(
        t.setKey,
        isNull,
        reason:
            "223 of the catalog's 257 ports carry no setKey — which is "
            'why DR-011.2 makes the gesture pin-to-pin',
      );
      expect(
        t.portId,
        derivePortId(_avr, const PortKey('hdmi.out.1')),
        reason:
            'the id is derived, so it is knowable before the port exists — '
            'that is what lets the command materialise on apply()',
      );
      expect(
        t.isMaterialised,
        isFalse,
        reason:
            'nothing in the app writes doc.ports, so this is the state of '
            'every pin on every document built from the palette',
      );
    });

    test('a materialised pin carries its Port and its real designator', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([_port('hdmi.out.1')]),
        materialise: {'hdmi.out.1'},
      );
      final t = _avrOut(doc);
      expect(t.isMaterialised, isTrue);
      expect(t.materialisedPort!.designator, 'J1');
      expect(
        t.plannedDesignator,
        isNull,
        reason:
            'an existing Port.designator is project state; nothing here '
            'proposes a replacement for one',
      );
      expect(
        t.citation,
        'AVR-1 J1',
        reason: 'the allocated designator wins over the template hint',
      );
    });

    test('AN UNMATERIALISED PIN IS CITED BY THE J-NUMBER IT WILL GET', () {
      // DR-011.5 wants "AVR-1 J03 already carries 1 of 1 connections", not
      // a generic string — and every pin is unmaterialised until a connect
      // succeeds, so this is the NORMAL case, not an edge. The number is
      // not invented: `PORT_SEQ` is the pin's position in its template's
      // declared order and the allocation is a pure function of the
      // document, so the J-number a refusal prints is the one the connect
      // would have written.
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([
          _port('hdmi.out.1'),
          _port('hdmi.out.2', order: 'a1'),
          _port('hdmi.out.3', order: 'a2'),
        ]),
      );
      final t = resolveConnectTarget(
        doc,
        deviceId: _avr,
        portKey: 'hdmi.out.3',
      )!;
      expect(t.isMaterialised, isFalse);
      expect(t.plannedDesignator, 'J03');
      expect(t.citation, 'AVR-1 J03');
      expect(
        allocatePortDesignatorFor(doc, t),
        t.plannedDesignator,
        reason:
            'the sentence and the connect must name the SAME jack — two '
            'code paths for one number is how they stop agreeing',
      );
    });

    test('the raw port key is the LAST resort, not the first', () {
      // The fallback chain only unwinds when the project's own
      // portDesignatorFormat cannot render: here it needs DEV_BLOCK, and
      // reserve-block allocation is not implemented anywhere in the repo.
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([_port('ir.out.3', label: 'IR OUT 3', hint: 'J34')]),
      );
      doc.settings.portDesignatorFormat = const IdFormat(
        '{DEV_BLOCK}{PORT_SEQ:2}',
      );

      final withHint = resolveConnectTarget(
        doc,
        deviceId: _avr,
        portKey: 'ir.out.3',
      )!;
      expect(
        withHint.plannedDesignator,
        isNull,
        reason: 'a sentence must not throw because a FORMAT SETTING is bad',
      );
      expect(withHint.citation, 'AVR-1 J34');

      // No hint — which is every one of the 727 seed ports — falls to the
      // silkscreen label before it falls to the machine key.
      final noHint = _doc();
      _addDevice(
        noHint,
        _avr,
        'AVR-1',
        _body([_port('ir.out.3', label: 'IR OUT 3')]),
      );
      noHint.settings.portDesignatorFormat = const IdFormat('{DEV_BLOCK}');
      expect(
        resolveConnectTarget(
          noHint,
          deviceId: _avr,
          portKey: 'ir.out.3',
        )!.citation,
        'AVR-1 IR OUT 3',
      );
    });

    test('a pattern with no sequence token falls back rather than hanging', () {
      // `portDesignatorFormat` is persisted as a raw string and decoded as
      // `IdFormat(raw)` with no token check, so `"J"` reaches here from a
      // file. It renders "J" for every PORT_SEQ; the second pin on the
      // device has nothing left to allocate, and the walk USED TO SPIN
      // FOREVER in a tight synchronous loop no timeout can interrupt.
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([_port('a'), _port('b', order: 'a1')]),
      );
      doc.settings.portDesignatorFormat = const IdFormat('J');
      final first = derivePortId(_avr, const PortKey('a'));
      doc.ports[first] = Port(id: first, deviceId: _avr, designator: 'J');

      final t = resolveConnectTarget(doc, deviceId: _avr, portKey: 'b')!;
      expect(t.plannedDesignator, isNull);
      expect(t.citation, 'AVR-1 b');
      expect(
        () => allocatePortDesignatorFor(doc, t),
        throwsA(isA<DesignatorExhaustedException>()),
        reason:
            'the COMMAND path must not invent a designator to keep quiet — '
            'it would print on a termination schedule (G4)',
      );
    });

    test('null for a missing device, a missing template, a missing key', () {
      final doc = _pair();
      expect(
        resolveConnectTarget(doc, deviceId: const Uuid('no'), portKey: 'x'),
        isNull,
      );
      expect(
        resolveConnectTarget(doc, deviceId: _avr, portKey: 'nope'),
        isNull,
      );
      doc.templates.clear();
      expect(
        resolveConnectTarget(doc, deviceId: _avr, portKey: 'hdmi.out.1'),
        isNull,
      );
    });
  });

  group('portConductorCount — PER PORT, not per device', () {
    test('counts ENDS, so a self-looped conductor consumes the pin twice', () {
      // TOP-001 makes this unreachable through a command; a hand-edited
      // or imported file can still carry one, and under-counting it makes
      // an over-subscribed jack read as legal.
      final doc = _pair();
      final a = _avrOut(doc).portId;
      _link(doc, 'W001', PortEndpoint(a), PortEndpoint(a));
      expect(portConductorCount(doc, a), 2);
    });

    test('ignores Open and Place endpoints', () {
      final doc = _pair();
      final a = _avrOut(doc).portId;
      _link(
        doc,
        'W001',
        const OpenEndpoint('coil'),
        const PlaceEndpoint(description: 'beam 3'),
      );
      expect(portConductorCount(doc, a), 0);
    });

    test('is NOT linkCountForDevice — two pins on one device differ', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([_port('a'), _port('b', order: 'a1')]),
      );
      final a = derivePortId(_avr, const PortKey('a'));
      final b = derivePortId(_avr, const PortKey('b'));
      doc.ports[a] = Port(id: a, deviceId: _avr, designator: 'J01');
      doc.ports[b] = Port(id: b, deviceId: _avr, designator: 'J02');
      _link(doc, 'W001', PortEndpoint(a), const OpenEndpoint('x'));
      _link(doc, 'W002', PortEndpoint(a), const OpenEndpoint('y'));

      expect(portConductorCount(doc, a), 2);
      expect(
        portConductorCount(doc, b),
        0,
        reason:
            'the per-DEVICE count is 2 for both pins; TOP-003 is bounded '
            'by a property of one jack and must not read the device total',
      );
      expect(linkCountForDevice(doc, _avr), 2);
    });
  });

  group('evaluateConnect — the tier-1 refusals', () {
    test('EVERY ConnectRule has a refusal case in this file', () {
      expect(
        _refusals().map((r) => r.rule).toSet(),
        ConnectRule.values.toSet(),
        reason:
            'a refusal mode with no exercised sentence is a spring-back '
            'the user cannot act on — DR-011.5 gives them no other '
            'recourse. Add a row above, do not relax this.',
      );
    });

    for (final c in _refusals()) {
      test('${c.rule.id} refuses when ${c.what}', () {
        final verdict = c.run();
        expect(verdict, isA<ConnectRefused>());
        final refused = verdict as ConnectRefused;
        expect(refused.rule, c.rule);
        expect(refused.ruleId, c.rule.id);
        expect(
          refused.message,
          endsWith('.'),
          reason: 'the sentence is read by a person, not parsed',
        );
        for (final needle in c.mustName) {
          expect(
            refused.message,
            contains(needle),
            reason:
                'the sentence must name what is actually involved — a '
                'generic string sends the user hunting: '
                '"${refused.message}"',
          );
        }
      });
    }

    test('no two rules share a sentence', () {
      final messages = <String, ConnectRule>{};
      for (final c in _refusals()) {
        final refused = c.run() as ConnectRefused;
        final clash = messages[refused.message];
        expect(
          clash,
          isNull,
          reason:
              '${c.rule.id} and ${clash?.id} produce the same sentence, so '
              'the user cannot tell which rule fired: "${refused.message}"',
        );
        messages[refused.message] = c.rule;
      }
      expect(messages, hasLength(ConnectRule.values.length));
    });

    test('TOP-005 also refuses a non-container host and a cycle', () {
      // Three distinct faults, one rule; the sentences differ so the user
      // is told which of the three they are looking at.
      final missingHost =
          _refusals()
                  .firstWhere((r) => r.rule == ConnectRule.hostResolves)
                  .run()
              as ConnectRefused;

      final notContainer = _doc();
      _addDevice(
        notContainer,
        _shelf,
        'SHF-1',
        _body(const []),
      );
      _addDevice(
        notContainer,
        _avr,
        'AVR-1',
        _body([_port('hdmi.out.1')]),
        placement: const ShelfPlacement(
          hostDeviceId: _shelf,
          order: FracIndex('a0'),
        ),
      );
      _addDevice(
        notContainer,
        _tv,
        'TV-1',
        _body([_port('hdmi.in.1')]),
      );
      final v1 = evaluateConnect(
        notContainer,
        _avrOut(notContainer),
        _tvIn(notContainer),
      );
      expect(v1, isA<ConnectRefused>());
      expect((v1 as ConnectRefused).rule, ConnectRule.hostResolves);
      expect(v1.message, contains('SHF-1'));
      expect(v1.message, isNot(missingHost.message));

      final cycle = _doc();
      _addDevice(
        cycle,
        _shelf,
        'SHF-1',
        _body(const [], isContainer: true),
        placement: const ShelfPlacement(
          hostDeviceId: _avr,
          order: FracIndex('a0'),
        ),
      );
      _addDevice(
        cycle,
        _avr,
        'AVR-1',
        _body([_port('hdmi.out.1')], isContainer: true),
        placement: const ShelfPlacement(
          hostDeviceId: _shelf,
          order: FracIndex('a0'),
        ),
      );
      _addDevice(
        cycle,
        _tv,
        'TV-1',
        _body([_port('hdmi.in.1')]),
      );
      final v2 = evaluateConnect(cycle, _avrOut(cycle), _tvIn(cycle));
      expect(v2, isA<ConnectRefused>());
      expect((v2 as ConnectRefused).rule, ConnectRule.hostResolves);
      expect(v2.message, contains('loops'));
      expect(v2.message, isNot(v1.message));
    });

    test('TOP-003 says a zero-max pin ACCEPTS NONE, not "0 of 0"', () {
      // "already carries 0 of 0" reads as a state the user could clear by
      // unplugging something. There is nothing to unplug.
      final doc = _pair(avrMax: 0);
      final v =
          evaluateConnect(doc, _avrOut(doc), _tvIn(doc)) as ConnectRefused;
      expect(v.rule, ConnectRule.withinMaxConnections);
      expect(v.message, 'AVR-1 J01 accepts no connections.');
    });

    test('TOP-002 is scoped to ONE link — a fresh link cannot duplicate', () {
      // Canon: "two conductors may not duplicate the same ordered port
      // pair ON THE SAME LINK". A second cable between the same two pins
      // is legal; reading the rule document-wide would make a redundant
      // run model-ILLEGAL with no escape, which is a rule canon does not
      // have (§5: "a rule not listed here does not exist").
      final doc = _pair(avrMax: 4, tvMax: 4);
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      _link(doc, 'W001', PortEndpoint(from.portId), PortEndpoint(to.portId));
      expect(
        evaluateConnect(doc, from, to),
        isA<ConnectAllowed>(),
        reason: 'no ontoLink means a NEW link, where TOP-002 cannot fire',
      );
    });

    test('TOP-002 ignores the REVERSED pair', () {
      final doc = _pair(avrMax: 4, tvMax: 4);
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      final id = _link(
        doc,
        'W001',
        PortEndpoint(to.portId),
        PortEndpoint(from.portId),
      );
      expect(
        evaluateConnect(doc, from, to, ontoLink: id),
        isA<ConnectAllowed>(),
        reason:
            'canon says "the same ORDERED port pair"; a reversed pair is '
            'DIR-001 business, and DIR-001 is tier 2 and deferred',
      );
    });
  });

  group('evaluateConnect — a legal pair is accepted', () {
    test('two unmaterialised pins on two devices connect', () {
      final doc = _pair();
      expect(
        evaluateConnect(doc, _avrOut(doc), _tvIn(doc)),
        isA<ConnectAllowed>(),
      );
    });

    test('a source-to-source pair is NOT refused — DIR-001 is tier 2', () {
      // The gesture may hesitate; the document may not lie (CR-017). A T2
      // condition implemented as a T1 refusal makes the product unable to
      // document a system it was called in to fix.
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([_port('hdmi.out.1')]),
      );
      _addDevice(
        doc,
        _tv,
        'TV-1',
        _body([_port('hdmi.in.1')]),
      );
      // Both declared `source`, which DIR-001 flags — in M5.
      for (final d in [_avr, _tv]) {
        final body = doc.templates['tpl.${d.v}@1']!.body;
        for (final p in body.ports) {
          p.direction = PortDirection.source;
        }
      }
      expect(
        evaluateConnect(doc, _avrOut(doc), _tvIn(doc)),
        isA<ConnectAllowed>(),
      );
    });

    test('a loopback between two DIFFERENT pins on one device is legal', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([
          _port('a'),
          _port('b', order: 'a1'),
        ]),
      );
      final a = resolveConnectTarget(doc, deviceId: _avr, portKey: 'a')!;
      final b = resolveConnectTarget(doc, deviceId: _avr, portKey: 'b')!;
      expect(evaluateConnect(doc, a, b), isA<ConnectAllowed>());
    });
  });

  group('TOP-004 — the limb the SHIPPED product can actually reach', () {
    // THE TOMBSTONE LIMB IS THE ONE NOTHING IN `lib/` WRITES. The only
    // mentions of `doc.tombstones` under lib/ are json_codec's
    // encode/decode and this rule's own read — no command creates one. A
    // DEVICE, by contrast, leaves the document every time the user
    // deletes one or undoes a placement, and `RemoveDeviceCommand.apply`
    // is a plain `doc.devices.remove(id)` whose own TODO records that it
    // does NOT clean up the ports and links that named it.
    //
    // So the device limb is the load-bearing one, and a covering test
    // that hand-fabricates a `Tombstone` does not exercise it: deleting
    // the containment check left the whole suite green.

    test('a device removed by RemoveDeviceCommand refuses the connect', () {
      final doc = _pair();
      // Both targets are resolved BEFORE the removal — which is exactly
      // the gesture: the user grabs a pin, and the device goes away
      // under them (a delete on another surface, or an undo).
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      expect(evaluateConnect(doc, from, to), isA<ConnectAllowed>());

      final controller = DocumentController(doc, clock: FixedClock(_when))
        ..run(RemoveDeviceCommand(id: _avr));
      expect(doc.devices.containsKey(_avr), isFalse);

      final verdict = evaluateConnect(doc, from, to);
      expect(
        verdict,
        isA<ConnectRefused>(),
        reason:
            'without this, TOP-005 returns null on a missing device by '
            'design, TOP-001/002 pass, and TOP-003 reads maxConnections '
            'off the captured PortDef snapshot and counts 0 live ends — '
            'so the connect is ALLOWED and materialises an orphan Port '
            'plus a Link with a dangling PortEndpoint',
      );
      final refused = verdict as ConnectRefused;
      expect(refused.rule, ConnectRule.endpointResolves);
      expect(refused.message, contains('AVR-1'));
      expect(refused.message, contains('no longer in this document'));

      // And an undo puts it back, so the same gesture is legal again.
      controller.undoLast();
      expect(evaluateConnect(doc, from, to), isA<ConnectAllowed>());
    });

    test('the removed device may be the TO end as well as the FROM end', () {
      final doc = _pair();
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      RemoveDeviceCommand(id: _tv).apply(doc);

      final refused = evaluateConnect(doc, from, to) as ConnectRefused;
      expect(refused.rule, ConnectRule.endpointResolves);
      expect(refused.message, contains('TV-1'));
    });
  });

  group('TOP-003 — the bound is EFFECTIVE maxConnections, not declared', () {
    // Not one seed-catalog port declares `maxConnections`: `PortBuilder.p`
    // never passes it, so all 727 take PortDef's default of 1. Eight are
    // declared `PortDirection.busNode` — a Cresnet drop, a 70 V speaker
    // tap — and a bus node bounded at one connection is not a bus. Under
    // a declared-is-effective reading, a two-keypad Cresnet run and a
    // two-pendant 70 V run are model-ILLEGAL with no escape, because
    // DR-011.5 gives T1 no [ Connect anyway ].

    /// CP-1 (one `busNode` bus pin) and two keypads, none materialised.
    RackDocument busDoc({
      PortDirection direction = PortDirection.busNode,
      PortTopology topology = PortTopology.p2p,
    }) {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'CP-1',
        _body([
          _port(
            'cresnet',
            family: 'ctl.cresnet',
            direction: direction,
            topology: topology,
          ),
        ]),
      );
      _addDevice(
        doc,
        _tv,
        'KP-1',
        _body([_port('cresnet', family: 'ctl.cresnet')]),
      );
      return doc;
    }

    test('a busNode pin takes a SECOND drop', () {
      final doc = busDoc();
      final bus = _pin(doc, _avr, 'cresnet');
      expect(bus.isMultidrop, isTrue);
      expect(
        bus.effectiveMaxConnections,
        isNull,
        reason: 'null is UNBOUNDED — a tap on a shared medium',
      );

      // KP-1 is already on the bus.
      _link(doc, 'W001', PortEndpoint(bus.portId), const OpenEndpoint('KP-1'));
      expect(portConductorCount(doc, bus.portId), 1);

      expect(
        evaluateConnect(doc, bus, _pin(doc, _tv, 'cresnet')),
        isA<ConnectAllowed>(),
        reason:
            'a two-keypad Cresnet bus is the normal case for C01 + 2x F13, '
            'and TOP-003 has no override to walk a wrong refusal back',
      );
    });

    test('a port-level `multidrop` topology says it just as well', () {
      // No seed port sets `topology` today — every one takes PortDef's
      // p2p default — but design-data-model.md:462 defines the field for
      // this fact, and an M4-authored template may use it alone.
      final doc = busDoc(
        direction: PortDirection.source,
        topology: PortTopology.multidrop,
      );
      final bus = _pin(doc, _avr, 'cresnet');
      expect(bus.isMultidrop, isTrue);
      expect(bus.effectiveMaxConnections, isNull);
    });

    test('a p2p pin is still bounded at 1 — this widens nothing else', () {
      final doc = busDoc(direction: PortDirection.source);
      final pin = _pin(doc, _avr, 'cresnet');
      expect(pin.isMultidrop, isFalse);
      expect(pin.effectiveMaxConnections, 1);

      _link(doc, 'W001', PortEndpoint(pin.portId), const OpenEndpoint('x'));
      final refused =
          evaluateConnect(doc, pin, _pin(doc, _tv, 'cresnet'))
              as ConnectRefused;
      expect(refused.rule, ConnectRule.withinMaxConnections);
      expect(refused.message, contains('1 of 1'));
    });

    test('a DECLARED bound above 1 wins over the bus fact', () {
      // `ir.out.1` in docs/catalog/seed-devices.md declares
      // `maxConnections: 2` — a real authored bound (two IR emitters on
      // one 3.5 mm output). Only the DEFAULT 1, which a template reaches
      // by saying nothing, yields to `busNode`.
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AMP-1',
        _body([
          _port(
            'cv.a',
            maxConnections: 2,
            direction: PortDirection.busNode,
          ),
        ]),
      );
      final pin = _pin(doc, _avr, 'cv.a');
      expect(pin.isMultidrop, isTrue);
      expect(pin.effectiveMaxConnections, 2);
    });

    test('a declared ZERO still means "not a socket", bus or not', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AMP-1',
        _body([
          _port(
            'cv.a',
            maxConnections: 0,
            direction: PortDirection.busNode,
          ),
        ]),
      );
      _addDevice(doc, _tv, 'SPK-1', _body([_port('in')]));
      final refused =
          evaluateConnect(doc, _pin(doc, _avr, 'cv.a'), _pin(doc, _tv, 'in'))
              as ConnectRefused;
      expect(refused.message, endsWith('accepts no connections.'));
    });

    test('THE REAL CATALOG: C01 + two F13 keypads is a legal bus', () {
      // The seed catalog itself, not a fixture: `ctl.cresnet` on C01 and
      // on F13 are both declared `BUS` (`PortDirection.busNode`), and
      // §4.4 gives the family `MD` topology.
      final doc = _doc();
      _seedDevice(doc, const Uuid('dev-cp'), 'C01', 'CP-1');
      _seedDevice(doc, const Uuid('dev-kp1'), 'F13', 'KP-1');
      _seedDevice(doc, const Uuid('dev-kp2'), 'F13', 'KP-2');

      final cp = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-cp'),
        portKey: 'cresnet',
      )!;
      expect(cp.direction, PortDirection.busNode);
      expect(
        cp.def.maxConnections,
        1,
        reason:
            'the DECLARED value: PortBuilder.p never passes maxConnections, '
            "so every catalog port takes PortDef's default",
      );
      expect(cp.effectiveMaxConnections, isNull);

      _link(doc, 'W001', PortEndpoint(cp.portId), const OpenEndpoint('KP-1'));
      final kp2 = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-kp2'),
        portKey: 'cresnet',
      )!;
      expect(evaluateConnect(doc, cp, kp2), isA<ConnectAllowed>());
    });

    test('THE REAL CATALOG: A05 70V out feeds two F08 pendants', () {
      final doc = _doc();
      _seedDevice(doc, const Uuid('dev-amp'), 'A05', 'AMP-1');
      _seedDevice(doc, const Uuid('dev-spk1'), 'F08', 'SPK-1');
      _seedDevice(doc, const Uuid('dev-spk2'), 'F08', 'SPK-2');

      final cv = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-amp'),
        portKey: 'cv.a',
      )!;
      _link(doc, 'W001', PortEndpoint(cv.portId), const OpenEndpoint('SPK-1'));

      final spk2 = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-spk2'),
        portKey: 'pos',
      )!;
      expect(
        evaluateConnect(doc, cv, spk2),
        isA<ConnectAllowed>(),
        reason:
            "A05's own catalog note reads 'a constant-voltage BUS output, "
            "not OUT (a 70V run is a multi-tap bus)'",
      );
    });
  });

  group('evaluateConnect — first failure wins, in the documented order', () {
    test('the enum declares the order the evaluation uses', () {
      expect(
        ConnectRule.values.map((r) => r.id).toList(),
        ['TOP-004', 'TOP-005', 'TOP-001', 'TOP-002', 'TOP-003'],
        reason:
            'ConnectRule.values IS the first-failure-wins order — if this '
            'list changes, the pair tests below are what say whether the '
            'new order was intended',
      );
    });

    test('TOP-004 beats TOP-005', () {
      final doc = _pair();
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      doc.tombstones[from.portId] = Tombstone(
        deletedAt: _when,
        entityType: 'Port',
        by: 'test',
      );
      doc.devices[_avr] = DeviceInstance(
        id: _avr,
        kind: DeviceKind.rackDevice,
        templateRef: doc.devices[_avr]!.templateRef,
        designator: 'AVR-1',
        name: 'AVR-1',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('dev-gone'),
          order: FracIndex('a0'),
        ),
        meta: _meta(),
      );
      expect(
        (evaluateConnect(doc, from, to) as ConnectRefused).rule,
        ConnectRule.endpointResolves,
      );
    });

    test('TOP-005 beats TOP-001', () {
      final doc = _pair();
      final from = _avrOut(doc);
      doc.devices[_avr] = DeviceInstance(
        id: _avr,
        kind: DeviceKind.rackDevice,
        templateRef: doc.devices[_avr]!.templateRef,
        designator: 'AVR-1',
        name: 'AVR-1',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('dev-gone'),
          order: FracIndex('a0'),
        ),
        meta: _meta(),
      );
      expect(
        (evaluateConnect(doc, from, from) as ConnectRefused).rule,
        ConnectRule.hostResolves,
      );
    });

    test('TOP-001 beats TOP-002', () {
      final doc = _pair(avrMax: 4);
      final from = _avrOut(doc);
      final id = _link(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(from.portId),
      );
      expect(
        (evaluateConnect(doc, from, from, ontoLink: id) as ConnectRefused).rule,
        ConnectRule.notSelf,
        reason:
            '"you already ran this cable" names the wrong problem for a '
            'wire dropped back on the pin it came from',
      );
    });

    test('TOP-002 beats TOP-003', () {
      final doc = _pair();
      final from = _avrOut(doc);
      final to = _tvIn(doc);
      final id = _link(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      final v = evaluateConnect(doc, from, to, ontoLink: id) as ConnectRefused;
      expect(
        v.rule,
        ConnectRule.notDuplicatePair,
        reason:
            'the pin being full is the CONSEQUENCE of the duplicate; a '
            'user told only the consequence frees a port they need',
      );
    });
  });

  group('DR-012.3 — acceptsFamily, and the third empty field', () {
    test('a pin always accepts its OWN family, declared list or not', () {
      final doc = _doc();
      _addDevice(doc, _avr, 'AVR-1', _body([_port('out', family: 'a.b')]));
      final t = resolveConnectTarget(doc, deviceId: _avr, portKey: 'out')!;
      expect(t.acceptsFamily(const SignalFamilyId('a.b')), isTrue);
      expect(t.acceptsFamily(const SignalFamilyId('c.d')), isFalse);
    });

    test('NOT ONE seed catalog port declares acceptedFamilies, which is '
        'why this is an effective* getter and not a field read', () {
      // The same arithmetic that produced effectiveMaxConnections in
      // Phase 0 and that DR-012 records for channelIndex. If this ever
      // fails, the catalog has started declaring exclusions and the
      // fallback below stops being the only branch real data reaches.
      final catalog = buildSeedCatalog();
      final declaring = <String>[];
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          if (port.acceptedFamilies.isNotEmpty) {
            declaring.add('${entry.key}/${port.key.v}');
          }
        }
      }
      expect(declaring, isEmpty);
    });

    test('a DECLARED list widens the pin, and never narrows it below its '
        'own family', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'AVR-1',
        _body([
          PortDef(
            key: const PortKey('out'),
            label: 'OUT',
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('video.hdbaset'),
            face: Face.rear,
            position: _pos,
            order: const FracIndex('a0'),
            // The exclusion case seed_registries.dart:394 describes,
            // authored the other way round: a pin that also takes IR.
            acceptedFamilies: const [SignalFamilyId('ctl.ir')],
          ),
        ]),
      );
      final t = resolveConnectTarget(doc, deviceId: _avr, portKey: 'out')!;
      expect(t.acceptsFamily(const SignalFamilyId('ctl.ir')), isTrue);
      expect(
        t.acceptsFamily(const SignalFamilyId('video.hdbaset')),
        isTrue,
        reason: 'a template that excluded its own signalFamily would be '
            'describing a jack that cannot carry what it is',
      );
      expect(t.acceptsFamily(const SignalFamilyId('net.ethernet')), isFalse);
    });
  });

  group('DR-012.1 — chainOutputFor, the "matching output"', () {
    RackDocument withChainDevice({
      int maxConnections = 1,
      String outFamily = 'video.hdmi.2_1',
    }) {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'MTX-1',
        _body([
          _port('in.1', direction: PortDirection.sink),
          _port(
            'out.1',
            direction: PortDirection.source,
            order: 'a1',
            family: outFamily,
            maxConnections: maxConnections,
          ),
          _port(
            'out.2',
            direction: PortDirection.source,
            order: 'a2',
            family: outFamily,
          ),
        ]),
      );
      return doc;
    }

    test('it is the first FREE output of the SAME family, in template '
        'order', () {
      final doc = withChainDevice();
      final next = chainOutputFor(
        doc,
        deviceId: _avr,
        family: const SignalFamilyId('video.hdmi.2_1'),
      );
      expect(next!.portKey.v, 'out.1');
    });

    test('a FULL output is skipped and the next one wins — the chain does '
        'not stop at an occupied jack', () {
      final doc = withChainDevice();
      _link(
        doc,
        'W1',
        PortEndpoint(derivePortId(_avr, const PortKey('out.1'))),
        const OpenEndpoint('to the field'),
      );
      expect(
        chainOutputFor(
          doc,
          deviceId: _avr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        )!.portKey.v,
        'out.2',
      );
    });

    test('a SINK is never the answer, however well its family matches', () {
      // The whole point of "output": a chain that re-armed from an input
      // would draw a cable back the way it came.
      final doc = withChainDevice();
      _link(
        doc,
        'W1',
        PortEndpoint(derivePortId(_avr, const PortKey('out.1'))),
        const OpenEndpoint('to the field'),
      );
      _link(
        doc,
        'W2',
        PortEndpoint(derivePortId(_avr, const PortKey('out.2'))),
        const OpenEndpoint('to the field'),
      );
      expect(
        chainOutputFor(
          doc,
          deviceId: _avr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        ),
        isNull,
        reason: 'both outputs are full and in.1 is a sink, so the chain '
            'ends rather than turning round',
      );
    });

    test('a different family ends the chain rather than proposing a jack '
        'that cannot carry it', () {
      final doc = withChainDevice();
      expect(
        chainOutputFor(
          doc,
          deviceId: _avr,
          family: const SignalFamilyId('audio.speaker'),
        ),
        isNull,
      );
    });

    test('a BUS NODE is a valid chain output — reading `source` alone '
        'would end the chain at every bus device in the catalog', () {
      final doc = _doc();
      _addDevice(
        doc,
        _avr,
        'IRB-1',
        _body([
          _port(
            'bus.1',
            direction: PortDirection.busNode,
            family: 'ctl.ir',
          ),
        ]),
      );
      final next = chainOutputFor(
        doc,
        deviceId: _avr,
        family: const SignalFamilyId('ctl.ir'),
      );
      expect(next, isNotNull);
      expect(
        next!.effectiveMaxConnections,
        isNull,
        reason: 'and it stays available, because a bus tap is unbounded',
      );
    });

    test('a device that is not in the document is null, not a throw', () {
      expect(
        chainOutputFor(
          _doc(),
          deviceId: _avr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        ),
        isNull,
      );
    });
  });
}
