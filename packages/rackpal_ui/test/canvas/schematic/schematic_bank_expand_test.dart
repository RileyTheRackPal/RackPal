// CR-103's user half, on the canvas (`#801`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS AT ALL
// ═══════════════════════════════════════════════════════════════════════
// `#801` was filed as a one-line change: pass `collapseBanks: true` from
// the scene builder. It is not. `symbolHitRegions` emits one region per
// entry in `RenderedSymbol.allPorts`, and a collapsed bank contributes
// ONE entry, so turning collapse on takes 47 of a 48-port switch's ports
// off the sheet entirely: no pin, no hit region, no way to select or wire
// them. Nothing in `rackpal_ui` or `rackpal_export` read `isCollapsed`,
// so there was no way back either.
//
// CR-103 always had the other half: any bank "may be collapsed by the
// user at any time", which means nothing unless it can be un-collapsed.
// This file is that half, and the first test is the one that says why the
// rest are needed.
//
// THE FIXTURE OPTS BACK IN. `schematic_test_document.dart` opts every seed
// bank OUT of collapse, so that sixty-five wiring tests stay about wiring;
// this file turns it back on for the one device it is about.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late DeviceInstance switchDevice;
  late String bankKey;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    switchDevice = deviceNamed(doc, 'SW-1');
    final body = doc.templates.values
        .firstWhere((t) => t.templateId == switchDevice.templateRef.templateId)
        .body;
    for (final bank in body.banks) {
      bank.collapseInSymbol = true;
    }
    bankKey = body.banks
        .firstWhere(
          (b) =>
              body.ports.where((p) => p.bankKey == b.key).length >
              kBankCollapseThreshold,
        )
        .key;
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 9, 1, 9)),
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  SchematicScene sceneWith({bool expanded = false}) => buildSchematicScene(
    doc: doc,
    measurer: const FakeMeasurer(),
    expandedBanks: expanded
        ? {
            switchDevice.id: {bankKey},
          }
        : const {},
  );

  RenderedSymbol symbolIn(SchematicScene scene) =>
      scene.symbols.firstWhere((s) => s.id == switchDevice.id.v);

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

  group('what collapse costs, which is why the rest of this file exists', () {
    test('a bank over eight leaves its other ports with NO pin and NO hit '
        'region, so they cannot be selected or wired', () {
      final scene = sceneWith();
      final symbol = symbolIn(scene);
      final drawn = symbol.allPorts.where((p) => p.bankKey == bankKey).toList();
      expect(drawn, hasLength(1), reason: 'the bank should draw one pin');
      expect(drawn.single.isCollapsed, isTrue);
      expect(
        drawn.single.collapsedCount,
        greaterThan(kBankCollapseThreshold),
        reason: 'a bank at or under eight is not what CR-103 collapses',
      );

      // THE HIT REGIONS ARE THE POINT. A pin that is not drawn is a port
      // a person cannot reach, and this is the count that says so.
      final regions = symbolHitRegions([
        symbol,
      ]).where((r) => r.partKey != null).length;
      expect(
        regions,
        lessThan(drawn.single.collapsedCount),
        reason: 'every port still had a hit region, so nothing collapsed',
      );
    });
  });

  group('a click on the vector pin gets them back', () {
    testWidgets('it expands the bank rather than selecting a pin that stands '
        'for forty-eight ports', (tester) async {
      await pump(tester);
      final symbol = symbolIn(sceneWith());
      final pin = symbol.allPorts.firstWhere(
        (p) => p.bankKey == bankKey && p.isCollapsed,
      );
      await tester.tapAt(toScreen(tester, symbolPortCentre(symbol, pin)));
      await tester.pumpAndSettle();

      // THE MESSAGE NAMES THE WAY BACK. A person who expanded a bank by
      // clicking it cannot guess how to put it away, and this canvas has
      // no modifier left to spend on the reverse.
      expect(find.textContaining('Expanded'), findsOneWidget);
      expect(find.textContaining('Press B'), findsOneWidget);
    });

    testWidgets('and a port that had no pin at all is now selectable, which '
        'is the whole reason the gesture exists', (tester) async {
      await pump(tester);
      final symbol = symbolIn(sceneWith());
      final collapsed = symbol.allPorts.firstWhere(
        (p) => p.bankKey == bankKey && p.isCollapsed,
      );
      await tester.tapAt(toScreen(tester, symbolPortCentre(symbol, collapsed)));
      await tester.pumpAndSettle();

      // A port the collapsed symbol had no pin for: the LAST of the bank,
      // read off the expanded geometry the screen now draws.
      final open = symbolIn(sceneWith(expanded: true));
      final ports = open.allPorts.where((p) => p.bankKey == bankKey).toList();
      expect(ports.length, greaterThan(1), reason: 'nothing expanded');
      final last = ports.last;
      expect(
        collapsed.key,
        isNot(last.key),
        reason: 'the representative pin is not the one being reached for',
      );

      await tester.tapAt(toScreen(tester, symbolPortCentre(open, last)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Expanded'),
        findsNothing,
        reason: 'the second tap re-expanded rather than selecting a port',
      );
    });

    testWidgets('B puts it away again, and says so', (tester) async {
      await pump(tester);
      final symbol = symbolIn(sceneWith());
      final pin = symbol.allPorts.firstWhere(
        (p) => p.bankKey == bankKey && p.isCollapsed,
      );
      await tester.tapAt(toScreen(tester, symbolPortCentre(symbol, pin)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Expanded'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(find.textContaining('Collapsed'), findsOneWidget);
      expect(find.textContaining('Click the pin'), findsOneWidget);
    });
  });
}
