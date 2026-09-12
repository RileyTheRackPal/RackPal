// The confirmation that states what removing a floorplan page costs,
// before it costs it (`#870`, DR-029).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FOURTH PLACE ONE GESTURE DESTROYS WORK THE USER CANNOT SEE
// ═══════════════════════════════════════════════════════════════════════
// `ShrinkRackDialog` was the first, `DeleteDeviceDialog` the second and
// `DeleteLocationDialog` the third. This takes the third's shape
// deliberately: a title naming the thing, the counts each in their own
// sentence, a line saying undo puts it back, Cancel and a destructive
// confirm. It is not factored into a shared widget with any of them, for
// the reason `delete_device_dialog.dart` already gives.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO NUMBERS, AND THEY ARE IN DIFFERENT UNITS
// ═══════════════════════════════════════════════════════════════════════
// A pin cleared is a rack, outlet or device that loses its POSITION and
// stays in the project. An outline cleared is a drawing that goes, and
// the room estimate derived from it goes with it (DR-050 §11.49). Adding
// them into one total would describe neither.
//
// ═══════════════════════════════════════════════════════════════════════
// AND A BARE PAGE IS NOT ASKED ABOUT
// ═══════════════════════════════════════════════════════════════════════
// `plan.needsConfirmation` is false for a page nothing is pinned to, and
// [confirmUnderlayRemoval] then returns true WITHOUT showing anything.
// DR-013 §11.13.2's last sentence: *"a prompt for a consequence-free
// delete is the nag that teaches people to click through prompts,
// including this one on the day it matters."*
//
// **THAT IS THE COMMON CASE HERE AND NOT AN EDGE ONE.** The reason a
// person reaches for this at all is usually that they picked the wrong
// page out of a multi-page PDF thirty seconds ago, and nothing is pinned
// to it yet.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks the user to confirm [plan], when it costs anything. Returns
/// whether to proceed.
///
/// Shows NOTHING and returns true when it does not: see the file header.
Future<bool> confirmUnderlayRemoval(
  BuildContext context, {
  required UnderlayRemovalPlan plan,
  required String name,
}) async {
  if (!plan.needsConfirmation) return true;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => RemoveUnderlayDialog(plan: plan, name: name),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class RemoveUnderlayDialog extends StatelessWidget {
  const RemoveUnderlayDialog({
    required this.plan,
    required this.name,
    super.key,
  });

  /// Computed BEFORE anything moved, and the same object the command
  /// consumes. A dialog that said "3 pins" and cleared four would be
  /// worse than no dialog.
  final UnderlayRemovalPlan plan;

  /// The page's own name, as the rail prints it.
  final String name;

  /// A stable handle for tests.
  static const Key confirmKey = ValueKey('remove-underlay-confirm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pins = plan.pinCount;
    final outlines = plan.outlineCount;

    return CallbackShortcuts(
      // `Esc` is Cancel, everywhere, always, and the activator comes from
      // the keymap rather than a literal so the row is in the generated
      // table and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop(false)),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text('Remove $name?', style: theme.textTheme.titleMedium),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // THE COUNTS FIRST, EACH IN ITS OWN SENTENCE. They are
                  // the reason this dialog exists, so they are not buried
                  // in a paragraph explaining themselves.
                  if (pins > 0)
                    Text(
                      // "LOSE THEIR POSITION", not "be deleted". Nothing
                      // is removed from the project by this: a rack whose
                      // pin is cleared is still a rack, and a dialog that
                      // implied otherwise would describe a cascade the
                      // command does not perform.
                      pins == 1
                          ? '1 item loses its position on this plan.'
                          : '$pins items lose their position on this plan.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (pins > 0 && outlines > 0) const SizedBox(height: 8),
                  if (outlines > 0)
                    Text(
                      outlines == 1
                          ? '1 room outline is erased, and the length it '
                                'estimated with it.'
                          : '$outlines room outlines are erased, and the '
                                'lengths they estimated with them.',
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Nothing else is removed: racks, outlets and devices '
                    'stay, with no position recorded on this plan. Undo '
                    'puts the page back with everything on it.',
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
              key: confirmKey,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}
