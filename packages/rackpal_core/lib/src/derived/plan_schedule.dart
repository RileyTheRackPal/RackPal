// rackpal_core/src/derived/plan_schedule.dart — the per-plan device
// schedule's rows (docs/15 §8, DR-152 §11.151, `PLAN-H/5`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ROW SUBJECT IS A PINNED CARRIER, AND THE BRIEF POINTED ELSEWHERE
// ═══════════════════════════════════════════════════════════════════════
// `#644` says this projects *"the derivation the equipment list already
// uses"*. **`EquipmentList` is one row per `DeviceInstance`** and its own
// header says so; a plan pins three carriers (docs/15 §3.4) and two of
// them are not devices. An `Outlet` and a `Rack` appear in that derivation
// nowhere at all, and on a rough-in outlets are most of what is pinned.
//
// The principle behind the brief is right and is CR-107's: two entities
// carrying the same facts *"is guaranteed to diverge within one week of
// real use ... nobody knows which to bill against."* What satisfies it is
// projecting the derivations the PLAN already has.
//
// ═══════════════════════════════════════════════════════════════════════
// THE REFERENCE COLUMN IS THE JOIN, AND IT IS THE CALLOUT'S OWN STRING
// ═══════════════════════════════════════════════════════════════════════
// `planPinsFor` enumerates the carriers and `planPinLabelsFor` resolves
// what each prints, both built at `PLAN-H/3` for the pills. This file
// takes both rather than walking `racks`, `outlets` and `devices` a third
// time, so **the reference in the table is literally the string on the
// drawing**. A reader going from a pill to a row cannot meet two spellings
// of one designator, which is the failure a second enumeration produces on
// the day somebody changes a fallback.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY CALLOUT RESOLVES, INCLUDING THE RACK (DR-152 §11.151.3)
// ═══════════════════════════════════════════════════════════════════════
// A reader who finds `RK-1` on the plan and nothing in the table beneath
// it has hit the one dead end this sheet exists to prevent, and the rack
// is the thing a stranger needs to find first. It costs one row.
//
// ═══════════════════════════════════════════════════════════════════════
// ORDER IS TOTAL (§8.4)
// ═══════════════════════════════════════════════════════════════════════
// Area name, then reference, then entity id. Dart's `List.sort` is not
// stable, so the chain ends in an id that is unique by construction and
// two exports of an unmodified document produce the identical table.
//
// **THE RACK IS NOT SORTED TO THE FRONT.** It sits in its own area like
// anything else, because a reader looks a reference up rather than reading
// the table top to bottom, and a row that jumps its sort is a row somebody
// has to explain.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart';
import 'package:rackpal_core/src/derived/plan_sheets.dart';
import 'package:rackpal_core/src/derived/plate_fill.dart';
import 'package:rackpal_core/src/draw/scene/plan_scene.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What the sheet prints when a column has nothing to say.
///
/// The same token every other schedule uses for an unknown (G4), so a
/// blank cell never has to be told apart from an absent one.
const String kPlanScheduleUnknown = '—';

/// One row of docs/15 §8's Floor Plan Device Schedule.
@immutable
final class PlanScheduleRow {
  const PlanScheduleRow({
    required this.entityId,
    required this.areaName,
    required this.reference,
    required this.item,
    required this.description,
  });

  /// The carrier this row is about. The sort's final tiebreak, and never
  /// printed.
  final Uuid entityId;

  /// `Great Room`. [kPlanScheduleUnknown] when the carrier's location is
  /// not stated: a plan can carry a pin whose room nobody has set, and
  /// inventing one from the underlay would be the unknown-equals-unknown
  /// join G4 forbids.
  final String areaName;

  /// `WP-1`. **The string the callout on the drawing prints**, from
  /// `planPinLabelsFor`.
  final String reference;

  /// What kind of thing it is: `Rack`, `Outlet`, or the device's model.
  final String item;

  /// The detail a reader needs to recognise it on site.
  final String description;
}

/// Every row for the plan on [underlayId].
///
/// [equipment] is `buildEquipmentList`'s output, passed in rather than
/// rebuilt: `build_document.dart` already has one for `T6.30` and a second
/// build would be the divergence CR-107 names.
List<PlanScheduleRow> planScheduleFor(
  RackDocument doc,
  Uuid underlayId, {
  required EquipmentList equipment,
}) {
  final pins = planPinsFor(doc, underlayId);
  final labels = planPinLabelsFor(doc, pins);

  final out = <PlanScheduleRow>[];
  for (final pin in pins) {
    // A CARRIER WITH NO DESIGNATOR HAS NO ROW, because it has no callout
    // either (DR-150 §11.149.3). The table lists what the drawing labels;
    // a row whose reference is blank could not be looked up.
    final reference = labels[pin.entityId];
    if (reference == null) continue;

    // AND THE `!` IS SAFE BECAUSE THE LINE ABOVE ALREADY PROVED IT.
    // `planPinLabelsFor` resolved that designator out of these same three
    // maps under this same key, so a pin whose entity is absent has no
    // label and left through the `continue`. A `row != null` arm here
    // survived being deleted for exactly that reason, and a branch no
    // state can reach is one every later reader has to reason about.
    out.add(switch (pin.carrier) {
      PlanPinCarrier.rack => _rackRow(doc, doc.racks[pin.entityId]!, reference),
      PlanPinCarrier.outlet => _outletRow(
        doc,
        doc.outlets[pin.entityId]!,
        reference,
      ),
      PlanPinCarrier.device => _deviceRow(
        doc,
        doc.devices[pin.entityId]!,
        reference,
        // `rowFor`, not the listed rows: since DR-213 a passive is not
        // a listed row, and a pinned one still has the list's values.
        equipment.rowFor(pin.entityId),
      ),
    });
  }

  out.sort((a, b) {
    final byArea = a.areaName.compareTo(b.areaName);
    if (byArea != 0) return byArea;
    final byRef = a.reference.compareTo(b.reference);
    if (byRef != 0) return byRef;
    return a.entityId.v.compareTo(b.entityId.v);
  });
  return out;
}

String _areaOf(RackDocument doc, Uuid? locationId) {
  final name = doc.locations[locationId]?.name.trim();
  return name == null || name.isEmpty ? kPlanScheduleUnknown : name;
}

PlanScheduleRow _rackRow(RackDocument doc, Rack rack, String reference) {
  final name = rack.name.trim();
  return PlanScheduleRow(
    entityId: rack.id,
    areaName: _areaOf(doc, rack.locationId),
    reference: reference,
    item: 'Rack',
    // THE HEIGHT IS WHAT IDENTIFIES A RACK IN A ROOM, and the name is
    // what the owner calls it. Both, when both exist.
    description: name.isEmpty ? '${rack.heightU}U' : '${rack.heightU}U · $name',
  );
}

PlanScheduleRow _outletRow(RackDocument doc, Outlet outlet, String reference) {
  // `computePlateFill` IS THE DERIVATION THAT ALREADY DESCRIBES A PLATE,
  // and it is given the document's links because a drop count is a fact
  // about what lands here rather than about the outlet's own fields.
  final fill = computePlateFill(outlet, doc.links.values);
  final parts = <String>[
    if (fill.gangCount > 0)
      '${fill.gangCount}-gang'
    else if (fill.needsNoPlate)
      'no plate',
    if (fill.dropCount > 0)
      '${fill.dropCount} drop${fill.dropCount == 1 ? '' : 's'}',
  ];
  return PlanScheduleRow(
    entityId: outlet.id,
    areaName: _areaOf(doc, outlet.locationId),
    reference: reference,
    item: 'Outlet',
    description: parts.isEmpty ? kPlanScheduleUnknown : parts.join(' · '),
  );
}

PlanScheduleRow _deviceRow(
  RackDocument doc,
  DeviceInstance device,
  String reference,
  EquipmentRow? equipment,
) {
  final placement = device.placement;
  final locationId = placement is OffRackPlacement
      ? placement.locationId
      : device.locationId;

  // THE EQUIPMENT LIST'S OWN VALUES WHERE IT HAS THEM. It resolves the
  // template snapshot, counts its unknowns and nulls what it cannot
  // answer; re-reading `TemplateBody` here would be the second reading
  // CR-107 forbids. A device that is not in it falls back to what the
  // instance itself holds, which is the same fallback the list uses.
  //
  // `EquipmentRow.description` IS THE DEVICE'S NAME. That field is
  // documented as *"the device's own name, falling back to the template's
  // display name"*, so it is this row's DESCRIPTION half rather than a
  // second description of its own.
  final model = equipment?.model?.trim();
  final maker = equipment?.manufacturer?.trim();
  final name = (equipment?.description ?? device.name).trim();

  return PlanScheduleRow(
    entityId: device.id,
    areaName: _areaOf(doc, locationId),
    reference: reference,
    item: model == null || model.isEmpty ? 'Device' : model,
    description: <String>[
      if (maker != null && maker.isNotEmpty) maker,
      if (name.isNotEmpty) name,
    ].join(' · ').ifEmpty(kPlanScheduleUnknown),
  );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
