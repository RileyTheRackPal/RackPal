// THE BATCH INSPECTOR (M4-F2 `#209`, DR-063, docs/06 §2 and §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §2's RIGHT DOCK, IN ITS ONE BUILT STATE
// ═══════════════════════════════════════════════════════════════════════
// §2 draws a 340 px third pane and says the dock *"swaps to a batch
// inspector when more than one grid row is selected"*. The rest of the
// time it holds three live previews, which are M4-K (`#182`) and are not
// built, so today the dock exists only in this state and is absent
// otherwise. That is `device_builder_screen.dart`'s standing rule rather
// than a shortcut: a pane that opens onto nothing is the `UnbuiltView`
// defect wearing a different hat.
//
// ═══════════════════════════════════════════════════════════════════════
// IT READS, AND THE GRID WRITES
// ═══════════════════════════════════════════════════════════════════════
// Editing across a selection is BUILT and is done in the grid: a cell
// edit on a selected row applies to every selected row (DR-063), which is
// §4.6's own sentence. What this pane adds is the thing the grid cannot
// show, because a grid shows one row at a time per line: **which fields
// the selection agrees on and which it does not**, at a glance, before
// somebody decides what to change.
//
// SETTING A FIELD FROM THIS PANE IS BUILT NOW (M4-F11, `#703`), and the
// refactor it waited on is why. Every column's control used to be private
// to `port_grid.dart` and bound to ONE port's value, and "mixed" is not a
// value; `port_cells.dart` is those controls extracted, with an explicit
// `mixedLabel` that makes a control hold NOTHING and write nothing until
// it is touched. The dock draws the same control the grid draws, so the
// two panes cannot disagree about what a column offers.
//
// THE SAFETY PROPERTY IS STRUCTURAL, NOT REMEMBERED. docs/06 §4.6's
// "left untouched unless explicitly set" is enforced by the controls
// themselves: a menu in the mixed state holds null and fires only from a
// pick, and a text cell seeds EMPTY and compares its commit against that
// seed. `#703` named the exact defect this prevents, a control that fires
// `onChanged` on construction or on focus and writes the dash back across
// N rows.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY SPELLING COMES FROM CORE
// ═══════════════════════════════════════════════════════════════════════
// `portBatchLabel` renders the three readings, over the same label
// functions the grid's cells use. The moment this file writes
// `value.name` the product owns a second speller, and the first time one
// changes the dock and the grid disagree about what a port is while both
// are visible.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/batch_cells.dart';

/// The dock's authored width (docs/06 §2).
const double kBatchInspectorWidth = 340;

/// The line under the count once this pane can write.
///
/// STATES THE SAFETY RULE RATHER THAN THE CAPABILITY. "You can edit here"
/// is obvious from the controls; what is not obvious, and what DR-063
/// spends its argument on, is that a field showing `Mixed` is not about
/// to be flattened by looking at it.
const String kBatchInspectorHint =
    'Set a field to change all of them. Nothing changes until you change '
    'it.';

/// What the grid tells the screen about its selection.
///
/// A RECORD OF PLAIN VALUES, so the screen can hold it, compare it and
/// rebuild on a real change rather than on every frame.
typedef PortBatchContext = ({
  /// The selected port keys, in the order the grid shows them.
  List<String> portKeys,

  /// The batch-writable columns the grid is currently showing.
  ///
  /// THE GRID'S OWN VISIBLE SET, minus what a batch may not write. A dock
  /// listing all 43 batch columns in 340 points would be a scroll nobody
  /// reads; listing exactly what the grid shows means the pane answers
  /// for the columns the person already chose to look at, and it grows
  /// when they open a pack.
  List<PortColumnId> columns,
});

/// docs/06 §2's right dock, in its batch state.
class BatchInspector extends StatelessWidget {
  const BatchInspector({
    required this.body,
    required this.registries,
    required this.context_,
    this.onWrite,
    super.key,
  });

  final TemplateBody body;
  final Registries registries;
  final PortBatchContext context_;

  /// Runs one column's write across the whole selection, as ONE undo
  /// entry. Null makes this pane read-only, which is what a render test
  /// wants and is the state it shipped in at M4-F2.
  ///
  /// THE PANE DOES NOT BUILD THE COMMANDS. `buildBatchWrite` does, in
  /// core, and the caller transacts them: a dock that assembled its own
  /// would be the second place a batch edit is defined.
  final void Function(PortColumnId column, Object? value)? onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = context_.portKeys.length;

    return SizedBox(
      width: kBatchInspectorWidth,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$n ports selected',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // WHAT IT SAYS DEPENDS ON WHAT IT CAN DO. Before
                    // M4-F11 this pane could only read, and it pointed at
                    // the grid rather than showing values a person would
                    // try to type into. It can write now, and says the
                    // rule that matters instead: nothing moves until you
                    // move it (docs/06 §4.6, DR-063).
                    onWrite == null
                        ? 'Edit any cell in the grid to change all of them.'
                        : kBatchInspectorHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: context_.columns.length,
                itemBuilder: (context, index) {
                  final column = context_.columns[index];
                  final batch = summariseBatch(
                    body: body,
                    column: column,
                    portKeys: context_.portKeys,
                  );
                  return _Field(
                    header: portColumnHeader(column),
                    reading: portBatchLabel(column, batch, registries),
                    control: onWrite == null
                        ? null
                        : buildBatchCell(
                            column: column,
                            batch: batch,
                            registries: registries,
                            onWrite: (value) => onWrite!(column, value),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One column's header and what the selection holds for it.
class _Field extends StatelessWidget {
  const _Field({required this.header, required this.reading, this.control});

  final String header;
  final String reading;

  /// The editable control, or null when this pane is read-only or the
  /// column has none. A column with no control still shows its READING,
  /// which is what keeps `KEY` and `WAS CALLED` on the pane: they are
  /// facts worth seeing and not facts a batch may write.
  final Widget? control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A DISAGREEMENT IS TONED APART FROM A VALUE, not only worded apart.
    // DR-063 is about a reader's glance, and a sentence in the same
    // colour as every other row is a sentence they scan past.
    final mixed = reading.startsWith('Mixed (');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              header,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child:
                control ??
                Text(
                  reading,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: mixed ? FontStyle.italic : null,
                    color: mixed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
