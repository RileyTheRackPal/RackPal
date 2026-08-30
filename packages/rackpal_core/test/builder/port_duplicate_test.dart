// `Ctrl+J` (M4-F6, `#696`, docs/06 §4.6, DR-078).
//
// The two traps the task named are the first two groups: keys must not
// collide, and "past the highest existing index" is a claim about the
// TEMPLATE rather than about the selection.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key,
  String label,
  String order, {
  String? bank,
  PortDirection direction = PortDirection.sink,
  String? designatorHint,
}) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('sig.hdmi'),
  face: Face.rear,
  order: FracIndex(order),
  bankKey: bank,
  direction: direction,
  designatorHint: designatorHint,
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Test',
  ports: ports,
);

/// Runs what the plan produced, so assertions are about the RESULT rather
/// than about the command list. `assert the artifact, not the mechanism`.
TemplateBody _apply(TemplateBody body, PortDuplicateResult result) {
  for (final command in result.commands) {
    command.apply(body);
  }
  return body;
}

List<String> _labelsInOrder(TemplateBody body) => [
  for (final p in portsInDeclaredOrder(body.ports)) p.label,
];

void main() {
  group('past the highest existing index, which is not plus one', () {
    test('a duplicate of 1-4 in a bank running to 12 starts at 13', () {
      final body = _body([
        for (var i = 1; i <= 12; i++)
          _port('hdmi.in.$i', 'HDMI IN $i', 'a${i.toString().padLeft(2, "0")}'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['hdmi.in.1', 'hdmi.in.2', 'hdmi.in.3', 'hdmi.in.4'],
      );

      _apply(body, result);
      expect(body.ports, hasLength(16));
      expect(_labelsInOrder(body).sublist(4, 8), [
        'HDMI IN 13',
        'HDMI IN 14',
        'HDMI IN 15',
        'HDMI IN 16',
      ]);
    });

    test('two series in one selection get two counters', () {
      final body = _body([
        _port('hdmi.in.1', 'HDMI IN 1', 'a1'),
        _port('hdmi.in.7', 'HDMI IN 7', 'a2'),
        _port('spk.a.1', 'SPK A 1', 'a3'),
        _port('spk.a.2', 'SPK A 2', 'a4'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['hdmi.in.1', 'spk.a.1'],
      );

      _apply(body, result);
      // THE WHOLE LIST, not a sublist at an index this test guessed. The
      // clones land after the last SELECTED row (`SPK A 1`), which puts
      // them before `SPK A 2` rather than at the end, and a positional
      // assertion hid that behind an off-by-one.
      expect(_labelsInOrder(body), [
        'HDMI IN 1',
        'HDMI IN 7',
        'SPK A 1',
        'HDMI IN 8',
        'SPK A 3',
        'SPK A 2',
      ]);
    });

    test('the width of the source survives, so IN 01 counts to IN 10', () {
      final body = _body([
        _port('in.01', 'IN 01', 'a1'),
        _port('in.09', 'IN 09', 'a2'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['in.01'],
      );

      _apply(body, result);
      expect(_labelsInOrder(body), ['IN 01', 'IN 10', 'IN 09']);
    });

    test('IN 1 and IN 01 are one series, not two', () {
      // Same prefix and suffix, different padding. Counting them apart
      // would put the clone straight over a label that already exists.
      final body = _body([
        _port('in.1', 'IN 1', 'a1'),
        _port('in.02', 'IN 02', 'a2'),
      ]);
      final result = buildPortDuplicate(body: body, selectedInOrder: ['in.1']);

      _apply(body, result);
      expect(_labelsInOrder(body), ['IN 1', 'IN 3', 'IN 02']);
    });

    test('a label with no digits is copied verbatim', () {
      final body = _body([_port('speaker', 'SPEAKER', 'a1')]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['speaker'],
      );

      _apply(body, result);
      expect(_labelsInOrder(body), ['SPEAKER', 'SPEAKER']);
      // Legal, and the keys still differ.
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(2));
    });

    test('the last run of digits counts, not the first (DR-062s rule)', () {
      final body = _body([_port('hdmi.2.in.1', 'HDMI 2.0 IN 1', 'a1')]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['hdmi.2.in.1'],
      );

      _apply(body, result);
      expect(_labelsInOrder(body), ['HDMI 2.0 IN 1', 'HDMI 2.0 IN 2']);
    });
  });

  group('keys never collide', () {
    test('two clones of one label get two distinct keys', () {
      final body = _body([
        _port('speaker', 'SPEAKER', 'a1'),
        _port('speaker.2', 'SPEAKER', 'a2'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['speaker', 'speaker.2'],
      );

      _apply(body, result);
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(4));
    });

    test('a clone keyed off its NEW label, not its source key', () {
      final body = _body([_port('hdmi.in.1', 'HDMI IN 1', 'a1')]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['hdmi.in.1'],
      );

      _apply(body, result);
      expect(portsInDeclaredOrder(body.ports).last.key.v, 'hdmi.in.2');
    });
  });

  group('where the clones land', () {
    test('immediately below the block, in the declared order', () {
      final body = _body([
        _port('a', 'A 1', 'a1'),
        _port('b', 'B 1', 'a2'),
        _port('c', 'C 1', 'a3'),
      ]);
      final result = buildPortDuplicate(body: body, selectedInOrder: ['a']);

      _apply(body, result);
      expect(_labelsInOrder(body), ['A 1', 'A 2', 'B 1', 'C 1']);
    });

    test('a non-contiguous selection consolidates its copies', () {
      // Three rows picked out of four give three copies TOGETHER, after
      // the last of them. "Below the selection" has one insertion point.
      final body = _body([
        _port('a', 'A 1', 'a1'),
        _port('b', 'B 1', 'a2'),
        _port('c', 'C 1', 'a3'),
        _port('d', 'D 1', 'a4'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['a', 'c'],
      );

      _apply(body, result);
      expect(_labelsInOrder(body), ['A 1', 'B 1', 'C 1', 'A 2', 'C 2', 'D 1']);
    });

    test('the block keeps its own relative order', () {
      final body = _body([
        _port('a', 'A 1', 'a1'),
        _port('b', 'B 1', 'a2'),
      ]);
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['a', 'b'],
      );

      _apply(body, result);
      expect(_labelsInOrder(body), ['A 1', 'B 1', 'A 2', 'B 2']);
    });

    test('duplicating the last row appends past the end', () {
      final body = _body([
        _port('a', 'A 1', 'a1'),
        _port('b', 'B 1', 'a2'),
      ]);
      final result = buildPortDuplicate(body: body, selectedInOrder: ['b']);

      _apply(body, result);
      expect(_labelsInOrder(body), ['A 1', 'B 1', 'B 2']);
    });
  });

  group('what a clone carries, and what it deliberately does not', () {
    test('every other field carries across', () {
      final source = PortDef(
        key: const PortKey('src'),
        label: 'IN 1',
        connector: const ConnectorTypeId('conn.xlr3'),
        signalFamily: const SignalFamilyId('sig.analog_bal'),
        face: Face.front,
        order: const FracIndex('a1'),
        direction: PortDirection.source,
        gender: Gender.female,
        impedanceOhms: 110,
        balanced: true,
        conductorCount: 3,
        notes: 'a note',
        bankKey: 'bank.a',
      );
      final body = _body([source]);
      _apply(
        body,
        buildPortDuplicate(body: body, selectedInOrder: ['src']),
      );

      final clone = portsInDeclaredOrder(body.ports).last;
      expect(clone.connector.v, 'conn.xlr3');
      expect(clone.signalFamily.v, 'sig.analog_bal');
      expect(clone.face, Face.front);
      expect(clone.direction, PortDirection.source);
      expect(clone.gender, Gender.female);
      expect(clone.impedanceOhms, 110);
      expect(clone.balanced, isTrue);
      expect(clone.conductorCount, 3);
      expect(clone.notes, 'a note');
      expect(clone.bankKey, 'bank.a');
    });

    test(
      'renamedFrom does NOT carry: those aliases are the source history',
      () {
        final body = _body([_port('now', 'IN 1', 'a1')]);
        body.ports[0] = portWithIdentity(
          body.ports[0],
          key: const PortKey('now'),
          label: 'IN 1',
          order: const FracIndex('a1'),
          position: null,
          renamedFrom: const [PortKey('was')],
          designatorHint: null,
        );
        _apply(
          body,
          buildPortDuplicate(body: body, selectedInOrder: ['now']),
        );

        expect(portsInDeclaredOrder(body.ports).last.renamedFrom, isEmpty);
        // The source keeps its own.
        expect(
          portsInDeclaredOrder(body.ports).first.renamedFrom,
          hasLength(1),
        );
      },
    );

    test('designatorHint does NOT carry: two ports cannot pin one name', () {
      final body = _body([
        _port('a', 'IN 1', 'a1', designatorHint: 'J01'),
      ]);
      _apply(body, buildPortDuplicate(body: body, selectedInOrder: ['a']));

      expect(portsInDeclaredOrder(body.ports).last.designatorHint, isNull);
      expect(portsInDeclaredOrder(body.ports).first.designatorHint, 'J01');
    });
  });

  group('refusals are announced, never swallowed', () {
    test('nothing selected', () {
      final result = buildPortDuplicate(
        body: _body([_port('a', 'A 1', 'a1')]),
        selectedInOrder: const [],
      );
      expect(result.refusal, PortDuplicateRefusal.nothingSelected);
      expect(result.commands, isEmpty);
    });

    test('a key that is not in the body is not a selection', () {
      final result = buildPortDuplicate(
        body: _body([_port('a', 'A 1', 'a1')]),
        selectedInOrder: const ['ghost'],
      );
      expect(result.refusal, PortDuplicateRefusal.nothingSelected);
    });

    test('the view is sorted', () {
      final result = buildPortDuplicate(
        body: _body([_port('a', 'A 1', 'a1')]),
        selectedInOrder: const ['a'],
        viewIsSorted: true,
      );
      expect(result.refusal, PortDuplicateRefusal.theViewIsSorted);
    });

    test('every refusal has a sentence', () {
      for (final refusal in PortDuplicateRefusal.values) {
        expect(portDuplicateRefusalMessage(refusal), isNotEmpty);
      }
    });
  });

  group('undo puts it back', () {
    test('reverting every command leaves the body as it was', () {
      final body = _body([
        _port('a', 'A 1', 'a1'),
        _port('b', 'B 1', 'a2'),
      ]);
      final before = body.ports.map((p) => p.key.v).toList();
      final result = buildPortDuplicate(
        body: body,
        selectedInOrder: ['a', 'b'],
      );
      _apply(body, result);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }
      expect(body.ports.map((p) => p.key.v).toList(), before);
    });
  });
}
