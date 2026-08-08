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
// `SetEntityPropertyCommand` WAS FOLDED IN by board #578, so the package now
// has ONE accessor-table mechanism rather than two that drift. That was a
// separate commit on purpose: M3-A/5 was scoped to `Outlet` and
// `StructureBody`, and rewriting `rackmate_ui`'s inspector inside it would
// have been a scope change under roadmap §8.3. The names survived the fold
// (`RackField.designator`, `RackField.all`) and so did the Edit menu's own
// word for a rack edit, which is what [EntityAccess.label] is for.
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
//  * `Location.parentId` — the SAME exclusion for the same reason, one
//    milestone task later. DR-021 §11.20.5 makes a reparent refuse a
//    cycle, and a row cannot refuse. `ReparentLocationCommand` owns it,
//    behind `buildReparentLocation` (location_commands.dart).
//  * `Location.order` — reordering siblings is a drag, and it wants
//    `nextLocationOrder` rather than a value a caller supplies. Identical
//    to `Outlet.order` above.
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
    show LifecycleStatus, MountSurface, RuNumbering, Wall;
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

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

Location? _lookUpLocation(RackDocument doc, Uuid id) => doc.locations[id];
EntityMeta _locationMeta(Location l) => l.meta;

Rack? _lookUpRack(RackDocument doc, Uuid id) => doc.racks[id];
EntityMeta _rackMeta(Rack r) => r.meta;

/// How [SetEntityPropertyCommand] reaches one KIND of entity: which map to
/// look an id up in, and where that entity keeps its [EntityMeta].
///
/// Shared by every field of that entity rather than repeated per field, so
/// adding a row to a table below is one line and cannot get the lookup
/// wrong.
final class EntityAccess<E> {
  const EntityAccess({
    required this.name,
    required this.label,
    required this.lookUp,
    required this.metaOf,
  });

  /// Namespaces [SetEntityPropertyCommand.mergeKey], so an `Outlet` field
  /// and a `StructureBody` field that happen to share a key (both have a
  /// location, for instance) can never coalesce into one undo entry.
  ///
  /// NOT persisted, so it is free to rename.
  final String name;

  /// What the Edit menu offers to undo.
  ///
  /// PER ENTITY KIND, not one value for the whole command. `Rack` edits
  /// said "set rack property" for a whole milestone before this class
  /// absorbed them, and folding two implementations together is not a
  /// reason to reword a menu item a user has learned. Every other kind
  /// shares `setEntityProperty`: whether someone was changing a mounting
  /// height or a label is not a distinction the menu has to draw.
  final LabelKey label;

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
    label: LabelKey.setEntityProperty,
    lookUp: _lookUpOutlet,
    metaOf: _outletMeta,
  );

  /// The Structure device's body, paired 1:1 with its `DeviceInstance`.
  static const structureBody = EntityAccess<StructureBody>(
    name: 'structureBody',
    label: LabelKey.setEntityProperty,
    lookUp: _lookUpStructureBody,
    metaOf: _structureBodyMeta,
  );

  /// One placed (or staged) piece of equipment.
  static const device = EntityAccess<DeviceInstance>(
    name: 'device',
    label: LabelKey.setEntityProperty,
    lookUp: _lookUpDevice,
    metaOf: _deviceMeta,
  );

  /// A physical enclosure or frame (docs/04 §4).
  static const rack = EntityAccess<Rack>(
    name: 'rack',
    label: LabelKey.setRackProperty,
    lookUp: _lookUpRack,
    metaOf: _rackMeta,
  );

  /// One cable.
  static const link = EntityAccess<Link>(
    name: 'link',
    label: LabelKey.setEntityProperty,
    lookUp: _lookUpLink,
    metaOf: _linkMeta,
  );

  /// One node of the arbitrary-depth location tree (CR-047).
  static const location = EntityAccess<Location>(
    name: 'location',
    label: LabelKey.setEntityProperty,
    lookUp: _lookUpLocation,
    metaOf: _locationMeta,
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

/// Every editable [Rack] property: the twelve docs/04 §4 makes editable.
///
/// THE ORIGINAL ACCESSOR TABLE. It shipped in M1 with its own command
/// class, `SetEntityPropertyCommand`, whose file argued this whole shape:
/// one class rather than twelve, and a typed table rather than an
/// `Object?` payload that would discard static typing at exactly the
/// inspector call sites that generate it. M3-A/5 needed the same thing on
/// two more entities and made the entity a type parameter; board #578
/// then folded this one in, so the package has ONE mechanism rather than
/// two that drift.
///
/// The names are unchanged (`RackField.designator`, `RackField.all`) and
/// so is the Edit menu's word for a rack edit — see [EntityAccess.label].
///
/// `heightU` IS ABSENT ON PURPOSE. It has its own `SetRackHeightCommand`,
/// because CR-038's 1..60 range is asserted on the setter and a resize can
/// displace occupants, which is a transaction rather than a field write.
abstract final class RackField {
  /// "RK-1" — the ONLY rack identifier (CR-040).
  static final designator = EntityField<Rack, String>(
    access: EntityAccess.rack,
    key: 'designator',
    get: (r) => r.designator,
    set: (r, v) => r.designator = v,
    touches: EpochMask.meta,
  );

  static final locationId = EntityField<Rack, Uuid?>(
    access: EntityAccess.rack,
    key: 'locationId',
    get: (r) => r.locationId,
    set: (r, v) => r.locationId = v,
    touches: EpochMask.meta,
  );

  /// Display-only (CR-026), but it redraws the RU ruler — hence `style` as
  /// well as `rack`.
  static final ruNumbering = EntityField<Rack, RuNumbering>(
    access: EntityAccess.rack,
    key: 'ruNumbering',
    get: (r) => r.ruNumbering,
    set: (r, v) => r.ruNumbering = v,
    touches: EpochMask.rack | EpochMask.style,
  );

  /// Display-only (CR-035), but it drives the NOT MIRRORED chip.
  static final mirrorRearElevation = EntityField<Rack, bool>(
    access: EntityAccess.rack,
    key: 'mirrorRearElevation',
    get: (r) => r.mirrorRearElevation,
    set: (r, v) => r.mirrorRearElevation = v,
    touches: EpochMask.rack | EpochMask.style,
  );

  static final widthClass = EntityField<Rack, RackWidthClass>(
    access: EntityAccess.rack,
    key: 'widthClass',
    get: (r) => r.widthClass,
    set: (r, v) => r.widthClass = v,
    touches: EpochMask.rack,
  );

  static final railType = EntityField<Rack, RailType>(
    access: EntityAccess.rack,
    key: 'railType',
    get: (r) => r.railType,
    set: (r, v) => r.railType = v,
    touches: EpochMask.rack,
  );

  static final formFactor = EntityField<Rack, RackFormFactor>(
    access: EntityAccess.rack,
    key: 'formFactor',
    get: (r) => r.formFactor,
    set: (r, v) => r.formFactor = v,
    touches: EpochMask.rack,
  );

  /// Nullable: a 2-post frame leaves it unset, and null means UNKNOWN,
  /// never zero (CR-114, docs/04 §4's "explicit unset/dash state").
  static final usableDepth = EntityField<Rack, Len?>(
    access: EntityAccess.rack,
    key: 'usableDepth',
    get: (r) => r.usableDepth,
    set: (r, v) => r.usableDepth = v,
    touches: EpochMask.rack,
  );

  static final weightCapacity = EntityField<Rack, Mass?>(
    access: EntityAccess.rack,
    key: 'weightCapacity',
    get: (r) => r.weightCapacity,
    set: (r, v) => r.weightCapacity = v,
    touches: EpochMask.rack,
  );

  static final isSwingFrame = EntityField<Rack, bool>(
    access: EntityAccess.rack,
    key: 'isSwingFrame',
    get: (r) => r.isSwingFrame,
    set: (r, v) => r.isSwingFrame = v,
    touches: EpochMask.rack,
  );

  static final hingeSide = EntityField<Rack, HingeSide?>(
    access: EntityAccess.rack,
    key: 'hingeSide',
    get: (r) => r.hingeSide,
    set: (r, v) => r.hingeSide = v,
    touches: EpochMask.rack,
  );

  static final groundBarPresent = EntityField<Rack, bool>(
    access: EntityAccess.rack,
    key: 'groundBarPresent',
    get: (r) => r.groundBarPresent,
    set: (r, v) => r.groundBarPresent = v,
    touches: EpochMask.rack,
  );

  /// See [OutletField.all].
  static final List<EntityField<Rack, Object?>> all = [
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

  /// How many splices are in this run (DR-020 §11.19.2(3), M3-J/2).
  ///
  /// `EntityField<Link, int?>` AND NOT `int`. Null is unknown and `0` is
  /// a confirmed none (G4, CR-114), so clearing the cell has to be a
  /// legal edit that lands as null rather than as zero. The generic
  /// machinery already carries the nullable case for `Outlet.notes` and
  /// `StructureOrigin.rackLabel`; this is the same contract on a number.
  static final spliceCount = EntityField<Link, int?>(
    access: EntityAccess.link,
    key: 'spliceCount',
    get: (l) => l.spliceCount,
    set: (l, v) => l.spliceCount = v,
    touches: EpochMask.wires | EpochMask.meta,
  );

  /// See [OutletField.all].
  static final List<EntityField<Link, Object?>> all = [
    lifecycleStatus,
    spliceCount,
  ];
}

/// Every editable [Location] property except `parentId`.
///
/// The exception is the whole design of this table and is stated in the
/// file header: a reparent refuses a cycle (DR-021 §11.20.5) and a row
/// cannot refuse, so the tree's one structural field is the one field not
/// in here. Everything else about a location is an ordinary write.
///
/// LIKE [OutletField] AND [StructureBodyField], this table owns every
/// `@internal` setter on its class bar that one, so its agreement test is
/// an equality rather than a `containsAll`.
abstract final class LocationField {
  /// "Master Bedroom". Renaming propagates to every label, schedule row
  /// and PDF callout in one undoable command (docs/04 §7.5), which is a
  /// property of designators being STORED (CR-048) and read through the
  /// location rather than copied onto each row.
  static final name = EntityField<Location, String>(
    access: EntityAccess.location,
    key: 'name',
    get: (l) => l.name,
    set: (l, v) => l.name = v,
    touches: EpochMask.meta,
  );

  /// "MBR" — the ONE abbreviation field (CR-046), which `{ROOM_ABBR}`
  /// reads.
  static final code = EntityField<Location, String>(
    access: EntityAccess.location,
    key: 'code',
    get: (l) => l.code,
    set: (l, v) => l.code = v,
    touches: EpochMask.meta,
  );

  /// `meta`, not `structure`, and this is CR-047 showing up as a mask: the
  /// tree's shape is `parentId` alone, so `kind` moves nothing. It is a
  /// word the user picked for a node, filtered on by the device builder's
  /// four-level VIEW and carrying no containment of its own.
  static final kind = EntityField<Location, LocationKind>(
    access: EntityAccess.location,
    key: 'kind',
    get: (l) => l.kind,
    set: (l, v) => l.kind = v,
    touches: EpochMask.meta,
  );

  /// `structure`, matching [OutletField.floorNumber]: a storey is where a
  /// thing is, not what it is called.
  static final floorNumber = EntityField<Location, int?>(
    access: EntityAccess.location,
    key: 'floorNumber',
    get: (l) => l.floorNumber,
    set: (l, v) => l.floorNumber = v,
    touches: EpochMask.structure,
  );

  /// "101" — a room number, so `meta` beside [code] rather than
  /// `structure` beside [floorNumber]. Both are identifiers a building
  /// gives a space; neither says where the space is.
  static final spaceCode = EntityField<Location, String?>(
    access: EntityAccess.location,
    key: 'spaceCode',
    get: (l) => l.spaceCode,
    set: (l, v) => l.spaceCode = v,
    touches: EpochMask.meta,
  );

  /// AC-024's ONE number per room, which seeds every home run in that room
  /// (`ScheduleLengthSource.roomEstimate`).
  ///
  /// `structure | wires` for [OutletField.nominalRunLength]'s reason: it is
  /// a CABLE length the schedule prints, and a consumer watching cable data
  /// subscribes to `wires`. Null stays UNKNOWN and the rollup counts it
  /// (G4, CR-114); it is never a measured zero.
  static final estimatedRunLengthFromRack = EntityField<Location, Len?>(
    access: EntityAccess.location,
    key: 'estimatedRunLengthFromRack',
    get: (l) => l.estimatedRunLengthFromRack,
    set: (l, v) => l.estimatedRunLengthFromRack = v,
    touches: EpochMask.structure | EpochMask.wires,
  );

  /// See [OutletField.all].
  static final List<EntityField<Location, Object?>> all = [
    name,
    code,
    kind,
    floorNumber,
    spaceCode,
    estimatedRunLengthFromRack,
  ];
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

  /// From the ACCESS, not this class — see [EntityAccess.label] for why a
  /// rack edit keeps its own word.
  @override
  LabelKey get label => field.access.label;

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
/// is a bug. `buildSetEntityProperty` draws the same line.
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
