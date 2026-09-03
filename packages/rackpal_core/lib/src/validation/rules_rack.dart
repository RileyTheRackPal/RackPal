// Tier-3 rack-geometry rules: `RCK-001` and `RCK-002` (`#285`, `#286`).
//
// ═════════════════════════════════════════════════════════════════════
// THE SAME CONDITION AS A TIER-1 RULE, AND THAT IS DR-112 RATHER THAN A
// DUPLICATE
// ═════════════════════════════════════════════════════════════════════
// `PLC-001` already refuses a placement outside the rack extent, and
// `RCK-002` reports a device that extends past `heightU`. Those look like
// one rule written twice, and DR-112 §11.111 rules that they are not:
// **tier 1 refuses the gesture, tier 3 reports the state, and the same
// condition may sit in both.** They answer different questions.
//
// The gap between them is not hypothetical and is the reason tier 3 has
// to ask anyway:
//
//  * A rack can SHRINK under a device that was placed legally. `#764`'s
//    `rack_shrink.dart` exists because that is a thing people do, and
//    every device above the new top is now past `heightU` without any
//    placement having been made.
//  * A `.rmpj` is a file people hand-edit and email each other, and
//    CR-117's round-trip is byte fidelity, not validity.
//  * `PLC-001` guards ONE path. A device placed before that rule shipped
//    (M5-C) is still in somebody's project today.
//
// So tier 1 is a gate on a gesture and tier 3 is a statement about a
// document, and a document can reach a state no gesture would have made.
//
// ═════════════════════════════════════════════════════════════════════
// FACE BY FACE, WHICH IS THE HALF THAT IS EASY TO GET WRONG
// ═════════════════════════════════════════════════════════════════════
// docs/02 §5.3 gives `RCK-001` as *"RU overlap on the same face"*, and
// the qualifier carries the whole rule: a front device and a rear device
// in the same U are the normal way a rack is packed, not a collision.
// `elevationOccupancyU` is the predicate that answers "does this device
// occupy U on THIS face", and `device_loads.dart`'s own header records
// what asking the other question instead did to four surfaces at once.

import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// One rail-placed device, with the U span it occupies on one face.
typedef _Span = ({DeviceInstance device, int ruIndex, int height});

/// Every device occupying U on [face] of [rack], ascending by U and then
/// by device id.
///
/// TOTAL ORDER, ENDING ON THE ID, because `List.sort` is not stable and
/// two devices in the same U is precisely the case `RCK-001` is about:
/// an unstable tie-break there would report the overlap with the pair
/// named in a different order on different runs, and a findings list is
/// something people diff.
List<_Span> _spansOn(RackDocument doc, Rack rack, Face face) {
  final out = <_Span>[];
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is! RailPlacement) continue;
    if (placement.rackId != rack.id) continue;
    final height = elevationOccupancyU(
      device,
      bodyFor(device, doc.templates),
      face,
    );
    // NULL IS UNKNOWN AND IS SKIPPED, NOT TREATED AS ZERO (G4/CR-114).
    // `elevationOccupancyU` returns null for a device whose snapshot does
    // not resolve, and a rule that read that as "occupies nothing" would
    // quietly stop checking exactly the devices whose data is broken.
    if (height == null || height <= 0) continue;
    out.add((device: device, ruIndex: placement.ruIndex, height: height));
  }
  out.sort((a, b) {
    final byU = a.ruIndex.compareTo(b.ruIndex);
    if (byU != 0) return byU;
    return a.device.id.v.compareTo(b.device.id.v);
  });
  return out;
}

/// The faces [a] and [b] overlap on, in `Face.values` order.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE FINDING PER PAIR, NOT PER PAIR PER FACE, AND A TEST FORCED IT
/// ═══════════════════════════════════════════════════════════════════════
/// The first draft looped faces on the outside and emitted a finding
/// inside. Most rack devices are `side: both` — V01 is — so two of them in
/// one U produced TWO findings with IDENTICAL targets, and therefore
/// **identical fingerprints**.
///
/// That is not merely noisy. `Finding.targetFingerprint` is what an
/// `AckedFinding` matches on, so two findings with one fingerprint cannot
/// be told apart by an acknowledgement: accepting the front collision
/// would silence the rear one, which is CR-019's instance scope failing
/// silently. And it is one physical collision anyway — a device occupying
/// both faces of U3 collides with another in U3 once, in the world.
///
/// So the pair is the unit, the faces are a detail of the sentence, and
/// the fingerprint means what it says.
List<Face> _facesWhereOverlapping(
  RackDocument doc,
  Rack rack,
  DeviceInstance a,
  DeviceInstance b,
) {
  final out = <Face>[];
  for (final face in Face.values) {
    final spans = {for (final s in _spansOn(doc, rack, face)) s.device.id: s};
    final sa = spans[a.id];
    final sb = spans[b.id];
    if (sa == null || sb == null) continue;
    if (sa.ruIndex < sb.ruIndex + sb.height &&
        sb.ruIndex < sa.ruIndex + sa.height) {
      out.add(face);
    }
  }
  return out;
}

/// `RCK-001` — two devices occupy the same U on the same face.
List<Finding> ruleRck001(RackDocument doc) {
  final out = <Finding>[];
  for (final rack in doc.racks.values) {
    // THE PAIRS ARE ENUMERATED ONCE, over the union of both faces, and
    // the face question is asked per pair afterwards. Walking faces on
    // the outside is what produced two findings with one fingerprint.
    final devices = <DeviceInstance>[];
    final seen = <String>{};
    for (final face in Face.values) {
      for (final span in _spansOn(doc, rack, face)) {
        if (seen.add(span.device.id.v)) devices.add(span.device);
      }
    }
    // TOTAL ORDER, so the pair (a, b) is always named the same way round
    // and its fingerprint is stable across runs.
    devices.sort((x, y) => x.id.v.compareTo(y.id.v));

    for (var i = 0; i < devices.length; i++) {
      for (var j = i + 1; j < devices.length; j++) {
        final faces = _facesWhereOverlapping(
          doc,
          rack,
          devices[i],
          devices[j],
        );
        if (faces.isEmpty) continue;
        final where = faces.length == Face.values.length
            ? 'both faces'
            : 'the ${faces.single.name} face';
        out.add(
          Finding(
            ruleId: 'RCK-001',
            severity: Severity.error,
            message:
                '${devices[i].designator} and ${devices[j].designator} '
                'overlap on $where of ${rack.designator}.',
            // BOTH DEVICES AND THE RACK. The fingerprint is built from
            // these, so an acknowledgement of "these two in this rack"
            // survives either of them moving to a different U and stops
            // applying the moment one moves to a different rack, which
            // is the behaviour CR-019's instance scope wants.
            targets: [devices[i].id, devices[j].id, rack.id],
            // THE SECOND OF THE PAIR, which is a stable choice rather
            // than a meaningful one: the pair is sorted by id, so the
            // ordering carries no information about which device a
            // person would move. Naming one is still better than naming
            // none, because the issues list has to select something.
            primaryEntityId: devices[j].id,
          ),
        );
      }
    }
  }
  return out;
}

/// `RCK-002` — a device extends past its rack's `heightU`.
List<Finding> ruleRck002(RackDocument doc) {
  final out = <Finding>[];
  for (final rack in doc.racks.values) {
    // ONE FINDING PER DEVICE, for `RCK-001`'s reason: a `side: both`
    // device past the top is past it once, and two findings sharing a
    // fingerprint would be unacknowledgeable apart.
    final worst = <String, _Span>{};
    for (final face in Face.values) {
      for (final span in _spansOn(doc, rack, face)) {
        final top = span.ruIndex + span.height - 1;
        if (top <= rack.heightU && span.ruIndex >= 1) continue;
        // THE TALLEST SPAN WINS when the two faces disagree, because the
        // sentence quotes a number and the honest one to quote is the
        // one that overruns furthest.
        final held = worst[span.device.id.v];
        if (held == null || span.height > held.height) {
          worst[span.device.id.v] = span;
        }
      }
    }
    final ids = worst.keys.toList()..sort();
    for (final id in ids) {
      final span = worst[id]!;
      final top = span.ruIndex + span.height - 1;
      // ONE RULE FOR BOTH WAYS OUT, because docs/02 §5.3 gives one row:
      // *"Device extends past `heightU`."* A device at U0 and one whose
      // top is U45 in a 42U rack are the same fact about the same
      // extent, and splitting them would invent a rule the catalogue
      // does not have (CR-021).
      final why = span.ruIndex < 1
          ? 'starts at U${span.ruIndex}, below the bottom rail'
          : 'needs U${span.ruIndex} to U$top';
      out.add(
        Finding(
          ruleId: 'RCK-002',
          severity: Severity.error,
          message:
              '${span.device.designator} $why, and ${rack.designator} is '
              '${rack.heightU}U.',
          targets: [span.device.id, rack.id],
          primaryEntityId: span.device.id,
        ),
      );
    }
  }
  return out;
}
