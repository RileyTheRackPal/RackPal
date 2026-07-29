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

/// The identity of ONE `beginDrag → update* → (commitDrag|cancel)` sequence.
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY A TOKEN AND NOT A LATCH IN THE HANDLER
/// ═══════════════════════════════════════════════════════════════════════
/// A handler that ARBITRATES — one that can refuse a gesture because some
/// other gesture already owns the canvas — is owed a terminal callback for
/// the begin it refused as well as for the begin it accepted
/// ([CanvasIntentHandler.commitDrag]'s "exactly one per beginDrag"). With no
/// identity on the callback, an arbitrating handler has to GUESS which of
/// its outstanding begins a bare `commitDrag()`/`cancel()` belongs to, and
/// every possible guess is wrong somewhere:
///
///  * "a pending refusal eats the next terminal" swallows the WINNER's own
///    release when the winner's pointer happens to lift first — its click
///    vanishes and its claim leaks;
///  * "the owner's terminal wins" releases the winner's claim the moment a
///    REFUSED gesture tears down, handing the canvas to a new gesture while
///    the winner's pointer is still physically down;
///  * a bool cannot count, so two outstanding refusals collapse into one and
///    the second falls through whichever branch is left.
///
/// The ordering is not the handler's to fix: nothing in this interface orders
/// two gestures' terminals, and a `bool`/counter is a property of the OBJECT
/// where the question is about the GESTURE. So the caller mints one token per
/// [CanvasIntentHandler.beginDrag] and hands the same token back on every
/// later call for that gesture, and attribution becomes a lookup instead of a
/// guess.
///
/// IDENTITY, NOT VALUE: two tokens are equal only when they are the same
/// object, so a token can be neither forged nor collided with — including by
/// a test that mints its own to stand in for a second pointer route.
final class CanvasGestureToken {
  /// A fresh, unequal-to-everything token. One per `beginDrag`.
  CanvasGestureToken();
}

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
  ///
  /// [gesture] is this sequence's identity, minted fresh by the caller and
  /// repeated on every subsequent call for it — see [CanvasGestureToken].
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  });

  /// The drag moved to [sceneCurrent]; [sceneDelta] is the scene-space step
  /// since the previous update.
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  });

  /// The drag ended at [sceneEnd]. Exactly one of [commitDrag]/[cancel] fires
  /// per [beginDrag], carrying that begin's own [gesture] token.
  ///
  /// A SINGLE CALLER never interleaves two: [CanvasIntentDetector] routes one
  /// pointer at a time and its own single-gesture guarantee is what makes a
  /// handler's per-drag state safe to (re)initialise in [beginDrag] without a
  /// concurrency check of its own. The token is what makes that safe for a
  /// handler serving MORE than one caller — a screen whose arbiter can refuse
  /// a begin while another route holds the canvas — where nothing orders the
  /// two gestures' terminals at all.
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture});

  /// The drag was aborted (pointer cancelled, e.g. Esc/app switch upstream).
  void cancel({required CanvasGestureToken gesture});
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
///
/// ONE ROUTED DRAG AT A TIME, and this is the class that guarantees it. A
/// second primary pointer going down while a drag is already routed gets no
/// [CanvasIntentHandler.beginDrag], so the handler sees a strict
/// `begin -> update* -> (commit|cancel)` sequence per gesture and never a
/// second `beginDrag` interleaved into a live one. Without that guard, a
/// second contact silently re-pointed `_dragPointer` at itself: the handler's
/// per-drag state was re-initialised out from under the FIRST pointer's still
/// live preview (orphaning it permanently, since that pointer's up/cancel then
/// matched nothing and neither [CanvasIntentHandler.commitDrag] nor
/// [CanvasIntentHandler.cancel] ever fired for it), which also broke this
/// interface's own "exactly one of commitDrag/cancel per beginDrag" contract.
/// Enforcing it HERE rather than in each handler is deliberate: it is a
/// property of the routing, every handler needs it, and re-asserting it per
/// handler is exactly the thing this codebase has already got wrong three
/// times (see `rack_canvas_screen.dart`'s own exclusivity section).
///
/// DEFERRED, NOT DISCARDED — and the difference is the whole reason the state
/// below keeps a `_deferred` map rather than a bare `return`. The
/// justification above holds only WHILE the first gesture's handler state is
/// live; it expires the
/// instant that gesture ends. A second contact that was merely dropped stayed
/// dropped forever, because `_dragPointer` was only ever assigned on
/// pointer-DOWN and that pointer's down was already spent: finger A scrubs,
/// finger B lands on a device, A lifts and frees the route, and B — still
/// physically on the glass — then drags and releases into a DEAD ZONE, its
/// events matching neither `_dragPointer` nor `_panPointer`. No begin, no
/// move, no click: the silent no-op docs/04 §3.4 forbids, produced by the
/// very guard that was meant to make gestures honest.
///
/// So a refused pointer is REMEMBERED, with its latest position and kind, and
/// every one of its subsequent events is explicitly consumed (its moves
/// update that remembered position; its up/cancel simply forget it, with no
/// handler call — it never got a `beginDrag`, so it is owed neither a
/// `commitDrag` nor a `cancel`). When the routed gesture ends while a
/// deferred pointer is still down, that pointer is ADOPTED: it receives a
/// `beginDrag` at where the finger actually is now, and from there it is an
/// ordinary routed gesture with the full begin/update*/commit|cancel
/// sequence. The exclusivity invariant is untouched — there is never more
/// than one routed pointer, and the adoption happens strictly AFTER the
/// previous gesture's `commitDrag`/`cancel` has returned — while a second
/// finger stops being a black hole.
///
/// Adoption is FIFO across multiple deferred pointers (three-finger contact
/// is the only way to get there), so which one inherits the route is a
/// property of the code rather than of `Map` iteration luck.
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

  /// The routed drag's identity, minted in [_beginDragFor] and repeated on
  /// every `updateDrag`/`commitDrag`/`cancel` for it — see
  /// [CanvasGestureToken]. Null exactly when [_dragPointer] is.
  CanvasGestureToken? _dragGesture;

  /// Pointers that went down while [_dragPointer] was already routed, keyed
  /// by pointer id and carrying the LATEST local position each has reported
  /// (so an adoption starts from where the finger is, not from where it
  /// landed several move events ago). Insertion-ordered, which is what makes
  /// [_adoptDeferredPointer] FIFO. See the class doc's deferral rule.
  final Map<int, ({Offset position, PointerDeviceKind kind})> _deferred =
      <int, ({Offset position, PointerDeviceKind kind})>{};

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
      // THE SINGLE-GESTURE GUARD (see the class doc). A second contact while
      // a drag is already routed gets no `beginDrag` — it must not steal the
      // route from a gesture whose handler state is still live — but it is
      // REMEMBERED rather than dropped, so its own later events are consumed
      // deliberately below and it can inherit the route once the current
      // gesture ends.
      if (_dragPointer != null) {
        _deferred[event.pointer] = (
          position: event.localPosition,
          kind: event.kind,
        );
        return;
      }
      _beginDragFor(event.pointer, event.localPosition, event.kind);
    } else {
      _panPointer = event.pointer;
    }
  }

  /// Routes [pointer] to the handler and opens its gesture. The ONE place
  /// `_dragPointer` is assigned and `beginDrag` is called, so a first contact
  /// and an adopted deferred one are the same code path by construction.
  void _beginDragFor(int pointer, Offset local, PointerDeviceKind kind) {
    final handler = widget.handler;
    if (handler == null) return;
    _dragPointer = pointer;
    final gesture = CanvasGestureToken();
    _dragGesture = gesture;
    final scene = _toScene(local);
    _lastDragScene = scene;
    handler.beginDrag(scene, {kind}, gesture: gesture);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _dragPointer) {
      final scene = _toScene(event.localPosition);
      final last = _lastDragScene ?? scene;
      widget.handler!.updateDrag(scene, scene - last, gesture: _dragGesture!);
      _lastDragScene = scene;
    } else if (event.pointer == _panPointer) {
      _vp.panBy(event.delta);
    } else if (_deferred.containsKey(event.pointer)) {
      // Deferred: no handler call — it has had no `beginDrag`, so it may not
      // have an `updateDrag` — but its position is tracked so an adoption
      // begins where the finger IS, not where it first landed.
      _deferred[event.pointer] = (
        position: event.localPosition,
        kind: event.kind,
      );
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _dragPointer) {
      widget.handler!.commitDrag(
        _toScene(event.localPosition),
        gesture: _dragGesture!,
      );
      _endDrag();
    } else if (event.pointer == _panPointer) {
      _panPointer = null;
    } else {
      // A deferred pointer lifting before it was ever adopted: forget it, and
      // call NOTHING. It never received a `beginDrag`, so it is owed neither
      // a `commitDrag` nor a `cancel` — the interface's contract is "exactly
      // one of them PER beginDrag", not "one per pointer".
      _deferred.remove(event.pointer);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _dragPointer) {
      widget.handler!.cancel(gesture: _dragGesture!);
      _endDrag();
    } else if (event.pointer == _panPointer) {
      _panPointer = null;
    } else {
      _deferred.remove(event.pointer); // see `_onPointerUp`.
    }
  }

  void _endDrag() {
    _dragPointer = null;
    _dragGesture = null;
    _lastDragScene = null;
    _adoptDeferredPointer();
  }

  /// The route just fell free. If a pointer is still physically down having
  /// been refused earlier, hand it the route now (class doc's deferral rule).
  ///
  /// Deliberately called from [_endDrag] — i.e. from BOTH the commit and the
  /// cancel path, and in both cases strictly after the previous gesture's
  /// terminal callback has returned, so the handler has already run its own
  /// teardown and is ready to be (re)initialised by `beginDrag`. A handler
  /// that still cannot accept the gesture (this screen's palette drag holds a
  /// claim through a different pointer route entirely) refuses it on its own
  /// terms and says so; that is its call to make, not the detector's.
  void _adoptDeferredPointer() {
    if (_deferred.isEmpty) return;
    final pointer = _deferred.keys.first; // FIFO — see the class doc.
    final deferred = _deferred.remove(pointer)!;
    _beginDragFor(pointer, deferred.position, deferred.kind);
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
