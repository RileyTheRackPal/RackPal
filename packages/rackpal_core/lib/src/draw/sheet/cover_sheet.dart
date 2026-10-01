// T0.00, the cover (docs/08 §5.5, M6-A1 `#312`, DR-210).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LEFT OF THE SHEET IS THE PROJECT; THE RIGHT IS THE INDEX
// ═══════════════════════════════════════════════════════════════════════
// DR-210 §11.209.1: the project block, the scope paragraph, the integrator
// and the sign-off take the left; the drawing index (M6-A3) is a
// full-height column on the right, as wide as the title block it stands
// above, because the index is the one block that grows (M6-A3,
// `cover_index.dart`); the rack summary strip (M6-A2,
// `cover_rack_strip.dart`) runs along the foot. This file builds the left
// and places the other two, and nothing on the left may grow into the
// index's column.
//
// EVERY LINE COMES FROM `ProjectInfo`, formatted by the helpers the title
// block uses (`formatAddress`, `formatSheetDate`, `newestRevisionLabel`),
// so the cover cannot spell an address or a date differently from every
// other sheet in the set. An empty optional line COLLAPSES (§5.2); the
// sign-off fields print `—` as the title block's grid does, because there
// the absence is the fact a reviewer is looking for.
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_outlets.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/cover_index.dart';
import 'package:rackpal_core/src/draw/sheet/cover_rack_strip.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show wrapMeasured;
import 'package:rackpal_core/src/draw/sheet/revision_block.dart'
    show newestRevisionLabel;
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/sheet/title_block.dart'
    show formatAddress;
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/model/template.dart';

/// The cover's type sizes, in points.
const double kCoverTitlePt = 24;
const double kCoverSubtitlePt = 12;
const double kCoverBodyPt = 10;
const double kCoverHeadingPt = 8;

/// The most lines the scope paragraph takes before it is ellipsised, and
/// the export says so (a cover that silently loses half a sentence of
/// scope is a contract that lies by omission).
const int kCoverScopeMaxLines = 14;

/// The gap between the left block and the index column, in points.
const double _gutter = 32;
const double _inset = 8;

/// The cover's build result.
@immutable
final class CoverSheet {
  const CoverSheet({
    required this.scene,
    required this.legibility,
    required this.indexColumn,
    required this.scopeTruncated,
    required this.racksShown,
    required this.racksHidden,
    required this.indexColumns,
    required this.indexOmitted,
  });

  final DiagramScene scene;
  final LegibilityReport legibility;

  /// The full-height right-hand column the drawing index fills
  /// (§11.209.1), as wide as the title block and ending above the revision
  /// and title blocks.
  final DBox indexColumn;

  /// The scope paragraph did not fit [kCoverScopeMaxLines] and was cut.
  final bool scopeTruncated;

  /// Racks with a row in the strip, and racks named only in its closing
  /// row (§11.210.4). A non-zero [racksHidden] is an export notice.
  final int racksShown;
  final int racksHidden;

  /// The sub-columns the drawing index used (§11.211.4).
  final int indexColumns;

  /// Sheets the index could not list; a non-empty list is an export
  /// notice, never a silent omission.
  final List<SheetDef> indexOmitted;
}

/// The sign-off line, `DRAWN J.S. · CHECKED — · APPROVED —` (§11.209.3).
String coverSignOffLine(ProjectInfo info) => [
  'DRAWN ${_orDash(info.drawnBy)}',
  'CHECKED ${_orDash(info.checkedBy)}',
  'APPROVED ${_orDash(info.approvedBy)}',
].join('   ·   ');

/// The issue line: drawing number when there is one, then the newest
/// revision and the issue date, which every set has.
String coverIssueLine(
  ProjectInfo info,
  List<RevisionEntry> revisions,
  DateTime issuedAt,
) => joinNonEmpty(<String?>[
  if (_present(info.drawingNumber)) 'DRAWING ${info.drawingNumber!.trim()}',
  if (_present(info.projectNumber)) 'PROJECT ${info.projectNumber!.trim()}',
  'REVISION ${_orDash(newestRevisionLabel(revisions))}',
  'ISSUED ${formatSheetDate(issuedAt)}',
], separator: '   ·   ')!;

/// Builds `T0.00`.
///
/// [racks], [devices], [templates] and [landings] feed the rack strip,
/// and [sheets] is the RESOLVED set, so the strip's overflow row (and,
/// from M6-A3, the index) can only name sheets the file contains.
/// [landings] is required for `computeRackRollups`' reason: a default of
/// "nothing is wired" would be a silent wrong answer.
CoverSheet buildCoverSheet({
  required SheetDef sheet,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  required Iterable<Rack> racks,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required PortLandings landings,
  required List<SheetDef> sheets,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.cover,
    'buildCoverSheet: ${sheet.role} is not the cover role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final drawing = layout.drawingArea;
  final area = DBox.fromLtwh(
    drawing.left + _inset,
    drawing.top + _inset,
    drawing.width - 2 * _inset,
    drawing.height - 2 * _inset,
  );
  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    rack: null,
    revisions: revisions,
    // A cover is not a scaled drawing; `NTS` is the truth about it.
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  // THE INDEX COLUMN, reserved: the title block's width, from the top of
  // the drawing area down to the furniture stacked bottom-right.
  final furnitureTop = math.min(
    layout.titleBlockBox.top,
    layout.revisionBlockBox?.top ?? double.infinity,
  );
  final indexColumn = DBox.fromLtwh(
    layout.titleBlockBox.left,
    area.top,
    layout.titleBlockBox.width,
    furnitureTop - 10 - area.top,
  );
  final leftWidth = indexColumn.left - _gutter - area.left;

  TextStyleSpec style(double size, int argb) => TextStyleSpec(
    font: kSheetFont,
    sizePt: size,
    argb: argb,
    anchor: TextAnchor.midLeft,
  );
  final title = style(kCoverTitlePt, palette.text);
  final subtitle = style(kCoverSubtitlePt, palette.text);
  final body = style(kCoverBodyPt, palette.text);
  final heading = style(kCoverHeadingPt, palette.mutedText);

  final ops = <DiagramOp>[...furniture.ops];
  final x = area.left;
  var y = area.top + kCoverTitlePt * 0.6;

  void line(String text, TextStyleSpec s, double advance) {
    ops.add(
      OpText(
        fitTextToWidth(text, leftWidth, style: s, measurer: measurer),
        DPt(x, y),
        s,
      ),
    );
    y += advance;
  }

  // ── the project block ────────────────────────────────────────────────
  line(info.projectName.trim(), title, kCoverTitlePt * 1.3);
  if (_present(info.clientName)) {
    line(info.clientName!.trim(), subtitle, kCoverSubtitlePt * 1.6);
  }
  if (formatAddress(info.siteAddress) case final address?) {
    line(address, body, kCoverBodyPt * 1.6);
  }
  y += 8;
  line(coverIssueLine(info, revisions, issuedAt), body, kCoverBodyPt * 1.6);

  // ── the scope paragraph, only when one is written (§5.2) ─────────────
  var scopeTruncated = false;
  if (_present(info.scopeNarrative)) {
    y += 18;
    line('SCOPE', heading, kCoverHeadingPt * 2);
    final lines = wrapMeasured(
      info.scopeNarrative!,
      leftWidth,
      style: body,
      measurer: measurer,
      maxLines: kCoverScopeMaxLines,
    );
    // CUT IS MEASURED, NOT GUESSED: the paragraph overflowed iff it needs
    // one more line than the cap allows.
    scopeTruncated =
        wrapMeasured(
          info.scopeNarrative!,
          leftWidth,
          style: body,
          measurer: measurer,
          maxLines: kCoverScopeMaxLines + 1,
        ).length >
        kCoverScopeMaxLines;
    for (final l in lines) {
      ops.add(OpText(l, DPt(x, y), body));
      y += kCoverBodyPt * 1.45;
    }
  }

  // ── the integrator, when there is one ─────────────────────────────────
  final integrator = [
    info.integratorName,
    info.integratorContact,
    info.integratorLicense,
  ].where(_present).map((s) => s!.trim()).toList();
  if (integrator.isNotEmpty) {
    y += 18;
    line('INTEGRATOR', heading, kCoverHeadingPt * 2);
    for (final l in integrator) {
      line(l, body, kCoverBodyPt * 1.45);
    }
  }

  // ── the sign-off (§11.209.3) ─────────────────────────────────────────
  y += 18;
  line('SIGN-OFF', heading, kCoverHeadingPt * 2);
  line(coverSignOffLine(info), body, kCoverBodyPt * 1.45);

  // ── the rack summary strip, along the foot (M6-A2, DR-211) ───────────
  //
  // BOTTOM-UP FROM THE DRAWING AREA'S FOOT, and never above the left
  // block's last line: the strip yields to the project block rather than
  // the other way round, and a rack it cannot fit is named, not dropped.
  final strip = drawCoverRackStrip(
    rows: coverRackRows(
      racks: racks,
      devices: devices,
      templates: templates,
      landings: landings,
    ),
    sheets: sheets,
    units: settings.displayUnits,
    left: area.left,
    width: leftWidth,
    ceiling: y + 24,
    // DOWN TO THE FRAME, NOT TO `drawingArea`'s FOOT. The drawing area is
    // deliberately a rectangle stopping at the furniture's top, giving up
    // the strip left of the title block so a centred elevation can never
    // run under it (`sheet_frame.dart`). The cover is an L by ruling
    // (§11.209.1): the strip ends a gutter left of the index column, which
    // is the title block's own left edge, so it cannot reach the block.
    // The first render stopped it at the furniture's top and left a third
    // of the left side empty beneath it.
    bottom: layout.frameBox.bottom - _inset,
    measurer: measurer,
    palette: palette,
  );
  ops.addAll(strip.ops);

  // ── the drawing index, in the column reserved for it (M6-A3) ─────────
  final index = drawCoverIndex(
    rows: coverIndexRows(sheets),
    box: indexColumn,
    measurer: measurer,
    palette: palette,
  );
  ops.addAll(index.ops);

  final minText = math.min(
    furniture.minTextSizePt,
    math.min(kCoverHeadingPt, kCoverStripPt),
  );
  return CoverSheet(
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
    indexColumn: indexColumn,
    scopeTruncated: scopeTruncated,
    racksShown: strip.shown,
    racksHidden: strip.hidden,
    indexColumns: index.columns,
    indexOmitted: index.omitted,
  );
}

bool _present(String? s) => s != null && s.trim().isNotEmpty;

String _orDash(String? s) => _present(s) ? s!.trim() : '—';
