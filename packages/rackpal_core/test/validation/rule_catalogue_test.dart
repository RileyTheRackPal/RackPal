// The catalogue is data, and docs/02 §5 is what it must equal (`#254`,
// `#256`, M5-A).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST TEST PARSES THE CORPUS, AND THAT IS THE POINT OF THE FILE
// ═══════════════════════════════════════════════════════════════════════
// CR-021: *"a rule not listed there does not exist"*, where "there" is
// docs/02 §5 and the `docs/rules.md` the corpus refers to is deliberately
// never created. A hand-maintained Dart list beside a hand-maintained
// markdown table is two copies of one fact, and this repository has
// written down what that costs more than once. So the test reads the
// tables and compares, tier by tier: a row added to one and not the other
// fails, in either direction.
//
// THE COUNT IS THE SCOPE GATE, not bookkeeping. Roadmap M5's own risk
// list names *"just one more obvious rule"* without its AC-051 fixture
// pair as the mechanism by which this milestone overruns. A test that
// fails when the registry size changes makes every addition deliberate.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// docs/02, read from the PACKAGE directory.
///
/// `run_suite.ps1` runs each suite with its package as the working
/// directory and CLAUDE.md says so in terms, because several tests here
/// read files relative to CWD and fail spuriously otherwise.
const String _docPath = '../../docs/02-data-model.md';

/// The rule ids docs/02 §5 lists, by the section heading they sit under.
///
/// PARSED, NOT TRANSCRIBED. A second transcription would have the same
/// failure mode as the thing it is checking.
Map<String, List<String>> _catalogueFromDocs() {
  final file = File(_docPath);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'docs/02 is missing at $_docPath. Suites run from the package '
        'directory; from the repo root this path is wrong and the test '
        'would fail for the wrong reason',
  );

  final out = <String, List<String>>{'5.1': [], '5.2': [], '5.3': []};
  // `| `TOP-001` | …` and nothing else. The header and separator rows do
  // not start with a backticked id, and neither does prose.
  final row = RegExp(r'^\|\s*`([A-Z]{2,4}-\d{3})`\s*\|');
  final heading = RegExp(r'^###\s+(5\.\d)\s');

  String? section;
  for (final line in file.readAsLinesSync()) {
    final head = heading.firstMatch(line);
    if (head != null) {
      section = head.group(1);
      continue;
    }
    if (section == null || !out.containsKey(section)) continue;
    final match = row.firstMatch(line);
    if (match != null) out[section]!.add(match.group(1)!);
  }
  return out;
}

void main() {
  group('the catalogue equals docs/02 §5 (CR-021)', () {
    late Map<String, List<String>> fromDocs;

    setUpAll(() {
      fromDocs = _catalogueFromDocs();
    });

    test('the parser found the three tables at all, so a later comparison '
        'of two empty lists cannot pass', () {
      expect(fromDocs['5.1'], isNotEmpty, reason: '§5.1 parsed as empty');
      expect(fromDocs['5.2'], isNotEmpty, reason: '§5.2 parsed as empty');
      expect(fromDocs['5.3'], isNotEmpty, reason: '§5.3 parsed as empty');
    });

    test('tier 1 is exactly §5.1', () {
      expect(
        rulesInTier(RuleTier.modelIllegal).map((r) => r.ruleId).toList(),
        fromDocs['5.1'],
        reason:
            'the tier-1 rows and docs/02 §5.1 disagree. The catalogue is '
            'the document; this file is a copy of it and must not drift',
      );
    });

    test('tier 2 is exactly §5.2', () {
      expect(
        rulesInTier(RuleTier.springBack).map((r) => r.ruleId).toList(),
        fromDocs['5.2'],
      );
    });

    test('tier 3 is exactly §5.3', () {
      expect(
        rulesInTier(RuleTier.postHoc).map((r) => r.ruleId).toList(),
        fromDocs['5.3'],
      );
    });
  });

  group('the count is the scope gate', () {
    test('28 rules: 8 tier-1, 6 tier-2, 14 tier-3', () {
      // The arithmetic written out, because AC-040's own "22" is an error
      // against its enumeration of 24 and canon §12.6(b)'s "27" predates
      // DR-020 adding `LEN-002`. A number this corpus has got wrong twice
      // is a number worth deriving rather than trusting.
      expect(rulesInTier(RuleTier.modelIllegal), hasLength(8));
      expect(rulesInTier(RuleTier.springBack), hasLength(6));
      expect(rulesInTier(RuleTier.postHoc), hasLength(14));
      expect(kRuleCatalogue, hasLength(28));
    });

    test('no two rules share an id, which is the join Finding, '
        'RuleOverride and AckedFinding all use', () {
      final ids = kRuleCatalogue.map((r) => r.ruleId).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(kRulesById, hasLength(28));
    });

    test('every rule cites at least one ruling (§8.2)', () {
      for (final rule in kRuleCatalogue) {
        expect(rule.governing, isNotEmpty, reason: rule.ruleId);
        for (final id in rule.governing) {
          expect(
            RegExp(r'^(CR|AC|RJ|DR)-\d{3}$').hasMatch(id),
            isTrue,
            reason: '${rule.ruleId} cites "$id", which is not a ruling id',
          );
        }
      }
    });

    test('every rule carries a summary', () {
      for (final rule in kRuleCatalogue) {
        expect(rule.summary.trim(), isNotEmpty, reason: rule.ruleId);
        expect(rule.summary.trim(), endsWith('.'), reason: rule.ruleId);
      }
    });
  });

  group('severity belongs to the tier', () {
    test('a tier-1 rule has NO default severity, because it files no '
        'finding to carry one', () {
      for (final rule in rulesInTier(RuleTier.modelIllegal)) {
        expect(
          rule.defaultSeverity,
          isNull,
          reason:
              '${rule.ruleId} is T1 and refuses the command. A severity '
              'here would describe a finding that is never filed',
        );
      }
    });

    test('every tier-2 and tier-3 rule has one, since both file findings', () {
      for (final rule in [
        ...rulesInTier(RuleTier.springBack),
        ...rulesInTier(RuleTier.postHoc),
      ]) {
        expect(rule.defaultSeverity, isNotNull, reason: rule.ruleId);
      }
    });

    test('no rule ships defaulted to off, which would be a rule that does '
        'not run wearing a severity', () {
      for (final rule in kRuleCatalogue) {
        expect(rule.defaultSeverity, isNot(Severity.off), reason: rule.ruleId);
      }
    });
  });

  group('the tier-1 rules agree with their implementations', () {
    // `derived/connect_rules.dart` shipped `TOP-001`..`TOP-005` before
    // this catalogue existed, with an evaluation order its enum encodes.
    // M5-A does not rewrite it: the rows point at it and this test is
    // what stops the two drifting.
    test('every ConnectRule id is a catalogue rule, and a tier-1 one', () {
      for (final rule in ConnectRule.values) {
        final meta = kRulesById[rule.id];
        expect(
          meta,
          isNotNull,
          reason:
              '${rule.id} is evaluated by evaluateConnect and is not in '
              'the catalogue, so it is a rule that does not exist (CR-021)',
        );
        expect(meta!.tier, RuleTier.modelIllegal, reason: rule.id);
      }
    });

    test('EVERY tier-1 rule has a predicate now, across both evaluators', () {
      // ═══════════════════════════════════════════════════════════════
      // THIS TEST REPLACED ITS OWN PREDECESSOR, ON THAT ONE'S ORDERS
      // ═══════════════════════════════════════════════════════════════
      // It used to assert the unbuilt set was EXACTLY `PLC-001..003`, a
      // census at the start of M5 rather than an assumption: the string
      // `PLC-00` appeared in no Dart file and there was no
      // placement-validity helper anywhere. Its own `reason` said what to
      // do next: *"if PLC-001..003 now have one, delete this test and
      // assert the placement command set enforces them"*. M5-C built
      // them, so this is that replacement.
      //
      // NOTE WHAT THE OLD ONE COULD NOT DO. It derived "built" from
      // `ConnectRule.values` alone, so it would have kept passing,
      // unchanged and quietly wrong, after `PlacementRule` shipped. A
      // census test that cannot see the thing it is counting is a
      // comment with an `expect` around it. This one fails the moment a
      // tier-1 rule joins the catalogue without a predicate, whichever
      // evaluator that predicate would belong to.
      final built = <String>{
        for (final rule in ConnectRule.values) rule.id,
        for (final rule in PlacementRule.values) rule.id,
      };
      final unbuilt = [
        for (final rule in rulesInTier(RuleTier.modelIllegal))
          if (!built.contains(rule.ruleId)) rule.ruleId,
      ];
      expect(
        unbuilt,
        isEmpty,
        reason:
            'these tier-1 rules are in the catalogue with no predicate in '
            'either evaluator. A rule that refuses nothing refuses '
            'nothing silently',
      );
    });
  });
}
