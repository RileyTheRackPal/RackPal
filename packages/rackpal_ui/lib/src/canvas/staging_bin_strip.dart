// The Staging Bin, as a strip under the rack canvas (DR-205, CR-032,
// docs/04 §1's layout sketch). `#961`, Chapter `#963`.
//
// ═══════════════════════════════════════════════════════════════════════
// SHOWN WHILE SOMETHING IS IN IT, AND ONLY THEN
// ═══════════════════════════════════════════════════════════════════════
// docs/04 draws `STAGING BIN (2)` under the canvas with the devices as
// chips. An empty bin is not drawn at all: a permanent strip reading
// "empty" spends canvas height saying nothing, and the bin fills only by a
// person's act (a drop off the rack, `U`, a shelf deleted, a rack shrunk),
// each of which says where the device went in the status line.
//
// Every chip is a DEVICE, not a template: it keeps its designator, its
// ports and its links (CR-032's "wiring preservation"), so a click selects
// it exactly as a click on the rack would, and the inspector shows it.
//
// THE RETURN CHIP SAYS WHERE, OR SAYS WHY NOT. CR-032's affordance is
// *"Return to RK-1 U21"*, offered *"once space exists"*. A return that is
// not possible yet is not hidden: the chip carries the reason in its
// tooltip, because a device whose way back is silently missing reads as a
// device the bin has swallowed.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// One staged device as the strip shows it.
@immutable
final class StagedChip {
  const StagedChip({
    required this.id,
    required this.designator,
    required this.heightLabel,
    this.returnLabel,
    this.returnRefusal,
  });

  final Uuid id;
  final String designator;

  /// `1U`, `2U`, or empty for a device with no rack height of its own.
  final String heightLabel;

  /// `Return to RK-1 U21` or `Return to SHF-1` when a return is possible
  /// now (CR-032's wording), else null.
  final String? returnLabel;

  /// Why there is no return yet, when [returnLabel] is null.
  final String? returnRefusal;
}

/// The strip. Stateless: the screen owns the document and the selection.
class StagingBinStrip extends StatelessWidget {
  const StagingBinStrip({
    required this.chips,
    required this.selectedIds,
    required this.onSelect,
    required this.onReturn,
    this.onArmDrag,
    super.key,
  });

  final List<StagedChip> chips;
  final Set<Uuid> selectedIds;
  final ValueChanged<Uuid> onSelect;
  final ValueChanged<Uuid> onReturn;

  /// Every pointer-down on a chip, for the screen's drag (`#964`). A
  /// `Listener` rather than a recognizer, as the palette's rows are: it
  /// joins no gesture arena, so the chip's own click still selects, and
  /// the screen decides past its 4px slop whether this became a drag.
  final void Function(Uuid id, PointerDownEvent event)? onArmDrag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Staging Bin (${chips.length})',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final chip in chips) _chip(context, chip)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, StagedChip chip) {
    final label = chip.heightLabel.isEmpty
        ? chip.designator
        : '${chip.designator} · ${chip.heightLabel}';
    final returnLabel = chip.returnLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (e) => onArmDrag?.call(chip.id, e),
          child: InputChip(
            key: ValueKey('staged-${chip.id.v}'),
            label: Text(label),
            selected: selectedIds.contains(chip.id),
            onSelected: (_) => onSelect(chip.id),
            showCheckmark: false,
          ),
        ),
        if (returnLabel != null)
          TextButton(
            key: ValueKey('return-${chip.id.v}'),
            onPressed: () => onReturn(chip.id),
            child: Text(returnLabel),
          )
        else if (chip.returnRefusal case final why?)
          Tooltip(
            message: why,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.info_outline,
                size: 16,
                semanticLabel: why,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
