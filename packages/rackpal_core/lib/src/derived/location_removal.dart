// rackpal_core/src/derived/location_removal.dart — pure Dart.
//
// DR-021 §11.20.3 — what deleting a location actually costs, computed
// BEFORE anything is removed. Board M3-B/1.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE NUMBER, ONE SOURCE
// ═══════════════════════════════════════════════════════════════════════
// `device_removal.dart` states the rule and every word of it applies here:
// the number has to exist before the command runs, because it is what the
// user answers a dialog about, and the command has to remove exactly what
// the number described. Two walks over the same document asking the same
// question is how the dialog and the edit drift apart.
//
// So the plan is computed HERE, once, and `RemoveLocationCommand` consumes
// it rather than re-deriving its own.
//
// ═══════════════════════════════════════════════════════════════════════
// NINE CARRIERS, AND WHY THE CENSUS IS IN THE RULING
// ═══════════════════════════════════════════════════════════════════════
// DR-021 enumerates them because a grep does not: `Pathway` spells its two
// `fromLocationId`/`toLocationId`, so a case-sensitive search for
// `locationId` finds seven of the nine. Two of the nine are inside
// IMMUTABLE value objects (`OffRackPlacement`, `PlaceEndpoint`), which is
// why [LocationRef] has to say WHERE in an entity the reference sits and
// not merely which entity holds one.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IS COUNTED IS ENTITIES, NOT REFERENCES
// ═══════════════════════════════════════════════════════════════════════
// A four-conductor home run to a wall plate holds four `PlaceEndpoint`s in
// one room. That is ONE cable to the person reading the dialog: one thing
// they pull, one row on the schedule. Any count of cables makes the same
// call about a link touching one jack twice, for the same reason: a count
// in the wrong unit is a dialog that says four where an installer sees
// one.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS DOES NOT COUNT, BECAUSE IT DOES NOT GO
// ═══════════════════════════════════════════════════════════════════════
// No `Link`, `Outlet`, `Pathway` or drop is deleted (DR-021 §11.20.6). A
// cable pulled to a wall is a fact about the building and survives the room
// being renamed out of existence, which is `RemoveStructureCommand`'s own
// argument about an outlet surviving the panel it feeds. So a referring
// entity appears in [LocationRemovalPlan.references] as something that
// LOSES A FIELD, never as something that goes.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/location_tree.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Which of DR-021's nine carriers one [LocationRef] names.
///
/// An enum rather than nine subclasses: eight of the nine are "one
/// nullable field on one entity" and differ only in which map to look the
/// id up in, so a sealed union would be eight empty classes and a switch
/// in exactly the same place.
enum LocationRefKind {
  /// `Rack.locationId`.
  rack,

  /// `DeviceInstance.locationId`.
  device,

  /// `OffRackPlacement.locationId`, inside `DeviceInstance.placement`.
  /// IMMUTABLE: clearing it constructs a replacement placement.
  devicePlacement,

  /// `Outlet.locationId`.
  outlet,

  /// `StructureBody.distributionDeviceLocationId`.
  structureBody,

  /// `Circuit.locationId`.
  circuit,

  /// `Pathway.fromLocationId`.
  pathwayFrom,

  /// `Pathway.toLocationId`.
  pathwayTo,

  /// `PlaceEndpoint.locationId`, inside one end of one `Conductor` of one
  /// `Link`. IMMUTABLE, and the only carrier that needs a position within
  /// its entity to be found again.
  placeEndpoint,

  /// `PlanUnderlay.locationId`, the floor a plan shows (DR-185, `#912`).
  ///
  /// THE TENTH, AND IT WAS NOT MISSED SO MUCH AS UNREACHABLE. The field
  /// has been in the model since `PLAN-C` and nothing wrote it until
  /// DR-185 gave it a dialog, so no document could carry a reference for
  /// this census to find. The day it could, a deleted floor would have
  /// left its plans pointing at nothing.
  underlay,
}

/// One field, somewhere in the document, that points at a location being
/// removed.
///
/// Enough to FIND the field again and no more. The command holds the
/// replaced objects across its own apply/revert boundary, which is how
/// undo restores them unchanged, but a plan is a question rather than a
/// clipboard: a plan holding entities would be a second place they could
/// go stale.
@immutable
final class LocationRef {
  const LocationRef({
    required this.kind,
    required this.entityId,
    required this.locationId,
    this.conductorIndex,
    this.isFromEnd,
  });

  final LocationRefKind kind;

  /// The rack / device / outlet / structure body / circuit / pathway /
  /// link this reference lives in. The unit the dialog counts.
  final Uuid entityId;

  /// Which location it points at. Not always the node being deleted: a
  /// subtree delete clears references to every node in it, and the ref
  /// records which, so revert puts the RIGHT id back.
  final Uuid locationId;

  /// [LocationRefKind.placeEndpoint] only: which conductor of the link.
  final int? conductorIndex;

  /// [LocationRefKind.placeEndpoint] only: `true` for `Conductor.from`,
  /// `false` for `Conductor.to`.
  final bool? isFromEnd;

  @override
  String toString() =>
      'LocationRef(${kind.name} ${entityId.v}'
      '${conductorIndex == null ? '' : ' c$conductorIndex'
                '${isFromEnd! ? '.from' : '.to'}'})';
}

/// Everything one `RemoveLocationCommand` will take, and everything it
/// will clear.
@immutable
final class LocationRemovalPlan {
  const LocationRemovalPlan({
    required this.locationId,
    required this.locationIds,
    required this.references,
  });

  /// The empty plan for a location this document does not have.
  ///
  /// A reachable and normal state — a stale selection, a second delete
  /// arriving after an undo — and not an error.
  static const LocationRemovalPlan none = LocationRemovalPlan(
    locationId: Uuid(''),
    locationIds: <Uuid>[],
    references: <LocationRef>[],
  );

  /// The node the user asked to delete.
  final Uuid locationId;

  /// [locationId] and every descendant, in pre-order (DR-021 §11.20.1).
  final List<Uuid> locationIds;

  /// Every field pointing into [locationIds], in a deterministic order.
  final List<LocationRef> references;

  /// THE FIRST NUMBER THE DIALOG SAYS. Includes the node itself, because
  /// "delete Level 1 and 4 locations under it" and "delete 5 locations"
  /// are different sentences and the second is the one that surprises
  /// nobody afterwards.
  int get locationCount => locationIds.length;

  /// THE SECOND NUMBER. Distinct ENTITIES, not references: four
  /// conductors of one home run landing in one room is one cable to the
  /// person reading this. See the file header.
  int get referenceCount => references.map((r) => r.entityId).toSet().length;

  /// Whether this delete destroys anything the user cannot see from the
  /// location itself, and therefore whether DR-021 §11.20.3 wants a dialog
  /// at all.
  ///
  /// A LEAF WITH NOTHING POINTING AT IT IS DELETED WITH NO PROMPT, which
  /// is DR-013 §11.13.2's *"a device carrying nothing is deleted with no
  /// prompt at all"* applied to the same shape of question. A confirmation
  /// on every delete trains people to dismiss confirmations.
  bool get needsConfirmation => locationIds.length > 1 || references.isNotEmpty;

  bool get isEmpty => locationIds.isEmpty;
}

/// What removing [locationId] would take with it, and what it would clear.
///
/// Returns [LocationRemovalPlan.none] when the document has no such
/// location.
LocationRemovalPlan planLocationRemoval(RackDocument doc, Uuid locationId) {
  if (!doc.locations.containsKey(locationId)) return LocationRemovalPlan.none;

  // Through the DERIVED tree, so a subtree here and a subtree in the panel
  // are the same walk. It is also already total against a document holding
  // a cycle, which a walk written here would have to re-earn.
  final subtree = LocationTree.of(doc).subtreeOf(locationId);
  final going = subtree.toSet();

  final refs = <LocationRef>[];

  // ENTITY ORDER, then a fixed order within an entity. `references` feeds
  // an undo that restores in reverse, so a stable order is what makes
  // delete/undo/redo land on identical bytes rather than merely equivalent
  // ones (CR-117).
  for (final entry in doc.racks.entries) {
    final id = entry.value.locationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.rack,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
  }

  for (final entry in doc.devices.entries) {
    final device = entry.value;
    final id = device.locationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.device,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
    // A SECOND REFERENCE ON THE SAME DEVICE, and both are real: a device
    // carries `locationId` and its `OffRackPlacement` carries one too, and
    // `AddStructureCommand` writes the same value into both. Clearing one
    // and not the other would leave the document disagreeing with itself
    // about a room that no longer exists.
    final placement = device.placement;
    if (placement is OffRackPlacement) {
      final placed = placement.locationId;
      if (placed != null && going.contains(placed)) {
        refs.add(
          LocationRef(
            kind: LocationRefKind.devicePlacement,
            entityId: entry.key,
            locationId: placed,
          ),
        );
      }
    }
  }

  for (final entry in doc.outlets.entries) {
    final id = entry.value.locationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.outlet,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
  }

  for (final entry in doc.structures.entries) {
    final id = entry.value.distributionDeviceLocationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.structureBody,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
  }

  for (final entry in doc.circuits.entries) {
    final id = entry.value.locationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.circuit,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
  }

  for (final entry in doc.pathways.entries) {
    final pathway = entry.value;
    final from = pathway.fromLocationId;
    if (from != null && going.contains(from)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.pathwayFrom,
          entityId: entry.key,
          locationId: from,
        ),
      );
    }
    final to = pathway.toLocationId;
    if (to != null && going.contains(to)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.pathwayTo,
          entityId: entry.key,
          locationId: to,
        ),
      );
    }
  }

  for (final entry in doc.links.entries) {
    final conductors = entry.value.conductors;
    for (var i = 0; i < conductors.length; i++) {
      for (final isFrom in const [true, false]) {
        final end = isFrom ? conductors[i].from : conductors[i].to;
        if (end is! PlaceEndpoint) continue;
        final id = end.locationId;
        if (id == null || !going.contains(id)) continue;
        refs.add(
          LocationRef(
            kind: LocationRefKind.placeEndpoint,
            entityId: entry.key,
            locationId: id,
            conductorIndex: i,
            isFromEnd: isFrom,
          ),
        );
      }
    }
  }

  // LAST, so every reference the nine before it produced keeps its place
  // in this list and a plan built before DR-185 is unchanged by it.
  for (final entry in doc.underlays.entries) {
    final id = entry.value.locationId;
    if (id != null && going.contains(id)) {
      refs.add(
        LocationRef(
          kind: LocationRefKind.underlay,
          entityId: entry.key,
          locationId: id,
        ),
      );
    }
  }

  return LocationRemovalPlan(
    locationId: locationId,
    locationIds: List<Uuid>.unmodifiable(subtree),
    references: List<LocationRef>.unmodifiable(refs),
  );
}
