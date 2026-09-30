// packages/rackpal_ui/lib/src/canvas/staging_bin_overlay.dart
//
// docs/04-rack-editor.md §3.1's escape hatch: "Dragging outside any rack
// shows the ghost at 40 % with a `Release to add to Staging Bin` chip;
// dropping there creates a `StagedPlacement` (CR-031, CR-032)."
//
// THIS CHIP SAYS THAT SENTENCE NOW (DR-205, `#961`), AND FOR MONTHS IT
// DELIBERATELY DID NOT.
//
// The Staging Bin is `StagedPlacement` (CR-032), a query rather than an
// entity. Until DR-205 the build had no command that produced one, nothing
// that listed the devices in it and no return chip, so releasing here was
// a no-op and this chip read "Staging Bin — not in this build": a chip
// promising "Release to add to Staging Bin" over a release that added
// nothing is the failure docs/09-roadmap.md M1 names, "an empty Schedule
// tab that explains it is coming is a lie". The bin ships with DR-205 (a
// strip under the canvas, `staging_bin_strip.dart`), so the copy changed
// and, as this comment always said it would, nothing else about the chip.
//
// SHAPE NOTES, both of them defects this file shipped with:
//  * It is a `Positioned` chip anchored to the drag cursor, sitting just
//    below the `_CursorCard`. It used to be inserted into the ROOT overlay
//    with no `Positioned` at all, so its `Material` stretched to fill the
//    whole window — a full-screen elevated panel flashing over the app
//    every time a drag left the canvas. The two `anchorX`/`anchorY`
//    constants that were meant to place it were computed and never used
//    (the analyzer reported both as `unused_local_variable`).
//  * It listens to the controller for the cursor position, so it follows
//    the pointer rather than sitting at a fixed corner.

import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/canvas/drag_preview_controller.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// The chip shown while a palette drag is outside every rack (docs/04
/// §3.1). Read the file header before changing its copy: the wording is
/// load-bearing, not filler.
class StagingBinOverlay extends StatelessWidget {
  /// Construct a staging bin overlay.
  const StagingBinOverlay({required this.controller, super.key});

  /// A stable handle for tests and for anything that needs to distinguish
  /// this chip's copy of the dragged device's name from the palette row's
  /// and the cursor card's — three widgets legitimately render the same
  /// string during one drag, and a bare text count cannot tell them apart.
  static const Key chipKey = ValueKey('staging-bin-chip');

  /// Offset from the drag cursor, clearing the 40px `_CursorCard` that
  /// occupies `cursor + (16, 16)` during the same phase.
  static const Offset cursorOffset = Offset(16, 64);

  /// The drag controller providing device details and position information.
  final DragPreviewController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // `lifted` is the phase that means "armed, past the 4px slop, and
          // NOT over the canvas": a drag that enters the canvas becomes
          // `dragging`, and one dragged back out returns to `lifted`. So
          // the phase alone answers "is the pointer outside?" — there is no
          // second bounds check to keep in sync with the screen's.
          if (!controller.isSourceEngaged ||
              controller.phase != DragPreviewPhase.lifted) {
            return const SizedBox.shrink();
          }
          final cursor = controller.cursorGlobal;
          if (cursor == null) return const SizedBox.shrink();

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final name = controller.displayName;

          return Stack(
            children: [
              Positioned(
                left: cursor.dx + cursorOffset.dx,
                top: cursor.dy + cursorOffset.dy,
                child: Material(
                  key: chipKey,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surfaceContainerHigh,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Release to add to the Staging Bin',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: kConsoleEmphasis,
                                ),
                              ),
                              if (name.isNotEmpty)
                                Text(
                                  '$name will wait there, off the rack.',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
