// Which rack, if any, an `Endpoint` lands in.
//
// Pure derivation over the document — no state, nothing stored. It exists
// because `Link` classification (DR-008 §11.8.1) and, later, the schedule's
// pathway grouping both need to answer "are these two ends in the same
// rack?", and neither should be re-deriving a device-to-rack walk.
//
// THE WALK IS NOT ONE HOP. A device's placement may be a `ShelfPlacement`,
// whose host is another device, which may itself be shelf-placed. That
// recursion — and its cycle guard — already exists as `hostRackOf` in
// `device_loads.dart`, so this file resolves the endpoint to a device and
// then defers.
//
// EVERY UNKNOWN IS `null`, AND `null` IS NOT "no". G4: an endpoint whose
// rack cannot be determined is COUNTED as undetermined, never guessed and
// never quietly treated as "a different rack". Callers must distinguish
// "both ends resolved and differ" from "at least one end did not resolve" —
// `linkClassOf` does, and its own doc explains why the distinction changes
// the answer.

import 'package:rackmate_core/src/derived/device_loads.dart' show hostRackOf;
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// The rack [endpoint] ultimately lands in, or `null` when that cannot be
/// determined from [doc].
///
/// `null` covers five distinct situations and deliberately does not
/// distinguish them, because no caller yet needs to:
///
///   * a `PlaceEndpoint` — the field, by definition not in a rack;
///   * an `OpenEndpoint` — a coil, terminated nowhere;
///   * a `PortEndpoint` naming a port that is not materialised in [doc];
///   * a port whose device is missing;
///   * a device that is off-rack, staged, or on a shelf whose host chain
///     never reaches a rack.
Uuid? rackOfEndpoint(RackDocument doc, Endpoint endpoint) => switch (endpoint) {
  PortEndpoint(:final portId) => _rackOfPort(doc, portId),
  PlaceEndpoint() => null,
  OpenEndpoint() => null,
};

Uuid? _rackOfPort(RackDocument doc, Uuid portId) {
  final deviceId = doc.ports[portId]?.deviceId;
  if (deviceId == null) return null;
  final device = doc.devices[deviceId];
  if (device == null) return null;
  return hostRackOf(device, doc.devices);
}
