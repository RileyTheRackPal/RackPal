// rackpal_ui/src/canvas/selection_controller.dart
//
// The REAL SelectionController (docs/03-architecture.md §4.4). M0 left a
// bare `Selection` value type in rackpal_core (commands/selection.dart)
// with an explicit note that "the real SelectionController lives in
// rackpal_ui"; this is that controller. The split is deliberate: core owns
// the plain persisted-shape value (what a `Transaction` captures as
// `selectionBefore`/`selectionAfter`), and the UI owns the observable,
// mutable wrapper the canvas overlay and inspector listen to. There is ONE
// `Selection` type — core's — reused here via [snapshot]/[restore]; this
// file does not declare a second.
//
// INVARIANT (docs/03 §4.4): selection is OBSERVED, never persisted. Nothing
// here touches `DocumentController`'s mutation path, bumps an epoch, or
// marks the document dirty — selecting a device must not dirty the file.
// The controller reads ids; it never writes to the document.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// How an [SelectionController.apply] call folds its hits into the current
/// set (docs/04 §3.5's click model).
enum SelectMode {
  /// Plain click: the hits become the entire selection.
  replace,

  /// Add the hits to the current selection (Ctrl+click on an unselected id).
  add,

  /// Remove the hits from the current selection (Ctrl+click on a selected
  /// id). Ctrl+click is thus "add if absent else subtract", decided by the
  /// caller from current membership; this controller just performs the set
  /// operation it is told.
  subtract,
}

/// The observable selection for the rack/schematic canvas: which entity ids
/// are selected, and which one has editing focus (last clicked — drives the
/// inspector). A [ChangeNotifier] so the canvas repaints selection chrome
/// and the (future) inspector rebuilds, without any of it living in the
/// document.
class SelectionController extends ChangeNotifier {
  Set<Uuid> _ids = <Uuid>{};
  Uuid? _focus;

  /// The selected ids, as an unmodifiable view — mutate only through
  /// [apply]/[restore]/[clear] so every change notifies listeners.
  Set<Uuid> get ids => UnmodifiableSetView(_ids);

  /// The focused id (last clicked), or null. Drives the inspector.
  Uuid? get focus => _focus;

  bool get isEmpty => _ids.isEmpty;
  bool get isNotEmpty => _ids.isNotEmpty;
  int get length => _ids.length;

  bool contains(Uuid id) => _ids.contains(id);

  /// Folds [hits] into the selection per [mode], then notifies.
  ///
  /// Focus rule (docs/03 §4.4: "last clicked — drives the inspector"):
  /// * [SelectMode.replace] — focus becomes the last hit, or null when
  ///   [hits] is empty (a click on empty canvas both clears and defocuses).
  /// * [SelectMode.add] — focus becomes the last added hit (what you just
  ///   Ctrl+clicked into the selection), unchanged if [hits] is empty.
  /// * [SelectMode.subtract] — focus is cleared iff it was among the ids
  ///   just removed; otherwise it is left as-is. A minimal, honest choice:
  ///   moving focus to some other surviving member would be guessing which.
  void apply(Iterable<Uuid> hits, SelectMode mode) {
    final hitList = hits.toList(growable: false);
    switch (mode) {
      case SelectMode.replace:
        _ids = hitList.toSet();
        _focus = hitList.isEmpty ? null : hitList.last;
      case SelectMode.add:
        _ids = {..._ids, ...hitList};
        if (hitList.isNotEmpty) _focus = hitList.last;
      case SelectMode.subtract:
        final removed = hitList.toSet();
        _ids = _ids.difference(removed);
        if (_focus != null && removed.contains(_focus)) _focus = null;
    }
    notifyListeners();
  }

  /// Clears the selection entirely (equivalent to `apply(const [],
  /// SelectMode.replace)`), notifying.
  void clear() => apply(const [], SelectMode.replace);

  /// An immutable [Selection] snapshot for a `Transaction` to capture as
  /// its before/after. Independent copy, so a later mutation here cannot
  /// alias what the undo stack recorded.
  Selection snapshot() => Selection(ids: Set<Uuid>.of(_ids), focus: _focus);

  /// Restores a [Selection] captured by an undo/redo — the counterpart to
  /// [snapshot]. Copies the incoming ids so the controller never aliases
  /// the undo stack's own set. Notifies so the canvas re-highlights.
  void restore(Selection s) {
    _ids = Set<Uuid>.of(s.ids);
    _focus = s.focus;
    notifyListeners();
  }
}
