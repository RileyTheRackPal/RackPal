import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';

/// Multiplier on scroll/pinch magnitude for zoom. `scale *= exp(-delta * k)`
/// with `k = 0.002` is the multiplicatively-symmetric formula from
/// docs/05-schematic-editor.md line 782, so three notches up then three down
/// land exactly where you started.
const double kZoomPerScrollUnit = 0.002;

/// The pointer-agnostic editing intent, built FIRST (AC-016 #23, docs/03 §4.4
/// and docs/04 §3). Every future editor gesture — move a device, marquee,
/// drag-to-connect — is expressed as this begin/update/commit/cancel sequence.
///
/// The contract that matters: a handler receives the identical sequence no
/// matter which physical device drove it (mouse, touch, stylus, trackpad). No
/// implementation may branch on [PointerDeviceKind] for editing semantics;
/// [beginDrag] is *given* the source kinds only so a handler can, e.g., widen
/// hit slop for touch — it must never gate the gesture on them.
abstract interface class CanvasIntentHandler {
  /// A drag has started at [sceneStart] (scene coordinates). [sourceKinds] is
  /// informational only (see class doc).
  void beginDrag(DPt sceneStart, Set<PointerDeviceKind> sourceKinds);

  /// The drag moved to [sceneCurrent]; [sceneDelta] is the scene-space step
  /// since the previous update.
  void updateDrag(DPt sceneCurrent, DPt sceneDelta);

  /// The drag ended at [sceneEnd]. Exactly one of [commitDrag]/[cancel] fires
  /// per [beginDrag].
  void commitDrag(DPt sceneEnd);

  /// The drag was aborted (pointer cancelled, e.g. Esc/app switch upstream).
  void cancel();
}

/// Wraps a `Listener` and turns raw pointer traffic into either
/// [CanvasIntentHandler] calls (scene-space, device-agnostic) or
/// [ViewportController] pan/zoom.
///
/// Routing rules, none of which branch on [PointerDeviceKind]:
/// * **Primary button / touch / stylus contact** — drives [handler] if one is
///   supplied; otherwise pans (so pan/zoom works standalone at this stage,
///   before anything is draggable).
/// * **Middle mouse button** — always pans (a *button* check, not a kind check;
///   docs/04 keymap: "MMB pans").
/// * **`onPointerSignal` scroll** — plain scroll pans; Ctrl/Cmd+scroll zooms
///   about the cursor.
/// * **`onPointerPanZoom*` (native trackpad)** — a SEPARATE channel from
///   `onPointerSignal`: `panDelta` pans, pinch `scale` zooms about the focus.
///
/// Distinguishing signal-vs-gesture *channels* is allowed (it is about which
/// physical channel carries pan/zoom, not about editing semantics); branching
/// on device *kind* is not.
class CanvasIntentDetector extends StatefulWidget {
  const CanvasIntentDetector({
    required this.viewport,
    required this.child,
    this.handler,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final ViewportController viewport;

  /// Optional editing sink. When null (the common case for the viewport-first
  /// stage) primary drags pan instead.
  final CanvasIntentHandler? handler;

  final Widget child;
  final HitTestBehavior behavior;

  @override
  State<CanvasIntentDetector> createState() => _CanvasIntentDetectorState();
}

class _CanvasIntentDetectorState extends State<CanvasIntentDetector> {
  // A drag being routed to the handler.
  int? _dragPointer;
  DPt? _lastDragScene;

  // A drag being consumed as a pan (middle button, or primary with no handler).
  int? _panPointer;

  // Trackpad pinch accumulator: PointerPanZoomUpdateEvent.scale is cumulative
  // from gesture start, so we track the last value to derive per-event factors.
  double _panZoomLastScale = 1;

  ViewportController get _vp => widget.viewport;

  DPt _toScene(Offset local) => _vp.screenToScene(DPt(local.dx, local.dy));

  bool get _zoomModifier =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  void _onPointerDown(PointerDownEvent event) {
    // Button check (not a device-kind check): middle mouse always pans.
    if (event.buttons & kMiddleMouseButton != 0) {
      _panPointer = event.pointer;
      return;
    }
    final handler = widget.handler;
    if (handler != null) {
      _dragPointer = event.pointer;
      final scene = _toScene(event.localPosition);
      _lastDragScene = scene;
      handler.beginDrag(scene, {event.kind});
    } else {
      _panPointer = event.pointer;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _dragPointer) {
      final scene = _toScene(event.localPosition);
      final last = _lastDragScene ?? scene;
      widget.handler!.updateDrag(scene, scene - last);
      _lastDragScene = scene;
    } else if (event.pointer == _panPointer) {
      _vp.panBy(event.delta);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _dragPointer) {
      widget.handler!.commitDrag(_toScene(event.localPosition));
      _endDrag();
    } else if (event.pointer == _panPointer) {
      _panPointer = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _dragPointer) {
      widget.handler!.cancel();
      _endDrag();
    } else if (event.pointer == _panPointer) {
      _panPointer = null;
    }
  }

  void _endDrag() {
    _dragPointer = null;
    _lastDragScene = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_zoomModifier) {
      final factor = math.exp(-event.scrollDelta.dy * kZoomPerScrollUnit);
      _vp.zoomBy(factor, screenPivot: event.localPosition);
    } else {
      // Negated so a downward wheel scroll moves content up (platform norm).
      _vp.panBy(-event.scrollDelta);
    }
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _panZoomLastScale = 1;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.panDelta != Offset.zero) {
      _vp.panBy(event.panDelta);
    }
    if (event.scale > 0 && event.scale != _panZoomLastScale) {
      final factor = event.scale / _panZoomLastScale;
      _panZoomLastScale = event.scale;
      _vp.zoomBy(factor, screenPivot: event.localPosition);
    }
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomLastScale = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      child: widget.child,
    );
  }
}
