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
    out.add(
      PlanPinSubject(
        entityId: id,
        at: pin.at,
        carrier: carrier,
        domain: planPinDomainFor(doc, id, carrier),
      ),
    );
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

/// What the thing on the end of a pin mostly IS, or null when nobody has
/// said (`#901`, DR-169 §11.168.4).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THREE CARRIERS, THREE LOOKUPS, AND ONE OF THEM IS DELIBERATELY NONE
/// ═══════════════════════════════════════════════════════════════════════
/// A **device** reads its template's `primaryDomain` out of the document's
/// own template shelf, so a project carries the answer that was current
/// when the device was placed rather than whatever the catalogue says now.
/// An **outlet** reads the recipe it was made from, through its nullable
/// `outletTemplateId`: an outlet built by hand, or one whose template has
/// been removed from the registries, has no domain and that is honest.
/// A **rack** has none at all. It is the datum every length on the plan is
/// measured from (`PLN-003`), not a ninth domain (§11.168.8).
///
/// **THIS EXISTS BECAUSE THERE ARE TWO PIN GATHERS.** `planPinsFor` is
/// this package's and `pinsOnUnderlay` is the editor's, and the header
/// above already records what a second hand-rolled gather costs. The
/// resolution at least is written once, so the sheet and the screen cannot
/// disagree about what colour a mark is.
SignalDomainId? planPinDomainFor(
  RackDocument doc,
  Uuid entityId,
  PlanPinCarrier carrier,
) {
  switch (carrier) {
    case PlanPinCarrier.rack:
      return null;
    case PlanPinCarrier.outlet:
      final outlet = doc.outlets[entityId];
      final templateId = outlet?.outletTemplateId;
      if (templateId == null) return null;
      return doc.registries.outletTemplates[templateId]?.primaryDomain;
    case PlanPinCarrier.device:
      final device = doc.devices[entityId];
      if (device == null) return null;
      final ref = device.templateRef;
      final snapshot = doc.templates['${ref.templateId.v}@${ref.version}'];
      return snapshot?.body.primaryDomain;
  }
}

/// What each pinned carrier prints on its callout, keyed by entity id.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE CARRIER'S OWN DESIGNATOR, WHICH IS THE ONLY ONE THAT IS A FUNCTION
/// OF A PIN (DR-150 §11.149.3)
/// ═══════════════════════════════════════════════════════════════════════
/// The exit criterion asks for *"a callout for every pinned drop, each
/// printing the designator its Pull Sheet row prints"*. A pinned outlet can
/// have **several** Pull Sheet rows, because a row is a `Link` and a drop
/// can carry three cables, so the CABLE designator is not a function of a
/// pin and choosing it would put three callouts on one dot.
///
/// The carrier's own designator is one string per pin and it appears on
/// every Pull Sheet row for that drop, so a stranger matching plan to sheet
/// finds it whichever row they are holding.
///
/// **AN ENTITY WITH NO DESIGNATOR IS ABSENT FROM THE MAP, NEVER BLANK**
/// (G4, CR-114). `Outlet.designation` is non-nullable but may be empty, and
/// an empty pill is a dot with a white box on it that says nothing. The
/// caller draws the marker and no callout, which is the honest rendering of
/// a drop nobody has designated.
Map<Uuid, String> planPinLabelsFor(
  RackDocument doc,
  Iterable<PlanPinSubject> pins,
) {
  final out = <Uuid, String>{};
  for (final pin in pins) {
    final label = switch (pin.carrier) {
      PlanPinCarrier.rack => doc.racks[pin.entityId]?.designator,
      PlanPinCarrier.outlet => doc.outlets[pin.entityId]?.designation,
      PlanPinCarrier.device => doc.devices[pin.entityId]?.designator,
    };
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    out[pin.entityId] = trimmed;
  }
  return out;
}
