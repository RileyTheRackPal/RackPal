// `Finding` and the fingerprint an acknowledgement joins on (`#258`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE CHAPTER'S OWN WARNING IS WHAT THIS FILE IS FOR
// ═══════════════════════════════════════════════════════════════════════
// `#258`: *"a fingerprint that changes when unrelated geometry moves
// re-fires every acknowledgement in the project. This is the part most
// likely to be got subtly wrong."* It is worse than re-firing. docs/02's
// rule 42 garbage-collects a stale acknowledgement ON LOAD, so a
// fingerprint that moved would not re-fire the finding with its reason
// attached: it would DELETE the reason and re-fire the finding bare.
//
// So the tests below are mostly about what must NOT change the answer.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _a = Uuid('11111111-1111-4111-8111-111111111111');
const _b = Uuid('22222222-2222-4222-8222-222222222222');
const _c = Uuid('33333333-3333-4333-8333-333333333333');

void main() {
  group('the fingerprint is stable under everything that is not identity', () {
    test('it is DETERMINISTIC, pinned to a literal so a change of '
        'algorithm is a visible diff and not a silent mass amnesty', () {
      // If this value moves, every acknowledgement in every project on
      // disk stops matching its finding and rule 42 deletes it on load.
      // Changing it is therefore a migration, not a refactor.
      expect(
        findingFingerprint(ruleId: 'SIG-001', targets: const [_a, _b]),
        'SIG-001:46bfea7713358f59',
      );
    });

    test('the order of the targets does not matter, because a joint is '
        'the same joint from either end', () {
      expect(
        findingFingerprint(ruleId: 'DIR-001', targets: const [_a, _b]),
        findingFingerprint(ruleId: 'DIR-001', targets: const [_b, _a]),
      );
    });

    test('naming an entity twice is the same as naming it once', () {
      expect(
        findingFingerprint(ruleId: 'TOP-001', targets: const [_a, _a]),
        findingFingerprint(ruleId: 'TOP-001', targets: const [_a]),
      );
    });
  });

  group('and it DOES change when the identity does', () {
    test('a different rule about the same entities is a different '
        'finding, so an acknowledgement of one cannot mute the other', () {
      expect(
        findingFingerprint(ruleId: 'SIG-001', targets: const [_a, _b]),
        isNot(findingFingerprint(ruleId: 'SIG-002', targets: const [_a, _b])),
      );
    });

    test('a different set of entities is a different finding', () {
      expect(
        findingFingerprint(ruleId: 'SIG-001', targets: const [_a, _b]),
        isNot(findingFingerprint(ruleId: 'SIG-001', targets: const [_a, _c])),
      );
    });

    test('the separator keeps neighbouring ids apart, so a concatenation '
        'cannot collide with a different split of the same characters', () {
      expect(
        findingFingerprint(
          ruleId: 'X-001',
          targets: const [Uuid('ab'), Uuid('c')],
        ),
        isNot(
          findingFingerprint(
            ruleId: 'X-001',
            targets: const [Uuid('a'), Uuid('bc')],
          ),
        ),
      );
    });
  });

  group('the project-wide mute cannot be forged', () {
    test('a real fingerprint always carries its rule id and a colon, so it '
        'can never equal the wildcard', () {
      for (final rule in kRuleCatalogue) {
        final fp = findingFingerprint(ruleId: rule.ruleId, targets: const [_a]);
        expect(fp, isNot(kProjectWideFingerprint), reason: rule.ruleId);
        expect(fp, startsWith('${rule.ruleId}:'));
      }
    });

    test('the wildcard is what CR-019 says it is', () {
      expect(kProjectWideFingerprint, '*');
    });
  });

  group('Finding carries what the issues list needs', () {
    const finding = Finding(
      ruleId: 'SIG-001',
      severity: Severity.error,
      message: 'MTX-1 J05 feeds SW-1 J12, which is a switch port.',
      targets: [_a, _b],
      primaryEntityId: _a,
    );

    test('its fingerprint is the shared function, not a second '
        'implementation that could drift from it', () {
      expect(
        finding.targetFingerprint,
        findingFingerprint(ruleId: 'SIG-001', targets: const [_a, _b]),
      );
    });

    test('every rule id it can carry is one the catalogue knows (CR-021)', () {
      expect(kRulesById.containsKey(finding.ruleId), isTrue);
    });

    test('the message is a sentence about this document, not a log line', () {
      expect(finding.message, endsWith('.'));
      expect(
        finding.message,
        isNot(contains(finding.ruleId)),
        reason:
            'the rule id is its own field; a message repeating it is the '
            'log line ConnectRefused already rules against',
      );
    });
  });

  group('COMPUTED, NEVER STORED (docs/02 §4.8)', () {
    test('the codec does not mention Finding, and AckedFinding does not '
        'count', () {
      // docs/02 §4.8: "Finding is computed, never stored | Persisted
      // findings. Only acknowledgements persist." A codec entry is how
      // that decision would be lost, so this reads the file rather than
      // trusting anyone to remember.
      final codec = File('lib/src/persistence/json_codec.dart');
      expect(
        codec.existsSync(),
        isTrue,
        reason: 'suites run from the package directory; see CLAUDE.md',
      );
      final hits = <String>[];
      for (final line in codec.readAsLinesSync()) {
        // `AckedFinding` is persisted and legitimate, so strip it before
        // looking for the bare word.
        final stripped = line.replaceAll('AckedFinding', '');
        if (RegExp(r'\bFinding\b').hasMatch(stripped)) hits.add(line.trim());
      }
      expect(
        hits,
        isEmpty,
        reason:
            'json_codec.dart names Finding at: $hits. A stored finding is '
            'a second copy of an answer the rules can recompute, and the '
            'copy is the one that goes stale',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // THE COPY THAT USED TO DROP FIELDS (DR-128 §11.127.5)
  // ═══════════════════════════════════════════════════════════════════
  // `evaluateDocument` rebuilds a finding twice to change its severity,
  // and both rebuilds were longhand, so `remedy` was added and neither
  // learned about it: `PWR-003`'s button never reached the panel. The
  // copy now lives on `Finding.withSeverity`.
  //
  // ASSERTED FIELD BY FIELD RATHER THAN ON EQUALITY, because `Finding`
  // has no `operator ==`, so `expect(copy, original)` would compare
  // identity and pass on a copy that dropped everything.
  group('withSeverity carries every field but the severity', () {
    const original = Finding(
      ruleId: 'PWR-003',
      severity: Severity.error,
      message: 'RK-1 provides 2 outlets and its devices need 4.',
      targets: [Uuid('rack-1'), Uuid('amp-1')],
      primaryEntityId: Uuid('rack-1'),
      remedy: FindingRemedy.addRackPdu,
    );

    test('the severity is the only thing that moves', () {
      final copy = original.withSeverity(Severity.warning);
      expect(copy.severity, Severity.warning);
      expect(copy.ruleId, original.ruleId);
      expect(copy.message, original.message);
      expect(copy.targets, original.targets);
      expect(copy.primaryEntityId, original.primaryEntityId);
      expect(copy.remedy, original.remedy);
    });

    test('and the fingerprint does not, so an acknowledgement survives a '
        'demotion', () {
      expect(
        original.withSeverity(Severity.advisory).targetFingerprint,
        original.targetFingerprint,
      );
    });

    test('a finding with no remedy stays without one', () {
      const bare = Finding(
        ruleId: 'LEN-001',
        severity: Severity.warning,
        message: 'A run is long.',
        targets: [Uuid('link-1')],
      );
      expect(bare.remedy, isNull);
      expect(bare.withSeverity(Severity.advisory).remedy, isNull);
    });
  });
}
