// rackpal_ui/src/canvas/plan/plan_pin_bubble.dart — the hovered mark's
// designator (`#902`, DR-169 §11.168.7).
//
// ═══════════════════════════════════════════════════════════════════════
// A HOVER AND NOT A LABEL BESIDE EVERY MARK, WHICH IS THE RULING
// ═══════════════════════════════════════════════════════════════════════
// §11.168.7: sixty drops in one room is sixty labels drawn over somebody
// else's drawing. Colour answers *what kind of thing is this* at a
// glance; this answers *which one* on demand.
//
// ═══════════════════════════════════════════════════════════════════════
// CHROME, NOT SCENE, AND THE DIFFERENCE IS WHAT PRINTS
// ═══════════════════════════════════════════════════════════════════════
// `plan_sheet.dart` SPLICES the plan scene, so a designator emitted into
// it would appear on `T1.01` for whichever mark the pointer happened to
// be over when the export ran. docs/15 §7's printed callout is `PLAN-H`'s
// and is a different thing with a different lifetime.
//
// ═══════════════════════════════════════════════════════════════════════
// ITS OWN FILE BECAUSE `plan_canvas_screen.dart` IMPORTS `widgets`
// ═══════════════════════════════════════════════════════════════════════
// That file takes `package:flutter/widgets.dart` and not `material.dart`,
// which `plan_outline.dart` already respects by keeping the mode chip
// over here. A `Material` dragged into the canvas file to save one file
// would quietly widen what a canvas may depend on.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// The hovered mark's designator, floating just above it.
class PlanPinBubble extends StatelessWidget {
  const PlanPinBubble({
    required this.label,
    required this.at,
    required this.viewport,
    required this.turn,
    required this.radiusPt,
    super.key,
  });

  /// A stable handle, so a case can find the bubble without matching on
  /// the designator it happens to be showing.
  static const Key bubbleKey = ValueKey('plan-pin-bubble');

  final String label;

  /// The mark's own position, in the underlay's pixel space.
  final PxPt at;

  final ViewportController viewport;

  /// The plan's turn, which maps every stored pixel above into the scene
  /// the viewport draws (DR-184 §11.183.2). REQUIRED, on `#904`'s lesson:
  /// a defaulted identity would draw this a quarter turn away from the
  /// picture on any turned plan, and nothing would say so.
  final PlanTurn turn;

  /// The mark's radius in screen points, so the bubble clears it.
  ///
  /// **SCREEN POINTS AND NOT SCENE UNITS**, which stopped being the same
  /// number at `#910` (DR-183): above the crossover the mark grows with
  /// the zoom, so a caller handing over the floor constant would park this
  /// label inside the mark it names.
  final double radiusPt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // POSITIONED FROM THE LIVE VIEWPORT, NOT FROM WHERE THE POINTER IS.
    // The bubble names a MARK, so it sits on the mark: a label that
    // trailed the cursor would drift off the thing it names while the
    // person moves to read it. Mapping through the viewport is also what
    // keeps it right at every zoom, which is `planMarkerSceneRadius`'s own
    // rule one layer up.
    final screen = viewport.sceneToScreen(turn.toScene(at));
    return Positioned(
      key: bubbleKey,
      left: screen.x,
      top: screen.y - radiusPt - 26,
      child: FractionalTranslation(
        // `left` is the mark's centre, so the bubble is pulled back by
        // half its own width rather than being laid out from its corner.
        translation: const Offset(-0.5, 0),
        // IGNORES THE POINTER, or the bubble would sit between the person
        // and the mark it describes: hovering would show it, and it would
        // then swallow the click that hover was leading up to.
        child: IgnorePointer(
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
