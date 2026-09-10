// rackpal_core/src/derived/unpinned_carriers.dart — what the Plan view's
// unpinned strip lists (docs/15 §6, DR-140 §11.139, DR-142 §11.141).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE SENTENCE, FOUR DECISIONS, AND THE BRIEF NAMED THE CLASS OF ALL FOUR
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6: *"a strip along the bottom lists everything in this plan's
// location that could carry a pin and does not, with a count."*
//
// `PLAN-E/4`'s brief warns about **the count that counts the wrong
// thing**, citing the status bar that read `0 pathways` the keystroke
// after somebody made one because it counted only pathways with drops in
// them. DR-140 then supplied a second instance deliberately: a strip
// built from `doc.devices` gets the number wrong on any document with an
// unpinned rack. Reading the model produced two more. **The warning was
// right about the class and had no way to name the members**, which is
// what a decomposition pass is for.
//
//   1. CARRIERS, NOT DEVICES (DR-140). A rack, an outlet and an off-rack
//      device each carry a pin, and the rack's is the one docs/15 §3.4
//      calls "not optional to the design".
//   2. UNPINNED IS NO PIN AT ALL, never "no pin on THIS underlay". See
//      below: the alternative is not a wrong row, it is a destructive
//      gesture.
//   3. AN UNDERLAY WITH NO LOCATION HAS NO FILTER, so a site plan lists
//      everything unpinned. Matching its null against a carrier's null
//      would be the unknown-equals-unknown join G4 forbids.
//   3a. AND THE FILTER IS THE SUBTREE, WHICH IT WAS NOT UNTIL `PLAN-I`
//      (DR-154 §11.153.7a). It compared locations for EQUALITY, and
//      docs/15 §3.1 says an underlay's location is "usually a floor":
//      an outlet filed in `Great Room` under `Level 1` matched neither
//      the scope nor the unknown branch, so it was dropped by a
//      comparison and appeared in no count at all. That is exactly the
//      failure [UnpinnedCarriers.unlocatedCount] was written to prevent,
//      arriving through the door beside the one it was watching.
//   4. A CARRIER WHOSE OWN LOCATION IS UNKNOWN IS A COUNT, NOT A ROW
//      (CR-114), so [UnpinnedCarriers.unlocatedCount] exists and every
//      surface showing the rows shows that number too.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY "UNPINNED HERE" IS NOT AVAILABLE, AND IS NOT A NEAR MISS
// ═══════════════════════════════════════════════════════════════════════
// A carrier holds exactly ONE `planPin` and a `PlanPin` names the
// underlay it stands on. So there is no state in which a device is
// pinned on `Level 1` and unpinned on `Level 2`: it is pinned, once,
// somewhere. A strip listing it while `Level 2` is open would offer a
// drag whose real effect is to MOVE the pin off `Level 1`, silently, as
// the answer to a gesture that presented itself as adding something.
//
// The cost is real and is not hidden: on a two-plan project, `Level 2`'s
// strip reads zero while `Level 2` has no pins on it. **That is the
// truth**, and the emptiness is visible on the canvas the strip sits
// under.
//
// ═══════════════════════════════════════════════════════════════════════
// A DEVICE'S ROOM IS `OffRackPlacement.locationId`, AND ASKING WHICH ONE
// FOUND A DEFECT
// ═══════════════════════════════════════════════════════════════════════
// `DeviceInstance.locationId` and `OffRackPlacement.locationId` are
// different fields holding the same value: `AddStructureCommand` writes
// both and `RemoveLocationCommand` clears both, because (the model's own
// words) "clearing one would leave the document disagreeing with itself".
//
// This file reads the PLACEMENT's, which is the field sitting beside the
// pin it is asking about. That choice is pinned by a test on a document
// where the two disagree, so the next reader sees which was taken rather
// than inferring it.
//
// **Asking the question is what found `buildPlaceOnPlanCommand` setting
// only one of them** (DR-142 §11.141.5). That is fixed in
// `AddDeviceCommand`, and this file would have been right about half the
// documents either way until it was.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/plan_commands.dart' show PinCarrier;
import 'package:rackpal_core/src/derived/location_tree.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One thing that could be on this plan and is not.
@immutable
final class UnpinnedCarrier {
  const UnpinnedCarrier({
    required this.entityId,
    required this.carrier,
    required this.designator,
    this.name,
  });

  final Uuid entityId;

  /// Which collection a pin on this row would be written into.
  ///
  /// `PinCarrier` AND NOT A THIRD ENUM. This package already carries two
  /// (`PinCarrier` for the writer, `PlanPinCarrier` for the drawing), and
  /// a row's whole downstream purpose is to become a
  /// `SetPlanPinCommand`, so it names the writer's.
  final PinCarrier carrier;

  /// The identifying string: `RK-1`, `D-014`. Never empty in practice and
  /// never null, because every carrier in this document has one.
  final String designator;

  /// A human label beside the designator, or null when the entity has no
  /// such field. G4: an `Outlet` has a designation and no name, and an
  /// empty string there would read as "named, with nothing in it".
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is UnpinnedCarrier &&
      other.entityId == entityId &&
      other.carrier == carrier &&
      other.designator == designator &&
      other.name == name;

  @override
  int get hashCode => Object.hash(entityId, carrier, designator, name);

  @override
  String toString() => 'UnpinnedCarrier(${carrier.name} $designator)';
}

/// What the unpinned strip shows for one underlay, and what it could not
/// place.
@immutable
final class UnpinnedCarriers {
  const UnpinnedCarriers({required this.rows, required this.unlocatedCount});

  /// In a total order: rack, then outlets, then off-rack devices, each
  /// band by designator and ties broken by id.
  ///
  /// THE RACK LEADS, and that is not tidiness. `PLN-003` fires when an
  /// underlay has device pins and no rack pin, because a home run is
  /// measured FROM the rack, so the one row whose absence costs every
  /// length on the plan is the row nobody should have to scroll to.
  /// **The order is the user's to change** (canon §11.139.6 left it
  /// open); this is a default, and it is one comparator in one place.
  final List<UnpinnedCarrier> rows;

  /// How many unpinned carriers were left out because their own location
  /// is unknown.
  ///
  /// G4/CR-114, and the alternatives are both defects this corpus has
  /// already shipped once. A ROW would invite pinning a second-floor
  /// speaker onto `Level 1` and calling it placed. SILENCE is the
  /// `0 pathways` status bar: a number that flatters by counting only
  /// what it can see.
  ///
  /// **Zero when the underlay has no location**, because then nothing is
  /// filtered out at all and there is nothing to report. This counts what
  /// is missing from [rows], not what is unlocated in the document.
  final int unlocatedCount;

  /// The count the strip prints. `rows.length`, named so a caller does
  /// not have to decide whether [unlocatedCount] is part of it. It is
  /// not: they are two answers to two questions, as `PathwayTable`'s two
  /// counts are.
  int get count => rows.length;
}

/// Everything that could carry a pin on [underlay] and does not.
UnpinnedCarriers unpinnedCarriersFor(RackDocument doc, PlanUnderlay underlay) {
  final scope = underlay.locationId;
  final rows = <UnpinnedCarrier>[];
  var unlocated = 0;

  // A CARRIER IS IN SCOPE WHEN THE PLAN NAMES NO ROOM (there is no
  // filter), or when the carrier's room is the plan's room OR ANY ROOM
  // UNDER IT. A null carrier location never matches a named plan:
  // unknown is not a value and two unknowns are not each other (G4).
  //
  // THE SUBTREE IS BUILT ONCE, and only when there is a scope to walk.
  // `LocationTree.of` reads every location in the document, which is
  // wasted work on a site plan that filters nothing.
  final inScope = scope == null
      ? const <Uuid>{}
      : LocationTree.of(doc).subtreeOf(scope).toSet();

  bool take(Uuid? where) {
    if (scope == null) return true;
    if (where == null) {
      unlocated++;
      return false;
    }
    return inScope.contains(where);
  }

  for (final rack in doc.racks.values) {
    if (rack.planPin != null) continue;
    if (!take(rack.locationId)) continue;
    rows.add(
      UnpinnedCarrier(
        entityId: rack.id,
        carrier: PinCarrier.rack,
        designator: rack.designator,
        name: rack.name,
      ),
    );
  }
  for (final outlet in doc.outlets.values) {
    if (outlet.planPin != null) continue;
    if (!take(outlet.locationId)) continue;
    rows.add(
      UnpinnedCarrier(
        entityId: outlet.id,
        carrier: PinCarrier.outlet,
        designator: outlet.designation,
      ),
    );
  }
  for (final device in doc.devices.values) {
    // ONLY AN OFF-RACK DEVICE CARRIES A PIN. A rail, shelf or 0U
    // placement says where the device is with a rack, a U and a face, and
    // `StagedPlacement` says it is nowhere yet; none of the four has a
    // `planPin` field to be null, so none of them is a carrier and none
    // belongs in this count.
    final placement = device.placement;
    if (placement is! OffRackPlacement) continue;
    if (placement.planPin != null) continue;
    if (!take(placement.locationId)) continue;
    rows.add(
      UnpinnedCarrier(
        entityId: device.id,
        carrier: PinCarrier.offRackDevice,
        designator: device.designator,
        name: device.name,
      ),
    );
  }

  // TOTAL, because `Map` iteration is insertion order and a document
  // reopened from disk enumerates differently from the one just built.
  // Dart's `List.sort` is not stable, so the chain ends in the id.
  rows.sort((a, b) {
    final byCarrier = a.carrier.index.compareTo(b.carrier.index);
    if (byCarrier != 0) return byCarrier;
    final byDesignator = a.designator.compareTo(b.designator);
    if (byDesignator != 0) return byDesignator;
    return a.entityId.v.compareTo(b.entityId.v);
  });

  return UnpinnedCarriers(rows: rows, unlocatedCount: unlocated);
}
