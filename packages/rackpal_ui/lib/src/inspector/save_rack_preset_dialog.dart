// Save as preset...: names the selected rack's form-factor facts as one of
// your presets (#561, DR-176 §11.175.2).
//
// ═════════════════════════════════════════════════════════════════════
// THE DIALOG ASKS FOR A NAME AND NOTHING ELSE
// ═════════════════════════════════════════════════════════════════════
// The values come from the rack the person has already set up to match
// their stock; that is the whole reason §11.175.2 chose saving from a rack
// over a form for every field. So the dialog says what will be captured,
// read-only, and asks only for the name the dropdown will show.
//
// ═════════════════════════════════════════════════════════════════════
// A NAME ALREADY IN THE DROPDOWN IS REFUSED, WITH A REASON
// ═════════════════════════════════════════════════════════════════════
// Two rows reading "Floor enclosure 24U" in one list cannot be told apart,
// so a name that matches any listed preset, seeded or yours, ignoring case
// and surrounding space, is refused where the person is typing rather than
// saved and left for them to find. Save is also refused for an empty name.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// The rack inspector's button, named once so the panel and its tests agree.
const String kSaveAsPresetLabel = 'Save as preset...';

/// The dialog's title.
const String kSaveAsPresetTitle = 'Save rack as preset';

/// Why [name] cannot be saved when [existingNames] are already listed, or
/// null when it can.
String? presetNameError(String name, Iterable<String> existingNames) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'A preset needs a name.';
  final lower = trimmed.toLowerCase();
  for (final existing in existingNames) {
    if (existing.trim().toLowerCase() == lower) {
      return 'A preset with that name is already in the list.';
    }
  }
  return null;
}

/// Asks what to call a preset saved from [rack]. Returns the trimmed name,
/// or null when the person cancelled.
///
/// [existingNames] is every name the Preset dropdown already lists.
Future<String?> showSaveRackPreset(
  BuildContext context, {
  required Rack rack,
  required Iterable<String> existingNames,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      SaveRackPresetDialog(rack: rack, existingNames: existingNames),
);

/// The dialog itself. Public so a widget test can pump it directly.
class SaveRackPresetDialog extends StatefulWidget {
  const SaveRackPresetDialog({
    required this.rack,
    required this.existingNames,
    super.key,
  });

  final Rack rack;
  final Iterable<String> existingNames;

  /// Stable handles for tests.
  static const Key nameKey = ValueKey('save-rack-preset-name');
  static const Key confirmKey = ValueKey('save-rack-preset-confirm');

  @override
  State<SaveRackPresetDialog> createState() => _SaveRackPresetDialogState();
}

class _SaveRackPresetDialogState extends State<SaveRackPresetDialog> {
  /// SEEDED WITH A NAME THE PERSON CAN KEEP OR TYPE OVER: the rack's height
  /// is the fact most presets are told apart by.
  late final TextEditingController _name = TextEditingController(
    text: '${widget.rack.heightU}U ${widget.rack.name}'.trim(),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final error = presetNameError(_name.text, widget.existingNames);
    setState(() => _error = error);
    if (error != null) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rack = widget.rack;
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: AlertDialog(
        title: Text(kSaveAsPresetTitle, style: theme.textTheme.titleMedium),
        content: SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: SaveRackPresetDialog.nameKey,
                controller: _name,
                autofocus: true,
                onSubmitted: (_) => _commit(),
                decoration: InputDecoration(
                  labelText: 'Name',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                // WHAT WILL BE CAPTURED, so nobody saves a preset expecting
                // it to remember something it does not.
                "Saves ${rack.heightU}U with this rack's form factor, width, "
                'rails, depth, capacity and swing-frame settings. Name and '
                'location are not saved.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
            key: SaveRackPresetDialog.confirmKey,
            onPressed: _commit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
