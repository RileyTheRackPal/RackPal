// What `Ctrl+Z` acts on right now (`#874`, DR-159 §11.158.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THERE ARE TWO UNDO STACKS AND CR-106 KEEPS THEM APART
// ═══════════════════════════════════════════════════════════════════════
// The document's, on `DocumentController`, and the Device Builder's own,
// scoped to the `TemplateBody` being edited and dying with the window.
// `KeyScope.builder`'s note already refuses to share a scope between them
// because *"a scope shared with the document's canvas would say the two
// stacks were one thing"*.
//
// DR-159 §11.158.5 rules that `Ctrl+Z` reaches the BUILDER's stack while
// the builder is open. So the shell's one global handler has to be able
// to act on either, and this is the handle it acts through.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY CLOSURES AND NOT THE STACK ITSELF
// ═══════════════════════════════════════════════════════════════════════
// Handing the shell a `TemplateEditSession` would let it call `undoLast`
// directly, and the builder would not repaint: that screen's state is
// rebuilt by its own `setState`, not by the document's listeners. The
// closures below are the builder's own methods, so pressing `Ctrl+Z` from
// anywhere goes through exactly the code path its toolbar button does.
import 'package:flutter/foundation.dart';

/// One undo stack, as the shell needs to see it.
///
/// Rebuilt and re-reported whenever the stack behind it moves, because
/// [canUndo] and [undoLabelKey] are what the Edit menu renders and a
/// stale copy would offer to take back something that is already back.
@immutable
final class UndoTarget {
  const UndoTarget({
    required this.canUndo,
    required this.canRedo,
    required this.undoLabelKey,
    required this.redoLabelKey,
    required this.undo,
    required this.redo,
  });

  final bool canUndo;
  final bool canRedo;

  /// `LabelKey.name`, as `UndoStack` exposes it: core hands out a stable
  /// identifier rather than a Flutter-facing type, and `undo_labels.dart`
  /// resolves it back to what the menu prints.
  final String? undoLabelKey;
  final String? redoLabelKey;

  final VoidCallback undo;
  final VoidCallback redo;

  /// Value equality on the RENDERED fields only.
  ///
  /// The two closures are deliberately excluded: they are freshly
  /// allocated by the reporting widget on every notification, so
  /// comparing them would make every target unequal to every other and
  /// turn the shell's "has anything changed?" guard into "always".
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UndoTarget &&
          other.canUndo == canUndo &&
          other.canRedo == canRedo &&
          other.undoLabelKey == undoLabelKey &&
          other.redoLabelKey == redoLabelKey;

  @override
  int get hashCode => Object.hash(canUndo, canRedo, undoLabelKey, redoLabelKey);

  @override
  String toString() =>
      'UndoTarget(canUndo: $canUndo, canRedo: $canRedo, '
      'undo: $undoLabelKey, redo: $redoLabelKey)';
}
