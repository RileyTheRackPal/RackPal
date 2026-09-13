// The picker that puts a device INTO a 0U channel (`#884`, DR-164
// §11.163).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PRODUCER NOTHING IN THE PRODUCT HAD
// ═══════════════════════════════════════════════════════════════════════
// `buildPlaceFromCatalogCommand` has taken a `ZeroUTarget? zeroU` since
// M5-C and the branch behind it is complete: it builds the
// `ZeroUPlacement`, runs `evaluatePlacement` and returns `PLC-003`'s
// refusal by name. **`ZeroUTarget` had ZERO call sites.** The only
// reachable writer of a `ZeroUPlacement` was `planSetZeroUPosition`, which
// moves one that already exists, so `#876`'s occupant list was a view over
// a set nothing could add to.
//
// Canon §11.162.5 deferred this to the palette. The palette refuses a 0U
// row with *"Add it from the rack inspector (AC-044)"* — each surface
// deferred to the other, which is why it shipped looking decided.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DOCUMENT'S SHELF, NOT THE SEED CATALOG (DR-077 §11.76.1)
// ═══════════════════════════════════════════════════════════════════════
// `buildPlaceableTemplates(doc)` with no libraries is the same projection
// the palette reads, and it is the right one for the same reason: a 0U
// template authored in the Device Builder is in the document and in no
// catalog, and a picker built from `buildSeedCatalog()` would be reading a
// constant while standing next to the answer.
//
// Libraries are NOT offered here, and that is a scope line rather than an
// oversight. A library row is not in the document yet, so placing one is
// the copy-on-place sequence (`LibraryPlacement`, DR-103 §11.102.2) that
// `rack_canvas_screen.dart` runs as a two-child transaction. This dialog
// returns an id and the screen places it; wiring the copy through here
// would put a second copy of that sequence in the tree for a picker that
// lists one row in every project that ships.
//
// ═══════════════════════════════════════════════════════════════════════
// IT VALIDATES NOTHING, ON `add_zero_u_channel_dialog.dart`'s REASONING
// ═══════════════════════════════════════════════════════════════════════
// `PLC-003` checks that the channel resolves and that the offset lands
// inside it, and `buildPlaceFromCatalogCommand` returns that refusal with
// its rule id attached. This collects one id and hands it over.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/inspector/add_zero_u_channel_dialog.dart'
    show zeroUChannelSummary;
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the channel row's control says.
const String kAddZeroUOccupantTooltip = 'Add a device to this channel';

/// The dialog's title and confirm.
const String kAddZeroUOccupantTitle = 'Add a device to this channel';
const String kAddZeroUOccupantConfirm = 'Add';

/// What it says when the project holds no 0U device at all.
///
/// **NAMES THE WAY OUT.** One 0U archetype ships (`P01`), so an empty list
/// here means somebody removed it from the project's shelf or is working
/// in a document that never had it, and the Device Builder is where a
/// replacement comes from. docs/04 §3.4's rule against a control that
/// silently does nothing applies to an empty dialog just as well.
const String kNoZeroUTemplates =
    'This project has no 0U devices. Author one in the Device Builder, or '
    'import a library that has one.';

/// A stable handle per offered row, for tests and for a rebuilt list.
String zeroUTemplateKeyFor(String catalogId) => 'zero-u-template-$catalogId';

/// Every template in [doc] that mounts in a vertical channel.
///
/// **THE PREDICATE COMES FROM `catalog_placement.dart`** and is not
/// spelled here: `isZeroUBody` is what decides whether
/// `buildPlaceFromCatalogCommand` will accept a `zeroU` target, so a
/// second copy is how a picker comes to offer a row the placer refuses.
List<PlaceableTemplate> zeroUTemplatesIn(RackDocument doc) => [
  for (final row in buildPlaceableTemplates(doc))
    if (isZeroUBody(row.body)) row,
];

/// Asks which device goes in [channel]. Returns the catalog id, or null
/// when the person cancelled.
Future<String?> showAddZeroUOccupant(
  BuildContext context, {
  required Rack rack,
  required ZeroUChannel channel,
  required RackDocument doc,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      AddZeroUOccupantDialog(rack: rack, channel: channel, doc: doc),
);

/// The dialog itself. Public so a widget test can pump it directly.
class AddZeroUOccupantDialog extends StatefulWidget {
  const AddZeroUOccupantDialog({
    required this.rack,
    required this.channel,
    required this.doc,
    super.key,
  });

  final Rack rack;
  final ZeroUChannel channel;
  final RackDocument doc;

  /// A stable handle for tests.
  static const Key confirmKey = ValueKey('zero-u-occupant-add-confirm');

  @override
  State<AddZeroUOccupantDialog> createState() => _AddZeroUOccupantDialogState();
}

class _AddZeroUOccupantDialogState extends State<AddZeroUOccupantDialog> {
  late final List<PlaceableTemplate> _rows = zeroUTemplatesIn(widget.doc);

  /// **PRESELECTED, BECAUSE ONE ROW IS THE COMMON CASE.** One 0U archetype
  /// ships, so a list that opens with nothing chosen would make the
  /// single-row case two clicks where one is enough, and a person who
  /// wants the other row still clicks it.
  late String? _chosen = _rows.isEmpty ? null : _rows.first.id;

  void _commit() {
    final chosen = _chosen;
    if (chosen == null) return;
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = _chosen;
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            kAddZeroUOccupantTitle,
            style: theme.textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // THE CHANNEL IT IS GOING INTO, spelled the same way
                    // the list behind the dialog spells it, so the two
                    // cannot come to describe one channel differently.
                    '${widget.rack.designator} · '
                    '${zeroUChannelSummary(widget.channel)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_rows.isEmpty)
                    Text(kNoZeroUTemplates, style: theme.textTheme.bodySmall)
                  else
                    // A `RadioGroup` ANCESTOR, not per-tile `groupValue`,
                    // which Flutter deprecated after 3.32. The group holds
                    // the choice and the tiles hold only their values.
                    RadioGroup<String>(
                      groupValue: chosen,
                      onChanged: (v) => setState(() => _chosen = v),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final row in _rows)
                            RadioListTile<String>(
                              key: ValueKey(zeroUTemplateKeyFor(row.id)),
                              value: row.id,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                row.body.displayName,
                                style: theme.textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                row.id,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    // SAID UP FRONT, because it is the one thing about
                    // this placement a person cannot see afterwards: the
                    // device does not appear in the elevation at all
                    // (`#883`), so the channel's own list is where it
                    // lands and where its start U is changed.
                    'It lands at U ${widget.channel.startU} and is listed '
                    'under this channel, where its start U can be changed. '
                    'A 0U device is not drawn in the elevation yet.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: AddZeroUOccupantDialog.confirmKey,
              // DISABLED RATHER THAN ABSENT when there is nothing to
              // choose: the sentence above says why, and a missing button
              // would leave a dialog whose only exit is Cancel with no
              // account of what went wrong.
              onPressed: chosen == null ? null : _commit,
              child: const Text(kAddZeroUOccupantConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
