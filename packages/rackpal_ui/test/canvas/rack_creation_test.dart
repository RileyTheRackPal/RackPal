// M1 EXIT CLAUSE 2, END TO END: "a user opens the app, **creates a 42U
// rack**, populates it with 20 devices … using only the keyboard".
//
// docs/12-milestone-board.md §3.2 marked this NOT BUILT — "the user
// cannot", no rack-creation command existed anywhere, and the 42U rack was
// a default handed out by `Ctrl+N`. What this file tests is the whole
// keyboard path against the real screen: `Ctrl+Alt+N` (docs/04 §8's
// keymap) opens §9's dialog, `Enter` commits, the canvas SHOWS the rack
// that was just created, and the `/ query ⏎` loop then fills it.
//
// THE HALF THAT MATTERS MOST IS THE CANVAS. An `AddRackCommand` that
// mutates the document while the screen keeps drawing the old rack is a
// button whose result is invisible, which is worse than no button — so the
// header's designator is asserted after every switch, and the rack switcher
// is asserted to appear only once there is something to switch between.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';
import 'rack_scene_to_screen.dart';
import 'rack_with_palette.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

Widget _app() {
  final controller = DocumentController(buildDemoRackDocument());
  return MaterialApp(
    // DR-159 §11.158.3: undo and redo are GLOBAL bindings, so a
    // screen pumped without the root's map is a configuration
    // the product does not ship. See test/app_like.dart.
    shortcuts: appGlobalShortcuts(),
    home: Scaffold(
      body: RackWithPalette(
        controller: controller,
        canvas: (key, searchFocus, dragRow) => RackCanvasScreen(
          key: key,
          measurer: _FakeMeasurer(),
          controller: controller,
          paletteSearchFocus: searchFocus,
          paletteDragRow: dragRow,
        ),
      ),
    ),
  );
}

/// The demo document with its rack and devices removed — a rack-less
/// project, which is what a Blank project or an emptied file looks like and
/// the only starting point from which "create the FIRST rack" is reachable.
/// Built from the demo seed so the template snapshots the palette needs are
/// still there.
RackDocument _racklessDocument() => buildDemoRackDocument()
  ..racks.clear()
  ..devices.clear();

Future<void> _focusCanvas(WidgetTester tester) async {
  await tester.tapAt(emptyCanvasPoint(tester));
  await tester.pump();
}

/// docs/04 §8: "`Ctrl+Alt+U` / `Ctrl+Alt+N` — rack settings · new rack".
Future<void> _pressCtrlAltN(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Finder _dialogFields() => find.descendant(
  of: find.byType(NewRackDialog),
  matching: find.byType(TextField),
);

/// `Ctrl+Alt+N`, type a name, `Enter` — no pointer at any point.
Future<void> _createRackByKeyboard(
  WidgetTester tester, {
  required String name,
  int? heightU,
}) async {
  await _pressCtrlAltN(tester);
  expect(find.byType(NewRackDialog), findsOneWidget);
  await tester.enterText(_dialogFields().at(0), name);
  await tester.pump();
  if (heightU != null) {
    await tester.enterText(_dialogFields().at(1), '$heightU');
    await tester.pump();
    await tester.tap(_dialogFields().at(0));
    await tester.pump();
  }
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// The tooltip of whatever currently has focus, or null — how this file
/// asks "which control is the Tab ring on now" without reaching into
/// private state.
String? _focusedTooltip() {
  String? tip;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    final w = e.widget;
    if (w is Tooltip) {
      tip = w.message;
      return false;
    }
    return true;
  });
  return tip;
}

/// Tabs until [tooltip] has focus. Returns false if it never does — i.e.
/// the control is not reachable without a pointer, which is the thing
/// docs/04 §9 says must never be true ("No pointer-only affordance
/// exists").
Future<bool> _tabTo(
  WidgetTester tester,
  String tooltip, {
  int maxSteps = 40,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_focusedTooltip() == tooltip) return true;
  }
  return false;
}

/// One `/ query ⏎` cycle against whatever rack the canvas is showing.
Future<void> _cycle(WidgetTester tester, {String? query}) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.slash);
  await tester.pump();
  if (query != null) {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump();
  }
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('Ctrl+Alt+N creates a 42U rack and the canvas switches to it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _focusCanvas(tester);

    // The demo document's one rack, before anything happens.
    expect(find.text('RK-1'), findsOneWidget);

    await _createRackByKeyboard(tester, name: 'Equipment Room');

    // THE RACK EXISTS…
    expect(find.textContaining('Created RK-2'), findsWidgets);
    // …AND IT IS WHAT THE CANVAS IS SHOWING. The header reads the ACTIVE
    // rack's designator, name and height, so all three assertions are
    // about the same rack.
    expect(find.text('RK-2'), findsOneWidget);
    expect(find.text('Equipment Room'), findsOneWidget);
    expect(find.text('42U'), findsOneWidget);
    expect(find.text('RK-1'), findsNothing);
  });

  testWidgets('EACH RACK REMEMBERS WHERE IT WAS LEFT (DR-066)', (
    tester,
  ) async {
    // A viewport is a way of LOOKING at the document, so it lives on the
    // screen's state and nowhere else: not in the `.rmpj`, where a pan
    // would dirty a file under CR-117's byte round-trip, and not in
    // preferences, where a bad view would outlive the restart that is
    // currently how you escape one.
    //
    // ASSERTED THROUGH THE LIVE VIEWPORT, not through a remembered field.
    // The transform is what the canvas actually paints with, so a restore
    // that wrote the map and not the matrix cannot pass this.
    // `pumpAndSettle`, NOT `pump`: the opening frame-and-centre runs in a
    // post-frame callback (`#710`), so a single pump leaves it pending and
    // the pan below is captured and then silently overwritten by it.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Moved somewhere distinctive on the way in, then settled, so the
    // capture below is of a viewport nothing else is still about to touch.
    final viewport =
        tester
            .renderObject<RenderRackCanvas>(find.byType(RackCanvasBody))
            .viewport
          ..panBy(const Offset(-140, -55));
    await tester.pumpAndSettle();
    final onRk1 = viewport.transform.clone();

    await _createRackByKeyboard(tester, name: 'Equipment Room');
    expect(find.text('RK-2'), findsOneWidget);

    // RK-2 IS FRAMED ON ITS OWN TERMS, not handed RK-1's view. It is a 42U
    // rack where RK-1 is 12U, so the two cannot share a sensible framing.
    expect(
      viewport.transform.storage[12],
      isNot(closeTo(onRk1.storage[12], 0.001)),
      reason: 'RK-2 inherited RK-1 viewport',
    );

    // Move RK-2 somewhere else, so the restore below cannot pass by the
    // viewport simply never having moved.
    viewport.panBy(const Offset(60, 30));
    await tester.pumpAndSettle();

    // Back to RK-1 through the switcher the header only shows once there
    // is something to switch between.
    await tester.tap(find.byTooltip('Switch rack'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('RK-1').last);
    await tester.pumpAndSettle();

    expect(find.text('RK-1'), findsOneWidget);
    expect(
      viewport.transform.storage[12],
      closeTo(onRk1.storage[12], 0.001),
      reason: 'RK-1 did not come back to where it was left',
    );
    expect(
      viewport.transform.storage[13],
      closeTo(onRk1.storage[13], 0.001),
    );
  });

  testWidgets('the new rack starts empty: the demo devices belong to RK-1 '
      'and are not drawn on RK-2', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _focusCanvas(tester);

    expect(
      tester.allRenderObjects.whereType<RenderDeviceBox>(),
      isNotEmpty,
      reason: 'the demo rack has three devices',
    );

    await _createRackByKeyboard(tester, name: 'Equipment Room');

    expect(
      tester.allRenderObjects.whereType<RenderDeviceBox>(),
      isEmpty,
      reason:
          'a device placed in RK-1 must not appear on RK-2 — '
          'scene_builder.dart filters on placement.rackId',
    );
  });

  // WHY THE CARET IS DRIVEN OFF U1 FIRST. On a brand-new EMPTY rack the
  // caret path and the lowest-free-U fallback give the SAME answer — after
  // k 1U devices the lowest free U is U(k+1), which is exactly where the
  // caret has advanced to — so a loop that starts at U1 cannot tell the two
  // apart, and this test used to pass with the keep-typing fix removed. Six
  // ArrowUps put the caret at U7 with U1..U6 empty, and from there the two
  // mechanisms disagree on every single cycle.
  testWidgets('the keep-typing loop then populates the rack that was just '
      'created, AT THE CARET — the whole of clause 2 without a pointer '
      'after the first focus click', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _focusCanvas(tester);

    await _createRackByKeyboard(tester, name: 'Equipment Room');

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pump();

    await _cycle(tester, query: 'Blank Panel');
    expect(find.textContaining('at RK-2 U7'), findsWidgets);
    // THE KILL IS THIS LINE. Cycle 1 lands at U7 either way (nothing is
    // selected, so caret targeting is on for both mechanisms). Cycle 2 is
    // where they part: the caret says U8, lowest-free-U says U1.
    await _cycle(tester);
    expect(find.textContaining('at RK-2 U8'), findsWidgets);
    await _cycle(tester);
    expect(find.textContaining('at RK-2 U9'), findsWidgets);

    expect(
      tester.allRenderObjects.whereType<RenderDeviceBox>().length,
      3,
      reason: 'three placements, three device boxes, all on RK-2',
    );
  });

  testWidgets('undoing the creation puts the canvas back on RK-1 rather '
      'than crashing on a rack that is gone', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _focusCanvas(tester);

    await _createRackByKeyboard(tester, name: 'Equipment Room');
    expect(find.text('RK-2'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('RK-2'), findsNothing);
    expect(find.text('RK-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // THE 1 → 0 UNDO, which the 2 → 1 case above does not reach. Until the
  // rack-less panel grew a "New rack…" button there was no way for a
  // mounted canvas to end up with zero racks, and the `_rack` getter's own
  // doc comment asserted as much ("the only thing in this build that
  // removes a rack is undoing an add, which by construction leaves whatever
  // was there before"). Creating the FIRST rack of an empty document
  // falsifies that: "before" is nothing. `Ctrl+Z` then emptied `racks` and
  // the `rack` epoch listener threw `Bad state: No element` synchronously,
  // inside `undo`, before any ancestor could swap the panel back in.
  testWidgets('undoing the creation of the ONLY rack leaves an honest empty '
      'panel rather than throwing', (tester) async {
    final controller = DocumentController(_racklessDocument());
    final built =
        buildAddRackCommand(
              doc: controller.doc,
              name: 'Equipment Room',
              heightU: 42,
              now: DateTime.utc(2026, 7, 27),
              actor: 'local',
            )
            as AddRackReady;
    controller.run(built.command);

    await tester.pumpWidget(
      MaterialApp(
        // DR-159 §11.158.3: undo and redo are GLOBAL bindings, so a
        // screen pumped without the root's map is a configuration
        // the product does not ship. See test/app_like.dart.
        shortcuts: appGlobalShortcuts(),
        home: Scaffold(
          body: RackWithPalette(
            controller: controller,
            canvas: (key, searchFocus, dragRow) => RackCanvasScreen(
              key: key,
              measurer: _FakeMeasurer(),
              controller: controller,
              paletteSearchFocus: searchFocus,
              paletteDragRow: dragRow,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _focusCanvas(tester);
    expect(find.text('RK-1'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.doc.racks, isEmpty);
    // Not an empty rack canvas — rails and a ruler for a rack that is not
    // in the document is the lie `no_racks_view.dart` exists to prevent.
    expect(find.byType(NoRacksView), findsOneWidget);
    expect(find.text('RK-1'), findsNothing);

    // …and redo brings the rack, and the canvas, back. Driven through the
    // controller rather than `Ctrl+Shift+Z`: the canvas's `Shortcuts`
    // subtree is not mounted while the panel is showing, so there is no
    // keyboard undo/redo from here — a real gap, and a shell-level one
    // (`NoRacksView` has never had either), stated rather than papered over.
    controller.redoLast();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('RK-1'), findsOneWidget);
    expect(find.byType(NoRacksView), findsNothing);
  });

  group('the rack switcher', () {
    testWidgets('does not exist while there is one rack', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.byTooltip('Switch rack'), findsNothing);
    });

    testWidgets('appears with the second rack and switches back to the '
        'first', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await _createRackByKeyboard(tester, name: 'Equipment Room');
      expect(find.byTooltip('Switch rack'), findsOneWidget);

      await tester.tap(find.byTooltip('Switch rack'));
      await tester.pumpAndSettle();
      // The MENU ITEM, not the Text inside it: the item is the thing with a
      // tap target, and tapping the label's own rect lands outside it.
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<Uuid>,
          'RK-1 · Media Closet',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RK-1'), findsOneWidget);
      expect(find.text('RK-2'), findsNothing);
      expect(find.textContaining('Editing RK-1'), findsWidgets);
      // Switching BACK shows RK-1's own devices again.
      expect(
        tester.allRenderObjects.whereType<RenderDeviceBox>(),
        isNotEmpty,
      );
    });

    testWidgets('lists racks in the order the elevation sheets print them', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await _createRackByKeyboard(tester, name: 'Second');
      await _createRackByKeyboard(tester, name: 'Third');

      await tester.tap(find.byTooltip('Switch rack'));
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(CheckedPopupMenuItem<Uuid>),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(rows, [
        'RK-1 · Media Closet',
        'RK-2 · Second',
        'RK-3 · Third',
      ]);
    });
  });

  testWidgets('TWENTY devices into a rack the keyboard created, with one '
      'focus click and no other pointer event — M1 exit clause 2 and the '
      'populate half of clause 3', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await _focusCanvas(tester); // the one and only pointer event

    await _createRackByKeyboard(tester, name: 'Equipment Room');
    expect(find.text('42U'), findsOneWidget);

    // THE CARET IS DRIVEN TO U5 FIRST, AND THAT IS WHAT GIVES THIS TEST
    // TEETH. Starting at U1 on an empty rack, the caret path and the
    // lowest-free-U fallback produce the identical U1..U20 — so the
    // original version of this test passed with the keep-typing fix
    // reverted, proving only that twenty devices can be placed. From U5 the
    // two disagree from cycle 2 onward: the caret says U6, the fallback
    // says U1. The stated reason for the old assertion — "a fallback would
    // have refused the moment it hit an occupied U" — was also false: a
    // lowest-free-U search by construction never targets an occupied U.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pump();

    await _cycle(tester, query: 'Blank Panel');
    expect(find.textContaining('at RK-2 U5'), findsWidgets);
    for (var i = 0; i < 19; i++) {
      await _cycle(tester);
    }

    expect(
      tester.allRenderObjects.whereType<RenderDeviceBox>().length,
      20,
      reason: 'twenty `/ query ⏎` cycles, twenty devices',
    );
    // U5..U24, consecutively. The twenty-fourth U is unreachable by any
    // number of lowest-free-U placements from an empty rack (that path
    // fills U1 upward and would have ended at U20), so this is the
    // assertion that the caret drove every cycle.
    expect(find.textContaining('at RK-2 U24'), findsWidgets);
  });

  group('no pointer-only affordance (docs/04 §9)', () {
    testWidgets('every canvas control the drill needs is on the Tab ring', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      for (final tooltip in [
        'Rack actions',
        'Shrink the rack by 1U (hold to repeat)',
        'Grow the rack by 1U (hold to repeat)',
        'Fit the rack',
        'Reset view (100%)',
      ]) {
        expect(
          await _tabTo(tester, tooltip),
          isTrue,
          reason: '"$tooltip" is not reachable by Tab',
        );
      }
    });

    testWidgets('the rack switcher opens and switches from the keyboard '
        'alone', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);
      await _createRackByKeyboard(tester, name: 'Equipment Room');
      expect(find.text('RK-2'), findsOneWidget);

      expect(await _tabTo(tester, 'Switch rack'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(CheckedPopupMenuItem<Uuid>), findsNWidgets(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('RK-1'), findsOneWidget);
      expect(find.textContaining('Editing RK-1'), findsWidgets);
    });
  });

  testWidgets('the overflow menu offers New rack and names its shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.tap(find.byTooltip('Rack actions'));
    await tester.pumpAndSettle();

    expect(find.text('New rack…  (Ctrl+Alt+N)'), findsOneWidget);
    await tester.tap(find.text('New rack…  (Ctrl+Alt+N)'));
    await tester.pumpAndSettle();
    expect(find.byType(NewRackDialog), findsOneWidget);
  });
}
