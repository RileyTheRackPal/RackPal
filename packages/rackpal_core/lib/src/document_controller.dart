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
import 'package:rackpal_core/src/commands/clock.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/selection.dart';
import 'package:rackpal_core/src/commands/simple_notifier.dart';
import 'package:rackpal_core/src/commands/transaction.dart';
import 'package:rackpal_core/src/commands/undo_stack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// The scope a `DocumentController.transact` body mutates through.
/// Commands `apply()` IMMEDIATELY inside [add], not at commit, so a later
/// command in the same transaction sees the results of an earlier one
/// ("add device, then connect to it", §5.4).
///
/// Generic over the aggregate since M4-A, so the Device Builder's session
/// (`TemplateEditSession`) reuses this one rather than growing a second
/// transaction scope of its own. CR-106's "stated once so nobody builds a
/// second mechanism" is about the `Command`/`UndoStack` pair, and this is
/// the third piece of the same pair: without it, every new aggregate
/// re-implements apply-on-add.
final class TxnScope<A> {
  TxnScope(this._children, this._aggregate);

  final List<Command<A>> _children;
  final A _aggregate;

  /// Applies [c] and keeps it ONLY IF IT CHANGED anything (DR-156
  /// §11.155.1). Returns what [Command.apply] returned, so a caller that
  /// needs to know can ask.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A REFUSAL MUST NOT REACH THE UNDO STACK, AND THIS IS THE ONE PLACE
  /// ═══════════════════════════════════════════════════════════════════
  /// A command that self-refuses inside `apply` used to become a child
  /// anyway: the transaction was recorded, the epochs bumped over a
  /// document that did not change, and the next `Ctrl+Z` called `revert`
  /// on a command that never applied, which throws. Probed on the shipped
  /// `SetPlanPinCommand` at `LEN-A/2` and filed as `#863`.
  ///
  /// **`_commit` ALREADY HAD THE CONCEPT AND COULD NOT SEE THIS CASE.** It
  /// reads `if (b.children.isEmpty) return; // no-op edits add no
  /// history`. What was missing was any way for a command to say it
  /// declined, so a refusal was indistinguishable from a write. Dropping
  /// it here is what makes that guard reach the case it was written for.
  ///
  /// **SHARED BY BOTH UNDO STACKS**, which is why the fix lands once:
  /// `TemplateEditSession` carries its own `_TxnBuilder` and `_commit` but
  /// imports this class.
  bool add(Command<A> c) {
    final changed = c.apply(_aggregate);
    if (changed) _children.add(c);
    return changed;
  }
}

/// Accumulates one in-progress transaction's children and before/after
/// selection while `DocumentController.transact`'s body runs.
final class _TxnBuilder {
  _TxnBuilder(this.label, this.selectionBefore);

  /// The name the Edit menu shows, or **null meaning the first child names
  /// this entry** (DR-156 §11.155.2), resolved in [DocumentController._commit]
  /// after every child has applied.
  final LabelKey? label;
  final Selection selectionBefore;
  final List<Command<RackDocument>> children = [];
}

/// THE only mutation entry point (docs/03-architecture.md §2.2) — every
/// document edit goes through [run]/[transact], which is what makes undo
/// exact and the epoch counters trustworthy.
class DocumentController {
  DocumentController(
    this.doc, {
    this.clock = const SystemClock(),
    this.actor = 'local',
    int undoDepth = kDefaultUndoDepth,
  }) : _savedStateId = doc.stateId,
       _nextStateId = doc.stateId + 1,
       undo = UndoStack<RackDocument>(maxEntries: undoDepth);

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

  /// The document's history. Its depth is the caller's: in the app, the
  /// per-machine undo depth preference (DR-172), which
  /// [UndoStack.resize] applies while the document stays open.
  final UndoStack<RackDocument> undo;

  /// M0 minimal shape (selection.dart) — the real `SelectionController`
  /// lives in `rackpal_ui`. Plain mutable so a future caller can just
  /// assign a new [Selection] as the user clicks around.
  Selection selection = Selection();

  /// Bumped once for every commit, undo, redo and save-point move —
  /// i.e. exactly the events that can change `isDirty`, `editsSinceSave`
  /// or the window title. A `SimpleNotifier` because it is pure Dart
  /// (simple_notifier.dart); the app layer subscribes and re-broadcasts to
  /// widgets, so no Flutter enters core.
  ///
  /// The value is an opaque monotonically-increasing tick. Do not read
  /// meaning into it — read [isDirty] / [editsSinceSave].
  final changes = SimpleNotifier<int>(0);

  _TxnBuilder? _open;
  int _savedStateId;

  /// The state-id allocator. STRICTLY MONOTONIC AND NEVER REUSED, which
  /// is what lets `doc.stateId` be RESTORED on undo/redo without two
  /// different document states ever colliding on one id. `doc.stateId`
  /// itself is therefore non-monotonic (it goes backwards on undo) —
  /// that is the point, and it is what `RackDocument.stateId`'s own
  /// "non-monotonic" doc comment already promised.
  int _nextStateId;

  /// `isDirty == stateId != savedStateId` (CR-094) — distinct from
  /// `doc.sequence`, the persisted sync cursor. `stateId` is in-memory
  /// only and reset to 0 for every freshly-constructed `RackDocument`;
  /// this class is the only thing that advances it.
  bool get isDirty => doc.stateId != _savedStateId;

  /// The `stateId` the last successful write captured. Exposed so the
  /// persistence layer can record it alongside the bytes it wrote.
  int get savedStateId => _savedStateId;

  /// How many edits stand between what is on disk and what is on screen —
  /// the number in "12 unsaved changes" and in "If you don't save, 12
  /// changes will be lost."
  ///
  /// `null` means UNKNOWN, not zero: the undo stack was poisoned, or the
  /// save point aged out past `maxEntries`. Callers must OMIT the count
  /// in that case rather than guess one (G4).
  int? get editsSinceSave => undo.distanceTo(_savedStateId, doc.stateId);

  /// Called by the persistence layer after a successful write, with the
  /// `stateId` that was actually SERIALIZED — not the one current when
  /// the write finished.
  ///
  /// THE DISTINCTION IS LOAD-BEARING. A save serializes in an isolate and
  /// awaits it; the user can edit across that await. Clearing the dirty
  /// flag against `doc.stateId` at completion would mark those later
  /// edits saved when they were never written, and the next crash would
  /// take them with no recovery snapshot to fall back on, because a
  /// "clean" document deletes its snapshot. Capture the id synchronously
  /// at serialize time and pass it here.
  void markSavedAt(int stateId) {
    _savedStateId = stateId;
    _bumpChanges();
  }

  /// Convenience for a synchronous save path: marks the CURRENT state
  /// saved. An asynchronous save must use [markSavedAt] with the id it
  /// captured before serializing.
  void markSaved() => markSavedAt(doc.stateId);

  /// Runs one command as one undo entry, **named by that command after it
  /// has applied** (DR-156 §11.155.2).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE NULL IS THE FIX, AND THIS LINE IS WHERE `#866` LIVED
  /// ═══════════════════════════════════════════════════════════════════
  /// This read `transact(c.label, (tx) => tx.add(c))`. Dart evaluates
  /// `c.label` BEFORE the closure runs and the closure is what calls
  /// `apply`, so a command that decides its label from what it found in
  /// the document was asked for that label while the document still held
  /// the old state. Three commands decide that way and every one of them
  /// names the SECOND half of a deliberate pair, so half of each pair
  /// never reached a person: `movePlanPin`, `reshapeRoomOutline` and
  /// `recalibratePlan`.
  void run(Command<RackDocument> c) => transact(null, (tx) => tx.add(c));

  /// Runs [body] as ONE undo entry.
  ///
  /// [label] names it. **NULL MEANS THE FIRST CHILD NAMES IT**, read at
  /// commit time, which is the only moment every child has applied and so
  /// the only moment a label decided from the document is right.
  ///
  /// A CALLER THAT NAMES THE ACT STILL WINS, and that is not a detail: it
  /// is what keeps "Undo Import CSV" from becoming "Undo Set Property"
  /// when a bulk operation's first child happens to be a property write.
  T transact<T>(LabelKey? label, T Function(TxnScope<RackDocument> tx) body) {
    final open = _open;
    if (open != null) {
      // Flatten: nested transactions share the outermost's children list,
      // so the user sees exactly one undo entry no matter how many
      // `transact` calls a single gesture nests.
      return body(TxnScope<RackDocument>(open.children, doc));
    }
    final b = _TxnBuilder(label, selection.snapshot());
    _open = b;
    try {
      final result = body(TxnScope<RackDocument>(b.children, doc));
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
    // RESOLVED HERE AND NOWHERE EARLIER (DR-156 §11.155.2). Every child
    // has applied by this line, so a command that decides its label from
    // the document has seen the document. `children` is non-empty by the
    // guard above, and by `TxnScope.add` every one of them CHANGED
    // something, so the first child is a real edit rather than a refusal
    // that happened to be listed first.
    final label = b.label ?? b.children.first.label;
    final txn = Transaction<RackDocument>(
      label,
      b.children,
      b.selectionBefore,
      selection.snapshot(),
    );
    final stateIdBefore = doc.stateId;
    final stateIdAfter = _nextStateId++;
    undo.push(
      txn,
      b.selectionBefore,
      selection.snapshot(),
      clock.nowUtc(),
      stateIdBefore,
      stateIdAfter,
    );
    epochs.bump(txn.touches, doc); // invalidation happens ONCE per commit
    // Distinct from doc.sequence, which epochs.bump advances. A commit
    // always lands on a FRESH id, so it can never collide with a state
    // some earlier save point still refers to.
    doc.stateId = stateIdAfter;
    _bumpChanges();
  }

  int _changeTick = 0;

  /// Changes how many steps [undo] keeps, dropping the oldest at once when
  /// it holds more (DR-172: a new depth takes effect immediately), and
  /// returns how many went.
  ///
  /// THROUGH HERE RATHER THAN [UndoStack.resize], because dropping the entry
  /// the save point sits on changes [editsSinceSave], which the window title
  /// and the close prompt read. [changes] rings only when something went.
  int resizeUndo(int depth) {
    final dropped = undo.resize(depth);
    if (dropped > 0) _bumpChanges();
    return dropped;
  }

  void _bumpChanges() {
    changes.value = ++_changeTick;
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
    final restoreStateId = undo.undoStateId!;
    final touched = undo.undo(doc);
    epochs.bump(touched, doc);
    // RESTORED, not advanced (CR-094): undoing back to the state that was
    // written to disk must read as clean, because this milestone makes
    // `isDirty` user-visible in the title bar and in the close-while-dirty
    // prompt. A monotonic counter here would prompt "save changes?" for a
    // document byte-identical to the one already on disk.
    doc.stateId = restoreStateId;
    _bumpChanges();
    return restore;
  }

  /// Redoes the last undone transaction and RETURNS the [Selection] that
  /// was in effect after it originally committed (or `null` if nothing was
  /// redone), for the same selection-restore reason as [undoLast].
  Selection? redoLast() {
    if (!undo.canRedo) return null;
    final restore = undo.redoSelection;
    final restoreStateId = undo.redoStateId!;
    final touched = undo.redo(doc);
    epochs.bump(touched, doc);
    doc.stateId = restoreStateId;
    _bumpChanges();
    return restore;
  }
}
