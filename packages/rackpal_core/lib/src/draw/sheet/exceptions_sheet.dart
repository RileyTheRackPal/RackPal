// T0.02, Exceptions and Acknowledgements (docs/08 §2.2 row 3, M6-C
// `#322`, DR-214).
//
// ═══════════════════════════════════════════════════════════════════════
// WHERE "THE REASON PRINTS", AND WHERE "NOTHING OPEN" IS A CLAIM
// ═══════════════════════════════════════════════════════════════════════
// CR-022 deleted every way a finding could hold a deliverable back and
// put the findings ON the deliverable instead: this sheet. So it prints in
// every set (`ON`), and when a section is empty it says so in words,
// because an empty table and a missing one are indistinguishable on paper
// and "no open exceptions" is a claim a reader should be able to read
// (`#325`). The open-findings note says the checks ran and when.
//
// THE CONTENT IS `buildExceptionsReport`'s, in DR-214's order: the
// project-wide exceptions, the open findings banded errors first, the
// acknowledged findings, and any acknowledgement whose finding no longer
// occurs. This file lays it out and decides nothing about it.
//
// PAGINATED LIKE T6.30: the page count is known before anything renders,
// so the set can say `SHEET i OF n`, and a page break re-emits the section
// heading and the severity band with `(cont.)` so page 2 never opens on
// rows belonging to a heading it does not name.
import 'package:meta/meta.dart';
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
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/validation/exceptions_report.dart';
import 'package:rackpal_core/src/validation/findings_view.dart';

/// Text size and the height of one wrapped line, in points.
const double kExceptionsPt = 7;
const double kExceptionsLine = 9;

/// The most lines a message or a reason wraps to before it is ellipsised.
/// Generous: a reason is somebody's signed sentence, and the 140-character
/// messages the starters produce take two lines in the MESSAGE column.
const int kExceptionsMaxLines = 4;

const double _kHeading = 22;
const double _kColumnHeads = 12;
const double _kBand = 14;
const double _kRowPad = 4;
const double _kNote = 14;
const double _kInset = 8;
const double _kCellPad = 3;

/// The three section headings, in DR-214's order.
const String kProjectWideHeading = 'PROJECT-WIDE EXCEPTIONS';
const String kOpenHeading = 'OPEN FINDINGS';
const String kAcknowledgedHeading = 'ACKNOWLEDGED FINDINGS';

/// The band under which an acknowledgement with no finding left prints
/// (§11.213.4).
const String kNoLongerOccurs = 'NO LONGER OCCURS';

/// What an empty PROJECT-WIDE section says.
const String kNoProjectWide =
    'None. Every rule runs at its catalogue severity, and none is muted.';

/// What an empty ACKNOWLEDGED section says.
const String kNoAcknowledged = 'None.';

/// What an empty OPEN section says: the claim, and its basis (`#325`).
String noOpenFindingsText(DateTime issuedAt) =>
    'No open findings. The design checks ran at export on '
    '${formatSheetDate(issuedAt)}.';

/// One column of a T0.02 table: its head, and its share of the width.
typedef ExceptionsColumn = ({String head, double share});

const List<ExceptionsColumn> _projectWideColumns = <ExceptionsColumn>[
  (head: 'RULE', share: 0.08),
  (head: 'CHANGE', share: 0.24),
  (head: 'REASON', share: 0.42),
  (head: 'BY', share: 0.12),
  (head: 'DATE', share: 0.14),
];

const List<ExceptionsColumn> _openColumns = <ExceptionsColumn>[
  (head: 'SEVERITY', share: 0.09),
  (head: 'RULE', share: 0.08),
  (head: 'LOCUS', share: 0.13),
  (head: 'MESSAGE', share: 0.70),
];

const List<ExceptionsColumn> _ackColumns = <ExceptionsColumn>[
  (head: 'SEVERITY', share: 0.08),
  (head: 'RULE', share: 0.07),
  (head: 'LOCUS', share: 0.10),
  (head: 'MESSAGE', share: 0.37),
  (head: 'REASON', share: 0.24),
  (head: 'BY', share: 0.07),
  (head: 'DATE', share: 0.07),
];

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a T0.02 page.
@immutable
sealed class ExceptionsItem {
  const ExceptionsItem();

  double get height;
}

/// A section's heading and its column heads.
@immutable
final class ExceptionsHeading extends ExceptionsItem {
  const ExceptionsHeading(this.title, this._columns, {this.continued = false});

  final String title;
  final List<ExceptionsColumn> _columns;
  final bool continued;

  List<String> get columnHeads => [for (final c in _columns) c.head];

  String get text => continued ? '$title (cont.)' : title;

  ExceptionsHeading get asContinued =>
      ExceptionsHeading(title, _columns, continued: true);

  @override
  double get height => _kHeading + _kColumnHeads;
}

/// A severity band, or the NO LONGER OCCURS band.
@immutable
final class ExceptionsBand extends ExceptionsItem {
  const ExceptionsBand(this.title, {this.continued = false});

  final String title;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  @override
  double get height => _kBand;
}

/// One row: each cell's wrapped lines, under its section's columns.
@immutable
final class ExceptionsRow extends ExceptionsItem {
  const ExceptionsRow(this.cells, this._columns);

  final List<List<String>> cells;
  final List<ExceptionsColumn> _columns;

  int get lineCount => cells.fold(1, (n, c) => c.length > n ? c.length : n);

  @override
  double get height => lineCount * kExceptionsLine + _kRowPad;
}

/// A sentence in place of an empty table.
@immutable
final class ExceptionsNote extends ExceptionsItem {
  const ExceptionsNote(this.text);

  final String text;

  @override
  double get height => _kNote;
}

/// One page's worth of items.
@immutable
final class ExceptionsPage {
  const ExceptionsPage(this.items);

  final List<ExceptionsItem> items;
}

/// The body box of a T0.02 page: the drawing area, inset clear of the
/// frame line (the legend's lesson: the drawing area's edge IS the border).
DBox exceptionsBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + _kInset,
  drawingArea.top + _kInset,
  drawingArea.width - 2 * _kInset,
  drawingArea.height - 2 * _kInset,
);

TextStyleSpec _style(int argb) => TextStyleSpec(
  font: kSheetFont,
  sizePt: kExceptionsPt,
  argb: argb,
  anchor: TextAnchor.midLeft,
);

ExceptionsRow _row(
  List<String> values,
  List<ExceptionsColumn> columns,
  double width,
  TextMeasurer measurer,
) => ExceptionsRow([
  for (final (i, c) in columns.indexed)
    () {
      final lines = wrapMeasured(
        values[i],
        c.share * width - 2 * _kCellPad,
        style: _style(0xFF000000),
        measurer: measurer,
        maxLines: kExceptionsMaxLines,
      );
      return lines.isEmpty ? <String>[''] : lines;
    }(),
], columns);

/// A reason as printed: an EMPTY one is legal on an instance (RJ-006) and
/// reads as given-and-blank, never as a missing value.
String _reasonOrNone(String? reason) {
  final r = reason?.trim() ?? '';
  return r.isEmpty ? '(no reason given)' : r;
}

String _locus(RackDocument doc, FindingRow row) {
  final id = row.finding.primaryEntityId;
  return id == null ? kNoLocusGroup : (locusLabel(doc, id) ?? kNoLocusGroup);
}

/// T0.02's pages for [report], laid out in [drawingArea].
///
/// Always at least one page: an empty report is three headings and three
/// sentences saying so, never a missing sheet.
List<ExceptionsPage> paginateExceptions({
  required ExceptionsReport report,
  required RackDocument doc,
  required DBox drawingArea,
  required TextMeasurer measurer,
  required DateTime issuedAt,
}) {
  final body = exceptionsBodyArea(drawingArea);
  final w = body.width;
  // ── project-wide (§11.213.1) ──────────────────────────────────────────
  final flat = <ExceptionsItem>[
    ExceptionsHeading(
      '$kProjectWideHeading (${report.projectWide.length})',
      _projectWideColumns,
    ),
  ];
  if (report.projectWide.isEmpty) {
    flat.add(const ExceptionsNote(kNoProjectWide));
  }
  for (final p in report.projectWide) {
    flat.add(
      _row(
        [p.ruleId, p.change, p.reason, p.by, formatSheetDate(p.at)],
        _projectWideColumns,
        w,
        measurer,
      ),
    );
  }

  // ── open, banded errors first (§11.213.2) ─────────────────────────────
  flat.add(
    ExceptionsHeading('$kOpenHeading (${report.openCount})', _openColumns),
  );
  if (report.open.isEmpty) {
    flat.add(ExceptionsNote(noOpenFindingsText(issuedAt)));
  }
  for (final group in report.open) {
    flat.add(ExceptionsBand('${group.label.toUpperCase()} (${group.length})'));
    for (final r in group.rows) {
      flat.add(
        _row(
          [
            severityLabel(r.finding.severity),
            r.finding.ruleId,
            _locus(doc, r),
            r.finding.message,
          ],
          _openColumns,
          w,
          measurer,
        ),
      );
    }
  }

  // ── acknowledged, then stale (§11.213.3, §11.213.4) ───────────────────
  final ackTotal = report.acknowledged.length + report.stale.length;
  flat.add(
    ExceptionsHeading('$kAcknowledgedHeading ($ackTotal)', _ackColumns),
  );
  if (ackTotal == 0) flat.add(const ExceptionsNote(kNoAcknowledged));
  for (final r in report.acknowledged) {
    final ack = r.acknowledgement!;
    flat.add(
      _row(
        [
          severityLabel(r.finding.severity),
          r.finding.ruleId,
          _locus(doc, r),
          r.finding.message,
          _reasonOrNone(r.reason),
          ack.by,
          formatSheetDate(ack.at),
        ],
        _ackColumns,
        w,
        measurer,
      ),
    );
  }
  if (report.stale.isNotEmpty) {
    flat.add(ExceptionsBand('$kNoLongerOccurs (${report.stale.length})'));
    for (final a in report.stale) {
      final locus = a.targetEntityId == null
          ? kNoLocusGroup
          : (locusLabel(doc, a.targetEntityId!) ?? kNoLocusGroup);
      flat.add(
        _row(
          [
            '—',
            a.ruleId,
            locus,
            'The finding this acknowledged no longer occurs.',
            _reasonOrNone(a.reason),
            a.by,
            formatSheetDate(a.at),
          ],
          _ackColumns,
          w,
          measurer,
        ),
      );
    }
  }

  // ── break into pages ──────────────────────────────────────────────────
  final pages = <ExceptionsPage>[];
  var page = <ExceptionsItem>[];
  var y = 0.0;
  ExceptionsHeading? heading;
  ExceptionsBand? band;
  for (final item in flat) {
    if (y + item.height > body.height && page.isNotEmpty) {
      pages.add(ExceptionsPage(List.unmodifiable(page)));
      page = <ExceptionsItem>[];
      y = 0;
      // RE-EMIT WHAT THE NEXT ROW BELONGS TO, unless the next item is
      // itself a heading or a band that replaces it.
      if (heading != null && item is! ExceptionsHeading) {
        page.add(heading.asContinued);
        y += heading.height;
        if (band != null && item is! ExceptionsBand) {
          final cont = ExceptionsBand(band.title, continued: true);
          page.add(cont);
          y += cont.height;
        }
      }
    }
    if (item is ExceptionsHeading) {
      heading = item;
      band = null;
    }
    if (item is ExceptionsBand) band = item;
    page.add(item);
    y += item.height;
  }
  if (page.isNotEmpty) pages.add(ExceptionsPage(List.unmodifiable(page)));
  return List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed T0.02 page.
@immutable
final class ExceptionsSheet {
  const ExceptionsSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T0.02`.
ExceptionsSheet buildExceptionsSheet({
  required SheetDef sheet,
  required ExceptionsPage page,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.exceptions,
    'buildExceptionsSheet: ${sheet.role} is not the exceptions role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final body = exceptionsBodyArea(layout.drawingArea);
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
  final text = _style(palette.text);
  final muted = _style(palette.mutedText);
  final heading = TextStyleSpec(
    font: kSheetFont,
    sizePt: 10,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final ops = <DiagramOp>[...furniture.ops];
  final x0 = body.left;
  var y = body.top;

  List<double> xs(List<ExceptionsColumn> cols) {
    final out = <double>[];
    var x = x0;
    for (final c in cols) {
      out.add(x);
      x += c.share * body.width;
    }
    return out;
  }

  for (final item in page.items) {
    switch (item) {
      case ExceptionsHeading():
        ops.add(
          OpText(item.text, DPt(x0, y + _kHeading * 0.6), heading),
        );
        final colX = xs(item._columns);
        for (final (i, head) in item.columnHeads.indexed) {
          ops.add(
            OpText(
              head,
              DPt(colX[i] + _kCellPad, y + _kHeading + _kColumnHeads / 2),
              muted,
            ),
          );
        }
        ops.add(
          OpLine(
            DPt(x0, y + item.height),
            DPt(body.right, y + item.height),
            Stroke(argb: palette.rule, widthPt: 0.5),
          ),
        );
      case ExceptionsBand():
        ops.add(
          OpText(
            fitTextToWidth(
              item.text,
              body.width,
              style: muted,
              measurer: measurer,
            ),
            DPt(x0 + _kCellPad, y + _kBand / 2),
            muted,
          ),
        );
      case ExceptionsRow():
        final colX = xs(item._columns);
        for (final (i, lines) in item.cells.indexed) {
          for (final (j, line) in lines.indexed) {
            if (line.isEmpty) continue;
            ops.add(
              OpText(
                line,
                DPt(
                  colX[i] + _kCellPad,
                  y + _kRowPad / 2 + kExceptionsLine * (j + 0.5),
                ),
                text,
              ),
            );
          }
        }
      case ExceptionsNote():
        ops.add(
          OpText(
            fitTextToWidth(
              item.text,
              body.width,
              style: text,
              measurer: measurer,
            ),
            DPt(x0 + _kCellPad, y + _kNote / 2),
            text,
          ),
        );
    }
    y += item.height;
  }

  final minText = furniture.minTextSizePt < kExceptionsPt
      ? furniture.minTextSizePt
      : kExceptionsPt;
  return ExceptionsSheet(
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
