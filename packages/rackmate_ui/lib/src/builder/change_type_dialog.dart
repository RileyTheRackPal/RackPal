// `Ctrl+T` `Change type…`, docs/06 §4.6. M4-F9, board `#699`, DR-078
// §11.77.3.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PREVIEW IS THE DELIVERABLE, SO IT IS ALWAYS ON SCREEN
// ═══════════════════════════════════════════════════════════════════════
// Not behind a "preview" button and not after the fact: the list is built
// from the current pickers on every keystroke of the person's attention,
// so the thing they approve is the thing they are looking at. `#699`'s own
// sentence is that the impact preview is the deliverable and the bulk
// write is twenty lines.
//
// ═══════════════════════════════════════════════════════════════════════
// PICKING A FAMILY PRE-FILLS THE CONNECTOR, ON SCREEN
// ═══════════════════════════════════════════════════════════════════════
// Retyping an HDMI bank to Ethernet should not leave Ethernet sitting on
// an HDMI Type A, so choosing a family moves the connector picker to that
// family's `defaultConnector` (`defaultConnectorFor`, the same value Quick
// Add inherits for a new port). **It moves the CONTROL, not the data**:
// the person can put it back, the preview shows the result either way, and
// nothing is written until `Apply`. A cascade applied silently at write
// time is the thing this dialog exists to prevent.
//
// THE CONNECTOR IS NOT FORCED. Once the person has touched the connector
// picker themselves, a later family change leaves it alone: a control that
// keeps overwriting a deliberate choice teaches people to distrust it.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_impact_list.dart';
import 'package:rackmate_ui/src/widgets/family_picker.dart';

/// What `[Apply]` returns. Either half may be null: null means "leave that
/// field alone", which is what makes a connector-only change expressible.
typedef ChangeTypeChoice = ({
  SignalFamilyId? family,
  ConnectorTypeId? connector,
});

/// Shows `Change type…` and returns what to write, or null on cancel.
Future<ChangeTypeChoice?> showChangeTypeDialog({
  required BuildContext context,
  required TemplateBody body,
  required List<String> selectedInOrder,
  required Registries registries,
}) => showDialog<ChangeTypeChoice>(
  context: context,
  builder: (context) => _ChangeTypeDialog(
    body: body,
    selectedInOrder: selectedInOrder,
    registries: registries,
  ),
);

class _ChangeTypeDialog extends StatefulWidget {
  const _ChangeTypeDialog({
    required this.body,
    required this.selectedInOrder,
    required this.registries,
  });

  final TemplateBody body;
  final List<String> selectedInOrder;
  final Registries registries;

  @override
  State<_ChangeTypeDialog> createState() => _ChangeTypeDialogState();
}

class _ChangeTypeDialogState extends State<_ChangeTypeDialog> {
  SignalFamilyId? _family;
  ConnectorTypeId? _connector;

  /// Whether the person has chosen a connector themselves. See the header:
  /// once they have, a family change stops moving it.
  bool _connectorIsTheirs = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = previewPortTypeChange(
      body: widget.body,
      selectedInOrder: widget.selectedInOrder,
      registries: widget.registries,
      family: _family,
      connector: _connector,
    );
    final picked = _family != null || _connector != null;

    return AlertDialog(
      title: Text('Change type on ${_ports(widget.selectedInOrder.length)}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Labelled(
                    label: 'Signal family',
                    child: FamilyPicker(
                      groups: signalFamilyCellGroups(widget.registries),
                      value: _family == null
                          ? null
                          : portFamilyText(widget.registries, _family!),
                      hint: 'Leave as is',
                      onPick: (label) {
                        final picked = resolveSignalFamilyCell(
                          widget.registries,
                          label,
                        );
                        if (picked == null) return;
                        setState(() {
                          _family = picked;
                          if (!_connectorIsTheirs) {
                            _connector = defaultConnectorFor(
                              widget.registries,
                              picked,
                            );
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Labelled(
                    label: 'Connector',
                    child: DropdownButton<ConnectorTypeId>(
                      isExpanded: true,
                      value: _connector,
                      hint: const Text('Leave as is'),
                      items: [
                        for (final def
                            in [...widget.registries.connectorTypes.values]
                              ..sort(
                                (a, b) =>
                                    a.displayName.compareTo(b.displayName),
                              ))
                          DropdownMenuItem(
                            value: def.id,
                            child: Text(def.displayName),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _connector = value;
                        _connectorIsTheirs = true;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              picked
                  ? portImpactSummary(rows)
                  : 'Pick a signal family, a connector, or both.',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(),
            PortImpactList(rows: rows),
            // WHAT IT WILL NOT DO, said once rather than on every row.
            // `#699`: the preview has to state what it leaves alone, and
            // the per-row notes carry the specifics.
            if (_family != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  kChangeTypeKeepsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
          onPressed: picked
              ? () => Navigator.of(
                  context,
                ).pop((family: _family, connector: _connector))
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _ports(int n) => n == 1 ? '1 port' : '$n ports';
}

/// The one-line statement of what a type change deliberately leaves alone.
const String kChangeTypeKeepsNote =
    'Direction and topology are left as they are. This build cannot tell a '
    'value somebody chose from one that came from a default, so it changes '
    'neither.';

/// A label over a control, because `FamilyPicker` and `DropdownButton`
/// carry no `InputDecoration` between them and a bare pair of controls in
/// a dialog is two buttons with no question attached.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      child,
    ],
  );
}
