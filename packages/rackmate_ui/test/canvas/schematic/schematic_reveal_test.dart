// M2-F PHASE 5 — the far end of CR-105's signpost: "clicking it switches
// to the schematic WITH THAT DEVICE SELECTED."
//
// ═══════════════════════════════════════════════════════════════════════
// THE CASE THAT DECIDED THE DESIGN, AND IT IS THE FIRST GROUP BELOW
// ═══════════════════════════════════════════════════════════════════════
// The chip is clicked on the RACK tab. The schematic is a sibling in a
// `TabBarView`, which builds its pages lazily — so at the instant the
// click happens this screen may not exist. A callback, or a notification
// with no listener, would be delivered to nobody on exactly the journey
// the affordance exists to serve, and the bug would look like "the chip
// sometimes does not work".
//
// So `SchematicRevealController` parks a REQUEST rather than firing an
// event, and this screen drains it on its first frame as well as on
// notification. `arriving after the request was made` is that case, and it
// is the one a naive implementation fails.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicRevealController reveal;
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
      clock: FixedClock(DateTime.utc(2026, 8, 2, 9)),
    );
    reveal = SchematicRevealController();
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    reveal.dispose();
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
            reveal: reveal,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The status line's current sentence, or null.
  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('selected') ||
          data.contains('no longer') ||
          data.contains('carries no ports')) {
        return data;
      }
    }
    return null;
  }

  /// How many wires the sheet is drawing right now.
  ///
  /// SELECTION IS OBSERVED THROUGH `F`, which is this suite's established
  /// technique (`schematic_canvas_screen_test.dart`) and not a workaround:
  /// selection ALONE draws nothing on this sheet — §11.1.1's third row is
  /// FOCUS, not selection — so the only honest way to ask "is it selected"
  /// from outside the widget is to press the key that acts on the
  /// selection and count what lights up.
  int drawnWires(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpPolyline>()
      .length;

  /// The links [designator] terminates, per the reference scene.
  int linksOf(String designator) {
    final id = deviceNamed(doc, designator).id.v;
    return <Uuid>{
      for (final label in reference.netLabels)
        if (label.deviceId == id) label.linkId,
    }.length;
  }

  /// Presses `F` and reports how many wires lit up, then presses `Esc` to
  /// leave the sheet as it was found.
  Future<int> focusCount(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    final n = drawnWires(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    return n;
  }

  group('1 — a request survives a screen that is not there yet', () {
    testWidgets('arriving AFTER the request was made still reveals', (
      tester,
    ) async {
      // The `TabBarView` case, reproduced without a tab view: the request
      // is parked before this screen is ever built.
      reveal.reveal(deviceNamed(doc, 'AMP-1').id);
      await pump(tester);

      expect(await focusCount(tester), linksOf('AMP-1'));
      expect(statusOf(tester), contains('AMP-1'));
    });

    testWidgets('a request made while mounted is picked up too', (
      tester,
    ) async {
      await pump(tester);
      expect(
        await focusCount(tester),
        0,
        reason: '`F` with nothing selected focuses nothing',
      );

      reveal.reveal(deviceNamed(doc, 'AMP-1').id);
      await tester.pumpAndSettle();

      expect(await focusCount(tester), linksOf('AMP-1'));
    });

    testWidgets('the SAME device twice reveals twice', (tester) async {
      // The reason this is a controller and not a `Uuid? revealDevice`
      // widget field: re-clicking a chip does not change the value, so a
      // `didUpdateWidget` implementation would do nothing the second time
      // — and re-clicking is exactly what a user does when a navigation
      // affordance appears not to have worked.
      await pump(tester);
      final amp = deviceNamed(doc, 'AMP-1').id;
      final mtx = deviceNamed(doc, 'MTX-1').id;

      reveal.reveal(amp);
      await tester.pumpAndSettle();
      reveal.reveal(mtx);
      await tester.pumpAndSettle();
      expect(await focusCount(tester), linksOf('MTX-1'));

      reveal.reveal(mtx);
      await tester.pumpAndSettle();
      expect(await focusCount(tester), linksOf('MTX-1'));
    });

    testWidgets('one request reveals ONCE — it is taken, not left standing', (
      tester,
    ) async {
      await pump(tester);
      final amp = deviceNamed(doc, 'AMP-1').id;
      reveal.reveal(amp);
      await tester.pumpAndSettle();
      expect(reveal.pending, isNull);

      // Selecting something else and rebuilding must not resurrect it. A
      // request that outlived its own consumption would re-select the
      // device every time the user came back to this tab.
      reveal.reveal(deviceNamed(doc, 'MTX-1').id);
      await tester.pumpAndSettle();
      await tester.pump();
      expect(await focusCount(tester), linksOf('MTX-1'));
      expect(
        linksOf('MTX-1'),
        isNot(linksOf('AMP-1')),
        reason: 'the two counts must differ or this asserts nothing',
      );
    });
  });

  group('2 — it puts the device on screen', () {
    testWidgets('the viewport moves to the revealed symbol', (tester) async {
      await pump(tester);
      final before = tester
          .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
          .debugSceneToScreen!
          .clone();

      reveal.reveal(deviceNamed(doc, 'DIS-1').id);
      await tester.pumpAndSettle();

      final after = tester
          .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
          .debugSceneToScreen!;
      expect(
        after,
        isNot(before),
        reason:
            'a reveal that selected without scrolling would leave the '
            'user staring at the same corner of the sheet',
      );
    });

    testWidgets('and it never says nothing', (tester) async {
      // docs/04 §3.4's "never silently stops", applied to arrival: the
      // user has just changed tabs and needs to know why.
      await pump(tester);
      reveal.reveal(deviceNamed(doc, 'MTX-1').id);
      await tester.pumpAndSettle();
      expect(statusOf(tester), isNotNull);
      expect(statusOf(tester), contains('MTX-1'));
    });
  });

  group('3 — the answers that are not a symbol', () {
    testWidgets('a device with no ports is named, not silently skipped', (
      tester,
    ) async {
      // Unreachable from the elevation — a port-less device carries no
      // chip — and handled anyway, because "the click did nothing" is the
      // one outcome a navigation affordance may never produce.
      await pump(tester);
      reveal.reveal(deviceNamed(doc, kFixturePortlessDesignator).id);
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('carries no ports'));
    });

    testWidgets('a device deleted between click and arrival says so', (
      tester,
    ) async {
      await pump(tester);
      reveal.reveal(const Uuid('not-in-this-document'));
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('no longer in this document'));
    });
  });

  group('4 — SchematicRevealController', () {
    test('take empties it; a second take gets null', () {
      final c = SchematicRevealController();
      expect(c.pending, isNull);
      c.reveal(const Uuid('a'));
      expect(c.pending, const Uuid('a'));
      expect(c.take(), const Uuid('a'));
      expect(c.take(), isNull);
      c.dispose();
    });

    test('an unclaimed request is REPLACED, not queued', () {
      // Two clicks before the sheet builds mean the user wants the second
      // device, not a tour of both.
      final c = SchematicRevealController()
        ..reveal(const Uuid('a'))
        ..reveal(const Uuid('b'));
      expect(c.take(), const Uuid('b'));
      expect(c.take(), isNull);
      c.dispose();
    });
  });
}
