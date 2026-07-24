// packages/rackmate_ui/lib/src/canvas/staging_bin_overlay.dart
//
// M2: Staging Bin overlay panel for palette drag outside canvas bounds.
// When dragging from the palette and releasing outside any rack, items land
// in the staging bin instead of being discarded.

import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/canvas/drag_preview_controller.dart';

/// An overlay that appears when a palette drag exits the canvas bounds,
/// indicating where the item will be placed (in the Staging Bin).
///
/// This is shown as a floating panel at the top of the canvas area.
class StagingBinOverlay extends StatelessWidget {
  /// Construct a staging bin overlay.
  const StagingBinOverlay({
    required this.controller,
    required this.canvasSize,
    Key? key,
  }) : super(key: key);

  /// The drag controller providing device details and position information.
  final DragPreviewController controller;

  /// The size of the canvas area, used to determine if cursor is outside.
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    // Only show when dragging but not in a valid drop position (outside canvas)
    // This occurs when phase is lifted and cursor is outside canvas bounds
    final cursor = controller.cursorGlobal;
    if (cursor == null || !controller.isSourceEngaged) {
      return const SizedBox.shrink();
    }

    // Check if cursor is outside the canvas bounds
    final inCanvas = cursor.dx >= 0 && 
                     cursor.dy >= 0 && 
                     cursor.dx <= canvasSize.width &&
                     cursor.dy <= canvasSize.height;
    
    if (inCanvas) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Position the staging bin indicator near the top of the canvas area
    // when outside bounds, showing where items will be placed
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // Show the staging bin info near the top-left of canvas area
          final anchorX = 16.0;
          final anchorY = 50.0;

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