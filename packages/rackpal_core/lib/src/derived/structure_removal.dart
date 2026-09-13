// rackpal_core/src/derived/structure_removal.dart — pure Dart.
//
// DR-160 §11.159 — what removing a wall plate or a whole Structure body
// actually costs, computed BEFORE anything is removed. Board `#877`.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE NUMBER, ONE SOURCE
// ═══════════════════════════════════════════════════════════════════════
// `device_removal.dart` states the rule, `location_removal.dart` restates
// it and `template_removal.dart` restates it again: the number has to
// exist before the command runs, because it is what the user answers a
// dialog about, and the edit has to remove exactly what the number
// described. Two walks over the same document asking the same question is
// how the dialog and the edit drift apart.
//
// So the plan is computed HERE, once, and `structure_removal_txn.dart`
// consumes it rather than re-deriving its own.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THE CASCADE IS ASYMMETRIC, WHICH IS THE MODEL AND NOT A PREFERENCE
// ═══════════════════════════════════════════════════════════════════════
// DR-160 §11.159.4. A PLATE'S drops go because they cannot be re-homed:
// `StructureOrigin.outletId` is nullable and clearing it would leave a
// legal document, but `StructureOriginField` lists seven editable
// properties and `outletId` is not one of them, so the cable would sit on
// the Structure table with an empty box column forever.
//
// A BODY'S plates and drops go because they cannot exist without it.
// `Outlet.structureBodyId` and `StructureOrigin.structureBodyId` are both
// non-nullable and `final`, so neither can be repaired to point at a
// surviving panel or at none. Leaving them behind does not produce a
// document saying something true; it produces two classes of entity
// naming a body that is not there.
//
// A later reader who makes `outletId` editable should reopen §11.159.2.
// §11.159.3 is not theirs to reopen.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE UNITS, AND THE THIRD IS NOT DECORATION
// ═══════════════════════════════════════════════════════════════════════
// Plates, cables and PINS. `Outlet.planPin` is walked-site work: somebody
// stood in the room and dotted the floorplan, `plan_length.dart` derives a
// cable length from it, and it travels inside the outlet when the outlet
// goes. A count naming only cables would understate what a pinned plate
// costs, which is `LocationRemovalPlan`'s "two numbers in different units"
// argument arriving at a third.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/link_lookup.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One home run going, and the implicit `Net` that goes with it.
///
/// A PAIR RATHER THAN TWO PARALLEL LISTS, because the two are answered
/// together and a caller that indexed one against the other could get the
/// pairing wrong silently. `DeviceRemovalPlan` keeps its nets in a flat
/// list because `RemoveDeviceCommand` consumes the whole plan at once;
/// here each cable leaves through its own `RemoveLinkCommand`, which wants
/// its own answer.
@immutable
final class DropRemoval {
  const DropRemoval({required this.linkId, required this.netId});

  final Uuid linkId;

  /// The `Net` to take with this link, or NULL when another link still
  /// references it.
  ///
  /// [netToRemoveWith]'s answer, computed against the UNMUTATED document
  /// for every drop, which is what `matrix_plan.dart` already does when a
  /// cell count comes down. Two drops sharing one net therefore both
  /// answer null and the net is left ORPHANED rather than dangling:
  /// `RemoveLinkCommand` says which of those two is the lie, and it is
  /// the dangling one.
  final Uuid? netId;
}

/// Everything removing one wall plate takes with it (DR-160 §11.159.2).
///
/// Ids only. The commands hold the removed OBJECTS across their own
/// apply/revert boundary, which is how undo restores them unchanged, but a
/// plan is a question rather than a clipboard: a plan holding entities
/// would be a second place they could go stale.
@immutable
final class OutletRemovalPlan {
  const OutletRemovalPlan({
    required this.outletId,
    required this.drops,
    required this.hasPlanPin,
  });

  /// The empty plan for an outlet this document does not have.
  static const OutletRemovalPlan none = OutletRemovalPlan(
    outletId: Uuid(''),
    drops: <DropRemoval>[],
    hasPlanPin: false,
  );

  final Uuid outletId;

  /// Every home run landing on this plate, in document order.
  ///
  /// MEMBERSHIP IS `Link.structureOrigin.outletId` AND NOTHING ELSE,
  /// which is `computePlateFill`'s rule quoted verbatim. A second
  /// membership test here would be a second answer to a question
  /// `plate_fill.dart` already owns.
  final List<DropRemoval> drops;

  /// Whether this plate is dotted on a floorplan. See the file header for
  /// why a boolean earns a place beside two counts.
  final bool hasPlanPin;

  /// THE NUMBER THE DIALOG SAYS. Cables, not conductors and not
  /// endpoints: a `Link` is what an installer pulls and what occupies a
  /// row on the schedule.
  int get cableCount => drops.length;

  /// **A BARE PLATE IS NOT ASKED ABOUT.** DR-013 §11.13.2's last
  /// sentence, and DR-160 §11.159.5 applies it here: a prompt for a
  /// consequence-free delete is the nag that teaches people to click
  /// through prompts, including this one on the day it matters.
  bool get needsConfirmation => drops.isNotEmpty || hasPlanPin;

  bool get isEmpty => outletId.v.isEmpty;
}

/// Everything removing one Structure body takes with it (§11.159.3).
@immutable
final class StructureRemovalPlan {
  const StructureRemovalPlan({
    required this.bodyId,
    required this.deviceId,
    required this.outletPlans,
    required this.otherDrops,
  });

  /// The empty plan for a body this document does not have.
  static const StructureRemovalPlan none = StructureRemovalPlan(
    bodyId: Uuid(''),
    deviceId: null,
    outletPlans: <OutletRemovalPlan>[],
    otherDrops: <DropRemoval>[],
  );

  final Uuid bodyId;

  /// The paired `DeviceInstance`, or NULL when the body names one this
  /// document does not hold.
  ///
  /// NULLABLE EVEN THOUGH THE PAIRING IS 1:1. `structure_commands.dart`
  /// says neither half is valid alone and `AddStructureCommand` mints
  /// both, so null here is a fault rather than a state the app can
  /// produce. It is carried anyway because a plan that asserted the
  /// pairing would throw on a hand-edited file at the moment somebody was
  /// trying to get rid of the damage.
  final Uuid? deviceId;

  /// One plan per plate on this body, in document order.
  final List<OutletRemovalPlan> outletPlans;

  /// Home runs out of this body that no departing plate already carries.
  ///
  /// ORDINARILY THE BOXLESS ONES: a ceiling speaker gets no low-voltage
  /// box (DR-046, `#718`), and a run nobody has assigned to a plate yet
  /// has a null `outletId` meaning "nobody has said". Both come out of
  /// this panel and both go with it.
  ///
  /// It also catches the hand-edited case where a drop names a plate on
  /// some OTHER body, which is why the field is not called `boxless`: the
  /// set is defined by what is left over, not by what a person stated.
  final List<DropRemoval> otherDrops;

  /// How many plates go.
  int get outletCount => outletPlans.length;

  /// How many cables go, across every plate and the leftovers.
  ///
  /// The sets are disjoint by construction: a drop is in an outlet plan
  /// when its `outletId` names a departing plate, and in [otherDrops]
  /// when it does not.
  int get cableCount =>
      outletPlans.fold<int>(0, (n, plan) => n + plan.cableCount) +
      otherDrops.length;

  /// How many of the departing plates are dotted on a floorplan.
  int get pinnedOutletCount =>
      outletPlans.where((plan) => plan.hasPlanPin).length;

  /// **ALWAYS TRUE FOR A BODY THIS DOCUMENT HAS**, which is where this
  /// departs from [OutletRemovalPlan] one field above it, and from
  /// `DeviceRemovalPlan` and `LocationRemovalPlan` (DR-160 §11.159.5).
  /// An empty panel is still the container the tab is named for, and
  /// re-creating one is a different order of work from re-typing a drop.
  bool get needsConfirmation => !isEmpty;

  bool get isEmpty => bodyId.v.isEmpty;
}

/// What removing [outletId] from [doc] would take with it.
///
/// Returns [OutletRemovalPlan.none] when the document has no such outlet,
/// which is a reachable and normal state (a stale selection, a second
/// delete arriving after an undo) and not an error.
OutletRemovalPlan planOutletRemoval(RackDocument doc, Uuid outletId) {
  final outlet = doc.outlets[outletId];
  if (outlet == null) return OutletRemovalPlan.none;

  return OutletRemovalPlan(
    outletId: outletId,
    drops: List<DropRemoval>.unmodifiable(_dropsOn(doc, outletId)),
    hasPlanPin: outlet.planPin != null,
  );
}

/// What removing the Structure body [bodyId] from [doc] would take.
///
/// Returns [StructureRemovalPlan.none] when the document has no such
/// body, for [planOutletRemoval]'s reason.
StructureRemovalPlan planStructureRemoval(RackDocument doc, Uuid bodyId) {
  final body = doc.structures[bodyId];
  if (body == null) return StructureRemovalPlan.none;

  final outletIds = <Uuid>[
    for (final entry in doc.outlets.entries)
      if (entry.value.structureBodyId == bodyId) entry.key,
  ];
  final departing = outletIds.toSet();

  return StructureRemovalPlan(
    bodyId: bodyId,
    // NOT `body.deviceId` STRAIGHT THROUGH. The plan reports the device
    // it will actually find, so a body whose pairing is already broken
    // says so instead of naming a row that is not there.
    deviceId: doc.devices.containsKey(body.deviceId) ? body.deviceId : null,
    outletPlans: List<OutletRemovalPlan>.unmodifiable([
      for (final id in outletIds) planOutletRemoval(doc, id),
    ]),
    otherDrops: List<DropRemoval>.unmodifiable([
      for (final entry in doc.links.entries)
        if (entry.value.structureOrigin case final origin?)
          if (origin.structureBodyId == bodyId &&
              !departing.contains(origin.outletId))
            DropRemoval(
              linkId: entry.key,
              netId: netToRemoveWith(doc, entry.key),
            ),
    ]),
  );
}

/// Every home run landing on [outletId], paired with the net each takes.
List<DropRemoval> _dropsOn(RackDocument doc, Uuid outletId) => [
  for (final entry in doc.links.entries)
    if (entry.value.structureOrigin?.outletId == outletId)
      DropRemoval(linkId: entry.key, netId: netToRemoveWith(doc, entry.key)),
];
