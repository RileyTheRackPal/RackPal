// The issues list (`#294`, M5-F1). docs/05 §8 calls it the DRC panel.
//
// ═══════════════════════════════════════════════════════════════════════
// IT DECIDES NOTHING ABOUT THE FINDINGS
// ═══════════════════════════════════════════════════════════════════════
// Grouping, filtering and order are `groupFindings` in core, because
// sheet `T0.02` and the device rollup chip need the same answers and
// three surfaces disagreeing about one document is the failure this
// splits to avoid. This file turns `FindingGroup`s into widgets and
// reports two gestures back: change the view, reveal a locus.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST CONSUMER OF `StatusMarker`, WHICH IS WHY IT EXISTS
// ═══════════════════════════════════════════════════════════════════════
// `status_marker.dart` says in its own header that nothing in the
// project drew a status marker yet, and that the DR-090 §11.89.6 gate was
// therefore vacuous and made structural instead. This is that consumer.
// Severity reaches the screen ONLY through `StatusMarker`, so every row
// carries a shape as well as a colour and survives the colour being
// removed.
//
// ═══════════════════════════════════════════════════════════════════════
// AN ACKNOWLEDGED ROW IS STILL A ROW
// ═══════════════════════════════════════════════════════════════════════
// docs/05 §8: *"the badge renders hollow, and the acknowledgement reason
// is in the tooltip"*. CR-019 makes acknowledgement a demotion, never a
// deletion, and CR-022 prints the reason on `T0.02` either way. So the
// row stays, visibly dealt with. Hiding it is a view filter the person
// chooses, and never something this panel does on their behalf.
//
// A REAL WIDGET LIST, NOT A CANVAS, for docs/05 §12.1's reason: every
// cell is a `Text`, so it is selectable and screen-reader navigable
// without a hand-written semantics layer.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/theme/status_marker.dart';

/// What the panel says when the document has no findings.
///
/// NOT "no issues found", which claims more than the product can: docs/05
/// §8 requires the copy be honest that *"this catches class errors, not
/// intent errors"*. Nothing here has been checked against intent.
const String kDrcNoFindings = 'Nothing to report from the checks that ran.';

/// What the panel says when findings exist but the filter hides them all.
///
/// A DIFFERENT SENTENCE FROM [kDrcNoFindings] on purpose. An empty list
/// under an active filter reads as a broken panel unless it says which
/// of the two empties it is.
const String kDrcAllFiltered = 'No findings match the current filter.';

/// The suffix a group header carries when some of its rows are dealt
/// with, e.g. "SIG-001 · 7 (3 acknowledged)".
String drcGroupCount(FindingGroup group) {
  final acked = group.acknowledgedCount;
  if (acked == 0) return '${group.length}';
  return '${group.length} ($acked acknowledged)';
}

/// The severities a finding can reach the list with, in the order the
/// filter row shows them.
///
/// `Severity.off` is absent by construction: `evaluateDocument` drops it
/// at step 2, so a chip for it would filter nothing and imply the list
/// might contain something it cannot.
const Set<Severity> kDrcFilterableSeverities = {
  Severity.error,
  Severity.warning,
  Severity.advisory,
};

/// The severity's marker, and the ONLY mapping from one to the other.
///
/// `Severity.off` never reaches a row: `evaluateDocument` drops it at
/// step 2, and a finding that is off is not a finding a person is being
/// shown. It maps to `nominal` rather than throwing so that a future
/// caller with a legitimate reason to draw one is not blocked by an
/// assertion written for a case that cannot happen here.
ConsoleStatus statusForSeverity(Severity severity) => switch (severity) {
  Severity.error => ConsoleStatus.critical,
  Severity.warning => ConsoleStatus.warning,
  Severity.advisory => ConsoleStatus.notice,
  Severity.off => ConsoleStatus.nominal,
};

/// The issues list.
class DrcPanel extends StatelessWidget {
  const DrcPanel({
    required this.groups,
    required this.grouping,
    required this.onGroupingChanged,
    this.severityFilter,
    this.onSeverityFilterChanged,
    this.includeAcknowledged = true,
    this.onIncludeAcknowledgedChanged,
    this.onReveal,
    this.hasAnyFindings = true,
    super.key,
  });

  /// Already grouped, filtered and ordered by `groupFindings`.
  final List<FindingGroup> groups;

  final FindingGrouping grouping;
  final ValueChanged<FindingGrouping> onGroupingChanged;

  /// Null means the severity filter is not applied; see `groupFindings`,
  /// where null and the empty set mean different things.
  final Set<Severity>? severityFilter;
  final ValueChanged<Set<Severity>>? onSeverityFilterChanged;

  final bool includeAcknowledged;
  final ValueChanged<bool>? onIncludeAcknowledgedChanged;

  /// Called with a finding's locus. `#294`: "every row navigates to the
  /// thing it is about". A row whose finding has no
  /// `primaryEntityId` does not call this, because there is no single
  /// thing to navigate to.
  final ValueChanged<Uuid>? onReveal;

  /// Whether the DOCUMENT has findings, as opposed to this filtered
  /// view. Distinguishes [kDrcNoFindings] from [kDrcAllFiltered].
  final bool hasAnyFindings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Controls(
          grouping: grouping,
          onGroupingChanged: onGroupingChanged,
          severityFilter: severityFilter,
          onSeverityFilterChanged: onSeverityFilterChanged,
          includeAcknowledged: includeAcknowledged,
          onIncludeAcknowledgedChanged: onIncludeAcknowledgedChanged,
        ),
        const Divider(height: 1),
        Expanded(
          child: groups.isEmpty
              ? _Empty(
                  message: hasAnyFindings ? kDrcAllFiltered : kDrcNoFindings,
                )
              : ListView(
                  children: [
                    for (final g in groups) ...[
                      _GroupHeader(group: g),
                      for (final row in g.rows)
                        _FindingTile(row: row, onReveal: onReveal),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.grouping,
    required this.onGroupingChanged,
    required this.severityFilter,
    required this.onSeverityFilterChanged,
    required this.includeAcknowledged,
    required this.onIncludeAcknowledgedChanged,
  });

  final FindingGrouping grouping;
  final ValueChanged<FindingGrouping> onGroupingChanged;
  final Set<Severity>? severityFilter;
  final ValueChanged<Set<Severity>>? onSeverityFilterChanged;
  final bool includeAcknowledged;
  final ValueChanged<bool>? onIncludeAcknowledgedChanged;

  @override
  Widget build(BuildContext context) {
    final filter = severityFilter;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Group by'),
          for (final g in FindingGrouping.values)
            ChoiceChip(
              label: Text(_groupingLabel(g)),
              selected: grouping == g,
              onSelected: (_) => onGroupingChanged(g),
            ),
          const SizedBox(width: 8),
          // `off` is not offered: it is not a severity a finding can
          // reach the list with, so a chip for it would filter nothing.
          for (final s in kDrcFilterableSeverities)
            FilterChip(
              avatar: StatusMarker(statusForSeverity(s), size: 12),
              label: Text(s.name),
              // A NULL FILTER SHOWS EVERY CHIP SELECTED, which is what
              // "not filtering" looks like to a person. Ticking one off
              // then hands `groupFindings` a real set.
              selected: filter == null || filter.contains(s),
              onSelected: onSeverityFilterChanged == null
                  ? null
                  : (on) {
                      // A null filter means "everything", so the first
                      // untick has to start from the full set rather
                      // than from an empty one, which would hide every
                      // severity the person did not just click.
                      final next = <Severity>{
                        ...(filter ?? kDrcFilterableSeverities),
                      };
                      if (on) {
                        next.add(s);
                      } else {
                        next.remove(s);
                      }
                      onSeverityFilterChanged!(next);
                    },
            ),
          if (onIncludeAcknowledgedChanged != null)
            FilterChip(
              label: const Text('Acknowledged'),
              selected: includeAcknowledged,
              onSelected: onIncludeAcknowledgedChanged,
            ),
        ],
      ),
    );
  }

  static String _groupingLabel(FindingGrouping g) => switch (g) {
    FindingGrouping.severity => 'Severity',
    FindingGrouping.rule => 'Rule',
    FindingGrouping.locus => 'Location',
  };
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final FindingGroup group;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            group.label,
            style: const TextStyle(fontWeight: kConsoleEmphasis),
          ),
        ),
        Text(drcGroupCount(group)),
      ],
    ),
  );
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.row, required this.onReveal});

  final FindingRow row;
  final ValueChanged<Uuid>? onReveal;

  @override
  Widget build(BuildContext context) {
    final finding = row.finding;
    final locus = finding.primaryEntityId;
    final reveal = onReveal;
    final tile = ListTile(
      dense: true,
      leading: StatusMarker(statusForSeverity(finding.severity)),
      title: Text(finding.message),
      subtitle: Text(
        row.isAcknowledged
            ? '${finding.ruleId} · acknowledged'
            : finding.ruleId,
      ),
      // A ROW WITH NO LOCUS IS NOT CLICKABLE, rather than clickable and
      // inert. There is no single thing to reveal, and a tap that looks
      // live and does nothing is worse than one that never offered.
      onTap: (locus == null || reveal == null) ? null : () => reveal(locus),
    );
    final reason = row.reason;
    if (reason == null) return tile;
    return Tooltip(message: reason, child: tile);
  }
}
