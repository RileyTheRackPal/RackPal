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
    targets: targets ?? [if (primary != null) primary],
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
    test('resolves the four types a rule can point at', () {
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
        ],
        by: FindingGrouping.locus,
      );
      expect(
        groups.map((g) => g.label).toSet(),
        {'RK-1', 'AVR-1', 'W001', 'Panel A / Breaker 14'},
      );
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

    test('locusLabel returns null for an id no rule should produce', () {
      // THE FIFTH-TYPE GUARD. A later rule pointing at a Port must fail
      // here rather than draw a blank, unclickable group header.
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
