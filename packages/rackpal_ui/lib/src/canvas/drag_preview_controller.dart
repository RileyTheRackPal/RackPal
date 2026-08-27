// packages/rackpal_ui/lib/src/canvas/drag_preview_controller.dart
//
// Observable state for the live "where would this land, and would it be
// refused?" preview shared by BOTH of the rack editor's drag gestures:
//
//  * docs/04-rack-editor.md §3.1 — drag a NEW device from the palette to
//    the rails: arm -> lift -> enter canvas -> snap -> evaluate -> commit.
//  * docs/04-rack-editor.md §3.3 — move an EXISTING placed device: grab ->
//    (4px threshold) -> snap -> evaluate -> commit. Step 3 of that section
//    is literally "Same checks and same blocked rendering as §3.1", which
//    is why this controller is shared rather than duplicated: ONE phase
//    machine, ONE evaluation value type, ONE set of readers.
//
// This class was originally `PaletteDragController` and carried the palette
// gesture only; §3.3's live-feedback stage generalised it rather than
// cloning it. The two gestures differ ONLY in how they are driven, never in
// what they show:
//
//                        palette drag (§3.1)      move drag (§3.3)
//   armed from           a sibling palette row    a hit inside the canvas
//   tracked via          GestureBinding's global  CanvasIntentDetector's
//                        pointerRouter            own Listener
//   [lifted] phase       yes (cursor card floats  never — the gesture
//                        before canvas entry)     starts inside the canvas
//   [subjectId] means    a seed catalog id        the moving device's Uuid
//   commits to           AddDeviceCommand         MoveDeviceCommand
//
// Everything below the `lifted` row — snapping, evaluating, the blocked
// verdict, the 1.2s blocked-release linger — is identical for both, so it
// lives here once. UI-owned, like `CaretController`/`SelectionController`/
// `ShakeController`: never persisted, never itself captured by undo (only
// the eventual `Command` a valid commit runs is undoable).
//
// `RackCanvasScreen` is the sole mutator, and owns ONE INSTANCE PER
// GESTURE (`_paletteDrag` and `_moveDrag`) rather than one shared instance,
// so a stray second pointer driving one gesture can never clobber the
// other's live state. `EditingOverlayPainter` (the scene-space ghost/
// snap-line/hatch) and the screen-space RU-range/reason-chip `OverlayEntry`
// are the READERS, and are written against this type — not against either
// gesture — which is what makes "same blocked rendering" literally true
// rather than approximately true.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/painting.dart' show Offset;
import 'package:rackpal_core/rackpal_core.dart';

/// Sentinel id `ShakeController` is keyed on for a drag GHOST's blocked-
/// release shake (docs/04 §3.1 step 5: "Release while blocked is a no-op
/// with a 120ms shake" — §3.3 step 3 inherits it verbatim). Reuses
/// `ShakeController` exactly as `RenderDeviceBox` does for a real placed
/// device (see that file's own doc comment: "ONE animation
/// implementation... two consumers") rather than adding a second shake
/// mechanism — a ghost has no `DeviceInstance` of its own to key on (a
/// palette drag has no device yet; a move drag's ghost previews a device
/// that is still sitting, dimmed, at its ORIGINAL U and must not itself
/// shake), so a fixed placeholder id stands in for one.
///
/// One sentinel serves both gestures because at most one drag ghost is ever
/// on screen; `ShakeController` is itself single-target by construction
/// (see its `_targetId`).
const Uuid kDragGhostShakeId = Uuid('__drag-preview-ghost__');

/// Where a drag currently sits in the arm/lift/enter/commit sequence
/// (docs/04 §3.1 for the palette gesture, §3.3 for the move gesture).
/// Exactly one drag per gesture is ever in flight, matching
/// `CanvasIntentDetector`'s own single-`_dragPointer` convention.
enum DragPreviewPhase {
  /// No drag armed.
  none,

  /// Pointer down on the drag SOURCE (a palette row, or a placed device),
  /// below the 4px slop (docs/04 §3.1 step 1: "Nothing until 4 px of
  /// movement, so a click still means 'show details'" — §3.3 step 1 uses
  /// the identical threshold) — might still just be a click/double-click.
  armed,

  /// Threshold crossed; the pointer has not yet entered the canvas
  /// widget's bounds. The cursor card floats at the pointer; the source
  /// row is dimmed + outlined (docs/04 §3.1 step 2).
  ///
  /// PALETTE-ONLY IN PRACTICE: a move drag's source is already inside the
  /// canvas, so it transitions `armed -> dragging` in one step (see
  /// `DragPreviewController.liftIntoCanvas`) and is never observed here.
  lifted,

  /// The pointer is inside the canvas widget's bounds — the scene-accurate
  /// ghost is live, snapped + evaluated every frame (docs/04 §3.1 steps
  /// 3-5, §3.3 steps 1/3).
  dragging,
}

/// One frame's live evaluation of a drag's landing spot (docs/04 §3.1
/// steps 4-5; §3.3 step 3): the hard-snapped `ruIndex`, whether either of
/// CR-017's two BLOCKING checks failed, and — when blocked — the
/// user-facing reason and (for an occupancy block only) the conflicting
/// occupant's own scene rect, so the painter can hatch it without
/// re-deriving device layouts itself.
@immutable
class DragPreviewEvaluation {
  const DragPreviewEvaluation({
    required this.ruIndex,
    required this.blocked,
    this.reason,
    this.blockingRect,
  });

  /// The hard-quantised RU the ghost is snapped to — always exactly a
  /// `RackGeometry` inverse result (docs/04 §3.1 step 4: "Snap is
  /// instant", never interpolated). The palette gesture derives it from
  /// the cursor centre (`ruIndexForCursorY`), the move gesture from the
  /// grabbed device's own top edge plus the drag delta (`ruIndexForTopY`),
  /// so the grab offset is preserved — two callers, still one
  /// inverse-geometry implementation.
  final int ruIndex;

  /// Whether either of the two BLOCKING CR-017 checks failed this frame:
  /// front U range free on this face, or fits within the rack extent. The
  /// five advisory/warning checks (opposite-face occupancy, depth-interval
  /// fit, clearance, mount-method compatibility, half-rack-on-bare-rails)
  /// are explicitly OUT OF SCOPE — no validation/finding engine exists
  /// anywhere in this codebase (no `derived/validation.dart`) and building
  /// one is a separate, later M1 roadmap item. See
  /// `rack_canvas_screen.dart`'s `_evaluateDrop` for the ONE place both
  /// gestures compute this.
  final bool blocked;

  /// The user-facing reason, e.g. `"Occupied by AMP-1 (U19-U20)."` or
  /// `"Needs 4U, only 2U free at top."` — null when not blocked. Wording
  /// matches `catalog_placement.dart`'s own `buildPlaceFromCatalogCommand`
  /// failure messages exactly, since a valid palette commit calls that
  /// same function with this frame's `ruIndex` and must never disagree
  /// with what was just shown.
  final String? reason;

  /// The conflicting occupant's own scene rect, for the blocked-drop
  /// hatch — null unless [blocked] is true AND the block is an occupancy
  /// conflict (an extent overflow has no single occupant to hatch).
  final DBox? blockingRect;
}

/// The observable drag-preview state machine. See the file header for the
/// two gestures that drive it, what they share, and why this lives here
/// rather than as a `Draggable`/`DragTarget` pair.
class DragPreviewController extends ChangeNotifier {
  DragPreviewPhase _phase = DragPreviewPhase.none;
  String? _subjectId;
  int _deviceH = 0;
  Face _face = Face.front;
  String _displayName = '';
  String _badge = '';
  Set<PointerDeviceKind> _sourceKinds = const {};

  Offset? _cursorGlobal;
  DPt? _sceneCursor;
  DragPreviewEvaluation? _evaluation;

  /// True from the moment a blocked release fires through the 1.2s the
  /// reason chip persists afterward (docs/04 §3.1 step 5 verbatim:
  /// "Release while blocked is a no-op with a 120ms shake and the chip
  /// persisting 1.2s."). While this is true, [evaluation]/[deviceH]/
  /// [sceneCursor] etc. are DELIBERATELY left as they were at release —
  /// [beginBlockedRelease] does not clear them — so the ghost/chip have
  /// something frozen to keep showing; `RackCanvasScreen` owns the 1.2s
  /// `Timer` that eventually calls [reset] (this controller is a pure
  /// state holder, matching `StatusMessageController`'s own precedent for
  /// who owns timers).
  bool _releaseLingering = false;

  DragPreviewPhase get phase => _phase;

  /// What is being dragged: a seed CATALOG id for the palette gesture, the
  /// moving device's `Uuid.v` for the move gesture (see the file header's
  /// table). Null when no drag is armed.
  String? get subjectId => _subjectId;

  int get deviceH => _deviceH;
  Face get face => _face;
  String get displayName => _displayName;
  String get badge => _badge;
  Set<PointerDeviceKind> get sourceKinds => _sourceKinds;

  Offset? get cursorGlobal => _cursorGlobal;
  DPt? get sceneCursor => _sceneCursor;
  DragPreviewEvaluation? get evaluation => _evaluation;
  bool get releaseLingering => _releaseLingering;

  /// Whether a drag is armed, lifted, dragging, OR lingering after a
  /// blocked release right now — one of `CaretController.recompute`'s
  /// three activation inputs (docs/04 §3.4: the keyboard caret and an
  /// in-flight drag are mutually exclusive; insertion_caret.dart names
  /// this exact field as its `dragInProgress` input).
  bool get isInProgress => _phase != DragPreviewPhase.none || _releaseLingering;

  /// Whether the drag SOURCE should currently show its "being dragged"
  /// chrome — the palette row's dim + outline (docs/04 §3.1 step 2), or
  /// the placed device's 30% in-place fade (docs/04 §3.3 step 1). Lift,
  /// not arm: "nothing until 4px of movement".
  ///
  /// Deliberately false once [beginBlockedRelease] has fired: the pointer
  /// is up, so the source is no longer "being dragged" and must return to
  /// full strength immediately, even while the blocked ghost + reason chip
  /// keep lingering for their 1.2s.
  bool get isSourceEngaged =>
      _phase == DragPreviewPhase.lifted || _phase == DragPreviewPhase.dragging;

  bool get isDragging => _phase == DragPreviewPhase.dragging;

  /// Whether `EditingOverlayPainter` should draw this drag's ghost/snap-
  /// line/hatch this frame, and the screen-space overlay its RU-range /
  /// reason chips: a live drag or a lingering blocked release, AND an
  /// evaluation to draw. The ONE predicate both readers use, so they can
  /// never disagree about whether a ghost is on screen.
  bool get isShowingGhost =>
      (_phase == DragPreviewPhase.dragging || _releaseLingering) &&
      _evaluation != null;

  /// docs/04 §3.1 step 1 / §3.3 step 1: pointer down on the drag source.
  void arm({
    required String subjectId,
    required int deviceH,
    required Face face,
    required String displayName,
    required String badge,
    required Set<PointerDeviceKind> sourceKinds,
  }) {
    _phase = DragPreviewPhase.armed;
    _subjectId = subjectId;
    _deviceH = deviceH;
    _face = face;
    _displayName = displayName;
    _badge = badge;
    _sourceKinds = sourceKinds;
    _cursorGlobal = null;
    _sceneCursor = null;
    _evaluation = null;
    _releaseLingering = false;
    notifyListeners();
  }

  /// docs/04 §3.1 step 2: "Lift — threshold crossed."
  void lift() {
    if (_phase != DragPreviewPhase.armed) return;
    _phase = DragPreviewPhase.lifted;
    notifyListeners();
  }

  /// docs/04 §3.1 step 3: "Enter canvas" — the cursor card cross-fades
  /// into the scene-accurate ghost (the actual 100ms cross-fade animation
  /// is a documented, deferred visual-polish nicety; see
  /// `rack_canvas_screen.dart`'s header and the stage report).
  void enterCanvas() {
    if (_phase != DragPreviewPhase.lifted) return;
    _phase = DragPreviewPhase.dragging;
    notifyListeners();
  }

  /// `armed -> dragging` in one step, for the MOVE gesture (docs/04 §3.3),
  /// whose source is already inside the canvas: there is no pre-entry
  /// cursor-card stage to pass through, so `DragPreviewPhase.lifted` is
  /// skipped rather than briefly (and misleadingly) entered. Deliberately
  /// expressed as [lift]
  /// then [enterCanvas] rather than a third phase assignment, so the
  /// legal-transition rules stay in exactly two places.
  void liftIntoCanvas() {
    lift();
    enterCanvas();
  }

  /// The pointer backed out of the canvas widget's bounds mid-drag (still
  /// held down) — falls back to the pre-entry (lifted / cursor-card)
  /// state WITHOUT ending the gesture (the design's own "back out over the
  /// palette again" case). Palette-only in practice: a move drag has no
  /// meaningful pre-entry state to fall back to.
  void exitCanvas() {
    if (_phase != DragPreviewPhase.dragging) return;
    _phase = DragPreviewPhase.lifted;
    _sceneCursor = null;
    _evaluation = null;
    notifyListeners();
  }

  /// Every pointer move: the raw global cursor position, for the cursor
  /// card (pre-entry) and reason-chip (post-entry) screen-space widgets.
  void updateCursorGlobal(Offset global) {
    _cursorGlobal = global;
    notifyListeners();
  }

  /// Every `updateDrag`-equivalent frame while [isDragging]: the live
  /// scene cursor + CR-017 evaluation (docs/04 §3.1 steps 4-5).
  void updateEvaluation(DPt sceneCursor, DragPreviewEvaluation evaluation) {
    if (_phase != DragPreviewPhase.dragging) return;
    _sceneCursor = sceneCursor;
    _evaluation = evaluation;
    notifyListeners();
  }

  /// docs/04 §3.1 step 5, a blocked pointer-up: freezes the current
  /// ghost/chip state ([releaseLingering] true) for the caller's own 1.2s
  /// `Timer` to clear via [reset]. Does not itself play the shake (that is
  /// `ShakeController.trigger(kDragGhostShakeId)`, driven by the same
  /// caller) — this controller only holds state, never animates.
  void beginBlockedRelease() {
    _phase = DragPreviewPhase.none;
    _releaseLingering = true;
    notifyListeners();
  }

  /// Clears everything: a valid commit, an Esc cancel, an outside-canvas
  /// release (SCOPE DECISION: no Staging Bin exists, so this is a plain
  /// no-op — see `rack_canvas_screen.dart`), or the end of a blocked
  /// release's 1.2s linger.
  void reset() {
    if (_phase == DragPreviewPhase.none &&
        _subjectId == null &&
        !_releaseLingering) {
      return; // already clear — avoid a spurious notify.
    }
    _phase = DragPreviewPhase.none;
    _subjectId = null;
    _deviceH = 0;
    _cursorGlobal = null;
    _sceneCursor = null;
    _evaluation = null;
    _releaseLingering = false;
    notifyListeners();
  }
}
