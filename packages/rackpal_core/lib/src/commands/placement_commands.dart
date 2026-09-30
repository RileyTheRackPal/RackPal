// Moving a device between placements WITHOUT removing it: into the
// Staging Bin, back out of it, onto another shelf, and along its own
// (DR-204 §11.203.5, DR-205, `#953`, `#961`).
//
// ═════════════════════════════════════════════════════════════════════
// ONE COMMAND, BECAUSE THE PROPERTY IS ONE PROPERTY
// ═════════════════════════════════════════════════════════════════════
// Every act here keeps the device's id, its ports and every link on them,
// because it replaces the device's `placement` and touches nothing else.
// That is CR-032's promise about the bin (*"wiring preservation"*) and the
// user's about a drag that leaves the rack (*"should also keep wiring"*),
// and it holds by construction: [ReplacePlacementCommand] has no code
// path that could reach a link. A delete-and-re-add would mint new ids,
// orphan the links and lose the designator, which is why none of this is
// built out of `RemoveDeviceCommand` and `AddDeviceCommand`.
//
// ═════════════════════════════════════════════════════════════════════
// THE BIN IS A QUERY (CR-032)
// ═════════════════════════════════════════════════════════════════════
// `devices.where((d) => d.placement is StagedPlacement)`. There is no bin
// entity and no list to keep in step: [stagedDevices] is the whole of it.
import 'package:rackpal_core/src/commands/catalog_placement.dart'
    show deviceKindFor, findBlockingOccupant;
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/device_commands.dart'
    show AddDeviceCommand;
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart'
    show nextOrder, orderBetween;
import 'package:rackpal_core/src/commands/shelf_placement.dart'
    show devicesOnShelf, shelfMoveWouldLoop;
import 'package:rackpal_core/src/derived/device_loads.dart'
    show bodyFor, occupancyU;
import 'package:rackpal_core/src/derived/placeable_templates.dart'
    show resolveLatestTemplate;
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart'
    show TemplateRef, TemplateSnapshot;
import 'package:rackpal_core/src/units/ids.dart';

/// Replaces one device's placement, and nothing else.
///
/// Captures the device's meta at every apply, for `MoveDeviceCommand`'s
/// reason: `touch` overwrites the triple with no way back, and CR-117's
/// byte round trip needs revert to restore it exactly.
final class ReplacePlacementCommand extends Command<RackDocument> {
  ReplacePlacementCommand({
    required this.id,
    required this.to,
    required this.label,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final Placement to;
  @override
  final LabelKey label;
  final DateTime now;
  final String actor;

  Placement? _from;
  // Set by every apply; read only by a revert, which the undo stack never
  // calls before an apply ([_from] guards the case that would).
  late DateTime _prevUpdatedAt;
  late String _prevUpdatedBy;
  late int _prevLocalRevision;

  /// `structure` because where a device sits changed, `wires` because its
  /// links' routed geometry is now stale, as `MoveDeviceCommand` reasons.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  bool apply(RackDocument doc) {
    final d = doc.devices[id];
    // A device that is gone, or already where it is going, is a no-op and
    // says so (DR-156): no undo entry for an edit that changed nothing.
    if (d == null) return false;
    _from = d.placement;
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d
      ..placement = to
      ..meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final from = _from;
    final d = doc.devices[id];
    if (from == null || d == null) {
      throw StateError('ReplacePlacementCommand.revert before apply.');
    }
    d
      ..placement = from
      ..meta.restoreTo(
        updatedAt: _prevUpdatedAt,
        updatedBy: _prevUpdatedBy,
        localRevision: _prevLocalRevision,
      );
    _from = null;
  }
}

/// What a planner decided: the command to run, or why not, in words.
sealed class PlacementPlan {
  const PlacementPlan();
}

final class PlacementPlanReady extends PlacementPlan {
  const PlacementPlanReady(this.command);
  final ReplacePlacementCommand command;
}

final class PlacementPlanRefused extends PlacementPlan {
  const PlacementPlanRefused(this.reason, {this.ruleId});
  final String reason;

  /// The rule a refusal enforces, when it is one (`TOP-005`), as
  /// `ShelfPlacementFailed` carries it.
  final String? ruleId;
}

/// TOP-005, asked of an EXISTING device before it is set on [host]: the
/// host must be a container, and the move must not make the shelf chain
/// loop. Null when the move is legal.
///
/// Both halves, where `buildPlaceOnShelfCommand` needs only the first:
/// that function mints a device, which is on nothing and hosts nothing,
/// and every planner here moves one that may already carry a shelf of its
/// own (a staged shelf keeps its hosts, DR-205).
PlacementPlanRefused? _top005(
  RackDocument doc,
  DeviceInstance d,
  DeviceInstance host,
) {
  if (bodyFor(host, doc.templates)?.isContainer != true) {
    return PlacementPlanRefused(
      '${host.designator} is not a shelf, so nothing can sit on it.',
      ruleId: 'TOP-005',
    );
  }
  if (shelfMoveWouldLoop(doc, d.id, host.id)) {
    return PlacementPlanRefused(
      d.id == host.id
          ? '${d.designator} cannot sit on itself.'
          : '${host.designator} already sits on ${d.designator}, so '
                '${d.designator} cannot sit on it.',
      ruleId: 'TOP-005',
    );
  }
  return null;
}

/// Every device in the Staging Bin, by designator then id (CR-032: the bin
/// is this query). Total, ending on the id, because `List.sort` is not
/// stable and two devices can share a designator in a hand-edited file.
List<DeviceInstance> stagedDevices(RackDocument doc) =>
    [
      for (final d in doc.devices.values)
        if (d.placement is StagedPlacement) d,
    ]..sort((a, b) {
      final byName = a.designator.compareTo(b.designator);
      return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
    });

/// Sends [id] to the Staging Bin, remembering where it was so its return
/// chip can put it back (CR-032).
PlacementPlan planStageDevice({
  required RackDocument doc,
  required Uuid id,
  required DateTime now,
  required String actor,
}) {
  final d = doc.devices[id];
  if (d == null) return const PlacementPlanRefused('That device is gone.');
  final to = switch (d.placement) {
    RailPlacement(:final rackId, :final ruIndex, :final face, :final locked) =>
      locked
          // DR-186 §11.185.1: a locked device does not move, and staging
          // it is a move.
          ? null
          : StagedPlacement(
              lastRackId: rackId,
              lastRuIndex: ruIndex,
              lastFace: face,
            ),
    ShelfPlacement(:final hostDeviceId) => StagedPlacement(
      lastRackId: switch (doc.devices[hostDeviceId]?.placement) {
        RailPlacement(:final rackId) => rackId,
        _ => null,
      },
      lastHostDeviceId: hostDeviceId,
    ),
    ZeroUPlacement(:final rackId) => StagedPlacement(lastRackId: rackId),
    OffRackPlacement() => const StagedPlacement(),
    StagedPlacement() => null,
  };
  if (to == null) {
    return PlacementPlanRefused(
      d.placement is StagedPlacement
          ? '${d.designator} is already in the Staging Bin.'
          : '${d.designator} is locked. Unlock it to move it.',
    );
  }
  return PlacementPlanReady(
    ReplacePlacementCommand(
      id: id,
      to: to,
      label: LabelKey.stageDevice,
      now: now,
      actor: actor,
    ),
  );
}

/// Where [id]'s return chip would put it back, or why it cannot yet
/// (CR-032: *"Return to RK-1 U21"* once space exists).
PlacementPlan planReturnFromStaging({
  required RackDocument doc,
  required Uuid id,
  required DateTime now,
  required String actor,
}) {
  final d = doc.devices[id];
  if (d == null) return const PlacementPlanRefused('That device is gone.');
  final placement = d.placement;
  if (placement is! StagedPlacement) {
    return PlacementPlanRefused('${d.designator} is not in the Staging Bin.');
  }

  PlacementPlan ready(Placement to) => PlacementPlanReady(
    ReplacePlacementCommand(
      id: id,
      to: to,
      label: LabelKey.returnFromStaging,
      now: now,
      actor: actor,
    ),
  );

  // BACK ONTO ITS SHELF, at the right-hand end, when the shelf is still
  // there and still a container.
  final hostId = placement.lastHostDeviceId;
  if (hostId != null) {
    final host = doc.devices[hostId];
    if (host == null) {
      return PlacementPlanRefused(
        'The shelf ${d.designator} came off is no longer in the drawing. '
        'Drag it onto a rack or a shelf instead.',
      );
    }
    if (_top005(doc, d, host) case final refused?) return refused;
    return ready(
      ShelfPlacement(
        hostDeviceId: hostId,
        order: nextOrder(
          devicesOnShelf(
            doc,
            hostId,
          ).map((h) => (h.placement as ShelfPlacement).order),
        ),
      ),
    );
  }

  final rackId = placement.lastRackId;
  final ru = placement.lastRuIndex;
  final face = placement.lastFace;
  final rack = rackId == null ? null : doc.racks[rackId];
  if (rack == null || ru == null || face == null) {
    return PlacementPlanRefused(
      '${d.designator} has no last position to return to. '
      'Drag it onto a rack or a shelf.',
    );
  }
  final to = RailPlacement(rackId: rack.id, ruIndex: ru, face: face);
  // THE SAME CHECKS A DROP MAKES, on both faces the device occupies.
  final body = bodyFor(d, doc.templates);
  for (final f in Face.values) {
    final h = occupancyU(body, f);
    if (h == null) continue;
    if (ru < 1 || ru + h - 1 > rack.heightU) {
      return PlacementPlanRefused(
        '${rack.designator} U$ru is no longer inside the rack.',
      );
    }
    final blocker = findBlockingOccupant(
      rack: rack,
      devices: doc.devices.values,
      face: f,
      templates: doc.templates,
      ruStart: ru,
      deviceH: h,
      exceptId: d.id,
    );
    if (blocker != null) {
      return PlacementPlanRefused(
        '${rack.designator} U$ru is taken by ${blocker.designator}.',
      );
    }
  }
  return ready(to);
}

/// Sets [id] on the shelf [hostId], at the gap after [after] (or first
/// when [after] is null), keeping the device (DR-204 §11.203.5).
///
/// One planner for three gestures: a host dragged along its own shelf
/// (a reorder), onto another shelf (a move), and a staged or rail device
/// dragged onto a shelf. All of them are `Move device` to a person.
PlacementPlan planMoveOntoShelf({
  required RackDocument doc,
  required Uuid id,
  required Uuid hostId,
  required DateTime now,
  required String actor,
  Uuid? after,
}) {
  final d = doc.devices[id];
  final host = doc.devices[hostId];
  if (d == null || host == null) {
    return const PlacementPlanRefused('That device is gone.');
  }
  if (_top005(doc, d, host) case final refused?) return refused;
  if (d.placement case RailPlacement(locked: true)) {
    return PlacementPlanRefused(
      '${d.designator} is locked. Unlock it to move it.',
    );
  }
  // THE ORDER, from the shelf's hosts WITHOUT this one, so a reorder does
  // not measure itself as its own neighbour.
  final others = [
    for (final h in devicesOnShelf(doc, hostId))
      if (h.id != id) h,
  ];
  final orders = [
    for (final h in others) (h.placement as ShelfPlacement).order,
  ];
  final index = after == null ? 0 : others.indexWhere((h) => h.id == after) + 1;
  final before = index == 0 ? null : orders[index - 1];
  final next = index >= orders.length ? null : orders[index];
  final order = orderBetween(before, next);
  if (order == null) {
    // A hand-edited file only (see `orderBetween`); refused in words
    // rather than renumbering the shelf behind the user's back.
    return PlacementPlanRefused(
      'There is no room between those two on ${host.designator}.',
    );
  }
  return PlacementPlanReady(
    ReplacePlacementCommand(
      id: id,
      to: ShelfPlacement(hostDeviceId: hostId, order: order),
      label: LabelKey.moveDevice,
      now: now,
      actor: actor,
    ),
  );
}

/// A NEW device, straight into the Staging Bin: a palette drag released
/// off the rack (DR-205, docs/04 §3.1 *"dropping there creates a
/// `StagedPlacement`"*). Null when the template is not in the document.
///
/// Minted exactly as a placement mints one, kind and designator included,
/// so a device that goes rack, bin, rack is indistinguishable from one
/// placed directly. It has no last position, so its chip offers a drag
/// and no return.
AddDeviceCommand? buildAddStagedCommand({
  required RackDocument doc,
  required String catalogId,
  required DateTime now,
  required String actor,
  TemplateSnapshot? using,
}) {
  final snapshot = using ?? resolveLatestTemplate(doc, catalogId);
  if (snapshot == null) return null;
  return AddDeviceCommand(
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
    placement: const StagedPlacement(),
    now: now,
    actor: actor,
  );
}
