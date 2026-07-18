// docs/03-architecture.md §5.3, quoted in full and transcribed exactly.
// Reverse-order revert is mandatory: deleting a device and its links must
// restore the device BEFORE the links that reference it, or the link
// restore dereferences a missing device.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/selection.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// A group of [Command]s applied and undone as one undo-stack entry.
/// Nested transactions flatten into the outermost — see
/// `DocumentController.transact` — so the user sees exactly one undo
/// entry regardless of how many commands a single user gesture produced.
final class Transaction extends Command {
  Transaction(
    this.label,
    this.children,
    this.selectionBefore,
    this.selectionAfter,
  ) : timestamp = DateTime.now();

  @override
  final LabelKey label;
  final List<Command> children;
  final Selection selectionBefore;
  final Selection selectionAfter;

  /// Diagnostics only — not part of any correctness property; commands
  /// themselves carry the `now`/`actor` that reach `EntityMeta`, per this
  /// package's injectable-`Clock` policy (docs/03-architecture.md §5.4's
  /// "do not call DateTime.now() directly").
  final DateTime timestamp;

  @override
  EpochMask get touches =>
      children.fold(const EpochMask(0), (m, c) => m | c.touches);

  @override
  Iterable<Uuid> get affects => children.expand((c) => c.affects);

  @override
  void apply(RackDocument doc) {
    for (final c in children) {
      c.apply(doc);
    }
  }

  @override
  void revert(RackDocument doc) {
    for (var i = children.length - 1; i >= 0; i--) {
      children[i].revert(doc);
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
  Command? mergeWith(Command next) {
    if (next is! Transaction ||
        children.length != 1 ||
        next.children.length != 1) {
      return null;
    }
    final mergedChild = children.single.mergeWith(next.children.single);
    if (mergedChild == null) return null;
    return Transaction(
      next.label,
      [mergedChild],
      selectionBefore,
      next.selectionAfter,
    );
  }
}
