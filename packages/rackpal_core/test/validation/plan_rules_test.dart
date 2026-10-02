// PLAN-I/1: the plan advisories, and the band they must not join
// (docs/15 §9, DR-154 §11.153).
//
// ═══════════════════════════════════════════════════════════════════════
// THE BAND IS BOUND TO ITS OWN TABLE, PARSED RATHER THAN TRANSCRIBED
// ═══════════════════════════════════════════════════════════════════════
// `rule_catalogue_test.dart` parses docs/02 §5 and compares ids with
// `kRuleCatalogue`, because *"a second transcription would have the same
// failure mode as the thing it is checking"*. docs/15 §9 is this band's
// normative table and gets the same treatment.
//
// ═══════════════════════════════════════════════════════════════════════
// AND EACH RULE'S COUNT IS ASSERTED IN THE SENTENCE, NOT IN A FIELD
// ═══════════════════════════════════════════════════════════════════════
// `#645`: *"A rule that fires without saying how much is the G4 failure
// in a findings list."* A `Finding` has no count field, so the number is
// in the words a person reads, and that is where it is checked.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/plan_scenarios.dart';

/// docs/15, from the package directory suites run in.
const String _docPath = '../../docs/15-plan-view.md';

/// The ids docs/15 §9's table lists, parsed.
List<String> _bandFromDocs() {
  final file = File(_docPath);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'docs/15 is missing at $_docPath. Suites run from the package '
        'directory; from the repo root this path is wrong and the test '
        'would fail for the wrong reason',
  );
  final row = RegExp(r'^\|\s*`(PLN-\d{3})`\s*\|');
  return [
    for (final line in file.readAsLinesSync())
      if (row.firstMatch(line) case final RegExpMatch m) m.group(1)!,
  ];
}

/// Every finding one document produces, keyed by rule.
Map<String, Finding> _byRule(RackDocument doc, {Set<Uuid> changed = const {}}) {
  final out = <String, Finding>{};
  for (final f in evaluateDocument(doc, changedUnderlays: changed)) {
    out[f.ruleId] = f;
  }
  return out;
}

void main() {
  group('the band equals docs/15 §9 (CR-021)', () {
    test('the parser found the table at all, so comparing two empty lists '
        'cannot pass', () {
      expect(_bandFromDocs(), isNotEmpty);
    });

    test('every row is a rule and every rule is a row', () {
      expect(kPlanRules.map((r) => r.ruleId).toList(), _bandFromDocs());
    });

    /// The whole point of a second list (DR-154 §11.153.2).
    test('and none of them is in the v1 catalogue', () {
      final drc = kRuleCatalogue.map((r) => r.ruleId).toSet();
      for (final rule in kPlanRules) {
        expect(drc, isNot(contains(rule.ruleId)), reason: rule.ruleId);
      }
      expect(kRuleCatalogue, hasLength(30));
    });

    test('every rule cites a ruling and explains itself (§8.2)', () {
      for (final rule in kPlanRules) {
        expect(rule.governing, isNotEmpty, reason: rule.ruleId);
        expect(rule.rationale, isNotEmpty, reason: rule.ruleId);
        for (final id in rule.governing) {
          expect(
            RegExp(r'^(CR|AC|RJ|DR)-\d{3}$').hasMatch(id),
            isTrue,
            reason: '${rule.ruleId} cites "$id", which is not a ruling id',
          );
        }
      }
    });

    /// DR-154 §11.153.5. The one rule that is not an advisory.
    test('PLN-004 is a warning and the other three are advisories', () {
      expect(kRulesById['PLN-004']!.defaultSeverity, Severity.warning);
      for (final id in const ['PLN-001', 'PLN-002', 'PLN-003']) {
        expect(kRulesById[id]!.defaultSeverity, Severity.advisory, reason: id);
      }
    });
  });

  group('each rule states its count (G4)', () {
    test('PLN-001 reports how many pins are stranded, in PLAN-F/3’s own '
        'words', () {
      final f = _byRule(planDoc(pinRack: true, pinOutlet: true))['PLN-001']!;

      expect(f.message, contains('Level 1'));
      expect(
        f.message,
        contains('1 pin carries no measurable position'),
        reason: 'the sentence is unmeasurablePinsSentence, not a second one',
      );
      expect(f.severity, Severity.advisory);
    });

    test('PLN-002 counts the drops that are not on the plan', () {
      final f = _byRule(
        planDoc(pinRack: true, scale: kUsableScale),
      )['PLN-002']!;

      expect(f.message, contains('1 device on Level 1 is not on the plan'));
    });

    test('PLN-003 counts the pinned drops it cannot measure', () {
      final f = _byRule(
        planDoc(pinOutlet: true, rackElsewhere: true, scale: kUsableScale),
      )['PLN-003']!;

      expect(f.message, contains('1 pinned drop and no pinned rack'));
    });

    test('PLN-004 names the plan and says what it means', () {
      final doc = planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale);
      final f = _byRule(
        doc,
        changed: {doc.underlays.keys.first},
      )['PLN-004']!;

      expect(f.message, contains('Level 1'));
      expect(f.message, contains('changed since it was imported'));
      expect(f.severity, Severity.warning);
    });

    /// THE PLURAL IS HAND-WRITTEN EVERYWHERE IN THIS CORPUS, because
    /// `1 pins` is the `0 pathways` status bar this repository has
    /// already shipped once.
    test('two of anything reads as two', () {
      final doc = planDoc(pinRack: true, scale: kUsableScale);
      final second = Outlet(
        id: const Uuid('0190e0dd-0f00-7000-8000-0000000000fe'),
        structureBodyId: const Uuid('0190e0dd-0f00-7000-8000-00000000005a'),
        designation: 'WP-2',
        order: const FracIndex('a1'),
        meta: doc.underlays.values.first.meta,
        locationId: doc.locations.values
            .firstWhere((l) => l.kind == LocationKind.room)
            .id,
      );
      doc.outlets[second.id] = second;

      expect(
        _byRule(doc)['PLN-002']!.message,
        contains('2 devices on Level 1 are not on the plan'),
      );
    });
  });

  group('what each rule does NOT fire on', () {
    test('an uncalibrated plan with nothing pinned to it strands nobody', () {
      // A finding here would be an advisory to do work nothing is
      // waiting for.
      expect(_byRule(planDoc(pinRack: true)), isNot(contains('PLN-001')));
    });

    test('PLN-003 is silent when the rack is pinned, calibrated or not', () {
      expect(
        _byRule(planDoc(pinRack: true, pinOutlet: true)),
        isNot(contains('PLN-003')),
      );
    });

    /// LOAD-BEARING (DR-154 §11.153.7a). The room is a CHILD of the
    /// floor the plan depicts, which is how the trade files a job. Before
    /// this ruling the scope compared locations for equality, so this
    /// outlet was in no count at all.
    test('PLN-002 sees an outlet in a room UNDER the plan’s floor', () {
      final findings = _byRule(planDoc(pinRack: true, scale: kUsableScale));

      expect(findings, contains('PLN-002'));
      expect(
        findings['PLN-002']!.message,
        contains('1 device'),
        reason:
            'an exact-match scope would have counted zero and said '
            'nothing at all',
      );
    });

    test('an empty set of changed underlays fires no PLN-004', () {
      // And it means "nobody checked" as much as "nothing changed", which
      // is why the app supplies it and `evaluateDocument` documents it.
      expect(
        _byRule(planDoc(pinRack: true, pinOutlet: true, scale: kUsableScale)),
        isNot(contains('PLN-004')),
      );
    });
  });

  group('the band goes through the same machinery (DR-154 §11.153.3)', () {
    test('a project override demotes a plan advisory like any other rule', () {
      final doc = planDoc(pinRack: true, pinOutlet: true);
      doc.settings.ruleOverrides['PLN-001'] = RuleOverride(
        severity: Severity.off,
        reason: 'this job is a locate-only drawing',
        by: 'tester',
        at: DateTime.utc(2026, 9, 10),
      );

      expect(
        evaluateDocument(doc).map((f) => f.ruleId),
        isNot(contains('PLN-001')),
        reason: 'off is honoured in one place, for every band',
      );
    });

    test('and a demotion resolves rather than being ignored', () {
      final doc = planDoc(pinRack: true, pinOutlet: true);
      doc.settings.ruleOverrides['PLN-001'] = RuleOverride(
        severity: Severity.warning,
        reason: 'this client wants every plan calibrated',
        by: 'tester',
        at: DateTime.utc(2026, 9, 10),
      );

      expect(_byRule(doc)['PLN-001']!.severity, Severity.warning);
    });

    test('the order is deterministic, which the issues list depends on', () {
      final doc = planDoc(pinOutlet: true, rackElsewhere: true);
      final first = evaluateDocument(doc).map((f) => f.ruleId).toList();
      final second = evaluateDocument(doc).map((f) => f.ruleId).toList();

      expect(first, orderedEquals(second));
      expect(first, orderedEquals(List<String>.from(first)..sort()));
    });
  });
}
