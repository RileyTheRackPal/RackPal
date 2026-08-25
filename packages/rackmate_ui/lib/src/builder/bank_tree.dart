// docs/06 §2's BANK TREE, and the bank menu §4.6 names without saying
// whose. Board `#181` / `#223` (M4-J1), DR-085.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE MENU, TWO MOUNT POINTS
// ═══════════════════════════════════════════════════════════════════════
// §4.6 puts `Mirror bank` on "the bank context menu" and never says which
// surface owns it. It is mounted twice: on the tree row, because the tree
// IS the list of banks and creation has to live somewhere a bank with no
// ports can still be reached; and on the grid's band header, because that
// is where the cursor already is when a person decides a bank is
// misnamed. [bankMenuItems] is the single builder, so the two can never
// offer different actions or spell one of them differently.
//
// ═══════════════════════════════════════════════════════════════════════
// ONLY A DECLARED BANK HAS A MENU
// ═══════════════════════════════════════════════════════════════════════
// `buildBankTree` marks each row `isDeclared`. `Not in a bank` and a
// `bankKey` naming no `BankDef` are PLACES the grid draws, not banks:
// there is nothing to rename, nothing to remove, and mirroring one would
// have to mint the definition it does not have. Both still navigate,
// because a person looking for the loose ports is looking for a band.
//
// ═══════════════════════════════════════════════════════════════════════
// REMOVE DOES NOT CONFIRM, AND THE REASON IS WHAT IT DOES
// ═══════════════════════════════════════════════════════════════════════
// `RemoveBankCommand` keeps every port and clears its `bankKey` (CR-055: a
// bank is presentation), so the ports a person can see do not go anywhere:
// they land in `Not in a bank`, which the grid redraws in front of them,
// and one `Ctrl+Z` puts the heading back. A confirm on an action that
// destroys nothing teaches a person to click through confirms, which is
// what makes the one on `Commit sort order` (AC-058/D5) stop working.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// What the tree and the band header ask the builder to do.
///
/// CALLBACKS AND NOT THE SESSION, the shape `PortGridActions` already
/// uses: this package stays out of the session layer, and the screen keeps
/// `setState` and the undo stack.
@immutable
final class BankActions {
  const BankActions({
    required this.onCreate,
    required this.onRename,
    required this.onRemove,
    required this.onMirror,
  });

  /// `New bank…`. Takes no key: there is nothing to act on yet.
  final VoidCallback onCreate;

  final ValueChanged<String> onRename;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onMirror;
}

/// The bank menu, for a row that has a `BankDef` behind it.
///
/// Returned rather than shown, so the tree can hang it off a `⋯` button
/// and the grid's band header can hang the same list off its own.
List<Widget> bankMenuItems({
  required String bankKey,
  required BankActions actions,
}) => [
  MenuItemButton(
    leadingIcon: const Icon(Icons.drive_file_rename_outline, size: 18),
    onPressed: () => actions.onRename(bankKey),
    child: const Text('Rename…'),
  ),
  MenuItemButton(
    leadingIcon: const Icon(Icons.flip, size: 18),
    onPressed: () => actions.onMirror(bankKey),
    child: const Text('Mirror bank…'),
  ),
  MenuItemButton(
    leadingIcon: const Icon(Icons.playlist_remove, size: 18),
    onPressed: () => actions.onRemove(bankKey),
    // NAMES WHAT SURVIVES, because that is the part a person cannot
    // guess. "Remove" beside a heading holding sixteen ports reads as
    // sixteen ports going with it, and CR-055 is the reason none do.
    child: const Text('Remove (ports stay)'),
  ),
];

/// docs/06 §2's left-rail bank tree.
class BankTree extends StatelessWidget {
  const BankTree({
    required this.body,
    required this.actions,
    required this.onSelect,
    this.selected,
    super.key,
  });

  /// The session's live body, read through [buildBankTree].
  final TemplateBody body;

  final BankActions actions;

  /// A row was clicked. The screen switches to the Ports section and
  /// tells the grid to jump; the tree does not know either of those
  /// things happened.
  final ValueChanged<String?> onSelect;

  /// The row drawn as current, which is the last one clicked.
  ///
  /// A RECORD OF THE CLICK, NOT OF WHERE THE GRID IS. The grid scrolls
  /// freely afterwards and this does not follow it: a highlight that
  /// chased the scroll position would flicker through every band on the
  /// way to the one a person asked for.
  final ({String? key})? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = buildBankTree(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'BANKS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'New bank',
                visualDensity: VisualDensity.compact,
                onPressed: actions.onCreate,
              ),
            ],
          ),
        ),
        // THE EMPTY STATE IS A SENTENCE, NOT A BLANK. A template with no
        // banks is the ordinary starting state, and a heading over nothing
        // reads as a list that failed to load.
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No banks yet. Quick Add names one for you, or make one here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Flexible(
            child: ListView(
              primary: false,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final row in rows)
                  _BankRow(
                    row: row,
                    actions: actions,
                    isSelected: selected?.key == row.key,
                    onSelect: () => onSelect(row.key),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.row,
    required this.actions,
    required this.isSelected,
    required this.onSelect,
  });

  final BankTreeRow row;
  final BankActions actions;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      selected: isSelected,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(
        row.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: row.isDeclared
            ? null
            // The same tone the grid's band header gives a band nobody
            // declared, so a reader skimming for banks does not mistake
            // one for the other on either surface.
            : theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
      ),
      subtitle: Text(
        row.portCount == 1 ? '1 port' : '${row.portCount} ports',
        style: theme.textTheme.labelSmall,
      ),
      trailing: row.isDeclared
          ? MenuAnchor(
              menuChildren: bankMenuItems(
                bankKey: row.key!,
                actions: actions,
              ),
              builder: (context, controller, child) => IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'Bank actions',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            )
          : null,
      onTap: onSelect,
    );
  }
}
