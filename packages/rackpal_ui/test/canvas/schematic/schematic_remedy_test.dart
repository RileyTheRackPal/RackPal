// M5-D `#278` — `[ Insert HDBaseT receiver ]`, pressed on a real chip.
//
// ITS OWN FIXTURE, AND ITS OWN FILE. `schematic_test_document.dart` holds
// no HDBaseT source at all: `MTX-1` is V03, an HDMI matrix whose jacks are
// `conn.hdmi_a`. So `SIG-001` cannot fire on that sheet, and adding a
// switcher to it would move counts under a dozen tests that are about
// other things entirely.
//
// WHAT THIS FILE PROVES THAT THE OTHER TWO CANNOT. `insert_receiver_test`
// drives the remedy through a transaction and asserts the document; the
// chip's own suite asserts the button exists and is reachable by keyboard.
// Neither can tell whether the SCREEN connects the two — and a screen that
// passed no `onRemedy` would leave both of them green while the button
// silently vanished from the only chip that has one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  final at = DateTime.utc(2026, 9, 3, 12);
  late RackDocument doc;
  late DocumentController controller;

  /// A switcher with an `HDBT OUT` and a PoE switch, which is the pair
  /// `SIG-001` is the flagship rule about.
  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0cc-0000-7000-8000-000000000000'),
      appVersion: '0.5.28',
      createdAt: at,
      modifiedAt: at,
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      info: ProjectInfo(projectName: 'REMEDY SHEET'),
      registries: buildSeedRegistries(),
    );
    const rackId = Uuid('0190e0cc-0000-7000-8000-000000000fff');
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
    );
    final catalog = buildSeedCatalog();
    for (final id in ['V05', 'N01']) {
      d.templates[templateKey(id, 1)] = TemplateSnapshot(
        templateId: TemplateId(id),
        version: 1,
        contentHash: 'sha256:seed-$id',
        body: catalog[id]!,
        capturedAt: at,
      );
      final placed = buildPlaceFromCatalogCommand(
        doc: d,
        catalogId: id,
        targetRack: d.racks[rackId]!,
        now: at,
        actor: 'test',
      );
      (placed as CatalogPlacementReady).command.apply(d);
    }
    return d;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
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

  /// The placed device for catalog id [id].
  ///
  /// BY TEMPLATE ID, NOT BY DESIGNATOR PREFIX. The first draft picked
  /// them with `startsWith('SW')` and `startsWith('SW-')`, which both
  /// matched the SWITCH: N01's `typePrefix` is `SW` and V05's is not. The
  /// premise test then reported that the sheet held no HDBaseT source,
  /// which was true of the device it had picked and false of the sheet.
  DeviceInstance deviceOf(String id) => doc.devices.values.firstWhere(
    (d) => d.templateRef.templateId.v == id,
  );

  /// The screen point of [device]'s port matching [where].
  Offset pointAt(
    WidgetTester tester,
    DeviceInstance device,
    bool Function(PortDef) where,
  ) {
    final scene = buildFixtureScene(doc);
    final symbol = scene.symbols.firstWhere((s) => s.id == device.id.v);
    final body = bodyFor(device, doc.templates)!;
    final def = body.ports.firstWhere(where);
    final port = symbol.allPorts.firstWhere((p) => p.key == def.key.v);
    final centre = symbolPortCentre(symbol, port);
    final m = tester
        .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
        .debugSceneToScreen!
        .storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * centre.x + m[4] * centre.y + m[12],
          m[1] * centre.x + m[5] * centre.y + m[13],
        );
  }

  Future<void> dragHdbaseTOntoSwitch(WidgetTester tester) async {
    final from = pointAt(
      tester,
      deviceOf('V05'),
      (p) =>
          p.signalFamily.v == 'video.hdbaset' &&
          p.direction == PortDirection.source,
    );
    final to = pointAt(
      tester,
      deviceOf('N01'),
      (p) => p.signalFamily.v == 'net.ethernet',
    );
    final drag = await tester.startGesture(from);
    await tester.pump();
    await drag.moveTo(to);
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
  }

  group('the premise: this sheet can actually fire SIG-001', () {
    testWidgets('it holds an HDBaseT source and a terminating ethernet port', (
      tester,
    ) async {
      await pump(tester);
      final devices = doc.devices.values.map((d) => d.designator).toList();
      expect(devices, hasLength(2));
      // Named through the catalog rather than assumed: if V05 ever loses
      // its `HDBT OUT`, this file should say so rather than quietly
      // testing a different rule.
      final body = bodyFor(deviceOf('V05'), doc.templates)!;
      expect(
        body.ports.where(
          (p) =>
              p.signalFamily.v == 'video.hdbaset' &&
              p.direction == PortDirection.source,
        ),
        isNotEmpty,
      );
    });
  });

  group('the remedy, pressed', () {
    testWidgets('a SIG-001 chip carries the remedy button', (tester) async {
      // The half neither other suite can see: the screen passing
      // `onRemedy` at all. Without it the chip renders no remedy button
      // and every existing test stays green.
      await pump(tester);
      await dragHdbaseTOntoSwitch(tester);

      expect(find.byType(SpringBackChipCard), findsOneWidget);
      expect(statusOfRemedy(tester), startsWith('SIG-001 '));
      expect(
        find.text(SpringBackRemedy.insertHdbasetReceiver.label),
        findsOneWidget,
        reason:
            'SIG-001 is the one rule with an inserting remedy, and the '
            'chip that fires it must offer it',
      );
    });

    testWidgets('pressing it mints a receiver and lands the run on it', (
      tester,
    ) async {
      await pump(tester);
      final before = doc.devices.length;
      await dragHdbaseTOntoSwitch(tester);
      expect(doc.links, isEmpty, reason: 'the spring-back wrote nothing');

      await tester.tap(
        find.text(SpringBackRemedy.insertHdbasetReceiver.label),
      );
      await tester.pumpAndSettle();

      expect(doc.devices, hasLength(before + 1));
      expect(doc.links, hasLength(1));
      final rx = doc.devices.values.firstWhere(
        (d) => d.templateRef.templateId.v == 'V06:receiver',
      );
      expect(rx.designator, startsWith('RX'));
      expect(find.byType(SpringBackChipCard), findsNothing);
    });

    testWidgets('and the sentence tells the user what is left to do', (
      tester,
    ) async {
      // DR-115 leaves the HDMI end open on purpose, so the one thing the
      // user must be told is that it is open and that landing it is
      // theirs to do. A remedy that silently left a loose end would look
      // like a half-finished insert.
      await pump(tester);
      await dragHdbaseTOntoSwitch(tester);
      await tester.tap(
        find.text(SpringBackRemedy.insertHdbasetReceiver.label),
      );
      await tester.pumpAndSettle();

      final said = statusOfRemedy(tester);
      expect(said, contains('RX'));
      expect(said, contains('open'));
    });

    testWidgets('ONE undo takes back the device AND the cable', (
      tester,
    ) async {
      // The Edit menu's own promise. `LabelKey.insertRemedyDevice` exists
      // so this does not read as "Undo connect" for a gesture that also
      // placed a device.
      await pump(tester);
      final before = doc.devices.length;
      await dragHdbaseTOntoSwitch(tester);
      await tester.tap(
        find.text(SpringBackRemedy.insertHdbasetReceiver.label),
      );
      await tester.pumpAndSettle();

      controller.undoLast();
      await tester.pumpAndSettle();
      expect(doc.devices, hasLength(before));
      expect(doc.links, isEmpty);
    });
  });
}

/// The transient status line, filtered the way the other suites filter it.
String statusOfRemedy(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data == null) continue;
    if (data.contains('Inserted ') ||
        kSpringBackRuleIds.any((id) => data.startsWith('$id '))) {
      return data;
    }
  }
  return '';
}
