// docs/03-architecture.md §2.2 lists this file as "Add/Remove/RetypeLink
// — CR-008"; `RetypeLink` is not part of M0's minimal command set (no UI
// drives it yet) and is deferred, noted here rather than silently
// omitted.
//
// A Link needs at least one Service and one Conductor to be meaningful
// (CR-010, CR-014). A Service's `netId` is non-null — CR-011's implicit
// singleton net — so AddLinkCommand mints and inserts a matching implicit
// `Net` alongside the `Link` itself, rather than leaving `Service.netId`
// dangling at a Net that doesn't exist in the document. Both Conductor
// ends are `OpenEndpoint`s: a self-contained, always-valid "coil left
// unterminated" (conductor.dart) that needs no real `Port`/`DeviceInstance`
// to exist, which keeps this command usable anywhere in a command
// sequence rather than only after a device has been placed.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// Adds a new [Link] (one [Service], one [Conductor] with two open ends)
/// plus its implicit [Net]. Both ids are minted in the constructor, never
/// in `apply()`, so redo recreates identical entities.
final class AddLinkCommand extends Command {
  AddLinkCommand({
    required this.designator,
    required this.media,
    required this.order,
    required this.now,
    required this.actor,
    Uuid? id,
    Uuid? netId,
  }) : id = id ?? newEntityId(),
       netId = netId ?? newEntityId();

  final Uuid id;
  final Uuid netId;
  final String designator;
  final MediaTypeId media;
  final FracIndex order;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addLink;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [id, netId];

  @override
  void apply(RackDocument doc) {
    doc.nets[netId] = Net(
      id: netId,
      name: '',
      signalFamily: const SignalFamilyId('structure.undetermined'),
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
    doc.links[id] = Link(
      id: id,
      designator: designator,
      media: media,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      services: [
        Service(
          id: 'svc-1',
          signalFamily: const SignalFamilyId('structure.undetermined'),
          netId: netId,
        ),
      ],
      conductors: [
        const Conductor(
          from: OpenEndpoint('end A'),
          to: OpenEndpoint('end B'),
        ),
      ],
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.links.remove(id);
    doc.nets.remove(netId);
  }
}

/// Removes an existing [Link] and, since [AddLinkCommand] always creates
/// exactly one implicit [Net] alongside it, that same paired [Net] —
/// holding both removed objects directly (not a field-by-field copy) so
/// `revert()` restores them exactly, the same pattern as
/// `RemoveDeviceCommand`.
final class RemoveLinkCommand extends Command {
  RemoveLinkCommand({required this.id, required this.netId});

  final Uuid id;
  final Uuid netId;

  Link? _removedLink;
  Net? _removedNet;

  @override
  LabelKey get label => LabelKey.removeLink;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [id, netId];

  @override
  void apply(RackDocument doc) {
    _removedLink = doc.links.remove(id);
    _removedNet = doc.nets.remove(netId);
  }

  @override
  void revert(RackDocument doc) {
    final link = _removedLink;
    final net = _removedNet;
    if (link == null || net == null) {
      throw StateError('RemoveLinkCommand.revert called before apply().');
    }
    doc.links[id] = link;
    doc.nets[netId] = net;
  }
}
