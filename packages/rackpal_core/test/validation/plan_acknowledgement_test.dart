// PLAN-I/2: the plan band goes through the ONE acknowledgement
// mechanism, and there is no second one (`#646`, CR-019, RJ-006,
// DR-154 §11.153.3a).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS A FILE AND NOT A SENTENCE IN THE RULING
// ═══════════════════════════════════════════════════════════════════════
// CR-019 collapsed three proposed dismissal mechanisms into one, and the
// cheapest way to grow a second is to ship a band of rules that quietly
// needs its own. `rule_exception_test.dart` and
// `severity_resolution_test.dart` now sweep BOTH bands, which proves the
// gate accepts a `PLN-*`; what they cannot show is that a real plan
// finding, produced by a real document, is demoted by a real
// acknowledgement. That is an end-to-end fact and this is where it is
// asserted.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FINGERPRINT IS THE PART THAT COULD HAVE GONE WRONG QUIETLY
// ═══════════════════════════════════════════════════════════════════════
// `finding.dart`: a fingerprint is *"`ruleId` plus a digest over the
// participants' STABLE ids"*, because rule 42 collects an acknowledgement
// whose fingerprint no longer matches any finding, and a person who lost
// forty written reasons to a renumber would be told they were stale.
//
// Every `PLN-*` message embeds `underlay.name`, and an underlay is
// renamed by typing in a text field. If the name had reached the
// fingerprint, renaming `Level 1` to `First Floor` would silently discard
// every acknowledgement about that plan. It does not, and that is
// asserted rather than assumed.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/fixture_docs.dart';
import 'fixtures/plan_scenarios.dart';

final DateTime _at = DateTime.utc(2026, 9, 10, 9);

/// An acknowledgement of [ruleId] at [scope], demoting to [to].
AckedFinding _ack(
  String ruleId,
  String scope, {
  Severity to = Severity.advisory,
  String reason = 'Surveyed as found.',
  int seq = 1,
}) => AckedFinding(
  id: Uuid('0190e0dd-0f00-7000-8000-00000000ac0$seq'),
  ruleId: ruleId,
  targetFingerprint: scope,
  reason: reason,
  by: 'tester',
  at: _at,
  demotedTo: to,
  meta: EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'tester'),
);

/// The document every `PLN-*` fires on at once, and the set `PLN-004`
/// needs.
RackDocument _allFour() => planDoc(
  pinOutlet: true,
  rackElsewhere: true,
  spareOutlet: true,
);

const Set<Uuid> _changed = <Uuid>{kPlanUnderlayId};

List<Finding> _findings(RackDocument doc) =>
    evaluateDocument(doc, changedUnderlays: _changed);

Finding _one(RackDocument doc, String ruleId) =>
    _findings(doc).firstWhere((f) => f.ruleId == ruleId);

void main() {
  group('the fixture really does fire all four', () {
    test('and it is stated first, because every case below is about a '
        'finding that has to exist', () {
      // THE CONTROL RUNS BEFORE THE ASSERTIONS. An acknowledgement test
      // over a document with no findings passes by demoting nothing,
      // which is the vacuity this repository keeps meeting.
      expect(
        {for (final f in _findings(_allFour())) f.ruleId},
        {'PLN-001', 'PLN-002', 'PLN-003', 'PLN-004'},
      );
    });

    test('three advisories and one warning, so the band is not one '
        'severity wearing four ids', () {
      final byRule = {
        for (final f in _findings(_allFour())) f.ruleId: f.severity,
      };
      expect(byRule['PLN-004'], Severity.warning);
      expect(byRule['PLN-001'], Severity.advisory);
      expect(byRule['PLN-002'], Severity.advisory);
      expect(byRule['PLN-003'], Severity.advisory);
    });
  });

  group('one mechanism, and the plan band uses it', () {
    test('an instance acknowledgement of any of the four takes one click '
        'and needs no essay (RJ-006)', () {
      for (final rule in kPlanRules) {
        expect(
          evaluateAcknowledgement(
            ruleId: rule.ruleId,
            targetFingerprint: '${rule.ruleId}:0123456789abcdef',
            reason: '',
          ),
          isA<RuleExceptionAllowed>(),
          reason: rule.ruleId,
        );
      }
      expect(kPlanRules, isNotEmpty, reason: 'an empty band asserts nothing');
    });

    test('and muting one across the project does need one, because that '
        'reason prints (CR-019)', () {
      for (final rule in kPlanRules) {
        expect(
          evaluateAcknowledgement(
            ruleId: rule.ruleId,
            targetFingerprint: kProjectWideFingerprint,
            reason: '   ',
          ),
          isA<RuleExceptionRefused>(),
          reason: rule.ruleId,
        );
      }
    });

    test('a PLN id the band does not list is refused like any other '
        'stranger (CR-021)', () {
      // `kRulesById` is the ONE registry, so a plausible-looking id from a
      // later build is refused by the same sentence `SIG-999` gets.
      final verdict = evaluateAcknowledgement(
        ruleId: 'PLN-009',
        targetFingerprint: kProjectWideFingerprint,
        reason: 'It looks like a rule.',
      );
      expect(verdict, isA<RuleExceptionRefused>());
      expect(
        (verdict as RuleExceptionRefused).message,
        contains('not a rule this version of RackPal knows'),
      );
    });
  });

  group('an acknowledgement demotes a real plan finding, end to end', () {
    test('a warning acknowledged down to advisory is still reported, at '
        'advisory', () {
      final doc = _allFour();
      final ack = _ack('PLN-004', _one(doc, 'PLN-004').targetFingerprint);
      doc.ackedFindings[ack.id] = ack;

      expect(_one(doc, 'PLN-004').severity, Severity.advisory);
    });

    test('DEMOTES, NEVER DELETES: the finding is still in the list', () {
      // CR-019's own distinction, and the case an inspector needs: noted,
      // justified, and still there.
      final doc = _allFour();
      final ack = _ack('PLN-004', _one(doc, 'PLN-004').targetFingerprint);
      doc.ackedFindings[ack.id] = ack;

      expect(
        {for (final f in _findings(doc)) f.ruleId},
        {'PLN-001', 'PLN-002', 'PLN-003', 'PLN-004'},
      );
    });

    test('a demotion to off does remove it, which is what off means', () {
      final doc = _allFour();
      final ack = _ack(
        'PLN-001',
        _one(doc, 'PLN-001').targetFingerprint,
        to: Severity.off,
      );
      doc.ackedFindings[ack.id] = ack;

      expect(
        {for (final f in _findings(doc)) f.ruleId},
        isNot(contains('PLN-001')),
      );
    });

    test('the project-wide mute reaches an instance nobody named', () {
      final doc = _allFour();
      final ack = _ack(
        'PLN-002',
        kProjectWideFingerprint,
        to: Severity.off,
        reason: 'This job is locate-only; the drops are scheduled instead.',
      );
      doc.ackedFindings[ack.id] = ack;

      expect(
        {for (final f in _findings(doc)) f.ruleId},
        isNot(contains('PLN-002')),
      );
    });

    test('and it does NOT reach the other three, because "*" is a mute of '
        'its own rule', () {
      final doc = _allFour();
      final ack = _ack(
        'PLN-002',
        kProjectWideFingerprint,
        to: Severity.off,
        reason: 'This job is locate-only.',
      );
      doc.ackedFindings[ack.id] = ack;

      expect(
        {for (final f in _findings(doc)) f.ruleId},
        {'PLN-001', 'PLN-003', 'PLN-004'},
      );
    });

    test('THE ACKNOWLEDGEMENT IS APPLIED LAST, so turning the dial back up '
        'does not discard a written reason', () {
      // `severity_resolution.dart` rules the order and this is the plan
      // band standing in it: an override is a dial, an acknowledgement is
      // a signed act.
      final doc = _allFour();
      doc.settings.ruleOverrides['PLN-004'] = RuleOverride(
        severity: Severity.error,
        reason: 'This client re-measures every plan.',
        by: 'tester',
        at: _at,
      );
      final ack = _ack('PLN-004', _one(doc, 'PLN-004').targetFingerprint);
      doc.ackedFindings[ack.id] = ack;

      expect(_one(doc, 'PLN-004').severity, Severity.advisory);
    });
  });

  group('the fingerprint moves when the finding does, and not otherwise', () {
    test('RENAMING THE PLAN DOES NOT ORPHAN THE ACKNOWLEDGEMENT, though it '
        'changes every word of the message', () {
      // LOAD-BEARING. All four messages embed `underlay.name` and an
      // underlay is renamed by typing in a text field. A fingerprint that
      // read the name would let rule 42 collect the acknowledgement on
      // the next load and report it as stale.
      final doc = _allFour();
      final before = _one(doc, 'PLN-003');
      doc.underlays[kPlanUnderlayId]!.name = 'First Floor';
      final after = _one(doc, 'PLN-003');

      expect(after.targetFingerprint, before.targetFingerprint);
      expect(after.message, isNot(before.message));
      expect(after.message, contains('First Floor'));
    });

    test('and neither does re-ordering it, which a drag on the plan list '
        'does', () {
      final doc = _allFour();
      final before = _one(doc, 'PLN-001').targetFingerprint;
      doc.underlays[kPlanUnderlayId]!.order = const FracIndex('z9');

      expect(_one(doc, 'PLN-001').targetFingerprint, before);
    });

    test('PLN-002 DOES move when the population moves, on PWR-003 and '
        'LNK-020’s written contract', () {
      // Those two say it in their own comments: acknowledging "this rack
      // is over" with three devices in it must not survive a fourth. The
      // same holds here, and it is the reason `PLN-002` targets the
      // carriers rather than only the plan: an acknowledgement of "1
      // device is not on the plan" is not an acknowledgement of two.
      final doc = _allFour();
      final before = _one(doc, 'PLN-002').targetFingerprint;

      final third = Outlet(
        id: const Uuid('0190e0dd-0f00-7000-8000-0000000000fd'),
        structureBodyId: fixtureId(92),
        designation: 'WP-3',
        order: const FracIndex('a2'),
        meta: fixtureMeta(),
        locationId: doc.locations.values
            .firstWhere((l) => l.kind == LocationKind.room)
            .id,
      );
      doc.outlets[third.id] = third;

      expect(_one(doc, 'PLN-002').targetFingerprint, isNot(before));
      expect(_one(doc, 'PLN-002').message, contains('2 devices'));
    });

    test('the other three do not, because they are about the plan and not '
        'about a set', () {
      final doc = _allFour();
      final before = {
        for (final id in const ['PLN-001', 'PLN-003', 'PLN-004'])
          id: _one(doc, id).targetFingerprint,
      };

      doc.outlets[const Uuid('0190e0dd-0f00-7000-8000-0000000000fc')] = Outlet(
        id: const Uuid('0190e0dd-0f00-7000-8000-0000000000fc'),
        structureBodyId: fixtureId(93),
        designation: 'WP-4',
        order: const FracIndex('a3'),
        meta: fixtureMeta(),
        locationId: doc.locations.values
            .firstWhere((l) => l.kind == LocationKind.room)
            .id,
      );

      for (final entry in before.entries) {
        expect(
          _one(doc, entry.key).targetFingerprint,
          entry.value,
          reason: entry.key,
        );
      }
    });
  });

  group('the issues list shows the acknowledgement, and where', () {
    test('an acknowledged plan finding is a hollow badge with a reason', () {
      final doc = _allFour();
      final ack = _ack(
        'PLN-001',
        _one(doc, 'PLN-001').targetFingerprint,
        reason: 'The owner is supplying a surveyed plan next week.',
      );
      doc.ackedFindings[ack.id] = ack;

      final row = groupFindings(
        doc,
        _findings(doc),
        by: FindingGrouping.rule,
      ).firstWhere((g) => g.key == 'PLN-001').rows.single;

      expect(row.isAcknowledged, isTrue);
      expect(row.reason, contains('surveyed plan'));
    });

    test('and all four group under the PLAN, not under "no location"', () {
      // The defect the locus census found (DR-154 §11.153.8a). Stated here
      // too because this is the surface it was wrong on.
      final doc = _allFour();
      final groups = groupFindings(
        doc,
        _findings(doc),
        by: FindingGrouping.locus,
      );

      expect(groups, hasLength(1));
      expect(groups.single.label, 'Level 1');
      expect(groups.single.length, 4);
    });

    test('excluding acknowledged rows is a VIEW filter and not a '
        'suppression', () {
      final doc = _allFour();
      final ack = _ack('PLN-003', _one(doc, 'PLN-003').targetFingerprint);
      doc.ackedFindings[ack.id] = ack;

      expect(
        groupFindings(
          doc,
          _findings(doc),
          by: FindingGrouping.rule,
          includeAcknowledged: false,
        ).map((g) => g.key),
        isNot(contains('PLN-003')),
      );
      // Still a finding, still evaluated, still on its way to `T0.02`.
      expect(_findings(doc).map((f) => f.ruleId), contains('PLN-003'));
    });
  });

  group('there is no second mechanism', () {
    test('the predicates consult neither an override nor an '
        'acknowledgement', () {
      // A SOURCE GATE, on `findings_never_block_export_test.dart`'s
      // precedent: a band cannot grow its own mute path if its predicates
      // never mention one. `drc.dart`'s header rules the order and says a
      // predicate re-implementing it would be a second copy.
      final src = File(
        '../../packages/rackpal_core/lib/src/validation/rules_plan.dart',
      ).readAsStringSync();

      expect(
        src,
        contains('PLN-004'),
        reason: 'the scan found the wrong file, so it proves nothing',
      );
      for (final needle in const [
        'ruleOverrides',
        'ackedFindings',
        'acknowledgementFor',
        'demotedTo',
        'effectiveSeverity',
        'Severity.off',
      ]) {
        expect(
          src,
          isNot(contains(needle)),
          reason: 'rules_plan.dart mentions $needle, which is drc.dart’s job',
        );
      }
    });

    test('and `AckedFinding` still has exactly one shape for both bands', () {
      // No `planMutes`, no per-rule opt-out, no second collection. If a
      // second mechanism is ever added, the document is where it would
      // have to live, and this is where that shows up.
      final doc = _allFour();
      final ack = _ack('PLN-001', _one(doc, 'PLN-001').targetFingerprint);
      doc.ackedFindings[ack.id] = ack;

      final read = const JsonDocumentCodec().read(
        const JsonDocumentCodec().write(doc),
      );
      final round = (read as Ok<RackDocument>).value;
      expect(round.ackedFindings, hasLength(1));
      expect(round.ackedFindings.values.single.ruleId, 'PLN-001');
      expect(
        round.ackedFindings.values.single.targetFingerprint,
        ack.targetFingerprint,
        reason:
            'a fingerprint that did not survive the codec would orphan '
            'the acknowledgement on the next load (rule 42)',
      );
    });
  });
}
