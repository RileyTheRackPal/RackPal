// `Ctrl+H` `Find & replace`, docs/06 §4.6. M4-F8, board `#698`, DR-078
// §11.77.3.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SAME IMPACT LIST `Change type…` SHOWS, BY RULING
// ═══════════════════════════════════════════════════════════════════════
// DR-078 §11.77.3 gives both dialogs one preview shape rather than giving
// this one a lighter count, so there is one thing to learn and one widget
// to maintain. The reason it is the heavier shape here is the KEY scope:
// `PortDef.key` is the migration join (CR-051), a key already published
// when the builder opened may have another project's cables resolving
// through it, and undo covers this document completely and cannot reach
// them. The list is the only place a person sees that before it happens.
//
// ═══════════════════════════════════════════════════════════════════════
// REGEX IS A SWITCH THAT IS OFF, AND IT SAYS SO
// ═══════════════════════════════════════════════════════════════════════
// §4.6's own word is "opt-in". The control is a checkbox rather than a
// mode this dialog remembers between openings: an installer who turned it
// on once to strip zeros should not find `HDMI (1)` silently a capture
// group a week later.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_impact_list.dart';

/// What `[Replace]` returns.
typedef FindReplaceChoice = ({
  PortTextScope scope,
  String find,
  String replace,
  bool useRegex,
});

/// The checkbox's label, and what the tests find it by.
const String kUseRegexLabel = 'Regular expression';

/// Shows `Find & replace` and returns what to run, or null on cancel.
Future<FindReplaceChoice?> showFindReplaceDialog({
  required BuildContext context,
  required TemplateBody body,
  required List<String> selectedInOrder,
  required Set<String> openedPortKeys,
}) => showDialog<FindReplaceChoice>(
  context: context,
  builder: (context) => _FindReplaceDialog(
    body: body,
    selectedInOrder: selectedInOrder,
    openedPortKeys: openedPortKeys,
  ),
);

class _FindReplaceDialog extends StatefulWidget {
  const _FindReplaceDialog({
    required this.body,
    required this.selectedInOrder,
    required this.openedPortKeys,
  });

  final TemplateBody body;
  final List<String> selectedInOrder;
  final Set<String> openedPortKeys;

  @override
  State<_FindReplaceDialog> createState() => _FindReplaceDialogState();
}

class _FindReplaceDialogState extends State<_FindReplaceDialog> {
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replace = TextEditingController();

  /// LABEL FIRST, because it is the column a person means when they say
  /// "find and replace" without saying which, and because it is the only
  /// one of the four that cannot break anything outside this document.
  PortTextScope _scope = PortTextScope.label;
  bool _useRegex = false;

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = previewPortFindReplace(
      body: widget.body,
      selectedInOrder: widget.selectedInOrder,
      scope: _scope,
      find: _find.text,
      replace: _replace.text,
      openedPortKeys: widget.openedPortKeys,
      useRegex: _useRegex,
    );
    final rows = preview.rows ?? const <PortImpactRow>[];
    final refusal = preview.refusal;

    return AlertDialog(
      title: const Text('Find and replace'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _find,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Find',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _replace,
                    decoration: const InputDecoration(
                      labelText: 'Replace with',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // A `Wrap`, NOT A `Row`, AND A TEST FOUND THAT. Four scope
            // segments beside the regex control overflowed 560 px by 243,
            // which is `_ScheduleToolbar`'s lesson one screen over: a
            // toolbar of controls whose widths are set by their LABELS
            // cannot be laid out on one line by assertion.
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<PortTextScope>(
                  segments: [
                    for (final scope in PortTextScope.values)
                      ButtonSegment(
                        value: scope,
                        label: Text(scope.columnLabel),
                      ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (picked) =>
                      setState(() => _scope = picked.first),
                ),
                // A CHECKBOX, NOT A REMEMBERED MODE. See the header.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _useRegex,
                      onChanged: (value) =>
                          setState(() => _useRegex = value ?? false),
                    ),
                    const Text(kUseRegexLabel),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (refusal != null)
              Text(
                portFindReplaceRefusalMessage(refusal),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _find.text.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              )
            else ...[
              Text(portImpactSummary(rows), style: theme.textTheme.bodySmall),
              const Divider(),
              PortImpactList(rows: rows),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // DEAD WHILE THERE IS A REFUSAL, which covers the empty find box
          // and the invalid pattern. A row that matches nothing is NOT a
          // refusal: pressing Replace on it is allowed and does nothing,
          // because a person is entitled to confirm an empty result rather
          // than to wonder why the button is grey.
          onPressed: refusal != null
              ? null
              : () => Navigator.of(context).pop((
                  scope: _scope,
                  find: _find.text,
                  replace: _replace.text,
                  useRegex: _useRegex,
                )),
          child: const Text('Replace'),
        ),
      ],
    );
  }
}
