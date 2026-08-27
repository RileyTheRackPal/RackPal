// packages/rackpal_core/lib/src/structure/plate_arrange.dart — pure
// Dart. Board M3-H/2 (#167), DR-007 §11.7.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS IS, AND WHAT DR-007 DELETED THAT IT IS NOT
// ═════════════════════════════════════════════════════════════════════
// A PROPOSAL: given an outlet and the drops that land on it, which
// straps to fit and which cell each keystone goes in. It returns a plan
// and mutates nothing, so a caller can show it before committing it.
//
// **IT IS NOT A PACKING SEARCH, AND THERE IS NO PACKING PROBLEM TO
// SOLVE.** §11.7.6, as overtaken by §11.7.2's revision: with no occupant
// larger than a cell "there is NO PACKING PROBLEM AT ALL, only a set of
// cells each holding zero or one keystone". An earlier draft of DR-007
// hedged that placement was cheap only because the grid is bounded at
// six cells; the hedge was written against an algorithm that turns out
// not to exist. This file counts and fills in order. Anything here that
// looks like a search would be rebuilding the subsystem a photograph
// deleted.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THERE IS AN ARRANGE AT ALL
// ═════════════════════════════════════════════════════════════════════
// M3's exit criterion is sixty drops in under fifteen minutes. Sixty
// drops across a house is on the order of two hundred keystones, and a
// person clicking each one into a cell is not doing a rough-in, they are
// doing data entry. The arithmetic that decides plate size is
// §11.7.2.1's table, which the product already computes; withholding it
// and making somebody re-derive it per plate is the opposite of what
// §11.7.2.2 means by "it falls straight out of the table above rather
// than being a rule anyone has to remember".
//
// ═════════════════════════════════════════════════════════════════════
// IT NEVER INVENTS A TERMINATION, AND IT SAYS WHAT IT SKIPPED
// ═════════════════════════════════════════════════════════════════════
// A drop whose `terminationField` is null cannot be placed, because how
// many cells it needs is unknown and the honest answers range from zero
// (a coil) to four (a 16/4 on binding posts). It is COUNTED in
// [PlateArrangement.skippedUnknown] and left out, never assumed to be a
// single keystone. G4, and the same discipline `derived/plate_fill.dart`
// keeps one layer up.
//
// ═════════════════════════════════════════════════════════════════════
// DETERMINISM
// ═════════════════════════════════════════════════════════════════════
// Same document, same plan, byte for byte. Drops sort by field label,
// which CR-113 makes unique project-wide, and the chain still ends in
// the link id so the comparator is TOTAL: `List.sort` is not stable in
// Dart and a comparator that ties would let two runs of the same
// document produce two different plates.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/plate_fill.dart';
import 'package:rackpal_core/src/model/conductor.dart' show ConductorRef;
import 'package:rackpal_core/src/model/enums.dart' show PassThroughStyle;
import 'package:rackpal_core/src/model/gang.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One keystone the plan puts somewhere.
@immutable
final class PlannedCell {
  const PlannedCell({
    required this.gangIndex,
    required this.cellIndex,
    required this.occupant,
  });

  final int gangIndex;
  final int cellIndex;
  final CellOccupant occupant;
}

/// What [planPlateArrangement] produced.
@immutable
final class PlateArrangement {
  const PlateArrangement({
    required this.straps,
    required this.cells,
    required this.skippedUnknown,
    this.keptPassThroughs = const [],
  });

  /// One entry per gang, left to right, giving the strap to fit.
  final List<({int width, int height})> straps;

  /// Where every placeable keystone goes.
  final List<PlannedCell> cells;

  /// Drops that could not be placed because nobody has said how they
  /// terminate. **Show this number or do not show the plan**: a plate
  /// arranged for four drops out of seven is not an arranged plate.
  final int skippedUnknown;

  /// Pass-through openings the plate already has, to be re-fitted AFTER
  /// [straps] (DR-047 §11.46.6).
  ///
  /// **THE ONE THING THIS PLAN READS OFF THE EXISTING PLATE**, and the
  /// ruling requires it: a brushed opening is a decision a person made,
  /// not arithmetic this file can re-derive from the drops. Arrange
  /// planning it away would replace a part somebody chose with a strap
  /// sized for zero cells.
  final List<PassThroughStyle> keptPassThroughs;

  /// True when there is nothing to do, which is the case a caller should
  /// refuse rather than commit an empty transaction for.
  ///
  /// **[keptPassThroughs] IS NOT IN HERE ON PURPOSE.** A plate holding
  /// nothing but brushes has nothing to arrange, and returning false
  /// would make Arrange tear those gangs down and build them straight
  /// back: one undo entry, no change, and a person wondering what it did.
  bool get isEmpty => straps.isEmpty && cells.isEmpty;
}

/// The demand one drop puts on a plate: its cells, in the order they
/// should be fitted.
List<CellOccupant> _cellsFor(Link link) {
  final origin = link.structureOrigin;
  if (origin == null) return const [];
  final needed = cellsRequiredFor(
    origin.terminationField,
    link.conductors.length,
  );
  if (needed == null || needed == 0) return const [];
  if (needed == 1) return [LinkEndOccupant(link.id)];
  // One post per conductor, in the link's own conductor order, so a
  // stereo pair reads L+ L- down the plate rather than in whatever order
  // a map iterated. §11.7.2 permits any two free cells; ORDER IS A
  // COURTESY TO THE INSTALLER, not a constraint the ruling imposes.
  return [
    for (var i = 0; i < needed; i++)
      ConductorOccupant(ConductorRef(link.id, i)),
  ];
}

/// Plans a whole plate for [outlet] from the [links] that land on it.
///
/// **THE EXISTING PLATE IS CONSULTED FOR EXACTLY ONE THING**, and DR-047
/// §11.46.6 is why: its pass-through openings, which come back in
/// [PlateArrangement.keptPassThroughs]. Everything else is a fresh
/// proposal and a caller committing it replaces whatever was there. That
/// is why the gesture is worth a confirmation when
/// `PlateFill.cellsOccupied > 0`: re-arranging a plate somebody hand-built
/// is destructive, and a "helpful" merge would have to guess which of the
/// two arrangements the person meant.
///
/// **A BRUSH IS NOT AN ARRANGEMENT.** Straps and cells fall out of
/// §11.7.2.1's table from the drops; a pass-through is a decision about a
/// part, so this file can neither invent one (it would assert a purchase
/// nobody made) nor discard one (it would delete a purchase somebody
/// did).
PlateArrangement planPlateArrangement(Outlet outlet, Iterable<Link> links) {
  final drops = <Link>[];
  var skippedUnknown = 0;

  // IN GANG ORDER, so the plate a person gets back has its brushes in the
  // same left-to-right sequence it had them in.
  final keptPassThroughs = <PassThroughStyle>[
    for (final gang in outlet.gangs)
      if (gang.fitting case PassThrough(:final style)) style,
  ];

  for (final link in links) {
    final origin = link.structureOrigin;
    if (origin == null || origin.outletId != outlet.id) continue;
    if (origin.terminationField == null) {
      skippedUnknown++;
      continue;
    }
    drops.add(link);
  }

  // TOTAL comparator, ending in the id. See the file header.
  drops.sort((a, b) {
    final byLabel = (a.structureOrigin?.fieldLabel ?? '').compareTo(
      b.structureOrigin?.fieldLabel ?? '',
    );
    if (byLabel != 0) return byLabel;
    return a.id.v.compareTo(b.id.v);
  });

  const maxCellsPerGang = kMaxStrapWidth * kMaxStrapHeight;
  final gangs = <List<CellOccupant>>[];

  for (final link in drops) {
    final demand = _cellsFor(link);
    if (demand.isEmpty) continue;

    // A DROP'S CELLS STAY IN ONE GANG when they fit in one. Splitting a
    // stereo pair across two openings is legal under §11.7.2 and is a
    // rotten thing to hand an installer, so the plan avoids it without
    // pretending it is forbidden.
    if (gangs.isEmpty ||
        (gangs.last.length + demand.length > maxCellsPerGang &&
            demand.length <= maxCellsPerGang)) {
      gangs.add(<CellOccupant>[]);
    }
    for (final occupant in demand) {
      if (gangs.last.length == maxCellsPerGang) gangs.add(<CellOccupant>[]);
      gangs.last.add(occupant);
    }
  }

  final straps = <({int width, int height})>[];
  final cells = <PlannedCell>[];
  for (var g = 0; g < gangs.length; g++) {
    final strap = smallestStrapFor(gangs[g].length);
    if (strap == null) continue;
    straps.add(strap);
    for (var c = 0; c < gangs[g].length; c++) {
      cells.add(
        PlannedCell(gangIndex: g, cellIndex: c, occupant: gangs[g][c]),
      );
    }
  }

  return PlateArrangement(
    straps: straps,
    cells: cells,
    skippedUnknown: skippedUnknown,
    keptPassThroughs: keptPassThroughs,
  );
}

/// The drops landing on [outlet] that the plate does not yet hold in
/// full.
///
/// What a "3 unplaced" chip counts, and what a cell picker offers. Unlike
/// [planPlateArrangement] this READS the current plate, so it is the
/// question a person editing by hand actually has.
///
/// **PARTIALLY PLACED IS UNPLACED, and that is the case worth naming.** A
/// 16/4 speaker run needs four posts. Counting it as done the moment the
/// first post lands would drop it off the picker with three conductors
/// still homeless, and the plate would look finished while the installer
/// found out otherwise. So this compares cells FOUND against
/// [cellsRequiredFor], per link.
///
/// A drop whose termination nobody has recorded needs an unknown number
/// of cells, so it is reported unplaced until somebody says. That is G4
/// choosing the answer that keeps it visible rather than the one that
/// makes the list shorter.
List<Uuid> unplacedDropsOf(Outlet outlet, Iterable<Link> links) {
  final found = <Uuid, int>{};
  for (final gang in outlet.gangs) {
    // A PASS-THROUGH HOLDS NOTHING, so it neither places a drop nor
    // hides one. Skipped for the same reason a gang with no fitting is:
    // there are no cells here to have found anything in.
    if (gang.fitting case final Strap strap) {
      for (final occupant in strap.cells.values) {
        switch (occupant) {
          case LinkEndOccupant(:final linkId):
            found[linkId] = (found[linkId] ?? 0) + 1;
          case ConductorOccupant(:final conductor):
            found[conductor.linkId] = (found[conductor.linkId] ?? 0) + 1;
          case BlankInsert():
            break;
        }
      }
    }
  }

  final out = <Uuid>[];
  for (final link in links) {
    final origin = link.structureOrigin;
    if (origin == null || origin.outletId != outlet.id) continue;
    final needed = cellsRequiredFor(
      origin.terminationField,
      link.conductors.length,
    );
    // Unknown termination: unplaceable, and reported rather than hidden.
    if (needed == null) {
      out.add(link.id);
      continue;
    }
    // A coil needs no cell and is not waiting for one.
    if (needed == 0) continue;
    if ((found[link.id] ?? 0) >= needed) continue;
    out.add(link.id);
  }
  return out;
}
