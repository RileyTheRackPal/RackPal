// rackpal_core/src/derived/plan_measurability.dart — what a calibration
// makes measurable, and why nothing is when nothing is (docs/15 §5,
// DR-144 §11.143.3, PLAN-F/2).
//
// ═══════════════════════════════════════════════════════════════════════
// IT COUNTS PINS AND PRODUCES NO `Len`, WHICH IS THE WHOLE BOUNDARY
// ═══════════════════════════════════════════════════════════════════════
// `PLAN-F/2`'s brief asks that a recalibration changing N lengths says N.
// **At `PLAN-F` there are no derived lengths at all**: `planLowerBound` is
// not a `ScheduleLengthSource` value, nothing derives one, and docs/15 §6's
// own pin-drag row forward-dates its recompute clause to `PLAN-G`. A report
// counting schedule rows would print `0` on every calibration in the
// product, which is a G4 report whose number is an artifact of what has not
// been built.
//
// So DR-144 §11.143.3 rules the count to be of **measurable pins**, and
// rules that this derivation **must not produce a `Len`**. One per pin
// would be `planLowerBound` shipped early under another name, without the
// rank, the `>=` prefix, the italic, the rollup exclusion or `LEN-001`'s
// reading, which are five decisions DR-037 §11.36.4 already took and
// `PLAN-G` owns.
//
// **THE TEST FOR THAT BOUNDARY IS A PROPERTY, NOT A COMMENT**: moving every
// pin to a different place must not change a single number here, because
// this file asks whether a length is DERIVABLE and never what it is.
// `plan_measurability_test.dart` asserts exactly that.
//
// ═══════════════════════════════════════════════════════════════════════
// WHICH RACK IS THE DATUM IS NOT DECIDED HERE
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §4.1 gives the bound as *"rack pin to device pin"* and does not
// say which rack when a document has several. DR-144 §11.143.3 leaves that
// to the chapter that derives the number. This one asks only whether a
// datum EXISTS, so a plan with two pinned racks counts the same as a plan
// with one.
//
// **RACKS ARE THE DATUM AND NOT THE SUBJECT**, so a pinned rack is not
// itself counted as measurable. A rack's distance from another rack is a
// real thing a sub-feed might want, and docs/15 §4.1 does not describe it;
// counting it here would answer a question nobody has asked in a number
// somebody would read as drops.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// The first reason no length derives on a plan, or absent when one does.
///
/// **ORDERED, AND THE ORDER IS THE REMEDY'S.** A plan can be uncalibrated
/// AND rackless AND empty at once; naming all three at a person would be a
/// list of chores rather than a next step. The order below is the order the
/// work is actually done in, so the reason reported is always the one to
/// act on now.
enum PlanBlocker {
  /// No scale, or one that cannot yield a factor (`PlanScale.isUsable`).
  uncalibrated,

  /// Calibrated, but no rack stands on this plan, so there is nothing to
  /// measure FROM. `PLN-003` is the advisory `PLAN-I` builds for this.
  noRackPinned,

  /// Calibrated with a rack, and nothing else is pinned here yet.
  noPins,
}

/// What a calibration on one underlay has made measurable.
@immutable
final class PlanMeasurability {
  const PlanMeasurability({
    required this.isCalibrated,
    required this.rackPinned,
    required this.measurableCount,
    required this.pinnedCarrierCount,
  });

  /// The underlay carries a scale that can yield a factor.
  ///
  /// **`PlanUnderlay.isCalibrated`, NOT `scale != null`.** A scale whose
  /// two points coincide is stored, and is useless: reporting it as
  /// calibrated would promise a length the model refuses to derive.
  final bool isCalibrated;

  /// At least one rack is pinned on this underlay.
  final bool rackPinned;

  /// How many pins on this underlay a length could be derived for.
  ///
  /// Zero whenever [blockedBy] is set. Never a `Len` and never a sum: see
  /// the file header.
  final int measurableCount;

  /// Every pin on this underlay, racks included.
  ///
  /// **A SECOND COUNT AND NOT A DERIVED ONE**, because the two answer
  /// different questions and `UnpinnedCarriers` draws the same
  /// distinction: `measurableCount` is what a calibration bought, and this
  /// is what stands on the plan at all. On an uncalibrated plan with forty
  /// pins the first is 0 and the second is 40, and a surface that had only
  /// the first would report a fully pinned plan as empty.
  final int pinnedCarrierCount;

  /// The first thing standing between this plan and a length, or null
  /// when nothing is.
  PlanBlocker? get blockedBy {
    if (!isCalibrated) return PlanBlocker.uncalibrated;
    if (!rackPinned) return PlanBlocker.noRackPinned;
    if (measurableCount == 0) return PlanBlocker.noPins;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanMeasurability &&
      other.isCalibrated == isCalibrated &&
      other.rackPinned == rackPinned &&
      other.measurableCount == measurableCount &&
      other.pinnedCarrierCount == pinnedCarrierCount;

  @override
  int get hashCode => Object.hash(
    isCalibrated,
    rackPinned,
    measurableCount,
    pinnedCarrierCount,
  );

  @override
  String toString() =>
      'PlanMeasurability(calibrated: $isCalibrated, rack: $rackPinned, '
      'measurable: $measurableCount of $pinnedCarrierCount)';
}

/// What [underlay] can measure, given what is pinned on it.
PlanMeasurability planMeasurabilityOf(
  RackDocument doc,
  PlanUnderlay underlay,
) {
  final id = underlay.id;
  var racks = 0;
  var others = 0;

  for (final rack in doc.racks.values) {
    if (rack.planPin?.underlayId == id) racks++;
  }
  for (final outlet in doc.outlets.values) {
    if (outlet.planPin?.underlayId == id) others++;
  }
  for (final device in doc.devices.values) {
    final placement = device.placement;
    // ONLY AN OFF-RACK DEVICE CARRIES A PIN, which is the same
    // enumeration `unpinnedCarriersFor` makes and for the same reason:
    // the other four placement variants have no `planPin` field to read.
    if (placement is! OffRackPlacement) continue;
    if (placement.planPin?.underlayId == id) others++;
  }

  final calibrated = underlay.isCalibrated;
  final hasRack = racks > 0;
  return PlanMeasurability(
    isCalibrated: calibrated,
    rackPinned: hasRack,
    // GATED ON BOTH, so the count is never a promise the plan cannot keep.
    // A calibrated plan with no rack has no datum and derives nothing
    // (`PLN-003`); an uncalibrated plan with a rack has no factor.
    measurableCount: calibrated && hasRack ? others : 0,
    pinnedCarrierCount: racks + others,
  );
}
