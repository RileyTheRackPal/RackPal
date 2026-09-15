// docs/03-architecture.md §5.4/§5.6, quoted in full and transcribed
// exactly, plus the undo()/redo()/canRedo/redoLabelKey members the quoted
// snippet leaves elided but "canUndo/canRedo" in poison()'s own comment
// obviously requires.
//
// CR-106 declares `UndoStack<A>` generic over the aggregate it undoes,
// since the Device Builder's own stack (docs/03-architecture.md §5.6)
// undoes a `TemplateBody`, not a `RackDocument`.
//
// M0 SHIPPED THIS HALF-DONE AND SAID SO: the class carried `<A>` for
// CR-106's documented intent while `undo`/`redo` concretely took a
// `RackDocument`, because `Command` itself was hard-typed to one (§5.1,
// transcribed as given) and making it generic was a bigger change than
// M0's exit criterion called for. The header said to revisit this
// together with `Command` if/when the builder's stack was built.
//
// **M4-A is that revisit, and the gap is closed.** `Command<A>` is
// generic (command.dart), `Transaction<A>` with it, and the members
// below take an `A`. The document instantiation is unchanged in
// behaviour: `DocumentController` holds an `UndoStack<RackDocument>` and
// still records CR-094's stateId-before/after per entry.
import 'package:collection/collection.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/selection.dart';

final class _Entry<A> {
  _Entry(
    this.command,
    this.selectionBefore,
    this.selectionAfter,
    this.at,
    this.stateIdBefore,
    this.stateIdAfter,
  );

  final Command<A> command;

  /// Null when the aggregate models no selection — see
  /// `Transaction.selectionBefore` (transaction.dart) for why that is not
  /// an empty [Selection]. The document stack always records a real one.
  final Selection? selectionBefore;
  final Selection? selectionAfter;
  final DateTime at;

  /// CR-094: "each undo entry records the stateId before and after". These
  /// are what let `DocumentController` RESTORE `doc.stateId` on undo/redo
  /// instead of merely advancing it, which is in turn what makes
  /// `isDirty == stateId != savedStateId` exact in both directions —
  /// undoing back to the save point really does read as clean.
  final int stateIdBefore;
  final int stateIdAfter;
}

/// How many steps a stack keeps when nobody chose a depth: canon
/// §10.12(a)'s 200, and docs/03 §11.1's scale target.
const int kDefaultUndoDepth = 200;

/// The shallowest depth a person may choose (DR-172). It keeps a slip of
/// the keyboard from leaving a handful of steps behind.
const int kMinUndoDepth = 50;

/// The deepest depth a person may choose (DR-172). docs/03 §11.1 budgets
/// 200 entries and sets no hard cap and no memory figure, so the ceiling
/// keeps the setting within reach of measured ground.
const int kMaxUndoDepth = 1000;

/// The undo/redo history for one aggregate. Linear undo — no undo tree in
/// v1 (§5.4): pushing a new command after some undos discards the redo
/// tail.
class UndoStack<A> {
  UndoStack({
    int maxEntries = kDefaultUndoDepth,
    this.mergeWindow = const Duration(milliseconds: 400),
  }) : assert(maxEntries > 0, 'an undo stack must keep at least one step'),
       _maxEntries = maxEntries;

  /// How many steps this stack keeps. Changed after construction only by
  /// [resize], because DR-172 makes a new depth take effect immediately.
  int get maxEntries => _maxEntries;
  int _maxEntries;

  final Duration mergeWindow;

  /// How many of the oldest steps this stack has dropped since it was
  /// built, by [push] past [maxEntries] or by [resize] below [depth].
  ///
  /// AC-058 D5 gives the cap a signal instead of a silent drop, and this is
  /// what the signal reads. A COUNT RATHER THAN A FLAG, so a caller can tell
  /// the first drop from a later one and a resize can say how many went.
  int get droppedCount => _droppedCount;
  int _droppedCount = 0;

  final List<_Entry<A>> _done = [];
  final List<_Entry<A>> _undone = [];
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
  /// `rackpal_ui`'s `SelectionController`; the `selectionBefore`/`After`
  /// were already captured in M0, they simply had no reader.
  ///
  /// Since M4-A `null` carries a second meaning — an aggregate that
  /// models no selection recorded none — so a caller that must tell the
  /// two apart reads [canUndo] first. No caller does: the only reason to
  /// read this is to restore a selection, and there is nothing to restore
  /// in either case.
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
  EpochMask? push(
    Command<A> c,
    Selection? before,
    Selection? after,
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
    if (_done.length > _maxEntries) {
      _done.removeAt(0);
      _droppedCount++;
    }
    return c.touches;
  }

  /// Makes [maxEntries] [entries], dropping the oldest steps at once when
  /// the stack holds more, and returns how many went: 0 when it grew or
  /// already fitted.
  ///
  /// THE REDO TAIL IS NOT TRIMMED. It holds steps undone from the top, not
  /// the oldest history, and the cap has only ever bounded the done stack,
  /// which is what [push] enforces too.
  int resize(int entries) {
    assert(entries > 0, 'an undo stack must keep at least one step');
    _maxEntries = entries;
    final over = _done.length - entries;
    if (over <= 0) return 0;
    _done.removeRange(0, over);
    _droppedCount += over;
    return over;
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
  EpochMask? undo(A aggregate) {
    if (!canUndo) return EpochMask.none;
    final entry = _done.removeLast();
    entry.command.revert(aggregate);
    _undone.add(entry);
    return entry.command.touches;
  }

  /// Re-applies the top of [_undone] and pushes it back onto [_done].
  /// Returns the `EpochMask` the redone command touched, or
  /// [EpochMask.none] if there was nothing to redo.
  EpochMask? redo(A aggregate) {
    if (!canRedo) return EpochMask.none;
    final entry = _undone.removeLast();
    entry.command.apply(aggregate);
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
