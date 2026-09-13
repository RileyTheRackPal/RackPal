// The placement tier's scenarios and their AC-051 pairs (M5-G2/G3).
//
// PLC-001..003 ALWAYS HAD BOTH HALVES, as named tests rather than a
// table: `placement_rules_test.dart` has carried a KNOWN-BAD and a
// NEAR-MISS for each since it was written. What it did not have was a
// coverage assertion, so nothing would have noticed a fourth PLC rule
// arriving with only one half, and nothing tied them to the catalogue.
//
// The cases here are those cases, in the shape `#302`'s gate can read.
import 'package:rackpal_core/rackpal_core.dart';

import 'drc_fixture.dart';

final DateTime _at = DateTime.utc(2026, 9, 4, 12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'fx');

const Uuid _rackId = Uuid('0190e0dd-0f01-7000-8000-0000000000a1');

/// A 12U rack with one 4-position zero-U channel.
Rack _rack() => Rack(
  id: _rackId,
  name: 'HEAD END',
  designator: 'RK-1',
  heightU: 12,
  order: const FracIndex('a0'),
  meta: _meta(),
  zeroUChannels: [
    ZeroUChannel(
      id: 'left',
      side: ZeroUChannelSide.rearLeft,
      startU: 1,
      endU: 12,
    ),
  ],
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('0190e0dd-0f01-7000-8000-000000000000'),
    appVersion: '0.5.50',
    createdAt: _at,
    modifiedAt: _at,
    meta: _meta(),
  );
  final r = _rack();
  doc.racks[r.id] = r;
  return doc;
}

FixtureOutcome _rail({
  int ruIndex = 1,
  int startTwelfth = 0,
  int spanTwelfths = 12,
}) => fromPlacement(
  evaluatePlacement(
    doc: _doc(),
    placement: RailPlacement(
      rackId: _rackId,
      ruIndex: ruIndex,
      face: Face.front,
      startTwelfth: startTwelfth,
      spanTwelfths: spanTwelfths,
    ),
    designator: 'AMP-1',
  ),
);

FixtureOutcome _zeroU(String channelId, Len offset, {Len? span}) =>
    fromPlacement(
      evaluatePlacement(
        doc: _doc(),
        placement: ZeroUPlacement(
          rackId: _rackId,
          channelId: channelId,
          offsetFromChannelStart: offset,
          spanAlongChannel: span,
          orientation: ZeroUOrientation.vertical,
        ),
        designator: 'PDU-1',
      ),
    );

/// The three PLC rules' pairs.
List<DrcFixture> placementFixtures() => [
  DrcFixture(
    ruleId: 'PLC-001',
    kind: FixtureKind.knownBad,
    what: 'U 40 of a 12 U rack',
    run: () => _rail(ruIndex: 40),
    // The refusal names the rack and the RU it was given, so a person
    // reading it does not have to guess which rack refused.
    mustName: const ['RK-1', '40'],
  ),
  DrcFixture(
    ruleId: 'PLC-001',
    kind: FixtureKind.nearMiss,
    what: 'U 12 is the top U of a 12 U rack and fits',
    run: () => _rail(ruIndex: 12),
  ),
  DrcFixture(
    ruleId: 'PLC-002',
    kind: FixtureKind.knownBad,
    what: '13 twelfths is wider than the opening',
    run: () => _rail(spanTwelfths: 13),
  ),
  const DrcFixture(
    ruleId: 'PLC-002',
    kind: FixtureKind.nearMiss,
    what: '12 twelfths is exactly the full opening',
    run: _rail,
  ),
  DrcFixture(
    ruleId: 'PLC-003',
    kind: FixtureKind.knownBad,
    what: 'a channel id the rack does not have',
    run: () => _zeroU('right', const Len(0)),
  ),
  DrcFixture(
    ruleId: 'PLC-003',
    kind: FixtureKind.nearMiss,
    what: 'the id the rack does have, at the near end',
    run: () => _zeroU('left', const Len(0)),
  ),
  // THE TAIL, which this rule could not see until `#883` gave a 0U
  // occupant an extent (DR-166 §11.165.3). The channel is 12 U long, so
  // 13 U of PDU starting at its near end hangs a unit off the top.
  DrcFixture(
    ruleId: 'PLC-003',
    kind: FixtureKind.knownBad,
    what: 'a span that runs off the end of the channel',
    run: () => _zeroU('left', const Len(0), span: kRackUnit * 13),
  ),
  DrcFixture(
    ruleId: 'PLC-003',
    kind: FixtureKind.nearMiss,
    what: 'a span that fills the channel exactly',
    run: () => _zeroU('left', const Len(0), span: kRackUnit * 12),
  ),
];
