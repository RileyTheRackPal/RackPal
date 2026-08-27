// The `window_manager` seam: the title, the minimum size, the geometry,
// and — the only genuinely load-bearing one — `setPreventClose`.
//
// ==================================================================
// WHY `setPreventClose` IS THE WHOLE REASON THIS DEPENDENCY EXISTS
// ==================================================================
// Without it the OS destroys the window and THEN Flutter finds out. The
// three-button Save / Don't Save / Cancel prompt cannot exist at all,
// because by the time anything could ask, the answer no longer matters.
// §10.1 says as much in its own fallback note: "the only load-bearing API
// is setPreventClose + the close event: ~80 lines of Win32 platform
// channel". Everything else here is convenience.
//
// ==================================================================
// AN INTERFACE WITH A FAKE, NOT A DIRECT CALL
// ==================================================================
// Every flow that matters — close-while-dirty, the dirty marker in the
// title, restoring a window onto a monitor that has been unplugged — is
// otherwise only testable by having a real window on a real desktop. So
// the app talks to [WindowChrome], `WindowManagerChrome` is the one
// implementation that talks to the plugin, and the tests supply a fake
// that records calls. `test/session/session_layering_test.dart` asserts
// `package:window_manager` is imported by this file and no other.
//
// ==================================================================
// TWO THINGS THIS FILE DOES NOT DO
// ==================================================================
//  * IT DOES NOT PERSIST ANYTHING. Window geometry goes into our own
//    `prefs.json` through `PrefsStore`. `window_manager` stores no state
//    itself, and that is one of the three things behind the portable
//    build's "RackPal writes only into its own folder" claim. The second
//    is that the data root is a folder beside the executable
//    (`data_root.dart`). The third used to be MISSING and is the reason
//    `file_picker.dart` now drives `IFileDialog` itself: without
//    `FOS_DONTADDTORECENT` the Windows file dialog wrote every opened
//    project's name and full path into HKCU\…\ComDlg32, and no amount of
//    care here changed that. The flag keeps the FILE NAMES off the host —
//    nothing lands in `OpenSavePidlMRU` any more — but the shell writes
//    values under ComDlg32 that RackPal does not control, at minimum
//    `LastVisitedPidlMRU` (this executable plus the last folder browsed)
//    and `CIDSizeMRU` (this executable, written even on a cancelled
//    dialog). Those are measured examples, not an inventory: they are the
//    shell's records and not ours to suppress. `file_picker.dart` carries
//    the measurement and says why this is stated as a bound.
//  * IT DOES NOT DEBOUNCE. A drag across the screen fires dozens of move
//    events; the debounce lives in [WindowGeometryRecorder] below, with
//    an injected timer factory so no test waits 500 ms of wall clock.
//
// ==================================================================
// AN OPEN RISK, STATED RATHER THAN ASSUMED
// ==================================================================
// Whether `window_manager` 0.5.2 surfaces `WM_QUERYENDSESSION` — a
// Windows shutdown or a forced update reboot — through `onWindowClose` is
// UNVERIFIED. If it does not, an OS-initiated shutdown loses up to 30 s
// of work rather than prompting. The recovery snapshot is the mitigation
// and the startup scan is the proof it worked; the behaviour still needs
// an empirical check on a real machine.
import 'dart:async';

import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:rackpal/src/session/timers.dart';
import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:window_manager/window_manager.dart';

/// How long window move/resize events settle before geometry is written.
///
/// A drag across the screen fires dozens of events and each one must not
/// become a disk write.
const Duration kGeometryDebounce = Duration(milliseconds: 500);

/// The window events the shell reacts to.
///
/// Deliberately FOUR, not `window_manager`'s sixteen. Every one of these
/// has a consequence in this app; the other twelve do not, and an
/// interface that forwards events nobody handles is an interface that
/// grows.
abstract interface class WindowChromeListener {
  /// The user asked to close. `setPreventClose(true)` means nothing has
  /// happened yet and this handler decides.
  Future<void> onWindowCloseRequested();

  /// The window lost focus. §9.4's second autosave trigger — the user
  /// alt-tabbed away, which is exactly when a crash costs the most.
  void onWindowBlurred();

  /// The window was moved, resized, maximised or unmaximised.
  void onWindowGeometryChanged();
}

/// Title, size, position and close interception.
abstract interface class WindowChrome {
  /// Brings the platform window under this app's control, BEFORE
  /// `runApp`.
  ///
  /// The whole of it is `ensureInitialized` plus
  /// `setPreventClose(true)`, and the second half is the reason the
  /// dependency exists at all: without it the OS destroys the window and
  /// Flutter finds out afterwards, so the three-button close prompt
  /// cannot exist.
  ///
  /// IT IS ON THE INTERFACE, not left in `main()`, for a mechanical
  /// reason: `session_layering_test.dart` asserts `window_manager` is
  /// imported by exactly one file, and a bootstrap in `main()` would be a
  /// second import site — and therefore a second place that could quietly
  /// stop calling `setPreventClose`.
  Future<void> initialize();

  /// Installs the close/blur/geometry handler.
  void setHandler(WindowChromeListener? handler);

  /// Sets the OS window title. Callers MUST diff — see
  /// [WindowTitleWriter].
  Future<void> setTitle(String title);

  /// Turns the window's own close button into a request rather than an
  /// act. Without this there is no close prompt.
  Future<void> setPreventClose({required bool prevent});

  /// A rack editor below ~1000 px wide is unusable (§9.5).
  Future<void> setMinimumSize(double width, double height);

  /// The window's current outer rectangle.
  Future<WindowBounds> bounds();

  /// Moves and resizes the window.
  Future<void> setBounds(WindowBounds bounds);

  /// Centres a default-size window — the answer when a saved position no
  /// longer lands on any display.
  Future<void> center();

  Future<bool> isMaximized();

  Future<void> maximize();

  /// Every display's work area, for [validateRestoredBounds]. An EMPTY
  /// list means "could not enumerate", which the caller treats exactly
  /// like "the saved position matches nothing" — centre, do not gamble.
  Future<List<WindowBounds>> displays();

  /// Makes the window visible. Called once, after geometry is restored,
  /// so the user never sees the window jump from its default position to
  /// its remembered one.
  Future<void> show();

  /// Closes for real. Only ever called after the close prompt has been
  /// answered and any save has SUCCEEDED.
  Future<void> destroy();
}

/// The `window_manager` implementation.
final class WindowManagerChrome with WindowListener implements WindowChrome {
  WindowManagerChrome({
    required this.displayEnumerator,
    WindowManager? manager,
  }) : _manager = manager ?? windowManager;

  /// How the display list is obtained. Injected because it is the one
  /// piece of this class that does not come from `window_manager` — it
  /// comes from `screen_retriever`, which `window_manager` already
  /// depends on, and keeping it behind a function keeps this class's
  /// import list to the one plugin the layering test names.
  final Future<List<WindowBounds>> Function() displayEnumerator;

  final WindowManager _manager;
  WindowChromeListener? _handler;
  bool _listening = false;

  @override
  Future<void> initialize() async {
    await _manager.ensureInitialized();
    await _manager.setPreventClose(true);
  }

  @override
  void setHandler(WindowChromeListener? handler) {
    _handler = handler;
    if (handler != null && !_listening) {
      _manager.addListener(this);
      _listening = true;
    } else if (handler == null && _listening) {
      _manager.removeListener(this);
      _listening = false;
    }
  }

  @override
  Future<void> setTitle(String title) => _manager.setTitle(title);

  @override
  Future<void> setPreventClose({required bool prevent}) =>
      _manager.setPreventClose(prevent);

  @override
  Future<void> setMinimumSize(double width, double height) =>
      _manager.setMinimumSize(Size(width, height));

  @override
  Future<WindowBounds> bounds() async => _fromRect(await _manager.getBounds());

  @override
  Future<void> setBounds(WindowBounds bounds) => _manager.setBounds(
    Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
  );

  @override
  Future<void> center() => _manager.center();

  @override
  Future<bool> isMaximized() => _manager.isMaximized();

  @override
  Future<void> maximize() => _manager.maximize();

  @override
  Future<List<WindowBounds>> displays() => displayEnumerator();

  @override
  Future<void> show() => _manager.show();

  @override
  Future<void> destroy() => _manager.destroy();

  // --- WindowListener ---------------------------------------------------

  @override
  void onWindowClose() {
    // FIRE AND FORGET IS CORRECT HERE and nowhere else in this file. The
    // plugin's callback is synchronous `void`; the handler must await a
    // modal dialog and possibly a whole save. The handler is the thing
    // that eventually calls `destroy()`, and until it does, the window
    // stays open because `setPreventClose(true)` said so.
    unawaited(_handler?.onWindowCloseRequested() ?? Future<void>.value());
  }

  @override
  void onWindowBlur() => _handler?.onWindowBlurred();

  @override
  void onWindowResized() => _handler?.onWindowGeometryChanged();

  @override
  void onWindowMoved() => _handler?.onWindowGeometryChanged();

  @override
  void onWindowMaximize() => _handler?.onWindowGeometryChanged();

  @override
  void onWindowUnmaximize() => _handler?.onWindowGeometryChanged();

  static WindowBounds _fromRect(Rect rect) => WindowBounds(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
  );

  /// Converts a `screen_retriever` display into the pure geometry type
  /// `validateRestoredBounds` works in.
  static WindowBounds displayBounds({
    required Offset? visiblePosition,
    required Size? visibleSize,
    required Size size,
  }) {
    final origin = visiblePosition ?? Offset.zero;
    final extent = visibleSize ?? size;
    return WindowBounds(
      left: origin.dx,
      top: origin.dy,
      width: extent.width,
      height: extent.height,
    );
  }
}

/// Calls `setTitle` only when the rendered string actually CHANGES.
///
/// The session recomputes the title on every change notification, and a
/// 60 Hz drag would otherwise become 60 platform-channel round trips. The
/// diff is one string comparison and it lives here rather than at each
/// call site so it cannot be forgotten at one of them.
final class WindowTitleWriter {
  WindowTitleWriter(this._chrome);

  final WindowChrome _chrome;
  String? _last;

  /// How many times the platform channel was actually called. Test-only
  /// observability, and the assertion that the diff is real rather than
  /// intended.
  int get writeCount => _writeCount;
  int _writeCount = 0;

  Future<void> apply(String title) async {
    if (title == _last) return;
    _last = title;
    _writeCount++;
    await _chrome.setTitle(title);
  }
}

/// Persists window geometry, debounced.
///
/// [flush] exists for clean shutdown: a debounced write with a pending
/// timer at `destroy()` time would simply never happen, and the user's
/// last resize would be lost every single session.
final class WindowGeometryRecorder {
  WindowGeometryRecorder({
    required this.chrome,
    required this.prefs,
    this.timerFactory = productionTimerFactory,
    this.debounce = kGeometryDebounce,
  });

  final WindowChrome chrome;
  final PrefsStore prefs;

  final TimerFactory timerFactory;
  final Duration debounce;

  CancellableTimer? _pending;

  /// True while a write is owed. Read by the shutdown path.
  bool get hasPendingWrite => _pending != null;

  void onGeometryChanged() {
    _pending?.cancel();
    _pending = timerFactory(debounce, () {
      _pending = null;
      unawaited(_write());
    });
  }

  /// Writes any owed geometry immediately. Idempotent.
  Future<void> flush() async {
    if (_pending == null) return;
    _pending?.cancel();
    _pending = null;
    await _write();
  }

  void cancel() {
    _pending?.cancel();
    _pending = null;
  }

  Future<void> _write() async {
    try {
      final maximized = await chrome.isMaximized();
      final bounds = await chrome.bounds();
      // THE STORE'S OWN LIVE VALUE, not a snapshot handed in at
      // construction. This used to be an injected `readPrefs()` closure
      // over a field on the composition root that nothing in `lib/` ever
      // re-assigned, so every geometry write put the STARTUP prefs back
      // over `prefs.json` — reverting a `lastSaveDirectory` the user's
      // Save As had just recorded correctly, 500 ms after they nudged the
      // window. See [PrefsStore.current].
      final live = prefs.current;
      await prefs.save(
        live.copyWith(
          // WHEN MAXIMISED THE RESTORE-DOWN RECT IS KEPT, not overwritten
          // with the maximised bounds: unmaximising a restored window
          // must put it back where the user had it, not leave it filling
          // the screen at a size it never had.
          window: maximized ? live.window : bounds,
          maximized: maximized,
        ),
      );
      // Geometry is a convenience. A failure to record it must never
      // reach the user, and must never take the window with it.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
  }
}
