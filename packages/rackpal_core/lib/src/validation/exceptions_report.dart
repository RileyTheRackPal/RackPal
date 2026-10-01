// T0.02's content (docs/08 §2.2 row 3, M6-C `#322`, DR-214).
//
// ═══════════════════════════════════════════════════════════════════════
// A PRESENTATION OF ONE ANSWER, NEVER A SECOND ONE (DR-111 §11.110.3)
// ═══════════════════════════════════════════════════════════════════════
// The issues list and this sheet show the same findings, and CR-022 makes
// them two presentations of one answer. So nothing here decides what a
// finding is or which acknowledgement covers it: the findings are what
// `evaluateDocument` returned, the open and acknowledged rows are what
// `groupFindings` returns, and a stale acknowledgement is one that
// `acknowledges` matches to no finding. A sheet that re-derived any of
// that would come to disagree with the panel about the same row in front
// of a client.
//
// THE ORDER IS DR-214's: project-wide exceptions, then open findings by
// severity (errors first), then acknowledged findings, then any
// acknowledgement whose finding no longer occurs.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/validation/finding.dart';
import 'package:rackpal_core/src/validation/findings_view.dart';
import 'package:rackpal_core/src/validation/rule_catalogue.dart';
import 'package:rackpal_core/src/validation/rule_exception.dart';

/// What a project-wide exception did to its rule.
enum ProjectWideKind {
  /// `ProjectSettings.ruleOverrides`: the rule counts as something else
  /// here.
  override,

  /// A `"*"` acknowledgement: every instance of the rule is acknowledged.
  mute,
}

/// One line of the PROJECT-WIDE EXCEPTIONS section (§11.213.1).
@immutable
final class ProjectWideException {
  const ProjectWideException({
    required this.ruleId,
    required this.kind,
    required this.from,
    required this.to,
    required this.reason,
    required this.by,
    required this.at,
  });

  final String ruleId;
  final ProjectWideKind kind;

  /// What the catalogue says the rule is: `WARNING`, or a band
  /// `ADVISORY/WARNING/ERROR`.
  final String from;

  /// What it is in this project: `OFF`, `ADVISORY`; for a mute, what every
  /// instance is demoted to.
  final String to;

  /// Mandatory for both kinds (CR-019, RJ-006), so never empty in a file
  /// the writer produced; a hand-edited file is printed as it stands.
  final String reason;
  final String by;
  final DateTime at;

  /// `WARNING → OFF`, or `WARNING → ADVISORY, every instance` for a mute.
  String get change => kind == ProjectWideKind.override
      ? '$from → $to'
      : '$from → $to, every instance';
}

/// Everything T0.02 prints, in the order it prints it (DR-214).
@immutable
final class ExceptionsReport {
  const ExceptionsReport({
    required this.projectWide,
    required this.open,
    required this.acknowledged,
    required this.stale,
  });

  /// Rule overrides, then `"*"` mutes, each by rule id (§11.213.1).
  final List<ProjectWideException> projectWide;

  /// Unacknowledged findings, banded by severity, errors first (§11.213.2).
  final List<FindingGroup> open;

  /// Acknowledged findings, in the same severity order (§11.213.3).
  final List<FindingRow> acknowledged;

  /// Instance acknowledgements that match no current finding, oldest
  /// first (§11.213.4).
  final List<AckedFinding> stale;

  int get openCount => open.fold(0, (n, g) => n + g.rows.length);

  /// Open findings at [Severity.error]: the count that withholds the
  /// ISSUED FOR CONSTRUCTION stamp (CR-022, DR-216 §11.215.1). An
  /// acknowledged error is not open, so it does not count.
  int get openErrorCount => open.fold(
    0,
    (n, g) =>
        n + g.rows.where((r) => r.finding.severity == Severity.error).length,
  );
}

/// What a severity prints as.
String severityLabel(Severity s) => s.name.toUpperCase();

String _catalogueSeverity(String ruleId) {
  final meta = kRulesById[ruleId];
  if (meta == null) return '—';
  if (meta.severityBand case final band? when band.isNotEmpty) {
    final ordered = band.toList()..sort((a, b) => b.index.compareTo(a.index));
    return ordered.map(severityLabel).join('/');
  }
  return meta.defaultSeverity == null
      ? '—'
      : severityLabel(meta.defaultSeverity!);
}

/// Builds T0.02's content from [doc] and the [findings] `evaluateDocument`
/// returned for it.
ExceptionsReport buildExceptionsReport(
  RackDocument doc,
  List<Finding> findings,
) {
  // ── project-wide (§11.213.1) ──────────────────────────────────────────
  final overrides = doc.settings.ruleOverrides.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final mutes =
      doc.ackedFindings.values
          .where((a) => a.targetFingerprint == kProjectWideFingerprint)
          .toList()
        ..sort((a, b) {
          final byRule = a.ruleId.compareTo(b.ruleId);
          return byRule != 0 ? byRule : a.id.v.compareTo(b.id.v);
        });
  final projectWide = <ProjectWideException>[
    for (final MapEntry(key: ruleId, value: o) in overrides)
      ProjectWideException(
        ruleId: ruleId,
        kind: ProjectWideKind.override,
        from: _catalogueSeverity(ruleId),
        to: severityLabel(o.severity),
        reason: o.reason,
        by: o.by,
        at: o.at,
      ),
    for (final m in mutes)
      ProjectWideException(
        ruleId: m.ruleId,
        kind: ProjectWideKind.mute,
        from: _catalogueSeverity(m.ruleId),
        to: severityLabel(m.demotedTo),
        reason: m.reason,
        by: m.by,
        at: m.at,
      ),
  ];

  // ── open and acknowledged, through the one grouping (§11.213.2-3) ─────
  final open = groupFindings(
    doc,
    findings,
    by: FindingGrouping.severity,
    includeAcknowledged: false,
  );
  final acknowledged = [
    for (final group in groupFindings(
      doc,
      findings,
      by: FindingGrouping.severity,
    ))
      for (final row in group.rows)
        if (row.isAcknowledged) row,
  ];

  // ── stale (§11.213.4): matched by `acknowledges`, never by hand ───────
  final stale =
      doc.ackedFindings.values
          .where((a) => a.targetFingerprint != kProjectWideFingerprint)
          .where((a) => !findings.any((f) => acknowledges(a, f)))
          .toList()
        ..sort((a, b) {
          final byAt = a.at.compareTo(b.at);
          return byAt != 0 ? byAt : a.id.v.compareTo(b.id.v);
        });

  return ExceptionsReport(
    projectWide: List.unmodifiable(projectWide),
    open: List.unmodifiable(open),
    acknowledged: List.unmodifiable(acknowledged),
    stale: List.unmodifiable(stale),
  );
}
