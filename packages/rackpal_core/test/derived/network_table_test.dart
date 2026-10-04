// derived/network_table.dart — the one derivation behind the Devices view
// and T6.50 (NET-A/2a, `#988`, DR-048, DR-226, DR-227).

import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

DeviceInstance _named(RackDocument doc, String designator) =>
    doc.devices.values.firstWhere((d) => d.designator == designator);

void main() {
  group('who is listed (DR-227 §11.226.2)', () {
    test('Whole House lists 26 by default: its Network devices less the '
        'four passthroughs, which carry Network ports and no address', () {
      final doc = _starter('whole_house');
      final rows = buildNetworkTable(doc);
      expect(rows, hasLength(26));
      final listed = {for (final r in rows) r.designator};
      for (final passthrough in ['PP-1', 'PP-2', 'PP-3', 'LIU-1']) {
        expect(listed, isNot(contains(passthrough)));
      }
      expect(listed, containsAll(<String>['SW-1', 'FW-1', 'AP-1', 'PDU-1']));
    });

    test('Show all lists every device, passthroughs and blanks included', () {
      final doc = _starter('whole_house');
      expect(
        buildNetworkTable(doc, showAll: true),
        hasLength(doc.devices.length),
      );
    });

    test('a template that says Wi-Fi lists without a Network port', () {
      final doc = _starter('whole_house');
      final amp = _named(doc, 'AMP-1');
      final unlisted = doc.devices.values.firstWhere(
        (d) => !isNetworkCapable(d, doc) && bodyFor(d, doc.templates) != null,
      );
      expect(isNetworkCapable(unlisted, doc), isFalse, reason: 'control');
      bodyFor(unlisted, doc.templates)!.wifi = true;
      expect(isNetworkCapable(unlisted, doc), isTrue);
      expect(isNetworkCapable(amp, doc), isTrue, reason: 'AMP-1 has a jack');
    });

    test('a device already carrying a value stays listed whatever its '
        'template says, so the table never hides what T6.50 prints', () {
      final doc = _starter('whole_house');
      final panel = _named(doc, 'PP-1');
      expect(isNetworkCapable(panel, doc), isFalse, reason: 'control');
      DocumentController(doc).run(
        buildSetEntityProperty(
          doc: doc,
          id: panel.id,
          field: DeviceField.macAddressPrimary,
          to: '00:11:22:33:44:55',
          now: DateTime.utc(2026, 10, 3),
          actor: 'test',
        )!,
      );
      expect(isNetworkCapable(panel, doc), isTrue);
    });
  });

  group('order (DR-227 §11.226.4)', () {
    test('by designator is the default, read the way a person reads them', () {
      final rows = buildNetworkTable(_starter('whole_house'));
      final names = [for (final r in rows) r.designator];
      final sorted = [...names]..sort(compareDesignators);
      expect(names, sorted);
    });

    test('rack then room: every rack device first, top unit down, then the '
        'rooms', () {
      final doc = _starter('whole_house');
      final rows = buildNetworkTable(doc, order: NetworkOrder.rackThenRoom);
      final inRack = [
        for (final r in rows)
          hostRackOf(doc.devices[r.deviceId]!, doc.devices) != null,
      ];
      final firstRoom = inRack.indexOf(false);
      expect(firstRoom, greaterThan(0));
      expect(inRack.skip(firstRoom), everyElement(isFalse));

      final units = [
        for (final r in rows.take(firstRoom))
          if (doc.devices[r.deviceId]!.placement case final RailPlacement p)
            p.ruIndex,
      ];
      expect(units, [...units]..sort((a, b) => b.compareTo(a)));
      expect(rows.first.where, startsWith('RK-1 · U'));
    });

    test('the two orders list the same devices', () {
      final doc = _starter('whole_house');
      Set<Uuid> ids(NetworkOrder o) => {
        for (final r in buildNetworkTable(doc, order: o)) r.deviceId,
      };
      expect(
        ids(NetworkOrder.rackThenRoom),
        ids(NetworkOrder.designator),
      );
    });
  });

  group('the cells', () {
    test('a row reads its device: the MAC is macAddressPrimary, not '
        'network.mac (DR-226 §11.225.4)', () {
      final doc = _starter('whole_house');
      final sw = _named(doc, 'SW-1')
        ..network = NetworkConfig(
          ip: '10.0.10.2',
          mac: 'never-shown',
          vlans: [10, 20],
          verifiedOn: DateTime.utc(2026, 10, 3),
        )
        ..macAddressPrimary = '00:11:22:33:44:55';
      final row = buildNetworkTable(doc).firstWhere((r) => r.deviceId == sw.id);
      expect(row.ip, '10.0.10.2');
      expect(row.mac, '00:11:22:33:44:55');
      expect(row.vlansText, '10, 20');
      expect(row.verifiedText, '2026-10-03');
      expect(row.hasValues, isTrue);
    });

    test('an undated row says unverified, never a blank (DR-048 §11.47.3)', () {
      final row = buildNetworkTable(_starter('whole_house')).first;
      expect(row.verifiedOn, isNull);
      expect(row.verifiedText, kUnverified);
      expect(row.hasValues, isFalse);
    });

    test('VLANs parse from commas or spaces, refuse anything else, and an '
        'empty cell is nobody said', () {
      expect(parseVlans('10, 20 30'), [10, 20, 30]);
      expect(parseVlans(''), isEmpty);
      expect(parseVlans('10, abc'), isNull);
      expect(parseVlans('0'), isNull, reason: '802.1Q usable range is 1-4094');
      expect(parseVlans('4095'), isNull);
    });
  });
}
