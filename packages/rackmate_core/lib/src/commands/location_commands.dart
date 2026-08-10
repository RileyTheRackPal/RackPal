// rackmate_core/src/commands/location_commands.dart — pure Dart.
//
// The commands that let the location tree be BUILT: create a node, move a
// node. Board M3-B/1, CR-047, CR-112, DR-021.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT WAS ALREADY THERE, AND WHAT WAS NOT
// ─────────────────────────────────────────────────────────────────────────
// `Location` has been modelled, persisted and byte-round-tripped since M0,
// exactly like `Outlet` and `StructureBody` before M3-A/1. The one thing
// that could produce a `Location` was `rack_canvas_screen.dart`'s three
// hard-coded demo rooms, whose own comment says they are "seeded rather
// than creatable". Board #143 deletes them once the panel can create one,
// and it is sequenced AFTER the panel for exactly that reason: deleting the
// demo three first would leave the dropdown empty again.
//
// ─────────────────────────────────────────────────────────────────────────
// THE RENAME IS NOT HERE, AND THAT IS THE POINT
// ─────────────────────────────────────────────────────────────────────────
// M3-B/1 asks for "add, rename, reparent, delete". Only three of the four
// are in this file. `name`, `code`, `kind`, `floorNumber`, `spaceCode` and
// `estimatedRunLengthFromRack` are ordinary field writes and go through
// `LocationField` on the ONE accessor-table mechanism (#578), so a rename
// costs a table row rather than a fifth command class.
//
// `parentId` is the one field that could not: DR-021 §11.20.5 makes a
// reparent REFUSE a cycle, and a table `set` writes and returns with no way
// to refuse. `StructureOrigin`'s two label fields were excluded from their
// table on the identical ground one task earlier.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY A CYCLE IS REFUSED WHEN DR-013 SAYS ORDINARY EDITS ARE NOT
// ─────────────────────────────────────────────────────────────────────────
// DR-013 §11.13.3 reserves refusal for the five tier-1 topology rules,
// whose escape docs/02 §5 gives as "None. There is nothing to escape to."
// DR-021 §11.20.5 puts a cycle in that class and says why: a cycle is not a
// design the user disagrees with, it is a tree that is not a tree. Every
// derivation over it — roots, the path to a node, the breadcrumb, the Pull
// Sheet's own room order — has no answer rather than a debatable one.
//
// The refusal carries a SENTENCE NAMING BOTH NODES, the discipline
// `connect_rules.dart` holds for all five topology rules: "TOP-003" alone
// is a log line, and a user told only that a move is impossible goes
// looking in the wrong place for why.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/derived/location_removal.dart';
import 'package:rackmate_core/src/derived/location_tree.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The `FracIndex` a new [Location] should sort at, after its siblings.
///
/// PER SIBLING GROUP, not per document, which is where this differs from
/// `nextOutletOrder`. Locations are a tree and `order` sorts siblings
/// against each other; allocating against every location in the project
/// would leave a new room under one parent carrying an index derived from
/// an unrelated branch. Harmless to the sort, but it makes the numbers
/// meaningless to read and to hand-edit.
FracIndex nextLocationOrder(RackDocument doc, {Uuid? parentId}) => nextOrder(
  doc.locations.values.where((l) => l.parentId == parentId).map((l) => l.order),
);

/// A short code for a room called [name], unique within [doc].
///
/// **docs/07 §5.3.1 ASKS FOR THIS AND NOTHING PROVIDED IT.** The section
/// says an unmatched room "offers 'create room' inline, pre-filled with
/// a derived `code`", and no derivation existed anywhere in the
/// repository: every room created so far was given a code by hand.
/// M3-F/6 needs it because a CSV import creates rooms in bulk, where
/// "by hand" is not available.
///
/// **INITIALS FOR A MULTI-WORD NAME, FIRST TWO LETTERS OTHERWISE.**
/// `Living Room` becomes `LR`, which is the spelling the corpus uses in
/// every worked example, and `Attic` becomes `AT`. Both cap at three
/// characters, because the code prints in the Pull Sheet's room column
/// and in `{ROOM_ABBR}` on a label somebody reads off a wall plate.
///
/// **A COLLISION TAKES A DIGIT RATHER THAN THE OTHER ROOM'S CODE.** Two
/// rooms with one code is the defect `rackLabel`'s uniqueness rule
/// exists to prevent one field over, and on a Pull Sheet it merges two
/// rooms' subtotals. `LR`, then `LR2`, then `LR3`.
///
/// [alsoUsed] carries codes a CALLER has already allocated against this
/// same unmutated document, which a bulk create needs and a single one
/// does not: a CSV import creating `Living Room` and `Laundry Room` in
/// one transaction derives `LR` for both, because neither is in [doc]
/// yet. Same shape and same reason as `buildAddHomeRunCommand`'s
/// `alsoUsedLabels`.
///
/// A SUGGESTION AND NOT A DECISION: the surface shows it in an editable
/// box. Nothing here is authoritative about what a room is called.
String deriveLocationCode(
  RackDocument doc,
  String name, {
  Set<String> alsoUsed = const {},
}) {
  final words = name
      .trim()
      .split(RegExp(r'[\s_/-]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final letters = words
      .map((w) => w.replaceAll(RegExp('[^A-Za-z0-9]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();

  var base = switch (letters.length) {
    0 => 'RM',
    1 =>
      letters.single.length >= 2
          ? letters.single.substring(0, 2)
          : letters.single,
    _ => letters.take(3).map((w) => w[0]).join(),
  }.toUpperCase();
  if (base.isEmpty) base = 'RM';

  final taken = {
    for (final l in doc.locations.values) l.code.trim().toUpperCase(),
    for (final c in alsoUsed) c.trim().toUpperCase(),
  };
  if (!taken.contains(base)) return base;
  var n = 2;
  while (taken.contains('$base$n')) {
    n++;
  }
  return '$base$n';
}

/// Creates one [Location].
final class AddLocationCommand extends Command {
  AddLocationCommand({
    required this.name,
    required this.code,
    required this.order,
    required this.now,
    required this.actor,
    this.kind = LocationKind.room,
    this.parentId,
    this.floorNumber,
    this.spaceCode,
    this.estimatedRunLengthFromRack,
    Uuid? id,
  }) : id = id ?? newEntityId();

  /// Minted in the CONSTRUCTOR, never in [apply] — the `Command` contract,
  /// so redo recreates the identical node and anything stacked on it (a
  /// child location, a rack's `locationId`) still resolves.
  final Uuid id;

  /// "Master Bedroom".
  final String name;

  /// "MBR" — the ONE abbreviation field (CR-046).
  final String code;

  /// Allocated caller-side through [nextLocationOrder], for the reason
  /// every other creating command allocates its order caller-side:
  /// recomputing it inside `apply` would drift under redo.
  final FracIndex order;

  /// Defaults to `room` because that is what a user creating a location
  /// almost always means, and because CR-047 makes the choice cosmetic:
  /// `kind` filters the device builder's four-level VIEW and carries no
  /// containment, so a wrong default costs a dropdown change rather than a
  /// misplaced node.
  final LocationKind kind;

  /// Null makes this a root. NOT VALIDATED HERE: a create cannot make a
  /// cycle, because nothing can already be below a node that does not
  /// exist yet. `buildReparentLocation` is where the tree can be broken
  /// and therefore where it is guarded.
  final Uuid? parentId;

  final int? floorNumber;
  final String? spaceCode;

  /// AC-024's one number per room. STAYS NULLABLE through this command:
  /// a user who has not paced the run passes null and the rollup counts it
  /// unknown. Defaulting it to zero here would fabricate a measurement at
  /// the exact point the user is saying they have none (G4, CR-114).
  final Len? estimatedRunLengthFromRack;

  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addLocation;

  /// `structure` because a location is where things are, `meta` because
  /// its name and code print on every schedule row and PDF callout that
  /// cites the room.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.locations[id] = Location(
      id: id,
      kind: kind,
      name: name,
      code: code,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      parentId: parentId,
      floorNumber: floorNumber,
      spaceCode: spaceCode,
      estimatedRunLengthFromRack: estimatedRunLengthFromRack,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.locations.remove(id);
  }
}

/// Moves one [Location] to a new parent, or to the top level.
///
/// Built through [buildReparentLocation], which is the only thing that
/// checks DR-021 §11.20.5's cycle rule. Constructing this class directly
/// bypasses that check, which is why the builder exists and why the panel
/// calls it.
final class ReparentLocationCommand extends Command {
  ReparentLocationCommand({
    required this.id,
    required this.from,
    required this.to,
    required this.now,
    required this.actor,
  });

  final Uuid id;

  /// The previous parent, captured by the BUILDER from the live document
  /// rather than read inside [apply]. `revert` restores this value, so a
  /// command constructed with the wrong `from` puts the node back in the
  /// wrong place, which is the failure mode the builder's existence
  /// prevents.
  final Uuid? from;
  final Uuid? to;
  final DateTime now;
  final String actor;

  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.reparentLocation;

  /// `structure` because moving a node moves everything under it, `meta`
  /// because every breadcrumb below the move is now a different string.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  /// NO `mergeKey`. Field edits coalesce so that typing in a name box is
  /// one undo entry; two consecutive moves of one branch are two acts a
  /// user can want to unpick separately, and merging them would offer one
  /// "undo move" that jumped a subtree two levels.
  @override
  void apply(RackDocument doc) {
    final location = _resolve(doc);
    final meta = location.meta;
    _prevUpdatedAt = meta.updatedAt;
    _prevUpdatedBy = meta.updatedBy;
    _prevLocalRevision = meta.localRevision;
    location.parentId = to;
    meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('ReparentLocationCommand.revert called before apply().');
    }
    final location = _resolve(doc);
    final meta = location.meta;
    location.parentId = from;
    // `restoreTo`, not a second `touch` — `MoveDeviceCommand` gives the
    // argument at length: a revision left one higher than it started is
    // exactly what breaks CR-117's byte round trip.
    meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  Location _resolve(RackDocument doc) {
    final location = doc.locations[id];
    if (location == null) {
      throw StateError(
        'ReparentLocationCommand: no location "${id.v}" in this document.',
      );
    }
    return location;
  }
}

/// The outcome of [buildReparentLocation].
sealed class ReparentLocationResult {
  const ReparentLocationResult();
}

final class ReparentLocationReady extends ReparentLocationResult {
  const ReparentLocationReady(this.command);
  final ReparentLocationCommand command;
}

/// The node is already where the caller asked to put it.
///
/// A THIRD outcome rather than a null, because docs/04 §3.4's "never
/// silently do nothing" needs the caller to tell "there was nothing to do"
/// apart from "it was refused" — the first says nothing to the user and the
/// second must say a sentence.
final class ReparentLocationUnchanged extends ReparentLocationResult {
  const ReparentLocationUnchanged();
}

final class ReparentLocationRefused extends ReparentLocationResult {
  const ReparentLocationRefused(this.reason);
  final String reason;
}

/// Builds the command that moves [id] under [newParentId], refusing a
/// cycle with a sentence that names both nodes (DR-021 §11.20.5).
///
/// [newParentId] null moves the node to the top level, which is always
/// legal: a root has no ancestors to loop through.
ReparentLocationResult buildReparentLocation({
  required RackDocument doc,
  required Uuid id,
  required Uuid? newParentId,
  required DateTime now,
  required String actor,
}) {
  final location = doc.locations[id];
  if (location == null) {
    return const ReparentLocationRefused(
      'That location is not in this project.',
    );
  }
  if (newParentId != null && !doc.locations.containsKey(newParentId)) {
    return const ReparentLocationRefused(
      'The location you are moving it under is not in this project.',
    );
  }
  if (location.parentId == newParentId) {
    return const ReparentLocationUnchanged();
  }

  if (newParentId != null) {
    // Asked of the DERIVED tree, not of a walk written here. That tree is
    // total against a document that already contains a cycle, and a second
    // walk would be a second answer to drift from the panel's.
    final tree = LocationTree.of(doc);
    if (tree.wouldCycle(id, newParentId)) {
      final target = doc.locations[newParentId];
      return ReparentLocationRefused(
        newParentId == id
            ? '${_nameOf(location)} cannot be moved inside itself.'
            : '${_nameOf(location)} cannot be moved inside '
                  '${_nameOf(target)}, which is already inside it.',
      );
    }
  }

  return ReparentLocationReady(
    ReparentLocationCommand(
      id: id,
      from: location.parentId,
      to: newParentId,
      now: now,
      actor: actor,
    ),
  );
}

/// The name to put in a refusal sentence.
///
/// Falls back to [kUnnamedLocation] rather than to an empty string, so a
/// refusal about a room the user has not named yet still reads as a
/// sentence instead of losing a word in the middle of one.
String _nameOf(Location? location) {
  final name = location?.name.trim() ?? '';
  return name.isEmpty ? kUnnamedLocation : name;
}

// ═════════════════════════════════════════════════════════════════════
// THE DELETE (DR-021 §11.20.1, §11.20.2, §11.20.4)
// ═════════════════════════════════════════════════════════════════════
// Takes a SUBTREE and clears every reference into it, in one undoable
// command, consuming the plan `planLocationRemoval` already computed
// rather than deriving its own. `device_removal.dart` states the reason
// and it is the whole point of the split: a dialog that said "4 rooms" and
// removed five is worse than no dialog.
//
// NO CONFIRMATION LIVES HERE. Core has no dialogs; the plan is what the
// panel puts in one (M3-B/2, board #145).
//
// UNDO RESTORES OBJECTS, NOT EQUAL VALUES, and DR-021 §11.20.4 says this
// reaches one step further than DR-013 had to. Everything DR-013 removed
// was a whole entity it could hand back. Two of the nine carriers here are
// IMMUTABLE (`OffRackPlacement` inside a device's placement, `PlaceEndpoint`
// inside a conductor of a link), so clearing them CONSTRUCTS replacements,
// and revert has to put the originals back rather than rebuild equal ones.
// `location_removal_test`'s byte case is what holds that.

/// Removes a location, its whole subtree, and every reference into it.
final class RemoveLocationCommand extends Command {
  RemoveLocationCommand({required this.plan});

  /// Computed by `planLocationRemoval` BEFORE anything moved, and the same
  /// object the confirmation was built from.
  final LocationRemovalPlan plan;

  /// The SAME objects, not equivalent ones, so undo is not a lossy round
  /// trip through the entities CR-117's byte gate is about. The discipline
  /// `RemoveDeviceCommand` already holds.
  final List<Location> _removed = [];

  /// One entry per cleared reference, in `plan.references` order. Carries
  /// what was there, including the whole immutable object for the two
  /// carriers that have one.
  final List<_ClearedRef> _cleared = [];
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeLocation;

  /// `structure` because rooms and the things that sit in them move,
  /// `meta` because every breadcrumb and every schedule row citing one of
  /// these rooms now reads differently, and `wires` because a `Link`'s
  /// `PlaceEndpoint` is one of the nine carriers and the schedule prints
  /// it.
  @override
  EpochMask get touches =>
      EpochMask.structure | EpochMask.meta | EpochMask.wires;

  /// The locations AND the entities that lose a field. A consumer watching
  /// one rack wants to know that rack just lost its room.
  @override
  Iterable<Uuid> get affects => [
    ...plan.locationIds,
    for (final ref in plan.references) ref.entityId,
  ];

  @override
  void apply(RackDocument doc) {
    // CLEARED, not accumulated: `apply` runs again on every redo and each
    // run must describe THAT run. `RemoveStructureCommand` carries the
    // same note for the same reason.
    _removed.clear();
    _cleared.clear();

    // References first, then the locations. Either order leaves the same
    // document, but this one means every ref is read while the node it
    // names is still present, so a `plan` built against a different
    // document fails loudly here rather than silently clearing nothing.
    for (final ref in plan.references) {
      final cleared = _clear(doc, ref);
      if (cleared != null) _cleared.add(cleared);
    }
    for (final id in plan.locationIds) {
      final location = doc.locations.remove(id);
      if (location != null) _removed.add(location);
    }
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveLocationCommand.revert before apply');
    }
    for (final location in _removed) {
      doc.locations[location.id] = location;
    }
    // REVERSE ORDER, so two references into one entity unwind in the
    // order they were taken. Only `Pathway` and a multi-conductor `Link`
    // can produce two today, and both are position-independent; the order
    // is held anyway because the cheap discipline is the one that survives
    // a tenth carrier being added.
    for (final cleared in _cleared.reversed) {
      cleared.restore(doc);
    }
  }

  /// Clears one reference, returning what it took, or null when the
  /// entity is not in the document.
  ///
  /// A missing entity is NOT an error here. A plan is a snapshot of a
  /// question, and a command replayed onto a document where that rack was
  /// itself deleted has nothing to clear and nothing to restore, which is
  /// the same "already gone" outcome `RemoveStructureCommand` treats as
  /// legal.
  _ClearedRef? _clear(RackDocument doc, LocationRef ref) {
    switch (ref.kind) {
      case LocationRefKind.rack:
        final rack = doc.racks[ref.entityId];
        if (rack == null) return null;
        rack.locationId = null;
        return _ClearedRef(
          ref,
          (d) => d.racks[ref.entityId]?.locationId = ref.locationId,
        );

      case LocationRefKind.device:
        final device = doc.devices[ref.entityId];
        if (device == null) return null;
        device.locationId = null;
        return _ClearedRef(
          ref,
          (d) => d.devices[ref.entityId]?.locationId = ref.locationId,
        );

      case LocationRefKind.devicePlacement:
        final device = doc.devices[ref.entityId];
        final placement = device?.placement;
        if (device == null || placement is! OffRackPlacement) return null;
        device.placement = OffRackPlacement(
          mountNote: placement.mountNote,
          unknown: placement.unknown,
        );
        // The ORIGINAL object, not a rebuild of it (DR-021 §11.20.4).
        return _ClearedRef(
          ref,
          (d) => d.devices[ref.entityId]?.placement = placement,
        );

      case LocationRefKind.outlet:
        final outlet = doc.outlets[ref.entityId];
        if (outlet == null) return null;
        outlet.locationId = null;
        return _ClearedRef(
          ref,
          (d) => d.outlets[ref.entityId]?.locationId = ref.locationId,
        );

      case LocationRefKind.structureBody:
        final body = doc.structures[ref.entityId];
        if (body == null) return null;
        body.distributionDeviceLocationId = null;
        return _ClearedRef(
          ref,
          (d) => d.structures[ref.entityId]?.distributionDeviceLocationId =
              ref.locationId,
        );

      case LocationRefKind.circuit:
        final circuit = doc.circuits[ref.entityId];
        if (circuit == null) return null;
        circuit.locationId = null;
        return _ClearedRef(
          ref,
          (d) => d.circuits[ref.entityId]?.locationId = ref.locationId,
        );

      case LocationRefKind.pathwayFrom:
        final pathway = doc.pathways[ref.entityId];
        if (pathway == null) return null;
        pathway.fromLocationId = null;
        return _ClearedRef(
          ref,
          (d) => d.pathways[ref.entityId]?.fromLocationId = ref.locationId,
        );

      case LocationRefKind.pathwayTo:
        final pathway = doc.pathways[ref.entityId];
        if (pathway == null) return null;
        pathway.toLocationId = null;
        return _ClearedRef(
          ref,
          (d) => d.pathways[ref.entityId]?.toLocationId = ref.locationId,
        );

      case LocationRefKind.placeEndpoint:
        final link = doc.links[ref.entityId];
        final index = ref.conductorIndex!;
        if (link == null || index >= link.conductors.length) return null;
        final conductor = link.conductors[index];
        final isFrom = ref.isFromEnd!;
        final end = isFrom ? conductor.from : conductor.to;
        if (end is! PlaceEndpoint) return null;
        link.conductors[index] = _withEnd(
          conductor,
          isFrom: isFrom,
          end: PlaceEndpoint(
            description: end.description,
            intendedTermination: end.intendedTermination,
            serviceLoop: end.serviceLoop,
          ),
        );
        // The ORIGINAL conductor, so revert restores the object the file
        // was written from rather than one that merely compares equal.
        return _ClearedRef(ref, (d) {
          final live = d.links[ref.entityId];
          if (live != null && index < live.conductors.length) {
            live.conductors[index] = conductor;
          }
        });
    }
  }
}

/// A `Conductor` with one end replaced. `Conductor` is immutable, so this
/// is the only way to change one.
Conductor _withEnd(
  Conductor conductor, {
  required bool isFrom,
  required Endpoint end,
}) => Conductor(
  from: isFrom ? end : conductor.from,
  to: isFrom ? conductor.to : end,
  role: conductor.role,
  pairNumber: conductor.pairNumber,
  colorCode: conductor.colorCode,
);

/// What one cleared reference needs in order to be put back.
final class _ClearedRef {
  const _ClearedRef(this.ref, this.restore);
  final LocationRef ref;
  final void Function(RackDocument doc) restore;
}

/// Builds the delete for [locationId], or null when the document does not
/// hold it.
///
/// The plan is returned ON the command (`command.plan`) rather than
/// separately, because the confirmation the panel shows and the edit it
/// then runs must be the same object. Two calls to `planLocationRemoval`
/// around a dialog is the drift DR-021 §11.20.3 forbids.
RemoveLocationCommand? buildRemoveLocation({
  required RackDocument doc,
  required Uuid locationId,
}) {
  final plan = planLocationRemoval(doc, locationId);
  if (plan.isEmpty) return null;
  return RemoveLocationCommand(plan: plan);
}
