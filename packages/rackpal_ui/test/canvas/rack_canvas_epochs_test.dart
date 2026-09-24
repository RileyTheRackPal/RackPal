// The Rack view follows EVERY epoch it reads, measured on the mounted
// screen rather than on the strip alone (`#97`, finding F1).
//
// ═════════════════════════════════════════════════════════════════════
// WHAT WAS WRONG, AND WHY THE APP DID NOT SHOW IT
// ═════════════════════════════════════════════════════════════════════
// DR-171 moved a device's consumed outlets onto the cords drawn to it
// (§11.170.4), so removing a cord changes the outlet chip over the rack.
// `RackCanvasScreen` listened to `structure`, `rack` and `meta` and never
// to `wires`, and it computes the chip (and the findings drawer) in
// `build`. So a wires-only commit changed the number and repainted nothing:
// mounted alone, the chip read `outlets 3/4` over a rack whose only cord
// was gone.
//
// **IN THE APP IT WAS MASKED**, because `DocumentSession` notifies on every
// commit and `AppShell` rebuilds the whole tree when it does. That is a
// correctness property borrowed from a performance accident: the day the
// shell stops rebuilding everything, the chip goes stale. So the screen
// states its own dependency, and this file mounts it WITHOUT the shell,
// which is the configuration that exposes the gap.
//
// `rack_metrics_row_test.dart` pumps the strip on its own and could not
// have seen this: it proves the strip renders what it is given, and says
// nothing about whether the host ever gives it anything new.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

final _when = DateTime.utc(2026, 9, 23);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);
const _rack = Uuid('rack-1');
const _a = Uuid('dev-a');
const _b = Uuid('dev-b');

PortDef _power(String key, PortPowerRole role, String connector, int i) =>
    PortDef(
      key: PortKey(key),
      label: key,
      connector: ConnectorTypeId(connector),
      signalFamily: const SignalFamilyId('power.ac_iec'),
      face: Face.rear,
      position: _pos,
      order: FracIndex('a${i.toString().padLeft(3, '0')}'),
      bankKey: 'pw',
      power: PortPowerSpec(role: role),
    );

/// Two inlets and two outlets, so a device counted from its ports
/// consumes two and a device with one cord drawn consumes one: the chip
/// moves by exactly one when that cord comes and goes.
TemplateBody _body(String model) => TemplateBody(
  manufacturer: 'Demo',
  model: model,
  displayName: model,
  frontU: 1,
  side: OccupancySide.front,
  banks: [
    BankDef(key: 'pw', label: 'PW', abbr: 'PW', order: const FracIndex('a0')),
  ],
  ports: [
    _power('in.1', PortPowerRole.inlet, 'conn.iec_c14', 1),
    _power('in.2', PortPowerRole.inlet, 'conn.iec_c14', 2),
    _power('out.1', PortPowerRole.outlet, 'conn.iec_c13', 3),
    _power('out.2', PortPowerRole.outlet, 'conn.iec_c13', 4),
  ],
);

void _place(RackDocument doc, Uuid id, String designator, int ru) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: _body(designator),
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: RailPlacement(rackId: _rack, ruIndex: ru, face: Face.front),
    meta: _meta(),
  );
}

DocumentController _controller() {
  final doc = RackDocument(
    id: const Uuid('doc-epochs'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'epochs'),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  _place(doc, _a, 'AAA-1', 1);
  _place(doc, _b, 'BBB-1', 4);
  return DocumentController(doc, clock: FixedClock(_when));
}

Future<void> _pump(WidgetTester tester, DocumentController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      shortcuts: appGlobalShortcuts(),
      home: Scaffold(
        body: RackCanvasScreen(
          measurer: _FakeMeasurer(),
          controller: controller,
          clock: FixedClock(_when),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _cord(DocumentController controller) {
  final doc = controller.doc;
  final built = buildConnectPortsCommand(
    doc: doc,
    from: resolveConnectTarget(doc, deviceId: _a, portKey: 'in.1')!,
    to: resolveConnectTarget(doc, deviceId: _b, portKey: 'out.1')!,
    media: const MediaTypeId('media.cat6'),
    now: _when,
    actor: 'test',
  );
  controller.run((built as ConnectPortsReady).command);
}

void main() {
  testWidgets('a cord removed by a wires-only edit gives its outlet back', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    expect(find.text('outlets 4/4'), findsOneWidget);

    _cord(controller);
    await tester.pumpAndSettle();
    expect(
      find.text('outlets 3/4'),
      findsOneWidget,
      reason: 'the precondition: one cord drawn, so AAA-1 consumes one',
    );

    final link = controller.doc.links.values.single;
    final removal = RemoveLinkCommand(
      id: link.id,
      netId: controller.doc.nets.values.single.id,
    );
    expect(
      removal.touches,
      EpochMask.wires,
      reason:
          'this case is only a test of the `wires` listener while the '
          'command it runs touches nothing else',
    );
    controller.run(removal);
    await tester.pumpAndSettle();

    expect(
      find.text('outlets 4/4'),
      findsOneWidget,
      reason:
          'the cord is gone, so AAA-1 is counted from its two inlets '
          'again; a chip still reading 3/4 is a screen that did not hear '
          'the `wires` epoch',
    );
  });

  testWidgets('and undoing that removal takes the outlet again', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    _cord(controller);
    final link = controller.doc.links.values.single;
    controller.run(
      RemoveLinkCommand(
        id: link.id,
        netId: controller.doc.nets.values.single.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('outlets 4/4'), findsOneWidget);

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(find.text('outlets 3/4'), findsOneWidget);
  });
}
