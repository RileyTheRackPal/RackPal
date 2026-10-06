// DR-236 §11.235.2 (BRK-A/3, `#1006`): the cable bar's "Add a set to this
// cable", driven through the real screen.
//
// THE CABLE IS THE ONE THE RULING WAS ASKED FOR: a 16/4 from an amplifier,
// tapped at one in-wall speaker and continued to the next. The real
// catalogue's A04 and two F05s, W001 already run from the A04's left pair to
// the first speaker, and the gesture continuing it to the second.
//
// THE DROP SPRINGS BACK, and that is the catalogue, not this feature: the
// A04's binding posts declare they mate with banana plugs only and the F05
// takes screw terminals, so `CON-001` fires on every amplifier-to-in-wall
// run. The test asserts the chip and goes through `[ Connect anyway ]`,
// which DR-234 §11.233.3 makes the same append.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  final at = DateTime.utc(2026, 10, 6, 12);
  late RackDocument doc;
  late DocumentController controller;
  const amp = Uuid('0190e0cc-1006-7000-8000-00000000a004');
  const spk1 = Uuid('0190e0cc-1006-7000-8000-0000000f0051');
  const spk2 = Uuid('0190e0cc-1006-7000-8000-0000000f0052');
  const w001 = Uuid('0190e0cc-1006-7000-8000-000000000001');

  void add(RackDocument d, Uuid id, String tpl, String designator) {
    d.templates[templateKey(tpl, 1)] = TemplateSnapshot(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:seed-$tpl',
      body: buildSeedCatalog()[tpl]!,
      capturedAt: at,
    );
    d.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(tpl),
        version: 1,
        contentHash: 'sha256:seed-$tpl',
      ),
      designator: designator,
      name: designator,
      placement: const OffRackPlacement(),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
    );
  }

  Uuid port(RackDocument d, Uuid device, String key) {
    final id = derivePortId(device, PortKey(key));
    d.ports.putIfAbsent(
      id,
      () => Port(
        id: id,
        deviceId: device,
        designator: key.toUpperCase(),
        templatePortKey: PortKey(key),
      ),
    );
    return id;
  }

  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0cc-1006-7000-8000-000000000000'),
      appVersion: '0.6.60',
      createdAt: at,
      modifiedAt: at,
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      info: ProjectInfo(projectName: 'BRK-A SHEET'),
      registries: buildSeedRegistries(),
    );
    add(d, amp, 'A04', 'AMP-1');
    add(d, spk1, 'F05', 'SPK-1');
    add(d, spk2, 'F05', 'SPK-2');
    d.links[w001] = Link(
      id: w001,
      designator: 'W001',
      media: kUnstatedMedia,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      services: [
        Service(
          id: 'svc-1',
          signalFamily: const SignalFamilyId('audio.speaker_lowz'),
          netId: const Uuid('0190e0cc-1006-7000-8000-0000000000e1'),
        ),
      ],
      conductors: [
        Conductor(
          from: PortEndpoint(port(d, amp, 'spk.L.pos')),
          to: PortEndpoint(port(d, spk1, 'spk.pos')),
          role: '+',
        ),
        Conductor(
          from: PortEndpoint(port(d, amp, 'spk.L.neg')),
          to: PortEndpoint(port(d, spk1, 'spk.neg')),
          role: '-',
        ),
      ],
    );
    return d;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1800, 1200)
      ..devicePixelRatio = 1;
    doc = build();
    controller = DocumentController(doc, clock: FixedClock(at));
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasScreen(
            measurer: const FakeMeasurer(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset screenOf(WidgetTester tester, DPt p) {
    final m = tester
        .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
        .debugSceneToScreen!
        .storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * p.x + m[4] * p.y + m[12],
          m[1] * p.x + m[5] * p.y + m[13],
        );
  }

  Offset pinAt(WidgetTester tester, Uuid device, String key) {
    final symbol = buildFixtureScene(
      doc,
    ).symbols.firstWhere((s) => s.id == device.v);
    final pin = symbol.allPorts.firstWhere((p) => p.key == key);
    return screenOf(tester, symbolPortCentre(symbol, pin));
  }

  String status(WidgetTester tester) =>
      [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          t.data ?? '',
      ].firstWhere(
        (d) =>
            d.contains('Adding to') ||
            d.contains('Continuing') ||
            d.contains('now reaches') ||
            d.contains('does not reach') ||
            d.contains('Stopped adding'),
        orElse: () => '',
      );

  Future<void> selectW001(WidgetTester tester) async {
    final label = buildFixtureScene(
      doc,
    ).netLabels.firstWhere((l) => l.linkId == w001);
    await tester.tapAt(
      screenOf(
        tester,
        DPt(
          (label.pennant.left + label.pennant.right) / 2,
          (label.pennant.top + label.pennant.bottom) / 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kCableBarAddSetKey), findsOneWidget);
  }

  Future<void> drag(WidgetTester tester, Offset a, Offset b) async {
    final g = await tester.startGesture(a);
    await tester.pump();
    await g.moveTo(b);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('THE EXIT CRITERION: Add a set, drag the right pair to SPK-2, '
      'and W001 is one cable reaching both speakers', (tester) async {
    await pump(tester);
    await selectW001(tester);
    await tester.tap(find.byKey(kCableBarAddSetKey));
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('Adding to W001'));

    await drag(
      tester,
      pinAt(tester, amp, 'spk.R.pos'),
      pinAt(tester, spk2, 'spk.pos'),
    );
    // The catalogue's CON-001 (see the file header), and nothing written.
    expect(find.byType(SpringBackChipCard), findsOneWidget);
    expect(doc.links[w001]!.conductors, hasLength(2));
    await tester.tap(find.text(kSpringBackConnectAnyway));
    await tester.pumpAndSettle();

    expect(doc.links, hasLength(1), reason: 'no second cable');
    final w = doc.links[w001]!;
    expect(w.conductors, hasLength(4));
    expect(
      w.conductors.any(
        (c) =>
            c.to is PortEndpoint &&
            doc.ports[(c.to as PortEndpoint).portId]?.deviceId == spk2,
      ),
      isTrue,
    );
    expect(status(tester), contains('W001 now reaches SPK-2 too'));

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(doc.links[w001]!.conductors, hasLength(2), reason: 'one undo step');
  });

  testWidgets('a set on a device the cable does NOT reach is answered in '
      'words, and the mode stays', (tester) async {
    await pump(tester);
    await selectW001(tester);
    await tester.tap(find.byKey(kCableBarAddSetKey));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(pinAt(tester, spk2, 'spk.pos'));
    await tester.pump();
    expect(status(tester), contains('W001 does not reach SPK-2'));
    await g.up();
    await tester.pumpAndSettle();
    expect(doc.links[w001]!.conductors, hasLength(2));
  });

  testWidgets('Esc stops adding, and the next press is an ordinary set again', (
    tester,
  ) async {
    await pump(tester);
    await selectW001(tester);
    await tester.tap(find.byKey(kCableBarAddSetKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(status(tester), startsWith('Stopped adding to W001'));
  });
}
