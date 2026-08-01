// Which cables land on one jack — the question a delete gesture asks, and
// the one nothing in the tree could answer.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DOCUMENT ANSWERS THIS, NOT THE SHEET, AND THAT IS THE WHOLE POINT
// ═══════════════════════════════════════════════════════════════════════
// `SchematicScene.netLabels` already carries a `linkId` beside a
// `deviceId`/`portKey` pair, so a screen holding a scene can look a link up
// from a pin without this file. It would be wrong on the pins that matter
// most. `net_label_layer.dart` labels `Link.conductors.first` and no other
// conductor, so on a stereo pair connected as one atomic cable the `R`
// member carries a conductor, occupies its jack, and has NO RENDERED LABEL
// AT ALL. A lookup through the scene reports `R` as free; a lookup through
// the document reports the cable that is really in it.
//
// The same asymmetry is why `port_fill.dart` walks conductors rather than
// reading what was drawn, and it is the reason a delete built on the scene
// would refuse to delete exactly the cable a user could not see and
// therefore most wants gone.
//
// ═══════════════════════════════════════════════════════════════════════
// ENDS, AND A SELF-LOOP IS STILL ONE CABLE
// ═══════════════════════════════════════════════════════════════════════
// `connect_rules.dart`'s `portConductorCount` counts ENDS, because
// `TOP-003` asks how many plugs are in a jack and a conductor looped from a
// port to itself fills it twice. This asks a different question — WHICH
// CABLES would go — and a link that touches the jack twice is still one
// link, one row on the schedule and one thing to pull. So the result is
// de-duplicated by link id, in document order.

import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Every `Link` with a conductor end on [portId], in document order.
///
/// Empty is the OVERWHELMINGLY NORMAL answer: AC-006 materialises a port
/// only once it carries project state, and most declared pins on most
/// devices are never wired. An unmaterialised pin's derived id simply
/// matches nothing, which is the same empty answer and needs no special
/// case — see `derivePortId`, which is total.
List<Uuid> linksOnPort(RackDocument doc, Uuid portId) => <Uuid>[
  for (final entry in doc.links.entries)
    if (_touches(entry.value.conductors, portId)) entry.key,
];

/// Every `Link` with a conductor end on any of [portIds], in document
/// order, each appearing once.
///
/// Not [linksOnPort] in a loop: a cable between two pins of ONE port set —
/// a loopback, or the second conductor of a stereo pair landing back on the
/// same device — would come back twice, and a caller counting cables to put
/// a number in a sentence would say two where an installer pulls one.
List<Uuid> linksOnPorts(RackDocument doc, Set<Uuid> portIds) {
  if (portIds.isEmpty) return const <Uuid>[];
  return <Uuid>[
    for (final entry in doc.links.entries)
      if (_touchesAny(entry.value.conductors, portIds)) entry.key,
  ];
}

/// The `Net` a `RemoveLinkCommand` for [linkId] may take with it, or null
/// when it must take none.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SURVIVORS DECIDE, EXACTLY AS THEY DO FOR A DEVICE
/// ═══════════════════════════════════════════════════════════════════════
/// `device_removal.dart` computes this for the many-link case and states
/// the rule: a `Net` belongs to no entity, it is merely referenced by
/// `Service.netId`, so it may go only when NO SURVIVING LINK still names
/// it. The one-link case takes the identical rule and is stated here so a
/// caller cannot accidentally take the easy reading —
/// `link.services.first.netId` — which is right for every net this
/// application creates and wrong for a hand-edited file that shares one.
///
/// Null is returned for three different reasons and the command's behaviour
/// is the same for all of them: the link has no services, its service names
/// no net, or another link still needs that net.
Uuid? netToRemoveWith(RackDocument doc, Uuid linkId) {
  final link = doc.links[linkId];
  if (link == null) return null;

  Uuid? candidate;
  for (final service in link.services) {
    final netId = service.netId;
    if (netId != null) {
      candidate = netId;
      break;
    }
  }
  if (candidate == null) return null;

  for (final entry in doc.links.entries) {
    if (entry.key == linkId) continue;
    for (final service in entry.value.services) {
      if (service.netId == candidate) return null;
    }
  }
  return candidate;
}

/// Whether any conductor of [conductors] lands on [portId].
///
/// `PortEndpoint` only. An `OpenEndpoint` names nothing and a
/// `PlaceEndpoint` names a location rather than a jack — the same reading
/// `device_removal.dart` takes, and for the same reason: neither can be the
/// port being asked about.
bool _touches(List<Conductor> conductors, Uuid portId) {
  for (final c in conductors) {
    for (final end in [c.from, c.to]) {
      if (end is PortEndpoint && end.portId == portId) return true;
    }
  }
  return false;
}

bool _touchesAny(List<Conductor> conductors, Set<Uuid> portIds) {
  for (final c in conductors) {
    for (final end in [c.from, c.to]) {
      if (end is PortEndpoint && portIds.contains(end.portId)) return true;
    }
  }
  return false;
}
