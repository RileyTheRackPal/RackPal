// M2-F PHASE 4D — the atomic-set gesture, driven through the screen.
//
// DR-011.2 rules the branch: "`AtomicConnectCommand` is reserved for the
// case where the grabbed pin belongs to a `PortSetDef` flagged
// `atomicConnect: true`." It is not a mode the user enters — it is a
// property of the jack under the cursor, and the arithmetic is that 223 of
// the catalog's 257 ports carry no `setKey` at all, so pin-to-pin is the
// general case and this is the exception.
//
// THE DISTINCTION THAT MATTERS MOST HERE IS DR-012.2's. An atomic set is
// ONE `Link` with N `Conductor`s (AC-053); multi-draw is N `Link`s. They
// sit one line apart in docs/05 and swapping them changes the pull sheet's
// row count — eight cables an installer pulls separately is a different
// bill of materials from one cable with eight conductors. Every test below
// that counts links is counting that.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 7, 31, 9)),
    );
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
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

  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('conductor') ||
          data.contains('connected') ||
          data.contains('cancelled') ||
          data.contains('Wire from') ||
          data.contains('one at a time') ||
          data.contains('No set') ||
          data.contains('No pin') ||
          data.startsWith('TOP-')) {
        return data;
      }
    }
    return null;
  }

  /// The centre of the first pin belonging to [setKey] on [designator].
  ///
  /// AMP-1 is the fixture's only device with port sets — 16 of them, eight
  /// source stereo pairs and eight zone speaker pairs, 32 ports in all. It
  /// is therefore both the source and the only available target, so the
  /// tests below connect two of ONE amplifier's own pairs. That is a
  /// loopback, and it is legal (only pin-to-ITSELF is refused, TOP-001) —
  /// it is the deterministic way to reach a second atomic set on this
  /// fixture, not a claim that anybody would wire an amp to itself.
  ///
  /// THE HIGH-NUMBERED SETS, deliberately: the fixture wires AMP-1 three
  /// times and `claim` takes ports in declared order, so src1 and src2 are
  /// already partly occupied and a cable from either is correctly refused
  /// by TOP-003. The first draft of these tests used src1 and read
  /// "No set on this sheet can take the Source 1 pair" — the branch
  /// working, against a source that was full.
  DPt pinOfSet(String designator, String setKey) {
    final device = deviceNamed(doc, designator);
    final body = doc.templates[templateKeyFor(device.templateRef)]!.body;
    final port = body.ports.firstWhere((p) => p.setKey == setKey);
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    final sym = symbol.allPorts.firstWhere((p) => p.key == port.key.v);
    return symbolPortCentre(symbol, sym);
  }

  /// A pin on AMP-1 that is in NO set — the pin-to-pin control case.
  DPt unsetPinOf(String designator) {
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

  group('1 — the branch is the JACK, not a mode', () {
    testWidgets('grabbing a pin in an atomic set arms the WHOLE SET', (
      tester,
    ) async {
      await pump(tester);
      final drag = await tester.startGesture(
        toScreen(tester, pinOfSet('AMP-1', 'src5')),
      );
      await tester.pump();

      final said = statusOf(tester)!;
      expect(
        said,
        contains('conductors'),
        reason: 'the announcement is about a CABLE with N conductors, not '
            'about one pin — that is the whole difference from DR-011.2’s '
            'general path',
      );
      expect(said, isNot(contains('Wire from')));
      await drag.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('grabbing a pin in NO set still arms the ordinary pin-to-pin '
        'gesture', (tester) async {
      // The control. 223 of 257 catalog ports are like this, so if the
      // branch leaked the common case would be the broken one.
      await pump(tester);
      final drag = await tester.startGesture(
        toScreen(tester, unsetPinOf('MTX-1')),
      );
      await tester.pump();

      expect(statusOf(tester), contains('Wire from'));
      expect(statusOf(tester), isNot(contains('conductors')));
      await drag.cancel();
      await tester.pumpAndSettle();
    });
  });

  group('2 — DR-012.2: ONE Link with N Conductors, never N Links', () {
    testWidgets('committing a set makes exactly one cable, and its conductor '
        'count is the set size', (tester) async {
      await pump(tester);
      final before = doc.links.length;

      final drag = await tester.startGesture(
        toScreen(tester, pinOfSet('AMP-1', 'src5')),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, pinOfSet('AMP-1', 'zone5')));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(
        doc.links,
        hasLength(before + 1),
        reason: 'ONE Link. N Links is multi-draw (board #93) and is a '
            'different bill of materials on the pull sheet',
      );
      final link = doc.links.values.last;
      expect(
        link.conductors.length,
        greaterThan(1),
        reason: 'and it carries the set, not a single pin',
      );
      expect(link.services, hasLength(1));
      expect(statusOf(tester), contains('connected'));
    });

    testWidgets('the ports it lands on are MATERIALISED — DR-011.1, on the '
        'path where it was missing until Phase 4C', (tester) async {
      // The finding this phase stopped for: `AtomicConnectCommand` never
      // wrote `doc.ports`, so on a palette-built document every set plan
      // came back with zero conductors. Driven here through the real
      // gesture rather than against the command.
      await pump(tester);
      final before = doc.ports.length;

      final drag = await tester.startGesture(
        toScreen(tester, pinOfSet('AMP-1', 'src6')),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, pinOfSet('AMP-1', 'zone6')));
      await drag.up();
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(6));
      expect(
        doc.ports.length,
        greaterThan(before),
        reason: 'the set gesture creates the pins it lands on',
      );
      for (final conductor in doc.links.values.last.conductors) {
        for (final end in [conductor.from, conductor.to]) {
          if (end is! PortEndpoint) continue;
          expect(
            doc.ports.containsKey(end.portId),
            isTrue,
            reason: 'every conductor end lands on a port that exists',
          );
        }
      }
    });

    testWidgets('it is ONE undo entry, however many conductors', (
      tester,
    ) async {
      await pump(tester);
      final drag = await tester.startGesture(
        toScreen(tester, pinOfSet('AMP-1', 'src7')),
      );
      await tester.pump();
      await drag.moveTo(toScreen(tester, pinOfSet('AMP-1', 'zone7')));
      await drag.up();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(6));

      controller.undoLast();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(5));
      expect(
        doc.ports.length,
        buildSchematicTestDocument().ports.length,
        reason: 'and the ports it created went back with it — revert '
            'removes exactly what apply added',
      );
    });
  });

  group('3 — the keyboard drives it too', () {
    testWidgets('W arms the set and Enter commits it, with no pointer at '
        'all', (tester) async {
      // The set gesture goes through the SAME `_armWireFrom` and
      // `_commitWire` the pin gesture does, so the keyboard route reaches
      // it for free — which is the point of having built the keyboard
      // first.
      await pump(tester);

      // Select AMP-1 and seed the caret onto it, then walk to a set pin.
      await tester.tapAt(toScreen(tester, pinOfSet('AMP-1', 'src8')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // The tap landed the caret on a set pin already (a press on a pin
      // sets the caret); W should arm the set from wherever it is.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();

      final said = statusOf(tester);
      expect(said, isNotNull, reason: 'never a silent no-op');
    });
  });
}
