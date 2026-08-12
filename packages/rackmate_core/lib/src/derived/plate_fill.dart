// packages/rackmate_core/lib/src/derived/plate_fill.dart
//
// HOW MANY CELLS ONE OUTLET NEEDS, AND WHAT IT HAS. DR-007 §11.7.2.1's
// table, computed rather than remembered.
//
// ═════════════════════════════════════════════════════════════════════
// CELLS ARE A FUNCTION OF TERMINATION, NOT OF THE CABLE
// ═════════════════════════════════════════════════════════════════════
// The tempting generalisation from DR-007's "one per conductor" is that
// cells always equal conductors. The ruling says outright that this "is
// FALSE for the most common drop in the building": a Cat6 run terminating
// in one RJ45 jack occupies ONE cell no matter how its conductors are
// modelled. §11.7.2.1's table, verbatim:
//
//   binding post / single post   one per `Conductor` landing there
//   modular jack, fBarrel, HDMI, one per `Link` end
//     3.5 mm modules
//   punchdown                    one per `Link` end
//   unterminated, fieldConnector ZERO — nothing is on the plate
//
// [cellsRequiredFor] is that table and nothing else. It is the reason
// `TerminationType.bindingPost` was added: the enum "already carries
// exactly this distinction and is the hook M3 should read", and until
// M3-H it could not name the one row that counts conductors.
//
// ═════════════════════════════════════════════════════════════════════
// NULL TERMINATION IS UNKNOWN, AND IT IS COUNTED (G4 / CR-114)
// ═════════════════════════════════════════════════════════════════════
// `StructureOrigin.terminationField` became nullable in M3-J for a
// reason this file inherits whole: a drop entered at rough-in, weeks
// before anyone opens a box of jacks, has NO ANSWER, and that is a
// different fact from `unterminated`, which is a decision to leave a
// coil bare. A coil needs no cell. A drop nobody has decided about
// might need one.
//
// So [PlateFill.unknownDrops] exists and no arm of this file guesses.
// A plate whose required-cell count is "at least 4, plus 3 drops nobody
// has ruled on" is honestly described; a plate reporting "4" is lying by
// an unstated amount, which is `totals.dart`'s rule 2 applied one entity
// down.
//
// ═════════════════════════════════════════════════════════════════════
// THE COVER PLATE IS DERIVED HERE AND STORED NOWHERE
// ═════════════════════════════════════════════════════════════════════
// §11.7.8 change 1: a strap and a Decora plate are two distinct
// purchasable objects, so an `Outlet` with N gangs is N straps plus
// exactly ONE N-gang cover plate, and "the plate's gang count is not
// free; it is `Outlet.gangs.length`, ALWAYS".
//
// Storing that count would be the second copy of one physical fact, and
// CR-107 deleted `StructureDrop` over exactly that: "the drop schedule
// says 78 ft and the wiring schedule says 90 ft, and nobody knows which
// to bill against." [PlateFill.coverPlateGangs] is a getter.
//
// This file COMPUTES and never formats. The materials sheet that prints
// it is M6's under DR-027; the derivation is M3's under §11.26.4, which
// is the same seam the Pull Sheet already straddles.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show TerminationType;
import 'package:rackmate_core/src/model/gang.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// How many cells one field end needs, per DR-007 §11.7.2.1.
///
/// [conductorCount] is only read for [TerminationType.bindingPost]; every
/// other termination is one cell per link end or none at all, whatever
/// the cable carries. Passing the wrong conductor count for an RJ45
/// therefore cannot change the answer, which is deliberate.
///
/// Returns `null` when [termination] is null: that is UNKNOWN and callers
/// must count it rather than substitute a number (G4). There is no
/// "probably one" arm here and there must never be one.
int? cellsRequiredFor(TerminationType? termination, int conductorCount) =>
    switch (termination) {
      null => null,
      TerminationType.bindingPost => conductorCount,
      TerminationType.keystone ||
      TerminationType.punchdown ||
      TerminationType.fBarrel => 1,
      // NOTHING IS ON THE PLATE. Not "one cell we cannot name" — zero, and
      // §11.7.2.1 states it as zero. A coil in a J-hook and a run brought
      // to a field connector both leave the plate alone.
      //
      // `euroblock` JOINED THIS ROW AT DR-044 (§11.43.4) AND WAS IN THE
      // ARM ABOVE, WRONGLY, FROM M3-H UNTIL THEN. §11.7.2.1's table does
      // not mention it at all, and M3-H put it beside `keystone` on an
      // inference nobody wrote down. A euroblock is a pluggable screw
      // terminal on a DEVICE: the conductors land on a keypad or an
      // amplifier and no jack occupies a cell. The keypad is the case
      // that makes it concrete, because the device fills the gang, and a
      // plate sized to give it a keystone as well is one cell too big on
      // every keypad drop in a house.
      //
      // `rj45Plug` JOINED THIS ROW AT DR-045 (§11.44.2), and unlike
      // `euroblock` above it was ASKED rather than assumed. The plug is
      // crimped on the cable and goes into the device, so an AP that
      // mounts to the box needs no strap at all.
      TerminationType.euroblock ||
      TerminationType.unterminated ||
      TerminationType.fieldConnector ||
      TerminationType.rj45Plug => 0,
    };

/// What one `Outlet`'s plate needs and what it currently provides.
///
/// Every count here is honest about what it could not answer. See
/// [unknownDrops], and `derived/totals.dart` for the rule it follows.
@immutable
final class PlateFill {
  const PlateFill({
    required this.outletId,
    required this.gangCount,
    required this.dropCount,
    required this.cellsRequired,
    required this.unknownDrops,
    required this.cellsProvided,
    required this.cellsOccupied,
    required this.blanksFitted,
    required this.strapsUnchosen,
  });

  final Uuid outletId;

  /// `Outlet.gangs.length`.
  final int gangCount;

  /// Every drop landing on this outlet, whatever it terminates in and
  /// whether or not anybody has said.
  ///
  /// CARRIED SO [needsNoPlate] CAN TELL AN EMPTY OUTLET FROM A PLATELESS
  /// ONE. Both have zero gangs and zero required cells; only the drop
  /// count separates "nothing lands here yet" from "everything that
  /// lands here goes into a device".
  final int dropCount;

  /// Cells the drops landing here need, summing only the drops whose
  /// termination is KNOWN. Reads with [unknownDrops] or not at all.
  final int cellsRequired;

  /// Drops landing at this outlet whose `terminationField` is null. Each
  /// one may need cells or may need none, and nothing here decides which.
  final int unknownDrops;

  /// Cells the fitted straps actually have. A gang with no strap chosen
  /// contributes nothing and is counted in [strapsUnchosen] instead.
  final int cellsProvided;

  /// Cells holding a jack or a post.
  final int cellsOccupied;

  /// Cells holding a [BlankInsert] — a decision, and a line item
  /// (§11.7.4).
  final int blanksFitted;

  /// Gangs whose strap nobody has chosen. Distinct from a strap with
  /// undecided cells: this is a part not yet picked, that one is a part
  /// picked and not yet filled.
  final int strapsUnchosen;

  /// EXACTLY ONE N-gang cover plate, N being [gangCount] (§11.7.8
  /// change 1). Zero gangs is zero plates rather than one 0-gang plate.
  int get coverPlateGangs => gangCount;

  /// Cells with nothing in them and no blank fitted: nobody has said.
  /// Blanks a materials sheet would need if every one were blanked, and
  /// the reason nothing auto-blanks them.
  int get cellsUndecided => cellsProvided - cellsOccupied - blanksFitted;

  /// Cells needed beyond what the fitted straps provide, or 0.
  ///
  /// **Read this beside [unknownDrops] or not at all.** A shortfall of 0
  /// with three unknown drops does not mean the plate fits; it means
  /// nobody has said whether it does. This is the whole reason the two
  /// counts are separate fields rather than one number.
  int get shortfall {
    final gap = cellsRequired - cellsProvided;
    return gap > 0 ? gap : 0;
  }

  /// True when the known drops fit and nothing is unknown. A plate that
  /// is merely not-known-to-be-wrong returns false.
  bool get isSettled =>
      unknownDrops == 0 && strapsUnchosen == 0 && shortfall == 0;

  /// **THIS OUTLET IS FINISHED AND HAS NO PLATE** (DR-045 §11.44.4). An
  /// access point mounting straight to the box, or a transceiver fed by a
  /// crimped RJ45 plug: drops land here, every one of them terminates in
  /// a device rather than in a jack, and there is correctly no strap and
  /// no cover plate.
  ///
  /// **THREE STATES, NOT TWO, AND THIS IS THE ONE THE PRODUCT COULD NOT
  /// SAY.** An empty outlet and a plateless one both have zero gangs and
  /// zero required cells; [dropCount] is what separates them. The surface
  /// showed the *undecided* sentence for both, so a correctly-finished AP
  /// box read as unfinished work. That is DR-007 §11.7.4's
  /// blank-insert-versus-empty-cell distinction one level up, and got
  /// wrong the same way: *nobody has said* and *somebody said no plate*
  /// are different facts.
  ///
  /// **AN UNKNOWN TERMINATION MAKES THIS FALSE, ALWAYS.** [unknownDrops]
  /// is in the condition because "needs no plate" asserted over a drop
  /// nobody has terminated is a guess, and it is the guess that would
  /// make a materials sheet omit a part somebody has to buy (G4).
  ///
  /// DERIVED AND NEVER STORED (CR-107). A `hasPlate` flag would be the
  /// second copy of one physical fact, and it would go stale the first
  /// time somebody changed a drop's termination.
  bool get needsNoPlate =>
      dropCount > 0 &&
      gangCount == 0 &&
      unknownDrops == 0 &&
      cellsRequired == 0;
}

/// Computes [PlateFill] for [outlet] against the links that land on it.
///
/// Takes the links loose rather than a `RackDocument`, for the reason
/// `resolveJacketColor` and `computeRackRollups` both give: a test states
/// a scenario in three lines, and this survives the arrival of a real
/// controller untouched.
///
/// MEMBERSHIP IS `Link.structureOrigin.outletId` AND NOTHING ELSE
/// (AC-019, CR-016). `Outlet` holds no member list, so this filters
/// rather than reads one, which is the single source of truth the model
/// was shaped around.
PlateFill computePlateFill(Outlet outlet, Iterable<Link> links) {
  var cellsRequired = 0;
  var unknownDrops = 0;
  var dropCount = 0;

  for (final link in links) {
    final origin = link.structureOrigin;
    if (origin == null || origin.outletId != outlet.id) continue;
    dropCount++;
    final needed = cellsRequiredFor(
      origin.terminationField,
      link.conductors.length,
    );
    if (needed == null) {
      unknownDrops++;
    } else {
      cellsRequired += needed;
    }
  }

  var cellsProvided = 0;
  var cellsOccupied = 0;
  var blanksFitted = 0;
  var strapsUnchosen = 0;

  for (final gang in outlet.gangs) {
    final strap = gang.strap;
    if (strap == null) {
      strapsUnchosen++;
      continue;
    }
    cellsProvided += strap.cellCount;
    for (var i = 0; i < strap.cellCount; i++) {
      switch (strap.cells[i]) {
        case null:
          break;
        case BlankInsert():
          blanksFitted++;
        case LinkEndOccupant() || ConductorOccupant():
          cellsOccupied++;
      }
    }
  }

  return PlateFill(
    outletId: outlet.id,
    gangCount: outlet.gangs.length,
    dropCount: dropCount,
    cellsRequired: cellsRequired,
    unknownDrops: unknownDrops,
    cellsProvided: cellsProvided,
    cellsOccupied: cellsOccupied,
    blanksFitted: blanksFitted,
    strapsUnchosen: strapsUnchosen,
  );
}

/// The smallest shipped strap with at least [cells] cells, or null when
/// [cells] exceeds 6.
///
/// DERIVED FROM THE BOUNDS, so 5 is impossible rather than skipped
/// (§11.7.1). The search is `W ∈ {1,2} × H ∈ {1,2,3}` ordered by cell
/// count then by width, which prefers a 1 × 3 over a 2 × 2 at three
/// cells: a 1-wide strap is the narrower part and a plate that fits a
/// 3-port has no reason to buy a 4-port.
///
/// **THIS IS A SUGGESTION AND NOT A PLACEMENT.** §11.7.2 deleted packing
/// outright: with no occupant larger than a cell "there is NO PACKING
/// PROBLEM AT ALL, only a set of cells each holding zero or one
/// keystone". Choosing a part is arithmetic; putting keystones in it is
/// a person's call and stays one.
({int width, int height})? smallestStrapFor(int cells) {
  if (cells <= 0) return null;
  ({int width, int height})? best;
  for (var w = kMinStrapWidth; w <= kMaxStrapWidth; w++) {
    for (var h = kMinStrapHeight; h <= kMaxStrapHeight; h++) {
      if (w * h < cells) continue;
      if (best == null ||
          w * h < best.width * best.height ||
          (w * h == best.width * best.height && w < best.width)) {
        best = (width: w, height: h);
      }
    }
  }
  return best;
}
