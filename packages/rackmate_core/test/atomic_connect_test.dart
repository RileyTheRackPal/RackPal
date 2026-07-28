// DR-008 §11.8.3 — the atomicConnect gesture.
//
// THE CASE THIS FILE EXISTS FOR is `a hole is an open end, not a shift`.
// A member the document has not materialised cannot carry a port end, and
// the tempting implementation filters those out and zips what remains. Do
// that and dropping an unmaterialised `L` slides `R` into index 0, so the
// gesture lands the right cable on the WRONG PIN — silently, with a
// complete-looking Link and a schedule that agrees with it all the way to
// the field. Position is the contract.
//
// The second reason this file exists is that the mismatched-set case is
// the whole point of the ruling. AC-053 raises "what happens when a
// 3-member set is dragged onto a 2-member set" in its own diagnosis and
// leaves it open; §11.8.3 answers CONNECT WHAT FITS AND WARN, chosen by
// the user against a recommendation to refuse. A gesture that quietly
// refused would pass a test suite that only checked matched sets.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 28);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _devA = Uuid('dev-a');
const _devB = Uuid('dev-b');

/// A body declaring one set whose members are `(portKey, setRole)` in the
/// order given — `order` is assigned ascending, so declared order IS list
/// order.
TemplateBody _body(String setKey, List<(String, String?)> members) =>
    TemplateBody(
      manufacturer: 'Acme',
      model: 'T',
      displayName: 'T',
      portSets: [
        PortSetDef(key: setKey, label: '$setKey set', kind: SetKind.stereoPair),
      ],
      ports: [
        for (var i = 0; i < members.length; i++)
          PortDef(
            key: PortKey(members[i].$1),
            label: members[i].$1,
            connector: const ConnectorTypeId('conn.rca'),
            signalFamily: const SignalFamilyId('audio.line_unbal'),
            face: Face.rear,
            position: _pos,
            order: FracIndex('a$i'),
            setKey: setKey,
            setRole: members[i].$2,
          ),
      ],
    );

/// A body whose ports are LISTED in one order and ORDERED in another, so
/// a test can tell which one the resolver actually uses.
TemplateBody _bodyOutOfOrder(
  String setKey,
  List<(String, String?, String)> members,
) => TemplateBody(
  manufacturer: 'Acme',
  model: 'T',
  displayName: 'T',
  portSets: [
    PortSetDef(key: setKey, label: '$setKey set', kind: SetKind.stereoPair),
  ],
  ports: [
    for (final m in members)
      PortDef(
        key: PortKey(m.$1),
        label: m.$1,
        connector: const ConnectorTypeId('conn.rca'),
        signalFamily: const SignalFamilyId('audio.line_unbal'),
        face: Face.rear,
        position: _pos,
        order: FracIndex(m.$3),
        setKey: setKey,
        setRole: m.$2,
      ),
  ],
);

/// Adds [id] with [body], materialising every port EXCEPT those in
/// [unmaterialised] — the state a document reaches when ports were never
/// created, or were created from a different template version.
void _addDevice(
  RackDocument doc,
  Uuid id,
  String tplId,
  TemplateBody body, {
  Set<String> unmaterialised = const {},
}) {
  final ref = TemplateRef(
    templateId: TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
  );
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
    templateRef: ref,
    designator: id.v.toUpperCase(),
    name: id.v,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  for (final p in body.ports) {
    if (unmaterialised.contains(p.key.v)) continue;
    final pid = derivePortId(id, p.key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: '${id.v}-${p.key.v}',
      templatePortKey: p.key,
    );
  }
}

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-ac'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

AtomicConnectPlan? _plan(RackDocument doc) => planAtomicConnect(
  doc,
  fromDeviceId: _devA,
  fromSetKey: 'sa',
  toDeviceId: _devB,
  toSetKey: 'sb',
);

Uuid _portOf(Uuid device, String key) => derivePortId(device, PortKey(key));

void main() {
  group('planAtomicConnect — matched sets', () {
    test('pairs 1:1 in declared order and reports complete', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L'), ('r', 'R')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      final plan = _plan(doc)!;
      expect(plan.conductors, hasLength(2));
      expect(plan.pairedCount, 2);
      expect(plan.openCount, 0);
      expect(plan.isComplete, isTrue);
      expect(plan.roleMismatches, isEmpty);

      expect(
        (plan.conductors[0].from as PortEndpoint).portId,
        _portOf(_devA, 'l'),
      );
      expect(
        (plan.conductors[0].to as PortEndpoint).portId,
        _portOf(_devB, 'l'),
      );
      expect(
        (plan.conductors[1].from as PortEndpoint).portId,
        _portOf(_devA, 'r'),
      );
      expect(
        (plan.conductors[1].to as PortEndpoint).portId,
        _portOf(_devB, 'r'),
      );
    });

    test('DECLARED ORDER is PortDef.order, not list position', () {
      // Device A lists `r` first but orders it second. "The set's declared
      // order" is the template author's `order`, so the pairing must follow
      // that — a resolver that trusts list position wires A.r to B.l.
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _bodyOutOfOrder('sa', [('r', 'R', 'a1'), ('l', 'L', 'a0')]),
      );
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      final plan = _plan(doc)!;
      expect(
        (plan.conductors[0].from as PortEndpoint).portId,
        _portOf(_devA, 'l'),
        reason:
            'A.l is declared first by `order` even though it is listed '
            'second; dropping the sort wires A.r onto B.l',
      );
      expect(
        (plan.conductors[1].from as PortEndpoint).portId,
        _portOf(_devA, 'r'),
      );
      expect(plan.roleMismatches, isEmpty);
    });

    test('carries setRole onto the conductor', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('p', '+'), ('n', '-')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('p', '+'), ('n', '-')]));

      final plan = _plan(doc)!;
      expect(plan.conductors.map((c) => c.role), ['+', '-']);
    });
  });

  group('planAtomicConnect — the mismatched sets AC-053 left open', () {
    test('CONNECTS WHAT FITS AND WARNS — it does not refuse', () {
      // Three members onto two: the exact case in AC-053's diagnosis.
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('y', 'Y'), ('pb', 'Pb'), ('pr', 'Pr')]),
      );
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      final plan = _plan(doc)!;
      expect(
        plan,
        isNotNull,
        reason:
            'the gesture must not refuse — §11.8.3, chosen by the user '
            'against a recommendation to refuse',
      );
      expect(plan.conductors, hasLength(3));
      expect(plan.pairedCount, 2);
      expect(plan.openCount, 1);
      expect(plan.isComplete, isFalse);

      // The third member landed one end and left the other open.
      final third = plan.conductors[2];
      expect((third.from as PortEndpoint).portId, _portOf(_devA, 'pr'));
      expect(
        third.to,
        isA<OpenEndpoint>(),
        reason:
            'an unpaired member becomes a Conductor with an OpenEndpoint — '
            'the fact M5 reads, so the half-connected run is derivable and '
            'not lost',
      );
    });

    test('the open end names why it is open', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L'), ('r', 'R')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));

      final plan = _plan(doc)!;
      expect(
        (plan.conductors[1].to as OpenEndpoint).description,
        contains('sb'),
      );
    });

    test('the SHORTER side may be the target', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      final plan = _plan(doc)!;
      expect(plan.conductors, hasLength(2));
      expect(plan.openCount, 1);
      expect(
        plan.conductors[1].from,
        isA<OpenEndpoint>(),
        reason: 'the open end belongs on the side that ran out',
      );
      expect(
        (plan.conductors[1].to as PortEndpoint).portId,
        _portOf(_devB, 'r'),
      );
    });
  });

  group('planAtomicConnect — a hole is an open end, NOT a shift', () {
    test('AN UNMATERIALISED MEMBER DOES NOT SLIDE ITS SUCCESSOR UP', () {
      // `l` is declared on device A but never materialised. If the
      // implementation filters unmaterialised members before zipping, `r`
      // becomes index 0 and gets wired to device B's `l` — the right cable
      // on the wrong pin, with nothing downstream able to notice.
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'l'},
      );
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      final plan = _plan(doc)!;
      expect(plan.conductors, hasLength(2));

      // Position 0: A's `l` is missing, so that end is open — B's `l` is
      // NOT stolen by A's `r`.
      expect(plan.conductors[0].from, isA<OpenEndpoint>());
      expect(
        (plan.conductors[0].to as PortEndpoint).portId,
        _portOf(_devB, 'l'),
      );

      // Position 1: the pin that matters.
      expect(
        (plan.conductors[1].from as PortEndpoint).portId,
        _portOf(_devA, 'r'),
      );
      expect(
        (plan.conductors[1].to as PortEndpoint).portId,
        _portOf(_devB, 'r'),
        reason:
            'A.r must land on B.r. A filtered zip lands it on B.l and every '
            'sheet agrees with the mis-wiring',
      );
      expect(plan.pairedCount, 1);
      expect(plan.openCount, 1);
    });

    test('a position where NEITHER end materialises records no conductor', () {
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'r'},
      );
      _addDevice(
        doc,
        _devB,
        'tpl.b',
        _body('sb', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'r'},
      );

      final plan = _plan(doc)!;
      expect(
        plan.conductors,
        hasLength(1),
        reason:
            'a conductor with two open ends asserts a cable nobody drew — '
            'there is no electrical path to record',
      );
      expect(plan.openCount, 0);
      expect(plan.pairedCount, 1);
    });
  });

  group('planAtomicConnect — role mismatch is reported, not corrected', () {
    test('opposite polarity order is REPORTED and the wiring is unchanged', () {
      // Two authors declared the same pair in opposite orders. §11.8.3
      // rules the ORDER, so the wiring follows it — but AC-030 wants a
      // polarity inversion to be impossible to land unremarked.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('p', '+'), ('n', '-')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('n', '-'), ('p', '+')]));

      final plan = _plan(doc)!;
      expect(plan.pairedCount, 2);
      expect(plan.roleMismatches, hasLength(2));
      expect(plan.roleMismatches[0].position, 0);
      expect(plan.roleMismatches[0].fromRole, '+');
      expect(plan.roleMismatches[0].toRole, '-');

      // And the ruling still governs the wiring.
      expect(
        (plan.conductors[0].from as PortEndpoint).portId,
        _portOf(_devA, 'p'),
      );
      expect(
        (plan.conductors[0].to as PortEndpoint).portId,
        _portOf(_devB, 'n'),
        reason:
            'declared order decides the wiring — reporting the mismatch must '
            'not quietly re-pair by role, which would be this file making a '
            'ruling §11.8.3 did not make',
      );
    });

    test('an EMPTY role is no role, not a role that differs', () {
      // `Conductor.role`'s own doc gives "" as a value meaning no role, so
      // a template may spell "unroled" either way. Comparing them raw
      // reports "" against "L" as a conflict on every such set.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('a', ''), ('b', '')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('a', 'L'), ('b', 'R')]));

      final plan = _plan(doc)!;
      expect(plan.pairedCount, 2);
      expect(plan.roleMismatches, isEmpty);
    });

    test('a member with no declared role is not a mismatch', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('a', null), ('b', null)]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('a', 'L'), ('b', 'R')]));

      final plan = _plan(doc)!;
      expect(
        plan.roleMismatches,
        isEmpty,
        reason:
            'no role declared means the POSITION carries the meaning; '
            'reporting that as a conflict would flag every unroled set',
      );
    });
  });

  group('planAtomicConnect — what does not resolve', () {
    test('an unknown set key gives null', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));
      expect(
        planAtomicConnect(
          doc,
          fromDeviceId: _devA,
          fromSetKey: 'nope',
          toDeviceId: _devB,
          toSetKey: 'sb',
        ),
        isNull,
      );
    });

    test('a missing device gives null', () {
      final doc = _doc();
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));
      expect(_plan(doc), isNull);
    });

    test('a declared set nothing joins to resolves EMPTY, not null', () {
      // The dangling-setKey state `port_set_integrity_test` guards. A
      // caller must be able to tell "no such set" from "a set no port
      // references".
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', []));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));

      final set = resolvePortSet(doc, _devA, 'sa');
      expect(set, isNotNull);
      expect(set!.members, isEmpty);

      final plan = _plan(doc)!;
      expect(plan.conductors, hasLength(1));
      expect(plan.conductors[0].from, isA<OpenEndpoint>());
    });
  });

  group('AtomicConnectCommand — one gesture, one undo entry', () {
    AtomicConnectCommand command(AtomicConnectPlan plan) =>
        AtomicConnectCommand(
          plan: plan,
          designator: 'W001',
          media: const MediaTypeId('media.cat6_utp'),
          order: const FracIndex('a0'),
          now: _when,
          actor: 'test',
          id: const Uuid('lnk-1'),
          netId: const Uuid('net-1'),
        );

    RackDocument threeOntoTwo() {
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('y', 'Y'), ('pb', 'Pb'), ('pr', 'Pr')]),
      );
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));
      return doc;
    }

    test('creates ONE Link carrying every conductor, plus its Net', () {
      final doc = threeOntoTwo();
      command(_plan(doc)!).apply(doc);

      expect(
        doc.links,
        hasLength(1),
        reason:
            'a five-conductor component run is ONE thing the user did; five '
            'Links would be five undo entries for one gesture',
      );
      expect(doc.nets, hasLength(1));
      expect(doc.links[const Uuid('lnk-1')]!.conductors, hasLength(3));
    });

    test('revert removes both the Link and its Net', () {
      final doc = threeOntoTwo();
      command(_plan(doc)!)
        ..apply(doc)
        ..revert(doc);

      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
    });

    test('redo recreates IDENTICAL entities', () {
      // Ids are minted in the constructor and the plan is fixed before
      // apply(), so a second apply cannot re-derive a different answer.
      final doc = threeOntoTwo();
      final cmd = command(_plan(doc)!)..apply(doc);
      final firstEnds = doc.links[const Uuid('lnk-1')]!.conductors
          .map((c) => c.from)
          .whereType<PortEndpoint>()
          .map((e) => e.portId.v)
          .toList();

      cmd
        ..revert(doc)
        ..apply(doc);

      final secondEnds = doc.links[const Uuid('lnk-1')]!.conductors
          .map((c) => c.from)
          .whereType<PortEndpoint>()
          .map((e) => e.portId.v)
          .toList();
      expect(secondEnds, firstEnds);
      expect(doc.links[const Uuid('lnk-1')]!.conductors, hasLength(3));
    });

    test('CR-117: apply then revert restores byte-identical JSON', () {
      // The 1000-sequence fuzz harness cannot reach this shape: its
      // fixture device has no port sets, and `AddLinkCommand` — the only
      // other Link-minting command — always makes a conductor with TWO
      // OPEN ENDS. This command is the first to put a `PortEndpoint` on a
      // Link at all, and to mix one with an `OpenEndpoint` on the same
      // conductor, so the byte property is pinned here instead.
      const codec = JsonDocumentCodec();
      final doc = threeOntoTwo();
      final before = codec.write(doc);

      final cmd = command(_plan(doc)!)..apply(doc);
      expect(
        codec.write(doc),
        isNot(before),
        reason: 'guards the assertion below against passing vacuously',
      );

      cmd.revert(doc);
      expect(codec.write(doc), before);
    });

    test('the mixed-endpoint Link survives a round trip intact', () {
      const codec = JsonDocumentCodec();
      final doc = threeOntoTwo();
      command(_plan(doc)!).apply(doc);

      final decoded = codec.read(codec.write(doc));
      expect(decoded, isA<Ok<RackDocument>>());
      final link =
          (decoded as Ok<RackDocument>).value.links[const Uuid(
            'lnk-1',
          )]!;
      expect(link.conductors, hasLength(3));
      expect(
        (link.conductors[0].from as PortEndpoint).portId,
        _portOf(_devA, 'y'),
      );
      expect(link.conductors[2].to, isA<OpenEndpoint>());
      expect(
        (link.conductors[2].to as OpenEndpoint).description,
        contains('sb'),
        reason:
            'the reason an end is open is the only thing a schedule can '
            'print about it before M5 exists — losing it on the wire loses '
            'the warning',
      );
    });

    test('carries its own label and touches the wires epoch', () {
      final doc = threeOntoTwo();
      final cmd = command(_plan(doc)!);
      expect(cmd.label, LabelKey.atomicConnect);
      expect(cmd.touches, EpochMask.wires);
      expect(cmd.affects, [const Uuid('lnk-1'), const Uuid('net-1')]);
    });
  });
}
