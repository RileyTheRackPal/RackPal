// docs/04-rack-editor.md §4.1 numbered rule 4: the shrink modal shows a
// LINK COUNT beside each doomed occupant, "because that is the real cost
// signal". A device losing its slot is cheap; a device losing its slot
// with eleven terminated cables on it is not, and the user deserves to see
// which one they are looking at before they press Apply.
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// How many `Link`s land on [deviceId] — a link is counted ONCE no matter
/// how many of its conductors terminate on this device (one physical
/// cable, one cost).
///
/// MATERIALISED PORTS ONLY, and that is correct rather than a gap:
/// `RackDocument.ports` holds only ports that carry project state
/// (AC-006), and a conductor endpoint IS project state — so any port a
/// link actually terminates on is, by construction, materialised. A device
/// whose ports were never materialised has no links to count, and this
/// returns a true 0. Stated here so a future reader does not mistake the
/// zero for a bug once M2 wiring lands.
int linkCountForDevice(RackDocument doc, Uuid deviceId) {
  final portIds = <Uuid>{
    for (final p in doc.ports.values)
      if (p.deviceId == deviceId) p.id,
  };
  if (portIds.isEmpty) return 0;

  var count = 0;
  for (final link in doc.links.values) {
    for (final c in link.conductors) {
      if (_landsOn(c.from, portIds) || _landsOn(c.to, portIds)) {
        count++;
        break;
      }
    }
  }
  return count;
}

/// Only a [PortEndpoint] can resolve to a device. A `PlaceEndpoint` names
/// a location with no device yet and an `OpenEndpoint` names nothing at
/// all (AC-018/B1) — neither is a link ON this device.
bool _landsOn(Endpoint e, Set<Uuid> portIds) =>
    e is PortEndpoint && portIds.contains(e.portId);
