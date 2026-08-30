// packages/rackpal_ui/lib/src/library/library_io_dialogs.dart
//
// `File ▸ Export device library…` and `File ▸ Import device library…`
// (`#240`, DR-015 §11.15.3, AC-042, AC-058/D8).
//
// ─────────────────────────────────────────────────────────────────────────
// THE PICKER IS A DISCLOSURE, NOT A SECOND DIALOG
// ─────────────────────────────────────────────────────────────────────────
// The user's call at `#240` was "pack everything, with an Advanced
// picker". That could have been two surfaces and is one, because a
// library needs a NAME for its manifest and therefore needs a dialog
// whatever the selection rule is. The picker folds into the dialog that
// already had to exist, so the default path is a name and a button and
// the subset case costs one expansion.
//
// **EVERYTHING IS TICKED WHEN IT OPENS**, which is what makes "pack
// everything" the default rather than a second option. Untick to narrow.
// Starting empty would make the common case a select-all click and would
// pose the question the disclosure exists to avoid.
//
// ─────────────────────────────────────────────────────────────────────────
// THE IMPORT SIDE IS #236's DIALOG WITH A LIST BEHIND IT
// ─────────────────────────────────────────────────────────────────────────
// Same three obligations: say what is in the file before it lands, carry
// the inert-data sentence (docs/06 §7.3), and surface AC-042's mismatch
// as a WARNING that does not take the button away. `#240` states that
// last one directly: an archive whose hashes do not match "imports WITH A
// BADGE, it does not refuse".
//
// It names the templates rather than counting them, because a warning
// saying "3 were edited" invites exactly the question the list answers,
// and at that point the dialog is doing the work twice.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/builder/archetype_dialogs.dart'
    show portsAcrossBanks;
import 'package:rackpal_ui/src/library/device_template_io_dialogs.dart'
    show kInertDataNotice;

/// What the export dialog popped.
@immutable
final class ExportLibraryRequest {
  const ExportLibraryRequest({required this.name, required this.selected});

  /// The manifest's one field.
  final String name;

  /// The templates to pack, in the order the chooser listed them.
  final List<DeviceTemplateFile> selected;
}

/// AC-042's mismatch warning for a whole archive.
///
/// **PLURAL-SAFE BY CONSTRUCTION**, because `1 templates` is the defect
/// this repository already shipped once and wrote a practice about.
String libraryMismatchWarning(List<String> names) {
  final n = names.length;
  final subject = n == 1
      ? 'One template in this library has'
      : '$n templates in this library have';
  return '$subject been edited since the library was exported. That is '
      'allowed, and they are imported exactly as they read; the note is '
      'here so a difference from the original is not a surprise later.';
}

/// Asks which templates to pack and what to call the library.
///
/// Returns null when the user cancelled, or when there was nothing to
/// offer: a project with no authored templates has no library to export
/// and the caller says so rather than opening an empty dialog.
Future<ExportLibraryRequest?> showExportLibrary(
  BuildContext context, {
  required List<DeviceTemplateFile> candidates,
  String suggestedName = 'Shop Kit',
}) => showDialog<ExportLibraryRequest>(
  context: context,
  builder: (context) => _ExportLibraryDialog(
    candidates: candidates,
    suggestedName: suggestedName,
  ),
);

/// Confirms a library import. False means cancelled.
Future<bool> showImportLibraryConfirm(
  BuildContext context, {
  required LibraryImportPreview preview,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _ImportLibraryDialog(preview: preview),
    ) ??
    // A dismissal is a cancel. The only non-destructive reading of "the
    // dialog went away" is that nothing was copied anywhere.
    false;

class _ExportLibraryDialog extends StatefulWidget {
  const _ExportLibraryDialog({
    required this.candidates,
    required this.suggestedName,
  });

  final List<DeviceTemplateFile> candidates;
  final String suggestedName;

  @override
  State<_ExportLibraryDialog> createState() => _ExportLibraryDialogState();
}

class _ExportLibraryDialogState extends State<_ExportLibraryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.suggestedName,
  );

  /// Indices of the ticked candidates. **All of them, on open.**
  late final Set<int> _ticked = {
    for (var i = 0; i < widget.candidates.length; i++) i,
  };

  bool _showPicker = false;

  @override
  void initState() {
    super.initState();
    // THE BUTTON READS `_name.text` AND NOTHING REBUILT WHEN IT CHANGED.
    // A second defect a widget test found: without this listener the
    // Export button stayed enabled after the name was cleared, because a
    // `TextEditingController` notifies its own field and not the tree
    // around it. The button's own enablement was the only thing that
    // could tell, and only a test that types then reads the button could
    // see it.
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  String get _summary {
    final n = _ticked.length;
    final total = widget.candidates.length;
    final noun = n == 1 ? '1 template' : '$n templates';
    return n == total ? '$noun, all of them' : '$noun of $total';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Export device library'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Library name',
                helperText: 'What this library calls itself.',
              ),
            ),
            const SizedBox(height: 16),
            Text(_summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              // THE SEED'S ABSENCE IS EXPLAINED, NOT SILENT. Somebody
              // counting rows in the palette and rows here would
              // otherwise be missing 48 and have no way to know why.
              'The 48 shipped archetypes are not included: every install '
              'already has them.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showPicker = !_showPicker),
              icon: Icon(
                _showPicker ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(_showPicker ? 'Pack all' : 'Choose templates…'),
            ),
            // FLEXIBLE, NOT A FIXED HEIGHT, and a widget test is why.
            // The first draft was `SizedBox(height: 220)` and it
            // overflowed the dialog by 56 pixels the moment the picker
            // opened, which renders as the yellow and black stripe and
            // which nothing but a pumped test was going to notice before
            // a user did. `Flexible` inside a `MainAxisSize.min` column
            // lets the list take what is left and no more.
            if (_showPicker)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    itemCount: widget.candidates.length,
                    itemBuilder: (context, i) {
                      final t = widget.candidates[i];
                      final counts = portsAcrossBanks(
                        t.body.ports.length,
                        t.body.banks.length,
                      );
                      return CheckboxListTile(
                        dense: true,
                        value: _ticked.contains(i),
                        onChanged: (on) => setState(() {
                          if (on ?? false) {
                            _ticked.add(i);
                          } else {
                            _ticked.remove(i);
                          }
                        }),
                        title: Text(t.body.displayName),
                        subtitle: Text('v${t.version} · $counts'),
                      );
                    },
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
          // REFUSED ON AN EMPTY SELECTION AND ON A BLANK NAME. A library
          // with no templates is a file nobody meant to make, and the
          // manifest's one field cannot be empty or the shelf shows a
          // nameless row.
          onPressed: _ticked.isEmpty || _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  ExportLibraryRequest(
                    name: _name.text.trim(),
                    selected: [
                      for (var i = 0; i < widget.candidates.length; i++)
                        if (_ticked.contains(i)) widget.candidates[i],
                    ],
                  ),
                ),
          child: const Text('Export…'),
        ),
      ],
    );
  }
}

class _ImportLibraryDialog extends StatelessWidget {
  const _ImportLibraryDialog({required this.preview});

  final LibraryImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = preview.templateCount;
    return AlertDialog(
      title: const Text('Import device library'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preview.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              n == 1 ? '1 template' : '$n templates',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(kInertDataNotice, style: theme.textTheme.bodySmall),
            if (preview.hasMismatch) ...[
              const Divider(height: 24),
              Text(
                libraryMismatchWarning(preview.mismatched),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              // NAMED, NOT COUNTED. A warning saying "3 were edited"
              // invites exactly the question this answers.
              ...preview.mismatched.map(
                (name) => Text('· $name', style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // STILL A FILLED BUTTON WITH A MISMATCH SHOWING. AC-042 makes
          // this a warning and never a refusal, and demoting the button
          // would be a refusal wearing a suggestion's clothes.
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
