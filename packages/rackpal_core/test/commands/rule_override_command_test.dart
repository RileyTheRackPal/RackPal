// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// Writing a rule override (`#260`, M5-B3, CR-019).
//
// ═══════════════════════════════════════════════════════════════════════
// CLEARING IS NOT THE SAME AS SETTING THE DEFAULT
// ═══════════════════════════════════════════════════════════════════════
// `projectSeverity` falls back to the catalogue when there is no entry,
// so an override that happens to equal the default resolves identically
// and is a DIFFERENT state: it carries a sentence, an author and a date
// that print on `T0.02`. A surface that collapsed the two would delete
// the record of a decision while showing the same severity, which is the
// same trap `SetFamilyColorOverrideCommand` names for colours.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 2, 13);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-rule-override'),
  appVersion: '0.5.13',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

RuleOverride _override({
  Severity severity = Severity.error,
  String reason = 'The client has accepted this risk in writing.',
}) => RuleOverride(
  severity: severity,
  reason: reason,
  by: 'R. Riley',
  at: _now,
);

void main() {
  group('setting one', () {
    test('writes the severity, the reason, the author and the date, '
        'which is the whole of what replaced the bare severity map', () {
      final doc = _doc();
      SetRuleOverrideCommand(
        ruleId: 'PWR-001',
        from: null,
        to: _override(),
      ).apply(doc);

      final written = doc.settings.ruleOverrides['PWR-001']!;
      expect(written.severity, Severity.error);
      expect(written.reason, 'The client has accepted this risk in writing.');
      expect(written.by, 'R. Riley');
      expect(written.at, _now);
      expect(projectSeverity('PWR-001', doc.settings), Severity.error);
    });

    test('and leaves every other rule where the catalogue put it', () {
      final doc = _doc();
      SetRuleOverrideCommand(
        ruleId: 'PWR-001',
        from: null,
        to: _override(),
      ).apply(doc);
      expect(projectSeverity('RCK-003', doc.settings), Severity.warning);
      expect(doc.settings.ruleOverrides.keys, ['PWR-001']);
    });

    test('apply, revert, apply lands on identical bytes (CR-117)', () {
      final doc = _doc();
      final before = _codec.write(doc);
      final cmd = SetRuleOverrideCommand(
        ruleId: 'PWR-001',
        from: null,
        to: _override(),
      );
      cmd.apply(doc);
      final applied = _codec.write(doc);
      cmd.revert(doc);
      expect(_codec.write(doc), before);
      cmd.apply(doc);
      expect(_codec.write(doc), applied);
    });
  });

  group('clearing one', () {
    test('returns the rule to the catalogue, and the record of the '
        'decision goes with it rather than lingering', () {
      final doc = _doc();
      final existing = _override();
      doc.settings.ruleOverrides['PWR-001'] = existing;

      SetRuleOverrideCommand(
        ruleId: 'PWR-001',
        from: existing,
        to: null,
      ).apply(doc);
      expect(doc.settings.ruleOverrides, isEmpty);
      expect(projectSeverity('PWR-001', doc.settings), Severity.warning);
    });

    test('and clearing needs no reason of its own, because taking an '
        'exception back is not itself an exception', () {
      expect(
        () => SetRuleOverrideCommand(ruleId: 'PWR-001', from: null, to: null),
        returnsNormally,
      );
    });
  });

  group('the writer refuses what the rules refuse', () {
    test('an override with an empty reason cannot be built, unlike a '
        'single-instance acknowledgement (RJ-006)', () {
      expect(
        () => SetRuleOverrideCommand(
          ruleId: 'PWR-001',
          from: null,
          to: _override(reason: '   '),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('and no tier-1 rule can be overridden at all', () {
      expect(
        () => SetRuleOverrideCommand(
          ruleId: 'TOP-001',
          from: null,
          to: _override(),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        evaluateRuleOverride(ruleId: 'TOP-001', reason: 'Anything.'),
        isA<RuleExceptionRefused>(),
      );
    });

    test('while an override on any rule that files a finding stands', () {
      for (final rule in kRuleCatalogue) {
        if (rule.tier == RuleTier.modelIllegal) continue;
        expect(
          evaluateRuleOverride(
            ruleId: rule.ruleId,
            reason: 'Surveyed as found.',
          ),
          isA<RuleExceptionAllowed>(),
          reason: rule.ruleId,
        );
      }
    });
  });

  group('`#879`: which rules may carry a standing decision', () {
    test('every tier-1 rule is excluded, and the list reads ALL of them', () {
      // THIS EXISTS BECAUSE A UI TEST COULD NOT SAY IT. The project
      // settings picker filtered tier 1 out inside the widget, and a
      // mutation that removed the filter SURVIVED: that list is
      // virtualised, so a tier-1 row below the fold is never built and
      // `findsNothing` passes whether it was excluded or merely out of
      // sight. The filter moved to `overridableRules` so this test can
      // read every rule in the catalogue.
      final offered = overridableRules().map((r) => r.ruleId).toSet();
      final tierOne = kRulesById.values
          .where((r) => r.tier == RuleTier.modelIllegal)
          .map((r) => r.ruleId)
          .toSet();

      expect(tierOne, isNotEmpty, reason: 'the catalogue has tier-1 rules');
      expect(
        offered.intersection(tierOne),
        isEmpty,
        reason:
            'a tier-1 rule refuses the edit outright and files no finding, '
            'so an override of one would sit in the file forever matching '
            'nothing, which is a person believing they decided something',
      );
    });

    test('and every rule that is NOT tier 1 IS offered', () {
      // The other direction, which an exclusion check alone cannot see: a
      // filter that returned the empty list would pass the test above.
      final offered = overridableRules().map((r) => r.ruleId).toSet();
      final expected = kRulesById.values
          .where((r) => r.tier != RuleTier.modelIllegal)
          .map((r) => r.ruleId)
          .toSet();
      expect(offered, expected);
      expect(offered.length, greaterThan(10));
    });

    test('the order is total, so two runs agree', () {
      final ids = overridableRules().map((r) => r.ruleId).toList();
      expect(ids, orderedEquals([...ids]..sort()));
      expect(overridableRules().map((r) => r.ruleId).toList(), ids);
    });
  });
}
