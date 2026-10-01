// T0.02's content (M6-C `#322`, DR-214).
//
// ON A REAL STARTER'S FINDINGS: Whole House opens with 39, across four
// rules and three severities, which is the mix the sheet has to order. It
// carries no acknowledgement and no override, so those are added here,
// one of each kind, plus one acknowledgement whose finding never occurs.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final DateTime _at = DateTime.utc(2026, 10);

EntityMeta _meta() =>
    EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test');

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

AckedFinding _ack(
  String id,
  String ruleId,
  String fingerprint, {
  String reason = 'Agreed on site.',
  Severity demotedTo = Severity.advisory,
  DateTime? at,
}) => AckedFinding(
  id: Uuid(id),
  ruleId: ruleId,
  targetFingerprint: fingerprint,
  reason: reason,
  by: 'riley',
  at: at ?? _at,
  demotedTo: demotedTo,
  meta: _meta(),
);

void main() {
  test('A PROJECT WITH NOTHING SIGNED: every finding open, banded errors '
      'first, nothing else', () {
    final doc = _wholeHouse();
    final findings = evaluateDocument(doc);
    final report = buildExceptionsReport(doc, findings);
    expect(report.projectWide, isEmpty);
    expect(report.acknowledged, isEmpty);
    expect(report.stale, isEmpty);
    expect(report.openCount, findings.length);
    expect(report.open.map((g) => g.label), ['error', 'warning', 'advisory']);
  });

  group('with one of each kind signed', () {
    late RackDocument doc;
    late List<Finding> findings;
    late ExceptionsReport report;
    late Finding acked;

    setUp(() {
      doc = _wholeHouse();
      final before = evaluateDocument(doc);
      // An instance acknowledgement on the first LEN-001 finding.
      acked = before.firstWhere((f) => f.ruleId == 'LEN-001');
      doc.ackedFindings[const Uuid('ack-instance')] = _ack(
        'ack-instance',
        'LEN-001',
        acked.targetFingerprint,
        reason: 'Length is measured on site at termination.',
        demotedTo: Severity.warning,
      );
      // A project-wide mute of LNK-020.
      doc.ackedFindings[const Uuid('ack-mute')] = _ack(
        'ack-mute',
        'LNK-020',
        kProjectWideFingerprint,
        reason: 'Client supplies the patch cords.',
      );
      // An acknowledgement whose finding never occurs.
      doc.ackedFindings[const Uuid('ack-stale')] = _ack(
        'ack-stale',
        'RCK-013',
        'RCK-013:gone',
        reason: 'Shelf added since.',
        at: DateTime.utc(2026, 9),
      );
      // A project override.
      doc.settings.ruleOverrides['LEN-002'] = RuleOverride(
        severity: Severity.advisory,
        reason: 'Lengths are estimated at rough-in.',
        by: 'riley',
        at: _at,
      );
      findings = evaluateDocument(doc);
      report = buildExceptionsReport(doc, findings);
    });

    test('PROJECT-WIDE: the override, then the mute, each with its change '
        'and its reason (§11.213.1)', () {
      expect(
        [
          for (final p in report.projectWide)
            (p.ruleId, p.kind, p.reason, p.by),
        ],
        [
          (
            'LEN-002',
            ProjectWideKind.override,
            'Lengths are estimated at rough-in.',
            'riley',
          ),
          (
            'LNK-020',
            ProjectWideKind.mute,
            'Client supplies the patch cords.',
            'riley',
          ),
        ],
      );
      expect(report.projectWide.first.change, endsWith('→ ADVISORY'));
      expect(report.projectWide.last.change, endsWith('every instance'));
    });

    test('EVERY FINDING IS EXACTLY ONE OPEN ROW OR ONE ACKNOWLEDGED ROW', () {
      final open = [
        for (final g in report.open) ...g.rows.map((r) => r.finding),
      ];
      final ack = [for (final r in report.acknowledged) r.finding];
      expect(open.length + ack.length, findings.length);
      expect({...open, ...ack}, findings.toSet());
      expect(open.where(ack.contains), isEmpty);
    });

    test('THE ACKNOWLEDGED ROWS ARE THE ONES acknowledgementFor COVERS, '
        'with their reasons (DR-111)', () {
      for (final row in report.acknowledged) {
        expect(
          row.acknowledgement,
          acknowledgementFor(row.finding, doc.ackedFindings.values),
        );
      }
      expect(
        report.acknowledged
            .where(
              (r) => r.finding.targetFingerprint == acked.targetFingerprint,
            )
            .single
            .reason,
        'Length is measured on site at termination.',
      );
      // Every LNK-020 finding is covered by the mute.
      expect(
        report.open
            .expand((g) => g.rows)
            .where((r) => r.finding.ruleId == 'LNK-020'),
        isEmpty,
      );
    });

    test('AN ACKNOWLEDGEMENT WITH NO FINDING LEFT IS STALE, and only that one '
        '(§11.213.4)', () {
      expect(report.stale.map((a) => a.id), [const Uuid('ack-stale')]);
    });
  });
}
