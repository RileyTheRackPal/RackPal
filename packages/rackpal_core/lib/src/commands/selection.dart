import 'package:rackpal_core/src/units/ids.dart';

/// M0 minimal shape; the real `SelectionController` lives in
/// `rackpal_ui` (docs/03-architecture.md §3 — selection is UI-adjacent,
/// observed by the canvas overlay, not a document concern). `Transaction`
/// and `DocumentController` need SOME selection type to compile and be
/// genuinely usable ahead of that package existing, so this package
/// carries a bare value class: which entities are selected, and which one
/// (if any) has editing focus. No observation/notification machinery —
/// that is exactly the presentation-layer concern deferred to
/// `rackpal_ui`.
final class Selection {
  Selection({Set<Uuid>? ids, this.focus}) : ids = ids ?? <Uuid>{};

  final Set<Uuid> ids;
  Uuid? focus;

  /// An independent copy, so a `selectionBefore` captured at transaction
  /// start does not alias whatever the live selection mutates into by
  /// transaction end.
  Selection snapshot() => Selection(ids: Set<Uuid>.of(ids), focus: focus);
}
