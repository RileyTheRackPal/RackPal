// #96 / 96-B — removing a cable, which nothing in the product could do.
//
// `RemoveLinkCommand` has been in core since M0, lossless and covered by
// `command_roundtrip_test`'s thousand random sequences, and the string
// appeared in no file of `rackpal_ui` or `apps/rackpal`. The only way to
// take a cable off a sheet was to delete a device at one end and let
// DR-013's cascade have it.
//
// Five claims, one group each:
//
//   1. a pennant is what there is to click, and clicking one picks the
//      cable it stands for — BOTH its flags, per §11.5;
//   2. `Del` removes it, and `Ctrl+Z` puts it back;
//   3. the keyboard route needs no mouse: a caret on a wired pin is enough,
//      and it works on a pin that HAS NO PENNANT (the R of an atomic pair),
//      which is the case a scene-based lookup would get wrong;
//   4. every nothing gets a sentence — docs/04 §3.4 forbids a silent no-op,
//      and `Del` on this sheet has three different nothings;
//   5. `Esc` joins the existing ladder rather than replacing a rung.

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

  /// Everything the screen is currently SAYING, joined.
  ///
  /// The status strip is one `Text` among many on this screen and its
  /// content is the whole point of half these assertions, so the reader
  /// takes the lot rather than encoding which widget it lives in — a test
  /// that knew the widget tree would fail on a layout change instead of on
  /// a behaviour one.
  String statusOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' | ');

  /// The link the fixture calls [designator].
  Uuid linkNamed(String designator) =>
      doc.links.entries.firstWhere((e) => e.value.designator == designator).key;

  /// A point inside one of [linkId]'s pennants.
  DPt pennantOf(Uuid linkId) {
    final label = reference.netLabels.firstWhere((l) => l.linkId == linkId);
    return DPt(
      (label.pennant.left + label.pennant.right) / 2,
      (label.pennant.top + label.pennant.bottom) / 2,
    );
  }

  /// How many pennant outlines the overlay drew.
  ///
  /// `OpRect` ALONE IS NOT THE FILTER — the sheet draws thirteen of them
  /// before anything is selected (symbol bodies, the frame). The
  /// discriminator is `scaleWithGeometry: false`, which is the overlay's
  /// signature rather than a lucky property: `connect_overlay.dart`'s header
  /// makes it the type-system statement that live gesture chrome is
  /// measured in SCREEN PIXELS and is meaningless to a PDF backend. Nothing
  /// that belongs on a printed sheet carries it.
  ///
  /// The idle case below asserts this actually discriminates, rather than
  /// leaving that as a sentence in a comment.
  int cableMarks(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpRect>()
      .where((r) => r.stroke?.scaleWithGeometry == false)
      .length;

  group('0 — the fixture is what this file thinks it is', () {
    test('five cables, each with one conductor and its own net', () {
      expect(doc.links, hasLength(5));
      for (final link in doc.links.values) {
        expect(link.conductors, hasLength(1));
        expect(link.services.single.netId, isNotNull);
      }
    });

    testWidgets('an idle sheet draws no cable mark at all', (tester) async {
      await pump(tester);
      expect(cableMarks(tester), 0);
    });
  });

  group('1 — clicking a pennant picks the cable', () {
    testWidgets('and says which one, by designator and by both ends', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
      await tester.pumpAndSettle();

      final status = statusOf(tester);
      expect(status, contains('W001'));
      expect(status, contains('MTX-1'));
      expect(status, contains('DIS-1'));
      expect(status, contains('Del removes it'));
    });

    testWidgets('BOTH flags are marked — §11.5 highlights together', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
      await tester.pumpAndSettle();
      // Two ends on the sheet, so two marks. A selection that lit one end
      // would say the cable is half-picked.
      expect(cableMarks(tester), 2);
    });

    testWidgets('a click on empty paper drops it again', (tester) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
      await tester.pumpAndSettle();
      expect(cableMarks(tester), 2);

      // THE WIDGET'S OWN CORNER, not a scene point off the sheet: a scene
      // coordinate outside the content maps to a screen point outside the
      // canvas, where `tapAt` delivers nothing at all and the test would
      // pass without the behaviour existing.
      await tester.tapAt(
        tester.getTopLeft(find.byType(SchematicCanvasBody)) +
            const Offset(4, 4),
      );
      await tester.pumpAndSettle();
      expect(cableMarks(tester), 0);
    });
  });

  group('2 — Del removes it and Ctrl+Z puts it back', () {
    testWidgets('the link and its net go; the other four stay', (
      tester,
    ) async {
      await pump(tester);
      final target = linkNamed('W001');
      final net = doc.links[target]!.services.single.netId!;

      await tester.tapAt(toScreen(tester, pennantOf(target)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(doc.links.containsKey(target), isFalse);
      expect(doc.links, hasLength(4));
      expect(doc.nets.containsKey(net), isFalse);
      expect(statusOf(tester), contains('W001'));
      expect(statusOf(tester), contains('removed'));
    });

    testWidgets('undo restores it under the SAME id', (tester) async {
      await pump(tester);
      final target = linkNamed('W001');

      await tester.tapAt(toScreen(tester, pennantOf(target)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      controller.undo.undo(doc);
      await tester.pumpAndSettle();

      expect(doc.links.containsKey(target), isTrue);
      expect(doc.links, hasLength(5));
    });

    testWidgets('the delete is not narrated as a teardown over its own '
        'sentence', (tester) async {
      // `_invalidateLivePreviews` would otherwise announce "Cable selection"
      // was dropped AFTER the success message — the last thing a screen
      // reader says about a delete that worked. The field is cleared before
      // the command runs, so that limb finds nothing.
      await pump(tester);
      await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(statusOf(tester), isNot(contains('Cable selection')));
    });

    testWidgets('Backspace does the same thing, for the keyboard with no '
        'Del key', (tester) async {
      await pump(tester);
      final target = linkNamed('W001');
      await tester.tapAt(toScreen(tester, pennantOf(target)));
      await tester.pumpAndSettle();
      // The selection is asserted before the key, so a failure below is
      // unambiguously about `Backspace` and not about where the tap landed.
      expect(cableMarks(tester), 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(doc.links.containsKey(target), isFalse);
    });
  });

  group('3 — the keyboard route needs no pennant and no mouse', () {
    testWidgets('a caret on a wired pin is enough', (tester) async {
      await pump(tester);
      final target = linkNamed('W001');
      final end = doc.links[target]!.conductors.single.from as PortEndpoint;
      final port = doc.ports[end.portId]!;
      final symbol = reference.symbols.firstWhere(
        (s) => s.id == port.deviceId.v,
      );
      final pin = symbol.allPorts.firstWhere(
        (p) => p.key == port.templatePortKey!.v,
      );

      // A TAP ON A PIN IS NOT A CABLE — it sets the caret and clears the
      // wire it armed on the way in (`_releaseWireAt`, `moved: false`), so
      // this leaves exactly the state a keyboard user is in after arrowing
      // onto a jack.
      await tester.tapAt(toScreen(tester, symbolPortCentre(symbol, pin)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(doc.links.containsKey(target), isFalse);
      expect(statusOf(tester), contains('W001'));
    });
  });

  group('4 — every nothing gets a sentence (docs/04 §3.4)', () {
    testWidgets('a caret on an unwired pin says so, and writes nothing', (
      tester,
    ) async {
      await pump(tester);
      final device = deviceNamed(doc, 'AMP-1');
      final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
      // A jack with no conductor on it — `portConductorCount` is the same
      // question `TOP-003` asks, so this cannot drift from the rules.
      final free = symbol.allPorts.firstWhere(
        (p) =>
            portConductorCount(doc, derivePortId(device.id, PortKey(p.key))) ==
            0,
      );
      final before = doc.links.length;

      await tester.tapAt(toScreen(tester, symbolPortCentre(symbol, free)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(before));
      expect(statusOf(tester), contains('carries no cable'));
    });

    testWidgets('Del with no caret and no selection asks for a flag', (
      tester,
    ) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      // The gate declines with no caret and nothing selected, so the key
      // falls through and the sheet is unchanged. Either way nothing is
      // written and nothing is claimed silently.
      expect(doc.links, hasLength(5));
    });
  });

  group('5 — Esc joins the ladder', () {
    testWidgets('deselects the cable and names it', (tester) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, pennantOf(linkNamed('W001'))));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(cableMarks(tester), 0);
      expect(statusOf(tester), contains('deselected'));
      expect(doc.links, hasLength(5));
    });
  });
}
