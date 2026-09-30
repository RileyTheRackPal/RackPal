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
import 'dart:io';

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

  group('the writers that exist are gated (M5-C wiring)', () {
    RackDocument docWithCatalog() {
      final doc = _doc();
      doc.templates[catalogTemplateKey('V01')] = TemplateSnapshot(
        templateId: const TemplateId('V01'),
        version: 1,
        contentHash: 'sha256:v01',
        body: _body(frontU: 3),
        capturedAt: _now,
      );
      return doc;
    }

    CatalogPlacementResult place(int ruIndex) => buildPlaceFromCatalogCommand(
      doc: docWithCatalog(),
      catalogId: 'V01',
      targetRack: _rack(),
      now: _now,
      actor: 'test',
      explicitRuIndex: ruIndex,
    );

    test('KNOWN-BAD: the catalog planner refuses a caret that would not '
        'fit, and the refusal now CITES PLC-001', () {
      // The bound used to be transcribed by hand into this planner with
      // no rule id on the refusal, which is the shape canon §12.6(b)
      // ratified PLC-001..003 over. The sentence is still the drop
      // chip's; the decision and the attribution are the rule's.
      final result = place(11);
      expect(result, isA<CatalogPlacementFailed>());
      expect((result as CatalogPlacementFailed).ruleId, 'PLC-001');
    });

    test('NEAR-MISS: one U lower fits exactly and builds a command', () {
      expect(place(10), isA<CatalogPlacementReady>());
    });

    test('an occupancy refusal carries NO rule id, because DR-112 rules '
        'it out of tier 1 and CR-021 forbids inventing one', () {
      final doc = docWithCatalog();
      doc.devices[const Uuid('dev-1')] = DeviceInstance(
        id: const Uuid('dev-1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('V01'),
          version: 1,
          contentHash: 'sha256:v01',
        ),
        designator: 'SW-1',
        name: 'Switch',
        placement: _rail(ruIndex: 2),
        meta: _meta(),
      );
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V01',
        targetRack: doc.racks[const Uuid('rk-1')]!,
        now: _now,
        actor: 'test',
        explicitRuIndex: 1,
      );
      expect(result, isA<CatalogPlacementFailed>());
      final failed = result as CatalogPlacementFailed;
      expect(failed.reason, contains('SW-1'));
      expect(failed.ruleId, isNull);
    });

    test('the writer-detector itself is verified in BOTH directions, '
        'because a scan that cannot fail is worse than no scan', () {
      // The gate below is a grep, and the first draft of it reported five
      // pattern matches as writers. `junit_converter_selftest.py` is the
      // precedent this follows: a checker whose negative direction is
      // reproduced by hand is a verification somebody performed, not one
      // the repository performs.
      //
      // The four NO cases are the exact shapes present in `lib/` today.
      for (final line in const [
        '      placement: ZeroUPlacement(',
        "  return ZeroUPlacement(rackId: rack.id, channelId: 'c');",
      ]) {
        expect(_constructs(line, 'ZeroUPlacement'), isTrue, reason: line);
      }
      for (final line in const [
        '      case ZeroUPlacement(:final rackId, :final channelId)',
        '      case ZeroUPlacement():',
        '    ZeroUPlacement() => (EquipmentMounting.zeroU, null, null),',
        '    ZeroUPlacement() => _evaluateZeroU(doc, placement, what),',
      ]) {
        expect(_constructs(line, 'ZeroUPlacement'), isFalse, reason: line);
      }
    });

    test('TOP-005 HAS a writer now, and the only one is the gated one', () {
      // ═══════════════════════════════════════════════════════════════
      // THIS TEST HAS NOW DONE ITS JOB THREE TIMES
      // ═══════════════════════════════════════════════════════════════
      // It asked "does a writer exist" and went red the moment one did,
      // naming the file, which is exactly what it was for. It covered
      // `PLC-002` until `#269` built the width control and `PLC-003`
      // until `#270` built the 0U chain; each of those became the
      // sharper question below. **`ShelfPlacement` is the third**, built
      // at DR-128 for `PWR-003`'s power-strip remedy, which had nowhere
      // to put a strip because nothing in this product could set a
      // device on a shelf.
      //
      // Its own reason string said what to do: "gate it and correct the
      // note on ConnectRule.hostResolves". Both are done, and the
      // question is now narrower and lasts longer: not whether a writer
      // exists, but whether the one that does asks TOP-005 first.
      //
      // The scan reads the SOURCE, and it is a grep rather than a
      // parser: false negatives are acceptable, a false positive that
      // makes it flaky is not. Its first draft was a false positive five
      // times over, because `contains('ShelfPlacement(')` matches every
      // pattern match on the type as well as every construction, and
      // this codebase switches on placements in four files.
      // [_constructs] carries the discriminator, and the test above
      // verifies that discriminator in BOTH directions.
      //
      // EVERY PACKAGE, not just this one, and the count is asserted so
      // the scan cannot silently degrade to core-only if the workspace
      // layout moves. `internal_setter_grep_test.dart` learned that the
      // hard way: it scanned core alone while the UI was writing
      // straight to `Rack` setters.
      final roots = <Directory>[
        Directory('lib'),
        Directory('../rackpal_ui/lib'),
        Directory('../../apps/rackpal/lib'),
      ].where((d) => d.existsSync()).toList();
      expect(
        roots,
        hasLength(3),
        reason:
            'expected core, ui and the app shell; found '
            '${roots.map((d) => d.path)}. Run from the package directory, '
            'and update these paths if the workspace moved',
      );

      final shelfWriters = <String>{};
      for (final f
          in roots
              .expand((d) => d.listSync(recursive: true))
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = f.path.replaceAll(r'\', '/');
        // The type's own declaration and the codec are not writers in
        // the sense that matters: one defines it and the other reads a
        // file somebody else wrote.
        if (path.endsWith('/model/placement.dart')) continue;
        if (path.endsWith('/persistence/json_codec.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          // COMMENTS ARE NOT WRITERS, and skipping them is not tidiness:
          // the files in this package explain themselves at length and a
          // doc comment showing a worked `ShelfPlacement(hostDeviceId:
          // ...)` would turn this gate red over prose.
          if (line.trimLeft().startsWith('//')) continue;
          if (_constructs(line, 'ShelfPlacement')) shelfWriters.add(path);
        }
      }

      // TWO WRITERS SINCE DR-204/DR-205, and this is where the second one
      // was caught: `placement_commands.dart` MOVES an existing device
      // onto a shelf (a drag, a return from the Staging Bin), and it went
      // red here before it asked. A move needs the cycle half as well,
      // because the device being moved can already be a shelf with hosts.
      const writers = {
        'lib/src/commands/shelf_placement.dart',
        'lib/src/commands/placement_commands.dart',
      };
      expect(
        shelfWriters,
        writers,
        reason:
            'a new shelf writer would need its own TOP-005 check, and '
            'one that moved would leave this pointing at nothing',
      );
      for (final writer in writers) {
        expect(
          File(writer).readAsStringSync(),
          contains("ruleId: 'TOP-005'"),
          reason:
              '$writer stopped asking whether its host is a container, so '
              'a device can be set on a rack ear and TOP-005 will not say '
              'so until somebody wires it',
        );
      }
      expect(
        File(
          'lib/src/commands/placement_commands.dart',
        ).readAsStringSync(),
        contains('shelfMoveWouldLoop('),
        reason:
            'the MOVE writer stopped walking the chain, so a shelf can be '
            'set on a shelf that sits on it',
      );
    });

    test('PLC-002 HAS a writer now, and the only one is the gated one', () {
      // The question this replaces was "does a writer exist"; it went
      // red the moment one did, which is what it was for. The question
      // now is narrower and lasts longer: `device_width_commands.dart`
      // is the single file that sets a lateral position it did not copy
      // from an existing placement, and it runs the placement gate.
      final writers = <String>{};
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = f.path.replaceAll(r'\', '/');
        if (path.endsWith('/persistence/json_codec.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          if (line.trimLeft().startsWith('//')) continue;
          // A COPY IS NOT A WRITE. `MoveDeviceCommand` rebuilds a rail
          // placement and carries `base.startTwelfth` across it, which
          // cannot introduce a value `PLC-002` would refuse.
          final m = RegExp(
            r'(startTwelfth|spanTwelfths):\s*(.+)$',
          ).firstMatch(line);
          if (m != null && !m.group(2)!.contains('.${m.group(1)}')) {
            writers.add(path);
          }
        }
      }
      expect(
        writers,
        {'lib/src/commands/device_width_commands.dart'},
        reason:
            'a second lateral writer would need its own gate, and a '
            'first one that moved would leave this pointing at nothing',
      );
      expect(
        File('lib/src/commands/device_width_commands.dart').readAsStringSync(),
        contains('evaluatePlacement('),
        reason:
            'the lateral writer stopped calling the placement gate, so '
            'PLC-002 is a predicate nobody calls again',
      );
    });

    test('PLC-003 HAS writers now, and BOTH of them are gated', () {
      // Two, and they are the two AC-044 names: creating an occupant
      // (`catalog_placement.dart`) and editing where it sits along its
      // channel (`zero_u_commands.dart`). A third that skipped the gate
      // would put a device in a channel the rack does not have.
      final writers = <String>{};
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = f.path.replaceAll(r'\', '/');
        if (path.endsWith('/model/placement.dart')) continue;
        if (path.endsWith('/persistence/json_codec.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          if (line.trimLeft().startsWith('//')) continue;
          if (_constructs(line, 'ZeroUPlacement')) writers.add(path);
        }
      }
      expect(writers, {
        'lib/src/commands/catalog_placement.dart',
        'lib/src/commands/zero_u_commands.dart',
      });
      for (final path in writers) {
        expect(
          File(path).readAsStringSync(),
          contains('evaluatePlacement('),
          reason: '$path builds a ZeroUPlacement without the gate',
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

/// Whether [line] CONSTRUCTS a placement of [type] rather than matching one.
///
/// A construction is followed by a named argument or by the end of the
/// line (a multi-line call). A pattern is followed by `)` immediately, or
/// by `:final`, or sits behind `case`. Every occurrence in `lib/` today is
/// one of those three.
bool _constructs(String line, String type) {
  final needle = '$type(';
  final at = line.indexOf(needle);
  if (at < 0) return false;
  if (line.contains('case ')) return false;
  final rest = line.substring(at + needle.length).trim();
  if (rest.startsWith(')')) return false;
  if (rest.startsWith(':')) return false;
  return true;
}
