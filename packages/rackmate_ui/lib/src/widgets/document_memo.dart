// One derived value, recomputed only when the document actually changed
// (M8-F1, board `#424`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS EXISTS, WITH THE MEASUREMENT THAT PAID FOR IT
// ═══════════════════════════════════════════════════════════════════════
// `derived/` is twenty-one pure modules and a grep for `cache` or `memo`
// across all of them returns nothing, which is correct: a pure function
// that caches is no longer pure and the determinism gates rest on those
// functions being total and side-effect free. The place to remember an
// answer is the widget that asked the question, and until now no widget
// did.
//
// `tool/scale_probe.dart` measured what that costs. On a 3x project (601
// devices, 3,600 cables) `buildSchedule` is **39 ms**, and
// `schedule_screen.dart` called it from inside `build()` — so changing a
// preset, changing a sort, or ticking "include jumpers" recomputed the
// whole schedule from the document. That is two and a half dropped frames
// per checkbox, on every interaction, forever.
//
// ═══════════════════════════════════════════════════════════════════════
// `stateId` IS THE KEY, AND THE INVARIANT IT NEEDS IS ALREADY WRITTEN DOWN
// ═══════════════════════════════════════════════════════════════════════
// `document_controller.dart` states it exactly: `_nextStateId` "is what
// lets `doc.stateId` be RESTORED on undo/redo without two different
// document states ever colliding on one id". Same id therefore means same
// state, which is precisely and only what a cache needs.
//
// NOT `sequence`. That is the persisted sync cursor and it is strictly
// monotonic INCLUDING across undo, so undoing an edit would leave a
// different `sequence` on a document that is byte-for-byte the state it
// was two ticks ago, and the cache would miss where it should hit. The
// direction that matters is the other one, and both are safe there: a
// key that changes too often costs a recompute, a key that changes too
// rarely serves a stale table to somebody about to order cable.
//
// THE DOCUMENT ID IS IN THE KEY TOO. `stateId` is in-memory and a
// freshly-opened document starts near zero, so two documents open in one
// session would otherwise collide on their first few states.
//
// ═══════════════════════════════════════════════════════════════════════
// WHICH SURFACES MAY USE THIS, AND THE ONE THAT MAY NOT
// ═══════════════════════════════════════════════════════════════════════
// ONLY A SCREEN WHOSE DOCUMENT COMES FROM A `DocumentController`.
// `stateId` is maintained by the controller and by nothing else, so a
// surface handed a bare `RackDocument` that some caller mutates in place
// sees a `stateId` that never moves, and this memo would answer with the
// first table it ever built, forever.
//
// `StructureEditorScreen` IS EXACTLY THAT SURFACE and was reverted after
// being written. Its API is `RackDocument Function() currentDoc`, which
// promises no revision, and `structure_editor_screen_test.dart` applies
// commands straight to a controller-less document in eight callbacks:
// 31 tests failed at once, which is the contract saying so out loud. The
// production wiring happens to pass `session.document` and edit through
// `session.controller`, so it would have WORKED in the app and been
// wrong in principle, which is the worst of the available outcomes.
// Memoising that screen needs its API to carry a revision first, and
// that is a design change rather than a drive-by.
//
// `ScheduleScreen` qualifies: `app_shell.dart` keys it on the controller
// and hands it `session.document`.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PRECEDENT, AND WHY THIS IS NOT IT
// ═══════════════════════════════════════════════════════════════════════
// `schematic_canvas_screen.dart` has hand-rolled exactly this shape since
// M2, keyed on `(epoch, palette, theme)`, and its header explains why the
// scene must not rebuild "because a chip was clicked, a symbol was hovered
// or a pointer moved". It is deliberately left alone: its key is an EPOCH
// COUNTER the screen bumps itself, not a `stateId`, because DR-011.4
// requires the layout to be held across a `wires` bump. Rewriting it to
// use this would quietly discard that hold.
import 'package:rackmate_core/rackmate_core.dart';

/// Remembers one derived value until the document, or the inputs the
/// caller names, change.
///
/// Held in a `State`, never in a widget: a `StatelessWidget` is rebuilt
/// from scratch and a memo on one would never hit.
///
/// ```dart
/// final _schedule = DocumentMemo<Schedule>();
/// ...
/// final schedule = _schedule.of(doc, () => buildSchedule(doc));
/// ```
final class DocumentMemo<T extends Object> {
  ({Uuid id, int stateId, Object? extra})? _key;
  T? _value;

  /// True once something has been remembered. Exposed for tests, which
  /// otherwise cannot tell a hit from a miss without timing it.
  bool get isEmpty => _value == null;

  /// The remembered value, or [build]'s result when the document moved.
  ///
  /// [extra] carries any input [build] reads that is NOT the document:
  /// the structure body a table is scoped to, a filter, a sort. It is
  /// compared with `==`, so pass a record or a primitive and never a
  /// freshly-allocated list, which is never equal to the last one and
  /// would turn every call into a miss.
  ///
  /// **[build] MUST read nothing the key does not name.** That is the one
  /// way to misuse this, it fails silently, and it fails by showing
  /// somebody a stale cable schedule rather than by throwing.
  T of(RackDocument doc, T Function() build, {Object? extra}) {
    final key = (id: doc.id, stateId: doc.stateId, extra: extra);
    final cached = _value;
    if (cached != null && _key == key) return cached;
    final built = build();
    _key = key;
    _value = built;
    return built;
  }

  /// Forgets what it remembered.
  ///
  /// For a caller that mutates a document in place without moving
  /// `stateId`. That is NOT hypothetical and the header says where it
  /// happens, so this exists rather than being an assertion that it
  /// cannot: a surface in that position should clear rather than hold a
  /// stale answer.
  void clear() {
    _key = null;
    _value = null;
  }
}
