// VIEW-ONLY SORT, AND THE COMMIT THAT IS NOT (M4-F5 `#212`, DR-065,
// AC-058/D5, docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ONE PLACE IN THIS GRID WHERE THE OBVIOUS BEHAVIOUR IS WRONG
// ═══════════════════════════════════════════════════════════════════════
// Every spreadsheet sorts by writing the rows into the sorted order,
// because in a spreadsheet the row order carries no meaning beyond
// itself. Here it carries four: FIXED_ORDER draws the symbol's pins in
// it, `PORT_SEQ` numbers the schedule by it, the panel auto-layout places
// jacks by it, and `J{PORT_SEQ:2}` prints it on the silkscreen. A person
// who clicks `IMPEDANCE` to find the odd one out has said nothing about
// where the jacks are on the chassis.
//
// So a click sorts the VIEW. The declared order is untouched, the badge
// says so, and `Commit sort order` is a separate deliberate act that
// AC-058/D5 gives a confirm. The clearest evidence that a sort is a view
// is left deliberately visible: `PortTableRow.portSeq` and its designator
// are computed from the DECLARED rank, so a sorted grid shows `J01`
// somewhere in the middle. That is not a defect to paper over. It is the
// one glance that tells a person what they are looking at.
//
// ═══════════════════════════════════════════════════════════════════════
// WITHIN A BAND (DR-065)
// ═══════════════════════════════════════════════════════════════════════
// A bank is a presentation grouping the template's author made (CR-055)
// and the bands are pinned headers over it. A sort is a question about
// the rows, not about whether the grouping exists, so each band sorts
// inside itself and the headers stay. It also makes the commit a
// PERMUTATION WITHIN ONE BAND rather than a global renumber: see
// [buildSortCommit].
import 'package:rackmate_core/src/builder/port_batch.dart' show portValueLabel;
import 'package:rackmate_core/src/builder/port_commands.dart';
import 'package:rackmate_core/src/builder/port_fill.dart' show portColumnFill;
import 'package:rackmate_core/src/builder/port_table.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Which way a sorted column runs.
enum PortSortDirection { ascending, descending }

/// A view sort. Null, wherever one of these is expected, means the grid is
/// showing the declared order and nothing else is true of it.
typedef PortSort = ({PortColumnId column, PortSortDirection direction});

/// What clicking [clicked] does to the sort that is showing.
///
/// THREE STATES, AND THE THIRD IS OFF. Ascending, descending, then back to
/// the declared order. A two-state cycle would leave a person who clicked
/// a header by accident with no way back to the truth except reloading,
/// and the declared order is the truth here in a way it is not in a
/// spreadsheet.
PortSort? nextPortSort(PortSort? now, PortColumnId clicked) {
  if (!portColumnSortable(clicked)) return now;
  if (now == null || now.column != clicked) {
    return (column: clicked, direction: PortSortDirection.ascending);
  }
  return now.direction == PortSortDirection.ascending
      ? (column: clicked, direction: PortSortDirection.descending)
      : null;
}

/// Whether [id] can be sorted at all.
///
/// ONE COLUMN CANNOT, and it is `PAIRED WITH`. A pairing is a
/// `TemplateBody.passthroughPairs` entry rather than a field on either
/// port, so there is no value on the row to compare. `port_fill.dart`
/// excludes it for the same reason from the other direction.
bool portColumnSortable(PortColumnId id) => id != PortColumnId.pairedPort;

/// What [column] compares on one row, or null when the row has no value
/// for it.
///
/// THREE COLUMNS ARE NOT READ THROUGH `portColumnFill`, and each is a
/// case where the FILL's value and the CELL's value are different facts:
///
///   * `KEY` is `final` on the model so it has no fill, and it is plainly
///     sortable;
///   * `DESIG` fills the author's *hint* and displays the ALLOCATED
///     value. Sorting by what a person cannot see would be a grid lying
///     about which column it just sorted;
///   * `WAS CALLED` is a list, and an empty one is not an empty string:
///     a port that was never renamed has no former name, which is an
///     absence and sorts with the other unknowns.
Object? portSortValue(PortColumnId column, PortTableRow row) =>
    switch (column) {
      PortColumnId.portKey => row.port.key.v,
      PortColumnId.designator => row.designator,
      PortColumnId.pairedPort => null,
      PortColumnId.renamedFrom =>
        row.port.renamedFrom.isEmpty
            ? null
            : row.port.renamedFrom.map((k) => k.v).join(', '),
      _ => portColumnFill(column)?.read(row.port),
    };

/// A TOTAL comparator over two rows under [sort].
///
/// ═══════════════════════════════════════════════════════════════════════
/// AN UNKNOWN IS NOT A VALUE, SO IT LEADS NEITHER ORDERING (DR-065)
/// ═══════════════════════════════════════════════════════════════════════
/// Unknowns sort LAST ascending and last descending, which means the null
/// branch runs OUTSIDE the direction flip. A spreadsheet treats a blank
/// as the smallest thing there is; here that would answer "the lowest
/// impedance on this device is eight ports nobody has measured", which is
/// the exact fabrication G4 and CR-114 exist to prevent.
///
/// ═══════════════════════════════════════════════════════════════════════
/// NUMBERS COMPARE AS NUMBERS, EVERYTHING ELSE COMPARES AS ITS CELL
/// ═══════════════════════════════════════════════════════════════════════
/// One rule, and it is the readable one: whatever the cell shows is what
/// the column sorts by, through the same `portValueLabel` the batch
/// inspector prints. So `CONNECTOR` sorts by `HDMI Type A` rather than by
/// `conn.hdmi_a`, and a tri-state sorts `No` before `Yes`. Numbers are
/// the exception because their spelling is not their order: `110` sorts
/// after `75` and not before it.
///
/// TOTAL, ENDING IN THE PORT KEY, because `List.sort` is not stable and
/// a comparator that answers 0 for two rows would let the decoder's
/// arrival order decide what a person sees.
int comparePortRows(
  PortSort sort,
  PortTableRow a,
  PortTableRow b,
  Registries registries,
) {
  final va = portSortValue(sort.column, a);
  final vb = portSortValue(sort.column, b);

  if (va == null || vb == null) {
    if (va != null) return -1;
    if (vb != null) return 1;
    return a.port.key.v.compareTo(b.port.key.v);
  }

  var ranked = _compareKnown(sort.column, va, vb, registries);
  if (sort.direction == PortSortDirection.descending) ranked = -ranked;
  // THE TIE-BREAK DOES NOT FLIP. It is there to make the order
  // deterministic rather than to express an intent, and a tie-break that
  // reversed with the arrow would reshuffle equal rows on every click.
  return ranked != 0 ? ranked : a.port.key.v.compareTo(b.port.key.v);
}

int _compareKnown(
  PortColumnId column,
  Object a,
  Object b,
  Registries registries,
) {
  if (a is num && b is num) return a.compareTo(b);
  final sa = portValueLabel(column, a, registries);
  final sb = portValueLabel(column, b, registries);
  // CASE-INSENSITIVE FIRST, because `HDMI IN 1` and `hdmi in 2` are the
  // same column of labels to a person and two blocks apart in ASCII. The
  // case-sensitive pass behind it keeps the comparator total.
  final folded = sa.toLowerCase().compareTo(sb.toLowerCase());
  return folded != 0 ? folded : sa.compareTo(sb);
}

/// [table] with each band's rows in [sort]'s order.
///
/// RETURNS THE SAME TABLE WHEN THERE IS NO SORT, so a caller can hand the
/// result straight on without asking whether anything happened, and the
/// grid's rebuild sees the identical object.
PortTable sortPortTable(
  PortTable table,
  PortSort? sort,
  Registries registries,
) {
  if (sort == null) return table;
  return PortTable(
    bands: [
      for (final band in table.bands)
        PortTableBand(
          bankKey: band.bankKey,
          bank: band.bank,
          rows: [...band.rows]
            ..sort((a, b) => comparePortRows(sort, a, b, registries)),
        ),
    ],
  );
}

/// What the badge over a sorted grid says.
String portSortBadge(PortSort sort) {
  final way = sort.direction == PortSortDirection.ascending ? 'A–Z' : 'Z–A';
  return 'Sorted by ${portColumnHeader(sort.column)} ($way). '
      'This is a view: the ports are still in their declared order.';
}

/// Why a commit did nothing.
enum PortSortCommitRefusal {
  /// The view is already the declared order.
  nothingToCommit,

  /// Two ports in one bank claim the same `order`.
  ///
  /// A hand-edited file only: a commit within a band is a PERMUTATION of
  /// the positions that band already occupies, and a permutation of a
  /// multiset with a repeat cannot express a strict order. Named rather
  /// than half-applied, because a half-committed sort leaves the grid
  /// showing an order the file does not hold.
  positionsAreNotDistinct,
}

/// What a commit produced.
final class PortSortCommit {
  const PortSortCommit.commands(this.commands, this.movedPorts)
    : refusal = null;
  const PortSortCommit.refused(PortSortCommitRefusal this.refusal)
    : commands = const [],
      movedPorts = 0;

  final List<Command<TemplateBody>> commands;

  /// How many ports change position, which is what the confirm names.
  final int movedPorts;

  final PortSortCommitRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// Writes [sortedTable]'s row order into `PortDef.order`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A PERMUTATION WITHIN EACH BAND, NOT A RENUMBER OF THE TEMPLATE
/// ═══════════════════════════════════════════════════════════════════════
/// Each band's ports already occupy a set of positions in the declared
/// order. This hands those same positions back out in the sorted order:
/// the k-th smallest index the band already held goes to the k-th row on
/// screen. Three things fall out of that and all three are wanted.
///
///   * NO INDEX IS MINTED, so `orderBetween` cannot run out of room and
///     a commit can never be refused for lack of space;
///   * THE BAND KEEPS ITS PLACE among the other banks, because the set of
///     positions it occupies is unchanged. Committing a sort of the HDMI
///     inputs does not move the HDMI outputs;
///   * ONLY THE PORTS THAT MOVE ARE WRITTEN. A band already in the sorted
///     order produces no commands at all.
///
/// It is destructive all the same, which is the point of the confirm:
/// after this the symbol's pins, the panel layout and every automatic
/// `J` number are in the new order, and the only way back is undo.
PortSortCommit buildSortCommit({
  required TemplateBody body,
  required PortTable sortedTable,
}) {
  final commands = <Command<TemplateBody>>[];
  var moved = 0;

  for (final band in sortedTable.bands) {
    final held = [for (final row in band.rows) row.port.order.v]..sort();
    if (held.toSet().length != held.length) {
      return const PortSortCommit.refused(
        PortSortCommitRefusal.positionsAreNotDistinct,
      );
    }
    for (var i = 0; i < band.rows.length; i++) {
      final port = band.rows[i].port;
      if (port.order.v == held[i]) continue;
      moved++;
      commands.add(
        SetPortFieldCommand<FracIndex>(
          port: port.key,
          field: PortDefField.order,
          from: port.order,
          to: FracIndex(held[i]),
        ),
      );
    }
  }

  if (commands.isEmpty) {
    return const PortSortCommit.refused(
      PortSortCommitRefusal.nothingToCommit,
    );
  }
  // `body` is not read: the sorted table was built from it, and taking it
  // as an argument is what stops a caller committing one template's sort
  // against another's rows.
  assert(
    body.ports.length >= moved,
    'the sorted table names more ports than the body holds',
  );
  return PortSortCommit.commands(commands, moved);
}

/// The confirm AC-058/D5 requires, in words.
///
/// NAMES THE CONSEQUENCE AND NOT THE ROWS (DR-065). A full before-and-after
/// list is 64 lines inside a modal on the device this grid exists for, and
/// a list nobody reads is a confirm nobody reads. What a person cannot see
/// from the grid is not WHICH rows move, which is on screen in front of
/// them, but WHAT ELSE follows the order, which is three things and none
/// of them visible here.
String portSortCommitPrompt(int movedPorts) =>
    'This rewrites the declared order of '
    '${movedPorts == 1 ? '1 port' : '$movedPorts ports'}. '
    'The symbol pin order, the rear panel layout and the automatic '
    'designators all follow it. Undoable.';

/// What the grid says when a commit declines.
String portSortCommitRefusalMessage(PortSortCommitRefusal refusal) =>
    switch (refusal) {
      PortSortCommitRefusal.nothingToCommit =>
        'These ports are already in this order.',
      PortSortCommitRefusal.positionsAreNotDistinct =>
        'Two ports in one bank claim the same position, so there is no '
            'order to commit them into. Move one of them first.',
    };
