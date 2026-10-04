// The schematic's cable bar (`#973`, DR-231 §11.230.1): select a cable,
// set its crossover, take it back, through the real screen and the real
// controller.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 10, 4, 9)),
    );
    reference = buildFixtureScene(doc);
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

  Offset toScreen(WidgetTester tester, DPt p) {
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

  Uuid linkNamed(String designator) =>
      doc.links.entries.firstWhere((e) => e.value.designator == designator).key;

  DPt pennantOf(Uuid linkId) {
    final label = reference.netLabels.firstWhere((l) => l.linkId == linkId);
    return DPt(
      (label.pennant.left + label.pennant.right) / 2,
      (label.pennant.top + label.pennant.bottom) / 2,
    );
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(kCableBarCrossoverKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('NO CABLE SELECTED, NO BAR', (tester) async {
    await pump(tester);
    expect(find.byType(SchematicCableBar), findsNothing);
  });

  testWidgets('selecting a cable shows the bar naming it, unset', (
    tester,
  ) async {
    await pump(tester);
    final id = linkNamed('W001');
    await tester.tapAt(toScreen(tester, pennantOf(id)));
    await tester.pumpAndSettle();
    expect(find.byType(SchematicCableBar), findsOneWidget);
    expect(
      tester.widget<SchematicCableBar>(find.byType(SchematicCableBar)).saying,
      startsWith('W001'),
    );
    expect(
      find.descendant(
        of: find.byKey(kCableBarCrossoverKey),
        matching: find.text(kCrossoverNotSet),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking Null-modem marks the cable, as one undo step, and '
      'Not set takes it back', (tester) async {
    await pump(tester);
    final id = linkNamed('W001');
    await tester.tapAt(toScreen(tester, pennantOf(id)));
    await tester.pumpAndSettle();

    await pick(tester, crossoverLabel(CrossoverKind.nullModem));
    expect(doc.links[id]!.crossover, CrossoverKind.nullModem);

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(doc.links[id]!.crossover, isNull);

    await pick(tester, crossoverLabel(CrossoverKind.polarityReversed));
    expect(doc.links[id]!.crossover, CrossoverKind.polarityReversed);
    await pick(tester, kCrossoverNotSet);
    expect(doc.links[id]!.crossover, isNull);
  });

  testWidgets('EVERY VALUE ON EVERY CABLE (§11.230.2): Not set and all four', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kCableBarCrossoverKey));
    await tester.pumpAndSettle();
    for (final label in [
      kCrossoverNotSet,
      for (final k in CrossoverKind.values) crossoverLabel(k),
    ]) {
      expect(
        find.widgetWithText(DropdownMenuItem<CrossoverKind?>, label),
        findsWidgets,
        reason: label,
      );
    }
  });
}
