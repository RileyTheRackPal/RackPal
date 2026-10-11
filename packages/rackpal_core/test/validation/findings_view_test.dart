// M5-F1 — the issues list's shape.
//
// WHAT THIS FILE DOES NOT DO: build a fixture per rule. AC-051's pairs
// are M5-G's whole scope (`#299`-`#302`), and duplicating them here would
// give the project two corpora to keep in step. These tests take
// `Finding`s as given and assert what the VIEW does with them, which is
// the only thing `findings_view.dart` decides.
//
// The one exception is [locusLabel], which is about real entities and so
// needs a real document.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 4, 12);
  EntityMeta meta() => EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't');

  const rackId = Uuid('0190e0dd-0001-7000-8000-000000000001');
  const deviceId = Uuid('0190e0dd-0001-7000-8000-000000000002');
  const linkId = Uuid('0190e0dd-0001-7000-8000-000000000003');
  const circuitId = Uuid('0190e0dd-0001-7000-8000-000000000004');
  const netId = Uuid('0190e0dd-0001-7000-8000-000000000005');
  const underlayId = Uuid('0190e0dd-0001-7000-8000-000000000006');
  const namedNetId = Uuid('0190e0dd-0001-7000-8000-000000000007');
  const strangerId = Uuid('0190e0dd-0001-7000-8000-00000000000f');

  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0dd-0001-7000-8000-000000000000'),
      appVersion: '0.5.46',
      createdAt: at,
      modifiedAt: at,
      meta: meta(),
      info: ProjectInfo(projectName: 'VIEW FIXTURE'),
      registries: buildSeedRegistries(),
    );
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      meta: meta(),
    );
    d.circuits[circuitId] = Circuit(
      id: circuitId,
      designator: 'Panel A / Breaker 14',
      breakerAmps: 20,
      volts: 120,
      meta: meta(),
    );
    // `ELE-005`'s locus, missing an arm since `#838` (DR-154 §11.153.8a).
    d.nets[netId] = Net(
      id: netId,
      name: 'Net 12',
      designator: 'SPK-A',
      signalFamily: const SignalFamilyId('audio.speaker_cv'),
      meta: meta(),
    );
    // A net with no designator, which is the ordinary case: CR-049 makes
    // the name generated and editable and the designator optional.
    d.nets[namedNetId] = Net(
      id: namedNetId,
      name: 'Net 13',
      signalFamily: const SignalFamilyId('audio.speaker_cv'),
      meta: meta(),
    );
    // Every `PLN-*`'s locus, missing an arm since `PLAN-I/1`.
    d.underlays[underlayId] = PlanUnderlay(
      id: underlayId,
      name: 'Level 1',
      imageMember: 'underlays/$underlayId.png',
      format: PlanImageFormat.png,
      pixelWidth: 8,
      pixelHeight: 8,
      contentHash: 'sha256:${'0' * 64}',
      order: const FracIndex('a0'),
      meta: meta(),
    );
    return d;
  }

  Finding finding(
    String ruleId,
    Severity severity, {
    Uuid? primary,
    List<Uuid>? targets,
  }) => Finding(
    ruleId: ruleId,
    severity: severity,
    message: 'A sentence about $ruleId.',
    targets: targets ?? [?primary],
    primaryEntityId: primary,
  );

  group('grouping by severity', () {
    test('orders error, warning, advisory — not alphabetically', () {
      // ALPHABETICAL WOULD GIVE advisory, error, warning. The assertion
      // is on the artifact: the header order a person reads.
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('LNK-020', Severity.advisory),
          finding('PWR-001', Severity.warning),
          finding('SIG-001', Severity.error),
        ],
        by: FindingGrouping.severity,
      );
      expect(
        groups.map((g) => g.label).toList(),
        ['error', 'warning', 'advisory'],
      );
    });

    test('findings of one severity land in one group', () {
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('SIG-001', Severity.error),
          finding('CODE-001', Severity.error),
        ],
        by: FindingGrouping.severity,
      );
      expect(groups, hasLength(1));
      expect(groups.single.length, 2);
    });
  });

  group('grouping by rule', () {
    test('one group per rule id, ordered by id', () {
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('SIG-001', Severity.error),
          finding('CODE-001', Severity.warning),
          finding('SIG-001', Severity.error, primary: linkId),
        ],
        by: FindingGrouping.rule,
      );
      expect(groups.map((g) => g.label).toList(), ['CODE-001', 'SIG-001']);
      expect(groups.last.length, 2);
    });
  });

  group('grouping by locus', () {
    test('resolves the six types a rule can point at', () {
      final doc = build();
      doc.devices[deviceId] = _device(deviceId, 'AVR-1', rackId, at);
      doc.links[linkId] = _link(linkId, 'W001', at);

      final groups = groupFindings(
        doc,
        [
          finding('RCK-001', Severity.error, primary: rackId),
          finding('SIG-001', Severity.error, primary: deviceId),
          finding('LEN-001', Severity.warning, primary: linkId),
          finding('PWR-001', Severity.warning, primary: circuitId),
          finding('ELE-005', Severity.warning, primary: netId),
          finding('PLN-001', Severity.advisory, primary: underlayId),
        ],
        by: FindingGrouping.locus,
      );
      expect(groups.map((g) => g.label).toSet(), {
        'RK-1',
        'AVR-1',
        'W001',
        'Panel A / Breaker 14',
        'SPK-A',
        'Level 1',
      });
      // NOT `kNoLocusGroup` FOR ANY OF THEM, said separately because that
      // is the failure this test was widened for: the last two grouped
      // under "no location" for as long as the arms were missing, and a
      // set assertion that happened to contain the right six labels
      // alongside a seventh would not have said so.
      expect(
        groups.map((g) => g.label),
        isNot(contains(kNoLocusGroup)),
      );
    });

    test('a net with no designator falls back to its name, exactly as '
        'ELE-005’s own message does', () {
      // TWO NAMES FOR ONE THING ON ONE SCREEN is the failure here: the
      // header and the sentence under it have to agree.
      expect(locusLabel(build(), namedNetId), 'Net 13');
      expect(locusLabel(build(), netId), 'SPK-A');
    });

    test('a null locus groups last, and says which kind of nothing', () {
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('PWR-002', Severity.warning),
          finding('RCK-001', Severity.error, primary: rackId),
        ],
        by: FindingGrouping.locus,
      );
      // LAST, because the least specific group belongs at the bottom of
      // a list whose purpose is navigation.
      expect(groups.last.label, kNoLocusGroup);
      expect(groups.first.label, 'RK-1');
    });

    test('locusLabel returns null for an id that names nothing at all', () {
      // THIS USED TO CALL ITSELF THE FIFTH-TYPE GUARD AND IT NEVER WAS
      // ONE (DR-154 §11.153.8a). An id belonging to no collection resolves
      // to null, which is a statement about a stranger and NOT about a
      // type some rule points at: two such types arrived, `Net` at `#838`
      // and `PlanUnderlay` at `PLAN-I/1`, and this test passed through
      // both.
      //
      // The real guard is in `drc_fixture.dart`, where every rule's
      // known-bad runs and every finding it produces has to resolve. What
      // is left here is the null path itself, which that census depends
      // on still existing.
      expect(locusLabel(build(), strangerId), isNull);
    });
  });

  group('filters', () {
    test('an empty set keeps nothing; null does not filter at all', () {
      final doc = build();
      final all = [
        finding('SIG-001', Severity.error),
        finding('LEN-001', Severity.warning),
      ];
      expect(
        groupFindings(doc, all, by: FindingGrouping.rule, severities: {}),
        isEmpty,
      );
      expect(
        groupFindings(doc, all, by: FindingGrouping.rule),
        hasLength(2),
      );
    });

    test('severity filter keeps only what it names', () {
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('SIG-001', Severity.error),
          finding('LEN-001', Severity.warning),
        ],
        by: FindingGrouping.rule,
        severities: {Severity.error},
      );
      expect(groups.single.label, 'SIG-001');
    });

    test('rule filter keeps only what it names', () {
      final doc = build();
      final groups = groupFindings(
        doc,
        [
          finding('SIG-001', Severity.error),
          finding('LEN-001', Severity.warning),
        ],
        by: FindingGrouping.rule,
        ruleIds: {'LEN-001'},
      );
      expect(groups.single.label, 'LEN-001');
    });
  });

  group('acknowledgements', () {
    test('an instance acknowledgement is carried onto its row', () {
      final doc = build();
      final f = finding('SIG-001', Severity.error, primary: rackId);
      doc.ackedFindings[strangerId] = AckedFinding(
        id: strangerId,
        ruleId: 'SIG-001',
        targetFingerprint: f.targetFingerprint,
        reason: 'Existing plant, documented as-found.',
        by: 'riley',
        at: at,
        demotedTo: Severity.error,
        meta: meta(),
      );
      final row = groupFindings(
        doc,
        [f],
        by: FindingGrouping.rule,
      ).single.rows.single;
      expect(row.isAcknowledged, isTrue);
      expect(row.reason, 'Existing plant, documented as-found.');
    });

    test('an acknowledged row with no reason reads as acknowledged, not '
        'as a missing value', () {
      // RJ-006 makes the instance reason OPTIONAL, so an empty one is a
      // legal state rather than a hole to fill in.
      final doc = build();
      final f = finding('LEN-001', Severity.warning, primary: rackId);
      doc.ackedFindings[strangerId] = AckedFinding(
        id: strangerId,
        ruleId: 'LEN-001',
        targetFingerprint: f.targetFingerprint,
        reason: '',
        by: 'riley',
        at: at,
        demotedTo: Severity.warning,
        meta: meta(),
      );
      final row = groupFindings(
        doc,
        [f],
        by: FindingGrouping.rule,
      ).single.rows.single;
      expect(row.isAcknowledged, isTrue);
      expect(row.reason, isNull);
    });

    test('the project-wide mute matches through the same join', () {
      // "*" is exactly the case a hand-written matcher gets wrong, which
      // is why the view borrows `acknowledgementFor` instead.
      final doc = build();
      final f = finding('CODE-002', Severity.error, primary: rackId);
      doc.ackedFindings[strangerId] = AckedFinding(
        id: strangerId,
        ruleId: 'CODE-002',
        targetFingerprint: kProjectWideFingerprint,
        reason: 'Reviewed with the AHJ for the whole job.',
        by: 'riley',
        at: at,
        demotedTo: Severity.advisory,
        meta: meta(),
      );
      final rows = groupFindings(doc, [
        f,
      ], by: FindingGrouping.rule).single.rows;
      expect(rows.single.isAcknowledged, isTrue);
    });

    test('includeAcknowledged false hides the row without suppressing the '
        'finding', () {
      final doc = build();
      final f = finding('SIG-001', Severity.error, primary: rackId);
      doc.ackedFindings[strangerId] = AckedFinding(
        id: strangerId,
        ruleId: 'SIG-001',
        targetFingerprint: f.targetFingerprint,
        reason: 'As-found.',
        by: 'riley',
        at: at,
        demotedTo: Severity.error,
        meta: meta(),
      );
      expect(
        groupFindings(
          doc,
          [f],
          by: FindingGrouping.rule,
          includeAcknowledged: false,
        ),
        isEmpty,
      );
      // Still a finding: the view hid it, nothing suppressed it.
      expect(
        groupFindings(doc, [f], by: FindingGrouping.rule).single.length,
        1,
      );
    });

    test('a group counts its acknowledged rows', () {
      final doc = build();
      final a = finding('SIG-001', Severity.error, primary: rackId);
      final b = finding('SIG-001', Severity.error, primary: circuitId);
      doc.ackedFindings[strangerId] = AckedFinding(
        id: strangerId,
        ruleId: 'SIG-001',
        targetFingerprint: a.targetFingerprint,
        reason: 'As-found.',
        by: 'riley',
        at: at,
        demotedTo: Severity.error,
        meta: meta(),
      );
      final g = groupFindings(doc, [a, b], by: FindingGrouping.rule).single;
      expect(g.length, 2);
      expect(g.acknowledgedCount, 1);
    });
  });

  test('the row order inside a group is the order it was given', () {
    // `evaluateDocument` sorts totally; a second sort here would be a
    // second opinion about the document's own answer.
    final doc = build();
    final given = [
      finding('SIG-001', Severity.error, primary: rackId),
      finding('SIG-001', Severity.error, primary: circuitId),
      finding('SIG-001', Severity.error, primary: deviceId),
    ];
    final rows = groupFindings(
      doc,
      given,
      by: FindingGrouping.rule,
    ).single.rows;
    expect(
      rows.map((r) => r.finding.primaryEntityId).toList(),
      [rackId, circuitId, deviceId],
    );
  });
}

DeviceInstance _device(Uuid id, String designator, Uuid rackId, DateTime at) =>
    DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('V01'),
        version: 1,
        contentHash: 'sha256:seed-V01',
      ),
      designator: designator,
      name: 'A device',
      placement: RailPlacement(
        rackId: rackId,
        ruIndex: 1,
        face: Face.front,
      ),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't'),
    );

Link _link(Uuid id, String designator, DateTime at) => Link(
  id: id,
  designator: designator,
  media: const MediaTypeId('cat6'),
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't'),
);
