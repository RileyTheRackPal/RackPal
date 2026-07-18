// docs/03-architecture.md §5.1/§5.2 — the DeviceInstance-shaped commands:
// Add, Remove, and the flagship worked example, Move. "RackFace" in the
// architecture doc's own MoveDeviceCommand sketch is this package's
// `Face` (placement.dart's naming-drift note).
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart' show TemplateRef;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// Places a brand-new [DeviceInstance]. The id is minted in the
/// constructor (never in `apply()`) so redo recreates the identical
/// entity (docs/03-architecture.md §5.1).
///
/// Every `apply()` call constructs a fresh [DeviceInstance] from this
/// command's own (immutable) fields — deliberately NOT caching a single
/// object instance across calls. Since every field, including the
/// `EntityMeta` it stamps, is derived purely from this command's own
/// constructor arguments, every such construction is field-for-field
/// identical, which is all the byte round-trip property (CR-117) needs;
/// there is no "prior state" to preserve because the entity did not
/// exist before this command's first `apply()`.
final class AddDeviceCommand extends Command {
  AddDeviceCommand({
    required this.kind,
    required this.templateRef,
    required this.designator,
    required this.name,
    required this.placement,
    required this.now,
    required this.actor,
    Uuid? id,
  }) : id = id ?? newEntityId();

  final Uuid id;
  final DeviceKind kind;
  final TemplateRef templateRef;
  final String designator;
  final String name;
  final Placement placement;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addDevice;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: kind,
      templateRef: templateRef,
      designator: designator,
      name: name,
      placement: placement,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.devices.remove(id);
    // TODO(post-M0): AC-015 template-snapshot refcounting. If a later
    // milestone has this command insert a `TemplateSnapshot` into
    // `doc.templates` when placing a catalog device, revert must drop it
    // here too, but ONLY when no other device still references the same
    // "$templateId@$version" key (refcount = `doc.devices.values.where(
    // (d) => d.templateRef.templateId == ... && d.templateRef.version ==
    // ...)`). Not needed yet: this command never touches `doc.templates`.
  }
}

/// Removes an existing [DeviceInstance]. Holds the removed object itself
/// (not a field-by-field copy) across the apply/revert boundary — unlike
/// a move or rename, undoing a removal must reconstruct the WHOLE
/// entity, and the object [apply] pulls out of `doc.devices` already IS
/// that whole entity, unchanged.
final class RemoveDeviceCommand extends Command {
  RemoveDeviceCommand({required this.id});

  final Uuid id;

  DeviceInstance? _removed;

  @override
  LabelKey get label => LabelKey.removeDevice;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    _removed = doc.devices.remove(id);
    // TODO(post-M0): AC-015 — this does not yet decrement any
    // TemplateSnapshot refcount, nor clean up orphaned `Port`/`Link`
    // references to this device. Deferred per this package's M0 scoping
    // instructions; noted rather than silently incomplete.
  }

  @override
  void revert(RackDocument doc) {
    final removed = _removed;
    if (removed == null) {
      throw StateError('RemoveDeviceCommand.revert called before apply().');
    }
    doc.devices[id] = removed;
  }
}

/// Repositions an already rail-placed device — docs/03-architecture.md
/// §5.2's worked example, transcribed with the rest of `RailPlacement`'s
/// fields (elided there) carried across unchanged.
final class MoveDeviceCommand extends Command {
  MoveDeviceCommand({
    required this.id,
    required this.fromRuIndex,
    required this.toRuIndex,
    required this.fromFace,
    required this.toFace,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final int fromRuIndex;
  final int toRuIndex;
  final Face fromFace;
  final Face toFace;
  final DateTime now;
  final String actor;

  // Captured at the top of apply(), consumed by revert(). Unlike
  // RailPlacement's untouched fields (rackId/startTwelfth/spanTwelfths/
  // chassisRotation/locked/depthOffsetFromFront survive because apply and
  // revert only ever rewrite ruIndex/face and read the rest off whatever
  // the CURRENT placement is), EntityMeta.touch() unconditionally
  // overwrites updatedAt/updatedBy and increments localRevision with no
  // way to recover the prior triple from "current state" afterward. Without
  // this cache, revert's own meta update would leave localRevision one
  // higher than before apply ran, and command_roundtrip_test's byte
  // round-trip property (CR-117) would fail on every generated sequence
  // that includes a move. Recording it fresh at the START of every
  // apply() call (rather than once in the constructor) keeps this correct
  // under redo too: right before ANY apply() call — first or redo — the
  // device's meta is always the true "from" state, because revert always
  // restores it exactly.
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.moveDevice;

  @override
  EpochMask get touches => EpochMask.structure | EpochMask.wires;
  //                                 ^ wires too: this device's link
  //                                 endpoints didn't change, but their
  //                                 routed geometry is now stale.

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (MoveDeviceCommand, id);

  RailPlacement _requireRail(DeviceInstance d) {
    final current = d.placement;
    if (current is RailPlacement) return current;
    throw StateError(
      'MoveDeviceCommand requires device $id to already be rail-placed; '
      'found ${current.runtimeType}.',
    );
  }

  RailPlacement _rebuild(RailPlacement base, int ruIndex, Face face) =>
      RailPlacement(
        rackId: base.rackId,
        ruIndex: ruIndex,
        face: face,
        startTwelfth: base.startTwelfth,
        spanTwelfths: base.spanTwelfths,
        depthOffsetFromFront: base.depthOffsetFromFront,
        chassisRotation: base.chassisRotation,
        locked: base.locked,
      );

  @override
  void apply(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireRail(d);
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d.placement = _rebuild(base, toRuIndex, toFace);
    d.meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireRail(d);
    d.placement = _rebuild(base, fromRuIndex, fromFace);
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('MoveDeviceCommand.revert called before apply().');
    }
    d.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  @override
  Command? mergeWith(Command next) => switch (next) {
    MoveDeviceCommand(
      id: final n,
      toRuIndex: final r,
      toFace: final f,
      now: final mergedNow,
      actor: final mergedActor,
    )
        when n == id =>
      // Carries THIS command's already-captured "before" meta snapshot
      // (from its own apply()) into the merged result. Without this, the
      // merged command's cache fields are null — it is a brand-new object
      // that has never itself had apply() called on it, since merging
      // happens as pure undo-HISTORY bookkeeping (UndoStack.push, called
      // from DocumentController._commit) after the document has already
      // been mutated by the original, now-discarded commands. Reachable
      // in practice the moment two `MoveDeviceCommand.run()` calls for the
      // same device land within the merge window — see
      // document_controller_test.dart's coalescing test, which is exactly
      // what caught this the first time it was missing. `_prevXxx` are
      // library-private, not class-private, so `this`'s fields are
      // directly readable here even though `next`/the result are
      // different instances.
      (MoveDeviceCommand(
          id: id,
          fromRuIndex: fromRuIndex,
          toRuIndex: r,
          fromFace: fromFace,
          toFace: f,
          now: mergedNow,
          actor: mergedActor,
        )
        .._prevUpdatedAt = _prevUpdatedAt
        .._prevUpdatedBy = _prevUpdatedBy
        .._prevLocalRevision = _prevLocalRevision),
    _ => null,
  };
}
