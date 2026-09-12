// Places a NEW `DeviceInstance` from a seeded catalog template
// (docs/09-roadmap.md M1 checklist #6; docs/04-rack-editor.md §3.2 "the
// faster paths" and §7 designator auto-assignment). This is deliberately
// NOT a new `Command` subtype — it is a factory that computes the right
// `AddDeviceCommand` arguments (a free RU slot, an idformat-allocated
// designator) and hands them to the existing command, per this package's
// governing instruction to extend the command pattern rather than invent
// a second one.
//
// Click-to-add, not drag-to-rails: docs/04 §3.1's full drag-from-palette
// gesture (arm/lift/enter-canvas/snap/evaluate/commit with live blocked-
// drop feedback) is out of scope for this stage — see the stage's task
// brief. [buildPlaceFromCatalogCommand] is the "faster path" analogue of
// §3.2's `/`-search-and-place / double-click-palette-row / double-click-
// empty-U behaviours: it always inserts at the lowest fitting free U,
// which is exactly what those gestures do when there is no specific caret.

import 'package:rackpal_core/src/commands/device_commands.dart';
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/derived/placement_rules.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The `RackDocument.templates` key a SEEDED template lands under: catalog
/// id at version 1, through `derived/device_loads.dart`'s [templateKey] so
/// the `@` join has exactly one spelling. The old comment here named
/// `scene_builder.dart` as the scheme's owner, which stopped being true
/// when the key moved to `device_loads.dart` and left this the last
/// hand-built one.
///
/// **A WRITE-SIDE KEY, NOT A READ-SIDE ONE** (DR-077 §11.76.3). Seeding
/// writes v1 and this spells that; RESOLVING a template for placement asks
/// for the newest version and goes through
/// `derived/placeable_templates.dart`'s [resolveLatestTemplate]. The pin
/// was on both sides until an authored template could be saved twice, at
/// which point the palette offered a row that resolved a stale body.
String catalogTemplateKey(String catalogId) => templateKey(catalogId, 1);

/// One rail-placed device on one face, with its per-face height already
/// resolved through the template store.
///
/// `ruIndex` and `deviceH` are the RAW model values — deliberately NOT
/// clipped to the rack extent, unlike [_occupancyByRu]'s map. A caller
/// asking "which devices would a shrink to N U destroy?" needs to see a
/// device whose top U already exceeds the rack, and clipping would hide
/// exactly that. Callers that want rack-clipped occupancy build it from
/// this list (as [_occupancyByRu] does).
typedef RailOccupant = ({
  DeviceInstance device,
  int ruIndex,
  int deviceH,
  bool locked,
});

/// Every device that OCCUPIES U on [face]'s elevation within [rack],
/// ascending by `ruIndex` (ties broken by device id, so the order is total
/// and stable across runs — a planner that emits moves in this order must
/// not depend on `Map` iteration order to be reproducible).
///
/// THE ONE occupancy scan for "is there room here", resolved through
/// `derived/device_loads.dart`'s [elevationOccupancyU] — the same
/// predicate `scene_builder.dart` draws by and `totals.dart` counts by. A
/// device is on this list exactly when this elevation DRAWS it, so
/// `findLowestFreeRu`, `findBlockingOccupant`, the insertion caret and the
/// drop evaluator can never call a U range free that the user can see a
/// device in.
///
/// WHICH RAILS THE DEVICE IS BOLTED TO DOES NOT ENTER INTO IT (docs/04
/// §2.2, CR-036). This used to additionally require
/// `placement.face == face`, which is why `whole_house` RK-1's UPS-1 —
/// front-bolted at U1, `frontU 3 / rearU 3`, `side: both` — was drawn
/// across rear U1-U3 by the rear elevation while `findLowestFreeRu(face:
/// rear, deviceH: 1)` answered `1` and `findBlockingOccupant` reported the
/// range free. Committing that put two device blocks in one rear U on both
/// the canvas and T2.02. The bolted-rails question still exists and still
/// has callers: it is [boltedOccupantsOnFace].
///
/// A device whose template snapshot cannot be resolved is skipped, and so
/// is one whose height on THIS face is 0 (it occupies the other face
/// only) — both exactly as the private occupancy map behaved before this
/// was factored out.
List<RailOccupant> elevationOccupantsOnFace({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) => _occupantsOnFace(
  rack: rack,
  devices: devices,
  face: face,
  templates: templates,
  boltedOnly: false,
);

/// Every device BOLTED TO [face]'s rails within [rack] and modelled on
/// that face, in [elevationOccupantsOnFace]'s order.
///
/// THE OTHER QUESTION (see `derived/device_loads.dart`'s [boltedRailFace]),
/// and it exists for the two callers whose answer is WRITTEN BACK into a
/// `RailPlacement.face`: `compaction.dart` and `rack_shrink.dart` turn
/// their plans into `MoveDeviceCommand(fromFace:, toFace:)`, so planning a
/// rear-elevation move over a front-bolted device by its rear FOOTPRINT
/// would silently unbolt it and re-hang it on the rear rails. Those
/// planners therefore move only what is bolted to the face they are
/// planning — and take what merely OCCUPIES an elevation, on EITHER face,
/// as an immovable anchor, so they never pack anything through visible
/// ink. See `compaction.dart`'s `_anchors`: what moves is the bolted set,
/// what it must clear is the rack.
///
/// No other caller should reach for this. Anything that draws, counts or
/// collision-checks a face wants [elevationOccupantsOnFace].
List<RailOccupant> boltedOccupantsOnFace({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) => _occupantsOnFace(
  rack: rack,
  devices: devices,
  face: face,
  templates: templates,
  boltedOnly: true,
);

/// The single implementation behind both scans: identical in every respect
/// except the one question they differ on, so the two can never drift into
/// disagreeing about heights, ordering or what "modelled" means.
List<RailOccupant> _occupantsOnFace({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
  required bool boltedOnly,
}) {
  final out = <RailOccupant>[];
  for (final d in devices) {
    final placement = d.placement;
    if (placement is! RailPlacement) continue;
    if (placement.rackId != rack.id) continue;
    if (boltedOnly && placement.face != face) continue;
    final deviceH = elevationOccupancyU(
      d,
      templates[templateKeyFor(d.templateRef)]?.body,
      face,
    );
    if (deviceH == null) continue;
    out.add((
      device: d,
      ruIndex: placement.ruIndex,
      deviceH: deviceH,
      locked: placement.locked,
    ));
  }
  out.sort((a, b) {
    final byRu = a.ruIndex.compareTo(b.ruIndex);
    return byRu != 0 ? byRu : a.device.id.v.compareTo(b.device.id.v);
  });
  return out;
}

/// Builds a 1-based `U -> occupying device` map for [face] within [rack],
/// as a fold over [elevationOccupantsOnFace] — so `findLowestFreeRu`,
/// `findBlockingOccupant` and the elevation that DRAWS the face all
/// resolve occupancy through exactly ONE piece of code. A device-valued
/// map rather than a bare `List<bool>` so a caller can report WHICH device
/// is in the way, not just that the slot is taken.
Map<int, DeviceInstance> _occupancyByRu({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) {
  final occupied = <int, DeviceInstance>{};
  for (final o in elevationOccupantsOnFace(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  )) {
    for (var u = o.ruIndex; u < o.ruIndex + o.deviceH; u++) {
      if (u >= 1 && u <= rack.heightU) occupied[u] = o.device;
    }
  }
  return occupied;
}

/// The lowest `ruIndex` at which a device needing [deviceH] U on [face]
/// fits in [rack] without overlapping any of [devices]' existing rail
/// placements on that face — docs/04 §3.2's "lowest fitting free U".
/// Returns null when nothing fits (an empty Staging Bin equivalent does
/// not exist yet in this stage; the caller decides what "no room" means).
int? findLowestFreeRu({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
  required int deviceH,
}) {
  if (deviceH <= 0 || deviceH > rack.heightU) return null;
  final occupied = _occupancyByRu(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  );

  for (var start = 1; start + deviceH - 1 <= rack.heightU; start++) {
    var fits = true;
    for (var u = start; u < start + deviceH; u++) {
      if (occupied.containsKey(u)) {
        fits = false;
        break;
      }
    }
    if (fits) return start;
  }
  return null;
}

/// The first OTHER device occupying any U in `[ruStart, ruStart+deviceH-1]`
/// on [face] within [rack], or null when that range is free. [exceptId],
/// when given, excludes that device from the scan — the device being
/// nudged/moved does not "block" itself against its OWN current placement.
///
/// Used by keyboard nudge (docs/04-rack-editor.md §3.4: "a nudge that
/// would collide never silently stops... the status bar reads 'Blocked by
/// SW-1'") and by [buildPlaceFromCatalogCommand]'s `explicitRuIndex` path
/// (caret-targeted quick-add), so both surfaces report the exact same
/// occupant for the exact same range.
DeviceInstance? findBlockingOccupant({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
  required int ruStart,
  required int deviceH,
  Uuid? exceptId,
}) {
  final occupied = _occupancyByRu(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  );
  for (var u = ruStart; u < ruStart + deviceH; u++) {
    final occupant = occupied[u];
    if (occupant != null && occupant.id != exceptId) return occupant;
  }
  return null;
}

/// The lowest U a [findBlockingOccupant] hit currently occupies — for the
/// "Occupied by AMP-1 (U19-U20)" style failure message. Returns 0 if,
/// somehow, [blocker] is not rail-placed (unreachable in practice:
/// [_occupancyByRu] only ever records rail-placed devices).
int _blockerStartRu(DeviceInstance blocker) {
  final placement = blocker.placement;
  return placement is RailPlacement ? placement.ruIndex : 0;
}

/// The highest U [blocker] occupies on [face], resolved through
/// [templates] the same way [_occupancyByRu] does — kept as a tiny,
/// message-only helper rather than widening [findBlockingOccupant]'s
/// return type, since only [buildPlaceFromCatalogCommand]'s failure text
/// needs the full range.
int _blockerEndRu(
  DeviceInstance blocker,
  Face face,
  Map<String, TemplateSnapshot> templates,
) {
  final placement = blocker.placement;
  if (placement is! RailPlacement) return _blockerStartRu(blocker);
  final snapshot = templates[templateKeyFor(blocker.templateRef)];
  final h = snapshot == null
      ? 1
      : (face == Face.front ? snapshot.body.frontU : snapshot.body.rearU);
  return placement.ruIndex + h - 1;
}

/// Where in a rack's 0U channel an occupant is being put (AC-044).
///
/// A RECORD RATHER THAN THREE PARAMETERS, because all three are
/// meaningless apart: a channel with no offset does not say where, and an
/// offset with no channel does not say where along what. `PLC-003` reads
/// both of the first two.
typedef ZeroUTarget = ({
  String channelId,
  Len offsetFromChannelStart,
  ZeroUOrientation orientation,
});

/// The outcome of [buildPlaceFromCatalogCommand]: either a ready-to-run
/// command, or a reason it could not build one (surfaced to the user
/// rather than silently doing nothing — docs/04 §3.4's "a nudge that
/// would collide never silently stops" principle applies here too).
sealed class CatalogPlacementResult {
  const CatalogPlacementResult();
}

final class CatalogPlacementReady extends CatalogPlacementResult {
  const CatalogPlacementReady(this.command);
  final AddDeviceCommand command;
}

final class CatalogPlacementFailed extends CatalogPlacementResult {
  const CatalogPlacementFailed(this.reason, {this.ruleId});
  final String reason;

  /// The tier-1 rule that refused, when one did: `"PLC-001"` (M5-C).
  ///
  /// NULLABLE, AND NULL IS NOT AN OVERSIGHT. Most refusals here are not
  /// rules at all. "Occupied by SW-1" is `findBlockingOccupant`, which
  /// DR-112 §11.111.4 rules OUT of tier 1 and leaves to `RCK-001` at tier
  /// 3; "P01 is a 0U occupant" is AC-044's scope boundary. Attaching a
  /// rule id to those would claim a catalogue entry that does not exist
  /// (CR-021), which is the failure the id exists to prevent.
  final String? ruleId;
}

/// Where a palette drag landed on a floorplan (docs/15 §6, `PLAN-E/2`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A THIRD DROP TARGET, WHICH IS EXACTLY WHAT CR-104 IS ABOUT
/// ═══════════════════════════════════════════════════════════════════════
/// CR-104 rules "one palette widget, one insert command, placement decided
/// by the drop target", and names two targets: a rack gives a
/// `RailPlacement`, the schematic canvas gives a `StagedPlacement` plus a
/// `SheetItem`. The Plan view is the third and postdates that ruling. It
/// needs no amendment because the rule it states answers the question:
/// **a device dropped on a floorplan is not in a rack**, so it is an
/// `OffRackPlacement`, and the pin says where on the page.
///
/// `locationId` IS THE ROOM AND THE PIN IS NOT. docs/15 §3.4 is explicit
/// that `locationId` "remains the schedule's source of room truth and a
/// pin never replaces it": a plan says WHERE on a page, a location says
/// which room, and the schedule prints the room. So the caller passes the
/// underlay's own location when it has one, and `null` is an honest
/// unknown (G4) rather than a room guessed from a picture. A site plan
/// depicts no room and an underlay is allowed to have no location at all.
///
/// A RACK-MOUNTABLE TEMPLATE IS NOT REFUSED HERE, and the choice is
/// deliberate. Dragging a 2U amplifier onto a floorplan produces an
/// off-rack amplifier, because that is what it is: it is in no rack.
/// Refusing would be the product deciding that rack-shaped gear cannot sit
/// in a credenza, which is a real installation and not an error, and
/// CR-104's whole point is that the target decides.
typedef PlanDropTarget = ({Uuid? locationId, PlanPin pin});

/// Builds the [AddDeviceCommand] that places one new instance of the
/// seeded template [catalogId] (e.g. `"V01"`) into [doc]. Rack-mountable
/// templates (`frontU`/`rearU` > 0) go to [explicitRuIndex] when given —
/// the insertion-caret / drag-drop target (docs/04-rack-editor.md §3.2:
/// "places at the insertion caret") — validated against the rack extent
/// and existing occupants via [findBlockingOccupant] rather than trusted
/// blindly, so a stale or out-of-range caret still fails loudly instead of
/// silently overlapping a device. When [explicitRuIndex] is omitted (the
/// pre-existing behaviour, unchanged), placement falls back to the lowest
/// fitting free U on whichever face the template's occupancy uses (front,
/// when both faces are occupied — docs/m1-implementation-log.md §2 notes
/// rear-mirroring/dual-face rendering is not yet built, so a
/// `both`-occupancy device can only be assigned one face today). Field
/// devices (`mountMethod: notInRack`) always get an [OffRackPlacement]
/// regardless of [explicitRuIndex] (a caret position is meaningless for a
/// device that isn't rail-mounted) — there is no Staging Bin or off-rack
/// device list surface in this stage, but the device still exists in the
/// document, undoes/redoes correctly, and is a real `DeviceInstance`
/// rather than a UI fiction.
///
/// [using] supplies the template INSTEAD of resolving it out of [doc],
/// and exists for exactly one caller: a palette row offered by a loaded
/// library, which by definition is not in the document yet (DR-103
/// §11.102.2). It is what lets the refusals above run **before** the copy
/// is committed. Adding the template first and discovering "the rack is
/// full" second would leave a template in the project for a device that
/// was never placed, because `DocumentController.transact` commits
/// whatever children it has and a refusal is not a throw.
///
/// Everything downstream of the resolution is unchanged by it: the
/// blocking-occupant and lowest-free-U searches read `doc.templates` for
/// the devices ALREADY placed, which is a different question.
CatalogPlacementResult buildPlaceFromCatalogCommand({
  required RackDocument doc,
  required String catalogId,
  required Rack targetRack,
  required DateTime now,
  required String actor,
  int? explicitRuIndex,
  TemplateSnapshot? using,
  ZeroUTarget? zeroU,
}) {
  final snapshot = using ?? resolveLatestTemplate(doc, catalogId);
  if (snapshot == null) {
    return CatalogPlacementFailed('Unknown catalog template "$catalogId".');
  }
  // The ref below is built from the SNAPSHOT rather than from a key
  // spelled here, so the device records whichever version was resolved
  // and stays pinned to it for life (CR-050).
  final body = snapshot.body;

  final isZeroU =
      body.side == OccupancySide.zeroUVertical ||
      body.mountMethod == MountMethod.zeroU;

  final Placement placement;
  // THE CHANNEL PATH, WHICH THE REFUSAL BELOW HAS BEEN NAMING SINCE M4.
  // AC-044 makes the inspector the only way a 0U occupant is created, and
  // until `#270` there was no inspector path to send anyone to. A caller
  // that supplies a target is that path; one that does not still gets the
  // sentence, because a double-click on P01 in the palette still has no
  // channel to mean.
  if (isZeroU && zeroU != null) {
    final proposed = ZeroUPlacement(
      rackId: targetRack.id,
      channelId: zeroU.channelId,
      offsetFromChannelStart: zeroU.offsetFromChannelStart,
      orientation: zeroU.orientation,
    );
    final verdict = evaluatePlacement(
      doc: doc,
      placement: proposed,
      body: body,
    );
    if (verdict is PlacementRefused) {
      return CatalogPlacementFailed(verdict.message, ruleId: verdict.ruleId);
    }
    placement = proposed;
  } else if (body.side == OccupancySide.none &&
      (body.frontU > 0 || body.rearU > 0) &&
      body.mountMethod != MountMethod.notInRack) {
    // ═══════════════════════════════════════════════════════════════════
    // A RACK HEIGHT WITH NO SIDE IS INCOHERENT, AND SILENCE WAS THE BUG
    // (DR-157 §11.156)
    // ═══════════════════════════════════════════════════════════════════
    // This body used to fall into the branch below and come back as a
    // `CatalogPlacementReady` carrying an `OffRackPlacement`: a reported
    // SUCCESS that put the device somewhere the person was not looking.
    // Reported from the `PLAN-J` demo as *"they act as though they are
    // present, but don't appear to do anything"*, and measured: the
    // builder permits `{frontU: 2, side: none}` because `_canSave` never
    // consults `side`, and this function checked `side` before it ever
    // looked at the height.
    //
    // It is the same outcome the `deviceH <= 0` guard below was written
    // for, and it slipped past that guard by RETURNING FIRST. The comment
    // there calls it "the worst possible outcome of the three" and it was
    // right.
    return CatalogPlacementFailed(
      '$catalogId declares ${body.frontU > 0 ? body.frontU : body.rearU}U '
      'in the rack but no mounting side. Open it in the device builder and '
      'set Side to front, rear or both.',
    );
  } else if (body.side == OccupancySide.none ||
      body.mountMethod == MountMethod.notInRack) {
    // A BODY WITH NO RACK HEIGHT AT ALL IS A FIELD DEVICE, and stays
    // off-rack. AC-031's eighteen shipped field templates are
    // `{front: 0, rear: 0, side: none}` and must keep landing here: the
    // fact that separates them from the case above is the HEIGHT, not the
    // side.
    placement = const OffRackPlacement();
  } else {
    final face = body.frontU > 0 ? Face.front : Face.rear;
    final deviceH = face == Face.front ? body.frontU : body.rearU;

    // A TEMPLATE WITH NO RAIL FOOTPRINT NEVER GETS A `RailPlacement`.
    //
    // `side: zeroUVertical` (P01, the 0U PDU) is `frontU: 0, rearU: 0`, so
    // `deviceH` resolves to 0. Everything downstream then quietly agrees
    // that nothing happened: the overflow check `ru + 0 - 1 > heightU` is
    // false for any caret, `findBlockingOccupant` loops zero times and
    // returns null, and a `RailPlacement` was committed and announced as
    // "Placed PDU-1 at RK-1 U3, rear." Meanwhile `scene_builder.dart`
    // skips `deviceH <= 0`, so the device is never painted, cannot be
    // clicked, cannot be selection-chromed, and landed on the REAR face
    // while the user was looking at the front. A reported success for a
    // device that does not exist on screen is the worst possible outcome
    // of the three.
    //
    // The refusal names the actual reason. Before this guard, the
    // no-caret path fell through to `findLowestFreeRu`, which returns null
    // for `deviceH <= 0` and produced "No 0U free on RK-1 (rear) for P01."
    // — blaming rack space for a feature that does not exist. P01's own
    // description already states the truth (AC-044: 0U occupants are
    // created and edited from the inspector in v1), and the drag path
    // already honours it via its `mountable` guard; this is the
    // double-click / row-Enter / search-Enter path catching up.
    if (deviceH <= 0) {
      return CatalogPlacementFailed(
        isZeroU
            ? '$catalogId is a 0U occupant: it mounts in a vertical channel, '
                  'not rail holes. Add it from the rack inspector (AC-044).'
            : '$catalogId occupies 0U on the ${face.name} face — there is no '
                  'rail footprint to place.',
      );
    }

    final int ruIndex;
    if (explicitRuIndex != null) {
      // ═══════════════════════════════════════════════════════════════
      // `PLC-001` DECIDES THIS, AND IT USED TO BE WRITTEN OUT HERE
      // ═══════════════════════════════════════════════════════════════
      // The predicate was `explicitRuIndex < 1 || explicitRuIndex +
      // deviceH - 1 > targetRack.heightU`, which is docs/02 §5.1's
      // `PLC-001` transcribed by hand into a planner, with no rule id on
      // the refusal. Canon §12.6(b) ratified `PLC-001..003` over exactly
      // that shape: *"an unnumbered blocking rule can carry neither a
      // `Finding.ruleId` nor an AC-051 fixture pair"*. M5-C gave it a
      // predicate, so this is the call site catching up, and the bound
      // now has one implementation instead of two that could drift.
      //
      // THE SENTENCE STAYS LOCAL AND THAT IS DELIBERATE. A drop chip is
      // read in half a second with a device under the cursor, and
      // "Needs 3U, only 1U free at top" is the shape docs/04 designs for
      // that moment; `PlacementRefused.message` is written for an
      // inspector reading a refusal at rest. The DECISION is shared,
      // which is the half that can drift into a bug; the wording is not,
      // and the rule id travels with it either way.
      final verdict = evaluatePlacement(
        doc: doc,
        placement: RailPlacement(
          rackId: targetRack.id,
          ruIndex: explicitRuIndex,
          face: face,
        ),
        body: body,
      );
      if (verdict is PlacementRefused) {
        final freeAtTop = (targetRack.heightU - explicitRuIndex + 1).clamp(
          0,
          targetRack.heightU,
        );
        return CatalogPlacementFailed(
          'Needs ${deviceH}U, only ${freeAtTop}U free at top.',
          ruleId: verdict.ruleId,
        );
      }
      final blocker = findBlockingOccupant(
        rack: targetRack,
        devices: doc.devices.values,
        face: face,
        templates: doc.templates,
        ruStart: explicitRuIndex,
        deviceH: deviceH,
      );
      if (blocker != null) {
        final blockerEnd = _blockerEndRu(blocker, face, doc.templates);
        return CatalogPlacementFailed(
          'Occupied by ${blocker.designator} '
          '(U${_blockerStartRu(blocker)}-U$blockerEnd).',
        );
      }
      ruIndex = explicitRuIndex;
    } else {
      final lowest = findLowestFreeRu(
        rack: targetRack,
        devices: doc.devices.values,
        face: face,
        templates: doc.templates,
        deviceH: deviceH,
      );
      if (lowest == null) {
        return CatalogPlacementFailed(
          'No ${deviceH}U free on ${targetRack.designator} '
          '(${face.name}) for $catalogId.',
        );
      }
      ruIndex = lowest;
    }
    placement = RailPlacement(
      rackId: targetRack.id,
      ruIndex: ruIndex,
      face: face,
    );
  }

  return _readyOffPlan(
    doc: doc,
    snapshot: snapshot,
    catalogId: catalogId,
    now: now,
    actor: actor,
    placement: placement,
  );
}

/// Builds the [AddDeviceCommand] for a palette drag dropped on a floorplan
/// (docs/15 §6, `PLAN-E/2`): the device and its pin, in ONE command, so one
/// undo restores both.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ITS OWN ENTRY POINT, AND THE FIRST ATTEMPT WAS A PARAMETER
/// ═══════════════════════════════════════════════════════════════════════
/// The obvious shape is an `onPlan:` argument on
/// [buildPlaceFromCatalogCommand], with `targetRack` relaxed to `Rack?`
/// because a plan drop has no rack. That was written, and the analyzer
/// refused it in a way worth recording: **nine existing call sites pass
/// `targetRack: doc.racks[id]!`, and every one of those `!` became an
/// `unnecessary_null_check`.**
///
/// The lint is the symptom and the design was the disease. Those `!` are
/// load-bearing: `doc.racks[id]!` throws at once if the rack is missing,
/// which is a loud failure at the line that made the mistake. Against a
/// `Rack?` parameter the same expression without its `!` compiles, passes
/// `null`, and turns an immediate throw into a refusal string returned
/// several frames later. **Relaxing the type to serve a new caller would
/// have charged nine old ones for it**, and bought a runtime message where
/// there had been a compile-time guarantee.
///
/// So the rack path keeps `required Rack` and this is a second entry
/// point. "Neither target supplied" then goes back to being unrepresentable
/// rather than refused, which is the better half of the trade.
///
/// CR-104 IS STILL SATISFIED, and it is worth being precise about how. It
/// rules "one palette widget, one insert command, placement decided by the
/// drop target" — a rule about the INSERT, not about the arity of the
/// function that computes its arguments. Both paths end in [_readyOffPlan],
/// so there is exactly one `AddDeviceCommand` construction, one designator
/// allocation and one template-ref shape. What differs is only the question
/// each path has to answer, and the plan's answer is that there is no
/// question: a device dropped on a floorplan is in no rack, so it is an
/// [OffRackPlacement] and none of the rail arithmetic has anything to be
/// about.
CatalogPlacementResult buildPlaceOnPlanCommand({
  required RackDocument doc,
  required String catalogId,
  required PlanDropTarget onPlan,
  required DateTime now,
  required String actor,
  TemplateSnapshot? using,
}) {
  final snapshot = using ?? resolveLatestTemplate(doc, catalogId);
  if (snapshot == null) {
    return CatalogPlacementFailed('Unknown catalog template "$catalogId".');
  }
  if (!doc.underlays.containsKey(onPlan.pin.underlayId)) {
    // REFUSED, NOT DROPPED. `SetPlanPinCommand` answers the same question
    // by returning without writing, which is right for a command that only
    // sets a pin: the carrier survives unpinned. Here the same silence
    // would CREATE A DEVICE and quietly discard the one thing the gesture
    // was about, leaving a mystery device off-plan for somebody to find
    // later.
    return CatalogPlacementFailed(
      'This plan is not in the project any more, so there is nothing to '
      'pin $catalogId to.',
    );
  }
  // ONE COMMAND, BECAUSE ONE UNDO HAS TO RESTORE BOTH (docs/15 §6). The
  // pin rides in on the placement rather than arriving behind a second
  // `SetPlanPinCommand`, so there is no window in which the device exists
  // unpinned and no way for an undo to leave one behind.
  return _readyOffPlan(
    doc: doc,
    snapshot: snapshot,
    catalogId: catalogId,
    now: now,
    actor: actor,
    placement: OffRackPlacement(
      locationId: onPlan.locationId,
      planPin: onPlan.pin,
    ),
  );
}

/// Allocates the designator and builds the `AddDeviceCommand`, for a
/// placement whichever branch above decided.
///
/// **FACTORED OUT WHEN THE PLAN DROP ARRIVED, AND SHARED RATHER THAN
/// COPIED.** The plan path skips every rack question and then needs the
/// identical five lines about designators, template refs and device kind.
/// Copying them is how the designator allocator acquires a second
/// implementation that drifts, and this file's own header records what a
/// second implementation of a shared decision costs: `PLC-001` was
/// transcribed by hand into a planner here and had to be given back its
/// rule id.
CatalogPlacementResult _readyOffPlan({
  required RackDocument doc,
  required TemplateSnapshot snapshot,
  required String catalogId,
  required DateTime now,
  required String actor,
  required Placement placement,
}) {
  final body = snapshot.body;
  final typePrefix = body.typePrefix ?? catalogId;
  final designator = allocateDeviceDesignator(
    settings: doc.settings,
    typePrefix: typePrefix,
    usedDesignators: {for (final d in doc.devices.values) d.designator},
  );

  final command = AddDeviceCommand(
    kind: _kindFor(catalogId, body),
    templateRef: TemplateRef(
      templateId: snapshot.templateId,
      version: snapshot.version,
      contentHash: snapshot.contentHash,
    ),
    designator: designator,
    name: body.displayName,
    placement: placement,
    now: now,
    actor: actor,
  );
  return CatalogPlacementReady(command);
}

DeviceKind _kindFor(String catalogId, TemplateBody body) {
  switch (catalogId) {
    case 'X01':
      return DeviceKind.blankPanel;
    case 'X02':
      return DeviceKind.ventPanel;
    case 'X03':
      return DeviceKind.shelf;
    case 'P01':
      return DeviceKind.pdu;
    case 'P03':
      return DeviceKind.ups;
  }
  if (body.mountMethod == MountMethod.notInRack) {
    return DeviceKind.offRackPassive;
  }
  return DeviceKind.rackDevice;
}
