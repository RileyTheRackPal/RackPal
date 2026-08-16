// Multi-row edit and the batch summary (DR-063, M4-F2 #209).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  required String order,
  int? impedance,
  PortDirection direction = PortDirection.sink,
  Face face = Face.rear,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: face,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: direction,
  impedanceOhms: impedance,
);

TemplateBody _body(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D')
      ..ports.addAll(ports);

void _run(TemplateBody body, List<Command<TemplateBody>> commands) {
  for (final command in commands) {
    command.apply(body);
  }
}

void main() {
  group('MIXED AND UNKNOWN ARE DIFFERENT ANSWERS (DR-063)', () {
    test('agreement reports the value', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1', impedance: 75),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b'],
        ),
        isA<BatchAgreed>().having((v) => v.value, 'value', 75),
      );
    });

    test('ALL UNMEASURED is UNKNOWN, and it keeps the dash it has '
        'everywhere else in the product', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b'],
        ),
        isA<BatchUnknown>(),
      );
    });

    test('DISAGREEMENT IS NOT UNKNOWN. Eight ports nobody measured and '
        'eight carrying 75 and 110 are different facts, and the inspector '
        'is the one surface built to look at many rows at once', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1', impedance: 110),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b'],
        ),
        isA<BatchMixed>().having((v) => v.distinct, 'distinct', 2),
      );
    });

    test('AN UNKNOWN AMONG VALUES IS A DISAGREEMENT, counted as one of '
        'them: reporting it as agreement in either direction fabricates', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1'),
        _port('c', order: 'a2', impedance: 75),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b', 'c'],
        ),
        isA<BatchMixed>().having((v) => v.distinct, 'distinct', 2),
      );
    });

    test('it counts DISTINCT values, not rows', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1', impedance: 110),
        _port('c', order: 'a2', impedance: 75),
        _port('d', order: 'a3', impedance: 600),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b', 'c', 'd'],
        ),
        isA<BatchMixed>().having((v) => v.distinct, 'distinct', 3),
      );
    });

    test('a selected row the body no longer holds is skipped, so a stale '
        'selection summarises smaller rather than crashing', () {
      final body = _body([_port('a', order: 'a0', impedance: 75)]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'gone'],
        ),
        isA<BatchAgreed>(),
      );
    });

    test('an enum column summarises the same way', () {
      final body = _body([
        _port('a', order: 'a0', face: Face.front),
        _port('b', order: 'a1', face: Face.rear),
      ]);

      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.face,
          portKeys: const ['a', 'b'],
        ),
        isA<BatchMixed>(),
      );
    });
  });

  group('writing across the selection', () {
    test('sets every selected row and no others', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
        _port('c', order: 'a2'),
      ]);

      _run(
        body,
        buildBatchWrite(
          body: body,
          column: PortColumnId.direction,
          portKeys: const ['a', 'c'],
          value: PortDirection.source,
        ),
      );

      expect(body.ports.map((p) => p.direction), [
        PortDirection.source,
        PortDirection.sink,
        PortDirection.source,
      ]);
    });

    test('produces no command for a row that already holds the value, so '
        'undoing the batch does not step through writes that changed '
        'nothing', () {
      final body = _body([
        _port('a', order: 'a0', direction: PortDirection.source),
        _port('b', order: 'a1'),
      ]);

      expect(
        buildBatchWrite(
          body: body,
          column: PortColumnId.direction,
          portKeys: const ['a', 'b'],
          value: PortDirection.source,
        ),
        hasLength(1),
      );
    });

    test('is undoable back to exactly what was there, INCLUDING the rows '
        'that disagreed', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1', impedance: 110),
        _port('c', order: 'a2'),
      ]);

      final commands = buildBatchWrite(
        body: body,
        column: PortColumnId.impedanceOhms,
        portKeys: const ['a', 'b', 'c'],
        value: 600,
      );
      _run(body, commands);
      expect(body.ports.map((p) => p.impedanceOhms), [600, 600, 600]);

      for (final command in commands.reversed) {
        command.revert(body);
      }
      expect(body.ports.map((p) => p.impedanceOhms), [75, 110, null]);
    });

    test('WRITING AN UNKNOWN IS A REAL EDIT, because null is a value a '
        'person means (G4) and not an absence of one', () {
      final body = _body([
        _port('a', order: 'a0', impedance: 75),
        _port('b', order: 'a1', impedance: 110),
      ]);

      _run(
        body,
        buildBatchWrite(
          body: body,
          column: PortColumnId.impedanceOhms,
          portKeys: const ['a', 'b'],
          value: null,
        ),
      );

      expect(body.ports.map((p) => p.impedanceOhms), everyElement(isNull));
    });
  });

  group('which columns a batch may write', () {
    test('THE IDENTITY COLUMNS ARE OUT. One label across eight rows names '
        'eight ports the same and mints eight colliding keys; Ctrl+Shift+D '
        'is the gesture for a column of labels (DR-062)', () {
      expect(portColumnBatchEditable(PortColumnId.label), isFalse);
      expect(portColumnBatchEditable(PortColumnId.designator), isFalse);
    });

    test('a refused column writes nothing even when asked directly', () {
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);

      expect(
        buildBatchWrite(
          body: body,
          column: PortColumnId.label,
          portKeys: const ['a', 'b'],
          value: 'HDMI IN',
        ),
        isEmpty,
      );
      expect(body.ports.map((p) => p.label), ['A', 'B']);
    });

    test('KEY, PAIRED WITH and WAS CALLED stay out, for port_fill\'s '
        'reasons rather than for a new one', () {
      for (final column in [
        PortColumnId.portKey,
        PortColumnId.pairedPort,
        PortColumnId.renamedFrom,
      ]) {
        expect(portColumnBatchEditable(column), isFalse, reason: '$column');
      }
    });

    test('everything else is in: five out of the whole enum are refused', () {
      expect(
        portBatchColumns,
        hasLength(PortColumnId.values.length - 5),
      );
    });
  });

  group('the typed write cannot be handed the wrong type', () {
    test('EVERY BATCH COLUMN ROUND-TRIPS ITS OWN READ, which is the one '
        'way a column map and a control can silently disagree', () {
      // Reading a port and writing the value straight back must produce
      // no command at all: same value, same type. A column whose write
      // threw, or whose read returned something its write could not
      // take, fails here rather than in front of a user.
      final body = _body([
        _port('a', order: 'a0'),
        _port('b', order: 'a1'),
      ]);
      final port = body.ports.first;

      for (final column in portBatchColumns) {
        final fill = portColumnFill(column)!;
        final value = fill.read(port);
        expect(
          buildBatchWrite(
            body: body,
            column: column,
            portKeys: const ['a'],
            value: value,
          ),
          isEmpty,
          reason: '$column did not round-trip its own value',
        );
      }
    });
  });
}
