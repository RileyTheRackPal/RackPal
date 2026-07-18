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
// ignore: one_member_abstracts
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
