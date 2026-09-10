// Three layers, in one order (`#260`, M5-B3, CR-018, CR-019).
//
// ═══════════════════════════════════════════════════════════════════════
// THE TEST THAT IS ACTUALLY ABOUT THE RULING
// ═══════════════════════════════════════════════════════════════════════
// Catalogue default, then the project override, then the
// acknowledgement. Every other order is defensible in the abstract and
// wrong in the trade: turning the severity dial back up to `error` must
// not silently discard a written justification, because the person who
// wrote it has no way of learning it stopped applying. So the
// acknowledgement is applied last, and there is a test below whose whole
// job is to fail if somebody swaps the two.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 2, 12);
const _target = Uuid('11111111-1111-4111-8111-111111111111');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-severity'),
  appVersion: '0.5.13',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

RuleOverride _override(Severity severity) => RuleOverride(
  severity: severity,
  reason: 'The client owns this decision.',
  by: 'R. Riley',
  at: _now,
);

Finding _finding(Severity severity) => Finding(
  ruleId: 'PWR-001',
  severity: severity,
  message: 'Circuit A-12 is planned to 84% of its breaker.',
  targets: const [_target],
);

AckedFinding _ack(Severity demotedTo, {String? fingerprint}) => AckedFinding(
  id: const Uuid('ack-1'),
  ruleId: 'PWR-001',
  targetFingerprint:
      fingerprint ??
      findingFingerprint(ruleId: 'PWR-001', targets: const [_target]),
  reason: 'Existing panel. Load is measured, not estimated.',
  by: 'R. Riley',
  at: _now,
  demotedTo: demotedTo,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'R. Riley'),
);

void main() {
  group('what the project says a rule counts as', () {
    test('with no override it is what the catalogue says, and PWR-001 '
        'is the one DR-079 deliberately demoted', () {
      final settings = _doc().settings;
      expect(projectSeverity('PWR-001', settings), Severity.warning);
      expect(kRulesById['PWR-001']!.defaultSeverity, Severity.warning);
    });

    test('an override replaces it, off included, because off is a '
        'legal severity and not an absence', () {
      final settings = _doc().settings;
      settings.ruleOverrides['PWR-001'] = _override(Severity.off);
      expect(projectSeverity('PWR-001', settings), Severity.off);
    });

    test('every rule that files a finding has one, so the resolver can '
        'never be asked a question the catalogue cannot answer', () {
      // BOTH BANDS (DR-154 §11.153.9). `projectSeverity` returns null for
      // a rule it cannot find, and `evaluateDocument` DROPS a finding on a
      // null: a plan rule missing from `kRulesById` would not throw, it
      // would silently never fire.
      final settings = _doc().settings;
      var band = 0;
      for (final rule in kRulesById.values) {
        if (rule.tier == RuleTier.modelIllegal) continue;
        if (rule.ruleId.startsWith('PLN-')) band++;
        expect(
          projectSeverity(rule.ruleId, settings),
          isNotNull,
          reason: rule.ruleId,
        );
      }
      expect(band, kPlanRules.length, reason: 'the band was never reached');
    });
  });

  group('null is inapplicable, not unknown (G4)', () {
    test('a tier-1 rule has no severity, because it refuses the edit '
        'and files nothing to be severe about', () {
      final settings = _doc().settings;
      for (final rule in rulesInTier(RuleTier.modelIllegal)) {
        expect(
          projectSeverity(rule.ruleId, settings),
          isNull,
          reason: rule.ruleId,
        );
      }
    });

    test('and an override written against one is IGNORED rather than '
        'obeyed, so a hand-edited file cannot give TOP-001 a severity', () {
      final settings = _doc().settings;
      settings.ruleOverrides['TOP-001'] = _override(Severity.error);
      expect(projectSeverity('TOP-001', settings), isNull);
    });

    test('a rule this build has never heard of is ignored too, AND its '
        'override survives the round trip (forward compat, G4)', () {
      // docs/02 section 5.4 keeps forward-compat on unknown rule ids as
      // data on purpose. Ignoring the entry is right; DROPPING it is
      // not, because the build that knows the rule needs it back.
      final doc = _doc();
      doc.settings.ruleOverrides['ZZZ-999'] = _override(Severity.advisory);
      expect(projectSeverity('ZZZ-999', doc.settings), isNull);

      final bytes = _codec.write(doc);
      final reopened = (_codec.read(bytes) as Ok<RackDocument>).value;
      expect(
        reopened.settings.ruleOverrides['ZZZ-999']?.severity,
        Severity.advisory,
      );
      expect(_codec.write(reopened), bytes);
    });
  });

  group('what a finding actually carries', () {
    test('with nothing acknowledged it is the finding as built', () {
      expect(
        effectiveSeverity(_finding(Severity.warning), const []),
        Severity.warning,
      );
    });

    test('an acknowledgement demotes it to whatever it says', () {
      expect(
        effectiveSeverity(_finding(Severity.error), [_ack(Severity.advisory)]),
        Severity.advisory,
      );
    });

    test('a project-wide mute reaches a finding it never named', () {
      expect(
        effectiveSeverity(_finding(Severity.error), [
          _ack(Severity.off, fingerprint: kProjectWideFingerprint),
        ]),
        Severity.off,
      );
    });

    test('THE ACKNOWLEDGEMENT IS APPLIED LAST. Turning the severity dial '
        'back up must not discard a written justification', () {
      // The finding is built at `error` because the project overrode
      // PWR-001 upward. The acknowledgement still governs it. Swap the
      // two layers and this reads `error`, and the reason on T0.02
      // would be describing a demotion that is not in effect.
      final settings = _doc().settings;
      settings.ruleOverrides['PWR-001'] = _override(Severity.error);
      final finding = _finding(projectSeverity('PWR-001', settings)!);
      expect(finding.severity, Severity.error);
      expect(
        effectiveSeverity(finding, [_ack(Severity.advisory)]),
        Severity.advisory,
      );
    });
  });

  group('open means somebody is still being shown it', () {
    test('off is the only closed state', () {
      for (final severity in Severity.values) {
        expect(
          isOpenFinding(_finding(Severity.error), [_ack(severity)]),
          severity != Severity.off,
          reason: severity.name,
        );
      }
    });

    test('an acknowledgement that does NOT demote to off leaves the '
        'finding visible, which is what noted-and-still-an-error needs', () {
      expect(
        isOpenFinding(_finding(Severity.error), [_ack(Severity.error)]),
        isTrue,
      );
    });
  });
}
