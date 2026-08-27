// The window: the diffed title, the debounced geometry write, and the
// restore that must not open a window where the user cannot reach it.
//
// NOTHING HERE TALKS TO A DESKTOP. `WindowChrome` is an interface with a
// recording fake, and `validateRestoredBounds` is pure geometry over
// synthetic display rectangles — no real monitors, no window manager, no
// Flutter binding.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/app_services.dart';
import 'package:rackpal/src/session/window_chrome.dart';
import 'package:rackpal/src/storage/prefs_store.dart';

import 'session_fakes.dart';

const _hd = WindowBounds(left: 0, top: 0, width: 1920, height: 1080);
const _second = WindowBounds(left: 1920, top: 0, width: 1920, height: 1080);

void main() {
  group('WindowTitleWriter', () {
    test('writes once, then only when the string CHANGES', () async {
      final chrome = FakeWindowChrome();
      final writer = WindowTitleWriter(chrome);

      await writer.apply('Smith — RackPal');
      await writer.apply('Smith — RackPal');
      await writer.apply('Smith — RackPal');

      // The session recomputes the title on every change notification. A
      // 60 Hz drag must not become 60 platform-channel round trips.
      expect(chrome.titles, ['Smith — RackPal']);
      expect(writer.writeCount, 1);
    });

    test('a dirty marker appearing IS a change', () async {
      final chrome = FakeWindowChrome();
      final writer = WindowTitleWriter(chrome);

      await writer.apply('Smith — RackPal');
      await writer.apply('*Smith — RackPal');

      expect(chrome.titles, ['Smith — RackPal', '*Smith — RackPal']);
    });
  });

  group('WindowGeometryRecorder', () {
    Future<
      ({
        WindowGeometryRecorder recorder,
        ManualTimers timers,
        TestSession session,
      })
    >
    build() async {
      final t = await buildTestSession();
      return (
        recorder: t.services.geometry!,
        timers: t.timers,
        session: t,
      );
    }

    test('a drag schedules exactly ONE write, however many events it '
        'fires', () async {
      final f = await build();

      for (var i = 0; i < 40; i++) {
        f.recorder.onGeometryChanged();
      }

      // Each move event cancels the previous timer. Forty events, one
      // pending write.
      expect(f.timers.pending, hasLength(1));
      expect(f.timers.pending.single.duration, kGeometryDebounce);
      // AND AGAINST THE LITERAL. `WindowGeometryRecorder.debounce` defaults
      // to `kGeometryDebounce`, so the line above compares the constant to
      // itself and passes for any value at all — including one long enough
      // that a move followed by a quit never writes the geometry, and one
      // short enough that a drag becomes forty disk writes.
      expect(kGeometryDebounce, const Duration(milliseconds: 500));
    });

    test('the write lands after the debounce', () async {
      final f = await build();
      f.session.chrome
        ..maximized = false
        ..setHandler(null);
      await f.session.chrome.setBounds(
        const WindowBounds(left: 40, top: 60, width: 1400, height: 900),
      );

      f.recorder.onGeometryChanged();
      // `flush` is what the shutdown path calls; it cancels the pending
      // timer and performs the same write, awaited. Firing the timer
      // instead would leave an un-awaitable future behind it.
      await f.recorder.flush();

      final prefs = await PrefsStore(
        fs: f.session.fs,
        writer: f.session.services.controller.store.writer,
        dataRoot: kTestDataRoot,
        context: f.session.context,
      ).load();
      expect(prefs.window?.width, 1400);
      expect(prefs.maximized, isFalse);
    });

    test('flush writes an OWED geometry immediately', () async {
      final f = await build();
      f.recorder.onGeometryChanged();
      expect(f.recorder.hasPendingWrite, isTrue);

      await f.recorder.flush();

      // A debounced write with a pending timer at shutdown would simply
      // never happen, and the user's last resize would be lost every
      // single session.
      expect(f.recorder.hasPendingWrite, isFalse);
      expect(
        f.session.fs.state.files.containsKey(r'C:\data\prefs.json'),
        isTrue,
      );
    });

    test('flush with nothing owed is a no-op', () async {
      final f = await build();
      await f.recorder.flush();
      expect(
        f.session.fs.state.files.containsKey(r'C:\data\prefs.json'),
        isFalse,
      );
    });

    test('a MAXIMISED window keeps its restore-down rectangle', () async {
      final f = await build();
      await f.session.services.controller.stores!.prefs.save(
        const AppPrefs(
          window: WindowBounds(left: 10, top: 20, width: 1200, height: 800),
        ),
      );
      // NOTHING IS SYNCED BY HAND HERE ANY MORE. This used to read
      // `services.prefs = await stores.prefs.load()` — a synchronisation
      // production never performed, which is exactly why this suite was
      // green while `lastSaveDirectory` was being reverted on every
      // window move. `PrefsStore.save` above already moved
      // `PrefsStore.current`, which is what the recorder reads.
      f.session.chrome.maximized = true;
      await f.session.chrome.setBounds(_hd);
      f.recorder.onGeometryChanged();
      await f.recorder.flush();

      final prefs = await f.session.services.controller.stores!.prefs.load();
      // Unmaximising a restored window must put it back where the user
      // had it, not leave it filling the screen at a size it never had.
      expect(prefs.window?.width, 1200);
      expect(prefs.maximized, isTrue);
    });
  });

  group('validateRestoredBounds', () {
    test('a rectangle inside a display is kept', () {
      const saved = WindowBounds(
        left: 100,
        top: 100,
        width: 1400,
        height: 900,
      );
      expect(validateRestoredBounds(saved, const [_hd]), saved);
    });

    test('a rectangle on an UNPLUGGED monitor is refused', () {
      // The whole reason this function exists: otherwise the window
      // reopens at coordinates the user cannot reach, and the only remedy
      // a non-technical user has is to delete a file they do not know
      // about.
      const saved = WindowBounds(
        left: 2400,
        top: 200,
        width: 1200,
        height: 800,
      );
      expect(validateRestoredBounds(saved, const [_hd]), isNull);
    });

    test('...and is kept when that monitor is plugged back in', () {
      const saved = WindowBounds(
        left: 2400,
        top: 200,
        width: 1200,
        height: 800,
      );
      expect(validateRestoredBounds(saved, const [_hd, _second]), saved);
    });

    test('a window smaller than the minimum is grown', () {
      const saved = WindowBounds(left: 0, top: 0, width: 600, height: 400);
      final result = validateRestoredBounds(saved, const [_hd]);
      // §9.5: "a rack editor below ~1000 px wide is unusable".
      expect(result?.width, kMinWindowWidth);
      expect(result?.height, kMinWindowHeight);
    });

    test('a window larger than its display is clamped down and pulled '
        'inside', () {
      const saved = WindowBounds(
        left: 1000,
        top: 800,
        width: 4000,
        height: 3000,
      );
      final result = validateRestoredBounds(saved, const [_hd]);
      expect(result?.width, 1920);
      expect(result?.height, 1080);
      expect(result?.left, 0);
      expect(result?.top, 0);
    });

    test('an EMPTY display list is refused, not gambled on', () {
      // A display list we could not read and a display that is not there
      // are the same amount of knowledge.
      const saved = WindowBounds(left: 0, top: 0, width: 1200, height: 800);
      expect(validateRestoredBounds(saved, const []), isNull);
    });

    test('a sliver of overlap is not enough to count as reachable', () {
      // 100 px of the window's left edge is still on the display: 100 x
      // 800 = 80,000 px², well past the 100x100 of title bar a user needs
      // to be able to grab. Accepted, and pulled fully back on-screen.
      const barelyOn = WindowBounds(
        left: 1820,
        top: 0,
        width: 1200,
        height: 800,
      );
      expect(validateRestoredBounds(barelyOn, const [_hd]), isNotNull);

      // 1 x 1 of overlap in the far corner. There is nothing there to
      // grab, so this is refused and the caller centres.
      const almostOff = WindowBounds(
        left: 1919,
        top: 1079,
        width: 1200,
        height: 800,
      );
      expect(validateRestoredBounds(almostOff, const [_hd]), isNull);
    });
  });

  group('restoreWindowGeometry', () {
    test('sets the minimum size before anything else', () async {
      final chrome = FakeWindowChrome();
      await restoreWindowGeometry(chrome: chrome, prefs: const AppPrefs());
      expect(chrome.minimumSize?.width, kMinWindowWidth);
      expect(chrome.minimumSize?.height, kMinWindowHeight);
    });

    test('with no saved geometry it centres', () async {
      final chrome = FakeWindowChrome();
      await restoreWindowGeometry(chrome: chrome, prefs: const AppPrefs());
      expect(chrome.centerCalls, 1);
      expect(chrome.appliedBounds, isEmpty);
    });

    test('with usable geometry it applies it', () async {
      final chrome = FakeWindowChrome();
      await restoreWindowGeometry(
        chrome: chrome,
        prefs: const AppPrefs(
          window: WindowBounds(left: 10, top: 20, width: 1400, height: 900),
        ),
      );
      expect(chrome.centerCalls, 0);
      expect(chrome.appliedBounds.single.width, 1400);
    });

    test('with geometry on a vanished display it CENTRES rather than '
        'restoring off-screen', () async {
      final chrome = FakeWindowChrome();
      await restoreWindowGeometry(
        chrome: chrome,
        prefs: const AppPrefs(
          window: WindowBounds(
            left: 4000,
            top: 200,
            width: 1200,
            height: 800,
          ),
        ),
      );
      expect(chrome.centerCalls, 1);
      expect(chrome.appliedBounds, isEmpty);
    });

    test('maximised is restored AFTER the restore-down rectangle', () async {
      final chrome = FakeWindowChrome();
      await restoreWindowGeometry(
        chrome: chrome,
        prefs: const AppPrefs(
          window: WindowBounds(left: 10, top: 20, width: 1400, height: 900),
          maximized: true,
        ),
      );
      expect(chrome.appliedBounds, hasLength(1));
      expect(chrome.maximizeCalls, 1);
    });
  });
}
