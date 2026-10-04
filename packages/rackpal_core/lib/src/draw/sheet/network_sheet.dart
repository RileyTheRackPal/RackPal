// T6.50, the Network/IP Schedule (docs/08 §2.2 row n+5, NET-A/3a `#992`,
// DR-048 §11.47.4, DR-228).
//
// ═══════════════════════════════════════════════════════════════════════
// AUTO, AND THE ROWS DECIDE IT
// ═══════════════════════════════════════════════════════════════════════
// The sheet exists iff a device carries a network value (DR-048
// §11.47.4), and it lists exactly those devices (DR-228 §11.227.2): a
// blank row on a client's copy reads as an omission. The rows come from
// `buildNetworkTable`, the derivation the Devices view renders, in the
// project's one network order (DR-227 §11.226.4), so the sheet and the
// screen cannot disagree about a value, its form or its place (CR-107).
// This file decides nothing about membership or order.
//
// ALL TEN COLUMNS (§11.227.1): the tech setting a static address at the
// rack needs the subnet and the gateway, and paper has no Columns menu.
//
// EVERY ROW IS DATED OR SAYS IT IS NOT (DR-048 §11.47.3, NET-A/3b
// `#993`). A sheet that prints a bare address is the failure the ruling
// exists to prevent: an address typed from a quote, never checked, reads
// on paper exactly like one a tech confirmed yesterday. So VERIFIED is a
// column like any other, an undated row prints `unverified` in the muted
// ink an unknown gets everywhere else, and a key on every page says what
// the column means.
//
// PAGINATED LIKE T6.20: the page count is known before anything renders,
// so the set can say `SHEET i OF n`, and the column heads repeat on every
// page. There are no bands: LOCATION carries the rack or room, and the
// order the user picked already groups by it.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/network_table.dart';
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
import 'package:rackpal_core/src/model/enums.dart' show NetworkOrder;
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart'
    show RackDocument, RevisionEntry;

/// Text size and the height of one wrapped line, in points: the
/// schedules' (T6.10, T6.15, T6.20).
const double kNetworkSheetPt = 7;
const double kNetworkSheetLine = 9;

/// The most lines a cell wraps to before it is ellipsised. A device name
/// is the only cell that wraps in practice.
const int kNetworkSheetMaxLines = 2;

const double _kHeading = 22;
const double _kColumnHeads = 12;
const double _kRowPad = 4;
const double _kNote = 12;
const double _kInset = 8;
const double _kCellPad = 3;

/// VERIFIED's position among the cells.
final int _kVerifiedColumn = NetworkColumnId.verified.index;

/// The sheet's heading, before its count.
const String kNetworkSheetHeading = 'NETWORK/IP SCHEDULE';

/// The note under the heading that says what order the rows are in, so a
/// reader looking for a device knows whether to scan by designator or by
/// rack. Printed on every page, as T6.20's key is.
String networkOrderNote(NetworkOrder order) => switch (order) {
  NetworkOrder.designator => 'Listed by device designator.',
  NetworkOrder.rackThenRoom =>
    'Listed rack by rack, top of rack down, then room by room.',
};

/// The key under the heading that says what VERIFIED means. Printed on
/// every page, as the order note is: a reader handed page 2 alone is owed
/// it as much as page 1.
const String kVerifiedKey =
    'VERIFIED: the day this row was last checked against the device on '
    'site. unverified: not checked yet, so treat the values as planned.';

/// T6.50's widths in points (Σ 674, the 690 pt ANSI A usable width less
/// the 8 pt inset each side), in [NetworkColumnId] order.
///
/// THE ADDRESS COLUMNS ARE SIZED FOR THE LONGEST DOTTED QUAD,
/// `255.255.255.255`, and MAC for `00:11:22:33:44:55`, at 7 pt, so a real
/// value never wraps; NAME takes the slack because a model name is the
/// one cell of unbounded length.
const Map<NetworkColumnId, double> kNetworkSheetWidths = {
  NetworkColumnId.device: 50,
  NetworkColumnId.name: 100,
  NetworkColumnId.where: 70,
  NetworkColumnId.hostname: 84,
  NetworkColumnId.ip: 66,
  NetworkColumnId.subnet: 66,
  NetworkColumnId.gateway: 66,
  NetworkColumnId.mac: 76,
  NetworkColumnId.vlans: 46,
  NetworkColumnId.verified: 50,
};

/// The text [row] prints in [column]: the Devices view's cell, with
/// nothing-said printed as G4's unknown so a blank on paper is never
/// mistaken for a cell somebody forgot to fill.
String networkSheetCell(NetworkRow row, NetworkColumnId column) {
  final text = networkCellText(row, column);
  return text.isEmpty ? kUnknownCell : text;
}

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a T6.50 page.
@immutable
sealed class NetworkSheetItem {
  const NetworkSheetItem();

  double get height;
}

/// The sheet heading, its note and the column heads.
@immutable
final class NetworkSheetHeading extends NetworkSheetItem {
  const NetworkSheetHeading({
    required this.title,
    required this.notes,
    this.continued = false,
  });

  final String title;
  final List<String> notes;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  NetworkSheetHeading get asContinued =>
      NetworkSheetHeading(title: title, notes: notes, continued: true);

  @override
  double get height => _kHeading + notes.length * _kNote + _kColumnHeads;
}

/// One device: each cell's wrapped lines, in [NetworkColumnId] order.
@immutable
final class NetworkSheetRow extends NetworkSheetItem {
  const NetworkSheetRow(this.designator, this.cells);

  /// The device's designator, so a test can find the row without reading
  /// a cell by position.
  final String designator;
  final List<List<String>> cells;

  int get lineCount => cells.fold(1, (n, c) => c.length > n ? c.length : n);

  @override
  double get height => lineCount * kNetworkSheetLine + _kRowPad;
}

/// One page's worth of items.
@immutable
final class NetworkSheetPage {
  const NetworkSheetPage(this.items);

  final List<NetworkSheetItem> items;

  /// The designators of the devices on this page, in order.
  List<String> get designators => [
    for (final item in items)
      if (item is NetworkSheetRow) item.designator,
  ];
}

/// The rows T6.50 prints for [doc]: the Devices view's rows, in the
/// project's order, keeping only those with a value (DR-228 §11.227.2).
List<NetworkRow> networkSheetRowsOf(RackDocument doc) => [
  for (final row in buildNetworkTable(doc, order: doc.settings.networkOrder))
    if (row.hasValues) row,
];

/// The export notice for network-capable devices with nothing recorded
/// (DR-228 §11.227.2), or null when there are none or when T6.50 does not
/// print.
///
/// ONLY WHEN THE SHEET PRINTS. A project that records no addresses at all
/// has no schedule to have a gap in, and a notice on every export of it
/// would be a nag about a feature the user is not using; the gap worth
/// saying is the one inside a schedule that looks complete.
String? networkUnrecordedNotice(RackDocument doc, String sheetId) {
  final rows = buildNetworkTable(doc, order: doc.settings.networkOrder);
  if (!rows.any((r) => r.hasValues)) return null;
  final blank = [
    for (final r in rows)
      if (!r.hasValues) r.designator,
  ];
  if (blank.isEmpty) return null;
  final n = blank.length;
  return '$n network-capable device${n == 1 ? ' has' : 's have'} nothing '
      'recorded and ${n == 1 ? 'is' : 'are'} not on $sheetId: '
      '${blank.join(', ')}.';
}

/// The body box of a T6.50 page: the drawing area, inset clear of the
/// frame line.
DBox networkSheetBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + _kInset,
  drawingArea.top + _kInset,
  drawingArea.width - 2 * _kInset,
  drawingArea.height - 2 * _kInset,
);

TextStyleSpec _style(int argb) => TextStyleSpec(
  font: kSheetFont,
  sizePt: kNetworkSheetPt,
  argb: argb,
  anchor: TextAnchor.midLeft,
);

/// [kNetworkSheetWidths] scaled to [width], so the table spans the body
/// whatever the drawing area is.
List<double> _widths(double width) {
  final total = kNetworkSheetWidths.values.fold<double>(0, (s, w) => s + w);
  return [
    for (final c in NetworkColumnId.values)
      kNetworkSheetWidths[c]! * width / total,
  ];
}

/// T6.50's pages for [rows], laid out in [drawingArea].
///
/// EMPTY when [rows] is: the sheet is `AUTO` (docs/08 §2.2), and a page
/// saying "none" is exactly what an `AUTO` sheet must not print.
List<NetworkSheetPage> paginateNetworkSchedule({
  required List<NetworkRow> rows,
  required NetworkOrder order,
  required DBox drawingArea,
  required TextMeasurer measurer,
}) {
  if (rows.isEmpty) return const <NetworkSheetPage>[];
  final body = networkSheetBodyArea(drawingArea);
  final widths = _widths(body.width);
  final heading = NetworkSheetHeading(
    title: '$kNetworkSheetHeading (${rows.length})',
    notes: <String>[networkOrderNote(order), kVerifiedKey],
  );

  final pages = <NetworkSheetPage>[];
  var page = <NetworkSheetItem>[heading];
  var y = heading.height;
  for (final row in rows) {
    final item = NetworkSheetRow(row.designator, [
      for (final (i, c) in NetworkColumnId.values.indexed)
        () {
          final lines = wrapMeasured(
            networkSheetCell(row, c),
            widths[i] - 2 * _kCellPad,
            style: _style(0xFF000000),
            measurer: measurer,
            maxLines: kNetworkSheetMaxLines,
          );
          return lines.isEmpty ? <String>[''] : lines;
        }(),
    ]);
    if (y + item.height > body.height && page.length > 1) {
      pages.add(NetworkSheetPage(List.unmodifiable(page)));
      page = <NetworkSheetItem>[heading.asContinued];
      y = heading.height;
    }
    page.add(item);
    y += item.height;
  }
  pages.add(NetworkSheetPage(List.unmodifiable(page)));
  return List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed T6.50 page.
@immutable
final class NetworkSheet {
  const NetworkSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T6.50`.
NetworkSheet buildNetworkSheet({
  required SheetDef sheet,
  required NetworkSheetPage page,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.networkSchedule,
    'buildNetworkSheet: ${sheet.role} is not the network schedule role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final body = networkSheetBodyArea(layout.drawingArea);
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
  final widths = _widths(body.width);
  final xs = <double>[];
  var x = body.left;
  for (final w in widths) {
    xs.add(x);
    x += w;
  }
  final text = _style(palette.text);
  final muted = _style(palette.mutedText);
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
      case NetworkSheetHeading():
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
        for (final (i, c) in NetworkColumnId.values.indexed) {
          ops.add(
            OpText(
              networkColumnHeader(c),
              DPt(xs[i] + _kCellPad, noteY + _kColumnHeads / 2),
              muted,
            ),
          );
        }
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            rule,
          ),
        );
      case NetworkSheetRow():
        for (final (i, lines) in item.cells.indexed) {
          // AN UNDATED ROW IN THE MUTED INK, so a column of dates and
          // `unverified`s reads at a glance as which rows to trust.
          final undated =
              i == _kVerifiedColumn &&
              lines.length == 1 &&
              lines.single == kUnverified;
          for (final (j, line) in lines.indexed) {
            if (line.isEmpty) continue;
            final lineY = y + _kRowPad / 2 + kNetworkSheetLine * (j + 0.5);
            ops.add(
              OpText(
                line,
                DPt(xs[i] + _kCellPad, lineY),
                undated ? muted : text,
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

  final minText = furniture.minTextSizePt < kNetworkSheetPt
      ? furniture.minTextSizePt
      : kNetworkSheetPt;
  return NetworkSheet(
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
