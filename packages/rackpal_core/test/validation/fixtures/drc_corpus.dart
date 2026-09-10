// The one DRC fixture corpus (`#299`-`#302`, M5-G).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THERE IS ONE OF THESE AND NOT FOUR
// ═══════════════════════════════════════════════════════════════════════
// Before M5-G each evaluator's tests carried their own AC-051 pairs and
// their own coverage assertion, driven off their own enum:
// `ConnectRule.values`, `SpringBackRule.values`. Both were good and both
// were green, and TOGETHER THEY STILL COULD NOT ENFORCE `#302`.
//
// The reason is CR-021. The catalogue is what decides a rule exists, and
// it is the UNION of four evaluators' rules. Three coverage tests, each
// complete over its own enum, all pass while a catalogue row has no pair
// at all: no enum mentions it, so no test is looking for it. The gate
// `#302` asks for has to have the CATALOGUE as its subject.
//
// So the pairs live here, and the tests that always asserted over them
// still do. The data moved; the assertions did not.
import 'package:rackpal_core/rackpal_core.dart';

import 'connect_scenarios.dart';
import 'drc_fixture.dart';
import 'placement_scenarios.dart';
import 'plan_scenarios.dart';
import 'spring_back_scenarios.dart';
import 'tier3_scenarios.dart';

/// The tier-1 connect pairs (TOP-001..005), adapted from the tables
/// `connect_rules_test.dart` has carried since it was written.
List<DrcFixture> connectFixtures() => [
  for (final r in connectRefusals())
    DrcFixture(
      ruleId: r.rule.id,
      kind: FixtureKind.knownBad,
      what: r.what,
      run: () => fromConnect(r.run()),
      mustName: r.mustName,
    ),
  for (final n in connectNearMisses())
    DrcFixture(
      ruleId: n.rule.id,
      kind: FixtureKind.nearMiss,
      what: n.what,
      run: () => fromConnect(n.run()),
    ),
];

/// The tier-2 spring-back pairs.
List<DrcFixture> springBackFixtures() => [
  for (final c in springBackChips())
    DrcFixture(
      ruleId: c.rule.id,
      kind: FixtureKind.knownBad,
      what: c.what,
      run: () => fromSpringBack(springBackRun(c.doc())),
    ),
  for (final c in springBackNearMisses())
    DrcFixture(
      ruleId: c.rule.id,
      kind: FixtureKind.nearMiss,
      what: c.what,
      run: () => fromSpringBack(springBackRun(c.doc())),
    ),
];

/// Every fixture the project has, across all four evaluators.
List<DrcFixture> drcCorpus() => [
  ...connectFixtures(),
  ...placementFixtures(),
  ...springBackFixtures(),
  ...tier3Fixtures(),
  ...planFixtures(),
];

/// The corpus indexed by rule, for the coverage gate.
Map<String, Set<FixtureKind>> corpusCoverage() {
  final out = <String, Set<FixtureKind>>{};
  for (final f in drcCorpus()) {
    (out[f.ruleId] ??= <FixtureKind>{}).add(f.kind);
  }
  return out;
}

/// Rules missing one or both halves of their AC-051 pair.
///
/// THE SUBJECT IS `kRuleCatalogue`, not an enum. See this file's header.
///
/// **AND SINCE DR-154 §11.153.4 IT IS BOTH BANDS**, because AC-051 is
/// written about rules rather than about a catalogue: *"No rule ships
/// without its pair."* A plan advisory shipped without one would not
/// become acceptable by being filed under a different heading, and
/// `corpusGapsIn` is what lets the report still name which band a gap is
/// in.
Map<String, List<FixtureKind>> corpusGaps() => <String, List<FixtureKind>>{
  ...corpusGapsIn(kRuleCatalogue),
  ...corpusGapsIn(kPlanRules),
};

/// The gaps in one band, so a failure says which catalogue it is about.
Map<String, List<FixtureKind>> corpusGapsIn(List<RuleMeta> band) {
  final have = corpusCoverage();
  final gaps = <String, List<FixtureKind>>{};
  for (final rule in band) {
    final got = have[rule.ruleId] ?? const <FixtureKind>{};
    final missing = [
      for (final k in FixtureKind.values)
        if (!got.contains(k)) k,
    ];
    if (missing.isNotEmpty) gaps[rule.ruleId] = missing;
  }
  return gaps;
}
