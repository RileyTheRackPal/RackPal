// DR-048 §11.47.3 and §11.47.9 on the wire (NET-A/1a, `#985`).
//
// A FILE-COMPATIBILITY GATE, shaped like `link_class_locked_wire_test.dart`
// and for its reason. The load-bearing assertions are NEGATIVE: an empty
// `vlans` and a null `verifiedOn` do not appear AT ALL. A byte-identity
// round trip cannot catch either, because an unconditionally written `[]`
// re-encodes consistently and passes every round trip there is; that is how
// `"vlans": []` sat in this codec from M0 until DR-048 read it.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

RackDocument _wholeHouse() =>
    (_codec.read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

String _text(RackDocument doc) => String.fromCharCodes(_codec.write(doc));

/// Whole House with [config] on its lowest-id port.
RackDocument _withNetwork(NetworkConfig config) {
  final doc = _wholeHouse();
  final port =
      (doc.ports.values.toList()..sort((a, b) => a.id.v.compareTo(b.id.v)))
          .first;
  return doc..ports[port.id]!.network = config;
}

void main() {
  test('THE CONTROL: no starter carries a network value, so every key '
      "below is this file's and not one a starter brought", () {
    // THE KEY, NOT THE WORD: every starter's templates carry a bank whose
    // key is the string "network", so the bare word is in all four files.
    final doc = _wholeHouse();
    expect(doc.ports.values.where((p) => p.network != null), isEmpty);
    expect(_text(doc), isNot(contains('"network": {')));
  });

  group('vlans', () {
    test('ABSENT when nobody stated one: an empty list is not measured zero '
        '(CR-114)', () {
      final text = _text(_withNetwork(NetworkConfig(ip: '10.0.10.2')));
      expect(text, contains('"ip": "10.0.10.2"'));
      expect(text, isNot(contains('"vlans"')));
    });

    test('present, and round-trips, when stated', () {
      final bytes = _codec.write(_withNetwork(NetworkConfig(vlans: [10, 20])));
      final back = (_codec.read(bytes) as Ok<RackDocument>).value;
      final stated = back.ports.values.where((p) => p.network != null);
      expect(stated.single.network!.vlans, [10, 20]);
    });

    test('an explicit "vlans": [] on disk reads as nobody said', () {
      final text = _text(
        _withNetwork(NetworkConfig(vlans: [99])),
      ).replaceFirst(RegExp(r'"vlans": \[\s*99\s*\]'), '"vlans": []');
      expect(text, contains('"vlans": []'), reason: 'the edit took');
      final back =
          (_codec.read(Uint8List.fromList(utf8.encode(text)))
                  as Ok<RackDocument>)
              .value;
      expect(
        back.ports.values.where((p) => p.network != null).single.network!.vlans,
        isEmpty,
      );
    });
  });

  group('verifiedOn', () {
    test('ABSENT when nobody verified: unverified is not a date', () {
      expect(
        _text(_withNetwork(NetworkConfig(ip: '10.0.10.2'))),
        isNot(contains('verifiedOn')),
      );
    });

    test('present, and round-trips to the day, when set', () {
      final day = DateTime.utc(2026, 10, 3);
      final bytes = _codec.write(
        _withNetwork(NetworkConfig(ip: '10.0.10.2', verifiedOn: day)),
      );
      expect(String.fromCharCodes(bytes), contains('"verifiedOn"'));
      final back = (_codec.read(bytes) as Ok<RackDocument>).value;
      expect(
        back.ports.values
            .where((p) => p.network != null)
            .single
            .network!
            .verifiedOn,
        day,
      );
    });
  });

  test('CR-117: a document carrying both writes back the bytes it read', () {
    final bytes = _codec.write(
      _withNetwork(
        NetworkConfig(
          hostname: 'core-sw',
          ip: '10.0.10.2',
          subnet: '255.255.255.0',
          gw: '10.0.10.1',
          vlans: [10, 20],
          verifiedOn: DateTime.utc(2026, 10, 3),
        ),
      ),
    );
    final again = _codec.write((_codec.read(bytes) as Ok<RackDocument>).value);
    expect(again, bytes);
  });
}
