// packages/rackmate_ui/lib/src/canvas/staging_bin_overlay.dart
//
// M2: Staging Bin overlay panel for palette drag outside canvas bounds.
// When dragging from the palette and releasing outside any rack, items land
// in the staging bin instead of being discarded.

import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/canvas/drag_preview_controller.dart';

/// An overlay that appears when a palette drag is outside the canvas bounds,
/// indicating where the item will be placed (in the Staging Bin).
///
/// This is shown as a floating panel at the top of the canvas area.
class StagingBinOverlay extends StatelessWidget {
  /// Construct a staging bin overlay.
  const StagingBinOverlay({
    required this.controller,
    Key? key,
  }) : super(key: key);

  /// The drag controller providing device details and position information.
  final DragPreviewController controller;

  @override
  Widget build(BuildContext context) {
    // Show staging bin when phase is 'lifted' - this means the pointer is
    // outside the canvas (drag entered canvas → phase becomes 'dragging',
    // dragged back out → phase becomes 'lifted' again).
    //
    // The controller's phase == lifted implies we're outside canvas, so there's
    // no need to check cursor position against canvas bounds.
    if (!controller.isSourceEngaged ||
        controller.phase != DragPreviewPhase.lifted) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // Show the staging bin info near the top-left of canvas area
          // Position is relative to canvas top-left since we only show when
          // outside canvas bounds
          const anchorX = 16.0;
          const anchorY = 50.0;

          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.inventory_2,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Staging Bin',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (controller.displayName.isNotEmpty)
                        Text(
                          controller.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
