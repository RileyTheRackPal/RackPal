// AC-051 pairs for the plan band: `PLN-001` to `PLN-004` (DR-154
// §11.153.4, `PLAN-I/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE GATE FOLLOWS THE RULE, NOT THE LIST
// ═══════════════════════════════════════════════════════════════════════
// AC-051 is written about rules: *"No rule ships without its pair."* So
// the four advisories get the same known-bad and known-good near-miss
// every other rule has, and `corpusGaps` reports them per band rather
// than adding four to the DRC catalogue's count.
//
// `#645` says the fixture gate *"applies to 28 pairs and this does not
// move it"*, which is honoured on the number. What it does not say, and
// what DR-154 rules, is that a rule shipped without its pair does not
// become acceptable by being filed under a different heading.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY NEAR MISS TURNS ON ONE PROPERTY
// ═══════════════════════════════════════════════════════════════════════
// A near miss that changes two things proves nothing about which one the
// rule reads. Each pair below differs by exactly one: a calibration, a
// pin, a rack's pin, a byte.
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';

import 'drc_fixture.dart';
import 'fixture_docs.dart';

const Uuid _underlayId = Uuid('0190e0dd-0f00-7000-8000-0000000000f0');
const Uuid _floorId = Uuid('0190e0dd-0f00-7000-8000-0000000000f1');
const Uuid _roomId = Uuid('0190e0dd-0f00-7000-8000-0000000000f2');
const Uuid _outletId = Uuid('0190e0dd-0f00-7000-8000-0000000000f3');
const Uuid _basementId = Uuid('0190e0dd-0f00-7000-8000-0000000000f4');

/// The bytes every fixture underlay claims to be.
final Uint8List kPlanBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

/// A calibration that yields a factor: two points a metre apart.
const PlanScale kUsableScale = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(1100, 100),
  distance: Len(1000000000),
);

/// A project with one floor, one room under it, and one underlay of the
/// floor.
///
/// THE ROOM IS A CHILD OF THE FLOOR, which is how the trade files a job
/// and is the case DR-154 §11.153.7a widened the scope for: an outlet in
/// `Great Room` is on `Level 1`'s plan.
RackDocument planDoc({
  PlanScale? scale,
  bool pinRack = false,
  bool pinOutlet = false,
  bool rackElsewhere = false,
  String? contentHash,
}) {
  final d = fixtureDoc();
  d.locations[_floorId] = Location(
    id: _floorId,
    kind: LocationKind.floor,
    name: 'Level 1',
    code: 'L1',
    order: const FracIndex('a0'),
    meta: fixtureMeta(),
  );
  d.locations[_roomId] = Location(
    id: _roomId,
    kind: LocationKind.room,
    name: 'Great Room',
    code: 'GR',
    order: const FracIndex('a1'),
    parentId: _floorId,
    meta: fixtureMeta(),
  );
  d.underlays[_underlayId] = PlanUnderlay(
    id: _underlayId,
    name: 'Level 1',
    imageMember: 'underlays/$_underlayId.png',
    format: PlanImageFormat.png,
    pixelWidth: 2000,
    pixelHeight: 1500,
    contentHash: contentHash ?? planUnderlayHash(kPlanBytes),
    order: const FracIndex('a0'),
    meta: fixtureMeta(),
    locationId: _floorId,
    scale: scale,
  );

  // THE HEAD END IS SOMETIMES ON ANOTHER FLOOR, which is `PLN-003`'s own
  // scenario rather than a way to dodge the harness: a utility room in
  // the basement, drops on Level 1, and no rack on Level 1's plan to
  // measure them from. It is also the only shape in which `PLN-003` fires
  // ALONE, because an unpinned rack on this floor is itself a row in the
  // strip `PLN-002` counts.
  d.locations[_basementId] = Location(
    id: _basementId,
    kind: LocationKind.floor,
    name: 'Basement',
    code: 'B1',
    order: const FracIndex('a2'),
    meta: fixtureMeta(),
  );
  d.racks[kFixtureRackId]!
    ..locationId = rackElsewhere ? _basementId : _floorId
    ..planPin = pinRack
        ? const PlanPin(underlayId: _underlayId, at: PxPt(50, 50))
        : null;

  d.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: fixtureId(90),
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: fixtureMeta(),
    locationId: _roomId,
    planPin: pinOutlet
        ? const PlanPin(underlayId: _underlayId, at: PxPt(400, 300))
        : null,
  );
  return d;
}

/// The evaluator's answer, with the byte fact `PLN-004` needs.
FixtureOutcome fromPlanDocument(
  RackDocument doc, {
  Set<Uuid> changed = const <Uuid>{},
}) {
  final findings = evaluateDocument(doc, changedUnderlays: changed);
  return (
    fired: {for (final f in findings) f.ruleId},
    messages: [for (final f in findings) f.message],
  );
}

List<DrcFixture> planFixtures() => [
  DrcFixture(
    ruleId: 'PLN-001',
    kind: FixtureKind.knownBad,
    what: 'a pinned drop on an underlay nobody has calibrated',
    run: () => fromPlanDocument(planDoc(pinRack: true, pinOutlet: true)),
  ),
  DrcFixture(
    ruleId: 'PLN-001',
    kind: FixtureKind.nearMiss,
    // ONE PROPERTY: the same document with a usable scale on it.
    what: 'the same plan with a two-point calibration on it',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale),
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-002',
    kind: FixtureKind.knownBad,
    what: 'an outlet in a room under this plan’s floor, with no pin',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, scale: kUsableScale),
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-002',
    kind: FixtureKind.nearMiss,
    what: 'the same outlet, pinned',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale),
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-003',
    kind: FixtureKind.knownBad,
    what: 'drops on this floor and the head end in the basement, unpinned',
    run: () => fromPlanDocument(
      planDoc(pinOutlet: true, rackElsewhere: true, scale: kUsableScale),
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-003',
    kind: FixtureKind.nearMiss,
    what: 'the same plan with the rack pinned too',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale),
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-004',
    kind: FixtureKind.knownBad,
    what: 'an underlay whose stored bytes no longer hash to its contentHash',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale),
      changed: const {_underlayId},
    ),
  ),
  DrcFixture(
    ruleId: 'PLN-004',
    kind: FixtureKind.nearMiss,
    // ONE PROPERTY: the same document, with the bytes verified and
    // matching. The empty set is what a caller that CHECKED and found
    // nothing passes, which is the state this fixture is about.
    what: 'the same plan whose bytes still match',
    run: () => fromPlanDocument(
      planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale),
    ),
  ),
];
