// The Devices view's writes (NET-A/1c, `#987`, DR-048 §11.47.6, DR-226):
// one `DeviceField` row per column, through the ordinary property command
// and the ordinary undo stack.
//
// Bytes are compared over THE DEVICE'S OWN RECORD, not the whole file,
// because every commit and every undo advances the document's `sequence`
// (CR-094) and the file can never come back byte for byte through the
// controller; the record can, and that is the claim.

import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 10, 3, 9);

RackDocument _wholeHouse() =>
    (_codec.read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

String _recordOf(RackDocument doc, Uuid id) {
  final root =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  final devices =
      (root['document']! as Map<String, Object?>)['devices']!
          as Map<String, Object?>;
  return jsonEncode(devices[id.v]);
}

/// The lowest-id device.
Uuid _firstId(RackDocument doc) =>
    (doc.devices.keys.toList()..sort((a, b) => a.v.compareTo(b.v))).first;

SetEntityPropertyCommand<DeviceInstance, T>? _set<T>(
  RackDocument doc,
  Uuid id,
  EntityField<DeviceInstance, T> field,
  T to,
) => buildSetEntityProperty(
  doc: doc,
  id: id,
  field: field,
  to: to,
  now: _now,
  actor: 'test',
);

void main() {
  late RackDocument doc;
  late Uuid id;
  late DocumentController controller;

  setUp(() {
    doc = _wholeHouse();
    id = _firstId(doc);
    controller = DocumentController(doc);
  });

  test("the first value creates the device's network, and undo leaves the "
      'record exactly as it was, key absent', () {
    final before = _recordOf(doc, id);
    expect(doc.devices[id]!.network, isNull);

    controller.run(_set(doc, id, DeviceField.networkIp, '10.0.10.2')!);
    expect(doc.devices[id]!.network!.ip, '10.0.10.2');
    expect(_recordOf(doc, id), contains('"network"'));

    controller.undoLast();
    expect(doc.devices[id]!.network, isNull);
    expect(_recordOf(doc, id), before);
  });

  test('clearing the last value drops the network, so the key is absent '
      'again (DR-048 §11.47.2)', () {
    controller
      ..run(_set(doc, id, DeviceField.networkHostname, 'core-sw')!)
      ..run(_set(doc, id, DeviceField.networkHostname, null)!);
    expect(doc.devices[id]!.network, isNull);
    expect(_recordOf(doc, id), isNot(contains('"network"')));
  });

  test('the MAC writes macAddressPrimary and never the network '
      '(DR-226 §11.225.4)', () {
    controller.run(
      _set(doc, id, DeviceField.macAddressPrimary, '00:11:22:33:44:55')!,
    );
    expect(doc.devices[id]!.macAddressPrimary, '00:11:22:33:44:55');
    expect(doc.devices[id]!.network, isNull);
  });

  test('editing a value never stamps verifiedOn (DR-226 §11.225.5)', () {
    controller.run(_set(doc, id, DeviceField.networkIp, '10.0.10.2')!);
    expect(doc.devices[id]!.network!.verifiedOn, isNull);
  });

  test('VLANs are compared by content: retyping the same list is nothing '
      'to do, not an empty undo entry', () {
    controller.run(_set(doc, id, DeviceField.networkVlans, [10, 20])!);
    expect(_set(doc, id, DeviceField.networkVlans, [10, 20]), isNull);
    expect(_set(doc, id, DeviceField.networkVlans, [10, 30]), isNotNull);
  });

  test("a stored VLAN list cannot be changed under an undo's feet", () {
    final typed = [10, 20];
    controller.run(_set(doc, id, DeviceField.networkVlans, typed)!);
    typed.add(99);
    expect(doc.devices[id]!.network!.vlans, [10, 20]);
    expect(() => doc.devices[id]!.network!.vlans.add(1), throwsA(anything));
  });

  test('Verified today over several devices is one undo entry, and undo '
      'restores every record', () {
    final ids = (doc.devices.keys.toList()..sort((a, b) => a.v.compareTo(b.v)))
        .take(3)
        .toList();
    final before = {for (final d in ids) d: _recordOf(doc, d)};
    final day = DateTime.utc(2026, 10, 3);

    controller.transact(null, (tx) {
      for (final d in ids) {
        tx.add(_set(doc, d, DeviceField.networkVerifiedOn, day)!);
      }
    });
    for (final d in ids) {
      expect(doc.devices[d]!.network!.verifiedOn, day);
    }

    controller.undoLast();
    for (final d in ids) {
      expect(_recordOf(doc, d), before[d], reason: d.v);
    }
  });

  test(
    'every network row is in DeviceField.all, keyed apart from the rest',
    () {
      final keys = DeviceField.all.map((f) => f.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(
        keys,
        containsAll(<String>[
          'macAddressPrimary',
          'network.hostname',
          'network.ip',
          'network.subnet',
          'network.gw',
          'network.vlans',
          'network.verifiedOn',
        ]),
      );
    },
  );
}
