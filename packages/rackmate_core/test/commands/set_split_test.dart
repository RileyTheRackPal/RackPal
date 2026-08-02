// DR-014 — a wire drawn from an already-wired set member to a DIFFERENT
// device splits the set.
//
// ═════════════════════════════════════════════════════════════════════
// THE TEST THIS FILE EXISTS FOR IS `a one-conductor link is never split`
// ═════════════════════════════════════════════════════════════════════
// Every other condition in `planSetSplit` refuses a gesture that would
// have been refused anyway — the user sees `TOP-003` where they used to
// see `TOP-003`. Condition 3 is the one whose failure mode is DESTRUCTIVE
// and silent: lift the only conductor out of a link and the cable becomes
// a `W` number with no electrical path — a row on the pull sheet for
// something that connects nothing — and the user who dragged a pin
// expecting a refusal has instead deleted a cable they cannot see.
//
// The second reason is `two splits on one link come out descending`. It
// looks like a fussy ordering detail and it is a wrong-cable defect: a
// `ConductorRef` is a POSITION, so removing the lower index first
// renumbers the higher one onto its neighbour.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8);
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
const _devC = Uuid('dev-c');

/// A stereo pair — `l`/`r`, roles `L`/`R`, both `atomicConnect`.
///
/// A `busNode` [direction] makes both pins taps on a shared medium, which
/// is what gives `effectiveMaxConnections` its `null` and therefore a pin
/// that is never full. The 70 V and Cresnet case, in the smallest form
/// that reaches the same getter.
TemplateBody _pair({PortDirection direction = PortDirection.source}) =>
    TemplateBody(
      manufacturer: 'Acme',
      model: 'T',
      displayName: 'T',
      portSets: [
        PortSetDef(key: 'st', label: 'Stereo', kind: SetKind.stereoPair),
      ],
      ports: [
        for (final m in [('l', 'L'), ('r', 'R')])
          PortDef(
            key: PortKey(m.$1),
            label: m.$1.toUpperCase(),
            connector: const ConnectorTypeId('conn.rca'),
            signalFamily: const SignalFamilyId('audio.line_unbal'),
            direction: direction,
            face: Face.rear,
            position: _pos,
            order: FracIndex('a${m.$1}'),
            setKey: 'st',
            setRole: m.$2,
          ),
      ],
    );

void _addDevice(RackDocument doc, Uuid id, TemplateBody body) {
  final tplId = 'tpl.${id.v}';
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
    final pid = derivePortId(id, p.key);
    doc.ports[pid] = Port(
      id: pid,
      deviceId: id,
      designator: '${id.v}-${p.key.v}',
      templatePortKey: p.key,
    );
  }
}

RackDocument _doc({PortDirection direction = PortDirection.source}) {
  final doc = RackDocument(
    id: const Uuid('doc-split'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  for (final id in [_devA, _devB, _devC]) {
    _addDevice(doc, id, _pair(direction: direction));
  }
  return doc;
}

Uuid _p(Uuid device, String key) => derivePortId(device, PortKey(key));

/// Adds a `Link` carrying [conductors], with the implicit `Net` and
/// `Service` every gesture in the app mints beside one.
Uuid _addLink(
  RackDocument doc,
  String designator,
  List<Conductor> conductors, {
  String netName = 'N001',
}) {
  final id = Uuid('link-$designator');
  final netId = Uuid('net-$designator');
  doc.nets[netId] = Net(
    id: netId,
    name: netName,
    signalFamily: const SignalFamilyId('audio.line_unbal'),
    meta: _meta(),
  );
  doc.links[id] = Link(
    id: id,
    designator: designator,
    media: kUnstatedMedia,
    order: FracIndex('a$designator'),
    meta: _meta(),
    services: [
      Service(
        id: 'svc-1',
        signalFamily: const SignalFamilyId('audio.line_unbal'),
        netId: netId,
      ),
    ],
    conductors: conductors,
  );
  return id;
}

Conductor _c(Uuid fromPort, Uuid toPort, String role) => Conductor(
  from: PortEndpoint(fromPort),
  to: PortEndpoint(toPort),
  role: role,
);

/// The atomic pair A→B, as `AtomicConnectCommand` would leave it: ONE
/// link, TWO conductors, L on L and R on R.
Uuid _wireAtoB(RackDocument doc) => _addLink(doc, 'W001', [
  _c(_p(_devA, 'l'), _p(_devB, 'l'), 'L'),
  _c(_p(_devA, 'r'), _p(_devB, 'r'), 'R'),
]);

ConnectTarget _t(RackDocument doc, Uuid device, String key) =>
    resolveConnectTarget(doc, deviceId: device, portKey: key)!;

void main() {
  group('planSetSplit — the four conditions', () {
    test('a wired set member drawn to a THIRD device splits, naming the '
        'conductor that holds it', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);

      final split = planSetSplit(
        doc,
        target: _t(doc, _devA, 'r'),
        towardsDeviceId: _devC,
      );

      expect(split, isNotNull);
      // INDEX 1, NOT 0. The R leg is the second conductor, and a plan that
      // named the first would lift the L leg out of the cable instead —
      // the whole set moving when one member was asked to.
      expect(split!.conductor, const ConductorRef(Uuid('link-W001'), 1));
      expect(split.conductor.linkId, w1);
      expect(split.linkDesignator, 'W001');
      expect(split.conductorsBefore, 2);
      expect(split.conductorsAfter, 1);
      expect(split.role, 'R');
    });

    test('(4) drawn back to the device it ALREADY reaches — no split', () {
      final doc = _doc();
      _wireAtoB(doc);

      // A-R already runs to B. Aiming it at B again is a misaimed drag far
      // more often than a request to re-plug, and DR-014's wording is "a
      // DIFFERENT device".
      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devB,
        ),
        isNull,
      );
    });

    test('(1) a pin with room takes the cable normally — no split', () {
      final doc = _doc();
      _wireAtoB(doc);

      // C is unwired entirely. Nothing to free, so nothing to split — this
      // is what keeps DR-014 inert on the overwhelming majority of pins.
      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devC, 'r'),
          towardsDeviceId: _devA,
        ),
        isNull,
      );
    });

    test('(3) a ONE-conductor link is never split — that would be a '
        'silent delete', () {
      final doc = _doc();
      // The same pin, equally full, but held by a cable that has nothing
      // else in it. Lifting this conductor leaves a `W` number with no
      // electrical path.
      _addLink(doc, 'W001', [_c(_p(_devA, 'r'), _p(_devB, 'r'), 'R')]);

      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devC,
        ),
        isNull,
      );
    });

    test('(2) two cables on one pin — no derivable answer, no split', () {
      final doc = _doc();
      _wireAtoB(doc);
      // A hand-edited or imported state: a second multi-conductor cable
      // also landing on A-R. "Which of these did you mean to displace" has
      // no answer the code is entitled to pick.
      _addLink(doc, 'W002', [
        _c(_p(_devA, 'r'), _p(_devC, 'l'), 'R'),
        _c(_p(_devA, 'l'), _p(_devC, 'r'), 'L'),
      ], netName: 'N002');

      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devC,
        ),
        isNull,
      );
    });

    test('(2) a conductor looped from the pin back to itself — no split', () {
      final doc = _doc();
      // Two ends on one pin. `TOP-001` makes this unreachable through a
      // command; a hand-edited file can carry it, and half of it is not a
      // thing that can be lifted.
      _addLink(doc, 'W001', [
        _c(_p(_devA, 'r'), _p(_devA, 'r'), 'R'),
        _c(_p(_devA, 'l'), _p(_devB, 'l'), 'L'),
      ]);

      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devC,
        ),
        isNull,
      );
    });

    test('(1) a BUS TAP is never full and therefore never splits', () {
      final doc = _doc(direction: PortDirection.busNode);
      _wireAtoB(doc);

      // `effectiveMaxConnections` is null here — unbounded, not unknown —
      // so the pin has room and the cable simply lands beside the one
      // already there. A split would take a conductor off a bus for no
      // reason at all.
      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devC,
        ),
        isNull,
      );
    });

    test('an OPEN far end splits — it names no device to be the same as', () {
      final doc = _doc();
      _addLink(doc, 'W001', [
        _c(_p(_devA, 'l'), _p(_devB, 'l'), 'L'),
        Conductor(
          from: PortEndpoint(_p(_devA, 'r')),
          to: const OpenEndpoint('no partner in Stereo'),
          role: 'R',
        ),
      ]);

      final split = planSetSplit(
        doc,
        target: _t(doc, _devA, 'r'),
        towardsDeviceId: _devC,
      );
      expect(split, isNotNull);
      expect(split!.conductor.index, 1);
    });

    test('an UNRESOLVABLE far end does NOT split — "I cannot tell" is not '
        '"it is different"', () {
      final doc = _doc();
      _addLink(doc, 'W001', [
        _c(_p(_devA, 'l'), _p(_devB, 'l'), 'L'),
        _c(_p(_devA, 'r'), const Uuid('port-that-is-not-there'), 'R'),
      ]);

      expect(
        planSetSplit(
          doc,
          target: _t(doc, _devA, 'r'),
          towardsDeviceId: _devC,
        ),
        isNull,
      );
    });
  });

  group('the rules count the pin as the split will leave it', () {
    test('portConductorCount drops the freed conductor', () {
      final doc = _doc();
      _wireAtoB(doc);
      final pin = _p(_devA, 'r');

      expect(portConductorCount(doc, pin), 1);
      expect(
        portConductorCount(
          doc,
          pin,
          freeing: {const ConductorRef(Uuid('link-W001'), 1)},
        ),
        0,
      );
      // AND NOT THE WRONG ONE. Freeing the L conductor leaves R occupied,
      // which is what makes the index in `ConductorRef` load-bearing
      // rather than decorative.
      expect(
        portConductorCount(
          doc,
          pin,
          freeing: {const ConductorRef(Uuid('link-W001'), 0)},
        ),
        1,
      );
    });

    test('TOP-003 refuses without the split and allows with it', () {
      final doc = _doc();
      _wireAtoB(doc);
      final from = _t(doc, _devA, 'r');
      final to = _t(doc, _devC, 'r');

      final refused = evaluateConnect(doc, from, to);
      expect(refused, isA<ConnectRefused>());
      expect((refused as ConnectRefused).ruleId, 'TOP-003');

      expect(
        evaluateConnect(
          doc,
          from,
          to,
          freeing: {const ConductorRef(Uuid('link-W001'), 1)},
        ),
        isA<ConnectAllowed>(),
      );
    });
  });

  group('SplitConductorCommand', () {
    test('lifts exactly one conductor and keeps everything else about the '
        'cable', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      final link = doc.links[w1]!;

      SplitConductorCommand(linkId: w1, index: 1).apply(doc);

      // The cable is STILL THERE — same `W` number, same net, same
      // service. A remove-and-recreate would mint a new designator and
      // change what the installer is looking for.
      expect(doc.links[w1], same(link));
      expect(link.designator, 'W001');
      expect(doc.nets, hasLength(1));
      expect(link.services, hasLength(1));
      expect(link.conductors, hasLength(1));
      final kept = link.conductors.single.from as PortEndpoint;
      expect(kept.portId, _p(_devA, 'l'));
    });

    test('revert puts the conductor back AT ITS OWN INDEX', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      final link = doc.links[w1]!;

      // Index 0 — the one whose restoration can land in the wrong place,
      // because appending would put L after R and `planAtomicConnect`
      // pairs set members BY POSITION.
      final command = SplitConductorCommand(linkId: w1, index: 0)..apply(doc);
      expect(link.conductors, hasLength(1));
      command.revert(doc);

      expect(link.conductors, hasLength(2));
      expect(link.conductors[0].role, 'L');
      expect(link.conductors[1].role, 'R');
    });

    test('apply finds nothing when the link has gone, and revert is then a '
        'no-op', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      final command = SplitConductorCommand(linkId: w1, index: 1);
      doc.links.remove(w1);

      // DR-013's cascade can take a link out from under a planned command.
      // "Apply ran and found nothing" is a legal outcome, not a crash.
      expect(() => command.apply(doc), returnsNormally);
      expect(() => command.revert(doc), returnsNormally);
      expect(doc.links, isEmpty);
    });

    test('revert before apply throws — that one is still a bug', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      expect(
        () => SplitConductorCommand(linkId: w1, index: 0).revert(doc),
        throwsStateError,
      );
    });

    test('an out-of-range index removes nothing', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      SplitConductorCommand(linkId: w1, index: 7).apply(doc);
      expect(doc.links[w1]!.conductors, hasLength(2));
    });

    test('touches wires only — no designator is minted or destroyed', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      final command = SplitConductorCommand(linkId: w1, index: 1);
      expect(command.touches, EpochMask.wires);
      expect(command.label, LabelKey.splitSet);
    });
  });

  group('buildSplitConnectCommands', () {
    SplitConnectReady build(
      RackDocument doc,
      ConnectTarget from,
      ConnectTarget to,
    ) {
      final result = buildSplitConnectCommands(
        doc: doc,
        from: from,
        to: to,
        media: kUnstatedMedia,
        now: _when,
        actor: 'test',
      );
      expect(
        result,
        isA<SplitConnectReady>(),
        reason: result is SplitConnectRefused ? result.message : '',
      );
      return result as SplitConnectReady;
    }

    test('one end full: the split comes first, then the connect', () {
      final doc = _doc();
      _wireAtoB(doc);

      final ready = build(doc, _t(doc, _devA, 'r'), _t(doc, _devC, 'r'));

      expect(ready.splits, hasLength(1));
      expect(ready.splits.single.linkDesignator, 'W001');
      expect(ready.commands, hasLength(2));
      // THE ORDER IS THE CLAIM. The connect writes a conductor onto a pin
      // the split has to have freed first, or a document read between the
      // two writes holds two cables on a one-connection jack.
      expect(ready.commands.first, isA<SplitConductorCommand>());
      expect(ready.commands.last, same(ready.connect));
    });

    test('BOTH ends full: two splits and a connect', () {
      final doc = _doc();
      _wireAtoB(doc);
      // C's pair wired to a fourth box, so C-R is full too and its far end
      // is not A.
      const devD = Uuid('dev-d');
      _addDevice(doc, devD, _pair());
      _addLink(doc, 'W002', [
        _c(_p(_devC, 'l'), _p(devD, 'l'), 'L'),
        _c(_p(_devC, 'r'), _p(devD, 'r'), 'R'),
      ], netName: 'N002');

      final ready = build(doc, _t(doc, _devA, 'r'), _t(doc, _devC, 'r'));

      // Planning only the grabbed end would refuse exactly this — two
      // amplifiers, the commonest thing a user does — with a TOP-003
      // sentence about the pin they were aiming AT.
      expect(ready.splits, hasLength(2));
      expect(
        ready.splits.map((s) => s.linkDesignator),
        containsAll(<String>['W001', 'W002']),
      );
      expect(ready.commands, hasLength(3));
      expect(ready.commands[0], isA<SplitConductorCommand>());
      expect(ready.commands[1], isA<SplitConductorCommand>());
      expect(ready.commands[2], same(ready.connect));
    });

    test('two splits on ONE link come out HIGHEST INDEX FIRST', () {
      final doc = _doc();
      // CR-014 lets one `Link` reach more than two devices. This is that
      // cable: one W number holding the conductor that occupies each end
      // of the drag, with far ends on neither peer.
      _addLink(doc, 'W001', [
        _c(_p(_devA, 'r'), _p(_devB, 'l'), 'L'),
        _c(_p(_devC, 'r'), _p(_devB, 'r'), 'R'),
      ]);

      final ready = build(doc, _t(doc, _devA, 'r'), _t(doc, _devC, 'r'));
      expect(ready.splits, hasLength(2));

      final indices = <int>[
        for (final c in ready.commands.whereType<SplitConductorCommand>())
          c.index,
      ];
      // Ascending would renumber the second onto its neighbour: the user
      // asked to move one leg and two would move.
      expect(indices, <int>[1, 0]);
    });

    test('a refusal returns NO commands at all — not even the splits', () {
      final doc = _doc();
      _wireAtoB(doc);
      final from = _t(doc, _devA, 'r');

      // TOP-001: the same pin at both ends. The split for `from` plans
      // fine; the connect refuses, and a gesture that had nonetheless
      // taken a conductor out of the cable would leave the user told
      // nothing happened and their stereo pair a mono cable.
      final result = buildSplitConnectCommands(
        doc: doc,
        from: from,
        to: from,
        media: kUnstatedMedia,
        now: _when,
        actor: 'test',
      );
      expect(result, isA<SplitConnectRefused>());
      expect((result as SplitConnectRefused).ruleId, 'TOP-001');
      expect(doc.links[const Uuid('link-W001')]!.conductors, hasLength(2));
    });

    test('an ordinary connect needs no split and says so', () {
      final doc = _doc();
      final ready = build(doc, _t(doc, _devA, 'r'), _t(doc, _devC, 'r'));
      expect(ready.splits, isEmpty);
      expect(ready.commands, hasLength(1));
      expect(ready.commands.single, same(ready.connect));
    });

    test('the whole gesture is one lossless round trip', () {
      final doc = _doc();
      final w1 = _wireAtoB(doc);
      final ready = build(doc, _t(doc, _devA, 'r'), _t(doc, _devC, 'r'));

      final txn = Transaction(
        LabelKey.splitSet,
        ready.commands,
        Selection(),
        Selection(),
      )..apply(doc);

      // ONE CABLE BECAME TWO. That is the bill of materials DR-012.2 is
      // about, and it is what the announcement has to name.
      expect(doc.links, hasLength(2));
      expect(doc.links[w1]!.conductors, hasLength(1));
      expect(doc.links[w1]!.conductors.single.role, 'L');
      final made = doc.links[ready.connect.id]!;
      expect(made.conductors, hasLength(1));
      expect(
        (made.conductors.single.from as PortEndpoint).portId,
        _p(_devA, 'r'),
      );
      expect(
        (made.conductors.single.to as PortEndpoint).portId,
        _p(_devC, 'r'),
      );

      txn.revert(doc);

      expect(doc.links, hasLength(1));
      expect(doc.nets, hasLength(1));
      final back = doc.links[w1]!;
      expect(back.conductors, hasLength(2));
      expect(back.conductors[0].role, 'L');
      expect(back.conductors[1].role, 'R');
      expect(
        (back.conductors[1].to as PortEndpoint).portId,
        _p(_devB, 'r'),
      );
    });
  });
}
