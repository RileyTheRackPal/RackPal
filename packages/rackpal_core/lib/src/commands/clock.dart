// A tiny injectable clock so commands/DocumentController never call
// `DateTime.now()` directly — tests inject `FixedClock` and get
// reproducible, byte-comparable timestamps; production code gets
// `SystemClock`. Referenced but never formally defined in
// docs/03-architecture.md's `doc.clock.nowUtc()` sketch; this is this
// package's own fill-in for that elided piece.

/// Abstract source of "now", always UTC (matches `EntityMeta`'s
/// documented UTC/microsecond-precision contract).
// Deliberate injection seam, not an unnecessary abstraction: SystemClock
// and FixedClock below are two real, swappable implementations, not a
// single call site a top-level function would serve just as well.
abstract class Clock {
  const Clock();

  DateTime nowUtc();
}

/// The real clock, used everywhere outside tests.
final class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock that always returns the same instant — for deterministic
/// tests (`command_roundtrip_test.dart`, `epoch_mask_test.dart`).
final class FixedClock extends Clock {
  const FixedClock(this.fixed);

  final DateTime fixed;

  @override
  DateTime nowUtc() => fixed;
}

/// A clock a test can step forward between commands — what `FixedClock`
/// cannot provide, since it always returns the same instant no matter how
/// many commands run. `UndoStack.push`'s merge check
/// (`now.difference(top.at) < mergeWindow`) always compares `0 <
/// mergeWindow` under a `FixedClock`, which is true for ANY positive
/// window — proving nothing about the actual 400ms boundary. `MutableClock`
/// lets a test [advance] simulated time by a real `Duration` between two
/// `DocumentController.run()` calls, so it can exercise BOTH sides of the
/// merge window (just under it -> coalesce; just over it -> two entries)
/// without a real `Future.delayed`/sleep.
final class MutableClock extends Clock {
  MutableClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves the clock forward by [duration] (or backward, if negative).
  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
