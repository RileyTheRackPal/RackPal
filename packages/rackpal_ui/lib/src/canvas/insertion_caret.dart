// packages/rackpal_ui/lib/src/canvas/insertion_caret.dart
//
// The insertion caret (docs/04-rack-editor.md §3.4): "a first-class
// object — a 2px accent line at a U boundary with a 6px triangle at each
// rail and the ruler label highlighted. It exists whenever the canvas has
// focus and nothing is selected, and it is what makes keyboard-only
// placement work." Sibling to [SelectionController] in every respect that
// matters (docs/03-architecture.md §4.4's split): UI-owned, observed, a
// plain `ChangeNotifier`, never persisted.
//
// WHY THIS LIVES HERE, NOT IN rackpal_core: core's `Selection` value type
// exists ONLY because `Transaction`/`UndoStack` must capture and restore
// it as before/after state on every undo entry (selection_controller.dart's
// own doc comment on the split). Nothing in the spec has the caret
// captured or restored by undo/redo — no `Transaction` ever touches it —
// so there is no forcing reason to give core a mirror type, and adding one
// would be new core surface with no core consumer. Undoing a caret-placed
// device does NOT rewind the caret; this is a deliberate, documented
// simplification (see docs/m1-implementation-log.md), not an oversight.

import 'package:flutter/foundation.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// Where the next quick-add placement would land if inserted right now.
@immutable
class InsertionCaret {
  const InsertionCaret({required this.rackId, required this.ruIndex});

  final Uuid rackId;

  /// 1-based, bottom-origin — the SAME domain as `RailPlacement.ruIndex`:
  /// the U a placement's LOWEST U would occupy if inserted at the caret
  /// right now. Deliberately not a separate "boundary index" scheme (0..
  /// heightU): the caret LINE is simply drawn at
  /// `RackGeometry.yBottomOfU(ruIndex)`, which is exactly a future
  /// device's bottom edge if placed here, so caret math and placement math
  /// can never drift apart. Range: `[1, rack.heightU]`.
  final int ruIndex;

  @override
  bool operator ==(Object other) =>
      other is InsertionCaret &&
      other.rackId == rackId &&
      other.ruIndex == ruIndex;

  @override
  int get hashCode => Object.hash(rackId, ruIndex);

  @override
  String toString() => 'InsertionCaret(rackId: $rackId, ruIndex: $ruIndex)';
}

/// The observable insertion caret for the rack canvas.
///
/// ACTIVATION (docs/04 §3.4): the caret is *displayed*, and arrow keys
/// drive IT rather than a nudge, exactly when `selection is empty AND the
/// canvas has focus AND no palette drag is in progress` — [recompute] is
/// how the screen feeds that three-input formula in every time one of the
/// inputs changes (selection, canvas focus, or a palette drag starting/
/// ending — the last is fed from `DragPreviewController.isInProgress`,
/// docs/04 §3.1's drag-from-palette-to-rails stage). This controller does
/// not poll or read any of the three inputs itself.
///
/// [caret] is gated on that formula (what the painter and the arrow-key
/// dispatcher consult). [stickyCaret] is NOT gated — it is the same
/// underlying position, exposed for placement targeting (quick-add), which
/// deliberately does not go stale just because focus is transiently on the
/// palette search field mid `/`-then-type-then-Enter (see
/// `RackCanvasScreen._placeFromCatalog`'s doc comment for the full
/// reasoning — a considered deviation from treating "caret exists" as a
/// single yes/no bit).
class CaretController extends ChangeNotifier {
  InsertionCaret? _caret; // null = never seeded this session
  bool _active = false; // last computed activation state
  int _heightU = 1; // the rack height last seen by recompute(), for clamping

  /// The current caret, gated on [active] — null when a selection exists,
  /// the canvas lacks focus, or a palette drag is in progress. This is
  /// what chrome (the painter) and the arrow-key dispatcher should read.
  InsertionCaret? get caret => _active ? _caret : null;

  /// The caret's position regardless of [active] — see the class doc.
  /// Null only before the very first [recompute] call ever seeds one.
  InsertionCaret? get stickyCaret => _caret;

  /// Whether the activation formula currently holds.
  bool get active => _active;

  /// Recomputes activation and, on first activation or a rack change,
  /// seeds the caret's position. Call this from every place the screen's
  /// selection/focus/drag/rack state changes.
  ///
  /// [smartDefaultRuIndex] is consulted ONLY the first time this rack's
  /// caret is seeded (or re-seeded after switching to a different rack) —
  /// once seeded, the caret is STICKY: its position survives losing and
  /// regaining activation, clamped only to the rack's current height.
  void recompute({
    required bool selectionEmpty,
    required bool canvasHasFocus,
    required bool dragInProgress,
    required Rack rack,
    required int? smartDefaultRuIndex,
  }) {
    final nextActive = selectionEmpty && canvasHasFocus && !dragInProgress;
    var changed = false;
    _heightU = rack.heightU;

    final existing = _caret;
    if (existing == null || existing.rackId != rack.id) {
      final seed = (smartDefaultRuIndex ?? 1).clamp(1, rack.heightU);
      _caret = InsertionCaret(rackId: rack.id, ruIndex: seed);
      changed = true;
    } else {
      final clamped = existing.ruIndex.clamp(1, rack.heightU);
      if (clamped != existing.ruIndex) {
        _caret = InsertionCaret(rackId: rack.id, ruIndex: clamped);
        changed = true;
      }
    }

    if (nextActive != _active) {
      _active = nextActive;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Moves the caret to [ruIndex], clamped to `[1, heightU]` (the height
  /// [recompute] last saw). A no-op (no notify) if already there, or if
  /// [recompute] has never seeded a caret yet.
  void moveTo(int ruIndex) {
    final current = _caret;
    if (current == null) return;
    final clamped = ruIndex.clamp(1, _heightU);
    if (clamped == current.ruIndex) return;
    _caret = InsertionCaret(rackId: current.rackId, ruIndex: clamped);
    notifyListeners();
  }

  /// `moveTo(current + delta)` — the shared step for Up/Down (±1) and
  /// PgUp/PgDn (±10).
  void moveBy(int delta) => moveTo((_caret?.ruIndex ?? 1) + delta);
}
