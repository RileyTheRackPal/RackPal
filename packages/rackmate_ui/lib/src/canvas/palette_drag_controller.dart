// packages/rackmate_ui/lib/src/canvas/palette_drag_controller.dart
//
// Observable state for docs/04-rack-editor.md §3.1's drag-from-palette-to-
// rails gesture: arm -> lift -> enter canvas -> snap -> evaluate -> commit.
// UI-owned, like `CaretController`/`SelectionController`/`ShakeController` —
// never persisted, never itself captured by undo (only the eventual
// `AddDeviceCommand` a valid commit runs is undoable).
//
// `RackCanvasScreen` is the sole mutator. It is armed from
// `DevicePalettePanel`'s new `onArmDrag` callback (a pointer-down on a
// palette row) and tracked for the rest of the gesture via a GLOBAL
// `GestureBinding.instance.pointerRouter` route — NOT through
// `CanvasIntentDetector`'s own `Listener` (the drag starts in a sibling
// widget, outside that subtree) and NOT through `Draggable`/`DragTarget`
// (docs/04 §3's hard constraint: hand-rolled `Listener`/pointer routing
// only). See `rack_canvas_screen.dart`'s own header comment for the full
// arm/track/commit mechanism this controller's state machine backs.
//
// `EditingOverlayPainter` (the scene-space ghost/snap-line/hatch) and the
// screen-space cursor-card/reason-chip `OverlayEntry` are the READERS.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/painting.dart' show Offset;
import 'package:rackmate_core/rackmate_core.dart';

/// Sentinel id `ShakeController` is keyed on for the palette-drag ghost's
/// own blocked-release shake (docs/04 §3.1: "Release while blocked is a
/// no-op with a 120ms shake"). Reuses `ShakeController` exactly as
/// `RenderDeviceBox` does for a real placed device (see that file's own
/// doc comment: "ONE animation implementation... two consumers") rather
/// than adding a second shake mechanism — the ghost has no real
/// `DeviceInstance` yet, so a fixed placeholder id stands in for one.
const Uuid kPaletteGhostShakeId = Uuid('__palette-drag-ghost__');

/// Where a palette drag currently sits in the arm/lift/enter/commit
/// sequence (docs/04 §3.1). Exactly one drag is ever in flight — armed by
/// one `_PaletteRow`'s pointer-down, tracked for one pointer id at a time,
/// matching `CanvasIntentDetector`'s own single-`_dragPointer` convention.
enum PaletteDragPhase {
  /// No drag armed.
  none,

  /// Pointer down on a palette row, below the 4px slop (docs/04 §3.1 step
  /// 1: "Nothing until 4 px of movement, so a click still means 'show
  /// details'") — might still just be a click/double-click.
  armed,

  /// Threshold crossed; the pointer has not yet entered the canvas
  /// widget's bounds. The cursor card floats at the pointer; the source
  /// row is dimmed + outlined (docs/04 §3.1 step 2).
  lifted,

  /// The pointer is inside the canvas widget's bounds — the scene-accurate
  /// ghost is live, snapped + evaluated every frame (docs/04 §3.1 steps
  /// 3-5).
  dragging,
}

/// One frame's live evaluation of a palette drag's landing spot (docs/04
/// §3.1 steps 4-5): the hard-snapped `ruIndex`, whether either of CR-017's
/// two BLOCKING checks failed, and — when blocked — the user-facing reason
/// and (for an occupancy block only) the conflicting occupant's own scene
/// rect, so the painter can hatch it without re-deriving device layouts
/// itself.
@immutable
class PaletteDragEvaluation {
  const PaletteDragEvaluation({
    required this.ruIndex,
    required this.blocked,
    this.reason,
    this.blockingRect,
  });

  /// The hard-quantised RU the ghost is snapped to — always exactly
  /// `RackGeometry.ruIndexForCursorY`'s result (docs/04 §3.1 step 4: "Snap
  /// is instant", never interpolated).
  final int ruIndex;

  /// Whether either of the two BLOCKING CR-017 checks failed this frame:
  /// front U range free on this face, or fits within the rack extent. The
  /// five advisory/warning checks (opposite-face occupancy, depth-interval
  /// fit, clearance, mount-method compatibility, half-rack-on-bare-rails)
  /// are explicitly OUT OF SCOPE this stage — no validation/finding engine
  /// exists anywhere in this codebase (no `derived/validation.dart`) and
  /// building one is a separate, later M1 roadmap item. See
  /// `rack_canvas_screen.dart`'s `_evaluatePaletteDrop` for where this is
  /// computed.
  final bool blocked;

  /// The user-facing reason, e.g. `"Occupied by AMP-1 (U19-U20)."` or
  /// `"Needs 4U, only 2U free at top."` — null when not blocked. Wording
  /// matches `catalog_placement.dart`'s own `buildPlaceFromCatalogCommand`
  /// failure messages exactly, since a valid commit calls that same
  /// function with this frame's `ruIndex` and must never disagree with
  /// what was just shown.
  final String? reason;

  /// The conflicting occupant's own scene rect, for the blocked-drop
  /// hatch — null unless [blocked] is true AND the block is an occupancy
  /// conflict (an extent overflow has no single occupant to hatch).
  final DBox? blockingRect;
}

/// The observable palette-drag state machine. See the file header for the
/// full arm/track/commit mechanism and why this lives here rather than as
/// a `Draggable`/`DragTarget` pair.
class PaletteDragController extends ChangeNotifier {
  PaletteDragPhase _phase = PaletteDragPhase.none;
  String? _catalogId;
  int _deviceH = 0;
  Face _face = Face.front;
  String _displayName = '';
  String _badge = '';
  Set<PointerDeviceKind> _sourceKinds = const {};

  Offset? _cursorGlobal;
  DPt? _sceneCursor;
  PaletteDragEvaluation? _evaluation;

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

  PaletteDragPhase get phase => _phase;
  String? get catalogId => _catalogId;
  int get deviceH => _deviceH;
  Face get face => _face;
  String get displayName => _displayName;
  String get badge => _badge;
  Set<PointerDeviceKind> get sourceKinds => _sourceKinds;

  Offset? get cursorGlobal => _cursorGlobal;
  DPt? get sceneCursor => _sceneCursor;
  PaletteDragEvaluation? get evaluation => _evaluation;
  bool get releaseLingering => _releaseLingering;

  /// Whether a drag is armed, lifted, dragging, OR lingering after a
  /// blocked release right now — one of `CaretController.recompute`'s
  /// three activation inputs (docs/04 §3.4: the keyboard caret and an
  /// in-flight palette drag are mutually exclusive; caret_controller.dart
  /// names this exact field as its `dragInProgress` input).
  bool get isInProgress =>
      _phase != PaletteDragPhase.none || _releaseLingering;

  /// Whether the source palette row should currently show the dimmed +
  /// outlined "being dragged" chrome (docs/04 §3.1 step 2 — lift, not
  /// arm: "nothing until 4px of movement").
  bool get isLifted =>
      _phase == PaletteDragPhase.lifted || _phase == PaletteDragPhase.dragging;

  bool get isDragging => _phase == PaletteDragPhase.dragging;

  /// docs/04 §3.1 step 1: "Arm — pointer down on a palette row."
  void arm({
    required String catalogId,
    required int deviceH,
    required Face face,
    required String displayName,
    required String badge,
    required Set<PointerDeviceKind> sourceKinds,
  }) {
    _phase = PaletteDragPhase.armed;
    _catalogId = catalogId;
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
    if (_phase != PaletteDragPhase.armed) return;
    _phase = PaletteDragPhase.lifted;
    notifyListeners();
  }

  /// docs/04 §3.1 step 3: "Enter canvas" — the cursor card cross-fades
  /// into the scene-accurate ghost (the actual 100ms cross-fade animation
  /// is a documented, deferred visual-polish nicety this stage; see
  /// `rack_canvas_screen.dart`'s header and the final report).
  void enterCanvas() {
    if (_phase != PaletteDragPhase.lifted) return;
    _phase = PaletteDragPhase.dragging;
    notifyListeners();
  }

  /// The pointer backed out of the canvas widget's bounds mid-drag (still
  /// held down) — falls back to the pre-entry (lifted / cursor-card)
  /// state WITHOUT ending the gesture (the design's own "back out over the
  /// palette again" case).
  void exitCanvas() {
    if (_phase != PaletteDragPhase.dragging) return;
    _phase = PaletteDragPhase.lifted;
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
  void updateEvaluation(DPt sceneCursor, PaletteDragEvaluation evaluation) {
    if (_phase != PaletteDragPhase.dragging) return;
    _sceneCursor = sceneCursor;
    _evaluation = evaluation;
    notifyListeners();
  }

  /// docs/04 §3.1 step 5, a blocked pointer-up: freezes the current
  /// ghost/chip state ([releaseLingering] true) for the caller's own 1.2s
  /// `Timer` to clear via [reset]. Does not itself play the shake (that is
  /// `ShakeController.trigger(kPaletteGhostShakeId)`, driven by the same
  /// caller) — this controller only holds state, never animates.
  void beginBlockedRelease() {
    _phase = PaletteDragPhase.none;
    _releaseLingering = true;
    notifyListeners();
  }

  /// Clears everything: a valid commit, an Esc cancel, an outside-canvas
  /// release (SCOPE DECISION: no Staging Bin exists, so this is a plain
  /// no-op — see `rack_canvas_screen.dart`), or the end of a blocked
  /// release's 1.2s linger.
  void reset() {
    if (_phase == PaletteDragPhase.none &&
        _catalogId == null &&
        !_releaseLingering) {
      return; // already clear — avoid a spurious notify.
    }
    _phase = PaletteDragPhase.none;
    _catalogId = null;
    _deviceH = 0;
    _cursorGlobal = null;
    _sceneCursor = null;
    _evaluation = null;
    _releaseLingering = false;
    notifyListeners();
  }
}
