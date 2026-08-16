// Fill down and fill series (DR-062, M4-F1 #208).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  required String order,
  String label = '',
  String? notes,
  PortDirection direction = PortDirection.sink,
  int? poeWatts,
}) => PortDef(
  key: PortKey(key),
  label: label.isEmpty ? key.toUpperCase() : label,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: direction,
  notes: notes,
  poe: poeWatts == null ? null : PoeSpec(watts: poeWatts),
);

TemplateBody _body(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D')
      ..ports.addAll(ports);

/// Runs [commands] against [body], the way the grid's `transact` does.
void _run(TemplateBody body, List<Command<TemplateBody>> commands) {
  for (final command in commands) {
    command.apply(body);
  }
}

void main() {
  group('inferring a series from one cell', () {
    test('takes the trailing digits and remembers their width', () {
      final s = inferLabelSeries('IN 01')!;
      expect(s.at(0), 'IN 01');
      expect(s.at(1), 'IN 02');
      expect(s.at(9), 'IN 10');
    });

    test('counts past the padding rather than overflowing it', () {
      final s = inferLabelSeries('IN 09')!;
      expect(s.at(1), 'IN 10');
      expect(s.at(92), 'IN 101');
    });

    test('starts from the cell it was read out of, not from one', () {
      final s = inferLabelSeries('OUT 12')!;
      expect(s.at(0), 'OUT 12');
      expect(s.at(3), 'OUT 15');
    });

    test('TAKES THE LAST RUN, so a standard in the name is left alone', () {
      // The catalog is full of these, and a first-run rule gets exactly
      // the cases that matter most wrong.
      expect(inferLabelSeries('HDMI 2.0 IN 1')!.at(1), 'HDMI 2.0 IN 2');
      expect(inferLabelSeries('802.3bt PORT 4')!.at(1), '802.3bt PORT 5');
      expect(inferLabelSeries('RS-232 CTL 2')!.at(2), 'RS-232 CTL 4');
    });

    test('keeps whatever follows the number', () {
      expect(inferLabelSeries('BANK 1 (REAR)')!.at(1), 'BANK 2 (REAR)');
    });

    test('handles a number with nothing around it', () {
      expect(inferLabelSeries('7')!.at(1), '8');
    });

    test('IS NULL WHEN THERE IS NO NUMBER, rather than falling back to a '
        'copy that the person would discover sixteen rows later', () {
      expect(inferLabelSeries('SPEAKER'), isNull);
      expect(inferLabelSeries(''), isNull);
    });
  });

  group('fill down', () {
    test('copies the top selected cell into every row below it', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'HDMI'),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.label), ['HDMI', 'HDMI', 'HDMI']);
    });

    test('leaves the top row alone, because it is the specimen', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'KEEP'),
        _port('p2', order: 'a1'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2'],
      );

      expect(
        result.commands.length,
        1,
        reason: 'one write, for the one row that changes',
      );
      _run(body, result.commands);
      expect(body.ports.first.label, 'KEEP');
    });

    test('skips rows that already hold the value, so an undo does not '
        'step through writes that changed nothing', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'SAME'),
        _port('p2', order: 'a1', label: 'SAME'),
        _port('p3', order: 'a2', label: 'OTHER'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );

      expect(result.commands.length, 1);
    });

    test('fills a NON-text column, which is the half fill series cannot '
        'do', () {
      final body = _body([
        _port('p1', order: 'a0', direction: PortDirection.source),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.direction,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );
      _run(body, result.commands);

      expect(
        body.ports.map((p) => p.direction),
        everyElement(PortDirection.source),
      );
    });

    test('AN UNKNOWN COPIES DOWN LIKE ANY OTHER VALUE, because G4 makes '
        'null a fact and not an absence of one', () {
      final body = _body([
        _port('p1', order: 'a0'),
        _port('p2', order: 'a1', notes: 'measured'),
        _port('p3', order: 'a2', notes: 'measured'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.notes,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.notes), everyElement(isNull));
    });

    test('is undoable row by row, back to exactly what was there', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'A'),
        _port('p2', order: 'a1', label: 'B'),
        _port('p3', order: 'a2', label: 'C'),
      ]);

      final result = buildFillDown(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );
      _run(body, result.commands);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }

      expect(body.ports.map((p) => p.label), ['A', 'B', 'C']);
    });
  });

  group('fill series', () {
    test('writes the sequence the top cell implies', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'IN 01'),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
        _port('p4', order: 'a3'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2', 'p3', 'p4'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.label), [
        'IN 01',
        'IN 02',
        'IN 03',
        'IN 04',
      ]);
    });

    test('STARTS FROM THE TOP OF THE SELECTION, not from one, so filling '
        'the back half of a bank does not collide with its front half', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'IN 01'),
        _port('p2', order: 'a1', label: 'IN 02'),
        _port('p3', order: 'a2', label: 'IN 09'),
        _port('p4', order: 'a3'),
        _port('p5', order: 'a4'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p3', 'p4', 'p5'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.label), [
        'IN 01',
        'IN 02',
        'IN 09',
        'IN 10',
        'IN 11',
      ]);
    });

    test('runs down the selection in DISPLAY order and skips what is not '
        'in it', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'J 1'),
        _port('p2', order: 'a1', label: 'UNTOUCHED'),
        _port('p3', order: 'a2'),
        _port('p4', order: 'a3'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p3', 'p4'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.label), [
        'J 1',
        'UNTOUCHED',
        'J 2',
        'J 3',
      ]);
    });

    test('works on any text column, not only the label', () {
      final body = _body([
        _port('p1', order: 'a0', notes: 'RUN 1'),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.notes,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );
      _run(body, result.commands);

      expect(body.ports.map((p) => p.notes), ['RUN 1', 'RUN 2', 'RUN 3']);
    });

    test('REFUSES A NUMBER COLUMN rather than rewriting a bank of '
        'electrical facts as a counting sequence', () {
      final body = _body([
        _port('p1', order: 'a0', poeWatts: 15),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.poeWatts,
        selectedInOrder: const ['p1', 'p2', 'p3'],
      );

      expect(result.refusal, PortFillRefusal.seriesNeedsText);
      expect(result.commands, isEmpty);
    });

    test('refuses when the top cell holds no number, and says which '
        'key to press instead', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'SPEAKER'),
        _port('p2', order: 'a1'),
      ]);

      final result = buildFillSeries(
        body: body,
        column: PortColumnId.label,
        selectedInOrder: const ['p1', 'p2'],
      );

      expect(result.refusal, PortFillRefusal.seriesNeedsANumber);
      expect(
        portFillRefusalMessage(result.refusal!),
        contains('Fill down'),
        reason: 'a refusal that does not name the way forward is a dead end',
      );
    });
  });

  group('both fills refuse the same three ways', () {
    test('with fewer than two rows there is nothing to fill into', () {
      final body = _body([_port('p1', order: 'a0')]);
      for (final result in [
        buildFillDown(
          body: body,
          column: PortColumnId.label,
          selectedInOrder: const ['p1'],
        ),
        buildFillSeries(
          body: body,
          column: PortColumnId.label,
          selectedInOrder: const ['p1'],
        ),
      ]) {
        expect(result.refusal, PortFillRefusal.needsTwoRows);
      }
    });

    test('with no focused column there is no column to fill', () {
      final body = _body([_port('p1', order: 'a0'), _port('p2', order: 'a1')]);
      for (final result in [
        buildFillDown(
          body: body,
          column: null,
          selectedInOrder: const ['p1', 'p2'],
        ),
        buildFillSeries(
          body: body,
          column: null,
          selectedInOrder: const ['p1', 'p2'],
        ),
      ]) {
        expect(result.refusal, PortFillRefusal.needsAColumn);
      }
    });

    test('KEY, PAIRED WITH and WAS CALLED are each written by their own '
        'action and never by a fill', () {
      final body = _body([_port('p1', order: 'a0'), _port('p2', order: 'a1')]);
      for (final column in [
        PortColumnId.portKey,
        PortColumnId.pairedPort,
        PortColumnId.renamedFrom,
      ]) {
        expect(portColumnFill(column), isNull, reason: '$column');
        expect(
          buildFillDown(
            body: body,
            column: column,
            selectedInOrder: const ['p1', 'p2'],
          ).refusal,
          PortFillRefusal.columnIsNotFillable,
        );
      }
    });

    test('every refusal has a sentence, so no fill can decline silently', () {
      for (final refusal in PortFillRefusal.values) {
        expect(portFillRefusalMessage(refusal), isNotEmpty);
      }
    });
  });

  group('the column map', () {
    test('answers for every column the grid can draw, which is what stops '
        'a new column reaching the grid unanswered', () {
      // Three decline and the rest resolve; the switch is exhaustive, so
      // this walks the whole enum rather than a list somebody maintains.
      var fillable = 0;
      for (final id in PortColumnId.values) {
        if (portColumnFill(id) != null) fillable++;
      }
      expect(fillable, PortColumnId.values.length - 3);
    });

    test('THREE columns carry a series, and SET and ROLE are deliberately '
        'not among them: they are keys into PortSetDef, so a series down '
        'one invents memberships no set declares', () {
      final text = [
        for (final id in PortColumnId.values)
          if (portColumnFill(id)?.isText ?? false) id,
      ];
      expect(text, [
        PortColumnId.label,
        PortColumnId.designator,
        PortColumnId.notes,
      ]);
    });
  });
}
