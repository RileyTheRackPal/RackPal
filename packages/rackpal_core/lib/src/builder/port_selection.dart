// What "the selection" is in the Device Builder's port grid (DR-061,
// M4-F0 #695, docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// A ROW RANGE AND A FOCUSED COLUMN, NOT A RECTANGLE OF CELLS
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §4.6 described this two ways, "the top cell of the selection"
// and "select N rows, edit any cell", and the corpus never said which.
// DR-061 settles it on a census of that table's own fourteen rows: nine
// want whole rows, three name their own columns in their own definitions
// (fill series takes the label, change type takes connector and family,
// find & replace takes a scope the dialog picks), one wants a single
// column and one is a single cell. A rectangle would be read by `Fill
// down` alone.
//
// So the column is not part of the selection's shape. It is one value,
// carried alongside, and it comes from whichever cell holds focus.
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS THE SET THE TICK BOXES ALREADY WERE
// ═══════════════════════════════════════════════════════════════════════
// M4-E shipped `_ticked`, a `Set<String>` of port keys feeding the delete
// button. DR-061 makes the checkbox an affordance ON the selection rather
// than a second set beside it, so `Delete` keeps acting on exactly what it
// acted on before and M4-E's delete tests keep their meaning.
//
// KEYS, NOT INDICES, AND NOT `PortDef` IDENTITY. `port_grid.dart` already
// held strings for the reason stated there: a rename replaces the key, so
// a selection matching by identity would follow a row that no longer
// exists. Indices would be worse still once F5's view-only sort makes
// display order differ from declared order.
import 'package:rackpal_core/src/builder/port_table.dart';

/// The grid's selection: which rows, where a `Shift`+click extends from,
/// and which column has focus.
///
/// IMMUTABLE, AND EVERY GESTURE RETURNS A NEW ONE. The grid holds one of
/// these in `State` and replaces it; nothing mutates a selection in place,
/// which is what lets the gestures below be tested as pure functions
/// rather than through a widget.
final class PortSelection {
  PortSelection({
    Set<String> keys = const <String>{},
    this.anchor,
    this.column,
  }) : keys = Set.unmodifiable(keys);

  /// Nothing selected, no anchor, no focused column.
  static final PortSelection empty = PortSelection();

  /// The selected rows, by `PortDef.key`. Unordered: [inOrder] and [top]
  /// are how a caller asks the question that has an answer.
  final Set<String> keys;

  /// The row a `Shift`+click extends from, which is the last row a plain
  /// click or a toggle touched.
  ///
  /// NOT "the first selected row". Excel's anchor stays put across a
  /// shift-extend so that a second shift-click re-extends from the same
  /// place rather than from wherever the first one landed, and a person
  /// correcting an over-long drag depends on exactly that.
  final String? anchor;

  /// The column whichever cell holds focus is in, or null when focus is
  /// not in the grid.
  ///
  /// The ONE consumer that needs it is `Fill down`, which has to know
  /// which column to copy. Every other operation in §4.6 either names its
  /// own columns or wants whole rows.
  final PortColumnId? column;

  bool get isEmpty => keys.isEmpty;

  bool get isNotEmpty => keys.isNotEmpty;

  int get length => keys.length;

  bool contains(String key) => keys.contains(key);

  /// The selected rows in [order], which is DISPLAY order and not the
  /// declared order once F5's view-only sort exists.
  ///
  /// Filters [order] rather than sorting [keys], so a key the grid no
  /// longer shows simply does not appear. That is the same defensive
  /// shape `buildPortTable` uses and it means a stale selection degrades
  /// to a smaller one rather than to a crash.
  List<String> inOrder(List<String> order) => [
    for (final key in order)
      if (keys.contains(key)) key,
  ];

  /// The first selected row in [order]: §4.6's "the top cell of the
  /// selection", once DR-061 has said the selection is rows.
  String? top(List<String> order) {
    for (final key in order) {
      if (keys.contains(key)) return key;
    }
    return null;
  }

  /// Selects exactly [rows], anchoring on the last of them, and keeps the
  /// focused column.
  ///
  /// FOR AN OPERATION THAT CREATED THE ROWS IT WANTS SELECTED, which is
  /// `Ctrl+J` (M4-F6): duplicate-then-retype is the gesture the clone
  /// exists for, and leaving the selection on the SOURCES means the next
  /// keystroke edits the rows the person just copied from. Not built out
  /// of `toggle`, which anchors per call and would leave the anchor on
  /// whichever row happened to be last in the loop.
  ///
  /// An empty [rows] gives an empty selection rather than leaving the old
  /// one: a caller that produced nothing is saying so.
  PortSelection replacedWith(Iterable<String> rows) {
    final keys = rows.toList();
    return PortSelection(
      keys: keys.toSet(),
      anchor: keys.isEmpty ? null : keys.last,
      column: column,
    );
  }

  /// Selects [key] alone and anchors there. A plain click.
  PortSelection selectOnly(String key) =>
      PortSelection(keys: {key}, anchor: key, column: column);

  /// Adds or removes [key], and anchors there. `Ctrl`+click, and the tick
  /// box, which DR-061 makes the same gesture.
  ///
  /// ANCHORS EVEN WHEN REMOVING. The anchor is "where the hand last was",
  /// not "what is selected": a person who unticks a row and then
  /// shift-clicks means to range from the row they just touched.
  PortSelection toggle(String key) => PortSelection(
    keys: keys.contains(key) ? ({...keys}..remove(key)) : ({...keys}..add(key)),
    anchor: key,
    column: column,
  );

  /// Selects the contiguous run of [order] from [anchor] to [key].
  /// `Shift`+click.
  ///
  /// REPLACES THE SET rather than adding to it, which is what makes a
  /// second shift-click a correction rather than an accumulation.
  ///
  /// [order] IS THE VISIBLE ROWS, AND THAT IS A SAFETY RULE RATHER THAN A
  /// CONVENIENCE. A collapsed band's rows are not in it, so a range drawn
  /// across a folded bank does not quietly pick up forty rows the person
  /// cannot see and then let `Fill down` write to them. Collapsing a band
  /// does NOT deselect what is already selected: folding to tidy the view
  /// is not a gesture about the selection, and a user who selected rows
  /// and then folded still knows what they picked.
  ///
  /// With no anchor, or an anchor [order] no longer holds, this is a
  /// plain click: there is no range without two ends.
  PortSelection extendTo(String key, List<String> order) {
    final from = anchor == null ? -1 : order.indexOf(anchor!);
    final to = order.indexOf(key);
    if (from < 0 || to < 0) return selectOnly(key);
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    return PortSelection(
      keys: {for (var i = lo; i <= hi; i++) order[i]},
      anchor: anchor,
      column: column,
    );
  }

  /// The same rows, with focus reported in [id].
  PortSelection withColumn(PortColumnId id) =>
      PortSelection(keys: keys, anchor: anchor, column: id);

  /// The same rows, with no column focused.
  PortSelection withoutColumn() => PortSelection(keys: keys, anchor: anchor);

  /// Drops every key not in [live], and the anchor with them.
  ///
  /// Called on every build, because a deleted or renamed port must not
  /// leave a count under the toolbar that counts rows which are not
  /// there. M4-E did this inline against `_ticked`; it lives here now so
  /// the rule is stated once and tested once.
  PortSelection prunedTo(Set<String> live) {
    final kept = {
      for (final key in keys)
        if (live.contains(key)) key,
    };
    if (kept.length == keys.length &&
        (anchor == null || live.contains(anchor))) {
      return this;
    }
    return PortSelection(
      keys: kept,
      // `contains` takes an `Object?`, so a null anchor answers false and
      // needs no guard of its own.
      anchor: live.contains(anchor) ? anchor : null,
      column: column,
    );
  }
}

/// The row after [key] in [order], or null at the end.
///
/// WHAT `Enter` MOVES TO (docs/06 §4.6 row 1). It crosses a band header
/// without stopping, because [order] is the grid's flat row list and a
/// band is a run inside it rather than a break in it: `PortTable.rows`
/// states the same thing for the same reason.
///
/// `PortCellFocusRegistry.moveDown` in rackpal_ui is the caller (#949). Until
/// then Enter used geometry, and at the last row of a bank the nearest
/// focusable below was in the next band's header, so Enter left the grid.
String? rowBelow(String key, List<String> order) {
  final at = order.indexOf(key);
  if (at < 0 || at + 1 >= order.length) return null;
  return order[at + 1];
}

/// The row before [key] in [order], or null at the top.
///
/// NOTHING CALLS THIS YET (#945): the port grid has no Tab handling of its own,
/// so Tab does what default focus traversal does. #949 decides whether the grid
/// needs these moves or they go.
String? rowAbove(String key, List<String> order) {
  final at = order.indexOf(key);
  if (at <= 0) return null;
  return order[at - 1];
}

/// The column after [id] in [columns], or null at the right edge.
///
/// TAB'S MOVE, and it takes the VISIBLE columns rather than
/// `PortColumnId.values`: a pack the user has closed is not a cell, and
/// tabbing into one would move focus somewhere nothing is drawn.
///
/// NOTHING CALLS THIS YET (#945): the port grid has no Tab handling of its own,
/// so Tab does what default focus traversal does. #949 decides whether the grid
/// needs these moves or they go.
PortColumnId? columnAfter(PortColumnId id, List<PortColumnId> columns) {
  final at = columns.indexOf(id);
  if (at < 0 || at + 1 >= columns.length) return null;
  return columns[at + 1];
}

/// The column before [id] in [columns], or null at the left edge.
///
/// NOTHING CALLS THIS YET (#945): the port grid has no Tab handling of its own,
/// so Tab does what default focus traversal does. #949 decides whether the grid
/// needs these moves or they go.
PortColumnId? columnBefore(PortColumnId id, List<PortColumnId> columns) {
  final at = columns.indexOf(id);
  if (at <= 0) return null;
  return columns[at - 1];
}
