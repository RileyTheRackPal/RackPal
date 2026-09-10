// rackpal_core/src/draw/sheet/plan_schedule_band.dart — the Floor Plan
// Device Schedule under `T1.01` (docs/15 §8, DR-152 §11.151, `PLAN-H/5`).
//
// ═══════════════════════════════════════════════════════════════════════
// IT IS SET IN BLOCKS BECAUSE ONE COLUMN FAILS THE EXIT CRITERION
// ═══════════════════════════════════════════════════════════════════════
// Measured on the real sheet rather than estimated. `T1.01`'s drawing area
// is 1122 × 567 pt, a row is `kScheduleRowHeight` and its header
// `kScheduleHeaderHeight`:
//
//   20 rows   one column 254 pt   plan keeps 313 pt
//   40 rows   one column 494 pt   plan keeps  73 pt
//   60 rows   one column 734 pt   DOES NOT FIT
//
// DR-037 §11.36.1 asks for *"the rack plus every drop of a real
// rough-in"*, and sixty is the number this corpus has used for a rough-in
// since AC-048. **A single column cannot print the exit criterion's own
// scenario.** Four blocks side by side put sixty rows in 194 pt and leave
// the plan 373, and it is how a floor-plan device schedule is actually
// set.
//
// ═══════════════════════════════════════════════════════════════════════
// FOUR BLOCKS AND NOT THREE, WHICH A MEASUREMENT CORRECTED (DR-152)
// ═══════════════════════════════════════════════════════════════════════
// The ruling was drafted saying three, on a claim that the cap then held
// *"roughly 180 rows"*. **It held sixty**, which is the exit criterion's
// own number, so the overflow that was "expected never to fire" fired on
// the sixty-first drop of an ordinary house. The arithmetic was rows per
// block multiplied by blocks in the wrong direction.
//
// Four blocks cost column width and buy everything else. Measured at
// [kPlanBandColumnMinPt]:
//
//   3 blocks of 365 pt   cap 60   60 rows leave the plan 313 pt
//   4 blocks of 270 pt   cap 80   60 rows leave the plan 373 pt
//
// So the plan, which is the sheet's subject, gets MORE room at every row
// count and not less. What narrows is the fields: DESCRIPTION goes from 37
// characters to 27 and AREA from 25 to 18, which is what `PLAN-J`'s print
// is for.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BAND TAKES WHAT IT NEEDS AND NEVER MORE THAN ITS SHARE
// ═══════════════════════════════════════════════════════════════════════
// Height is the rows it actually has, capped at [kPlanBandMaxShare] of the
// drawing area. A ten-drop plan gives its schedule 50 pt and keeps the
// rest; a sixty-drop plan gives 194. **The plan is the sheet's subject and
// the table serves it**, which is the whole reason a cap exists.
//
// PAST THE CAP THE SHEET SAYS WHAT IT COULD NOT PRINT (G4). Four blocks at
// the cap hold eighty rows, a third more than the criterion asks for, but
// a table quietly shorter than the drawing above it is the failure this
// chapter is about, so the count is printed rather than the rows dropped
// silently.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/plan_schedule.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show kScheduleHeaderHeight, kSchedulePt, kScheduleRowHeight;
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/text.dart';

/// The band's title, above its rules.
const String kPlanScheduleTitle = 'DEVICE SCHEDULE';

/// docs/15 §8's column headers, from the standard's own sample.
const List<String> kPlanScheduleHeaders = <String>[
  'AREA',
  'REF',
  'ITEM',
  'DESCRIPTION',
];

/// Each column's share of one block's width, in order.
///
/// DESCRIPTION TAKES THE REST because it is the only field with no bound:
/// an area is a room name, a reference is a designator, and an item is one
/// word or a model number.
const List<double> kPlanScheduleFieldShares = <double>[0.26, 0.16, 0.20, 0.38];

/// The most of the drawing area's height the band may take.
const double kPlanBandMaxShare = 0.45;

/// The gap between two blocks of rows.
const double kPlanBandColumnGapPt = 14;

/// How wide one block wants to be before another is opened.
///
/// 260 AND NOT 300, WHICH IS THE DIFFERENCE BETWEEN FOUR BLOCKS AND
/// THREE on a 1122 pt drawing area, and so between a cap of 80 rows and a
/// cap of 60. Sixty is the exit criterion's own figure (DR-037 §11.36.1),
/// and a cap standing exactly on it omits a row from an ordinary house.
const double kPlanBandColumnMinPt = 260;

/// What the band drew, and what it could not.
@immutable
final class PlanScheduleBand {
  const PlanScheduleBand({
    required this.ops,
    required this.height,
    required this.shown,
    required this.omitted,
  });

  final List<DiagramOp> ops;

  /// What the band occupies, measured from the drawing area's bottom.
  /// Zero when there are no rows at all.
  final double height;

  final int shown;

  /// Rows the cap would not hold.
  ///
  /// **A NUMBER RATHER THAN A SILENCE.** Expected to be zero on every
  /// document this product can make; printed on the sheet when it is not,
  /// because a table shorter than the drawing above it is exactly the
  /// dead end this schedule exists to close.
  final int omitted;
}

/// Lays the schedule into the bottom of [area].
///
/// Returns an empty band for an empty plan: a heading over nothing is a
/// form somebody forgot to fill in, and `T1.01` only exists for underlays
/// that carry a pin anyway.
PlanScheduleBand buildPlanScheduleBand({
  required List<PlanScheduleRow> rows,
  required DBox area,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  if (rows.isEmpty) {
    return const PlanScheduleBand(
      ops: <DiagramOp>[],
      height: 0,
      shown: 0,
      omitted: 0,
    );
  }

  // HOW MANY BLOCKS FIT ACROSS, then how many rows fit down. The width is
  // decided first because it is fixed by the sheet, and the height then
  // follows from what is left to print.
  final blocks =
      ((area.width + kPlanBandColumnGapPt) /
              (kPlanBandColumnMinPt + kPlanBandColumnGapPt))
          .floor();
  // AND THERE IS NO UPPER CAP, which a mutation had to establish. One at
  // `kPlanScheduleHeaders.length` was written here out of symmetry and
  // SURVIVED being raised to 99: `T1.01` is ANSI B landscape, its drawing
  // area is 1122 pt, and at [kPlanBandColumnMinPt] a fifth block would
  // need one 1,356 pt wide. The floor is real, because a caller may hand
  // this any box; the ceiling was arithmetic nobody can reach.
  final columns = blocks < 1 ? 1 : blocks;

  final maxRowsDown =
      ((area.height * kPlanBandMaxShare - kScheduleHeaderHeight) /
              kScheduleRowHeight)
          .floor();
  final rowsDown = maxRowsDown < 1 ? 1 : maxRowsDown;
  final capacity = rowsDown * columns;

  final shown = rows.length < capacity ? rows.length : capacity;
  final omitted = rows.length - shown;
  // THE BAND IS AS TALL AS IT NEEDS. A ten-drop plan does not reserve the
  // cap and leave white space the drawing could have used.
  final used = (shown / columns).ceil();
  final height = kScheduleHeaderHeight + used * kScheduleRowHeight;

  final top = area.bottom - height;
  final blockWidth =
      (area.width - kPlanBandColumnGapPt * (columns - 1)) / columns;

  final ops = <DiagramOp>[
    OpText(
      omitted == 0
          ? kPlanScheduleTitle
          : '$kPlanScheduleTitle  ($shown OF ${rows.length} SHOWN)',
      DPt(area.left, top - kSchedulePt),
      TextStyleSpec(
        font: kSheetFont,
        sizePt: kSchedulePt,
        argb: palette.mutedText,
        anchor: TextAnchor.midLeft,
      ),
    ),
  ];

  for (var c = 0; c < columns; c++) {
    final left = area.left + (blockWidth + kPlanBandColumnGapPt) * c;
    final block = DBox.fromLtwh(left, top, blockWidth, height);
    final first = c * used;
    if (first >= shown) break;
    final last = (first + used) < shown ? first + used : shown;
    ops.addAll(
      _block(
        rows: rows.sublist(first, last),
        block: block,
        palette: palette,
        measurer: measurer,
      ),
    );
  }

  return PlanScheduleBand(
    ops: List.unmodifiable(ops),
    height: height,
    shown: shown,
    omitted: omitted,
  );
}

List<DiagramOp> _block({
  required List<PlanScheduleRow> rows,
  required DBox block,
  required SheetPalette palette,
  required TextMeasurer measurer,
}) {
  final ops = <DiagramOp>[
    OpLine(
      DPt(block.left, block.top),
      DPt(block.right, block.top),
      sheetRule(palette.rule, kTableRuleWidthPt),
    ),
    OpLine(
      DPt(block.left, block.top + kScheduleHeaderHeight),
      DPt(block.right, block.top + kScheduleHeaderHeight),
      sheetRule(palette.rule, kTableRuleWidthPt),
    ),
  ];

  final headerStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: kSchedulePt,
    argb: palette.mutedText,
    anchor: TextAnchor.midLeft,
  );
  final cellStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: kSchedulePt,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );

  // EVERY BLOCK CARRIES ITS OWN HEADERS, because a reader scanning the
  // third column across is not going to look back at the first to find out
  // which field they are in.
  var x = block.left;
  for (var f = 0; f < kPlanScheduleHeaders.length; f++) {
    ops.add(
      OpText(
        kPlanScheduleHeaders[f],
        DPt(x, block.top + kScheduleHeaderHeight / 2),
        headerStyle,
      ),
    );
    x += block.width * kPlanScheduleFieldShares[f];
  }

  var y = block.top + kScheduleHeaderHeight;
  for (final row in rows) {
    final cells = <String>[
      row.areaName,
      row.reference,
      row.item,
      row.description,
    ];
    var cx = block.left;
    for (var f = 0; f < cells.length; f++) {
      final width = block.width * kPlanScheduleFieldShares[f];
      // TRUNCATED TO ITS OWN COLUMN, never allowed to run into the next
      // one: three blocks across leave no slack, and a description
      // overrunning its field would print on top of the AREA of the block
      // beside it.
      final text = fitTextToWidth(
        cells[f],
        width - kPlanScheduleCellPadPt,
        style: cellStyle,
        measurer: measurer,
      );
      // `fitTextToWidth` RETURNS EMPTY when not even the ellipsis fits,
      // and its own doc says callers check rather than draw it: an empty
      // text op is what the rest of the sheet furniture refuses to emit.
      if (text.isNotEmpty) {
        ops.add(OpText(text, DPt(cx, y + kScheduleRowHeight / 2), cellStyle));
      }
      cx += width;
    }
    y += kScheduleRowHeight;
  }
  return ops;
}

/// Space kept between one cell's text and the next field.
const double kPlanScheduleCellPadPt = 4;
