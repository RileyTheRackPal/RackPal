// DR-008 §11.8.3 — the atomicConnect gesture. One user action, one Link,
// one undo entry, however many conductors it takes.
//
// ═════════════════════════════════════════════════════════════════════
// IT CONNECTS WHAT FITS. IT DOES NOT REFUSE OVER A SIZE MISMATCH.
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
// IT DOES REFUSE A TIER-1 VIOLATION. THE SAME FIVE RULES, THE SAME WAY.
// ═════════════════════════════════════════════════════════════════════
// "Connect what fits" is a ruling about SIZE. It is not a licence to
// write a state in which the document means nothing, and this command
// could write two of them: drag a set onto ITSELF — `resolvePortSet` is
// deterministic in `(deviceId, setKey)`, so both sides return the same
// port ids — and the position-pairing loop below emitted
// `Conductor(from: PortEndpoint(p), to: PortEndpoint(p))` for every
// member. `TOP-001` violated once per member, and `TOP-003` twice over
// on each pin, with no refusal anywhere: the zero-conductor guard does
// not fire because the conductors are not zero, they are wrong.
//
// So every PAIRED position is put through `evaluateConnect` — the same
// `TOP-001..005` in the same first-failure-wins order that
// `ConnectPortsCommand` uses — and the first refusal stops the whole
// gesture. One Link is one user action; there is no coherent "connect
// three of these five members" outcome to fall back to, and DR-011.5
// gives T1 no `[ Connect anyway ]` either way. An UNPAIRED position is
// not evaluated: its open end is exempt from `TOP-004` by construction
// (AC-018) and lands on no jack, so there is nothing for the five rules
// to be about.
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
import 'package:rackmate_core/src/derived/connect_rules.dart';
import 'package:rackmate_core/src/derived/connect_target.dart';
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

/// What [planAtomicConnect] decided: the plan, or the tier-1 refusal that
/// stopped it.
///
/// Sealed, and in the same shape `ConnectPortsResult` takes for the
/// pin-to-pin gesture — one gesture family, one way of saying "no", so a
/// surface that handles one refusal handles both.
@immutable
sealed class AtomicConnectResult {
  const AtomicConnectResult();
}

/// The gesture is legal. [plan] may still carry open ends — see the file
/// header on "connect what fits".
@immutable
final class AtomicConnectReady extends AtomicConnectResult {
  const AtomicConnectReady(this.plan);
  final AtomicConnectPlan plan;
}

/// A tier-1 rule refuses the gesture. DR-011.5: there is no
/// `[ Connect anyway ]`, and nothing is written, so there is no history
/// entry to undo.
@immutable
final class AtomicConnectRefused extends AtomicConnectResult {
  const AtomicConnectRefused(this.verdict);
  final ConnectRefused verdict;

  String get ruleId => verdict.ruleId;
  String get message => verdict.message;
}

/// Plans a connection between two devices' port sets, or `null` when
/// either set does not resolve.
///
/// `null` is "there is no such set", which is a DIFFERENT answer from
/// [AtomicConnectRefused] ("the set is there and the connection is
/// model-illegal") and from an [AtomicConnectReady] carrying an empty
/// plan ("nothing in either set is materialised — nothing to connect").
/// A caller that collapses the three cannot tell a typo'd set key from a
/// rule refusal.
AtomicConnectResult? planAtomicConnect(
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
      // BOTH ENDS LAND ON A JACK, SO THE FIVE RULES APPLY TO THEM. First
      // failure wins across positions as well as within one, because a
      // partially-written atomicConnect is not one of the outcomes
      // §11.8.3 offers.
      final refusal = _tier1(
        doc,
        fromDeviceId: from.deviceId,
        fromPortKey: a!.portKey,
        toDeviceId: to.deviceId,
        toPortKey: b!.portKey,
      );
      if (refusal != null) return AtomicConnectRefused(refusal);

      paired++;
      final aRole = a.role;
      final bRole = b.role;
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

  return AtomicConnectReady(
    AtomicConnectPlan(
      conductors: conductors,
      pairedCount: paired,
      openCount: open,
      roleMismatches: mismatches,
    ),
  );
}

/// `evaluateConnect`'s verdict for one paired position, or `null` when no
/// tier-1 rule objects.
///
/// `ontoLink` is deliberately absent: this gesture mints a FRESH `Link`,
/// where `TOP-002` is structurally unreachable — see `evaluateConnect`'s
/// own doc comment.
ConnectRefused? _tier1(
  RackDocument doc, {
  required Uuid fromDeviceId,
  required PortKey fromPortKey,
  required Uuid toDeviceId,
  required PortKey toPortKey,
}) {
  final a = resolveConnectTarget(
    doc,
    deviceId: fromDeviceId,
    portKey: fromPortKey.v,
  );
  final b = resolveConnectTarget(
    doc,
    deviceId: toDeviceId,
    portKey: toPortKey.v,
  );
  // `resolvePortSet` built these members out of the same device, the same
  // template snapshot and the same `PortDef` list this join re-reads, so
  // neither can be null. The guard keeps the function total rather than
  // relying on that agreement holding — the same shape `_shelfChainFault`
  // takes in connect_rules.dart.
  if (a == null || b == null) return null;

  final verdict = evaluateConnect(doc, a, b);
  return verdict is ConnectRefused ? verdict : null;
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
    required this.signalFamily,
    required this.media,
    required this.order,
    required this.now,
    required this.actor,
    Uuid? id,
    Uuid? netId,
  }) : id = id ?? newEntityId(),
       netId = netId ?? newEntityId() {
    // ─────────────────────────────────────────────────────────────────
    // THE ZERO-CONDUCTOR GUARD. AN EMPTY PLAN IS NOT A SUCCESS.
    // ─────────────────────────────────────────────────────────────────
    // `planAtomicConnect` returns a plan with NO conductors when neither
    // set has a materialised member — and until DR-011.1, that was EVERY
    // plan on every document built from the palette, because nothing in
    // the app ever wrote `doc.ports`. Writing that plan produces a `Link`
    // with a designator, a `Net`, a `Service` and nothing electrical at
    // all: a row on the pull sheet for a cable that connects nothing,
    // and an undo entry for a gesture that did nothing. CR-010/CR-014
    // require at least one conductor.
    //
    // A THROW, NOT AN `assert` — release builds strip asserts, and this
    // failure mode is silent by nature: the link LOOKS complete on the
    // schedule. The caller's job is to treat an empty plan as "nothing to
    // connect", which `planAtomicConnect`'s own doc comment already says.
    if (plan.conductors.isEmpty) {
      throw ArgumentError.value(
        plan,
        'plan',
        'AtomicConnectCommand would create a Link with no conductors. An '
            'empty plan means neither set has a materialised member — '
            'treat it as "nothing to connect" (CR-010, CR-014).',
      );
    }
    // ─────────────────────────────────────────────────────────────────
    // THE SELF-CONDUCTOR GUARD — `ConnectPortsCommand`'s, applied to a
    // plan with N conductors instead of one.
    // ─────────────────────────────────────────────────────────────────
    // `planAtomicConnect` now refuses this through `TOP-001` with a
    // sentence, which is the answer a user should get. This is the answer
    // a CALLER gets for a hand-built plan that never went through it:
    // a conductor from a jack to itself is zero electrical paths wearing
    // one conductor's clothes, and it also consumes the pin twice under
    // `TOP-003` (portConductorCount counts ENDS). A throw, not an
    // `assert` — release builds strip asserts and this failure is silent
    // by nature.
    for (final c in plan.conductors) {
      final a = c.from;
      final b = c.to;
      if (a is PortEndpoint && b is PortEndpoint && a.portId == b.portId) {
        throw ArgumentError.value(
          a.portId.v,
          'plan.conductors',
          'AtomicConnectCommand would write a conductor from a port to '
              'itself, which is no conductor at all (TOP-001, CR-014). '
              'Plan through planAtomicConnect, which refuses this.',
        );
      }
    }
  }

  final AtomicConnectPlan plan;
  final Uuid id;
  final Uuid netId;
  final String designator;

  /// The implicit `Net`'s generated name — see `AddLinkCommand.netName`
  /// for why the caller allocates it rather than `apply()`.
  final String netName;

  /// The SET'S OWN signal family, landing on both the `Net` and the
  /// `Service` (DR-011.3).
  ///
  /// This was hardcoded to `SignalFamilyId('structure.undetermined')` in
  /// both places, which put EVERY link this command created into the
  /// `str` domain — so every atomic-connected component run, stereo pair
  /// and speaker pair drew in the structure colour, with the structure
  /// dash, weight and glyph (CR-078's four encoding channels all keyed
  /// off the family). The family is available with no new derivation:
  /// `PortDef.signalFamily` on every member of the set the plan came
  /// from, and `SymbolPort.family` on the pin the user grabbed. The
  /// CALLER supplies it, for the same reason it supplies [netName] — the
  /// plan is fixed before construction so that redo cannot re-derive a
  /// different answer.
  final SignalFamilyId signalFamily;

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
      signalFamily: signalFamily,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
    doc.links[id] = Link(
      id: id,
      designator: designator,
      media: media,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      services: [
        Service(id: 'svc-1', signalFamily: signalFamily, netId: netId),
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
