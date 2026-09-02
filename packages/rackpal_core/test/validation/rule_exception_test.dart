// One dismissal mechanism, two scopes (`#259`, M5-B2, CR-019, RJ-006).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SEAM RJ-006 CUT, AND THE ONE BUG THAT WOULD UNDO CR-019 ENTIRELY
// ═══════════════════════════════════════════════════════════════════════
// RJ-006 answers the "type an essay to dismiss a yellow triangle"
// objection by requiring a reason only where the consequence is
// permanent. Most of this file is that seam from both sides.
//
// The bug worth naming is the wildcard. `"*"` is a project-wide mute OF
// THAT RULE, and an implementation that read it as "matches everything"
// would let one acknowledgement silence all 28. It looks identical in
// every test that uses one rule.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _target = Uuid('11111111-1111-4111-8111-111111111111');

/// The fingerprint of the finding `_finding()` builds. COMPUTED, never
/// typed out: a literal here would pass every test in this file while
/// matching nothing the real evaluator will ever produce.
final String _instance = findingFingerprint(
  ruleId: 'LEN-001',
  targets: const [
    _target,
  ],
);
const _otherInstance = 'LEN-001:fedcba9876543210';

AckedFinding _ack({
  required String id,
  String ruleId = 'LEN-001',
  String? targetFingerprint,
  String reason = '',
  DateTime? at,
  Severity demotedTo = Severity.off,
}) {
  final when = at ?? DateTime.utc(2026, 9);
  return AckedFinding(
    id: Uuid(id),
    ruleId: ruleId,
    targetFingerprint: targetFingerprint ?? _instance,
    reason: reason,
    by: 'R. Riley',
    at: when,
    demotedTo: demotedTo,
    meta: EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'R. Riley'),
  );
}

Finding _finding({
  String ruleId = 'LEN-001',
  List<Uuid> targets = const [_target],
}) => Finding(
  ruleId: ruleId,
  severity: Severity.error,
  message: 'The channel is longer than 100 m.',
  targets: targets,
);

void main() {
  group('the reason is owed at project scope and nowhere else', () {
    test('a single-instance acknowledgement takes one click and may '
        'leave the reason box empty (RJ-006)', () {
      expect(
        evaluateAcknowledgement(
          ruleId: 'LEN-001',
          targetFingerprint: _instance,
          reason: '',
        ),
        isA<RuleExceptionAllowed>(),
      );
    });

    test('a project-wide mute with no reason is refused, and the '
        'message says where the reason would have printed', () {
      final verdict = evaluateAcknowledgement(
        ruleId: 'LEN-001',
        targetFingerprint: kProjectWideFingerprint,
        reason: '',
      );
      expect(verdict, isA<RuleExceptionRefused>());
      expect((verdict as RuleExceptionRefused).message, contains('T0.02'));
      expect(verdict.message, contains('LEN-001'));
    });

    test('a box holding only whitespace is an empty box', () {
      expect(
        evaluateAcknowledgement(
          ruleId: 'LEN-001',
          targetFingerprint: kProjectWideFingerprint,
          reason: '   \n\t ',
        ),
        isA<RuleExceptionRefused>(),
      );
      expect(isWrittenReason(' '), isFalse);
      expect(isWrittenReason(''), isFalse);
      expect(isWrittenReason('Existing condition, Phase 2.'), isTrue);
    });

    test('a project-wide mute with a written reason stands', () {
      expect(
        evaluateAcknowledgement(
          ruleId: 'LEN-001',
          targetFingerprint: kProjectWideFingerprint,
          reason: 'Existing condition, to be corrected in Phase 2.',
        ),
        isA<RuleExceptionAllowed>(),
      );
    });
  });

  group('what may be acknowledged at all', () {
    test('no tier-1 rule can be, at either scope, because it files no '
        'finding to acknowledge', () {
      for (final rule in rulesInTier(RuleTier.modelIllegal)) {
        for (final scope in [kProjectWideFingerprint, _instance]) {
          expect(
            evaluateAcknowledgement(
              ruleId: rule.ruleId,
              targetFingerprint: scope,
              reason: 'I know what I am doing.',
            ),
            isA<RuleExceptionRefused>(),
            reason: '${rule.ruleId} at $scope',
          );
        }
      }
    });

    test('every tier-2 and tier-3 rule can be, which is CR-019 saying '
        'errors are acknowledgeable', () {
      for (final rule in kRuleCatalogue) {
        if (rule.tier == RuleTier.modelIllegal) continue;
        expect(
          evaluateAcknowledgement(
            ruleId: rule.ruleId,
            targetFingerprint: kProjectWideFingerprint,
            reason: 'Surveyed as found.',
          ),
          isA<RuleExceptionAllowed>(),
          reason: rule.ruleId,
        );
      }
    });

    test('a rule id the catalogue does not know is refused (CR-021)', () {
      expect(
        evaluateAcknowledgement(
          ruleId: 'SIG-999',
          targetFingerprint: _instance,
          reason: 'Anything.',
        ),
        isA<RuleExceptionRefused>(),
      );
    });
  });

  group('which findings an acknowledgement speaks to', () {
    test('an instance acknowledgement matches its own finding and no '
        'other instance of the same rule', () {
      final finding = _finding();
      expect(
        acknowledges(
          _ack(id: 'a', targetFingerprint: finding.targetFingerprint),
          finding,
        ),
        isTrue,
      );
      expect(
        acknowledges(_ack(id: 'b', targetFingerprint: _otherInstance), finding),
        isFalse,
      );
    });

    test('the wildcard matches every instance of ITS OWN rule', () {
      expect(
        acknowledges(
          _ack(id: 'a', targetFingerprint: kProjectWideFingerprint),
          _finding(),
        ),
        isTrue,
      );
    });

    test('and the wildcard does NOT reach a different rule, which is '
        'the whole difference between muting one rule and muting the '
        'catalogue', () {
      final wildcard = _ack(
        id: 'a',
        targetFingerprint: kProjectWideFingerprint,
      );
      for (final rule in kRuleCatalogue) {
        if (rule.ruleId == 'LEN-001') continue;
        expect(
          acknowledges(wildcard, _finding(ruleId: rule.ruleId)),
          isFalse,
          reason: rule.ruleId,
        );
      }
    });
  });

  group('which acknowledgement governs, when more than one could', () {
    test('the instance beats the project-wide mute, whichever order '
        'they arrive in', () {
      final finding = _finding();
      final wide = _ack(id: 'wide', targetFingerprint: kProjectWideFingerprint);
      final one = _ack(id: 'one', targetFingerprint: finding.targetFingerprint);
      expect(acknowledgementFor(finding, [wide, one])?.id.v, 'one');
      expect(acknowledgementFor(finding, [one, wide])?.id.v, 'one');
    });

    test('between two of equal scope the later one wins, because that '
        'is the opinion arrived at second', () {
      final march = _ack(
        id: 'march',
        targetFingerprint: kProjectWideFingerprint,
        at: DateTime.utc(2026, 3),
      );
      final september = _ack(
        id: 'september',
        targetFingerprint: kProjectWideFingerprint,
        at: DateTime.utc(2026, 9),
      );
      expect(
        acknowledgementFor(_finding(), [march, september])?.id.v,
        'september',
      );
      expect(
        acknowledgementFor(_finding(), [september, march])?.id.v,
        'september',
      );
    });

    test('two written in the same instant resolve by id and not by map '
        'order, because which reason prints is not a coin toss', () {
      final same = DateTime.utc(2026, 9, 2, 14, 30);
      final a = _ack(id: 'aaaa', at: same);
      final z = _ack(id: 'zzzz', at: same);
      expect(acknowledgementFor(_finding(), [a, z])?.id.v, 'zzzz');
      expect(acknowledgementFor(_finding(), [z, a])?.id.v, 'zzzz');
    });

    test('and none at all is null, not an empty acknowledgement', () {
      expect(acknowledgementFor(_finding(), const []), isNull);
      expect(
        acknowledgementFor(_finding(), [
          _ack(id: 'a', targetFingerprint: _otherInstance),
        ]),
        isNull,
      );
    });
  });
}
