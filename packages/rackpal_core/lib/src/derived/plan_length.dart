// rackpal_core/src/derived/plan_length.dart — the one length statement a
// plan may honestly make (docs/15 §4.1, DR-020 §11.19.2, DR-037 §11.36.4,
// the datum rule at DR-147 §11.146.2, `PLAN-G/2`).
//
// ═══════════════════════════════════════════════════════════════════════
// A FLOOR, NEVER A LENGTH, AND THE DIFFERENCE IS THE WHOLE FEATURE
// ═══════════════════════════════════════════════════════════════════════
// Straight-line pin-to-pin distance on a calibrated plan is ALWAYS less
// than or equal to any real route, because structure decides the route and
// structure is discovered rather than designed (DR-020). So this number
// stays true whatever the framing turns out to be, and it is the only
// length statement a floorplan is entitled to make.
//
// It buys exactly one thing, and it is not the column: `LEN-001` and
// `LEN-002` can prove a VIOLATION from it, because a run whose floor
// already exceeds the limit cannot be rescued by any path. They can never
// prove compliance from it.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO CONSUMERS, ONE FUNCTION, AND NO COPY OF THE NUMBER ANYWHERE
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §4.1 requires the rules to read the bound "regardless of which
// tier printed", and the obvious shape for that is a second field on
// `ScheduleEntry` beside `length`. IT WAS WRITTEN AND CUT. `rules_cable.
// dart` takes a `RackDocument` and a `Link` and never builds a schedule,
// so it calls this function directly; the field would have had no reader
// and would have been this epic's fifth unreachable one. `schedule.dart`
// calls it too, for the tier. Two callers, one derivation, and nothing
// stored that could disagree with it.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DATUM IS THE RACK THIS RUN LANDS IN, NOT A RACK ON THIS PLAN
// ═══════════════════════════════════════════════════════════════════════
// DR-144 §11.143.3 left "which rack when two are pinned" to this chapter
// and DR-147 §11.146.2 settles it: the pin on the rack THIS LINK LANDS IN,
// and no bound at all when that rack carries no pin, even when another
// rack stands pinned on the same underlay. The nearest rack and the first
// rack were both refused. Each yields a bound more often and a WRONG one
// on any job with a head end and a satellite rack, which is the ordinary
// shape of this work; a distance to a rack the cable does not go to is not
// a weaker floor, it is another run's number wearing this one's authority.
//
// The rule pays for itself twice, because two exclusions fall out of it
// instead of being written down:
//
//   * A JUMPER has both ends in one rack, so no end is the field end and
//     nothing is the subject.
//   * A SUB-FEED has its ends in two racks, and a rack is the datum every
//     length is measured FROM rather than a thing lengths are measured to
//     (`plan_measurability.dart` holds the same rule for its count).
//
// "Exactly one end in a rack" is the whole gate, and both of those fail it
// without naming themselves.
//
// ═══════════════════════════════════════════════════════════════════════
// A NULL `riseAllowance` COSTS THE FLOOR NOTHING IT IS ENTITLED TO
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §4.1 gives the bound as the straight line "plus the location's
// `riseAllowance` if one is set", and that field is null on every location
// this product has ever written. A null contributes zero and THE RESULT IS
// STILL A TRUE LOWER BOUND, because dropping a non-negative term from a
// floor leaves a floor (DR-147 §11.146.6). That is not a G4 substitution
// and must not be "improved" into one: this paragraph is here so the next
// reader who notices the omission knows it was priced rather than missed.
//
// The allowance is read from THE SUBJECT'S OWN LOCATION, the outlet's or
// the off-rack device's, and not from `ScheduleEntry.roomId`. The rise is
// a fact about where the device is, and the row's room falls back through
// a chain that can land on the far end's location.
//
// ═══════════════════════════════════════════════════════════════════════
// ROUNDED ONCE, BECAUSE `PlanScale` ROUNDS ONCE
// ═══════════════════════════════════════════════════════════════════════
// `lengthBetween` performs the single conversion and the single round
// (`plan.dart`'s header: half away from zero, at the boundary, never per
// segment). Adding the allowance afterwards is integer addition in
// nanometres and introduces no second rounding, so two machines given the
// same file agree on the same nanometre (CR-001, CR-117).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY REFUSAL IS `null` AND THE REASONS ARE NOT ENUMERATED
// ═══════════════════════════════════════════════════════════════════════
// Six distinct situations yield no floor: no conductors, not exactly one
// rack end, an unpinned rack, an unpinned subject, two underlays, and no
// usable scale. A `PlanBoundRefusal` naming them was written and cut,
// because it would have had ZERO readers in `lib/` and would have been
// this epic's fifth modelled thing nothing can reach (DR-140, DR-143,
// DR-144, DR-146). The tests name the case they exercise by building it.
// `PLN-003` is the surface that reports a reason, it reads per underlay,
// and it is `PLAN-I`'s.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/endpoint_resolution.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The plan-derived lower bound for [link], or null when none derives.
///
/// `Len.zero` is a legal answer and is NOT a refusal: two pins in the same
/// place is a measured zero (G4, CR-114), which is what a device pinned on
/// top of the rack really is.
Len? planLowerBoundOf(RackDocument doc, Link link) {
  // A LINK'S ENDS ARE ITS CONDUCTORS' ENDS, and CR-014 gives every
  // conductor of one cable the same physical pair, so the first speaks for
  // the link. The identical assumption `_row` and `linkClassOf` make,
  // spelled the same way so the three cannot drift.
  final conductors = link.conductors;
  if (conductors.isEmpty) return null;
  final first = conductors.first;

  final rackFrom = rackOfEndpoint(doc, first.from);
  final rackTo = rackOfEndpoint(doc, first.to);
  // EXACTLY ONE. See the file header: this one condition excludes the
  // jumper, the sub-feed and the field-to-field run without naming them.
  if ((rackFrom == null) == (rackTo == null)) return null;
  final rackId = (rackFrom ?? rackTo)!;
  final fieldEnd = rackFrom == null ? first.from : first.to;

  final rackPin = doc.racks[rackId]?.planPin;
  if (rackPin == null) return null;

  final subject = _subjectOf(doc, link, fieldEnd);
  if (subject == null) return null;
  if (subject.pin.underlayId != rackPin.underlayId) return null;

  // ONE PREDICATE FOR FOUR REFUSALS, and it is the model's own. A pin may
  // name an underlay this document no longer holds, since `read never
  // throws` (CR-093) lets a hand-edited file carry one; the underlay may
  // hold no scale; and a stored scale whose two points coincide yields no
  // factor, which `PlanUnderlay.isCalibrated` reports as uncalibrated
  // (DR-146 §11.145.1). `lengthBetween` returns null in exactly the cases
  // `isCalibrated` is false, so asking it once cannot disagree with the
  // flag the underlay row prints.
  final scale = doc.underlays[rackPin.underlayId]?.scale;
  final line = scale?.lengthBetween(rackPin.at, subject.pin.at);
  if (line == null) return null;

  final rise = doc.locations[subject.locationId]?.riseAllowance;
  return rise == null ? line : line + rise;
}

/// What this run's field end is pinned as, or null when nothing there is.
///
/// **THE OUTLET WINS AND DOES NOT FALL BACK.** When
/// `StructureOrigin.outletId` names a box, that box IS where this cable
/// stops, so a pinned device beyond it is a different point on the plan and
/// measuring to it would be measuring a cable this document does not have.
/// `outletId` null is *"nobody has said which box"* and `boxless` is
/// *"there is no box"* (`structure_body.dart`); both leave the field
/// endpoint as the last thing the cable reaches, so both fall through to
/// the device.
_Subject? _subjectOf(RackDocument doc, Link link, Endpoint fieldEnd) {
  final outletId = link.structureOrigin?.outletId;
  if (outletId != null) {
    final outlet = doc.outlets[outletId];
    final pin = outlet?.planPin;
    return pin == null ? null : _Subject(pin, outlet!.locationId);
  }
  // ONLY AN OFF-RACK DEVICE CARRIES A PIN, the same enumeration
  // `unpinnedCarriersFor` and `planMeasurabilityOf` make: the other four
  // placement variants have no `planPin` field to read.
  if (fieldEnd is! PortEndpoint) return null;
  final deviceId = doc.ports[fieldEnd.portId]?.deviceId;
  final placement = deviceId == null ? null : doc.devices[deviceId]?.placement;
  if (placement is! OffRackPlacement) return null;
  final pin = placement.planPin;
  return pin == null ? null : _Subject(pin, placement.locationId);
}

@immutable
final class _Subject {
  const _Subject(this.pin, this.locationId);

  final PlanPin pin;

  /// Whose `riseAllowance` applies. See the file header on why this is the
  /// subject's own location and not the schedule row's room.
  final Uuid? locationId;
}
