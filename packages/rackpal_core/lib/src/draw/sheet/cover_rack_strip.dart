// T0.00's rack summary strip (docs/08 §5.5, M6-A2 `#313`, DR-211).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY FIGURE HERE IS ONE ANOTHER SHEET ALREADY PRINTS
// ═══════════════════════════════════════════════════════════════════════
// Weight, VA and BTU/hr are `computeRackLoadProfile`'s, the numbers each
// elevation's load gutter prints (§11.210.1); RU is `computeRackRollups`'s,
// per face, as the Rack view's chip strip counts it (§11.210.2). Each is
// formatted by the gutter's own formatter, so an unknown reads
// `≥ 312.4 lb (3 unknown)` here exactly as it does on T2.01 and T6.30. A
// cover that phrased an unknown differently from the sheets behind it
// would be two sets of books.
//
// THE DEVICE COUNT IS ACTIVE EQUIPMENT (§11.210.3), in the user's words:
// "leave out passives from an equipment list, but note them on the BOM".
// Passive is the catalog's `Passive & Mechanical` category, whole. A
// device whose template does not resolve is counted: nothing says it is
// passive, and a count that silently dropped it would be the fabrication
// G4 forbids in the other direction.
//
// A STRIP TOO LONG IS CAPPED AND SAYS SO (§11.210.4): the racks that fit,
// in rack order, then one row naming how many more and the elevation
// sheets that hold them, and the caller turns the shortfall into a notice.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/catalog/catalog_passive.dart' show kCatPassive;
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/device_outlets.dart';
import 'package:rackpal_core/src/derived/totals.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_load_gutter.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// The strip's column headings, in order.
const List<String> kCoverStripHeaders = <String>[
  'RACK',
  'SIZE',
  'DEVICES',
  'RU USED',
  'WEIGHT',
  'POWER',
  'HEAT',
];

/// Each column's share of the strip's width, in [kCoverStripHeaders]'
/// order. Sums to 1.
///
/// Weighted toward the three rollups, whose unknown suffix is the longest
/// text in a row: the first render clipped `≥ 2490 VA (5 unknown)` at a
/// 13% POWER column while WEIGHT had room to spare.
const List<double> _columnShare = <double>[
  0.22,
  0.06,
  0.08,
  0.12,
  0.16,
  0.17,
  0.19,
];

/// The strip's text size and row pitch, in points.
const double kCoverStripPt = 8;
const double kCoverStripRow = 13;

/// One rack's line on the cover.
@immutable
final class CoverRackRow {
  const CoverRackRow({
    required this.rackId,
    required this.designator,
    required this.name,
    required this.heightU,
    required this.activeDevices,
    required this.ruFront,
    required this.ruRear,
    required this.ruUnknown,
    required this.mass,
    required this.apparentVA,
    required this.btuPerHour,
  });

  final Uuid rackId;
  final String designator;
  final String name;
  final int heightU;

  /// Devices in the rack that are not `Passive & Mechanical` (§11.210.3).
  final int activeDevices;

  /// U occupied on each face, as the Rack view counts them.
  final int ruFront;
  final int ruRear;

  /// Rail devices no elevation can give a height to. The same devices on
  /// both faces (`totals.dart`'s `isDrawnOnSomeElevation`), so one count.
  final int ruUnknown;

  final Rollup<Mass> mass;
  final Rollup<int> apparentVA;
  final Rollup<double> btuPerHour;
}

/// One row per rack, in rack order (`Rack.order`, then id, as the sheet
/// set orders the elevations).
List<CoverRackRow> coverRackRows({
  required Iterable<Rack> racks,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required PortLandings landings,
}) {
  final ordered = racks.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });
  final all = devices.toList();
  final byId = <Uuid, DeviceInstance>{for (final d in all) d.id: d};
  return [
    for (final rack in ordered)
      () {
        RackRollups face(Face f) => computeRackRollups(
          rack: rack,
          devices: all,
          templates: templates,
          face: f,
          landings: landings,
        );
        final front = face(Face.front);
        final rear = face(Face.rear);
        final load = computeRackLoadProfile(
          rack: rack,
          devices: all,
          templates: templates,
        );
        var active = 0;
        for (final d in all) {
          if (!belongsToRack(d, rack.id, byId)) continue;
          if (bodyFor(d, templates)?.category == kCatPassive) continue;
          active++;
        }
        return CoverRackRow(
          rackId: rack.id,
          designator: rack.designator,
          name: rack.name,
          heightU: rack.heightU,
          activeDevices: active,
          ruFront: front.ruUsed,
          ruRear: rear.ruUsed,
          ruUnknown: front.ruUnknownCount,
          mass: load.totalMass,
          apparentVA: load.apparentVA,
          btuPerHour: load.btuPerHour,
        );
      }(),
  ];
}

/// [row]'s cells, in [kCoverStripHeaders]' order.
List<String> coverRackCells(CoverRackRow row, UnitSystem units) => <String>[
  joinNonEmpty(<String?>[
    row.designator,
    if (row.name.trim().isNotEmpty) row.name.trim(),
  ], separator: '  ')!,
  '${row.heightU}U',
  '${row.activeDevices}',
  _ruCell(row),
  formatMassRollup(row.mass, units),
  formatIntRollup(row.apparentVA, 'VA'),
  formatBtuRollup(row.btuPerHour),
];

String _ruCell(CoverRackRow row) {
  final unknown = row.ruUnknown == 0 ? '' : ' (${row.ruUnknown} unknown)';
  return 'F ${row.ruFront} · R ${row.ruRear}$unknown';
}

/// The closing row when racks outnumber the space (§11.210.4):
/// `+ 6 more racks: see T2.13–T2.24`, naming the elevation sheets that
/// hold the racks left off, read from the RESOLVED set so it can never
/// name a sheet the file does not contain.
String coverOverflowText(Iterable<Uuid> hidden, List<SheetDef> sheets) {
  final ids = hidden.toSet();
  final elevations = [
    for (final s in sheets)
      if (s.rackId != null && ids.contains(s.rackId)) s.ncsId,
  ];
  final count = ids.length;
  final noun = count == 1 ? 'rack' : 'racks';
  if (elevations.isEmpty) return '+ $count more $noun';
  final span = elevations.length == 1
      ? elevations.single
      : '${elevations.first}–${elevations.last}';
  return '+ $count more $noun: see $span';
}

/// What [drawCoverRackStrip] drew.
@immutable
final class CoverStripResult {
  const CoverStripResult(this.ops, this.shown, this.hidden);

  final List<DiagramOp> ops;

  /// Racks given a row.
  final int shown;

  /// Racks named only in the closing row; 0 when every rack fits. When the
  /// strip could not fit even one rack, every rack is hidden and [ops] is
  /// empty.
  final int hidden;
}

/// Draws the strip bottom-up from [bottom] within [left]..[left]+[width],
/// never rising above [ceiling].
CoverStripResult drawCoverRackStrip({
  required List<CoverRackRow> rows,
  required List<SheetDef> sheets,
  required UnitSystem units,
  required double left,
  required double width,
  required double ceiling,
  required double bottom,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  if (rows.isEmpty) return const CoverStripResult(<DiagramOp>[], 0, 0);
  TextStyleSpec style(int argb) => TextStyleSpec(
    font: kSheetFont,
    sizePt: kCoverStripPt,
    argb: argb,
    anchor: TextAnchor.midLeft,
  );
  final body = style(palette.text);
  final muted = style(palette.mutedText);

  // HEADING + COLUMN HEADS + RULE, then the rows.
  const chrome = 2 * kCoverStripRow + 4;
  final capacity = ((bottom - ceiling - chrome) / kCoverStripRow).floor();
  if (capacity < 1) {
    return CoverStripResult(const <DiagramOp>[], 0, rows.length);
  }
  final fits = rows.length <= capacity;
  final shown = fits ? rows.length : capacity - 1;
  final lineCount = fits ? rows.length : shown + 1;

  final widths = [for (final s in _columnShare) s * width];
  final xs = <double>[left];
  for (final w in widths.take(widths.length - 1)) {
    xs.add(xs.last + w);
  }

  final ops = <DiagramOp>[];
  var y = bottom - (lineCount * kCoverStripRow + chrome) + kCoverStripRow / 2;
  ops.add(OpText('RACKS', DPt(left, y), muted));
  y += kCoverStripRow;
  for (var c = 0; c < kCoverStripHeaders.length; c++) {
    ops.add(OpText(kCoverStripHeaders[c], DPt(xs[c], y), muted));
  }
  y += kCoverStripRow / 2 + 2;
  ops.add(
    OpLine(
      DPt(left, y),
      DPt(left + width, y),
      Stroke(argb: palette.rule, widthPt: 0.5),
    ),
  );
  y += kCoverStripRow / 2 + 2;

  for (final row in rows.take(shown)) {
    final cells = coverRackCells(row, units);
    for (var c = 0; c < cells.length; c++) {
      ops.add(
        OpText(
          fitTextToWidth(
            cells[c],
            widths[c] - 6,
            style: body,
            measurer: measurer,
          ),
          DPt(xs[c], y),
          body,
        ),
      );
    }
    y += kCoverStripRow;
  }
  if (!fits) {
    ops.add(
      OpText(
        coverOverflowText(rows.skip(shown).map((r) => r.rackId), sheets),
        DPt(left, y),
        muted,
      ),
    );
  }
  return CoverStripResult(ops, shown, rows.length - shown);
}
