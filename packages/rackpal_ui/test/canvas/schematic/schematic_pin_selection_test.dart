// #93 / 93-C — "N ports selected in ONE BANK" on the real screen.
//
// `pin_selection_test.dart` proves the value type in isolation. This file
// is the half that only a mounted screen can get wrong:
//
//   * Shift on the press has to reach the selection and NOT arm a cable,
//     while the same press without Shift still does exactly what it did
//     before #93 existed;
//   * a modifier-free press has to leave an ANCHOR behind, because there
//     is no other gesture that could set one;
//   * the keyboard route has to be able to start a run from nothing, which
//     is the "worked once and then quietly stopped" shape DR-011 records
//     M1 being refuted by;
//   * `Esc` is a LADDER and the run is a new rung on it;
//   * a document that moves under a held run must drop it and SAY SO.
//
// THE FIXTURE IS THE REAL SEED CATALOG, so the banks these tests select
// along are the ones the app ships. `A01`'s `srcIn` and `zoneOut` are
// docs/05:484's own "wire the 8x8 matrix to eight zone amps" example, and
// they are 16 ports each here because they are 16 ports each in the
// product.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      clock: FixedClock(DateTime.utc(2026, 8, 2, 9)),
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

  Matrix4 matrixOf(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .debugSceneToScreen!;

  Offset toScreen(WidgetTester tester, DPt p) {
    final m = matrixOf(tester).storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * p.x + m[4] * p.y + m[12],
          m[1] * p.x + m[5] * p.y + m[13],
        );
  }

  RenderedSymbol symbolOf(String designator) {
    final device = deviceNamed(doc, designator);
    return reference.symbols.firstWhere((s) => s.id == device.id.v);
  }

  /// The pins of [designator]'s [bankKey] bank, in DR-012.2 RANK order and
  /// with the centres the sheet drew them at.
  ///
  /// Rank comes from core's `portsInBank` and the geometry from the scene,
  /// which is the same split the screen itself uses — the test must not
  /// invent a third ordering of a bank any more than the screen may.
  List<({PinRef ref, DPt centre})> bank(String designator, String bankKey) {
    final device = deviceNamed(doc, designator);
    final symbol = symbolOf(designator);
    return <({PinRef ref, DPt centre})>[
      for (final target in portsInBank(
        doc,
        deviceId: device.id,
        bankKey: bankKey,
      ))
        (
          ref: PinRef(deviceId: symbol.id, portKey: target.def.key.v),
          centre: symbolPortCentre(
            symbol,
            symbol.allPorts.firstWhere((p) => p.key == target.def.key.v),
          ),
        ),
    ];
  }

  /// Every selection/caret/candidate ring the overlay drew this frame.
  int rings(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpCircle>()
      .length;

  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('jacks selected') ||
          data.contains('No pin') ||
          data.contains('can take it') ||
          data.contains('Shift+click') ||
          data.contains('deselected') ||
          data.contains('cancelled') ||
          data.contains('Wire from') ||
          data.contains('end of') ||
          data.contains('last jack') ||
          data.contains('first jack') ||
          data.contains('the document changed')) {
        return data;
      }
    }
    return null;
  }

  Future<void> shiftTapAt(WidgetTester tester, Offset at) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  group('0 — the fixture is docs/05:484 own example', () {
    test('AMP-1 srcIn and zoneOut are sixteen each, in zone order', () {
      // The demo moment, in the shipped catalog rather than in a fixture
      // invented here. If this ever stops being true, multi-draw is being
      // tested against something the product does not have.
      final srcIn = bank('AMP-1', 'srcIn');
      expect(srcIn, hasLength(16));
      expect(srcIn.first.ref.portKey, 'src.1.l');
      expect(srcIn.last.ref.portKey, 'src.8.r');
      expect(bank('AMP-1', 'zoneOut'), hasLength(16));
    });
  });

  group('1 — a modifier-free press leaves an anchor', () {
    testWidgets('and says so, because this sentence is the only place the '
        'gesture is discoverable', (tester) async {
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[4].centre));
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('Shift+click'));
      expect(
        statusOf(tester),
        contains('Source Inputs'),
        reason:
            "the bank is named by core's bankLabelFor, so the screen "
            'and the plan cannot disagree about what it is called',
      );
    });

    testWidgets('a press on a pin STILL arms a cable — #93 changed nothing '
        'about the gesture users perform sixty times an hour', (
      tester,
    ) async {
      // MTX-1's hdmiIn AND NOT AMP-1's srcIn, which is the interesting
      // part. Every one of A01's srcIn and zoneOut pins carries a `setKey`
      // with `atomicConnect: true` — they are stereo and speaker PAIRS —
      // so a press there takes DR-011.2's set branch and announces "one
      // cable, N conductors" instead. That is correct and untouched by
      // #93; this test is about the ordinary pin-to-pin path, so it uses
      // a bank that has one. (Which branch a run of set pins takes when
      // multi-draw arms is 93-D's question, not this phase's.)
      //
      // Index 8 because the fixture's cables fill a contiguous run at the
      // top of that bank and a full pin refuses to arm, correctly.
      await pump(tester);
      final hdmiIn = bank('MTX-1', 'hdmiIn');
      final drag = await tester.startGesture(
        toScreen(tester, hdmiIn[8].centre),
      );
      await tester.pump();

      expect(
        statusOf(tester),
        contains('Wire from'),
        reason: 'the anchor is set on the way in and the arm still happens',
      );
      await drag.cancel();
      await tester.pumpAndSettle();
    });
  });

  group('2 — Shift+click extends the run', () {
    testWidgets('four clicks apart selects four jacks, in rank order', (
      tester,
    ) async {
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[3].centre));

      expect(statusOf(tester), contains('4 jacks selected'));
      expect(statusOf(tester), contains('Source Inputs'));
      expect(statusOf(tester), contains('4 cables'));
    });

    testWidgets('the whole sixteen-jack bank is two clicks — the demo '
        'moment', (tester) async {
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src.first.centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src.last.centre));

      expect(statusOf(tester), contains('16 jacks selected'));
    });

    testWidgets('Shift+click does NOT arm a cable', (tester) async {
      // The press has to decide once what it is, and a Shift press is a
      // selection. An armed wire here would leave a band in flight that
      // the next click would commit.
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[2].centre));

      expect(statusOf(tester), isNot(contains('Wire from')));
      expect(doc.links, hasLength(5), reason: 'the fixture wires five');
    });

    testWidgets('Shift+click into ANOTHER bank replaces rather than mixing', (
      tester,
    ) async {
      // The invariant `planMultiDraw` re-filters its sources to defend
      // against, held one layer earlier so there is nothing to filter.
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');
      final zone = bank('AMP-1', 'zoneOut');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[3].centre));
      expect(statusOf(tester), contains('4 jacks selected'));

      await shiftTapAt(tester, toScreen(tester, zone[0].centre));
      expect(
        statusOf(tester),
        contains('Shift+click'),
        reason:
            'a run cannot span two banks, so the second bank starts a '
            'fresh anchor rather than growing the first',
      );
      expect(statusOf(tester), contains('Zone Speaker Outputs'));
    });
  });

  group('3 — the keyboard route (Shift+arrow)', () {
    testWidgets('starts a run from nothing — it does not require a click '
        'first', (tester) async {
      // The "worked once and then quietly stopped" shape DR-011 names.
      // A keyboard route gated on a selection that only the pointer can
      // create is a route that does not exist.
      await pump(tester);
      await tester.tapAt(
        toScreen(
          tester,
          DPt(
            (symbolOf('AMP-1').bodyRect.left +
                    symbolOf('AMP-1').bodyRect.right) /
                2,
            (symbolOf('AMP-1').bodyRect.top +
                    symbolOf('AMP-1').bodyRect.bottom) /
                2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('2 jacks selected'));
    });

    testWidgets('refuses to wrap at the end of the bank, and SAYS so rather '
        'than doing nothing', (tester) async {
      // docs/04 §3.4's rule against the silent no-op. The ends of a bank
      // are states a user sits in, not edge cases.
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src.first.centre));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('first jack'));
      expect(statusOf(tester), contains('Source Inputs'));
    });
  });

  group('4 — the run is chrome, and Esc is a ladder', () {
    testWidgets('selected jacks are RINGED, and the ring survives the '
        'gesture that made it', (tester) async {
      await pump(tester);
      final idle = rings(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[3].centre));

      expect(
        rings(tester),
        // Four selected, MINUS the one the caret is on — which the overlay
        // skips because the two rings are the same radius and would be
        // exactly coincident — PLUS the caret's own.
        idle + 4,
        reason:
            'three selection rings and one caret ring, with no '
            'coincident pair',
      );
    });

    testWidgets('Esc clears the run BEFORE the focus scope, and reports the '
        'count', (tester) async {
      await pump(tester);
      final idle = rings(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[3].centre));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('4 selected jacks deselected'));
      expect(
        rings(tester),
        idle + 1,
        reason:
            'every selection ring is gone and the caret stays — the '
            'user is still there, exactly as after a cancelled cable',
      );
    });
  });

  group('5 — the document moving under a held run', () {
    testWidgets('drops the WHOLE run and says so, rather than quietly '
        'shrinking it', (tester) async {
      // The failure this exists to prevent: `planMultiDraw` silently
      // dropping a source that no longer resolves, so "sixteen cables"
      // becomes fifteen with nothing said. `_invalidateLivePreviews`'s
      // rule, applied to a selection.
      await pump(tester);
      final src = bank('AMP-1', 'srcIn');

      await tester.tapAt(toScreen(tester, src[0].centre));
      await tester.pumpAndSettle();
      await shiftTapAt(tester, toScreen(tester, src[3].centre));
      expect(statusOf(tester), contains('4 jacks selected'));

      // Delete the device the run is on, through the real command path.
      controller.run(
        RemoveDeviceCommand(id: deviceNamed(doc, 'AMP-1').id),
      );
      await tester.pumpAndSettle();

      expect(
        statusOf(tester),
        'Jack selection cancelled — the document changed.',
        reason:
            'the teardown is announced, and the RUN is what gets named '
            'rather than the caret: `_onDocumentChanged` shows one '
            'sentence, so the order of the limbs decides which loss the '
            'user hears about, and sixteen jacks cost more to rebuild '
            'than a caret does',
      );
    });
  });
}
