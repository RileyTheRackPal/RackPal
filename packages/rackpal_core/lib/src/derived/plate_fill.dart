// packages/rackpal_core/lib/src/derived/plate_fill.dart
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
import 'package:rackpal_core/src/model/conductor.dart' show PortEndpoint;
import 'package:rackpal_core/src/model/enums.dart' show TerminationType;
import 'package:rackpal_core/src/model/gang.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// How many cells one field end needs, per DR-007 §11.7.2.1 as amended by
/// DR-069 §11.68.
///
/// [conductorCount] is only read for [TerminationType.bindingPost]; every
/// other termination is one cell per link end or none at all, whatever
/// the cable carries. Passing the wrong conductor count for an RJ45
/// therefore cannot change the answer, which is deliberate.
///
/// [fieldEndIsLanded] is whether the run's FIELD end is bound to a device
/// port rather than to a place, and it changes exactly one arm. See
/// [TerminationType.bindingPost] below.
///
/// Returns `null` when [termination] is null: that is UNKNOWN and callers
/// must count it rather than substitute a number (G4). There is no
/// "probably one" arm here and there must never be one.
int? cellsRequiredFor(
  TerminationType? termination,
  int conductorCount, {
  bool fieldEndIsLanded = false,
}) => switch (termination) {
  null => null,
  // ═══════════════════════════════════════════════════════════════
  // WHOSE POSTS ARE THEY? THE ONLY ARM WHERE THE WORD DOES NOT SAY
  // ═══════════════════════════════════════════════════════════════
  // Reported by a user diagramming a real system (`#717`): tagging a
  // ceiling speaker's run `BINDING POST` demanded two plate cells,
  // and a ceiling speaker has no low-voltage box, let alone a strap.
  //
  // Both readings of the word are real hardware. A speaker
  // binding-post WALL PLATE is a product, its posts are on the plate,
  // and each conductor lands in a cell: that is what §11.7.2.1's
  // original arm was written for and it is still right. An in-wall or
  // in-ceiling driver's posts are on the DRIVER, and nothing sits in
  // a cell because there is no plate.
  //
  // `keystone` and `punchdown` are ALWAYS the plate's; `euroblock`
  // and `rj45Plug` are ALWAYS the device's. This is the one arm where
  // the termination type genuinely cannot say, so it stopped being
  // asked: the answer comes from where the run LANDS, which DR-068
  // made expressible by letting a field end bind to a device port.
  //
  // THE THIRD TIME THIS QUESTION HAS BEEN PUT. DR-044 corrected
  // `euroblock` from one cell to zero on exactly this reasoning, and
  // DR-045 asked it of `rj45Plug` out loud rather than inferring it.
  // Adding a `directTermination` member was the alternative and was
  // refused: it would put one fact in two places and let a document
  // say `DIRECT TERMINATION` on a run whose field end is an unlanded
  // wall plate.
  TerminationType.bindingPost => fieldEndIsLanded ? 0 : conductorCount,
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

/// Whether [link]'s FIELD end is bound to a device port rather than to a
/// place (DR-069 §11.68).
///
/// `Conductor.from` is the field end and `.to` is the rack end, which is
/// the reading `link_class.dart` and `schematic_scene.dart` both take:
/// CR-014 fixes each conductor at two ends and every conductor of one
/// cable shares the same pair, so the first speaks for the link.
///
/// A LINK WITH NO CONDUCTORS IS NOT LANDED, rather than an error. It is
/// reachable from a file, and answering "landed" for it would zero a
/// plate's requirement on the strength of a cable that states nothing.
bool fieldEndIsLanded(Link link) {
  if (link.conductors.isEmpty) return false;
  return link.conductors.first.from is PortEndpoint;
}

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
    required this.fittingsUnchosen,
    this.passThroughGangs = 0,
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

  /// Cells the fitted straps actually have. A gang with no fitting chosen
  /// contributes nothing and is counted in [fittingsUnchosen] instead; a
  /// gang fitted with a `PassThrough` contributes nothing either, and is
  /// counted in [passThroughGangs], because a hole has no cells.
  final int cellsProvided;

  /// Gangs fitted with a `PassThrough`: a hole in the plate, decided
  /// (DR-047 §11.46).
  ///
  /// **NOT AN UNCHOSEN GANG AND NOT A SETTLED-AWAY ONE.** It provides no
  /// cells, exactly like a gang nobody has fitted, and it is the opposite
  /// state: somebody said this opening gets no strap. Keeping the two in
  /// separate fields is the whole of the ruling at this scale, and
  /// [isSettled] reads only the first.
  final int passThroughGangs;

  /// Cells holding a jack or a post.
  final int cellsOccupied;

  /// Cells holding a [BlankInsert] — a decision, and a line item
  /// (§11.7.4).
  final int blanksFitted;

  /// Gangs whose fitting nobody has chosen. Distinct from a strap with
  /// undecided cells: this is a part not yet picked, that one is a part
  /// picked and not yet filled.
  ///
  /// **NAMED `fittingsUnchosen` SINCE DR-047 AND `strapsUnchosen` BEFORE
  /// IT.** The rename is the ruling: a gang destined for a brush was
  /// never a strap nobody chose, so the old name asserted the very
  /// collapse §11.46.1 exists to remove. A field name that has stopped
  /// describing its field is worse than a missing one, because it is
  /// trusted.
  final int fittingsUnchosen;

  /// EXACTLY ONE N-gang cover plate, N being [gangCount] (§11.7.8
  /// change 1). Zero gangs is zero plates rather than one 0-gang plate.
  ///
  /// **UNCHANGED BY DR-047, AND §12.19 IS WHY THAT IS WORTH SAYING.**
  /// DR-045 §11.44.6 held that a pass-through plate is one this getter
  /// "structurally cannot express". That was true only while a brush
  /// opening had no gang. It has one now, so the count still falls out of
  /// `gangs.length` and the *style* of the plate is a separate derivation
  /// in `derived/plate_materials.dart`.
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
  ///
  /// **[passThroughGangs] IS DELIBERATELY NOT IN HERE** (DR-047 §11.46.5).
  /// A brushed opening is a decided opening, so a plate whose every gang
  /// is a pass-through is settled: there is nothing left for anybody to
  /// say about it. Counting it as unsettled would be the M3-H defect
  /// again, where a finished AP box read as unfinished work.
  bool get isSettled =>
      unknownDrops == 0 && fittingsUnchosen == 0 && shortfall == 0;

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
  ///
  /// **DR-047 DOES NOT MOVE THIS, AND THE `gangCount == 0` IS WHY.** An
  /// outlet covered by a brush plate is **not** a plateless outlet; it is
  /// an outlet with a plate that has no jacks in it, and it has a gang to
  /// prove it. The two states stay distinct: a box with an AP screwed to
  /// it needs no part at all, and a box with a brush plate needs one.
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
      fieldEndIsLanded: fieldEndIsLanded(link),
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
  var fittingsUnchosen = 0;
  var passThroughGangs = 0;

  // THREE ARMS, AND THE SWITCH IS THE RULING (DR-047 §11.46.2). The two
  // that provide no cells are NOT the same arm: one is a gang nobody has
  // fitted and the other is one somebody fitted with a hole. A
  // `if (strap == null)` could only see the first.
  for (final gang in outlet.gangs) {
    switch (gang.fitting) {
      case null:
        fittingsUnchosen++;
      case PassThrough():
        passThroughGangs++;
      case final Strap strap:
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
    fittingsUnchosen: fittingsUnchosen,
    passThroughGangs: passThroughGangs,
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
