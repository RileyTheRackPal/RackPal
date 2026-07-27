// rackmate_core/src/draw/sheet/title_block.dart — pure Dart.
//
// docs/08-pdf-export.md §5.2's title block: bottom-right 396 × 115 pt on
// ANSI B, a full-width 690 × 43 pt strip on ANSI A so the schedule table is
// not notched.
//
// ─────────────────────────────────────────────────────────────────────────
// EVERY FIELD RESOLVES FROM DATA. NOTHING IS TYPED AT EXPORT TIME.
// ─────────────────────────────────────────────────────────────────────────
// [TitleBlockFields.resolve] is a pure function of `(ProjectInfo,
// ProjectSettings, SheetDef, Rack?, revisions, DrawingScale, fileName,
// issuedAt)`. There is no free-text parameter anywhere in it — no note, no
// caption, no "drawing title" the export dialog could ask a user to fill
// in. `title_block_test.dart` asserts that against this file's own source,
// so adding one is a red suite and therefore a decision rather than a
// drift.
//
// The one `String` parameter, [fileName], is the DOCUMENT'S OWN file name
// carried in from the session — the same string the FILE field has printed
// since §5.2's worked example (`FILE smith.rackmate`). It is data about the
// project, not annotation about the drawing.
//
// ─────────────────────────────────────────────────────────────────────────
// EMPTY OPTIONAL LINES COLLAPSE
// ─────────────────────────────────────────────────────────────────────────
// §5.2: "Empty optional lines collapse rather than printing a blank." A
// project with no client, no address and no integrator produces a title
// block with NO blank bands — the surviving lines redistribute over the
// same height. No `OpText` is ever emitted with an empty string, which is
// the mechanical form of that rule and is asserted directly.
//
// ─────────────────────────────────────────────────────────────────────────
// TWO COMPUTED FIELDS, AND ONE OMITTED ONE
// ─────────────────────────────────────────────────────────────────────────
// * SCALE is [DrawingScale.label] — `1:n` only when the honesty predicate
//   holds, else `NTS`. See `drawing_scale.dart`.
// * SHEET follows `ProjectSettings.sheetNumbering` (CR-066): `simple`
//   prints `SHEET 3 OF 3 · …`, `ncs` prints the NCS id.
// * THE LEGEND REFERENCE IS OMITTED. §5.2's `SYMBOL LEGEND: SEE SHEET …`
//   is auto-filled from the legend sheet's number — and T0.01 is not in
//   this sheet set. Printing a cross-reference to a sheet that is not in
//   the file is the exact failure T0.00's drawing-index rule exists to
//   prevent, so the line is dropped rather than pointed at nothing. CR-023
//   already forbids it being a gate; this is stronger, and it is recorded
//   in the M1 log.
//
// THERE IS NO LOGO (RJ-017). The integrator ships as a TEXT block — firm,
// contact, licence — which carries the same information and needs no raster
// asset, which is why `drawImage`/`ImageRef` stay out of the
// `DiagramCanvas` interface entirely.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackmate_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackmate_core/src/draw/sheet/revision_block.dart'
    show newestRevisionLabel;
import 'package:rackmate_core/src/draw/sheet/sheet_def.dart';
import 'package:rackmate_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackmate_core/src/draw/sheet/text_fit.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/enums.dart' show SheetNumbering;
import 'package:rackmate_core/src/model/project_info.dart';
import 'package:rackmate_core/src/model/project_settings.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart' show RevisionEntry;

/// The discipline letter every sheet in this set carries — `T` for
/// Telecommunications (§2.1).
const String kDisciplineCode = 'T';

/// One `LABEL value` cell of the title block's two-row field grid.
@immutable
final class TitleBlockField {
  const TitleBlockField(this.label, this.value);

  final String label;

  /// Never empty — an absent value resolves to [kEmDash], because a blank
  /// cell reads as "not filled in" while `—` reads as "there is none".
  final String value;

  @override
  bool operator ==(Object other) =>
      other is TitleBlockField && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'TitleBlockField($label: $value)';
}

/// Every string the title block prints, already resolved. Contains no
/// geometry — the layout is [buildTitleBlockLayer]'s job — so the field
/// resolution can be asserted without drawing anything.
@immutable
final class TitleBlockFields {
  const TitleBlockFields._({
    required this.projectLine,
    required this.addressLine,
    required this.clientLine,
    required this.sheetTitle,
    required this.rackLine,
    required this.gridRowA,
    required this.gridRowB,
    required this.integratorLine,
    required this.sheetNumberLine,
    required this.sheetIdLine,
  });

  /// Resolves every field from the model. See the file header: no
  /// parameter here is free text.
  factory TitleBlockFields.resolve({
    required ProjectInfo info,
    required ProjectSettings settings,
    required SheetDef sheet,
    required Rack? rack,
    required List<RevisionEntry> revisions,
    required DrawingScale scale,
    required String fileName,
    required DateTime issuedAt,
  }) {
    final projectLine = rack == null
        ? info.projectName
        : '${info.projectName} — ${_rackTitle(rack)}';

    final sheetNumberValue = switch (settings.sheetNumbering) {
      SheetNumbering.simple => '${sheet.index}/${sheet.total}',
      SheetNumbering.ncs => sheet.ncsId,
    };
    final sheetNumberLine = switch (settings.sheetNumbering) {
      SheetNumbering.simple =>
        'SHEET ${sheet.index} OF ${sheet.total} · ${sheet.title}',
      SheetNumbering.ncs => 'SHEET ${sheet.ncsId} · ${sheet.title}',
    };

    return TitleBlockFields._(
      projectLine: projectLine,
      addressLine: formatAddress(info.siteAddress),
      clientLine: info.clientName == null || info.clientName!.trim().isEmpty
          ? null
          : 'CLIENT  ${info.clientName!.trim()}',
      sheetTitle: sheet.title,
      rackLine: rack == null
          ? null
          : joinNonEmpty(<String?>[
              rack.designator,
              rack.name,
              '${rack.heightU}U',
            ], separator: '  ·  '),
      gridRowA: <TitleBlockField>[
        TitleBlockField('DRAWN', _orDash(info.drawnBy)),
        TitleBlockField('SCALE', scale.label),
        TitleBlockField('SIZE', sheet.size.sizeCode),
        TitleBlockField('DATE', formatSheetDate(issuedAt)),
        TitleBlockField('REV', _orDash(newestRevisionLabel(revisions))),
      ],
      gridRowB: <TitleBlockField>[
        TitleBlockField("CHK'D", _orDash(info.checkedBy)),
        TitleBlockField('PROJ', _orDash(info.projectNumber)),
        const TitleBlockField('DISC', kDisciplineCode),
        TitleBlockField('FILE', _orDash(fileName)),
        TitleBlockField('SHEET', sheetNumberValue),
      ],
      integratorLine: joinNonEmpty(<String?>[
        info.integratorName,
        info.integratorContact,
        info.integratorLicense,
      ]),
      sheetNumberLine: sheetNumberLine,
      sheetIdLine: 'SHEET NO.  ${sheet.ncsId}',
    );
  }

  /// `SMITH RESIDENCE — RK-1 MASTER RACK`.
  final String projectLine;

  /// The formatted site address, or `null` when there is none.
  final String? addressLine;

  /// `CLIENT  J. & M. Smith`, or `null`.
  final String? clientLine;

  /// `RACK ELEVATION — FRONT`.
  final String sheetTitle;

  /// `RK-1  ·  MASTER RACK  ·  42U`, or `null` on a sheet with no rack.
  final String? rackLine;

  /// DRAWN · SCALE · SIZE · DATE · REV.
  final List<TitleBlockField> gridRowA;

  /// CHK'D · PROJ · DISC · FILE · SHEET.
  final List<TitleBlockField> gridRowB;

  /// The RJ-017 integrator text block, or `null`.
  final String? integratorLine;

  /// `SHEET 3 OF 3 · EQUIPMENT LIST AND MATERIALS`.
  final String sheetNumberLine;

  /// `SHEET NO.  T6.30` — the sheet's stable identity, always printed
  /// whatever the numbering scheme (§2.1).
  final String sheetIdLine;

  /// Every optional line, in the order they appear, for tests and for the
  /// collapse rule's own documentation.
  List<String?> get optionalLines => <String?>[
    addressLine,
    clientLine,
    rackLine,
    integratorLine,
  ];
}

/// `RK-1 MASTER RACK`, or just the designator when the rack is unnamed.
String _rackTitle(Rack rack) => rack.name.trim().isEmpty
    ? rack.designator
    : '${rack.designator} ${rack.name.trim()}';

String _orDash(String? value) =>
    value == null || value.trim().isEmpty ? kEmDash : value.trim();

/// Formats a structured [Address] into one line, collapsing every absent
/// part. Returns `null` when nothing at all is set.
String? formatAddress(Address? address) {
  if (address == null) return null;
  final cityLine = joinNonEmpty(<String?>[
    joinNonEmpty(<String?>[
      address.city,
      address.region,
    ], separator: ', '),
    address.postalCode,
  ], separator: ' ');
  return joinNonEmpty(<String?>[
    address.line1,
    address.line2,
    cityLine,
    address.country,
  ], separator: ', ');
}

// ── layout ───────────────────────────────────────────────────────────────

/// §5.2's five field-grid columns. Sums to [kTitleBlockWidth] (396) —
/// asserted by `title_block_test.dart`.
const List<double> kTitleGridColumnWidths = <double>[84, 84, 60, 96, 72];

/// The height of each of the two grid rows.
const double kTitleGridRowHeight = 13;

/// The height of each footer line (integrator, sheet numbering).
const double _kFooterLineHeight = 12;

/// Padding inside a title-block cell.
const double _kPad = 4;

/// Builds the title block into [box] (from `SheetLayout.titleBlockBox`).
///
/// [compact] selects §5.2's ANSI A full-width strip over the 396 × 115
/// block; pass `sheet.size.usesCompactTitleBlock`.
LayerBuild buildTitleBlockLayer({
  required DBox box,
  required TitleBlockFields fields,
  required TextMeasurer measurer,
  required bool compact,
  SheetPalette palette = const SheetPalette(),
}) => compact
    ? _buildCompact(box, fields, measurer, palette)
    : _buildFull(box, fields, measurer, palette);

LayerBuild _buildFull(
  DBox box,
  TitleBlockFields fields,
  TextMeasurer measurer,
  SheetPalette palette,
) {
  final ops = <DiagramOp>[
    OpRect(box, stroke: sheetRule(palette.rule, kBlockOutlineWidthPt)),
  ];

  // ── band heights ───────────────────────────────────────────────────
  final footerLines = <String>[
    if (fields.integratorLine != null) fields.integratorLine!,
  ];
  final footerHeight = (footerLines.length + 1) * _kFooterLineHeight;
  const gridHeight = 2 * kTitleGridRowHeight;
  final gridTop = box.bottom - footerHeight - gridHeight;

  // ── upper band: identity lines then sheet lines, collapsing ────────
  final identity = <({String text, double size})>[
    (text: fields.projectLine, size: SheetTextSizes.projectName),
    if (fields.addressLine != null)
      (text: fields.addressLine!, size: SheetTextSizes.identity),
    if (fields.clientLine != null)
      (text: fields.clientLine!, size: SheetTextSizes.identity),
  ];
  final sheetLines = <({String text, double size})>[
    (text: fields.sheetTitle, size: SheetTextSizes.sheetTitle),
    if (fields.rackLine != null)
      (text: fields.rackLine!, size: SheetTextSizes.rackLine),
  ];
  final upperLines = <({String text, double size})>[...identity, ...sheetLines];
  final upperHeight = gridTop - box.top;
  final rowHeight = upperHeight / upperLines.length;

  for (var i = 0; i < upperLines.length; i++) {
    final line = upperLines[i];
    final style = TextStyleSpec(
      font: kSheetFont,
      sizePt: line.size,
      argb: palette.text,
      anchor: TextAnchor.midLeft,
    );
    _emitFitted(
      ops,
      text: line.text,
      at: DPt(box.left + _kPad, box.top + (i + 0.5) * rowHeight),
      maxWidth: box.width - 2 * _kPad,
      style: style,
      measurer: measurer,
    );
    // The rule between the identity band and the sheet band.
    if (i == identity.length - 1 && sheetLines.isNotEmpty) {
      final y = box.top + (i + 1) * rowHeight;
      ops.add(
        OpLine(
          DPt(box.left, y),
          DPt(box.right, y),
          sheetRule(palette.rule, kTableRuleWidthPt),
        ),
      );
    }
  }

  // ── field grid ─────────────────────────────────────────────────────
  _emitGrid(
    ops,
    box: box,
    top: gridTop,
    rows: <List<TitleBlockField>>[fields.gridRowA, fields.gridRowB],
    palette: palette,
    measurer: measurer,
  );

  // ── footer ─────────────────────────────────────────────────────────
  var footerTop = gridTop + gridHeight;
  ops.add(
    OpLine(
      DPt(box.left, footerTop),
      DPt(box.right, footerTop),
      sheetRule(palette.rule, kTableRuleWidthPt),
    ),
  );
  for (final line in footerLines) {
    _emitFitted(
      ops,
      text: line,
      at: DPt(box.left + _kPad, footerTop + _kFooterLineHeight / 2),
      maxWidth: box.width - 2 * _kPad,
      style: TextStyleSpec(
        font: kSheetFont,
        sizePt: SheetTextSizes.integrator,
        argb: palette.text,
        anchor: TextAnchor.midLeft,
      ),
      measurer: measurer,
    );
    footerTop += _kFooterLineHeight;
  }

  _emitPair(
    ops,
    box: box,
    top: footerTop,
    height: _kFooterLineHeight,
    left: fields.sheetNumberLine,
    right: fields.sheetIdLine,
    sizePt: SheetTextSizes.sheetNumber,
    palette: palette,
    measurer: measurer,
  );

  return (
    ops: ops,
    minTextPt: SheetTextSizes.fieldLabel,
    inkBounds: box.inflate(kBlockOutlineWidthPt / 2),
  );
}

LayerBuild _buildCompact(
  DBox box,
  TitleBlockFields fields,
  TextMeasurer measurer,
  SheetPalette palette,
) {
  final ops = <DiagramOp>[
    OpRect(box, stroke: sheetRule(palette.rule, kBlockOutlineWidthPt)),
  ];

  // The whole field grid becomes one run of `LABEL value` pairs, because a
  // 43 pt strip has no room for a two-row five-column table.
  final fieldRun = <TitleBlockField>[
    ...fields.gridRowA,
    ...fields.gridRowB,
  ].map((f) => '${f.label} ${f.value}').join(' · ');

  final rows = <({String? left, String right, double size})>[
    (
      left: fields.projectLine,
      right: fields.sheetTitle,
      size: SheetTextSizes.sheetTitle,
    ),
    if (joinNonEmpty(<String?>[
          fields.addressLine,
          fields.clientLine,
          fields.integratorLine,
        ]) !=
        null)
      (
        left: joinNonEmpty(<String?>[
          fields.addressLine,
          fields.clientLine,
          fields.integratorLine,
        ]),
        right: fields.sheetNumberLine,
        size: SheetTextSizes.identity,
      ),
    (
      left: fieldRun,
      right: fields.sheetIdLine,
      size: SheetTextSizes.fieldValue,
    ),
  ];

  final rowHeight = box.height / rows.length;
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    _emitPair(
      ops,
      box: box,
      top: box.top + i * rowHeight,
      height: rowHeight,
      left: row.left,
      right: row.right,
      sizePt: row.size,
      palette: palette,
      measurer: measurer,
    );
    if (i > 0) {
      final y = box.top + i * rowHeight;
      ops.add(
        OpLine(
          DPt(box.left, y),
          DPt(box.right, y),
          sheetRule(palette.rule, kTableRuleWidthPt),
        ),
      );
    }
  }

  return (
    ops: ops,
    minTextPt: SheetTextSizes.identity,
    inkBounds: box.inflate(kBlockOutlineWidthPt / 2),
  );
}

/// Emits the two-row, five-column field grid at [top].
void _emitGrid(
  List<DiagramOp> ops, {
  required DBox box,
  required double top,
  required List<List<TitleBlockField>> rows,
  required SheetPalette palette,
  required TextMeasurer measurer,
}) {
  final gridHeight = rows.length * kTitleGridRowHeight;
  final rule = sheetRule(palette.rule, kTableRuleWidthPt);

  ops.add(OpLine(DPt(box.left, top), DPt(box.right, top), rule));

  var x = box.left;
  for (var c = 0; c < kTitleGridColumnWidths.length - 1; c++) {
    x += kTitleGridColumnWidths[c];
    ops.add(OpLine(DPt(x, top), DPt(x, top + gridHeight), rule));
  }

  final labelStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: SheetTextSizes.fieldLabel,
    argb: palette.mutedText,
    anchor: TextAnchor.midLeft,
  );
  final valueStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: SheetTextSizes.fieldValue,
    argb: palette.text,
    anchor: TextAnchor.midRight,
  );

  for (var r = 0; r < rows.length; r++) {
    final rowTop = top + r * kTitleGridRowHeight;
    if (r > 0) {
      ops.add(OpLine(DPt(box.left, rowTop), DPt(box.right, rowTop), rule));
    }
    final midY = rowTop + kTitleGridRowHeight / 2;
    var cellLeft = box.left;
    for (var c = 0; c < rows[r].length; c++) {
      final width = kTitleGridColumnWidths[c];
      final field = rows[r][c];
      final labelWidth = measurer
          .measureText(field.label, labelStyle)
          .advanceWidth;
      ops.add(OpText(field.label, DPt(cellLeft + _kPad, midY), labelStyle));
      _emitFitted(
        ops,
        text: field.value,
        at: DPt(cellLeft + width - _kPad, midY),
        maxWidth: width - labelWidth - 3 * _kPad,
        style: valueStyle,
        measurer: measurer,
      );
      cellLeft += width;
    }
  }

  ops.add(
    OpLine(
      DPt(box.left, top + gridHeight),
      DPt(box.right, top + gridHeight),
      rule,
    ),
  );
}

/// Emits a left-aligned string and a right-aligned string sharing one row,
/// truncating the left one so the two cannot collide.
void _emitPair(
  List<DiagramOp> ops, {
  required DBox box,
  required double top,
  required double height,
  required String? left,
  required String right,
  required double sizePt,
  required SheetPalette palette,
  required TextMeasurer measurer,
}) {
  final midY = top + height / 2;
  final rightStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: sizePt,
    argb: palette.text,
    anchor: TextAnchor.midRight,
  );
  final rightWidth = measurer.measureText(right, rightStyle).advanceWidth;
  ops.add(OpText(right, DPt(box.right - _kPad, midY), rightStyle));

  if (left == null || left.isEmpty) return;
  _emitFitted(
    ops,
    text: left,
    at: DPt(box.left + _kPad, midY),
    maxWidth: box.width - rightWidth - 3 * _kPad,
    style: TextStyleSpec(
      font: kSheetFont,
      sizePt: sizePt,
      argb: palette.text,
      anchor: TextAnchor.midLeft,
    ),
    measurer: measurer,
  );
}

/// Truncates [text] to [maxWidth] and emits it — or emits nothing at all
/// when not even an ellipsis fits, so no empty `OpText` ever reaches the
/// scene.
void _emitFitted(
  List<DiagramOp> ops, {
  required String text,
  required DPt at,
  required double maxWidth,
  required TextStyleSpec style,
  required TextMeasurer measurer,
}) {
  final fitted = fitTextToWidth(
    text,
    maxWidth,
    style: style,
    measurer: measurer,
  );
  if (fitted.isEmpty) return;
  ops.add(OpText(fitted, at, style));
}
