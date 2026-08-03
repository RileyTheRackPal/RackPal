// Widget tests for docs/04-rack-editor.md §3.6's compaction preview, driven
// through the REAL affordance (the rack header's overflow menu) and REAL key
// events (`Enter` / `Esc`) against `RackCanvasScreen`'s own
// `DocumentController` — never by calling private methods.
//
// The demo rack is 12U with three FRONT devices — UPS-1 @U1 (2U), AMP-1 @U4
// (2U), SW-1 @U7 (1U) — and one REAR device, PP-1 @U9 (1U). So a Compact
// Down on the front face is a genuinely non-trivial proposal: UPS-1 is
// already at the bottom and stays, AMP-1 closes to U3, SW-1 closes to U5,
// freeing the 2U run that used to sit above SW-1.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

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

const _geo = RackGeometry(12);

Widget _app() => MaterialApp(
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

Offset _canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CanvasIntentDetector));

Finder _device(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byType(DeviceBox),
);

RenderDeviceBox _render(WidgetTester tester, String id) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().firstWhere(
      (r) => r.deviceId == id,
    );

/// The device's on-screen top edge, which is how these tests observe
/// "did it actually move" without reaching into the document.
double _topOf(WidgetTester tester, String id) =>
    tester.getTopLeft(_device(id)).dy;

double _expectedTop(WidgetTester tester, int ru, int deviceH) =>
    _canvasOrigin(tester).dy + _geo.deviceRect(ru, deviceH).top;

/// Opens the rack header's overflow menu and picks [item] — the affordance
/// §3.6's commands actually ship behind, since `Ctrl+B` stays RESERVED AND
/// UNBOUND (AC-045).
Future<void> _headerMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

/// "Is §3.6's floating bar on screen?", asked via its Apply button rather
/// than its label text. The label is deliberately NOT used: the post-apply
/// STATUS line reads "Compacted RK-1: 2 devices moved, 2U freed", which a
/// `textContaining('devices move')` finder happily matches — so a
/// bar-is-gone assertion written that way would fail for the right reason
/// but the wrong cause, and (worse) an equivalent bar-is-present assertion
/// would pass on the status line alone.
final Finder _barFinder = find.widgetWithText(FilledButton, 'Apply');

Future<void> _undo(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
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

  testWidgets('Compact Down opens a PREVIEW and commits nothing: the bar '
      'reads the spec sentence, the movers dim to 25%, and every device '
      'is still where it was', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final ampBefore = _topOf(tester, 'dev-amp');
    final swBefore = _topOf(tester, 'dev-sw');

    await _headerMenu(tester, 'Compact Down');

    // §3.6's floating bar, verbatim in shape. AMP-1 U4->U3 and SW-1 U7->U5,
    // freeing the 2U that used to sit above SW-1.
    expect(
      find.text('Compact Down — 2 devices move — 2U freed'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    // "current positions dimmed to 25%" — and ONLY the movers. UPS-1 is
    // already at U1 and is not part of the proposal, so dimming it would
    // claim the whole rack is about to change.
    //
    // ASSERTED AGAINST THE SPEC LITERAL, not against the constant that feeds
    // the render object. Written as
    // `expect(render.fadeOpacity, RenderDeviceBox.compactionSourceOpacity)`
    // — which is how it first shipped — both sides move together, so setting
    // the constant to 1.0 and deleting §3.6's dimming outright left the whole
    // rackmate_ui suite green. The literal is pinned once, here, and the
    // sibling 0.30 with it (rack_canvas_screen_test.dart asserts §3.3's drag
    // fade against the same constant, so the two must not silently swap).
    expect(
      RenderDeviceBox.compactionSourceOpacity,
      0.25,
      reason: "docs/04 §3.6: 'current positions dimmed to 25%'",
    );
    expect(
      RenderDeviceBox.dragSourceOpacity,
      0.30,
      reason: "docs/04 §3.3 step 1: 'drops to 30 % opacity in place'",
    );
    expect(_render(tester, 'dev-amp').fadeOpacity, 0.25);
    expect(_render(tester, 'dev-sw').fadeOpacity, 0.25);
    expect(_render(tester, 'dev-ups').fadeOpacity, isNull);

    // ...and the flag actually reaches the PIXELS. The drag case already has
    // this check (rack_canvas_screen_test.dart); without it here, a
    // regression that set `fadeOpacity` but stopped compositing it would
    // leave §3.6's movers at full strength and still pass everything above.
    for (final id in ['dev-amp', 'dev-sw']) {
      expect(
        _render(tester, id),
        paints..something((symbol, args) {
          if (symbol != #saveLayer) return false;
          final paint = args[1] as Paint;
          return (paint.color.a - 0.25).abs() < 1 / 255;
        }),
        reason: '$id must be composited through a 25%-alpha saveLayer',
      );
    }

    // "they never apply silently" — nothing has moved yet.
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
    expect(_topOf(tester, 'dev-sw'), closeTo(swBefore, 0.5));
  });

  testWidgets('Enter applies the preview as ONE undo entry — every device '
      'moves, and a single Ctrl+Z puts them all back', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final ampBefore = _topOf(tester, 'dev-amp');
    final swBefore = _topOf(tester, 'dev-sw');

    await _headerMenu(tester, 'Compact Down');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // The bar is gone and the devices really landed at the previewed U.
    expect(_barFinder, findsNothing);
    expect(
      _topOf(tester, 'dev-amp'),
      closeTo(_expectedTop(tester, 3, 2), 0.5),
    );
    expect(
      _topOf(tester, 'dev-sw'),
      closeTo(_expectedTop(tester, 5, 1), 0.5),
    );
    // Full opacity again — nothing is being previewed any more.
    expect(_render(tester, 'dev-amp').fadeOpacity, isNull);

    // §3.6: "Enter applies as one undo entry." TWO devices moved, so a
    // single Ctrl+Z restoring only one of them would be the bug this
    // asserts against.
    await _undo(tester);
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
    expect(_topOf(tester, 'dev-sw'), closeTo(swBefore, 0.5));
  });

  testWidgets('Esc cancels: nothing moves, and there is no undo entry to '
      'unwind', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final ampBefore = _topOf(tester, 'dev-amp');
    final swBefore = _topOf(tester, 'dev-sw');

    await _headerMenu(tester, 'Compact Down');
    expect(_barFinder, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(_barFinder, findsNothing);
    expect(_render(tester, 'dev-amp').fadeOpacity, isNull);
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));

    // A cancel that had quietly run (and then undone) commands would leave
    // an undo entry behind; pressing Ctrl+Z must find nothing to do.
    await _undo(tester);
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
    expect(_topOf(tester, 'dev-sw'), closeTo(swBefore, 0.5));
  });

  testWidgets('the Cancel button behaves exactly like Esc', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final ampBefore = _topOf(tester, 'dev-amp');

    await _headerMenu(tester, 'Compact Down');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();

    expect(_barFinder, findsNothing);
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
  });

  testWidgets('Compact Up packs toward the top and frees the bottom run', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await _headerMenu(tester, 'Compact Up');

    // Mirror of Compact Down: SW-1 -> U12, AMP-1 -> U10, UPS-1 -> U8, so
    // all three move and the whole 7U below U8 comes free.
    expect(
      find.text('Compact Up — 3 devices move — 7U freed'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      _topOf(tester, 'dev-sw'),
      closeTo(_expectedTop(tester, 12, 1), 0.5),
    );
    expect(
      _topOf(tester, 'dev-ups'),
      closeTo(_expectedTop(tester, 8, 2), 0.5),
    );
  });

  testWidgets('compacting an ALREADY-PACKED face is reported, not silently '
      'ignored (§3.4)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    // First Compact Down packs the front face...
    await _headerMenu(tester, 'Compact Down');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // ...so the second one has nothing to propose. No bar, and a real
    // message — "never silently do nothing".
    await _headerMenu(tester, 'Compact Down');
    expect(_barFinder, findsNothing);
    expect(find.textContaining('Nothing to compact'), findsOneWidget);
  });

  testWidgets('a document edit under an open preview CANCELS it — the plan '
      'is stale and must never be applied', (tester) async {
    // Regression coverage for the bug class this file's own history is full
    // of (two stale-`Timer` bugs in the drag gestures). A plan holds
    // `fromRuIndex` values captured at plan time; if the document moves
    // underneath, applying it would issue MoveDeviceCommands whose "from"
    // is a fabrication — and `revert()` would faithfully restore devices to
    // positions they were never in, so the corruption would SURVIVE an undo.
    await tester.pumpWidget(_app());
    await tester.pump();

    // Make an edit there is something to undo: nudge SW-1 up one U.
    await tester.tapAt(
      _canvasOrigin(tester) +
          Offset(
            (_geo.deviceRect(7, 1).left + _geo.deviceRect(7, 1).right) / 2,
            (_geo.deviceRect(7, 1).top + _geo.deviceRect(7, 1).bottom) / 2,
          ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      _topOf(tester, 'dev-sw'),
      closeTo(_expectedTop(tester, 8, 1), 0.5),
    );

    await _headerMenu(tester, 'Compact Down');
    expect(_barFinder, findsOneWidget);
    final ampBefore = _topOf(tester, 'dev-amp');

    // Undo the nudge WHILE the preview is open.
    await _undo(tester);

    expect(
      _barFinder,
      findsNothing,
      reason:
          'a plan computed against a since-changed document must not '
          'stay applicable',
    );
    expect(find.textContaining('preview cancelled'), findsOneWidget);
    expect(_render(tester, 'dev-amp').fadeOpacity, isNull);

    // And Enter now does nothing at all — the action is disabled.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_topOf(tester, 'dev-amp'), closeTo(ampBefore, 0.5));
  });

  testWidgets('beginning a canvas gesture cancels an open preview rather '
      'than layering two of them', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await _headerMenu(tester, 'Compact Down');
    expect(_barFinder, findsOneWidget);

    // A plain click on the canvas is a new interaction. Aimed WELL clear of
    // the floating chrome (the zoom HUD sits at 12,12 and would otherwise
    // swallow the tap) and clear of every device.
    await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 500));
    await tester.pump();

    expect(_barFinder, findsNothing);
    expect(_render(tester, 'dev-amp').fadeOpacity, isNull);
  });

  testWidgets('bare Enter FALLS THROUGH when no preview is open, and is '
      'consumed only when one is', (tester) async {
    // The real hazard of binding `Enter` bare at screen level: the palette
    // search box and every focusable palette row live inside the SAME
    // `Shortcuts` subtree, and docs/04 §3.2's headline flow is "type, press
    // Enter". A `CallbackAction` returning null would still report the key
    // as HANDLED — `ShortcutManager` consults `isActionEnabled`, not the
    // return value — and would silently eat `Enter` app-wide forever.
    //
    // WHAT THIS TEST HAD TO BECOME, and why. It first asserted the palette
    // flow end-to-end (type a query, `receiveAction(done)`, expect a device
    // placed) — and a deliberate mutation making `isActionEnabled` return
    // `true` unconditionally did NOT fail it. It could not: `receiveAction`
    // drives the TEXT INPUT channel, never the key-event path, so the
    // screen's `Shortcuts` layer was not in the loop at all. The assertion
    // was true but vacuous about the thing it claimed to protect.
    //
    // "Handled vs ignored" is only observable if something else is waiting
    // for the key, so this wraps the screen in an ANCESTOR `Focus` that
    // counts `Enter`. Key events propagate from the focused node UPWARD, so
    // the ancestor sees the key exactly when the screen's `Shortcuts` layer
    // declines it — which is the property under test, stated directly.
    var enterReachedAncestor = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            canRequestFocus: false,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                enterReachedAncestor++;
              }
              return KeyEventResult.ignored;
            },
            child: RackCanvasScreen(measurer: _FakeMeasurer()),
          ),
        ),
      ),
    );
    await tester.pump();

    // Canvas focused, NO preview: the binding must decline the key.
    await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 500));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      enterReachedAncestor,
      1,
      reason:
          'with no preview open the Apply action must be DISABLED, so '
          'the key falls through to whatever else wants it',
    );

    // Preview open: now the same key is legitimately consumed.
    await _headerMenu(tester, 'Compact Down');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      enterReachedAncestor,
      1,
      reason: 'an open preview claims Enter — it must not also bubble',
    );
    expect(_barFinder, findsNothing, reason: 'and it really applied');
  });

  testWidgets("the palette's own type-and-Enter placement still works with "
      'the compaction binding in place', (tester) async {
    // The end-to-end companion to the test above: docs/04 §3.2's "populate
    // a rack by pure typing" flow, unbroken. Kept deliberately even though
    // it cannot discriminate the `isActionEnabled` mechanism (see that
    // test's own note), because it is the user-visible behaviour that
    // mechanism exists to protect.
    await tester.pumpWidget(_app());
    await tester.pump();

    final before = tester.allRenderObjects.whereType<RenderDeviceBox>().length;

    await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 500));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'switch');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      tester.allRenderObjects.whereType<RenderDeviceBox>().length,
      greaterThan(before),
    );
  });
}
