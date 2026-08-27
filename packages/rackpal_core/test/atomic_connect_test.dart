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

import 'package:rackpal_core/rackpal_core.dart';
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
TemplateBody _body(
  String setKey,
  List<(String, String?)> members, {
  bool atomic = true,
}) => TemplateBody(
  manufacturer: 'Acme',
  model: 'T',
  displayName: 'T',
  portSets: [
    PortSetDef(
      key: setKey,
      label: '$setKey set',
      kind: SetKind.stereoPair,
      atomicConnect: atomic,
    ),
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

AtomicConnectResult? _result(RackDocument doc) => planAtomicConnect(
  doc,
  fromDeviceId: _devA,
  fromSetKey: 'sa',
  toDeviceId: _devB,
  toSetKey: 'sb',
);

/// [_result], asserting the gesture was not refused — null still means
/// "one of the sets does not resolve".
AtomicConnectPlan? _plan(RackDocument doc) {
  final result = _result(doc);
  if (result == null) return null;
  expect(
    result,
    isA<AtomicConnectReady>(),
    reason: 'refused: ${result is AtomicConnectRefused ? result.verdict : ''}',
  );
  return (result as AtomicConnectReady).plan;
}

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

  group('planAtomicConnect — position is the contract', () {
    test('AN UNMATERIALISED MEMBER IS NOW MATERIALISED, not left open', () {
      // ═══════════════════════════════════════════════════════════════
      // THIS TEST ASSERTED THE OPPOSITE UNTIL M2-F PHASE 4C, AND IT WAS
      // RIGHT TO, UNDER THE BEHAVIOUR OF THE TIME.
      // ═══════════════════════════════════════════════════════════════
      // It used to require `conductors[0].from` to be an `OpenEndpoint`
      // when device A's `l` was declared but unmaterialised. That was the
      // honest answer while nothing could CREATE a port — but DR-011.1
      // rules that ports are materialised inside the connect command's
      // apply(), and Phase 0 implemented it for `ConnectPortsCommand`
      // ONLY. The set path kept the old answer, so a stereo pair dragged
      // on a palette-built document produced a cable with two open ends
      // and no electrical path at all.
      //
      // The old behaviour conflated two different things, and this is the
      // separation: "this position has no PARTNER" is a size mismatch and
      // is still an open end (see below), while "this port has not been
      // CREATED yet" was an artefact of AC-006's laziness and is now
      // simply planned.
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
      expect(
        (plan.conductors[0].from as PortEndpoint).portId,
        _portOf(_devA, 'l'),
        reason: 'the id is DERIVED, so it is knowable before the port is',
      );
      expect(
        plan.neededPorts.map((n) => n.portId),
        contains(_portOf(_devA, 'l')),
        reason: 'and the plan says it must be created',
      );
      expect(plan.pairedCount, 2);
      expect(plan.openCount, 0);
    });

    test('AN UNMATERIALISED MEMBER STILL DOES NOT SLIDE ITS SUCCESSOR UP', () {
      // THE INVARIANT THE OLD TEST WAS REALLY PROTECTING, and it survives
      // the change unaltered: if the implementation filtered unmaterialised
      // members before zipping, `r` would become index 0 and be wired to
      // device B's `l` — the right cable on the wrong pin, with nothing
      // downstream able to notice. Position is the contract.
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
        reason:
            'A.r must land on B.r. A filtered zip lands it on B.l and every '
            'sheet agrees with the mis-wiring',
      );
    });

    test('a SIZE mismatch is still an open end — connect-what-fits is '
        'untouched', () {
      // The distinction the rewrite above turns on. §11.8.3's ruling is
      // about SIZE, and a position with no partner on one side has no
      // second pin to derive an id for: there is nothing to materialise
      // and the end stays open.
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('y', 'Y'), ('pb', 'Pb'), ('pr', 'Pr')]),
        unmaterialised: {'y', 'pb', 'pr'},
      );
      _addDevice(
        doc,
        _devB,
        'tpl.b',
        _body('sb', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'l', 'r'},
      );

      final plan = _plan(doc)!;
      expect(plan.conductors, hasLength(3));
      expect(plan.pairedCount, 2);
      expect(plan.openCount, 1, reason: 'the third member has no partner');
      expect(plan.conductors[2].to, isA<OpenEndpoint>());
      expect(
        plan.neededPorts,
        hasLength(5),
        reason:
            'every pin the plan lands on is planned, including the '
            'one whose partner is missing',
      );
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

  group('planAtomicConnect — the tier-1 rules refuse it too', () {
    test('A SET DRAGGED ONTO ITSELF IS TOP-001, NOT TWO SELF-CONDUCTORS', () {
      // `resolvePortSet` is deterministic in (deviceId, setKey), so both
      // sides return the SAME port ids and the position loop paired every
      // member with itself. That wrote `Conductor(PortEndpoint(p),
      // PortEndpoint(p))` once per member: TOP-001 violated twice over,
      // and TOP-003 twice again (portConductorCount counts ENDS, so a
      // self-looped conductor consumes a max-1 pin twice). The
      // zero-conductor guard cannot catch it — there are two conductors,
      // they are just not conductors.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('p', '+'), ('n', '-')]));

      final result = planAtomicConnect(
        doc,
        fromDeviceId: _devA,
        fromSetKey: 'sa',
        toDeviceId: _devA,
        toSetKey: 'sa',
      );

      expect(result, isA<AtomicConnectRefused>());
      final refused = result! as AtomicConnectRefused;
      expect(refused.ruleId, 'TOP-001');
      expect(
        refused.message,
        contains('DEV-A'),
        reason:
            'DR-011.5: the sentence names the real designators, because it '
            "is the whole of the user's recourse",
      );
      expect(refused.message, endsWith('.'));
    });

    test('a full pin refuses the WHOLE gesture — TOP-003', () {
      // One Link is one user action. There is no "connect the other three
      // members" outcome §11.8.3 offers, and DR-011.5 gives T1 no
      // [ Connect anyway ] to fall back to.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L'), ('r', 'R')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L'), ('r', 'R')]));

      // B.r is already occupied by an existing run.
      doc.links[const Uuid('lnk-existing')] = Link(
        id: const Uuid('lnk-existing'),
        designator: 'W009',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        meta: _meta(),
        services: [
          Service(
            id: 'svc-1',
            signalFamily: const SignalFamilyId('audio.line_unbal'),
            netId: const Uuid('net-x'),
          ),
        ],
        conductors: [
          Conductor(
            from: PortEndpoint(_portOf(_devB, 'r')),
            to: const OpenEndpoint('elsewhere'),
          ),
        ],
      );

      final result = _result(doc);
      expect(result, isA<AtomicConnectRefused>());
      final refused = result! as AtomicConnectRefused;
      expect(refused.ruleId, 'TOP-003');
      expect(refused.message, contains('1 of 1'));
      expect(
        doc.links,
        hasLength(1),
        reason: 'planning writes nothing, refused or not',
      );
    });

    test('a device that has LEFT the document refuses — TOP-004', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));
      // The ports survive `RemoveDeviceCommand` (it removes the device
      // only — device_commands.dart's own TODO says so), so the set still
      // resolves and only TOP-004 stands between this and a Link whose
      // endpoint names a device that is gone.
      final removed = doc.devices[_devB]!;
      RemoveDeviceCommand(id: _devB).apply(doc);
      expect(resolvePortSet(doc, _devB, 'sb'), isNull);

      // Put it back and tombstone the port instead — the other TOP-004
      // limb, on a document whose sets still resolve.
      doc.devices[_devB] = removed;
      doc.tombstones[_portOf(_devB, 'l')] = Tombstone(
        deletedAt: _when,
        entityType: 'Port',
        by: 'test',
      );
      final result = _result(doc);
      expect(result, isA<AtomicConnectRefused>());
      expect((result! as AtomicConnectRefused).ruleId, 'TOP-004');
    });

    test('an UNPAIRED position is not put through the rules', () {
      // An open end lands on no jack: TOP-004 exempts it by construction
      // (AC-018) and TOP-003 has no pin to count. A rule evaluated
      // against it would refuse the "connect what fits" case §11.8.3 was
      // decided to allow.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L'), ('r', 'R')]));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', [('l', 'L')]));

      final plan = _plan(doc)!;
      expect(plan.openCount, 1);
      expect(plan.conductors[1].to, isA<OpenEndpoint>());
    });
  });

  group('AtomicConnectCommand — one gesture, one undo entry', () {
    AtomicConnectCommand command(AtomicConnectPlan plan) =>
        AtomicConnectCommand(
          plan: plan,
          materialisations: const [],
          designator: 'W001',
          netName: 'N001',
          // DR-011.3: the set's OWN family. `_body` declares every port
          // as `audio.line_unbal`, so that is what a caller reading
          // `PortDef.signalFamily` off the resolved set would hand over.
          signalFamily: const SignalFamilyId('audio.line_unbal'),
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
      expect(
        cmd.touches,
        EpochMask.wires | EpochMask.meta,
        reason:
            'meta since Phase 4C, because materialisation MINTS A '
            'DESIGNATOR — the same pair ConnectPortsCommand declares. A '
            'surface subscribed only to wires would draw the new run '
            'against a pin whose identifier it has never read.',
      );
      expect(
        cmd.affects,
        containsAll(<Uuid>[const Uuid('lnk-1'), const Uuid('net-1')]),
      );
    });

    test('DR-011.3: the REAL family reaches the Net and the Service', () {
      // This command hardcoded `structure.undetermined` in BOTH places,
      // so every component run, stereo pair and speaker pair it created
      // landed in the `str` domain — and CR-078 keys all four encoding
      // channels (hue, dash, weight, glyph/tag) off the family, so every
      // one of them drew as structure.
      final doc = threeOntoTwo();
      command(_plan(doc)!).apply(doc);

      final net = doc.nets[const Uuid('net-1')]!;
      final service = doc.links[const Uuid('lnk-1')]!.services.single;
      expect(net.signalFamily, const SignalFamilyId('audio.line_unbal'));
      expect(service.signalFamily, const SignalFamilyId('audio.line_unbal'));
      expect(
        net.signalFamily,
        isNot(const SignalFamilyId('structure.undetermined')),
        reason: 'the hardcode this parameter replaced',
      );
      expect(
        service.signalFamily,
        isNot(const SignalFamilyId('structure.undetermined')),
      );
    });

    test('REFUSES to be constructed with a zero-conductor plan', () {
      // THE GUARD SURVIVES, BUT ITS REACHABLE CASE HAS MOVED. It used to
      // fire whenever neither set had a MATERIALISED member — "which,
      // before DR-011.1, was every plan on every document built from the
      // palette". Phase 4C makes those plans real, so the only route to
      // an empty plan now is a set with no MEMBERS at all: a declared
      // `PortSetDef` that no port joins, which
      // `port_set_integrity_test.dart` records as the state 72 of 90
      // catalog references were once in.
      //
      // Writing it would produce a `Link` with a designator, a pull-sheet
      // row and nothing electrical on it at all.
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', []));
      _addDevice(doc, _devB, 'tpl.b', _body('sb', []));

      final plan = _plan(doc)!;
      expect(
        plan.conductors,
        isEmpty,
        reason: 'guards the assertion below against passing vacuously',
      );
      expect(() => command(plan), throwsArgumentError);
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
    });

    test('REFUSES a hand-built plan carrying a self-conductor', () {
      // `planAtomicConnect` refuses this with a TOP-001 sentence, which is
      // what a user should get. This is what a CALLER gets for a plan
      // that never went through it — the same guard
      // `ConnectPortsCommand` carries, over N conductors instead of one.
      final doc = threeOntoTwo();
      final self = PortEndpoint(_portOf(_devA, 'y'));
      expect(
        () => command(
          AtomicConnectPlan(
            conductors: [Conductor(from: self, to: self)],
            pairedCount: 1,
            openCount: 0,
            roleMismatches: const [],
          ),
        ),
        throwsArgumentError,
      );
      expect(doc.links, isEmpty);
    });
  });

  group('DR-011.2 — PortSetDef.atomicConnect stops being decorative', () {
    // "This also makes `PortSetDef.atomicConnect` load-bearing for the
    // first time. It is a persisted per-set opt-out that
    // `planAtomicConnect` never reads; M2-F enforces it or the flag is
    // decorative." — DR-011.2, and this group is the enforcement.

    test('the SEED CATALOG has no opt-out, so this arm is unreachable from '
        'shipped data — it exists for M4-authored templates', () {
      // Stated as an assertion rather than a comment because it is the
      // reason the enforcement could sit unnoticed: nothing in the
      // catalog would ever have exercised it.
      final catalog = buildSeedCatalog();
      final optedOut = <String>[];
      for (final entry in catalog.entries) {
        for (final set in entry.value.portSets) {
          if (!set.atomicConnect) optedOut.add('${entry.key}/${set.key}');
        }
      }
      expect(optedOut, isEmpty);
    });

    test('a set that opted out is NOT planned, and NOT reported as a rule '
        'refusal', () {
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'A-1',
        _body('s', [('l', 'L'), ('r', 'R')], atomic: false),
      );
      _addDevice(doc, _devB, 'B-1', _body('s', [('l', 'L'), ('r', 'R')]));

      final result = planAtomicConnect(
        doc,
        fromDeviceId: _devA,
        fromSetKey: 's',
        toDeviceId: _devB,
        toSetKey: 's',
      );
      expect(result, isA<AtomicConnectNotAtomic>());
      expect(
        result,
        isNot(isA<AtomicConnectRefused>()),
        reason:
            'no tier-1 rule was broken, and canon §5 forbids inventing '
            'a TOP id for something that is not in the catalogue',
      );
      expect((result! as AtomicConnectNotAtomic).setKey, 's');
      expect((result as AtomicConnectNotAtomic).deviceId, _devA);
    });

    test('EITHER end disqualifies it — a cable cannot be one object at one '
        'end and N at the other', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'A-1', _body('s', [('l', 'L'), ('r', 'R')]));
      _addDevice(
        doc,
        _devB,
        'B-1',
        _body('s', [('l', 'L'), ('r', 'R')], atomic: false),
      );

      final result = planAtomicConnect(
        doc,
        fromDeviceId: _devA,
        fromSetKey: 's',
        toDeviceId: _devB,
        toSetKey: 's',
      );
      expect(result, isA<AtomicConnectNotAtomic>());
      expect(
        (result! as AtomicConnectNotAtomic).deviceId,
        _devB,
        reason:
            'the TO end is the one that opted out, and the answer names '
            'which',
      );
    });

    test('it is told apart from "no such set" (null) and from an EMPTY '
        'plan — the three the file header warns not to collapse', () {
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'A-1',
        _body('s', [('l', 'L'), ('r', 'R')], atomic: false),
      );
      _addDevice(doc, _devB, 'B-1', _body('s', [('l', 'L'), ('r', 'R')]));

      expect(
        planAtomicConnect(
          doc,
          fromDeviceId: _devA,
          fromSetKey: 'nope',
          toDeviceId: _devB,
          toSetKey: 's',
        ),
        isNull,
        reason: "a typo'd set key is still null, not the opt-out",
      );
      expect(
        planAtomicConnect(
          doc,
          fromDeviceId: _devA,
          fromSetKey: 's',
          toDeviceId: _devB,
          toSetKey: 's',
        ),
        isA<AtomicConnectNotAtomic>(),
      );
    });

    test('both ends atomic still plans, so the check did not break the '
        'normal path', () {
      final doc = _doc();
      _addDevice(doc, _devA, 'A-1', _body('s', [('l', 'L'), ('r', 'R')]));
      _addDevice(doc, _devB, 'B-1', _body('s', [('l', 'L'), ('r', 'R')]));
      expect(
        planAtomicConnect(
          doc,
          fromDeviceId: _devA,
          fromSetKey: 's',
          toDeviceId: _devB,
          toSetKey: 's',
        ),
        isA<AtomicConnectReady>(),
      );
    });
  });

  group('DR-011.1 on the SET path — the half Phase 0 did not do', () {
    // DR-011's finding #1 was that nothing in the application ever
    // materialises a `Port`, so "on a document built by placing devices
    // from the palette — the document the M2 exit criterion starts from —
    // every port set resolves to all-null members and planAtomicConnect
    // returns a plan with zero conductors". Phase 0 fixed that for
    // `ConnectPortsCommand`. This group is the same fix for the gesture
    // the finding was literally written about.

    RackDocument palette() {
      // NOTHING MATERIALISED — exactly what dropping two devices out of
      // the palette produces.
      final doc = _doc();
      _addDevice(
        doc,
        _devA,
        'tpl.a',
        _body('sa', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'l', 'r'},
      );
      _addDevice(
        doc,
        _devB,
        'tpl.b',
        _body('sb', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'l', 'r'},
      );
      return doc;
    }

    AtomicConnectCommand built(RackDocument doc) => buildAtomicConnectCommand(
      doc: doc,
      plan: _plan(doc)!,
      signalFamily: const SignalFamilyId('audio.line_unbal'),
      media: kUnstatedMedia,
      now: _when,
      actor: 'test',
    );

    test('a palette-built document now yields a REAL plan, not a '
        'zero-conductor one', () {
      final plan = _plan(palette())!;
      expect(
        plan.conductors,
        hasLength(2),
        reason:
            'this was ZERO before Phase 4C — the exact defect DR-011 '
            'was created to record',
      );
      expect(plan.pairedCount, 2);
      expect(plan.neededPorts, hasLength(4));
    });

    test('applying it CREATES the four ports, with allocated designators', () {
      final doc = palette();
      expect(doc.ports, isEmpty, reason: 'the premise');
      built(doc).apply(doc);

      expect(doc.ports, hasLength(4));
      for (final conductor in doc.links.values.single.conductors) {
        for (final end in [conductor.from, conductor.to]) {
          expect(end, isA<PortEndpoint>());
          expect(
            doc.ports.containsKey((end as PortEndpoint).portId),
            isTrue,
            reason: 'a conductor end must land on a port the document has',
          );
        }
      }
    });

    test('the two designators on ONE device are DIFFERENT — the allocator '
        'sees its own previous answer', () {
      // `buildConnectPortsCommand` reserves the first end's designator
      // when both pins are on one device. A set has N pins on one device,
      // so the reservation has to accumulate across all of them or a
      // stereo pair gets J01 twice and CR-042's per-device uniqueness is
      // broken by the command that created both.
      final doc = palette();
      built(doc).apply(doc);

      final onA = [
        for (final port in doc.ports.values)
          if (port.deviceId == _devA) port.designator,
      ];
      expect(onA, hasLength(2));
      expect(onA.toSet(), hasLength(2), reason: 'CR-042: unique per device');
    });

    test('revert removes EXACTLY what apply created, and nothing that was '
        'already there', () {
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
        unmaterialised: {'l', 'r'},
      );
      // A.l is the ONLY pre-materialised pin: A.r and both of B's are not.
      // So the command creates three and must give back exactly three.
      final preexisting = doc.ports.keys.toSet();
      expect(preexisting, {_portOf(_devA, 'l')});

      final cmd = built(doc)..apply(doc);
      expect(doc.ports.length, greaterThan(preexisting.length));

      cmd.revert(doc);
      expect(
        doc.ports.keys.toSet(),
        preexisting,
        reason:
            "a port the user's document already owned is not this "
            "command's to remove — its designator, notes and every "
            'conductor landing on it would go with it',
      );
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
    });

    test('apply is IDEMPOTENT over an existing port — it keeps the '
        "document's own designator", () {
      final doc = _doc();
      _addDevice(doc, _devA, 'tpl.a', _body('sa', [('l', 'L'), ('r', 'R')]));
      _addDevice(
        doc,
        _devB,
        'tpl.b',
        _body('sb', [('l', 'L'), ('r', 'R')]),
        unmaterialised: {'l', 'r'},
      );
      final kept = doc.ports[_portOf(_devA, 'l')]!.designator;

      built(doc).apply(doc);
      expect(
        doc.ports[_portOf(_devA, 'l')]!.designator,
        kept,
        reason:
            'CR-048: a designator is evaluated once at creation and '
            'stored; a connect never rewrites project state',
      );
    });

    test('apply/revert/apply lands in the identical state — the Command '
        'contract, over a data-dependent revert', () {
      final doc = palette();
      final cmd = built(doc)..apply(doc);
      final once = doc.ports.keys.toSet();
      cmd
        ..revert(doc)
        ..apply(doc);
      expect(doc.ports.keys.toSet(), once);
      expect(doc.links, hasLength(1));
    });
  });
}
