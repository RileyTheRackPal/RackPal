// rackpal_core/src/derived/room_estimate.dart — plan geometry fills the
// room estimate (DR-050 §11.49, `LEN-A/3`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIGURE: FARTHEST CORNER PLUS RISE, RULED BY THE USER
// ═══════════════════════════════════════════════════════════════════════
// The straight line from the datum rack's pin to the room's most distant
// vertex, plus `Location.riseAllowance`. **Every term is measured and
// nothing is invented**, which is the posture DR-020 takes throughout,
// and it over-estimates, which is the safe direction for a consumable
// bought with a margin the estimator controls.
//
// ═══════════════════════════════════════════════════════════════════════
// NO MARGIN, NO FACTOR, AND THAT IS A RULING RATHER THAN AN OVERSIGHT
// ═══════════════════════════════════════════════════════════════════════
// The trade quotes conservatively, commonly several hundred feet over the
// actual totals. **That margin is the estimator's and stays theirs.**
// DR-020 killed `routingFactor` and `slackAllowance` as the product
// guessing at building geometry it cannot observe, and DR-050 §11.49.4
// says they are *"still deleted and still not to be re-argued from"*. A
// waste factor on this tier would be an amendment with a ruling id, not a
// decision this file may take.
//
// ═══════════════════════════════════════════════════════════════════════
// A ROOM'S DIMENSIONS ARE NOT A ROUTE (§11.49.4)
// ═══════════════════════════════════════════════════════════════════════
// What this computes is a ROOM-LEVEL figure from measured geometry
// instead of from somebody's recollection, into a tier that already
// existed for room-level figures. A per-drop figure derived from a drawn
// path remains forbidden, and nothing here draws one.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DATUM IS THE RACK THIS ROOM'S RUNS LAND IN
// ═══════════════════════════════════════════════════════════════════════
// DR-147 §11.146.2 ruled that the BOUND measures from *"the rack this
// link lands in"* and refused both *the nearest pinned rack* and *the
// first in document order*. A room estimate has no single run, so that
// answer does not transfer verbatim; **the user ruled that it transfers
// in substance**, and the reason is better than the alternatives put with
// it: `estimatedRunLengthFromRack` is read PER RUN, at `schedule.dart`'s
// length ladder, so the runs that consume this answer are the same runs
// that say which rack. The estimate and the bound therefore measure from
// one rack by one rule and cannot disagree about a room's head end.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO RACKS OVER-ESTIMATE RATHER THAN REFUSE, AND THE LADDER IS WHY
// ═══════════════════════════════════════════════════════════════════════
// This was drafted as a refusal on DR-147's reasoning and changed after
// reading what a refusal costs. `_lengthOf` falls through
// `roomEstimate → planLowerBound → none`, and `cable_footage.dart`'s
// `_isQuantity` is FALSE for both of those. **A refused estimate means
// every run in that room buys zero wire in the takeoff.**
//
// Against a trade that deliberately quotes high, silently contributing
// nothing for a whole room is the worst available direction of error. So
// a room whose runs land in more than one rack measures from whichever
// gives the LARGER figure: still entirely measured, conservative the way
// the quote already leans, and never a silent zero.
//
// **DR-147 IS NOT CONTRADICTED**, because it is about a different object.
// DR-050 §11.49.1 is the ruling whose whole point is that the rollup
// *"forbids a BOUND, which is not the same object"*, and this is that
// distinction doing its work rather than being worked around. A bound
// claims to be a floor, so a wrong one is a false claim; an estimate
// says it is an estimate and `estimatedCount` keeps its standing visible.
import 'package:rackpal_core/src/derived/endpoint_resolution.dart';
import 'package:rackpal_core/src/derived/schedule.dart' show roomOfLink;
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The plan-derived estimate for [location], or null when none derives.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE REFUSALS MIRROR `planLowerBoundOf` AND ARE NOT RE-DERIVED
/// ═══════════════════════════════════════════════════════════════════════
/// Null when there is no outline, when the outline is not a shape, when
/// the underlay carries no usable calibration, when no run to this room
/// lands in a rack, or when the datum rack is not pinned on the outline's
/// own underlay. **Never a guess**, which is G4 in the one place a reader
/// cannot see it happening.
///
/// THE LAST ONE IS THE COMMON WHOLE-HOUSE SHAPE AND IT STILL REFUSES: a
/// head end in the basement with drops on `Level 1` has its pin on the
/// basement plan, and two plans are two unrelated pixel spaces. The
/// horizontal offset between them is not a thing anybody has recorded, so
/// there is no measured quantity to be conservative WITH.
/// `riseAllowance` covers the vertical drop a plan cannot see; nothing
/// covers the horizontal one.
///
/// NOT GATED ON `LocationKind`. The field is per-`Location` and a person
/// who drew an outline on a zone meant it; refusing by kind would be
/// inventing a rule DR-050 does not state.
Len? roomEstimateFor(RackDocument doc, Location location) {
  final outline = location.planOutline;
  if (outline == null || !outline.isUsable) return null;

  final scale = doc.underlays[outline.underlayId]?.scale;
  // ONE PREDICATE FOR TWO REFUSALS, which is `planLowerBoundOf`'s own
  // arrangement: an outline may name an underlay this document no longer
  // holds, since `read never throws` (CR-093), and a stored scale whose
  // two points coincide yields no factor. `lengthBetween` returns null in
  // exactly the cases `isCalibrated` is false, so asking it cannot
  // disagree with the flag the underlay row prints.
  if (scale == null) return null;

  Len? best;
  for (final rackId in _datumRacksFor(doc, location.id)) {
    final pin = doc.racks[rackId]?.planPin;
    if (pin == null) continue;
    if (pin.underlayId != outline.underlayId) continue;
    final reach = _farthestCorner(scale, pin, outline);
    if (reach == null) continue;
    // THE LARGER ONE WINS. See this file's header: a room served by two
    // head ends gets the conservative figure rather than no figure.
    if (best == null || reach.nm > best.nm) best = reach;
  }
  if (best == null) return null;

  final rise = location.riseAllowance;
  return rise == null ? best : best + rise;
}

/// Why [location] has no plan-derived run length, or null when one derives
/// (DR-191 §11.190.4).
///
/// **THE SAME REFUSALS AS [roomEstimateFor], IN THE SAME ORDER**, named
/// rather than collapsed into null, so the room's helper line can tell a
/// person which one input is missing instead of leaving a blank field and a
/// guess about why.
PlanEstimateGap? planEstimateGapOf(RackDocument doc, Location location) {
  final outline = location.planOutline;
  if (outline == null || !outline.isUsable) return PlanEstimateGap.noOutline;
  if (doc.underlays[outline.underlayId]?.scale == null) {
    return PlanEstimateGap.notCalibrated;
  }
  final racks = _datumRacksFor(doc, location.id);
  if (racks.isEmpty) return PlanEstimateGap.noLandedRun;
  final pins = [
    for (final rackId in racks)
      if (doc.racks[rackId]?.planPin case final pin?) pin,
  ];
  if (pins.isEmpty) return PlanEstimateGap.rackNotPinned;
  if (pins.every((p) => p.underlayId != outline.underlayId)) {
    return PlanEstimateGap.rackOnAnotherPlan;
  }
  // Every named input is present. A null from [roomEstimateFor] now means a
  // calibration whose two points coincide, which reads to a person as a plan
  // that is not calibrated.
  return roomEstimateFor(doc, location) == null
      ? PlanEstimateGap.notCalibrated
      : null;
}

/// The one input a room's plan-derived run length is waiting for.
enum PlanEstimateGap {
  /// The room has no outline on any plan.
  noOutline,

  /// The plan the outline is on has no usable calibration.
  notCalibrated,

  /// No run to this room lands in a rack, so there is no rack to measure
  /// from.
  noLandedRun,

  /// The rack this room's runs land in is pinned on no plan.
  rackNotPinned,

  /// The rack is pinned, on a DIFFERENT plan from the outline. Two plans are
  /// unrelated pictures and nothing records how they line up, so this one
  /// is fixed by typing the figure rather than by the next edit.
  rackOnAnotherPlan,
}

/// The distance from [pin] to the most distant vertex of [outline].
///
/// `lengthBetween` per vertex and the MAXIMUM of those, which is not the
/// rounding hazard `lengthAlong` exists to avoid: that one sums segments
/// and must convert once at the end, while this compares independent
/// distances and never adds them. Each is rounded once, by the one rule
/// `PlanScale` states.
Len? _farthestCorner(PlanScale scale, PlanPin pin, RoomOutline outline) {
  Len? best;
  for (final vertex in outline.vertices) {
    final d = scale.lengthBetween(pin.at, vertex);
    if (d == null) return null;
    if (best == null || d.nm > best.nm) best = d;
  }
  return best;
}

/// Every rack the runs belonging to [roomId] land in.
///
/// ═══════════════════════════════════════════════════════════════════════
/// EXACTLY ONE END IN A RACK, WHICH EXCLUDES THREE SHAPES WITHOUT NAMING
/// THEM
/// ═══════════════════════════════════════════════════════════════════════
/// `planLowerBoundOf`'s condition, spelled the same way so the two cannot
/// drift: a jumper between two rack devices has two rack ends, and a
/// field-to-field run has none. Neither is a run FROM a head end TO this
/// room, so neither names a datum.
///
/// Returns a `Set`, so a room with forty runs to one rack yields one
/// candidate and the loop above measures once.
Set<Uuid> _datumRacksFor(RackDocument doc, Uuid roomId) {
  final out = <Uuid>{};
  for (final link in doc.links.values) {
    if (roomOfLink(doc, link) != roomId) continue;
    final conductors = link.conductors;
    if (conductors.isEmpty) continue;
    // The first conductor holds the cable's rack end. A cable may reach N
    // devices (DR-236), and a set added to it appends after the conductors
    // already there, so the conductor the run was first drawn with, from
    // the head end, stays first. A later conductor need not touch the rack
    // at all: one added from the first speaker onward does not.
    final first = conductors.first;
    final rackFrom = rackOfEndpoint(doc, first.from);
    final rackTo = rackOfEndpoint(doc, first.to);
    if ((rackFrom == null) == (rackTo == null)) continue;
    out.add((rackFrom ?? rackTo)!);
  }
  return out;
}

/// Whether a plan-derived figure may be written over what [location]
/// already holds (DR-050 §11.49.3, `LEN-A/5`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A TYPED VALUE IS NEVER OVERWRITTEN, WHICH IS THE USER'S CALL AND
/// §11.45.2's LINE
/// ═══════════════════════════════════════════════════════════════════════
/// §11.49.3 permits an auto-fill here that §11.45.2 refused for
/// terminations, and the reason is the cost of being wrong: a termination
/// is a discrete part and a wrong one orders the wrong object, while a
/// length is a continuous estimate consumed with a margin. **That argument
/// licenses filling an EMPTY field and replacing the software's own
/// earlier guess. It does not license replacing a person.**
///
/// **AN UNRECORDED ORIGIN COUNTS AS A PERSON'S** (G4). Absent means nobody
/// wrote down where the figure came from, which is the state of every
/// document written before `LEN-A/1`; treating that as "not typed" would
/// read an unknown as a licence, and the figure it silently replaced might
/// be the one somebody walked the house to get.
bool planEstimateMayFill(Location location) =>
    location.estimatedRunLengthFromRack == null ||
    location.estimatedRunLengthOrigin == RunLengthOrigin.computedFromPlan;
