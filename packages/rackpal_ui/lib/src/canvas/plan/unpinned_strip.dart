// rackpal_ui/src/canvas/plan/unpinned_strip.dart — the strip along the
// bottom of the Plan editor (docs/15 §6, DR-140 §11.139, DR-142 §11.141,
// PLAN-E/4).
//
// ═══════════════════════════════════════════════════════════════════════
// IT RENDERS A DERIVATION, IT DOES NOT CONTAIN ONE
// ═══════════════════════════════════════════════════════════════════════
// `structure_editor_screen.dart` opens with that rule and this file keeps
// it. Every decision about WHAT is listed lives in
// `derived/unpinned_carriers.dart`, where it is one line somebody can
// mutate: what "unpinned" means, what an underlay with no location
// filters, and which of a device's two location fields is its room. A
// widget that walked `doc.devices` itself would be a second place those
// questions get answered, and the second answer is the one that drifts.
//
// ═══════════════════════════════════════════════════════════════════════
// THE COUNT IS THE POINT, NOT THE DECORATION
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6: this strip "is the difference between a plan that is trusted
// and a plan that is 80% complete without saying so". So the number is
// rendered even when the rows are scrolled out of sight, and the SECOND
// number is rendered beside it: G4/CR-114 requires a rollup to report what
// it could not place rather than absorb it, and `unlocatedCount` is
// exactly that. A strip showing rows without it would be the `0 pathways`
// status bar with a nicer font.
//
// ═══════════════════════════════════════════════════════════════════════
// COPY AND ORDER ARE THE USER'S, AND THIS IS A DEFAULT
// ═══════════════════════════════════════════════════════════════════════
// Canon §11.139.6 leaves the strip's order and whether a rack row is drawn
// differently open, and DR-142 §11.141.6 ships a default rather than a
// blank: the order is the derivation's (rack first, PLN-003's reason), and
// a rack row here is distinguished only by leading. The three strings
// below are named constants for the same reason `kPinArmIdleLabel` is:
// changing on-screen wording should be one edit in one place, not a
// search through a build method.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the strip says when there is nothing left to put on the plan.
///
/// NOT "everything is pinned", which is a claim about the project, and
/// this strip only ever knew about one plan's room (DR-142 §11.141.2).
const String kUnpinnedStripEmptyLabel = 'Nothing left to pin';

/// The count, as a suffix: `4 not on the plan`.
const String kUnpinnedStripCountSuffix = 'not on the plan';

/// The unknown count, as a suffix: `2 with no location`.
///
/// Its own sentence rather than a parenthetical on the first, because the
/// two answer different questions and a reader who merges them gets a
/// total that is wrong in the flattering direction.
const String kUnpinnedStripUnlocatedSuffix = 'with no location';

/// The Plan editor's unpinned strip: everything that could be on this plan
/// and is not, with the count that keeps the plan honest.
final class UnpinnedStrip extends StatelessWidget {
  const UnpinnedStrip({required this.carriers, this.onArmDrag, super.key});

  /// From `unpinnedCarriersFor`. Passed in rather than derived here: see
  /// the file header.
  final UnpinnedCarriers carriers;

  /// Fires on a plain pointer-down over a row, handing the host the raw
  /// event so it can decide whether the gesture ever becomes a drag.
  ///
  /// SAME SHAPE AS `DevicePalettePanel.onArmDrag`, and for the same
  /// reason: the pointer starts here and ends over the canvas, so no
  /// single `Listener` sees both halves and the host tracks it through the
  /// global router. Null means the rows are readable and not draggable,
  /// which is what a host with no canvas to drop on should pass.
  final void Function(UnpinnedCarrier row, PointerDownEvent event)? onArmDrag;

  /// A stable handle for tests. The strip legitimately renders the same
  /// designator a canvas label does, so a bare text finder cannot say
  /// which one it found.
  static const Key stripKey = ValueKey('unpinned-strip');

  /// The key on one row, so a case can grab the row it means rather than
  /// `byType().first`.
  static Key rowKey(Uuid entityId) => ValueKey('unpinned-row-${entityId.v}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: stripKey,
      color: scheme.surfaceContainerHighest,
      child: SizedBox(
        // 64 AND NOT 56, WHICH A TEST ESTABLISHED RATHER THAN AN EYE. A
        // row is two lines when the carrier has a name, and 56 leaves 28
        // for them after the list's padding and the chip's: the `Column`
        // overflowed by 6 pixels the first time a named row was rendered.
        // The strip's height is the constraint the rows sit inside, so
        // this number and the two paddings below are one decision.
        height: 64,
        child: Row(
          children: [
            // BOUNDED, so the counts shrink and the list keeps a width.
            // Unbounded, this block takes its natural width first and the
            // `Expanded` beside it gets whatever is left, which goes
            // negative on a narrow window: `RenderFlex overflowed by 44
            // pixels on the right` at 220px, found by the same case that
            // found the vertical one. The two counts ellipsize rather
            // than wrap, because a wrapped count is a third line in a
            // fixed-height strip and that is the vertical overflow again.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Counts(carriers: carriers),
              ),
            ),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: carriers.rows.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) =>
                    _Row(row: carriers.rows[i], onArmDrag: onArmDrag),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one number the strip exists for, and the one G4 requires beside it.
class _Counts extends StatelessWidget {
  const _Counts({required this.carriers});

  final UnpinnedCarriers carriers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          carriers.count == 0
              ? kUnpinnedStripEmptyLabel
              : '${carriers.count} $kUnpinnedStripCountSuffix',
          style: theme.textTheme.labelLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // ONLY WHEN THERE IS ONE. A permanent "0 with no location" trains
        // the reader to stop seeing the line, which is the opposite of
        // what a G4 unknown count is for.
        if (carriers.unlocatedCount > 0)
          Text(
            '${carriers.unlocatedCount} $kUnpinnedStripUnlocatedSuffix',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// One draggable row: what it is, and what it is called.
class _Row extends StatelessWidget {
  const _Row({required this.row, this.onArmDrag});

  final UnpinnedCarrier row;
  final void Function(UnpinnedCarrier row, PointerDownEvent event)? onArmDrag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = row.name;
    final chip = Container(
      key: UnpinnedStrip.rowKey(row.entityId),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.designator, style: theme.textTheme.labelMedium),
          // NOTHING RATHER THAN AN EMPTY LINE when the carrier has no
          // name field. An `Outlet` has a designation and no name, and
          // G4's absent key is the model saying so; a blank second line
          // would draw the same hole the strip exists to close.
          if (name != null && name.isNotEmpty)
            Text(
              name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    final arm = onArmDrag;
    if (arm == null) return chip;
    // `Listener` NEVER ENTERS THE GESTURE ARENA, so it cannot interfere
    // with anything else this subtree wants from the same pointer. Same
    // mechanism as the device palette's arm, verbatim.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => arm(row, event),
      child: chip,
    );
  }
}
