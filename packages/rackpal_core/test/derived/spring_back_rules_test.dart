// The six tier-2 rules (`#272`..`#277`, M5-D, docs/02 §5.2).
//
// ═══════════════════════════════════════════════════════════════════════
// BOTH TABLES, GATED, FROM THE FIRST COMMIT
// ═══════════════════════════════════════════════════════════════════════
// `connect_rules_test.dart` shipped a gated table of refusals and went
// four milestones before anything checked the other direction; M5-C added
// that half and mutation-tested it. This file starts with both, so a
// seventh rule cannot arrive with a known-bad and no near-miss, and so a
// rule written as `return chip` fails on sight.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 9, 3);
const _a = Uuid('dev-a');
const _b = Uuid('dev-b');

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(
  String key,
  String family, {
  PortDirection dir = PortDirection.source,
  String connector = 'conn.rj45',
  List<String> accepts = const [],
  ReturnChannel? returnChannel,
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _pos,
  order: const FracIndex('a0'),
  direction: dir,
  returnChannel: returnChannel,
  acceptedFamilies: [for (final f in accepts) SignalFamilyId(f)],
  maxConnections: 4,
);

/// Two devices, one port each, so every case below is exactly the pair
/// under test with nothing else able to fire.
RackDocument _pair(
  PortDef fromPort,
  PortDef toPort, {
  bool toIsPassthrough = false,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-t2'),
    appVersion: '0.5.22',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  _add(doc, _a, 'SRC-1', fromPort, isPassthrough: false);
  _add(doc, _b, 'DST-1', toPort, isPassthrough: toIsPassthrough);
  return doc;
}

void _add(
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
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

SpringBackVerdict _run(RackDocument doc) => evaluateSpringBack(
  doc,
  resolveConnectTarget(doc, deviceId: _a, portKey: 'p')!,
  resolveConnectTarget(doc, deviceId: _b, portKey: 'p')!,
);

typedef _Case = ({
  SpringBackRule rule,
  String what,
  RackDocument Function() doc,
});

/// One known-bad per rule. The coverage test below compares this against
/// `SpringBackRule.values`.
List<_Case> _chips() => [
  (
    rule: SpringBackRule.hdbasetIntoEthernet,
    what: 'HDBaseT lands on a terminating Ethernet port',
    doc: () => _pair(
      _port('p', 'video.hdbaset'),
      _port('p', 'net.ethernet', dir: PortDirection.sink),
    ),
  ),
  (
    rule: SpringBackRule.irEmitterIntoReceiver,
    what: 'an IR emitter output lands on an IR receiver jack',
    doc: () => _pair(
      _port('p', 'ctl.ir_emitter', connector: 'conn.3_5mm_ts'),
      _port(
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
    doc: () => _pair(
      _port('p', 'audio.speaker_cv', connector: 'conn.euroblock_2'),
      _port(
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
    doc: () => _pair(
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
    ),
  ),
  (
    rule: SpringBackRule.familyNotAccepted,
    what: 'the sink does not accept the source family',
    doc: () => _pair(
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
      _port(
        'p',
        'audio.analog_bal',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
      ),
    ),
  ),
  (
    rule: SpringBackRule.connectorsDoNotMate,
    what: 'the connectors do not mate and no adapter is declared',
    doc: () => _pair(
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
      _port(
        'p',
        'video.hdmi',
        dir: PortDirection.sink,
        connector: 'conn.xlr3_f',
        accepts: ['video.hdmi'],
      ),
    ),
  ),
];

/// One known-good near-miss per rule, ONE PROPERTY from its bad case.
List<_Case> _nearMisses() => [
  (
    rule: SpringBackRule.hdbasetIntoEthernet,
    what:
        'the Ethernet port is on a PASSTHROUGH, so the joint is a patch '
        'panel and the switch question is a path question (DR-113)',
    doc: () => _pair(
      _port('p', 'video.hdbaset'),
      _port('p', 'net.ethernet', dir: PortDirection.sink),
      toIsPassthrough: true,
    ),
  ),
  (
    rule: SpringBackRule.irEmitterIntoReceiver,
    what:
        'the far end is an emitter port too, which is what an IR '
        'connecting block offers',
    doc: () => _pair(
      _port('p', 'ctl.ir_emitter', connector: 'conn.3_5mm_ts'),
      _port(
        'p',
        'ctl.ir_emitter',
        dir: PortDirection.sink,
        connector: 'conn.3_5mm_ts',
      ),
    ),
  ),
  (
    rule: SpringBackRule.speakerImpedanceMismatch,
    what: 'both ends are constant voltage',
    doc: () => _pair(
      _port('p', 'audio.speaker_cv', connector: 'conn.euroblock_2'),
      _port(
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
    doc: () => _pair(
      _port(
        'p',
        'video.hdmi',
        connector: 'conn.hdmi_a',
        returnChannel: ReturnChannel.eArc,
      ),
      _port(
        'p',
        'video.hdmi',
        connector: 'conn.hdmi_a',
        returnChannel: ReturnChannel.eArc,
      ),
    ),
  ),
  (
    rule: SpringBackRule.familyNotAccepted,
    what: 'the sink DECLARES the source family in acceptedFamilies',
    doc: () => _pair(
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
      _port(
        'p',
        'audio.analog_bal',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
        accepts: ['video.hdmi'],
      ),
    ),
  ),
  (
    rule: SpringBackRule.connectorsDoNotMate,
    what: 'the connectors mate',
    doc: () => _pair(
      _port('p', 'video.hdmi', connector: 'conn.hdmi_a'),
      _port(
        'p',
        'video.hdmi',
        dir: PortDirection.sink,
        connector: 'conn.hdmi_a',
        accepts: ['video.hdmi'],
      ),
    ),
  ),
];

void main() {
  group('every rule springs back on its own known-bad', () {
    test('EVERY SpringBackRule has one in this file', () {
      expect(
        _chips().map((c) => c.rule).toSet(),
        SpringBackRule.values.toSet(),
        reason:
            'a tier-2 rule with no exercised chip is a spring-back whose '
            'sentence nobody has read. Add a row, do not relax this.',
      );
    });

    for (final c in _chips()) {
      test('${c.rule.id} springs back when ${c.what}', () {
        final verdict = _run(c.doc());
        expect(verdict, isA<SpringBackChip>());
        final chip = verdict as SpringBackChip;
        expect(chip.rule, c.rule);
        expect(chip.ruleId, c.rule.id);
        // Both lines are a person's, not a log's: the headline names the
        // pins and the explanation says why it matters.
        expect(chip.headline, endsWith('.'));
        expect(chip.explanation, endsWith('.'));
        expect(chip.headline, isNot(contains(c.rule.id)));
      });
    }

    test('no two rules share a headline, so a person can tell which one '
        'fired', () {
      final seen = <String, SpringBackRule>{};
      for (final c in _chips()) {
        final chip = _run(c.doc()) as SpringBackChip;
        expect(seen[chip.headline], isNull, reason: chip.headline);
        seen[chip.headline] = c.rule;
      }
      expect(seen, hasLength(SpringBackRule.values.length));
    });
  });

  group('and clears on the case one property away (AC-051)', () {
    test('EVERY SpringBackRule has a near-miss in this file', () {
      expect(
        _nearMisses().map((c) => c.rule).toSet(),
        SpringBackRule.values.toSet(),
        reason:
            'a rule with a known-bad and no near-miss is proven to FIRE '
            'and not proven to DISCRIMINATE',
      );
    });

    for (final c in _nearMisses()) {
      test('${c.rule.id} clears when ${c.what}', () {
        expect(
          _run(c.doc()),
          isA<SpringBackClear>(),
          reason:
              '${c.rule.id} sprang back on a case one property from its '
              'own known-bad, so the rule is wider than the catalogue says',
        );
      });
    }

    test('the two tables stay the same size, so neither can grow alone', () {
      expect(_nearMisses(), hasLength(_chips().length));
    });
  });

  group('the chip carries what CR-017 says it must', () {
    test('SIG-001 offers the remedy that INSERTS A DEVICE (CR-015), and it '
        'is the only rule with one', () {
      for (final c in _chips()) {
        final chip = _run(c.doc()) as SpringBackChip;
        if (c.rule == SpringBackRule.hdbasetIntoEthernet) {
          expect(chip.remedies, [SpringBackRemedy.insertHdbasetReceiver]);
        } else {
          expect(
            chip.remedies,
            isEmpty,
            reason:
                'docs/02 §5.2 names a remedy for SIG-001 and for no other '
                'rule; inventing one puts words in a designer mouth',
          );
        }
      }
    });

    test('[ Connect anyway ] is NOT a remedy value, so no chip can ship '
        'without it', () {
      // DR-011.5 gives tier 2 its escape hatch unconditionally. Making it
      // per-rule data is how a chip ends up without one.
      for (final remedy in SpringBackRemedy.values) {
        expect(remedy.label.toLowerCase(), isNot(contains('anyway')));
        expect(remedy.label.toLowerCase(), isNot(contains('why')));
        expect(remedy.label.toLowerCase(), isNot(contains('different port')));
      }
    });
  });

  group('the catalogue and the predicates agree', () {
    test('every SpringBackRule is a tier-2 catalogue rule with a severity', () {
      for (final rule in SpringBackRule.values) {
        final meta = kRulesById[rule.id];
        expect(meta, isNotNull, reason: rule.id);
        expect(meta!.tier, RuleTier.springBack, reason: rule.id);
        expect(meta.defaultSeverity, isNotNull, reason: rule.id);
      }
    });

    test('and every tier-2 rule in the catalogue has a predicate here, so '
        'the six are the six', () {
      expect(
        SpringBackRule.values.map((r) => r.id).toSet(),
        {for (final r in rulesInTier(RuleTier.springBack)) r.ruleId},
      );
    });
  });
}
