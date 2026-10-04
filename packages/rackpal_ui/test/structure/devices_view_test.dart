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

/// What the harness's actions were asked to do.
final class _Calls {
  final List<List<NetworkCellEdit>> edits = [];
  final List<List<Uuid>> verifiedToday = [];
}

late _Calls _calls;

Future<List<List<NetworkCellEdit>>> _pump(
  WidgetTester tester,
  RackDocument doc, {
  NetworkOrder order = NetworkOrder.designator,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _calls = _Calls();
  final edits = _calls.edits;
  // THE EDITOR'S STATE, played by a StatefulBuilder: the view is
  // controlled, so a test that does not hold its state cannot flip it.
  var showAll = false;
  final shown = {...defaultNetworkColumns};
  final selected = <Uuid>{};
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DevicesView(
            doc: doc,
            order: order,
            showAll: showAll,
            onShowAll: (v) => setState(() => showAll = v),
            shown: shown,
            onColumn: (c) => setState(() {
              if (!shown.remove(c)) shown.add(c);
            }),
            selected: selected,
            onSelect: (id, {required ticked}) => setState(() {
              ticked ? selected.add(id) : selected.remove(id);
            }),
            onSelectAll: (ids, {required ticked}) => setState(() {
              ticked ? selected.addAll(ids) : selected.removeAll(ids);
            }),
            onCaret: (_) {},
            actions: DevicesActions(
              onEdit: (e) {
                edits.add(e);
                return null;
              },
              onVerifiedToday: (ids) {
                _calls.verifiedToday.add(ids);
                return null;
              },
            ),
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

  testWidgets('the table follows the order it is given, the one T6.50 '
      'prints by (DR-227 §11.226.4)', (tester) async {
    final doc = _wholeHouse();
    final byRack = buildNetworkTable(doc, order: NetworkOrder.rackThenRoom);
    final byName = buildNetworkTable(doc);
    // THE CONTROL: the two orders must start differently on this project,
    // or this test could not tell them apart.
    expect(byRack.first.deviceId, isNot(byName.first.deviceId));

    await _pump(tester, doc, order: NetworkOrder.rackThenRoom);
    final firstOnScreen = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .firstWhere((t) => byRack.any((r) => r.designator == t));
    expect(firstOnScreen, byRack.first.designator);
  });

  testWidgets('Columns puts subnet and gateway on, and a default column off '
      '(NET-A/2b)', (tester) async {
    await _pump(tester, _wholeHouse());
    expect(find.text('SUBNET'), findsNothing, reason: 'control');

    await tester.tap(find.text(kDeviceColumnsLabel));
    await tester.pumpAndSettle();
    // THE MENU ITEM, NOT THE WORD: once a column shows, its name is both a
    // heading and an item, and `.last` picked the heading, which taps to
    // nothing. Anchored on the item's own type.
    await tester.tap(find.widgetWithText(MenuItemButton, 'SUBNET'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'MAC'));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    expect(find.text('SUBNET'), findsOneWidget, reason: 'now a heading');
    expect(find.text('MAC'), findsNothing, reason: 'turned off');
  });

  group('the batch bar (NET-A/2c)', () {
    testWidgets('absent until a row is ticked, then counts it', (
      tester,
    ) async {
      final doc = _wholeHouse();
      await _pump(tester, doc);
      expect(find.text(kVerifiedTodayLabel), findsNothing, reason: 'control');

      final first = buildNetworkTable(doc).first;
      await tester.tap(
        find.byKey(ValueKey('devices-tick-${first.deviceId.v}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text(kVerifiedTodayLabel), findsOneWidget);
    });

    testWidgets('Set writes one value into every ticked row, as ONE call', (
      tester,
    ) async {
      final doc = _wholeHouse();
      await _pump(tester, doc);
      final rows = buildNetworkTable(doc);
      for (final r in rows.take(2)) {
        await tester.tap(find.byKey(ValueKey('devices-tick-${r.deviceId.v}')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('devices-batch-column')));
      await tester.pumpAndSettle();
      // AN ON-SCREEN COLUMN: the bar offers only what shows, the cable
      // bar's rule. Anchored on the menu item, since HOSTNAME is also a
      // heading.
      await tester.tap(
        find.widgetWithText(DropdownMenuItem<NetworkColumnId>, 'HOSTNAME').last,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('devices-batch-value')),
        'core-sw',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final batch = _calls.edits.single;
      expect(batch.map((e) => e.deviceId), [
        rows[0].deviceId,
        rows[1].deviceId,
      ]);
      expect(batch.map((e) => e.column).toSet(), {NetworkColumnId.hostname});
      expect(batch.map((e) => e.value).toSet(), {'core-sw'});
    });

    testWidgets('Verified today asks for exactly the ticked rows', (
      tester,
    ) async {
      final doc = _wholeHouse();
      await _pump(tester, doc);
      await tester.tap(find.byKey(const ValueKey('devices-tick-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kVerifiedTodayLabel));
      await tester.pumpAndSettle();
      expect(
        _calls.verifiedToday.single,
        [for (final r in buildNetworkTable(doc)) r.deviceId],
      );
    });

    testWidgets('Clear selection unticks and the bar goes', (tester) async {
      final doc = _wholeHouse();
      await _pump(tester, doc);
      await tester.tap(find.byKey(const ValueKey('devices-tick-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kClearSelectionLabel));
      await tester.pumpAndSettle();
      expect(find.text(kVerifiedTodayLabel), findsNothing);
    });
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
