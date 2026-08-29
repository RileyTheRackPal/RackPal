// M4-L4's form in the inspector — `#233`, CR-053, DR-098 §11.97.6.
//
// =====================================================================
// THE POINT IS THAT A CORRECTION REACHES SOMETHING
// =====================================================================
// `PortOverrides` had no reader anywhere before `#233`, so a form over it
// would have been a save that changed nothing a person could see. The
// resolver landed first and `connect_target.dart` reads it. The
// load-bearing case here is therefore not "the dropdown changed" but that
// the CONNECT TARGET — the pin the connect gesture acts on and the pin
// tier-1 rules are evaluated against — answers with the correction
// afterwards. The callback runs the REAL `SetPortFactCommand` for that
// reason: asserting the arguments handed to a callback would prove the
// widget calls something, not that anything happens.
//
// =====================================================================
// NOT MOUNTED THROUGH `RackCanvasScreen`, AND THE REASON IS A FINDING
// =====================================================================
// EVERY TEMPLATE ON THE DEMO DOCUMENT HAS ZERO PORTS. The first draft of
// this file drove the real screen, selected SW-1 and asserted the section
// listed its jacks; the count came back 0, on a network switch. So the
// demo fixture cannot exercise this section at all, and a test that looked
// like it did would have been asserting an empty list.
//
// The section is therefore mounted directly over a document that has
// ports. Its wiring into the panel is covered by
// `device_overrides_section_test.dart`, which mounts the real panel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 8, 29);
const _deviceId = Uuid('d1');
const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

PortDef _def(String key, String label, String order) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
);

RackDocument _doc({bool withPorts = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-ports-form'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  doc.templates['sw@1'] = TemplateSnapshot(
    templateId: const TemplateId('sw'),
    version: 1,
    contentHash: 'unhashed:sw@1',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'sw',
      displayName: 'Switch',
      frontU: 1,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
      // DECLARED OUT OF ORDER ON PURPOSE: `p2` is listed first and ordered
      // second, so a section that skipped the sort shows them swapped.
      ports: withPorts
          ? [_def('p2', 'PORT 2', 'a1'), _def('p1', 'PORT 1', 'a0')]
          : const [],
    ),
    capturedAt: _now,
  );
  doc.devices[_deviceId] = DeviceInstance(
    id: _deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('sw'),
      version: 1,
      contentHash: 'unhashed:sw@1',
    ),
    designator: 'SW-1',
    name: 'SW-1',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  return doc;
}

/// Mounts the section over [doc] and runs the REAL command on every edit,
/// rebuilding after so the widget reads the document it just changed.
Widget _host(RackDocument doc, {void Function(SetPortFactCommand)? onRun}) =>
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: DevicePortsSection(
                doc: doc,
                device: doc.devices[_deviceId]!,
                onSetPortFact: (key, field, value, designator) {
                  final cmd = SetPortFactCommand(
                    deviceId: _deviceId,
                    portKey: key,
                    field: field,
                    value: value,
                    designatorIfMaterialised: designator,
                    now: _now,
                    actor: 'test',
                  )..apply(doc);
                  onRun?.call(cmd);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );

ConnectTarget _target(RackDocument doc, String key) =>
    resolveConnectTarget(doc, deviceId: _deviceId, portKey: key)!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the list, opens `p1`, and picks the XLR connector.
Future<void> _correctP1(WidgetTester tester, RackDocument doc) async {
  await _tap(tester, find.textContaining('PORTS ('));
  await _tap(tester, find.byKey(const ValueKey('port-row-p1')));
  await _tap(tester, find.byKey(const ValueKey('port-connector-p1')));
  final xlr =
      doc.registries.connectorTypes[const ConnectorTypeId('conn.xlr3')]!;
  await _tap(tester, find.text(xlr.displayName).last);
}

void main() {
  testWidgets('the section counts the ports and starts CLOSED', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_doc()));
    await tester.pumpAndSettle();

    expect(find.text('PORTS (2)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('port-row-p1')),
      findsNothing,
      reason: 'a 68-port list expanding on selection would bury door 1',
    );
  });

  testWidgets('opening it lists the ports IN TEMPLATE ORDER, not the order '
      'they happen to sit in the list', (tester) async {
    await tester.pumpWidget(_host(_doc()));
    await tester.pumpAndSettle();
    await _tap(tester, find.textContaining('PORTS ('));

    final rows = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .map((w) => w.key)
        .whereType<ValueKey<String>>()
        .map((k) => k.value)
        .where((v) => v.startsWith('port-row-'))
        .toList();
    expect(rows, <String>['port-row-p1', 'port-row-p2']);
  });

  testWidgets('CORRECTING A CONNECTOR REACHES THE CONNECT TARGET, which is '
      'the whole reason the resolver came first', (tester) async {
    final doc = _doc();
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();

    expect(_target(doc, 'p1').connector, const ConnectorTypeId('conn.rj45'));

    await _correctP1(tester, doc);

    expect(
      _target(doc, 'p1').connector,
      const ConnectorTypeId('conn.xlr3'),
      reason:
          'a correction that does not reach the pin is a save that '
          'changes nothing a person can see',
    );
  });

  testWidgets('THE EDIT MATERIALISES THE PORT, and undoing removes it', (
    tester,
  ) async {
    final doc = _doc();
    final ran = <SetPortFactCommand>[];
    await tester.pumpWidget(_host(doc, onRun: ran.add));
    await tester.pumpAndSettle();

    expect(doc.ports, isEmpty, reason: 'every pin starts unmaterialised');

    await _correctP1(tester, doc);

    expect(doc.ports, hasLength(1));
    expect(
      doc.ports.values.single.designator,
      isNotEmpty,
      reason:
          'the designator is allocated caller-side and handed over, '
          'because the command must not allocate inside apply (DR-011.1)',
    );

    ran.single.revert(doc);
    expect(
      doc.ports,
      isEmpty,
      reason:
          'a port holding no override is a row in the file that means '
          'nothing, which lazy materialisation exists to keep out',
    );
  });

  testWidgets('a corrected port is MARKED in the list, so the correction is '
      'findable without opening every row', (tester) async {
    final doc = _doc();
    await tester.pumpWidget(_host(doc));
    await tester.pumpAndSettle();
    await _tap(tester, find.textContaining('PORTS ('));

    expect(find.byTooltip('Corrected on this device'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('port-row-p1')));
    await _tap(tester, find.byKey(const ValueKey('port-connector-p1')));
    final xlr =
        doc.registries.connectorTypes[const ConnectorTypeId('conn.xlr3')]!;
    await _tap(tester, find.text(xlr.displayName).last);

    expect(find.byTooltip('Corrected on this device'), findsOneWidget);
  });

  testWidgets('a template with NO PORTS says so and prints no count', (
    tester,
  ) async {
    // "PORTS (0)" reads as something having gone wrong. A blank panel or a
    // shelf is a normal thing to place. The first draft printed the zero
    // while its own comment claimed it did not.
    await tester.pumpWidget(_host(_doc(withPorts: false)));
    await tester.pumpAndSettle();

    expect(find.text('PORTS (0)'), findsNothing);
    expect(find.text('PORTS'), findsOneWidget);
    expect(find.text('This template declares no ports.'), findsOneWidget);
  });
}
