// The confirmation that states what removing a device template costs,
// before it costs it (`#871`, DR-158 §11.157).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIFTH PLACE ONE GESTURE DESTROYS WORK THE USER CANNOT SEE
// ═══════════════════════════════════════════════════════════════════════
// `ShrinkRackDialog` was the first, `DeleteDeviceDialog` the second,
// `DeleteLocationDialog` the third and `RemoveUnderlayDialog` the fourth.
// This takes their shape deliberately: a title naming the thing, the
// counts each in its own sentence, a line saying undo puts it back,
// Cancel and a destructive confirm. It is not factored into a shared
// widget with any of them, for the reason `delete_device_dialog.dart`
// already gives.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE NUMBERS IN THREE UNITS, AND THEY ARE NOT SUMMED
// ═══════════════════════════════════════════════════════════════════════
// DR-158 §11.157.5. A **device** is a thing that leaves the project; a
// **cable** is a row that leaves the schedule, which is the deliverable;
// a **snapshot** is an archived version CR-050 kept resolvable and which
// nobody has ever seen. They are ordered by how much the reader cares,
// and the third is mentioned only when there is more than one.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THIS ONE ALWAYS ASKS, WHICH IS WHERE IT DEPARTS FROM THE OTHER FOUR
// ═══════════════════════════════════════════════════════════════════════
// DR-013 §11.13.2 exempts the *consequence-free* delete and DR-158
// §11.157.5 rules that this is not one: authoring a template is minutes
// of work that exists nowhere else in the project, so removing an unused
// one still destroys something no route but undo brings back. The prompt
// is SHORTER when nothing stands on it. It is not absent.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks the user to confirm [plan]. Returns whether to proceed.
///
/// **A REFUSING PLAN RETURNS FALSE WITHOUT ASKING ANYTHING.** A seeded
/// template has no question to put to anybody (DR-158 §11.157.3), and the
/// surface should not have offered the control; this is the second guard
/// rather than the message.
Future<bool> confirmTemplateRemoval(
  BuildContext context, {
  required TemplateRemovalPlan plan,
  required String name,
}) async {
  if (!plan.needsConfirmation) return false;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => RemoveTemplateDialog(plan: plan, name: name),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class RemoveTemplateDialog extends StatelessWidget {
  const RemoveTemplateDialog({
    required this.plan,
    required this.name,
    super.key,
  });

  /// Computed BEFORE anything moved, and the same object
  /// `addTemplateRemoval` consumes. A dialog that said "3 devices" and
  /// removed four would be worse than no dialog.
  final TemplateRemovalPlan plan;

  /// The template's `displayName`, as the browser card prints it.
  final String name;

  /// A stable handle for tests.
  static const Key confirmKey = ValueKey('remove-template-confirm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = plan.deviceCount;
    final cables = plan.cableCount;
    final snapshots = plan.snapshotCount;

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
                  // THE DEVICE COUNT FIRST AND IN ITS OWN SENTENCE. It is
                  // the reason this dialog is not the short one, so it is
                  // not buried in a paragraph explaining itself.
                  if (devices > 0)
                    Text(
                      devices == 1
                          ? 'This also deletes the 1 device placed from it.'
                          : 'This also deletes the $devices devices placed '
                                'from it.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (devices > 0 && cables > 0) const SizedBox(height: 8),
                  if (cables > 0)
                    Text(
                      // A CABLE IS A SCHEDULE ROW, which is why it is
                      // counted separately and in its own unit: DR-013
                      // §11.13.2's "the schedule is the deliverable".
                      cables == 1
                          ? 'They take 1 cable with them, off the schedule.'
                          : 'They take $cables cables with them, off the '
                                'schedule.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (devices == 0)
                    Text(
                      // THE SHORT FORM, AND IT STILL ASKS. §11.157.5.
                      'Nothing is placed from it, so nothing else changes.',
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    snapshots > 1
                        ? 'All $snapshots saved versions of the template go. '
                              'Undo puts everything back.'
                        : 'Undo puts everything back.',
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
