// The rack metrics strip: a horizontal bar at the bottom of the canvas
// showing RU count, weight, VA, and outlet counts - docs/04-rack-editor.md
// §3.6's "Chip Strip" (deferred from M1 to make room for header stepper).
//
// This is NOT yet wired to the document model - it's a UI-only placeholder
// that shows fixed demo values until the validation engine (M2) computes
// real metrics from the rack occupants.
import 'package:flutter/material.dart';

/// A compact horizontal bar showing rack summary metrics: RU usage, weight,
/// VA draw, and outlet counts. The actual metrics computation is deferred to
/// M2's validation engine; this widget shows fixed demo values for now.
class RackMetricsRow extends StatelessWidget {
  /// Constructs a metrics row with the given values. Use zero or null to hide
  /// that metric entirely (e.g., if no power outlets exist, don't show VA).
  const RackMetricsRow({
    super.key,
    this.ruCount = 0,
    this.ruFree = 0,
    this.weightKg = 0.0,
    this.vaDraw = 0,
    this.outletCount = 0,
  });

  /// Total rack RU capacity (e.g., 42).
  final int ruCount;

  /// How manyRU are free.
  final int ruFree;

  /// Rack weight in kilograms.
  final double weightKg;

  /// Total VA draw of all devices.
  final int vaDraw;

  /// Number of power outlets in the rack.
  final int outletCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 128), width: 1.0)),
      ),
      child: Row(
        children: [
          _buildMetricChip(
            context,
            label: '${ruCount - ruFree}/${ruCount}U',
            subLabel: '$ruFree free',
            color: colors.primaryContainer,
          ),
          if (weightKg > 0)
            _buildMetricChip(
              context,
              label: '${_formatWeight(weightKg)}',
              subLabel: 'kg',
              color: colors.secondaryContainer,
            ),
          if (vaDraw > 0)
            _buildMetricChip(
              context,
              label: '$vaDraw VA',
              subLabel: 'draw',
              color: colors.tertiaryContainer,
            ),
          if (outletCount > 0)
            _buildMetricChip(
              context,
              label: '$outletCount outlets',
              subLabel: 'power',
              color: colors.errorContainer,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String subLabel,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              subLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 191),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWeight(double kg) {
    // Round to 1 decimal place, strip trailing zero if whole number
    final formatted = kg.toStringAsFixed(1);
    return formatted.endsWith('.0') ? '${kg.toInt()}' : formatted;
  }
}