// One control per batch-writable column, for the dock. M4-F11, board
// `#703`, DR-063.
//
// ═══════════════════════════════════════════════════════════════════════
// IT PICKS A CONTROL, IT DOES NOT DEFINE ONE
// ═══════════════════════════════════════════════════════════════════════
// Every widget below is `port_cells.dart`'s, which is the grid's. This
// file is the switch that says which column gets which, and it is a
// switch rather than a table because the answer is already in core:
// `portColumnOptions` lists a column's closed set or answers null when
// its values are open. A second list of "which columns are dropdowns"
// would drift from that one the day an enum gains a member.
//
// ═══════════════════════════════════════════════════════════════════════
// `Mixed` IS PASSED THROUGH, NEVER RECONSTRUCTED
// ═══════════════════════════════════════════════════════════════════════
// The reading comes from `portBatchLabel`, the same function the pane's
// text rows use, so the label on a mixed control and the label on a mixed
// row are one string produced once. A control that spelled its own would
// be the second speller `port_batch.dart`'s header exists to forbid.
//
// A COLUMN WITH NO CONTROL RETURNS NULL, and the pane then shows its
// reading as text. `KEY` and `WAS CALLED` are the cases: facts worth
// seeing on the dock and facts a batch may not write (`KEY` is the
// migration join, CR-051, and renaming N of them at once is
// `Find & replace`'s job, with an impact list in front of it).
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_cells.dart';

/// The control for [column] over a selection summarised as [batch], or
/// null when the column is not batch-writable.
///
/// [onWrite] takes the VALUE, not a command: `buildBatchWrite` turns it
/// into one per row and the caller transacts them, so this file never
/// learns what a command is.
///
/// EVERY CONTROL IS KEYED [batchCellKey], and that is not only for tests.
/// The dock and the grid draw the SAME widget types over the same columns,
/// so without a key there is no way for anything, a test or a screen
/// reader walk, to say which of the two it is looking at. The first draft
/// of the widget cases proved the point by tapping a grid cell and
/// passing: the multi-row edit applied, the assertion held, and the dock
/// was never touched.
Widget? buildBatchCell({
  required PortColumnId column,
  required BatchValue batch,
  required Registries registries,
  required ValueChanged<Object?> onWrite,
}) {
  if (!portColumnBatchEditable(column)) return null;

  // ONE STRING, FROM CORE. Null for anything that is not a disagreement,
  // which is what every control below reads as "hold your value".
  final mixed = batch is BatchMixed
      ? portBatchLabel(column, batch, registries)
      : null;
  final value = batch is BatchAgreed ? batch.value : null;

  // THE TWO ID COLUMNS FIRST, because their control is chosen by what
  // they hold rather than by `portColumnOptions`, which answers null for
  // both: their sets live in `Registries` and are resolved rather than
  // enumerated.
  if (column == PortColumnId.connector) {
    return PortConnectorCell(
      key: batchCellKey(column),
      registries: registries,
      value: (value as ConnectorTypeId?) ?? const ConnectorTypeId(''),
      mixedLabel: mixed,
      onPick: onWrite,
    );
  }
  if (column == PortColumnId.family) {
    return PortFamilyCell(
      key: batchCellKey(column),
      registries: registries,
      value: (value as SignalFamilyId?) ?? const SignalFamilyId(''),
      mixedLabel: mixed,
      onPick: onWrite,
    );
  }

  final options = portColumnOptions(column);
  if (options == null) {
    // AN OPEN COLUMN: free text, or a number. `portColumnIsNumeric` is
    // the authority and is consulted whenever the reading cannot say, an
    // all-unknown numeric selection being exactly that case: the value is
    // null and null is not an `int`.
    return value is int || (value == null && portColumnIsNumeric(column))
        ? PortNumberCell(
            key: batchCellKey(column),
            value: value as int?,
            mixedLabel: mixed,
            onCommit: onWrite,
          )
        : PortTextCell(
            key: batchCellKey(column),
            value: value as String?,
            mixedLabel: mixed,
            onCommit: onWrite,
          );
  }

  // A CLOSED SET, AND UNKNOWN IS ALWAYS IN IT (G4). Every one of these
  // fields is nullable in the model because absent means unknown, so a
  // menu a person cannot get back out of would make the first pick
  // permanent. That is `PortNullableChoiceCell`'s own rule, reused.
  return PortChoiceCell<Object?>(
    key: batchCellKey(column),
    value: value,
    options: [null, ...options],
    label: (v) =>
        v == null ? kUnknownCell : portValueLabel(column, v, registries),
    mixedLabel: mixed,
    onPick: onWrite,
  );
}

/// The key every control [buildBatchCell] returns carries.
///
/// One spelling, because a test naming it by hand would be a second one.
ValueKey<String> batchCellKey(PortColumnId column) =>
    ValueKey<String>('batch.${column.name}');
