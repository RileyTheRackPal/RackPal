// The rackpal_ui half of the schematic fixture: pin pairs both validation
// tiers accept, and the spring-back rule ids.
//
// THE DOCUMENT ITSELF IS IN rackpal_core SINCE #948
// (`packages/rackpal_core/test/scene/schematic_test_document.dart`), because
// `wire_trace.dart`'s tests moved to core with the code and needed it. It is
// re-exported below so every test here keeps importing this one file. A
// relative path across packages is unusual; the alternative was a second
// copy of a 280-line fixture, and two copies of a moving thing drift.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../../../../rackpal_core/test/scene/schematic_test_document.dart';

export '../../../../rackpal_core/test/scene/schematic_test_document.dart';

/// A pin on [from] and a pin on [to] that BOTH validation tiers accept.
///
/// ═══════════════════════════════════════════════════════════════════════
/// M5-D MADE THE PAIR MATTER, AND "TWO FREE PINS" STOPPED BEING ENOUGH
/// ═══════════════════════════════════════════════════════════════════════
/// Suites across this directory drew the first free pin of `MTX-1` to the
/// first free pin of `AMP-1` and asserted the gesture committed. Both
/// halves were wrong about the cable and nothing in the product could say
/// so until the six tier-2 rules shipped:
///
///  * `MTX-1` is the seed catalog's V03, sixteen HDMI INPUTS and then
///    sixteen outputs, with the first four inputs wired. So its first free
///    pin is `hdmi.in.5`, a SINK, and `AMP-1`'s first free pin is a sink
///    too. **Two inputs with nothing driving the cable**, which is
///    `DIR-001`.
///  * Arming from an OUTPUT instead does not rescue it. `AMP-1` is A01 and
///    its first free sink is `src.2.l`, an RCA analog jack, so HDMI-out
///    into RCA-in is `SIG-002` and would be `CON-001` besides.
///
/// **The rules are right both times and the fixture choice was wrong**, so
/// what moves is which pins a test picks.
///
/// IT SEARCHES RATHER THAN NAMING A PAIR, and that is the lesson rather
/// than laziness: both hand-picked pairs above looked obviously fine to a
/// person and neither was. A premise chosen by eye can be wrong, and these
/// were, twice in one afternoon. A search cannot be, and when a seventh
/// rule lands it re-answers rather than going stale.
///
/// THROWS rather than returning null when no pair exists, because that is
/// not a case any caller can handle: it means this fixture can no longer
/// demonstrate a commit at all, which is a fact about the fixture and
/// wants a loud failure rather than a skipped assertion.
({PinRef from, PinRef to, DPt fromCentre, DPt toCentre}) clearConnectPair(
  RackDocument doc,
  SchematicScene scene,
  String from,
  String to,
) {
  List<({PinRef ref, DPt centre, ConnectTarget target})> freeOn(String d) {
    final device = deviceNamed(doc, d);
    final symbol = scene.symbols.firstWhere((s) => s.id == device.id.v);
    return <({PinRef ref, DPt centre, ConnectTarget target})>[
      for (final port in symbol.allPorts)
        if (portConductorCount(
              doc,
              derivePortId(device.id, PortKey(port.key)),
            ) ==
            0)
          if (resolveConnectTarget(
                doc,
                deviceId: device.id,
                portKey: port.key,
              )
              case final t?)
            (
              ref: PinRef(deviceId: symbol.id, portKey: port.key),
              centre: symbolPortCentre(symbol, port),
              target: t,
            ),
    ];
  }

  for (final a in freeOn(from)) {
    for (final b in freeOn(to)) {
      if (evaluateConnect(doc, a.target, b.target) is! ConnectAllowed) continue;
      if (evaluateSpringBack(doc, a.target, b.target) is! SpringBackClear) {
        continue;
      }
      return (
        from: a.ref,
        to: b.ref,
        fromCentre: a.centre,
        toCentre: b.centre,
      );
    }
  }
  throw StateError(
    'no cable between $from and $to satisfies both validation tiers, so '
    'this fixture can no longer demonstrate a commit at all',
  );
}

/// Every tier-2 rule id, derived from the enum rather than typed out.
///
/// The suites' `statusOf` helpers are WHITELISTS: a message they do not
/// recognise reads as no message at all, which is how a spring-back looked
/// exactly like silence to every assertion in this directory for one test
/// run. Deriving the list means a seventh rule cannot go unheard the same
/// way, which a typed list of six would have allowed silently.
final List<String> kSpringBackRuleIds = <String>[
  for (final rule in SpringBackRule.values) rule.id,
];

/// A free pin that landing [linkId]'s loose end may terminate on, which
/// BOTH validation tiers accept (DR-116).
///
/// The bind's counterpart to [clearConnectPair], and it exists for the
/// same reason and was found the same way. Landing a home run used to
/// consult occupancy alone, so any free pin would do; DR-116 rules that a
/// rule is a statement about the resulting STATE rather than about the
/// gesture, so the bind now springs back like a connect does.
///
/// The suites here landed on `freePin('MTX-1')` and went red on
/// `DIR-001`: the fixture's first half-landed run is anchored on
/// `MTX-1 J01`, an HDMI **input**, and MTX-1's free pins are its other
/// fifteen inputs. **Two inputs, nothing driving the cable** — the same
/// shape, on a third gesture. The outputs clear it.
///
/// SEARCHES rather than naming one, for [clearConnectPair]'s reason:
/// every pair picked by eye in this directory has been wrong.
/// [anchorPortId] is the end this landing is NOT writing. Omit it for a
/// half-landed run, where exactly one end is a port and the helper finds
/// it; pass it for a MOVE, where both ends are ports and only the caller
/// knows which one is being dragged.
///
/// THE FIRST DRAFT DERIVED IT FROM `LinkEnd` AND HAD IT BACKWARDS.
/// `buildBindEndpointCommand` reads `LinkEnd.field` as `conductor.from`,
/// which is the end being WRITTEN, while `_runEndAt` sets `anchorPortId`
/// to the opposite one. Two conventions one letter apart, and a helper
/// that picked the wrong end would have searched for a pin compatible
/// with the jack the cable is leaving.
({PinRef ref, DPt centre}) clearBindTarget(
  RackDocument doc,
  SchematicScene scene,
  Uuid linkId, {
  Uuid? anchorPortId,
}) {
  final link = doc.links[linkId]!;
  final conductor = link.conductors.first;
  final anchorId =
      anchorPortId ??
      [conductor.from, conductor.to].whereType<PortEndpoint>().single.portId;
  final anchorPort = doc.ports[anchorId]!;
  final anchor = resolveConnectTarget(
    doc,
    deviceId: anchorPort.deviceId,
    portKey: anchorPort.templatePortKey!.v,
  )!;

  for (final symbol in scene.symbols) {
    final device = doc.devices[Uuid(symbol.id)];
    if (device == null) continue;
    for (final port in symbol.allPorts) {
      final id = derivePortId(device.id, PortKey(port.key));
      if (portConductorCount(doc, id) != 0) continue;
      final t = resolveConnectTarget(
        doc,
        deviceId: device.id,
        portKey: port.key,
      );
      if (t == null) continue;
      if (evaluateSpringBack(doc, anchor, t, ontoLink: linkId)
          is! SpringBackClear) {
        continue;
      }
      return (
        ref: PinRef(deviceId: symbol.id, portKey: port.key),
        centre: symbolPortCentre(symbol, port),
      );
    }
  }
  throw StateError(
    'no free jack on this sheet takes ${link.designator} without springing '
    'back, so this fixture can no longer demonstrate a landing at all',
  );
}
