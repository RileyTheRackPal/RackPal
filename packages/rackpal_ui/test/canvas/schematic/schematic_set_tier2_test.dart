// DR-234 §11.233 (`#909`): the atomic set gesture asks tier 2 per pair.
//
// THE CASE IS THE TICKET'S, ON THE REAL CATALOGUE. V01's zone 1 audio is an
// L/R pair on two 3-pin blocks (DR-173) and A04's balanced input is an L/R
// pair on XLR. Same family, different connector: `CON-001` on both pairs.
// Dropped as a set, that committed a cable with no chip, where the pin
// gesture springs each half back. Every case drags it through the screen,
// because the defect was the screen never asking, which no core suite can
// see.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

String _statusLine(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data == null) continue;
    if (kSpringBackRuleIds.any((id) => data.startsWith('$id '))) return data;
    if (data.contains('connected')) return data;
  }
  return '';
}

void main() {
  final at = DateTime.utc(2026, 10, 4, 12);
  late RackDocument doc;
  late DocumentController controller;

  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0cc-0909-7000-8000-000000000000'),
      appVersion: '0.6.60',
      createdAt: at,
      modifiedAt: at,
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      info: ProjectInfo(projectName: 'DR-234 SHEET'),
      registries: buildSeedRegistries(),
    );
    const rackId = Uuid('0190e0cc-0909-7000-8000-000000000fff');
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 24,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
    );
    final catalog = buildSeedCatalog();
    for (final id in ['V01', 'A04']) {
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

  DeviceInstance deviceOf(String id) =>
      doc.devices.values.firstWhere((d) => d.templateRef.templateId.v == id);

  Offset pointAt(WidgetTester tester, String device, String portKey) {
    final scene = buildFixtureScene(doc);
    final symbol = scene.symbols.firstWhere(
      (s) => s.id == deviceOf(device).id.v,
    );
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

  int amberRings(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpCircle>()
      .where((op) => op.stroke?.argb == kSpringBackRingArgb)
      .length;

  /// V01's `audOut` bank STARTS COLLAPSED (sixteen jacks), so the first
  /// press on it expands the bank rather than arming anything. Found by
  /// printing the screen: the first draft's drop said "Expanded audOut" and
  /// raised no chip, which read exactly like the defect under test.
  Future<void> expandZoneAudio(WidgetTester tester) async {
    await tester.tapAt(pointAt(tester, 'V01', 'aud.out.1.l'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Expanded audOut'),
      findsOneWidget,
      reason: 'the precondition: the bank opened',
    );
  }

  /// V01's zone 1 L, dropped on A04's balanced L: the set gesture.
  Future<void> dropThePair(WidgetTester tester) async {
    await expandZoneAudio(tester);
    final gesture = await tester.startGesture(
      pointAt(tester, 'V01', 'aud.out.1.l'),
    );
    await tester.pump();
    await gesture.moveTo(pointAt(tester, 'A04', 'bal.l'));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  ConnectTarget pin(String device, String key) => resolveConnectTarget(
    doc,
    deviceId: deviceOf(device).id,
    portKey: key,
  )!;

  test('THE PREMISE, through core: each half alone is CON-001', () {
    // So a failure below reads as "the screen did not ask", not as "the
    // catalogue moved".
    for (final (l, r) in [('aud.out.1.l', 'bal.l'), ('aud.out.1.r', 'bal.r')]) {
      final verdict = evaluateSpringBack(doc, pin('V01', l), pin('A04', r));
      expect(verdict, isA<SpringBackChip>());
      expect((verdict as SpringBackChip).ruleId, 'CON-001');
    }
  });

  testWidgets('dropping the pair SPRINGS BACK on CON-001, names the first '
      'pair, counts both, and writes nothing', (tester) async {
    await pump(tester);
    await dropThePair(tester);

    expect(find.byType(SpringBackChipCard), findsOneWidget);
    final said = _statusLine(tester);
    expect(said, startsWith('CON-001 '));
    expect(said, contains(pin('V01', 'aud.out.1.l').citation));
    expect(
      said,
      contains(" 2 of this cable's 2 paired conductors spring back."),
    );
    expect(find.text(SpringBackRemedy.declareAdapter.label), findsOneWidget);
    expect(doc.links, isEmpty, reason: 'this committed with no chip (#909)');
  });

  testWidgets('arming the pair AMBERS the target set (DR-116 §11.115.5)', (
    tester,
  ) async {
    await pump(tester);
    await expandZoneAudio(tester);
    final before = amberRings(tester);
    final gesture = await tester.startGesture(
      pointAt(tester, 'V01', 'aud.out.1.l'),
    );
    await tester.pump();
    final armed = amberRings(tester);
    // RELEASED BEFORE THE ASSERTION: a failure with the pointer still down
    // leaked it into the next test and failed that one too, which reported
    // two defects for one.
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      armed - before,
      greaterThanOrEqualTo(2),
      reason: "both of A04's balanced inputs stay offered, wearing amber",
    );
  });

  testWidgets('[ Connect anyway ] commits the WHOLE SET as one cable', (
    tester,
  ) async {
    await pump(tester);
    await dropThePair(tester);
    await tester.tap(find.text(kSpringBackConnectAnyway));
    await tester.pumpAndSettle();

    expect(doc.links, hasLength(1));
    expect(doc.links.values.single.conductors, hasLength(2));
    expect(doc.links.values.single.inlineAdapters, isEmpty);
  });

  testWidgets('[ Declare an adapter ] makes the set cable with ONE adapter, '
      'and CON-001 clears on both pairs', (tester) async {
    await pump(tester);
    await dropThePair(tester);
    await tester.tap(find.text(SpringBackRemedy.declareAdapter.label));
    await tester.pumpAndSettle();

    expect(doc.links, hasLength(1));
    final link = doc.links.values.single;
    expect(
      link.conductors,
      hasLength(2),
      reason: 'the pair, not a one-conductor pin cable',
    );
    expect(link.inlineAdapters, hasLength(1));
    expect(
      find.textContaining(
        'Euroblock 3-pole to XLR3 adapter declared on it. Select the cable',
      ),
      findsWidgets,
    );
    final adapter = link.inlineAdapters.single;
    expect(adapter.fromConnector.v, 'conn.euroblock_3');
    expect(adapter.toConnector.v, 'conn.xlr3');
    expect(adapter.satisfiesRuleIds, ['CON-001']);

    // THE ARTIFACT: both halves are quiet on the cable that now exists.
    for (final (l, r) in [('aud.out.1.l', 'bal.l'), ('aud.out.1.r', 'bal.r')]) {
      expect(
        evaluateSpringBack(
          doc,
          pin('V01', l),
          pin('A04', r),
          ontoLink: link.id,
        ),
        isA<SpringBackClear>(),
      );
    }

    controller.undoLast();
    expect(doc.links, isEmpty, reason: 'cable and adapter are one undo entry');
  });
}
