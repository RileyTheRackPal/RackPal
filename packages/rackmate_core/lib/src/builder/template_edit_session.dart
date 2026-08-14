// The Device Builder's edit session: the second of CR-106's three
// stacks, over the `TemplateBody` being edited
// (docs/03-architecture.md §5.6). M4-A/4, board #192.
//
// WHAT IT REUSES, AND WHY THAT IS THE WHOLE POINT. `Command<A>`,
// `Transaction<A>`, `TxnScope<A>` and `UndoStack<A>` are all shared with
// the document (M4-A/1-3). CR-106 says the machinery is stated once "so
// nobody builds a second mechanism", and this file is where that claim
// gets tested: everything below is session POLICY, and none of it is
// undo.
//
// WHAT IT DELIBERATELY DOES NOT OWN. Library operations — delete a
// template, import one, set a favourite — are NOT on this stack and must
// not be added to it. CR-106 rules them individually confirmable or
// trivially reversible instead. The temptation is real and it is a
// design error: an undo stack scoped to one template cannot coherently
// undo an act on the shelf that template sits on, and a Ctrl+Z that
// sometimes un-deletes a file is worse than one that never does.
//
// THE THIRD STACK IS NONE AT ALL. Settings share the library's answer.
import 'package:rackmate_core/src/commands/clock.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/simple_notifier.dart';
import 'package:rackmate_core/src/commands/transaction.dart';
import 'package:rackmate_core/src/commands/undo_stack.dart';
import 'package:rackmate_core/src/document_controller.dart' show TxnScope;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/persistence/json_codec.dart'
    show copyTemplateBody;

/// Accumulates one in-progress transaction's children while
/// [TemplateEditSession.transact]'s body runs. No selection pair, unlike
/// the document's: a `Selection` is a set of `Uuid`s and a
/// `TemplateBody`'s ports are keyed by `PortKey`, so the builder's
/// grid selection is M4-E's to model and is not this.
final class _TxnBuilder {
  _TxnBuilder(this.label);

  final LabelKey label;
  final List<Command<TemplateBody>> children = [];
}

/// One open Device Builder window's editing state.
///
/// **It edits a COPY, and that is what makes "discarded on close without
/// save" true rather than aspirational (CR-106).** The session deep-copies
/// the body handed to it, so the library's own `TemplateBody` is not
/// reachable from here and dropping the session is a complete undo of
/// everything done in it. A session that mutated the original in place
/// would leave every cancelled edit behind in memory, where the next
/// device placed from that template would pick it up, and no test that
/// only checks the undo stack would ever see it.
///
/// Saving is not this class's job and is deliberately absent: writing the
/// working copy back to a library is M4-N's directory service, and
/// [markSaved] exists only to move the dirty save point once somebody
/// has.
final class TemplateEditSession {
  /// Opens a session over a deep copy of [original], which is left
  /// untouched for the life of the session.
  TemplateEditSession(TemplateBody original, {this.clock = const SystemClock()})
    : body = copyTemplateBody(original);

  /// The working copy. Mutated only through [run]/[transact], which is
  /// what makes [undo] exact — the same rule `DocumentController` states
  /// for the document, and it has no `@internal` setters to enforce it
  /// with, so it is stated here and asserted by test rather than by the
  /// analyzer.
  final TemplateBody body;

  /// Injected for the same reason the document controller injects one:
  /// nothing here calls `DateTime.now()`, so a test can drive the
  /// coalescing window instead of sleeping through it.
  final Clock clock;

  final undo = UndoStack<TemplateBody>();

  /// Bumped for every commit, undo, redo and save-point move — the
  /// events that can change [isDirty] or the window title. Pure Dart, so
  /// no Flutter enters core.
  final changes = SimpleNotifier<int>(0);

  _TxnBuilder? _open;
  int _changeTick = 0;

  /// The session's own state-id line. `RackDocument` carries a `stateId`
  /// field and a `TemplateBody` does not, so the counter lives here
  /// instead of on the aggregate. Strictly monotonic and never reused,
  /// for `DocumentController`'s reason: [_stateId] itself goes backwards
  /// on undo, and two different states must never collide on one id or
  /// [editsSinceSave] would answer a question about the wrong one.
  int _stateId = 0;
  int _savedStateId = 0;
  int _nextStateId = 1;

  bool _closed = false;

  /// True once [close] has run. A closed session is inert and must be
  /// thrown away; nothing reopens one.
  bool get isClosed => _closed;

  /// Whether the working copy differs from the last save point.
  bool get isDirty => _stateId != _savedStateId;

  /// How many edits stand between the last save and the working copy, or
  /// `null` when that is UNKNOWN — the stack was poisoned, or the save
  /// point aged out past `maxEntries`. Callers OMIT the count rather than
  /// guess one (G4), exactly as the document side does.
  int? get editsSinceSave => undo.distanceTo(_savedStateId, _stateId);

  /// Moves the save point to the current state. Called by whoever wrote
  /// [body] somewhere; this class does no I/O.
  void markSaved() {
    _savedStateId = _stateId;
    _bumpChanges();
  }

  /// Closes the session. The stack and the working copy are discarded
  /// with it (CR-106); nothing is written anywhere, and any edits not
  /// already saved by a caller are gone by construction, because [body]
  /// is a copy nothing else holds.
  ///
  /// Editing after this is a caller bug rather than a no-op, so it
  /// throws: a builder window that keeps taking keystrokes after it has
  /// closed is a leak with a UI attached, and the failure should name
  /// itself here rather than surface as edits that vanish.
  void close() {
    _closed = true;
    _bumpChanges();
  }

  void run(Command<TemplateBody> c) => transact(c.label, (tx) => tx.add(c));

  T transact<T>(LabelKey label, T Function(TxnScope<TemplateBody> tx) body) {
    if (_closed) {
      throw StateError('TemplateEditSession.transact after close().');
    }
    final open = _open;
    if (open != null) {
      // Flatten, as the document does: one gesture is one undo entry no
      // matter how many `transact` calls it nests.
      return body(TxnScope<TemplateBody>(open.children, this.body));
    }
    final b = _TxnBuilder(label);
    _open = b;
    try {
      final result = body(TxnScope<TemplateBody>(b.children, this.body));
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
    final txn = Transaction<TemplateBody>(b.label, b.children, null, null);
    final stateIdBefore = _stateId;
    final stateIdAfter = _nextStateId++;
    undo.push(txn, null, null, clock.nowUtc(), stateIdBefore, stateIdAfter);
    _stateId = stateIdAfter;
    _bumpChanges();
  }

  /// Reverts every child already applied, in reverse order, so a failed
  /// transaction never leaves a half-written template behind.
  /// [error]/[stackTrace] are accepted for the diagnostics hook the
  /// document side is also still waiting for.
  void _rollback(_TxnBuilder b, Object error, StackTrace stackTrace) {
    for (var i = b.children.length - 1; i >= 0; i--) {
      try {
        b.children[i].revert(body);
        // Deliberately catch-all, for `DocumentController._rollback`'s
        // reason: a revert failing mid-rollback is a double-fault and
        // this handler must not care what it threw. The body may now be
        // in a state no command here can reconstruct, so poison rather
        // than risk a later undo making it worse.
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {
        undo.poison();
        break;
      }
    }
  }

  /// Undoes the last transaction. Returns false if there was nothing to
  /// undo. No `Selection` comes back, unlike `DocumentController.undoLast`
  /// — see [_TxnBuilder].
  bool undoLast() {
    if (_closed) {
      throw StateError('TemplateEditSession.undoLast after close().');
    }
    if (!undo.canUndo) return false;
    final restoreStateId = undo.undoStateId!;
    undo.undo(body);
    // RESTORED, not advanced (CR-094's reasoning, applied to a stack
    // that has no document): undoing back to the state that was saved
    // must read as clean, or closing the builder prompts about changes
    // that are byte-identical to the ones on disk.
    _stateId = restoreStateId;
    _bumpChanges();
    return true;
  }

  /// Redoes the last undone transaction. Returns false if there was
  /// nothing to redo.
  bool redoLast() {
    if (_closed) {
      throw StateError('TemplateEditSession.redoLast after close().');
    }
    if (!undo.canRedo) return false;
    final restoreStateId = undo.redoStateId!;
    undo.redo(body);
    _stateId = restoreStateId;
    _bumpChanges();
    return true;
  }

  void _bumpChanges() {
    changes.value = ++_changeTick;
  }
}
