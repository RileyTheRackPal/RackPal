// T6.20, Unused Home Runs (docs/08 §2.2 row n+3, M6-E1 `#332`, DR-220).
//
// ═══════════════════════════════════════════════════════════════════════
// AUTO, AND THE ROWS DECIDE IT
// ═══════════════════════════════════════════════════════════════════════
// The sheet exists iff `unusedHomeRunsOf` returns a room. This file lays
// out what that derivation returns and decides nothing about membership;
// the export asks it for pages only when there is something to print, so
// an absent T6.20 is absent from the file and the index alike (M6-E3).
//
// THE LAYOUT IS DR-220's. ANSI A landscape, a band per room with its
// count, rows in cable-ID order, ten columns, `OPEN` saying which end is a
// coil so no reader infers it from what another cell does not say.
//
// PAGINATED LIKE T0.02 AND T6.30: the page count is known before anything
// renders, so the set can say `SHEET i OF n`. A page that opens inside a
// room re-prints the column heads and the band `(cont.)`, and a band keeps
// with its first row (DR-219 §11.218.1, `#337`): a band at a page foot
// with its rows overleaf names a room the page then says nothing about.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/derived/structure_table.dart'
    show roughInLabel;
import 'package:rackpal_core/src/derived/unused_home_runs.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show wrapMeasured;
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;

/// Text size and the height of one wrapped line, in points.
const double kUnusedRunsPt = 7;
const double kUnusedRunsLine = 9;

/// The most lines a cell wraps to before it is ellipsised. A field end is
/// somebody's description of a wall ("Great Room TV wall, F-barrel 2"),
/// and two lines hold every one the starters carry.
const int kUnusedRunsMaxLines = 2;

const double _kHeading = 22;
const double _kColumnHeads = 12;
const double _kBand = 14;
const double _kRowPad = 4;
const double _kNote = 12;
const double _kInset = 8;
const double _kCellPad = 3;

/// The sheet's heading, before its count.
const String kUnusedRunsHeading = 'UNUSED HOME RUNS';

/// The line under the heading that says what `OPEN` means. Printed on
/// every page: a reader handed page 2 alone is owed it as much as page 1.
const String kOpenEndKey =
    'OPEN: the end left as a coil. RACK not landed at the rack · '
    'ROOM not terminated at the room · BOTH neither.';

/// What `FIELD END` prints before an open field end's note, docs/08 §3.3's
/// convention for an `OpenEndpoint`.
const String kOpenFieldEndPrefix = '— OPEN —';

/// One column of T6.20: its head and its width in points (Σ 674, the
/// 690 pt ANSI A usable width less the 8 pt inset each side).
@immutable
final class UnusedRunsColumn {
  const UnusedRunsColumn(this.head, this.widthPt, {this.alignRight = false});

  final String head;
  final double widthPt;
  final bool alignRight;
}

/// DR-220 §11.219.2's ten columns, in order, for [units].
///
/// THE WIDTHS WERE SET BY RENDERING WHOLE HOUSE, not by a guess at the
/// content. The first cut gave `PATHWAY` 56 pt, and every row wrapped,
/// because a pathway without a designator prints its NAME
/// (`Equipment room to attic riser`); `FIELD END` and `MEDIA` had the
/// slack.
List<UnusedRunsColumn> unusedRunsColumns(UnitSystem units) =>
    <UnusedRunsColumn>[
      const UnusedRunsColumn('CABLE ID', 56),
      const UnusedRunsColumn('OPEN', 36),
      const UnusedRunsColumn('RACK LBL', 56),
      const UnusedRunsColumn('FIELD LBL', 64),
      const UnusedRunsColumn('OUTLET', 52),
      const UnusedRunsColumn('FIELD END', 136),
      const UnusedRunsColumn('MEDIA', 90),
      UnusedRunsColumn(
        units == UnitSystem.metric ? 'LEN (M)' : 'LEN (FT)',
        40,
        alignRight: true,
      ),
      const UnusedRunsColumn('PATHWAY', 84),
      const UnusedRunsColumn('ROUGH-IN', 60),
    ];

/// The ten cells of [run], unwrapped, in [unusedRunsColumns]' order.
///
/// Every cell the Schedule view also prints comes from
/// `ScheduleEntry.cell`, so the sheet and the screen cannot disagree.
List<String> unusedRunCells(UnusedHomeRun run, UnitSystem units) {
  final e = run.entry;
  final field = run.fieldEnd;
  final fieldText = field.description.trim();
  final String fieldEnd;
  if (run.open == OpenEnd.room || run.open == OpenEnd.both) {
    fieldEnd = fieldText.isEmpty
        ? kOpenFieldEndPrefix
        : '$kOpenFieldEndPrefix $fieldText';
  } else {
    fieldEnd = fieldText.isEmpty ? kUnknownCell : fieldText;
  }
  final outlet = e.boxless
      ? kNoBoxCell
      : (e.outletDesignation == null || e.outletDesignation!.isEmpty)
      ? kUnknownCell
      : e.outletDesignation!;
  return <String>[
    e.cell(ScheduleColumnId.cableIdWithLifecycle, units: units),
    run.open.label,
    e.cell(ScheduleColumnId.rackLabel, units: units),
    e.cell(ScheduleColumnId.fieldLabel, units: units),
    outlet,
    fieldEnd,
    e.cell(ScheduleColumnId.media, units: units),
    e.cell(ScheduleColumnId.length, units: units),
    e.cell(ScheduleColumnId.pathway, units: units),
    roughInLabel(e.roughInStatus),
  ];
}

/// A band's title: the room in capitals and its count.
String unusedRunsBandText(String room, int count) =>
    '${room.toUpperCase()} · $count ${count == 1 ? 'run' : 'runs'}';

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a T6.20 page.
@immutable
sealed class UnusedRunsItem {
  const UnusedRunsItem();

  double get height;
}

/// The sheet heading, its key lines and the column heads.
@immutable
final class UnusedRunsHeading extends UnusedRunsItem {
  const UnusedRunsHeading({
    required this.title,
    required this.notes,
    this.continued = false,
  });

  final String title;

  /// [kOpenEndKey], and the lifecycle key when a suffix prints.
  final List<String> notes;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  UnusedRunsHeading get asContinued =>
      UnusedRunsHeading(title: title, notes: notes, continued: true);

  @override
  double get height => _kHeading + notes.length * _kNote + _kColumnHeads;
}

/// One room's band.
@immutable
final class UnusedRunsBand extends UnusedRunsItem {
  const UnusedRunsBand(this.title, {this.continued = false});

  final String title;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  @override
  double get height => _kBand;
}

/// One run: each cell's wrapped lines.
@immutable
final class UnusedRunsRow extends UnusedRunsItem {
  const UnusedRunsRow(this.designator, this.cells);

  /// The run's `W` number, so a test can find the row without reading a
  /// cell by position.
  final String designator;
  final List<List<String>> cells;

  int get lineCount => cells.fold(1, (n, c) => c.length > n ? c.length : n);

  @override
  double get height => lineCount * kUnusedRunsLine + _kRowPad;
}

/// One page's worth of items.
@immutable
final class UnusedRunsPage {
  const UnusedRunsPage(this.items);

  final List<UnusedRunsItem> items;

  /// The designators of the runs on this page, in order.
  List<String> get designators => [
    for (final item in items)
      if (item is UnusedRunsRow) item.designator,
  ];
}

/// The body box of a T6.20 page: the drawing area, inset clear of the
/// frame line.
DBox unusedRunsBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + _kInset,
  drawingArea.top + _kInset,
  drawingArea.width - 2 * _kInset,
  drawingArea.height - 2 * _kInset,
);

TextStyleSpec _style(int argb, {TextAnchor anchor = TextAnchor.midLeft}) =>
    TextStyleSpec(
      font: kSheetFont,
      sizePt: kUnusedRunsPt,
      argb: argb,
      anchor: anchor,
    );

/// The widths [unusedRunsColumns] gives, scaled to [width] so the table
/// spans the body whatever the drawing area is (a stamped sheet is no
/// narrower, but nothing here should depend on that).
List<double> _widths(List<UnusedRunsColumn> columns, double width) {
  final total = columns.fold<double>(0, (s, c) => s + c.widthPt);
  return [for (final c in columns) c.widthPt * width / total];
}

/// T6.20's pages for [rooms], laid out in [drawingArea].
///
/// EMPTY when [rooms] is: the sheet is `AUTO` (docs/08 §2.2), and a page
/// saying "none" is exactly what an `AUTO` sheet must not print.
List<UnusedRunsPage> paginateUnusedRuns({
  required List<UnusedHomeRunRoom> rooms,
  required DBox drawingArea,
  required TextMeasurer measurer,
  required UnitSystem units,
}) {
  if (rooms.isEmpty) return const <UnusedRunsPage>[];
  final body = unusedRunsBodyArea(drawingArea);
  final columns = unusedRunsColumns(units);
  final widths = _widths(columns, body.width);
  final total = rooms.fold<int>(0, (n, r) => n + r.runs.length);
  final suffixed = rooms.any(
    (r) => r.runs.any((u) => lifecycleSuffix(u.entry.lifecycleStatus) != ''),
  );
  final heading = UnusedRunsHeading(
    title: '$kUnusedRunsHeading ($total)',
    notes: <String>[kOpenEndKey, if (suffixed) kLifecycleSuffixKey],
  );

  final flat = <UnusedRunsItem>[heading];
  for (final room in rooms) {
    flat.add(UnusedRunsBand(unusedRunsBandText(room.title, room.runs.length)));
    for (final run in room.runs) {
      final values = unusedRunCells(run, units);
      flat.add(
        UnusedRunsRow(run.entry.designator, [
          for (final (i, v) in values.indexed)
            () {
              final lines = wrapMeasured(
                v,
                widths[i] - 2 * _kCellPad,
                style: _style(0xFF000000),
                measurer: measurer,
                maxLines: kUnusedRunsMaxLines,
              );
              return lines.isEmpty ? <String>[''] : lines;
            }(),
        ]),
      );
    }
  }

  final pages = <UnusedRunsPage>[];
  var page = <UnusedRunsItem>[];
  var y = 0.0;
  UnusedRunsBand? band;
  for (final (i, item) in flat.indexed) {
    // A BAND KEEPS WITH ITS FIRST ROW: it is placed only where the row
    // after it fits too.
    final next = i + 1 < flat.length ? flat[i + 1] : null;
    final need = item is UnusedRunsBand && next is UnusedRunsRow
        ? item.height + next.height
        : item.height;
    if (y + need > body.height && page.isNotEmpty) {
      pages.add(UnusedRunsPage(List.unmodifiable(page)));
      page = <UnusedRunsItem>[heading.asContinued];
      y = heading.height;
      // RE-EMIT THE ROOM THE NEXT ROW BELONGS TO, unless the next item is
      // itself a band that replaces it.
      if (band != null && item is UnusedRunsRow) {
        final cont = UnusedRunsBand(band.title, continued: true);
        page.add(cont);
        y += cont.height;
      }
    }
    if (item is UnusedRunsBand) band = item;
    page.add(item);
    y += item.height;
  }
  if (page.isNotEmpty) pages.add(UnusedRunsPage(List.unmodifiable(page)));
  return List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed T6.20 page.
@immutable
final class UnusedRunsSheet {
  const UnusedRunsSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T6.20`.
UnusedRunsSheet buildUnusedRunsSheet({
  required SheetDef sheet,
  required UnusedRunsPage page,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.unusedHomeRuns,
    'buildUnusedRunsSheet: ${sheet.role} is not the unused home runs role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final body = unusedRunsBodyArea(layout.drawingArea);
  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    rack: null,
    revisions: revisions,
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );
  final columns = unusedRunsColumns(settings.displayUnits);
  final widths = _widths(columns, body.width);
  final xs = <double>[];
  var x = body.left;
  for (final w in widths) {
    xs.add(x);
    x += w;
  }
  final text = _style(palette.text);
  final right = _style(palette.text, anchor: TextAnchor.midRight);
  final muted = _style(palette.mutedText);
  final mutedRight = _style(palette.mutedText, anchor: TextAnchor.midRight);
  final headingStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: 10,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final rule = Stroke(argb: palette.rule, widthPt: 0.5);
  final ops = <DiagramOp>[...furniture.ops];
  var y = body.top;

  for (final item in page.items) {
    switch (item) {
      case UnusedRunsHeading():
        ops.add(
          OpText(item.text, DPt(body.left, y + _kHeading * 0.6), headingStyle),
        );
        var noteY = y + _kHeading;
        for (final note in item.notes) {
          ops.add(
            OpText(
              fitTextToWidth(
                note,
                body.width,
                style: muted,
                measurer: measurer,
              ),
              DPt(body.left + _kCellPad, noteY + _kNote / 2),
              muted,
            ),
          );
          noteY += _kNote;
        }
        for (final (i, c) in columns.indexed) {
          final at = noteY + _kColumnHeads / 2;
          ops.add(
            c.alignRight
                ? OpText(
                    c.head,
                    DPt(xs[i] + widths[i] - _kCellPad, at),
                    mutedRight,
                  )
                : OpText(c.head, DPt(xs[i] + _kCellPad, at), muted),
          );
        }
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            rule,
          ),
        );
      case UnusedRunsBand():
        ops.add(
          OpText(
            fitTextToWidth(
              item.text,
              body.width,
              style: muted,
              measurer: measurer,
            ),
            DPt(body.left + _kCellPad, y + _kBand / 2),
            muted,
          ),
        );
      case UnusedRunsRow():
        for (final (i, lines) in item.cells.indexed) {
          final alignRight = columns[i].alignRight;
          for (final (j, line) in lines.indexed) {
            if (line.isEmpty) continue;
            final lineY = y + _kRowPad / 2 + kUnusedRunsLine * (j + 0.5);
            ops.add(
              alignRight
                  ? OpText(
                      line,
                      DPt(xs[i] + widths[i] - _kCellPad, lineY),
                      right,
                    )
                  : OpText(line, DPt(xs[i] + _kCellPad, lineY), text),
            );
          }
        }
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            Stroke(argb: palette.rule, widthPt: 0.25),
          ),
        );
    }
    y += item.height;
  }

  final minText = furniture.minTextSizePt < kUnusedRunsPt
      ? furniture.minTextSizePt
      : kUnusedRunsPt;
  return UnusedRunsSheet(
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
