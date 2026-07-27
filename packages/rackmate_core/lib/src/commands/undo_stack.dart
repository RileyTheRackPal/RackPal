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
  _Entry(
    this.command,
    this.selectionBefore,
    this.selectionAfter,
    this.at,
    this.stateIdBefore,
    this.stateIdAfter,
  );

  final Command command;
  final Selection selectionBefore;
  final Selection selectionAfter;
  final DateTime at;

  /// CR-094: "each undo entry records the stateId before and after". These
  /// are what let `DocumentController` RESTORE `doc.stateId` on undo/redo
  /// instead of merely advancing it, which is in turn what makes
  /// `isDirty == stateId != savedStateId` exact in both directions —
  /// undoing back to the save point really does read as clean.
  final int stateIdBefore;
  final int stateIdAfter;
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

  /// The selection to restore when the NEXT [undo] runs — the
  /// `selectionBefore` captured with the entry currently on top of the done
  /// stack, or `null` if there is nothing to undo. Read this BEFORE calling
  /// [undo], since [undo] pops that entry (docs/03-architecture.md §4.4:
  /// "undo restores it, so undoing a delete does not leave the caret on an
  /// entity that no longer exists"). Added in M1 to close the loop with
  /// `rackmate_ui`'s `SelectionController`; the `selectionBefore`/`After`
  /// were already captured in M0, they simply had no reader.
  Selection? get undoSelection => canUndo ? _done.last.selectionBefore : null;

  /// The selection to restore when the NEXT [redo] runs — the
  /// `selectionAfter` of the entry currently on top of the undone stack.
  /// Read before calling [redo].
  Selection? get redoSelection => canRedo ? _undone.last.selectionAfter : null;

  /// The `stateId` to restore when the NEXT [undo] runs — the
  /// `stateIdBefore` of the entry on top of the done stack, or `null` if
  /// there is nothing to undo. Read BEFORE calling [undo], which pops it.
  int? get undoStateId => canUndo ? _done.last.stateIdBefore : null;

  /// The `stateId` to restore when the NEXT [redo] runs — the
  /// `stateIdAfter` of the entry on top of the undone stack. Read before
  /// calling [redo].
  int? get redoStateId => canRedo ? _undone.last.stateIdAfter : null;

  /// How many undo entries are currently on the done stack.
  int get depth => _done.length;

  /// Coalesces into the stack top iff `mergeKey` matches AND the window
  /// has not elapsed.
  ///
  /// [stateIdBefore]/[stateIdAfter] are the ids of the document state on
  /// either side of [c] (CR-094). On a MERGE the surviving entry keeps
  /// the original top's `stateIdBefore` and takes the new
  /// [stateIdAfter] — the merged pair is one undo step, so it spans from
  /// where the first edit started to where the second one ended, and the
  /// intermediate id is simply retired. The allocator never reuses an id,
  /// so a retired one can never be mistaken for a live state.
  EpochMask push(
    Command c,
    Selection before,
    Selection after,
    DateTime now,
    int stateIdBefore,
    int stateIdAfter,
  ) {
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
          top.stateIdBefore,
          stateIdAfter,
        );
        return c.touches;
      }
    }
    _done.add(_Entry(c, before, after, now, stateIdBefore, stateIdAfter));
    if (_done.length > maxEntries) _done.removeAt(0);
    return c.touches;
  }

  /// How many undo (or redo) steps separate the state identified by
  /// [stateId] from [currentStateId] — i.e. how many edits stand between
  /// "what is on disk" and "what is on screen".
  ///
  /// Returns `null` when [stateId] is NOT on this stack's timeline: the
  /// stack was poisoned, the entry aged out past [maxEntries], or the id
  /// was retired by a merge. Null means UNKNOWN and callers must say so
  /// rather than substitute a plausible number (G4) — "12 unsaved
  /// changes" that is actually 13 is worse than no count at all.
  int? distanceTo(int stateId, int currentStateId) {
    if (stateId == currentStateId) return 0;
    if (_poisoned) return null;
    // Undo direction: after k undos, doc.stateId == _done[len - k].
    // stateIdBefore.
    for (var k = 1; k <= _done.length; k++) {
      if (_done[_done.length - k].stateIdBefore == stateId) return k;
    }
    // Redo direction: after k redos, doc.stateId == _undone[len - k].
    // stateIdAfter. This is the "saved, then undone past the save point"
    // case, which is just as dirty as having edited forward.
    for (var k = 1; k <= _undone.length; k++) {
      if (_undone[_undone.length - k].stateIdAfter == stateId) return k;
    }
    return null;
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
