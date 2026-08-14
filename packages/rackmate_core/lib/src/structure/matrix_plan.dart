// ONE MATRIX CELL, CHANGED. Board M3-C/3 (#149), docs/07 §4.2.
//
// §4.2 in one sentence: "Changing a cell from 0 to 2 materialises two
// `Link`s with generated labels in one command; decrementing it deletes
// the two highest-sequence unconnected drops in that cell and refuses
// (with a spring-back chip, CR-017) to delete a connected one."
//
// ═════════════════════════════════════════════════════════════════════
// A CELL IS A TARGET, NOT A DELTA, AND THE DIFFERENCE MATTERS
// ═════════════════════════════════════════════════════════════════════
// The surface hands over the number a person typed and this works out
// what that means against the CURRENT document. A `+1` computed by the
// widget would be `+1` against whatever it last rendered, and the thing
// a grid of sixty cells does most is go stale: an undo, a typed line, a
// second window. Reading the count back off `buildStructureTable` — the
// same list the deletion then takes from — is what makes the number a
// person saw and the rows that go the same list.
//
// ═════════════════════════════════════════════════════════════════════
// AN INCREMENT CREATES A PLATE, EXACTLY AS THE TYPED LINE DOES
// ═════════════════════════════════════════════════════════════════════
// `Living Room: 2x Cat6` creates an `Outlet` and hangs two drops on it,
// and so does this. THE MATRIX DOES NOT KNOW ABOUT PLATES: a cell is a
// room and a cable, and a real plate is mixed media (§4's `WP-1` carries
// Cat6 and RG6), so no cell can correspond to one. The tempting rule —
// join the room's first outlet — is worse than it looks, because it puts
// speaker cable on a TV plate somebody else created.
//
// So the count of plates a matrix session leaves behind is one per
// gesture, and §4.2's own `Outlets` column is where that is VISIBLE
// rather than hidden. `planOutletFromTemplate` states the same rule from
// the other side: it "creates an outlet and never joins one".
//
// ═════════════════════════════════════════════════════════════════════
// A DECREMENT NEVER TAKES THE OUTLET WITH IT
// ═════════════════════════════════════════════════════════════════════
// A plate with no drops on it is a real state — somebody planned a
// location and has not pulled to it yet — and it is what
// `AddOutletCommand` alone produces. Deleting one because the last drop
// left would destroy an entity another gesture may have created
// deliberately, so the emptied plate stays and keeps showing in the
// `Outlets` column.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/home_run_commands.dart'
    show usedFieldLabels;
import 'package:rackmate_core/src/commands/link_commands.dart';
import 'package:rackmate_core/src/commands/pathway_commands.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/commands/structure_commands.dart';
import 'package:rackmate_core/src/derived/link_lookup.dart';
import 'package:rackmate_core/src/derived/schedule.dart';
import 'package:rackmate_core/src/derived/structure_matrix.dart'
    show structureMatrixColumnHeader;
import 'package:rackmate_core/src/derived/structure_table.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/pathway.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/structure/drop_build.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// The outcome of [planMatrixCell].
sealed class MatrixCellPlan {
  const MatrixCellPlan();
}

/// The cell already says that. NOT a refusal and not an empty Ready:
/// tabbing across a row of sixty cells commits every one of them, and a
/// no-op that produced a command would cost an undo step per keystroke.
@immutable
final class MatrixCellUnchanged extends MatrixCellPlan {
  const MatrixCellUnchanged();
}

/// N drops created or N removed, ready to apply as ONE undo entry.
@immutable
final class MatrixCellReady extends MatrixCellPlan {
  const MatrixCellReady({
    required this.commands,
    required this.added,
    required this.removed,
    required this.fieldLabels,
  });

  /// In application order: the outlet, if one is being created, then the
  /// drops. Apply them inside ONE transaction.
  final List<Command<RackDocument>> commands;

  /// How many drops this creates. Zero on a decrement.
  final int added;

  /// How many it deletes. Zero on an increment.
  final int removed;

  /// The labels the created drops will carry, in order. Empty on a
  /// decrement.
  final List<String> fieldLabels;
}

/// The cell cannot become that number, and here is one sentence saying
/// why.
@immutable
final class MatrixCellRefused extends MatrixCellPlan {
  const MatrixCellRefused(this.reason);
  final String reason;
}

/// The project has no Structure device to hang an outlet on. An offer
/// rather than an error, for the same reason the drop line's is: it is
/// the one thing every blank project is missing and it is one keystroke
/// to fix.
@immutable
final class MatrixCellNeedsStructure extends MatrixCellPlan {
  const MatrixCellNeedsStructure();
}

/// Plans `[locationId × media] = targetCount` against [doc], mutating
/// nothing.
///
/// [structureBodyId] names the body being edited; null means the only
/// one. Filing sixty drops on the wrong Structure body puts them on the
/// wrong sheet, so a project with several and no id REFUSES rather than
/// guessing (#158, M3-E/3), which is the drop line's rule too.
MatrixCellPlan planMatrixCell({
  required RackDocument doc,
  required Uuid locationId,
  required MediaTypeId media,
  required int targetCount,
  required DateTime now,
  required String actor,
  Uuid? structureBodyId,
}) {
  if (targetCount < 0) {
    return const MatrixCellRefused('A cell cannot hold fewer than no drops.');
  }

  final location = doc.locations[locationId];
  if (location == null) {
    return const MatrixCellRefused(
      'That room is not in this project any more.',
    );
  }

  // CONDUIT IS NOT A CABLE, so a pathway-only column takes a different
  // path entirely and takes it FIRST (CR-109, DR-032 §11.31.5). Falling
  // through to the drop logic would make `Living Room × EMT = 2` mint an
  // outlet and two `Link`s, which is the exact thing CR-109 rejected:
  // "conduit as a connectable drop like any other, which produces a port
  // you can wire an HDMI cable into".
  if (doc.registries.mediaTypes[media]?.isPathwayOnly ?? false) {
    return _planPathwayCell(
      doc: doc,
      location: location,
      media: media,
      targetCount: targetCount,
      now: now,
      actor: actor,
    );
  }

  // THE COUNT AND THE DELETION LIST COME FROM ONE PLACE. See the header:
  // the number on screen and the rows a decrement takes must be the same
  // list, or a person deletes something they were not looking at.
  final inCell = <ScheduleEntry>[
    for (final group in buildStructureTable(
      doc,
      structureBodyId: structureBodyId,
    ).groups)
      if (group.locationId == locationId)
        for (final row in group.rows)
          if (row.mediaId == media) row,
  ];

  final current = inCell.length;
  if (targetCount == current) return const MatrixCellUnchanged();
  if (targetCount > current) {
    return _add(
      doc: doc,
      location: location,
      media: media,
      count: targetCount - current,
      now: now,
      actor: actor,
      structureBodyId: structureBodyId,
    );
  }
  return _remove(
    doc: doc,
    location: location,
    media: media,
    inCell: inCell,
    target: targetCount,
  );
}

/// The increment. One outlet and [count] drops.
MatrixCellPlan _add({
  required RackDocument doc,
  required Location location,
  required MediaTypeId media,
  required int count,
  required DateTime now,
  required String actor,
  required Uuid? structureBodyId,
}) {
  final def = doc.registries.mediaTypes[media];
  if (def == null) {
    // Reachable only through a dangling column, which
    // `structureMatrixColumns` draws for drops that already exist and
    // never offers as a place to add more.
    return MatrixCellRefused(
      '${media.v} is not a cable type this project carries, so nothing can '
      'be added to that column.',
    );
  }

  if (doc.structures.isEmpty) return const MatrixCellNeedsStructure();
  final bodyId =
      structureBodyId ??
      (doc.structures.length == 1 ? doc.structures.keys.first : null);
  if (bodyId == null || !doc.structures.containsKey(bodyId)) {
    return const MatrixCellRefused(
      'This project has more than one Structure device, and this grid does '
      'not say which one these drops belong to.',
    );
  }

  final add = AddOutletCommand(
    structureBodyId: bodyId,
    designation: outletDesignationFor(doc, location),
    order: nextOutletOrder(doc),
    now: now,
    actor: actor,
    locationId: location.id,
  );

  // The outlet the drops will name, before it is in the document. See
  // `alsoOutlets` in `buildAddHomeRunCommand`.
  final plannedOutlet = Outlet(
    id: add.id,
    structureBodyId: bodyId,
    designation: add.designation,
    order: add.order,
    meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    locationId: location.id,
  );

  final built = buildDropsFor(
    doc: doc,
    location: location,
    outlet: plannedOutlet,
    items: [PlannedDropItem(media: def, count: count)],
    // DR-023 STEP 3, DIRECTLY, and there is no step 1 or 2 to reach: a
    // grid cell carries no `@service=` and the outlet it creates carries
    // no template. A media type with no `shortTag` refuses inside
    // `buildDropsFor` with its own sentence rather than printing
    // `media.cat6` on a label.
    serviceTag: (item) => item.media.shortTag,
    now: now,
    actor: actor,
    usedLabels: usedFieldLabels(doc),
    usedDesignators: {for (final l in doc.links.values) l.designator},
    usedNetNames: {for (final n in doc.nets.values) n.name},
  );

  return switch (built) {
    DropBuildRefused(:final reason) => MatrixCellRefused(reason),
    DropBuildOk(:final commands, :final fieldLabels) => MatrixCellReady(
      commands: [add, ...commands],
      added: fieldLabels.length,
      removed: 0,
      fieldLabels: fieldLabels,
    ),
  };
}

/// §4.2's tinted `EMT` column: the cell counts `Pathway`s and creates
/// them (CR-109, DR-032, DR-035).
///
/// ═════════════════════════════════════════════════════════════════════
/// IT NEEDS NO STRUCTURE BODY, WHICH IS THE STRUCTURAL DIFFERENCE
/// ═════════════════════════════════════════════════════════════════════
/// Every other cell in this grid refuses on a project with no Structure
/// device, because a drop hangs off an `Outlet` and an outlet hangs off a
/// body. A `Pathway` hangs off the document, exactly as a `Location`
/// does (CR-112), so a conduit can be recorded in a project that has
/// nothing else in it yet. That is not a loophole: a conduit IS a thing
/// somebody pulls before there is a panel to terminate in.
///
/// ═════════════════════════════════════════════════════════════════════
/// A DECREMENT REFUSES TO TAKE A PATHWAY THAT HAS CABLE IN IT
/// ═════════════════════════════════════════════════════════════════════
/// §4.2's rule for drops is that a decrement takes the unconnected ones
/// and refuses the rest; the fact it protects is work somebody has
/// already done. The analogue here is a pathway with runs through it:
/// deleting it does not destroy the cable — `RemovePathwayCommand`
/// clears the reference — but it silently un-records the route of every
/// run in it, from a cell that shows a number and nothing else.
///
/// So this refuses and NAMES THE SURFACE THAT WILL DO IT, which is the
/// `[ Pathways ]` tab, where the delete states the run count in its
/// tooltip before the click. CR-017's spring-back, applied to the one
/// place a grid could quietly cost somebody an afternoon of routing.
MatrixCellPlan _planPathwayCell({
  required RackDocument doc,
  required Location location,
  required MediaTypeId media,
  required int targetCount,
  required DateTime now,
  required String actor,
}) {
  // ORDERED, and the comparator is total: two pathways can share a
  // `FracIndex`, and a decrement that took "the last ones" out of map
  // iteration order would delete a different pathway on a different
  // machine (§8.4).
  final inCell =
      <Pathway>[
        for (final p in doc.pathways.values)
          if (p.pathwayMedia == media && p.fromLocationId == location.id) p,
      ]..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });

  final current = inCell.length;
  if (targetCount == current) return const MatrixCellUnchanged();

  if (targetCount > current) {
    final tag = structureMatrixColumnHeader(doc, media);
    final commands = <Command<RackDocument>>[];
    final names = <String>[];
    // Grown as the cell is planned, because `nextPathwayOrder` reads the
    // DOCUMENT and cannot see commands that have not been applied yet —
    // the trap `b093062` found on the drop line.
    final plannedOrders = [for (final p in doc.pathways.values) p.order];
    for (var n = current; n < targetCount; n++) {
      // DR-032 §11.31.1's shape: the room and the medium, with a 1-based
      // index once there is more than one to tell apart.
      //
      // THE INDEX CONTINUES FROM THE CELL rather than restarting per
      // gesture, which is where this departs from §11.31.1's letter and
      // serves §11.31.3's reason. A line is one act on a state nobody
      // has counted; a CELL is a running total, so an index that
      // restarted would give `1 -> 3` a second "Living Room EMT 1" and
      // produce the identical `PATH` cells §11.31.3 exists to prevent.
      final name = n == 0
          ? '${location.name} $tag'
          : '${location.name} $tag ${n + 1}';
      final order = nextOrder(plannedOrders);
      plannedOrders.add(order);
      names.add(name);
      commands.add(
        AddPathwayCommand(
          name: name,
          order: order,
          now: now,
          actor: actor,
          pathwayMedia: media,
          fromLocationId: location.id,
        ),
      );
    }
    return MatrixCellReady(
      commands: commands,
      added: commands.length,
      removed: 0,
      // NOT FIELD LABELS, and empty is the honest answer: a pathway has
      // no `fieldLabel` because CR-109 says it is "never a `Link` and
      // never a `Port`". The preview line reads `pathwayNames` on the
      // drop line for the same reason.
      fieldLabels: const [],
    );
  }

  final going = inCell.sublist(targetCount);
  final routed = <Pathway>[
    for (final p in going)
      if (doc.links.values.any((l) => l.pathwayId == p.id)) p,
  ];
  if (routed.isNotEmpty) {
    final names = routed.map((p) => p.name).join(', ');
    final floor = inCell.length - going.length + routed.length;
    final one = routed.length == 1;
    return MatrixCellRefused(
      'This cell cannot go below $floor: $names ${one ? 'has' : 'have'} cable '
      'running through ${one ? 'it' : 'them'}. Delete it on the Pathways tab, '
      'which says how many runs lose their recorded route.',
    );
  }

  return MatrixCellReady(
    commands: [for (final p in going) RemovePathwayCommand(id: p.id, now: now)],
    added: 0,
    removed: going.length,
    fieldLabels: const [],
  );
}

/// The decrement. §4.2's "the highest-sequence unconnected drops".
MatrixCellPlan _remove({
  required RackDocument doc,
  required Location location,
  required MediaTypeId media,
  required List<ScheduleEntry> inCell,
  required int target,
}) {
  // HIGHEST-SEQUENCE MEANS LAST IN THE TABLE'S OWN ORDER, which sorts by
  // `Link.order` then id. Reusing that comparator rather than inventing
  // a second one is what makes "the ones that go" the rows a person can
  // see at the bottom of the room's band.
  final spare = <ScheduleEntry>[
    for (final row in inCell)
      if (!_isLanded(row)) row,
  ];
  final wanted = inCell.length - target;

  if (spare.length < wanted) {
    // CR-017's spring-back: the cell goes back to what it was and the
    // sentence names the floor it cannot go below, so a person knows
    // what to do rather than only that they were stopped.
    final tag = doc.registries.mediaTypes[media]?.shortTag ?? media.v;
    final landed = inCell.length - spare.length;
    return MatrixCellRefused(
      '${location.name} has ${inCell.length} $tag and $landed of them land '
      'on a port, so this cell cannot go below $landed. Unpatch a run in the '
      'table first, or delete it there.',
    );
  }

  final going = spare.sublist(spare.length - wanted);
  return MatrixCellReady(
    commands: [
      for (final row in going)
        RemoveLinkCommand(
          id: row.linkId,
          // THE SURVIVORS DECIDE whether the net goes too, which is
          // `netToRemoveWith`'s whole reason. Computed against the
          // unmutated document, one per link, because every net this
          // application creates belongs to exactly one link and a
          // hand-edited file's may not.
          netId: netToRemoveWith(doc, row.linkId),
        ),
    ],
    added: 0,
    removed: going.length,
    fieldLabels: const [],
  );
}

/// True when the rack end is a real port — `StructureTable`'s own rule
/// for "connected", so the grid and the status bar cannot disagree about
/// which drops a decrement may take.
///
/// `unresolvedPort` IS TAKEABLE and that is deliberate: a `PortEndpoint`
/// naming a port this document does not hold is a fault rather than a
/// connection, and refusing to delete it would make the fault permanent.
bool _isLanded(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => true,
  _ => false,
};
