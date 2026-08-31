// Reordering ports (M4-F4 `#211`, CR-027, DR-064, docs/06 §4.6).
//
// THE ASSERTIONS ARE THE ROW ORDER AND THE WRITE COUNT, which are the two
// halves of §4.6's sentence: "a reorder is one field write on one row, not
// a renumber of the bank". A test that pinned the minted `FracIndex`
// strings would pass while the rows came out backwards, and would fail the
// day the generator got shorter answers without anything being wrong.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(String key, {required String order, String? bank}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  order: FracIndex(order),
  bankKey: bank,
);

TemplateBody _body(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D')
      ..ports.addAll(ports);

/// One bank of four, `a` through `d`.
TemplateBody _oneBank() => _body([
  _port('a', order: 'a0', bank: 'in'),
  _port('b', order: 'a1', bank: 'in'),
  _port('c', order: 'a2', bank: 'in'),
  _port('d', order: 'a3', bank: 'in'),
]);

/// Two banks of three, declared one after the other.
TemplateBody _twoBanks() => _body([
  _port('a', order: 'a0', bank: 'in'),
  _port('b', order: 'a1', bank: 'in'),
  _port('c', order: 'a2', bank: 'in'),
  _port('x', order: 'a3', bank: 'out'),
  _port('y', order: 'a4', bank: 'out'),
  _port('z', order: 'a5', bank: 'out'),
]);

List<String> _run(TemplateBody body, PortReorderPlan plan) {
  expect(plan.refusal, null, reason: 'the plan refused');
  for (final command in plan.commands) {
    command.apply(body);
  }
  return [for (final port in portsInDeclaredOrder(body.ports)) port.key.v];
}

void main() {
  group('a reorder writes the rows that move and nothing else', () {
    test('moving one row writes exactly one port', () {
      final body = _oneBank();
      final plan = buildPortReorder(
        body: body,
        moving: const ['d'],
        afterKey: 'a',
      );
      expect(plan.commands, hasLength(1));
      expect(_run(body, plan), ['a', 'd', 'b', 'c']);
    });

    test('moving a block of three writes three, and not the four it '
        'passed', () {
      final body = _body([
        for (var i = 0; i < 7; i++) _port('p$i', order: 'a$i', bank: 'in'),
      ]);
      final plan = buildPortReorder(
        body: body,
        moving: const ['p4', 'p5', 'p6'],
        afterKey: 'p0',
      );
      expect(plan.commands, hasLength(3));
      expect(_run(body, plan), ['p0', 'p4', 'p5', 'p6', 'p1', 'p2', 'p3']);
    });

    test('the block keeps its own order, whichever end it entered from', () {
      final body = _oneBank();
      expect(
        _run(
          body,
          buildPortReorder(
            body: body,
            moving: const ['c', 'd'],
            afterKey: null,
          ),
        ),
        ['c', 'd', 'a', 'b'],
      );
    });

    test('dropping a block back where it already was writes nothing', () {
      final body = _oneBank();
      final plan = buildPortReorder(
        body: body,
        moving: const ['b'],
        afterKey: 'a',
      );
      expect(plan.isRefused, isFalse);
      expect(plan.commands, isEmpty);
    });

    test('a move is one undo away, because every write is reversible', () {
      final body = _oneBank();
      final plan = buildPortReorder(
        body: body,
        moving: const ['a', 'b'],
        afterKey: 'd',
      );
      expect(_run(body, plan), ['c', 'd', 'a', 'b']);
      for (final command in plan.commands.reversed) {
        command.revert(body);
      }
      expect(
        [for (final port in portsInDeclaredOrder(body.ports)) port.key.v],
        ['a', 'b', 'c', 'd'],
      );
    });
  });

  group('the band is a wall, and the bank below it is not stepped over', () {
    test('dropping at the foot of a band lands before the next bank, not '
        'after it', () {
      // The bands GROUP by bank, so a row dropped at the foot of its own
      // band would look identical either way on screen. It is not
      // identical in the file: landing past the next bank rewrites every
      // PORT_SEQ under it, and the silkscreen with it.
      final body = _twoBanks();
      expect(
        _run(
          body,
          buildPortReorder(body: body, moving: const ['a'], afterKey: 'c'),
        ),
        ['b', 'c', 'a', 'x', 'y', 'z'],
      );
    });

    test('dropping at the head of a band lands after the bank above it', () {
      final body = _twoBanks();
      expect(
        _run(
          body,
          buildPortReorder(body: body, moving: const ['z'], afterKey: null),
        ),
        ['a', 'b', 'c', 'z', 'x', 'y'],
      );
    });

    test('a destination in another bank is refused', () {
      final body = _twoBanks();
      expect(
        buildPortReorder(
          body: body,
          moving: const ['a'],
          afterKey: 'y',
        ).refusal,
        PortReorderRefusal.destinationIsNotInTheBand,
      );
    });

    test('a selection spanning two banks is refused, because it has no one '
        'band to land in', () {
      final body = _twoBanks();
      expect(
        buildPortReorder(
          body: body,
          moving: const ['c', 'x'],
          afterKey: 'a',
        ).refusal,
        PortReorderRefusal.crossesBanks,
      );
    });

    test('the no-bank band reorders like any other', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
        _port('c', order: 'a2', bank: 'in'),
      ]);
      expect(
        _run(
          body,
          buildPortReorder(body: body, moving: const ['b'], afterKey: null),
        ),
        ['b', 'a', 'c'],
      );
    });
  });

  group('Alt+Up and Alt+Down slide one row (DR-064)', () {
    test('up moves a row above the one it was under', () {
      final body = _oneBank();
      expect(
        _run(body, buildPortNudge(body: body, moving: const ['c'], up: true)),
        ['a', 'c', 'b', 'd'],
      );
    });

    test('down moves a row below the one it was over', () {
      final body = _oneBank();
      expect(
        _run(body, buildPortNudge(body: body, moving: const ['b'], up: false)),
        ['a', 'c', 'b', 'd'],
      );
    });

    test('a block of two slides as one', () {
      final body = _oneBank();
      expect(
        _run(
          body,
          buildPortNudge(body: body, moving: const ['c', 'd'], up: true),
        ),
        ['a', 'c', 'd', 'b'],
      );
    });

    test('a block with a gap in it closes up where it lands', () {
      // Non-contiguous is a real selection: Ctrl+click makes one in two
      // clicks. "One slot up" then has to mean something, and the rule is
      // that the block lands above the nearest row above it that is
      // staying put.
      final body = _oneBank();
      expect(
        _run(
          body,
          buildPortNudge(body: body, moving: const ['b', 'd'], up: true),
        ),
        ['b', 'd', 'a', 'c'],
      );
    });

    test('the top row refuses to go up, and says which wall it hit', () {
      final body = _oneBank();
      final plan = buildPortNudge(body: body, moving: const ['a'], up: true);
      expect(plan.refusal, PortReorderRefusal.atTheBandEdge);
      expect(
        portReorderRefusalMessage(plan.refusal!),
        contains('Bank column'),
      );
    });

    test('the bottom row refuses to go down', () {
      final body = _oneBank();
      expect(
        buildPortNudge(body: body, moving: const ['d'], up: false).refusal,
        PortReorderRefusal.atTheBandEdge,
      );
    });

    test('the top row of the SECOND bank refuses, rather than joining the '
        'bank above it', () {
      // The chosen ruling: an arrow key never retypes a port. Crossing the
      // boundary would change `bankKey`, which is a structural edit, and a
      // keystroke that silently makes one is how a template ends up with a
      // jack in the wrong bank on a printed panel.
      final body = _twoBanks();
      final plan = buildPortNudge(body: body, moving: const ['x'], up: true);
      expect(plan.refusal, PortReorderRefusal.atTheBandEdge);
      expect(body.ports.firstWhere((p) => p.key.v == 'x').bankKey, 'out');
    });

    test('nudging every row of a band at once refuses rather than doing '
        'nothing quietly', () {
      final body = _oneBank();
      expect(
        buildPortNudge(
          body: body,
          moving: const ['a', 'b', 'c', 'd'],
          up: true,
        ).refusal,
        PortReorderRefusal.atTheBandEdge,
      );
    });

    test('an empty selection is refused by name', () {
      final body = _oneBank();
      expect(
        buildPortNudge(body: body, moving: const [], up: true).refusal,
        PortReorderRefusal.nothingToMove,
      );
    });

    test('sliding down and back up returns the exact row order', () {
      final body = _oneBank();
      _run(body, buildPortNudge(body: body, moving: const ['a'], up: false));
      expect(
        _run(body, buildPortNudge(body: body, moving: const ['a'], up: true)),
        ['a', 'b', 'c', 'd'],
      );
    });
  });

  group('the refusal a hand-edited file can still produce', () {
    test('two rows with no index between them refuse rather than renumber '
        'the bank', () {
      // `nextOrder` cannot mint this pair any more (DR-064). A file edited
      // by hand can hold it, and CR-027 chose this field's type precisely
      // so that neighbours are never renumbered, so the honest answer is
      // to say so.
      final body = _body([
        _port('a', order: 'az', bank: 'in'),
        _port('b', order: 'az0', bank: 'in'),
        _port('c', order: 'b0', bank: 'in'),
      ]);
      final plan = buildPortReorder(
        body: body,
        moving: const ['c'],
        afterKey: 'a',
      );
      expect(plan.refusal, PortReorderRefusal.noRoomBetweenTheRows);
      expect(
        portReorderRefusalMessage(plan.refusal!),
        contains('never renumbers'),
      );
    });
  });

  group('a reorder is 64 ports deep, not 8', () {
    test('a patchbay built by Quick Add can be reordered at the row where '
        'the alphabet turned over', () {
      // The 63rd port is where `nextOrder` extends, which is where the old
      // `'0'` extension left a pair nothing could be dropped between. This
      // is the same fact `order_between_test.dart` asserts on the raw
      // chain, seen from the grid's end.
      final orders = <FracIndex>[];
      for (var n = 0; n < 64; n++) {
        orders.add(nextOrder(orders));
      }
      final body = _body([
        for (var n = 0; n < 64; n++)
          _port('p$n', order: orders[n].v, bank: 'in'),
      ]);

      expect(
        _run(
          body,
          buildPortNudge(body: body, moving: const ['p63'], up: true),
        ).sublist(61),
        ['p61', 'p63', 'p62'],
      );
    });
  });
}
