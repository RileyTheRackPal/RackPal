// The confirmation that states what removing a wall plate costs, before
// it costs it (`#877`, DR-160 §11.159.2 and §11.159.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SIXTH PLACE ONE GESTURE DESTROYS WORK THE USER CANNOT SEE
// ═══════════════════════════════════════════════════════════════════════
// `ShrinkRackDialog` was the first, `DeleteDeviceDialog` the second,
// `DeleteLocationDialog` the third, `RemoveUnderlayDialog` the fourth and
// `RemoveTemplateDialog` the fifth. This takes their shape deliberately: a
// title naming the thing, the counts each in its own sentence, a line
// saying undo puts it back, Cancel and a destructive confirm. It is not
// factored into a shared widget with any of them, for the reason
// `delete_device_dialog.dart` already gives, and it is not shared with
// `remove_structure_dialog.dart` either: the two count different things in
// different units and one of them contains the other.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO NUMBERS, AND THE SECOND IS A BOOLEAN
// ═══════════════════════════════════════════════════════════════════════
// CABLES, which are schedule rows and therefore the deliverable (DR-013
// §11.13.2), and THE PIN, which is not a count because a plate has at most
// one. It earns a sentence anyway: somebody stood in the room and dotted
// the floorplan, `plan_length.dart` derives a cable length from that dot,
// and it travels inside the outlet when the outlet goes. A dialog naming
// only cables would understate what a pinned plate costs.
//
// ═══════════════════════════════════════════════════════════════════════
// AND A BARE PLATE IS NOT ASKED ABOUT
// ═══════════════════════════════════════════════════════════════════════
// `plan.needsConfirmation` is false for a plate with no drops and no pin,
// and [confirmOutletRemoval] then returns true WITHOUT showing anything.
// DR-013 §11.13.2's last sentence: a prompt for a consequence-free delete
// is the nag that teaches people to click through prompts, including this
// one on the day it matters. This is where it departs from
// `remove_structure_dialog.dart`, which always asks.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks the user to confirm [plan], when it costs anything. Returns
/// whether to proceed.
///
/// Shows NOTHING and returns true when it does not: see the file header.
/// An EMPTY plan returns false without asking, because a plate this
/// document does not hold has no question to put to anybody.
Future<bool> confirmOutletRemoval(
  BuildContext context, {
  required OutletRemovalPlan plan,
  required String designation,
}) async {
  if (plan.isEmpty) return false;
  if (!plan.needsConfirmation) return true;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) =>
        RemoveOutletDialog(plan: plan, designation: designation),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class RemoveOutletDialog extends StatelessWidget {
  const RemoveOutletDialog({
    required this.plan,
    required this.designation,
    super.key,
  });

  /// Computed BEFORE anything moved, and the same object
  /// `addOutletRemoval` consumes. A dialog that said "3 cables" and
  /// removed four would be worse than no dialog.
  final OutletRemovalPlan plan;

  /// What the left rail calls this plate.
  final String designation;

  /// A stable handle for tests.
  static const Key confirmKey = ValueKey('remove-outlet-confirm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cables = plan.cableCount;

    return CallbackShortcuts(
      // `Esc` is Cancel, everywhere, always, and the activator comes from
      // the keymap rather than a literal so the row is in the generated
      // table and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop(false)),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            'Remove $designation?',
            style: theme.textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // THE CABLE COUNT FIRST AND IN ITS OWN SENTENCE. It is
                  // the reason this dialog exists, so it is not buried in
                  // a paragraph explaining itself.
                  if (cables > 0)
                    Text(
                      cables == 1
                          ? 'This also deletes the 1 cable that lands on it, '
                                'off the schedule.'
                          : 'This also deletes the $cables cables that land '
                                'on it, off the schedule.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (cables > 0 && plan.hasPlanPin) const SizedBox(height: 8),
                  if (plan.hasPlanPin)
                    Text(
                      // NOT A COUNT. A plate carries at most one pin, so
                      // "1 pin" would be a number that can only ever be
                      // one, which reads as a template somebody forgot to
                      // fill in.
                      'Its pin on the floorplan goes with it.',
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    // WHY THE CABLES GO, IN ONE LINE. DR-160 §11.159.2:
                    // nothing in the product can move a drop onto another
                    // plate, so a cable left behind here could never be
                    // re-homed. Saying so is what makes this the smaller
                    // loss rather than a surprise.
                    'A cable cannot be moved to another plate, so these go '
                    'with it. Undo puts everything back.',
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
