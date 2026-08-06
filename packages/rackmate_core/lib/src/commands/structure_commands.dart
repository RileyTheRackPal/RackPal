// rackmate_core/src/commands/structure_commands.dart — pure Dart.
//
// The commands that let a Structure body and its Outlets EXIST. Board
// M3-A/1, roadmap M3, requirement 6.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS FILE IS THE FIRST THING M3 BUILDS
// ─────────────────────────────────────────────────────────────────────────
// `StructureBody`, `Outlet` and `OutletDrop` have been modelled since M0
// and byte-round-tripped since the codec landed, and until this file
// NOTHING IN THE APP COULD WRITE ONE. That is exactly the shape M2-F found
// on `doc.ports`: the whole connect gesture was unreachable because no code
// path ever created a port. A model that round-trips is not a model
// anything can create, and a starter that ships Structure data only proves
// the codec works.
//
// AC-018 is unreachable by construction until these exist, because a home
// run needs an `Outlet` to originate from. M2-B's schedule already handles
// unbound far ends; the work is producing the drops, not teaching the
// schedule (board #141 verifies that claim rather than assuming it).
//
// ─────────────────────────────────────────────────────────────────────────
// THE DEVICE AND THE BODY ARE ONE UNIT
// ─────────────────────────────────────────────────────────────────────────
// `StructureBody` is "always paired 1:1 with a `DeviceInstance` whose
// `kind == DeviceKind.structure`" (structure_body.dart). Neither half is
// valid alone: a body whose `deviceId` resolves to nothing fails the
// starters' own referential check, and a structure device with no body has
// nothing to draw. So [AddStructureCommand] creates BOTH and
// [RemoveStructureCommand] takes both, rather than leaving a caller to
// compose two commands and eventually forget one.
//
// ─────────────────────────────────────────────────────────────────────────
// THE RESERVED TEMPLATE REF, AND WHY IT IS A CONSTANT HERE
// ─────────────────────────────────────────────────────────────────────────
// `DeviceInstance.templateRef` is non-nullable and CR-054 says a ref always
// resolves, but docs/07 §2 gives the Structure device NO template: its
// "ports" are a rendering of home-run field endpoints (AC-019). It
// therefore names a reserved id that deliberately resolves to nothing, and
// `starter_integrity.dart` exempts exactly this one `DeviceKind` from the
// resolve check. The shipped starters all spell that ref the same way; it
// is a named constant here so the app's spelling cannot drift from
// theirs, which would make every created Structure fail a check the
// starters pass.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show MountSurface, Wall;
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/model/template.dart' show TemplateRef;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The Structure device's designator prefix — `STR-1`, `STR-2`, …
const String kStructureTypePrefix = 'STR';

/// The reserved `TemplateRef` every Structure device names. See the file
/// header for why it resolves to nothing on purpose.
const TemplateRef kStructureTemplateRef = TemplateRef(
  templateId: TemplateId('structure'),
  version: 1,
  contentHash: 'sha256:structure-no-template',
);

/// The designator a NEW Structure device should receive.
///
/// Through the ONE format engine (CR-045), like `allocateRackDesignator`,
/// rather than a second `'STR-$n'` concatenation that would ignore a
/// project's customised separator or padding.
///
/// ALLOCATED CALLER-SIDE and passed in, never computed inside `apply`:
/// `Command`'s contract is that redo recreates the IDENTICAL entity, and a
/// designator recomputed at apply time would drift the moment another
/// device was added between the undo and the redo.
String allocateStructureDesignator({
  required RackDocument doc,
  String typePrefix = kStructureTypePrefix,
}) => allocateDeviceDesignator(
  settings: doc.settings,
  typePrefix: typePrefix,
  usedDesignators: {for (final d in doc.devices.values) d.designator},
);

/// The `FracIndex` a new [Outlet] should sort at, at the end of the list.
///
/// Locations, outlets and structures all previously had NO creating command
/// at all, which is why `Location.order` collisions were reachable from a
/// decoded file. Everything this file creates goes through [nextOrder], the
/// same allocator racks and links use.
FracIndex nextOutletOrder(RackDocument doc) =>
    nextOrder(doc.outlets.values.map((o) => o.order));

/// Creates the paired Structure `DeviceInstance` + [StructureBody].
final class AddStructureCommand extends Command {
  AddStructureCommand({
    required this.title,
    required this.designator,
    required this.now,
    required this.actor,
    String? name,
    this.role = StructureRole.homeRunField,
    this.sheetEdge = SheetEdge.left,
    this.locationId,
    this.enclosureModel,
    Uuid? deviceId,
    Uuid? bodyId,
  }) : name = name ?? title,
       deviceId = deviceId ?? newEntityId(),
       bodyId = bodyId ?? newEntityId();

  /// Both ids are minted in the CONSTRUCTOR, never in [apply] — the
  /// `Command` contract, so redo recreates the identical pair and anything
  /// stacked on top of it (an `Outlet`, a `Link.structureOrigin`) still
  /// resolves.
  final Uuid deviceId;
  final Uuid bodyId;

  /// "Rough-In - First Floor". Also the device's `name` unless one is
  /// given: the two are the same thing to a user, and a Structure whose
  /// device and body disagree reads as two entities.
  final String title;
  final String name;
  final String designator;
  final StructureRole role;
  final SheetEdge sheetEdge;

  /// The SMC / can / MDF location. Feeds BOTH the device's placement and
  /// the body's `distributionDeviceLocationId`, which is how the shipped
  /// starters spell it.
  final Uuid? locationId;
  final String? enclosureModel;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addStructure;

  /// `structure` for the device, `meta` for the designator, name and title
  /// that the equipment list and the schedule's TYPE cell read.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [deviceId, bodyId];

  @override
  void apply(RackDocument doc) {
    final meta = EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor);
    doc.devices[deviceId] = DeviceInstance(
      id: deviceId,
      kind: DeviceKind.structure,
      templateRef: kStructureTemplateRef,
      designator: designator,
      name: name,
      // OFF-RACK, not staged. A Structure body is the building side of the
      // job; it is not waiting to be racked, so the Staging Bin (CR-032)
      // is the wrong home for it. This matches every shipped starter.
      placement: OffRackPlacement(locationId: locationId),
      meta: meta,
      locationId: locationId,
      structureBodyId: bodyId,
    );
    doc.structures[bodyId] = StructureBody(
      id: bodyId,
      deviceId: deviceId,
      title: title,
      meta: meta,
      role: role,
      sheetEdge: sheetEdge,
      distributionDeviceLocationId: locationId,
      enclosureModel: enclosureModel,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.structures.remove(bodyId);
    doc.devices.remove(deviceId);
  }
}

/// Removes a Structure body and its paired device.
///
/// DOES NOT CASCADE TO OUTLETS OR LINKS, and that is deliberate rather than
/// unfinished. `RemoveDeviceCommand` cascades because a device's ports and
/// links are meaningless without it; an `Outlet` is a fact about the
/// BUILDING (a plate on a wall) and survives the panel it currently feeds.
/// A caller that means to remove both composes a `Transaction`, which is
/// visible in the Edit menu as one undo step and leaves this command
/// honest about what it took.
final class RemoveStructureCommand extends Command {
  RemoveStructureCommand({required this.bodyId});

  final Uuid bodyId;

  /// The SAME objects, not equivalent ones, so undo is not a lossy round
  /// trip through the entity CR-117's byte gate is about. The discipline
  /// `RemoveDeviceCommand` already holds.
  StructureBody? _removedBody;
  DeviceInstance? _removedDevice;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeStructure;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [bodyId];

  @override
  void apply(RackDocument doc) {
    // Reassigned, not accumulated: `apply` runs again on every redo and
    // each run must describe THAT run.
    _removedBody = doc.structures.remove(bodyId);
    final deviceId = _removedBody?.deviceId;
    _removedDevice = deviceId == null ? null : doc.devices.remove(deviceId);
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveStructureCommand.revert before apply');
    }
    // "Apply ran and it was already gone" is a legal outcome whose revert
    // is a no-op; "revert without apply" is a bug and throws above.
    final device = _removedDevice;
    if (device != null) doc.devices[device.id] = device;
    final body = _removedBody;
    if (body != null) doc.structures[body.id] = body;
  }
}

/// Creates one [Outlet] on a Structure body.
final class AddOutletCommand extends Command {
  AddOutletCommand({
    required this.structureBodyId,
    required this.designation,
    required this.order,
    required this.now,
    required this.actor,
    this.locationId,
    this.wall,
    this.mountSurface,
    this.mountHeightAff,
    this.floorNumber,
    this.outletTemplateId,
    this.tia570Grade,
    this.pathwayId,
    this.nominalRunLength,
    Uuid? id,
  }) : id = id ?? newEntityId();

  final Uuid id;
  final Uuid structureBodyId;

  /// "GR-TV-1" — the outlet's own field designation.
  final String designation;

  /// Allocated caller-side through [nextOutletOrder], for the same reason
  /// the designator is: recomputing it in `apply` would drift under redo.
  final FracIndex order;

  final Uuid? locationId;
  final Wall? wall;
  final MountSurface? mountSurface;
  final Len? mountHeightAff;
  final int? floorNumber;
  final String? outletTemplateId;
  final String? tia570Grade;
  final Uuid? pathwayId;

  /// EVERY OPTIONAL FIELD STAYS NULLABLE THROUGH THIS COMMAND. A caller
  /// that has not measured a run length passes null and the rollup counts
  /// it unknown; defaulting any of these to zero here would fabricate a
  /// measurement at the one point where the user is telling us they do not
  /// have one (G4, CR-114).
  final Len? nominalRunLength;

  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addOutlet;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: structureBodyId,
      designation: designation,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      locationId: locationId,
      wall: wall,
      mountSurface: mountSurface,
      mountHeightAff: mountHeightAff,
      floorNumber: floorNumber,
      outletTemplateId: outletTemplateId,
      tia570Grade: tia570Grade,
      pathwayId: pathwayId,
      nominalRunLength: nominalRunLength,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.outlets.remove(id);
  }
}

/// Removes one [Outlet].
///
/// Like [RemoveStructureCommand] this does NOT cascade: a `Link` keys back
/// to its outlet through `structureOrigin.outletId` (AC-019), and silently
/// deleting a user's home runs because they removed a wall plate is a much
/// larger edit than the gesture asked for. A caller that means both
/// composes a `Transaction`.
final class RemoveOutletCommand extends Command {
  RemoveOutletCommand({required this.id});

  final Uuid id;

  Outlet? _removed;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeOutlet;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    _removed = doc.outlets.remove(id);
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveOutletCommand.revert before apply');
    }
    final outlet = _removed;
    if (outlet != null) doc.outlets[outlet.id] = outlet;
  }
}
