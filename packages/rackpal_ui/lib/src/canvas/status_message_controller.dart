// packages/rackpal_ui/lib/src/canvas/status_message_controller.dart
//
// A minimal transient-message channel for docs/04-rack-editor.md §3.4's
// "never silently stops" principle: a blocked keyboard nudge, a blocked
// drop (later stage), and a successful caret/quick-add placement all get
// a screen-space status line AND a `SemanticsService.sendAnnouncement`, so a
// screen-reader user gets the same feedback a sighted user gets from the
// (also required) visual chrome.
//
// THE ANNOUNCEMENT IS ADDRESSED TO A VIEW (#946). Flutter deprecated
// `SemanticsService.announce` after 3.35 because it sends to the implicit
// view, which a multi-window app does not have; `sendAnnouncement` takes
// the `FlutterView` to speak in. This controller is a plain field on its
// screen's `State` and has no `BuildContext`, so the owner hands it [view]
// as a callback, and it is REQUIRED so that an owner cannot forget it and
// silence the only announcement channel the app has (AC-058's NVDA
// matrix at M7 rests on it).
//
// Deliberately NOT the full always-visible status bar of docs/04 §1
// (cursor context / zoom / selection rollup / project counts) — that
// stays not-started (docs/m1-implementation-log.md §2, §1 row). This is
// sized exactly to what this stage's spec text requires: a message that
// shows, holds briefly, and clears.

import 'dart:async';

import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// The current transient status text, or null when nothing is showing.
class StatusMessageController extends ChangeNotifier {
  StatusMessageController({
    required this.view,
    this.defaultHold = const Duration(seconds: 3),
  });

  /// The view an announcement is spoken in, read at each [show]. Null
  /// means the owner is gone (a screen past `dispose`), and then the line
  /// still updates and nothing is announced, since nobody is there to hear
  /// it. Owners pass `() => mounted ? View.of(context) : null`.
  final FlutterView? Function() view;

  /// How long a message stays on screen after [show] before auto-clearing,
  /// unless overridden per-call.
  final Duration defaultHold;

  String? _text;
  String? get text => _text;

  Timer? _timer;

  /// Shows [message], resetting any in-flight auto-clear timer, and fires
  /// [SemanticsService.sendAnnouncement] in [view] so the same message
  /// reaches assistive tech even though this is not a persistent,
  /// focusable widget.
  void show(String message, {Duration? hold}) {
    _text = message;
    notifyListeners();
    final target = view();
    if (target != null) {
      SemanticsService.sendAnnouncement(target, message, TextDirection.ltr);
    }

    _timer?.cancel();
    _timer = Timer(hold ?? defaultHold, () {
      _text = null;
      notifyListeners();
    });
  }

  /// Clears the current message immediately, cancelling any pending
  /// auto-clear.
  void clear() {
    _timer?.cancel();
    if (_text == null) return;
    _text = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
