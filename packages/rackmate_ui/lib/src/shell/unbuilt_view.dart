// packages/rackmate_ui/lib/src/shell/unbuilt_view.dart
//
// The honest unbuilt-state panel: what a view looks like when it has not
// been built yet.
//
// WHY THIS EXISTS AT ALL. Two governing texts pull in opposite directions
// and this widget is where they are reconciled.
//
//   * docs/09-roadmap.md M1, "What M1 deliberately lacks": "No wiring, no
//     schedule, no schematic ... The app says so: an empty Schedule tab that
//     explains it is coming is a lie, so the tab does not exist yet."
//   * docs/05-schematic-editor.md §12 (line 780): "The v1 tab strip shows
//     three tabs: Rack, Schematic, Schedule."
//
// The two agree on the thing that actually matters and disagree only about
// furniture. What M1 forbids is a view that LOOKS finished and is empty —
// a schedule table with no rows says "you have not wired anything", which
// is false when the truth is "this app cannot wire anything". What §12
// fixes is the strip. So the strip keeps three tabs and the two unbuilt
// ones say, in the first line the user reads, that they are not built.
//
// NO TAB RENDERS THIS ANY MORE, AND IT IS KEPT ANYWAY. The Schedule
// stopped being unbuilt at M2-B and the Schematic at M2-E, so the app has
// no `UnbuiltView` on screen. It is kept because the RULING below is what
// this file is, not the widget: the next view that ships before its
// pipeline does — CR-071's Rear Panel is the named candidate, and it is
// v1.1 — says so through this, rather than through a fresh panel that
// re-decides whether an empty view may carry a button.
// `test/shell/unbuilt_view_test.dart` still holds the line on that
// question, so the widget is exercised rather than merely present.
//
// THIS IS THE G4 RULE APPLIED TO A WHOLE VIEW. "Never fabricate data. Show
// `unknown`" (G4, CR-114) is normally about a weight or a VA draw. The same
// rule decides this: the view that shipped before this panel drew ONE
// hardcoded symbol with ports labelled `Pin1`/`Pout1` that corresponded to
// no device in any document, over a "New Wire" button wired to
// `setState(() {})`. That is a fabricated drawing, and it cost twelve
// consecutive "fix:" commits from an engineer who reasonably assumed there
// was a pipeline behind it. An unbuilt view that says so costs nobody
// anything.
//
// WHAT THIS WIDGET MAY NEVER CONTAIN: an actionable control. No button, no
// field, no menu, nothing tappable — because every one of those would be a
// promise. `test/shell/unbuilt_view_test.dart` walks the rendered semantics
// subtree and fails if any node offers `SemanticsAction.tap`, which is the
// assertion that actually holds the line here.

import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/theme/console_theme.dart';

/// A view that has not been built, said plainly.
///
/// Renders a milestone badge, the view's name, what is absent, and why the
/// tab exists anyway. It is deliberately inert: see the file header.
final class UnbuiltView extends StatelessWidget {
  /// Creates the unbuilt-state panel for [viewName].
  const UnbuiltView({
    required this.viewName,
    required this.milestone,
    required this.absent,
    required this.why,
    required this.reference,
    super.key,
  });

  /// The view's name as the tab strip spells it — `Schematic`, `Schedule`.
  final String viewName;

  /// The roadmap milestone that builds it, e.g. `M2`. Named, never dated:
  /// a date would be a claim.
  final String milestone;

  /// What does not exist. States absence, never a timeline.
  final String absent;

  /// Why the tab is in the strip even so.
  final String why;

  /// The governing documents, so the next reader starts where this ends.
  final String reference;

  /// The panel's heading. One definition, so the widget and its tests
  /// cannot spell it differently.
  String get heading => '$viewName — not built';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    return Semantics(
      container: true,
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.construction_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MilestoneBadge(milestone: milestone),
                  const SizedBox(height: 12),
                  Text(
                    heading,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(absent, style: bodyStyle),
                  const SizedBox(height: 12),
                  Text(why, style: bodyStyle),
                  const SizedBox(height: 24),
                  Text(
                    reference,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The `NOT BUILT · M2` pill. Outlined rather than filled: a filled chip in
/// a container colour reads as a status the app is reporting, and this is
/// not a status, it is an absence.
final class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.milestone});

  final String milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'NOT BUILT · $milestone',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: kConsoleEmphasis,
          ),
        ),
      ),
    );
  }
}
