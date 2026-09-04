// The six tier-2 rules (`#272`..`#277`, M5-D, docs/02 §5.2).
//
// ═══════════════════════════════════════════════════════════════════════
// BOTH TABLES, GATED, FROM THE FIRST COMMIT
// ═══════════════════════════════════════════════════════════════════════
// `connect_rules_test.dart` shipped a gated table of refusals and went
// four milestones before anything checked the other direction; M5-C added
// that half and mutation-tested it. This file starts with both, so a
// seventh rule cannot arrive with a known-bad and no near-miss, and so a
// rule written as `return chip` fails on sight.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/spring_back_scenarios.dart';

void main() {
  group('every rule springs back on its own known-bad', () {
    test('EVERY SpringBackRule has one in this file', () {
      expect(
        springBackChips().map((c) => c.rule).toSet(),
        SpringBackRule.values.toSet(),
        reason:
            'a tier-2 rule with no exercised chip is a spring-back whose '
            'sentence nobody has read. Add a row, do not relax this.',
      );
    });

    for (final c in springBackChips()) {
      test('${c.rule.id} springs back when ${c.what}', () {
        final verdict = springBackRun(c.doc());
        expect(verdict, isA<SpringBackChip>());
        final chip = verdict as SpringBackChip;
        expect(chip.rule, c.rule);
        expect(chip.ruleId, c.rule.id);
        // Both lines are a person's, not a log's: the headline names the
        // pins and the explanation says why it matters.
        expect(chip.headline, endsWith('.'));
        expect(chip.explanation, endsWith('.'));
        expect(chip.headline, isNot(contains(c.rule.id)));
      });
    }

    test('no two rules share a headline, so a person can tell which one '
        'fired', () {
      final seen = <String, SpringBackRule>{};
      for (final c in springBackChips()) {
        final chip = springBackRun(c.doc()) as SpringBackChip;
        expect(seen[chip.headline], isNull, reason: chip.headline);
        seen[chip.headline] = c.rule;
      }
      expect(seen, hasLength(SpringBackRule.values.length));
    });
  });

  group('and clears on the case one property away (AC-051)', () {
    test('EVERY SpringBackRule has a near-miss in this file', () {
      expect(
        springBackNearMisses().map((c) => c.rule).toSet(),
        SpringBackRule.values.toSet(),
        reason:
            'a rule with a known-bad and no near-miss is proven to FIRE '
            'and not proven to DISCRIMINATE',
      );
    });

    for (final c in springBackNearMisses()) {
      test('${c.rule.id} clears when ${c.what}', () {
        expect(
          springBackRun(c.doc()),
          isA<SpringBackClear>(),
          reason:
              '${c.rule.id} sprang back on a case one property from its '
              'own known-bad, so the rule is wider than the catalogue says',
        );
      });
    }

    test('the two tables stay the same size, so neither can grow alone', () {
      expect(springBackNearMisses(), hasLength(springBackChips().length));
    });
  });

  group('the chip carries what CR-017 says it must', () {
    test('SIG-001 offers the remedy that INSERTS A DEVICE (CR-015), and it '
        'is the only rule with one', () {
      for (final c in springBackChips()) {
        final chip = springBackRun(c.doc()) as SpringBackChip;
        if (c.rule == SpringBackRule.hdbasetIntoEthernet) {
          expect(chip.remedies, [SpringBackRemedy.insertHdbasetReceiver]);
        } else {
          expect(
            chip.remedies,
            isEmpty,
            reason:
                'docs/02 §5.2 names a remedy for SIG-001 and for no other '
                'rule; inventing one puts words in a designer mouth',
          );
        }
      }
    });

    test('[ Connect anyway ] is NOT a remedy value, so no chip can ship '
        'without it', () {
      // DR-011.5 gives tier 2 its escape hatch unconditionally. Making it
      // per-rule data is how a chip ends up without one.
      for (final remedy in SpringBackRemedy.values) {
        expect(remedy.label.toLowerCase(), isNot(contains('anyway')));
        expect(remedy.label.toLowerCase(), isNot(contains('why')));
        expect(remedy.label.toLowerCase(), isNot(contains('different port')));
      }
    });
  });

  group('the catalogue and the predicates agree', () {
    test('every SpringBackRule is a tier-2 catalogue rule with a severity', () {
      for (final rule in SpringBackRule.values) {
        final meta = kRulesById[rule.id];
        expect(meta, isNotNull, reason: rule.id);
        expect(meta!.tier, RuleTier.springBack, reason: rule.id);
        expect(meta.defaultSeverity, isNotNull, reason: rule.id);
      }
    });

    test('and every tier-2 rule in the catalogue has a predicate here, so '
        'the six are the six', () {
      expect(
        SpringBackRule.values.map((r) => r.id).toSet(),
        {for (final r in rulesInTier(RuleTier.springBack)) r.ruleId},
      );
    });
  });
}
