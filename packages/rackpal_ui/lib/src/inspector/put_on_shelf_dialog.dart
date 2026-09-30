// The picker that sets a device on a shelf from the inspector (DR-204
// §11.203.1, `#957`): *"selecting a shelf offers `Put a device on this
// shelf…`, AC-044's shape for 0U occupants and the keyboard's route"*.
//
// ═══════════════════════════════════════════════════════════════════════
// THE KEYBOARD'S ROUTE, WHICH THE DRAG IS NOT
// ═══════════════════════════════════════════════════════════════════════
// A drag onto a shelf (`#956`) needs a pointer. This needs Tab and Enter:
// the filter has focus when the dialog opens, typing narrows the list, and
// Enter puts the first match on the shelf. It auto-packs at the right-hand
// end (AC-043), because a keyboard has no caret to aim.
//
// ═══════════════════════════════════════════════════════════════════════
// ANY DEVICE, EXCEPT A SHELF
// ═══════════════════════════════════════════════════════════════════════
// §11.203.2 gives the template no vote: an AVR may sit on a shelf whether
// or not a rack kit exists for it. The one exclusion is a CONTAINER, and it
// is a drawing fact rather than a rule about what may sit where: the
// elevation draws one level of hosts, so a shelf set on a shelf would land
// where nobody can see it. The drag excludes it for the same reason.
//
// Shelf-sitting devices are listed first, because they are what a person
// opening this is usually looking for; everything else follows by name.
//
// Like `add_zero_u_occupant_dialog.dart`, it returns an id and validates
// nothing: `buildPlaceOnShelfCommand` asks TOP-005 and says why in words.
// Libraries are not offered, for that file's reason.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the inspector's button says, and the dialog's title.
const String kPutOnShelfLabel = 'Put a device on this shelf…';
const String kPutOnShelfTitle = 'Put a device on this shelf';
const String kPutOnShelfConfirm = 'Put on shelf';

/// A stable handle per offered row.
String putOnShelfRowKeyFor(String catalogId) => 'put-on-shelf-$catalogId';

/// Whether [body] is set on a shelf rather than bolted to rails.
bool _sitsOnAShelf(TemplateBody body) =>
    body.mountMethod == MountMethod.shelf ||
    body.mountMethod == MountMethod.hosted;

/// Every template in [doc] that can be put on a shelf, shelf-sitting ones
/// first, then by name, then by id (a total order, since `List.sort` is not
/// stable).
List<PlaceableTemplate> shelfCandidatesIn(RackDocument doc) {
  return [
    for (final row in buildPlaceableTemplates(doc))
      if (!row.body.isContainer) row,
  ]..sort((a, b) {
    final byKind =
        (_sitsOnAShelf(a.body) ? 0 : 1) - (_sitsOnAShelf(b.body) ? 0 : 1);
    if (byKind != 0) return byKind;
    final byName = a.body.displayName.compareTo(b.body.displayName);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
}

/// Asks which device goes on [shelf]. Returns the catalog id, or null when
/// the person cancelled.
Future<String?> showPutOnShelf(
  BuildContext context, {
  required DeviceInstance shelf,
  required RackDocument doc,
}) => showDialog<String>(
  context: context,
  builder: (context) => PutOnShelfDialog(shelf: shelf, doc: doc),
);

/// The dialog itself. Public so a widget test can pump it directly.
class PutOnShelfDialog extends StatefulWidget {
  const PutOnShelfDialog({required this.shelf, required this.doc, super.key});

  final DeviceInstance shelf;
  final RackDocument doc;

  static const Key filterKey = ValueKey('put-on-shelf-filter');
  static const Key confirmKey = ValueKey('put-on-shelf-confirm');

  @override
  State<PutOnShelfDialog> createState() => _PutOnShelfDialogState();
}

class _PutOnShelfDialogState extends State<PutOnShelfDialog> {
  late final List<PlaceableTemplate> _all = shelfCandidatesIn(widget.doc);
  String _filter = '';
  String? _chosen;

  List<PlaceableTemplate> get _rows {
    final f = _filter.trim().toLowerCase();
    if (f.isEmpty) return _all;
    return [
      for (final row in _all)
        if (row.body.displayName.toLowerCase().contains(f) ||
            row.id.toLowerCase().contains(f))
          row,
    ];
  }

  /// The chosen row when it is still visible, else the first match: a
  /// filter that hides the choice must not leave Enter placing something
  /// the person can no longer see.
  String? get _effective {
    final rows = _rows;
    if (rows.isEmpty) return null;
    final chosen = _chosen;
    if (chosen != null && rows.any((r) => r.id == chosen)) return chosen;
    return rows.first.id;
  }

  void _commit() {
    final id = _effective;
    if (id == null) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rows;
    final effective = _effective;
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: AlertDialog(
        title: Text(kPutOnShelfTitle, style: theme.textTheme.titleMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Onto ${widget.shelf.designator}, at the right-hand end.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: PutOnShelfDialog.filterKey,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Filter by name',
                ),
                onChanged: (v) => setState(() => _filter = v),
                onSubmitted: (_) => _commit(),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Text(
                  _all.isEmpty
                      ? 'This project has no devices to put on a shelf. '
                            'Author one in the Device Builder.'
                      : 'Nothing matches "$_filter".',
                  style: theme.textTheme.bodySmall,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: RadioGroup<String>(
                      groupValue: effective,
                      onChanged: (v) => setState(() => _chosen = v),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final row in rows)
                            RadioListTile<String>(
                              key: ValueKey(putOnShelfRowKeyFor(row.id)),
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
            key: PutOnShelfDialog.confirmKey,
            onPressed: effective == null ? null : _commit,
            child: const Text(kPutOnShelfConfirm),
          ),
        ],
      ),
    );
  }
}
