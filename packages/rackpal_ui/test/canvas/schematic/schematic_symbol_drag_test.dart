// `#918`, DR-187 §11.186.4, §11.186.8 and §11.186.9 — a symbol drags, the
// drag pins it, and `Ctrl+Shift+U` gives it back.
//
// ═══════════════════════════════════════════════════════════════════════
// THE GESTURE THIS STEALS FROM IS THE ONE THAT HAD TO KEEP WORKING
// ═══════════════════════════════════════════════════════════════════════
// A press on a symbol body used to arm a marquee and, on release under the
// slop, select the device. Selecting is by far the commonest thing anybody
// does to a symbol, so the cases below spend as much effort proving a
// press still SELECTS as proving a drag moves. A gesture that gained a
// move and lost a click would be a bad trade nobody asked for.
//
// The three other branches of `beginDrag` are unaffected and have their
// own suites: a press on a pin is a cable (`schematic_drag_connect_test`),
// a press on a pennant lands a run (`schematic_drag_to_land_test`), and a
// press on empty paper is the band (`schematic_marquee_test`). One case
// here guards the boundary between the last of those and this one.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SELECTION IS NOT DIRECTLY OBSERVABLE, SO IT IS ASSERTED THROUGH A
// KEYBINDING THAT READS IT
// ═══════════════════════════════════════════════════════════════════════
// `schematic_marquee_test.dart`'s header measured this and it cost this
// file two red tests before its note was read: `SchematicCanvasScreen`
// builds its OWN private `SelectionController`, so `controller.selection`
// is always empty here, and the painted op count is identical before and
// after a tap on a symbol (831 either way, measured there).
//
// So "the press selected it" is asserted the only way this screen reports
// it: by pressing `Ctrl+L`, which reads the selection and pins what it
// finds, and then reading the DOCUMENT. That is an artifact assertion
// rather than a mechanism one, which is the house rule anyway; the cost
// is that a failure could be the selection or the chord, and
// `schematic_pin_selection_test.dart` is what separates those.

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
      clock: FixedClock(DateTime.utc(2026, 9, 22, 9)),
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

  /// The centre of [designator]'s body, which is a place no pin sits.
  ///
  /// THE CENTRE AND NOT A CORNER: a symbol's jacks live on its edges, and
  /// a press 3 px inside one is a cable rather than a drag. Every case
  /// here means to start a drag, so every one starts from the middle.
  DPt bodyCentre(String designator) {
    final box = symbolOf(designator).bodyRect;
    return DPt((box.left + box.right) / 2, (box.top + box.bottom) / 2);
  }

  Map<Uuid, Pt> stored() => {
    for (final item
        in schematicSheetOf(doc)?.items.values ?? const <SheetItem>[])
      item.targetId: item.position,
  };

  Finder ghost() => find.byKey(DragGhostLayer.layerKey);

  /// `Ctrl+L`, the schematic's pin toggle (DR-186 §11.185.3). It reads the
  /// SELECTION, which is what makes it this file's selection probe.
  Future<void> pressCtrlL(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// `Ctrl+Shift+U` (§11.186.9).
  Future<void> pressUnpin(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Drags [designator]'s body by [by] and releases.
  Future<void> dragSymbol(
    WidgetTester tester,
    String designator, {
    Offset by = const Offset(60, 40),
  }) async {
    final gesture = await tester.startGesture(
      toScreen(tester, bodyCentre(designator)),
    );
    await gesture.moveBy(by);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('a press on a symbol body still SELECTS (the trade this must not '
      'make)', () {
    testWidgets('a tap with no travel writes NOTHING and leaves the symbol '
        'selected', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();

      expect(doc.sheets, isEmpty, reason: 'a selection is not an edit');
      expect(controller.undo.canUndo, isFalse);

      // THE PROBE: `Ctrl+L` pins the SELECTION, so a pin landing on this
      // device is how this screen reports that the tap selected it. See
      // the file header for why it cannot be read directly.
      await pressCtrlL(tester);
      expect(
        pinnedSymbolIds(doc),
        {device.id},
        reason: 'the commonest gesture on a symbol is still a click',
      );
    });

    testWidgets('a WOBBLE under the slop is still a click, so a shaky hand '
        'does not move the drawing', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final at = toScreen(tester, bodyCentre('MTX-1'));

      final gesture = await tester.startGesture(at);
      // Under `_clickSlopPx`, which is 4.
      await gesture.moveBy(const Offset(2, 1));
      await tester.pump();
      expect(ghost(), findsNothing, reason: 'no ghost under the slop');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        doc.sheets,
        isEmpty,
        reason: 'a wobble must not write a position',
      );
      await pressCtrlL(tester);
      expect(pinnedSymbolIds(doc), {device.id});
    });
  });

  group('a drag moves the symbol and pins it (§11.186.4)', () {
    testWidgets('THE GHOST APPEARS PAST THE SLOP and goes on release', (
      tester,
    ) async {
      await pump(tester);
      final at = toScreen(tester, bodyCentre('MTX-1'));

      final gesture = await tester.startGesture(at);
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      expect(ghost(), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(ghost(), findsNothing, reason: 'the proposal is over');
    });

    testWidgets('the drop WRITES THE POSITION AND PINS IT (CR-068), and the '
        'entry names the move rather than its side effect', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final at = toScreen(tester, bodyCentre('MTX-1'));

      final gesture = await tester.startGesture(at);
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final item = schematicSheetOf(doc)!.items.values.firstWhere(
        (i) => i.targetId == device.id,
      );
      expect(item.pinned, isTrue, reason: 'any manual move pins');
      expect(
        controller.undo.undoLabelKey,
        LabelKey.moveSymbol.name,
        reason: '"Undo Pin symbol" names what it cost, not what they did',
      );
    });

    testWidgets('AND THE SYMBOL IS WHERE IT WAS DROPPED, which is the claim '
        'a ghost makes and has to keep', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final before = reference.positions[device.id]!;
      final at = toScreen(tester, bodyCentre('MTX-1'));

      final gesture = await tester.startGesture(at);
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final after = buildFixtureScene(doc).positions[device.id]!;
      expect(
        after,
        isNot(before),
        reason: 'the control: it actually moved',
      );
      expect(
        after,
        stored()[device.id],
        reason: 'the layout put it exactly where the document says',
      );
    });

    testWidgets('ONE undo puts it back, and takes the pin with it', (
      tester,
    ) async {
      await pump(tester);
      final at = toScreen(tester, bodyCentre('MTX-1'));

      final gesture = await tester.startGesture(at);
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(stored(), isNotEmpty);

      controller.undoLast();
      await tester.pumpAndSettle();

      expect(
        pinnedSymbolIds(doc),
        isEmpty,
        reason: 'the move and the pin are one write and one undo',
      );
    });

    testWidgets('a press on EMPTY PAPER is still the marquee, so the drag '
        'took nothing from the band', (tester) async {
      await pump(tester);
      // Far outside every symbol, which the fixture scene can confirm.
      final empty = DPt(
        reference.scene.bounds.right + 200,
        reference.scene.bounds.bottom + 200,
      );

      final gesture = await tester.startGesture(toScreen(tester, empty));
      await gesture.moveBy(const Offset(80, 60));
      await tester.pump();
      expect(ghost(), findsNothing, reason: 'nothing was grabbed');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(doc.sheets, isEmpty, reason: 'a band writes nothing');
    });
  });

  group('Ctrl+Shift+U gives a symbol back to the layout (§11.186.9)', () {
    testWidgets('it unpins what a drag pinned, and Tidy sheet can reach it '
        'again', (tester) async {
      await pump(tester);

      await dragSymbol(tester, 'MTX-1');
      expect(TidySheetCommand.wouldReflow(doc), 0, reason: 'pinned, so spared');

      await pressUnpin(tester);

      expect(pinnedSymbolIds(doc), isEmpty);
      expect(
        TidySheetCommand.wouldReflow(doc),
        1,
        reason: 'the whole reason this chord ships with the drag',
      );
      expect(controller.undo.undoLabelKey, LabelKey.unpinSymbol.name);
    });

    testWidgets('the symbol DOES NOT JUMP when it is released: it keeps its '
        'place until a Tidy moves it', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');

      await dragSymbol(tester, 'MTX-1');
      final dropped = buildFixtureScene(doc).positions[device.id];

      await pressUnpin(tester);

      expect(buildFixtureScene(doc).positions[device.id], dropped);
    });

    testWidgets('with nothing pinned in the selection it SAYS SO rather than '
        'falling through silently (docs/04 §3.4)', (tester) async {
      await pump(tester);
      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();

      await pressUnpin(tester);

      expect(find.textContaining('Nothing pinned'), findsOneWidget);
      expect(controller.undo.canUndo, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // THE ARROWS NUDGE (DR-187 §11.186.4 and §11.186.10, `#919`)
  // ═══════════════════════════════════════════════════════════════════
  // THE DISCRIMINATOR IS THE CARET AND NOT "A CONNECT IN FLIGHT", which
  // is what the clause first said and which cannot work: the arrows are
  // also how a pin is reached BEFORE anything is armed, so "no wire in
  // flight" is true for half of the connect route itself. A caret on
  // screen takes the arrows; `Esc` hands them back; `W` seeds a caret and
  // arms in one press, so the connect route keeps its entry.
  //
  // `schematic_keyboard_connect_test.dart` owns the other side of this
  // boundary and its `caretOnto` helper is what proves the route survived.
  group('the arrows nudge when no caret has them (§11.186.10)', () {
    Future<void> arrow(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    testWidgets('one press moves ONE grid unit and pins it (CR-068)', (
      tester,
    ) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final before = reference.positions[device.id]!;

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();
      await arrow(tester, LogicalKeyboardKey.arrowRight);

      expect(stored()[device.id], Pt(before.gx + 1, before.gy));
      expect(pinnedSymbolIds(doc), {device.id});
      expect(controller.undo.undoLabelKey, LabelKey.moveSymbol.name);
    });

    testWidgets('each direction moves its own way, which a transposed sign '
        'would not survive', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final before = reference.positions[device.id]!;

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();
      await arrow(tester, LogicalKeyboardKey.arrowDown);
      await arrow(tester, LogicalKeyboardKey.arrowDown);
      await arrow(tester, LogicalKeyboardKey.arrowLeft);

      // Two down, one left. A fixture whose deltas were equal could not
      // see a transposition, so they deliberately are not.
      expect(stored()[device.id], Pt(before.gx - 1, before.gy + 2));
    });

    testWidgets('A RUN OF PRESSES IS ONE UNDO ENTRY, so five nudges do not '
        'cost five Ctrl+Z', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');
      final before = reference.positions[device.id]!;

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await arrow(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(stored()[device.id], Pt(before.gx + 5, before.gy));

      controller.undoLast();
      await tester.pumpAndSettle();

      expect(
        doc.sheets,
        isEmpty,
        reason: 'one undo, and the document is the one that existed before',
      );
      expect(controller.undo.canUndo, isFalse);
    });

    testWidgets('and the REDO of a merged run lands on the same bytes, which '
        'is what carrying the ids across a merge buys', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await arrow(tester, LogicalKeyboardKey.arrowRight);
      }
      final itemIds = schematicSheetOf(doc)!.items.keys.toSet();
      final where = stored()[device.id];

      controller.undoLast();
      await tester.pumpAndSettle();
      controller.redoLast();
      await tester.pumpAndSettle();

      expect(schematicSheetOf(doc)!.items.keys.toSet(), itemIds);
      expect(stored()[device.id], where);
    });

    testWidgets('A CARET TAKES THE ARROWS BACK, which is the discriminator '
        'the whole clause rests on', (tester) async {
      await pump(tester);
      final device = deviceNamed(doc, 'MTX-1');

      await tester.tapAt(toScreen(tester, bodyCentre('MTX-1')));
      await tester.pumpAndSettle();
      // `W` seeds a caret on the selection and arms from it in one press.
      await arrow(tester, LogicalKeyboardKey.keyW);
      final frozen = stored();

      await arrow(tester, LogicalKeyboardKey.arrowDown);
      await arrow(tester, LogicalKeyboardKey.arrowDown);

      expect(
        stored(),
        frozen,
        reason: 'with a caret on screen the arrows move it, not the symbol',
      );
      expect(
        stored()[device.id],
        isNull,
        reason: 'the control: nothing was nudged at all',
      );
    });

    testWidgets('with NOTHING selected the arrows still seed a caret, so the '
        'key is never a silent no-op (docs/04 §3.4)', (tester) async {
      await pump(tester);

      // WHICH PIN IT SEEDS IS THE PRODUCT'S ANSWER, NOT THIS TEST'S:
      // `_seedCaret` falls back to the sheet's first located pin when
      // nothing is selected, so the citation is read off the same
      // function the screen uses rather than typed out here.
      final seeded = locatePins(reference).first.ref;
      final owner = doc.devices[Uuid(seeded.deviceId)]!.designator;

      await arrow(tester, LogicalKeyboardKey.arrowDown);

      expect(doc.sheets, isEmpty, reason: 'nothing to nudge, nothing moved');
      expect(
        find.textContaining(owner),
        findsWidgets,
        reason: 'the caret announced itself, which is the old behaviour',
      );
    });
  });
}
