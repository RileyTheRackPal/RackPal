// DR-013 §11.13 — what deleting a device actually costs, computed BEFORE
// anything is removed.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE NUMBER, ONE SOURCE
// ═══════════════════════════════════════════════════════════════════════
// §11.13.2 requires a confirmation that states the COUNT — *"a delete that
// silently drops a dozen rows off the schedule is the failure G1 makes most
// expensive: the schedule is the deliverable"*. That number has to exist
// before the command runs, because it is what the user answers a dialog
// about; and the command has to remove exactly what the number described,
// because a dialog that said "4 cables" and removed 5 is worse than no
// dialog.
//
// So the plan is computed HERE, once, and `RemoveDeviceCommand` consumes
// it rather than re-deriving its own. Two walks over the same document
// asking the same question is how the dialog and the edit drift apart —
// the same argument `multi_draw.dart` makes about two orderings of one
// bank, and `portFillByDevice` makes about a signpost that disagrees with
// the schedule.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A NET NEEDS COUNTING AND A PORT DOES NOT
// ═══════════════════════════════════════════════════════════════════════
// A `Port` belongs to exactly one device (`Port.deviceId`), so "does this
// port go" is a lookup. A `Net` belongs to no device at all: it is
// referenced by `Service.netId`, services live inside links, and a link
// can carry services on nets that other links also carry. So a net is
// removed only when NO SURVIVING LINK still references it — which means
// asking about the links that REMAIN, not the ones that go.
//
// Getting that backwards deletes a net still in use and leaves every
// surviving service pointing at nothing, which is the same shape of lie
// DR-013 exists to stop, arriving through the tidy-up.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Everything one `RemoveDeviceCommand` will take with the device.
///
/// Ids only. The command holds the removed OBJECTS across its own
/// apply/revert boundary — that is how undo restores them unchanged — but
/// a plan is a question, not a clipboard, and a plan holding entities
/// would be a second place they could go stale.
@immutable
final class DeviceRemovalPlan {
  const DeviceRemovalPlan({
    required this.deviceId,
    required this.linkIds,
    required this.portIds,
    required this.netIds,
  });

  /// The empty plan for a device this document does not have.
  static const DeviceRemovalPlan none = DeviceRemovalPlan(
    deviceId: Uuid(''),
    linkIds: <Uuid>[],
    portIds: <Uuid>[],
    netIds: <Uuid>[],
  );

  final Uuid deviceId;

  /// Every `Link` with a conductor terminating on one of this device's
  /// ports, in document order.
  final List<Uuid> linkIds;

  /// This device's materialised `Port` rows. Usually FEWER than the
  /// template declares — DR-011.1 materialises a port when a cable
  /// reaches it, so an unwired device has none at all.
  final List<Uuid> portIds;

  /// Nets that no surviving link would still reference.
  final List<Uuid> netIds;

  /// THE NUMBER THE DIALOG SAYS. Cables, not conductors and not
  /// endpoints: a `Link` is what an installer pulls and what occupies a
  /// row on the schedule, so it is the unit the count has to be in.
  int get cableCount => linkIds.length;

  /// Whether removing this device destroys anything the user cannot see
  /// from the device itself — and therefore whether §11.13.2 wants a
  /// dialog at all. *"A device carrying nothing is deleted with no prompt
  /// at all."*
  bool get needsConfirmation => linkIds.isNotEmpty;

  bool get isEmpty => deviceId.v.isEmpty;
}

/// What removing [deviceId] would take with it.
///
/// Returns [DeviceRemovalPlan.none] when the document has no such device,
/// which is a reachable and normal state — a stale selection, a second
/// delete arriving after an undo — and not an error.
DeviceRemovalPlan planDeviceRemoval(RackDocument doc, Uuid deviceId) {
  if (!doc.devices.containsKey(deviceId)) return DeviceRemovalPlan.none;

  final portIds = <Uuid>[
    for (final entry in doc.ports.entries)
      if (entry.value.deviceId == deviceId) entry.key,
  ];
  final portSet = portIds.toSet();

  final linkIds = <Uuid>[
    for (final entry in doc.links.entries)
      if (_terminatesOn(entry.value.conductors, portSet)) entry.key,
  ];
  final linkSet = linkIds.toSet();

  // THE SURVIVORS DECIDE, not the departed. See the file header.
  final stillReferenced = <Uuid>{};
  for (final entry in doc.links.entries) {
    if (linkSet.contains(entry.key)) continue;
    for (final service in entry.value.services) {
      final netId = service.netId;
      if (netId != null) stillReferenced.add(netId);
    }
  }
  final netIds = <Uuid>[
    for (final entry in doc.nets.entries)
      if (!stillReferenced.contains(entry.key) &&
          _netIsCarriedBy(doc, entry.key, linkSet))
        entry.key,
  ];

  return DeviceRemovalPlan(
    deviceId: deviceId,
    linkIds: List<Uuid>.unmodifiable(linkIds),
    portIds: List<Uuid>.unmodifiable(portIds),
    netIds: List<Uuid>.unmodifiable(netIds),
  );
}

/// Whether any conductor lands on one of [portIds].
///
/// `PortEndpoint` only. A `PlaceEndpoint` names a location and an
/// `OpenEndpoint` names nothing — neither can belong to a device, so
/// neither is affected by one going away. A cable from this device to a
/// bare field location still has one end on this device's port and is
/// caught by the other end of its own conductor.
bool _terminatesOn(List<Conductor> conductors, Set<Uuid> portIds) {
  for (final c in conductors) {
    for (final end in [c.from, c.to]) {
      if (end is PortEndpoint && portIds.contains(end.portId)) return true;
    }
  }
  return false;
}

/// Whether [netId] is referenced by a link that is going away.
///
/// A net referenced by NOTHING at all was already orphaned before this
/// delete, and tidying it here would make one gesture's undo responsible
/// for restoring debris it did not create.
bool _netIsCarriedBy(RackDocument doc, Uuid netId, Set<Uuid> removedLinks) {
  for (final id in removedLinks) {
    final link = doc.links[id];
    if (link == null) continue;
    for (final service in link.services) {
      if (service.netId == netId) return true;
    }
  }
  return false;
}
