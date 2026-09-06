// rackpal_core/src/draw/sheet/equipment_sheet.dart — pure Dart.
//
// docs/08-pdf-export.md §2.2's `T6.30 EQUIPMENT LIST AND MATERIALS`, drawn
// entirely through `DiagramCanvas` ops with the pagination computed here,
// in core, from the shared `TextMeasurer`.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY NOT `pw.Table` + `MultiPage`
// ─────────────────────────────────────────────────────────────────────────
// It would be less code. It would also be laid out by dart_pdf's own text
// engine, which is not the engine the on-screen preview uses — so the
// schedule would break lines, truncate cells and paginate DIFFERENTLY in
// the preview and in the print, which is the exact divergence CR-081 and
// CR-086 exist to make impossible. Drawing it through the shared IR puts
// column layout, wrapping and pagination on us, and in exchange the table
// is identical on both backends by construction and every assertion about
// it is a `dart test` over `scene.ops` with no PDF involved.
//
// It also disposes of §3.7's three VERIFY items — `Table.headerCount`'s
// per-page repeat behaviour, `MultiPage` overflow and `maxPages` — because
// the pages are hand-cut here and each one is a plain `pw.Page`.
//
// ─────────────────────────────────────────────────────────────────────────
// PAGINATION IS §3.7's EXPLICIT LOOP
// ─────────────────────────────────────────────────────────────────────────
// Rows are laid out into pages by summing measured heights; a group band
// interrupted by a page break is RE-EMITTED at the top of the next page
// marked ` (cont.)`, and every page carries its own header row. Row heights
// are deterministic because the notes column is capped at two MEASURED
// lines, so the same document always produces the same page count — which
// is what lets the sheet set resolve `SHEET i OF n` before anything is
// rendered.
//
// ─────────────────────────────────────────────────────────────────────────
// SECTIONS OMITTED, AND SAID SO ON THE SHEET
// ─────────────────────────────────────────────────────────────────────────
// §2.2 also asks T6.30 for the cable-footage rollup by media with waste
// factor, the jumper/power-cord rollup and the PDU outlet map. Every one of
// them derives from `Link`s, `Service`s or `Conductor`s, and a document
// edited in this build creates none. They are omitted WHOLE rather than
// printed empty — and because their absence changes what a sheet titled
// "Equipment List and Materials" promises, the sheet carries
// [kEquipmentScopeNote].
//
// NO PRICING (AC-055), and the word BOM appears nowhere. See
// `derived/equipment_list.dart`.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_load_gutter.dart'
    show formatIntRollup, formatMassRollup;
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/unit_formatter.dart';

/// What the sheet says about the schedules it does NOT carry. See the file
/// header.
const String kEquipmentScopeNote =
    'EQUIPMENT ONLY. CABLE AND POWER SCHEDULES NOT ISSUED IN THIS SET.';

/// What a group band gains when it is re-emitted after a page break.
const String kContinuationSuffix = ' (cont.)';

/// The thirteen columns docs/08 §2.2 names, in its order.
enum EquipmentColumn {
  qty('QTY', 22, _Align.right),
  designator('DESIGNATOR', 58, _Align.left),
  manufacturer('MANUFACTURER', 68, _Align.left),
  model('MODEL', 78, _Align.left),
  description('DESCRIPTION', 104, _Align.left),
  ru('RU', 46, _Align.left),
  rack('RACK', 34, _Align.left),
  location('LOCATION', 60, _Align.left),
  face('FACE', 34, _Align.left),
  mass('MASS', 46, _Align.right),
  draw('DRAW', 40, _Align.right),
  lifecycle('LIFECYCLE', 46, _Align.left),
  notes('NOTES', 54, _Align.left);

  const EquipmentColumn(this.heading, this.width, this._align);

  /// What the header row prints, before [headingIn] adds a unit.
  final String heading;

  /// Column width in points. The thirteen sum to 690 — the ANSI A
  /// landscape usable width — and `equipment_sheet_test.dart` asserts that
  /// against the frame rather than against a repeated literal.
  final double width;

  final _Align _align;

  /// What the header row prints for [units] — `MASS (LB)`, `MASS (KG)`,
  /// `DRAW (VA)`.
  ///
  /// THE UNIT BELONGS IN THE HEADER BECAUSE THE CELLS CANNOT CARRY IT.
  /// A MASS cell is a bare number and the unit is a project setting
  /// (`ProjectSettings.displayUnits`, CR-097) worth a factor of 2.2:
  /// `UPS-1` prints `91.9` imperial and `41.7` metric, the same device,
  /// with nothing else on the sheet different. The only place lb/kg/VA
  /// used to appear was the group subtotal band, which on a continuation
  /// page sits over a dozen rows below the header — and the header
  /// repeats on every page, which is exactly the property this needs.
  ///
  /// Putting it in the cell instead was the alternative and it does not
  /// fit: the column is 46 pt, `1234.5 lb` at 6.5 pt does not, and a
  /// measured truncation would eat the unit off the widest — that is,
  /// the heaviest — rows first.
  String headingIn(UnitSystem units) => switch (this) {
    EquipmentColumn.mass =>
      units == UnitSystem.metric ? 'MASS (KG)' : 'MASS (LB)',
    EquipmentColumn.draw => 'DRAW (VA)',
    _ => heading,
  };

  TextAnchor get _anchor =>
      _align == _Align.right ? TextAnchor.midRight : TextAnchor.midLeft;
}

enum _Align { left, right }

/// Body-text size on the schedule, in points of paper.
const double kSchedulePt = 6.5;

/// Header-row text size.
const double kScheduleHeaderPt = 6.5;

/// The height of one single-line data row.
const double kScheduleRowHeight = 12;

/// The extra height a second line of notes adds.
const double kScheduleSecondLine = 8;

/// The height of the header row.
const double kScheduleHeaderHeight = 14;

/// The height of a group band.
const double kScheduleBandHeight = 15;

/// The height of a subtotal band.
const double kScheduleSubtotalHeight = 13;

/// The height of the scope-note line at the top of every page.
const double kScheduleNoteHeight = 13;

/// Padding inside a schedule cell.
const double _kCellPad = 3;

/// The maximum number of lines the NOTES column wraps to (§3.7).
const int kMaxNoteLines = 2;

/// What separates a mount note from a device note in one NOTES cell.
///
/// A CONSTANT SO A TEST CAN NAME IT rather than repeat the literal, which
/// is how a separator quietly becomes two different separators.
const String kNoteJoin = '; ';

/// The NOTES cell for [row]: the mount note first, then the device note.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MOUNT NOTE GOES FIRST, AND THE ORDER IS THE WHOLE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// On an off-rack row, RU prints an em dash, RACK prints an em dash and
/// FACE prints `NONE`. **The mount note is the only cell on that row that
/// says where the device is.** The column wraps to [kMaxNoteLines] and
/// truncates past it, so whichever fact is second is the one a long row
/// loses, and losing "AV closet, top shelf" to keep "spare unit, ordered
/// 2026-04" would be the wrong trade on a placement document.
///
/// A FOURTEENTH COLUMN WAS THE ALTERNATIVE AND DOES NOT FIT. The thirteen
/// widths sum to 690 pt, the ANSI A landscape usable width, and
/// `equipment_sheet_test.dart` asserts that against the frame. A new
/// column has to be taken out of the others, and the two it would come
/// from are DESCRIPTION and MODEL, which are what a reader identifies the
/// row by.
String equipmentNotesCell(EquipmentRow row) {
  final parts = [
    if (row.mountNote case final m? when m.isNotEmpty) m,
    if (row.notes case final n? when n.isNotEmpty) n,
  ];
  return parts.join(kNoteJoin);
}

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a schedule page.
@immutable
sealed class ScheduleItem {
  const ScheduleItem();

  double get height;
}

/// A rack's opening band.
@immutable
final class ScheduleBand extends ScheduleItem {
  const ScheduleBand({required this.title, required this.continued});

  final String title;

  /// True when this band was re-emitted after a page break — §3.7's
  /// `(cont.)`.
  final bool continued;

  String get text => continued ? '$title$kContinuationSuffix' : title;

  @override
  double get height => kScheduleBandHeight;
}

/// One device.
@immutable
final class ScheduleRow extends ScheduleItem {
  const ScheduleRow({required this.cells, required this.noteLines});

  /// The thirteen cell strings, in [EquipmentColumn] order, already
  /// measured-and-truncated.
  final List<String> cells;

  /// The NOTES column's wrapped lines, 0..[kMaxNoteLines].
  final List<String> noteLines;

  @override
  double get height =>
      kScheduleRowHeight + (noteLines.length > 1 ? kScheduleSecondLine : 0);
}

/// A group's closing subtotal.
@immutable
final class ScheduleSubtotal extends ScheduleItem {
  const ScheduleSubtotal(this.text);

  final String text;

  @override
  double get height => kScheduleSubtotalHeight;
}

/// One page's worth of items.
@immutable
final class SchedulePage {
  const SchedulePage(this.items);

  final List<ScheduleItem> items;

  Iterable<ScheduleRow> get rows => items.whereType<ScheduleRow>();
}

/// Where the schedule's body sits inside a sheet's drawing area — below
/// the scope note and the header row.
DBox scheduleBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left,
  drawingArea.top + kScheduleNoteHeight + kScheduleHeaderHeight,
  drawingArea.width,
  drawingArea.height - kScheduleNoteHeight - kScheduleHeaderHeight,
);

/// docs/08 §3.7's explicit pagination loop.
///
/// Deterministic: the same [list] and the same [drawingArea] always give
/// the same pages, because every height is a function of measured text and
/// nothing is left to a widget. That is what lets the sheet set resolve
/// `SHEET i OF n` before rendering starts.
///
/// Always returns at least one page, even for a document with no devices —
/// a sheet that says the list is empty is a deliverable; a missing sheet is
/// a hole in the set.
List<SchedulePage> paginateEquipmentList({
  required EquipmentList list,
  required DBox drawingArea,
  required TextMeasurer measurer,
  UnitSystem units = UnitSystem.imperial,
}) {
  final body = scheduleBodyArea(drawingArea);
  final flat = <ScheduleItem>[];
  for (final group in list.groups) {
    flat
      ..add(ScheduleBand(title: group.title, continued: false))
      ..addAll(<ScheduleItem>[
        for (final row in group.rows) _row(row, measurer, units),
      ])
      ..add(ScheduleSubtotal(_subtotalText(group, units)));
  }

  final pages = <SchedulePage>[];
  var page = <ScheduleItem>[];
  var y = 0.0;
  ScheduleBand? openBand;

  void flush() {
    if (page.isEmpty) return;
    pages.add(SchedulePage(List.unmodifiable(page)));
    page = <ScheduleItem>[];
    y = 0;
  }

  for (final item in flat) {
    final h = item.height;
    if (y + h > body.height && page.isNotEmpty) {
      flush();
      final band = openBand;
      // The re-emitted band is what makes a group readable across a break:
      // without it, page 2 opens with rows belonging to a rack it never
      // names.
      if (band != null && item is! ScheduleBand) {
        final cont = ScheduleBand(title: band.title, continued: true);
        page.add(cont);
        y += cont.height;
      }
    }
    if (item is ScheduleBand) openBand = item;
    page.add(item);
    y += h;
  }
  flush();

  return pages.isEmpty
      ? const <SchedulePage>[SchedulePage(<ScheduleItem>[])]
      : List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed T6.30 page.
@immutable
final class EquipmentSheet {
  const EquipmentSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T6.30`.
///
/// [page] comes from [paginateEquipmentList], and [sheet] from the sheet
/// set that was resolved from that same pagination — so the page count in
/// `SHEET i OF n` and the number of pages actually drawn are the same
/// number by construction.
EquipmentSheet buildEquipmentSheet({
  required SheetDef sheet,
  required SchedulePage page,
  required EquipmentList list,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.equipmentList,
    'buildEquipmentSheet: ${sheet.role} is not the equipment-list role',
  );

  final layout = sheetLayoutFor(sheet, revisions);
  final area = layout.drawingArea;
  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    // A schedule spans the whole project, so it names no single rack —
    // the RACK column does that per row.
    rack: null,
    revisions: revisions,
    // A table is not a scaled drawing. `NTS` is the truth about it, and
    // `DrawingScale.fitted` at 1:1 would print `1:1`, which invites
    // exactly the scaling-off §5.2 forbids.
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  final ops = <DiagramOp>[
    ...furniture.ops,
    // The scope note, on EVERY page — a reader holding page 2 has the same
    // right to know what is not in the set as one holding page 1.
    OpText(
      list.unplacedCount == 0
          ? kEquipmentScopeNote
          : '$kEquipmentScopeNote  ${list.unplacedCount} DEVICE'
                '${list.unplacedCount == 1 ? '' : 'S'} NOT IN A RACK.',
      DPt(area.left, area.top + kScheduleNoteHeight / 2),
      TextStyleSpec(
        font: kSheetFont,
        sizePt: kSchedulePt,
        argb: palette.mutedText,
        anchor: TextAnchor.midLeft,
      ),
    ),
    ..._header(area, palette, measurer, settings.displayUnits),
  ];

  var y = scheduleBodyArea(area).top;
  for (final item in page.items) {
    switch (item) {
      case ScheduleBand():
        ops.addAll(_band(area, y, item, palette, measurer));
      case ScheduleRow():
        ops.addAll(_dataRow(area, y, item, palette));
      case ScheduleSubtotal():
        ops.addAll(_subtotal(area, y, item, palette, measurer));
    }
    y += item.height;
  }

  if (page.items.isEmpty) {
    // A document with no equipment produces a sheet that SAYS so, not a
    // blank grid. A blank grid reads as a form somebody forgot to fill in.
    ops.add(
      OpText(
        'NO EQUIPMENT IN THIS PROJECT.',
        DPt(area.left, scheduleBodyArea(area).top + kScheduleRowHeight / 2),
        TextStyleSpec(
          font: kSheetFont,
          sizePt: kSchedulePt,
          argb: palette.text,
          anchor: TextAnchor.midLeft,
        ),
      ),
    );
  }

  final minText = furniture.minTextSizePt < kSchedulePt
      ? furniture.minTextSizePt
      : kSchedulePt;

  return EquipmentSheet(
    scene: DiagramScene(
      ops: ops,
      bounds: layout.geometry.pageBox,
      hits: const <HitRegion>[],
      minTextSizePt: minText,
      fragments: const <String, IntRange>{},
    ),
    legibility: checkLegibility(
      sceneMinTextSizePt: minText,
      scale: const SceneFactor(1),
    ),
  );
}

List<DiagramOp> _header(
  DBox area,
  SheetPalette palette,
  TextMeasurer measurer,
  UnitSystem units,
) {
  final top = area.top + kScheduleNoteHeight;
  final ops = <DiagramOp>[
    OpLine(
      DPt(area.left, top),
      DPt(area.right, top),
      sheetRule(palette.rule, kTableRuleWidthPt),
    ),
    OpLine(
      DPt(area.left, top + kScheduleHeaderHeight),
      DPt(area.right, top + kScheduleHeaderHeight),
      sheetRule(palette.rule, kBlockOutlineWidthPt),
    ),
  ];
  var x = area.left;
  for (final column in EquipmentColumn.values) {
    final style = TextStyleSpec(
      font: kSheetFont,
      sizePt: kScheduleHeaderPt,
      argb: palette.mutedText,
      anchor: column._anchor,
    );
    final text = fitTextToWidth(
      column.headingIn(units),
      column.width - 2 * _kCellPad,
      style: style,
      measurer: measurer,
    );
    if (text.isNotEmpty) {
      ops.add(
        OpText(
          text,
          DPt(
            column._align == _Align.right
                ? x + column.width - _kCellPad
                : x + _kCellPad,
            top + kScheduleHeaderHeight / 2,
          ),
          style,
        ),
      );
    }
    x += column.width;
  }
  return ops;
}

List<DiagramOp> _band(
  DBox area,
  double y,
  ScheduleBand band,
  SheetPalette palette,
  TextMeasurer measurer,
) {
  final style = TextStyleSpec(
    font: kSheetFont,
    sizePt: kSchedulePt,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final text = fitTextToWidth(
    band.text,
    area.width - 2 * _kCellPad,
    style: style,
    measurer: measurer,
  );
  return <DiagramOp>[
    OpLine(
      DPt(area.left, y + kScheduleBandHeight),
      DPt(area.right, y + kScheduleBandHeight),
      sheetRule(palette.rule, kTableRuleWidthPt),
    ),
    if (text.isNotEmpty)
      OpText(
        text,
        DPt(area.left + _kCellPad, y + kScheduleBandHeight / 2),
        style,
      ),
  ];
}

List<DiagramOp> _dataRow(
  DBox area,
  double y,
  ScheduleRow row,
  SheetPalette palette,
) {
  final ops = <DiagramOp>[];
  var x = area.left;
  for (var i = 0; i < EquipmentColumn.values.length; i++) {
    final column = EquipmentColumn.values[i];
    final text = column == EquipmentColumn.notes ? '' : row.cells[i];
    if (text.isNotEmpty) {
      ops.add(
        OpText(
          text,
          DPt(
            column._align == _Align.right
                ? x + column.width - _kCellPad
                : x + _kCellPad,
            y + kScheduleRowHeight / 2,
          ),
          TextStyleSpec(
            font: kSheetFont,
            sizePt: kSchedulePt,
            argb: palette.text,
            anchor: column._anchor,
          ),
        ),
      );
    }
    if (column == EquipmentColumn.notes) {
      for (var line = 0; line < row.noteLines.length; line++) {
        ops.add(
          OpText(
            row.noteLines[line],
            DPt(
              x + _kCellPad,
              y + kScheduleRowHeight / 2 + line * kScheduleSecondLine,
            ),
            TextStyleSpec(
              font: kSheetFont,
              sizePt: kSchedulePt,
              argb: palette.text,
              anchor: TextAnchor.midLeft,
            ),
          ),
        );
      }
    }
    x += column.width;
  }
  return ops;
}

List<DiagramOp> _subtotal(
  DBox area,
  double y,
  ScheduleSubtotal subtotal,
  SheetPalette palette,
  TextMeasurer measurer,
) {
  final style = TextStyleSpec(
    font: kSheetFont,
    sizePt: kSchedulePt,
    argb: palette.text,
    anchor: TextAnchor.midRight,
  );
  final text = fitTextToWidth(
    subtotal.text,
    area.width - 2 * _kCellPad,
    style: style,
    measurer: measurer,
  );
  return <DiagramOp>[
    OpLine(
      DPt(area.left, y + kScheduleSubtotalHeight),
      DPt(area.right, y + kScheduleSubtotalHeight),
      sheetRule(palette.rule, kBlockOutlineWidthPt),
    ),
    if (text.isNotEmpty)
      OpText(
        text,
        DPt(area.right - _kCellPad, y + kScheduleSubtotalHeight / 2),
        style,
      ),
  ];
}

/// The cells for one device, measured and truncated to their columns.
ScheduleRow _row(
  EquipmentRow row,
  TextMeasurer measurer,
  UnitSystem units,
) {
  final cells = <String>[
    '${row.qty}',
    row.designator,
    // An absent manufacturer or model is an EM DASH, never a blank: an
    // empty cell reads as "nobody filled this in" (`text_fit.dart`) and
    // this row's MASS, DRAW and RU cells already print `—` for the same
    // device, so a blank beside them is unreadable rather than merely
    // terse.
    row.manufacturer ?? kUnknownCell,
    row.model ?? kUnknownCell,
    row.description,
    row.ruLabel,
    row.rackDesignator ?? kUnknownCell,
    row.location ?? kUnknownCell,
    row.mounting.label,
    _mass(row.loads.mass, units),
    // NEVER `0` for an unknown draw. `derived/totals.dart`'s distinction —
    // 0 means measured, null means we do not know — survives onto paper.
    if (row.loads.apparentVA case final va?) '$va' else kUnknownCell,
    lifecycleLabel(row.lifecycleStatus),
    equipmentNotesCell(row),
  ];

  final fitted = <String>[
    for (var i = 0; i < EquipmentColumn.values.length; i++)
      fitTextToWidth(
        cells[i],
        EquipmentColumn.values[i].width - 2 * _kCellPad,
        style: TextStyleSpec(
          font: kSheetFont,
          sizePt: kSchedulePt,
          argb: 0xFF000000,
          anchor: EquipmentColumn.values[i]._anchor,
        ),
        measurer: measurer,
      ),
  ];

  return ScheduleRow(
    cells: List.unmodifiable(fitted),
    noteLines: List.unmodifiable(
      wrapMeasured(
        cells[EquipmentColumn.notes.index],
        EquipmentColumn.notes.width - 2 * _kCellPad,
        style: const TextStyleSpec(
          font: kSheetFont,
          sizePt: kSchedulePt,
          argb: 0xFF000000,
          anchor: TextAnchor.midLeft,
        ),
        measurer: measurer,
        maxLines: kMaxNoteLines,
      ),
    ),
  );
}

String _mass(Mass? mass, UnitSystem units) => mass == null
    ? kUnknownCell
    : (units == UnitSystem.metric
          ? mass.toKilogramsValue(fractionDigits: 1)
          : mass.toPoundsValue(fractionDigits: 1));

String _subtotalText(EquipmentGroup group, UnitSystem units) {
  final label = group.isUnplaced
      ? kUnplacedGroupTitle
      : group.title.split(' · ').first;
  final devices = group.rows.length;
  return '$label SUBTOTAL   $devices DEVICE${devices == 1 ? '' : 'S'}   '
      '${formatMassRollup(group.mass, units)}   '
      '${formatIntRollup(group.apparentVA, 'VA')}';
}

/// Greedy word wrap to at most [maxLines] MEASURED lines, the last one
/// ellipsised if there is more.
///
/// §3.7's "hard-truncate with a measured ellipsis using the shared
/// `TextMeasurer` rather than trusting the widget", extended to two lines.
/// A single word longer than [maxWidth] is truncated rather than allowed to
/// run out of its cell — `PdfGraphics.drawString` neither wraps nor clips,
/// so an unmeasured string runs across the next column and off the sheet.
List<String> wrapMeasured(
  String text,
  double maxWidth, {
  required TextStyleSpec style,
  required TextMeasurer measurer,
  required int maxLines,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || maxLines <= 0) return const <String>[];

  final words = trimmed.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (measurer.measureText(candidate, style).advanceWidth <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current.isNotEmpty) {
      lines.add(current);
      if (lines.length == maxLines) {
        return _withEllipsis(lines, word, maxWidth, style, measurer, maxLines);
      }
      current = '';
    }
    // The word alone does not fit — truncate it and keep going.
    current = fitTextToWidth(
      word,
      maxWidth,
      style: style,
      measurer: measurer,
    );
    if (measurer.measureText(current, style).advanceWidth >= maxWidth) {
      lines.add(current);
      if (lines.length == maxLines) return List.unmodifiable(lines);
      current = '';
    }
  }
  if (current.isNotEmpty && lines.length < maxLines) lines.add(current);
  return List.unmodifiable(lines);
}

List<String> _withEllipsis(
  List<String> lines,
  String remainder,
  double maxWidth,
  TextStyleSpec style,
  TextMeasurer measurer,
  int maxLines,
) {
  // The cap was hit with text still to place. The last line gains a
  // measured ellipsis so the reader can SEE that the cell is truncated
  // rather than believing they have the whole note.
  final last = lines.removeLast();
  lines.add(
    fitTextToWidth(
      '$last $remainder',
      maxWidth,
      style: style,
      measurer: measurer,
    ),
  );
  return List.unmodifiable(lines);
}
