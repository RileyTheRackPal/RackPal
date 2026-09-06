// `ELE-005`, the rule AC-040 cut and DR-132 §11.131 restored (`#838`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE AC-051 PAIR PROVES IT FIRES. THIS PROVES IT COUNTS HONESTLY
// ═══════════════════════════════════════════════════════════════════════
// DR-125 §11.124.5's limit applies here as everywhere: *"a pair proves a
// rule fires, not that it fires correctly."* What a load rule can get
// wrong and still pass its pair is the ARITHMETIC around absences, and
// CR-114 is unusually specific about it: a speaker whose tap nobody
// recorded still draws from the amplifier, so it is neither zero nor a
// guess.
import 'package:rackpal_core/rackpal_core.dart';
// DIRECTLY, because no rules_*.dart is in the barrel: the predicates are
// reached through evaluateDocument and only the threshold is asserted
// here, so exporting the file to read one constant would widen the
// public surface for a test's convenience.
import 'package:rackpal_core/src/validation/rules_audio.dart'
    show kTapBudgetPermille;
import 'package:test/test.dart';

import 'fixtures/tier3_scenarios.dart';

List<Finding> _ele005(RackDocument doc) =>
    evaluateDocument(doc).where((f) => f.ruleId == 'ELE-005').toList();

void main() {
  group('the budget is 80% and it is named once', () {
    test('a line exactly at the budget does not fire', () {
      // 60+60+60+20 = 200, and 250 * 800 / 1000 = 200. The boundary is
      // asserted because `<=` written as `<` passes every other test
      // here.
      expect(
        _ele005(cvLineFixture(rating: 250, taps: [60, 60, 60, 20])),
        isEmpty,
      );
    });

    test('and one watt over it does', () {
      expect(
        _ele005(cvLineFixture(rating: 250, taps: [60, 60, 60, 21])),
        hasLength(1),
      );
    });

    test('the threshold is kTapBudgetPermille, not a literal', () {
      // A second copy of a moving number is a liability. If somebody
      // changes the constant, this fails rather than the rule quietly
      // meaning something else than the catalogue says.
      expect(kTapBudgetPermille, 800);
    });
  });

  group('an unrecorded tap is counted and named, never estimated (G4)', () {
    test('a blank tap does NOT push a compliant line over', () {
      // The conservative direction is not "assume the worst": inventing a
      // wattage would be fabricating a measurement, which is the thing
      // CR-114 forbids in the same breath as estimating an unknown.
      expect(
        _ele005(cvLineFixture(rating: 250, taps: [60, 60], unrecorded: 4)),
        isEmpty,
        reason:
            'six speakers on a 200 W budget is probably over, and this '
            'rule does not know that, so it must not claim to',
      );
    });

    test('but when the KNOWN taps alone are over, the message says how '
        'many it could not count', () {
      final findings = _ele005(
        cvLineFixture(rating: 250, taps: [60, 60, 60, 60], unrecorded: 2),
      );
      expect(findings, hasLength(1));
      final message = findings.single.message;
      expect(message, contains('240 W'));
      expect(
        message,
        contains('no tap recorded'),
        reason:
            'a total presented without its unknown count reads as a '
            'measurement, and this one is a floor',
      );
      expect(message, contains('2 speakers'));
    });

    test('and a fully recorded line says nothing about unknowns', () {
      final findings = _ele005(
        cvLineFixture(rating: 250, taps: [60, 60, 60, 60]),
      );
      expect(findings.single.message, isNot(contains('no tap recorded')));
    });
  });

  group('what it deliberately stays silent about', () {
    test('a line whose amplifier states no rating is UNEVALUATABLE', () {
      // Not a pass. There is no rating to be over, and deriving one from
      // the amplifier's model string would be exactly the fabrication
      // CR-114 forbids. G4: silence, and the rollup counts it elsewhere.
      expect(
        _ele005(cvLineFixture(rating: null, taps: [60, 60, 60, 60])),
        isEmpty,
      );
    });

    test('a BYPASSED speaker is not on the line at all (DR-131)', () {
      // Its transformer is out of circuit, so it draws nothing from the
      // 70 V bus. Charging the amplifier for it would report an overload
      // that physically is not there.
      expect(
        _ele005(
          cvLineFixture(rating: 250, taps: [60, 60, 60, 60], bypassLast: true),
        ),
        isEmpty,
        reason: '180 W of live taps against a 200 W budget',
      );
    });

    test('and the same document WITHOUT the bypass fires, so the test '
        'above is not vacuous', () {
      expect(
        _ele005(cvLineFixture(rating: 250, taps: [60, 60, 60, 60])),
        hasLength(1),
      );
    });
  });
}
