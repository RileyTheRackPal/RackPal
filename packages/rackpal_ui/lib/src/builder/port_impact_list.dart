// The per-row before-and-after list DR-078 §11.77.3 puts in front of every
// bulk write. M4-F7/F8/F9.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE WIDGET FOR THREE DIALOGS
// ═══════════════════════════════════════════════════════════════════════
// `Renumber…`, `Find & replace` and `Change type…` all produce
// `PortImpactRow`s, so they all draw this. Three lists would be three
// places the arrow points the wrong way and three spellings of "no
// change", on the one screen whose whole job is to be believed.
//
// IT RENDERS STRINGS AND KNOWS NOTHING ELSE. A row carries what a cell
// would print, so this file has no idea whether it is showing a label, a
// key or a connector, which is exactly why it can show all three.
//
// ═══════════════════════════════════════════════════════════════════════
// A ROW THAT CHANGES NOTHING IS STILL DRAWN, AND SAYS SO
// ═══════════════════════════════════════════════════════════════════════
// A search matching twelve rows and changing none of them has told the
// person the most useful thing this dialog can tell them. Hiding those
// rows would leave an empty list under a count of twelve, which reads as
// a broken screen rather than as an answer.
//
// A REAL WIDGET TABLE, NOT A CANVAS. docs/05 §12.1's argument for the
// Schedule applies to every table this package draws: every cell here is
// a `Text`, so it is selectable and screen-reader navigable without a
// hand-written semantics layer.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the `after` column prints when an operation would clear a value.
///
/// NOT `kUnknownCell`'s dash, which means "nobody has measured this"
/// (G4/CR-114), and not an empty cell, which reads as a rendering bug in a
/// column of arrows. The word says the act.
const String kImpactCleared = '(cleared)';

/// What a row prints when it matches and changes nothing.
const String kImpactUnchanged = 'no change';

/// The scrollable impact list.
///
/// [rows] is in the order the operation will apply them, which for every
/// caller is the selection's display order. Nothing sorts here: a list
/// that reordered its rows would stop describing the act.
class PortImpactList extends StatelessWidget {
  const PortImpactList({required this.rows, this.maxHeight = 240, super.key});

  final List<PortImpactRow> rows;

  /// Tall enough for eight rows at this density, short enough that the
  /// dialog's own buttons stay on screen at 1080 logical px, which is the
  /// floor docs/04 §1 sets before the shell becomes the tablet viewer.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nothing matches.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        child: ListView.builder(
          primary: false,
          shrinkWrap: true,
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            final changes = row.before != row.after;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THE KEY IS THE JOIN, so it leads the row: it is what a
                  // person uses to find the port in the grid behind this
                  // dialog, and it is the one column that is never the
                  // thing being changed except in the scope where it is.
                  SizedBox(
                    width: 116,
                    child: Text(
                      row.key,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                row.before.isEmpty ? '(blank)' : row.before,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (changes) ...[
                              Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  row.after.isEmpty
                                      ? kImpactCleared
                                      : row.after,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: kConsoleEmphasis,
                                  ),
                                ),
                              ),
                            ] else
                              Text(
                                kImpactUnchanged,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        // THE NOTE IS THE REASON THIS IS A LIST AND NOT A
                        // COUNT. It is where a row says what else the
                        // write does to it: a named value a family default
                        // would overwrite (DR-060), or a key that was
                        // already published when the builder opened
                        // (CR-051).
                        if (row.note case final String note)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 11,
                                  color: scheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    note,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.tertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The summary line above an impact list.
///
/// **A COUNT OF ROWS THAT CHANGE, NOT OF ROWS THAT MATCH**, and the
/// difference is the point: "12 rows match, 3 will change" is a sentence a
/// person can act on, and "12 rows" is the one that gets approved by
/// accident. The notes are counted separately for the same reason.
String portImpactSummary(List<PortImpactRow> rows) {
  final changing = portImpactChanges(rows).length;
  final notes = portImpactNoteCount(rows);
  final matched = rows.length;
  final head = changing == matched
      ? '$matched ${_rows(matched)} will change'
      : '$matched ${_rows(matched)} matched, $changing will change';
  return notes == 0 ? '$head.' : '$head, $notes to check.';
}

String _rows(int n) => n == 1 ? 'row' : 'rows';
