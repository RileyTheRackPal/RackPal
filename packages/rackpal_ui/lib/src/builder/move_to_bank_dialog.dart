// `Ctrl+M` `Move to bank…`, docs/06 §4.6. M4-F10, board `#700`, DR-078
// §11.77.2.
//
// ═══════════════════════════════════════════════════════════════════════
// A LIST OF WHAT EXISTS, AND NO TEXT FIELD
// ═══════════════════════════════════════════════════════════════════════
// DR-078 §11.77.2 rules that this offers the template's declared banks and
// mints none, because creating a bank is `BankDef` CRUD and belongs to
// M4-J1. So there is nothing here to type into: `movableBanks` is the whole
// of what may be offered, and a template with nowhere to move to never
// reaches this dialog at all (the grid refuses with a sentence first).
//
// NO IMPACT LIST. DR-078 requires one on `Find & replace` and
// `Change type…`, the two that can overwrite a value or a published key.
// A move writes `bankKey` and `order`, both of which the grid redraws in
// front of the person the instant it lands, and neither of which reaches
// another project. The destination's own port count is the one number
// worth showing, and it is on the row.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What `[Move]` returns.
///
/// A RECORD RATHER THAN A BARE `String?`, because `null` is a legitimate
/// destination (`Not in a bank`) and a nullable return could not tell it
/// from a cancel.
typedef MoveToBankChoice = ({String? bankKey});

/// Shows `Move to bank…` and returns the destination, or null on cancel.
Future<MoveToBankChoice?> showMoveToBankDialog({
  required BuildContext context,
  required List<PortBankTarget> targets,
  required int portCount,
}) => showDialog<MoveToBankChoice>(
  context: context,
  builder: (context) =>
      _MoveToBankDialog(targets: targets, portCount: portCount),
);

class _MoveToBankDialog extends StatefulWidget {
  const _MoveToBankDialog({required this.targets, required this.portCount});

  final List<PortBankTarget> targets;

  /// How many rows are moving, for the title line. Stated rather than
  /// implied: a person who meant to move one row and selected eight finds
  /// out here rather than afterwards.
  final int portCount;

  @override
  State<_MoveToBankDialog> createState() => _MoveToBankDialogState();
}

class _MoveToBankDialogState extends State<_MoveToBankDialog> {
  /// NOTHING PRESELECTED, and `[Move]` is disabled until something is.
  /// A preselected first row on a list of destinations means one careless
  /// `Enter` moves eight ports into whichever bank happened to sort first,
  /// and this dialog has no preview to catch it.
  String? _chosen;
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = widget.portCount == 1 ? 'port' : 'ports';
    return AlertDialog(
      title: Text('Move ${widget.portCount} $rows'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'They land at the end of the bank you pick.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              // A `RadioGroup` ANCESTOR, not per-tile `groupValue`, which
              // Flutter deprecated after 3.32. The group holds the choice
              // and the tiles hold only their values.
              //
              // A RECORD OF WHETHER ANYTHING WAS PICKED, beside the value,
              // because `null` is a real destination here (`Not in a
              // bank`) and `groupValue == null` cannot mean "no choice
              // yet" as well. The sentinel equals no target key, so no
              // tile is selected until one is tapped.
              child: RadioGroup<String?>(
                groupValue: _picked ? _chosen : _kNothingPicked,
                onChanged: (value) => setState(() {
                  _chosen = value;
                  _picked = true;
                }),
                child: Scrollbar(
                  child: ListView(
                    primary: false,
                    shrinkWrap: true,
                    children: [
                      for (final target in widget.targets)
                        RadioListTile<String?>(
                          value: target.key,
                          dense: true,
                          title: Text(target.label),
                          subtitle: Text(
                            target.portCount == 1
                                ? '1 port'
                                : '${target.portCount} ports',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _picked
              ? () => Navigator.of(context).pop((bankKey: _chosen))
              : null,
          child: const Text('Move'),
        ),
      ],
    );
  }
}

/// A sentinel `groupValue` no `PortBankTarget.key` can equal, so "nothing
/// picked" is distinguishable from "the unbanded band is picked".
const String _kNothingPicked = '\u0000 nothing picked';
