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

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'validation/fixtures/connect_scenarios.dart';

void main() {
  group('resolveConnectTarget — the join that did not exist', () {
    test('resolves a pin the document has NOT materialised', () {
      final doc = connectPair();
      final t = connectAvrOut(doc);
      expect(t.deviceId, connectAvr);
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
        derivePortId(connectAvr, const PortKey('hdmi.out.1')),
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('hdmi.out.1')]),
        materialise: {'hdmi.out.1'},
      );
      final t = connectAvrOut(doc);
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([
          connectPort('hdmi.out.1'),
          connectPort('hdmi.out.2', order: 'a1'),
          connectPort('hdmi.out.3', order: 'a2'),
        ]),
      );
      final t = resolveConnectTarget(
        doc,
        deviceId: connectAvr,
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('ir.out.3', label: 'IR OUT 3', hint: 'J34')]),
      );
      doc.settings.portDesignatorFormat = const IdFormat(
        '{DEV_BLOCK}{PORT_SEQ:2}',
      );

      final withHint = resolveConnectTarget(
        doc,
        deviceId: connectAvr,
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
      final noHint = connectDoc();
      connectAddDevice(
        noHint,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('ir.out.3', label: 'IR OUT 3')]),
      );
      noHint.settings.portDesignatorFormat = const IdFormat('{DEV_BLOCK}');
      expect(
        resolveConnectTarget(
          noHint,
          deviceId: connectAvr,
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('a'), connectPort('b', order: 'a1')]),
      );
      doc.settings.portDesignatorFormat = const IdFormat('J');
      final first = derivePortId(connectAvr, const PortKey('a'));
      doc.ports[first] = Port(id: first, deviceId: connectAvr, designator: 'J');

      final t = resolveConnectTarget(doc, deviceId: connectAvr, portKey: 'b')!;
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
      final doc = connectPair();
      expect(
        resolveConnectTarget(doc, deviceId: const Uuid('no'), portKey: 'x'),
        isNull,
      );
      expect(
        resolveConnectTarget(doc, deviceId: connectAvr, portKey: 'nope'),
        isNull,
      );
      doc.templates.clear();
      expect(
        resolveConnectTarget(doc, deviceId: connectAvr, portKey: 'hdmi.out.1'),
        isNull,
      );
    });
  });

  group('portConductorCount — PER PORT, not per device', () {
    test('counts ENDS, so a self-looped conductor consumes the pin twice', () {
      // TOP-001 makes this unreachable through a command; a hand-edited
      // or imported file can still carry one, and under-counting it makes
      // an over-subscribed jack read as legal.
      final doc = connectPair();
      final a = connectAvrOut(doc).portId;
      connectLink(doc, 'W001', PortEndpoint(a), PortEndpoint(a));
      expect(portConductorCount(doc, a), 2);
    });

    test('ignores Open and Place endpoints', () {
      final doc = connectPair();
      final a = connectAvrOut(doc).portId;
      connectLink(
        doc,
        'W001',
        const OpenEndpoint('coil'),
        const PlaceEndpoint(description: 'beam 3'),
      );
      expect(portConductorCount(doc, a), 0);
    });

    test('is NOT linkCountForDevice — two pins on one device differ', () {
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('a'), connectPort('b', order: 'a1')]),
      );
      final a = derivePortId(connectAvr, const PortKey('a'));
      final b = derivePortId(connectAvr, const PortKey('b'));
      doc.ports[a] = Port(id: a, deviceId: connectAvr, designator: 'J01');
      doc.ports[b] = Port(id: b, deviceId: connectAvr, designator: 'J02');
      connectLink(doc, 'W001', PortEndpoint(a), const OpenEndpoint('x'));
      connectLink(doc, 'W002', PortEndpoint(a), const OpenEndpoint('y'));

      expect(portConductorCount(doc, a), 2);
      expect(
        portConductorCount(doc, b),
        0,
        reason:
            'the per-DEVICE count is 2 for both pins; TOP-003 is bounded '
            'by a property of one jack and must not read the device total',
      );
      expect(linkCountForDevice(doc, connectAvr), 2);
    });
  });

  group('evaluateConnect — the tier-1 refusals', () {
    test('EVERY ConnectRule has a refusal case in this file', () {
      expect(
        connectRefusals().map((r) => r.rule).toSet(),
        ConnectRule.values.toSet(),
        reason:
            'a refusal mode with no exercised sentence is a spring-back '
            'the user cannot act on — DR-011.5 gives them no other '
            'recourse. Add a row above, do not relax this.',
      );
    });

    for (final c in connectRefusals()) {
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
      for (final c in connectRefusals()) {
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
          connectRefusals()
                  .firstWhere((r) => r.rule == ConnectRule.hostResolves)
                  .run()
              as ConnectRefused;

      final notContainer = connectDoc();
      connectAddDevice(
        notContainer,
        connectShelf,
        'SHF-1',
        connectBody(const []),
      );
      connectAddDevice(
        notContainer,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('hdmi.out.1')]),
        placement: const ShelfPlacement(
          hostDeviceId: connectShelf,
          order: FracIndex('a0'),
        ),
      );
      connectAddDevice(
        notContainer,
        connectTv,
        'TV-1',
        connectBody([connectPort('hdmi.in.1')]),
      );
      final v1 = evaluateConnect(
        notContainer,
        connectAvrOut(notContainer),
        connectTvIn(notContainer),
      );
      expect(v1, isA<ConnectRefused>());
      expect((v1 as ConnectRefused).rule, ConnectRule.hostResolves);
      expect(v1.message, contains('SHF-1'));
      expect(v1.message, isNot(missingHost.message));

      final cycle = connectDoc();
      connectAddDevice(
        cycle,
        connectShelf,
        'SHF-1',
        connectBody(const [], isContainer: true),
        placement: const ShelfPlacement(
          hostDeviceId: connectAvr,
          order: FracIndex('a0'),
        ),
      );
      connectAddDevice(
        cycle,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('hdmi.out.1')], isContainer: true),
        placement: const ShelfPlacement(
          hostDeviceId: connectShelf,
          order: FracIndex('a0'),
        ),
      );
      connectAddDevice(
        cycle,
        connectTv,
        'TV-1',
        connectBody([connectPort('hdmi.in.1')]),
      );
      final v2 = evaluateConnect(
        cycle,
        connectAvrOut(cycle),
        connectTvIn(cycle),
      );
      expect(v2, isA<ConnectRefused>());
      expect((v2 as ConnectRefused).rule, ConnectRule.hostResolves);
      expect(v2.message, contains('loops'));
      expect(v2.message, isNot(v1.message));
    });

    test('TOP-003 says a zero-max pin ACCEPTS NONE, not "0 of 0"', () {
      // "already carries 0 of 0" reads as a state the user could clear by
      // unplugging something. There is nothing to unplug.
      final doc = connectPair(avrMax: 0);
      final v =
          evaluateConnect(doc, connectAvrOut(doc), connectTvIn(doc))
              as ConnectRefused;
      expect(v.rule, ConnectRule.withinMaxConnections);
      expect(v.message, 'AVR-1 J01 accepts no connections.');
    });

    test('TOP-002 is scoped to ONE link — a fresh link cannot duplicate', () {
      // Canon: "two conductors may not duplicate the same ordered port
      // pair ON THE SAME LINK". A second cable between the same two pins
      // is legal; reading the rule document-wide would make a redundant
      // run model-ILLEGAL with no escape, which is a rule canon does not
      // have (§5: "a rule not listed here does not exist").
      final doc = connectPair(avrMax: 4, tvMax: 4);
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      expect(
        evaluateConnect(doc, from, to),
        isA<ConnectAllowed>(),
        reason: 'no ontoLink means a NEW link, where TOP-002 cannot fire',
      );
    });

    test('TOP-002 ignores the REVERSED pair', () {
      final doc = connectPair(avrMax: 4, tvMax: 4);
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      final id = connectLink(
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

  group('evaluateConnect — the near-miss for every refusal (AC-051)', () {
    test('EVERY ConnectRule has a near-miss case in this file', () {
      expect(
        connectNearMisses().map((n) => n.rule).toSet(),
        ConnectRule.values.toSet(),
        reason:
            'a rule with a known-bad and no known-good near-miss is a rule '
            'proven to FIRE and not proven to DISCRIMINATE. `return '
            'refused` satisfies the refusal table above and nothing else. '
            'Add a row, do not relax this.',
      );
    });

    for (final n in connectNearMisses()) {
      test('${n.rule.id} accepts when ${n.what}', () {
        expect(
          n.run(),
          isA<ConnectAllowed>(),
          reason:
              '${n.rule.id} refused a case one property away from its own '
              'known-bad, so the rule is wider than the catalogue says',
        );
      });
    }

    test('the two tables are the same size and cover the same rules, so '
        'neither can grow without the other', () {
      expect(connectNearMisses(), hasLength(connectRefusals().length));
      expect(
        connectNearMisses().map((n) => n.rule).toSet(),
        connectRefusals().map((r) => r.rule).toSet(),
      );
    });
  });

  group('evaluateConnect — a legal pair is accepted', () {
    test('two unmaterialised pins on two devices connect', () {
      final doc = connectPair();
      expect(
        evaluateConnect(doc, connectAvrOut(doc), connectTvIn(doc)),
        isA<ConnectAllowed>(),
      );
    });

    test('a source-to-source pair is NOT refused — DIR-001 is tier 2', () {
      // The gesture may hesitate; the document may not lie (CR-017). A T2
      // condition implemented as a T1 refusal makes the product unable to
      // document a system it was called in to fix.
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('hdmi.out.1')]),
      );
      connectAddDevice(
        doc,
        connectTv,
        'TV-1',
        connectBody([connectPort('hdmi.in.1')]),
      );
      // Both declared `source`, which DIR-001 flags — in M5.
      for (final d in [connectAvr, connectTv]) {
        final body = doc.templates['tpl.${d.v}@1']!.body;
        for (final p in body.ports) {
          p.direction = PortDirection.source;
        }
      }
      expect(
        evaluateConnect(doc, connectAvrOut(doc), connectTvIn(doc)),
        isA<ConnectAllowed>(),
      );
    });

    test('a loopback between two DIFFERENT pins on one device is legal', () {
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([
          connectPort('a'),
          connectPort('b', order: 'a1'),
        ]),
      );
      final a = resolveConnectTarget(doc, deviceId: connectAvr, portKey: 'a')!;
      final b = resolveConnectTarget(doc, deviceId: connectAvr, portKey: 'b')!;
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
      final doc = connectPair();
      // Both targets are resolved BEFORE the removal — which is exactly
      // the gesture: the user grabs a pin, and the device goes away
      // under them (a delete on another surface, or an undo).
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      expect(evaluateConnect(doc, from, to), isA<ConnectAllowed>());

      final controller = DocumentController(doc, clock: FixedClock(connectWhen))
        ..run(RemoveDeviceCommand(id: connectAvr));
      expect(doc.devices.containsKey(connectAvr), isFalse);

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
      final doc = connectPair();
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      RemoveDeviceCommand(id: connectTv).apply(doc);

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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'CP-1',
        connectBody([
          connectPort(
            'cresnet',
            family: 'ctl.cresnet',
            direction: direction,
            topology: topology,
          ),
        ]),
      );
      connectAddDevice(
        doc,
        connectTv,
        'KP-1',
        connectBody([connectPort('cresnet', family: 'ctl.cresnet')]),
      );
      return doc;
    }

    test('a busNode pin takes a SECOND drop', () {
      final doc = busDoc();
      final bus = connectPin(doc, connectAvr, 'cresnet');
      expect(bus.isMultidrop, isTrue);
      expect(
        bus.effectiveMaxConnections,
        isNull,
        reason: 'null is UNBOUNDED — a tap on a shared medium',
      );

      // KP-1 is already on the bus.
      connectLink(
        doc,
        'W001',
        PortEndpoint(bus.portId),
        const OpenEndpoint('KP-1'),
      );
      expect(portConductorCount(doc, bus.portId), 1);

      expect(
        evaluateConnect(doc, bus, connectPin(doc, connectTv, 'cresnet')),
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
      final bus = connectPin(doc, connectAvr, 'cresnet');
      expect(bus.isMultidrop, isTrue);
      expect(bus.effectiveMaxConnections, isNull);
    });

    test('a p2p pin is still bounded at 1 — this widens nothing else', () {
      final doc = busDoc(direction: PortDirection.source);
      final pin = connectPin(doc, connectAvr, 'cresnet');
      expect(pin.isMultidrop, isFalse);
      expect(pin.effectiveMaxConnections, 1);

      connectLink(
        doc,
        'W001',
        PortEndpoint(pin.portId),
        const OpenEndpoint('x'),
      );
      final refused =
          evaluateConnect(doc, pin, connectPin(doc, connectTv, 'cresnet'))
              as ConnectRefused;
      expect(refused.rule, ConnectRule.withinMaxConnections);
      expect(refused.message, contains('1 of 1'));
    });

    test('a DECLARED bound above 1 wins over the bus fact', () {
      // `ir.out.1` in docs/catalog/seed-devices.md declares
      // `maxConnections: 2` — a real authored bound (two IR emitters on
      // one 3.5 mm output). Only the DEFAULT 1, which a template reaches
      // by saying nothing, yields to `busNode`.
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AMP-1',
        connectBody([
          connectPort(
            'cv.a',
            maxConnections: 2,
            direction: PortDirection.busNode,
          ),
        ]),
      );
      final pin = connectPin(doc, connectAvr, 'cv.a');
      expect(pin.isMultidrop, isTrue);
      expect(pin.effectiveMaxConnections, 2);
    });

    test('a declared ZERO still means "not a socket", bus or not', () {
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AMP-1',
        connectBody([
          connectPort(
            'cv.a',
            maxConnections: 0,
            direction: PortDirection.busNode,
          ),
        ]),
      );
      connectAddDevice(
        doc,
        connectTv,
        'SPK-1',
        connectBody([connectPort('in')]),
      );
      final refused =
          evaluateConnect(
                doc,
                connectPin(doc, connectAvr, 'cv.a'),
                connectPin(doc, connectTv, 'in'),
              )
              as ConnectRefused;
      expect(refused.message, endsWith('accepts no connections.'));
    });

    test('THE REAL CATALOG: C01 + two F13 keypads is a legal bus', () {
      // The seed catalog itself, not a fixture: `ctl.cresnet` on C01 and
      // on F13 are both declared `BUS` (`PortDirection.busNode`), and
      // §4.4 gives the family `MD` topology.
      final doc = connectDoc();
      connectSeedDevice(doc, const Uuid('dev-cp'), 'C01', 'CP-1');
      connectSeedDevice(doc, const Uuid('dev-kp1'), 'F13', 'KP-1');
      connectSeedDevice(doc, const Uuid('dev-kp2'), 'F13', 'KP-2');

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

      connectLink(
        doc,
        'W001',
        PortEndpoint(cp.portId),
        const OpenEndpoint('KP-1'),
      );
      final kp2 = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-kp2'),
        portKey: 'cresnet',
      )!;
      expect(evaluateConnect(doc, cp, kp2), isA<ConnectAllowed>());
    });

    test('THE REAL CATALOG: A05 70V out feeds two F08 pendants', () {
      final doc = connectDoc();
      connectSeedDevice(doc, const Uuid('dev-amp'), 'A05', 'AMP-1');
      connectSeedDevice(doc, const Uuid('dev-spk1'), 'F08', 'SPK-1');
      connectSeedDevice(doc, const Uuid('dev-spk2'), 'F08', 'SPK-2');

      final cv = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-amp'),
        portKey: 'cv.a',
      )!;
      connectLink(
        doc,
        'W001',
        PortEndpoint(cv.portId),
        const OpenEndpoint('SPK-1'),
      );

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
      final doc = connectPair();
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      doc.tombstones[from.portId] = Tombstone(
        deletedAt: connectWhen,
        entityType: 'Port',
        by: 'test',
      );
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
      expect(
        (evaluateConnect(doc, from, to) as ConnectRefused).rule,
        ConnectRule.endpointResolves,
      );
    });

    test('TOP-005 beats TOP-001', () {
      final doc = connectPair();
      final from = connectAvrOut(doc);
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
      expect(
        (evaluateConnect(doc, from, from) as ConnectRefused).rule,
        ConnectRule.hostResolves,
      );
    });

    test('TOP-001 beats TOP-002', () {
      final doc = connectPair(avrMax: 4);
      final from = connectAvrOut(doc);
      final id = connectLink(
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
      final doc = connectPair();
      final from = connectAvrOut(doc);
      final to = connectTvIn(doc);
      final id = connectLink(
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([connectPort('out', family: 'a.b')]),
      );
      final t = resolveConnectTarget(
        doc,
        deviceId: connectAvr,
        portKey: 'out',
      )!;
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'AVR-1',
        connectBody([
          PortDef(
            key: const PortKey('out'),
            label: 'OUT',
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('video.hdbaset'),
            face: Face.rear,
            position: connectPos,
            order: const FracIndex('a0'),
            // The exclusion case seed_registries.dart:394 describes,
            // authored the other way round: a pin that also takes IR.
            acceptedFamilies: const [SignalFamilyId('ctl.ir')],
          ),
        ]),
      );
      final t = resolveConnectTarget(
        doc,
        deviceId: connectAvr,
        portKey: 'out',
      )!;
      expect(t.acceptsFamily(const SignalFamilyId('ctl.ir')), isTrue);
      expect(
        t.acceptsFamily(const SignalFamilyId('video.hdbaset')),
        isTrue,
        reason:
            'a template that excluded its own signalFamily would be '
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
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'MTX-1',
        connectBody([
          connectPort('in.1', direction: PortDirection.sink),
          connectPort(
            'out.1',
            direction: PortDirection.source,
            order: 'a1',
            family: outFamily,
            maxConnections: maxConnections,
          ),
          connectPort(
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
        deviceId: connectAvr,
        family: const SignalFamilyId('video.hdmi.2_1'),
      );
      expect(next!.portKey.v, 'out.1');
    });

    test('a FULL output is skipped and the next one wins — the chain does '
        'not stop at an occupied jack', () {
      final doc = withChainDevice();
      connectLink(
        doc,
        'W1',
        PortEndpoint(derivePortId(connectAvr, const PortKey('out.1'))),
        const OpenEndpoint('to the field'),
      );
      expect(
        chainOutputFor(
          doc,
          deviceId: connectAvr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        )!.portKey.v,
        'out.2',
      );
    });

    test('a SINK is never the answer, however well its family matches', () {
      // The whole point of "output": a chain that re-armed from an input
      // would draw a cable back the way it came.
      final doc = withChainDevice();
      connectLink(
        doc,
        'W1',
        PortEndpoint(derivePortId(connectAvr, const PortKey('out.1'))),
        const OpenEndpoint('to the field'),
      );
      connectLink(
        doc,
        'W2',
        PortEndpoint(derivePortId(connectAvr, const PortKey('out.2'))),
        const OpenEndpoint('to the field'),
      );
      expect(
        chainOutputFor(
          doc,
          deviceId: connectAvr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        ),
        isNull,
        reason:
            'both outputs are full and in.1 is a sink, so the chain '
            'ends rather than turning round',
      );
    });

    test('a different family ends the chain rather than proposing a jack '
        'that cannot carry it', () {
      final doc = withChainDevice();
      expect(
        chainOutputFor(
          doc,
          deviceId: connectAvr,
          family: const SignalFamilyId('audio.speaker'),
        ),
        isNull,
      );
    });

    test('a BUS NODE is a valid chain output — reading `source` alone '
        'would end the chain at every bus device in the catalog', () {
      final doc = connectDoc();
      connectAddDevice(
        doc,
        connectAvr,
        'IRB-1',
        connectBody([
          connectPort(
            'bus.1',
            direction: PortDirection.busNode,
            family: 'ctl.ir',
          ),
        ]),
      );
      final next = chainOutputFor(
        doc,
        deviceId: connectAvr,
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
          connectDoc(),
          deviceId: connectAvr,
          family: const SignalFamilyId('video.hdmi.2_1'),
        ),
        isNull,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // TOP-003 OVER THE REAL CATALOG (M5-H2, DR-124)
  // ═══════════════════════════════════════════════════════════════════
  // THE AC-051 PAIR COULD NOT HAVE FOUND THIS AND THAT IS THE LESSON.
  // `TOP-003`'s fixtures build a synthetic port and pass `maxConnections`
  // in explicitly (`connectPair(avrMax: 4)`), so both halves passed while
  // every shipped IR output refused a legal second conductor. A rule
  // exercised only against ports the test itself authored is a rule
  // tested against its own assumptions.
  //
  // The finding came from the domain review: a dual-head IR flasher
  // (Episode IRF-2) is ONE 3.5 mm plug with TWO heads, and Control4's
  // Composer Pro models exactly that. `docs/catalog/seed-devices.md` had
  // documented `"maxConnections": 2` on `ir.out.1` since M0; the catalog
  // builder had no parameter to carry it.
  group('TOP-003 against seeded devices', () {
    test('every IR emitter OUTPUT in the catalog accepts two conductors', () {
      final catalog = buildSeedCatalog();
      final emitters = <String>[];
      final wrong = <String>[];
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          if (port.signalFamily.v == 'ctl.ir_emitter' &&
              port.direction == PortDirection.source) {
            final at = '${entry.key}/${port.key.v}';
            emitters.add(at);
            if (port.maxConnections != 2) {
              wrong.add('$at declares ${port.maxConnections}');
            }
          }
        }
      }
      // NOT VACUOUS: a census that found no emitter outputs would report
      // no offenders and pass, which is this repository's recurring shape.
      expect(emitters, isNotEmpty, reason: 'no IR emitter outputs found');
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('a second head lands on a seeded IR output, and a third refuses', () {
      // V01 is the matrix with `ir.out.1`..`ir.out.8`, which is the port
      // seed-devices.md names. The body is the SHIPPED one, so this fails
      // if the catalog stops declaring the bound.
      final body = buildSeedCatalog()['V01']!;
      final doc = connectDoc();
      connectAddDevice(doc, connectAvr, 'AVR-1', body);
      connectAddDevice(
        doc,
        connectTv,
        'TV-1',
        connectBody([connectPort('ir.in', maxConnections: 4)]),
      );

      final from = resolveConnectTarget(
        doc,
        deviceId: connectAvr,
        portKey: 'ir.out.1',
      )!;
      final to = resolveConnectTarget(
        doc,
        deviceId: connectTv,
        portKey: 'ir.in',
      )!;

      // Head one.
      connectLink(
        doc,
        'W001',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      // Head two: the case the review found refused.
      final second = evaluateConnect(doc, from, to);
      expect(
        second is ConnectRefused &&
            second.rule == ConnectRule.withinMaxConnections,
        isFalse,
        reason: 'a dual-head flasher must reach its second head, got $second',
      );
      connectLink(
        doc,
        'W002',
        PortEndpoint(from.portId),
        PortEndpoint(to.portId),
      );
      // Head three: three or more needs another port or an expansion
      // block, so the bound is still a bound.
      final third = evaluateConnect(doc, from, to);
      expect(third, isA<ConnectRefused>());
      expect((third as ConnectRefused).rule, ConnectRule.withinMaxConnections);
      // The sentence is the whole recourse at tier 1, so it must name the
      // real bound rather than the rule id.
      expect(third.message, contains('2 of 2'));
    });
  });
}
