// The Schematic tab, pumped over a real document.
//
// THE FIRST GROUP IS THE `b560a50` REGRESSION AT SCREEN LEVEL. That canvas
// was handed a hardcoded EMPTY scene by `main.dart` and manufactured a
// symbol to fill the hole; every test here mounts the screen the way the
// app mounts it — a `DocumentController` and nothing else — so the only
// way anything appears is for the document to have reached the layout.
//
// EVERY ASSERTION BELOW IS ABOUT A RULING. §11.1.1's table (exactly one
// domain ⇒ `drawn`), §11.2's click model and `1`–`8`, §11.4's `Alt`-hover
// and `F`, DR-001's "labels are the base state". The wording of a chip is
// not a ruling and is not asserted; the number on it is, because it is a
// claim about the drawing.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

  // The supported window (docs/04 §1), matching the app's own shell tests.
  // AT THE 800×600 DEFAULT the eight chips overflow the bar's horizontal
  // scroll view and `tester.tap` lands on the clip instead of the chip —
  // which reads as "soloing does not work" and is really "the chip was off
  // screen". Sizing the window is what makes the tap mean what it says.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 9)),
    );
    // The same layout the screen will compute — the geometry depends on the
    // measurer alone, never on the palette — so this test can point at a
    // symbol without reaching inside the widget for its scene.
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, {RackDocument? over}) async {
    final c = over == null
        ? controller
        : DocumentController(
            over,
            clock: FixedClock(DateTime.utc(2026, 7, 28, 9)),
          );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasScreen(
            measurer: const FakeMeasurer(),
            controller: c,
          ),
        ),
      ),
    );
    // The viewport frames the sheet in a post-frame callback.
    await tester.pumpAndSettle();
  }

  List<DiagramOp> painted(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops;

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

  DPt centreOf(String designator) {
    final device = deviceNamed(doc, designator);
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    return DPt(
      (symbol.bodyRect.left + symbol.bodyRect.right) / 2,
      (symbol.bodyRect.top + symbol.bodyRect.bottom) / 2,
    );
  }

  Future<TestGesture> hover(WidgetTester tester, Offset at) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(at);
    await tester.pump();
    return gesture;
  }

  group('the document reaches the canvas (b560a50)', () {
    testWidgets("the sheet draws the DOCUMENT's devices and no manufactured "
        'symbol', (tester) async {
      await pump(tester);
      final texts = painted(tester).whereType<OpText>().map((t) => t.text);
      for (final designator in kFixtureDesignators) {
        if (designator == kFixturePortlessDesignator) continue;
        expect(
          texts,
          contains(designator),
          reason: '$designator is in the document and not on the sheet',
        );
      }
      expect(
        texts.where((t) => RegExp(r'^P?(in|out)\d+$').hasMatch(t)),
        isEmpty,
        reason: 'the deleted canvas drew ports labelled Pin1 / Pout1',
      );
    });

    testWidgets('the screen has no way to be given a scene — it takes a '
        'controller and derives one', (tester) async {
      // The constructor IS the fix. If a `scene`/`document` parameter is
      // ever added here, this test is the one that has to be deleted
      // deliberately.
      await pump(tester);
      final screen = tester.widget<SchematicCanvasScreen>(
        find.byType(SchematicCanvasScreen),
      );
      expect(screen.controller, same(controller));
      expect(painted(tester), isNotEmpty);
    });

    testWidgets('an edit to the document reaches the sheet', (tester) async {
      // A `meta` edit specifically: the scene is CACHED (relaying a
      // 300-link sheet on every hover would be unusable), so every epoch
      // the schematic reads has to invalidate it. A cache keyed on
      // `structure` alone would leave a renamed device showing its old
      // name forever, and no test that only adds devices could see it.
      await pump(tester);
      final mtx = deviceNamed(doc, 'MTX-1');
      expect(
        painted(tester).whereType<OpText>().map((t) => t.text),
        isNot(contains('ZZ')),
      );
      controller.run(
        RenameEntityCommand(
          targetKind: RenameTargetKind.device,
          id: mtx.id,
          from: mtx.name,
          to: 'ZZ',
          now: DateTime.utc(2026, 7, 28, 10),
          actor: 'test',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        painted(tester).whereType<OpText>().map((t) => t.text),
        contains('ZZ'),
        reason: 'the scene cache is not keyed on the `meta` epoch',
      );
    });
  });

  group('the domain filter bar (§11.2)', () {
    testWidgets('one chip per seeded domain, each carrying its own live '
        'count', (tester) async {
      await pump(tester);
      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips, hasLength(doc.registries.signalDomains.length));

      final counts = linksByDomain(reference);
      for (final chip in bar.chips) {
        expect(
          chip.linkCount,
          counts[chip.id]?.length ?? 0,
          reason: '${chip.id.v} advertises a count the sheet does not draw',
        );
      }
      // The fixture wires two `net` links and one each of the other two.
      expect(
        bar.chips.firstWhere((c) => c.id.v == 'net').linkCount,
        2,
      );
    });

    testWidgets('the chips are in `schematicDomainOrder`, so key n and chip '
        'n are the same domain', (tester) async {
      await pump(tester);
      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(
        bar.chips.map((c) => c.id).toList(),
        schematicDomainOrder(doc.registries),
      );
      expect(bar.chips.map((c) => c.index).toList(), [
        for (var i = 1; i <= bar.chips.length; i++) i,
      ]);
    });

    testWidgets('an unfiltered sheet draws NO wire — DR-001 makes labels the '
        'base state', (tester) async {
      await pump(tester);
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);
    });

    testWidgets('clicking a chip solos it and switches THAT domain to '
        'drawn', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      final wires = painted(tester).whereType<OpPolyline>().toList();
      expect(wires, hasLength(2), reason: 'the fixture has two net links');
      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.drawn).map((c) => c.id.v), ['net']);
      expect(bar.chips.where((c) => c.visible).map((c) => c.id.v), ['net']);
    });

    testWidgets('Ctrl+clicking a second chip shows two and draws NEITHER — '
        '§11.1.1 says exactly one', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(painted(tester).whereType<OpPolyline>(), isNotEmpty);

      // A CHIP NEAR THE FRONT OF THE STRIP, deliberately: soloing puts the
      // HUD headline in the bar, which narrows the chips' scroll view and
      // pushes the last chip out of the hit-testable area. A tap that
      // lands on the clip reads as "Ctrl+click does not toggle" and is
      // really "the chip was off screen".
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Digital Audio'));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible).length, 2);
      expect(
        painted(tester).whereType<OpPolyline>(),
        isEmpty,
        reason: 'two visible domains is not "exactly one"',
      );
    });

    testWidgets('Ctrl+clicking the ONLY visible domain off leaves nothing '
        'visible, not everything', (tester) async {
      // A user who Ctrl+clicks a soloed chip meant to remove it. Springing
      // back to the whole sheet would be the surface deciding they meant
      // the opposite, and it is the difference `SchematicViewFilter` keeps
      // `explicit` for: "nothing selected" and "no selection made" are two
      // states, and only one of them is [All].
      await pump(tester);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible), isEmpty);
    });

    testWidgets('[All] returns to the unfiltered sheet and [None] hides '
        'every cable', (tester) async {
      await pump(tester);
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      var bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible), isEmpty);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible), hasLength(bar.chips.length));
    });

    testWidgets('`1` solos the first chip and `` ` `` shows all (§11.2, '
        '§14)', (tester) async {
      await pump(tester);
      final order = schematicDomainOrder(doc.registries);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      var bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible).map((c) => c.id), [order.first]);

      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.pumpAndSettle();
      bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.chips.where((c) => c.visible), hasLength(bar.chips.length));
    });
  });

  group('Alt-hover and focus (§11.4)', () {
    testWidgets('hovering WITHOUT Alt draws nothing — it is a modifier, not '
        'a mouse-over', (tester) async {
      await pump(tester);
      await hover(tester, toScreen(tester, centreOf('MTX-1')));
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);
    });

    testWidgets("Alt+hover draws exactly the hovered symbol's links, and "
        'letting go of Alt takes them away again', (tester) async {
      await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await hover(tester, toScreen(tester, centreOf('MTX-1')));

      // MTX-1 carries three of the fixture's four links.
      final mtx = deviceNamed(doc, 'MTX-1');
      final expected = <Uuid>{
        for (final label in reference.netLabels)
          if (label.deviceId == mtx.id.v) label.linkId,
      };
      // FOUR: the fixture wires MTX-1 to DIS-1, to SW-1 and TWICE to
      // AMP-1 (see `schematic_test_document.dart` on why the pair is
      // doubled).
      expect(expected, hasLength(4));
      expect(
        painted(tester).whereType<OpPolyline>(),
        hasLength(expected.length),
      );

      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(
        painted(tester).whereType<OpPolyline>(),
        isEmpty,
        reason:
            '§11.4: "No click, no mode, no state" — the hover is '
            'transient and Alt going up ends it',
      );
    });

    testWidgets('Alt+hover over empty sheet draws nothing', (tester) async {
      await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      // Far outside every symbol, but inside the canvas.
      await hover(
        tester,
        tester.getTopLeft(find.byType(SchematicCanvasBody)) +
            const Offset(4, 4),
      );
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });

    testWidgets('clicking selects, `F` focuses the selection, `Esc` leaves '
        'it', (tester) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      // Selection alone draws nothing: §11.1.1's third row is FOCUS, not
      // selection.
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      final amp = deviceNamed(doc, 'AMP-1');
      final expected = <Uuid>{
        for (final label in reference.netLabels)
          if (label.deviceId == amp.id.v) label.linkId,
      };
      expect(expected, hasLength(3));
      expect(
        painted(tester).whereType<OpPolyline>(),
        hasLength(expected.length),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);
    });

    testWidgets('`F` with nothing selected does nothing rather than '
        'focusing the sheet', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(painted(tester).whereType<OpPolyline>(), isEmpty);
    });

    testWidgets('Alt-hover outranks a soloed domain, and says so in the '
        'headline', (tester) async {
      // The precedence `resolveDrawnScope` states: a hover the user is
      // holding down right now beats a filter they set a minute ago.
      await pump(tester);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await hover(tester, toScreen(tester, centreOf('MTX-1')));
      final bar = tester.widget<DomainFilterBar>(find.byType(DomainFilterBar));
      expect(bar.headline, contains('Alt-hover'));
      expect(bar.chips.where((c) => c.drawn), isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });
  });

  group('what the sheet says about itself', () {
    testWidgets('the under-glyphed family count is on screen, not hidden', (
      tester,
    ) async {
      // DR-010 §11.10.4 keeps the per-family glyph out of scope, so
      // `SchematicScene.underGlyphedFamilyIds` is how the gap stays known
      // rather than silent (G4). A UI that dropped the count would undo
      // that.
      await pump(tester);
      expect(reference.underGlyphedFamilyIds, isNotEmpty);
      expect(
        find.textContaining(
          '${reference.underGlyphedFamilyIds.length} families drawn with an '
          'unverified glyph',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a device with no ports is counted, not silently dropped', (
      tester,
    ) async {
      await pump(tester);
      expect(reference.unsymbolisedDeviceIds, hasLength(1));
      expect(find.textContaining('1 without ports'), findsOneWidget);
      expect(
        find.textContaining(
          '${reference.symbols.length} of ${doc.devices.length} devices drawn',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a document with no cable says so, and blames the missing '
        'GESTURE rather than the user', (tester) async {
      final bare = buildSchematicTestDocument()..links.clear();
      await pump(tester, over: bare);
      expect(find.textContaining(kNoLinksHeadline), findsOneWidget);
      final strip = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      for (final lie in [
        'you have not wired',
        'coming soon',
        'no connections yet',
        'create links in the',
      ]) {
        expect(strip, isNot(contains(lie)), reason: '"$lie" is not true');
      }
    });

    testWidgets('a document whose devices have no ports draws no sheet and '
        'explains why', (tester) async {
      final bare = buildSchematicTestDocument()
        ..links.clear()
        ..ports.clear()
        ..devices.removeWhere(
          (_, d) => d.designator != kFixturePortlessDesignator,
        );
      await pump(tester, over: bare);
      expect(find.textContaining(kNoSymbolsHeadline), findsOneWidget);
      expect(find.byType(SchematicCanvasBody), findsNothing);
    });
  });

  group('the sheet edits ONLY through the connect gesture', () {
    testWidgets('filtering, selecting, focusing and cancelling change '
        'NOTHING in the document', (tester) async {
      // THIS GROUP'S TITLE USED TO READ "the sheet is a projection, never
      // an editor", and M2-F is what retired it: `_commitWire` runs a
      // `ConnectPortsCommand`. What survives — and is worth more now than
      // when nothing here could write at all — is that the VIEW controls
      // are still inert. A domain filter, a selection, a focus scope and a
      // cancel are all observed-never-persisted state (docs/03 §4.4), and
      // a filter click that dirtied the file would be a save prompt for
      // looking at something.
      //
      // The keys that DO write are exercised in
      // `schematic_keyboard_connect_test.dart`; deliberately none of them
      // appears below, so this stays a statement about the view controls
      // rather than a list that has to be edited every time one is added.
      await pump(tester);
      final before = controller.doc.sequence;

      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(controller.doc.sequence, before);
      expect(controller.doc.links, hasLength(5));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // `#913`, DR-186 §11.185.3: Ctrl+L PINS A SYMBOL WHERE IT STANDS
  // ═════════════════════════════════════════════════════════════════════
  group('#913, DR-186: Ctrl+L pins a symbol', () {
    Future<void> ctrlL(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('LOAD-BEARING: it pins the selected symbol at the position '
        'the layout gave it, so nothing moves', (tester) async {
      await pump(tester);
      final amp = deviceNamed(doc, 'AMP-1');
      final before = reference.positions[amp.id];
      expect(before, isNotNull);

      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      await ctrlL(tester);

      // CR-073's ONE sheet, created by this pin (§11.185.4).
      expect(controller.doc.sheets, hasLength(1));
      expect(pinnedSymbolIds(controller.doc), {amp.id});
      final item = schematicSheetOf(controller.doc)!.items.values.single;
      expect(
        item.position,
        before,
        reason: 'pinned where it stands, so the symbol does not jump',
      );
      expect(find.textContaining('Pinned AMP-1'), findsOneWidget);
    });

    testWidgets('THE PIN IS DRAWN, as screen chrome over the sheet', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(PinBadgeLayer.layerKey), findsNothing);

      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      await ctrlL(tester);

      expect(find.byKey(PinBadgeLayer.layerKey), findsOneWidget);
      // AND NOT IN THE SCENE: the plan the PDF backend would replay is
      // what `painted` reads, and a badge there would print (CR-086).
      expect(
        painted(tester).whereType<OpImage>(),
        isEmpty,
        reason: 'the badge is chrome, never an op',
      );
    });

    testWidgets('a second Ctrl+L unpins it, and the pin goes with it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      await ctrlL(tester);
      await ctrlL(tester);

      expect(pinnedSymbolIds(controller.doc), isEmpty);
      expect(find.byKey(PinBadgeLayer.layerKey), findsNothing);
    });

    testWidgets('one undo takes the pin back, sheet and all', (tester) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      await ctrlL(tester);
      expect(controller.doc.sheets, hasLength(1));

      // `undoLast`, which is what the app's own Undo runs: the raw stack
      // does not bump an epoch, so a screen watching one would not hear it.
      controller.undoLast();
      await tester.pumpAndSettle();

      expect(controller.doc.sheets, isEmpty);
      expect(find.byKey(PinBadgeLayer.layerKey), findsNothing);
    });
  });
}
