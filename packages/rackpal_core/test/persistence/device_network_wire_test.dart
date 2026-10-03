// DR-048 §11.47.2 on the wire (NET-A/1b, `#986`): `DeviceInstance.network`,
// the device's management address, ABSENT when null.
//
// THE KEY IS READ OFF THE DEVICE RECORDS, NOT THE TEXT. `Port.network` has
// the same key name, and every starter's templates carry a bank keyed
// "network", so a substring test would see things that are not this field.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
const _starters = ['apartment', 'home_theatre', 'small_office', 'whole_house'];

Uint8List _bytesOf(String name) =>
    File('../../apps/rackpal/assets/starters/$name.rppj').readAsBytesSync();

RackDocument _read(Uint8List bytes) =>
    (_codec.read(bytes) as Ok<RackDocument>).value;

/// Each device record's JSON, by id.
Map<String, Map<String, Object?>> _deviceRecords(List<int> bytes) {
  final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final document = root['document']! as Map<String, Object?>;
  return (document['devices']! as Map<String, Object?>).map(
    (k, v) => MapEntry(k, v! as Map<String, Object?>),
  );
}

/// The lowest-id device of [doc].
DeviceInstance _first(RackDocument doc) =>
    (doc.devices.values.toList()..sort((a, b) => a.id.v.compareTo(b.id.v)))
        .first;

void main() {
  for (final name in _starters) {
    test('$name: no device record carries the key, and the file still '
        'writes back its own bytes (CR-117, kSchemaVersion unmoved)', () {
      final bytes = _bytesOf(name);
      for (final record in _deviceRecords(bytes).values) {
        expect(record.containsKey('network'), isFalse);
      }
      expect(_codec.write(_read(bytes)), bytes);
    });
  }

  test('a device with a management address writes it on ITS record, and '
      'reads it back', () {
    final doc = _read(_bytesOf('whole_house'));
    final device = _first(doc)
      ..network = NetworkConfig(
        hostname: 'core-sw',
        ip: '10.0.10.2',
        vlans: [10],
        verifiedOn: DateTime.utc(2026, 10, 3),
      );
    final bytes = _codec.write(doc);

    final record = _deviceRecords(bytes)[device.id.v]!;
    expect(record['network'], {
      'vlans': [10],
      'hostname': 'core-sw',
      'ip': '10.0.10.2',
      'verifiedOn': '2026-10-03T00:00:00.000Z',
    });
    final others = _deviceRecords(
      bytes,
    ).entries.where((e) => e.key != device.id.v);
    expect(others.where((e) => e.value.containsKey('network')), isEmpty);

    final back = _read(bytes).devices[device.id]!.network!;
    expect(back.hostname, 'core-sw');
    expect(back.ip, '10.0.10.2');
    expect(back.vlans, [10]);
    expect(back.verifiedOn, DateTime.utc(2026, 10, 3));
    expect(_codec.write(_read(bytes)), bytes, reason: 'CR-117');
  });
}
