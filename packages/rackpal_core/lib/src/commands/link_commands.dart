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
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/service.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

/// Adds a new [Link] (one [Service], one [Conductor] with two open ends)
/// plus its implicit [Net]. Both ids are minted in the constructor, never
/// in `apply()`, so redo recreates identical entities.
final class AddLinkCommand extends Command<RackDocument> {
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
  bool apply(RackDocument doc) {
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
    return true;
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
final class RemoveLinkCommand extends Command<RackDocument> {
  RemoveLinkCommand({required this.id, required this.netId});

  final Uuid id;

  /// The implicit `Net` to take with the link, or NULL to take none.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// NULL IS "ANOTHER LINK STILL NEEDS IT", NOT "I DID NOT LOOK"
  /// ═══════════════════════════════════════════════════════════════════
  /// The paired-net assumption above holds for every net this application
  /// creates — `AddLinkCommand`, `ConnectPortsCommand` and
  /// `AtomicConnectCommand` each mint exactly one — so the ordinary caller
  /// passes `link.services.first.netId` and this reads as it always did.
  ///
  /// It does NOT hold for a hand-edited or imported file, where two links
  /// can name one net. Removing it there would leave the surviving link's
  /// `Service` pointing at nothing: the same lie `device_removal.dart`'s
  /// header describes arriving through the tidy-up, and the reason
  /// `planDeviceRemoval` asks the SURVIVORS which nets may go. A caller
  /// that cannot promise exclusivity passes null and removes the link
  /// alone; an orphaned net is inert, and a dangling `netId` is not.
  ///
  /// NULLABLE RATHER THAN A SECOND COMMAND, and rather than a sentinel id
  /// that happens to match no row: a caller reading `netId: someUnusedId`
  /// three years from now has no way to tell a deliberate skip from a bug,
  /// and `revert` would restore the same nothing either way without
  /// anybody having said so.
  final Uuid? netId;

  Link? _removedLink;
  Net? _removedNet;

  /// Whether [apply] has run — which is NOT the same question as "did it
  /// remove anything", and conflating the two is the defect DR-013's
  /// cascade exposed.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// A NULLABLE FIELD CANNOT ANSWER BOTH QUESTIONS
  /// ═════════════════════════════════════════════════════════════════
  /// This used to read `if (link == null || net == null) throw`, taking a
  /// null capture to mean "revert before apply" — a programming error
  /// worth shouting about. That was sound while `RemoveLinkCommand` was
  /// the ONLY way a `Link` could leave the document.
  ///
  /// DR-013 §11.13.1 makes `RemoveDeviceCommand` cascade, so a link can
  /// now disappear because the device at one end did. Removing that
  /// device and then reverting a `RemoveLinkCommand` that legitimately
  /// found nothing threw `StateError` out of undo. `command_roundtrip
  /// _test`'s thousand random sequences found it on the first run after
  /// the cascade landed.
  ///
  /// "Apply ran and there was nothing to remove" is a legal outcome and
  /// its revert is a no-op. "Revert without apply" is still a bug and
  /// still throws. One flag, two answers.
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.removeLink;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [id, if (netId case final n?) n];

  @override
  bool apply(RackDocument doc) {
    _removedLink = doc.links.remove(id);
    final net = netId;
    _removedNet = net == null ? null : doc.nets.remove(net);
    _applied = true;
    return true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('RemoveLinkCommand.revert called before apply().');
    }
    // EACH HALF INDEPENDENTLY. The link and the net are separate
    // removals and either can find nothing — a net shared with a
    // surviving link is not this command's to have taken.
    final link = _removedLink;
    if (link != null) doc.links[id] = link;
    final net = _removedNet;
    // `_removedNet` is non-null only where `netId` was, so the bang is
    // carried by the same condition rather than by an assumption.
    if (net != null) doc.nets[netId!] = net;
    _removedLink = null;
    _removedNet = null;
    _applied = false;
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
String allocateNetNameFor(
  RackDocument doc, {
  Set<String> alsoUsed = const {},
}) => allocateNetName(
  settings: doc.settings,
  usedNames: {for (final n in doc.nets.values) n.name, ...alsoUsed},
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
String allocateLinkDesignatorFor(
  RackDocument doc, {
  Set<String> alsoUsed = const {},
}) => allocateLinkDesignator(
  settings: doc.settings,
  usedDesignators: {
    for (final l in doc.links.values) l.designator,
    ...alsoUsed,
  },
);

// ═══════════════════════════════════════════════════════════════════════
// WHY BOTH GAINED AN `alsoUsed`, AND THE DEFECT IT EXISTS TO STOP
// ═══════════════════════════════════════════════════════════════════════
// Both read the DOCUMENT to decide what is taken. That is correct for one
// command and silently wrong for N built in one gesture: multi-draw
// (DR-012.2) builds N `ConnectPortsCommand`s against an unmutated document
// and applies them together, so without a reservation every one of them
// allocates `W006`, every one allocates `N006`, and the schedule gets N
// rows an installer cannot tell apart — with link-designator uniqueness
// being PROJECT-WIDE, which is the whole point of the paragraph above.
//
// `allocatePortDesignatorFor` has carried the same parameter since M2-F
// Phase 0, for the loopback case (two jacks on one box), and
// `buildAtomicConnectCommand` accumulates it across a set. This is that
// discipline extended from ports to the two project-wide names.
// `ConnectAllocations` in `connect_commands.dart` is what carries all
// three together, so a caller cannot remember one and forget another.
