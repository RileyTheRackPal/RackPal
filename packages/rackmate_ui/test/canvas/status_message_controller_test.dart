// Unit tests for StatusMessageController: show()/clear()/auto-hold timing.
// SemanticsService.announce is a platform channel call under the hood in a
// full Flutter binding, so these run under flutter_test's binding (which
// stubs platform channels) rather than plain `package:test`.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('show() sets text and notifies; clear() clears and notifies', () {
    final status = StatusMessageController();
    addTearDown(status.dispose);
    var notifications = 0;
    status.addListener(() => notifications++);

    status.show('Blocked by SW-1');
    expect(status.text, 'Blocked by SW-1');
    expect(notifications, 1);

    status.clear();
    expect(status.text, isNull);
    expect(notifications, 2);
  });

  test('clear() on an already-empty controller does not notify', () {
    final status = StatusMessageController();
    addTearDown(status.dispose);
    var notifications = 0;
    status.addListener(() => notifications++);

    status.clear();
    expect(notifications, 0);
  });

  test('a message auto-clears after its hold duration', () {
    fakeAsync((async) {
      final status = StatusMessageController(
        defaultHold: const Duration(milliseconds: 500),
      );
      addTearDown(status.dispose);

      status.show('Placed AMP-2 at RK-1 U19-U20, front');
      expect(status.text, isNotNull);

      async.elapse(const Duration(milliseconds: 499));
      expect(status.text, isNotNull); // not yet

      async.elapse(const Duration(milliseconds: 2));
      expect(status.text, isNull); // now cleared
    });
  });

  test('a second show() before the first hold elapses resets the timer '
      '(no premature clear)', () {
    fakeAsync((async) {
      final status = StatusMessageController(
        defaultHold: const Duration(milliseconds: 500),
      );
      addTearDown(status.dispose);

      status.show('first');
      async.elapse(const Duration(milliseconds: 300));
      status.show('second'); // resets the 500ms window
      async.elapse(const Duration(milliseconds: 300));
      expect(status.text, 'second'); // first window would have expired by now

      async.elapse(const Duration(milliseconds: 250));
      expect(status.text, isNull);
    });
  });

  test('a per-call hold overrides defaultHold', () {
    fakeAsync((async) {
      final status = StatusMessageController(); // default 3s hold
      addTearDown(status.dispose);

      status.show('quick', hold: const Duration(milliseconds: 50));
      async.elapse(const Duration(milliseconds: 60));
      expect(status.text, isNull);
    });
  });
}
