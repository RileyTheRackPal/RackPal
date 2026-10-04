// DR-234 (canon §11.233): tier 2 over a gesture that makes several pairs.
//
// THE CASE THIS FILE EXISTS FOR is `#909`'s: a stereo pair on two 3-pin
// blocks dropped on an XLR pair. The set gesture committed it on tier 1
// alone, a cable with no `CON-001` chip, where the pin gesture springs each
// half back. Every case plans a real set connect and asks the evaluator
// about the pairs that plan would write, so what is asserted is the chip a
// person would see on that drop, not a pairing this file made up.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 4);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _src = Uuid('dev-src');
const _dst = Uuid('dev-dst');

/// One jack of a set: key, role, connector and family.
typedef _Jack = (String, String, String, String);

TemplateBody _setBody(String setKey, List<_Jack> jacks, PortDirection dir) =>
    TemplateBody(
      manufacturer: 'Test',
      model: setKey,
      displayName: setKey,
      portSets: [
        PortSetDef(key: setKey, label: '$setKey set', kind: SetKind.stereoPair),
      ],
      ports: [
        for (final (i, j) in jacks.indexed)
          PortDef(
            key: PortKey(j.$1),
            label: j.$1.toUpperCase(),
            connector: ConnectorTypeId(j.$3),
            signalFamily: SignalFamilyId(j.$4),
            face: Face.rear,
            position: _pos,
            order: FracIndex('a$i'),
            direction: dir,
            setKey: setKey,
            setRole: j.$2,
          ),
      ],
    );

void _add(RackDocument doc, Uuid id, TemplateBody body) {
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
    designator: id == _src ? 'V-1' : 'A-1',
    name: id.v,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// A source set of [from] jacks and a target set of [to] jacks, planned.
AtomicConnectPlan _plan(List<_Jack> from, List<_Jack> to) {
  final doc = _doc(from, to);
  final result = planAtomicConnect(
    doc,
    fromDeviceId: _src,
    fromSetKey: 'out',
    toDeviceId: _dst,
    toSetKey: 'in',
  );
  expect(result, isA<AtomicConnectReady>(), reason: 'tier 1 must allow it');
  return (result! as AtomicConnectReady).plan;
}

RackDocument _doc(List<_Jack> from, List<_Jack> to) {
  final doc = RackDocument(
    id: const Uuid('doc-psb'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  _add(doc, _src, _setBody('out', from, PortDirection.source));
  _add(doc, _dst, _setBody('in', to, PortDirection.sink));
  return doc;
}

PairedSpringBack? _ask(
  List<_Jack> from,
  List<_Jack> to, {
  PairedGesture gesture = PairedGesture.set,
}) {
  final doc = _doc(from, to);
  final plan = _plan(from, to);
  return evaluatePairedSpringBack(doc, [
    for (final p in plan.pairs) (p.from, p.to),
  ], gesture: gesture);
}

const _bal = 'audio.line_bal';
const _Jack _euroL = ('aud.l', 'L', 'conn.euroblock_3', _bal);
const _Jack _euroR = ('aud.r', 'R', 'conn.euroblock_3', _bal);
const _Jack _xlrL = ('bal.l', 'L', 'conn.xlr3', _bal);
const _Jack _xlrR = ('bal.r', 'R', 'conn.xlr3', _bal);
const _Jack _euroInL = ('bal.l', 'L', 'conn.euroblock_3', _bal);
const _Jack _euroInR = ('bal.r', 'R', 'conn.euroblock_3', _bal);

void main() {
  group('the plan carries its pairs (DR-234 §11.233.1)', () {
    test('one pair per paired position, in declared order', () {
      final plan = _plan([_euroL, _euroR], [_xlrL, _xlrR]);
      expect(plan.pairs.map((p) => p.position), [0, 1]);
      expect(plan.pairs.map((p) => p.from.def.key.v), ['aud.l', 'aud.r']);
      expect(plan.pairs.map((p) => p.to.def.key.v), ['bal.l', 'bal.r']);
      expect(plan.pairs.length, plan.pairedCount);
    });

    test('AN OPEN POSITION HAS NO PAIR and is not asked', () {
      final plan = _plan([_euroL, _euroR], [_xlrL]);
      expect(plan.openCount, 1);
      expect(plan.pairs.map((p) => p.position), [0]);
    });
  });

  group('the set gesture (#909)', () {
    test('a matched pair is clear', () {
      expect(_ask([_euroL, _euroR], [_euroInL, _euroInR]), isNull);
    });

    test("THE TICKET'S CASE: a 3-pin pair onto an XLR pair springs back on "
        'CON-001, naming the first pair and counting both', () {
      final verdict = _ask([_euroL, _euroR], [_xlrL, _xlrR]);
      expect(verdict, isNotNull, reason: 'this committed with no chip');
      final chip = verdict!.chip;
      expect(chip.ruleId, 'CON-001');
      expect(chip.headline, contains('V-1'));
      expect(verdict.from.def.key.v, 'aud.l');
      expect(verdict.to.def.key.v, 'bal.l');
      expect(
        chip.explanation,
        endsWith(" 2 of this cable's 2 paired conductors spring back."),
      );
      expect(verdict.failing, 2);
      expect(verdict.asked, 2);
      expect(
        chip.remedies,
        [SpringBackRemedy.declareAdapter],
        reason:
            'one adapter on the cable clears every conductor, since '
            'CON-001 reads adapters per cable (§11.233.4)',
      );
    });

    test('only the second pair failing names the SECOND pair', () {
      final verdict = _ask([_euroL, _euroR], [_euroInL, _xlrR]);
      expect(verdict!.from.def.key.v, 'aud.r');
      expect(verdict.to.def.key.v, 'bal.r');
      expect(
        verdict.chip.explanation,
        endsWith(" 1 of this cable's 2 paired conductors springs back."),
      );
    });

    test('ANOTHER RULE ON ANOTHER PAIR WITHDRAWS THE ADAPTER', () {
      // Position 0 fails CON-001 alone; position 1 fails SIG-002. An
      // adapter would clear the first and commit past the second.
      const hdmi = ('bal.r', 'R', 'conn.xlr3', 'video.hdmi.2_0');
      final verdict = _ask([_euroL, _euroR], [_xlrL, hdmi]);
      expect(verdict!.chip.ruleId, 'CON-001', reason: 'first pair wins');
      expect(verdict.failing, 2);
      expect(verdict.chip.remedies, isEmpty);
    });

    test('A DEVICE-INSERTING REMEDY IS WITHHELD ON A SET', () {
      // SIG-002's own chip offers a converter, which wires two pin cables
      // and would split the one-cable set apart.
      const hdmiL = ('bal.l', 'L', 'conn.euroblock_3', 'video.hdmi.2_0');
      const hdmiR = ('bal.r', 'R', 'conn.euroblock_3', 'video.hdmi.2_0');
      final doc = _doc([_euroL, _euroR], [hdmiL, hdmiR]);
      final plan = _plan([_euroL, _euroR], [hdmiL, hdmiR]);
      final alone = evaluateSpringBack(
        doc,
        plan.pairs.first.from,
        plan.pairs.first.to,
      );
      expect(alone, isA<SpringBackChip>());
      expect(
        (alone as SpringBackChip).remedies,
        isNotEmpty,
        reason: 'the control: the pin gesture offers a remedy here',
      );
      final verdict = _ask([_euroL, _euroR], [hdmiL, hdmiR]);
      expect(verdict!.chip.ruleId, alone.ruleId);
      expect(verdict.chip.remedies, isEmpty);
    });
  });

  group('multi-draw (#999)', () {
    test('counts CABLES and offers no rule-specific remedy (§11.233.5)', () {
      final verdict = _ask(
        [_euroL, _euroR],
        [_xlrL, _xlrR],
        gesture: PairedGesture.multiDraw,
      );
      expect(verdict!.chip.ruleId, 'CON-001');
      expect(
        verdict.chip.explanation,
        endsWith(' 2 of the 2 cables spring back.'),
      );
      expect(verdict.chip.remedies, isEmpty);
    });
  });
}
