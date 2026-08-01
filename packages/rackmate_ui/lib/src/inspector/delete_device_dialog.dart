// DR-013 §11.13.2 — the confirmation that states the count.
//
// ═══════════════════════════════════════════════════════════════════════
// A BARE "ARE YOU SURE?" DOES NOT DISCHARGE THIS CLAUSE
// ═══════════════════════════════════════════════════════════════════════
// Canon: *"this is the second place in the product where one gesture
// destroys work the user cannot see all of. A delete that silently drops a
// dozen rows off the schedule is the failure G1 makes most expensive — the
// schedule is the deliverable — so the count is the whole point of the
// dialog."*
//
// The first such place is `ShrinkRackDialog`, and this deliberately takes
// its shape: a title naming the thing and the cost, a body listing what
// goes, Cancel and a destructive confirm. The two are not factored into a
// common widget, because the shrink dialog also carries a trim selector
// and three mutually exclusive rescue options — sharing a base class would
// mean the simple case inheriting machinery it does not use, which is how
// the simple case stops being simple.
//
// ═══════════════════════════════════════════════════════════════════════
// THE COUNT IS NOT COMPUTED HERE
// ═══════════════════════════════════════════════════════════════════════
// It arrives as a `DeviceRemovalPlan` from core's `planDeviceRemoval`, the
// same function `RemoveDeviceCommand.apply` calls. A dialog that said
// "4 cables" and removed 5 would be worse than no dialog, and the only way
// to guarantee it cannot is for the sentence and the edit to read one
// answer.
//
// ═══════════════════════════════════════════════════════════════════════
// AND A DEVICE CARRYING NOTHING IS NOT ASKED ABOUT
// ═══════════════════════════════════════════════════════════════════════
// §11.13.2's last sentence. [confirmDeviceRemoval] returns true WITHOUT
// showing anything when no plan needs confirmation — a prompt for a
// consequence-free delete is the nag that teaches people to click through
// prompts, including this one on the day it matters.

import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// Asks the user to confirm deleting [plans]' devices, when any of them
/// carries cables. Returns whether to proceed.
///
/// Shows NOTHING and returns true when nothing would be cascaded — see the
/// file header.
Future<bool> confirmDeviceRemoval(
  BuildContext context, {
  required List<DeviceRemovalPlan> plans,
  required Map<Uuid, String> designators,
}) async {
  final wired = <DeviceRemovalPlan>[
    for (final p in plans)
      if (p.needsConfirmation) p,
  ];
  if (wired.isEmpty) return true;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => DeleteDeviceDialog(
      plans: wired,
      designators: designators,
      totalDevices: plans.length,
    ),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class DeleteDeviceDialog extends StatelessWidget {
  const DeleteDeviceDialog({
    required this.plans,
    required this.designators,
    required this.totalDevices,
    super.key,
  });

  /// Only the plans that carry cables — the ones there is anything to warn
  /// about.
  final List<DeviceRemovalPlan> plans;
  final Map<Uuid, String> designators;

  /// How many devices the gesture deletes IN TOTAL, including any that
  /// carry nothing. The dialog says so when the two numbers differ,
  /// because "delete 3 devices?" listing one is otherwise a dialog that
  /// looks like it has lost track.
  final int totalDevices;

  int get _cableTotal =>
      plans.fold(0, (sum, plan) => sum + plan.cableCount);

  String _nameOf(DeviceRemovalPlan plan) =>
      designators[plan.deviceId] ?? plan.deviceId.v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cables = _cableTotal;
    final devices = totalDevices;

    return CallbackShortcuts(
      // `Esc` is Cancel, everywhere, always — and the activator comes from
      // kKeymap rather than a literal so the row is in the generated table
      // and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(
        () => Navigator.of(context).pop(false),
      ),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            devices == 1
                ? 'Delete ${_nameOf(plans.first)}?'
                : 'Delete $devices devices?',
            style: theme.textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // THE COUNT, FIRST AND IN ITS OWN SENTENCE. It is the
                  // reason this dialog exists, so it does not get buried
                  // in a paragraph explaining itself.
                  Text(
                    cables == 1
                        ? 'This also deletes 1 cable.'
                        : 'This also deletes $cables cables.',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'They will come off the schedule. Undo puts them back.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (plans.length > 1) ...[
                    const Divider(height: 24),
                    for (final plan in plans)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${_nameOf(plan)} — ${plan.cableCount} '
                          '${plan.cableCount == 1 ? 'cable' : 'cables'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
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
