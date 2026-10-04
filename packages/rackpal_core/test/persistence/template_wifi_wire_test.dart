// `TemplateBody.wifi` on the wire (NET-A/2e, `#996`, DR-227 §11.226.3).
//
// THE KEY IS READ OFF THE TEMPLATE BODIES, NOT THE TEXT: the access point's
// template already carries the TAG "wifi" in every starter, so the bare word
// is in all four files and says nothing about this field.

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

/// Every template body's JSON, by template key.
Map<String, Map<String, Object?>> _bodies(Uint8List bytes) {
  final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final templates =
      (root['document']! as Map<String, Object?>)['templates']!
          as Map<String, Object?>;
  return templates.map(
    (k, v) => MapEntry(
      k,
      (v! as Map<String, Object?>)['body']! as Map<String, Object?>,
    ),
  );
}

/// [bytes] with the lowest-key template's `wifi` set to [value].
Uint8List _withWifi(Uint8List bytes, bool? value) {
  final doc = _read(bytes);
  final key = (doc.templates.keys.toList()..sort()).first;
  doc.templates[key]!.body.wifi = value;
  return _codec.write(doc);
}

void main() {
  for (final name in _starters) {
    test('$name: no template states it, so no body carries the key and the '
        'file still writes back its own bytes', () {
      final bytes = _bytesOf(name);
      for (final body in _bodies(bytes).values) {
        expect(body.containsKey('wifi'), isFalse);
      }
      expect(_codec.write(_read(bytes)), bytes);
    });
  }

  test('a stated yes and a stated NO are both written, and read back as '
      'themselves: no is a fact, not an absence (G4)', () {
    for (final value in [true, false]) {
      final bytes = _withWifi(_bytesOf('whole_house'), value);
      final stated = _bodies(bytes).values.where((b) => b.containsKey('wifi'));
      expect(stated.single['wifi'], value);
      final back = _read(bytes);
      expect(
        back.templates.values
            .where((t) => t.body.wifi != null)
            .single
            .body
            .wifi,
        value,
      );
      expect(_codec.write(back), bytes, reason: 'CR-117');
    }
  });

  test('unstated after being stated is absent again', () {
    final once = _withWifi(_bytesOf('whole_house'), true);
    final cleared = _withWifi(once, null);
    expect(
      _bodies(cleared).values.where((b) => b.containsKey('wifi')),
      isEmpty,
    );
  });
}
