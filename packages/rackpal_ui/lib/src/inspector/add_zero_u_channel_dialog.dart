// The form that adds a 0U channel to a rack (`#876`, DR-163 §11.162.2).
//
// ═══════════════════════════════════════════════════════════════════════
// A FORM AND NOT A ONE-CLICK DEFAULT, BECAUSE BOUNDS CANNOT BE EDITED
// ═══════════════════════════════════════════════════════════════════════
// Settled by the user on 2026-09-13. `zero_u_commands.dart` has add and
// remove and nothing else: **there is no command that changes a channel's
// extent**, so a channel whose span is wrong is replaced rather than
// corrected. A one-click full-height default would therefore be a claim
// about the rack that somebody who wanted U 1 to U 12 has to delete and
// retype.
//
// Two comments in this tree promised an editability that never existed:
// `add_outlets.dart`'s remedy ("an ordinary one they can edit or remove
// afterwards") and `new_rack_dialog.dart`'s header ("0U channels ... All
// of it is editable afterwards from the rack inspector"). Both are
// corrected; this file is what makes the second half of each true.
//
// ═══════════════════════════════════════════════════════════════════════
// IT VALIDATES NOTHING (§11.162.3)
// ═══════════════════════════════════════════════════════════════════════
// `planAddZeroUChannel` already refuses a duplicate id, an inverted span
// and a span that does not fit, each with a sentence naming the rack and
// the numbers. This collects four values and hands them over. A second
// copy of any of those checks here is how a dialog and an edit come to
// disagree, which is DR-013 §11.13.2's rule arriving at another surface.
//
// **WHICH MEANS THE REFUSAL ARRIVES AFTER THE DIALOG CLOSES**, on the
// status line, rather than under the field. That is the honest trade for
// one source of truth, and it is the same trade `DropEntryLoop` makes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the rack inspector's button says.
const String kAddZeroUChannelLabel = 'Add channel…';

/// The dialog's own title, and the confirm.
const String kAddZeroUChannelTitle = 'Add a 0U channel';
const String kAddZeroUChannelConfirm = 'Add';

/// What a side is called on screen.
///
/// ONE FUNCTION, and it is the only place these four words are spelled:
/// the picker here and the rack inspector's list both read it, so a row
/// and the form that made it cannot drift apart.
String zeroUSideLabel(ZeroUChannelSide side) => switch (side) {
  ZeroUChannelSide.frontLeft => 'Front left',
  ZeroUChannelSide.frontRight => 'Front right',
  ZeroUChannelSide.rearLeft => 'Rear left',
  ZeroUChannelSide.rearRight => 'Rear right',
};

/// What a channel is CALLED: its name if it has one, else its side.
///
/// **ONE FUNCTION, because three surfaces now answer it.** A row reading
/// nothing for an unnamed channel is a gap where the model has a default,
/// and the inspector's row, the occupant picker's header and the status
/// line that reports a placement into it must all pick the same word.
String zeroUChannelLabel(ZeroUChannel channel) =>
    channel.name.isEmpty ? zeroUSideLabel(channel.side) : channel.name;

/// What one channel reads as in a list: `Rear left · U 1 to 42`.
String zeroUChannelSummary(ZeroUChannel channel) =>
    '${zeroUSideLabel(channel.side)} · U ${channel.startU} to ${channel.endU}';

/// The four values the form collects.
@immutable
final class ZeroUChannelDraft {
  const ZeroUChannelDraft({
    required this.id,
    required this.side,
    required this.startU,
    required this.endU,
    required this.name,
  });

  final String id;
  final ZeroUChannelSide side;
  final int startU;
  final int endU;
  final String name;
}

/// Asks for a channel. Returns null when the person cancelled.
Future<ZeroUChannelDraft?> showAddZeroUChannel(
  BuildContext context, {
  required Rack rack,
}) => showDialog<ZeroUChannelDraft>(
  context: context,
  builder: (context) => AddZeroUChannelDialog(rack: rack),
);

/// The dialog itself. Public so a widget test can pump it directly.
class AddZeroUChannelDialog extends StatefulWidget {
  const AddZeroUChannelDialog({required this.rack, super.key});

  final Rack rack;

  /// Stable handles for tests.
  static const Key confirmKey = ValueKey('zero-u-add-confirm');
  static const Key sideKey = ValueKey('zero-u-add-side');
  static const Key startKey = ValueKey('zero-u-add-start');
  static const Key endKey = ValueKey('zero-u-add-end');
  static const Key nameKey = ValueKey('zero-u-add-name');

  @override
  State<AddZeroUChannelDialog> createState() => _AddZeroUChannelDialogState();
}

class _AddZeroUChannelDialogState extends State<AddZeroUChannelDialog> {
  // REAR LEFT, and the default is the trade's rather than the model's
  // first enum value. `add_outlets.dart` already chose it for the remedy
  // and said why: "a 0U PDU goes down the back of the rack where the cords
  // are, not down the front where the gear is read."
  ZeroUChannelSide _side = ZeroUChannelSide.rearLeft;

  // THE WHOLE RACK, 1-BASED (CR-025). A vertical channel is a rail down
  // the rack's height, so the full span is the common case and the one
  // the remedy mints; a person wanting U 1 to U 12 types over it.
  late final TextEditingController _start = TextEditingController(text: '1');
  late final TextEditingController _end = TextEditingController(
    text: '${widget.rack.heightU}',
  );
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _name.dispose();
    super.dispose();
  }

  /// A local id that is unique on THIS rack.
  ///
  /// NOT A `Uuid`. `ZeroUChannel.id` is a plain `String` local to the rack
  /// (`zero_u_channel.dart`: "a sub-object with a plain String id local to
  /// the rack"), and the shipped ones read `ch-rear-l`, so a v4 uuid here
  /// would be the one unreadable id in a file full of readable ones.
  ///
  /// `planAddZeroUChannel` refuses a duplicate, which is what makes the
  /// counter safe rather than merely tidy.
  String _nextId() {
    final used = {for (final c in widget.rack.zeroUChannels) c.id};
    for (var n = 1; ; n++) {
      final id = 'ch-$n';
      if (!used.contains(id)) return id;
    }
  }

  int _intOr(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  void _commit() {
    Navigator.of(context).pop(
      ZeroUChannelDraft(
        id: _nextId(),
        side: _side,
        // A BLANK OR UNPARSEABLE FIELD FALLS BACK TO THE FULL SPAN rather
        // than to zero, which `planAddZeroUChannel` would refuse with a
        // sentence about a channel nobody described. Zero is also the
        // value CR-025 forbids, so defaulting to it would reintroduce the
        // defect `da60884` removed.
        startU: _intOr(_start, 1),
        endU: _intOr(_end, widget.rack.heightU),
        name: _name.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            kAddZeroUChannelTitle,
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
                    'On ${widget.rack.designator}, which is '
                    '${widget.rack.heightU} U.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ZeroUChannelSide>(
                    key: AddZeroUChannelDialog.sideKey,
                    initialValue: _side,
                    decoration: const InputDecoration(labelText: 'Side'),
                    items: [
                      for (final s in ZeroUChannelSide.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(zeroUSideLabel(s)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _side = v ?? _side),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: AddZeroUChannelDialog.startKey,
                          controller: _start,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Start U',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: AddZeroUChannelDialog.endKey,
                          controller: _end,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'End U'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: AddZeroUChannelDialog.nameKey,
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      // OPTIONAL AND SAID SO. `ZeroUChannel.name` defaults
                      // to empty and the list falls back to the side, so a
                      // blank here is a real answer rather than a gap.
                      helperText: 'Optional',
                    ),
                    onSubmitted: (_) => _commit(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // WHY THE NUMBERS MATTER NOW RATHER THAN LATER.
                    'A channel runs bottom to top and its span cannot be '
                    'changed afterwards: a channel with the wrong extent is '
                    'removed and added again.',
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
              key: AddZeroUChannelDialog.confirmKey,
              onPressed: _commit,
              child: const Text(kAddZeroUChannelConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
