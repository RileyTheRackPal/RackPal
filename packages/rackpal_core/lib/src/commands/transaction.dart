// docs/03-architecture.md §5.3, quoted in full and transcribed exactly.
// Reverse-order revert is mandatory: deleting a device and its links must
// restore the device BEFORE the links that reference it, or the link
// restore dereferences a missing device.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/selection.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// A group of [Command]s applied and undone as one undo-stack entry.
/// Nested transactions flatten into the outermost — see
/// `DocumentController.transact` — so the user sees exactly one undo
/// entry regardless of how many commands a single user gesture produced.
///
/// Generic over the same aggregate its children are (M4-A, CR-106): a
/// transaction is a composite `Command`, so it can no more be
/// document-bound than the interface it implements.
final class Transaction<A> extends Command<A> {
  Transaction(
    this.label,
    this.children,
    this.selectionBefore,
    this.selectionAfter,
  ) : timestamp = DateTime.now();

  @override
  final LabelKey label;
  final List<Command<A>> children;

  /// Nullable since M4-A: [Selection] is a set of `Uuid`s, and an
  /// aggregate whose parts are not `Uuid`-keyed has no selection to
  /// record — a `TemplateBody`'s ports are keyed by `PortKey`. Null is
  /// "this aggregate does not model selection", not "nothing was
  /// selected"; an empty [Selection] means the latter and the two must
  /// not share a value (G4's shape again).
  ///
  /// **These two are not what undo restores.** `UndoStack` captures its
  /// own `selectionBefore`/`selectionAfter` per entry and those are the
  /// pair `undoSelection`/`redoSelection` read; the copies here are used
  /// only to carry a merge forward. Kept because docs/03-architecture.md
  /// §5.3 declares them on `Transaction`.
  final Selection? selectionBefore;
  final Selection? selectionAfter;

  /// Diagnostics only — not part of any correctness property; commands
  /// themselves carry the `now`/`actor` that reach `EntityMeta`, per this
  /// package's injectable-`Clock` policy (docs/03-architecture.md §5.4's
  /// "do not call DateTime.now() directly").
  final DateTime timestamp;

  /// The union of the children's masks, or `null` when NO child declares
  /// one — a transaction over an aggregate with no epoch model. A child
  /// that declares `EpochMask.none` still counts as declaring, so a
  /// document transaction whose commands all touch nothing folds to
  /// `none` and not to null: those are different answers (see
  /// [DocEpochs.bump]).
  @override
  EpochMask? get touches {
    EpochMask? acc;
    for (final c in children) {
      final t = c.touches;
      if (t == null) continue;
      acc = acc == null ? t : acc | t;
    }
    return acc;
  }

  @override
  Iterable<Uuid> get affects => children.expand((c) => c.affects);

  @override
  void apply(A aggregate) {
    for (final c in children) {
      c.apply(aggregate);
    }
  }

  @override
  void revert(A aggregate) {
    for (var i = children.length - 1; i >= 0; i--) {
      children[i].revert(aggregate);
    }
  }

  // `DocumentController.run()` wraps EVERY command in a `Transaction`
  // before it ever reaches `UndoStack.push` — so without forwarding
  // `mergeKey`/`mergeWith` from a single-child transaction to that one
  // child, §5.4's "Coalescing policy" (inspector typing, arrow-key
  // nudges) could never actually fire: `UndoStack.push`'s merge check
  // compares `top.command.mergeKey`, and `top.command` is always a
  // `Transaction`, never the raw `MoveDeviceCommand`/etc. the individual
  // command classes declare a `mergeKey` for. This is the elided piece
  // that makes those declarations reachable rather than dead code.
  @override
  Object? get mergeKey =>
      children.length == 1 ? children.single.mergeKey : null;

  @override
  Command<A>? mergeWith(Command<A> next) {
    if (next is! Transaction<A> ||
        children.length != 1 ||
        next.children.length != 1) {
      return null;
    }
    final mergedChild = children.single.mergeWith(next.children.single);
    if (mergedChild == null) return null;
    return Transaction<A>(
      next.label,
      [mergedChild],
      selectionBefore,
      next.selectionAfter,
    );
  }
}
