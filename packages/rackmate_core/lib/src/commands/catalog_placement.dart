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

import 'package:rackmate_core/src/commands/device_commands.dart';
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// The `RackDocument.templates` key for a seed catalog id at version 1
/// (matching `scene_builder.dart`'s own `"$templateId@$version"` scheme).
String catalogTemplateKey(String catalogId) => '$catalogId@1';

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

/// Every rail-placed occupant of [face] within [rack], ascending by
/// `ruIndex` (ties broken by device id, so the order is total and stable
/// across runs — a planner that emits moves in this order must not depend
/// on `Map` iteration order to be reproducible).
///
/// THE ONE occupancy scan in the system. A device whose template snapshot
/// cannot be resolved is skipped, and a device whose per-face height is 0
/// (it occupies the OTHER face only) is skipped too — both exactly as the
/// private occupancy map behaved before this was factored out.
List<RailOccupant> railOccupantsOnFace({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) {
  final out = <RailOccupant>[];
  for (final d in devices) {
    final placement = d.placement;
    if (placement is! RailPlacement) continue;
    if (placement.rackId != rack.id || placement.face != face) continue;
    final snapshot = templates[_templateKey(d.templateRef)];
    if (snapshot == null) continue;
    final deviceH = face == Face.front
        ? snapshot.body.frontU
        : snapshot.body.rearU;
    if (deviceH <= 0) continue;
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
/// as a fold over [railOccupantsOnFace] — so `findLowestFreeRu`,
/// `findBlockingOccupant` and the compaction/shrink planners all resolve
/// template heights through exactly ONE piece of code. A device-valued map
/// rather than a bare `List<bool>` so a caller can report WHICH device is
/// in the way, not just that the slot is taken.
Map<int, DeviceInstance> _occupancyByRu({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) {
  final occupied = <int, DeviceInstance>{};
  for (final o in railOccupantsOnFace(
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

String _templateKey(TemplateRef ref) => '${ref.templateId.v}@${ref.version}';

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
  final snapshot = templates[_templateKey(blocker.templateRef)];
  final h = snapshot == null
      ? 1
      : (face == Face.front ? snapshot.body.frontU : snapshot.body.rearU);
  return placement.ruIndex + h - 1;
}

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
  const CatalogPlacementFailed(this.reason);
  final String reason;
}

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
CatalogPlacementResult buildPlaceFromCatalogCommand({
  required RackDocument doc,
  required String catalogId,
  required Rack targetRack,
  required DateTime now,
  required String actor,
  int? explicitRuIndex,
}) {
  final key = catalogTemplateKey(catalogId);
  final snapshot = doc.templates[key];
  if (snapshot == null) {
    return CatalogPlacementFailed('Unknown catalog template "$catalogId".');
  }
  final body = snapshot.body;

  final Placement placement;
  if (body.side == OccupancySide.none || body.mountMethod == MountMethod.notInRack) {
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
      final isZeroU =
          body.side == OccupancySide.zeroUVertical ||
          body.mountMethod == MountMethod.zeroU;
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
      final overflow =
          explicitRuIndex < 1 ||
          explicitRuIndex + deviceH - 1 > targetRack.heightU;
      if (overflow) {
        final freeAtTop = (targetRack.heightU - explicitRuIndex + 1).clamp(
          0,
          targetRack.heightU,
        );
        return CatalogPlacementFailed(
          'Needs ${deviceH}U, only ${freeAtTop}U free at top.',
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
    placement = RailPlacement(rackId: targetRack.id, ruIndex: ruIndex, face: face);
  }

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
  if (body.mountMethod == MountMethod.notInRack) return DeviceKind.offRackPassive;
  return DeviceKind.rackDevice;
}
