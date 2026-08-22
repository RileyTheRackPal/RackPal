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
import 'package:rackmate_core/rackmate_core.dart';
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
      position: kUnplacedPanelPosition,
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
}
