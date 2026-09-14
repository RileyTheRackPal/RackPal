// rackpal_ui/src/canvas/viewport_hud.dart — the zoom readout, Fit and
// Reset, shared by every canvas that has a viewport (`#898`, DR-169).
//
// ═══════════════════════════════════════════════════════════════════════
// EXTRACTED, NOT INVENTED, AND THAT IS THE WHOLE POINT
// ═══════════════════════════════════════════════════════════════════════
// This was `_ViewportHud`, private to `rack_canvas_screen.dart`, where it
// has shipped since M2. DR-169 §11.168.3 gives the Plan view a Fit
// control, and a second control doing the same job in a different shape
// would be two answers to one question: the rack says `140%` with a Fit
// and a Reset beside it, and somebody who has learned that on one canvas
// has learned it.
//
// The only parameter that differs is the tooltip, because a plan is not a
// rack and *"Fit the rack"* on the Plan tab would be copy naming a thing
// that is not there. `.okf/practices/copy-outlives-the-route-it-names.md`
// is the same lesson one artifact over.
import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// The zoom percentage, a Fit button and a Reset button.
///
/// [onFit] frames the content the host decides is the subject: the rack's
/// own box on the elevation, the underlay's pixel extent on a plan. This
/// widget does not know what is being framed and must not: the box is the
/// one fact the host has and it does not.
class ViewportHud extends StatelessWidget {
  const ViewportHud({
    required this.viewport,
    required this.onReset,
    required this.onFit,
    required this.fitTooltip,
    super.key,
  });

  final ViewportController viewport;
  final VoidCallback onReset;
  final VoidCallback onFit;

  /// What the Fit button says it will frame, e.g. `Fit the plan`.
  final String fitTooltip;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: viewport,
              builder: (context, _) => Text(
                '${(viewport.scale * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: fitTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Reset view (100%)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
