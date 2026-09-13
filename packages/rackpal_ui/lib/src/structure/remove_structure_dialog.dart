// The confirmation that states what removing a whole Structure body
// costs, before it costs it (`#877`, DR-160 §11.159.3 and §11.159.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LARGEST DELETE IN THE PRODUCT
// ═══════════════════════════════════════════════════════════════════════
// It takes the panel, its paired device, every plate on it and every home
// run out of it, which on a real job is the whole field side of the
// building. It takes the shape the other six confirmations use (a title
// naming the thing, the counts each in its own sentence, a line saying
// undo puts it back, Cancel and a destructive confirm) and is not
// factored into a shared widget with any of them, for the reason
// `delete_device_dialog.dart` gives.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE NUMBERS IN THREE UNITS, AND THEY ARE NOT SUMMED
// ═══════════════════════════════════════════════════════════════════════
// A PLATE is a thing on a wall. A CABLE is a row that leaves the schedule,
// which is the deliverable (DR-013 §11.13.2). A PIN is walked-site work: a
// dot somebody placed standing in the room, which `plan_length.dart`
// derives a length from. They are ordered by how much the reader loses,
// and the third is counted in PLATES rather than pins because that is the
// thing a person would go back and re-dot.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THIS ONE ALWAYS ASKS, WHICH IS WHERE IT DEPARTS FROM THE PLATE
// ═══════════════════════════════════════════════════════════════════════
// DR-160 §11.159.5. DR-013 §11.13.2 exempts the *consequence-free* delete,
// and an empty panel is not one: it is the container the tab is named for,
// and re-creating one is a different order of work from re-typing a drop.
// The prompt is SHORTER when nothing is on it. It is not absent.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the editor header's overflow menu calls this.
///
/// WITH THE DIALOG IT OPENS, on `kImportCsvLabel`'s convention: the words
/// on the control and the words in the thing it opens are one decision,
/// and a label declared in the screen would drift from the title here.
const String kRemoveStructureLabel = 'Remove this Structure…';

/// Asks the user to confirm [plan]. Returns whether to proceed.
///
/// An EMPTY plan returns false without asking: a body this document does
/// not hold has no question to put to anybody, and the surface should not
/// have offered the control.
Future<bool> confirmStructureRemoval(
  BuildContext context, {
  required StructureRemovalPlan plan,
  required String name,
}) async {
  if (!plan.needsConfirmation) return false;

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => RemoveStructureDialog(plan: plan, name: name),
  );
  return answer ?? false;
}

/// The dialog itself. Public so a widget test can pump it directly.
class RemoveStructureDialog extends StatelessWidget {
  const RemoveStructureDialog({
    required this.plan,
    required this.name,
    super.key,
  });

  /// Computed BEFORE anything moved, and the same object
  /// `addStructureRemoval` consumes.
  final StructureRemovalPlan plan;

  /// `STR-1 · Media Panel`, as the editor header prints it.
  final String name;

  /// A stable handle for tests.
  static const Key confirmKey = ValueKey('remove-structure-confirm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plates = plan.outletCount;
    final cables = plan.cableCount;
    final pinned = plan.pinnedOutletCount;

    return CallbackShortcuts(
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
                  if (plates > 0)
                    Text(
                      plates == 1
                          ? 'This also deletes the 1 plate on it.'
                          : 'This also deletes the $plates plates on it.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (plates > 0 && cables > 0) const SizedBox(height: 8),
                  if (cables > 0)
                    Text(
                      cables == 1
                          ? 'The 1 cable out of this panel goes with it, off '
                                'the schedule.'
                          : 'The $cables cables out of this panel go with it, '
                                'off the schedule.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (pinned > 0) const SizedBox(height: 8),
                  if (pinned > 0)
                    Text(
                      // COUNTED IN PLATES, not in pins: a plate carries at
                      // most one, and what a person would go back and
                      // re-dot is the plate.
                      pinned == 1
                          ? '1 of those plates is pinned on the floorplan.'
                          : '$pinned of those plates are pinned on the '
                                'floorplan.',
                      style: theme.textTheme.titleSmall,
                    ),
                  if (plates == 0 && cables == 0)
                    Text(
                      // THE SHORT FORM, AND IT STILL ASKS. §11.159.5.
                      'Nothing is on it, so nothing else changes.',
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    // WHY IT ALL GOES, IN ONE LINE. A plate and a home run
                    // each name this panel in a field that is not
                    // nullable, so neither can be left behind pointing at
                    // nothing (§11.159.3).
                    'A plate and a cable each belong to this panel and '
                    'cannot be moved off it. Undo puts everything back.',
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
