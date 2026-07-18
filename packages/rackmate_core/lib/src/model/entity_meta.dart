// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter names intentionally differ from the private backing field
// names they feed (mirrors this package's other private-backing-field
// getters), so the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';

/// Conflict-unit metadata (CR-095) attached to every top-level document
/// entity. `Port`, `Conductor`, `Service`, `SheetItem` and `ZeroUChannel`
/// deliberately do NOT carry one — see each type's own doc comment.
final class EntityMeta {
  EntityMeta({
    required DateTime createdAt,
    required DateTime updatedAt,
    required String updatedBy,
    int localRevision = 0,
    Map<String, Object?>? unknown,
  }) : _createdAt = createdAt,
       _updatedAt = updatedAt,
       _updatedBy = updatedBy,
       _localRevision = localRevision,
       unknown = unknown ?? {};

  final DateTime _createdAt;

  /// UTC, microsecond precision. Never changes after construction.
  DateTime get createdAt => _createdAt;

  DateTime _updatedAt;
  DateTime get updatedAt => _updatedAt;

  String _updatedBy;
  String get updatedBy => _updatedBy;

  int _localRevision;
  int get localRevision => _localRevision;

  /// Forward-compat: fields a future schema version adds that this reader
  /// does not model yet are preserved here and re-emitted verbatim (G4)
  /// rather than silently dropped.
  final Map<String, Object?> unknown;

  /// The forward mutation entry point. A Command's `apply()` calls this
  /// instead of touching the private fields directly — see the worked
  /// example in docs/03-architecture.md §5.2
  /// (`d.meta.touch(doc.clock.nowUtc(), doc.actor)`). `@internal`: only
  /// `rackmate_core`'s own `commands/` may call it (AC-013) — never
  /// `rackmate_ui` or any other package.
  @internal
  void touch(DateTime now, String by) {
    _updatedAt = now;
    _updatedBy = by;
    _localRevision++;
  }

  /// The revert-side counterpart to [touch]. `touch` can only ever move
  /// `updatedAt`/`updatedBy`/`localRevision` forward — `localRevision` is
  /// a per-entity edit counter in the same "never decreases" spirit as
  /// `RackDocument.sequence` (CR-094) — so undoing a touch is not itself
  /// another touch; there is no `(now, by)` that makes `touch` produce
  /// the exact prior triple back. A Command's `revert()` calls this
  /// instead, with the triple it captured for itself at the top of its
  /// own `apply()`, wherever restoring its target's meta exactly (not
  /// just its own before-values) is needed to satisfy
  /// docs/03-architecture.md §5.1's "apply; revert; apply is idempotent"
  /// property — verified end to end by `command_roundtrip_test.dart`'s
  /// byte round-trip (CR-117). `@internal` for the same reason as
  /// [touch].
  @internal
  void restoreTo({
    required DateTime updatedAt,
    required String updatedBy,
    required int localRevision,
  }) {
    _updatedAt = updatedAt;
    _updatedBy = updatedBy;
    _localRevision = localRevision;
  }
}
