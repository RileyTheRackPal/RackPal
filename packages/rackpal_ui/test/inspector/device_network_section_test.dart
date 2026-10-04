// The device inspector's network summary (NET-A/2d, `#991`, DR-048
// §11.47.6): read-only, from the one derivation, never a bare address.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

/// Writes through the command, as the product does: the fields' setters
/// are `@internal` to core.
void _set<T>(
  RackDocument doc,
  DeviceInstance d,
  EntityField<DeviceInstance, T> field,
  T to,
) => DocumentController(doc).run(
  buildSetEntityProperty(
    doc: doc,
    id: d.id,
    field: field,
    to: to,
    now: DateTime.utc(2026, 10, 3),
    actor: 'test',
  )!,
);

Future<void> _pump(WidgetTester tester, RackDocument doc, DeviceInstance d) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceNetworkSection(doc: doc, device: d),
        ),
      ),
    );

void main() {
  testWidgets('nothing recorded says so, and where to record it', (
    tester,
  ) async {
    final doc = _wholeHouse();
    await _pump(tester, doc, doc.devices.values.first);
    expect(find.text(kNoNetworkRecorded), findsOneWidget);
  });

  testWidgets('a recorded address shows, with UNVERIFIED beside it until '
      'somebody dates it (DR-048 §11.47.3)', (tester) async {
    final doc = _wholeHouse();
    final sw = doc.devices.values.firstWhere((d) => d.designator == 'SW-1');
    _set(doc, sw, DeviceField.networkIp, '10.0.10.2');
    _set(doc, sw, DeviceField.macAddressPrimary, '00:11:22:33:44:55');
    await _pump(tester, doc, sw);

    expect(find.text('10.0.10.2'), findsOneWidget);
    expect(find.text('00:11:22:33:44:55'), findsOneWidget);
    expect(find.text(kUnverified), findsOneWidget);
    expect(find.text(kEditNetworkInDevices), findsOneWidget);
  });

  testWidgets('a dated row shows its day', (tester) async {
    final doc = _wholeHouse();
    final sw = doc.devices.values.firstWhere((d) => d.designator == 'SW-1');
    _set(doc, sw, DeviceField.networkIp, '10.0.10.2');
    _set(doc, sw, DeviceField.networkVerifiedOn, DateTime.utc(2026, 10, 3));
    await _pump(tester, doc, sw);
    expect(find.text('2026-10-03'), findsOneWidget);
    expect(find.text(kUnverified), findsNothing);
  });

  testWidgets('READ-ONLY: there is nothing here to type into, so the table '
      'is the one place a value is written', (tester) async {
    final doc = _wholeHouse();
    final sw = doc.devices.values.firstWhere((d) => d.designator == 'SW-1');
    _set(doc, sw, DeviceField.networkIp, '10.0.10.2');
    await _pump(tester, doc, sw);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });
}
