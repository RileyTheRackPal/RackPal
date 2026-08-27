// packages/rackpal_ui/lib/src/canvas/status_message_controller.dart
//
// A minimal transient-message channel for docs/04-rack-editor.md §3.4's
// "never silently stops" principle: a blocked keyboard nudge, a blocked
// drop (later stage), and a successful caret/quick-add placement all get
// a screen-space status line AND a `SemanticsService.announce`, so a
// screen-reader user gets the same feedback a sighted user gets from the
// (also required) visual chrome.
//
// Deliberately NOT the full always-visible status bar of docs/04 §1
// (cursor context / zoom / selection rollup / project counts) — that
// stays not-started (docs/m1-implementation-log.md §2, §1 row). This is
// sized exactly to what this stage's spec text requires: a message that
// shows, holds briefly, and clears.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// The current transient status text, or null when nothing is showing.
class StatusMessageController extends ChangeNotifier {
  StatusMessageController({this.defaultHold = const Duration(seconds: 3)});

  /// How long a message stays on screen after [show] before auto-clearing,
  /// unless overridden per-call.
  final Duration defaultHold;

  String? _text;
  String? get text => _text;

  Timer? _timer;

  /// Shows [message], resetting any in-flight auto-clear timer, and fires
  /// [SemanticsService.announce] so the same message reaches assistive
  /// tech even though this is not a persistent, focusable widget.
  void show(String message, {Duration? hold}) {
    _text = message;
    notifyListeners();
    SemanticsService.announce(message, TextDirection.ltr);

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
