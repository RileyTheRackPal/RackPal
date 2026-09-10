// The DRC fixture format and its harness (`#299`, M5-G1, AC-051).
//
// ═══════════════════════════════════════════════════════════════════════
// FOUR EVALUATORS, NOT ONE, AND THAT IS THE WHOLE DESIGN PROBLEM
// ═══════════════════════════════════════════════════════════════════════
// `#299` asks for *"a document plus the expected finding set"*. For tier
// 3 that is literally what it is. The other tiers produce no findings:
//
//   * TIER 1 refuses a GESTURE, through TWO evaluators. `evaluateConnect`
//     returns `ConnectRefused` carrying a `ConnectRule` (TOP-001..005);
//     `evaluatePlacement` returns `PlacementRefused` carrying a
//     `PlacementRule` (PLC-001..003). Eight rules, split across two
//     functions, which is the easy thing to miss.
//   * TIER 2 springs a gesture back: `SpringBackChip`, `SpringBackRule`.
//   * TIER 3 describes a DOCUMENT: `evaluateDocument`, `List<Finding>`.
//
// A format built around one evaluator could express fourteen of the
// twenty-eight rules and would have looked complete doing it.
//
// ═══════════════════════════════════════════════════════════════════════
// SO EVERY TIER NORMALISES TO ONE QUESTION: WHICH RULE IDS FIRED?
// ═══════════════════════════════════════════════════════════════════════
// Every verdict carries its rule, and every rule enum carries its
// canonical id. A fixture runs its own case and reports [FixtureOutcome],
// after which both halves of AC-051 are one comparison:
//
//   * a KNOWN-BAD fires EXACTLY its own rule and nothing else;
//   * a NEAR-MISS fires that rule not at all.
//
// "And nothing else" is `#300` in its own words: *"a fixture that also
// trips two other rules is not evidence about this one."* Without it a
// known-bad passes while the rule under test does nothing, carried by a
// neighbour that happened to fire on the same document.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MESSAGES COME BACK TOO, BECAUSE A REFUSAL IS COPY
// ═══════════════════════════════════════════════════════════════════════
// `ConnectRefused` promises a complete sentence naming the real
// designators, and the connect corpus has asserted that from the day it
// was written. Returning only the fired ids would have thrown that away
// in the name of uniformity, so [FixtureOutcome] carries both and
// `mustName` survives absorption.
import 'package:rackpal_core/rackpal_core.dart';

/// Which half of AC-051's pair a fixture is.
enum FixtureKind {
  /// The state the rule exists to catch. Fires exactly its own rule.
  knownBad,

  /// One property away from [knownBad], and correct. Fires it not at all.
  ///
  /// THE HALF THAT GETS SKIPPED, and the half that matters: a known-bad
  /// alone proves a rule FIRES, never that it discriminates. M5-D's
  /// near-miss table found a real defect on the day it shipped, one rule
  /// along from the one it was written for.
  nearMiss,
}

/// What running a fixture produced.
///
/// ═══════════════════════════════════════════════════════════════════════
/// `loci` IS HERE BECAUSE THE GUARD THAT SHOULD HAVE CAUGHT IT COULD NOT
/// ═══════════════════════════════════════════════════════════════════════
/// `findings_view.dart` promised that a fifth `primaryEntityId` type
/// would be *"a test failure, not a blank cell"*. One arrived at
/// `PLAN-I/1` and nothing failed, because the guard asserted `locusLabel`
/// returns null for an id NO rule produces, which cannot see a type that
/// rules DO produce (DR-154 §11.153.8).
///
/// So every finding a fixture produces reports the label the issues panel
/// would print for it, and [violationOf] fails on a null. One entry per
/// finding that names a primary; a finding about a SET names none and
/// contributes nothing here, which is `kNoLocusGroup`'s legal case and
/// not a gap.
///
/// EMPTY FOR THE OTHER THREE TIERS, and that is a fact rather than a
/// stub: a refusal and a spring-back produce no `Finding` at all, so
/// there is no panel row to click.
typedef FixtureOutcome = ({
  Set<String> fired,
  List<String> messages,
  List<String?> loci,
});

/// An outcome in which nothing fired.
const FixtureOutcome kNothingFired = (
  fired: <String>{},
  messages: <String>[],
  loci: <String?>[],
);

/// One half of one rule's AC-051 pair.
final class DrcFixture {
  const DrcFixture({
    required this.ruleId,
    required this.kind,
    required this.what,
    required this.run,
    this.mustName = const <String>[],
  });

  /// The rule this fixture is evidence about. Joins to `kRulesById`.
  final String ruleId;

  final FixtureKind kind;

  /// One line for the failure message: what makes this document bad, or
  /// which single property pulls it back to good.
  ///
  /// REQUIRED, because a fixture that fails without saying what it meant
  /// to express sends the next reader to the git history.
  final String what;

  /// Builds the case, runs the right evaluator, and reports what fired.
  ///
  /// A FUNCTION, so every run gets a fresh document and no fixture can be
  /// mutated by another.
  final FixtureOutcome Function() run;

  /// Designators the refusal message must name, for the tiers whose
  /// verdicts carry copy. Empty where there is no message to check.
  final List<String> mustName;
}

/// [ConnectVerdict] as an outcome.
FixtureOutcome fromConnect(ConnectVerdict v) => v is ConnectRefused
    ? (fired: {v.rule.id}, messages: [v.message], loci: const <String?>[])
    : kNothingFired;

/// [PlacementVerdict] as an outcome.
FixtureOutcome fromPlacement(PlacementVerdict v) => v is PlacementRefused
    ? (fired: {v.rule.id}, messages: [v.message], loci: const <String?>[])
    : kNothingFired;

/// [SpringBackVerdict] as an outcome.
FixtureOutcome fromSpringBack(SpringBackVerdict v) => v is SpringBackChip
    ? (
        fired: {v.rule.id},
        messages: [v.headline, v.explanation],
        loci: const <String?>[],
      )
    : kNothingFired;

/// A whole document as an outcome, for the post-hoc rules.
FixtureOutcome fromDocument(RackDocument doc) =>
    outcomeOf(doc, evaluateDocument(doc));

/// [findings] over [doc] as an outcome.
///
/// Split out so the plan band can hand in the run that carries
/// `changedUnderlays`, WITHOUT a second copy of how a finding becomes a
/// locus: two spellings of that is how the corpus and the panel come to
/// disagree about the same row.
FixtureOutcome outcomeOf(RackDocument doc, List<Finding> findings) => (
  fired: {for (final f in findings) f.ruleId},
  messages: [for (final f in findings) f.message],
  loci: [
    for (final f in findings)
      if (f.primaryEntityId case final Uuid id) locusLabel(doc, id),
  ],
);

/// Why [fixture] fails its own contract, or null when it holds.
///
/// A STRING RATHER THAN A THROW, so the harness reports every broken
/// fixture in one run instead of stopping at the first. Twenty-eight
/// rules failing one at a time is twenty-eight runs.
String? violationOf(DrcFixture fixture) {
  final outcome = fixture.run();
  final fired = outcome.fired;
  // BOTH HALVES, BEFORE EITHER CONTRACT. A near-miss document still
  // produces findings from its neighbours, and a finding nobody can click
  // is broken whichever fixture happened to produce it.
  if (outcome.loci.contains(null)) {
    return '${fixture.ruleId} ${fixture.kind.name} (${fixture.what}) '
        'produced a finding whose primaryEntityId resolves to no locus, so '
        'the issues panel files it under "$kNoLocusGroup" and nobody can '
        'click it. locusLabel needs an arm for whatever it points at';
  }
  switch (fixture.kind) {
    case FixtureKind.knownBad:
      if (!fired.contains(fixture.ruleId)) {
        return '${fixture.ruleId} known-bad (${fixture.what}) did not fire '
            'it; fired: ${_show(fired)}';
      }
      final others = fired.difference({fixture.ruleId});
      if (others.isNotEmpty) {
        return '${fixture.ruleId} known-bad (${fixture.what}) also fired '
            '${_show(others)}, so it is not evidence about this rule';
      }
      for (final name in fixture.mustName) {
        if (!outcome.messages.any((m) => m.contains(name))) {
          return '${fixture.ruleId} known-bad (${fixture.what}) never named '
              '$name; said: ${outcome.messages.join(' | ')}';
        }
      }
      return null;
    case FixtureKind.nearMiss:
      if (fired.contains(fixture.ruleId)) {
        return '${fixture.ruleId} near-miss (${fixture.what}) fired it, so '
            'the rule does not discriminate here';
      }
      return null;
  }
}

String _show(Set<String> ids) {
  if (ids.isEmpty) return 'nothing';
  final sorted = ids.toList()..sort();
  return sorted.join(', ');
}
