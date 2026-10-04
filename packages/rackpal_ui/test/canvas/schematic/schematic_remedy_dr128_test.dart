// DR-128 §11.127 — `[ Declare an adapter ]` and `[ Insert a converter ]`,
// pressed on real chips.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS FILE PROVES THAT THE CORE SUITES CANNOT
// ═════════════════════════════════════════════════════════════════════
// `declare_adapter_test.dart` and `insert_converter_test.dart` drive the
// commands and assert the document. Neither can tell whether the SCREEN
// reaches them, and the screen is where this nearly went wrong twice:
//
//   * `SpringBackRemedy` gained two members while both chips still
//     carried `remedies: const []`, so the ruling described buttons that
//     did not exist. A core test would never have noticed.
//   * `_applyRemedy`'s switch then failed to compile, which is the only
//     reason the UI half got written at all.
//
// So these press the button on a chip raised by a real drag.
//
// ═════════════════════════════════════════════════════════════════════
// THE PAIRS ARE CENSUSED, NOT CHOSEN
// ═════════════════════════════════════════════════════════════════════
// A throwaway probe swept every seeded source against every seeded sink
// and reported which pairs actually raise each chip. Picking two by eye
// is how a fixture ends up exercising a different rule than its name
// says, which `schematic_remedy_test.dart`'s own header records happening
// to its first draft.
//
//   CON-001  V05.audio.out (audio.line_bal / euroblock_5)
//              -> A03.in.1 (audio.line_bal / euroblock_3)
//   SIG-002  V01.hdbt.out.1 (video.hdbaset / rj45)
//              -> V02.hdmi.in.1 (video.hdmi.2_0 / hdmi_a)
//
// Same family and different connector for the first; different family for
// the second. That is the split CR-015 makes, arriving from the catalogue
// rather than from an argument.
//
// THE CON-001 PAIR MOVED AT DR-173 (#112), AND THE RE-RUN CENSUS CHOSE IT.
// It was V01.aud.out.1 -> A04.bal.l until V01's zone audio became an
// atomic L/R pair. A drag from a set member takes the SET gesture, which
// did not consult tier 2 until DR-234 (#909), so no chip could be raised
// through it then; `schematic_set_tier2_test.dart` now drives that pair
// through the set's own chip. This file keeps the pin gesture's case.
// Swept again over ports in no atomic set, same family and different
// connector, the audio domain has exactly one shape left: V05's 5-pin
// stereo output into a 3-pin input, on A03 or A05.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

/// The transient status line, filtered the way the sibling suite filters
/// it. Duplicated rather than shared: `schematic_remedy_test.dart` is a
/// test file, and importing one test from another to reach a private
/// helper couples two fixtures that are about different rules.
String _statusLine(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data == null) continue;
    if (kSpringBackRuleIds.any((id) => data.startsWith('$id '))) return data;
  }
  return '';
}

void main() {
  final at = DateTime.utc(2026, 9, 6, 12);
  late RackDocument doc;
  late DocumentController controller;

  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0cc-0001-7000-8000-000000000000'),
      appVersion: '0.5.28',
      createdAt: at,
      modifiedAt: at,
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      info: ProjectInfo(projectName: 'DR-128 SHEET'),
      registries: buildSeedRegistries(),
    );
    const rackId = Uuid('0190e0cc-0001-7000-8000-000000000fff');
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 24,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
    );
    final catalog = buildSeedCatalog();
    for (final id in ['V01', 'V02', 'V05', 'A03']) {
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

  /// BY TEMPLATE ID, on `schematic_remedy_test.dart`'s recorded lesson:
  /// its first draft picked devices by designator prefix and matched the
  /// wrong one, then reported a true fact about the wrong device.
  DeviceInstance deviceOf(String id) =>
      doc.devices.values.firstWhere((d) => d.templateRef.templateId.v == id);

  Offset pointAt(WidgetTester tester, DeviceInstance device, String portKey) {
    final scene = buildFixtureScene(doc);
    final symbol = scene.symbols.firstWhere((s) => s.id == device.id.v);
    final port = symbol.allPorts.firstWhere((p) => p.key == portKey);
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

  Future<void> drag(
    WidgetTester tester,
    (String, String) from,
    (String, String) to,
  ) async {
    final a = pointAt(tester, deviceOf(from.$1), from.$2);
    final b = pointAt(tester, deviceOf(to.$1), to.$2);
    final gesture = await tester.startGesture(a);
    await tester.pump();
    await gesture.moveTo(b);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  const conPair = (('V05', 'audio.out'), ('A03', 'in.1'));
  const sigPair = (('V01', 'hdbt.out.1'), ('V02', 'hdmi.in.1'));

  group('CON-001 offers to declare the adapter, and does', () {
    testWidgets('the chip is CON-001 and carries the button', (tester) async {
      await pump(tester);
      await drag(tester, conPair.$1, conPair.$2);

      expect(find.byType(SpringBackChipCard), findsOneWidget);
      expect(_statusLine(tester), startsWith('CON-001 '));
      expect(
        find.text(SpringBackRemedy.declareAdapter.label),
        findsOneWidget,
        reason:
            'the enum gained this member while the chip still carried an '
            'empty remedy list, which is what this asserts against',
      );
      expect(doc.links, isEmpty, reason: 'the spring-back wrote nothing');
    });

    testWidgets('pressing it makes the cable AND declares the adapter, and '
        'the rule then clears', (tester) async {
      await pump(tester);
      await drag(tester, conPair.$1, conPair.$2);
      await tester.tap(find.text(SpringBackRemedy.declareAdapter.label));
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(1), reason: 'the cable the adapter sits in');
      final link = doc.links.values.single;
      expect(link.inlineAdapters, hasLength(1));
      final adapter = link.inlineAdapters.single;
      expect(adapter.fromConnector.v, 'conn.euroblock_5');
      expect(adapter.toConnector.v, 'conn.euroblock_3');
      expect(adapter.satisfiesRuleIds, ['CON-001']);
      expect(
        adapter.model,
        isNull,
        reason: 'nobody has said which part, and G4 does not invent one',
      );

      // THE ARTIFACT: the rule that raised the chip is now quiet on the
      // cable it produced.
      final from = resolveConnectTarget(
        doc,
        deviceId: deviceOf('V05').id,
        portKey: 'audio.out',
      )!;
      final to = resolveConnectTarget(
        doc,
        deviceId: deviceOf('A03').id,
        portKey: 'in.1',
      )!;
      expect(
        evaluateSpringBack(doc, from, to, ontoLink: link.id),
        isA<SpringBackClear>(),
      );
    });

    testWidgets('and it is ONE undo entry, cable and adapter together', (
      tester,
    ) async {
      await pump(tester);
      await drag(tester, conPair.$1, conPair.$2);
      await tester.tap(find.text(SpringBackRemedy.declareAdapter.label));
      await tester.pumpAndSettle();

      controller.undoLast();
      expect(doc.links, isEmpty);
    });
  });

  group('SIG-002 offers to insert a converter, and does', () {
    testWidgets('the chip is SIG-002 and carries the button', (tester) async {
      await pump(tester);
      await drag(tester, sigPair.$1, sigPair.$2);

      expect(find.byType(SpringBackChipCard), findsOneWidget);
      expect(_statusLine(tester), startsWith('SIG-002 '));
      expect(
        find.text(SpringBackRemedy.insertConverter.label),
        findsOneWidget,
      );
    });

    testWidgets('pressing it mints a converter and runs a cable to each '
        'side', (tester) async {
      await pump(tester);
      final before = doc.devices.length;
      await drag(tester, sigPair.$1, sigPair.$2);
      await tester.tap(find.text(SpringBackRemedy.insertConverter.label));
      await tester.pumpAndSettle();

      expect(doc.devices, hasLength(before + 1));
      expect(doc.links, hasLength(2), reason: 'one cable on each side');
      final conv = doc.devices.values.firstWhere(
        (d) => d.templateRef.templateId.v.startsWith('conv.'),
      );
      expect(conv.placement, isA<OffRackPlacement>());

      // THE ARTIFACT, both sides. A converter whose ports were the wrong
      // way round would still be a third device with two cables.
      final inPin = resolveConnectTarget(
        doc,
        deviceId: conv.id,
        portKey: kConverterInKey,
      )!;
      final outPin = resolveConnectTarget(
        doc,
        deviceId: conv.id,
        portKey: kConverterOutKey,
      )!;
      final src = resolveConnectTarget(
        doc,
        deviceId: deviceOf('V01').id,
        portKey: 'hdbt.out.1',
      )!;
      final snk = resolveConnectTarget(
        doc,
        deviceId: deviceOf('V02').id,
        portKey: 'hdmi.in.1',
      )!;
      expect(evaluateSpringBack(doc, src, inPin), isA<SpringBackClear>());
      expect(evaluateSpringBack(doc, outPin, snk), isA<SpringBackClear>());
    });

    testWidgets('and one undo takes back the converter and both cables', (
      tester,
    ) async {
      await pump(tester);
      final before = doc.devices.length;
      await drag(tester, sigPair.$1, sigPair.$2);
      await tester.tap(find.text(SpringBackRemedy.insertConverter.label));
      await tester.pumpAndSettle();

      controller.undoLast();
      expect(doc.devices, hasLength(before));
      expect(doc.links, isEmpty);
    });
  });
}
