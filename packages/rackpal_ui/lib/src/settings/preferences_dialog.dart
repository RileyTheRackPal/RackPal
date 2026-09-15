// Edit > Preferences: this computer's settings (DR-172, DR-176).
//
// ═════════════════════════════════════════════════════════════════════
// NOT PROJECT SETTINGS, AND OPENED FROM A DIFFERENT MENU FOR THAT REASON
// ═════════════════════════════════════════════════════════════════════
// File > Project settings edits `ProjectSettings`, which travels in the
// project file and is undoable on the document's stack (`#805`). What
// lives here is a fact about THIS MACHINE, kept beside the data root and
// never in a document: it does not travel with a file and nothing undoes
// it. The undo depth canon §10.12(a) made a setting, and since DR-176 the
// rack presets you saved and the seeded ones you hid.
//
// ═════════════════════════════════════════════════════════════════════
// THE DEPTH IS COMMITTED ON ENTER OR CLOSE, NEVER ON CLICKING AWAY
// ═════════════════════════════════════════════════════════════════════
// The project dialog's number rows commit when focus leaves them. That is
// harmless for a sheet number and wrong here: the depth takes effect at
// once and lowering it drops history, so typing "60" on the way to "600"
// and clicking elsewhere would throw away steps nobody meant to lose.
// Enter and Close apply what is typed; Escape and a click outside the
// dialog discard it.
//
// ═════════════════════════════════════════════════════════════════════
// A PRESET CHANGE IS APPLIED AT ONCE
// ═════════════════════════════════════════════════════════════════════
// Renaming, deleting, showing and hiding a preset each reach the store the
// moment they happen. None of them loses history the way a lowered depth
// does, and a rename is committed in its own small dialog, so there is no
// half-typed value for Close or Escape to decide about.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show RackPreset, UserRackPresets, kMaxUndoDepth, kMinUndoDepth;
import 'package:rackpal_ui/src/inspector/save_rack_preset_dialog.dart'
    show presetNameError;

/// The Edit menu's item, named once so the shell and its tests agree, and
/// spelled with three dots as `kProjectSettingsLabel` is.
const String kPreferencesLabel = 'Preferences...';

/// The help line under the undo depth field.
const String kUndoDepthHelp =
    'Steps kept for each document and in the Device Builder, from '
    '$kMinUndoDepth to $kMaxUndoDepth. Saved on this computer.';

/// The rack presets section's heading.
const String kRackPresetsSectionLabel = 'Rack presets';

/// The help line under that heading.
const String kRackPresetsHelp =
    'Presets you saved from a rack, and which seeded presets the Preset '
    'list shows. Saved on this computer.';

/// What the section says when you have saved none.
const String kNoSavedPresets =
    'None saved yet. Use Save as preset... in the rack inspector.';

/// A stable handle for one of your presets' Rename control.
String presetRenameKeyFor(String id) => 'preferences.rename.$id';

/// A stable handle for one of your presets' Delete control.
String presetDeleteKeyFor(String id) => 'preferences.delete.$id';

/// A stable handle for a seeded preset's show/hide checkbox.
String presetShowKeyFor(String id) => 'preferences.show.$id';

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
///
/// The rack presets section shows only when [seededPresets], [rackPresets]
/// and [onRackPresetsChanged] are all given. [onRackPresetsChanged] fires
/// with the whole new value after each rename, delete, show or hide.
Future<void> showPreferencesDialog(
  BuildContext context, {
  required int undoDepth,
  required ValueChanged<int> onUndoDepthChanged,
  Map<String, RackPreset>? seededPresets,
  UserRackPresets? rackPresets,
  ValueChanged<UserRackPresets>? onRackPresetsChanged,
}) => showDialog<void>(
  context: context,
  builder: (context) => PreferencesDialog(
    undoDepth: undoDepth,
    onUndoDepthChanged: onUndoDepthChanged,
    seededPresets: seededPresets,
    rackPresets: rackPresets,
    onRackPresetsChanged: onRackPresetsChanged,
  ),
);

/// Edit > Preferences.
class PreferencesDialog extends StatefulWidget {
  const PreferencesDialog({
    required this.undoDepth,
    required this.onUndoDepthChanged,
    this.seededPresets,
    this.rackPresets,
    this.onRackPresetsChanged,
    super.key,
  });

  /// The depth in force when the dialog opened.
  final int undoDepth;

  final ValueChanged<int> onUndoDepthChanged;

  /// The seeded presets, every one of them including the hidden, so each
  /// can be shown again (DR-176 §11.175.4).
  final Map<String, RackPreset>? seededPresets;

  /// Your presets and the hidden seeded ids when the dialog opened.
  final UserRackPresets? rackPresets;

  /// Takes each change to [rackPresets]. Null hides the section.
  final ValueChanged<UserRackPresets>? onRackPresetsChanged;

  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  late final TextEditingController _depth = TextEditingController(
    text: '${widget.undoDepth}',
  );
  late int _applied = widget.undoDepth;
  String? _error;

  late UserRackPresets _presets = widget.rackPresets ?? const UserRackPresets();

  bool get _showsPresets =>
      widget.seededPresets != null &&
      widget.rackPresets != null &&
      widget.onRackPresetsChanged != null;

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

  void _changePresets(UserRackPresets next) {
    setState(() => _presets = next);
    widget.onRackPresetsChanged!(next);
  }

  void _delete(RackPreset preset) => _changePresets(
    UserRackPresets(
      presets: [
        for (final p in _presets.presets)
          if (p.id != preset.id) p,
      ],
      hiddenSeedIds: _presets.hiddenSeedIds,
    ),
  );

  void _setShown(String seedId, {required bool shown}) => _changePresets(
    UserRackPresets(
      presets: _presets.presets,
      hiddenSeedIds: {
        for (final id in _presets.hiddenSeedIds)
          if (id != seedId) id,
        if (!shown) seedId,
      },
    ),
  );

  Future<void> _rename(RackPreset preset) async {
    // EVERY OTHER NAME, SEEDED ONES INCLUDED EVEN WHEN HIDDEN: a hidden
    // seeded preset can be shown again, and then two rows would match.
    final others = <String>[
      for (final p in widget.seededPresets!.values) p.displayName,
      for (final p in _presets.presets)
        if (p.id != preset.id) p.displayName,
    ];
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenamePresetDialog(
        initialName: preset.displayName,
        otherNames: others,
      ),
    );
    if (name == null || !mounted || name == preset.displayName) return;
    _changePresets(
      UserRackPresets(
        presets: [
          for (final p in _presets.presets)
            if (p.id == preset.id) _renamed(p, name) else p,
        ],
        hiddenSeedIds: _presets.hiddenSeedIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Preferences'),
      // SCROLLABLE, because the presets section grows with what you save,
      // and Close must stay reachable on a short window.
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
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
            if (_showsPresets) ..._presetsSection(theme),
          ],
        ),
      ),
      actions: [TextButton(onPressed: _close, child: const Text('Close'))],
    );
  }

  List<Widget> _presetsSection(ThemeData theme) {
    final hidden = _presets.hiddenSeedIds;
    return [
      const SizedBox(height: 16),
      Text(kRackPresetsSectionLabel, style: theme.textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(kRackPresetsHelp, style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      if (_presets.presets.isEmpty)
        Text(kNoSavedPresets, style: theme.textTheme.bodySmall)
      else
        for (final preset in _presets.presets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(preset.displayName),
            subtitle: Text('${preset.heightU}U'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey(presetRenameKeyFor(preset.id)),
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => unawaited(_rename(preset)),
                ),
                IconButton(
                  key: ValueKey(presetDeleteKeyFor(preset.id)),
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(preset),
                ),
              ],
            ),
          ),
      const SizedBox(height: 8),
      Text('Seeded presets', style: theme.textTheme.labelMedium),
      for (final entry in widget.seededPresets!.entries)
        CheckboxListTile(
          key: ValueKey(presetShowKeyFor(entry.key)),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(entry.value.displayName),
          value: !hidden.contains(entry.key),
          onChanged: (shown) => _setShown(entry.key, shown: shown ?? true),
        ),
    ];
  }
}

/// [p] under a new display name, every other fact kept.
RackPreset _renamed(RackPreset p, String name) => RackPreset(
  id: p.id,
  displayName: name,
  heightU: p.heightU,
  formFactor: p.formFactor,
  widthClass: p.widthClass,
  railType: p.railType,
  usableDepth: p.usableDepth,
  weightCapacity: p.weightCapacity,
  isSwingFrame: p.isSwingFrame,
  hingeSide: p.hingeSide,
);

/// Renames one of your presets. Pops the trimmed name, or null on Cancel.
class _RenamePresetDialog extends StatefulWidget {
  const _RenamePresetDialog({
    required this.initialName,
    required this.otherNames,
  });

  final String initialName;
  final List<String> otherNames;

  @override
  State<_RenamePresetDialog> createState() => _RenamePresetDialogState();
}

class _RenamePresetDialogState extends State<_RenamePresetDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final error = presetNameError(_name.text, widget.otherNames);
    setState(() => _error = error);
    if (error == null) Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename preset'),
    content: SizedBox(
      width: 380,
      child: TextField(
        key: const ValueKey('preferences.rename-name'),
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('preferences.rename-confirm'),
        onPressed: _commit,
        child: const Text('Save'),
      ),
    ],
  );
}
