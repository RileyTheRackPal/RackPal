// The Devices view (NET-A/2a, `#988`, DR-226, DR-227), on Whole House.
//
// Rows are built lazily, so how many there are is read off the toolbar's
// own count, which is the view's statement of it, rather than by counting
// widgets that a ListView only builds on screen.

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

Future<List<List<NetworkCellEdit>>> _pump(
  WidgetTester tester,
  RackDocument doc,
) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final edits = <List<NetworkCellEdit>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DevicesView(
          doc: doc,
          actions: DevicesActions(
            onEdit: (e) {
              edits.add(e);
              return null;
            },
          ),
        ),
      ),
    ),
  );
  return edits;
}

void main() {
  testWidgets('lists the 26 network-capable devices, with the default '
      'columns and not subnet or gateway (DR-226 §11.225.3)', (tester) async {
    await _pump(tester, _wholeHouse());
    expect(find.text('26 devices · 0 verified'), findsOneWidget);
    for (final header in [
      'DEVICE',
      'HOSTNAME',
      'IP ADDRESS',
      'MAC',
      'VLANS',
      'VERIFIED',
    ]) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('SUBNET'), findsNothing);
    expect(find.text('GATEWAY'), findsNothing);
  });

  testWidgets('a patch panel is not listed until Show all is on '
      '(DR-227 §11.226.2)', (tester) async {
    final doc = _wholeHouse();
    await _pump(tester, doc);
    expect(find.text('PP-1'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text('${doc.devices.length} devices · 0 verified'),
      findsOneWidget,
    );
  });

  testWidgets('an undated row says unverified in the date box', (
    tester,
  ) async {
    await _pump(tester, _wholeHouse());
    expect(find.text(kUnverified), findsWidgets);
  });

  testWidgets('typing an address and pressing Enter sends ONE edit for that '
      'device and column', (tester) async {
    final doc = _wholeHouse();
    final edits = await _pump(tester, doc);
    final first = buildNetworkTable(doc).first;
    final ipBox = find.byKey(ValueKey('${first.deviceId.v}:ip'));
    expect(ipBox, findsOneWidget, reason: 'the first row is on screen');

    await tester.enterText(
      find.descendant(of: ipBox, matching: find.byType(TextField)),
      '10.0.10.2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(edits, hasLength(1));
    expect(edits.single.single.deviceId, first.deviceId);
    expect(edits.single.single.column, NetworkColumnId.ip);
    expect(edits.single.single.value, '10.0.10.2');
  });

  testWidgets('the identity columns are read, not typed into', (
    tester,
  ) async {
    final doc = _wholeHouse();
    await _pump(tester, doc);
    final first = buildNetworkTable(doc).first;
    expect(find.byKey(ValueKey('${first.deviceId.v}:device')), findsNothing);
    expect(find.text(first.designator), findsOneWidget);
  });
}
