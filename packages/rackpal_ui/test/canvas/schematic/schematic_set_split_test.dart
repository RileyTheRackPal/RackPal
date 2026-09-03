// DR-014 — drawing an already-wired set member somewhere else splits the
// set, driven through the screen.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIELD REPORT THIS FILE CLOSES
// ═════════════════════════════════════════════════════════════════════
// *"The Right analog audio channels can't have connections made once the
// left channel is made."* Both were true: `AtomicConnectCommand` makes a
// stereo pair ONE `Link` with two `Conductor`s, so both jacks are full and
// `TOP-003` refuses everything afterwards. The document was right and the
// gesture had no way to say the one thing the user meant.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO TESTS THAT CARRY THE RULING
// ═════════════════════════════════════════════════════════════════════
// `a wired member arms PIN-TO-PIN` is the branch. DR-011.2 decides
// set-vs-pin BY THE JACK, and this is the one exception: a set that is
// already one cable has no legal set gesture left, so a full member falls
// through to the path where the split lives. Break it and the report comes
// straight back — with the set gesture arming and finding nothing to aim
// at, which is precisely what the user saw.
//
// `aiming at the device it ALREADY reaches does not split` is the guard.
// Every other test here proves the gesture fires; that one proves it stays
// its hand. A split that fired on a misaimed drag would take a conductor
// out of a cable the user was not thinking about, and the only evidence
// would be a conductor count on a schedule they have not printed yet.

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
      clock: FixedClock(DateTime.utc(2026, 8)),
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

  /// The status line. Broader than the atomic-set suite's reader, because
  /// this gesture's sentence is the thing under test and filtering on the
  /// words it is supposed to contain would make it unfalsifiable.
  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('connected') ||
          data.contains('Wire from') ||
          data.contains('conductor') ||
          data.contains('cancelled') ||
          data.startsWith('TOP-')) {
        return data;
      }
    }
    return null;
  }

  /// The [n]th pin of [setKey] on [designator], in DECLARED order — so
  /// index 1 is the `R` leg of a stereo pair, which is the pin the field
  /// report is about.
  DPt nthPinOfSet(String designator, String setKey, int n) {
    final device = deviceNamed(doc, designator);
    final body = doc.templates[templateKeyFor(device.templateRef)]!.body;
    final ports =
        [
          for (final p in body.ports)
            if (p.setKey == setKey) p,
        ]..sort((a, b) {
          final byOrder = a.order.v.compareTo(b.order.v);
          return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
        });
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    final sym = symbol.allPorts.firstWhere((p) => p.key == ports[n].key.v);
    return symbolPortCentre(symbol, sym);
  }

  Uuid portIdOfSet(String designator, String setKey, int n) {
    final device = deviceNamed(doc, designator);
    final body = doc.templates[templateKeyFor(device.templateRef)]!.body;
    final ports =
        [
          for (final p in body.ports)
            if (p.setKey == setKey) p,
        ]..sort((a, b) {
          final byOrder = a.order.v.compareTo(b.order.v);
          return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
        });
    return derivePortId(device.id, ports[n].key);
  }

  /// A FREE pin on [designator] that belongs to no set — the pin-to-pin
  /// control, and the only kind of target that isolates one condition at a
  /// time.
  DPt freeUnsetPinOf(String designator) {
    final device = deviceNamed(doc, designator);
    final body = doc.templates[templateKeyFor(device.templateRef)]!.body;
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    for (final sym in symbol.allPorts) {
      final def = body.ports.firstWhere((p) => p.key.v == sym.key);
      if (def.setKey != null) continue;
      if (portConductorCount(doc, derivePortId(device.id, def.key)) != 0) {
        continue;
      }
      return symbolPortCentre(symbol, sym);
    }
    throw StateError('$designator has no free unset pin');
  }

  Future<void> dragFromTo(WidgetTester tester, DPt from, DPt to) async {
    final drag = await tester.startGesture(toScreen(tester, from));
    await tester.pump();
    await drag.moveTo(toScreen(tester, to));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
  }

  /// Presses `[ Connect anyway ]` when a tier-2 chip is up, and reports
  /// whether it had to.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS SUITE'S CABLES REALLY ARE ONES THE RULES OBJECT TO, AND THAT IS
  /// NOT FIXABLE BY PICKING BETTER PINS
  /// ═══════════════════════════════════════════════════════════════════
  /// DR-014's split gesture is *"the same builder for both, because from
  /// the user's side there is one gesture"*, so a split is a connect and
  /// tier 2 applies to it. The drag these tests perform lifts the R leg
  /// of `AMP-1`'s `src5` pair — an RCA ANALOG AUDIO INPUT — onto a free
  /// pin of `MTX-1`, which carries HDMI on `conn.hdmi_a`. Two sinks, two
  /// families, two connectors: `DIR-001` first and `SIG-002` behind it.
  ///
  /// Elsewhere in this directory the answer was to pick a legal pair
  /// (`clearConnectPair`). Here there is nothing to pick: this fixture
  /// has no free ANALOG AUDIO SOURCE for that leg to land on, so a pair
  /// that satisfies both tiers does not exist and inventing one would
  /// mean changing the fixture out from under the split tests that made
  /// it.
  ///
  /// So these gestures OVERRIDE, which is what a real user drawing an
  /// as-found survey does (G2, CR-017) — and it earns something the
  /// suite did not have: `[ Connect anyway ]` proven end to end, writing
  /// exactly the cable the ordinary gesture would have written.
  Future<bool> connectAnyway(WidgetTester tester) async {
    final button = find.text(kSpringBackConnectAnyway);
    if (button.evaluate().isEmpty) return false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    return true;
  }

  /// Wires AMP-1's `src5` pair to its `zone5` pair as ONE atomic cable —
  /// the state the field report starts from — and returns that link.
  ///
  /// AMP-1 is the fixture's only device carrying port sets, so the atomic
  /// connect is necessarily a loopback between two of its own pairs. That
  /// is legal (only pin-to-ITSELF is refused) and it is convenient here
  /// for a second reason: it puts the far end of every conductor on AMP-1,
  /// so "a different device" and "this device" are both one drag away.
  Future<Link> wireTheSet(WidgetTester tester) async {
    final before = doc.links.keys.toSet();
    await dragFromTo(
      tester,
      nthPinOfSet('AMP-1', 'src5', 0),
      nthPinOfSet('AMP-1', 'zone5', 0),
    );
    await connectAnyway(tester);
    final made = doc.links.entries
        .firstWhere((e) => !before.contains(e.key))
        .value;
    expect(
      made.conductors,
      hasLength(2),
      reason: 'the premise: one cable, two conductors — DR-012.2',
    );
    return made;
  }

  group('1 — the branch: a wired member arms PIN-TO-PIN', () {
    testWidgets('an UNWIRED member still arms the whole set (DR-011.2 '
        'untouched)', (tester) async {
      await pump(tester);
      final drag = await tester.startGesture(
        toScreen(tester, nthPinOfSet('AMP-1', 'src5', 1)),
      );
      await tester.pump();

      expect(statusOf(tester), contains('conductors'));
      expect(statusOf(tester), isNot(contains('Wire from')));
      await drag.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('once the set is one cable, grabbing a member arms a PIN', (
      tester,
    ) async {
      await pump(tester);
      await wireTheSet(tester);

      final drag = await tester.startGesture(
        toScreen(tester, nthPinOfSet('AMP-1', 'src5', 1)),
      );
      await tester.pump();

      // The set gesture has no legal outcome from a full member — every
      // candidate meets TOP-003 at this very position — so falling through
      // costs nothing and is what makes the split reachable.
      expect(statusOf(tester), contains('Wire from'));
      await drag.cancel();
      await tester.pumpAndSettle();
    });
  });

  group('2 — the split itself', () {
    testWidgets('drawing the R leg to ANOTHER device lifts it into its own '
        'cable', (tester) async {
      await pump(tester);
      final set = await wireTheSet(tester);
      final before = doc.links.length;

      await dragFromTo(
        tester,
        nthPinOfSet('AMP-1', 'src5', 1),
        freeUnsetPinOf('MTX-1'),
      );
      await connectAnyway(tester);

      // ONE CABLE BECAME TWO. That is the bill of materials moving, which
      // is the whole subject of DR-012.2 and the reason this is announced
      // rather than done quietly.
      expect(doc.links, hasLength(before + 1));
      expect(
        set.conductors,
        hasLength(1),
        reason: 'the pair keeps its W number and loses the leg that left',
      );
      expect(
        (set.conductors.single.from as PortEndpoint).portId,
        portIdOfSet('AMP-1', 'src5', 0),
        reason:
            'and it is the L leg that stayed — lifting index 0 would '
            'move the wrong half of the pair',
      );

      final made = doc.links.values.last;
      expect(made.conductors, hasLength(1));
      expect(
        (made.conductors.single.from as PortEndpoint).portId,
        portIdOfSet('AMP-1', 'src5', 1),
      );
    });

    testWidgets('the announcement names both cables and both conductor '
        'counts', (tester) async {
      await pump(tester);
      final set = await wireTheSet(tester);

      await dragFromTo(
        tester,
        nthPinOfSet('AMP-1', 'src5', 1),
        freeUnsetPinOf('MTX-1'),
      );
      await connectAnyway(tester);

      final said = statusOf(tester)!;
      // DR-012.2: a silent choice between "one cable, N conductors" and "N
      // cables" is the harm the ruling exists to prevent, so naming the
      // W number is not enough on its own — the COUNT is the point.
      expect(said, contains(set.designator));
      expect(said, contains('split out of'));
      expect(said, contains('1 conductor instead of 2'));
    });
  });

  group('3 — the guard: it stays its hand', () {
    testWidgets('aiming at the device it ALREADY reaches does not split', (
      tester,
    ) async {
      await pump(tester);
      final set = await wireTheSet(tester);
      final before = doc.links.length;

      // A FREE pin, on the device this conductor already runs to. Nothing
      // about the target refuses the cable — only DR-014's fourth
      // condition does, and this is the drag that isolates it.
      await dragFromTo(
        tester,
        nthPinOfSet('AMP-1', 'src5', 1),
        freeUnsetPinOf('AMP-1'),
      );
      await connectAnyway(tester);

      expect(doc.links, hasLength(before));
      expect(set.conductors, hasLength(2));
      expect(statusOf(tester), startsWith('TOP-003'));
    });
  });

  group('4 — one undo entry, and it says which gesture', () {
    testWidgets('undo puts the conductor back in the cable it came from', (
      tester,
    ) async {
      await pump(tester);
      final set = await wireTheSet(tester);
      final before = doc.links.length;

      await dragFromTo(
        tester,
        nthPinOfSet('AMP-1', 'src5', 1),
        freeUnsetPinOf('MTX-1'),
      );
      await connectAnyway(tester);
      expect(doc.links, hasLength(before + 1));

      controller.undo.undo(doc);

      expect(doc.links, hasLength(before));
      expect(set.conductors, hasLength(2));
      expect(
        (set.conductors[1].from as PortEndpoint).portId,
        portIdOfSet('AMP-1', 'src5', 1),
        reason:
            'AT ITS OWN INDEX. Appending would put R before L on a '
            'later replay, and planAtomicConnect pairs BY POSITION',
      );
    });

    testWidgets('the Edit menu says "split", not "connect"', (tester) async {
      await pump(tester);
      await wireTheSet(tester);

      await dragFromTo(
        tester,
        nthPinOfSet('AMP-1', 'src5', 1),
        freeUnsetPinOf('MTX-1'),
      );
      await connectAnyway(tester);

      // A user who reads "Undo connect" and takes it at its word expects
      // one cable to disappear, not a lifted conductor to go back into the
      // cable it came out of.
      expect(controller.undo.undoLabelKey, LabelKey.splitSet.name);
    });

    testWidgets('an ordinary cable is unchanged — no split, and still '
        '"connect"', (tester) async {
      await pump(tester);
      final before = doc.links.length;

      await dragFromTo(
        tester,
        freeUnsetPinOf('MTX-1'),
        freeUnsetPinOf('AMP-1'),
      );
      await connectAnyway(tester);

      expect(doc.links, hasLength(before + 1));
      expect(controller.undo.undoLabelKey, LabelKey.connectPorts.name);
      expect(statusOf(tester), isNot(contains('split out of')));
    });
  });
}
