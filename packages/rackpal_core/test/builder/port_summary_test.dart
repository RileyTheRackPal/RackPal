// The port grid's footer readout (M4-E5, #207).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.hdmi_a'),
      displayName: 'HDMI Type A',
      aliases: ['hdmi'],
    ),
    const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rj45'),
      displayName: 'RJ45 (8P8C)',
      aliases: ['rj45'],
    ),
    // NO ALIAS, on purpose: the seeded `conn.rca` has none either, and
    // the fallback has to be the display name rather than the id.
    const ConnectorTypeId('conn.rca'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rca'),
      displayName: 'RCA',
    ),
  },
);

PortDef _port(
  String key, {
  required String order,
  String connector = 'conn.hdmi_a',
  String? bank,
  Face face = Face.rear,
  PoeSpec? poe,
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: ConnectorTypeId(connector),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: face,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  bankKey: bank,
  poe: poe,
);

void main() {
  group('the short names', () {
    final registries = _registries();

    test('the first alias, which is what aliases are for', () {
      expect(
        portConnectorShortLabel(registries, const ConnectorTypeId('conn.rj45')),
        'RJ45',
        reason:
            'CR-058 puts the bare trade names in aliases so a footer can '
            'read 17 RJ45 rather than 17 RJ45 (8P8C)',
      );
    });

    test('the display name when there is no alias', () {
      expect(
        portConnectorShortLabel(registries, const ConnectorTypeId('conn.rca')),
        'RCA',
      );
    });

    test('an id the registry does not hold stays visible as the id', () {
      expect(
        portConnectorShortLabel(
          registries,
          const ConnectorTypeId('conn.invented'),
        ),
        'conn.invented',
      );
    });
  });

  group('the counts', () {
    test('the whole line, in the shape docs/06 §4.5 draws it', () {
      final body = _body()
        ..ports.addAll([
          for (var i = 0; i < 3; i++)
            _port('h$i', order: 'a00$i', bank: 'video'),
          for (var i = 0; i < 2; i++)
            _port(
              'n$i',
              order: 'a01$i',
              connector: 'conn.rj45',
              bank: 'net',
              poe: PoeSpec(
                role: PoeRole.pse,
                standard: PoeStandard.at,
                watts: 30,
              ),
            ),
          _port('f1', order: 'a020', connector: 'conn.rca', face: Face.front),
        ]);

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        '6 ports · 3 banks · 3 HDMI · 2 RJ45 (PoE+ x2, 60 W) · 1 RCA · '
        'Rear 5 / Front 1',
      );
    });

    test('the banks are the ones the grid draws, not the ones declared', () {
      // A bank declared and then emptied is not a bank the reader can
      // see; a ports-in-no-bank group is not a declared one.
      final body = _body()
        ..banks.add(
          BankDef(
            key: 'empty',
            label: 'Empty',
            abbr: 'EMP',
            order: const FracIndex('a0'),
          ),
        )
        ..ports.add(_port('p1', order: 'a0'));

      expect(buildPortSummary(body, _registries()).bankCount, 1);
    });

    test('connectors come out most numerous first, and the order is '
        'stable under a tie', () {
      final body = _body()
        ..ports.addAll([
          _port('a', order: 'a0', connector: 'conn.rj45'),
          _port('b', order: 'a1', connector: 'conn.rca'),
        ]);
      final reversed = _body()
        ..ports.addAll([
          _port('b', order: 'a1', connector: 'conn.rca'),
          _port('a', order: 'a0', connector: 'conn.rj45'),
        ]);

      expect(
        buildPortSummary(body, _registries()).connectors.map((c) => c.label),
        buildPortSummary(
          reversed,
          _registries(),
        ).connectors.map((c) => c.label),
      );
    });

    test('an empty template still reads as a sentence', () {
      expect(
        portSummaryLine(buildPortSummary(_body(), _registries())),
        '0 ports · 0 banks · Rear 0 / Front 0',
      );
    });

    test('one of a thing is singular', () {
      final body = _body()..ports.add(_port('p1', order: 'a0', bank: 'b'));

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        startsWith('1 port · 1 bank ·'),
      );
    });
  });

  group('the PoE budget', () {
    PoeSpec pse({int? watts, PoeStandard? standard}) =>
        PoeSpec(role: PoeRole.pse, standard: standard, watts: watts);

    test('only ports that SUPPLY power are budgeted', () {
      // A PD port draws from somebody else's budget, not this device's.
      final body = _body()
        ..ports.add(
          _port(
            'p1',
            order: 'a0',
            connector: 'conn.rj45',
            poe: PoeSpec(role: PoeRole.pd, watts: 15),
          ),
        );

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        isNot(contains('PoE')),
      );
    });

    test('watts nobody stated are REPORTED, never assumed zero', () {
      final body = _body()
        ..ports.addAll([
          _port(
            'a',
            order: 'a0',
            connector: 'conn.rj45',
            poe: pse(watts: 30, standard: PoeStandard.at),
          ),
          _port(
            'b',
            order: 'a1',
            connector: 'conn.rj45',
            poe: pse(standard: PoeStandard.at),
          ),
        ]);

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        contains('PoE+ x2, 30 W and 1 unknown'),
      );
    });

    test('no wattage at all says so rather than printing 0 W', () {
      final body = _body()
        ..ports.add(
          _port('a', order: 'a0', connector: 'conn.rj45', poe: pse()),
        );

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        contains('(PoE x1, watts unknown)'),
      );
    });

    test('the standard is named only when every supplying port agrees', () {
      final body = _body()
        ..ports.addAll([
          _port(
            'a',
            order: 'a0',
            connector: 'conn.rj45',
            poe: pse(watts: 15, standard: PoeStandard.af),
          ),
          _port(
            'b',
            order: 'a1',
            connector: 'conn.rj45',
            poe: pse(watts: 30, standard: PoeStandard.at),
          ),
        ]);

      expect(
        portSummaryLine(buildPortSummary(body, _registries())),
        contains('(PoE x2, 45 W)'),
      );
    });

    test('the footer uses the name on a switch panel, not the standard '
        'number', () {
      expect(portPoeStandardShortLabel(PoeStandard.af), 'PoE');
      expect(portPoeStandardShortLabel(PoeStandard.at), 'PoE+');
      expect(portPoeStandardShortLabel(PoeStandard.btType3), 'PoE++');
    });
  });

  group('what is deliberately NOT in the line', () {
    test('no panel fill, because nothing can compute one yet', () {
      // `panel_layer.dart` is M4-K and does not exist; every port this
      // editor creates sits at the origin. Printing a percentage would
      // be a fabricated number, and printing `Panel fill R: —` is what
      // the Structure editor's band header already rejected: a dash
      // belongs in a column, not in a running sentence.
      final body = _body()..ports.add(_port('p1', order: 'a0'));
      final line = portSummaryLine(buildPortSummary(body, _registries()));

      expect(line, isNot(contains('fill')));
      expect(line, isNot(contains('%')));
      expect(line, isNot(contains('—')));
    });

    test('and no ruling ids, because a person reads this one', () {
      final citation = RegExp(r'\b(CR-\d|AC-\d|DR-\d|RJ-\d|§)');
      final body = _body()
        ..ports.add(
          _port(
            'p1',
            order: 'a0',
            connector: 'conn.rj45',
            poe: PoeSpec(role: PoeRole.pse, watts: 30),
          ),
        );

      expect(
        citation.hasMatch(
          portSummaryLine(buildPortSummary(body, _registries())),
        ),
        isFalse,
      );
    });
  });
}
