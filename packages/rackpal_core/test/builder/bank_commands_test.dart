// #223 (M4-J1) — `BankDef` CRUD and DR-085's mirror.
//
// ═════════════════════════════════════════════════════════════════════
// THE CASE THIS FILE EXISTS FOR IS `an already-loose port stays loose`
// ═════════════════════════════════════════════════════════════════════
// `RemoveBankCommand` un-bands the ports that named the bank, so its
// revert has to re-band EXACTLY those and no others. A revert written as
// "set every bankless port back to this bank" passes a naive round-trip
// case and quietly captures ports that were never in the bank at all,
// which the undo stack would then make permanent. The command captures the
// set it touched for that reason and the case below is what proves it.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(String key, {String? bank, PortDirection dir = kSource}) =>
    PortDef(
      key: PortKey(key),
      label: key,
      connector: const ConnectorTypeId('conn.hdmi_a'),
      signalFamily: const SignalFamilyId('video.hdmi.2_1'),
      direction: dir,
      bankKey: bank,
      face: Face.rear,
      order: const FracIndex('a0000'),
    );

const PortDirection kSource = PortDirection.source;

TemplateBody _body() => TemplateBody(
  manufacturer: 'Generic',
  model: 'M',
  displayName: 'Mirror probe',
  category: 'Video Distribution & Switching',
  frontU: 1,
  banks: [
    BankDef(
      key: 'inputs',
      label: 'IN',
      abbr: 'IN',
      order: const FracIndex('a0000'),
    ),
    BankDef(
      key: 'other',
      label: 'Other',
      abbr: 'OTH',
      order: const FracIndex('a1000'),
    ),
  ],
  ports: [
    _port('inputs.1', bank: 'inputs'),
    _port('inputs.2', bank: 'inputs'),
    _port('other.1', bank: 'other'),
    _port('loose.1'),
  ],
);

/// `_body()` with the four ports given DISTINCT orders.
///
/// The shared fixture gives every port `a0000`, so `portsInDeclaredOrder`
/// tie-breaks on the key and `loose.1` lands ahead of `other.1`. That is
/// correct and it is not what the banding tests are about, so they read a
/// body whose declared order is stated rather than incidental.
TemplateBody _ordered() {
  final body = _body();
  const orders = ['a0000', 'a1000', 'a2000', 'a3000'];
  for (var i = 0; i < body.ports.length; i++) {
    body.ports[i].order = FracIndex(orders[i]);
  }
  return body;
}

void main() {
  group('rename writes both strings and puts both back', () {
    test('label and abbr change together', () {
      final b = _body();
      RenameBankCommand('inputs', toLabel: 'Sources', toAbbr: 'SRC').apply(b);

      final bank = b.banks.firstWhere((x) => x.key == 'inputs');
      expect(bank.label, 'Sources');
      expect(bank.abbr, 'SRC');
    });

    test('and revert restores what was there, not a default', () {
      final b = _body();
      RenameBankCommand('inputs', toLabel: 'Sources', toAbbr: 'SRC')
        ..apply(b)
        ..revert(b);

      final bank = b.banks.firstWhere((x) => x.key == 'inputs');
      expect(bank.label, 'IN');
      expect(bank.abbr, 'IN');
    });

    test('renaming a bank that is not there throws rather than doing '
        'nothing quietly', () {
      expect(
        () =>
            RenameBankCommand('nope', toLabel: 'x', toAbbr: 'y').apply(_body()),
        throwsStateError,
      );
    });
  });

  group('remove keeps the ports, because a bank is presentation (CR-055)', () {
    test('the bank goes and every port survives, un-banded', () {
      final b = _body();
      RemoveBankCommand('inputs').apply(b);

      expect(b.banks.map((x) => x.key), ['other']);
      expect(b.ports, hasLength(4), reason: 'no port may be destroyed');
      expect(
        b.ports.where((p) => p.bankKey == 'inputs'),
        isEmpty,
        reason: 'a dangling bankKey reads as a bank the user cannot see',
      );
    });

    test('revert puts the bank back AT ITS INDEX, because the codec reads '
        '`banks` in list order and CR-117 counts the bytes', () {
      final b = _body();
      RemoveBankCommand('inputs')
        ..apply(b)
        ..revert(b);

      expect(b.banks.map((x) => x.key), ['inputs', 'other']);
    });

    test('AN ALREADY-LOOSE PORT STAYS LOOSE ACROSS THE ROUND TRIP, which a '
        'revert written as "re-band every bankless port" would break', () {
      final b = _body();
      RemoveBankCommand('inputs')
        ..apply(b)
        ..revert(b);

      expect(
        b.ports.firstWhere((p) => p.key.v == 'loose.1').bankKey,
        isNull,
        reason: 'loose.1 was never in `inputs` and must not be captured',
      );
      expect(
        b.ports.where((p) => p.bankKey == 'inputs').map((p) => p.key.v),
        ['inputs.1', 'inputs.2'],
      );
      expect(
        b.ports.firstWhere((p) => p.key.v == 'other.1').bankKey,
        'other',
        reason: 'another bank is not this command to touch',
      );
    });
  });

  group('DR-085 §11.84.3: only source and sink have an opposite', () {
    test('source and sink flip', () {
      expect(mirroredDirection(PortDirection.source), PortDirection.sink);
      expect(mirroredDirection(PortDirection.sink), PortDirection.source);
    });

    test('the other three are returned unchanged, because inventing an '
        'opposite is a guess made on a port somebody has to wire', () {
      for (final d in [
        PortDirection.bidirectional,
        PortDirection.busNode,
        PortDirection.passive,
      ]) {
        expect(mirroredDirection(d), d);
      }
    });
  });

  group('DR-085 §11.84.4: swap where the words occur, otherwise null', () {
    test('whole words swap, and the case the author typed survives', () {
      expect(swapInOut('IN'), 'OUT');
      expect(swapInOut('OUT 1'), 'IN 1');
      expect(swapInOut('Line Out'), 'Line In');
      expect(swapInOut('in'), 'out');
    });

    test('ROUTING does not become ROUTOUTG, which is why it is whole words '
        'and not a substring', () {
      expect(swapInOut('ROUTING'), isNull);
      expect(swapInOut('Input'), isNull);
    });

    test('a bank with nothing to swap answers NULL rather than a guess, '
        'which is the signal that a person names it', () {
      expect(swapInOut('HDMI'), isNull);
      expect(swapInOut('HDBaseT'), isNull);
    });
  });

  group('DR-085 §11.84.5: the mirror plans new ports under a new key', () {
    test('the new bank key is unique and the ports hang off it', () {
      final b = _body();
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      expect(b.banks.map((x) => x.key), isNot(contains(plan.bank.key)));
      expect(plan.ports, hasLength(2));
      expect(plan.ports.every((p) => p.bankKey == plan.bank.key), isTrue);
    });

    test('the keys are NEW and collide with nothing, and no renamedFrom is '
        'written, because these are new ports rather than renamed ones '
        '(CR-051)', () {
      final b = _body();
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      final existing = b.ports.map((p) => p.key.v).toSet();
      for (final p in plan.ports) {
        expect(existing, isNot(contains(p.key.v)));
        expect(p.renamedFrom, isEmpty);
      }
    });

    test('directions flip and the source bank is left exactly as it was', () {
      final b = _body();
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      expect(plan.ports.every((p) => p.direction == PortDirection.sink), true);
      expect(
        b.ports
            .where((p) => p.bankKey == 'inputs')
            .every(
              (p) => p.direction == PortDirection.source,
            ),
        isTrue,
        reason: 'planning is not applying: the plan must not mutate the body',
      );
    });

    test('notFlipped NAMES every port left alone, so a silent copy cannot '
        'read as a flip that failed', () {
      final b = _body()
        ..ports.add(
          _port('inputs.3', bank: 'inputs', dir: PortDirection.passive),
        );
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      expect(plan.notFlipped.map((k) => k.v), ['inputs.3']);
    });

    test('mirroring a bank that is not there throws', () {
      expect(
        () => planMirrorBank(
          _body(),
          sourceBankKey: 'nope',
          label: 'x',
          abbr: 'y',
        ),
        throwsStateError,
      );
    });
  });

  group('the bank tree is the grid own band order, not a second opinion', () {
    test('every band the grid draws is a row, in the same order', () {
      final rows = buildBankTree(_ordered());

      expect(
        rows.map((r) => r.key).toList(),
        ['inputs', 'other', null],
        reason: 'movableBanks bands by first appearance and the tree follows',
      );
      expect(rows.map((r) => r.portCount).toList(), [2, 1, 1]);
      expect(rows.last.label, kUnbandedBankLabel);
    });

    test('a declared bank with no ports is a row, because it has no band', () {
      final b = _body()
        ..banks.add(
          BankDef(
            key: 'empty',
            label: 'Empty',
            abbr: 'E',
            order: const FracIndex('a2000'),
          ),
        );

      final rows = buildBankTree(b);
      final empty = rows.singleWhere((r) => r.key == 'empty');
      expect(empty.portCount, 0);
      expect(empty.isDeclared, isTrue);
      expect(
        rows.last.key,
        'empty',
        reason: 'it has no band, so it appends past the ones that do',
      );
    });

    test('ONLY A ROW WITH A BankDef IS EDITABLE: the unbanded band and an '
        'undeclared key are places, not banks', () {
      final b = _body()..ports.add(_port('ghost.1', bank: 'ghost'));

      final rows = buildBankTree(b);
      expect(rows.singleWhere((r) => r.key == 'inputs').isDeclared, isTrue);
      expect(rows.singleWhere((r) => r.key == 'ghost').isDeclared, isFalse);
      expect(rows.singleWhere((r) => r.key == null).isDeclared, isFalse);
    });

    test('a bank order this template scrambles does NOT move a tree row', () {
      final b = _ordered();
      // `BankDef.order` now says `other` leads and `inputs` trails. The
      // ports say otherwise, and the ports are what the grid bands.
      b.banks[0].order = const FracIndex('a9000');

      expect(
        buildBankTree(b).map((r) => r.key).toList(),
        ['inputs', 'other', null],
        reason: 'the tree navigates the GRID, which bands by first appearance',
      );
    });
  });

  group('a duplicate bank label is refused, not suffixed', () {
    test('an existing label is taken, in any case', () {
      final b = _body();
      expect(bankLabelIsTaken(b, 'Other'), isTrue);
      expect(bankLabelIsTaken(b, '  other '), isTrue);
      expect(bankLabelIsTaken(b, 'Outputs'), isFalse);
    });

    test('A BANK MAY KEEP ITS OWN NAME, or Rename refuses on open', () {
      final b = _body();
      expect(bankLabelIsTaken(b, 'Other', exceptKey: 'other'), isFalse);
      expect(bankLabelIsTaken(b, 'Other', exceptKey: 'inputs'), isTrue);
    });
  });

  group('mirrorBankCommands', () {
    test('THE BANK LEADS, so no port ever names a bank that is not there', () {
      final b = _body();
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      final commands = mirrorBankCommands(plan);
      expect(commands.first, isA<AddBankCommand>());
      expect(commands.length, 1 + plan.ports.length);

      // Applied in order, every port finds its bank already declared.
      for (final command in commands) {
        if (command is AddPortCommand) {
          expect(b.banks.any((x) => x.key == command.port.bankKey), isTrue);
        }
        command.apply(b);
      }
      expect(b.ports.where((p) => p.bankKey == plan.bank.key).length, 2);
    });

    test('reverted backwards, the body is exactly what it was', () {
      final b = _body();
      final was = b.ports.length;
      final commands = mirrorBankCommands(
        planMirrorBank(b, sourceBankKey: 'inputs', label: 'OUT', abbr: 'OUT'),
      );

      for (final command in commands) {
        command.apply(b);
      }
      for (final command in commands.reversed) {
        command.revert(b);
      }

      expect(b.ports.length, was);
      expect(b.banks.map((x) => x.key), ['inputs', 'other']);
    });
  });

  group('the mirror preview is read off the plan, so it cannot lie', () {
    test('one row per copied port, before and after taken from the plan', () {
      final b = _ordered()
        ..ports.add(
          _port('inputs.3', bank: 'inputs', dir: PortDirection.busNode),
        );
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      final rows = mirrorBankImpact(b, plan, sourceBankKey: 'inputs');
      expect(rows.length, plan.ports.length);
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].after, portDirectionLabel(plan.ports[i].direction));
      }
      expect(rows.map((r) => r.key), ['inputs.1', 'inputs.2', 'inputs.3']);
    });

    test('ONLY THE ROWS THAT KEEP A DIRECTION CARRY A NOTE, which is what '
        'makes the summary say how many to check', () {
      final b = _ordered()
        ..ports.add(
          _port('inputs.3', bank: 'inputs', dir: PortDirection.busNode),
        );
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      final rows = mirrorBankImpact(b, plan, sourceBankKey: 'inputs');
      expect(portImpactNoteCount(rows), 1);
      expect(portImpactChanges(rows).length, 2);
      expect(
        rows.singleWhere((r) => r.key == 'inputs.3').note,
        contains('has no opposite'),
      );
      // `portImpactSummary` lives in `rackpal_ui`, which core may not
      // import; the sentence those two numbers produce is asserted there.
    });

    test('the rows the preview shows are the ports the commands add', () {
      final b = _ordered();
      final plan = planMirrorBank(
        b,
        sourceBankKey: 'inputs',
        label: 'OUT',
        abbr: 'OUT',
      );

      final rows = mirrorBankImpact(b, plan, sourceBankKey: 'inputs');
      final added = [
        for (final command in mirrorBankCommands(plan))
          if (command is AddPortCommand) command.port,
      ];
      expect(added.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].after, portDirectionLabel(added[i].direction));
      }
    });
  });
}
