// T0.00's drawing index (docs/08 §5.5, M6-A3 `#314`, DR-212).
//
// ═══════════════════════════════════════════════════════════════════════
// BUILT FROM THE RESOLVED SET, NEVER FROM THE CATALOGUE OF ROLES
// ═══════════════════════════════════════════════════════════════════════
// docs/08 §2.2's one rule for the index: it is generated AFTER the sheet
// list resolves, so it can never reference a sheet that is not in the
// file. Several sheets are AUTO (a plan only when something is pinned to
// it, and more to come), and an index read off `SheetRole.values` would
// confidently list sheets that were never emitted. So the only input here
// is the `List<SheetDef>` the export is about to render.
//
// THE FOUR RULINGS (DR-212): every row carries both numbers the title
// blocks print (§11.211.1); flat, in set order (§11.211.2); consecutive
// pages of one schedule collapse to one row with a count (§11.211.3); and
// a set too long for the column flows into two, then three, sub-columns
// before anything is omitted, and an omission is reported (§11.211.4).
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';

/// The index's text size and row pitch, in points.
const double kCoverIndexPt = 8;
const double kCoverIndexRow = 12;

/// The most sub-columns the index divides into before it omits (§11.211.4).
const int kCoverIndexMaxColumns = 3;

/// One line of the index: one sheet, or one run of a schedule's pages.
@immutable
final class CoverIndexRow {
  const CoverIndexRow({
    required this.positions,
    required this.ids,
    required this.role,
    required this.shortRole,
    required this.suffix,
    required this.sheets,
  });

  /// `4`, or `6–8` for a run.
  final String positions;

  /// `T2.01`, or `T6.30–T6.32` for a run.
  final String ids;

  /// The role's title, `RACK ELEVATION — FRONT`: the part that gives way
  /// when the row is too narrow.
  final String role;

  /// [role]'s short form, `FRONT ELEV.`, for a narrow row.
  final String shortRole;

  /// What tells this row from its neighbours, ` · RK-1` and/or
  /// ` (3 pages)`, or empty: the part that never gives way.
  final String suffix;

  /// `RACK ELEVATION — FRONT · RK-1`, as a wide row prints it.
  String get title => '$role$suffix';

  /// The sheets this row stands for, in set order.
  final List<SheetDef> sheets;
}

/// What a sheet is about, beside its role: the rack an elevation draws,
/// or the floor a plan depicts.
String? _subject(SheetDef s) {
  final rack = s.rackDesignator?.trim();
  if (rack != null && rack.isNotEmpty) return rack;
  final plan = s.underlayName?.trim();
  if (plan != null && plan.isNotEmpty) return plan;
  final domain = s.domainName?.trim();
  if (domain != null && domain.isNotEmpty) return domain;
  return null;
}

/// Two sheets are pages of one thing when they share a role and a subject
/// (§11.211.3). Front and rear elevations differ in role, two plans in
/// underlay and two interconnect sheets in domain, so only a paginated
/// schedule ever runs. Without the domain term the set's interconnect
/// sheets, adjacent and sharing a role, would index as one sheet of
/// several pages.
bool _samePagesOf(SheetDef a, SheetDef b) =>
    a.role == b.role &&
    a.rackId == b.rackId &&
    a.underlayId == b.underlayId &&
    a.domainId == b.domainId;

/// The index's rows for [sheets], the RESOLVED set, in its order.
List<CoverIndexRow> coverIndexRows(List<SheetDef> sheets) {
  final rows = <CoverIndexRow>[];
  var i = 0;
  while (i < sheets.length) {
    var j = i + 1;
    while (j < sheets.length && _samePagesOf(sheets[i], sheets[j])) {
      j++;
    }
    final run = sheets.sublist(i, j);
    final first = run.first;
    final last = run.last;
    final subject = _subject(first);
    rows.add(
      CoverIndexRow(
        positions: run.length == 1
            ? '${first.index}'
            : '${first.index}–${last.index}',
        ids: run.length == 1 ? first.ncsId : '${first.ncsId}–${last.ncsId}',
        role: first.title,
        shortRole: first.role.shortTitle,
        suffix: [
          if (subject != null) ' · $subject',
          if (run.length > 1) ' (${run.length} pages)',
        ].join(),
        sheets: List.unmodifiable(run),
      ),
    );
    i = j;
  }
  return rows;
}

/// [row]'s title fitted to [width]: the full title where it fits, then
/// the role's short form, and only then the short form cut, giving way
/// from the ROLE and never the suffix, since the rack is what tells one
/// elevation row from the next.
String _fitTitle(
  CoverIndexRow row,
  double width,
  TextStyleSpec style,
  TextMeasurer measurer,
) {
  double w(String t) => measurer.measureText(t, style).advanceWidth;
  if (w(row.title) <= width) return row.title;
  final short = '${row.shortRole}${row.suffix}';
  if (w(short) <= width) return short;
  final suffixW = w(row.suffix);
  if (suffixW >= width) {
    return fitTextToWidth(short, width, style: style, measurer: measurer);
  }
  final role = fitTextToWidth(
    row.shortRole,
    width - suffixW,
    style: style,
    measurer: measurer,
  );
  return '$role${row.suffix}';
}

/// What [drawCoverIndex] drew.
@immutable
final class CoverIndexResult {
  const CoverIndexResult(this.ops, this.columns, this.omitted);

  final List<DiagramOp> ops;

  /// Sub-columns used: 1, 2 or [kCoverIndexMaxColumns].
  final int columns;

  /// Sheets the index could not list, in set order; empty when it holds
  /// the whole set.
  final List<SheetDef> omitted;
}

/// The closing line when even [kCoverIndexMaxColumns] cannot hold the
/// set: which sheets are missing, read off the rows left out.
String coverIndexOmittedText(List<SheetDef> omitted) {
  final noun = omitted.length == 1 ? 'sheet' : 'sheets';
  final span = omitted.length == 1
      ? omitted.single.ncsId
      : '${omitted.first.ncsId}–${omitted.last.ncsId}';
  return '+ ${omitted.length} more $noun not indexed: $span';
}

/// Draws the index into [box], the column DR-210 reserved.
CoverIndexResult drawCoverIndex({
  required List<CoverIndexRow> rows,
  required DBox box,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  TextStyleSpec style(int argb) => TextStyleSpec(
    font: kSheetFont,
    sizePt: kCoverIndexPt,
    argb: argb,
    anchor: TextAnchor.midLeft,
  );
  final body = style(palette.text);
  final muted = style(palette.mutedText);

  const chrome = kCoverIndexRow + 6;
  final perColumn = ((box.height - chrome) / kCoverIndexRow).floor();
  if (perColumn < 1) {
    return CoverIndexResult(const <DiagramOp>[], 0, [
      for (final r in rows) ...r.sheets,
    ]);
  }
  var columns = 1;
  while (columns < kCoverIndexMaxColumns && rows.length > columns * perColumn) {
    columns++;
  }
  final fits = rows.length <= columns * perColumn;
  // A SET TOO LONG GIVES UP THE BOTTOM ROW OF EVERY SUB-COLUMN for one
  // full-width line saying what is missing, rather than ending on a sheet
  // as if the list were complete. FULL WIDTH because the first draft put
  // that line in the last narrow slot, where it was cut to
  // `+ 272 more sheets not index…` and lost the range, the one fact the
  // line exists to carry.
  final rowsPerColumn = fits ? perColumn : perColumn - 1;
  final shown = fits ? rows.length : columns * rowsPerColumn;
  final omitted = [
    for (final r in rows.skip(shown)) ...r.sheets,
  ];

  const gap = 12.0;
  final colWidth = (box.width - (columns - 1) * gap) / columns;
  // THE NUMBER COLUMNS ARE AS WIDE AS WHAT THEY HOLD. The first draft
  // reserved 26 and 70 pt, which in three sub-columns left a title about
  // 20 pt and printed `RAC…` on every row of a 131-sheet set.
  double widest(Iterable<String> texts) => texts.fold(
    0,
    (w, t) => w > measurer.measureText(t, body).advanceWidth
        ? w
        : measurer.measureText(t, body).advanceWidth,
  );
  // PER SUB-COLUMN, so one long range at the end (`T6.30–T6.34`) does not
  // squeeze the titles of the columns before it.
  final posW = <double>[];
  final idW = <double>[];
  for (var c = 0; c < columns; c++) {
    final inCol = rows
        .take(shown)
        .skip(c * rowsPerColumn)
        .take(rowsPerColumn)
        .toList();
    var p = widest(inCol.map((r) => r.positions)) + 6;
    var i = widest(inCol.map((r) => r.ids)) + 8;
    // A RANGE ROW MAY NOT STARVE ITS COLUMN. `127–131  T6.30–T6.34` is
    // the widest pair in a set and sits in the last sub-column; sized by
    // it, every title above it got about 30 pt. When that would leave the
    // titles under half the column, the single-sheet rows set the widths
    // and the range row alone sets its title after its own ids.
    final singles = inCol.where((r) => r.sheets.length == 1);
    if (colWidth - p - i - 4 < colWidth / 2 && singles.isNotEmpty) {
      p = widest(singles.map((r) => r.positions)) + 6;
      i = widest(singles.map((r) => r.ids)) + 8;
    }
    posW.add(p);
    idW.add(i);
  }

  final ops = <DiagramOp>[];
  var y = box.top + kCoverIndexRow / 2;
  ops.add(OpText('DRAWING INDEX', DPt(box.left, y), muted));
  y += kCoverIndexRow / 2 + 3;
  ops.add(
    OpLine(
      DPt(box.left, y),
      DPt(box.right, y),
      Stroke(argb: palette.rule, widthPt: 0.5),
    ),
  );
  final top = y + 3 + kCoverIndexRow / 2;

  for (var n = 0; n < shown; n++) {
    final row = rows[n];
    final col = n ~/ rowsPerColumn;
    final x = box.left + col * (colWidth + gap);
    final rowY = top + (n % rowsPerColumn) * kCoverIndexRow;
    // Where this row's own numbers are wider than the column's (a range
    // row in a squeezed column), its id and title move right past them.
    final idX = math.max(
      posW[col],
      measurer.measureText(row.positions, body).advanceWidth + 6,
    );
    final titleX = math.max(
      idX + idW[col],
      idX + measurer.measureText(row.ids, body).advanceWidth + 8,
    );
    ops
      ..add(OpText(row.positions, DPt(x, rowY), muted))
      ..add(OpText(row.ids, DPt(x + idX, rowY), body))
      ..add(
        OpText(
          _fitTitle(row, colWidth - titleX - 4, body, measurer),
          DPt(x + titleX, rowY),
          body,
        ),
      );
  }
  if (!fits) {
    ops.add(
      OpText(
        fitTextToWidth(
          coverIndexOmittedText(omitted),
          box.width,
          style: muted,
          measurer: measurer,
        ),
        DPt(box.left, top + rowsPerColumn * kCoverIndexRow),
        muted,
      ),
    );
  }
  return CoverIndexResult(ops, columns, omitted);
}
