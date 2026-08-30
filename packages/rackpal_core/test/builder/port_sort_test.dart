// View-only sort and its commit (M4-F5 `#212`, DR-065, AC-058/D5).
//
// WHAT THESE PROTECT. The whole feature is a claim that clicking a header
// changes nothing in the file, so most of these assert the DECLARED order
// is untouched after a sort, which is the half a screenshot cannot show.
// The commit's cases assert the opposite half: that the one deliberate
// act does write, writes only what moves, and can be undone.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.hdmi_a'),
      displayName: 'HDMI Type A',
    ),
    const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rj45'),
      displayName: 'RJ45',
    ),
  },
);

PortDef _port(
  String key, {
  required String order,
  String? label,
  String? bank,
  int? impedance,
  ConnectorTypeId connector = const ConnectorTypeId('conn.hdmi_a'),
}) => PortDef(
  key: PortKey(key),
  label: label ?? key.toUpperCase(),
  connector: connector,
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  order: FracIndex(order),
  bankKey: bank,
  impedanceOhms: impedance,
);

TemplateBody _body(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D')
      ..ports.addAll(ports);

List<String> _rowLabels(PortTable table) => [
  for (final band in table.bands)
    for (final row in band.rows) row.port.label,
];

List<String> _declared(TemplateBody body) => [
  for (final port in portsInDeclaredOrder(body.ports)) port.label,
];

const PortSortDirection _asc = PortSortDirection.ascending;
const PortSortDirection _desc = PortSortDirection.descending;

void main() {
  group('a sort is a view, and the file does not move', () {
    test('sorting reorders the rows and NOT the declared order', () {
      // THE WHOLE FEATURE IN ONE CASE. Everything else here is a detail
      // of this claim.
      final body = _body([
        _port('c', order: 'a0', label: 'CHARLIE'),
        _port('a', order: 'a1', label: 'ALPHA'),
        _port('b', order: 'a2', label: 'BRAVO'),
      ]);
      final sorted = sortPortTable(
        buildPortTable(body),
        (column: PortColumnId.label, direction: _asc),
        _registries(),
      );

      expect(_rowLabels(sorted), ['ALPHA', 'BRAVO', 'CHARLIE']);
      expect(_declared(body), ['CHARLIE', 'ALPHA', 'BRAVO']);
    });

    test('THE DESIGNATOR STAYS WITH ITS PORT, which is what tells a person '
        'they are looking at a view', () {
      // `PORT_SEQ` is the DECLARED rank, so a sorted grid shows `J01`
      // somewhere in the middle. Deliberate: it is the one glance that
      // says the row order on screen is not the row order in the file.
      final body = _body([
        _port('c', order: 'a0', label: 'CHARLIE'),
        _port('a', order: 'a1', label: 'ALPHA'),
      ]);
      final sorted = sortPortTable(
        buildPortTable(body),
        (column: PortColumnId.label, direction: _asc),
        _registries(),
      );

      final first = sorted.bands.single.rows.first;
      expect(first.port.label, 'ALPHA');
      expect(first.portSeq, 2, reason: 'ALPHA is still the second port');
      expect(first.designator, 'J02');
    });

    test('no sort returns the same table object, not a copy of it', () {
      final table = buildPortTable(_body([_port('a', order: 'a0')]));
      expect(identical(sortPortTable(table, null, _registries()), table), true);
    });
  });

  group('the sort works inside each band (DR-065)', () {
    test('each bank sorts within itself and the bands keep their order', () {
      final body = _body([
        _port('i2', order: 'a0', label: 'IN B', bank: 'in'),
        _port('i1', order: 'a1', label: 'IN A', bank: 'in'),
        _port('o2', order: 'a2', label: 'OUT B', bank: 'out'),
        _port('o1', order: 'a3', label: 'OUT A', bank: 'out'),
      ]);
      final sorted = sortPortTable(
        buildPortTable(body),
        (column: PortColumnId.label, direction: _asc),
        _registries(),
      );

      expect(sorted.bands.map((b) => b.bankKey), ['in', 'out']);
      expect(_rowLabels(sorted), ['IN A', 'IN B', 'OUT A', 'OUT B']);
    });
  });

  group('AN UNKNOWN IS NOT A VALUE, so it leads neither ordering', () {
    test('unmeasured ports sort last ascending AND last descending', () {
      // A spreadsheet would put the blanks first ascending, which answers
      // "the lowest impedance here is a port nobody has measured". That
      // is the fabrication G4 exists to prevent, and an installer reading
      // it would believe it.
      final body = _body([
        _port('u', order: 'a0', label: 'UNMEASURED'),
        _port('h', order: 'a1', label: 'HIGH', impedance: 110),
        _port('l', order: 'a2', label: 'LOW', impedance: 75),
      ]);
      final table = buildPortTable(body);

      expect(
        _rowLabels(
          sortPortTable(
            table,
            (column: PortColumnId.impedanceOhms, direction: _asc),
            _registries(),
          ),
        ),
        ['LOW', 'HIGH', 'UNMEASURED'],
      );
      expect(
        _rowLabels(
          sortPortTable(
            table,
            (column: PortColumnId.impedanceOhms, direction: _desc),
            _registries(),
          ),
        ),
        ['HIGH', 'LOW', 'UNMEASURED'],
      );
    });
  });

  group('a column sorts by what its cell shows', () {
    test('numbers compare as numbers, not as their spelling', () {
      final body = _body([
        _port('a', order: 'a0', label: 'NINE', impedance: 9),
        _port('b', order: 'a1', label: 'TEN', impedance: 10),
      ]);
      expect(
        _rowLabels(
          sortPortTable(
            buildPortTable(body),
            (column: PortColumnId.impedanceOhms, direction: _asc),
            _registries(),
          ),
        ),
        ['NINE', 'TEN'],
        reason: 'a text compare would put 10 before 9',
      );
    });

    test('CONNECTOR sorts by its display name, not by its id', () {
      // `conn.hdmi_a` sorts before `conn.rj45` by id and `HDMI Type A`
      // before `RJ45` by name, so the case is built the other way round:
      // by id `conn.hdmi_a` < `conn.rj45`, by NAME `RJ45` would come
      // second either way. Use two whose orders disagree.
      final registries = Registries(
        connectorTypes: {
          const ConnectorTypeId('conn.zzz'): const ConnectorTypeDef(
            id: ConnectorTypeId('conn.zzz'),
            displayName: 'BNC',
          ),
          const ConnectorTypeId('conn.aaa'): const ConnectorTypeDef(
            id: ConnectorTypeId('conn.aaa'),
            displayName: 'XLR',
          ),
        },
      );
      final body = _body([
        _port(
          'x',
          order: 'a0',
          label: 'XLR ROW',
          connector: const ConnectorTypeId('conn.aaa'),
        ),
        _port(
          'b',
          order: 'a1',
          label: 'BNC ROW',
          connector: const ConnectorTypeId('conn.zzz'),
        ),
      ]);

      expect(
        _rowLabels(
          sortPortTable(
            buildPortTable(body),
            (column: PortColumnId.connector, direction: _asc),
            registries,
          ),
        ),
        ['BNC ROW', 'XLR ROW'],
        reason: 'sorting by the raw id would answer the other way round',
      );
    });

    test('the comparator is total, so equal values still rank', () {
      final body = _body([
        _port('z', order: 'a0', label: 'SAME', impedance: 75),
        _port('a', order: 'a1', label: 'SAME', impedance: 75),
      ]);
      final sorted = sortPortTable(
        buildPortTable(body),
        (column: PortColumnId.label, direction: _asc),
        _registries(),
      );
      expect(
        sorted.bands.single.rows.map((r) => r.port.key.v),
        ['a', 'z'],
        reason: 'the port key is the tie-break that makes the order total',
      );
    });
  });

  group('clicking a header cycles through three states', () {
    test('none, ascending, descending, and back to the declared order', () {
      var sort = nextPortSort(null, PortColumnId.label);
      expect(sort, (column: PortColumnId.label, direction: _asc));
      sort = nextPortSort(sort, PortColumnId.label);
      expect(sort, (column: PortColumnId.label, direction: _desc));
      // THE THIRD CLICK IS THE WAY BACK. Without it a person who clicked
      // by accident has no route to the declared order at all.
      expect(nextPortSort(sort, PortColumnId.label), null);
    });

    test('clicking a different column starts that one ascending', () {
      const now = (column: PortColumnId.label, direction: _desc);
      expect(nextPortSort(now, PortColumnId.notes), (
        column: PortColumnId.notes,
        direction: _asc,
      ));
    });

    test('the one column that cannot sort refuses to change anything', () {
      // A pairing is a `passthroughPairs` entry rather than a field, so
      // there is nothing on the row to compare.
      expect(portColumnSortable(PortColumnId.pairedPort), false);
      expect(nextPortSort(null, PortColumnId.pairedPort), null);
    });
  });

  group('the commit, which is the destructive half (AC-058/D5)', () {
    test('writes the view order into the declared order', () {
      final body = _body([
        _port('c', order: 'a0', label: 'CHARLIE'),
        _port('a', order: 'a1', label: 'ALPHA'),
        _port('b', order: 'a2', label: 'BRAVO'),
      ]);
      final sorted = sortPortTable(
        buildPortTable(body),
        (column: PortColumnId.label, direction: _asc),
        _registries(),
      );

      final commit = buildSortCommit(body: body, sortedTable: sorted);
      expect(commit.refusal, null);
      for (final command in commit.commands) {
        command.apply(body);
      }
      expect(_declared(body), ['ALPHA', 'BRAVO', 'CHARLIE']);
    });

    test('IT IS A PERMUTATION: the band occupies the same positions it '
        'already held', () {
      // No index is minted, so a commit can never run out of room, and a
      // sorted bank cannot step over the bank below it.
      final body = _body([
        _port('c', order: 'a0', label: 'CHARLIE'),
        _port('a', order: 'a1', label: 'ALPHA'),
        _port('b', order: 'a2', label: 'BRAVO'),
      ]);
      final before = body.ports.map((p) => p.order.v).toSet();

      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _asc),
          _registries(),
        ),
      );
      for (final command in commit.commands) {
        command.apply(body);
      }

      expect(body.ports.map((p) => p.order.v).toSet(), before);
    });

    test('committing one bank leaves the other bank alone', () {
      final body = _body([
        _port('i2', order: 'a0', label: 'IN B', bank: 'in'),
        _port('i1', order: 'a1', label: 'IN A', bank: 'in'),
        _port('o1', order: 'a2', label: 'OUT A', bank: 'out'),
        _port('o2', order: 'a3', label: 'OUT B', bank: 'out'),
      ]);
      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _asc),
          _registries(),
        ),
      );

      expect(commit.movedPorts, 2, reason: 'only the IN bank is out of order');
      for (final command in commit.commands) {
        command.apply(body);
      }
      expect(_declared(body), ['IN A', 'IN B', 'OUT A', 'OUT B']);
    });

    test('only the ports that move are written', () {
      final body = _body([
        _port('a', order: 'a0', label: 'ALPHA'),
        _port('c', order: 'a1', label: 'CHARLIE'),
        _port('b', order: 'a2', label: 'BRAVO'),
      ]);
      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _asc),
          _registries(),
        ),
      );
      expect(commit.commands, hasLength(2));
      expect(commit.movedPorts, 2);
    });

    test('it reverts exactly, which is what makes the confirm honest', () {
      final body = _body([
        _port('c', order: 'a0', label: 'CHARLIE'),
        _port('a', order: 'a1', label: 'ALPHA'),
        _port('b', order: 'a2', label: 'BRAVO'),
      ]);
      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _asc),
          _registries(),
        ),
      );
      for (final command in commit.commands) {
        command.apply(body);
      }
      for (final command in commit.commands.reversed) {
        command.revert(body);
      }
      expect(_declared(body), ['CHARLIE', 'ALPHA', 'BRAVO']);
    });

    test('committing an order that is already the declared one is refused '
        'rather than pushed as an empty undo entry', () {
      final body = _body([
        _port('a', order: 'a0', label: 'ALPHA'),
        _port('b', order: 'a1', label: 'BRAVO'),
      ]);
      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _asc),
          _registries(),
        ),
      );
      expect(commit.refusal, PortSortCommitRefusal.nothingToCommit);
    });

    test('two ports claiming one position refuse rather than half-commit', () {
      // A hand-edited file only. A permutation of a multiset with a
      // repeat cannot express a strict order, and a half-committed sort
      // leaves the grid showing an order the file does not hold.
      final body = _body([
        _port('b', order: 'a0', label: 'BRAVO'),
        _port('a', order: 'a0', label: 'ALPHA'),
      ]);
      final commit = buildSortCommit(
        body: body,
        sortedTable: sortPortTable(
          buildPortTable(body),
          (column: PortColumnId.label, direction: _desc),
          _registries(),
        ),
      );
      expect(commit.refusal, PortSortCommitRefusal.positionsAreNotDistinct);
      expect(
        portSortCommitRefusalMessage(commit.refusal!),
        contains('same position'),
      );
    });

    test('the confirm names the count and the three things that follow the '
        'order', () {
      final prompt = portSortCommitPrompt(24);
      expect(prompt, contains('24 ports'));
      expect(prompt, contains('symbol pin order'));
      expect(prompt, contains('panel'));
      expect(prompt, contains('designators'));
      expect(portSortCommitPrompt(1), contains('1 port.'));
    });
  });

  group('a reorder refuses while a sort is showing (DR-065)', () {
    test('the nudge refuses and names the sort', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);
      final plan = buildPortNudge(
        body: body,
        moving: const ['b'],
        up: true,
        viewIsSorted: true,
      );
      expect(plan.refusal, PortReorderRefusal.theViewIsSorted);
      expect(
        portReorderRefusalMessage(plan.refusal!),
        contains('Clear the sort'),
      );
    });

    test('the drop refuses too, which is the belt to the handle being '
        'disabled', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);
      expect(
        buildPortReorder(
          body: body,
          moving: const ['b'],
          afterKey: null,
          viewIsSorted: true,
        ).refusal,
        PortReorderRefusal.theViewIsSorted,
      );
    });

    test('and both still work when nothing is sorted', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);
      expect(
        buildPortNudge(body: body, moving: const ['b'], up: true).refusal,
        null,
      );
    });
  });

  group('the badge says which way and that it is a view', () {
    test('it names the column, the direction and the declared order', () {
      final badge = portSortBadge((
        column: PortColumnId.label,
        direction: _asc,
      ));
      expect(badge, contains(portColumnHeader(PortColumnId.label)));
      expect(badge, contains('A–Z'));
      expect(badge, contains('declared order'));
      expect(
        portSortBadge((column: PortColumnId.label, direction: _desc)),
        contains('Z–A'),
      );
    });
  });
}
