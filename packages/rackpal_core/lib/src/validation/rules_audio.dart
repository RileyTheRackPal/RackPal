// Tier-3 audio rules: `ELE-005` (`#838`, M5-K, DR-132 §11.131).
//
// ═════════════════════════════════════════════════════════════════════
// A RESTORED RULE, NOT A NEW ONE, AND BOTH ITS INPUTS WERE DEAD FIELDS
// ═════════════════════════════════════════════════════════════════════
// AC-040 cut `ELE-005` from v1. DR-132 restores it on that cut's own
// test, that a rule earns its place when it *"protects the user from real
// money"*: overload a 70 V line and the amplifier clips, and clipped
// square waves are what destroy tweeters.
//
// `docs/research/design-data-model.md` line 1136 had already specified it
// exactly, down to the severity and the 80% threshold, and this file was
// nearly written as `ELE-007` instead. That id was taken too, by a
// satellite-splitter rule in the same document.
//
// THE TWO FIELDS IT SUMS HAD NO PRODUCER AND NO CONSUMER UNTIL NOW.
// `PortDef.bus.maxTapWatts` was declared on zero of 727 seeded ports
// because `p()` had no `bus` parameter, and `Port.tapWatts` was written
// by nothing at all (DR-131 §11.130.9). This rule is what both of them
// have been waiting for since M0.
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// The share of an amplifier channel's rating a design may plan to use.
///
/// EIGHTY PERCENT, WHICH IS NOT A NUMBER INVENTED HERE. `PWR-001` already
/// derates a breaker to 80% and calls itself *"a planning estimate and
/// not a compliance check"*; the research corpus specified the same
/// figure for this rule independently. A second copy of a moving number
/// is a liability, so it is named once and both readings cite it.
const int kTapBudgetPermille = 800;

/// `ELE-005` — the taps on a constant-voltage line exceed 80% of the
/// amplifier channel driving it.
///
/// ═══════════════════════════════════════════════════════════════════
/// IT FIRES ONLY WHEN THE **KNOWN** TAPS ALONE CROSS THE LINE
/// ═══════════════════════════════════════════════════════════════════
/// G4/CR-114. A speaker whose tap nobody recorded still draws from the
/// amplifier, so it cannot be counted as zero, and it must not be
/// guessed either. The only certain statement is about the taps that are
/// written down, so that is the only one the rule makes, and the message
/// carries the unknown count so the figure reads as a FLOOR.
///
/// The asymmetry is deliberate: a net whose recorded taps sit under the
/// line while four are blank has not been cleared, it has been
/// incompletely measured.
List<Finding> ruleEle005(RackDocument doc) {
  final out = <Finding>[];
  for (final net in doc.nets.values) {
    if (net.signalFamily.v != 'audio.speaker_cv') continue;

    final ports = _portsOnNet(doc, net.id);
    final capacity = _capacityOf(doc, ports);
    // NO STATED CAPACITY IS UNEVALUATABLE AND SILENT, not a pass. There
    // is no rating to be over, and inventing one from the amplifier's
    // model string would be exactly the fabrication CR-114 forbids.
    if (capacity == null) continue;

    var known = 0;
    final unknown = <DeviceInstance>[];
    for (final port in ports) {
      // THE AMPLIFIER IS NOT A LOAD ON ITS OWN OUTPUT, and it has no tap
      // to record. Counting it made the message read "3 speakers have no
      // tap recorded (AMP-1, SPK-5, SPK-6)", naming the amplifier as a
      // speaker somebody forgot to measure. A port that DECLARES the
      // capacity is the source by definition, which is the same test
      // `_capacityOf` uses, so the two cannot disagree.
      if (_declaredCapacity(doc, port) != null) continue;
      // A BYPASSED SPEAKER IS NOT ON THIS LINE (DR-131). Its transformer
      // is out of circuit, so it draws nothing from the 70 V bus, and
      // counting its tap would charge the amplifier for a load that is
      // not there.
      if (port.lowZBypass) continue;
      if (port.tapWatts case final w?) {
        known += w;
      } else {
        final device = doc.devices[port.deviceId];
        if (device != null) unknown.add(device);
      }
    }

    final budget = capacity * kTapBudgetPermille ~/ 1000;
    if (known <= budget) continue;
    out.add(
      Finding(
        ruleId: 'ELE-005',
        severity: Severity.warning,
        message:
            '${net.designator ?? net.name} carries $known W of speaker '
            'taps on an amplifier channel rated $capacity W, over the '
            '$budget W this plans to.${_unknownTapClause(unknown)}',
        // THE NET AND ITS MEMBERS, on `PWR-003`'s reasoning: the
        // fingerprint has to move when the population does, so
        // acknowledging "this line is over" with six speakers on it must
        // not survive somebody adding a seventh.
        targets: [net.id, ...ports.map((p) => p.id)],
        primaryEntityId: net.id,
      ),
    );
  }
  return out;
}

/// Every materialised port carrying [netId], in document order.
///
/// THROUGH THE CONDUCTORS, because that is where a port endpoint lives: a
/// `Service` names the net and the `Link` it rides, and the link's
/// conductors name the two ends.
List<Port> _portsOnNet(RackDocument doc, Uuid netId) {
  final seen = <Uuid>{};
  final out = <Port>[];
  for (final link in doc.links.values) {
    if (!link.services.any((s) => s.netId == netId)) continue;
    for (final conductor in link.conductors) {
      for (final end in [conductor.from, conductor.to]) {
        if (end is! PortEndpoint) continue;
        if (!seen.add(end.portId)) continue;
        if (doc.ports[end.portId] case final port?) out.add(port);
      }
    }
  }
  return out;
}

/// The amplifier channel rating driving this net, or null when no port on
/// it states one.
///
/// THE SMALLEST STATED CAPACITY WINS when more than one port declares
/// one, which should not happen and is not an error worth a rule: two
/// sources on one constant-voltage line is a different fault, and until
/// somebody rules on it the conservative reading is the safe one.
int? _capacityOf(RackDocument doc, List<Port> ports) {
  int? best;
  for (final port in ports) {
    final rating = _declaredCapacity(doc, port);
    if (rating == null) continue;
    if (best == null || rating < best) best = rating;
  }
  return best;
}

/// The `bus.maxTapWatts` [port]'s template declares, or null.
///
/// ONE FUNCTION, USED TWICE, and deliberately so: it answers both "what
/// is this line rated at" and "is this port the source rather than a
/// load", and those two must not be able to disagree about which port is
/// the amplifier.
int? _declaredCapacity(RackDocument doc, Port port) {
  final device = doc.devices[port.deviceId];
  if (device == null) return null;
  final key = port.templatePortKey;
  if (key == null) return null;
  final body = bodyFor(device, doc.templates);
  if (body == null) return null;
  for (final def in body.ports) {
    if (def.key == key) return def.bus?.maxTapWatts;
  }
  return null;
}

/// Names the speakers whose tap nobody recorded, so the total reads as a
/// floor. Deliberately the same shape `rules_power.dart` uses for an
/// unknown outlet count, because it is the same G4 sentence.
String _unknownTapClause(List<DeviceInstance> unknown) {
  if (unknown.isEmpty) return '';
  final names = unknown.map((d) => d.designator).toList()..sort();
  final said = names.length <= 3
      ? names.join(', ')
      : '${names.take(3).join(', ')} and ${names.length - 3} more';
  return ' ${names.length == 1 ? 'One speaker' : '${names.length} speakers'} '
      'on it ${names.length == 1 ? 'has' : 'have'} no tap recorded '
      '($said), so the real load is higher than this.';
}
