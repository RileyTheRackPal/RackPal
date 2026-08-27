// docs/04 §9's progressive disclosure: "three one-time coach marks, not a
// tour: one on first placement, one on first finding, and one on the first
// rack→schematic switch (CR-104, AC-048)."
//
// ═══════════════════════════════════════════════════════════════════════
// ONE OF THE THREE IS BUILT, AND THE OTHER TWO ARE NAMED, NOT WRITTEN
// ═══════════════════════════════════════════════════════════════════════
// [kCoachMarkSchematicFilter] is the third. The ids for the first two are
// not declared here — a constant for a mark nothing shows is a claim that
// it exists, and this file would then be the thing that has to be
// re-checked when somebody wonders why `firstPlacement` never fires. The
// STORE is a set of ids precisely so they cost nothing when they land.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THE THIRD ONE SAYS, AND WHY IT IS NOT OPTIONAL COPY
// ═══════════════════════════════════════════════════════════════════════
// docs/04:468: it "points at the **domain filter bar** and reads
// `Filter to a domain to draw the wires` — under DR-001 the filter is the
// primary way a user sees routed links, not a fallback for a crowded
// sheet, so it is taught the first time the Schematic is opened rather
// than discovered later."
//
// That last clause is the ruling on WHEN, and it is narrower than "the
// first rack→schematic switch" reads: the trigger is the first time the
// sheet is SHOWN, whichever tab the user came from. In practice they came
// from the rack — it is the tab the app opens on — so the two readings
// coincide today; docs/04 is the one implemented because it is the one
// that says what the user experiences.
//
// A SHEET WITH NOTHING TO FILTER IS NOT A TEACHABLE MOMENT. The mark
// explains how to SEE wires, and a document with no cables has none to
// see, so the host is expected to hold it back until there is something
// for the filter to do. That decision is the shell's (it owns "first"),
// not this widget's — see `app_shell.dart`.
import 'package:flutter/material.dart';

/// AC-048's third mark: the domain filter, taught on the first sheet.
const String kCoachMarkSchematicFilter = 'schematic.domainFilter';

/// docs/04:468, verbatim. The one sentence the mark shows.
const String kCoachMarkSchematicFilterText =
    'Filter to a domain to draw the wires';

/// Why the sentence above is worth acting on — DR-001's default render,
/// said in the words of what is on screen rather than by ruling id.
const String kCoachMarkSchematicFilterDetail =
    'Cables render as pairs of net labels until you narrow the sheet. '
    'Pick a domain above — or hold Alt over a symbol — and its wires are '
    'drawn.';

/// A one-time hint anchored under the thing it teaches.
///
/// A BANNER RATHER THAN A FLOATING BUBBLE WITH AN ARROW, deliberately: it
/// occupies real layout under its subject, so it cannot cover the control
/// it is pointing at, cannot be positioned against a widget that has
/// moved, and cannot survive as an `Overlay` entry after the screen that
/// owns it is gone. The caret at its top edge is what does the pointing.
///
/// It is DISMISSIBLE AND SELF-RETIRING: [onDismiss] fires from the button
/// and is also what the host calls when the user does the taught thing,
/// so a user who filters a domain without reading it is not shown it
/// again. Both routes go through the same callback, so there is one
/// definition of "seen".
final class CoachMark extends StatelessWidget {
  const CoachMark({
    required this.headline,
    required this.detail,
    required this.onDismiss,
    this.caretInset = 24,
    super.key,
  });

  final String headline;
  final String detail;
  final VoidCallback onDismiss;

  /// How far from the left edge the caret points. Defaults to a position
  /// under the first chip of a filter bar.
  final double caretInset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$headline. $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: caretInset),
            child: CustomPaint(
              size: const Size(16, 8),
              painter: _CaretPainter(scheme.secondaryContainer),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            color: scheme.secondaryContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: text.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onDismiss, child: const Text('Got it')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}
