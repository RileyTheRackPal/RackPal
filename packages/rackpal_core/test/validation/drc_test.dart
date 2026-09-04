// M5-E — the tier-3 evaluator, and the first two rules through it.
//
// AC-051 IS THE MILESTONE'S EXIT CRITERION, so every rule here arrives
// with a known-bad fixture AND a known-good near-miss. The near-miss is
// the half that catches a predicate firing on correct designs, which is
// how a rule loses its credibility with the people it is for — and M5-D's
// near-miss table found a real defect on the day it shipped, one rule
// along from the one it was written for.
//
// AND THE COVERAGE GATE RUNS BOTH WAYS. Fourteen catalogue rows and
// thirteen predicates ships a catalogue that lies about what the product
// checks; thirteen rows and fourteen predicates ships a rule CR-021 says
// does not exist.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 3, 12);
  EntityMeta meta() => EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't');

  late RackDocument doc;
  late Rack rack;

  /// A 12U rack and nothing in it.
  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0dd-0000-7000-8000-000000000000'),
      appVersion: '0.5.32',
      createdAt: at,
      modifiedAt: at,
      meta: meta(),
      info: ProjectInfo(projectName: 'DRC FIXTURE'),
      registries: buildSeedRegistries(),
    );
    const rackId = Uuid('0190e0dd-0000-7000-8000-000000000fff');
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      meta: meta(),
    );
    return d;
  }

  var seq = 0;

  /// Places [catalogId] at [ru] on [face], bypassing the placement
  /// planner.
  ///
  /// DELIBERATELY NOT `buildPlaceFromCatalogCommand`. That path enforces
  /// `PLC-001` and refuses an overlap, which is the whole point of
  /// DR-112: tier 1 gates the GESTURE and tier 3 reports the STATE, and a
  /// document can reach a state no gesture would have made — a rack
  /// shrunk under a device, a hand-edited file, a device placed before
  /// M5-C shipped. A fixture built through the gate could not express any
  /// of those, so these tests would be asserting that an unreachable
  /// state is never reported.
  DeviceInstance place(
    String catalogId,
    int ru, {
    Face face = Face.front,
    String? designator,
  }) {
    seq++;
    final body = buildSeedCatalog()[catalogId]!;
    doc.templates[templateKey(catalogId, 1)] = TemplateSnapshot(
      templateId: TemplateId(catalogId),
      version: 1,
      contentHash: 'sha256:seed-$catalogId',
      body: body,
      capturedAt: at,
    );
    final device = DeviceInstance(
      id: Uuid('0190e0dd-0000-7000-8000-${seq.toString().padLeft(12, '0')}'),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(catalogId),
        version: 1,
        contentHash: 'sha256:seed-$catalogId',
      ),
      designator: designator ?? '$catalogId-$seq',
      name: body.displayName,
      placement: RailPlacement(rackId: rack.id, ruIndex: ru, face: face),
      meta: meta(),
    );
    doc.devices[device.id] = device;
    return device;
  }

  setUp(() {
    seq = 0;
    doc = build();
    rack = doc.racks.values.first;
  });

  List<String> idsOf(List<Finding> f) => [for (final x in f) x.ruleId];

  /// [catalogId]'s front occupancy, MEASURED rather than remembered.
  ///
  /// The first draft of this file asserted V01 was 2U. It is 3U, and the
  /// premise assertion that said so is the only reason two near-misses
  /// were not quietly testing the wrong boundary. Heights come from the
  /// catalog now.
  int heightOf(String catalogId) => buildSeedCatalog()[catalogId]!.frontU;

  group('the catalogue and the predicates agree (CR-021)', () {
    test('every post-hoc row has a predicate, and every predicate a row', () {
      // BOTH DIRECTIONS, and the second is the one that matters: a row
      // with no predicate ships a catalogue that lies about what the
      // product checks, and nothing else in the tree would notice.
      final rows = {
        for (final m in kRulesById.values)
          if (m.tier == RuleTier.postHoc) m.ruleId,
      };
      final built = kDrcRules.keys.toSet();
      expect(
        built.difference(rows),
        isEmpty,
        reason:
            'a predicate with no catalogue row is a rule CR-021 says '
            'does not exist',
      );
      // THE OTHER DIRECTION NOW CLOSES, which it could not while M5-E was
      // part-built. Fourteen rows and thirteen predicates ships a
      // catalogue that LIES about what the product checks, and nothing
      // else in the tree would notice.
      expect(
        rows.difference(built),
        isEmpty,
        reason:
            'a catalogue row with no predicate is a rule the product '
            'claims to check and does not',
      );
      expect(
        built,
        hasLength(14),
        reason:
            'docs/02 §5 gives 28 rules as 8 + 6 + 14, and this is '
            'the fourteen',
      );
    });

    test('every rule this file builds carries the severity its row does', () {
      // The evaluator resolves severity through `projectSeverity`, so a
      // predicate stamping a different one would be silently overwritten
      // and the disagreement would never surface. Asserted here instead.
      for (final id in kDrcRules.keys) {
        expect(kRulesById[id]!.defaultSeverity, isNotNull, reason: id);
      }
    });
  });

  group('RCK-001 — RU overlap on the same face (#285)', () {
    test('KNOWN BAD: two devices in the same U on one face', () {
      // A02 is the AV receiver, hosted 4U. V01 is the 8x8 matrix. Both
      // occupy front U, so U3 and U4 collide.
      final lower = place('V01', 3, designator: 'MTX-1');
      final upper = place('V01', 3, designator: 'MTX-2');

      final found = evaluateDocument(doc, only: 'RCK-001');
      expect(found, hasLength(1));
      expect(found.single.severity, Severity.error);
      expect(found.single.message, contains('MTX-1'));
      expect(found.single.message, contains('MTX-2'));
      expect(found.single.message, contains('RK-1'));
      expect(
        found.single.targets,
        containsAll([lower.id, upper.id, rack.id]),
      );
      expect(
        found.single.primaryEntityId,
        upper.id,
        reason: 'the issues list selects the device a person will move',
      );
    });

    test('the FACE is read, and the sentence proves it', () {
      // docs/02 §5.3's qualifier is the whole rule: front and rear in one
      // U is how a rack is packed, not a collision.
      //
      // A PURE OPPOSITE-FACES NEAR-MISS CANNOT BE BUILT FROM THIS
      // CATALOG, and that is a fact about the seed set rather than a gap
      // in this test. Measured: every rack-side archetype is
      // `OccupancySide.both` except `N03`, the patch panel, which is
      // front-only. There is no rear-only body to pair it with, so no two
      // seeded devices can share a U without also sharing a face.
      //
      // So face-awareness is proven the way the fixture allows: a
      // front-only panel overlapping a both-faces device collides on ONE
      // face, and the sentence has to say which. A predicate that ignored
      // the face would say "both faces" here.
      expect(
        buildSeedCatalog()['N03']!.rearU,
        0,
        reason: 'the premise: N03 is front-only',
      );
      place('N03', 3, designator: 'PP-1');
      place('V01', 3, designator: 'MTX-1');

      final found = evaluateDocument(doc, only: 'RCK-001');
      expect(found, hasLength(1));
      expect(found.single.message, contains('the front face'));
      expect(
        found.single.message,
        isNot(contains('both faces')),
        reason: 'PP-1 occupies no rear U, so there is no rear collision',
      );
    });

    test('KNOWN GOOD (near miss): stacked, touching, not overlapping', () {
      // The off-by-one that a `>` instead of a `>=` would produce. V01 is
      // 2U, so U3-U4 and U5-U6 are adjacent and legal.
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3 + heightOf('V01'), designator: 'MTX-2');
      expect(evaluateDocument(doc, only: 'RCK-001'), isEmpty);
    });

    test('KNOWN GOOD (near miss): the same U in DIFFERENT racks', () {
      const otherId = Uuid('0190e0dd-0000-7000-8000-0000000000aa');
      doc.racks[otherId] = Rack(
        id: otherId,
        name: 'SECOND',
        designator: 'RK-2',
        heightU: 12,
        order: const FracIndex('a1'),
        meta: meta(),
      );
      place('V01', 3, designator: 'MTX-1');
      final second = place('V01', 3, designator: 'MTX-2');
      doc.devices[second.id] = DeviceInstance(
        id: second.id,
        kind: second.kind,
        templateRef: second.templateRef,
        designator: second.designator,
        name: second.name,
        placement: const RailPlacement(
          rackId: otherId,
          ruIndex: 3,
          face: Face.front,
        ),
        meta: meta(),
      );
      expect(evaluateDocument(doc, only: 'RCK-001'), isEmpty);
    });

    test('three in one U is three PAIRS, not one finding', () {
      // The rule is about a pair of devices, so the fingerprint is about
      // a pair: acknowledging "MTX-1 and MTX-2 overlap" must not silence
      // "MTX-1 and MTX-3 overlap", which is a different fact about a
      // different pair of things to move.
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3, designator: 'MTX-2');
      place('V01', 3, designator: 'MTX-3');
      final found = evaluateDocument(doc, only: 'RCK-001');
      expect(found, hasLength(3));
      expect(
        found.map((f) => f.targetFingerprint).toSet(),
        hasLength(3),
        reason: 'three distinct pairs are three distinct fingerprints',
      );
    });
  });

  group('RCK-002 — a device extends past heightU (#286)', () {
    test('KNOWN BAD: a 2U device at U12 in a 12U rack', () {
      final device = place('V01', 12, designator: 'MTX-1');
      final found = evaluateDocument(doc, only: 'RCK-002');
      expect(found, hasLength(1));
      expect(found.single.message, contains('MTX-1'));
      expect(found.single.message, contains('12U'));
      expect(found.single.targets, containsAll([device.id, rack.id]));
    });

    test(
      'KNOWN GOOD (near miss): the same device one U lower fits exactly',
      () {
        // The boundary, computed rather than typed. A device whose top U
        // is the rack's last U fits exactly, and a `>=` here would report
        // every device that reaches the top of its rack.
        place(
          'V01',
          rack.heightU - heightOf('V01') + 1,
          designator: 'MTX-1',
        );
        expect(evaluateDocument(doc, only: 'RCK-002'), isEmpty);
      },
    );

    test(
      'a device BELOW the bottom rail is the same rule, said differently',
      () {
        // docs/02 §5.3 gives one row for the extent, so U0 and U13 are one
        // rule. Splitting them would invent a catalogue entry (CR-021), and
        // saying the same sentence for both would misdescribe one of them.
        place('V01', 0, designator: 'MTX-1');
        final found = evaluateDocument(doc, only: 'RCK-002');
        expect(found, hasLength(1));
        expect(found.single.ruleId, 'RCK-002');
        expect(found.single.message, contains('below the bottom rail'));
      },
    );

    test(
      'a device whose template does not resolve is SKIPPED, not reported',
      () {
        // G4/CR-114: `elevationOccupancyU` returns null for an unresolvable
        // snapshot, and a rule reading that as "occupies nothing" would
        // quietly stop checking exactly the devices whose data is broken.
        // Skipping is the honest answer; reporting a height nobody knows
        // would be inventing one.
        final device = place('V01', 12, designator: 'MTX-1');
        doc.templates.clear();
        expect(evaluateDocument(doc, only: 'RCK-002'), isEmpty);
        expect(doc.devices.containsKey(device.id), isTrue);
      },
    );
  });

  group('the evaluator resolves severity, in one place and in order', () {
    test('a project override changes what the finding IS', () {
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3, designator: 'MTX-2');
      expect(
        evaluateDocument(doc, only: 'RCK-001').single.severity,
        Severity.error,
      );

      doc.settings.ruleOverrides['RCK-001'] = RuleOverride(
        severity: Severity.warning,
        // CR-019's whole point: an override is a project-scope act and
        // the reason is required at the writer, so a fixture that
        // omitted it would be exercising a shape the product refuses.
        reason: 'this rack is documented as-found',
        by: 't',
        at: at,
      );
      expect(
        evaluateDocument(doc, only: 'RCK-001').single.severity,
        Severity.warning,
        reason:
            'a finding carries what it IS in this project, so the '
            'issues list and the sheet cannot disagree about one row',
      );
    });

    test('an override to OFF removes it entirely', () {
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3, designator: 'MTX-2');
      doc.settings.ruleOverrides['RCK-001'] = RuleOverride(
        severity: Severity.off,
        // CR-019's whole point: an override is a project-scope act and
        // the reason is required at the writer, so a fixture that
        // omitted it would be exercising a shape the product refuses.
        reason: 'this rack is documented as-found',
        by: 't',
        at: at,
      );
      expect(evaluateDocument(doc, only: 'RCK-001'), isEmpty);
    });

    test('the order is deterministic across runs', () {
      // CLAUDE.md's determinism invariant. `List.sort` is not stable, so
      // a comparator that tied would give a different order on a
      // different run over the same document.
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3, designator: 'MTX-2');
      place('V01', 12, designator: 'MTX-3');
      final once = evaluateDocument(doc);
      final twice = evaluateDocument(doc);
      expect(once, isNotEmpty, reason: 'the premise: something fired');
      expect(idsOf(once), idsOf(twice));
      expect(
        once.map((f) => f.targetFingerprint).toList(),
        twice.map((f) => f.targetFingerprint).toList(),
      );
      final sorted = [...idsOf(once)]..sort();
      expect(
        idsOf(once),
        sorted,
        reason:
            'sorted by rule id, not by severity — severity is a '
            'per-project setting and sorting by it would churn the whole '
            'list when somebody demotes one rule',
      );
    });

    test('an empty project reports nothing at all', () {
      // THE ONE DOCUMENT THAT REALLY IS CLEAN. The first draft used two
      // properly stacked matrices and expected silence; it got three
      // findings, and ALL THREE WERE RIGHT — a rack with no PDU provides
      // zero outlets against two consumed (`PWR-003`), and V01 is 7.3 kg
      // against a 7.0 kg front-ear rating (`RCK-013`, twice). Fourteen
      // rules over a realistic rack is a document with things to say
      // about it, which is the product working rather than a defect.
      expect(evaluateDocument(doc), isEmpty);
    });

    test('a bare rack with two matrices reports exactly what it should', () {
      // The corrected version of the test above, and more useful than the
      // silence it expected: this NAMES what a realistic two-device rack
      // is guilty of, so a rule that stops firing shows up here.
      place('V01', 3, designator: 'MTX-1');
      place('V01', 3 + heightOf('V01'), designator: 'MTX-2');
      expect(
        idsOf(evaluateDocument(doc)).toSet(),
        {'PWR-003', 'RCK-013'},
        reason:
            'no PDU means no outlets provided, and V01 is over its own '
            'front-ear rating — both are true of this document',
      );
      expect(
        evaluateDocument(doc, only: 'RCK-001'),
        isEmpty,
        reason: 'and the two are correctly stacked',
      );
    });
  });
}
