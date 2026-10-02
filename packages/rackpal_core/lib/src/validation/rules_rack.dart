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
//  * A `.rppj` is a file people hand-edit and email each other, and
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
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
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

// ─────────────────────────────────────────────────────────────────────
// RCK-003 — total device weight exceeds the rack's capacity (#287)
// ─────────────────────────────────────────────────────────────────────

/// Which band [ruleRck003] landed in. Named rather than inlined so the
/// severity and the sentence cannot disagree about it.
enum _Band { advisory, warning, over }

/// The loaded-weight band at which `RCK-003` first speaks, in percent.
///
/// **60, AND THE REASON IS A FLOOR RATHER THAN AN ARITHMETIC** (DR-125,
/// M5-H2). The domain reviewer set it from a job they have done twice:
/// a 42U rack at 85% of capacity is around 850 lb, which is already
/// enough for the casters to damage a floor, and a notice that arrives
/// then arrives after the fourth amplifier has been specified rather than
/// before. The number is a working practice, not a derivation, and it is
/// stated here once so nothing else has to hold a copy.
const int kRck003AdvisoryPercent = 60;

/// The band at which `RCK-003` escalates to a warning.
const int kRck003WarningPercent = 85;

/// `RCK-003` — the rack's loaded weight is over capacity, or near it.
///
/// THREE SEVERITIES FROM ONE ROW (DR-125). docs/02 §5.3 used to read
/// *"warning (advisory at 85%)"* and now reads three bands: `advisory` at
/// [kRck003AdvisoryPercent], `warning` at [kRck003WarningPercent], and
/// `error` over capacity. The evaluator's override still applies on top
/// of whichever was chosen, so a project that demotes `RCK-003` demotes
/// all three.
///
/// **THE `error` BAND BLOCKS NOTHING**, and saying so here is worth the
/// line: CR-022/G3 makes no finding at any severity prevent an export.
/// What the severity changes is whether a loaded rack reads as a note
/// somebody scrolls past.
///
/// THE UNKNOWN COUNT IS IN THE SENTENCE (G4/CR-114). A rack whose devices
/// mostly state no mass is a rack this rule cannot speak about, and a
/// total that silently omitted them would read as reassurance.
List<Finding> ruleRck003(RackDocument doc) {
  final out = <Finding>[];
  for (final rack in doc.racks.values) {
    final capacity = rack.weightCapacity;
    // NO CAPACITY IS UNKNOWN, NOT UNLIMITED, and the rule is silent. A
    // rack whose capacity nobody stated cannot be over it.
    if (capacity == null) continue;

    var loadedUg = 0;
    final unknown = <String>[];
    final members = <Uuid>[];
    for (final device in doc.devices.values) {
      if (!belongsToRack(device, rack.id, doc.devices)) continue;
      members.add(device.id);
      final mass = resolveDeviceLoads(
        device,
        bodyFor(device, doc.templates),
      ).mass;
      if (mass == null) {
        unknown.add(device.designator);
      } else {
        loadedUg += mass.ug;
      }
    }
    if (members.isEmpty) continue;

    // THE BANDS, IN MICROGRAMS, so every comparison stays in CR-001's
    // integer units and never becomes a float.
    final advisoryAtUg = (capacity.ug * kRck003AdvisoryPercent) ~/ 100;
    final warningAtUg = (capacity.ug * kRck003WarningPercent) ~/ 100;
    if (loadedUg < advisoryAtUg) continue;
    unknown.sort();
    final more = unknown.length > 3 ? ' and ${unknown.length - 3} more' : '';
    final caveat = unknown.isEmpty
        ? ''
        : ' ${unknown.length} of its devices state no weight '
              '(${unknown.take(3).join(', ')}$more), so the real load is '
              'higher.';
    // THREE BANDS, NOT TWO (DR-125). The rule used to speak first at 85%,
    // which the domain review found is far too late: a 42U rack at 85% of
    // a 1,000 lb capacity is 850 lb, already enough for the casters to
    // damage a floor. The advisory now lands at 60%, before the decision
    // to add one more amplifier rather than after it.
    final (severity, band) = switch (loadedUg) {
      _ when loadedUg > capacity.ug => (Severity.error, _Band.over),
      _ when loadedUg >= warningAtUg => (Severity.warning, _Band.warning),
      _ => (Severity.advisory, _Band.advisory),
    };
    out.add(
      Finding(
        ruleId: 'RCK-003',
        severity: severity,
        message: switch (band) {
          // OVER CAPACITY IS AN ERROR AND STILL BLOCKS NOTHING. CR-022/G3
          // is unchanged: no finding at any severity prevents an export.
          // What the severity buys is that the rack stops being a note in
          // a list somebody scrolls past.
          _Band.over =>
            '${rack.designator} is loaded to ${_kg(loadedUg)} kg against '
                'a ${_kg(capacity.ug)} kg capacity.$caveat',
          _Band.warning =>
            '${rack.designator} is at ${_kg(loadedUg)} kg, over '
                '$kRck003WarningPercent% of its ${_kg(capacity.ug)} kg '
                'capacity.$caveat',
          _Band.advisory =>
            '${rack.designator} is at ${_kg(loadedUg)} kg, over '
                '$kRck003AdvisoryPercent% of its ${_kg(capacity.ug)} kg '
                'capacity. Check the floor and the casters before adding '
                'more.$caveat',
        },
        targets: [rack.id, ...members],
        primaryEntityId: rack.id,
      ),
    );
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// RCK-012 — front depth + rear depth + 50 mm > usable depth (#288)
// ─────────────────────────────────────────────────────────────────────

/// The cable allowance docs/02 §5.3 names: 50 mm between a front device's
/// tail and a rear device's.
final Len kRearCableAllowance = Len.fromMillimetres(50);

/// `RCK-012` — a front and a rear device collide in depth over shared U.
///
/// THE PAIR IS THE UNIT, for `RCK-001`'s reason: this is a fact about two
/// devices, and a fingerprint naming one of them could not be
/// acknowledged apart from another pair that same device is in.
List<Finding> ruleRck012(RackDocument doc) {
  final out = <Finding>[];
  for (final rack in doc.racks.values) {
    final usable = rack.usableDepth;
    // UNKNOWN DEPTH, UNKNOWN ANSWER. A rack that states no usable depth
    // cannot be over it, and assuming a standard depth would be exactly
    // the estimate G4 forbids.
    if (usable == null) continue;

    final fronts = _spansOn(doc, rack, Face.front);
    final rears = _spansOn(doc, rack, Face.rear);
    for (final f in fronts) {
      for (final r in rears) {
        if (f.device.id == r.device.id) continue;
        // OVERLAPPING RU RANGES ONLY, which is §5.3's own qualifier: two
        // devices at opposite ends of the rack share no depth to fight
        // over.
        if (f.ruIndex >= r.ruIndex + r.height) continue;
        if (r.ruIndex >= f.ruIndex + f.height) continue;

        final fd = _depthOf(doc, f.device);
        final rd = _depthOf(doc, r.device);
        // EITHER DEPTH UNKNOWN MEANS NO ARITHMETIC. Two bodies and an
        // allowance is a sum, and a sum missing a term is not a smaller
        // sum.
        if (fd == null || rd == null) continue;

        final needed = fd + rd + kRearCableAllowance.nm;
        if (needed <= usable.nm) continue;
        out.add(
          Finding(
            ruleId: 'RCK-012',
            severity: Severity.error,
            // THE SENTENCE SAYS WHAT TO DO ABOUT IT (M5-H2, DR-125).
            // Many chassis carry several sets of rack-ear holes and shift
            // fore and aft in the field, so a depth collision on paper is
            // often an adjustment rather than a redesign. The reviewer's
            // point was that `error` reads as "blocked" to somebody who
            // has not read CR-022/G3, and the remedy belongs in the
            // sentence rather than in a document they will not open.
            message:
                '${f.device.designator} at the front and '
                '${r.device.designator} at the rear need ${_mm(needed)} mm '
                'together including the 50 mm cable allowance, and '
                '${rack.designator} is ${_mm(usable.nm)} mm deep. May '
                'require adjustment of the rack ears.',
            targets: [f.device.id, r.device.id, rack.id],
            primaryEntityId: f.device.id,
          ),
        );
      }
    }
  }
  return out;
}

/// [device]'s depth including what its connectors project, in nanometres.
///
/// BOTH TERMS OR NEITHER. `bodyDepth` without `connectorProjection` is the
/// box and not the space it needs, and `RCK-012` is about the space.
int? _depthOf(RackDocument doc, DeviceInstance device) {
  final body = bodyFor(device, doc.templates);
  final depth = body?.bodyDepth;
  if (depth == null) return null;
  return depth.nm + (body?.connectorProjection?.nm ?? 0);
}

// ─────────────────────────────────────────────────────────────────────
// RCK-013 — mass over maxUnsupportedMass on front ears only (#289)
// ─────────────────────────────────────────────────────────────────────

/// `RCK-013` — a heavy device hangs on its front ears with no rear
/// support.
///
/// WHAT THIS CAN SEE AND WHAT IT CANNOT. The model records which rails a
/// device's ears are bolted to (`boltedRailFace`) and what a template can
/// hang unsupported (`maxUnsupportedMass`). It does NOT record a shelf
/// under a device that is not hosted by it, so the rule speaks about the
/// case it can see — front-only ears, mass over the limit — and says
/// "rear support or a shelf" rather than asserting there is none.
List<Finding> ruleRck013(RackDocument doc) {
  final out = <Finding>[];
  for (final device in doc.devices.values) {
    final body = bodyFor(device, doc.templates);
    final limit = body?.maxUnsupportedMass;
    // NO STATED LIMIT IS UNKNOWN, and a device with none is one this rule
    // has nothing to say about rather than one that can hang any weight.
    if (limit == null) continue;
    final mass = resolveDeviceLoads(device, body).mass;
    if (mass == null) continue;
    if (mass.ug <= limit.ug) continue;

    // FRONT EARS ONLY. `boltedRailFace` answers which rails carry the
    // ears, which `device_loads.dart` keeps deliberately separate from
    // "does it occupy U on this face" — asking the other question is what
    // emptied the rear elevation.
    if (boltedRailFace(device) != Face.front) continue;
    final placement = device.placement;
    if (placement is! RailPlacement) continue;
    final rack = doc.racks[placement.rackId];
    if (rack == null) continue;

    out.add(
      Finding(
        ruleId: 'RCK-013',
        severity: Severity.warning,
        message:
            '${device.designator} is ${_kg(mass.ug)} kg on front ears rated '
            'to ${_kg(limit.ug)} kg. It needs rear rail support or a shelf '
            'in ${rack.designator}, and may require adjustment of the rack '
            'ears.',
        targets: [device.id, rack.id],
        primaryEntityId: device.id,
      ),
    );
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// RCK-014 — a half-rack device alone in its U (CR-030, DR-219)
// ─────────────────────────────────────────────────────────────────────

/// `RCK-014` — a rail-mounted device narrower than the rack with nothing
/// else in any of its U on its face.
///
/// CR-030 RULED THIS IN 2026-08 AND NOTHING FILED IT: *"A half-rack device
/// dropped alone is allowed and files an advisory naming the ear kit."*
/// DR-219 §11.218.4 builds it because `T6.30`'s hardware rollup lists the
/// ear kit, and the drawer's advisory and the materials line must come
/// from one predicate rather than two that can disagree.
///
/// ALONE MEANS NOTHING ELSE IN ANY OF ITS U ON ITS FACE. Two half-rack
/// units side by side are joined with the kit they ship with; a full-width
/// device overlapping it is `RCK-001`'s error, not this advisory's.
List<Finding> ruleRck014(RackDocument doc) {
  final out = <Finding>[];
  final racks = doc.racks.values.toList()
    ..sort((a, b) => a.id.v.compareTo(b.id.v));
  for (final rack in racks) {
    for (final face in Face.values) {
      final spans = _spansOn(doc, rack, face)
        ..sort((a, b) => a.device.id.v.compareTo(b.device.id.v));
      for (final span in spans) {
        final placement = span.device.placement;
        if (placement is! RailPlacement) continue;
        // ITS OWN FACE ONLY, so a half-rack device is judged once, where
        // its ears are, and not again from behind.
        if (placement.face != face) continue;
        if (placement.spanTwelfths >= 12) continue;
        final alone = spans.every(
          (other) =>
              identical(other, span) ||
              other.ruIndex >= span.ruIndex + span.height ||
              span.ruIndex >= other.ruIndex + other.height,
        );
        if (!alone) continue;
        out.add(
          Finding(
            ruleId: 'RCK-014',
            severity: Severity.advisory,
            message:
                '${span.device.designator} is a half-rack device with '
                'nothing beside it in ${rack.designator}. It needs an ear '
                'kit or a shelf.',
            targets: [span.device.id, rack.id],
            primaryEntityId: span.device.id,
          ),
        );
      }
    }
  }
  return out;
}

/// [ug] in kilograms, to one decimal place.
String _kg(int ug) => (ug / 1000000000).toStringAsFixed(1);

/// [nm] in millimetres, as a whole number.
String _mm(int nm) => (nm / 1000000).round().toString();
