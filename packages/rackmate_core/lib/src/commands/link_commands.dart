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
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
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
    required this.netName,
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

  /// The implicit `Net`'s generated name — `allocateNetName`'s answer,
  /// computed by the CALLER before construction for the same reason the
  /// ids are: `apply()` must be replayable. Allocating inside `apply()`
  /// would let a redo see a different set of used names and mint a
  /// different name than the original run.
  final String netName;
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
      name: netName,
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

/// The name the NEXT implicit `Net` in [doc] should carry — `N001`, then
/// `N002`, … — rendered through the ONE format engine (CR-045/CR-049)
/// rather than an `'N$n'` concatenation that would ignore a project's
/// customised pattern.
///
/// Doc-aware companion to `allocateNetName`, placed here for the same
/// reason `allocateRackDesignator` sits beside `AddRackCommand`: the pure
/// function stays in `idformat/` depending only on `ProjectSettings`, and
/// the document query lives with the command that needs it.
///
/// CALL THIS BEFORE CONSTRUCTING THE COMMAND, never inside `apply()` —
/// see `AddLinkCommand.netName`.
String allocateNetNameFor(RackDocument doc) => allocateNetName(
  settings: doc.settings,
  usedNames: {for (final n in doc.nets.values) n.name},
);

/// The designator the NEXT `Link` in [doc] should carry — `W001`, then
/// `W002`, … — through the same one format engine, and for the same
/// reason, as [allocateNetNameFor] above it.
///
/// Uniqueness is PROJECT-WIDE, unlike a port's: one `W###` is one physical
/// cable and one schedule row (G1), so two links sharing a designator are
/// two rows an installer cannot tell apart.
///
/// CALL THIS BEFORE CONSTRUCTING THE COMMAND, never inside `apply()`.
String allocateLinkDesignatorFor(RackDocument doc) => allocateLinkDesignator(
  settings: doc.settings,
  usedDesignators: {for (final l in doc.links.values) l.designator},
);
