// The six tier-2 rules, evaluated for ONE prospective connection
// (`#272`..`#277`, M5-D, docs/02 §5.2).
//
// ═════════════════════════════════════════════════════════════════════
// THESE HESITATE. THEY DO NOT REFUSE.
// ═════════════════════════════════════════════════════════════════════
// CR-017's frame is *"the gesture may hesitate. The document may not
// lie."* Tier 1 (`connect_rules.dart`) refuses and offers nothing to
// escape to. This tier springs the wire back, shows a chip carrying the
// reason and its remedies, and ALWAYS offers `[ Connect anyway ]`.
// Overriding creates the Link, and the same condition is then a tier-3
// finding in the issues list.
//
// NOTHING FILES THAT FINDING, AND NOTHING SHOULD. `Finding` is computed
// and never stored (docs/02 §4.8, M5-B1), so `[ Connect anyway ]` writes
// the Link and stops. The finding appears because the tier-3 pass
// recomputes it. A "file the finding" path here would be the stored
// finding that section rules against, arriving through the back door.
//
// ═════════════════════════════════════════════════════════════════════
// THE REGISTRY'S FAMILY TAXONOMY IS THIS TIER'S INPUT
// ═════════════════════════════════════════════════════════════════════
// Three of the six are family-versus-family, and the seed registry was
// authored that way on purpose. `seed_registries.dart` says so for the
// flagship: HDBaseT is its own family because *"patching an HDBaseT
// output into a switch does not work and its 100 W PoH can damage the
// switch. That check (`SIG-001`) is the highest-value validation in the
// product and is only expressible because this is its own family."* The
// same split carries `DIR-003` (`ctl.ir_emitter` vs `ctl.ir_receiver`)
// and `ELE-006` (`audio.speaker_cv` vs `audio.speaker_lowz`).
//
// docs/02 §5.2 says `PortDef.pinoutVariant` *"exists solely to make
// `DIR-003` detectable"*. It does not: every value the catalog authors is
// a connector wiring pinout (`xantech-stereo`, `mono-tip-sleeve`), and
// the emitter/receiver distinction is the family split. See DR-110
// §11.109.6.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart' show PortDirection;
import 'package:rackpal_core/src/units/ids.dart';

/// The six rules a connect gesture can spring back on, IN EVALUATION
/// ORDER (first failure wins, as tier 1 does).
///
/// THE ORDER IS BY WHAT DAMAGES HARDWARE FIRST. `connect_rules.dart`
/// orders outside-in by dependency because each of its rules reads a fact
/// the previous one guarantees. Nothing here depends on anything else
/// here: all six read the two pins and answer independently. So the tie
/// is broken on consequence, because when two chips could show, the one
/// a person needs is the one about the thing that lets out smoke.
enum SpringBackRule {
  /// `SIG-001` — HDBaseT into a terminating Ethernet port. **The
  /// flagship.** 100 W of PoH into a switch port damages the switch.
  hdbasetIntoEthernet('SIG-001'),

  /// `DIR-003` — an IR emitter output into an IR receiver jack. Destroys
  /// the emitter and can damage the PSU.
  irEmitterIntoReceiver('DIR-003'),

  /// `ELE-006` — a constant-voltage speaker on a low-Z amplifier output,
  /// or the reverse.
  speakerImpedanceMismatch('ELE-006'),

  /// `DIR-001` — source to source, or sink to sink.
  directionMismatch('DIR-001'),

  /// `SIG-002` — the sink does not accept the source's family and no
  /// adapter is declared.
  familyNotAccepted('SIG-002'),

  /// `CON-001` — the connectors do not mate and no adapter is declared.
  /// LAST, because it is the one most often satisfied by data somebody is
  /// about to add rather than by picking a different jack.
  connectorsDoNotMate('CON-001');

  const SpringBackRule(this.id);

  /// The canonical rule id, e.g. `"SIG-001"`.
  final String id;
}

/// A rule-specific action the chip offers, beyond the three every chip
/// carries.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE VALUE, AND THAT IS THE HONEST COUNT
/// ═══════════════════════════════════════════════════════════════════════
/// `design-ux-schematic.md §2.1` designs one chip in full and names three
/// actions on it: `[ Insert HDBaseT receiver ] [ Pick a different port ]
/// [ Why? ]`. Two of those are generic and the third is `SIG-001`'s.
/// docs/02 §5.2's table names a remedy for `SIG-001` and for no other
/// rule.
///
/// So this enum has one member. Inventing labels for the other five would
/// be putting words in a designer's mouth and shipping them as though the
/// corpus had said them.
enum SpringBackRemedy {
  /// CR-015: it inserts a DEVICE, not an annotation, and *"creates both
  /// links in one undo step"* (docs/05 §5).
  insertHdbasetReceiver('Insert HDBaseT receiver');

  const SpringBackRemedy(this.label);

  /// What the chip's button reads.
  final String label;
}

/// What [evaluateSpringBack] decided.
@immutable
sealed class SpringBackVerdict {
  const SpringBackVerdict();
}

/// No tier-2 rule objects. Says nothing about tier 1, which
/// `evaluateConnect` answers, and nothing about tier 3.
@immutable
final class SpringBackClear extends SpringBackVerdict {
  const SpringBackClear();
}

/// The wire springs back, and this is the chip.
@immutable
final class SpringBackChip extends SpringBackVerdict {
  const SpringBackChip({
    required this.rule,
    required this.headline,
    required this.explanation,
    this.remedies = const [],
  });

  final SpringBackRule rule;

  /// The first line: what just happened, naming the real pins.
  /// `design-ux-schematic.md §2.1`'s worked chip is *"HDBaseT output
  /// cannot terminate on an Ethernet switch port."*
  final String headline;

  /// The second line: WHY, in the trade's terms. The same chip continues
  /// *"HDBaseT uses Ethernet cabling but is not interoperable; PoH may
  /// damage the switch."* A chip that only states the rule is the nag
  /// §2.1 contrasts a rule engine with.
  final String explanation;

  /// Rule-specific actions only.
  ///
  /// `[ Connect anyway ]`, `[ Pick a different port ]` and `[ Why? ]` are
  /// DELIBERATELY ABSENT. They are on every chip without exception
  /// (`#278`, CR-017), so making them per-rule data would make it
  /// possible to ship a chip missing the escape hatch that DR-011.5 says
  /// tier 2 must always have. The widget renders them unconditionally.
  final List<SpringBackRemedy> remedies;

  /// `"SIG-001"`.
  String get ruleId => rule.id;

  @override
  String toString() => '$ruleId: $headline';
}

/// Whether connecting [from] to [to] springs back, and with what chip.
///
/// [ontoLink] is the Link the gesture would join, when it joins an
/// existing one: `DIR-001` reads its net, because a passive splitter
/// legitimately drives several sinks from one source.
SpringBackVerdict evaluateSpringBack(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to, {
  Uuid? ontoLink,
}) {
  for (final rule in SpringBackRule.values) {
    final chip = switch (rule) {
      SpringBackRule.hdbasetIntoEthernet => _hdbasetIntoEthernet(doc, from, to),
      SpringBackRule.irEmitterIntoReceiver => _irEmitterIntoReceiver(from, to),
      SpringBackRule.speakerImpedanceMismatch => _speakerMismatch(from, to),
      SpringBackRule.directionMismatch => _directionMismatch(
        doc,
        from,
        to,
        ontoLink,
      ),
      SpringBackRule.familyNotAccepted => _familyNotAccepted(
        doc,
        from,
        to,
        ontoLink,
      ),
      SpringBackRule.connectorsDoNotMate => _connectorsDoNotMate(
        doc,
        from,
        to,
        ontoLink,
      ),
    };
    if (chip != null) return chip;
  }
  return const SpringBackClear();
}

// ─────────────────────────────────────────────────────────────────────
// SIG-001 — HDBaseT into a terminating Ethernet port (DR-113)
// ─────────────────────────────────────────────────────────────────────

const SignalFamilyId _hdbaset = SignalFamilyId('video.hdbaset');
const SignalFamilyId _ethernet = SignalFamilyId('net.ethernet');

SpringBackChip? _hdbasetIntoEthernet(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
) {
  final hdbaset = _oneOf(from, to, _hdbaset);
  final ethernet = _oneOf(from, to, _ethernet);
  if (hdbaset == null || ethernet == null) return null;

  // DR-113: THE JOINT, NOT THE PATH. A patch panel passes the signal
  // through to another connector, so landing on one is ordinary
  // structured cabling and not the damaging act. Whether the far side of
  // the panel reaches a switch is a path question, and CR-017 sends path
  // questions to tier 3 for the same reason it demoted Dante and AVB:
  // the link being drawn may be the one that completes the path.
  if (_isPassthrough(doc, ethernet)) return null;

  return SpringBackChip(
    rule: SpringBackRule.hdbasetIntoEthernet,
    headline:
        '${hdbaset.citation} is HDBaseT and cannot terminate on '
        '${ethernet.citation}.',
    explanation:
        'HDBaseT uses Ethernet cabling but is not interoperable, and its '
        'PoH supply may damage the equipment on the other end.',
    remedies: const [SpringBackRemedy.insertHdbasetReceiver],
  );
}

bool _isPassthrough(RackDocument doc, ConnectTarget t) {
  final device = doc.devices[t.deviceId];
  if (device == null) return false;
  return bodyFor(device, doc.templates)?.isPassthrough ?? false;
}

// ─────────────────────────────────────────────────────────────────────
// DIR-003 — an IR emitter output into an IR receiver jack
// ─────────────────────────────────────────────────────────────────────

const SignalFamilyId _irEmitter = SignalFamilyId('ctl.ir_emitter');
const SignalFamilyId _irReceiver = SignalFamilyId('ctl.ir_receiver');

SpringBackChip? _irEmitterIntoReceiver(ConnectTarget from, ConnectTarget to) {
  final emitter = _oneOf(from, to, _irEmitter);
  final receiver = _oneOf(from, to, _irReceiver);
  if (emitter == null || receiver == null) return null;
  return SpringBackChip(
    rule: SpringBackRule.irEmitterIntoReceiver,
    headline:
        '${emitter.citation} drives an IR emitter and '
        '${receiver.citation} expects an IR sensor.',
    explanation:
        'The emitter output supplies current to an LED. Landing it on a '
        'receiver jack destroys the emitter and can damage the supply.',
  );
}

// ─────────────────────────────────────────────────────────────────────
// ELE-006 — constant-voltage speaker on a low-Z output, or the reverse
// ─────────────────────────────────────────────────────────────────────

const SignalFamilyId _speakerCv = SignalFamilyId('audio.speaker_cv');
const SignalFamilyId _speakerLowZ = SignalFamilyId('audio.speaker_lowz');

SpringBackChip? _speakerMismatch(ConnectTarget from, ConnectTarget to) {
  final cv = _oneOf(from, to, _speakerCv);
  final lowZ = _oneOf(from, to, _speakerLowZ);
  if (cv == null || lowZ == null) return null;
  return SpringBackChip(
    rule: SpringBackRule.speakerImpedanceMismatch,
    headline:
        '${cv.citation} is a constant-voltage line and '
        '${lowZ.citation} is low impedance.',
    explanation:
        'A 70 V line needs a transformer at the speaker, and a low-Z '
        'speaker across one is a near short on the amplifier.',
  );
}

// ─────────────────────────────────────────────────────────────────────
// DIR-001 — source to source, or sink to sink
// ─────────────────────────────────────────────────────────────────────

SpringBackChip? _directionMismatch(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
  Uuid? ontoLink,
) {
  final a = from.def.direction;
  final b = to.def.direction;
  final bothSources = a == PortDirection.source && b == PortDirection.source;
  final bothSinks = a == PortDirection.sink && b == PortDirection.sink;
  if (!bothSources && !bothSinks) return null;

  // EXCEPTION ONE: eARC. Both ends declare a return channel, so the
  // audio legitimately travels back up a cable whose video went the
  // other way. Miss this and every eARC design in the product fires.
  if (from.def.returnChannel != null && to.def.returnChannel != null) {
    return null;
  }
  // EXCEPTION TWO: a passive splitter drives several sinks from one
  // source, so sink-to-sink on its net is the topology working.
  if (_netOf(doc, ontoLink)?.topology == NetTopologyKind.passiveSplit) {
    return null;
  }

  return SpringBackChip(
    rule: SpringBackRule.directionMismatch,
    headline: bothSources
        ? '${from.citation} and ${to.citation} are both outputs.'
        : '${from.citation} and ${to.citation} are both inputs.',
    explanation: bothSources
        ? 'Two sources driving one another has no signal path, and each '
              'may be driving into the other output stage.'
        : 'Neither end drives the cable, so nothing reaches either input.',
  );
}

Net? _netOf(RackDocument doc, Uuid? linkId) {
  if (linkId == null) return null;
  final link = doc.links[linkId];
  if (link == null) return null;
  for (final service in link.services) {
    final net = doc.nets[service.netId];
    if (net != null) return net;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// SIG-002 — the sink does not accept the source's family
// ─────────────────────────────────────────────────────────────────────

SpringBackChip? _familyNotAccepted(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
  Uuid? ontoLink,
) {
  // WHICH END IS THE SINK MATTERS, and neither being one is not this
  // rule's business: `DIR-001` above has already spoken about a pair
  // with no sink, and a bidirectional pin accepts by construction.
  final (source, sink) = switch ((from.def.direction, to.def.direction)) {
    (PortDirection.source, PortDirection.sink) => (from, to),
    (PortDirection.sink, PortDirection.source) => (to, from),
    _ => (null, null),
  };
  if (source == null || sink == null) return null;
  // A PASSTHROUGH IS A PHYSICAL JOINT AND NOT A SIGNAL ENDPOINT, which is
  // DR-113's reasoning one rule along and was found by that ruling's own
  // near-miss test (§11.112.5). A patch panel is passive copper: it
  // carries whatever the cable carries, and its RJ45 declares
  // `net.ethernet` because that is what the jack IS, not a claim about
  // what may pass through it. Asking a panel to enumerate every family
  // that runs on RJ45 is a list nobody can finish, and until it were
  // finished this rule would spring back on ordinary structured cabling.
  //
  // `CON-001` deliberately still applies to a passthrough: you really do
  // plug into that jack, so the connectors really must mate. The split is
  // physical rules yes, signal rules no.
  if (_isPassthrough(doc, sink)) return null;
  if (sink.acceptsFamily(source.def.signalFamily)) return null;
  if (_adapterSatisfies(doc, ontoLink, SpringBackRule.familyNotAccepted.id)) {
    return null;
  }
  return SpringBackChip(
    rule: SpringBackRule.familyNotAccepted,
    headline:
        '${sink.citation} does not accept '
        '${source.def.signalFamily.v}.',
    explanation:
        'The jack carries ${sink.def.signalFamily.v}, and nothing on this '
        'cable converts one to the other.',
  );
}

// ─────────────────────────────────────────────────────────────────────
// CON-001 — the connectors do not mate
// ─────────────────────────────────────────────────────────────────────

SpringBackChip? _connectorsDoNotMate(
  RackDocument doc,
  ConnectTarget from,
  ConnectTarget to,
  Uuid? ontoLink,
) {
  final a = from.def.connector;
  final b = to.def.connector;
  final defA = doc.registries.connectorTypes[a];
  // EMPTY IS UNKNOWN AND THIS RULE SKIPS IT (G4, `#255`). Forty of the
  // forty-nine seeded connectors declare `matesWith`; a rule that fired
  // on an empty list would report a mating failure for every connector
  // nobody has reached yet, which is a false FAIL on a half-built table.
  if (defA == null || defA.matesWith.isEmpty) return null;
  if (defA.matesWith.contains(b)) return null;
  // SATISFIED BY DATA (CR-015, docs/02 §5.2): declaring the adapter
  // clears it with no acknowledgement. Do not make somebody acknowledge
  // a thing they have already fixed.
  if (_adapterSatisfies(doc, ontoLink, SpringBackRule.connectorsDoNotMate.id)) {
    return null;
  }
  return SpringBackChip(
    rule: SpringBackRule.connectorsDoNotMate,
    headline: '${from.citation} and ${to.citation} do not mate.',
    explanation:
        'One is ${a.v} and the other is ${b.v}, and no adapter is '
        'declared on this cable.',
  );
}

bool _adapterSatisfies(RackDocument doc, Uuid? linkId, String ruleId) {
  if (linkId == null) return false;
  final link = doc.links[linkId];
  if (link == null) return false;
  for (final adapter in link.inlineAdapters) {
    if (adapter.satisfiesRuleIds.contains(ruleId)) return true;
  }
  return false;
}

/// The end whose family is [family], or null when neither is.
///
/// Returns ONE end rather than a bool so the chip can name the actual
/// pin. `ConnectRefused`'s contract carries over: a sentence that says
/// which jack is which is the difference between a remedy and a riddle.
ConnectTarget? _oneOf(ConnectTarget a, ConnectTarget b, SignalFamilyId family) {
  if (a.def.signalFamily == family) return a;
  if (b.def.signalFamily == family) return b;
  return null;
}
