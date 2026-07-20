// docs/04-rack-editor.md §4.1's FIRST way to change rack height — the header
// stepper and its "hold to repeat at 8/s after 400 ms".
//
// Driven through REAL pointer gestures against the real `RackHeaderBar`, with
// real timer advancement via `tester.pump(duration)` — never by calling the
// private state's methods. The multi-pointer case uses two genuinely distinct
// `TestGesture`s, because the defect it covers is invisible to a single one:
// the state used to cancel its timers on ANY pointer-up.
//
// WHICH TESTS HERE ARE ABOUT TIMING, stated because getting this wrong is
// how the numbers went unpinned once already. EXACTLY TWO are:
//
//   * the spec-literal test, which pins the two public CONSTANTS to §4.1's
//     own "8/s after 400 ms"; and
//   * the measuring test, which pins what the widget's TIMERS actually run
//     at, by advancing the clock in 1ms literals and solving for the delay
//     and the period. It never mentions either constant.
//
// Every OTHER test in this file is timing-AGNOSTIC by construction and pumps
// by `holdRepeatDelay`/`holdRepeatPeriod` purely to reach the next tick. Those
// pumps are self-referential — they advance the clock by whatever value drives
// the timer — and are deliberately not evidence about the numbers. Do not add
// a timing claim to one of them; add it to the measuring test.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The stepper's `-` button. `Icons.remove` is unique in this widget.
final Finder _minus = find.byIcon(Icons.remove);

/// Records every step and always permits the repeat to continue, so these
/// tests observe the TIMING rather than the screen's refusal logic.
({List<int> steps, RackHeightStep onStep}) _recorder() {
  final steps = <int>[];
  return (
    steps: steps,
    onStep: (int delta) {
      steps.add(delta);
      return true;
    },
  );
}

/// Records every step and REFUSES the repeat from the [refuseFrom]'th step
/// onward — the screen's own answer when a step opened §4.1's shrink modal
/// or the height did not change (see [RackHeightStep]).
({List<int> steps, RackHeightStep onStep}) _refusingAfter(int refuseFrom) {
  final steps = <int>[];
  return (
    steps: steps,
    onStep: (int delta) {
      steps.add(delta);
      return steps.length < refuseFrom;
    },
  );
}

Widget _app(RackHeightStep onStep) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RackHeaderBar(
        designator: 'RK-1',
        name: 'Media Closet',
        heightU: 12,
        onHeaderTap: () {},
        onAction: (_) {},
        onStep: onStep,
      ),
    ),
  ),
);

void main() {
  test("the hold-repeat timings ARE §4.1's own two numbers, and the period "
      'spells the same rate the spec states in hertz', () {
    // The spec sentence is "hold to repeat at 8/s after 400 ms". Asserted
    // against those literals rather than against the constants themselves,
    // so this cannot drift along with the production values it pins.
    expect(RackHeaderBar.holdRepeatDelay, const Duration(milliseconds: 400));
    expect(RackHeaderBar.holdRepeatPeriod, const Duration(milliseconds: 125));
    expect(
      const Duration(seconds: 1).inMicroseconds /
          RackHeaderBar.holdRepeatPeriod.inMicroseconds,
      8,
      reason: "the period must spell §4.1's 8/s exactly",
    );
  });

  testWidgets('a held stepper fires once immediately, and the delay and '
      'period the TIMERS actually run at MEASURE to 400ms and 125ms', (
    tester,
  ) async {
    // WHY THIS MEASURES RATHER THAN BRACKETS. The predecessor pumped
    // `399ms` then `2ms` and asserted "still one step" after each, then
    // pumped `RackHeaderBar.holdRepeatPeriod` twice. Both halves were
    // toothless:
    //
    //   * The delay was only bracketed into roughly (280ms, 401ms]. Wiring
    //     the widget's `Timer` to a literal `Duration(milliseconds: 300)`
    //     while leaving the public constant at 400 — the stepper then
    //     repeating 100ms early on every hold — passed, because with a
    //     300ms delay the periodic's FIRST tick is at 425ms and both
    //     probes land before it.
    //   * The period half pumped by `holdRepeatPeriod` itself, so it
    //     advanced the clock by whatever value drove the timer. Mutate the
    //     constant to 250ms and this test still passes; only the
    //     spec-literal test above notices, and that one pins the CONSTANT,
    //     not the timer's use of it.
    //
    // So: advance in 1ms LITERALS, record the clock reading at which each
    // repeat lands, and solve for both figures. Nothing below mentions
    // `holdRepeatDelay` or `holdRepeatPeriod`, which is the point — this
    // test cannot drift along with the values it pins, and together with
    // the spec-literal test above it closes the loop (that one says the
    // constants are §4.1's numbers; this one says the timers use them).
    final rec = _recorder();
    await tester.pumpWidget(_app(rec.onStep));

    final hold = await tester.startGesture(tester.getCenter(_minus));
    // "The FIRST step is immediate" — §4.1's 400ms governs the REPEAT.
    expect(rec.steps, [-1]);

    const tick = Duration(milliseconds: 1);
    const horizonMs = 1500;
    final firedAtMs = <int>[];
    for (var t = 1; t <= horizonMs && firedAtMs.length < 3; t++) {
      final before = rec.steps.length;
      await tester.pump(tick);
      if (rec.steps.length > before) firedAtMs.add(t);
    }

    expect(
      firedAtMs,
      hasLength(3),
      reason: 'a held stepper produced ${firedAtMs.length} repeats in '
          '${horizonMs}ms (at $firedAtMs). Either the repeat never armed, '
          'or its period is far longer than §4.1 allows',
    );

    // The first repeat lands one PERIOD after the delay elapses (the delay
    // timer only arms the periodic; it does not step), so the second and
    // third readings give the period and the first then gives the delay.
    final periodMs = firedAtMs[1] - firedAtMs[0];
    final delayMs = firedAtMs[0] - periodMs;

    expect(
      firedAtMs[2] - firedAtMs[1],
      periodMs,
      reason: 'the repeat is not evenly spaced: $firedAtMs',
    );
    expect(
      delayMs,
      400,
      reason: 'the hold-repeat began ${delayMs}ms after pointer-down; §4.1 '
          'says 400ms. Steps landed at $firedAtMs',
    );
    expect(
      periodMs,
      125,
      reason: 'the repeat ran at ${1000 / periodMs}/s; §4.1 says 8/s. '
          'Steps landed at $firedAtMs',
    );
    expect(rec.steps, [-1, -1, -1, -1]);

    await hold.up();
    await tester.pump();
    final afterRelease = rec.steps.length;
    await tester.pump(const Duration(seconds: 1));
    expect(rec.steps.length, afterRelease, reason: 'release stops the repeat');
    await tester.pumpAndSettle();
  });

  testWidgets('THE HOLD BELONGS TO THE POINTER THAT BEGAN IT: a second finger '
      'neither steps nor restarts the countdown, and lifting that second '
      "finger does not kill the first finger's repeat", (tester) async {
    final rec = _recorder();
    await tester.pumpWidget(_app(rec.onStep));

    final centre = tester.getCenter(_minus);

    // Finger A claims the hold and takes the immediate step.
    final fingerA = await tester.startGesture(centre, pointer: 1);
    expect(rec.steps, [-1]);

    // 200ms into A's 400ms countdown, finger B lands on the same button.
    await tester.pump(const Duration(milliseconds: 200));
    final fingerB = await tester.startGesture(centre, pointer: 2);
    expect(
      rec.steps,
      [-1],
      reason: 'B must not fire a second, unrequested 1U step',
    );

    // B lifts while A is still physically down. THIS is the pointer-up that
    // used to cancel A's timers.
    await fingerB.up();
    await tester.pump();
    expect(rec.steps, [-1]);

    // A's countdown must still be the one that started 200ms ago — NOT
    // restarted by B's press. 201ms more reaches 401ms since A went down.
    await tester.pump(const Duration(milliseconds: 201));
    expect(
      rec.steps,
      [-1],
      reason: 'the delay has only just elapsed; the periodic has not ticked',
    );

    // And the repeat A armed is still alive under A's finger.
    await tester.pump(RackHeaderBar.holdRepeatPeriod);
    expect(
      rec.steps,
      [-1, -1],
      reason: "B's lift must not have cancelled A's hold-repeat",
    );

    await fingerA.up();
    await tester.pump();
    final afterRelease = rec.steps.length;
    await tester.pump(const Duration(seconds: 1));
    expect(
      rec.steps.length,
      afterRelease,
      reason: 'the owning pointer released, so the repeat stops',
    );
    await tester.pumpAndSettle();
  });

  group("§4.1's MODAL-STORM guard: a refused step stops the repeat dead", () {
    testWidgets('a refusal on the FIRST press never arms the repeat at all — '
        'a held stepper ratcheting into occupied territory must not open one '
        'modal per 125ms tick', (tester) async {
      // The screen answers false when the step it just handled opened the
      // shrink modal. Refusing immediately is the realistic case: the very
      // first `-1` is already blocked by an occupant.
      final rec = _refusingAfter(1);
      await tester.pumpWidget(_app(rec.onStep));

      final hold = await tester.startGesture(tester.getCenter(_minus));
      expect(rec.steps, [-1], reason: 'the first step still happens');

      // Well past the 400ms delay and many periods beyond it. Without the
      // guard this is ~8 modals per second for as long as the finger rests.
      await tester.pump(const Duration(seconds: 2));
      expect(
        rec.steps,
        [-1],
        reason: 'a refused first step must not arm the repeat',
      );

      await hold.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a refusal MID-REPEAT cancels the periodic, and the finger '
        'staying down does not restart it', (tester) async {
      // The other half: the hold ratchets down freely for a while and only
      // then hits the occupant. Three steps are permitted; the fourth tick
      // is refused and must be the last.
      final rec = _refusingAfter(4);
      await tester.pumpWidget(_app(rec.onStep));

      final hold = await tester.startGesture(tester.getCenter(_minus));
      expect(rec.steps, [-1]);

      await tester.pump(RackHeaderBar.holdRepeatDelay);
      await tester.pump(RackHeaderBar.holdRepeatPeriod);
      expect(rec.steps, [-1, -1]);
      await tester.pump(RackHeaderBar.holdRepeatPeriod);
      expect(rec.steps, [-1, -1, -1]);

      // The refusing tick fires (the step IS attempted — the modal opening
      // in that instant is the feedback) and then stops everything.
      await tester.pump(RackHeaderBar.holdRepeatPeriod);
      expect(rec.steps, hasLength(4));

      await tester.pump(const Duration(seconds: 2));
      expect(
        rec.steps,
        hasLength(4),
        reason: 'the repeat stopped dead at the first tick that could not '
            'proceed, and a still-held finger does not resurrect it',
      );

      await hold.up();
      await tester.pumpAndSettle();
    });

    testWidgets('and the refused hold stays claimed: a SECOND finger cannot '
        're-trigger the refused step while the first is still down', (
      tester,
    ) async {
      // `_stop()` deliberately does not release the pointer slot. Without
      // that, the modal-storm guard would be defeated by a second contact —
      // one refused step, one modal, per extra touch.
      final rec = _refusingAfter(1);
      await tester.pumpWidget(_app(rec.onStep));

      final centre = tester.getCenter(_minus);
      final fingerA = await tester.startGesture(centre, pointer: 1);
      expect(rec.steps, [-1]);

      final fingerB = await tester.startGesture(centre, pointer: 2);
      await tester.pump();
      expect(
        rec.steps,
        [-1],
        reason: 'the slot is still claimed by the refused hold',
      );

      await fingerB.up();
      await fingerA.up();
      await tester.pumpAndSettle();
    });
  });

  group('the double-fire latch', () {
    testWidgets('ONE physical tap is ONE step, even though the Listener and '
        "the IconButton's tap recogniser both fire on the same pointer-up", (
      tester,
    ) async {
      // `_pointerActivated` exists precisely because a pointer tap reaches
      // BOTH this `Listener`'s pointer-down and, eventually,
      // `IconButton.onPressed`. Without the latch a single click on `-`
      // shrinks the rack by 2U.
      final rec = _recorder();
      await tester.pumpWidget(_app(rec.onStep));

      await tester.tap(_minus);
      await tester.pumpAndSettle();

      expect(rec.steps, [-1]);
    });

    testWidgets('the latch SELF-HEALS: after a tap, keyboard activation still '
        'produces exactly one step', (tester) async {
      // The latch is cleared in a post-frame callback, unconditionally, so
      // the press-then-drag-off case (where `onPressed` never arrives) does
      // not leave it stuck and swallow the next activation. A stuck latch
      // would make the button silently dead to Space/Enter forever after.
      final rec = _recorder();
      await tester.pumpWidget(_app(rec.onStep));

      await tester.tap(_minus);
      await tester.pumpAndSettle();
      expect(rec.steps, [-1]);

      // Keyboard activation of the focused IconButton — the path a bare
      // `Listener` would have thrown away, and the one a stuck latch would
      // swallow. `Focus.of` on the icon's own element resolves the
      // IconButton's internal focus node, so this is the real widget's real
      // focus, not a node the test invented.
      Focus.of(tester.element(_minus)).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        rec.steps,
        [-1, -1],
        reason: 'the post-frame clear re-opened the keyboard path',
      );
    });
  });
}
