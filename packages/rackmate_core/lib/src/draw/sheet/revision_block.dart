// rackmate_core/src/draw/sheet/revision_block.dart — pure Dart.
//
// docs/08-pdf-export.md §5.3's revision block: directly above the title
// block, same 396 pt width, 13 pt rows, entries stacking UPWARD, a maximum
// of 8 visible, columns REV 30 · DATE 62 · DESCRIPTION 268 · BY 36 = 396.
//
// WHAT IS REAL AND WHAT IS NOT, verified by opening the model rather than
// assumed:
//
//   * `RevisionEntry` EXISTS (`model/rack_document.dart`) with
//     `{revision, date, description, by}`, is held as
//     `RackDocument.revisionBlock` (defaulting to `[]`) and round-trips
//     through `json_codec.dart`.
//   * NO GENERATOR EXISTS. A repo-wide search finds no writer outside the
//     codec and the starter-authoring tool. §5.3's "generated from project
//     history, not hand-entered" is therefore UNBUILT, and this file must
//     not pretend otherwise.
//
// So the normal case in this build is an EMPTY list, and the honest
// rendering of that is one row reading `NO REVISIONS RECORDED`. Not eight
// blank rows — a blank grid reads as a form somebody forgot to fill in.
// And not a fabricated `A · today · Initial issue`, which would be the
// exporter inventing project history.
//
// IT NEVER READS `RackDocument.sequence`. That is the strictly-monotonic
// sync cursor and is explicitly never called "revision" (CR-094). A
// revision block backfilled from a transaction counter would be a number
// that looks like history and is not.
//
// REVISION CLOUDS (§5.3, DR-005) ARE NOT BUILT. A cloud encircles "each
// element changed since the last issued revision"; with no revision
// generator there is no last issued revision and therefore no such set.
// Omitted whole and recorded as a stated DR-005 deviation.
//
// STACKING DIRECTION, stated because the design brief for this stage and
// the doc read differently. §5.3 says entries stack UPWARD. Under the
// drafting convention that phrase names, the block GROWS upward from the
// title block: the column header sits at the bottom, adjacent to the title
// block, the oldest visible entry sits just above it, and the newest is on
// top. That is what is implemented. (The stage's design note glossed
// "upward" as "newest nearest the title block", which is the opposite
// order; the doc's own word governs, and either way the ordering is
// asserted by a test rather than left to the reader.)

import 'dart:math' as math;

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackmate_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackmate_core/src/draw/sheet/text_fit.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/rack_document.dart';

/// §5.3's column widths, in order: REV, DATE, DESCRIPTION, BY. Sums to
/// [kTitleBlockWidth] (396) — asserted by `revision_block_test.dart`.
const List<double> kRevisionColumnWidths = <double>[30, 62, 268, 36];

/// §5.3's "maximum 8 visible".
const int kMaxVisibleRevisions = 8;

/// The overflow line's wording.
///
/// §5.3 says `SEE SHEET T0.00 FOR FULL REVISION HISTORY`. T0.00 IS NOT IN
/// THIS SHEET SET — it is an M6 sheet — and pointing a reader at a sheet
/// that is not in the file is precisely what T0.00's own drawing-index rule
/// forbids ("generated after the sheet list resolves, so it can never
/// reference a sheet that is not in the file"). So the line points at the
/// project file instead, which does exist.
String overflowRevisionText(int hidden) =>
    '+$hidden EARLIER REVISION${hidden == 1 ? '' : 'S'} — SEE PROJECT FILE';

/// What an empty revision list prints. A fact, not a blank.
const String kNoRevisionsText = 'NO REVISIONS RECORDED';

/// Padding inside a revision cell.
const double _kCellPad = 3;

/// The revision entries actually shown, oldest first — the newest
/// [kMaxVisibleRevisions] of [revisions].
///
/// Sorted by `date`, tie-broken by `revision` then `description`, so the
/// order on paper never depends on the order the list happened to be
/// decoded in (§8.4: stable iteration order everywhere).
List<RevisionEntry> visibleRevisions(List<RevisionEntry> revisions) {
  final sorted = sortedRevisions(revisions);
  if (sorted.length <= kMaxVisibleRevisions) return sorted;
  return sorted.sublist(sorted.length - kMaxVisibleRevisions);
}

/// [revisions] in a deterministic oldest-to-newest order.
List<RevisionEntry> sortedRevisions(List<RevisionEntry> revisions) {
  final sorted = revisions.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byRevision = a.revision.compareTo(b.revision);
      return byRevision != 0
          ? byRevision
          : a.description.compareTo(b.description);
    });
  return sorted;
}

/// The newest entry's revision label, or `null` when there is no history —
/// what the title block's REV field resolves from.
String? newestRevisionLabel(List<RevisionEntry> revisions) {
  final sorted = sortedRevisions(revisions);
  return sorted.isEmpty ? null : sorted.last.revision;
}

/// How many BODY rows the block needs for [revisions] — what
/// `SheetLayout.resolve` sizes the box from. Excludes the column header
/// row, which the layout adds.
int revisionBodyRowCount(List<RevisionEntry> revisions) {
  if (revisions.isEmpty) return 1; // the NO REVISIONS RECORDED row
  final shown = visibleRevisions(revisions).length;
  final hidden = revisions.length - shown;
  return shown + (hidden > 0 ? 1 : 0);
}

/// One laid-out row's four cell strings, in column order.
typedef _Row = ({String rev, String date, String description, String by});

/// Builds the revision block into [box] (from
/// `SheetLayout.revisionBlockBox`).
///
/// [box] must be `(revisionBodyRowCount(revisions) + 1) *
/// kRevisionRowHeight` tall — the layout and this builder derive it from
/// the same function, and an `assert` here catches a caller that resolved
/// the layout from a different list than it drew.
LayerBuild buildRevisionBlockLayer({
  required DBox box,
  required List<RevisionEntry> revisions,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  final bodyRows = revisionBodyRowCount(revisions);
  assert(
    (box.height - (bodyRows + 1) * kRevisionRowHeight).abs() < 0.001,
    'buildRevisionBlockLayer: box height ${box.height} does not match '
    '${bodyRows + 1} rows of $kRevisionRowHeight pt — the layout was '
    'resolved from a different revision list than the one being drawn',
  );

  // Rows bottom-up: the header sits against the title block, the oldest
  // shown entry above it, the newest on top (see the file header).
  final shown = visibleRevisions(revisions);
  final hidden = revisions.length - shown.length;
  final rows = <_Row>[
    if (revisions.isEmpty)
      (rev: '', date: '', description: kNoRevisionsText, by: '')
    else ...[
      if (hidden > 0)
        (rev: '', date: '', description: overflowRevisionText(hidden), by: ''),
      for (final entry in shown)
        (
          rev: entry.revision,
          date: formatSheetDate(entry.date),
          description: entry.description,
          by: entry.by,
        ),
    ],
  ];

  final ops = <DiagramOp>[
    // Block outline.
    OpRect(box, stroke: sheetRule(palette.rule, kBlockOutlineWidthPt)),
  ];

  // Column separators, full height.
  var x = box.left;
  for (var i = 0; i < kRevisionColumnWidths.length - 1; i++) {
    x += kRevisionColumnWidths[i];
    ops.add(
      OpLine(
        DPt(x, box.top),
        DPt(x, box.bottom),
        sheetRule(palette.rule, kTableRuleWidthPt),
      ),
    );
  }

  final headerStyleCentre = _cellStyle(
    SheetTextSizes.revisionHeader,
    palette.mutedText,
    TextAnchor.midCenter,
  );
  final headerStyleLeft = _cellStyle(
    SheetTextSizes.revisionHeader,
    palette.mutedText,
    TextAnchor.midLeft,
  );
  final rowStyleCentre = _cellStyle(
    SheetTextSizes.revisionRow,
    palette.text,
    TextAnchor.midCenter,
  );
  final rowStyleLeft = _cellStyle(
    SheetTextSizes.revisionRow,
    palette.text,
    TextAnchor.midLeft,
  );

  // The header row occupies the BOTTOM band of the box.
  final headerTop = box.bottom - kRevisionRowHeight;
  _emitRow(
    ops,
    box: box,
    top: headerTop,
    row: (rev: 'REV', date: 'DATE', description: 'DESCRIPTION', by: 'BY'),
    centreStyle: headerStyleCentre,
    leftStyle: headerStyleLeft,
    measurer: measurer,
  );

  for (var i = 0; i < rows.length; i++) {
    final top = headerTop - (i + 1) * kRevisionRowHeight;
    ops.add(
      OpLine(
        DPt(box.left, top + kRevisionRowHeight),
        DPt(box.right, top + kRevisionRowHeight),
        sheetRule(palette.rule, kTableRuleWidthPt),
      ),
    );
    _emitRow(
      ops,
      box: box,
      top: top,
      row: rows[i],
      centreStyle: rowStyleCentre,
      leftStyle: rowStyleLeft,
      measurer: measurer,
    );
  }

  return (
    ops: ops,
    minTextPt: math.min(
      SheetTextSizes.revisionHeader,
      SheetTextSizes.revisionRow,
    ),
    inkBounds: box.inflate(kBlockOutlineWidthPt / 2),
  );
}

void _emitRow(
  List<DiagramOp> ops, {
  required DBox box,
  required double top,
  required _Row row,
  required TextStyleSpec centreStyle,
  required TextStyleSpec leftStyle,
  required TextMeasurer measurer,
}) {
  final cells = <String>[row.rev, row.date, row.description, row.by];
  // REV centre · DATE centre · DESCRIPTION left · BY centre (§5.3).
  const leftAligned = <bool>[false, false, true, false];
  final midY = top + kRevisionRowHeight / 2;

  var x = box.left;
  for (var i = 0; i < cells.length; i++) {
    final width = kRevisionColumnWidths[i];
    final text = cells[i];
    if (text.isNotEmpty) {
      final style = leftAligned[i] ? leftStyle : centreStyle;
      final fitted = fitTextToWidth(
        text,
        width - 2 * _kCellPad,
        style: style,
        measurer: measurer,
      );
      if (fitted.isNotEmpty) {
        ops.add(
          OpText(
            fitted,
            DPt(
              leftAligned[i] ? x + _kCellPad : x + width / 2,
              midY,
            ),
            style,
          ),
        );
      }
    }
    x += width;
  }
}

TextStyleSpec _cellStyle(double sizePt, int argb, TextAnchor anchor) =>
    TextStyleSpec(
      font: kSheetFont,
      sizePt: sizePt,
      argb: argb,
      anchor: anchor,
    );
