// Deleting a shelf that carries devices asks what happens to them (DR-204
// §11.203.6, `#959`): docs/04 §6.1 item 7, *"SHF-1 hosts 3 devices.
// [Delete all 4] [Move hosts to Staging Bin] [Cancel]"*, defaulting to the
// bin.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY IT ASKS AT ALL
// ═══════════════════════════════════════════════════════════════════════
// Before this, deleting a shelf removed the shelf and left every device on
// it pointing at a host that no longer existed: TOP-005's "sits on a shelf
// that is not in this document", produced by an ordinary Delete. The two
// honest outcomes are the two buttons. The bin is the default because it
// loses nothing (DR-205: a staged device keeps its ports and every link),
// and deleting the lot is one deliberate click further.
//
// It RETURNS a choice and runs nothing, like every dialog here: the screen
// composes the one transaction, so a Ctrl+Z undoes the shelf and its hosts
// together whichever button was pressed.
import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the person chose for the devices on the shelves being deleted.
enum ShelfHostsChoice {
  /// docs/04's default: the hosts go to the Staging Bin, wiring kept.
  moveToBin,

  /// The hosts are deleted with their shelves.
  deleteAll,
}

/// One shelf being deleted and how many devices sit on it.
typedef ShelfWithHosts = ({String designator, int hosts});

/// Asks what happens to the devices on [shelves]. Null when cancelled.
///
/// [totalDevices] is every device `Delete all` would remove: the whole
/// selection plus the hosts, so the button's number is the gesture's.
Future<ShelfHostsChoice?> askAboutShelfHosts(
  BuildContext context, {
  required List<ShelfWithHosts> shelves,
  required int totalDevices,
}) => showDialog<ShelfHostsChoice>(
  context: context,
  builder: (_) =>
      DeleteShelfDialog(shelves: shelves, totalDevices: totalDevices),
);

/// The dialog itself. Public so a widget test can pump it directly.
class DeleteShelfDialog extends StatelessWidget {
  const DeleteShelfDialog({
    required this.shelves,
    required this.totalDevices,
    super.key,
  });

  final List<ShelfWithHosts> shelves;
  final int totalDevices;

  static const Key moveKey = ValueKey('delete-shelf-move-hosts');
  static const Key deleteAllKey = ValueKey('delete-shelf-delete-all');

  int get _hosts => shelves.fold(0, (sum, s) => sum + s.hosts);

  String get _title {
    final hosts = _hosts == 1 ? '1 device' : '$_hosts devices';
    if (shelves.length == 1) {
      final s = shelves.single;
      return '${s.designator} hosts $hosts.';
    }
    return '${shelves.length} shelves host $hosts.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pop = Navigator.of(context).pop;
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(pop),
      child: AlertDialog(
        title: Text(_title, style: theme.textTheme.titleMedium),
        content: SizedBox(
          width: 440,
          child: Text(
            'Moved to the Staging Bin they keep their cables and can be put '
            'back on a shelf or the rails. Undo reverses either choice.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: pop, child: const Text('Cancel')),
          TextButton(
            key: deleteAllKey,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => pop(ShelfHostsChoice.deleteAll),
            child: Text('Delete all $totalDevices'),
          ),
          // THE DEFAULT, focused, so Enter takes the choice that loses
          // nothing (docs/04 §6.1 item 7).
          FilledButton(
            key: moveKey,
            autofocus: true,
            onPressed: () => pop(ShelfHostsChoice.moveToBin),
            child: const Text('Move hosts to Staging Bin'),
          ),
        ],
      ),
    );
  }
}
