// Putting a device on a shelf: AC-043's auto-pack, which was ruled IN for
// v1 and which nothing implemented (DR-128, `#837`).
//
// ═════════════════════════════════════════════════════════════════════
// NOTHING A PERSON DOES HAS EVER PUT A DEVICE ON A SHELF
// ═════════════════════════════════════════════════════════════════════
// Censused before this file was written. `ShelfPlacement` is in the
// sealed union, round-trips through the codec, is read by
// `hostRackOf`, `equipment_list.dart` and `TOP-005`, and its only writers
// are `_decodePlacement` and `tool/starters/authoring.dart`, which is a
// build-time generator. **No command creates one**, so a shelf in this
// product is a 2U box that nothing can be set on.
//
// That is the sixth field or type in one milestone whose producer is
// missing, after `maxConnections` (DR-124), `acceptedFamilies` (DR-126),
// `RuleMeta`'s discarded severity (DR-125) and `InlineAdapter` (DR-128).
// See `#841`.
//
// ═════════════════════════════════════════════════════════════════════
// AUTO-PACK ONLY, AND THAT IS AC-043 RATHER THAN A SHORTCUT
// ═════════════════════════════════════════════════════════════════════
// AC-043, *Cut #11: shelves, stripped*, keeps exactly this much of the
// interaction for v1:
//
//   "auto-pack left to right; `ShelfPlacement.order` decides sequence;
//    free lateral positioning, `Alt`-drag, the third focus level entered
//    with `Enter`, and per-host depth-overhang warnings all defer.
//    `lateralOffset` stays in the format (CR-029) because it is one
//    nullable field and the free-position case is real; only the UI
//    defers."
//
// So this file allocates an `order` and leaves `lateralOffset` null. It
// does NOT position by depth, does not orient, and does not stack, and
// none of those is an oversight: they are `#844`, which carries the trade
// facts that make them worth doing (a Roku is under 1U so two stack; a
// shallow device leaves room at the back of the shelf, which is where a
// power strip goes; a modem sits sideways or upright depending on the
// install; Penn Elecom and Marantz make shelves for specific gear).
//
// **Building any of that here would amend a confirmed acceptance
// criterion inside a DRC remedy commit**, which §8.3 forbids in terms.
import 'package:rackpal_core/src/commands/catalog_placement.dart'
    show deviceKindFor;
import 'package:rackpal_core/src/commands/device_commands.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart'
    show nextOrder, orderBetween;
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What [buildPlaceOnShelfCommand] decided.
sealed class ShelfPlacementResult {
  const ShelfPlacementResult();
}

/// The device may go on that shelf. Apply [command].
final class ShelfPlacementReady extends ShelfPlacementResult {
  const ShelfPlacementReady(this.command);

  final AddDeviceCommand command;
}

/// Why it may not, in words for a person.
final class ShelfPlacementFailed extends ShelfPlacementResult {
  const ShelfPlacementFailed(this.reason, {this.ruleId});

  final String reason;

  /// The tier-1 rule that refused, when one did.
  final String? ruleId;
}

/// Every device currently sitting on [hostId], in pack order.
///
/// CONTAINMENT IS CHILD TO PARENT ONLY (CR-029): the shelf carries no
/// list, so the only way to know what is on it is to ask every device
/// what it is on. `X03`'s own description says so.
List<DeviceInstance> devicesOnShelf(RackDocument doc, Uuid hostId) =>
    devicesOnShelfIn(doc.devices.values, hostId);

/// [devicesOnShelf] over a bare device list, for a caller holding no
/// document: the elevation's scene builder is handed devices and
/// templates, never a `RackDocument`, and one sort is better than two.
List<DeviceInstance> devicesOnShelfIn(
  Iterable<DeviceInstance> devices,
  Uuid hostId,
) {
  final out = <DeviceInstance>[];
  for (final device in devices) {
    final placement = device.placement;
    if (placement is ShelfPlacement && placement.hostDeviceId == hostId) {
      out.add(device);
    }
  }
  out.sort((a, b) {
    final ao = (a.placement as ShelfPlacement).order.v;
    final bo = (b.placement as ShelfPlacement).order.v;
    final byOrder = ao.compareTo(bo);
    // TOTAL, ENDING ON THE ID. Dart's `List.sort` is not stable and two
    // devices can hold the same `order` in a hand-edited file, so the
    // chain ends on a unique id or the pack order differs between two
    // runs of one build.
    return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
  });
  return out;
}

/// The `order` for a device set on [hostId] in the gap right after
/// [after] (first, when [after] is null), or null when a hand-edited file
/// leaves no room between two neighbours (see `orderBetween`).
///
/// [except] is left out of the neighbours, so a host reordered along its
/// own shelf does not measure itself. One function for a palette drop, a
/// moved host and the inspector's picker, so no two of them can disagree
/// about where a gap is (DR-204 §11.203.1, *"at the nearest gap"*).
///
/// An [after] that is not on the shelf lands first, which is what a stale
/// neighbour from a frame ago should mean rather than a throw.
FracIndex? shelfOrderAfter(
  RackDocument doc,
  Uuid hostId, {
  Uuid? after,
  Uuid? except,
}) {
  final others = [
    for (final h in devicesOnShelf(doc, hostId))
      if (h.id != except) h,
  ];
  final orders = [
    for (final h in others) (h.placement as ShelfPlacement).order,
  ];
  final index = after == null ? 0 : others.indexWhere((h) => h.id == after) + 1;
  final before = index == 0 ? null : orders[index - 1];
  final next = index >= orders.length ? null : orders[index];
  return orderBetween(before, next);
}

/// TOP-005's cycle half, asked of a MOVE: whether setting [id] on
/// [hostId] would put [id] in its own shelf chain.
///
/// Walks [hostId]'s chain child to parent (CR-029) looking for [id], and
/// stops on a chain that already loops, which is `connect_rules.dart`'s
/// fault to report rather than this question's. A minted device can never
/// loop, which is why [buildPlaceOnShelfCommand] does not ask.
bool shelfMoveWouldLoop(RackDocument doc, Uuid id, Uuid hostId) {
  final visited = <Uuid>{};
  Uuid? current = hostId;
  while (current != null && visited.add(current)) {
    if (current == id) return true;
    current = switch (doc.devices[current]?.placement) {
      ShelfPlacement(:final hostDeviceId) => hostDeviceId,
      _ => null,
    };
  }
  return false;
}

/// The first container in [rackId] that could host something, or null.
///
/// PREFERS THE EMPTIEST, so a remedy adding one small thing does not pile
/// it onto a shelf that is already carrying four. This is a tie-break and
/// not a capacity check: AC-043 defers per-host overhang warnings, and
/// `X03` states a usable depth and width but **no usable height**, so
/// there is no number here to be full against (`#844`).
DeviceInstance? findShelfInRack(RackDocument doc, Uuid rackId) {
  DeviceInstance? best;
  var bestLoad = -1;
  for (final device in doc.devices.values) {
    if (!belongsToRack(device, rackId, doc.devices)) continue;
    final body = bodyFor(device, doc.templates);
    if (body == null || !body.isContainer) continue;
    final load = devicesOnShelf(doc, device.id).length;
    // `<` not `<=`, and then the id, so the choice is deterministic when
    // two shelves are equally empty.
    if (best == null ||
        load < bestLoad ||
        (load == bestLoad && device.id.v.compareTo(best.id.v) < 0)) {
      best = device;
      bestLoad = load;
    }
  }
  return best;
}

/// Builds the command that sets [catalogId] onto the shelf [hostId].
///
/// The template must already be in `doc.templates`: this resolves through
/// it rather than through the seed catalogue, for DR-103 §11.102's reason,
/// that the placement path has resolved out of `doc.templates` since M0
/// and a caller minting a device from a body the document does not hold
/// produces a device whose `TemplateRef` draws as unknown.
///
/// [gap] null auto-packs at the right-hand end (AC-043); a record names
/// the gap a drop chose, right after `after` or first when that is null
/// (DR-204 §11.203.1, `#956`), through [shelfOrderAfter].
ShelfPlacementResult buildPlaceOnShelfCommand({
  required RackDocument doc,
  required String catalogId,
  required Uuid hostId,
  required DateTime now,
  required String actor,
  TemplateSnapshot? using,
  ({Uuid? after})? gap,
}) {
  final snapshot = using ?? resolveLatestTemplate(doc, catalogId);
  if (snapshot == null) {
    return ShelfPlacementFailed('Unknown catalog template "$catalogId".');
  }
  final host = doc.devices[hostId];
  if (host == null) {
    return const ShelfPlacementFailed(
      'That shelf is no longer in the drawing.',
    );
  }
  // TOP-005, ASKED HERE RATHER THAN WAITED FOR. That rule refuses a
  // shelf-hosted device whose host is not a container, and it is
  // evaluated on CONNECT, not on placement, so a device set on a rack
  // ear would sit wrongly in the document until somebody wired it.
  final hostBody = bodyFor(host, doc.templates);
  if (hostBody == null || !hostBody.isContainer) {
    return ShelfPlacementFailed(
      '${host.designator} is not a container, so nothing can sit on it.',
      ruleId: 'TOP-005',
    );
  }
  // NO CYCLE CHECK HERE, AND THAT IS AN ARGUMENT RATHER THAN AN OMISSION.
  // TOP-005 refuses a shelf chain that loops, and a loop needs the device
  // being placed to already be somewhere in the host's chain. This
  // function only ever mints a device, which by definition is on nothing
  // and in nobody's chain, so the cycle is unreachable from here. A
  // second walk would be a copy of `connect_rules.dart`'s that no test
  // could make fail, which is worse than none: it would read as though
  // the case were live.
  //
  // A MOVE IS A DIFFERENT MATTER, and it exists now (DR-204 §11.203.5):
  // `placement_commands.dart` sets an EXISTING device on a shelf, which
  // can already host others, so it walks the chain with
  // [shelfMoveWouldLoop] before it writes.
  final order = gap == null
      ? nextOrder(
          devicesOnShelf(
            doc,
            hostId,
          ).map((d) => (d.placement as ShelfPlacement).order),
        )
      : shelfOrderAfter(doc, hostId, after: gap.after);
  if (order == null) {
    return ShelfPlacementFailed(
      'There is no room between those two on ${host.designator}.',
    );
  }
  return ShelfPlacementReady(
    AddDeviceCommand(
      kind: deviceKindFor(catalogId, snapshot.body),
      templateRef: TemplateRef(
        templateId: snapshot.templateId,
        version: snapshot.version,
        contentHash: snapshot.contentHash,
      ),
      designator: allocateDeviceDesignator(
        settings: doc.settings,
        typePrefix: snapshot.body.typePrefix ?? catalogId,
        usedDesignators: {for (final d in doc.devices.values) d.designator},
      ),
      name: snapshot.body.displayName,
      placement: ShelfPlacement(
        hostDeviceId: hostId,
        // AUTO-PACK, or the gap a drop chose. `lateralOffset` is
        // deliberately left null either way, which is AC-043's "free
        // lateral positioning defers" with the field kept in the format
        // for when it does not.
        order: order,
      ),
      now: now,
      actor: actor,
    ),
  );
}
