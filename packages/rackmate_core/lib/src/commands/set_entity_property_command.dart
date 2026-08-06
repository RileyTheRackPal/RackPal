// rackmate_core/src/commands/set_entity_property_command.dart — pure Dart.
//
// ONE GENERIC COMMAND that writes one declared property on one entity,
// plus the accessor tables that say which properties those are. Board
// M3-A/5 (Outlet, StructureBody) and M3-A/7 (the lifecycle enum on
// DeviceInstance and Link), AC-013.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS ONE IS GENERIC OVER THE ENTITY AND THE RACK ONE IS NOT
// ─────────────────────────────────────────────────────────────────────────
// `set_rack_property_command.dart` argued the accessor-table shape for
// twelve fields of ONE entity, and every word of that argument applies
// here: one class rather than a class per field, and a typed table rather
// than an `Object?` payload that would discard static typing at exactly
// the inspector call sites that generate it.
//
// What is new is that M3-A/5 asked for the same thing on TWO entities at
// once. Writing the command class twice would have put a THIRD copy of the
// `_prevUpdatedAt`/`_prevUpdatedBy`/`_prevLocalRevision` snapshot dance in
// this package — which is the duplication that argument exists to avoid,
// one level up. So the entity is a type parameter and the tables are data,
// and M3-A/7 then cost two rows rather than a fifth command class.
//
// `SetRackPropertyCommand` IS DELIBERATELY LEFT ALONE. Folding it into
// this class is mechanical but wide: `rackmate_ui`'s inspector, the canvas
// screen and a dedicated test file all name `RackField` and
// `SetRackPropertyCommand` directly, and rewriting them inside a task
// scoped to `Outlet` and `StructureBody` would be a scope change under
// roadmap §8.3. It is a board item, not a TODO comment.
//
// ─────────────────────────────────────────────────────────────────────────
// WIRING A FIELD TO THIS COMMAND *IS* THE AC-013 RETROFIT
// ─────────────────────────────────────────────────────────────────────────
// `outlet.dart` and `structure_body.dart` each carried the standing note
// that their fields are "plain mutable pending @internal retrofit,
// converted as each is wired to a Command". This file is that wiring, so
// every field named in a table below is now a public getter plus an
// `@internal` setter, and `internal_setter_grep_test.dart` holds the
// boundary: nothing outside `src/model/` and `src/commands/` may assign
// one. The table's `set` closures live here, which is exactly where that
// test permits a call site.
//
// THE FIELDS LEFT OUT ARE LEFT OUT ON PURPOSE, not left over:
//
//  * `Outlet.order` — reordering is a drag, and it wants the `FracIndex`
//    allocator (`nextOutletOrder`) rather than a value a caller supplies.
//  * `Outlet.outletTemplateId` — provenance (CR-108, "what created it").
//    The creating gesture writes it; an inspector displays it.
//  * `Outlet.structureBodyId` — `final`. Moving an outlet onto a different
//    body is a re-parent, not a property edit.
//  * `Outlet.unknown` — DR-019's passthrough. A reader that does not model
//    a key has no business offering to edit it.
//  * `StructureOrigin`'s fields — they ARE `EntityField`s, but their table
//    lives in `home_run_commands.dart` beside the builder that guards it,
//    NOT here. `fieldLabel` and `rackLabel` carry CR-113's project-wide
//    uniqueness, and a bare table `set` writes and returns with no way to
//    refuse; a table sitting among tables that are safe to drive directly,
//    with two rows that are not, would be a trap. See that file's
//    "EDITING A DROP AFTER IT EXISTS" block.
//
// [DeviceField] and [LinkField] are SUBSETS of their models' `@internal`
// setters rather than equal to them, and deliberately: a device's
// designator, name and placement are each already wired to a command of
// their own. Only [OutletField] and [StructureBodyField] own every
// converted setter on their class, which is why only those two carry the
// exact-agreement test.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show LifecycleStatus, MountSurface, Wall;
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

// Top-level functions rather than closures so the [EntityAccess] instances
// below can be `const`: a tear-off of a top-level function is a constant
// expression, a closure literal is not.
Outlet? _lookUpOutlet(RackDocument doc, Uuid id) => doc.outlets[id];
EntityMeta _outletMeta(Outlet o) => o.meta;

StructureBody? _lookUpStructureBody(RackDocument doc, Uuid id) =>
    doc.structures[id];
EntityMeta _structureBodyMeta(StructureBody b) => b.meta;

DeviceInstance? _lookUpDevice(RackDocument doc, Uuid id) => doc.devices[id];
EntityMeta _deviceMeta(DeviceInstance d) => d.meta;

Link? _lookUpLink(RackDocument doc, Uuid id) => doc.links[id];
EntityMeta _linkMeta(Link l) => l.meta;

/// How [SetEntityPropertyCommand] reaches one KIND of entity: which map to
/// look an id up in, and where that entity keeps its [EntityMeta].
///
/// Shared by every field of that entity rather than repeated per field, so
/// adding a row to a table below is one line and cannot get the lookup
/// wrong.
final class EntityAccess<E> {
  const EntityAccess({
    required this.name,
    required this.lookUp,
    required this.metaOf,
  });

  /// Namespaces [SetEntityPropertyCommand.mergeKey], so an `Outlet` field
  /// and a `StructureBody` field that happen to share a key (both have a
  /// location, for instance) can never coalesce into one undo entry.
  ///
  /// NOT persisted, so it is free to rename.
  final String name;

  /// Returns null when the document does not hold that entity, which is a
  /// caller bug the command turns into a named [StateError] rather than a
  /// bare null dereference.
  final E? Function(RackDocument doc, Uuid id) lookUp;

  /// The entity's own `EntityMeta`, which the command snapshots before it
  /// writes and restores on revert (CR-117 byte identity).
  final EntityMeta Function(E entity) metaOf;

  /// One wall plate / one ceiling location (CR-016).
  static const outlet = EntityAccess<Outlet>(
    name: 'outlet',
    lookUp: _lookUpOutlet,
    metaOf: _outletMeta,
  );

  /// The Structure device's body, paired 1:1 with its `DeviceInstance`.
  static const structureBody = EntityAccess<StructureBody>(
    name: 'structureBody',
    lookUp: _lookUpStructureBody,
    metaOf: _structureBodyMeta,
  );

  /// One placed (or staged) piece of equipment.
  static const device = EntityAccess<DeviceInstance>(
    name: 'device',
    lookUp: _lookUpDevice,
    metaOf: _deviceMeta,
  );

  /// One cable.
  static const link = EntityAccess<Link>(
    name: 'link',
    lookUp: _lookUpLink,
    metaOf: _linkMeta,
  );

  @override
  String toString() => 'EntityAccess($name)';
}

/// A typed accessor for one editable property of entity [E]: how to read
/// it, how to write it, and which epochs writing it invalidates.
///
/// The table entries below are `static final`, not `const`, and cannot be
/// `const`: `EpochMask` is an `extension type`, so `|` is a method call
/// and `EpochMask.structure | EpochMask.meta` is not a constant
/// expression. Spelling those masks as raw bit literals to buy `const`ness
/// would hardcode `EpochMask`'s bit assignments in a second place. The
/// tables are built once at first use; nothing about them is hot.
final class EntityField<E, T> {
  const EntityField({
    required this.access,
    required this.key,
    required this.get,
    required this.set,
    required this.touches,
  });

  /// Which map to find the entity in, and where its meta lives.
  final EntityAccess<E> access;

  /// A stable identifier, unique within its own table (asserted by the
  /// unit test) because it is half of [SetEntityPropertyCommand.mergeKey]
  /// and therefore what makes coalescing per-property.
  final String key;

  final T Function(E entity) get;
  final void Function(E entity, T value) set;

  /// Declared PER FIELD rather than as one blanket mask. Over-declaring is
  /// explicitly sanctioned (AC-014, "when in doubt, over-declare") and
  /// `epoch_mask_test` only ever asserts a superset, but renaming an
  /// outlet genuinely does not move it and should not force that relayout.
  final EpochMask touches;

  @override
  String toString() => 'EntityField(${access.name}.$key)';
}

/// Every editable [Outlet] property.
///
/// The epoch split is the one `EpochMask`'s own doc comments describe:
/// `meta` is "designators, names, notes", `structure` is where a thing
/// physically sits. `nominalRunLength` over-declares `wires` as well,
/// because it is a CABLE length the schedule prints in a link row
/// (`ScheduleLengthSource`), and a consumer watching cable data subscribes
/// to `wires`.
abstract final class OutletField {
  /// "GR-TV-1" — the outlet's own field designation.
  static final designation = EntityField<Outlet, String>(
    access: EntityAccess.outlet,
    key: 'designation',
    get: (o) => o.designation,
    set: (o, v) => o.designation = v,
    touches: EpochMask.meta,
  );

  static final notes = EntityField<Outlet, String?>(
    access: EntityAccess.outlet,
    key: 'notes',
    get: (o) => o.notes,
    set: (o, v) => o.notes = v,
    touches: EpochMask.meta,
  );

  /// A standards TAG, not an axis (CR-108) — so `meta`, not `structure`.
  static final tia570Grade = EntityField<Outlet, String?>(
    access: EntityAccess.outlet,
    key: 'tia570Grade',
    get: (o) => o.tia570Grade,
    set: (o, v) => o.tia570Grade = v,
    touches: EpochMask.meta,
  );

  static final locationId = EntityField<Outlet, Uuid?>(
    access: EntityAccess.outlet,
    key: 'locationId',
    get: (o) => o.locationId,
    set: (o, v) => o.locationId = v,
    touches: EpochMask.structure,
  );

  static final wall = EntityField<Outlet, Wall?>(
    access: EntityAccess.outlet,
    key: 'wall',
    get: (o) => o.wall,
    set: (o, v) => o.wall = v,
    touches: EpochMask.structure,
  );

  static final mountSurface = EntityField<Outlet, MountSurface?>(
    access: EntityAccess.outlet,
    key: 'mountSurface',
    get: (o) => o.mountSurface,
    set: (o, v) => o.mountSurface = v,
    touches: EpochMask.structure,
  );

  /// Height above finished floor. Null is UNKNOWN, never zero (CR-114) —
  /// a plate nobody has measured is not a plate on the floor.
  static final mountHeightAff = EntityField<Outlet, Len?>(
    access: EntityAccess.outlet,
    key: 'mountHeightAff',
    get: (o) => o.mountHeightAff,
    set: (o, v) => o.mountHeightAff = v,
    touches: EpochMask.structure,
  );

  static final floorNumber = EntityField<Outlet, int?>(
    access: EntityAccess.outlet,
    key: 'floorNumber',
    get: (o) => o.floorNumber,
    set: (o, v) => o.floorNumber = v,
    touches: EpochMask.structure,
  );

  static final pathwayId = EntityField<Outlet, Uuid?>(
    access: EntityAccess.outlet,
    key: 'pathwayId',
    get: (o) => o.pathwayId,
    set: (o, v) => o.pathwayId = v,
    touches: EpochMask.structure,
  );

  /// Null is UNKNOWN and the rollup counts it as such (G4, CR-114); it is
  /// never a measured zero-length run.
  static final nominalRunLength = EntityField<Outlet, Len?>(
    access: EntityAccess.outlet,
    key: 'nominalRunLength',
    get: (o) => o.nominalRunLength,
    set: (o, v) => o.nominalRunLength = v,
    touches: EpochMask.structure | EpochMask.wires,
  );

  /// Every field in the table, for tests and for any caller that needs to
  /// enumerate them. READ-ONLY use: calling `set` through the erased
  /// element type would defeat the static typing the table exists for.
  static final List<EntityField<Outlet, Object?>> all = [
    designation,
    notes,
    tia570Grade,
    locationId,
    wall,
    mountSurface,
    mountHeightAff,
    floorNumber,
    pathwayId,
    nominalRunLength,
  ];
}

/// Every editable [StructureBody] property.
abstract final class StructureBodyField {
  /// "Rough-In - First Floor".
  static final title = EntityField<StructureBody, String>(
    access: EntityAccess.structureBody,
    key: 'title',
    get: (b) => b.title,
    set: (b, v) => b.title = v,
    touches: EpochMask.meta,
  );

  /// "Generic 42 in structured media enclosure" — a model string the
  /// equipment list prints, not a placement.
  static final enclosureModel = EntityField<StructureBody, String?>(
    access: EntityAccess.structureBody,
    key: 'enclosureModel',
    get: (b) => b.enclosureModel,
    set: (b, v) => b.enclosureModel = v,
    touches: EpochMask.meta,
  );

  static final role = EntityField<StructureBody, StructureRole>(
    access: EntityAccess.structureBody,
    key: 'role',
    get: (b) => b.role,
    set: (b, v) => b.role = v,
    touches: EpochMask.structure,
  );

  /// The SMC / can / MDF location.
  static final distributionDeviceLocationId = EntityField<StructureBody, Uuid?>(
    access: EntityAccess.structureBody,
    key: 'distributionDeviceLocationId',
    get: (b) => b.distributionDeviceLocationId,
    set: (b, v) => b.distributionDeviceLocationId = v,
    touches: EpochMask.structure,
  );

  /// CR-072. `structure`, not `style`: `schematic_scene.dart` and
  /// `sugiyama.dart` both read it, so flipping it moves the bank of
  /// off-page connectors to the other side of the sheet. That is a
  /// relayout, not a repaint.
  static final sheetEdge = EntityField<StructureBody, SheetEdge>(
    access: EntityAccess.structureBody,
    key: 'sheetEdge',
    get: (b) => b.sheetEdge,
    set: (b, v) => b.sheetEdge = v,
    touches: EpochMask.structure,
  );

  /// See [OutletField.all].
  static final List<EntityField<StructureBody, Object?>> all = [
    title,
    enclosureModel,
    role,
    distributionDeviceLocationId,
    sheetEdge,
  ];
}

/// Editable [DeviceInstance] properties.
///
/// ONE ROW SO FAR, and the AC-013 rule is why: a field is converted to an
/// `@internal` setter as it is wired to a Command, and `DeviceInstance`'s
/// other converted setters (`designator`, `name`, `placement`, `notes`)
/// are wired to `RenameEntityCommand` and `MoveDeviceCommand` instead. So
/// unlike [OutletField] and [StructureBodyField], this table is a SUBSET
/// of the model's `@internal` setters rather than equal to it, and its
/// test asserts the one direction that holds.
abstract final class DeviceField {
  /// The five-state enum M3-A/7 exists for.
  ///
  /// `structure | meta` because the rack canvas subscribes to exactly
  /// those two: `structure` redraws the elevation, whose border is a
  /// different dash per state (`lifecycleStroke`, docs/08 §2.2), and
  /// `meta` refreshes T6.30's STATUS word (`lifecycleLabel`). Declaring
  /// only one of them would leave a user looking at a stale border or a
  /// stale list after an edit they just made.
  static final lifecycleStatus = EntityField<DeviceInstance, LifecycleStatus>(
    access: EntityAccess.device,
    key: 'lifecycleStatus',
    get: (d) => d.lifecycleStatus,
    set: (d, v) => d.lifecycleStatus = v,
    touches: EpochMask.structure | EpochMask.meta,
  );

  /// See [OutletField.all].
  static final List<EntityField<DeviceInstance, Object?>> all = [
    lifecycleStatus,
  ];
}

/// Editable [Link] properties.
///
/// A subset of the model's `@internal` setters, for [DeviceField]'s
/// reason: `designator`, `notes`, the two jacket colours and the link
/// class are each wired to their own command.
abstract final class LinkField {
  /// `wires | meta` rather than the device's `structure | meta`: a cable's
  /// state reaches paper through the schedule and the schematic, and the
  /// schematic canvas subscribes to `wires`.
  static final lifecycleStatus = EntityField<Link, LifecycleStatus>(
    access: EntityAccess.link,
    key: 'lifecycleStatus',
    get: (l) => l.lifecycleStatus,
    set: (l, v) => l.lifecycleStatus = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// See [OutletField.all].
  static final List<EntityField<Link, Object?>> all = [lifecycleStatus];
}

/// Sets one [EntityField] on one entity.
///
/// `revert()` restores [EntityMeta] via `restoreTo` rather than calling
/// `touch` again, for the reason `MoveDeviceCommand` (device_commands.dart)
/// gives at length: a revision left one higher than it started is exactly
/// what breaks CR-117's byte round-trip.
final class SetEntityPropertyCommand<E, T> extends Command {
  SetEntityPropertyCommand({
    required this.id,
    required this.field,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final EntityField<E, T> field;
  final T from;
  final T to;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  /// ONE value for both entity kinds, and for every field. The Edit menu
  /// says "Undo edit"; the distinction between editing an outlet's height
  /// and its label is not one a user needs the menu to make, and
  /// `SetRackPropertyCommand` already sets that precedent with twelve
  /// fields behind `setRackProperty`.
  @override
  LabelKey get label => LabelKey.setEntityProperty;

  @override
  EpochMask get touches => field.touches;

  @override
  Iterable<Uuid> get affects => [id];

  /// Includes the table name AND the field key, so coalescing is PER
  /// PROPERTY PER ENTITY KIND: typing in a designation box collapses into
  /// one undo entry, but editing a designation and then a mounting height
  /// does not merge into a single "edit" the user cannot unpick.
  @override
  Object? get mergeKey => (
    SetEntityPropertyCommand,
    field.access.name,
    field.key,
    id,
  );

  @override
  void apply(RackDocument doc) {
    final entity = _resolve(doc);
    final meta = field.access.metaOf(entity);
    _prevUpdatedAt = meta.updatedAt;
    _prevUpdatedBy = meta.updatedBy;
    _prevLocalRevision = meta.localRevision;
    field.set(entity, to);
    meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError(
        'SetEntityPropertyCommand.revert called before apply().',
      );
    }
    final entity = _resolve(doc);
    field.set(entity, from);
    field.access
        .metaOf(entity)
        .restoreTo(
          updatedAt: prevAt,
          updatedBy: prevBy,
          localRevision: prevRev,
        );
  }

  @override
  Command? mergeWith(Command next) {
    if (next is! SetEntityPropertyCommand<E, T>) return null;
    if (next.id != id) return null;
    if (next.field.key != field.key) return null;
    if (next.field.access.name != field.access.name) return null;
    // Carries THIS command's already-captured "before" meta snapshot
    // forward: the merged command is a fresh object that never itself has
    // apply() called on it before a possible revert(). Same reasoning as
    // MoveDeviceCommand.mergeWith.
    return SetEntityPropertyCommand<E, T>(
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

  /// A missing entity is a caller bug — an undo stack replayed against the
  /// wrong document, or a command outliving the thing it edits — so it
  /// names itself rather than failing as a null dereference three frames
  /// deeper.
  E _resolve(RackDocument doc) {
    final entity = field.access.lookUp(doc, id);
    if (entity == null) {
      throw StateError(
        'SetEntityPropertyCommand: no ${field.access.name} "${id.v}" in '
        'this document (field ${field.key}).',
      );
    }
    return entity;
  }
}

/// Builds the command that moves [field] on entity [id] from its CURRENT
/// value to [to], or null when it already holds [to] — so a caller can
/// honour docs/04 §3.4's "never silently do nothing" by telling "nothing
/// to do" apart from "did something" instead of pushing an empty undo
/// entry.
///
/// An unknown id THROWS rather than returning null, because the two mean
/// different things: null is a no-op the caller may ignore, an unknown id
/// is a bug. `buildSetRackProperty` draws the same line.
SetEntityPropertyCommand<E, T>? buildSetEntityProperty<E, T>({
  required RackDocument doc,
  required Uuid id,
  required EntityField<E, T> field,
  required T to,
  required DateTime now,
  required String actor,
}) {
  final entity = field.access.lookUp(doc, id);
  if (entity == null) {
    throw ArgumentError.value(
      id,
      'id',
      'no such ${field.access.name} in document',
    );
  }
  final from = field.get(entity);
  if (from == to) return null;
  return SetEntityPropertyCommand<E, T>(
    id: id,
    field: field,
    from: from,
    to: to,
    now: now,
    actor: actor,
  );
}
