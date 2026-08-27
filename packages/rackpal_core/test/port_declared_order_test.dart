// `portsInDeclaredOrder` — FIXED_ORDER (docs/05 §3), and the one spelling
// of it.
//
// WHAT THIS PROTECTS. The comparator was written five times, byte for byte:
// `derived/connect_rules.dart`, `derived/connect_target.dart`,
// `derived/port_set_resolution.dart`, `commands/multi_draw.dart` and
// `draw/scene/schematic_scene.dart`. They agreed, so nothing was wrong.
// They were also free to stop agreeing, and `connect_target.dart` had
// already written down what that would cost: "two orderings of the same
// list is how a pin ends up with one number on the schedule and a
// different one in the set that wires it".
//
// WHY THE TIE-BREAK CASES ARE WRITTEN AS TWO INPUT ORDERS. `order` is a
// `FracIndex` compared as a raw string and nothing enforces its uniqueness
// within a body, so a tie is reachable from a decoded file. But Dart sorts
// stably below 32 elements, so simply CREATING a tie and asserting the
// result would pass against a comparator that had no tie-break at all.
// Stability is the lever instead: a stable sort preserves input order for
// tied elements, so feeding the same ports in two orders makes a missing
// tie-break produce two different answers.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(String key, String order) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_1'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
);

List<String> _keys(Iterable<PortDef> ports) =>
    portsInDeclaredOrder(ports).map((p) => p.key.v).toList();

void main() {
  group('portsInDeclaredOrder', () {
    test('orders by the declared `order`, not by the list it arrived in', () {
      expect(
        _keys([_port('c', 'a2'), _port('a', 'a0'), _port('b', 'a1')]),
        <String>['a', 'b', 'c'],
      );
    });

    test('ports sharing an `order` rank the same whichever way round they '
        'arrive', () {
      final in1 = [_port('hdmi_2', 'a0'), _port('hdmi_1', 'a0')];
      final in2 = [_port('hdmi_1', 'a0'), _port('hdmi_2', 'a0')];

      expect(_keys(in1), _keys(in2));
      expect(_keys(in1), <String>['hdmi_1', 'hdmi_2']);
    });

    test('the `order` still wins over the key', () {
      // The tie-break must not quietly become the primary sort: `z` sorts
      // after `a` by key but before it by declared order, and the template
      // author's order is the drawing's order.
      expect(
        _keys([_port('a', 'a9'), _port('z', 'a1')]),
        <String>['z', 'a'],
      );
    });

    test('does not mutate its argument', () {
      // Three of the five call sites pass `body.ports` straight in, and a
      // sort in place would reorder the template itself.
      final ports = [_port('c', 'a2'), _port('a', 'a0')];
      portsInDeclaredOrder(ports);
      expect(ports.map((p) => p.key.v), <String>['c', 'a']);
    });

    test('accepts a filtered Iterable, not just a List', () {
      // `multi_draw` and `resolvePortSet` both filter before sorting.
      final ports = [_port('c', 'a2'), _port('a', 'a0'), _port('b', 'a1')];
      expect(
        _keys(ports.where((p) => p.key.v != 'b')),
        <String>['a', 'c'],
      );
    });

    test('empty in, empty out', () {
      expect(portsInDeclaredOrder(const <PortDef>[]), isEmpty);
    });
  });
}
