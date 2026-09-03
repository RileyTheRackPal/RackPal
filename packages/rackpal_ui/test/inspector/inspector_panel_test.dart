// The rack inspector's device column, assembled (`#808`).
//
// ═══════════════════════════════════════════════════════════════════════
// NOTHING MOUNTED `InspectorPanel` UNTIL THIS FILE, AND THAT IS THE BUG
// ═══════════════════════════════════════════════════════════════════════
// `device_ports_section_test.dart` mounts `DevicePortsSection` directly,
// inside its own `SingleChildScrollView`, and passes. The section is not
// broken. What was broken was the COLUMN IT SITS IN, which only
// `rack_canvas_screen.dart` ever built, and no test built that either.
//
// A `Spacer` after the `Expanded(SingleChildScrollView(...))` is itself an
// `Expanded`, so the two split the free space 50/50. The viewport got half
// the column while its content needed all of it, and the port list was
// laid out BELOW the viewport inside the blank half: painted where a
// person can see it, and outside the viewport for hit testing. `PORTS
// (52)` showed above a large empty area and did nothing when clicked.
//
// So the first test here is geometric rather than behavioural. Tapping
// alone would have gone on passing the moment somebody scrolled the
// header into view by hand; what has to hold is that the section is
// INSIDE the thing that scrolls it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9);
const _deviceId = Uuid('d1');
const _rackId = Uuid('r1');
const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

PortDef _def(int i) => PortDef(
  key: PortKey('p$i'),
  label: 'PORT $i',
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  position: _pos,
  order: FracIndex('a${i.toString().padLeft(3, '0')}'),
);

/// A placed device whose template declares [ports] jacks.
///
/// FIFTY-TWO BY DEFAULT, not two. The defect is a layout one and it is
/// invisible on a short list: the section has to be tall enough to reach
/// past the viewport's bottom edge before anything goes wrong.
RackDocument _doc({int ports = 52}) {
  final doc = RackDocument(
    id: const Uuid('doc-inspector'),
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
      ports: [for (var i = 0; i < ports; i++) _def(i)],
    ),
    capturedAt: _now,
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    designator: 'RK-1',
    name: 'Rack 1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
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

/// The panel in the column `rack_canvas_screen.dart` gives it: 320 wide,
/// stretched to the row's height. Both of those matter to the defect.
Future<void> _pump(
  WidgetTester tester,
  RackDocument doc, {
  Size size = const Size(1600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: SizedBox()),
            SizedBox(
              width: 320,
              child: InspectorPanel(
                target: InspectorTarget.selection,
                rack: doc.racks[_rackId]!,
                doc: doc,
                presets: const {},
                selectedIds: const {_deviceId},
                focusedId: _deviceId,
                onSetProperty: <T>(field, value) {},
                onRename: (_) {},
                onRequestHeight: (_) {},
                onApplyPreset: (_) {},
                onRefuse: (_) {},
                onSetLifecycle: (_) {},
                onSetWidth: (_) {},
                onSetOverride: <T>(field, value) {},
                onSetPortFact: (a, b, c, d, e) {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the device column can actually reach its port list (`#808`)', () {
    testWidgets('the ports section is INSIDE the scroll viewport, which is '
        'what makes it hit-testable at all', (tester) async {
      await _pump(tester, _doc());

      final viewport = find.descendant(
        of: find.byType(InspectorPanel),
        matching: find.byType(SingleChildScrollView),
      );
      expect(viewport, findsOneWidget, reason: 'the column stopped scrolling');

      final section = tester.getRect(find.byType(DevicePortsSection));
      final box = tester.getRect(viewport);
      expect(
        section.bottom,
        lessThanOrEqualTo(box.bottom),
        reason:
            'the port list is laid out below the viewport, so it paints '
            'where a person can see it and refuses every click. A `Spacer` '
            'competing with the scroll view for flex is how it got there',
      );
    });

    testWidgets('the header is collapsed, and clicking it lists every port', (
      tester,
    ) async {
      final doc = _doc();
      await _pump(tester, doc);

      expect(find.text('PORTS (52)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('port-row-p0')),
        findsNothing,
        reason: 'a long list expanding on selection would bury door 1',
      );

      // NO `ensureVisible` HERE, DELIBERATELY. It would scroll the header
      // into reach and hide the defect: the point is that the header a
      // person can already see responds to the click they give it.
      await tester.tap(find.text('PORTS (52)'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byKey(const ValueKey('port-row-p0')), findsOneWidget);
      expect(find.text('PORT 0'), findsOneWidget);
    });

    testWidgets('and the rack-settings hint still sits at the bottom when '
        'there is no sole device to fill the column', (tester) async {
      // The `Spacer` is gated on the sole device now, so the case it was
      // there for has to keep working: with nothing selected the hint is
      // pushed down rather than left floating under the header.
      final doc = _doc();
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 320,
                  child: InspectorPanel(
                    target: InspectorTarget.selection,
                    rack: doc.racks[_rackId]!,
                    doc: doc,
                    presets: const {},
                    selectedIds: const {},
                    focusedId: null,
                    onSetProperty: <T>(field, value) {},
                    onRename: (_) {},
                    onRequestHeight: (_) {},
                    onApplyPreset: (_) {},
                    onRefuse: (_) {},
                    onSetLifecycle: (_) {},
                    onSetWidth: (_) {},
                    onSetOverride: <T>(field, value) {},
                    onSetPortFact: (a, b, c, d, e) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hint = tester.getRect(
        find.textContaining('Rack settings: Ctrl+Alt+U'),
      );
      expect(
        hint.bottom,
        greaterThan(1200),
        reason:
            'the hint floated up to meet the header instead of being '
            'pushed to the foot of the column',
      );
    });
  });
}
