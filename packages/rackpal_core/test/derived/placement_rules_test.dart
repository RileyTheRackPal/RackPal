// `PLC-001`, `PLC-002` and `PLC-003` (`#268`, `#269`, `#270`, M5-C).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY RULE GETS ITS PAIR HERE, NOT LATER
// ═══════════════════════════════════════════════════════════════════════
// AC-051: no rule ships without a known-bad and a known-good near-miss,
// and *"a known-bad alone proves the rule fires, not that it
// discriminates"* (`#298`). The `.bad`/`.near` document corpus and the CI
// gate that counts pairs are M5-G's (`#299`..`#302`); the DISCIPLINE is
// not deferred with them, so each rule below has a bad case and a case
// ONE PROPERTY away from it that must produce nothing. A rule written as
// `return refused` passes every bad case in this file and fails every
// near-miss.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY NOT HERE
// ═══════════════════════════════════════════════════════════════════════
// Occupancy. Two devices in one U is `findBlockingOccupant`'s refusal and
// `RCK-001`'s finding, and DR-112 rules it out of tier 1. There is a test
// below asserting exactly that, because the natural mistake when writing
// `PLC-001` is to reach for the occupancy scan that is sitting right
// there in `catalog_placement.dart`.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 2);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

Rack _rack({int heightU = 12, List<ZeroUChannel>? channels}) => Rack(
  id: const Uuid('rk-1'),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  zeroUChannels: channels,
  meta: _meta(),
);

TemplateBody _body({required int frontU, int rearU = 0}) => TemplateBody(
  manufacturer: 'Test',
  model: 'test-device',
  displayName: 'test-device',
  typePrefix: 'DEV',
  frontU: frontU,
  rearU: rearU,
  side: frontU > 0 && rearU > 0
      ? OccupancySide.both
      : (rearU > 0 ? OccupancySide.rear : OccupancySide.front),
);

RackDocument _doc({Rack? rack}) {
  final doc = RackDocument(
    id: const Uuid('doc-plc'),
    appVersion: '0.5.14',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final r = rack ?? _rack();
  doc.racks[r.id] = r;
  return doc;
}

RailPlacement _rail({
  int ruIndex = 1,
  int startTwelfth = 0,
  int spanTwelfths = 12,
  Face face = Face.front,
  Uuid rackId = const Uuid('rk-1'),
}) => RailPlacement(
  rackId: rackId,
  ruIndex: ruIndex,
  face: face,
  startTwelfth: startTwelfth,
  spanTwelfths: spanTwelfths,
);

PlacementVerdict _verdict(
  RackDocument doc,
  Placement placement, {
  TemplateBody? body,
  String designator = 'AMP-1',
}) => evaluatePlacement(
  doc: doc,
  placement: placement,
  body: body,
  designator: designator,
);

void main() {
  group('PLC-001: the RU is in the rack, and the device fits from it', () {
    test('KNOWN-BAD: U 40 of a 12 U rack is refused, and the sentence '
        'names the rack and its height', () {
      final verdict = _verdict(_doc(), _rail(ruIndex: 40));
      expect(verdict, isA<PlacementRefused>());
      final refused = verdict as PlacementRefused;
      expect(refused.ruleId, 'PLC-001');
      expect(refused.message, contains('RK-1'));
      expect(refused.message, contains('40'));
      expect(refused.message, endsWith('.'));
    });

    test('NEAR-MISS: U 12 of the same rack is the top U and is fine', () {
      expect(_verdict(_doc(), _rail(ruIndex: 12)), isA<PlacementAllowed>());
    });

    test('U 0 is refused too, because the RU axis is 1-based from the '
        'bottom whatever the display numbering says (CR-025)', () {
      expect(_verdict(_doc(), _rail(ruIndex: 0)), isA<PlacementRefused>());
      expect(_verdict(_doc(), _rail()), isA<PlacementAllowed>());
    });

    test('KNOWN-BAD: a 3 U device at U 11 of a 12 U rack reaches U 13 and '
        'is refused on the EXTENT half', () {
      final verdict = _verdict(
        _doc(),
        _rail(ruIndex: 11),
        body: _body(frontU: 3),
      );
      expect(verdict, isA<PlacementRefused>());
      expect((verdict as PlacementRefused).ruleId, 'PLC-001');
      expect(verdict.message, contains('13'));
    });

    test('NEAR-MISS: the same 3 U device at U 10 reaches U 12 exactly and '
        'is fine', () {
      expect(
        _verdict(_doc(), _rail(ruIndex: 10), body: _body(frontU: 3)),
        isA<PlacementAllowed>(),
      );
    });

    test('the height is read from the PLACED FACE, so a front-only device '
        'placed on the rear is not measured by its front height', () {
      // `occupancyU` returns null for a face the device does not occupy,
      // and null is unknown rather than zero (G4). A 3 U front-only
      // device placed on the rear has no knowable rear height, so the
      // extent half is silent rather than refusing at U 11.
      expect(
        _verdict(
          _doc(),
          _rail(ruIndex: 11, face: Face.rear),
          body: _body(frontU: 3),
        ),
        isA<PlacementAllowed>(),
      );
    });

    test('an unresolvable template is UNKNOWN, not zero: the bounds half '
        'still runs and the extent half stays silent (G4)', () {
      expect(_verdict(_doc(), _rail(ruIndex: 12)), isA<PlacementAllowed>());
      expect(_verdict(_doc(), _rail(ruIndex: 13)), isA<PlacementRefused>());
    });
  });

  group('PLC-002: the lateral span fits the opening (CR-030)', () {
    test('KNOWN-BAD: 13 twelfths is wider than the opening', () {
      final verdict = _verdict(_doc(), _rail(spanTwelfths: 13));
      expect(verdict, isA<PlacementRefused>());
      expect((verdict as PlacementRefused).ruleId, 'PLC-002');
    });

    test('NEAR-MISS: 12 twelfths is the full opening and is the default', () {
      expect(_verdict(_doc(), _rail()), isA<PlacementAllowed>());
    });

    test('KNOWN-BAD: a half-rack device starting at twelfth 7 runs one '
        'twelfth past the right-hand rail', () {
      final verdict = _verdict(_doc(), _rail(startTwelfth: 7, spanTwelfths: 6));
      expect(verdict, isA<PlacementRefused>());
      expect((verdict as PlacementRefused).ruleId, 'PLC-002');
      expect(verdict.message, contains('1 twelfths'));
    });

    test('NEAR-MISS: CR-030 three shipped positions all pass', () {
      // `Full (0,12) | Left half (0,6) | Right half (6,6)` is the whole
      // of what the v1 editor can produce, so if any of these refused the
      // rule would be refusing the product.
      for (final (start, span) in const [(0, 12), (0, 6), (6, 6)]) {
        expect(
          _verdict(_doc(), _rail(startTwelfth: start, spanTwelfths: span)),
          isA<PlacementAllowed>(),
          reason: 'start $start span $span',
        );
      }
    });

    test('a zero-width or negative span is refused, which no editor can '
        'produce and an import can', () {
      expect(_verdict(_doc(), _rail(spanTwelfths: 0)), isA<PlacementRefused>());
      expect(
        _verdict(_doc(), _rail(startTwelfth: -1)),
        isA<PlacementRefused>(),
      );
      expect(
        _verdict(_doc(), _rail(startTwelfth: 12)),
        isA<PlacementRefused>(),
      );
    });
  });

  group('PLC-003: the 0U channel resolves and holds the offset (CR-031)', () {
    ZeroUChannel channel() => ZeroUChannel(
      id: 'ch-left',
      side: ZeroUChannelSide.rearLeft,
      startU: 1,
      endU: 12,
    );

    RackDocument docWithChannel() => _doc(rack: _rack(channels: [channel()]));

    ZeroUPlacement zeroU({
      String channelId = 'ch-left',
      Len offset = const Len(0),
    }) => ZeroUPlacement(
      rackId: const Uuid('rk-1'),
      channelId: channelId,
      offsetFromChannelStart: offset,
      orientation: ZeroUOrientation.vertical,
    );

    test('KNOWN-BAD: a channel id the rack does not have is refused', () {
      final verdict = _verdict(docWithChannel(), zeroU(channelId: 'ch-right'));
      expect(verdict, isA<PlacementRefused>());
      final refused = verdict as PlacementRefused;
      expect(refused.ruleId, 'PLC-003');
      expect(refused.message, contains('ch-right'));
      expect(refused.message, contains('RK-1'));
    });

    test('NEAR-MISS: the id the rack DOES have resolves', () {
      expect(_verdict(docWithChannel(), zeroU()), isA<PlacementAllowed>());
    });

    test('KNOWN-BAD: an offset past the end of the channel is refused', () {
      // The channel spans U1..U12 inclusive, so 12 U of rail.
      final verdict = _verdict(
        docWithChannel(),
        zeroU(offset: kRackUnit * 13),
      );
      expect(verdict, isA<PlacementRefused>());
      expect((verdict as PlacementRefused).ruleId, 'PLC-003');
    });

    test('NEAR-MISS: an offset at exactly the far end is inside it, '
        'because endU is the last U the channel COVERS', () {
      expect(
        _verdict(docWithChannel(), zeroU(offset: kRackUnit * 12)),
        isA<PlacementAllowed>(),
      );
    });

    test('a negative offset is refused', () {
      expect(
        _verdict(docWithChannel(), zeroU(offset: const Len(-1))),
        isA<PlacementRefused>(),
      );
    });
  });

  group('what tier 1 does NOT refuse (DR-112, CR-021)', () {
    test('OCCUPANCY IS NOT A PLC RULE. Two devices in one U is '
        'findBlockingOccupant and RCK-001, and stacking them here is the '
        'natural mistake this test exists to catch', () {
      final doc = _doc();
      doc.devices[const Uuid('dev-1')] = DeviceInstance(
        id: const Uuid('dev-1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.test'),
          version: 1,
          contentHash: 'sha256:test',
        ),
        designator: 'SW-1',
        name: 'Switch',
        placement: _rail(ruIndex: 5),
        meta: _meta(),
      );
      expect(
        _verdict(doc, _rail(ruIndex: 5), body: _body(frontU: 1)),
        isA<PlacementAllowed>(),
      );
    });

    test('a rack that is not in the document makes PLC-001 and PLC-003 '
        'UNEVALUATABLE, because no catalogue rule covers a dangling rack '
        'reference and CR-021 says one that is not listed does not exist', () {
      final doc = _doc();
      expect(
        _verdict(doc, _rail(ruIndex: 999, rackId: const Uuid('rk-nope'))),
        isA<PlacementAllowed>(),
      );
    });

    test('but PLC-002 still runs on a dangling rack reference, because it '
        'reads nothing but the placement', () {
      expect(
        _verdict(
          _doc(),
          _rail(spanTwelfths: 13, rackId: const Uuid('rk-nope')),
        ),
        isA<PlacementRefused>(),
      );
    });

    test('no PLC rule reaches a shelf, off-rack or staged placement', () {
      final doc = _doc();
      for (final placement in <Placement>[
        ShelfPlacement(hostDeviceId: const Uuid('dev-1'), order: _order()),
        const OffRackPlacement(),
        const StagedPlacement(),
      ]) {
        expect(
          _verdict(doc, placement),
          isA<PlacementAllowed>(),
          reason: placement.runtimeType.toString(),
        );
      }
    });
  });

  group('the catalogue and the predicates agree', () {
    test('every PlacementRule id is a tier-1 rule the catalogue knows, '
        'and the three PLC rows are exactly the three here', () {
      for (final rule in PlacementRule.values) {
        final meta = kRulesById[rule.id];
        expect(meta, isNotNull, reason: rule.id);
        expect(meta!.tier, RuleTier.modelIllegal, reason: rule.id);
        expect(meta.defaultSeverity, isNull, reason: rule.id);
      }
      expect(
        PlacementRule.values.map((r) => r.id).toList(),
        <String>['PLC-001', 'PLC-002', 'PLC-003'],
      );
    });

    test('a refusal never carries a severity, because tier 1 files no '
        'finding to be severe about', () {
      final verdict = _verdict(_doc(), _rail(ruIndex: 40));
      expect(verdict, isA<PlacementRefused>());
      expect(projectSeverity('PLC-001', _doc().settings), isNull);
    });
  });
}

FracIndex _order() => const FracIndex('a0');
