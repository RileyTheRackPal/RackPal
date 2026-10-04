// T5.01, Plate, Panel & Pinout Details (docs/08 §2.2 row n+5, M6-E2c
// `#976`, DR-221).
//
// ═══════════════════════════════════════════════════════════════════════
// PINOUT TABLES ONLY, AND ONLY THE KINDS THAT EXIST
// ═══════════════════════════════════════════════════════════════════════
// DR-221 §11.220.1: one section per kind of non-standard pinout, each with
// its own header row (DR-219 §11.218.1's mechanism), and a section with no
// rows is not drawn. The sheet as a whole exists iff `pinoutDetailsOf` is
// not empty; this file lays out what that derivation returns and decides
// nothing about it. Plate drawings were not taken.
//
// The title stays docs/08's canonical name although this pass draws no
// plate: a sheet's name is an identity across revisions, and the name was
// ruled before its contents were.
//
// PAGINATED LIKE T6.20: a section heading keeps with its first row, and a
// page that opens inside a section re-prints its heading `(cont.)` with
// the column heads, so no row sits under heads that are not its own.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/pinout_details.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/derived/wiring_standard.dart'
    show wiringStandardLabel;
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
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;

const double kPinoutPt = 7;
const double kPinoutLine = 9;
const int _kMaxLines = 2;

const double _kSectionTitle = 20;
const double _kNote = 12;
const double _kColumnHeads = 12;
const double _kRowPad = 4;
const double _kInset = 8;
const double _kCellPad = 3;

/// The section titles, in the order they print. Not counted here: a count
/// beside the list it counts goes stale when the list grows (DR-231 did).
/// PORTS AND NOT JACKS: the render showed IRR-1's `PIGTAIL TO BLOCK`, the
/// receiver eye's plug, carries the same powered pinout.
const String kIrSectionTitle = 'POWERED IR RECEIVER PORTS';
const String kWiringSectionTitle = 'WIRING STANDARD EXCEPTIONS';
const String kNullModemSectionTitle = 'NULL-MODEM CABLES';
const String kPolarityReversedSectionTitle = 'POLARITY-REVERSED CABLES';
const String kTerminalSectionTitle = 'TERMINAL ORDER';

/// What the IR section says under its title (DR-221 §11.220.3).
const String kIrSectionNote =
    'A powered receiver port carries +12 V on the ring. Never plug a mono '
    'emitter into its jack: the plug bridges ring to sleeve.';

/// The T568A and T568B pin colours, pin 1 first (TIA-568). Printed under
/// the wiring section so a reader holding a punch tool needs no second
/// document.
const String kT568aKey =
    'T568A: 1 W/GN · 2 GN · 3 W/OR · 4 BL · 5 W/BL · 6 OR · 7 W/BR · 8 BR';
const String kT568bKey =
    'T568B: 1 W/OR · 2 OR · 3 W/GN · 4 BL · 5 W/BL · 6 GN · 7 W/BR · 8 BR';

/// What the null-modem section says under its title.
const String kNullModemNote =
    'Transmit and receive are crossed in the cable. Confirm the handshake '
    'lines against both devices.';

/// What the polarity-reversed section says under its title (DR-231
/// §11.230.3): the swap is the design, and the person holding the strippers
/// is the one who needs telling.
const String kPolarityReversedNote =
    'Wired + to - and - to + on purpose. Terminate as marked; do not '
    'correct the polarity.';

/// What the terminal section says under its title.
const String kTerminalNote =
    'Terminals listed pin 1 first. Wire to WIRED, not to the standard.';

/// What a variant with no recorded map prints (G4: never a guess).
const String kPinMapNotRecorded = 'not recorded';

/// One column: its head and its width in points (Σ 674).
@immutable
final class PinoutColumn {
  const PinoutColumn(this.head, this.widthPt);

  final String head;
  final double widthPt;
}

const List<PinoutColumn> _irColumns = <PinoutColumn>[
  PinoutColumn('DEVICE', 90),
  PinoutColumn('PORT', 150),
  PinoutColumn('VARIANT', 130),
  PinoutColumn('PIN MAP', 304),
];

const List<PinoutColumn> _cableColumns = <PinoutColumn>[
  PinoutColumn('CABLE ID', 70),
  PinoutColumn('FROM', 190),
  PinoutColumn('TO', 190),
  PinoutColumn('CABLE', 112),
  PinoutColumn('PROJECT', 112),
];

const List<PinoutColumn> _nullModemColumns = <PinoutColumn>[
  PinoutColumn('CABLE ID', 70),
  PinoutColumn('FROM', 230),
  PinoutColumn('TO', 230),
  PinoutColumn('MEDIA', 144),
];

const List<PinoutColumn> _terminalColumns = <PinoutColumn>[
  PinoutColumn('DEVICE', 90),
  PinoutColumn('PORT', 150),
  PinoutColumn('FAMILY', 130),
  PinoutColumn('WIRED', 152),
  PinoutColumn('STANDARD', 152),
];

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a T5.01 page.
@immutable
sealed class PinoutItem {
  const PinoutItem();

  double get height;
}

/// A section's title, its notes and its column heads.
@immutable
final class PinoutSectionHead extends PinoutItem {
  const PinoutSectionHead({
    required this.title,
    required this.columns,
    required this.notes,
    this.continued = false,
  });

  final String title;
  final List<PinoutColumn> columns;
  final List<String> notes;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  /// The heading a continuation page opens with: the title and the heads,
  /// not the notes, which page 1 already printed.
  PinoutSectionHead get asContinued => PinoutSectionHead(
    title: title,
    columns: columns,
    notes: const <String>[],
    continued: true,
  );

  @override
  double get height => _kSectionTitle + notes.length * _kNote + _kColumnHeads;
}

/// One row: each cell's wrapped lines, under its section's columns.
@immutable
final class PinoutRow extends PinoutItem {
  const PinoutRow(this.columns, this.cells);

  final List<PinoutColumn> columns;
  final List<List<String>> cells;

  /// The first cell, unwrapped, so a test can find a row by its key.
  String get key => cells.first.join(' ');

  int get lineCount => cells.fold(1, (n, c) => c.length > n ? c.length : n);

  @override
  double get height => lineCount * kPinoutLine + _kRowPad;
}

/// One page's worth of items.
@immutable
final class PinoutPage {
  const PinoutPage(this.items);

  final List<PinoutItem> items;
}

/// The body box of a T5.01 page.
DBox pinoutBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + _kInset,
  drawingArea.top + _kInset,
  drawingArea.width - 2 * _kInset,
  drawingArea.height - 2 * _kInset,
);

TextStyleSpec _style(int argb) => TextStyleSpec(
  font: kSheetFont,
  sizePt: kPinoutPt,
  argb: argb,
  anchor: TextAnchor.midLeft,
);

List<double> _widths(List<PinoutColumn> columns, double width) {
  final total = columns.fold<double>(0, (s, c) => s + c.widthPt);
  return [for (final c in columns) c.widthPt * width / total];
}

String _standard(ScheduleEntry e) {
  final s = e.wiringStandard;
  return s == null ? '—' : wiringStandardLabel(s);
}

/// T5.01's pages for [details], laid out in [drawingArea].
///
/// EMPTY when [details] is: the sheet is `AUTO`.
List<PinoutPage> paginatePinoutDetails({
  required PinoutDetails details,
  required ProjectSettings settings,
  required DBox drawingArea,
  required TextMeasurer measurer,
}) {
  if (details.isEmpty) return const <PinoutPage>[];
  final body = pinoutBodyArea(drawingArea);
  final units = settings.displayUnits;
  final project = settings.wiringStandard;
  // A PROJECT WITH NO STANDARD HAS NO EXCEPTIONS (DR-180 §11.179.4), so
  // the dash is unreachable through `pinoutDetailsOf`; it is here so a
  // hand-built report cannot print an invented standard.
  final projectStandard = project == null ? '—' : wiringStandardLabel(project);

  final flat = <PinoutItem>[];
  void section(
    String title,
    List<PinoutColumn> columns,
    List<String> notes,
    List<List<String>> rows,
  ) {
    if (rows.isEmpty) return;
    flat.add(
      PinoutSectionHead(
        title: '$title (${rows.length})',
        columns: columns,
        notes: notes,
      ),
    );
    final widths = _widths(columns, body.width);
    for (final values in rows) {
      flat.add(
        PinoutRow(columns, [
          for (final (i, v) in values.indexed)
            () {
              final lines = wrapMeasured(
                v,
                widths[i] - 2 * _kCellPad,
                style: _style(0xFF000000),
                measurer: measurer,
                maxLines: _kMaxLines,
              );
              return lines.isEmpty ? <String>[''] : lines;
            }(),
        ]),
      );
    }
  }

  section(
    kIrSectionTitle,
    _irColumns,
    const [kIrSectionNote],
    [
      for (final r in details.irPorts)
        [
          r.port.deviceDesignator,
          r.port.portLabel,
          r.variant,
          r.pinMap ?? kPinMapNotRecorded,
        ],
    ],
  );
  section(
    kWiringSectionTitle,
    _cableColumns,
    const [kT568aKey, kT568bKey],
    [
      for (final e in details.wiringExceptions)
        [
          e.designator,
          e.cell(ScheduleColumnId.fromRoomOutlet, units: units),
          e.cell(ScheduleColumnId.toRackRuFace, units: units),
          _standard(e),
          projectStandard,
        ],
    ],
  );
  section(
    kNullModemSectionTitle,
    _nullModemColumns,
    const [kNullModemNote],
    [
      for (final e in details.nullModems)
        [
          e.designator,
          e.cell(ScheduleColumnId.fromRoomOutlet, units: units),
          e.cell(ScheduleColumnId.toRackRuFace, units: units),
          e.cell(ScheduleColumnId.media, units: units),
        ],
    ],
  );
  section(
    kPolarityReversedSectionTitle,
    _nullModemColumns,
    const [kPolarityReversedNote],
    [
      for (final e in details.polarityReversed)
        [
          e.designator,
          e.cell(ScheduleColumnId.fromRoomOutlet, units: units),
          e.cell(ScheduleColumnId.toRackRuFace, units: units),
          e.cell(ScheduleColumnId.media, units: units),
        ],
    ],
  );
  section(
    kTerminalSectionTitle,
    _terminalColumns,
    const [kTerminalNote],
    [
      for (final r in details.terminalOrders)
        [
          r.port.deviceDesignator,
          r.port.portLabel,
          r.port.family.v,
          r.roles.join(' '),
          r.standard.join(' '),
        ],
    ],
  );

  final pages = <PinoutPage>[];
  var page = <PinoutItem>[];
  var y = 0.0;
  PinoutSectionHead? head;
  for (final (i, item) in flat.indexed) {
    // A SECTION HEADING KEEPS WITH ITS FIRST ROW.
    final next = i + 1 < flat.length ? flat[i + 1] : null;
    final need = item is PinoutSectionHead && next is PinoutRow
        ? item.height + next.height
        : item.height;
    if (y + need > body.height && page.isNotEmpty) {
      pages.add(PinoutPage(List.unmodifiable(page)));
      page = <PinoutItem>[];
      y = 0;
      if (head != null && item is PinoutRow) {
        final cont = head.asContinued;
        page.add(cont);
        y += cont.height;
      }
    }
    if (item is PinoutSectionHead) head = item;
    page.add(item);
    y += item.height;
  }
  if (page.isNotEmpty) pages.add(PinoutPage(List.unmodifiable(page)));
  return List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed T5.01 page.
@immutable
final class PinoutSheet {
  const PinoutSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T5.01`.
PinoutSheet buildPinoutSheet({
  required SheetDef sheet,
  required PinoutPage page,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.pinoutDetails,
    'buildPinoutSheet: ${sheet.role} is not the pinout details role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final body = pinoutBodyArea(layout.drawingArea);
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
  final titleStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: 9,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final ops = <DiagramOp>[...furniture.ops];
  var y = body.top;

  List<double> xs(List<PinoutColumn> columns) {
    final widths = _widths(columns, body.width);
    final out = <double>[];
    var x = body.left;
    for (final w in widths) {
      out.add(x);
      x += w;
    }
    return out;
  }

  for (final item in page.items) {
    switch (item) {
      case PinoutSectionHead():
        ops.add(
          OpText(
            item.text,
            DPt(body.left, y + _kSectionTitle * 0.6),
            titleStyle,
          ),
        );
        var noteY = y + _kSectionTitle;
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
        final colX = xs(item.columns);
        for (final (i, c) in item.columns.indexed) {
          ops.add(
            OpText(
              c.head,
              DPt(colX[i] + _kCellPad, noteY + _kColumnHeads / 2),
              muted,
            ),
          );
        }
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            Stroke(argb: palette.rule, widthPt: 0.5),
          ),
        );
      case PinoutRow():
        final colX = xs(item.columns);
        for (final (i, lines) in item.cells.indexed) {
          for (final (j, line) in lines.indexed) {
            if (line.isEmpty) continue;
            ops.add(
              OpText(
                line,
                DPt(
                  colX[i] + _kCellPad,
                  y + _kRowPad / 2 + kPinoutLine * (j + 0.5),
                ),
                text,
              ),
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

  final minText = furniture.minTextSizePt < kPinoutPt
      ? furniture.minTextSizePt
      : kPinoutPt;
  return PinoutSheet(
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
