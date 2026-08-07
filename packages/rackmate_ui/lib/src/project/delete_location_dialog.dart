// DR-021 §11.20.3 — the confirmation that states what a location delete
// costs, before it costs it. Board M3-B/2.
//
// ═══════════════════════════════════════════════════════════════════════
// THE THIRD PLACE ONE GESTURE DESTROYS WORK THE USER CANNOT SEE
// ═══════════════════════════════════════════════════════════════════════
// `ShrinkRackDialog` was the first and `DeleteDeviceDialog` the second.
// This takes the second's shape deliberately: a title naming the thing, a
// count in its own sentence, a line saying undo puts it back, Cancel and a
// destructive confirm.
//
// It is not factored into a shared widget with either, for the reason
// `delete_device_dialog.dart` already gives: the shrink dialog carries a
// trim selector and three rescue options, and sharing a base would make
// the simple case inherit machinery it does not use.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO NUMBERS, AND THEY ARE IN DIFFERENT UNITS
// ═══════════════════════════════════════════════════════════════════════
// A device delete has one number, cables. This has two, because a location
// delete destroys ROOMS (the subtree, DR-021 §11.20.1) and disconnects
// THINGS THAT POINT AT THEM (nine carriers, §11.20.2), and those are not
// the same kind of loss. The second is not a deletion at all: a rack whose
// room is cleared is still a rack, and the sentence has to say "lose their
// room" rather than "be deleted" or it describes a cascade this ruling
// explicitly does not perform (§11.20.6).
//
// ═══════════════════════════════════════════════════════════════════════
// NEITHER NUMBER IS COMPUTED HERE
// ═══════════════════════════════════════════════════════════════════════
// Both arrive on a `LocationRemovalPlan` from core's `planLocationRemoval`,
// the SAME object `RemoveLocationCommand` consumes. A dialog that said
// "4 rooms" and removed five would be worse than no dialog, and the only
// structural guarantee against that is one answer read twice.
//
// ═══════════════════════════════════════════════════════════════════════
// AND A BARE LEAF IS NOT ASKED ABOUT
// ═══════════════════════════════════════════════════════════════════════
// `plan.needsConfirmation` is false for a childless location nothing points
// at, and [confirmLocationRemoval] then returns true WITHOUT showing
// anything. DR-013 §11.13.2's last sentence, and the reason is the same: a
// prompt for a consequence-free delete is the nag that teaches people to
// click through prompts, including this one on the day it matters.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks the user to confirm [plan], when it costs anything. Returns
/// whether to proceed.
///
/// Shows NOTHING and returns true when it does not: see the file header.
Future<bool> confirmLocationRemoval(
  BuildContext context, {
  required LocationRemovalPlan plan,
  required String name,
}) async {
  if (!plan.needsConfirmation) return true;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => DeleteLocationDialog(plan: plan, name: name),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class DeleteLocationDialog extends StatelessWidget {
  const DeleteLocationDialog({
    required this.plan,
    required this.name,
    super.key,
  });

  /// Computed BEFORE anything moved, and the same object the command will
  /// consume.
  final LocationRemovalPlan plan;

  /// What to call the location being deleted, already resolved by the
  /// caller through the tree.
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The node itself is not "also"; the subtree beneath it is.
    final descendants = plan.locationCount - 1;
    final refs = plan.referenceCount;

    return CallbackShortcuts(
      // `Esc` is Cancel, everywhere, always, and the activator comes from
      // kKeymap rather than a literal so the row is in the generated table
      // and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop(false)),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text('Delete $name?', style: theme.textTheme.titleMedium),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // THE COUNTS, FIRST AND EACH IN ITS OWN SENTENCE. They
                  // are the reason this dialog exists, so they are not
                  // buried in a paragraph explaining themselves.
                  if (descendants > 0)
                    Text(
                      descendants == 1
                          ? 'This also deletes 1 location inside it.'
                          : 'This also deletes $descendants locations inside '
                                'it.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (descendants > 0 && refs > 0) const SizedBox(height: 8),
                  if (refs > 0)
                    Text(
                      // "LOSE THEIR ROOM", not "be deleted". DR-021
                      // §11.20.6 deletes no rack, cable, outlet or
                      // pathway, and a dialog that implied otherwise would
                      // describe a cascade the ruling refuses to perform.
                      refs == 1
                          ? '1 item loses its room.'
                          : '$refs items lose their room.',
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    refs > 0
                        ? 'Nothing else is deleted: cables, racks and outlets '
                              'stay, with no room recorded. Undo puts the '
                              'rooms back.'
                        : 'Undo puts them back.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
