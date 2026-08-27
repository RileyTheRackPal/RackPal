// `Ctrl+R` `Renumber…`, docs/06 §4.6. M4-F7, board `#697`, DR-078.
//
// ═══════════════════════════════════════════════════════════════════════
// IT PARSES THROUGH M4-H's ENGINE AND OWNS NO GRAMMAR
// ═══════════════════════════════════════════════════════════════════════
// `parseLabelPattern` is the one parser, and the failures it returns
// already carry everything a surface needs to explain itself: WHERE (a
// character range), WHAT (one line in the user's vocabulary) and WHAT TO DO
// (a repair, which is the WHOLE pattern with the fix applied so accepting
// it is one tap and never a merge). This dialog shows those three and adds
// no rules of its own. A second pattern parser here is the defect this
// project has a practice about.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY `Start` IS IN THIS DIALOG AND `Step` CAME FREE
// ═══════════════════════════════════════════════════════════════════════
// §4.6 asks for a pattern and says nothing about a start, and without one
// the feature cannot do the thing it is for: `{n}` always counts from 1, so
// renumbering rows 9 to 16 of a bank to `IN 9`..`IN 16` would be
// unexpressible. `Step` is the same engine parameter one field over and
// costs a `SizedBox`, so it ships rather than being the next task's gap.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DIALOG SAYS WHICH ORDER IT IS ABOUT
// ═══════════════════════════════════════════════════════════════════════
// §4.6 says "current display order", and under M4-F5's view-only sort that
// is not the declared order. The two readings part in exactly one state,
// and in that state this dialog names it rather than leaving a person to
// discover that they numbered a sorted view. `#697` called that clause
// load-bearing and it is the only reason this dialog knows a sort exists.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/builder/port_impact_list.dart';

/// What `[Apply]` returns: a compiled pattern and its two seeds.
typedef RenumberChoice = ({LabelPattern pattern, int start, int step});

/// The label above the pattern field, and the string the tests find it by.
const String kRenumberPatternLabel = 'Label pattern';

/// Said only while a sort badge is showing (see the file header).
const String kRenumberSortedNote =
    'The grid is sorted, so this numbers the rows in the order you see them, '
    'not the declared order.';

/// Shows `Renumber…` over [selectedInOrder] and returns what to apply, or
/// null if the person cancelled.
Future<RenumberChoice?> showRenumberDialog({
  required BuildContext context,
  required TemplateBody body,
  required List<String> selectedInOrder,
  required bool viewIsSorted,
}) => showDialog<RenumberChoice>(
  context: context,
  builder: (context) => _RenumberDialog(
    body: body,
    selectedInOrder: selectedInOrder,
    viewIsSorted: viewIsSorted,
  ),
);

class _RenumberDialog extends StatefulWidget {
  const _RenumberDialog({
    required this.body,
    required this.selectedInOrder,
    required this.viewIsSorted,
  });

  final TemplateBody body;
  final List<String> selectedInOrder;
  final bool viewIsSorted;

  @override
  State<_RenumberDialog> createState() => _RenumberDialogState();
}

class _RenumberDialogState extends State<_RenumberDialog> {
  /// SEEDED FROM THE FIRST SELECTED LABEL'S OWN SHAPE, so the common case
  /// is a person pressing Enter. A bank of `HDMI IN 3`.. offers
  /// `HDMI IN {n}` and a start of 3, which is what "re-apply a pattern"
  /// means when the rows already have one; `inferLabelSeries` is the same
  /// reader `Ctrl+Shift+D` uses, so the two gestures cannot disagree about
  /// what the number in a label is.
  late final TextEditingController _pattern = TextEditingController(
    text: _seed?.$1 ?? '',
  );
  late final TextEditingController _start = TextEditingController(
    text: '${_seed?.$2 ?? 1}',
  );
  final TextEditingController _step = TextEditingController(text: '1');

  (String, int)? get _seed {
    final first = widget.selectedInOrder.isEmpty
        ? null
        : widget.body.ports
              .where((p) => p.key.v == widget.selectedInOrder.first)
              .firstOrNull;
    if (first == null) return null;
    final series = inferLabelSeries(first.label);
    if (series == null) {
      return first.label.isEmpty ? null : ('${first.label} {n}', 1);
    }
    final token = series.width > 1 ? '{n:${series.width}}' : '{n}';
    return ('${series.prefix}$token${series.suffix}', series.start);
  }

  @override
  void dispose() {
    _pattern.dispose();
    _start.dispose();
    _step.dispose();
    super.dispose();
  }

  int get _startValue => int.tryParse(_start.text.trim()) ?? 1;

  /// A step of 0 would write the same number to every row, which is a
  /// pattern with no token spelled the confusing way. Clamped rather than
  /// refused: the field is a nudge, not a gate.
  int get _stepValue {
    final parsed = int.tryParse(_step.text.trim()) ?? 1;
    return parsed == 0 ? 1 : parsed;
  }

  LabelPatternResult get _parsed => parseLabelPattern(_pattern.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;
    final pattern = parsed is LabelPattern ? parsed : null;
    final rows = pattern == null
        ? const <PortImpactRow>[]
        : previewPortRenumber(
            body: widget.body,
            selectedInOrder: widget.selectedInOrder,
            pattern: pattern,
            start: _startValue,
            step: _stepValue,
          );

    return AlertDialog(
      title: const Text('Renumber ports'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.viewIsSorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  kRenumberSortedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _pattern,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: kRenumberPatternLabel,
                      isDense: true,
                      border: OutlineInputBorder(),
                      helperText: 'Tokens: {n}, {n:2}, {n@2}, {A}, {a}, {rev}',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _step,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Step',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (parsed case final LabelPatternFailure failure)
              _ParseFailure(
                failure: failure,
                onRepair: () {
                  _pattern.text = failure.repair;
                  setState(() {});
                },
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
          // DISABLED ON A FAILED PARSE, not on an empty preview: a pattern
          // that changes nothing is a legitimate thing to confirm, and a
          // person who typed one is entitled to press the button and see
          // it do nothing rather than to wonder why it is grey.
          onPressed: pattern == null
              ? null
              : () => Navigator.of(context).pop((
                  pattern: pattern,
                  start: _startValue,
                  step: _stepValue,
                )),
          child: const Text('Renumber'),
        ),
      ],
    );
  }
}

/// M4-H's designed parse error, shown where the person is typing.
///
/// THE QUOTE RATHER THAN AN UNDERLINE. `LabelPatternFailure` offers both,
/// and a dialog cannot underline a range inside a `TextField` without
/// reimplementing its painting; `span` exists for exactly this caller.
class _ParseFailure extends StatelessWidget {
  const _ParseFailure({required this.failure, required this.onRepair});

  final LabelPatternFailure failure;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                failure.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.build_outlined, size: 14),
            label: Text(failure.repair),
            onPressed: onRepair,
          ),
        ),
      ],
    );
  }
}
