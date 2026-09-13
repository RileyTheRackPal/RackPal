// The host `DrcPanel` never had (`#847`, DR-133 §11.132).
//
// ═════════════════════════════════════════════════════════════════════
// THIS WAS IN docs/04 §1's LAYOUT TABLE THE WHOLE TIME
// ═════════════════════════════════════════════════════════════════════
// Not a panel somebody had to design. A row that was written and never
// built:
//
//   Validation drawer | 28 px | 28 / 320 | Auto-expands to 180 px once,
//   on the first error per session, never again.
//
// `#847` was filed saying the mount point was an open shell decision and
// listing three questions. All three were already answered, and one of
// the answers is better than the keybinding that was about to be
// proposed: **it opens by itself**, because a person who does not know
// the validation engine exists cannot press a key to find it.
//
// Everything M5-F built has been real, tested and unreachable since it
// shipped, while a closed chapter recorded that a user could see
// findings. This file is the path a person walks.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/validation/drc_panel.dart';

/// The collapsed height, and the shell's own floor for this band.
const double kDrawerCollapsedHeight = 28;

/// What it opens to on the first error, per docs/04 §1.
const double kDrawerAutoHeight = 180;

/// The maximum a person can drag it to.
const double kDrawerMaxHeight = 320;

/// What the collapsed rail says when the document is clean.
///
/// NOT AN EMPTY RAIL. A 28 px strip with nothing in it reads as chrome,
/// and the point of the drawer is that the engine is visible without
/// being loud. "No issues" is a result; blank is a shrug.
const String kDrawerClean = 'No issues';

/// The tooltip on the rail, naming the key that re-runs the check.
const String kDrawerRecheckHint = 'Re-check (F7)';

/// A one-line summary of [findings] for the collapsed rail.
///
/// COUNTS BY RESOLVED SEVERITY, and says the words rather than only
/// colouring a dot: PAL-1's argument is that hue is never the only
/// channel, and this rail is 28 px with no room for a legend.
String drawerSummary(List<Finding> findings) {
  if (findings.isEmpty) return kDrawerClean;
  var errors = 0;
  var warnings = 0;
  var advisories = 0;
  for (final f in findings) {
    switch (f.severity) {
      case Severity.error:
        errors++;
      case Severity.warning:
        warnings++;
      case Severity.advisory:
        advisories++;
      case Severity.off:
        break;
    }
  }
  final parts = <String>[
    if (errors > 0) '$errors error${errors == 1 ? '' : 's'}',
    if (warnings > 0) '$warnings warning${warnings == 1 ? '' : 's'}',
    // "advisories", NOT "advisorys", and NOT the unreachable
    // `else if (advisories > 1)` this was first written as: the `> 0`
    // limb catches every case, so three advisories would have printed
    // "3 advisory". `validation_drawer_test.dart` prints the whole string
    // rather than matching a substring, on this repository's own rule
    // about twelve green assertions over a line reading "1 ports".
    if (advisories > 0) '$advisories advisor${advisories == 1 ? 'y' : 'ies'}',
  ];
  // Every severity can be filtered to nothing while findings remain, so
  // an all-`off` document still has to say something true.
  return parts.isEmpty ? kDrawerClean : parts.join(' · ');
}

/// Whether [findings] should make the drawer open itself.
///
/// ═══════════════════════════════════════════════════════════════════
/// RESOLVED SEVERITY, NOT THE CATALOGUE'S DEFAULT (DR-133 §11.132.3)
/// ═══════════════════════════════════════════════════════════════════
/// docs/04 says *"on the first error per session"* and does not say what
/// an error IS at that moment. `RuleOverride` and `AckedFinding` both
/// move severities, and a project that has demoted a rule has said it
/// does not want to be stopped by it. Opening a drawer for it anyway
/// would overrule a decision the user wrote down, which is RJ-006's whole
/// reason for keeping the acknowledgement machinery.
///
/// `evaluateDocument` already resolves both, so this reads what a person
/// would actually see.
bool drawerShouldAutoOpen(List<Finding> findings) =>
    findings.any((f) => f.severity == Severity.error);

/// The bottom band of the shell: a 28 px rail that hosts [DrcPanel].
///
/// STATEFUL FOR ONE REASON, the once-per-session latch. Height and
/// expansion are the caller's, because the shell owns its own layout and
/// persists panel sizes in app settings (docs/04 §1); the latch is this
/// widget's because it is about what has been SHOWN, which nothing else
/// can observe.
class ValidationDrawer extends StatefulWidget {
  const ValidationDrawer({
    required this.findings,
    required this.groups,
    required this.grouping,
    required this.onGroupingChanged,
    required this.expanded,
    required this.onExpandedChanged,
    this.height = kDrawerAutoHeight,
    this.onHeightChanged,
    this.onReveal,
    this.severityFilter,
    this.onSeverityFilterChanged,
    this.includeAcknowledged = true,
    this.onIncludeAcknowledgedChanged,
    this.onAcknowledge,
    this.onWithdraw,
    this.onRemedy,
    super.key,
  });

  /// Every finding, severity resolved and acknowledgements applied.
  final List<Finding> findings;

  /// The same list, grouped and filtered for the panel. Passed rather
  /// than computed here so the shell keeps one source of both.
  final List<FindingGroup> groups;

  final FindingGrouping grouping;
  final ValueChanged<FindingGrouping> onGroupingChanged;

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Clamped to `[kDrawerCollapsedHeight, kDrawerMaxHeight]` on use, so a
  /// stale persisted width from a future build cannot make the drawer
  /// eat the canvas.
  final double height;
  final ValueChanged<double>? onHeightChanged;

  /// Takes the locus id: the panel reveals an ENTITY, not a finding.
  final ValueChanged<Uuid>? onReveal;

  /// The severity chips and the `Acknowledged` toggle (`#875`).
  ///
  /// **THE WHOLE FILTER WAS BUILT AND UNREACHABLE.** `DrcPanel` renders
  /// both controls, `groupFindings` takes `severities` and
  /// `includeAcknowledged`, and this widget passed neither the state nor
  /// its callbacks, so the panel drew controls that could not move. Same
  /// defect as the three callbacks below, in the same feature, found by
  /// the same gate.
  final Set<Severity>? severityFilter;
  final ValueChanged<Set<Severity>>? onSeverityFilterChanged;
  final bool includeAcknowledged;
  final ValueChanged<bool>? onIncludeAcknowledgedChanged;

  final ValueChanged<Finding>? onAcknowledge;
  final ValueChanged<FindingRow>? onWithdraw;
  final ValueChanged<Finding>? onRemedy;

  @override
  State<ValidationDrawer> createState() => _ValidationDrawerState();
}

class _ValidationDrawerState extends State<ValidationDrawer> {
  /// ONCE PER SESSION, NEVER AGAIN, which is the spec's own word. It is
  /// set the first time an error is present and is never cleared: a user
  /// who collapses the drawer has answered it, and re-opening on the next
  /// rebuild would be an argument rather than a notification.
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _maybeAutoOpen();
  }

  @override
  void didUpdateWidget(ValidationDrawer old) {
    super.didUpdateWidget(old);
    _maybeAutoOpen();
  }

  void _maybeAutoOpen() {
    if (_autoOpened) return;
    if (!drawerShouldAutoOpen(widget.findings)) return;
    _autoOpened = true;
    if (widget.expanded) return;
    // AFTER THE FRAME, because this runs from `initState`/`didUpdateWidget`
    // and the callback rebuilds the shell above us.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpandedChanged(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final height = widget.expanded
        ? widget.height.clamp(kDrawerCollapsedHeight, kDrawerMaxHeight)
        : kDrawerCollapsedHeight;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            _Rail(
              summary: drawerSummary(widget.findings),
              expanded: widget.expanded,
              onToggle: () => widget.onExpandedChanged(!widget.expanded),
              // DRAGGING UP GROWS IT, so `delta.dy` is subtracted: the
              // drawer's top edge moves against the gesture. docs/04 §1
              // makes it resizable and the range is enforced here rather
              // than trusted from the caller.
              onDragHeight: widget.expanded && widget.onHeightChanged != null
                  ? (dy) => widget.onHeightChanged!(
                      (widget.height - dy).clamp(
                        kDrawerCollapsedHeight,
                        kDrawerMaxHeight,
                      ),
                    )
                  : null,
            ),
            if (widget.expanded)
              Expanded(
                child: DrcPanel(
                  groups: widget.groups,
                  grouping: widget.grouping,
                  onGroupingChanged: widget.onGroupingChanged,
                  hasAnyFindings: widget.findings.isNotEmpty,
                  severityFilter: widget.severityFilter,
                  onSeverityFilterChanged: widget.onSeverityFilterChanged,
                  includeAcknowledged: widget.includeAcknowledged,
                  onIncludeAcknowledgedChanged:
                      widget.onIncludeAcknowledgedChanged,
                  onReveal: widget.onReveal,
                  onAcknowledge: widget.onAcknowledge,
                  onWithdraw: widget.onWithdraw,
                  onRemedy: widget.onRemedy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 28 px strip, which is all a clean document ever shows.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.summary,
    required this.expanded,
    required this.onToggle,
    this.onDragHeight,
  });

  final String summary;
  final bool expanded;
  final VoidCallback onToggle;

  /// Null while collapsed: there is nothing to resize, and a resize
  /// cursor over a 28 px rail that cannot move is a lie about what the
  /// pointer will do.
  final ValueChanged<double>? onDragHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rail = InkWell(
      onTap: onToggle,
      child: Tooltip(
        message: kDrawerRecheckHint,
        child: SizedBox(
          height: kDrawerCollapsedHeight,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(
                expanded ? Icons.expand_more : Icons.expand_less,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                summary,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: kConsoleEmphasis,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onDragHeight == null) return rail;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) => onDragHeight!(d.delta.dy),
        child: rail,
      ),
    );
  }
}
