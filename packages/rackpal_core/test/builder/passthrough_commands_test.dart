// `#225` (M4-J3) — pairing, unpairing, and DR-087's additive run.
//
// ═════════════════════════════════════════════════════════════════════
// THE CASE THIS FILE EXISTS FOR IS `a second run touches only the new`
// ═════════════════════════════════════════════════════════════════════
// DR-087 §11.86.2 makes the action additive because replacing every pair
// puts a hand-corrected crossing back on one press. A test that ran it
// once over a blank panel proves the pairing and says nothing about the
// property that decided the design; the cases below run it twice, and
// once over a panel somebody has already crossed on purpose.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  required String order,
  required Face face,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: face,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: PortDirection.passive,
);

/// A four-position panel: F1..F4 front, R1..R4 rear, nothing paired.
TemplateBody _panel({int positions = 4, bool passthrough = true}) {
  final body = TemplateBody(
    manufacturer: 'Generic',
    model: 'PP-4',
    displayName: 'Panel',
    frontU: 1,
    isPassthrough: passthrough,
  );
  for (var i = 1; i <= positions; i++) {
    body.ports.add(_port('f$i', order: 'a${100 + i}', face: Face.front));
  }
  for (var i = 1; i <= positions; i++) {
    body.ports.add(_port('r$i', order: 'a${200 + i}', face: Face.rear));
  }
  return body;
}

void applyAll(List<Command<TemplateBody>> commands, TemplateBody body) {
  for (final command in commands) {
    command.apply(body);
  }
}

List<String> _pairsOf(TemplateBody body) => [
  for (final p in body.passthroughPairs) '${p.frontKey.v}->${p.rearKey.v}',
];

void main() {
  group('DR-087 §11.86.2: the run is additive and idempotent', () {
    test('a blank panel pairs front to rear in declared order', () {
      final body = _panel();
      final result = buildPairFrontToRearByOrder(body: body);

      expect(result.isRefused, isFalse);
      applyAll(result.commands, body);

      expect(_pairsOf(body), ['f1->r1', 'f2->r2', 'f3->r3', 'f4->r4']);
      expect(body.passthroughPairs.every((p) => p.sameNet), isTrue);
    });

    test('A SECOND RUN REFUSES, because there is nothing unpaired left', () {
      final body = _panel();
      applyAll(buildPairFrontToRearByOrder(body: body).commands, body);

      expect(
        buildPairFrontToRearByOrder(body: body).refusal,
        PairByOrderRefusal.nothingToPair,
      );
    });

    test('A HAND-CORRECTED CROSSING SURVIVES A RUN, which is the whole '
        'reason the action is additive rather than replacing', () {
      final body = _panel();
      // Somebody punched F1 down on R2 and F2 on R1, and said so.
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f1'),
          partnerKey: const PortKey('r2'),
        ),
        body,
      );
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f2'),
          partnerKey: const PortKey('r1'),
        ),
        body,
      );

      applyAll(buildPairFrontToRearByOrder(body: body).commands, body);

      expect(_pairsOf(body), ['f1->r2', 'f2->r1', 'f3->r3', 'f4->r4']);
    });

    test(
      'adding two more positions and running again pairs only those two',
      () {
        final body = _panel();
        applyAll(buildPairFrontToRearByOrder(body: body).commands, body);
        body.ports.addAll([
          _port('f5', order: 'a105', face: Face.front),
          _port('r5', order: 'a205', face: Face.rear),
        ]);

        final second = buildPairFrontToRearByOrder(body: body);
        expect(second.commands, hasLength(1));
        applyAll(second.commands, body);
        expect(_pairsOf(body).last, 'f5->r5');
      },
    );

    test('UNEQUAL FACES PAIR WHAT THEY CAN AND REPORT THE REST, which is '
        'the seeded fibre LIU (12 front over 24 rear)', () {
      final body = _panel();
      body.ports.addAll([
        _port('r5', order: 'a205', face: Face.rear),
        _port('r6', order: 'a206', face: Face.rear),
      ]);

      final result = buildPairFrontToRearByOrder(body: body);
      expect(result.commands, hasLength(4));
      expect(result.leftOverRear, 2);
      expect(result.leftOverFront, 0);
      expect(
        pairByOrderOutcome(result),
        'Paired 4 ports. 2 rear ports had no partner left.',
      );
    });

    test('a template that is not a passthrough refuses in words', () {
      final result = buildPairFrontToRearByOrder(
        body: _panel(passthrough: false),
      );
      expect(result.refusal, PairByOrderRefusal.notAPassthrough);
      expect(
        pairByOrderRefusalMessage(result.refusal!),
        contains('not a passthrough'),
      );
    });

    test(
      'and a sorted view refuses, because pairs go on in DECLARED order',
      () {
        final result = buildPairFrontToRearByOrder(
          body: _panel(),
          viewIsSorted: true,
        );
        expect(result.refusal, PairByOrderRefusal.theViewIsSorted);
      },
    );

    test('reverted backwards, the panel is exactly what it was', () {
      final body = _panel();
      final commands = buildPairFrontToRearByOrder(body: body).commands;
      applyAll(commands, body);
      for (final command in commands.reversed) {
        command.revert(body);
      }
      expect(body.passthroughPairs, isEmpty);
    });
  });

  group('DR-087 §11.86.3: the options are the validation', () {
    test('only the OTHER face, and only what is unpaired', () {
      final body = _panel();
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f1'),
          partnerKey: const PortKey('r1'),
        ),
        body,
      );

      expect(
        passthroughPartners(body, const PortKey('f2')).map((p) => p.key.v),
        ['r2', 'r3', 'r4'],
        reason: 'r1 is taken, and no front port is ever offered',
      );
    });

    test('A PAIRED ROW STILL SEES ITS OWN PARTNER, or opening the picker '
        'would show an empty box on a row that plainly has a value', () {
      final body = _panel();
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f1'),
          partnerKey: const PortKey('r1'),
        ),
        body,
      );

      expect(
        passthroughPartners(body, const PortKey('f1')).map((p) => p.key.v),
        ['r1', 'r2', 'r3', 'r4'],
      );
    });

    test('a rear row is offered fronts', () {
      expect(
        passthroughPartners(_panel(), const PortKey('r1')).map((p) => p.key.v),
        ['f1', 'f2', 'f3', 'f4'],
      );
    });
  });

  group('the cell writes both ends the right way round', () {
    test('THE FACE DECIDES WHICH KEY IS WHICH, not the argument order', () {
      final body = _panel();
      // Pairing FROM the rear row: the pair must still read f1 -> r1.
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('r1'),
          partnerKey: const PortKey('f1'),
        ),
        body,
      );

      expect(_pairsOf(body), ['f1->r1']);
    });

    test(
      're-pairing removes the old pair FIRST, so no port ever holds two',
      () {
        final body = _panel();
        applyAll(
          buildSetPassthroughPartner(
            body: body,
            portKey: const PortKey('f1'),
            partnerKey: const PortKey('r1'),
          ),
          body,
        );

        final commands = buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f1'),
          partnerKey: const PortKey('r2'),
        );
        expect(commands.first, isA<RemovePassthroughPairCommand>());
        applyAll(commands, body);
        expect(_pairsOf(body), ['f1->r2']);
      },
    );

    test(
      'a blank unpairs, and pairing to what is already there is a no-op',
      () {
        final body = _panel();
        applyAll(
          buildSetPassthroughPartner(
            body: body,
            portKey: const PortKey('f1'),
            partnerKey: const PortKey('r1'),
          ),
          body,
        );

        expect(
          buildSetPassthroughPartner(
            body: body,
            portKey: const PortKey('f1'),
            partnerKey: const PortKey('r1'),
          ),
          isEmpty,
        );

        applyAll(
          buildSetPassthroughPartner(
            body: body,
            portKey: const PortKey('f1'),
            partnerKey: null,
          ),
          body,
        );
        expect(body.passthroughPairs, isEmpty);
      },
    );

    test('the partner reads the same from either end', () {
      final body = _panel();
      applyAll(
        buildSetPassthroughPartner(
          body: body,
          portKey: const PortKey('f1'),
          partnerKey: const PortKey('r1'),
        ),
        body,
      );

      expect(passthroughPartnerOf(body, const PortKey('f1'))?.v, 'r1');
      expect(passthroughPartnerOf(body, const PortKey('r1'))?.v, 'f1');
      expect(passthroughPartnerOf(body, const PortKey('f2')), isNull);
    });
  });

  group('the seeded catalog, which is what the ruling was about', () {
    test('N03 is fully paired and a run over it has nothing to do', () {
      final n03 = buildSeedCatalog()['N03']!;
      expect(n03.isPassthrough, isTrue);
      expect(n03.passthroughPairs, hasLength(24));
      expect(
        buildPairFrontToRearByOrder(body: n03).refusal,
        PairByOrderRefusal.nothingToPair,
      );
    });

    test('N04 IS A PASSTHROUGH THE MODEL CANNOT EXPRESS, and it ships '
        'unpaired on purpose (DR-087 §11.86.4)', () {
      final n04 = buildSeedCatalog()['N04']!;
      expect(n04.isPassthrough, isTrue);
      expect(n04.passthroughPairs, isEmpty);

      final fronts = n04.ports.where((p) => p.face == Face.front).length;
      final rears = n04.ports.where((p) => p.face == Face.rear).length;
      expect(fronts, 12, reason: '12 duplex LC adapters');
      expect(rears, 24, reason: '24 splices, two per adapter');
      expect(
        rears,
        fronts * 2,
        reason:
            'the relation is 1 front to 2 rear, and PassthroughPairDef '
            'holds one key each side, so no pairing here can be true',
      );
    });

    test('and its ports carry the unpaired notice, which is the honest '
        'report of that', () {
      final issues = validatePorts(buildSeedCatalog()['N04']!);
      final unpaired = issues.values
          .expand((l) => l)
          .where((i) => i.column == PortColumnId.pairedPort);
      expect(unpaired, hasLength(36));
      expect(
        unpaired.every((i) => i.severity == PortIssueSeverity.notice),
        isTrue,
        reason: 'docs/06 §4.6: a missing pair is a load warning, not an error',
      );
    });
  });
}
