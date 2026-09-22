// rackpal_ui/src/canvas/plan/edit_plan_dialog.dart — a plan's name and the
// place it shows (DR-185 §11.184, `#912`).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE DIALOG FOR TWO MOMENTS, AND THEY DIFFER IN WHAT DISMISSING MEANS
// ═══════════════════════════════════════════════════════════════════════
// From the rail's `Edit plan…` it is an edit: `Cancel` and `Esc` change
// nothing, which is what both words mean everywhere else in this product.
// Straight after an import it is a PROPOSAL (§11.184.2): the page is
// already picked and nothing in this dialog can un-pick it, so `Esc`
// keeps the proposal and there is no `Cancel` to suggest otherwise. The
// one button there says `Done`, because `Import` would name an act that
// has already happened.
//
// THE SHOWS LIST IS THE SITE TREE, IN THE SITE TREE'S ORDER AND DEPTH.
// `LocationTree.preOrder` is what the rail beside it draws, so a floor
// sits where the person just saw it rather than in an alphabetical list
// that puts `Attic` above `Level 1`.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// What the dialog answers: a name, and the place the plan shows.
@immutable
final class PlanDetails {
  const PlanDetails({required this.name, required this.locationId});

  /// The name as typed, untrimmed. `SetPlanUnderlayDetailsCommand` trims.
  final String name;

  /// The place the plan shows, or null for a site plan.
  final Uuid? locationId;

  @override
  bool operator ==(Object other) =>
      other is PlanDetails &&
      other.name == name &&
      other.locationId == locationId;

  @override
  int get hashCode => Object.hash(name, locationId);

  @override
  String toString() => 'PlanDetails($name, ${locationId?.v})';
}

/// Which of the two moments the dialog is opened in.
enum EditPlanMode {
  /// From the rail's `Edit plan…`. `Cancel` and `Esc` change nothing.
  edit,

  /// Straight after an import. `Esc` keeps the proposal.
  import,
}

/// Opens the dialog. Returns the details to store, or null when the person
/// dismissed it, which the caller reads by [mode]: nothing changes after
/// an edit, and the proposal stands after an import.
Future<PlanDetails?> showEditPlanDialog(
  BuildContext context, {
  required RackDocument doc,
  required PlanDetails initial,
  EditPlanMode mode = EditPlanMode.edit,
}) => showDialog<PlanDetails>(
  context: context,
  builder: (context) => EditPlanDialog(doc: doc, initial: initial, mode: mode),
);

/// The dialog itself, public so a test can pump it on its own.
class EditPlanDialog extends StatefulWidget {
  const EditPlanDialog({
    required this.doc,
    required this.initial,
    this.mode = EditPlanMode.edit,
    super.key,
  });

  final RackDocument doc;
  final PlanDetails initial;
  final EditPlanMode mode;

  /// Stable handles for tests.
  static const Key nameKey = ValueKey('edit-plan-name');
  static const Key showsKey = ValueKey('edit-plan-shows');
  static const Key confirmKey = ValueKey('edit-plan-confirm');

  /// The Shows row that says the plan shows no one place.
  static const String noPlaceLabel = 'No floor or room (a site plan)';

  @override
  State<EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<EditPlanDialog> {
  late final TextEditingController _name =
      TextEditingController(
          text: widget.initial.name,
        )
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.name.length,
        );
  late Uuid? _location = _knownOrNull(widget.initial.locationId);

  /// A location the document no longer holds is shown as none rather than
  /// as a dropdown value with no item, which Flutter asserts on.
  Uuid? _knownOrNull(Uuid? id) =>
      id != null && widget.doc.locations.containsKey(id) ? id : null;

  bool get _canConfirm => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(
      context,
    ).pop(PlanDetails(name: _name.text, locationId: _location));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tree = LocationTree.of(widget.doc);
    final importing = widget.mode == EditPlanMode.import;
    return CallbackShortcuts(
      // `Esc` dismisses, and the caller reads a dismissal by mode: nothing
      // changes after an edit, and the proposal stands after an import.
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: AlertDialog(
        title: Text(
          importing ? 'New floorplan page' : 'Edit floorplan page',
          style: theme.textTheme.titleMedium,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: EditPlanDialog.nameKey,
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Uuid?>(
                key: EditPlanDialog.showsKey,
                initialValue: _location,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Shows'),
                items: [
                  const DropdownMenuItem<Uuid?>(
                    child: Text(EditPlanDialog.noPlaceLabel),
                  ),
                  for (final id in tree.preOrder)
                    DropdownMenuItem<Uuid?>(
                      value: id,
                      child: Padding(
                        padding: EdgeInsets.only(left: 12.0 * tree.depthOf(id)),
                        child: Text(
                          widget.doc.locations[id]!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _location = id),
              ),
              if (importing) ...[
                const SizedBox(height: 12),
                // SAID, because this is the one dialog in the product where
                // `Esc` does not mean "forget it" (§11.184.2).
                Text(
                  'Esc skips this and keeps the suggested name and place. '
                  'Undo removes the page.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!importing)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          FilledButton(
            key: EditPlanDialog.confirmKey,
            onPressed: _canConfirm ? _confirm : null,
            child: Text(importing ? 'Done' : 'Save'),
          ),
        ],
      ),
    );
  }
}
