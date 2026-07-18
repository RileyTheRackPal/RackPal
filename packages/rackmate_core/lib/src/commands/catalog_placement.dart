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

/// The `RackDocument.templates` key for a seed catalog id at version 1
/// (matching `scene_builder.dart`'s own `"$templateId@$version"` scheme).
String catalogTemplateKey(String catalogId) => '$catalogId@1';

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

  // 1-based occupancy flags, index 0 unused.
  final occupied = List<bool>.filled(rack.heightU + 1, false);
  for (final d in devices) {
    final placement = d.placement;
    if (placement is! RailPlacement) continue;
    if (placement.rackId != rack.id || placement.face != face) continue;
    final snapshot = templates[_templateKey(d.templateRef)];
    if (snapshot == null) continue;
    final otherH = face == Face.front
        ? snapshot.body.frontU
        : snapshot.body.rearU;
    for (var u = placement.ruIndex; u < placement.ruIndex + otherH; u++) {
      if (u >= 1 && u <= rack.heightU) occupied[u] = true;
    }
  }

  for (var start = 1; start + deviceH - 1 <= rack.heightU; start++) {
    var fits = true;
    for (var u = start; u < start + deviceH; u++) {
      if (occupied[u]) {
        fits = false;
        break;
      }
    }
    if (fits) return start;
  }
  return null;
}

String _templateKey(TemplateRef ref) => '${ref.templateId.v}@${ref.version}';

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
/// templates (`frontU`/`rearU` > 0) go to the lowest fitting free U of
/// [targetRack] on whichever face their occupancy uses (front, when both
/// faces are occupied — docs/m1-implementation-log.md §2 notes rear-
/// mirroring/dual-face rendering is not yet built, so a `both`-occupancy
/// device can only be assigned one face today). Field devices
/// (`mountMethod: notInRack`) get an [OffRackPlacement] — there is no
/// Staging Bin or off-rack device list surface in this stage, but the
/// device still exists in the document, undoes/redoes correctly, and is a
/// real `DeviceInstance` rather than a UI fiction.
CatalogPlacementResult buildPlaceFromCatalogCommand({
  required RackDocument doc,
  required String catalogId,
  required Rack targetRack,
  required DateTime now,
  required String actor,
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
    final ruIndex = findLowestFreeRu(
      rack: targetRack,
      devices: doc.devices.values,
      face: face,
      templates: doc.templates,
      deviceH: deviceH,
    );
    if (ruIndex == null) {
      return CatalogPlacementFailed(
        'No ${deviceH}U free on ${targetRack.designator} '
        '(${face.name}) for $catalogId.',
      );
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
