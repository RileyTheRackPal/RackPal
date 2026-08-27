// packages/rackpal_ui/lib/src/canvas/shake_animation.dart
//
// A shared 120ms decaying-oscillation "shake" (docs/04-rack-editor.md
// §3.4: "a nudge that would collide never silently stops: the selection
// shakes 3px"). ONE animation implementation, with two intended
// consumers: the blocked-keyboard-nudge device outline (this stage, via
// `RenderDeviceBox.shakeOffset`) and, in a later stage, the blocked-drop
// drag ghost (docs/04 §3.1's "Release while blocked is a no-op with a
// 120ms shake"). Kept as one small file rather than inlined into either
// consumer so the decay curve cannot drift between the two.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart' show Uuid;

/// The decaying-oscillation curve itself: [t] is normalized progress in
/// `[0, 1]`. Three decaying half-cycles land back at `Offset.zero` by
/// `t == 1`, so a shake that plays to completion never leaves a residual
/// offset. Factored out as a pure function (no `AnimationController`
/// dependency) so a future consumer can reuse exactly this shape without
/// [ShakeController]'s ticking plumbing.
Offset shakeOffsetAt(double t, {double amplitude = 3}) {
  if (t <= 0 || t >= 1) return Offset.zero;
  final decay = 1 - t;
  final wave = math.sin(t * math.pi * 3);
  return Offset(amplitude * decay * wave, 0);
}

/// Drives [shakeOffsetAt] over a real 120ms animation, one "shake target"
/// at a time (docs/04 §3.4 only ever shakes the single blocked selection —
/// multi-device nudge is out of scope this stage, see
/// `RackCanvasScreen._nudgeSelectedTo`'s doc comment). A `ChangeNotifier`
/// so painters/render objects can listen directly without requiring a
/// screen-wide rebuild every animation frame.
class ShakeController extends ChangeNotifier {
  ShakeController({required TickerProvider vsync}) : _vsync = vsync;

  static const Duration duration = Duration(milliseconds: 120);
  static const double amplitude = 3;

  final TickerProvider _vsync;
  AnimationController? _controller;
  Uuid? _targetId;

  /// The shake offset for [id] right now — zero unless [id] is the
  /// current shake target and the animation has not finished.
  Offset offsetFor(Uuid id) {
    final controller = _controller;
    if (controller == null || _targetId != id) return Offset.zero;
    return shakeOffsetAt(controller.value, amplitude: amplitude);
  }

  /// Starts (or restarts) the 120ms shake on [id]. Safe to call again
  /// mid-shake — e.g. holding Down against the same blocker keeps
  /// re-triggering a fresh, full-amplitude shake, which reads as "still
  /// blocked" rather than a silently truncated animation.
  void trigger(Uuid id) {
    _targetId = id;
    final controller = _controller ??= AnimationController(
      vsync: _vsync,
      duration: duration,
    )..addListener(notifyListeners);
    controller
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
