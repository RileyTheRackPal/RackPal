// M5-F3 — every rule can answer "why?", and answers in trade language.
//
// AC-058/D1 promised a `[ Why? ]` viewer over a `rationale` that did not
// exist: the type it names, `CompatibilityRuleDef`, is from
// `docs/research/design-data-model.md` and was never built. These tests
// hold the field that sentence assumed, and hold it to the standard
// M5-H1 sets for the same 28 rules: *"trade language, not model
// language"*.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  test('every rule in the catalogue carries a rationale', () {
    // REQUIRED ON THE CONSTRUCTOR, so this cannot fail by omission. It
    // can still fail by someone typing '' to get past the compiler.
    final empty = [
      for (final r in kRuleCatalogue)
        if (r.rationale.trim().isEmpty) r.ruleId,
    ];
    expect(empty, isEmpty);
    expect(kRuleCatalogue, hasLength(28));
  });

  test('a rationale is not the summary again', () {
    // The failure this guards is the cheap one: filling the field by
    // pasting what the rule already says. `summary` is what the
    // predicate TESTS; `rationale` is what goes wrong on the job.
    for (final r in kRuleCatalogue) {
      expect(
        r.rationale.trim(),
        isNot(r.summary.trim()),
        reason: '${r.ruleId} answers "why?" with its own summary',
      );
    }
  });

  test('no rationale reaches for a model identifier', () {
    // THE H1 CONTRACT, MADE CHECKABLE. An expert reviewing these should
    // not have to know the data model to say whether the reasoning is
    // right. Trade terms are welcome and several are load-bearing
    // (HDBaseT, eARC, PoE, NEC 725.136); what is banned is this
    // repository's own vocabulary.
    const modelWords = [
      'PortDef',
      'PortEndpoint',
      'InlineAdapter',
      'MediaTypeDef',
      'RailPlacement',
      'ZeroUPlacement',
      'PowerProfile',
      'Pathway.kind',
      'acceptedFamilies',
      'signalFamily',
      'maxConnections',
      'heightU',
      'hostDeviceId',
      'startTwelfth',
      'spanTwelfths',
      'ruIndex',
      'channelId',
      'weightCapacity',
      'poeBudgetWatts',
      'containsLineVoltage',
      'maxUnsupportedMass',
      'maxRunLengthPassive',
      'tombstoned',
      'passiveSplit',
      'returnChannel',
      'pinoutVariant',
      'Finding',
      'Severity',
      'RuleMeta',
    ];
    final offenders = <String>[];
    for (final r in kRuleCatalogue) {
      for (final w in modelWords) {
        if (r.rationale.contains(w)) offenders.add('${r.ruleId}: $w');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the ban list is not vacuous: the summaries DO use those words', () {
    // A ban list that named words nobody writes would pass forever. The
    // summaries are the same 28 rules in model language, so if the list
    // is real it must catch them there.
    const modelWords = [
      'acceptedFamilies',
      'maxConnections',
      'heightU',
      'hostDeviceId',
      'startTwelfth',
      'ruIndex',
      'MediaTypeDef',
    ];
    final caught = <String>[];
    for (final r in kRuleCatalogue) {
      for (final w in modelWords) {
        if (r.summary.contains(w)) caught.add(w);
      }
    }
    expect(
      caught.toSet(),
      hasLength(modelWords.length),
      reason: 'every banned word should appear in some summary',
    );
  });

  test('a rationale is a sentence, not a fragment', () {
    for (final r in kRuleCatalogue) {
      expect(
        r.rationale.trim(),
        endsWith('.'),
        reason: '${r.ruleId} does not end in a full stop',
      );
      // Long enough to be an explanation. The shortest useful one here
      // is two clauses; a handful of words would be the summary again
      // under another name.
      expect(
        r.rationale.length,
        greaterThan(60),
        reason: '${r.ruleId} is too short to explain anything',
      );
    }
  });

  test('the flagship rule explains the damage, not the condition', () {
    // SIG-001 is the rule this product exists for, so its rationale is
    // pinned rather than left to a length check: a person reading it
    // must learn that the switch can be destroyed.
    final sig = kRulesById['SIG-001']!;
    expect(sig.rationale, contains('destroy'));
    expect(sig.rationale, contains('switch'));
  });

  test('the two code rules keep DR-079 verify-do-not-assert framing', () {
    // DR-079 demoted these to warnings that ask a person to check a named
    // article. A rationale that asserted a violation would put the
    // product back in the position that ruling took it out of.
    for (final id in ['CODE-001', 'CODE-002']) {
      final r = kRulesById[id]!;
      expect(
        r.rationale.toLowerCase(),
        isNot(contains('violation')),
        reason: '$id must not assert a code violation',
      );
    }
    expect(kRulesById['CODE-001']!.rationale, contains('725.136'));
  });

  test('PWR-001 says it is an estimate, because AC-039 and DR-079 do', () {
    final r = kRulesById['PWR-001']!.rationale;
    expect(r.toLowerCase(), contains('estimate'));
    expect(r.toLowerCase(), contains('not a compliance check'));
  });
}
