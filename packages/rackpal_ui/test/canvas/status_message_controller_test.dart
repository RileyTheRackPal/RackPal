// Unit tests for StatusMessageController: show()/clear()/auto-hold timing.
// SemanticsService.sendAnnouncement is a platform channel call under the hood
// in a full Flutter binding, so these run under flutter_test's binding (which
// stubs platform channels) rather than plain `package:test`.

import 'dart:ui' show FlutterView;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// A view whose id is NOT the implicit view's, so an announcement that
/// reaches the channel carrying 7 was addressed to the view the owner
/// supplied and not sent by the deprecated implicit-view path (#946).
class _OtherView implements FlutterView {
  @override
  int get viewId => 7;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  FlutterView? implicit() => binding.platformDispatcher.implicitView;

  /// Every announcement map sent on the accessibility channel.
  List<Map<Object?, Object?>> heard() {
    final out = <Map<Object?, Object?>>[];
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          out.add(message['data']! as Map<Object?, Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () =>
          binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    return out;
  }

  test('an announcement is addressed to the view the owner supplies', () async {
    final said = heard();
    final status = StatusMessageController(view: _OtherView.new);
    addTearDown(status.dispose);

    status.show('Blocked by SW-1');
    await pumpEventQueue();

    expect(said, hasLength(1));
    expect(said.single['message'], 'Blocked by SW-1');
    expect(said.single['viewId'], 7);
  });

  test('an owner that is gone still updates the line and announces '
      'nothing', () async {
    final said = heard();
    final status = StatusMessageController(view: () => null);
    addTearDown(status.dispose);

    status.show('Placed AMP-2');
    await pumpEventQueue();

    expect(status.text, 'Placed AMP-2');
    expect(said, isEmpty);
  });

  test('show() sets text and notifies; clear() clears and notifies', () {
    final status = StatusMessageController(view: implicit);
    addTearDown(status.dispose);
    var notifications = 0;
    status
      ..addListener(() => notifications++)
      ..show('Blocked by SW-1');
    expect(status.text, 'Blocked by SW-1');
    expect(notifications, 1);

    status.clear();
    expect(status.text, isNull);
    expect(notifications, 2);
  });

  test('clear() on an already-empty controller does not notify', () {
    final status = StatusMessageController(view: implicit);
    addTearDown(status.dispose);
    var notifications = 0;
    status
      ..addListener(() => notifications++)
      ..clear();
    expect(notifications, 0);
  });

  test('a message auto-clears after its hold duration', () {
    fakeAsync((async) {
      final status = StatusMessageController(
        view: implicit,
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
        view: implicit,
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
      final status = StatusMessageController(view: implicit); // default 3s hold
      addTearDown(status.dispose);

      status.show('quick', hold: const Duration(milliseconds: 50));
      async.elapse(const Duration(milliseconds: 60));
      expect(status.text, isNull);
    });
  });
}
