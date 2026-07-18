// Widget tests for the CR-086 hybrid render objects (RenderRackCanvas +
// RenderDeviceBox). They confirm the wiring — one device child per visible
// device, each carrying real Semantics, laid out at its scene size, painting
// without throwing — while the pixel geometry itself is covered by
// rackmate_core's scene_builder_test. A fake measurer keeps them off the
// bundled TTF; the anchor math only needs metrics, not a real glyph atlas.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

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

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

RackScene _demoScene(TextMeasurer measurer, Face face) {
  final rack = Rack(
    id: const Uuid('rack-1'),
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  final templates = {
    'amp@1': TemplateSnapshot(
      templateId: const TemplateId('amp'),
      version: 1,
      contentHash: 'h',
      capturedAt: DateTime.utc(2026),
      body: TemplateBody(
        manufacturer: 'D',
        model: 'amp',
        displayName: '16-channel amplifier',
        frontU: 2,
      ),
    ),
    'sw@1': TemplateSnapshot(
      templateId: const TemplateId('sw'),
      version: 1,
      contentHash: 'h',
      capturedAt: DateTime.utc(2026),
      body: TemplateBody(
        manufacturer: 'D',
        model: 'sw',
        displayName: '24-port switch',
        frontU: 1,
      ),
    ),
    'pp@1': TemplateSnapshot(
      templateId: const TemplateId('pp'),
      version: 1,
      contentHash: 'h',
      capturedAt: DateTime.utc(2026),
      body: TemplateBody(
        manufacturer: 'D',
        model: 'pp',
        displayName: 'patch panel',
        rearU: 1,
        side: OccupancySide.rear,
      ),
    ),
  };
  DeviceInstance device(
    String id,
    String des,
    String tpl,
    int ru,
    Face f,
  ) => DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'h',
    ),
    designator: des,
    name: des,
    placement: RailPlacement(rackId: rack.id, ruIndex: ru, face: f),
    meta: _meta(),
  );
  final devices = [
    device('dev-amp', 'AMP-1', 'amp', 4, Face.front),
    device('dev-sw', 'SW-1', 'sw', 7, Face.front),
    device('dev-pp', 'PP-1', 'pp', 9, Face.rear),
  ];
  return buildRackScene(
    rack: rack,
    devices: devices,
    templates: templates,
    face: face,
    lod: LodLevel.full,
    measurer: measurer,
  );
}

Widget _harness(
  RackScene rackScene,
  TextMeasurer measurer,
  ViewportController vp,
) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: RackCanvasBody(
      scene: rackScene.scene,
      viewport: vp,
      measurer: measurer,
      rackId: rackScene.rackId.v,
      children: [
        for (final d in rackScene.devices)
          RackDevicePlacement(
            key: ValueKey(d.deviceId.v),
            sceneOffset: Offset(d.rect.left, d.rect.top),
            sceneSize: Size(d.rect.width, d.rect.height),
            child: DeviceBox(
              scene: rackScene.scene,
              deviceId: d.deviceId.v,
              measurer: measurer,
              semanticLabel: d.semanticLabel,
              palette: const RackPalette(),
            ),
          ),
      ],
    ),
  );
}

void main() {
  testWidgets('one DeviceBox per visible device; renders without throwing', (
    tester,
  ) async {
    final measurer = _FakeMeasurer();
    final vp = ViewportController();
    final scene = _demoScene(measurer, Face.front);

    await tester.pumpWidget(_harness(scene, measurer, vp));

    // Front face has AMP-1 + SW-1 (PP-1 is rear-only).
    expect(scene.devices, hasLength(2));
    expect(find.byType(DeviceBox), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    // The host render object is our RenderRackCanvas.
    expect(
      tester.renderObject(find.byType(RackCanvasBody)),
      isA<RenderRackCanvas>(),
    );

    vp.dispose();
  });

  testWidgets('each device child is laid out at its scene size', (
    tester,
  ) async {
    final measurer = _FakeMeasurer();
    final vp = ViewportController();
    final scene = _demoScene(measurer, Face.front);

    await tester.pumpWidget(_harness(scene, measurer, vp));

    for (final d in scene.devices) {
      // The leaf RenderDeviceBox lives under the device's key; its size is
      // the device's scene rect size (the tight constraint the parent set).
      final box = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byKey(ValueKey(d.deviceId.v)),
          matching: find.byType(DeviceBox),
        ),
      );
      expect(box.size.width, closeTo(d.rect.width, 0.001));
      expect(box.size.height, closeTo(d.rect.height, 0.001));
    }

    vp.dispose();
  });

  testWidgets('devices expose real Semantics labels (CR-086 / docs/04 §9)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final measurer = _FakeMeasurer();
    final vp = ViewportController();
    final scene = _demoScene(measurer, Face.front);

    await tester.pumpWidget(_harness(scene, measurer, vp));

    expect(find.bySemanticsLabel(RegExp('AMP-1')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('16-channel amplifier')),
      findsOneWidget,
    );

    handle.dispose();
    vp.dispose();
  });

  testWidgets('the rear face swaps which devices render', (tester) async {
    final measurer = _FakeMeasurer();
    final vp = ViewportController();
    final rear = _demoScene(measurer, Face.rear);

    await tester.pumpWidget(_harness(rear, measurer, vp));

    // Rear face: only PP-1.
    expect(rear.devices.map((d) => d.deviceId.v), ['dev-pp']);
    expect(find.byType(DeviceBox), findsOneWidget);

    vp.dispose();
  });
}
