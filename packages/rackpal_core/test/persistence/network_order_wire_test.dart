// `ProjectSettings.networkOrder` on the wire (NET-A/2f, `#997`, DR-227
// §11.226.4): ABSENT at the default, so every file written before the
// setting existed keeps its bytes and `kSchemaVersion` stays put.

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

Map<String, Object?> _settings(Uint8List bytes) {
  final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  return (root['document']! as Map<String, Object?>)['settings']!
      as Map<String, Object?>;
}

void main() {
  for (final name in _starters) {
    test('$name reads as by designator, carries no key, and still writes '
        'back its own bytes', () {
      final bytes = _bytesOf(name);
      final doc = _read(bytes);
      expect(doc.settings.networkOrder, NetworkOrder.designator);
      expect(_settings(bytes).containsKey('networkOrder'), isFalse);
      expect(_codec.write(doc), bytes);
    });
  }

  test('rack then room is written, and read back as itself', () {
    final doc = _read(_bytesOf('whole_house'))
      ..settings.networkOrder = NetworkOrder.rackThenRoom;
    final bytes = _codec.write(doc);
    expect(_settings(bytes)['networkOrder'], 'rackThenRoom');
    final back = _read(bytes);
    expect(back.settings.networkOrder, NetworkOrder.rackThenRoom);
    expect(_codec.write(back), bytes, reason: 'CR-117');
  });

  test('back to by designator, the key is absent again', () {
    final doc = _read(_bytesOf('whole_house'))
      ..settings.networkOrder = NetworkOrder.rackThenRoom;
    final once = _codec.write(doc);
    final again = _read(once)..settings.networkOrder = NetworkOrder.designator;
    expect(
      _settings(_codec.write(again)).containsKey('networkOrder'),
      isFalse,
    );
  });
}
