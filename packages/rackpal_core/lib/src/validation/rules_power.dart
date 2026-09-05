// Tier-3 power rules: `NET-001`, `PWR-001`, `PWR-003` (`#281`-`#283`).
//
// ═════════════════════════════════════════════════════════════════════
// EVERY ROLLUP HERE REPORTS ITS UNKNOWN COUNT (G4 / CR-114)
// ═════════════════════════════════════════════════════════════════════
// *"null is unknown, never estimated. `0` means measured zero. Every
// rollup reports its unknown count rather than fabricating a total."*
// That is the invariant these three rules are most exposed to, because
// all three are sums and a sum is exactly where an absent figure
// disappears quietly.
//
// So a device with no `typicalWatts` is COUNTED AS UNKNOWN and named in
// the sentence, never treated as drawing nothing. A rule that summed
// nulls to zero would report a 15 A circuit as comfortable while three
// amplifiers on it had no data at all, which is worse than saying
// nothing: it is a green light nobody earned.
//
// ═════════════════════════════════════════════════════════════════════
// `PWR-001` IS A PLANNING ESTIMATE AND SAYS SO IN ITS OWN SENTENCE
// ═════════════════════════════════════════════════════════════════════
// DR-079 §11.78.4 and `Circuit.continuousLimitAmps`'s own doc: eighty
// percent of the breaker is the continuous-load allowance, and this is
// not a load calculation. There are no demand factors here, nothing in
// this product classifies a load as continuous, and what is actually
// summed is typical draw times a diversity factor, in VA — a third
// quantity again. The finding therefore names the circuit to look at
// first and asserts nothing about NEC, and the message carries that
// rather than leaving it to a comment nobody reads at 2am.

import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/model/circuit.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// A sum that remembers what it could not add.
///
/// THE PAIR IS THE POINT. `total` alone is a number that looks complete
/// whatever went into it, and CR-114 requires the rollup to report its
/// unknown count rather than fabricating one. Carrying them together
/// makes it impossible to quote the total without having the other half
/// in hand.
typedef _Sum = ({int total, List<DeviceInstance> unknown});

/// The clause naming what a sum could not see, or `''`.
///
/// EMPTY WHEN NOTHING IS UNKNOWN, so a complete sum reads as a plain
/// sentence and an incomplete one visibly is not. Names up to three
/// devices and then counts, because a circuit with nine unknown devices
/// wants the count and a person chasing two wants the designators.
String _unknownClause(List<DeviceInstance> unknown) {
  if (unknown.isEmpty) return '';
  final names = unknown.map((d) => d.designator).toList()..sort();
  final said = names.length <= 3
      ? names.join(', ')
      : '${names.take(3).join(', ')} and ${names.length - 3} more';
  return ' ${names.length == 1 ? 'One device' : '${names.length} devices'} '
      'on it ${names.length == 1 ? 'has' : 'have'} no figure at all '
      '($said), so the real total is higher than this.';
}

/// The clause naming devices charged their IEEE class ceiling rather
/// than a stated draw (M5-H2, DR-125).
///
/// **A CEILING IS NOT A MEASUREMENT AND THE SENTENCE MUST NOT IMPLY IT
/// IS.** The domain review's point: a PoE+ access point is rated at 30 W
/// and commonly settles around 15 to 20, so a switch reported over budget
/// purely on class ceilings may be comfortably inside it on the job. The
/// arithmetic stays conservative, which `_ceilingFor` argues is the only
/// defensible direction for a PSE, and the honesty is carried in the
/// words instead.
///
/// Same shape as [_unknownClause] on purpose: designators up to three,
/// then a count.
String _estimatedClause(List<DeviceInstance> estimated) {
  if (estimated.isEmpty) return '';
  final names = estimated.map((d) => d.designator).toList()..sort();
  final said = names.length <= 3
      ? names.join(', ')
      : '${names.take(3).join(', ')} and ${names.length - 3} more';
  return ' ${names.length == 1 ? 'One of them' : '${names.length} of them'} '
      '${names.length == 1 ? 'states' : 'state'} no measured draw and '
      '${names.length == 1 ? 'was' : 'were'} charged the class ceiling '
      '($said), so the real total is likely lower.';
}

// ─────────────────────────────────────────────────────────────────────
// PWR-003 — outlets consumed exceed outlets provided in the rack
// ─────────────────────────────────────────────────────────────────────

/// `PWR-003` — a rack's devices want more outlets than it provides.
List<Finding> rulePwr003(RackDocument doc) {
  final out = <Finding>[];
  for (final rack in doc.racks.values) {
    var provided = 0;
    var consumed = 0;
    final unknown = <DeviceInstance>[];
    final members = <Uuid>[];
    for (final device in doc.devices.values) {
      if (!belongsToRack(device, rack.id, doc.devices)) continue;
      members.add(device.id);
      final loads = resolveDeviceLoads(
        device,
        bodyFor(device, doc.templates),
      );
      provided += loads.outletsProvided ?? 0;
      // AN ABSENT `outletsConsumed` IS UNKNOWN, NOT ZERO. A PDU provides
      // and a device consumes; a device whose template says nothing
      // about either is a device nobody has counted, and adding zero for
      // it is how a rack reads as comfortable while three of its boxes
      // are unaccounted for.
      final want = loads.outletsConsumed;
      if (want == null) {
        unknown.add(device);
      } else {
        consumed += want;
      }
    }
    if (consumed <= provided) continue;
    out.add(
      Finding(
        ruleId: 'PWR-003',
        severity: Severity.error,
        message:
            '${rack.designator} provides $provided outlets and its devices '
            'need $consumed.${_unknownClause(unknown)}',
        // THE RACK AND ITS MEMBERS. The fingerprint has to move when the
        // population does: acknowledging "this rack is over" while three
        // devices are in it should not survive somebody adding a fourth.
        targets: [rack.id, ...members],
        primaryEntityId: rack.id,
        // THE ONLY TIER-3 RULE WITH A REMEDY, AND THE REVIEW IS WHY
        // (DR-128 §11.127.5). The M5-H2 reviewer's own sentence for this
        // rule is "somebody will arrive with a power strip nobody drew,
        // in a rack whose load was worked out without it", which names
        // both the defect and its answer. The other twelve tier-3 rules
        // have no remedy because nobody has designed one.
        remedy: FindingRemedy.addRackPdu,
      ),
    );
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// NET-001 — PD draw on a switch exceeds its PoE budget
// ─────────────────────────────────────────────────────────────────────

/// The IEEE 802.3 PSE-side ceiling for [spec], in watts.
///
/// PUBLISHED STANDARD, and the one place in this file that is not a
/// project's own data: `sources.md` §1 already cites these as *"IEEE
/// 802.3-2018 Clause 33/145 PSE/PD power budgets"*. A PD that declares a
/// class but no watts is charged its class ceiling, which is the
/// conservative direction and the only defensible one — under-charging
/// it would let a switch read as within budget on devices nobody sized.
int? _ceilingFor(PoeSpec spec) {
  if (spec.watts != null) return spec.watts;
  return switch (spec.standard) {
    PoeStandard.af => 15,
    PoeStandard.at => 30,
    PoeStandard.btType3 => 60,
    PoeStandard.btType4 => 90,
    // PoH IS NOT 802.3 AND HAS NO ROW HERE (`#813`). A PoH port declares
    // a role and no standard, deliberately, so this returns null and the
    // device counts as UNKNOWN rather than being charged an IEEE figure
    // that does not describe it.
    null => null,
  };
}

/// `NET-001` — the sum of PD draw on a switch exceeds `poeBudgetWatts`.
List<Finding> ruleNet001(RackDocument doc) {
  final out = <Finding>[];
  for (final device in doc.devices.values) {
    final body = bodyFor(device, doc.templates);
    final budget = body?.power.poeBudgetWatts;
    // NO BUDGET IS NOT A ZERO BUDGET. Most devices are not switches, and
    // a null here means "this is not a PSE", which is why the rule is
    // silent rather than reporting every device in the project as over.
    if (budget == null || budget <= 0) continue;

    var drawn = 0;
    final unknown = <DeviceInstance>[];
    final estimated = <DeviceInstance>[];
    final powered = <Uuid>[];
    for (final port in body!.ports) {
      if (port.poe?.role != PoeRole.pse) continue;
      final portId = derivePortId(device.id, port.key);
      for (final peer in _peersOf(doc, portId)) {
        final peerDevice = doc.devices[peer.deviceId];
        if (peerDevice == null) continue;
        final peerBody = bodyFor(peerDevice, doc.templates);
        PortDef? peerPort;
        for (final def in peerBody?.ports ?? const <PortDef>[]) {
          if (def.key == peer.templatePortKey) {
            peerPort = def;
            break;
          }
        }
        final spec = peerPort?.poe;
        if (spec == null || spec.role != PoeRole.pd) continue;
        powered.add(peerDevice.id);
        final ceiling = _ceilingFor(spec);
        if (ceiling == null) {
          unknown.add(peerDevice);
        } else {
          drawn += ceiling;
          // CHARGED ITS CLASS CEILING RATHER THAN A STATED DRAW, and the
          // sentence has to say so (M5-H2, DR-125). A PoE+ access point
          // is rated at 30 W and commonly settles around 15 to 20, so a
          // switch reported as over budget on class ceilings alone may be
          // comfortably within it in the field. The arithmetic stays
          // conservative, which is the only defensible direction for a
          // PSE, but presenting a ceiling as if it were a measurement is
          // how a designer stops trusting the rule.
          if (spec.watts == null) estimated.add(peerDevice);
        }
      }
    }
    if (drawn <= budget) continue;
    out.add(
      Finding(
        ruleId: 'NET-001',
        severity: Severity.error,
        message:
            '${device.designator} has a $budget W PoE budget and the '
            'devices on it draw up to $drawn W.'
            '${_estimatedClause(estimated)}${_unknownClause(unknown)}',
        targets: [device.id, ...powered],
        primaryEntityId: device.id,
      ),
    );
  }
  return out;
}

/// Every port on the far end of a conductor from [portId].
List<Port> _peersOf(RackDocument doc, Uuid portId) {
  final out = <Port>[];
  for (final link in doc.links.values) {
    for (final conductor in link.conductors) {
      final ends = [conductor.from, conductor.to].whereType<PortEndpoint>();
      if (!ends.any((e) => e.portId == portId)) continue;
      for (final end in ends) {
        if (end.portId == portId) continue;
        final port = doc.ports[end.portId];
        if (port != null) out.add(port);
      }
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// PWR-001 — a circuit's estimated load exceeds 80% of its breaker
// ─────────────────────────────────────────────────────────────────────

/// `PWR-001` — a circuit's estimated VA exceeds its continuous allowance.
///
/// A PLANNING ESTIMATE, AND THE SENTENCE SAYS SO. See the file header and
/// DR-079 §11.78.4: this names the circuit to look at first and asserts
/// nothing about NEC.
List<Finding> rulePwr001(RackDocument doc) {
  final out = <Finding>[];
  for (final circuit in doc.circuits.values) {
    final sum = _circuitVa(doc, circuit);
    // THE ALLOWANCE IN VA, from the circuit's own voltage. `Circuit.volts`
    // is authoritative downstream and `Rack.lineVoltage` does not exist
    // (CR-039), so there is one place to read it from.
    final allowanceVa = circuit.continuousLimitAmps * circuit.volts;
    if (allowanceVa <= 0) continue;
    if (sum.total <= allowanceVa) continue;
    out.add(
      Finding(
        ruleId: 'PWR-001',
        severity: Severity.warning,
        message:
            '${circuit.designator} is estimated at ${sum.total} VA against '
            'a ${circuit.continuousLimitAmps} A continuous allowance '
            '($allowanceVa VA) on a ${circuit.breakerAmps} A breaker. '
            'This is a planning estimate on typical draw and a diversity '
            'factor, not a load calculation: look at this circuit first '
            'rather than treating it as a code '
            'violation.${_unknownClause(sum.unknown)}',
        targets: [circuit.id],
        primaryEntityId: circuit.id,
      ),
    );
  }
  return out;
}

/// The estimated VA on [circuit], and the devices it could not add.
_Sum _circuitVa(RackDocument doc, Circuit circuit) {
  var total = 0;
  final unknown = <DeviceInstance>[];
  final counted = <String>{};
  for (final port in doc.ports.values) {
    if (port.circuitId != circuit.id) continue;
    final device = doc.devices[port.deviceId];
    if (device == null) continue;
    // ONCE PER DEVICE, not once per inlet. A redundant-PSU device is two
    // inlets on one circuit (AC-020) and counting it twice would double
    // a figure the whole rule is about.
    if (!counted.add(device.id.v)) continue;
    final loads = resolveDeviceLoads(device, bodyFor(device, doc.templates));
    final va = loads.apparentVA;
    if (va == null) {
      unknown.add(device);
    } else {
      // THE DIVERSITY FACTOR, from the project's own settings. docs/02
      // §5.3 gives the sum as *"typical x diversity factor, in VA"*, and
      // `apparentVA` is already the VA half.
      // ═════════════════════════════════════════════════════════════
      // THE DIVERSITY FACTOR IS PER CATEGORY, AND THIS IS ITS FIRST
      // CONSUMER
      // ═════════════════════════════════════════════════════════════
      // `ProjectSettings.diversityFactorsByCategory` has been a field
      // with no reader since M0. AC-020 gives its worked case
      // (*"amplifiers default 350 permille"*) and docs/02 §5.3 gives the
      // sum as *"typical x diversity factor, in VA"*, so `PWR-001` is
      // the rule that field exists for.
      //
      // AN ABSENT ENTRY APPLIES NO DE-RATING, and that is not the
      // fabrication G4 forbids. A diversity factor is a REDUCTION
      // somebody claims; its absence means nobody has claimed one, and
      // the honest reading of no claim is the device's full VA. Reading
      // it as unknown and refusing to sum would silence the rule on
      // every project that has not filled the map in — which is every
      // project, since the map defaults to empty ON PURPOSE so an old
      // file cannot decode carrying a convention its author never wrote.
      final category = bodyFor(device, doc.templates)?.category;
      final factor =
          doc.settings.diversityFactorsByCategory[category]?.v ?? 1000;
      total += (va * factor) ~/ 1000;
    }
  }
  return (total: total, unknown: unknown);
}
