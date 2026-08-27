// docs/03-architecture.md §5.1/§5.2 — the DeviceInstance-shaped commands:
// Add, Remove, and the flagship worked example, Move. "RackFace" in the
// architecture doc's own MoveDeviceCommand sketch is this package's
// `Face` (placement.dart's naming-drift note).
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/device_removal.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart' show TemplateRef;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

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
final class AddDeviceCommand extends Command<RackDocument> {
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

/// Removes an existing [DeviceInstance] **and every cable that terminates
/// on it** — DR-013 §11.13.1.
///
/// Holds the removed objects themselves (not field-by-field copies) across
/// the apply/revert boundary — unlike a move or rename, undoing a removal
/// must reconstruct the WHOLE entity, and the objects [apply] pulls out of
/// the document already ARE those entities, unchanged.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE CASCADE, AND THE DEFECT IT CLOSES
/// ═════════════════════════════════════════════════════════════════════
/// This command carried a `TODO(post-M0)`: it removed the device and left
/// its materialised `Port`s and every `Link` terminating on it. That was
/// **inert for every milestone up to M2-F**, because nothing in the
/// application wrote `doc.ports` — and DR-011.1 made it live in the same
/// commit that fixed the finding it came from. From that point a delete
/// produced a schedule row citing a device that is not in the document,
/// which is exactly what CR-017's *"the gesture may hesitate; the
/// document may not lie"* forbids.
///
/// AC-018's `OpenEndpoint` demotion was the recommendation and was
/// REJECTED (§11.13.1). It is not wrong about the model — `OpenEndpoint`
/// genuinely expresses "a cable whose far end is unbound" — but it would
/// leave a pull sheet full of half-cables nobody asked for, on a document
/// the user believes they simplified, and M5's validation (where "this
/// run ends nowhere" becomes visible) does not exist yet. **A cable to a
/// device that has been deleted is not a design intent; it is debris.**
///
/// ═════════════════════════════════════════════════════════════════════
/// THE COUNT COMES FROM `planDeviceRemoval`, NOT FROM HERE
/// ═════════════════════════════════════════════════════════════════════
/// §11.13.2's dialog states how many cables are about to go, and it has to
/// state it BEFORE this runs. Rather than derive the set twice — once for
/// the sentence and once for the edit, which is how the two drift — this
/// command calls the same function the dialog does. `device_removal.dart`
/// is the one source.
///
/// ═════════════════════════════════════════════════════════════════════
/// WHAT IS STILL DEFERRED, AND IT IS NOT A LIE
/// ═════════════════════════════════════════════════════════════════════
/// §11.13.5: the `TemplateSnapshot` refcount half of the same TODO is
/// untouched. An unreferenced snapshot is INERT — AC-006's lazy design
/// already leaves snapshots in files for devices that were never placed —
/// so it is file size rather than correctness, and it stays deferred
/// rather than being folded in here because it is a different question.
final class RemoveDeviceCommand extends Command<RackDocument> {
  RemoveDeviceCommand({required this.id});

  final Uuid id;

  DeviceInstance? _removed;

  /// Everything the cascade took, keyed by id so [revert] puts each back
  /// where it was. **The SAME ids, not equivalent objects** — §11.13.4,
  /// and the discipline `ConnectPortsCommand` already holds for the ports
  /// it materialises. Anything less makes delete-then-undo a lossy round
  /// trip through the one entity CR-117's byte gate is about.
  final Map<Uuid, Link> _removedLinks = <Uuid, Link>{};
  final Map<Uuid, Port> _removedPorts = <Uuid, Port>{};
  final Map<Uuid, Net> _removedNets = <Uuid, Net>{};

  /// Whether [apply] has run — see `RemoveLinkCommand._applied` for the
  /// full argument. "Apply ran and the device was already gone" is a
  /// legal outcome whose revert is a no-op; "revert without apply" is a
  /// bug and still throws.
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeDevice;

  /// `wires` JOINS THE MASK, and it has to: this command now removes
  /// `Link`s. Before the cascade it touched structure alone, and a
  /// schematic that did not rebuild after a delete would keep drawing
  /// cables to a symbol that is gone.
  @override
  EpochMask get touches =>
      EpochMask.structure | EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    // Cleared, not appended to: `apply` runs again on every redo and each
    // run must describe THAT run rather than the union of all of them —
    // `ConnectPortsCommand._materialised`'s rule, for the same reason.
    _removedLinks.clear();
    _removedPorts.clear();
    _removedNets.clear();

    // PLANNED BEFORE ANYTHING MOVES. Every question the plan asks — which
    // ports are this device's, which links land on them, which nets no
    // survivor still carries — is a question about the document as it is
    // now, and half of them become unanswerable once the device is gone.
    final plan = planDeviceRemoval(doc, id);

    for (final linkId in plan.linkIds) {
      final link = doc.links.remove(linkId);
      if (link != null) _removedLinks[linkId] = link;
    }
    for (final portId in plan.portIds) {
      final port = doc.ports.remove(portId);
      if (port != null) _removedPorts[portId] = port;
    }
    for (final netId in plan.netIds) {
      final net = doc.nets.remove(netId);
      if (net != null) _removedNets[netId] = net;
    }
    _removed = doc.devices.remove(id);
    _applied = true;
    // TODO(post-M0): AC-015 — this still does not decrement a
    // TemplateSnapshot refcount. Deferred deliberately by DR-013 §11.13.5,
    // which is a ruling rather than an omission: an unreferenced snapshot
    // is inert, so it is file size and not correctness.
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveDeviceCommand.revert called before apply().');
    }
    final removed = _removed;
    if (removed != null) doc.devices[id] = removed;
    // THE SAME OBJECTS, UNDER THE SAME IDS. Map insertion order changes —
    // these go to the end — and that is harmless because `deepSortKeys`
    // canonicalises every map before encoding, so the byte round trip
    // CR-117 gates depends on the ids and the values, never on the order
    // they were put back in.
    _removedPorts
      ..forEach((portId, port) => doc.ports[portId] = port)
      ..clear();
    _removedNets
      ..forEach((netId, net) => doc.nets[netId] = net)
      ..clear();
    _removedLinks
      ..forEach((linkId, link) => doc.links[linkId] = link)
      ..clear();
    _removed = null;
    _applied = false;
  }
}

/// Repositions an already rail-placed device — docs/03-architecture.md
/// §5.2's worked example, transcribed with the rest of `RailPlacement`'s
/// fields (elided there) carried across unchanged.
final class MoveDeviceCommand extends Command<RackDocument> {
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
  Command<RackDocument>? mergeWith(Command<RackDocument> next) =>
      switch (next) {
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
