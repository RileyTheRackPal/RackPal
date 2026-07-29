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
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
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
int portConductorCount(RackDocument doc, Uuid portId) {
  var count = 0;
  for (final link in doc.links.values) {
    for (final c in link.conductors) {
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
ConnectVerdict evaluateConnect(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to, {
  Uuid? ontoLink,
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
      ConnectRule.withinMaxConnections => _withinMaxConnections(doc, from, to),
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
    final live = portConductorCount(doc, t.portId);
    if (live + 1 > max) {
      return ConnectRefused(
        ConnectRule.withinMaxConnections,
        '${t.citation} already carries $live of $max connections.',
      );
    }
  }
  return null;
}
