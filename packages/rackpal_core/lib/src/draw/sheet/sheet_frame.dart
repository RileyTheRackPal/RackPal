// rackpal_core/src/draw/sheet/sheet_frame.dart — pure Dart.
//
// Sheet page geometry as pure numbers, plus the border rules (docs/08
// §5.1, §6.1). Emits `DiagramOp`s; owns no PDF type and knows nothing about
// `PdfPageFormat`.
//
// WHY THE MARGINS LIVE HERE AND NOT IN `PdfPageFormat`. Every page in this
// exporter carries exactly ONE full-page `pw.CustomPaint`, so dart_pdf
// never lays anything out and its margin machinery would only be a second,
// silent source of offsets. §6.1's `EdgeInsets.fromLTRB(54, 36, 36, 36)`
// therefore lives as numbers in [SheetMargins.standard], and the ANSI
// `PdfPageFormat`s in `rackpal_export` declare ZERO margins deliberately.
//
// THE ARITHMETIC, cross-checked against the doc's own stated widths:
//   ANSI B portrait  792 × 1224   − margins → 702 × 1152 at (54, 36)
//                                 − 6 pt inset → 690 × 1140 at (60, 42)
//   ANSI A landscape 792 ×  612   − margins → 702 ×  540 at (54, 36)
//                                 − 6 pt inset → 690 ×  528 at (60, 42)
// The 690 matches §3.2/§3.3's stated usable widths exactly
// (612 − 54 − 36 − 12 = 510 portrait; 792 − 54 − 36 − 12 = 690 landscape),
// which is a useful confirmation that the arithmetic here is the doc's.
//
// THE 6 PT INSET vs §5.1's ZONE BAND, recorded rather than papered over.
// §5.1's stack is `margin → outer rule → 0.22 in zone band → inner rule →
// drawing area`, which would put 15.84 pt between the two rules. §3.2's
// arithmetic says 6 pt each side. They disagree. 6 pt is used because it is
// the figure that reproduces the doc's own usable widths, and because THE
// ZONE GRID IS NOT BUILT in this stage: its only v1 consumer is the
// schedule's `REF` column, which needs `Link`s, which do not exist until M2.
// It is omitted whole, not stubbed as an empty band.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackpal_core/src/draw/scene/rack_style.dart' show kRackFont;
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';

/// The font sheet furniture draws with.
///
/// Only one TTF is bundled today (`Jost-Regular`), so this resolves to the
/// same [FontRef] the rack scene uses. It is declared under its own name so
/// furniture can move to CR-080's `RackBody`/`RackCond`/`RackMono` faces
/// without touching every call site — and so a reader can see at a glance
/// that furniture and rack geometry are separately styleable even while
/// they currently share a face.
const FontRef kSheetFont = kRackFont;

/// Per-sheet-role page margins (docs/08 §6.1).
@immutable
final class SheetMargins {
  const SheetMargins({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// §6.1's `EdgeInsets.fromLTRB(54, 36, 36, 36)` — the wider left edge is
  /// the binding margin.
  static const SheetMargins standard = SheetMargins(
    left: 54,
    top: 36,
    right: 36,
    bottom: 36,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is SheetMargins &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'SheetMargins(l: $left, t: $top, r: $right, b: $bottom)';
}

/// Packed-ARGB colours for sheet furniture, kept separate from
/// `RackPalette` because furniture is drafting chrome rather than rack
/// geometry and a greyscale/CMYK export (§2.4) swaps one without the other.
///
/// The defaults are black ink on white paper, which is what a title block
/// is; a colour palette is an `ExportSpec` option that ships with the
/// export dialog.
@immutable
final class SheetPalette {
  const SheetPalette({
    this.rule = 0xFF000000,
    this.text = 0xFF000000,
    this.mutedText = 0xFF444444,
  });

  /// Border rules, block outlines and table hairlines.
  final int rule;

  /// Primary furniture text.
  final int text;

  /// Field LABELS (`DRAWN`, `SCALE`) as opposed to their values.
  final int mutedText;

  @override
  bool operator ==(Object other) =>
      other is SheetPalette &&
      other.rule == rule &&
      other.text == text &&
      other.mutedText == mutedText;

  @override
  int get hashCode => Object.hash(rule, text, mutedText);
}

/// Text sizes for sheet furniture, in points of paper.
///
/// Furniture is drawn at 1:1 on the sheet — it is annotation, never model
/// geometry — so these ARE the printed sizes. Every one of them is at or
/// above §6.2's 6.0 pt hard floor, and `sheet_frame_test.dart` asserts that
/// mechanically rather than by inspection.
abstract final class SheetTextSizes {
  /// Project name, the title block's first line.
  static const double projectName = 11;

  /// Site address and client lines.
  static const double identity = 7.5;

  /// The sheet-title line (`RACK ELEVATION — FRONT`).
  static const double sheetTitle = 10;

  /// The rack identity line (`RK-1  MASTER RACK  ·  42U`).
  static const double rackLine = 8;

  /// Grid cell labels (`DRAWN`, `SCALE`, …).
  static const double fieldLabel = 6;

  /// Grid cell values.
  static const double fieldValue = 7.5;

  /// The integrator text block (RJ-017).
  static const double integrator = 7;

  /// The sheet-number footer line and `SHEET NO.`.
  static const double sheetNumber = 8;

  /// Revision block column headers.
  static const double revisionHeader = 6;

  /// Revision block rows.
  static const double revisionRow = 6.5;

  /// Every size declared above — the list the floor test iterates.
  static const List<double> all = <double>[
    projectName,
    identity,
    sheetTitle,
    rackLine,
    fieldLabel,
    fieldValue,
    integrator,
    sheetNumber,
    revisionHeader,
    revisionRow,
  ];
}

/// docs/08 §5.1's outer border rule weight.
const double kOuterRuleWidthPt = 0.7;

/// docs/08 §5.1's inner border rule weight.
const double kInnerRuleWidthPt = 1;

/// The weight of block outlines inside the furniture (title block,
/// revision block).
const double kBlockOutlineWidthPt = 0.7;

/// The weight of internal table rules (§3.3's "0.35 pt between all other
/// columns and between rows").
const double kTableRuleWidthPt = 0.35;

/// A furniture stroke.
///
/// TWO CR-082 KNOBS, AND BOTH ARE SET DELIBERATELY:
///
/// * `hairlineFloor: true` selects the 0.25 pt PRINT floor rather than the
///   0.5 pt signal floor — a border rule may legitimately be finer than a
///   cable trace.
/// * `scaleWithGeometry: false` says the width is constant on paper. Sheet
///   furniture is drawn at 1:1 by every current caller, so this changes
///   nothing today; it is set anyway because the field is what the backends
///   now read (see `pdf_canvas.dart`'s `_applyStroke`), and a title block
///   that ever ends up inside a scaled bracket must not get a scaled rule.
Stroke sheetRule(int argb, double widthPt) => Stroke(
  argb: argb,
  widthPt: widthPt,
  scaleWithGeometry: false,
  hairlineFloor: true,
);

/// Static page geometry for one sheet size: the page, the margin box and
/// the drawing frame. Independent of what is drawn on it.
@immutable
final class SheetGeometry {
  const SheetGeometry(
    this.size, {
    this.margins = SheetMargins.standard,
    this.borderInset = 6,
  });

  final SheetSize size;
  final SheetMargins margins;

  /// §3.2's "border inset 6 pt inside margin" — the gap between the outer
  /// and inner rules. See the file header on §5.1's zone band.
  final double borderInset;

  double get pageWidth => size.widthPt;
  double get pageHeight => size.heightPt;

  /// The whole sheet, top-left origin, Y down (the diagram convention;
  /// the PDF backend absorbs the flip — §7.4).
  DBox get pageBox => DBox.fromLtwh(0, 0, pageWidth, pageHeight);

  /// Inside the margins — where the outer rule is drawn.
  DBox get marginBox => DBox.fromLtwh(
    margins.left,
    margins.top,
    pageWidth - margins.left - margins.right,
    pageHeight - margins.top - margins.bottom,
  );

  /// Inside the inner rule — everything a sheet may draw in.
  DBox get frameBox => marginBox.inflate(-borderInset);

  @override
  bool operator ==(Object other) =>
      other is SheetGeometry &&
      other.size == size &&
      other.margins == margins &&
      other.borderInset == borderInset;

  @override
  int get hashCode => Object.hash(size, margins, borderInset);

  @override
  String toString() => 'SheetGeometry(${size.name})';
}

/// §5.2's full title block: 396 × 115 pt, bottom-right.
const double kTitleBlockWidth = 396;
const double kTitleBlockHeight = 115;

/// §5.2's ANSI A variant: a full-width 43 pt strip along the bottom, so the
/// schedule table is not notched.
const double kCompactTitleBlockHeight = 43;

/// §5.3: the revision block is the same width as the title block, and its
/// rows are 13 pt.
const double kRevisionRowHeight = 13;

/// Where every piece of furniture sits on one sheet, and what is left over
/// for content.
///
/// The revision block's height depends on how many rows it has, so this is
/// resolved from a row count rather than being static — but it does NOT
/// depend on the drawing scale, which breaks what would otherwise be a
/// circular dependency: the caller resolves the layout, uses
/// [drawingArea] to choose a scale, and only then builds the title block
/// (which needs the scale label).
@immutable
final class SheetLayout {
  const SheetLayout._({
    required this.geometry,
    required this.frameBox,
    required this.titleBlockBox,
    required this.revisionBlockBox,
    required this.drawingArea,
    required this.revisionRowCount,
  });

  /// Resolves the furniture boxes for [geometry] given a revision block of
  /// [revisionRowCount] BODY rows (the header row is added here).
  ///
  /// Pass `revisionBodyRowCount(revisions)` from `revision_block.dart`.
  factory SheetLayout.resolve({
    required SheetGeometry geometry,
    required int revisionRowCount,
  }) {
    final frame = geometry.frameBox;
    final compact = geometry.size.usesCompactTitleBlock;

    final titleBox = compact
        ? DBox.fromLtwh(
            frame.left,
            frame.bottom - kCompactTitleBlockHeight,
            frame.width,
            kCompactTitleBlockHeight,
          )
        : DBox.fromLtwh(
            frame.right - kTitleBlockWidth,
            frame.bottom - kTitleBlockHeight,
            kTitleBlockWidth,
            kTitleBlockHeight,
          );

    // THE REVISION BLOCK IS NOT DRAWN ON THE COMPACT STRIP, and this is a
    // stated deviation from §5.3 rather than an oversight. §5.2 makes the
    // ANSI A title block full-width specifically "so the schedule table is
    // not notched"; stacking an eight-row revision grid above it would
    // notch the table by 130 pt and undo that. The REV field still prints
    // in the strip, so the sheet still states its revision — it simply does
    // not carry the history table. Recorded in the M1 log.
    final revisionBox = compact
        ? null
        : DBox.fromLtwh(
            titleBox.left,
            titleBox.top - (revisionRowCount + 1) * kRevisionRowHeight,
            kTitleBlockWidth,
            (revisionRowCount + 1) * kRevisionRowHeight,
          );

    // The drawing area is the frame with its bottom raised clear of the
    // furniture. On a full sheet the title block is bottom-RIGHT, so the
    // strictly-available region is an L — the strip to its left is given
    // up deliberately, because a rectangular drawing area is what a
    // centred elevation and a paginated table both want, and reasoning
    // about an L-shaped one is how content ends up under a title block.
    final furnitureTop = revisionBox?.top ?? titleBox.top;
    final drawing = DBox.fromLtwh(
      frame.left,
      frame.top,
      frame.width,
      furnitureTop - frame.top,
    );

    return SheetLayout._(
      geometry: geometry,
      frameBox: frame,
      titleBlockBox: titleBox,
      revisionBlockBox: revisionBox,
      drawingArea: drawing,
      revisionRowCount: revisionRowCount,
    );
  }

  final SheetGeometry geometry;
  final DBox frameBox;
  final DBox titleBlockBox;

  /// `null` on the compact (ANSI A) strip — see the constructor's note.
  final DBox? revisionBlockBox;

  /// What is left for the sheet's own content.
  final DBox drawingArea;

  /// The BODY row count the revision box was sized for.
  final int revisionRowCount;

  @override
  String toString() =>
      'SheetLayout(${geometry.size.name}, drawing: $drawingArea)';
}

/// docs/08 §5.1's border: an outer rule at the margin and an inner rule at
/// the drawing frame, both at the 0.25 pt furniture floor (CR-082).
///
/// The zone band between them is NOT drawn — see the file header.
LayerBuild buildSheetFrameLayer(
  SheetGeometry geometry, {
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[
    OpRect(
      geometry.marginBox,
      stroke: sheetRule(palette.rule, kOuterRuleWidthPt),
    ),
    OpRect(
      geometry.frameBox,
      stroke: sheetRule(palette.rule, kInnerRuleWidthPt),
    ),
  ];
  return (
    ops: ops,
    minTextPt: double.infinity,
    // The frame draws no text and its ink is exactly the margin box, grown
    // by half the outer rule's width on each side.
    inkBounds: geometry.marginBox.inflate(kOuterRuleWidthPt / 2),
  );
}
