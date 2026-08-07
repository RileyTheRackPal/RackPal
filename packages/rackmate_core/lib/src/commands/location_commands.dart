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
import 'package:rackmate_core/src/derived/location_tree.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/location.dart';
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
