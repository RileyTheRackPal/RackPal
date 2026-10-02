// A port records the order its terminal block is wired in (M6-E2a `#974`,
// DR-221 §11.220.5).
//
// The model holds an ordered list; the grid, fill and paste machinery see
// it as one string through `PortDefField.terminalRoles`, so no scalar `==`
// ever compares two lists by identity. What this file holds: the string
// seam both ways, absent-when-unknown in the file, the bytes round-trip,
// and a changed order classed as breaking.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port({List<String>? roles}) => PortDef(
  key: const PortKey('rs232'),
  label: 'RS-232',
  connector: const ConnectorTypeId('conn.euroblock_3'),
  signalFamily: const SignalFamilyId('ctl.rs232'),
  face: Face.rear,
  order: const FracIndex('a0'),
  terminalRoles: roles,
);

TemplateBody _body(PortDef port) => TemplateBody(
  manufacturer: 'Generic',
  model: 'CTL-1',
  displayName: 'Control processor',
  frontU: 1,
  power: PowerProfile(),
  ports: [port],
);

JsonMap _portJson(PortDef port) =>
    ((templateBodyToJson(_body(port))['ports']! as List).single as Map)
        .cast<String, Object?>();

void main() {
  group('THE STRING SEAM', () {
    test('typed roles split on any whitespace, and print with one space', () {
      expect(parseTerminalRoles('TX  RX\tG'), ['TX', 'RX', 'G']);
      expect(terminalRolesText(['TX', 'RX', 'G']), 'TX RX G');
    });

    test('BLANK IS NONE RECORDED, never an empty order', () {
      expect(parseTerminalRoles(''), isNull);
      expect(parseTerminalRoles('   '), isNull);
      expect(parseTerminalRoles(null), isNull);
      expect(terminalRolesText(null), isNull);
    });

    test('the port field reads and writes the list through the string', () {
      final port = _port();
      PortDefField.terminalRoles.set(port, '24 Y Z G');
      expect(port.terminalRoles, ['24', 'Y', 'Z', 'G']);
      expect(PortDefField.terminalRoles.get(port), '24 Y Z G');
      PortDefField.terminalRoles.set(port, '');
      expect(port.terminalRoles, isNull);
    });

    test('two ports with the same order compare EQUAL at the seam, which a '
        'List would not', () {
      final a = _port(roles: ['TX', 'RX', 'G']);
      final b = _port(roles: ['TX', 'RX', 'G']);
      expect(identical(a.terminalRoles, b.terminalRoles), isFalse);
      expect(
        PortDefField.terminalRoles.get(a),
        PortDefField.terminalRoles.get(b),
      );
    });
  });

  group('THE FILE (G4, CR-117)', () {
    test('UNKNOWN IS AN ABSENT KEY, never null and never []', () {
      expect(_portJson(_port()).containsKey('terminalRoles'), isFalse);
    });

    test('a recorded order is a JSON array, pin 1 first, and reads back', () {
      final json = _portJson(_port(roles: ['TX', 'RX', 'G']));
      expect(json['terminalRoles'], ['TX', 'RX', 'G']);
      final back = templateBodyFromJson(
        templateBodyToJson(_body(_port(roles: ['TX', 'RX', 'G']))),
      );
      expect(back.ports.single.terminalRoles, ['TX', 'RX', 'G']);
    });

    test('the bytes round-trip, an order and an [] a file happened to hold '
        'alike', () {
      for (final roles in [
        <String>['24', 'Y', 'Z', 'G'],
        <String>[],
      ]) {
        final first = jsonEncode(
          templateBodyToJson(_body(_port(roles: roles))),
        );
        final again = jsonEncode(
          templateBodyToJson(
            templateBodyFromJson(
              (jsonDecode(first) as Map).cast<String, Object?>(),
            ),
          ),
        );
        expect(again, first, reason: '$roles');
      }
    });
  });

  test('A CHANGED ORDER IS BREAKING: a cable landed on the old order is on '
      'the wrong pins', () {
    final report = classifyTemplateChange(
      _body(_port(roles: ['TX', 'RX', 'G'])),
      _body(_port(roles: ['RX', 'TX', 'G'])),
    );
    expect(report.changeClass, TemplateChangeClass.breaking);
  });
}
