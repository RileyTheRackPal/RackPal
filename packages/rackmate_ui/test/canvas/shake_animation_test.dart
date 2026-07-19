// Unit tests for the shared shake animation: the pure decaying-oscillation
// curve (shakeOffsetAt) and ShakeController's per-id targeting.

import 'package:flutter/widgets.dart' show Offset, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart' show Uuid;
import 'package:rackmate_ui/rackmate_ui.dart';

const _vsync = TestVSync();

void main() {
  group('shakeOffsetAt (pure curve)', () {
    test('is zero at t=0 and t=1 -- no residual offset at either edge', () {
      expect(shakeOffsetAt(0), Offset.zero);
      expect(shakeOffsetAt(1), Offset.zero);
    });

    test('is zero outside [0, 1]', () {
      expect(shakeOffsetAt(-0.5), Offset.zero);
      expect(shakeOffsetAt(1.5), Offset.zero);
    });

    test('is nonzero somewhere in the middle of the animation', () {
      final mid = shakeOffsetAt(0.15); // default amplitude (3)
      expect(mid.dx.abs(), greaterThan(0));
      expect(mid.dy, 0); // horizontal-only shake
    });

    test('amplitude scales the peak displacement', () {
      final small = shakeOffsetAt(0.15, amplitude: 1);
      final big = shakeOffsetAt(0.15, amplitude: 10);
      expect(big.dx.abs(), greaterThan(small.dx.abs()));
    });
  });

  testWidgets('ShakeController drives an offset only for its current '
      'target id', (tester) async {
    // A trivial widget so the test binding is actively pumping frames —
    // `AnimationController.forward()` schedules ticks through
    // `SchedulerBinding`, which only advances via `tester.pump()` once a
    // widget tree exists.
    await tester.pumpWidget(const SizedBox());
    final shake = ShakeController(vsync: _vsync);
    addTearDown(shake.dispose);

    const a = Uuid('device-a');
    const b = Uuid('device-b');

    expect(shake.offsetFor(a), Offset.zero); // nothing triggered yet

    shake.trigger(a);
    // A ticker's FIRST tick after `.forward()` only establishes its t=0
    // baseline (Flutter's own `Ticker` semantics) — an empty pump primes
    // that baseline so the NEXT timed pump measures real elapsed time.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(shake.offsetFor(a), isNot(Offset.zero));
    expect(shake.offsetFor(b), Offset.zero); // b was never the target

    // Let the 120ms animation run to completion.
    await tester.pump(const Duration(milliseconds: 200));
    expect(shake.offsetFor(a), Offset.zero);
  });

  testWidgets('retriggering mid-shake restarts from full amplitude', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final shake = ShakeController(vsync: _vsync);
    addTearDown(shake.dispose);
    const a = Uuid('device-a');

    shake.trigger(a);
    await tester.pump(); // prime the ticker baseline
    await tester.pump(const Duration(milliseconds: 100)); // near the end
    shake.trigger(a); // re-trigger
    await tester.pump(); // re-prime after the restart
    // Restarted: right at its own new t=0, offsetFor is (by construction
    // of shakeOffsetAt) zero — the assertion that matters is that it did
    // NOT stay near the near-complete value it had before retriggering.
    expect(shake.offsetFor(a), Offset.zero);

    await tester.pump(const Duration(milliseconds: 30));
    expect(shake.offsetFor(a), isNot(Offset.zero));

    // Let the animation finish before the test ends, so no Ticker is left
    // running when the widget tree tears down.
    await tester.pump(const Duration(milliseconds: 200));
  });
}
