// rackpal_core/src/draw/sheet/sheet_furniture.dart — pure Dart.
//
// Composes docs/08-pdf-export.md §5's sheet furniture — border, title
// block, revision block — into ONE `DiagramScene` fragment, and reports the
// [SheetFurniture.drawingArea] left over for the sheet's own content.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY FURNITURE IS COMPOSED INTO THE SCENE RATHER THAN ATTACHED VIA
// `PageTheme(buildBackground:)`
// ─────────────────────────────────────────────────────────────────────────
// §5 specifies attaching furniture through `pw.PageTheme(buildBackground:)`
// wrapping `pw.FullPage(ignoreMargins: true, child: pw.CustomPaint(...))`,
// with a VERIFY on the parameter names.
//
// VERIFIED, on the pinned pdf 3.13.0: `PageTheme.buildBackground` and
// `buildForeground` exist verbatim (`page_theme.dart`, `BuildCallback?`),
// and `Page.postProcess` does lay them out and paint them around the page
// content. The doc's mechanism works. The VERIFY item is answered.
//
// We do not use it, for a reason that makes §5's own promises STRONGER
// rather than weaker. §5 asks for two properties: furniture must draw on
// every page including overflow pages, and it must "render identically in
// the on-screen preview". Composing furniture and content into one scene
// before the page exists gives both by construction:
//
//   * every page in this exporter is hand-paginated (§3.7) into a plain
//     `pw.Page` carrying one full-page painter, so there are no overflow
//     pages for a background to have to catch — each page composes its own
//     furniture explicitly, and a page with no furniture would be a missing
//     function call, not a missing theme;
//   * `buildSheetFurniture` returns a pure-core `DiagramScene` fragment, so
//     `rackpal_ui` can replay the IDENTICAL object through
//     `FlutterDiagramCanvas` with no dependency on `rackpal_export` —
//     which is the only way the preview promise can actually be kept, since
//     `rackpal_ui` may not import `rackpal_export` (docs/03 §7.1);
//   * one scene means ONE coordinate origin. A background painter and a
//     content painter are two `CustomPaint`s with two boxes and therefore
//     two chances to get §7.4's `boxHeight` gotcha wrong.
//
// Recorded as a deliberate deviation from §5's stated mechanism, not a
// silent one.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/revision_block.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/title_block.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;

/// The furniture layer for one sheet, plus what it leaves for content.
@immutable
final class SheetFurniture {
  const SheetFurniture({
    required this.ops,
    required this.layout,
    required this.fields,
    required this.minTextSizePt,
  });

  /// The furniture's ops, in absolute PAGE coordinates (top-left origin,
  /// Y down). A sheet builder concatenates its own content ops after these.
  final List<DiagramOp> ops;

  final SheetLayout layout;
  final TitleBlockFields fields;

  /// The smallest text size the furniture emitted, in points of paper.
  final double minTextSizePt;

  /// What is left of the drawing frame for the sheet's content.
  DBox get drawingArea => layout.drawingArea;

  /// The furniture alone as a replayable scene — what the on-screen sheet
  /// preview will render, and what a furniture-only golden asserts on.
  DiagramScene get scene => DiagramScene(
    ops: ops,
    bounds: layout.geometry.pageBox,
    hits: const <HitRegion>[],
    minTextSizePt: minTextSizePt,
    fragments: const <String, IntRange>{},
  );
}

/// Resolves the furniture geometry for [sheet] given [revisions], WITHOUT
/// needing a drawing scale.
///
/// This is the first half of the two-step dance that keeps the dependency
/// acyclic: the drawing area depends on the revision count but not on the
/// scale, while the title block's SCALE field depends on the scale, which
/// in turn depends on the drawing area. So a caller does:
///
/// ```dart
/// final layout = sheetLayoutFor(sheet, doc.revisionBlock);
/// final area   = elevationAreaOf(layout.drawingArea);
/// final scale  = /* the fit, measured against `area` — see
///                   elevation_sheet.dart's `_fitElevation` */;
/// final furniture = buildSheetFurniture(sheet: sheet, ..., scale: scale);
/// ```
///
/// THE MIDDLE LINE IS NOT A ONE-LINER, AND THIS COMMENT USED TO PRETEND IT
/// WAS. It named a `chooseDrawingScale(content.bounds, …)` helper that had
/// no production caller and has since been deleted: an elevation's content
/// box is not fixed, because annotation is inflated as the ratio shrinks,
/// so the fit rebuilds the scene per candidate and measures what it would
/// actually emit. What this doc is really about — that the LAYOUT is
/// resolved before the scale and the scale before the furniture — is
/// unchanged.
///
/// [buildSheetFurniture] re-resolves the identical layout from the same
/// inputs, so the two can never disagree.
SheetLayout sheetLayoutFor(SheetDef sheet, List<RevisionEntry> revisions) =>
    SheetLayout.resolve(
      // ZONED BY ROLE (DR-215 §11.214.1): a drawing sheet carries the
      // band and grid, a table sheet the plain inset.
      geometry: SheetGeometry(sheet.size, zoned: sheet.role.zoned),
      revisionRowCount: revisionBodyRowCount(revisions),
    );

/// Builds §5's furniture for one sheet.
///
/// [rack] is the sheet's rack for the per-rack roles and `null` for the
/// equipment list. [fileName] is the document's own file name; [issuedAt]
/// is the ONE injected clock value for the whole export (§8.4) — this
/// function never calls `DateTime.now()`, and neither does anything it
/// calls.
SheetFurniture buildSheetFurniture({
  required SheetDef sheet,
  required ProjectInfo info,
  required ProjectSettings settings,
  required Rack? rack,
  required List<RevisionEntry> revisions,
  required DrawingScale scale,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  final layout = sheetLayoutFor(sheet, revisions);

  final fields = TitleBlockFields.resolve(
    info: info,
    settings: settings,
    sheet: sheet,
    rack: rack,
    revisions: revisions,
    scale: scale,
    fileName: fileName,
    issuedAt: issuedAt,
  );

  final frame = buildSheetFrameLayer(layout.geometry, palette: palette);
  final title = buildTitleBlockLayer(
    box: layout.titleBlockBox,
    fields: fields,
    measurer: measurer,
    compact: sheet.size.usesCompactTitleBlock,
    palette: palette,
  );

  final revisionBox = layout.revisionBlockBox;
  final revision = revisionBox == null
      ? null
      : buildRevisionBlockLayer(
          box: revisionBox,
          revisions: revisions,
          measurer: measurer,
          palette: palette,
        );

  final ops = <DiagramOp>[
    ...frame.ops,
    ...title.ops,
    if (revision != null) ...revision.ops,
  ];

  final minText = math.min(
    title.minTextPt,
    revision?.minTextPt ?? double.infinity,
  );

  return SheetFurniture(
    ops: ops,
    layout: layout,
    fields: fields,
    minTextSizePt: minText,
  );
}
