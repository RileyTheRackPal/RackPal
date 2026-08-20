// `Ctrl+T` (M4-F9, `#699`, docs/06 §4.6, DR-078 §11.77.3).
//
// The task's own sentence is the second group: the impact preview IS the
// deliverable, so most of these cases are about what the preview says
// rather than about what the write does.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  String connector = 'conn.hdmi_a',
  String family = 'video.hdmi',
  PortDirection direction = PortDirection.sink,
  PortTopology topology = PortTopology.p2p,
  String order = 'a1',
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: direction,
  topology: topology,
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Test',
  ports: ports,
);

/// Two families and two connectors, enough to state every rule under test
/// without dragging the 55-family seed in.
Registries _registries() => Registries(
  signalFamilies: {
    const SignalFamilyId('video.hdmi'): const SignalFamilyDef(
      id: SignalFamilyId('video.hdmi'),
      domain: SignalDomainId('video'),
      displayName: 'HDMI',
      defaultConnector: ConnectorTypeId('conn.hdmi_a'),
      defaultDirection: PortDirection.sink,
      defaultTopology: PortTopology.p2p,
    ),
    const SignalFamilyId('net.ethernet'): const SignalFamilyDef(
      id: SignalFamilyId('net.ethernet'),
      domain: SignalDomainId('network'),
      displayName: 'Ethernet',
      defaultConnector: ConnectorTypeId('conn.rj45'),
      defaultDirection: PortDirection.bidirectional,
      defaultTopology: PortTopology.p2p,
    ),
  },
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

TemplateBody _apply(TemplateBody body, PortTypeChangeResult result) {
  for (final command in result.commands) {
    command.apply(body);
  }
  return body;
}

void main() {
  group('it writes the two fields it was given', () {
    test('a family change writes the family and nothing else', () {
      final body = _body([_port('a'), _port('b', order: 'a2')]);
      _apply(
        body,
        buildPortTypeChange(
          body: body,
          selectedInOrder: ['a', 'b'],
          registries: _registries(),
          family: const SignalFamilyId('net.ethernet'),
        ),
      );
      expect(body.ports.map((p) => p.signalFamily.v), [
        'net.ethernet',
        'net.ethernet',
      ]);
      // The connector is UNTOUCHED, because it was not picked. The dialog
      // pre-fills it from the family; this function never does.
      expect(body.ports.map((p) => p.connector.v), [
        'conn.hdmi_a',
        'conn.hdmi_a',
      ]);
    });

    test('a connector change writes the connector and nothing else', () {
      final body = _body([_port('a')]);
      _apply(
        body,
        buildPortTypeChange(
          body: body,
          selectedInOrder: ['a'],
          registries: _registries(),
          connector: const ConnectorTypeId('conn.rj45'),
        ),
      );
      expect(body.ports.single.connector.v, 'conn.rj45');
      expect(body.ports.single.signalFamily.v, 'video.hdmi');
    });

    // THE CLAUSE THE WHOLE FILE EXISTS FOR. Both fields are non-nullable
    // with defaults, so the model cannot tell a named value from a
    // defaulted one; cascading the new family's defaults would overwrite
    // deliberate values with no way to know how many (DR-060).
    test('direction and topology are never written', () {
      final body = _body([
        _port('a', direction: PortDirection.source),
        _port('b', order: 'a2', topology: PortTopology.multidrop),
      ]);
      _apply(
        body,
        buildPortTypeChange(
          body: body,
          selectedInOrder: ['a', 'b'],
          registries: _registries(),
          family: const SignalFamilyId('net.ethernet'),
        ),
      );
      expect(body.ports.first.direction, PortDirection.source);
      expect(body.ports.last.topology, PortTopology.multidrop);
    });

    test('a row already carrying the value produces no command', () {
      final body = _body([_port('a')]);
      final result = buildPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        family: const SignalFamilyId('video.hdmi'),
      );
      expect(result.commands, isEmpty);
    });
  });

  group('the preview is the deliverable', () {
    test('it prints the trade names, not the ids', () {
      final body = _body([_port('a')]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        family: const SignalFamilyId('net.ethernet'),
        connector: const ConnectorTypeId('conn.rj45'),
      );
      expect(rows.single.before, 'HDMI Type A · HDMI');
      expect(rows.single.after, 'RJ45 · Ethernet');
    });

    test('a row keeping a direction the new family would not choose says '
        'so, per row', () {
      final body = _body([
        _port('a', direction: PortDirection.source),
        _port('b', order: 'a2'),
      ]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a', 'b'],
        registries: _registries(),
        // Ethernet defaults to bidirectional; `a` is a source and `b` is
        // a sink, so both diverge and both say what they keep.
        family: const SignalFamilyId('net.ethernet'),
      );
      expect(rows.first.note, contains('direction stays'));
      expect(rows.last.note, contains('direction stays'));
    });

    test('a row that agrees with the new family carries no note', () {
      final body = _body([_port('a')]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        family: const SignalFamilyId('video.hdmi'),
      );
      expect(rows.single.note, isNull);
    });

    test('the note names topology as well as direction', () {
      final body = _body([
        _port(
          'a',
          direction: PortDirection.bidirectional,
          topology: PortTopology.multidrop,
        ),
      ]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        family: const SignalFamilyId('net.ethernet'),
      );
      expect(rows.single.note, contains('topology stays'));
      expect(rows.single.note, isNot(contains('direction stays')));
    });

    test('a connector-only change carries no note at all', () {
      // No family was picked, so there are no defaults to diverge from
      // and nothing honest to say about direction.
      final body = _body([_port('a', direction: PortDirection.source)]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        connector: const ConnectorTypeId('conn.rj45'),
      );
      expect(rows.single.note, isNull);
    });

    test('the preview and the write agree about which rows change', () {
      final body = _body([
        _port('a'),
        _port('b', order: 'a2', family: 'net.ethernet'),
      ]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a', 'b'],
        registries: _registries(),
        family: const SignalFamilyId('net.ethernet'),
      );
      final result = buildPortTypeChange(
        body: body,
        selectedInOrder: ['a', 'b'],
        registries: _registries(),
        family: const SignalFamilyId('net.ethernet'),
      );
      expect(portImpactChanges(rows).length, result.commands.length);
    });

    test('an unknown family resolves to its id rather than to a blank', () {
      // G4 applies to registries too: a document may name a family this
      // build does not ship, and the preview says which one.
      final body = _body([_port('a', family: 'video.from_the_future')]);
      final rows = previewPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        connector: const ConnectorTypeId('conn.rj45'),
      );
      expect(rows.single.before, contains('video.from_the_future'));
    });
  });

  group('the family default a dialog pre-fills with', () {
    test('a known family names its connector', () {
      expect(
        defaultConnectorFor(
          _registries(),
          const SignalFamilyId('net.ethernet'),
        ),
        const ConnectorTypeId('conn.rj45'),
      );
    });

    test('an unknown family names none, rather than guessing', () {
      expect(
        defaultConnectorFor(_registries(), const SignalFamilyId('nope')),
        isNull,
      );
    });

    test('no family at all names none', () {
      expect(defaultConnectorFor(_registries(), null), isNull);
    });
  });

  group('refusals', () {
    test('nothing picked is a refusal, not a silent no-op', () {
      expect(
        buildPortTypeChange(
          body: _body([_port('a')]),
          selectedInOrder: ['a'],
          registries: _registries(),
        ).refusal,
        PortTypeChangeRefusal.nothingPicked,
      );
    });

    test('nothing selected', () {
      expect(
        buildPortTypeChange(
          body: _body([_port('a')]),
          selectedInOrder: const [],
          registries: _registries(),
          family: const SignalFamilyId('net.ethernet'),
        ).refusal,
        PortTypeChangeRefusal.nothingSelected,
      );
    });

    test('every refusal has a sentence', () {
      for (final refusal in PortTypeChangeRefusal.values) {
        expect(portTypeChangeRefusalMessage(refusal), isNotEmpty);
      }
    });
  });

  group('undo', () {
    test('reverting restores both fields', () {
      final body = _body([_port('a')]);
      final result = buildPortTypeChange(
        body: body,
        selectedInOrder: ['a'],
        registries: _registries(),
        family: const SignalFamilyId('net.ethernet'),
        connector: const ConnectorTypeId('conn.rj45'),
      );
      _apply(body, result);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }
      expect(body.ports.single.connector.v, 'conn.hdmi_a');
      expect(body.ports.single.signalFamily.v, 'video.hdmi');
    });
  });
}
