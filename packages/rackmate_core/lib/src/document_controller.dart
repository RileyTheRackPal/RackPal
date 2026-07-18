// docs/03-architecture.md §5.4, quoted in full and transcribed, with the
// elided pieces (`TxnScope`, `_TxnBuilder`, `selection`, `clock`,
// `_savedStateId`, `_rollback`) filled in per this package's governing
// instructions. `derived`/`DerivedRegistry` (the quoted snippet's
// `derived.invalidateTouching(txn.affects)` line) is a later milestone's
// derived-data pipeline (§6) that does not exist yet — omitted rather
// than stubbed, since there is nothing yet for it to invalidate.
//
// `SnapshotCommand` (§5.5) is deferred for M0 — see
// commands/snapshot_command.dart's header comment.
import 'package:rackmate_core/src/commands/clock.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/selection.dart';
import 'package:rackmate_core/src/commands/transaction.dart';
import 'package:rackmate_core/src/commands/undo_stack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';

/// The scope a `DocumentController.transact` body mutates through.
/// Commands `apply()` IMMEDIATELY inside [add], not at commit, so a later
/// command in the same transaction sees the results of an earlier one
/// ("add device, then connect to it", §5.4).
final class TxnScope {
  TxnScope(this._children, this._doc);

  final List<Command> _children;
  final RackDocument _doc;

  void add(Command c) {
    c.apply(_doc);
    _children.add(c);
  }
}

/// Accumulates one in-progress transaction's children and before/after
/// selection while `DocumentController.transact`'s body runs.
final class _TxnBuilder {
  _TxnBuilder(this.label, this.selectionBefore);

  final LabelKey label;
  final Selection selectionBefore;
  final List<Command> children = [];
}

/// THE only mutation entry point (docs/03-architecture.md §2.2) — every
/// document edit goes through [run]/[transact], which is what makes undo
/// exact and the epoch counters trustworthy.
class DocumentController {
  DocumentController(
    this.doc, {
    this.clock = const SystemClock(),
    this.actor = 'local',
  }) : _savedStateId = doc.stateId;

  final RackDocument doc;

  /// Injected so nothing in this class or in a `Command` calls
  /// `DateTime.now()` directly — tests supply a [FixedClock] and get
  /// reproducible, byte-comparable timestamps.
  final Clock clock;

  /// Stamped onto every `EntityMeta.touch()` a command performs this
  /// session. A later milestone may make this per-transaction (e.g. a
  /// signed-in user identity); a single controller-wide value is enough
  /// for M0, where there is exactly one local editor.
  final String actor;

  final epochs = DocEpochs();
  final undo = UndoStack<RackDocument>();

  /// M0 minimal shape (selection.dart) — the real `SelectionController`
  /// lives in `rackmate_ui`. Plain mutable so a future caller can just
  /// assign a new [Selection] as the user clicks around.
  Selection selection = Selection();

  _TxnBuilder? _open;
  int _savedStateId;

  /// `isDirty == stateId != savedStateId` (CR-094) — distinct from
  /// `doc.sequence`, the persisted sync cursor. `stateId` is in-memory
  /// only and reset to 0 for every freshly-constructed `RackDocument`;
  /// this class is the only thing that advances it.
  bool get isDirty => doc.stateId != _savedStateId;

  /// Called by the persistence layer after a successful write.
  void markSaved() {
    _savedStateId = doc.stateId;
  }

  void run(Command c) => transact(c.label, (tx) => tx.add(c));

  T transact<T>(LabelKey label, T Function(TxnScope tx) body) {
    final open = _open;
    if (open != null) {
      // Flatten: nested transactions share the outermost's children list,
      // so the user sees exactly one undo entry no matter how many
      // `transact` calls a single gesture nests.
      return body(TxnScope(open.children, doc));
    }
    final b = _TxnBuilder(label, selection.snapshot());
    _open = b;
    try {
      final result = body(TxnScope(b.children, doc));
      _commit(b);
      return result;
    } catch (e, st) {
      _rollback(b, e, st);
      rethrow;
    } finally {
      _open = null;
    }
  }

  void _commit(_TxnBuilder b) {
    if (b.children.isEmpty) return; // no-op edits add no history
    final txn = Transaction(
      b.label,
      b.children,
      b.selectionBefore,
      selection.snapshot(),
    );
    undo.push(txn, b.selectionBefore, selection.snapshot(), clock.nowUtc());
    epochs.bump(txn.touches, doc); // invalidation happens ONCE per commit
    doc.stateId++; // distinct from doc.sequence, bumped inside epochs.bump
  }

  /// Reverts every child already applied, in reverse order, so a failed
  /// transaction never leaves a partially-applied edit in the document.
  /// [error]/[stackTrace] are accepted (per docs/03-architecture.md §5.4's
  /// `catch (e, st)`) for a future diagnostics hook; M0 has none yet, so
  /// they are otherwise unused here.
  void _rollback(_TxnBuilder b, Object error, StackTrace stackTrace) {
    for (var i = b.children.length - 1; i >= 0; i--) {
      try {
        b.children[i].revert(doc);
        // Deliberately catch-all: a revert failing mid-rollback is a
        // double-fault, and this handler must not care WHAT a Command's
        // revert() threw. The document may now be in a state no command
        // here can cleanly reconstruct, so poison rather than risk
        // further corruption from a later undo/redo, and stop unwinding.
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {
        undo.poison();
        break;
      }
    }
  }

  /// Undoes the last transaction and RETURNS the [Selection] that was in
  /// effect before it (or `null` if nothing was undone). The caller — the
  /// UI's `SelectionController` — restores it, so undoing a delete puts the
  /// selection back on the entity it just brought back rather than leaving
  /// a dangling focus (docs/03-architecture.md §4.4). Return type widened
  /// from `void` in M1; existing `void`-context callers are unaffected.
  Selection? undoLast() {
    if (!undo.canUndo) return null;
    // Captured BEFORE undo() pops the entry off the done stack.
    final restore = undo.undoSelection;
    final touched = undo.undo(doc);
    epochs.bump(touched, doc);
    doc.stateId++;
    return restore;
  }

  /// Redoes the last undone transaction and RETURNS the [Selection] that
  /// was in effect after it originally committed (or `null` if nothing was
  /// redone), for the same selection-restore reason as [undoLast].
  Selection? redoLast() {
    if (!undo.canRedo) return null;
    final restore = undo.redoSelection;
    final touched = undo.redo(doc);
    epochs.bump(touched, doc);
    doc.stateId++;
    return restore;
  }
}
