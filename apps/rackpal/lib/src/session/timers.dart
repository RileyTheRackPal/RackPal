// The time seam. Two typedefs and one tiny wrapper, and the reason they
// exist is a rule rather than a preference: NOTHING IN THIS LAYER SLEEPS.
//
// The autosave interval is 30 s and the geometry debounce is 500 ms.
// A test that proves "autosave fires when the document is dirty and skips
// when it is not" must not take 60 seconds, and a test that proves "a
// drag does not become 40 disk writes" must not be a race against a real
// 500 ms. So every duration in the session layer is scheduled through a
// [TimerFactory], production wires `Timer`, and tests wire a manual one
// they advance by hand.
//
// `dart:async`'s own `Timer` would almost do — but it cannot be advanced,
// and `fake_async` cannot be driven from inside a `testWidgets` body that
// also pumps frames. A two-method interface costs nothing and works in
// both.
import 'dart:async';

/// A scheduled callback that can be cancelled.
///
/// ONE METHOD, AND `one_member_abstracts` WAS SUPPRESSED RATHER THAN
/// OBEYED, until very_good_analysis 11 dropped the lint (DR-248) and the
/// ignore went with it. The argument stands for anyone tempted to
/// "simplify" this: the lint's advice (make it a top-level function) is right
/// for a callback and wrong for a HANDLE: the thing being modelled is an
/// object with identity and a lifetime, which a `void Function()` cannot
/// express without every holder inventing its own convention for "was
/// this already cancelled". Two implementations exist (`dart:async`'s
/// timer and the tests' manual one) and both are objects.
abstract interface class CancellableTimer {
  void cancel();
}

/// Schedules [callback] after [duration], once.
typedef TimerFactory =
    CancellableTimer Function(Duration duration, void Function() callback);

/// Schedules [callback] every [duration] until cancelled.
typedef PeriodicTimerFactory =
    CancellableTimer Function(Duration duration, void Function() callback);

final class _DartTimer implements CancellableTimer {
  _DartTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Production one-shot timer.
CancellableTimer productionTimerFactory(
  Duration duration,
  void Function() callback,
) => _DartTimer(Timer(duration, callback));

/// Production periodic timer.
CancellableTimer productionPeriodicTimerFactory(
  Duration duration,
  void Function() callback,
) => _DartTimer(Timer.periodic(duration, (_) => callback()));
