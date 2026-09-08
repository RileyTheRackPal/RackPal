// PLAN-E/6: CR-102's band on the third canvas (DR-139 §11.138).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS FILE CAN ASSERT, AND WHAT IT DELIBERATELY DOES NOT
// ═══════════════════════════════════════════════════════════════════════
// The band's ARRIVAL is observable here and is asserted: it appears on a
// drag across bare sheet, it does not appear for a click, and it is gone
// after the release.
//
// **THE SELECTION IT PRODUCES IS NOT OBSERVABLE ON THIS SCREEN**, and
// that is a property of the screen rather than of the marquee.
// `SchematicCanvasScreen` builds its own private `SelectionController`,
// and on this fixture selecting a device changes nothing a widget test can
// read: the drawn-scope headline never renders in this harness, and the
// painted op count is IDENTICAL before and after a plain tap on a symbol
// (831 either way, measured). So an assertion on the selection here would
// have to pass through a mechanism that does not report, which is the
// class of test this repository has already been bitten by.
//
// The selection rule is covered where it CAN be read: `marquee_test.dart`
// in core pins the geometry, including the `partKey` filter this canvas is
// the reason for, and `marquee_adoption_test.dart` asserts the id count
// end to end on the rack elevation, where selection is visible on the
// render objects. Making it readable here means letting the screen take an
// external `SelectionController` the way the plan canvas does, which is a
// change to that screen's API and is not this chapter's.
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
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 9)),
    );
    reference = buildFixtureScene(doc);
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
    // The viewport frames the sheet in a post-frame callback.
    await tester.pumpAndSettle();
  }

  /// A scene point in global (screen) coordinates.
  Offset toScreen(WidgetTester tester, DPt p) {
    final ro = tester.renderObject<RenderSchematicCanvas>(
      find.byType(SchematicCanvasBody),
    );
    final m = ro.debugSceneToScreen!.storage;
    final local = Offset(
      m[0] * p.x + m[4] * p.y + m[12],
      m[1] * p.x + m[5] * p.y + m[13],
    );
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) + local;
  }

  DBox bodyOf(String designator) => reference.symbols
      .firstWhere((s) => s.id == deviceNamed(doc, designator).id.v)
      .bodyRect;

  group('the schematic adopts the band (DR-139)', () {
    testWidgets('A DRAG ON THE BARE SHEET RAISES A BAND', (tester) async {
      // Before this chapter that drag reached `if (travelled > slopPx)
      // return;` and did nothing at all.
      await pump(tester);
      final b = bodyOf('MTX-1');

      final g = await tester.startGesture(
        toScreen(tester, DPt(b.left - 400, b.top - 400)),
      );
      await g.moveTo(toScreen(tester, DPt(b.left - 100, b.top - 100)));
      await tester.pump();

      expect(find.byKey(MarqueeBand.bandKey), findsOneWidget);

      await g.up();
      await tester.pumpAndSettle();
      expect(
        find.byKey(MarqueeBand.bandKey),
        findsNothing,
        reason: 'the band dies with the gesture that raised it',
      );
    });

    testWidgets('A CLICK RAISES NO BAND, so a tap is still a tap', (
      tester,
    ) async {
      // The regression this adoption could most easily have caused: the
      // schematic decides click-versus-drag by travel against the slop and
      // the band now shares that branch. `MarqueeController.begin` gives
      // the band no extent until the first update, so a press that never
      // moves paints nothing.
      await pump(tester);
      final b = bodyOf('MTX-1');

      final g = await tester.startGesture(
        toScreen(tester, DPt(b.left - 400, b.top - 400)),
      );
      await tester.pump();
      expect(find.byKey(MarqueeBand.bandKey), findsNothing);

      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(MarqueeBand.bandKey), findsNothing);
    });

    testWidgets('A DRAG FROM A PIN IS STILL A CABLE, not a band', (
      tester,
    ) async {
      // The other regression, and the sharper one. `beginDrag` asks the
      // pin question BEFORE either claim, so a press on a jack takes the
      // connect route and never arms the marquee. A band appearing here
      // would mean the band had stolen the product's wiring gesture.
      await pump(tester);
      final pin = reference.symbols
          .firstWhere((s) => s.id == deviceNamed(doc, 'MTX-1').id.v)
          .allPorts
          .first;
      final symbol = reference.symbols.firstWhere(
        (s) => s.id == deviceNamed(doc, 'MTX-1').id.v,
      );
      final centre = symbolPortCentre(symbol, pin);

      final g = await tester.startGesture(toScreen(tester, centre));
      await g.moveBy(const Offset(40, 40));
      await tester.pump();

      expect(
        find.byKey(MarqueeBand.bandKey),
        findsNothing,
        reason: 'a press on a jack is a cable, and always was',
      );

      await g.up();
      await tester.pumpAndSettle();
    });
  });
}
