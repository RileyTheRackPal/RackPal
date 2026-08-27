// packages/rackpal_ui/lib/src/canvas/resize_preview_controller.dart
//
// UI-owned observable state for docs/04-rack-editor.md §4.1's THIRD way to
// change a rack's height: "dragging the rack's top edge (8 px band, snaps to
// whole U, a '24U (+3)' readout follows the cursor). While dragging SMALLER,
// any occupied U about to be removed is hatched in red IN REAL TIME, so the
// collision is visible before release."
//
// NOTHING HERE IS EVER COMMITTED. The drag runs no command at all — not one
// per frame, not one per U crossed. It accumulates a CANDIDATE height, and
// only the pointer-up hands that single integer to the screen's one height
// funnel (`_requestHeight`), which is what makes §4.1's "ALL producing one
// ResizeRackCommand" literally true for this gesture and what stops a drag
// across occupied territory from opening a modal per frame.
//
// WHY NOT `DragPreviewController`, restated because this is the THIRD
// preview-then-commit interaction on one screen and the question deserves a
// straight answer rather than an assumption. That controller's whole
// vocabulary is "ONE device landing at ONE ruIndex": `subjectId`, `deviceH`,
// `face`, `evaluation.ruIndex`, `blocked`, `blockingRect`. A rack resize has
// no device, no face, no ruIndex — and, crucially, NO BLOCKED VERDICT.
// Shrinking below occupancy is not refused; it opens §4.1's modal. Forcing
// this through that shape would mean a nullable everything and a `blocked`
// flag whose one honest value would be "sort of". What the three DO share is
// the discipline — UI-owned state holder, evaluate-then-commit, painter and
// floating chrome as readers, timers owned by the screen — and the PAINTER,
// which is where the real duplication risk lived. That is the same judgement
// `drag_preview_controller.dart` documents when it explains why the palette
// drag and the move drag are two instances of one type rather than one
// shared instance.
//
// THE HATCH IS COMPUTED FROM THE DOCUMENT, ON BOTH FACES, and that second
// half is a deliberate call the spec does not make. A rear-face occupant is
// not drawn on a front elevation, so hatching its U paints a red band across
// what looks like empty rack. The alternative — hatching only the displayed
// face — would let a user drag past a rear device seeing nothing at all, and
// §4.1's entire point is that "the collision is visible BEFORE release". A
// hatch on a U that is genuinely occupied (just not from this side) is
// truthful; silence is not. [doomedCount] exists so the readout chip can say
// how many devices that is, since the hatch alone cannot distinguish "the
// device you can see" from "the one behind it".

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:rackpal_core/rackpal_core.dart';

/// The observable "the rack's top edge is being dragged" state. See the file
/// header for what it deliberately does not share with
/// `DragPreviewController`.
class ResizePreviewController extends ChangeNotifier {
  bool _active = false;
  int _originalHeightU = 0;
  int _candidateHeightU = 0;
  Offset? _cursorGlobal;
  List<DBox> _doomedRects = const [];
  int _doomedCount = 0;

  /// Whether a top-edge drag is live. The painter draws its hatch and its
  /// candidate top-edge line only while this is true, and the screen's
  /// preview-exclusivity invariant guarantees no other preview is open at
  /// the same time.
  bool get isActive => _active;

  /// The rack's height when the drag began — the `24U (+3)` readout's
  /// baseline, and what a cancel returns to (trivially, since nothing was
  /// committed).
  int get originalHeightU => _originalHeightU;

  /// The whole-U height the pointer currently implies, already clamped to
  /// CR-038's `[1, 60]` by `RackGeometry.heightForTopEdgeY`.
  int get candidateHeightU => _candidateHeightU;

  /// The live global pointer position the readout chip follows.
  Offset? get cursorGlobal => _cursorGlobal;

  /// Scene-space rects of every occupant, ON EITHER FACE, whose highest U
  /// would fall outside the rack at [candidateHeightU] — §4.1's "any
  /// occupied U about to be removed is hatched in red IN REAL TIME". Empty
  /// while growing, which is why "growing is always safe" needs no special
  /// case anywhere in this class.
  List<DBox> get doomedRects => _doomedRects;

  /// How many devices [doomedRects] represents. Not `doomedRects.length` by
  /// accident but by construction — one rect per doomed occupant — and
  /// carried separately so the readout chip can name the cost in words for
  /// the rear-face occupants whose hatch lands on apparently-empty rack (see
  /// the file header).
  int get doomedCount => _doomedCount;

  /// §4.1's readout, verbatim in shape: `"24U (+3)"` while growing,
  /// `"9U (-3)"` while shrinking, and a bare `"12U"` at the identity
  /// position — a `(+0)` would be noise, and the drag genuinely is at its
  /// starting height there.
  String get readout {
    final delta = _candidateHeightU - _originalHeightU;
    if (delta == 0) return '${_candidateHeightU}U';
    return '${_candidateHeightU}U (${delta > 0 ? '+' : '-'}${delta.abs()})';
  }

  /// Arms the preview at the rack's current height. The candidate starts
  /// EQUAL to the original, so the first frame reads `"12U"` rather than
  /// flashing some interpolated value before the first move event lands.
  void begin(int originalHeightU) {
    _active = true;
    _originalHeightU = originalHeightU;
    _candidateHeightU = originalHeightU;
    _cursorGlobal = null;
    _doomedRects = const [];
    _doomedCount = 0;
    notifyListeners();
  }

  /// One frame of the drag. Called on every pointer move; deliberately
  /// cheap, and deliberately notifying unconditionally — the hatch, the
  /// candidate line and the chip position all move with the cursor even when
  /// the snapped height does not change.
  void update({
    required int candidateHeightU,
    required Offset? cursorGlobal,
    required List<DBox> doomedRects,
  }) {
    if (!_active) return;
    _candidateHeightU = candidateHeightU;
    _cursorGlobal = cursorGlobal;
    _doomedRects = doomedRects;
    _doomedCount = doomedRects.length;
    notifyListeners();
  }

  /// Tears the preview down — on commit, on `Esc`, on pointer-cancel, or
  /// when another interaction claims the screen. There is nothing to roll
  /// back: the drag never mutated the document.
  void cancel() {
    if (!_active) return; // already clear — avoid a spurious notify.
    _active = false;
    _candidateHeightU = _originalHeightU;
    _cursorGlobal = null;
    _doomedRects = const [];
    _doomedCount = 0;
    notifyListeners();
  }
}
