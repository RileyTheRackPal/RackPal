// THE KEEP-TYPING LOOP, driven for real — docs/04-rack-editor.md §9's own
// measured path: "The measured keyboard-only path from launch to a
// populated 8-device rack is nine `/ query ⏎` cycles, roughly 25 seconds.
// That works because `Enter` from palette search places at the caret and
// advances it; it is worth protecting in every future change."
//
// WHY THIS FILE EXISTS. It did NOT work. `rack_canvas_screen.dart`
// documented the gap against itself — a freshly-placed device becomes the
// sole selection, a selection suppressed caret targeting, and no key
// cleared a selection — so the second `⏎` of any loop fell back to
// lowest-free-U. `docs/12-milestone-board.md` §3.2 clause 3 records the
// user performing the drill on 2026-07-27 and finding no full keyboard
// path. These tests are the regression net for the fix, and they are
// written to FAIL if either half of it is removed:
//
//   * remove `Esc`'s deselect and `caret survives Esc` fails;
//   * remove the just-placed-selection transparency and the three-cycle
//     loop lands its second and third devices at lowest-free-U instead of
//     at consecutive caret positions;
//   * remove the loop's lowest-free-U retry and the loop JAMS on the first
//     occupied U, placing one device and then refusing for ever;
//   * remove the refusal path's `requestFocus` and the canvas stops
//     answering the keyboard the moment a cycle is refused.
//
// NO WALL CLOCK IS INVOLVED. §9's "roughly 25 seconds" is a human
// measurement and a timing assertion here would be flaky and would prove
// nothing about the mechanism. What makes the drill possible is that
// consecutive placements land at CONSECUTIVE U — that is what is asserted.

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
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

// The screen's demo rack is 12U with UPS-1 @U1-2, AMP-1 @U4-5, SW-1 @U7,
// so its free 1U slots are U3, U6 and U8..U12 — and U3 is both the caret's
// smart default AND where a lowest-free-U fallback would put everything.
// That coincidence is what makes "did the caret drive this?" answerable by
// looking at where the devices landed.
const _geo = RackGeometry(12);

Offset _canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CanvasIntentDetector));

Offset _topLeftOf1U(WidgetTester tester, int ru) {
  final rect = _geo.deviceRect(ru, 1);
  return _canvasOrigin(tester) + Offset(rect.left, rect.top);
}

/// The screen-space centre of the [h]U device occupying [ru].
Offset _centreOf(WidgetTester tester, int ru, int h) {
  final rect = _geo.deviceRect(ru, h);
  return _canvasOrigin(tester) +
      Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2);
}

/// How many device boxes are rendering with their top-left at [ru]'s 1U
/// slot. Position, not id: the ids are freshly minted per placement.
int _devicesAt(WidgetTester tester, int ru) {
  final target = _topLeftOf1U(tester, ru);
  return tester.allRenderObjects
      .whereType<RenderDeviceBox>()
      .where((r) => (r.localToGlobal(Offset.zero) - target).distance < 0.5)
      .length;
}

RenderDeviceBox _render(WidgetTester tester, String id) =>
    tester.allRenderObjects.whereType<RenderDeviceBox>().firstWhere(
      (r) => r.deviceId == id,
    );

Widget _app() => MaterialApp(
  home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
);

/// A click on empty canvas — the only thing in this file that uses a
/// pointer, and only to establish the canvas focus a real user gets by
/// looking at the window. Every assertion after it is keyboard-driven.
Future<void> _focusCanvas(WidgetTester tester) async {
  await tester.tapAt(_canvasOrigin(tester) + const Offset(300, 400));
  await tester.pump();
}

/// ONE `/ query ⏎` CYCLE, as a keyboard user performs it.
///
/// [query] null re-uses whatever is already in the search box, which is
/// what makes the `/` press load-bearing: with no `enterText` to focus the
/// field, the only thing that can put focus back in it — and therefore the
/// only thing that can make `receiveAction` reach a live text client — is
/// the `/` binding itself.
Future<void> _cycle(WidgetTester tester, {String? query}) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.slash);
  await tester.pump();
  if (query != null) {
    await tester.enterText(find.byType(TextField), query);
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

  group('the keep-typing loop (docs/04 §9)', () {
    testWidgets('slash, type, Enter, Enter, Enter lands three devices at '
        'CONSECUTIVE caret positions, not three at lowest-free-U', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      // Drive the caret off its smart default (U3) to U8, so "the caret
      // drove this" and "the fallback drove this" have different answers.
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.pump();

      await _cycle(tester, query: 'Blank Panel');
      await _cycle(tester);
      await _cycle(tester);

      for (final ru in [8, 9, 10]) {
        expect(
          _devicesAt(tester, ru),
          1,
          reason:
              'cycle ${ru - 7} should have landed at U$ru — the caret '
              'position after ${ru - 8} advance(s)',
        );
      }
      // U3 is where EVERY one of them would be (well, the first; the rest
      // would stack at U6 and beyond) if the caret had been ignored. Its
      // emptiness is the negative half of the claim.
      expect(
        _devicesAt(tester, 3),
        0,
        reason: 'a lowest-free-U fallback would have filled U3 first',
      );
    });

    testWidgets('the loop needs no pointer between cycles: no tap happens '
        'after the first, and the caret still advances', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.pump();

      await _cycle(tester, query: 'Blank Panel');
      final afterFirst = _devicesAt(tester, 8);
      await _cycle(tester);
      final afterSecond = _devicesAt(tester, 9);

      expect(afterFirst, 1);
      expect(
        afterSecond,
        1,
        reason:
            'the second cycle is the one that used to fall back — see '
            'docs/12-milestone-board.md §3.2 clause 3',
      );
    });

    // WHAT THIS TEST DOES AND DOES NOT PROVE, corrected. It was called "a
    // click between cycles ENDS the transparency" and justified itself with
    // "if the transparency had survived the click, this would have aimed at
    // the caret's U4" — which is false. `_selectionIsLastQuickAdd` requires
    // the selection to BE the quick-added device, and this test selects a
    // different one (AMP-1), so the predicate is false whether or not the
    // window is still open. Mutation-checked: neutralising
    // `_forgetQuickAddSelection` so the window NEVER closes leaves this
    // test green and fails only its sibling below, which re-selects the
    // quick-added device by hand. That sibling is the transparency
    // window's guard; this one is the rule underneath it.
    testWidgets('a user selection of a DIFFERENT device suppresses caret '
        'targeting (docs/04 §3.4), so the next cycle uses lowest-free-U', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      // Cycle one at the caret's smart default, U3. The caret advances to
      // U4 — which AMP-1 occupies.
      await _cycle(tester, query: 'Blank Panel');
      expect(_devicesAt(tester, 3), 1);

      // A REAL selection, made by the user, of a device the placement did
      // not create. docs/04 §3.4: the caret conceptually does not exist
      // while something is selected.
      await tester.tapAt(
        _canvasOrigin(tester) +
            Offset(
              (_geo.deviceRect(4, 2).left + _geo.deviceRect(4, 2).right) / 2,
              (_geo.deviceRect(4, 2).top + _geo.deviceRect(4, 2).bottom) / 2,
            ),
      );
      await tester.pump();
      expect(_render(tester, 'dev-amp').selected, isTrue);

      await _cycle(tester);

      // Lowest free 1U with U3 now taken is U6, and — the part that IS
      // distinguishing — the caret is at U4, so a caret-targeted cycle
      // would have reported "Occupied by AMP-1" before landing anywhere.
      // Silence on that line is what says the caret was never consulted.
      expect(_devicesAt(tester, 6), 1);
      expect(find.textContaining('Occupied by'), findsNothing);
    });

    testWidgets('re-selecting the just-placed device by hand does NOT '
        'resume the transparency: a decision about what is selected is a '
        'decision, whichever device it names', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await _cycle(tester, query: 'Blank Panel'); // U3; caret → U4
      expect(_devicesAt(tester, 3), 1);

      // Clear, then deliberately click the SAME device the placement
      // selected. Membership alone cannot tell this apart from the
      // untouched post-placement state — only the fact that a selection
      // change happened in between can.
      await _focusCanvas(tester);
      await tester.tapAt(
        _canvasOrigin(tester) +
            Offset(
              (_geo.deviceRect(3, 1).left + _geo.deviceRect(3, 1).right) / 2,
              (_geo.deviceRect(3, 1).top + _geo.deviceRect(3, 1).bottom) / 2,
            ),
      );
      await tester.pump();

      await _cycle(tester);

      // Lowest free 1U is U6. Caret targeting would have aimed at U4 and
      // been refused by AMP-1.
      expect(_devicesAt(tester, 6), 1);
      expect(find.textContaining('Occupied by'), findsNothing);
    });

    // THE LOOP DOES NOT JAM ON A POPULATED RACK, and this is the case that
    // says so. The first version of the keep-typing fix turned the demo
    // rack into a one-shot: cycle 1 landed at U3, the caret advanced to U4
    // (AMP-1), and cycles 2, 3 and 4 were all refused with "Occupied by
    // AMP-1" because caret targeting stayed live and could no longer reach
    // the lowest-free-U fallback. That is worse than the behaviour it
    // replaced — which placed one device per cycle — and worse on the
    // everyday case of adding gear to a rack that already has some.
    testWidgets('a cycle whose caret lands on an occupied U says so AND '
        'keeps the loop going, at lowest-free-U', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      // Caret at U3 (the smart default), place → U3, caret advances to U4,
      // which AMP-1 occupies.
      await _cycle(tester, query: 'Blank Panel');
      expect(_devicesAt(tester, 3), 1);

      await _cycle(tester);
      // BOTH halves. The blocker is named — a redirect the user is not told
      // about is a silent redirect (docs/04 §3.4) — and the device is on
      // the rack, at §3.2's lowest fitting free U.
      expect(find.textContaining('Occupied by AMP-1'), findsWidgets);
      expect(
        _devicesAt(tester, 6),
        1,
        reason:
            'the cycle must place, not jam: U6 is the lowest free 1U '
            'once U3 is taken',
      );

      // …and the caret advanced past the fallback, so cycle 3 aims at U7
      // (SW-1), is redirected again to U8, and cycle 4 lands at U9 with
      // nothing in its way. Four cycles, four devices — which is what
      // "keep typing" means.
      await _cycle(tester);
      await _cycle(tester);
      expect(_devicesAt(tester, 8), 1);
      expect(_devicesAt(tester, 9), 1);
    });

    // THE OTHER HALF OF THE SAME RULE. The redirect above exists because
    // the SCREEN advanced the caret; when the USER puts the caret on an
    // occupied U and presses Enter, that is an aimed shot and the honest
    // answer is a refusal, not a device somewhere they did not point at.
    testWidgets('a caret the USER aimed at an occupied U refuses loudly and '
        'places nothing', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      // U3 (smart default) → U4, which AMP-1 occupies. Nothing is selected,
      // so this is not the keep-typing loop: it is a deliberate aim.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await _cycle(tester, query: 'Blank Panel');
      expect(find.textContaining('Occupied by AMP-1'), findsWidgets);
      expect(
        _devicesAt(tester, 3),
        0,
        reason: 'a refused placement must not quietly land somewhere else',
      );
      expect(
        _devicesAt(tester, 6),
        0,
        reason: 'nor anywhere else',
      );
    });

    // THE REFUSAL DOES NOT COST THE USER THEIR KEYBOARD. `Enter` from the
    // palette search box unfocuses it, and only the SUCCESS path used to
    // hand focus back to the canvas — so a refused quick-add left primary
    // focus on the route's modal scope, where Esc, the arrows and Tab all
    // did nothing and only a mouse click recovered. In a clause that is
    // about there being a full keyboard path, that is the whole defect.
    testWidgets('after a refusal the canvas still has the keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // caret → U4
      await tester.pump();
      await _cycle(tester, query: 'Blank Panel');
      expect(find.textContaining('Occupied by AMP-1'), findsWidgets);

      // The canvas answers a keyboard shortcut, with no pointer in between:
      // ArrowUp moves the caret off the blocked U, and the next cycle
      // places there. If focus had been lost, neither would happen.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.pump();
      await _cycle(tester);
      expect(
        _devicesAt(tester, 8),
        1,
        reason:
            'caret U4 + 4 = U8, reached with the keyboard alone after '
            'the refusal',
      );
    });
  });

  group('Esc clears the selection (docs/04 §8: "cancel drag, exit mode, '
      'clear selection")', () {
    testWidgets('a selected device is deselected, and it is reported', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tapAt(
        _canvasOrigin(tester) +
            Offset(
              (_geo.deviceRect(4, 2).left + _geo.deviceRect(4, 2).right) / 2,
              (_geo.deviceRect(4, 2).top + _geo.deviceRect(4, 2).bottom) / 2,
            ),
      );
      await tester.pump();
      expect(_render(tester, 'dev-amp').selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_render(tester, 'dev-amp').selected, isFalse);
      // "Never silently do nothing" cuts both ways: a mode change the user
      // cannot see is a mode change they cannot rely on.
      expect(find.textContaining('Selection cleared'), findsWidgets);
    });

    testWidgets('Esc gives the caret back at the position it had, so the '
        'next quick-add lands there rather than at lowest-free-U', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      // Caret U3 → U8.
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.pump();

      // Now make a REAL selection — the kind that legitimately suppresses
      // the caret (docs/04 §3.4) and that no placement created.
      await tester.tapAt(
        _canvasOrigin(tester) +
            Offset(
              (_geo.deviceRect(7, 1).left + _geo.deviceRect(7, 1).right) / 2,
              (_geo.deviceRect(7, 1).top + _geo.deviceRect(7, 1).bottom) / 2,
            ),
      );
      await tester.pump();
      expect(_render(tester, 'dev-sw').selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await _cycle(tester, query: 'Blank Panel');
      expect(
        _devicesAt(tester, 8),
        1,
        reason:
            'the caret is sticky, so Esc restores it at U8 — not at the '
            'smart default and not at lowest-free-U',
      );
      expect(_devicesAt(tester, 3), 0);
    });

    // ESC IS A CANCEL KEY BEFORE IT IS A DESELECT KEY, and the palette drag
    // is the case where that nearly went wrong invisibly. Its cancel lives
    // in a raw `HardwareKeyboard` hook whose `return true` does NOT stop the
    // `Shortcuts` dispatch — Flutter ORs the two verdicts — so one Esc used
    // to cancel the drag AND empty a selection the user had built before the
    // drag started, reporting "Selection cleared (2 devices)."
    testWidgets('Esc that cancels a palette drag does NOT also clear the '
        'selection the user built before it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // A deliberate two-device selection: AMP-1, then Ctrl+click SW-1.
      await tester.tapAt(_centreOf(tester, 4, 2));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapAt(_centreOf(tester, 7, 1));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_render(tester, 'dev-amp').selected, isTrue);
      expect(_render(tester, 'dev-sw').selected, isTrue);

      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.widgetWithText(ListTile, 'Blank Panel, 1U')),
      );
      await gesture.moveBy(const Offset(320, 0)); // past the drag slop
      await tester.pump();
      await gesture.moveTo(_centreOf(tester, 3, 1)); // a valid drop
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // The drag is cancelled…
      await gesture.up();
      await tester.pump();
      expect(_devicesAt(tester, 3), 0);
      // …and the selection survived it, exactly as it does for a cancelled
      // MOVE drag.
      expect(_render(tester, 'dev-amp').selected, isTrue);
      expect(_render(tester, 'dev-sw').selected, isTrue);
      expect(find.textContaining('Selection cleared'), findsNothing);

      // The latch that makes that true lasts ONE key event: the very next
      // Esc is an ordinary deselect again.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_render(tester, 'dev-amp').selected, isFalse);
      expect(
        find.textContaining('Selection cleared (2 devices)'),
        findsWidgets,
      );
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    });

    testWidgets('Esc with nothing selected and nothing in flight is a '
        'silent no-op, not a report', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await _focusCanvas(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.textContaining('Selection cleared'), findsNothing);
    });
  });
}
