// DR-008 §11.8.3 — the atomicConnect gesture. One user action, one Link,
// one undo entry, however many conductors it takes.
//
// ═════════════════════════════════════════════════════════════════════
// IT CONNECTS WHAT FITS. IT DOES NOT REFUSE.
// ═════════════════════════════════════════════════════════════════════
// Drag a 3-member component-video set onto a 2-member stereo set and the
// gesture creates the Link, pairs members in the sets' DECLARED ORDER,
// and leaves every unpaired member as a `Conductor` with an
// `OpenEndpoint`. This answers the sub-question AC-053 raises in its own
// diagnosis and does not resolve.
//
// THIS WAS THE USER'S CALL, TAKEN AGAINST A RECOMMENDATION TO REFUSE,
// and canon §11.8.3 records both the decision and its cost: validation
// does not exist until M5, so until then a half-connected run LOOKS
// COMPLETE on the schedule. That is acceptable only because the state is
// DERIVABLE AND NOT LOST — a `Link` carrying a conductor with an
// `OpenEndpoint` is a fact in the document, so M5's rule reads what this
// command writes and needs no new state and no migration.
//
// ═════════════════════════════════════════════════════════════════════
// PAIRING IS BY DECLARED POSITION, NOT BY A FILTERED LIST
// ═════════════════════════════════════════════════════════════════════
// A member the document has not materialised cannot carry a port end.
// The tempting shape is to filter those out and zip what remains — and
// that is a silent mis-wiring: drop an unmaterialised `L` from a set and
// `R` slides into index 0, so the gesture lands the right cable on the
// WRONG PIN and every downstream sheet agrees with it. Position is the
// contract; a hole in it becomes an open end, never a shift.
//
// ═════════════════════════════════════════════════════════════════════
// ROLE MISMATCH IS REPORTED, NOT CORRECTED
// ═════════════════════════════════════════════════════════════════════
// §11.8.3 rules the ORDER, so this pairs on order. But `setRole` exists
// because AC-030 wants a polarity inversion to be inexpressible rather
// than silently wrong, and order-pairing two sets whose authors declared
// `+`/`-` in opposite orders would express exactly that. Every catalog
// set today declares `+` before `-` and `L` before `R`, so the two
// agree — the exposure is latent, and it opens the moment M4 lets a user
// author a template.
//
// So the plan REPORTS a mismatch and changes nothing about the wiring.
// Overriding the declared order here would be this file quietly making a
// ruling; reporting keeps §11.8.3 intact and still refuses to let a
// swapped pair land unremarked. Surfacing it is the caller's job.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/derived/port_set_resolution.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// One paired position whose two ends declare DIFFERENT roles.
///
/// Carries both sides rather than a boolean so a caller can say which pin
/// met which — "you are about to land + on −" is actionable; "role
/// mismatch" is not.
@immutable
final class RoleMismatch {
  const RoleMismatch({
    required this.position,
    required this.fromRole,
    required this.toRole,
  });

  /// Index in declared order.
  final int position;
  final String fromRole;
  final String toRole;
}

/// What an atomicConnect gesture will do, computed before it does it.
///
/// A PLAN, in the shape `planCompaction`/`planRackShrink` already
/// established: the decision is made here where it can be inspected and
/// previewed, and [AtomicConnectCommand] only writes it. That is also
/// what makes redo exact — the conductors are fixed before `apply()` runs,
/// so replaying the command cannot re-derive a different answer from a
/// document that has moved.
@immutable
final class AtomicConnectPlan {
  const AtomicConnectPlan({
    required this.conductors,
    required this.pairedCount,
    required this.openCount,
    required this.roleMismatches,
  });

  /// In declared order. One per position that lands at least one end.
  final List<Conductor> conductors;

  /// Positions where BOTH ends resolved to a real port.
  final int pairedCount;

  /// Positions where exactly one end resolved — the incomplete run
  /// §11.8.3 says the user must be warned about.
  final int openCount;

  /// Order-paired positions whose declared roles disagree. Empty is the
  /// normal case; see the file header for why this is reported and not
  /// acted on.
  final List<RoleMismatch> roleMismatches;

  /// Whether every position landed both ends.
  bool get isComplete => openCount == 0;
}

/// Plans a connection between two devices' port sets, or `null` when
/// either set does not resolve.
///
/// Returns a plan with NO conductors when neither set has a materialised
/// member — a legible empty result rather than a `Link` with nothing on
/// it. Callers should treat an empty plan as "nothing to connect".
AtomicConnectPlan? planAtomicConnect(
  RackDocument doc, {
  required Uuid fromDeviceId,
  required String fromSetKey,
  required Uuid toDeviceId,
  required String toSetKey,
}) {
  final from = resolvePortSet(doc, fromDeviceId, fromSetKey);
  final to = resolvePortSet(doc, toDeviceId, toSetKey);
  if (from == null || to == null) return null;

  final conductors = <Conductor>[];
  final mismatches = <RoleMismatch>[];
  var paired = 0;
  var open = 0;

  final n = from.members.length > to.members.length
      ? from.members.length
      : to.members.length;

  for (var i = 0; i < n; i++) {
    // Position, not a filtered index — see the file header.
    final a = i < from.members.length ? from.members[i] : null;
    final b = i < to.members.length ? to.members[i] : null;

    final aId = a?.portId;
    final bId = b?.portId;

    // Neither end landed: there is no electrical path to record, and a
    // conductor with two open ends would assert a cable nobody drew.
    if (aId == null && bId == null) continue;

    if (aId != null && bId != null) {
      paired++;
      final aRole = a!.role;
      final bRole = b!.role;
      if (aRole != null &&
          bRole != null &&
          aRole.isNotEmpty &&
          bRole.isNotEmpty &&
          aRole != bRole) {
        mismatches.add(
          RoleMismatch(position: i, fromRole: aRole, toRole: bRole),
        );
      }
      conductors.add(
        Conductor(
          from: PortEndpoint(aId),
          to: PortEndpoint(bId),
          role: aRole ?? '',
        ),
      );
      continue;
    }

    open++;
    final landed = aId ?? bId!;
    final landedRole = (aId != null ? a!.role : b!.role) ?? '';
    // The description names WHY the end is open, because it is the only
    // thing a schedule can print about it before M5's rule exists.
    final why = aId != null
        ? 'no partner in ${to.def.label}'
        : 'no partner in ${from.def.label}';
    conductors.add(
      aId != null
          ? Conductor(
              from: PortEndpoint(landed),
              to: OpenEndpoint(why),
              role: landedRole,
            )
          : Conductor(
              from: OpenEndpoint(why),
              to: PortEndpoint(landed),
              role: landedRole,
            ),
    );
  }

  return AtomicConnectPlan(
    conductors: conductors,
    pairedCount: paired,
    openCount: open,
    roleMismatches: mismatches,
  );
}

/// Creates ONE [Link] carrying every conductor of [plan], plus its
/// implicit [Net] — one gesture, one undo entry.
///
/// A five-conductor component run is one thing the user did, so undo must
/// take back one thing. Ids are minted in the constructor, never in
/// `apply()`, so redo recreates identical entities — the `AddLinkCommand`
/// rule, and the reason [plan] is computed before construction rather
/// than inside `apply()`.
final class AtomicConnectCommand extends Command {
  AtomicConnectCommand({
    required this.plan,
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

  final AtomicConnectPlan plan;
  final Uuid id;
  final Uuid netId;
  final String designator;

  /// The implicit `Net`'s generated name — see `AddLinkCommand.netName`
  /// for why the caller allocates it rather than `apply()`.
  final String netName;
  final MediaTypeId media;
  final FracIndex order;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.atomicConnect;

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
      // The plan's conductors, verbatim and in declared order.
      conductors: [...plan.conductors],
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.links.remove(id);
    doc.nets.remove(netId);
  }
}
