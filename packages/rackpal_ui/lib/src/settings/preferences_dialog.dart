// Edit > Preferences: this computer's settings (DR-172).
//
// ═════════════════════════════════════════════════════════════════════
// NOT PROJECT SETTINGS, AND OPENED FROM A DIFFERENT MENU FOR THAT REASON
// ═════════════════════════════════════════════════════════════════════
// File > Project settings edits `ProjectSettings`, which travels in the
// project file and is undoable on the document's stack (`#805`). What
// lives here is a fact about THIS MACHINE, written to `prefs.json`: it does
// not travel with a file and nothing undoes it. One setting today, the
// undo depth canon §10.12(a) made a setting.
//
// ═════════════════════════════════════════════════════════════════════
// COMMITTED ON ENTER OR CLOSE, NEVER ON CLICKING AWAY
// ═════════════════════════════════════════════════════════════════════
// The project dialog's number rows commit when focus leaves them. That is
// harmless for a sheet number and wrong here: the depth takes effect at
// once and lowering it drops history, so typing "60" on the way to "600"
// and clicking elsewhere would throw away steps nobody meant to lose.
// Enter and Close apply what is typed; Escape and a click outside the
// dialog discard it.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show kMaxUndoDepth, kMinUndoDepth;

/// The Edit menu's item, named once so the shell and its tests agree, and
/// spelled with three dots as `kProjectSettingsLabel` is.
const String kPreferencesLabel = 'Preferences...';

/// The help line under the undo depth field.
const String kUndoDepthHelp =
    'Steps kept for each document and in the Device Builder, from '
    '$kMinUndoDepth to $kMaxUndoDepth. Saved on this computer.';

/// Why [text] is not an acceptable undo depth, or null when it is.
String? undoDepthError(String text) {
  final n = int.tryParse(text.trim());
  if (n == null) return 'Whole numbers only.';
  if (n < kMinUndoDepth || n > kMaxUndoDepth) {
    return 'Between $kMinUndoDepth and $kMaxUndoDepth.';
  }
  return null;
}

/// Shows Edit > Preferences.
///
/// [onUndoDepthChanged] fires only with a depth the field accepted, inside
/// [kMinUndoDepth]..[kMaxUndoDepth], and only when it differs from what
/// the dialog opened with or last applied.
Future<void> showPreferencesDialog(
  BuildContext context, {
  required int undoDepth,
  required ValueChanged<int> onUndoDepthChanged,
}) => showDialog<void>(
  context: context,
  builder: (context) => PreferencesDialog(
    undoDepth: undoDepth,
    onUndoDepthChanged: onUndoDepthChanged,
  ),
);

/// Edit > Preferences.
class PreferencesDialog extends StatefulWidget {
  const PreferencesDialog({
    required this.undoDepth,
    required this.onUndoDepthChanged,
    super.key,
  });

  /// The depth in force when the dialog opened.
  final int undoDepth;

  final ValueChanged<int> onUndoDepthChanged;

  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  late final TextEditingController _depth = TextEditingController(
    text: '${widget.undoDepth}',
  );
  late int _applied = widget.undoDepth;
  String? _error;

  @override
  void dispose() {
    _depth.dispose();
    super.dispose();
  }

  /// Applies the typed depth when it is acceptable and says why when it
  /// is not. True when nothing is left to refuse.
  bool _commit() {
    final error = undoDepthError(_depth.text);
    setState(() => _error = error);
    if (error != null) return false;
    final depth = int.parse(_depth.text.trim());
    if (depth != _applied) {
      _applied = depth;
      widget.onUndoDepthChanged(depth);
    }
    return true;
  }

  /// Enter and Close: apply, and leave only when what is typed is
  /// acceptable, so a refused value is never closed away unseen.
  void _close() {
    if (_commit()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preferences'),
    content: SizedBox(
      width: 420,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Undo history'),
        subtitle: TextField(
          key: const ValueKey('preferences.undoDepth'),
          controller: _depth,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _close(),
          decoration: InputDecoration(
            isDense: true,
            suffixText: 'steps',
            helperText: kUndoDepthHelp,
            helperMaxLines: 2,
            errorText: _error,
          ),
        ),
      ),
    ),
    actions: [TextButton(onPressed: _close, child: const Text('Close'))],
  );
}
