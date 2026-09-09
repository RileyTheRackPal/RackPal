// rackpal_core/src/derived/plan_measurability.dart — what a calibration
// makes measurable, and why nothing is when nothing is (docs/15 §5,
// DR-144 §11.143.3, PLAN-F/2; the population and `PLN-001`'s sentence at
// DR-146 §11.145, PLAN-F/3).
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
//
// ═══════════════════════════════════════════════════════════════════════
// ONE POPULATION IN BOTH DIRECTIONS (DR-146 §11.145.5, PLAN-F/3)
// ═══════════════════════════════════════════════════════════════════════
// What is STORED is [PlanMeasurability.subjectPinCount], the pins a length
// could be derived for whether or not one currently can be. Everything
// else about the count is derived from it and the two booleans beside it.
//
// `PLAN-F/2` stored `measurableCount` next to the flags that decide it and
// carried a second field, `pinnedCarrierCount`, holding racks plus
// subjects. **DR-146 replaced that field rather than adding to it.** The
// underlay row is its only caller and it needs the number to mean the same
// thing before and after a calibration: thirty-nine unmeasurable becoming
// `39 measurable` is the honest pair, and forty becoming thirty-nine reads
// as a pin the calibration ate. The rack is the datum on both sides
// (§11.143.3) and belongs in neither number.
//
// Storing the subject count and deriving the rest also makes the gate
// unspellable in more than one place: a constructor taking a
// `measurableCount` could be handed a number its own flags forbid.
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
    required this.subjectPinCount,
  });

  /// The underlay carries a scale that can yield a factor.
  ///
  /// **`PlanUnderlay.isCalibrated`, NOT `scale != null`.** A scale whose
  /// two points coincide is stored, and is useless: reporting it as
  /// calibrated would promise a length the model refuses to derive.
  final bool isCalibrated;

  /// At least one rack is pinned on this underlay.
  final bool rackPinned;

  /// The pins on this underlay a length could be derived FOR, whether or
  /// not one currently can be.
  ///
  /// **THE ONE STORED COUNT** (DR-146 §11.145.5). Outlets and off-rack
  /// devices; never a rack, which is the datum every length is measured
  /// from and is a subject of nothing. It does not move when a
  /// calibration lands, which is exactly what makes it the number the
  /// underlay row prints on both sides of one.
  final int subjectPinCount;

  /// How many pins on this underlay a length could be derived for NOW.
  ///
  /// Zero whenever [blockedBy] is set, and [subjectPinCount] when nothing
  /// blocks. Never a `Len` and never a sum: see the file header.
  ///
  /// **GATED ON BOTH FACTS**, so the count is never a promise the plan
  /// cannot keep. A calibrated plan with no rack has no datum and derives
  /// nothing (`PLN-003`); an uncalibrated plan with a rack has no factor.
  int get measurableCount => isCalibrated && rackPinned ? subjectPinCount : 0;

  /// How many pins stand on this plan carrying no measurable position.
  ///
  /// The complement of [measurableCount] over the same population, so the
  /// two always sum to [subjectPinCount] and neither can be read as the
  /// other's total. This is the number `PLN-001` reports (docs/15 §9) and
  /// the number the underlay row prints while a plan is uncalibrated.
  int get unmeasurablePinCount => subjectPinCount - measurableCount;

  /// The first thing standing between this plan and a length, or null
  /// when nothing is.
  PlanBlocker? get blockedBy {
    if (!isCalibrated) return PlanBlocker.uncalibrated;
    if (!rackPinned) return PlanBlocker.noRackPinned;
    if (measurableCount == 0) return PlanBlocker.noPins;
    return null;
  }

  // EQUALITY IS OVER THE STORED FIELDS ONLY, which is not a shortcut:
  // every derived member above is a total function of these three, so two
  // instances agreeing on them agree on everything.
  @override
  bool operator ==(Object other) =>
      other is PlanMeasurability &&
      other.isCalibrated == isCalibrated &&
      other.rackPinned == rackPinned &&
      other.subjectPinCount == subjectPinCount;

  @override
  int get hashCode => Object.hash(isCalibrated, rackPinned, subjectPinCount);

  @override
  String toString() =>
      'PlanMeasurability(calibrated: $isCalibrated, rack: $rackPinned, '
      'measurable: $measurableCount of $subjectPinCount)';
}

/// docs/15 §9's `PLN-001` sentence, or null when nothing is stranded.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SENTENCE IS CORE'S, AND THE PACKAGE BOUNDARY IS THE REASON
/// ═══════════════════════════════════════════════════════════════════════
/// DR-146 §11.145.6: `PLN-001` is a validation rule and rules live in this
/// package; the underlay row that prints the same fact today lives in
/// `rackpal_ui`. A sentence written on the surface would have to be COPIED
/// into core when `PLAN-I` files the finding, and a copied sentence
/// disagrees with its original the first time somebody edits one of them.
/// So it is written once, beside the count it reports, and the row
/// composes it.
///
/// **NULL RATHER THAN A ZERO SENTENCE.** `0 pins carry no measurable
/// position` is true of an empty plan and tells nobody anything, which is
/// the `Calibrated · 0 measurable` DR-144 §11.143.3 already refused one
/// state later. The caller prints the bare state instead.
///
/// **NO TRAILING STOP**, because the row appends it to a state line and a
/// finding will wrap it in a sentence of its own.
///
/// The plural is HAND-WRITTEN, on `PLAN-F/2`'s finding: `1 pins` is the
/// `0 pathways` status bar this repository has already shipped once.
String? unmeasurablePinsSentence(PlanMeasurability m) {
  final n = m.unmeasurablePinCount;
  if (n <= 0) return null;
  return n == 1
      ? '1 pin carries no measurable position'
      : '$n pins carry no measurable position';
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

  return PlanMeasurability(
    isCalibrated: underlay.isCalibrated,
    rackPinned: racks > 0,
    // THE SUBJECTS, UNGATED. What a calibration can buy is decided by the
    // two flags above and derived from them, so this stays a plain count
    // of what stands on the plan and is comparable across a calibration.
    subjectPinCount: others,
  );
}
