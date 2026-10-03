// The Devices view's writes, through a real controller (NET-A/2a, `#988`,
// DR-048, DR-226).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/network_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _clock = FixedClock(DateTime.utc(2026, 10, 3, 9));

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File('assets/starters/whole_house.rppj').readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late DeviceNetworkEditFn edit;
  late DeviceInstance sw;

  setUp(() {
    doc = _wholeHouse();
    controller = DocumentController(doc, clock: _clock);
    edit = buildDeviceNetworkEditAction(controller: controller);
    sw = doc.devices.values.firstWhere((d) => d.designator == 'SW-1');
  });

  NetworkCellEdit cell(NetworkColumnId column, String value) =>
      NetworkCellEdit(deviceId: sw.id, column: column, value: value);

  test('an address typed into a cell lands on the device, trimmed', () {
    expect(edit([cell(NetworkColumnId.ip, ' 10.0.10.2 ')]), isNull);
    expect(sw.network!.ip, '10.0.10.2');
  });

  test('the MAC lands on macAddressPrimary (DR-226 §11.225.4)', () {
    expect(edit([cell(NetworkColumnId.mac, '00:11:22:33:44:55')]), isNull);
    expect(sw.macAddressPrimary, '00:11:22:33:44:55');
    expect(sw.network, isNull);
  });

  test('an emptied cell is unknown again, never an empty string (G4)', () {
    edit([cell(NetworkColumnId.hostname, 'core-sw')]);
    expect(edit([cell(NetworkColumnId.hostname, '   ')]), isNull);
    expect(sw.network, isNull);
  });

  test('VLANs parse, and anything else is refused with the reason, '
      'changing nothing', () {
    expect(edit([cell(NetworkColumnId.vlans, '10, 20')]), isNull);
    expect(sw.network!.vlans, [10, 20]);
    expect(
      edit([cell(NetworkColumnId.vlans, 'ten')]),
      kVlansNotUnderstood,
    );
    expect(sw.network!.vlans, [10, 20]);
  });

  test('a date is a day, and a mistyped one is refused (DR-048 §11.47.3)', () {
    expect(edit([cell(NetworkColumnId.verified, '2026-10-03')]), isNull);
    expect(sw.network!.verifiedOn, DateTime.utc(2026, 10, 3));
    expect(
      edit([cell(NetworkColumnId.verified, '2026-02-30')]),
      kVerifiedNotUnderstood,
    );
    expect(edit([cell(NetworkColumnId.verified, 'unverified')]), isNull);
    expect(sw.network, isNull);
  });

  test('editing an address never stamps the date (DR-226 §11.225.5)', () {
    edit([cell(NetworkColumnId.ip, '10.0.10.2')]);
    expect(sw.network!.verifiedOn, isNull);
  });

  test('several cells are ONE undo step', () {
    edit([
      cell(NetworkColumnId.hostname, 'core-sw'),
      cell(NetworkColumnId.ip, '10.0.10.2'),
    ]);
    controller.undoLast();
    expect(sw.network, isNull);
  });

  test('a device not in the project is refused', () {
    expect(
      edit([
        const NetworkCellEdit(
          deviceId: Uuid('nobody'),
          column: NetworkColumnId.ip,
          value: '1.2.3.4',
        ),
      ]),
      kDeviceNotInProject,
    );
  });
}
