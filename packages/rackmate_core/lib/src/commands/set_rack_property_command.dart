// ONE command class for the twelve scalar `Rack` properties the rack
// inspector (docs/04-rack-editor.md §4) edits — not twelve classes, and
// not one class with an `Object?` payload.
//
// WHY ONE CLASS. This codebase already ruled on the identical question:
// rename_entity_command.dart chose a single class with a target-kind
// discriminator over two classes because "the shape is identical and the
// only thing that differs is which map to look the id up in". Here the
// case is stronger — same map, same meta snapshot/restore, same revert
// shape, same merge shape. Twelve classes would be twelve copies of the
// same `_prevUpdatedAt`/`_prevUpdatedBy`/`_prevLocalRevision` dance,
// twelve `epoch_mask_test` cases and twelve `command_roundtrip_test`
// generator arms.
//
// WHY NOT AN `Object?` PAYLOAD. The values are heterogeneous — String,
// bool, `Uuid?`, `Len?`, `Mass?` and four enums. A single class with
// `Object? from/to` and a `switch` in `apply()` buys concision by
// discarding static typing at exactly the call sites the inspector
// generates, where a wrong-typed value would compile and fail at runtime.
// [RackField] keeps one class AND full type safety; the cost is one small
// accessor table, which is also the only place the field set is written
// down and therefore the natural place to test it.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/enums.dart' show RuNumbering;
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

/// A typed accessor for one editable [Rack] property: how to read it, how
/// to write it, and which epochs writing it invalidates.
///
/// The setters live in `src/commands/` (this file), which is exactly where
/// `internal_setter_grep_test.dart` permits `@internal` setter call sites
/// — so the whole inspector reaches `Rack`'s state through this table and
/// through nothing else.
///
/// The table entries below are `static final`, not `const`, and cannot be
/// `const`: `EpochMask` is an `extension type`, so its
/// `|` operator is a method call and `EpochMask.rack | EpochMask.style` is
/// not a constant expression. Spelling those masks as raw bit literals to
/// buy `const`ness would hardcode `EpochMask`'s bit assignments in a
/// second place — exactly the drift this codebase avoids elsewhere. The
/// table is built once at first use; nothing about it is hot.
final class RackField<T> {
  const RackField({
    required this.key,
    required this.get,
    required this.set,
    required this.touches,
  });

  /// A stable identifier, used in [SetRackPropertyCommand.mergeKey] and in
  /// diagnostics. NOT persisted, so it is free to rename — but it is what
  /// makes coalescing per-property, so it must be unique across the table
  /// (asserted by the unit test).
  final String key;
  final T Function(Rack rack) get;
  final void Function(Rack rack, T value) set;

  /// Declared PER FIELD rather than as one blanket mask. Over-declaring is
  /// explicitly sanctioned (AC-014, "when in doubt, over-declare") and
  /// `epoch_mask_test` only ever asserts a superset, but a designator edit
  /// genuinely does not invalidate rack geometry and should not force that
  /// repaint.
  final EpochMask touches;

  @override
  String toString() => 'RackField($key)';

  // ── the table ──────────────────────────────────────────────────────────
  //
  // Getter/setter pairs are written as closures rather than named
  // top-level functions purely for density: twelve named pairs would be
  // twenty-four one-line functions restating what the closure already
  // says. They live in `src/commands/`, which is where
  // internal_setter_grep_test.dart permits @internal setter call sites.

  /// "RK-1" — the ONLY rack identifier (CR-040).
  static final designator = RackField<String>(
    key: 'designator',
    get: (r) => r.designator,
    set: (r, v) => r.designator = v,
    touches: EpochMask.meta,
  );

  static final locationId = RackField<Uuid?>(
    key: 'locationId',
    get: (r) => r.locationId,
    set: (r, v) => r.locationId = v,
    touches: EpochMask.meta,
  );

  /// Display-only (CR-026), but it redraws the RU ruler — hence `style`
  /// as well as `rack`.
  static final ruNumbering = RackField<RuNumbering>(
    key: 'ruNumbering',
    get: (r) => r.ruNumbering,
    set: (r, v) => r.ruNumbering = v,
    touches: EpochMask.rack | EpochMask.style,
  );

  /// Display-only (CR-035), but it drives the NOT MIRRORED chip.
  static final mirrorRearElevation = RackField<bool>(
    key: 'mirrorRearElevation',
    get: (r) => r.mirrorRearElevation,
    set: (r, v) => r.mirrorRearElevation = v,
    touches: EpochMask.rack | EpochMask.style,
  );

  static final widthClass = RackField<RackWidthClass>(
    key: 'widthClass',
    get: (r) => r.widthClass,
    set: (r, v) => r.widthClass = v,
    touches: EpochMask.rack,
  );

  static final railType = RackField<RailType>(
    key: 'railType',
    get: (r) => r.railType,
    set: (r, v) => r.railType = v,
    touches: EpochMask.rack,
  );

  static final formFactor = RackField<RackFormFactor>(
    key: 'formFactor',
    get: (r) => r.formFactor,
    set: (r, v) => r.formFactor = v,
    touches: EpochMask.rack,
  );

  /// Nullable: a 2-post frame leaves it unset, and null means UNKNOWN,
  /// never zero (CR-114, docs/04 §4's "explicit unset/dash state").
  static final usableDepth = RackField<Len?>(
    key: 'usableDepth',
    get: (r) => r.usableDepth,
    set: (r, v) => r.usableDepth = v,
    touches: EpochMask.rack,
  );

  static final weightCapacity = RackField<Mass?>(
    key: 'weightCapacity',
    get: (r) => r.weightCapacity,
    set: (r, v) => r.weightCapacity = v,
    touches: EpochMask.rack,
  );

  static final isSwingFrame = RackField<bool>(
    key: 'isSwingFrame',
    get: (r) => r.isSwingFrame,
    set: (r, v) => r.isSwingFrame = v,
    touches: EpochMask.rack,
  );

  static final hingeSide = RackField<HingeSide?>(
    key: 'hingeSide',
    get: (r) => r.hingeSide,
    set: (r, v) => r.hingeSide = v,
    touches: EpochMask.rack,
  );

  static final groundBarPresent = RackField<bool>(
    key: 'groundBarPresent',
    get: (r) => r.groundBarPresent,
    set: (r, v) => r.groundBarPresent = v,
    touches: EpochMask.rack,
  );

  /// Every field in the table, for tests and for any caller that needs to
  /// enumerate them (a preset apply, a diff view). READ-ONLY use: calling
  /// `set` through the erased element type would defeat the static typing
  /// this table exists to preserve.
  static final List<RackField<Object?>> all = [
    designator,
    locationId,
    ruNumbering,
    mirrorRearElevation,
    widthClass,
    railType,
    formFactor,
    usableDepth,
    weightCapacity,
    isSwingFrame,
    hingeSide,
    groundBarPresent,
  ];
}

/// Sets one [RackField] on one [Rack]. See `MoveDeviceCommand`
/// (device_commands.dart) for why `revert()` restores `EntityMeta` via
/// `restoreTo` rather than calling `touch` again — the same reasoning
/// applies here verbatim, and CR-117's byte round-trip depends on it.
final class SetRackPropertyCommand<T> extends Command {
  SetRackPropertyCommand({
    required this.id,
    required this.field,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final RackField<T> field;
  final T from;
  final T to;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setRackProperty;

  @override
  EpochMask get touches => field.touches;

  @override
  Iterable<Uuid> get affects => [id];

  /// Includes `field.key`, so coalescing is PER PROPERTY: typing in the
  /// designator box collapses into one undo entry, but editing the
  /// designator and then the width class does not incorrectly merge into
  /// a single "set rack property" the user cannot unpick.
  @override
  Object? get mergeKey => (SetRackPropertyCommand, field.key, id);

  @override
  void apply(RackDocument doc) {
    final r = doc.racks[id]!;
    _prevUpdatedAt = r.meta.updatedAt;
    _prevUpdatedBy = r.meta.updatedBy;
    _prevLocalRevision = r.meta.localRevision;
    field.set(r, to);
    r.meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final r = doc.racks[id]!;
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError(
        'SetRackPropertyCommand.revert called before apply().',
      );
    }
    field.set(r, from);
    r.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  @override
  Command? mergeWith(Command next) {
    if (next is! SetRackPropertyCommand<T>) return null;
    if (next.id != id || next.field.key != field.key) return null;
    // See MoveDeviceCommand.mergeWith's comment (device_commands.dart):
    // carries THIS command's already-captured "before" meta snapshot
    // forward, since the merged command is a fresh object that never
    // itself has apply() called on it before a possible revert().
    return SetRackPropertyCommand<T>(
        id: id,
        field: field,
        from: from,
        to: next.to,
        now: next.now,
        actor: next.actor,
      )
      .._prevUpdatedAt = _prevUpdatedAt
      .._prevUpdatedBy = _prevUpdatedBy
      .._prevLocalRevision = _prevLocalRevision;
  }
}

/// Builds the command that moves [field] from its CURRENT value to [to],
/// or null when the value is already [to] — so a caller can honour
/// docs/04 §3.4's "never silently do nothing" by distinguishing "nothing
/// to do" from "did something" rather than pushing a no-op undo entry.
SetRackPropertyCommand<T>? buildSetRackProperty<T>({
  required RackDocument doc,
  required Uuid rackId,
  required RackField<T> field,
  required T to,
  required DateTime now,
  required String actor,
}) {
  final rack = doc.racks[rackId];
  if (rack == null) {
    throw ArgumentError.value(rackId, 'rackId', 'no such rack in document');
  }
  final from = field.get(rack);
  if (from == to) return null;
  return SetRackPropertyCommand<T>(
    id: rackId,
    field: field,
    from: from,
    to: to,
    now: now,
    actor: actor,
  );
}
