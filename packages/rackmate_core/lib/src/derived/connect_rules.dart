// The five tier-1 topology rules, evaluated for ONE prospective
// connection — docs/02-data-model.md §5.1, `TOP-001`..`TOP-005`.
//
// ═════════════════════════════════════════════════════════════════════
// THESE REFUSE. THERE IS NO [ Connect anyway ].
// ═════════════════════════════════════════════════════════════════════
// DR-011.5, and it is canon's own frame: docs/02 §5's tier table gives
// T1's escape hatch as *"None. There is nothing to escape to."* Tier 2 is
// where the spring-back chip and `[ Connect anyway ]` live, and all six
// T2 rules (`SIG-001`, `SIG-002`, `DIR-001`, `DIR-003`, `CON-001`,
// `ELE-006`) are deferred to M5 and are NOT evaluated here. A T2 rule
// quietly implemented as a T1 refusal would make the product unable to
// draw a mistake, which is the exact failure G2 and CR-017 exist to
// prevent: *"a model that cannot draw a mistake cannot document reality"*.
//
// ═════════════════════════════════════════════════════════════════════
// EVERY REFUSAL CARRIES A RULE ID **AND** A SENTENCE ABOUT THIS DOCUMENT
// ═════════════════════════════════════════════════════════════════════
// "TOP-003" alone is a log line, not an explanation. The sentence names
// the real designators — "AVR-1 J03 already carries 1 of 1 connections."
// — because the user's next action depends on WHICH pin is full, and a
// generic string sends them looking. [ConnectRefused] carries both, and
// `connect_rules_test.dart` is table-driven over [ConnectRule.values] so
// a sixth rule cannot be added without one.
//
// ═════════════════════════════════════════════════════════════════════
// FIRST FAILURE WINS, IN [ConnectRule]'s DECLARATION ORDER
// ═════════════════════════════════════════════════════════════════════
// The order is the enum's, so there is ONE place it is written down and
// the `switch` in [evaluateConnect] is exhaustive over it — a new rule is
// a compile error until it has both a check and a sentence. Why THAT
// order is argued on each value below; the shape of the argument is
// outside-in: a rule whose failure makes the later answers meaningless
// goes first, and the rule that can be true of a perfectly sensible
// connection goes last.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/connect_target.dart';
import 'package:rackmate_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackmate_core/src/model/conductor.dart';
// `Link` — DR-014's `planSetSplit` reads the link a conductor sits in, to
// refuse a split that would leave it with none.
import 'package:rackmate_core/src/model/link.dart' show Link;
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
// `PortDirection` — `chainOutputFor` skips the two directions where a
// signal STOPS (see its own note on why `busNode` is not one of them).
import 'package:rackmate_core/src/model/template.dart' show PortDirection;
import 'package:rackmate_core/src/units/ids.dart';

/// The five model-level illegality rules a connect gesture can meet, IN
/// EVALUATION ORDER (see the file header).
///
/// Declared in evaluation order rather than in rule-id order deliberately:
/// [evaluateConnect] iterates `values`, so this declaration IS the
/// first-failure-wins order and cannot drift from it.
enum ConnectRule {
  /// `TOP-004` — every endpoint must resolve: a `PortEndpoint` to an
  /// existing, non-tombstoned port.
  ///
  /// FIRST, because every other rule reads a fact off one of the two pins
  /// — its device's containment, its live conductor count, its identity.
  /// If the pin is not there to be read, the other four are answering a
  /// question about nothing, and the answer they give is arbitrary rather
  /// than merely different.
  ///
  /// NOTE the reading DR-011.1 forces: a pin the document has not
  /// MATERIALISED still resolves. `derivePortId` is deterministic and the
  /// connect command materialises on `apply()`, so "not yet in
  /// `doc.ports`" is the normal state of a legal target, not a dangling
  /// endpoint. What this rule rejects is a pin whose DEVICE has left the
  /// document, or one the document has buried in a `Tombstone`.
  endpointResolves('TOP-004'),

  /// `TOP-005` — a shelf-hosted device's `hostDeviceId` must resolve to a
  /// container and must not create a containment cycle.
  ///
  /// SECOND: it is about the pin's OWNER, the next ring out from the pin
  /// itself, and a device the model cannot place is a device whose ports
  /// mean nothing to hang a cable on.
  ///
  /// THIS GESTURE CANNOT CREATE A `TOP-005` VIOLATION — it is a PLACEMENT
  /// rule, and the only edits that can break it are placement edits. It is
  /// evaluated here as a PRECONDITION: a connect must not write a `Link`
  /// into a region of the document that is already model-illegal, because
  /// the resulting cable would be the only evidence of a state the model
  /// says means nothing. The enforcement site for the state's CREATION is
  /// the placement command set, which does not check it today — see the
  /// note in `connect_rules_test.dart`.
  hostResolves('TOP-005'),

  /// `TOP-001` — a conductor may not connect a port to itself.
  ///
  /// THIRD, and first of the three that are about the PAIR rather than
  /// about one end. Before [notDuplicatePair] because a self-connection is
  /// also trivially a duplicate of itself, and reporting "you already ran
  /// this cable" for what is really "you dropped the wire back on the pin
  /// you picked it up from" names the wrong problem to the user.
  notSelf('TOP-001'),

  /// `TOP-002` — two conductors may not duplicate the same ordered port
  /// pair on the same link.
  ///
  /// FOURTH: before [withinMaxConnections] because "you already ran a
  /// cable between these two pins" is both more specific and more
  /// actionable than "this pin is full" — the fullness is the CONSEQUENCE
  /// of the duplicate, and a user told only the consequence goes looking
  /// for a port to free that they do not need to free.
  ///
  /// SCOPED TO ONE LINK, exactly as canon writes it. See
  /// [evaluateConnect]'s `ontoLink` parameter for what that means for a
  /// gesture that mints a fresh `Link`.
  notDuplicatePair('TOP-002'),

  /// `TOP-003` — a port's live conductor count may not exceed its
  /// effective `maxConnections`.
  ///
  /// LAST, because it is the only one of the five that can be true of a
  /// perfectly sensible connection between two real, distinct, resolvable
  /// pins. Its remedy — free a port, or pick another one — only makes
  /// sense once the connection has been shown not to be a self-connect or
  /// a duplicate.
  withinMaxConnections('TOP-003');

  const ConnectRule(this.id);

  /// The canonical rule id, e.g. `"TOP-003"` — `Finding.ruleId`'s value
  /// and the `AAA-000` form CR-021 fixes.
  final String id;
}

/// What [evaluateConnect] decided. Sealed, so a caller must handle both
/// arms — there is no `isAllowed` boolean to check and forget, and no way
/// to read "allowed" out of a refusal by ignoring it.
@immutable
sealed class ConnectVerdict {
  const ConnectVerdict();
}

/// No tier-1 rule objects. Says nothing about tiers 2 and 3, which are
/// deferred to M5 — see the file header.
@immutable
final class ConnectAllowed extends ConnectVerdict {
  const ConnectAllowed();
}

/// A tier-1 refusal: the rule that fired and a sentence naming the actual
/// devices and pins involved.
@immutable
final class ConnectRefused extends ConnectVerdict {
  const ConnectRefused(this.rule, this.message);

  final ConnectRule rule;

  /// A COMPLETE SENTENCE about THIS document, ending in a full stop —
  /// "AVR-1 J03 already carries 1 of 1 connections." Never a generic
  /// string; see the file header.
  final String message;

  /// `"TOP-003"`.
  String get ruleId => rule.id;

  @override
  String toString() => '$ruleId: $message';
}

/// How many live conductor ends land on [portId].
///
/// PER PORT. `linkCountForDevice` (commands/link_count.dart) is per
/// DEVICE and counts each `Link` once no matter how many of its
/// conductors terminate on the device — the right answer for the shrink
/// modal's cost signal, and the wrong one entirely for `TOP-003`, whose
/// bound is a property of one jack.
///
/// ENDS, NOT CONDUCTORS. A conductor with BOTH ends on [portId] counts
/// twice: two plugs cannot occupy one jack, so a self-looped conductor
/// consumes the pin twice over. `TOP-001` makes that state unreachable
/// through a command, but a hand-edited or imported file can carry one
/// and this must not under-count it into looking legal.
/// [freeing] names conductors a gesture is ABOUT TO LIFT OUT and that are
/// therefore not counted — DR-014's split, asked here so `TOP-003` keeps
/// living in exactly one place.
///
/// THE ALTERNATIVE WAS A SECOND COPY OF THE RULE. A caller that planned a
/// split and then decided for itself whether the pin had room would be
/// re-implementing `_withinMaxConnections` — including
/// [ConnectTarget.effectiveMaxConnections]'s bus-tap reading, which is the
/// half everybody gets wrong. One parameter here beats a second answer
/// somewhere else, for the same reason `connect_target.dart`'s `_seqIn`
/// refuses to sort the port list a second way.
///
/// EMPTY IS THE NORMAL CASE and costs one set lookup per conductor.
int portConductorCount(
  RackDocument doc,
  Uuid portId, {
  Set<ConductorRef> freeing = const <ConductorRef>{},
}) {
  var count = 0;
  for (final entry in doc.links.entries) {
    final conductors = entry.value.conductors;
    for (var i = 0; i < conductors.length; i++) {
      if (freeing.isNotEmpty && freeing.contains(ConductorRef(entry.key, i))) {
        continue;
      }
      final c = conductors[i];
      if (_landsOn(c.from, portId)) count++;
      if (_landsOn(c.to, portId)) count++;
    }
  }
  return count;
}

/// Only a [PortEndpoint] occupies a jack. A `PlaceEndpoint` names a
/// location with no device yet and an `OpenEndpoint` names nothing at all
/// (AC-018/B1) — neither consumes a connection on any port.
bool _landsOn(Endpoint e, Uuid portId) =>
    e is PortEndpoint && e.portId == portId;

// ─────────────────────────────────────────────────────────────────────
// CHAIN-DRAW'S NEXT OUTPUT (DR-012.1)
// ─────────────────────────────────────────────────────────────────────
// IT LIVES HERE RATHER THAN IN `connect_target.dart`, WHERE IT WOULD
// READ MORE NATURALLY, for one mechanical reason: it has to ask whether
// a candidate output is FULL, and [portConductorCount] is here. Putting
// it beside its own type would make the two files import each other,
// and the dependency between them runs one way on purpose — rules read
// targets, targets never read rules.
//
// It is also not as foreign to this file as it first looks: "which
// output could take the next cable" is a `TOP-003` question with a
// search in front of it.

/// The output on [deviceId] that chain-draw should re-arm from after a
/// cable of [family] landed there — DR-012.1 — or null when the chain ends.
///
/// ═══════════════════════════════════════════════════════════════════════
/// "MATCHING" CANNOT MEAN "THE PAIRED OUTPUT", AND docs/05 PROVES IT
/// ═══════════════════════════════════════════════════════════════════════
/// docs/05:482 re-arms from *"the sink device's matching output"* and gives
/// its own worked example: `ATV-1 → MTX-1 IN1`, then `MTX-1 OUT1 → DA-1`.
/// **A matrix switcher has no pairing between IN1 and OUT1** — routing any
/// input to any output is what makes it a matrix — so the reading that
/// sounds most natural is refuted by the example that introduces it.
/// Nothing in the model pairs them either: `PortDef` has no field that
/// relates an input to an output.
///
/// So *matching* is the SIGNAL FAMILY, through
/// [ConnectTarget.acceptsFamily], and among the pins that qualify the
/// first FREE one wins.
///
/// THE ORDER IS `PortDef.order` THEN `key`, WHICH IS NOT A NEW ORDERING.
/// It is the sort `connect_target.dart`'s `_seqIn` already uses for
/// `PORT_SEQ`, and that function's
/// own comment records the reason: two orderings of one port list is how a
/// pin ends up with one number on the schedule and a different one in the
/// set that wires it. DR-012.2 ranks multi-draw on the same sort.
///
/// FREE MEANS `TOP-003` WOULD ALLOW IT, asked through
/// [ConnectTarget.effectiveMaxConnections] rather than by counting to one —
/// a bus tap is unbounded and stays available, which is the whole point of
/// that getter.
///
/// Returning null is an ORDINARY ANSWER, not a failure: a device with no
/// free output of that family is where a chain legitimately stops. The
/// caller is expected to say so rather than stop silently (docs/04 §3.4).
ConnectTarget? chainOutputFor(
  RackDocument doc, {
  required Uuid deviceId,
  required SignalFamilyId family,
}) {
  final device = doc.devices[deviceId];
  if (device == null) return null;
  final body = bodyFor(device, doc.templates);
  if (body == null) return null;

  final ordered = [...body.ports]..sort((a, b) {
    final byOrder = a.order.v.compareTo(b.order.v);
    return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
  });

  for (final def in ordered) {
    // A SOURCE, OR SOMETHING THAT CAN ACT AS ONE. `bidirectional` and
    // `busNode` both leave a device carrying signal onward — an IR
    // distribution block's bus taps and an RS-485 thru are exactly the
    // chain the gesture is for — while `sink` and `passive` are where a
    // signal stops. Reading `source` alone would end the chain at every
    // bus device in the catalog.
    if (def.direction == PortDirection.sink ||
        def.direction == PortDirection.passive) {
      continue;
    }
    final target = resolveConnectTarget(
      doc,
      deviceId: deviceId,
      portKey: def.key.v,
    );
    if (target == null) continue;
    if (!target.acceptsFamily(family)) continue;
    final max = target.effectiveMaxConnections;
    if (max != null && portConductorCount(doc, target.portId) + 1 > max) {
      continue;
    }
    return target;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// DR-014 — SPLITTING A SET BY DRAWING ONE MEMBER SOMEWHERE ELSE
// ─────────────────────────────────────────────────────────────────────
// HERE FOR `chainOutputFor`'S REASON, WHICH IS STATED ABOVE AND HOLDS
// TWICE OVER: this asks whether a pin is FULL, which is
// [portConductorCount] plus [ConnectTarget.effectiveMaxConnections], and
// putting it in a file of its own would make that file and this one
// import each other. The dependency runs one way on purpose — rules read
// targets, targets never read rules.
//
// It is a `TOP-003` question with a REMEDY behind it rather than a search,
// which is the only thing that distinguishes it from its neighbour.

/// One conductor a gesture will lift out of a multi-conductor `Link` so the
/// pin it occupies can take a new cable — DR-014.
///
/// EVERY FIELD IS CAPTURED, NOT RE-READ. A caller announces this AFTER the
/// commands have run, when the link has already lost the conductor and
/// asking the document again would report the state the sentence is trying
/// to describe the change TO.
@immutable
final class SetSplit {
  const SetSplit({
    required this.conductor,
    required this.linkDesignator,
    required this.conductorsBefore,
    required this.role,
  });

  /// Which conductor, in which link.
  final ConductorRef conductor;

  /// The link's `W` number — "W001". What the sentence has to name, because
  /// a user who is about to see one cable become two needs to know which
  /// row on the schedule changed.
  final String linkDesignator;

  /// How many conductors the link carried BEFORE the lift. Always >= 2 —
  /// see [planSetSplit] on why a one-conductor link is never split.
  final int conductorsBefore;

  /// The lifted conductor's role — `"R"`, `"-"` — or `''` when it declares
  /// none. Carried for the sentence only; the new cable takes its role from
  /// its own two pins through `buildConnectPortsCommand`, which is the only
  /// thing entitled to decide it (see `ConnectPortsCommand.role`).
  final String role;

  int get conductorsAfter => conductorsBefore - 1;
}

/// Whether `TOP-003` would refuse another cable on [target]'s pin.
///
/// ONE PIN, NOT A PAIR — which is what makes it a different question from
/// [evaluateConnect], and the question a SURFACE has to ask before it knows
/// which gesture the user is starting. A schematic deciding between the
/// set gesture and the pin-to-pin one needs to know whether the grabbed pin
/// is already spoken for, and it has no second pin yet to ask about.
///
/// EXPORTED SO THE ARITHMETIC IS NOT COPIED. A caller that counted
/// conductors and compared to `maxConnections` itself would miss
/// [ConnectTarget.effectiveMaxConnections] — where a bus tap's declared
/// default of `1` becomes unbounded — and would report every Cresnet drop
/// and 70 V tap in the catalog as full.
///
/// `true` for a pin declaring ZERO connections, which is "not a socket"
/// rather than "full". The distinction matters to the SENTENCE, which is
/// `_withinMaxConnections`' to write, and not to this predicate: neither
/// pin can take the cable.
bool isPortFull(
  RackDocument doc,
  ConnectTarget target, {
  Set<ConductorRef> freeing = const <ConductorRef>{},
}) {
  final max = target.effectiveMaxConnections;
  if (max == null) return false;
  if (max <= 0) return true;
  return portConductorCount(doc, target.portId, freeing: freeing) + 1 > max;
}

/// Every split DR-014 performs for a connect from [from] to [to], in plan
/// order — the `from` end's first. EMPTY IS THE NORMAL CASE.
///
/// ═══════════════════════════════════════════════════════════════════════
/// BOTH ENDS, SYMMETRICALLY, BECAUSE THE GESTURE IS SYMMETRIC
/// ═══════════════════════════════════════════════════════════════════════
/// Dragging the `R` of one stereo pair onto the `R` of another is one
/// gesture and two full pins. Planning only the grabbed end would refuse
/// exactly that — the commonest thing anybody does with two amplifiers —
/// with a `TOP-003` sentence about the pin they were aiming AT, which
/// reads as a rule about the target rather than as a limit of the code.
///
/// Each end is planned against the OTHER end's device, which is what makes
/// [planSetSplit]'s fourth condition mean what DR-014 says: *different*
/// means different from where THIS conductor already goes.
///
/// HERE RATHER THAN INSIDE THE BUILDER because a surface needs the same
/// answer without building anything: the candidate walk that decides which
/// pins may be aimed at asks it once per pin, and allocating a designator
/// per candidate to find out would mint hundreds of names it throws away.
List<SetSplit> planSplitsFor(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
) {
  final fromSplit = planSetSplit(
    doc,
    target: from,
    towardsDeviceId: to.deviceId,
  );
  final toSplit = planSetSplit(doc, target: to, towardsDeviceId: from.deviceId);
  return <SetSplit>[
    if (fromSplit != null) fromSplit,
    if (toSplit != null) toSplit,
  ];
}

/// The conductor to lift so [target] can take a cable to [towardsDeviceId],
/// or `null` when this gesture is not a split.
///
/// ═══════════════════════════════════════════════════════════════════════
/// FOUR CONDITIONS, AND EVERY ONE OF THEM IS A REFUSAL TO GUESS
/// ═══════════════════════════════════════════════════════════════════════
/// DR-014 rules that drawing a wire from an already-wired member of a set
/// to a DIFFERENT device splits the set automatically. There is no
/// modifier, no mode and no dialog, so this function is the whole of the
/// decision — and a gesture that acts without being asked has to be sure.
/// It answers `null` unless all four hold:
///
///   1. **The pin is FULL.** If `TOP-003` would let the cable land, there
///      is nothing to free and nothing to split. This is what keeps the
///      rule inert on the 223 catalog ports that carry no `setKey` and on
///      every unwired pin in the document — which is almost all of them.
///
///   2. **EXACTLY ONE conductor end lands on it.** A pin carrying two is a
///      bus tap or a hand-edited file, and "which of these did you mean to
///      displace" is a question with no derivable answer. A conductor
///      looped from the pin BACK to the same pin counts twice here and is
///      excluded by the same clause — `TOP-001` makes it unreachable
///      through a command, and lifting half of it is not a thing.
///
///   3. **Its link carries MORE THAN ONE conductor.** This is the clause
///      that keeps a split from being a DELETE. Lifting the only conductor
///      out of a one-conductor link leaves a `Link` that asserts nothing —
///      a `W` number and a schedule row for a cable with no electrical
///      path, which `ConnectPortsCommand`'s own zero-conductor guard calls
///      "no conductor at all" and throws over. Re-routing a single cable by
///      dragging its end is a real gesture and a reasonable thing to want;
///      it is not this one, and it must not happen by accident to a user
///      who was aiming at a stereo pair.
///
///   4. **The far end is not already on [towardsDeviceId].** This is the
///      user's own wording — *"when another wire is drawn to a DIFFERENT
///      device"* — and it is load-bearing rather than decorative. Drawing
///      `R` at the box it is already wired to is far more likely a
///      misaimed drag than a request to re-plug, and the honest answer
///      there is the `TOP-003` refusal the pin has always given.
///
/// AN OPEN OR PLACED FAR END SPLITS. Neither names a device, so condition 4
/// has nothing to compare and cannot be violated: an `OpenEndpoint` is a
/// coil left unterminated (AC-018/B1) and a `PlaceEndpoint` is a location
/// with no device yet. A pin held by a conductor that goes nowhere is held
/// by the weakest claim in the model, and the user pointing it at a real
/// jack is unambiguous.
///
/// AN UNRESOLVABLE FAR END DOES NOT. `doc.ports` holds every port a connect
/// command lands on (DR-011.1), so a `PortEndpoint` naming no row is a
/// hand-edited or imported file. "I cannot tell which device that end is
/// on" is not the same as "it is a different one", and only the second
/// licenses a split.
SetSplit? planSetSplit(
  RackDocument doc, {
  required ConnectTarget target,
  required Uuid towardsDeviceId,
}) {
  // (1) FULL. Through [isPortFull], so a bus tap — unbounded, `null` — is
  // never "full" and never splits. The extra `max <= 0` guard is not
  // redundant with it: a pin declaring zero connections IS full, and
  // freeing a conductor would not make it a socket.
  final max = target.effectiveMaxConnections;
  if (max == null || max <= 0) return null;
  if (!isPortFull(doc, target)) return null;

  // (2) EXACTLY ONE.
  ConductorRef? found;
  Link? foundLink;
  for (final entry in doc.links.entries) {
    final conductors = entry.value.conductors;
    for (var i = 0; i < conductors.length; i++) {
      final c = conductors[i];
      final ends =
          (_landsOn(c.from, target.portId) ? 1 : 0) +
          (_landsOn(c.to, target.portId) ? 1 : 0);
      if (ends == 0) continue;
      // A second occupant, or one conductor occupying the pin twice.
      if (ends > 1 || found != null) return null;
      found = ConductorRef(entry.key, i);
      foundLink = entry.value;
    }
  }
  final ref = found;
  final link = foundLink;
  // Unreachable while (1) holds — a full pin has an occupant — and kept so
  // the function is total rather than relying on that agreement.
  if (ref == null || link == null) return null;

  // (3) NOT THE LAST CONDUCTOR.
  if (link.conductors.length < 2) return null;

  // (4) NOT ALREADY THERE.
  final c = link.conductors[ref.index];
  final far = _landsOn(c.from, target.portId) ? c.to : c.from;
  if (far is PortEndpoint) {
    final farPort = doc.ports[far.portId];
    if (farPort == null) return null;
    if (farPort.deviceId == towardsDeviceId) return null;
  }

  return SetSplit(
    conductor: ref,
    linkDesignator: link.designator,
    conductorsBefore: link.conductors.length,
    role: c.role,
  );
}

/// Evaluates `TOP-001`..`TOP-005` for connecting [from] to [to] in [doc],
/// returning the FIRST refusal in [ConnectRule.values] order, or
/// [ConnectAllowed].
///
/// [ontoLink] names the `Link` the new conductor would join, and exists
/// solely so `TOP-002` can be evaluated as canon states it — *"two
/// conductors may not duplicate the same ordered port pair ON THE SAME
/// LINK"*. `null` (the default, and what `ConnectPortsCommand` means)
/// says the conductor lands on a link that does not exist yet, where
/// `TOP-002` is structurally unreachable: a fresh `Link` carries exactly
/// one conductor and one conductor cannot duplicate itself.
///
/// The alternative — reading `TOP-002` as "no two conductors ANYWHERE may
/// share an ordered pair" — was rejected. It is a strictly different and
/// stricter rule than the one CR-017 ratified, it would make a legitimate
/// second run between the same two pins (a redundant fibre pair, a
/// re-pull left in place) model-ILLEGAL with no escape, and inventing a
/// tier-1 rule is precisely what canon §5's opening line forbids: *"a rule
/// not listed here does not exist"*.
///
/// [freeing] is DR-014's pending split — conductors this same gesture will
/// lift out before it writes, so `TOP-003` must count the pin as they will
/// leave it rather than as it stands. It reaches `TOP-003` and NOTHING
/// ELSE, because nothing else it could reach is affected: `TOP-004` and
/// `TOP-005` ask about devices and shelves, `TOP-001` compares the two
/// pins the user picked, and `TOP-002` is unreachable without an
/// `ontoLink`. Threading it into all five would be five places for a
/// future rule to be wrong.
ConnectVerdict evaluateConnect(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to, {
  Uuid? ontoLink,
  Set<ConductorRef> freeing = const <ConductorRef>{},
}) {
  for (final rule in ConnectRule.values) {
    // Exhaustive over the enum, so a sixth rule cannot be declared
    // without a check — the compiler enforces what the file header
    // promises.
    final refusal = switch (rule) {
      ConnectRule.endpointResolves => _endpointResolves(doc, from, to),
      ConnectRule.hostResolves => _hostResolves(doc, from, to),
      ConnectRule.notSelf => _notSelf(from, to),
      ConnectRule.notDuplicatePair => _notDuplicatePair(
        doc,
        from,
        to,
        ontoLink,
      ),
      ConnectRule.withinMaxConnections => _withinMaxConnections(
        doc,
        from,
        to,
        freeing,
      ),
    };
    if (refusal != null) return refusal;
  }
  return const ConnectAllowed();
}

// ─────────────────────────────────────────────────────────────────────
// TOP-004 — every endpoint must resolve.
// ─────────────────────────────────────────────────────────────────────

ConnectRefused? _endpointResolves(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
) {
  for (final t in [from, to]) {
    if (!doc.devices.containsKey(t.deviceId)) {
      return ConnectRefused(
        ConnectRule.endpointResolves,
        '${t.citation} belongs to ${t.deviceDesignator}, which is no '
        'longer in this document.',
      );
    }
    // A tombstone is CR-095's grave marker, not an absence: the port row
    // may still be in `doc.ports` while the document records it as
    // deleted. Landing a conductor on it would resurrect it silently.
    if (doc.tombstones.containsKey(t.portId)) {
      return ConnectRefused(
        ConnectRule.endpointResolves,
        '${t.citation} has been deleted from this document.',
      );
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// TOP-005 — a shelf host must resolve to a container, without a cycle.
// ─────────────────────────────────────────────────────────────────────

ConnectRefused? _hostResolves(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
) {
  for (final t in [from, to]) {
    final fault = _shelfChainFault(doc, t);
    if (fault != null) {
      return ConnectRefused(ConnectRule.hostResolves, fault);
    }
  }
  return null;
}

/// The sentence describing what is wrong with [t]'s shelf-host chain, or
/// `null` when there is nothing wrong with it.
///
/// Walks child -> parent, which is the only direction containment points
/// (CR-029: the parent never owns a list). A device that is not
/// shelf-placed has no chain and passes immediately, which is the
/// overwhelmingly normal case.
String? _shelfChainFault(RackDocument doc, ConnectTarget t) {
  var current = doc.devices[t.deviceId];
  // A missing device is TOP-004's refusal, already returned above; this
  // guard is here so the walk is total rather than relying on ordering.
  if (current == null) return null;

  final visited = <Uuid>{current.id};
  while (true) {
    final placement = current!.placement;
    if (placement is! ShelfPlacement) return null;

    final host = doc.devices[placement.hostDeviceId];
    if (host == null) {
      return '${t.deviceDesignator} sits on a shelf that is not in this '
          'document.';
    }
    final body = bodyFor(host, doc.templates);
    if (body == null || !body.isContainer) {
      return '${t.deviceDesignator} sits on ${host.designator}, which is '
          'not a container.';
    }
    if (!visited.add(host.id)) {
      return "${t.deviceDesignator}'s shelf chain loops back on itself "
          'through ${host.designator}.';
    }
    current = host;
  }
}

// ─────────────────────────────────────────────────────────────────────
// TOP-001 — a conductor may not connect a port to itself.
// ─────────────────────────────────────────────────────────────────────

ConnectRefused? _notSelf(ConnectTarget from, ConnectTarget to) {
  // Compared on the DERIVED id, not on `(deviceId, portKey)`: the id is
  // what actually lands on the conductor, and it is the identity two
  // independently-resolved targets must agree on.
  if (from.portId != to.portId) return null;
  return ConnectRefused(
    ConnectRule.notSelf,
    '${from.citation} cannot connect to itself.',
  );
}

// ─────────────────────────────────────────────────────────────────────
// TOP-002 — no duplicate ordered pair on one link.
// ─────────────────────────────────────────────────────────────────────

ConnectRefused? _notDuplicatePair(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
  Uuid? ontoLink,
) {
  if (ontoLink == null) return null;
  final link = doc.links[ontoLink];
  if (link == null) return null;

  for (final c in link.conductors) {
    // ORDERED. (a -> b) duplicates (a -> b) and NOT (b -> a): canon says
    // "the same ordered port pair", and a reversed pair is a second,
    // differently-directed path that `DIR-001` — a tier-2 rule, deferred
    // — is the one entitled to have an opinion about.
    if (_landsOn(c.from, from.portId) && _landsOn(c.to, to.portId)) {
      return ConnectRefused(
        ConnectRule.notDuplicatePair,
        '${link.designator} already runs a conductor from ${from.citation} '
        'to ${to.citation}.',
      );
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// TOP-003 — live conductor count vs. effective maxConnections.
// ─────────────────────────────────────────────────────────────────────

ConnectRefused? _withinMaxConnections(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
  Set<ConductorRef> freeing,
) {
  for (final t in [from, to]) {
    final max = t.effectiveMaxConnections;
    // NULL IS UNBOUNDED, NOT UNKNOWN. A Cresnet drop or a 70 V tap is a
    // node on a shared medium and the whole point of it is that more than
    // one thing lands there; canon's word is "EFFECTIVE maxConnections"
    // and `ConnectTarget.effectiveMaxConnections` is where the difference
    // between that and the declared default of 1 is argued.
    if (max == null) continue;
    if (max <= 0) {
      // A pin declaring zero is not "full", it is "not a socket". Saying
      // "already carries 0 of 0" would read as a state the user could
      // clear by unplugging something.
      return ConnectRefused(
        ConnectRule.withinMaxConnections,
        '${t.citation} accepts no connections.',
      );
    }
    final live = portConductorCount(doc, t.portId, freeing: freeing);
    if (live + 1 > max) {
      return ConnectRefused(
        ConnectRule.withinMaxConnections,
        '${t.citation} already carries $live of $max connections.',
      );
    }
  }
  return null;
}
