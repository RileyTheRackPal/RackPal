// `Ctrl+R` (M4-F7, `#697`, docs/06 §4.6, DR-078).
//
// The task's own trap is the first group: this shares M4-H's engine and
// must not fork it. Every case here compiles its pattern through
// `parseLabelPattern`, so a second grammar could not pass them.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(String key, String label, String order) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('sig.hdmi'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Test',
  ports: ports,
);

TemplateBody _four() => _body([
  _port('a', 'OLD 1', 'a1'),
  _port('b', 'OLD 2', 'a2'),
  _port('c', 'OLD 3', 'a3'),
  _port('d', 'OLD 4', 'a4'),
]);

LabelPattern _pattern(String source) {
  final parsed = parseLabelPattern(source);
  if (parsed is! LabelPattern) fail('$source did not parse');
  return parsed;
}

List<String> _labels(TemplateBody body) => [
  for (final p in portsInDeclaredOrder(body.ports)) p.label,
];

TemplateBody _apply(TemplateBody body, PortRenumberResult result) {
  for (final command in result.commands) {
    command.apply(body);
  }
  return body;
}

void main() {
  group('it drives M4-H engine and owns no grammar', () {
    test('a compiled pattern writes one label per row', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('IN {n}'),
        ),
      );
      expect(_labels(body), ['IN 1', 'IN 2', 'IN 3', 'IN 4']);
    });

    test('the padded token pads, because the engine does', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('J{n:2}'),
        ),
      );
      expect(_labels(body), ['J01', 'J02', 'J03', 'J04']);
    });

    test('a pattern with no token writes the same label to every row', () {
      // Legal, and `LabelPattern.isSequenced` is how a surface knows to
      // say so rather than implying a sequence.
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('SPEAKER'),
        ),
      );
      expect(_labels(body), ['SPEAKER', 'SPEAKER', 'SPEAKER', 'SPEAKER']);
    });
  });

  group('start and step, so a bank can be renumbered from 9', () {
    test('start seeds the counter', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('IN {n}'),
          start: 9,
        ),
      );
      expect(_labels(body), ['IN 9', 'IN 10', 'IN 11', 'IN 12']);
    });

    test('step counts by more than one', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('IN {n}'),
          step: 2,
        ),
      );
      expect(_labels(body), ['IN 1', 'IN 3', 'IN 5', 'IN 7']);
    });
  });

  group('display order, which is the selection order it is given', () {
    // §4.6 says CURRENT DISPLAY ORDER, and under M4-F5's view-only sort
    // that is not the declared order. This file takes the order it is
    // handed rather than re-deriving one, so the caller's sort decides.
    test('a reversed selection numbers in that order', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['d', 'c', 'b', 'a'],
          pattern: _pattern('IN {n}'),
        ),
      );
      // Declared order is a, b, c, d, so reading it back shows the
      // numbering ran the other way.
      expect(_labels(body), ['IN 4', 'IN 3', 'IN 2', 'IN 1']);
    });

    test('only the selection is touched', () {
      final body = _four();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['b', 'c'],
          pattern: _pattern('IN {n}'),
        ),
      );
      expect(_labels(body), ['OLD 1', 'IN 1', 'IN 2', 'OLD 4']);
    });
  });

  group('the preview and the write cannot disagree', () {
    test('the preview names the same labels the write produces', () {
      final body = _four();
      final preview = previewPortRenumber(
        body: body,
        selectedInOrder: ['a', 'b', 'c', 'd'],
        pattern: _pattern('IN {n}'),
        start: 5,
      );
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('IN {n}'),
          start: 5,
        ),
      );
      expect(preview.map((r) => r.after).toList(), _labels(body));
      expect(preview.map((r) => r.before).toList(), [
        'OLD 1',
        'OLD 2',
        'OLD 3',
        'OLD 4',
      ]);
    });
  });

  group('what it does not write', () {
    test('a row already holding its new label produces no command', () {
      final body = _body([
        _port('a', 'IN 1', 'a1'),
        _port('b', 'WRONG', 'a2'),
      ]);
      final result = buildPortRenumber(
        body: body,
        selectedInOrder: ['a', 'b'],
        pattern: _pattern('IN {n}'),
      );
      // One command, not two: an undo entry that changes nothing is one
      // the user has to press Ctrl+Z through twice.
      expect(result.commands, hasLength(1));
    });

    test('keys are never touched, however the labels move', () {
      final body = _four();
      final before = body.ports.map((p) => p.key.v).toList();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['a', 'b', 'c', 'd'],
          pattern: _pattern('HDMI {n}'),
        ),
      );
      expect(body.ports.map((p) => p.key.v).toList(), before);
    });

    test('order is never touched, so a renumber is not a reorder', () {
      final body = _four();
      final before = body.ports.map((p) => p.order.v).toList();
      _apply(
        body,
        buildPortRenumber(
          body: body,
          selectedInOrder: ['d', 'c', 'b', 'a'],
          pattern: _pattern('IN {n}'),
        ),
      );
      expect(body.ports.map((p) => p.order.v).toList(), before);
    });
  });

  group('refusals', () {
    test('nothing selected', () {
      final result = buildPortRenumber(
        body: _four(),
        selectedInOrder: const [],
        pattern: _pattern('IN {n}'),
      );
      expect(result.refusal, PortRenumberRefusal.nothingSelected);
    });

    test('every refusal has a sentence', () {
      for (final refusal in PortRenumberRefusal.values) {
        expect(portRenumberRefusalMessage(refusal), isNotEmpty);
      }
    });
  });

  group('undo puts the old labels back', () {
    test('reverting every command restores what was there', () {
      final body = _four();
      final before = _labels(body);
      final result = buildPortRenumber(
        body: body,
        selectedInOrder: ['a', 'b', 'c', 'd'],
        pattern: _pattern('IN {n}'),
      );
      _apply(body, result);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }
      expect(_labels(body), before);
    });
  });
}
