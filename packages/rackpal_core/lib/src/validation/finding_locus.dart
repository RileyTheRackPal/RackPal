// Where a finding can be FIXED (DR-193 §11.192.1, board #928).
//
// ═══════════════════════════════════════════════════════════════════════
// A QUESTION ABOUT THE DOCUMENT, SO IT LIVES HERE AND NOT IN THE SHELL
// ═══════════════════════════════════════════════════════════════════════
// `F8` switches to the view that can fix a finding and selects its subject.
// Which view that is depends only on what the finding points at and where
// that thing is in the model: a device on the rails is fixed on the Rack
// view, a device in a room on the Schematic, a floorplan on the Site view.
// None of that is a widget's business, and a shell that decided it inline
// would be the one place the rule could not be tested without a window.
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// What kind of thing a finding points at, as far as fixing it goes.
enum FindingLocusKind {
  /// A device in a rack: on the rails, in a 0U channel, or on a shelf.
  rackDevice,

  /// A device that sits in no rack.
  fieldDevice,

  /// A rack.
  rack,

  /// A cable.
  cable,

  /// A floorplan.
  plan,

  /// Nothing one view can select: a net, a circuit, or no locus at all.
  none,
}

/// Where a finding can be fixed, and the id to select there.
///
/// `rackId` is set for [FindingLocusKind.rackDevice] and
/// [FindingLocusKind.rack], because the Rack view shows one rack at a time
/// and has to switch to the right one before it can select anything.
typedef FindingLocus = ({FindingLocusKind kind, Uuid? subject, Uuid? rackId});

const FindingLocus _nowhere = (
  kind: FindingLocusKind.none,
  subject: null,
  rackId: null,
);

/// Where [finding] can be fixed in [doc].
///
/// **AN ID THE DOCUMENT NO LONGER HOLDS IS [FindingLocusKind.none]**, not
/// an error: a finding is computed, and a key pressed between an edit and
/// the next evaluation must say "nothing to show" rather than select a
/// ghost.
FindingLocus findingLocusOf(RackDocument doc, Finding finding) {
  final id = finding.primaryEntityId;
  if (id == null) return _nowhere;
  if (doc.racks.containsKey(id)) {
    return (kind: FindingLocusKind.rack, subject: id, rackId: id);
  }
  final device = doc.devices[id];
  if (device != null) {
    final rackId = rackIdOfDevice(doc, device);
    return rackId == null
        ? (kind: FindingLocusKind.fieldDevice, subject: id, rackId: null)
        : (kind: FindingLocusKind.rackDevice, subject: id, rackId: rackId);
  }
  if (doc.links.containsKey(id)) {
    return (kind: FindingLocusKind.cable, subject: id, rackId: null);
  }
  if (doc.underlays.containsKey(id)) {
    return (kind: FindingLocusKind.plan, subject: id, rackId: null);
  }
  return _nowhere;
}

/// The rack [device] sits in, or null when it sits in none.
///
/// **A SHELF IS FOLLOWED TO ITS HOST**, because a source on a shelf is in
/// the rack the shelf is in. The walk is bounded by the device count, so a
/// hand-edited file with a shelf loop answers null rather than hanging.
Uuid? rackIdOfDevice(RackDocument doc, DeviceInstance device) {
  var current = device;
  for (var hops = 0; hops <= doc.devices.length; hops++) {
    switch (current.placement) {
      case RailPlacement(:final rackId):
        return rackId;
      case ZeroUPlacement(:final rackId):
        return rackId;
      case ShelfPlacement(:final hostDeviceId):
        final host = doc.devices[hostDeviceId];
        if (host == null) return null;
        current = host;
      default:
        return null;
    }
  }
  return null;
}
