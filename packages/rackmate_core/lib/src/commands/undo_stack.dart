// docs/03-architecture.md §5.4/§5.6, quoted in full and transcribed
// exactly, plus the undo()/redo()/canRedo/redoLabelKey members the quoted
// snippet leaves elided but "canUndo/canRedo" in poison()'s own comment
// obviously requires.
//
// CR-106 declares `UndoStack<A>` generic over the aggregate it undoes,
// since the Device Builder's own stack (docs/03-architecture.md §5.6)
// will one day undo a `TemplateBody`, not a `RackDocument`. The `Command`
// interface this milestone builds (command.dart) is NOT itself generic —
// its `apply`/`revert` are hard-typed to `RackDocument` (§5.1, transcribed
// as given) — so full generic reuse would need `Command<A>` too, which is
// a bigger change than M0's exit criterion calls for. This class keeps
// the `<A>` type parameter for CR-106's documented intent and for
// `DocumentController`'s `UndoStack<RackDocument>` instantiation to read
// correctly, but its `undo`/`redo` concretely take a `RackDocument` — the
// only aggregate any `Command` in this milestone can act on. Revisit
// together with `Command` if/when the Device Builder's own stack is
// built.
import 'package:collection/collection.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/selection.dart';
import 'package:rackmate_core/src/model/rack_document.dart';

final class _Entry {
  _Entry(this.command, this.selectionBefore, this.selectionAfter, this.at);

  final Command command;
  final Selection selectionBefore;
  final Selection selectionAfter;
  final DateTime at;
}

/// The undo/redo history for one aggregate. Linear undo — no undo tree in
/// v1 (§5.4): pushing a new command after some undos discards the redo
/// tail.
class UndoStack<A> {
  UndoStack({
    this.maxEntries = 200,
    this.mergeWindow = const Duration(milliseconds: 400),
  });

  final int maxEntries;
  final Duration mergeWindow;

  final List<_Entry> _done = [];
  final List<_Entry> _undone = [];
  bool _poisoned = false;

  bool get canUndo => !_poisoned && _done.isNotEmpty;
  bool get canRedo => !_poisoned && _undone.isNotEmpty;

  String? get undoLabelKey => _done.lastOrNull?.command.label.name;
  String? get redoLabelKey => _undone.lastOrNull?.command.label.name;

  /// Coalesces into the stack top iff `mergeKey` matches AND the window
  /// has not elapsed.
  EpochMask push(Command c, Selection before, Selection after, DateTime now) {
    _undone.clear(); // linear undo; no undo tree in v1
    final top = _done.lastOrNull;
    if (top != null &&
        c.mergeKey != null &&
        top.command.mergeKey == c.mergeKey &&
        now.difference(top.at) < mergeWindow) {
      final merged = top.command.mergeWith(c);
      if (merged != null) {
        _done[_done.length - 1] = _Entry(
          merged,
          top.selectionBefore,
          after,
          now,
        );
        return c.touches;
      }
    }
    _done.add(_Entry(c, before, after, now));
    if (_done.length > maxEntries) _done.removeAt(0);
    return c.touches;
  }

  /// Reverts the top of [_done] and pushes it onto [_undone]. Returns the
  /// `EpochMask` the undone command touched, or [EpochMask.none] if there
  /// was nothing to undo.
  EpochMask undo(RackDocument doc) {
    if (!canUndo) return EpochMask.none;
    final entry = _done.removeLast();
    entry.command.revert(doc);
    _undone.add(entry);
    return entry.command.touches;
  }

  /// Re-applies the top of [_undone] and pushes it back onto [_done].
  /// Returns the `EpochMask` the redone command touched, or
  /// [EpochMask.none] if there was nothing to redo.
  EpochMask redo(RackDocument doc) {
    if (!canRedo) return EpochMask.none;
    final entry = _undone.removeLast();
    entry.command.apply(doc);
    _done.add(entry);
    return entry.command.touches;
  }

  /// Irreversibly disables undo/redo — see docs/03-architecture.md §12.3:
  /// a `revert()` that itself throws mid-rollback (a double-fault) leaves
  /// the document in a state no command in this stack can be trusted to
  /// reconstruct, so `DocumentController._rollback` calls this rather
  /// than risk further corruption from a subsequent undo/redo.
  void poison() {
    _poisoned = true;
    _done.clear();
    _undone.clear();
  }
}
