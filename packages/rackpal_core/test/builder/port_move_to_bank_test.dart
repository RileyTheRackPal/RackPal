// `Ctrl+M` (M4-F10, `#700`, docs/06 §4.6, DR-078 §11.77.2).
//
// The task's trap is the first group: a move that writes `bankKey` and not
// `order` splits the destination band in two, because `port_table.dart`
// bands by first appearance over the declared order.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(String key, String order, {String? bank}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('sig.hdmi'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  bankKey: bank,
);

BankDef _bank(String key, String label, String order) =>
    BankDef(key: key, label: label, abbr: key, order: FracIndex(order));

TemplateBody _body(List<PortDef> ports, {List<BankDef> banks = const []}) =>
    TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: 'Test',
      ports: ports,
      banks: banks,
    );

TemplateBody _apply(TemplateBody body, PortMoveToBankResult result) {
  for (final command in result.commands) {
    command.apply(body);
  }
  return body;
}

/// The bands a person would SEE, as `buildPortTable` computes them, so the
/// assertions are about the artifact rather than about `bankKey` values.
///
/// FLATTENED TO STRINGS ON PURPOSE. The first draft returned a record
/// holding a `List`, and two lists with equal contents are never `==`, so
/// every assertion failed while printing two identical-looking values. A
/// shape that compares by value is worth more than a shape that reads
/// nicely in the source.
List<String> _bands(TemplateBody body) => [
  for (final band in buildPortTable(body).bands)
    '${band.title}: ${band.rows.map((r) => r.port.key.v).join(",")}',
];

/// A template with two banks: `in` holds i1..i3, `out` holds o1, o2.
TemplateBody _twoBanks() => _body(
  [
    _port('i1', 'a1', bank: 'in'),
    _port('i2', 'a2', bank: 'in'),
    _port('i3', 'a3', bank: 'in'),
    _port('o1', 'a4', bank: 'out'),
    _port('o2', 'a5', bank: 'out'),
  ],
  banks: [_bank('in', 'Inputs', 'a1'), _bank('out', 'Outputs', 'a2')],
);

void main() {
  group('a move writes order too, so the band does not split', () {
    test('a row from the middle lands at the END of the target band', () {
      final body = _twoBanks();
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['i2'],
          targetBankKey: 'out',
        ),
      );

      // TWO bands, not three. Without the `order` write, `i2` would carry
      // `bankKey: out` while sitting between `i1` and `i3`, and the grid
      // would draw Outputs, Inputs, Outputs.
      expect(_bands(body), ['Inputs: i1,i3', 'Outputs: o1,o2,i2']);
    });

    test('a block keeps its own relative order when it lands', () {
      final body = _twoBanks();
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['i1', 'i3'],
          targetBankKey: 'out',
        ),
      );
      expect(_bands(body), ['Inputs: i2', 'Outputs: o1,o2,i1,i3']);
    });

    test('moving a whole band out leaves the other band whole', () {
      final body = _twoBanks();
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['o1', 'o2'],
          targetBankKey: 'in',
        ),
      );
      expect(_bands(body), ['Inputs: i1,i2,i3,o1,o2']);
    });

    test('a selection spanning two banks all lands in the destination', () {
      final body = _twoBanks();
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['i1', 'o1'],
          targetBankKey: 'out',
        ),
      );
      // `o1` was already in `out` and still moves POSITION, because the
      // block has to land contiguously; only `i1` changes bank.
      expect(_bands(body), ['Inputs: i2,i3', 'Outputs: o2,i1,o1']);
    });
  });

  group('Not in a bank is a destination, both ways', () {
    test('a banded row can be unbanded', () {
      final body = _twoBanks();
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['i1'],
          targetBankKey: null,
        ),
      );
      expect(_bands(body), [
        'Inputs: i2,i3',
        'Outputs: o1,o2',
        'Not in a bank: i1',
      ]);
    });

    test('an unbanded row can join a bank', () {
      final body = _body(
        [
          _port('loose', 'a1'),
          _port('i1', 'a2', bank: 'in'),
        ],
        banks: [_bank('in', 'Inputs', 'a1')],
      );
      _apply(
        body,
        buildPortMoveToBank(
          body: body,
          selectedInOrder: ['loose'],
          targetBankKey: 'in',
        ),
      );
      expect(_bands(body), ['Inputs: i1,loose']);
    });
  });

  group('the destinations a dialog may offer (DR-078 section 11.77.2)', () {
    test('the bands that exist, in the order the person sees them', () {
      expect(movableBanks(_twoBanks()), [
        (key: 'in', label: 'Inputs', portCount: 3),
        (key: 'out', label: 'Outputs', portCount: 2),
      ]);
    });

    test('the unbanded band is offered when it has rows', () {
      final body = _body([
        _port('loose', 'a1'),
        _port('i1', 'a2', bank: 'in'),
      ]);
      expect(movableBanks(body).map((t) => t.label), [
        kUnbandedBankLabel,
        'in',
      ]);
    });

    test('a declared bank with no ports is still a destination', () {
      // The bank somebody just created in order to move ports into. It
      // has no band in the grid, so a count-the-bands rule misses it.
      final body = _body(
        [_port('i1', 'a1', bank: 'in')],
        banks: [_bank('in', 'Inputs', 'a1'), _bank('spare', 'Spare', 'a2')],
      );
      expect(movableBanks(body), [
        (key: 'in', label: 'Inputs', portCount: 1),
        (key: 'spare', label: 'Spare', portCount: 0),
      ]);
    });

    test('an undeclared bank key is offered under its own key', () {
      // Named by ports, defined by no BankDef: what a hand-edited file
      // leaves behind, and a state the grid already draws.
      final body = _body([_port('i1', 'a1', bank: 'ghost')]);
      expect(movableBanks(body), [
        (key: 'ghost', label: 'ghost', portCount: 1),
      ]);
    });

    test('nothing is ever minted: an empty template offers nothing', () {
      expect(movableBanks(_body(const [])), isEmpty);
    });
  });

  group('refusals are announced, never swallowed', () {
    test('nothing selected', () {
      expect(
        buildPortMoveToBank(
          body: _twoBanks(),
          selectedInOrder: const [],
          targetBankKey: 'out',
        ).refusal,
        PortMoveToBankRefusal.nothingSelected,
      );
    });

    test('the view is sorted, because a move rewrites order', () {
      expect(
        buildPortMoveToBank(
          body: _twoBanks(),
          selectedInOrder: const ['i1'],
          targetBankKey: 'out',
          viewIsSorted: true,
        ).refusal,
        PortMoveToBankRefusal.theViewIsSorted,
      );
    });

    test('already there is a refusal and not a no-op write', () {
      expect(
        buildPortMoveToBank(
          body: _twoBanks(),
          selectedInOrder: const ['i1', 'i2'],
          targetBankKey: 'in',
        ).refusal,
        PortMoveToBankRefusal.alreadyThere,
      );
    });

    test('every refusal has a sentence', () {
      for (final refusal in PortMoveToBankRefusal.values) {
        expect(portMoveToBankRefusalMessage(refusal), isNotEmpty);
      }
    });
  });

  group('undo puts the bank and the position back', () {
    test('reverting every command restores the bands', () {
      final body = _twoBanks();
      final before = _bands(body);
      final result = buildPortMoveToBank(
        body: body,
        selectedInOrder: ['i1', 'i2'],
        targetBankKey: 'out',
      );
      _apply(body, result);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }
      expect(_bands(body), before);
    });
  });
}
