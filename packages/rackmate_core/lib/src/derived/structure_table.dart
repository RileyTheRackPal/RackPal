// THE STRUCTURE EDITOR'S TABLE, as a row model. Board M3-C/2 (#148),
// docs/07 §4 and §4.1, AC-048.
//
// ═════════════════════════════════════════════════════════════════════
// IT IS A PROJECTION OF `buildSchedule`, AND THAT IS THE WHOLE DESIGN
// ═════════════════════════════════════════════════════════════════════
// docs/07 §4.1's eight default columns are FIELD LABEL, RACK LBL, OUTLET,
// MEDIA, SERVICE, PATHWAY, RACK TERM and ROUGH-IN. Every one of them is
// already on `ScheduleEntry`, resolved, with its registry lookups done
// and its unknowns counted. So this file filters and regroups; it does
// not re-derive.
//
// A SECOND DERIVATION IS THE FAILURE CR-107 IS ABOUT. That ruling deleted
// `StructureDrop` because two entities carrying media, length, status and
// test result "is guaranteed [to diverge] within one week of real use:
// the drop schedule says 78 ft and the wiring schedule says 90 ft, and
// nobody knows which to bill against." A table that computed its own
// media name and its own termination would be the same divergence one
// layer up, and the editor is the surface people trust MOST because they
// are typing into it.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IT ADDS THAT THE SHEET DOES NOT HAVE
// ═════════════════════════════════════════════════════════════════════
//  * THE ROOM ORDER IS THE TREE'S, not the sheet's sort. docs/07 §4 draws
//    the table beside the location tree, and a room that sits third in
//    the tree must sit third here or the two panels disagree in front of
//    the person using them. `scheduleViewOf`'s grouping sorts bands by
//    footage or by name, which is right for a sheet nobody is editing.
//  * THE COUNTS THE STATUS BAR PRINTS: `52 drops · 41 connected · 11
//    spare · 9 outlets · 8 pathways`, and the same three per room.
//  * NO PRESET AND NO FILTER. `buildSchedule` is total, one row per
//    `Link`; this keeps every drop on the body, including the ones a
//    Pull Sheet preset would drop. An editor that hid rows would let a
//    person delete a room's last drop and see nothing change.
//
// ═════════════════════════════════════════════════════════════════════
// NO EDITING HERE
// ═════════════════════════════════════════════════════════════════════
// Which `EntityField` a cell writes through, and what a refusal reads
// like, belong with the surface. This answers "what does the table show",
// and it answers it against an unmutated document so a widget can rebuild
// it on every frame.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/location_tree.dart';
import 'package:rackmate_core/src/derived/schedule.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// One room's worth of drops, in the location tree's own order.
@immutable
final class StructureTableGroup {
  const StructureTableGroup({
    required this.locationId,
    required this.title,
    required this.code,
    required this.rows,
    required this.connectedCount,
    required this.spareCount,
    required this.estimatedRunLength,
  });

  /// Null for the trailing band, which has no room.
  final Uuid? locationId;

  /// The room's name, or [kUngroupedTitle] for the trailing band.
  final String title;

  /// `LR`. Empty when the room has no code, which is a real state: a room
  /// created by hand is being named and not labelled (M3-B), and the drop
  /// line refuses to label its drops until somebody fills this in.
  final String code;

  final List<ScheduleEntry> rows;

  /// How many of [rows] land on a real port. See [StructureTable].
  final int connectedCount;

  /// How many are deliberately not landed. COUNTED, not subtracted, for
  /// the reason [StructureTable.hasUnresolvedEnds] gives.
  final int spareCount;

  /// `Location.estimatedRunLengthFromRack`. NULL IS UNKNOWN and prints as
  /// such (G4, CR-114); it is never a zero and never a sum of the drops.
  final Len? estimatedRunLength;

  int get dropCount => rows.length;
}

/// What the Structure editor's table tab shows.
@immutable
final class StructureTable {
  const StructureTable({
    required this.groups,
    required this.dropCount,
    required this.connectedCount,
    required this.spareCount,
    required this.outletCount,
    required this.pathwayCount,
  });

  /// Rooms in the location tree's order, then the trailing band for drops
  /// with no room. A room with no drops is NOT here: the tree beside the
  /// table is what lists every room, and an empty band per room would
  /// push the drops off the screen in a project with forty of them.
  final List<StructureTableGroup> groups;

  final int dropCount;

  /// A drop is CONNECTED when its rack end resolves to a real port on a
  /// device this document holds — `rackPort` or `unrackedPort`. It is
  /// SPARE otherwise, which covers the coil in a J-hook (`open`), the
  /// described place nobody has landed (`place`) and the drop with no
  /// second end at all (`none`).
  ///
  /// `unresolvedPort` COUNTS AS NEITHER, and that is deliberate: a
  /// `PortEndpoint` naming a port this document does not hold is a fault,
  /// not a state, and counting it as connected would report work that
  /// cannot be traced while counting it as spare would invite somebody to
  /// land a second cable on the same panel port. It is in [dropCount] and
  /// in neither of the other two, so the status bar's own arithmetic
  /// exposes it: `drops` stops equalling `connected + spare`.
  final int connectedCount;

  /// COUNTED FROM THE ENDS, NEVER `dropCount - connectedCount`. The
  /// subtraction is the bug this field exists to avoid: it makes
  /// [hasUnresolvedEnds] arithmetically impossible to trip, so a
  /// `PortEndpoint` naming a port nobody holds would be silently reported
  /// as a spare drop. The first version of this class did exactly that
  /// and its own test caught it.
  final int spareCount;

  /// Outlets with at least one drop on this body. NOT `doc.outlets.length`
  /// — an outlet the user created and has not pulled anything to yet is
  /// real, but it is not what "9 outlets" means beside "52 drops".
  final int outletCount;

  /// Distinct pathways named by these drops, on the same rule.
  final int pathwayCount;

  /// True when a `PortEndpoint` names something this document does not
  /// hold, so [connectedCount] and [spareCount] do not add up. The status
  /// bar says so rather than hiding it (G4: every rollup reports what it
  /// could not resolve).
  bool get hasUnresolvedEnds => connectedCount + spareCount != dropCount;
}

/// Builds the table for [structureBodyId], or for every Structure body
/// when it is null.
///
/// PURE, and cheap enough to call on every rebuild: it is one pass over
/// `buildSchedule`'s rows plus one tree walk.
StructureTable buildStructureTable(
  RackDocument doc, {
  Uuid? structureBodyId,
}) {
  final rows = <ScheduleEntry>[];
  for (final row in buildSchedule(doc).rows) {
    final origin = doc.links[row.linkId]?.structureOrigin;
    if (origin == null) continue;
    if (structureBodyId != null && origin.structureBodyId != structureBodyId) {
      continue;
    }
    rows.add(row);
  }

  // Grouped by the room the FIELD end names. `ScheduleEntry.roomId` is
  // already oriented (§3.2 reads a row `FROM — ROOM` then `TO — RACK`),
  // so this does not have to re-decide which end is the wall.
  final byRoom = <Uuid, List<ScheduleEntry>>{};
  final unplaced = <ScheduleEntry>[];
  for (final row in rows) {
    if (row.roomId case final id?) {
      (byRoom[id] ??= []).add(row);
    } else {
      unplaced.add(row);
    }
  }

  final groups = <StructureTableGroup>[];
  for (final id in _roomsInTreeOrder(doc)) {
    final inRoom = byRoom[id];
    if (inRoom == null) continue;
    final location = doc.locations[id];
    groups.add(
      StructureTableGroup(
        locationId: id,
        title: location?.name.trim().isNotEmpty ?? false
            ? location!.name.trim()
            : kUnnamedLocation,
        code: location?.code.trim() ?? '',
        rows: inRoom,
        connectedCount: inRoom.where(_isConnected).length,
        spareCount: inRoom.where(_isSpare).length,
        estimatedRunLength: location?.estimatedRunLengthFromRack,
      ),
    );
  }

  // A DROP WHOSE ROOM IS GONE STILL HAS A BAND. DR-021 clears a deleted
  // location's references to null rather than deleting the drops, and its
  // own §11.20 text names this band as where they land: "so a cleared
  // drop lands in the Pull Sheet's `NO ROOM RECORDED` band instead of
  // vanishing." The editor owes the same, more so, because this is the
  // surface somebody would use to put them back.
  if (unplaced.isNotEmpty) {
    groups.add(
      StructureTableGroup(
        locationId: null,
        title: kUngroupedTitle,
        code: '',
        rows: unplaced,
        connectedCount: unplaced.where(_isConnected).length,
        spareCount: unplaced.where(_isSpare).length,
        estimatedRunLength: null,
      ),
    );
  }

  return StructureTable(
    groups: groups,
    dropCount: rows.length,
    connectedCount: rows.where(_isConnected).length,
    spareCount: rows.where(_isSpare).length,
    outletCount: {
      for (final row in rows)
        if (doc.links[row.linkId]?.structureOrigin case final o?) o.outletId,
    }.length,
    pathwayCount: {
      for (final row in rows)
        if (row.pathwayId case final id?) id,
    }.length,
  );
}

bool _isConnected(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => true,
  _ => false,
};

/// Deliberately not landed: a coil in a J-hook, a described place, or no
/// second end at all. `unresolvedPort` is NEITHER this nor connected.
bool _isSpare(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.unresolvedPort => false,
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => false,
  _ => true,
};

/// Every location id, parents before children, siblings in `order`.
///
/// THE TREE'S ORDER AND NOT `doc.locations`'. A `Map`'s iteration order is
/// insertion order, which is the order rooms were CREATED; the panel next
/// to this table draws them sorted, and two panels disagreeing about
/// which room is third is the kind of defect nobody reports and everybody
/// distrusts.
List<Uuid> _roomsInTreeOrder(RackDocument doc) {
  final tree = LocationTree.of(doc);
  final out = <Uuid>[];
  void walk(Uuid id) {
    out.add(id);
    for (final child in tree.childrenOf(id)) {
      walk(child);
    }
  }

  for (final root in tree.roots) {
    walk(root);
  }
  return out;
}
