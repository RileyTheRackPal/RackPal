// #93 / 93-D — the gesture itself: a run of jacks dragged onto a bank.
//
// docs/05:484, verbatim: *"With N ports selected in one bank, dragging to
// a target bank creates N `Link`s in rank order under **one undo entry** —
// the 'wire the 8x8 matrix to eight zone amps' gesture. Live preview shows
// all N bands. This is the demo moment."*
//
// Four claims in one sentence, and this file is one group per claim:
//
//   1. N `Link`s — not one `Link` with N `Conductor`s, which is the OTHER
//      gesture (DR-012.2, AC-053) and a different bill of materials;
//   2. in RANK order — `PortDef.order` then `key`, the same order the
//      schedule numbers by, so cable i lands on jack i;
//   3. under ONE undo entry — one `Ctrl+Z` puts all N back;
//   4. live preview shows ALL N bands.
//
// THE SOURCE BANK IS V03's `audOut`, sixteen ports and free of atomic
// sets — measured, not assumed: 48 of the catalog's 57 banks with four or
// more ports carry no `atomicConnect` set, and the 16x16 matrix's three
// big banks are three of them. A01's `srcIn` is one of the nine that DO,
// which is why the last group is about that collision.

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

  List<({PinRef ref, DPt centre})> bank(String designator, String bankKey) {
    final device = deviceNamed(doc, designator);
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
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

  /// The jacks of [bankKey] that carry no cable yet, in rank order.
  ///
  /// WHICH IS NOT THE SAME AS "the first N jacks of the bank", and the
  /// difference is the fixture: it already wires three of AMP-1's srcIn.
  /// `planMultiDraw` pairs against jacks `evaluateConnect` allows, so a
  /// test that expected `bank[i]` would be asserting that multi-draw
  /// overwrites occupied jacks.
  List<({PinRef ref, DPt centre})> freeJacks(
    String designator,
    String bankKey,
  ) {
    final device = deviceNamed(doc, designator);
    return <({PinRef ref, DPt centre})>[
      for (final pin in bank(designator, bankKey))
        if (portConductorCount(
              doc,
              derivePortId(device.id, PortKey(pin.ref.portKey)),
            ) ==
            0)
          pin,
    ];
  }

  List<List<DPt>> bandsOf(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpPolyline>()
      .map((p) => p.pts)
      .toList();

  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('cables') ||
          data.contains('cable to') ||
          data.contains('connected') ||
          data.contains('No bank') ||
          data.contains('none of these')) {
        return data;
      }
    }
    return null;
  }

  /// Selects [count] jacks from the top of [designator]'s [bankKey] bank
  /// and returns them in rank order.
  Future<List<({PinRef ref, DPt centre})>> selectRun(
    WidgetTester tester,
    String designator,
    String bankKey, {
    required int count,
  }) async {
    final pins = bank(designator, bankKey);
    await tester.tapAt(toScreen(tester, pins.first.centre));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(toScreen(tester, pins[count - 1].centre));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    return pins.take(count).toList();
  }

  group('1 — N Links, and NOT one Link with N conductors', () {
    testWidgets('four selected jacks dragged onto a bank make FOUR links, '
        'each with ONE conductor', (tester) async {
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = bank('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(before + 4), reason: 'four CABLES');
      final made = doc.links.values.skip(before).toList();
      for (final link in made) {
        expect(
          link.conductors,
          hasLength(1),
          reason:
              'DR-012.2: multi-draw is N Links. One Link with N '
              'conductors is atomicConnect, and the two are different '
              'bills of materials',
        );
      }
    });

    testWidgets('every cable gets its OWN designator — the defect 93-B was '
        'written for, proven through the gesture', (tester) async {
      // Four links all called W006 is four schedule rows an installer
      // cannot tell apart. `ConnectAllocations` is what prevents it, and
      // this is the end-to-end proof that the screen actually reaches it.
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = bank('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      final designators = doc.links.values
          .skip(before)
          .map((l) => l.designator)
          .toSet();
      expect(designators, hasLength(4));
    });
  });

  group('2 — in RANK order', () {
    testWidgets('cable i leaves source i and lands on target i', (
      tester,
    ) async {
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = freeJacks('AMP-1', 'srcIn');
      final drop = bank('AMP-1', 'srcIn').first;

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, drop.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      final made = doc.links.values.skip(before).toList();
      for (var i = 0; i < 4; i++) {
        final ends = made[i].conductors.single;
        expect(
          (ends.from as PortEndpoint).portId,
          derivePortId(
            Uuid(sources[i].ref.deviceId),
            PortKey(sources[i].ref.portKey),
          ),
          reason: 'source $i is aud.out.${i + 1} in DR-012.2 rank order',
        );
        expect(
          (ends.to as PortEndpoint).portId,
          derivePortId(
            Uuid(target[i].ref.deviceId),
            PortKey(target[i].ref.portKey),
          ),
          reason: 'and it lands on the ith FREE jack of the target bank',
        );
      }
    });

    testWidgets('the drop lands on the bank, not on the jack under the '
        'cursor — dropping on jack 5 still starts at jack 1', (tester) async {
      // `atomicConnect`'s own rule, applied: "dropping on any member of
      // the target pair works — which is what a user aiming at a stereo
      // pair will do". A bulk gesture aimed at a bank is aimed at the
      // bank.
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 3);
      final target = freeJacks('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target[5].centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      final first = doc.links.values.skip(before).first.conductors.single;
      expect(
        (first.to as PortEndpoint).portId,
        derivePortId(
          Uuid(target.first.ref.deviceId),
          PortKey(target.first.ref.portKey),
        ),
        reason: 'dropped on the sixth free jack, wired from the first',
      );
    });
  });

  group('3 — ONE undo entry', () {
    testWidgets('one Ctrl+Z takes all four cables back', (tester) async {
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = bank('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(before + 4));

      controller.undo.undo(doc);
      expect(
        doc.links,
        hasLength(before),
        reason:
            'docs/05:484 — "N Links in rank order under ONE undo '
            'entry". Four entries would make the user press it four times',
      );

      controller.undo.redo(doc);
      expect(doc.links, hasLength(before + 4), reason: 'and redo restores');
    });

    testWidgets('the undo entry is labelled multiDraw, not atomicConnect', (
      tester,
    ) async {
      // LabelKey.multiDraw exists for exactly this: the Edit menu is
      // where a user finds out which of the two gestures they just did.
      await pump(tester);
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 3);
      final target = bank('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(controller.undo.undoLabelKey, LabelKey.multiDraw.name);
    });
  });

  group('4 — live preview shows all N bands', () {
    testWidgets('hovering a target bank draws one band per planned cable', (
      tester,
    ) async {
      await pump(tester);
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = bank('AMP-1', 'srcIn');

      // THE BASELINE IS TAKEN MID-GESTURE, not before it. `bandsOf`
      // counts every polyline in the frame, and the committed links of a
      // SELECTED device are drawn as polylines too (DR-001's drawn mode)
      // — so a baseline taken before the press would be measuring the
      // selection changing as well as the bands appearing. After the
      // press the run is armed and the caret is on its own source pin,
      // whose bank is excluded from the plan, so exactly zero multi-draw
      // bands are drawn: a clean zero to count up from.
      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      final armed = bandsOf(tester).length;

      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();

      expect(
        bandsOf(tester).length - armed,
        4,
        reason:
            'docs/05:484 — "Live preview shows all N bands." Four '
            'cables, four bands, and no fifth band from the pin the '
            'pointer happens to be on',
      );
      await drag.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('and NOTHING is written until the release', (tester) async {
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 4);
      final target = bank('AMP-1', 'srcIn');

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      expect(doc.links, hasLength(before));

      await drag.cancel();
      await tester.pumpAndSettle();
      expect(
        doc.links,
        hasLength(before),
        reason:
            'docs/05 §7 — cancel aborts "with no model mutation and '
            'no undo entry"',
      );
    });
  });

  group('5 — the keyboard drives the same gesture', () {
    testWidgets('W arms the run and Enter commits it', (tester) async {
      // The one arming path and the one commit path, reached from the
      // other driver — which is the whole reason M2-F built the keyboard
      // first.
      await pump(tester);
      final before = doc.links.length;
      await selectRun(tester, 'MTX-1', 'audOut', count: 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(statusOf(tester), contains('3 cables'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(before + 3));
      expect(statusOf(tester), contains('connected 3 cables'));
    });
  });

  group('6 — the run outruns the target bank', () {
    testWidgets('connects what fits and REPORTS the rest, minting nothing '
        'for it', (tester) async {
      // `multi_draw.dart`'s ruling: §11.8.3's "connect what fits and
      // warn", with one deliberate difference — an unpaired source mints
      // NOTHING, because a multi-draw surplus would be an entire Link
      // with its own W number pulled to nowhere.
      //
      // DIS-1's `video` bank has four jacks and MTX-1's audOut has
      // sixteen, so a run of eight cannot fit.
      await pump(tester);
      final before = doc.links.length;
      final sources = await selectRun(tester, 'MTX-1', 'audOut', count: 8);
      final target = bank('DIS-1', 'video');
      expect(target.length, lessThan(sources.length));

      final drag = await tester.startGesture(
        toScreen(tester, sources.first.centre),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, target.first.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      final made = doc.links.length - before;
      expect(made, lessThan(8), reason: 'the bank could not take them all');
      expect(made, greaterThan(0), reason: 'and it took what it could');
      expect(
        statusOf(tester),
        contains('left unwired'),
        reason:
            'the surplus is the only record the user gets, because '
            'nothing was written for it',
      );
    });
  });

  group('7 — a run of atomic-set jacks', () {
    testWidgets('multi-draw wins, and SAYS what it is doing instead', (
      tester,
    ) async {
      // The collision this build rules on rather than leaves silent:
      // every A01 srcIn jack carries an `atomicConnect` setKey, so
      // DR-011.2's set branch would normally claim the press. An explicit
      // run of N jacks outranks a property of the hardware — but the cost
      // is a different bill of materials, so the arming sentence names it.
      await pump(tester);
      await selectRun(tester, 'AMP-1', 'srcIn', count: 4);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();

      final status = statusOf(tester);
      expect(status, contains('4 cables'));
      expect(
        status,
        contains('cable SETS'),
        reason:
            'DR-012.2 makes N Links and one Link with N conductors '
            'different bills of materials, so choosing between them in '
            'silence is the harm the ruling names',
      );
    });
  });
}
