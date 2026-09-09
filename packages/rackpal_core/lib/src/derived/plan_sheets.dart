// rackpal_core/src/derived/plan_sheets.dart — which underlays earn a
// `T1.01` (docs/15 §8, DR-149 §11.148, `PLAN-H/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// A PIN IS WHAT MAKES A PLAN A DRAWING RATHER THAN A PICTURE
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §8: one sheet per `PlanUnderlay` **that carries at least one
// pin**. An imported-but-unused underlay prints nothing, and the reason is
// the same one docs/15 §7 gives for making an unresolvable image throw
// rather than draw nothing: *"a `T1.01` that is a title block over white
// paper is indistinguishable from a plan with no drops on it."* A plan
// nobody has pinned anything to is exactly that sheet, and emitting it
// would put a page in a client deliverable that says nothing and costs a
// sheet number.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY CARRIER COUNTS, INCLUDING THE RACK, AND THAT DIVERGES FROM
// `plan_measurability.dart` ON PURPOSE
// ═══════════════════════════════════════════════════════════════════════
// That file counts SUBJECTS: outlets and off-rack devices, never a rack,
// because a rack is the datum every length is measured from and counting
// it would make a number move at the moment of a calibration
// (DR-146 §11.145.5, DR-147 §11.146.2).
//
// The question here is different and so is the answer. This asks whether
// there is anything on the paper worth printing, and **a plan showing only
// the head end is a drawing**: it tells an installer which room the rack is
// in, which is the first thing a stranger to the building needs. So the
// predicate is "any carrier", and the two functions disagreeing is the
// two questions differing rather than one of them being wrong.
//
// ═══════════════════════════════════════════════════════════════════════
// IT RETURNS UNDERLAYS AND NOT A COUNT
// ═══════════════════════════════════════════════════════════════════════
// `SheetSet.forRacks` needs the identity and the name of each survivor to
// build a `SheetDef`, and it sorts them itself on `order` then `id`. A
// count would make the caller re-derive the membership to find out WHICH
// ones, which is how two answers to one question get built.
import 'package:rackpal_core/src/draw/scene/plan_scene.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Every underlay in [doc] that carries at least one pin.
///
/// Unordered: `SheetSet.forRacks` applies the sheet order. Returning them
/// in `doc.underlays` order would be a `Map` iteration order leaking into
/// a deliverable (§8.4), and the sort that fixes it belongs beside the
/// numbering that depends on it.
List<PlanUnderlay> planUnderlaysWithPins(RackDocument doc) {
  final pinned = <String>{};

  for (final rack in doc.racks.values) {
    final pin = rack.planPin;
    if (pin != null) pinned.add(pin.underlayId.v);
  }
  for (final outlet in doc.outlets.values) {
    final pin = outlet.planPin;
    if (pin != null) pinned.add(pin.underlayId.v);
  }
  for (final device in doc.devices.values) {
    // ONLY AN OFF-RACK DEVICE CARRIES A PIN — the same enumeration
    // `unpinnedCarriersFor`, `planMeasurabilityOf` and `planLowerBoundOf`
    // make, and for the same reason: the other four placement variants
    // have no `planPin` field to read.
    final placement = device.placement;
    if (placement is! OffRackPlacement) continue;
    final pin = placement.planPin;
    if (pin != null) pinned.add(pin.underlayId.v);
  }

  return [
    for (final underlay in doc.underlays.values)
      if (pinned.contains(underlay.id.v)) underlay,
  ];
}

/// Every pin standing on [underlayId], as the scene sees them.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE QUERY `buildPlanScene` REFUSED TO OWN, WRITTEN ONCE
/// ═══════════════════════════════════════════════════════════════════════
/// That builder takes a flat `Iterable<PlanPinSubject>` on purpose: *"the
/// pins on one underlay come from three different collections and
/// resolving them is a query, not a drawing decision, so it happens once
/// at the call site."* It happened at ONE call site while the only caller
/// was the editor. `T1.01` is the second, and two hand-rolled gathers
/// would be the two-builders failure docs/08 §3.1 keeps naming, so the
/// query moves here rather than being written again.
///
/// **ORDERED, BECAUSE A DISPLAY LIST IS COMPARED BYTE FOR BYTE.** The three
/// collections are `Map`s and iterating them in their own order would put
/// `Map` iteration order into an exported document (§8.4). Sorted by
/// entity id, which is unique by construction, so the chain is total.
List<PlanPinSubject> planPinsFor(RackDocument doc, Uuid underlayId) {
  final out = <PlanPinSubject>[];

  void take(Uuid id, PlanPin? pin, PlanPinCarrier carrier) {
    if (pin == null || pin.underlayId != underlayId) return;
    out.add(PlanPinSubject(entityId: id, at: pin.at, carrier: carrier));
  }

  for (final rack in doc.racks.values) {
    take(rack.id, rack.planPin, PlanPinCarrier.rack);
  }
  for (final outlet in doc.outlets.values) {
    take(outlet.id, outlet.planPin, PlanPinCarrier.outlet);
  }
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is! OffRackPlacement) continue;
    take(device.id, placement.planPin, PlanPinCarrier.device);
  }

  out.sort((a, b) => a.entityId.v.compareTo(b.entityId.v));
  return out;
}
