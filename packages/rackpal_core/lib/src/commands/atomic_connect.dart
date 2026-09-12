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
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/connect_commands.dart'
    show PortMaterialisation;
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/link_commands.dart'
    show allocateLinkDesignatorFor, allocateNetNameFor;
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/derived/connect_rules.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/derived/port_set_resolution.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/service.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

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

/// A pin an [AtomicConnectPlan] will land on that the document does not
/// hold yet — the plan's half of DR-011.1.
///
/// `PortMaterialisation` minus the designator, and the missing field is
/// the whole distinction: that one is an ALLOCATION and belongs to the
/// builder, this one is a DERIVATION (`derivePortId` over the device and
/// key) and is the same on every peer and every replay.
@immutable
final class PlannedPort {
  const PlannedPort({
    required this.deviceId,
    required this.portKey,
    required this.portId,
  });

  final Uuid deviceId;
  final PortKey portKey;

  /// `derivePortId(deviceId, portKey)`.
  final Uuid portId;
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
    this.neededPorts = const <PlannedPort>[],
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

  /// Every pin this plan lands on that the document does NOT hold yet —
  /// DR-011.1, extended to the set path in M2-F Phase 4C.
  ///
  /// The pin-to-pin command has carried its equivalent since Phase 0; this
  /// one did not, so `AtomicConnectCommand` could only ever write
  /// conductors onto ports something else had already created. On a
  /// document built by dropping devices from the palette — the document
  /// the M2 exit criterion starts from — that was none of them.
  ///
  /// NO DESIGNATORS, DELIBERATELY. A designator is an ALLOCATION against
  /// the document's current contents, and this is a pure plan: two calls
  /// on one unchanged document must agree, which an allocator cannot
  /// promise across a redo. [buildAtomicConnectCommand] turns these into
  /// `PortMaterialisation`s, allocating each in turn with the previous
  /// answers reserved — the same caller-side rule `AddLinkCommand.netName`
  /// established.
  ///
  /// EMPTY IS NORMAL, and means every member was already materialised.
  final List<PlannedPort> neededPorts;

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

/// The set exists and is legal, but it has **opted out of being connected
/// as a set** — `PortSetDef.atomicConnect == false`.
///
/// ═════════════════════════════════════════════════════════════════════
/// A FOURTH ANSWER, BECAUSE IT IS A FOURTH QUESTION
/// ═════════════════════════════════════════════════════════════════════
/// This is NOT a refusal and must not be reported as one. No tier-1 rule
/// was broken and canon §5 opens with *"a rule not listed here does not
/// exist"*, so there is no `TOP-` id to carry and inventing one would be
/// exactly the fabrication DR-011.5 forbids. It is also not `null` ("there
/// is no such set") and not an empty [AtomicConnectReady] ("nothing in
/// either set is materialised") — this file's own header warns that a
/// caller which collapses those cannot tell a typo from a rule.
///
/// WHAT IT MEANS TO THE USER: these pins are wired one at a time. The
/// author of the template said this grouping is presentational or
/// otherwise not a single cable, and the pin-to-pin gesture (DR-011.2) is
/// the one that applies.
///
/// **THE FLAG WAS DECORATIVE UNTIL NOW.** DR-011.2 records it: a persisted
/// per-set opt-out that `planAtomicConnect` never read. Every one of the
/// 17 sets in the seed catalog takes the `true` default and not one passes
/// `atomic: false`, so this arm is unreachable from the shipped catalog —
/// it exists for templates authored in M4's device builder, and it is
/// enforced now so the flag means something the first time somebody sets
/// it rather than being discovered to be inert.
@immutable
final class AtomicConnectNotAtomic extends AtomicConnectResult {
  const AtomicConnectNotAtomic(this.setKey, this.deviceId);

  /// The set that opted out. When BOTH ends did, this is the `from` end —
  /// first failure wins, in argument order, matching `evaluateConnect`'s
  /// own first-failure-wins discipline.
  final String setKey;
  final Uuid deviceId;
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

  // THE OPT-OUT, READ AT LAST — see [AtomicConnectNotAtomic]. DR-011.2:
  // "This also makes `PortSetDef.atomicConnect` load-bearing for the first
  // time. It is a persisted per-set opt-out that `planAtomicConnect` never
  // reads; M2-F enforces it or the flag is decorative."
  //
  // BEFORE ANY RULE RUNS, because it is not a rule. A set that has opted
  // out is not model-illegal and evaluating TOP-001..005 against it would
  // produce a refusal sentence about the wrong thing entirely.
  //
  // EITHER END DISQUALIFIES THE GESTURE. Connecting an atomic set to a
  // non-atomic one is not "half a cable" — the whole point of an atomic
  // set is that the N conductors are ONE cable, and a cable cannot be one
  // object at one end and N at the other.
  if (!from.def.atomicConnect) {
    return AtomicConnectNotAtomic(fromSetKey, fromDeviceId);
  }
  if (!to.def.atomicConnect) {
    return AtomicConnectNotAtomic(toSetKey, toDeviceId);
  }

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

    // THE DERIVED ID, NOT THE MATERIALISED ONE — DR-011.1, extended to
    // this path in Phase 4C. Reading `portId` here is what made every
    // plan on every palette-built document a zero-conductor plan: ports
    // are lazily materialised (AC-006), so a device dropped from the
    // palette has none, and the pairing loop skipped every position.
    // `derivePortId` is deterministic, so the id a member WILL have is
    // knowable before the port exists — see `PortSetMember.derivedPortId`.
    final aId = a?.derivedPortId;
    final bId = b?.derivedPortId;

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

  // EVERY PIN THE PLAN LANDS ON THAT THE DOCUMENT DOES NOT HOLD YET.
  // Walked in the same declared order as the conductors, so the
  // designators a caller allocates for these come out in a stable
  // sequence; `landedIds` is what keeps an open end's single pin in the
  // list and an unlanded position out of it.
  final needed = <PlannedPort>[];
  void note(ResolvedPortSet set, PortSetMember m) {
    if (m.isMaterialised) return;
    if (needed.any((n) => n.portId == m.derivedPortId)) return;
    needed.add(
      PlannedPort(
        deviceId: set.deviceId,
        portKey: m.portKey,
        portId: m.derivedPortId,
      ),
    );
  }

  for (var i = 0; i < n; i++) {
    final a = i < from.members.length ? from.members[i] : null;
    final b = i < to.members.length ? to.members[i] : null;
    if (a == null && b == null) continue;
    if (a != null) note(from, a);
    if (b != null) note(to, b);
  }

  return AtomicConnectReady(
    AtomicConnectPlan(
      conductors: conductors,
      neededPorts: List<PlannedPort>.unmodifiable(needed),
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
final class AtomicConnectCommand extends Command<RackDocument> {
  AtomicConnectCommand({
    required this.plan,
    required this.materialisations,
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

  /// The ports to create, with the designators the CALLER allocated —
  /// [AtomicConnectPlan.neededPorts] resolved by
  /// [buildAtomicConnectCommand]. Empty when every member of both sets is
  /// already materialised, which on a palette-built document is none of
  /// them (DR-011.1).
  final List<PortMaterialisation> materialisations;
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

  /// The ports THIS apply() created, in creation order. Empty until
  /// `apply()` runs, and empty again after `revert()`.
  final List<Uuid> _materialised = [];

  @override
  LabelKey get label => LabelKey.atomicConnect;

  /// `wires` for the `Link`/`Conductor`/`Service`/`Net`, and `meta`
  /// because materialisation MINTS A DESIGNATOR — the same pair
  /// `ConnectPortsCommand` declares, and for the reason stated there:
  /// `Port.designator` is what the termination schedule prints in its
  /// terminal column and what CR-042 cites as `MTX-1:J09`, so a surface
  /// subscribed only to `wires` would draw the new run against a pin
  /// whose identifier it has never read.
  ///
  /// `meta` was NOT here before Phase 4C, correctly — this command
  /// created no ports and therefore minted no designators. It does now.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [
    id,
    netId,
    for (final spec in materialisations) spec.portId,
  ];

  @override
  bool apply(RackDocument doc) {
    // ═══════════════════════════════════════════════════════════════
    // THE PINS FIRST — DR-011.1, and the same idempotent shape
    // `ConnectPortsCommand` has carried since Phase 0.
    // ═══════════════════════════════════════════════════════════════
    // Cleared rather than appended to: `apply` runs again on every redo
    // and this must describe THIS run, not the union of all of them.
    // Recorded rather than recomputed, because "did this command create
    // that port" is unanswerable from the document afterwards — the port
    // looks identical either way — and getting it wrong deletes a port
    // the user's document already owned, with its designator, notes and
    // every conductor that lands on it left dangling.
    _materialised.clear();
    for (final spec in materialisations) {
      if (doc.ports.containsKey(spec.portId)) continue;
      doc.ports[spec.portId] = Port(
        id: spec.portId,
        deviceId: spec.deviceId,
        designator: spec.designator,
        templatePortKey: spec.portKey,
      );
      _materialised.add(spec.portId);
    }

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
    return true;
  }

  @override
  void revert(RackDocument doc) {
    doc.links.remove(id);
    doc.nets.remove(netId);
    // ONLY what this apply added. A port that was already in the document
    // when this command ran is not this command's to remove.
    for (final portId in _materialised) {
      doc.ports.remove(portId);
    }
    _materialised.clear();
  }
}

/// Builds the [AtomicConnectCommand] for [plan], allocating everything an
/// allocation must be allocated for — CALLER-SIDE.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SET PATH HAD NO BUILDER, AND THAT IS WHY IT COULD NOT MATERIALISE
/// ═══════════════════════════════════════════════════════════════════════
/// `buildConnectPortsCommand` has existed since M2-F Phase 0 and does
/// exactly this for the pin-to-pin gesture: run the rules, then allocate
/// the link designator, the net name, the sort order and every port
/// designator BEFORE constructing the command, "because an allocation
/// performed inside `apply()` would see a different set of used values on
/// a redo and mint a different answer than the original run".
///
/// The set path had no equivalent, so a caller had to allocate by hand —
/// and the one thing nobody hand-allocated was the PORT DESIGNATORS,
/// because the command did not create ports at all. That is the shape
/// DR-011's finding #1 describes, surviving in the half of the gesture
/// Phase 0 did not touch.
///
/// The allocator's `alsoUsed` reservation accumulates ACROSS the plan's
/// ports, so two members of one
/// set on one device cannot be handed the same `J`-number — the same
/// reservation `buildConnectPortsCommand` makes for a loopback between two
/// jacks on one box, extended from two ports to N.
AtomicConnectCommand buildAtomicConnectCommand({
  required RackDocument doc,
  required AtomicConnectPlan plan,
  required SignalFamilyId signalFamily,
  required MediaTypeId media,
  required DateTime now,
  required String actor,
}) {
  // PER DEVICE, per CR-042 — a designator is unique within its device, so
  // the reservation is keyed by device and not by the whole plan.
  final reserved = <Uuid, Set<String>>{};
  final materialisations = <PortMaterialisation>[];
  for (final port in plan.neededPorts) {
    final target = resolveConnectTarget(
      doc,
      deviceId: port.deviceId,
      portKey: port.portKey.v,
    );
    if (target == null) continue;
    final used = reserved.putIfAbsent(port.deviceId, () => <String>{});
    final designator = allocatePortDesignatorFor(doc, target, alsoUsed: used);
    used.add(designator);
    materialisations.add(
      PortMaterialisation(
        portId: port.portId,
        deviceId: port.deviceId,
        portKey: port.portKey,
        designator: designator,
      ),
    );
  }

  return AtomicConnectCommand(
    plan: plan,
    materialisations: List<PortMaterialisation>.unmodifiable(materialisations),
    designator: allocateLinkDesignatorFor(doc),
    netName: allocateNetNameFor(doc),
    signalFamily: signalFamily,
    media: media,
    order: nextOrder(doc.links.values.map((l) => l.order)),
    now: now,
    actor: actor,
  );
}
