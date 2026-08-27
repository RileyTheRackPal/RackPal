// How much of a device is still unwired — the number behind CR-105's
// elevation chip.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS NOT `portConductorCount` IN A LOOP
// ═══════════════════════════════════════════════════════════════════════
// `connect_rules.dart`'s `portConductorCount` answers ONE port by walking
// every conductor of every `Link`. That is the right shape for `TOP-003`,
// which asks about the single jack a user just grabbed. The elevation asks
// about every port of every device on every rebuild, and the same function
// in a loop is `devices × ports × links × conductors` — on the 300-link
// density fixture (docs/05 §11.6) that is millions of comparisons per
// frame, to draw a chip.
//
// So the traversal is inverted: ONE pass over the conductors builds the set
// of occupied port ids, and each device is then a set lookup per declared
// port. `links·conductors + devices·ports`.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DENOMINATOR IS EVERY `PortDef` THE TEMPLATE DECLARES
// ═══════════════════════════════════════════════════════════════════════
// Not every port in `doc.ports` — DR-011.1 materialises a `Port` only when
// a cable lands on it, so a freshly-placed 12-jack device has zero rows
// there and `0/0` would be the one answer the chip must never give.
//
// It is also the count the user can check: `symbol_layer.dart` draws one
// pin per declared `PortDef`, so the denominator on the elevation chip
// equals the number of pins on that device's schematic symbol. A narrower
// rule ("only ports that could take a cable") would need the T2
// compatibility matrix, which DR-012.5 records as absent until M5.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/port.dart' show derivePortId;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// How many of one device's declared pins already carry a conductor.
@immutable
final class PortFill {
  const PortFill({required this.connected, required this.total});

  /// Declared pins with at least one live conductor end on them.
  final int connected;

  /// Declared pins — `TemplateBody.ports.length`, materialised or not.
  final int total;

  /// Declared pins nothing has landed on yet.
  int get unconnected => total - connected;

  /// Whether CR-105's chip has anything to signpost.
  ///
  /// A device with NO ports is not "unwired", it is furniture — a blank
  /// panel, a vent, a shelf. `kNoSymbolsDetail` already says so on the
  /// schematic and a chip pointing at a sheet that will not draw it would
  /// be a signpost to nowhere.
  bool get hasUnconnected => total > 0 && connected < total;

  /// `"3/12"` — CR-105's chip text, without its glyph.
  String get label => '$connected/$total';

  @override
  bool operator ==(Object other) =>
      other is PortFill && other.connected == connected && other.total == total;

  @override
  int get hashCode => Object.hash(connected, total);

  @override
  String toString() => 'PortFill($label)';
}

/// [PortFill] for every device in [doc], keyed by device id.
///
/// EVERY device, including the fully-wired and the port-less ones: this is
/// a derivation, not a filter, and the caller that wants CR-105's chip asks
/// [PortFill.hasUnconnected]. A device whose template snapshot does not
/// resolve reports `0/0` — `bodyFor`'s own reading of CR-054, and the same
/// "unknown contributor" answer `device_loads.dart` gives.
Map<Uuid, PortFill> portFillByDevice(RackDocument doc) {
  final occupied = occupiedPortIds(doc);
  final out = <Uuid, PortFill>{};
  for (final entry in doc.devices.entries) {
    final body = bodyFor(entry.value, doc.templates);
    if (body == null) {
      out[entry.key] = const PortFill(connected: 0, total: 0);
      continue;
    }
    var connected = 0;
    for (final def in body.ports) {
      if (occupied.contains(derivePortId(entry.key, def.key))) connected++;
    }
    out[entry.key] = PortFill(connected: connected, total: body.ports.length);
  }
  return out;
}

/// Every port id a live conductor end lands on, in one pass.
///
/// ENDS, NOT CONDUCTORS, and deliberately a SET rather than a count: this
/// answers "is this jack in use", where `portConductorCount`'s question is
/// "how many plugs are in it" and a self-looped conductor has to count
/// twice. Two jacks' worth of occupancy is still one occupied jack.
///
/// Only a [PortEndpoint] occupies one. A `PlaceEndpoint` names a location
/// with no device yet and an `OpenEndpoint` names nothing at all
/// (AC-018/B1).
Set<Uuid> occupiedPortIds(RackDocument doc) {
  final out = <Uuid>{};
  for (final link in doc.links.values) {
    for (final conductor in link.conductors) {
      for (final end in <Endpoint>[conductor.from, conductor.to]) {
        if (end is PortEndpoint) out.add(end.portId);
      }
    }
  }
  return out;
}
