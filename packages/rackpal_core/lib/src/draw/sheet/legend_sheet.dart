// T0.01, the symbol legend (docs/08 §5.4, AC-054, M6-B `#316`).
//
// ═══════════════════════════════════════════════════════════════════════
// BLOCK 1, THE CABLE-TYPE KEY, AND WHY IT IS A PAIR
// ═══════════════════════════════════════════════════════════════════════
// Hue is the signal DOMAIN, not the cable type (AC-054): no palette stays
// distinguishable to a colour-blind reader past about eight hues, and on a
// greyscale laser hue is gone altogether. Dash, weight and the mark carry
// the type. So every row prints its line TWICE, in colour and in
// greyscale side by side, because the pair is the evidence: a colour-only
// legend cannot be checked against a photocopy, and a greyscale-only one
// cannot be checked against the drawing.
//
// THE GREYSCALE HALF IS WHAT A MONO LASER DOES TO THE COLOUR SHEET: each
// hue becomes the grey of its own relative luminance, the same L that
// PAL-1 is stated over. Black would be the greyscale-EXPORT mode instead
// (docs/08 §3.5), which erases L entirely; a legend that previews the
// photocopy has to show the photocopy.
//
// ═══════════════════════════════════════════════════════════════════════
// WHICH ROWS (DR-207)
// ═══════════════════════════════════════════════════════════════════════
// Requirement 4's ten named types ALWAYS, one row each, as canon §6.6
// draws them, with a type's several families together on its row. Then
// one row per other family some cable in the set carries. The key a crew
// learns is the same on every project, and it is the exact sheet AC-054's
// photocopy test reads.
//
// EVERY RENDERING COMES FROM `resolveSignalStyle`, the resolver the
// canvas, the schedule's TYPE chip and the exporter already share, with
// the project's own colour overrides. A legend that computed its own
// would document a rendering the sheets do not have (M6-B1's brief).
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/catalog/catalog_passive.dart' show kCatPassive;
import 'package:rackpal_core/src/derived/device_loads.dart' show templateKeyFor;
import 'package:rackpal_core/src/draw/contrast.dart' show relativeLuminance;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/family_glyph.dart';
import 'package:rackpal_core/src/draw/scene/plan_scene.dart'
    show PlanPinCarrier;
import 'package:rackpal_core/src/draw/scene/signal_style.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/legend_blocks.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart'
    show TemplateBody, TemplateSnapshot;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// One of requirement 4's named cable types and the families that render
/// it, in canon §6.6's order.
typedef NamedCableType = ({String name, List<SignalFamilyId> families});

/// Requirement 4's ten named types (canon §6.6, AC-054).
///
/// DATA, AND HELD TO `tools/pal1_check.py`'s `REQUIREMENT_4` by a test, so
/// the legend and the PAL-1 check cannot come to name different families.
/// IR carries `ctl.ir_direct` as well as canon §6.6's two: it ships, it is
/// IR, and docs/05 §6.4 and `pal1_check.py` both list it.
const List<NamedCableType> kRequirement4Types = <NamedCableType>[
  (name: 'Analog RCA', families: [SignalFamilyId('audio.line_unbal')]),
  (
    name: 'HDMI',
    families: [
      SignalFamilyId('video.hdmi.2_0'),
      SignalFamilyId('video.hdmi.2_1'),
      SignalFamilyId('video.hdmi.1_4'),
    ],
  ),
  (
    name: 'Network',
    families: [SignalFamilyId('net.ethernet'), SignalFamilyId('net.poe')],
  ),
  (
    name: 'IR',
    families: [
      SignalFamilyId('ctl.ir_emitter'),
      SignalFamilyId('ctl.ir_receiver'),
      SignalFamilyId('ctl.ir_direct'),
    ],
  ),
  (name: 'RS-232', families: [SignalFamilyId('ctl.rs232')]),
  (
    name: 'RG6',
    families: [
      SignalFamilyId('rf.catv'),
      SignalFamilyId('rf.satellite'),
      SignalFamilyId('rf.ota'),
    ],
  ),
  (name: 'S/PDIF', families: [SignalFamilyId('audio.spdif_coax')]),
  (name: 'TOSLINK', families: [SignalFamilyId('audio.spdif_optical')]),
  (
    name: 'Speaker level',
    families: [
      SignalFamilyId('audio.speaker_lowz'),
      SignalFamilyId('audio.speaker_cv'),
    ],
  ),
  (
    name: 'Power',
    families: [
      SignalFamilyId('power.ac_branch'),
      SignalFamilyId('power.ac_iec'),
    ],
  ),
];

/// The key's rows for a set whose cables carry [familiesInUse]: the ten,
/// then every other family in use as its own row, named by the family's
/// `displayName` and ordered by that name then id (a total order).
List<NamedCableType> legendCableTypes({
  required Iterable<SignalFamilyId> familiesInUse,
  required Registries registries,
}) {
  final named = {for (final t in kRequirement4Types) ...t.families};
  final extras =
      {
        for (final f in familiesInUse)
          if (!named.contains(f)) f,
      }.toList()..sort((a, b) {
        final an = registries.signalFamilies[a]?.displayName ?? a.v;
        final bn = registries.signalFamilies[b]?.displayName ?? b.v;
        final byName = an.compareTo(bn);
        return byName != 0 ? byName : a.v.compareTo(b.v);
      });
  return [
    ...kRequirement4Types,
    for (final f in extras)
      (name: registries.signalFamilies[f]?.displayName ?? f.v, families: [f]),
  ];
}

/// [argb] as a mono laser prints it: the grey of its relative luminance,
/// encoded back to sRGB. Display arithmetic only; nothing is stored.
int greyscaleOf(int argb) {
  final l = relativeLuminance(argb);
  final srgb = l <= 0.0031308
      ? 12.92 * l
      : 1.055 * math.pow(l, 1 / 2.4) - 0.055;
  final v = (srgb * 255).round().clamp(0, 255);
  return 0xFF000000 | (v << 16) | (v << 8) | v;
}

/// The legend's text size: J-STD-710's attribute floor is 3/32 in, which
/// is 6.75 pt, and the key is read at arm's length on a rack door.
const double kLegendPt = 7.5;
const double kLegendHeadingPt = 10;

/// One family's line in the key.
const double kLegendLineHeight = 15;

/// The key's columns, in points.
const double _typeW = 96;
const double _familyW = 150;
const double _pairW = 130;
const double _swatchW = 56;
const double _inset = 8;

/// The legend's build result, with what did not fit COUNTED (a sheet that
/// silently drops a row is a legend that lies by omission).
@immutable
final class LegendSheet {
  const LegendSheet({
    required this.scene,
    required this.legibility,
    required this.omittedRows,
    this.omittedBlocks = const <String>[],
  });

  final DiagramScene scene;
  final LegibilityReport legibility;

  /// Family lines that did not fit the sheet, or zero.
  final int omittedRows;

  /// The headings of blocks 2 to 6 that did not fit the sheet, or none.
  final List<String> omittedBlocks;
}

/// Builds `T0.01`.
LegendSheet buildLegendSheet({
  required SheetDef sheet,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  required Registries registries,
  required Iterable<SignalFamilyId> familiesInUse,
  Iterable<DeviceInstance> devices = const <DeviceInstance>[],
  Map<String, TemplateSnapshot> templates = const <String, TemplateSnapshot>{},
  Iterable<PlanPinCarrier> planCarriers = const <PlanPinCarrier>[],

  /// A cable a DRAWN interconnect sheet in this set prints, or null when
  /// none does; and a cable a FALLEN-BACK one prints, or null (DR-225
  /// §11.224.6). The key shows each mark only when the set carries it.
  LegendCableSample? tagPillSample,
  LegendCableSample? netLabelSample,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.symbolLegend,
    'buildLegendSheet: ${sheet.role} is not the legend role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  // INSET FROM THE FRAME: the drawing area's edge IS the inner border
  // line, and a rendered legend showed every row's first letter sitting on
  // it.
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
    // A key is not a scaled drawing; `NTS` is the truth about it.
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  TextStyleSpec text(
    double size,
    int argb, [
    TextAnchor a = TextAnchor.midLeft,
  ]) => TextStyleSpec(font: kSheetFont, sizePt: size, argb: argb, anchor: a);

  final ops = <DiagramOp>[...furniture.ops];
  var y = area.top + kLegendHeadingPt;
  ops.add(
    OpText(
      'CABLE TYPES',
      DPt(area.left, y),
      text(kLegendHeadingPt, palette.text),
    ),
  );
  y += kLegendHeadingPt;

  // THE ARGUMENT, ON THE SHEET (docs/08 §5.4: "printed on the sheet so the
  // reader sees why"). Two lines, so it is read rather than skipped.
  for (final line in kLegendHueNote) {
    y += kLegendPt + 3;
    ops.add(
      OpText(line, DPt(area.left, y), text(kLegendPt, palette.mutedText)),
    );
  }
  y += kLegendLineHeight;

  final colourX = area.left + _typeW + _familyW;
  final greyX = colourX + _pairW;
  for (final (label, x) in [
    ('TYPE', area.left),
    ('FAMILY', area.left + _typeW),
    ('IN COLOUR', colourX),
    ('IN GREYSCALE', greyX),
  ]) {
    ops.add(OpText(label, DPt(x, y), text(kLegendPt, palette.mutedText)));
  }
  y += kLegendLineHeight / 2;
  ops.add(
    OpLine(
      DPt(area.left, y),
      DPt(greyX + _pairW, y),
      Stroke(argb: palette.rule, widthPt: 0.5),
    ),
  );

  final rows = legendCableTypes(
    familiesInUse: familiesInUse,
    registries: registries,
  );
  final bottom = area.bottom;
  var omitted = 0;
  for (final type in rows) {
    var first = true;
    for (final family in type.families) {
      y += kLegendLineHeight;
      if (y + kLegendLineHeight / 2 > bottom) {
        omitted++;
        continue;
      }
      final style = resolveSignalStyle(
        family: family,
        registries: registries,
        colorOverrides: settings.familyColorOverrides,
      );
      if (first) {
        ops.add(
          OpText(type.name, DPt(area.left, y), text(kLegendPt, palette.text)),
        );
        first = false;
      }
      ops
        ..add(
          OpText(
            registries.signalFamilies[family]?.displayName ?? family.v,
            DPt(area.left + _typeW, y),
            text(kLegendPt, palette.text),
          ),
        )
        ..addAll(_sample(style, colourX, y, style.argb, measurer, text))
        ..addAll(
          _sample(style, greyX, y, greyscaleOf(style.argb), measurer, text),
        );
    }
    // A hairline between types, so a type's families read as one row.
    ops.add(
      OpLine(
        DPt(area.left, y + kLegendLineHeight / 2),
        DPt(greyX + _pairW, y + kLegendLineHeight / 2),
        Stroke(argb: palette.mutedText, widthPt: 0.25),
      ),
    );
  }

  // ── blocks 2 to 6, right of the key (DR-208) ─────────────────────────
  //
  // WHAT THE ELEVATIONS DRAW: a device on the rails, on a shelf or in a
  // 0U channel. A staged or off-rack device prints on no elevation, so
  // its mark and its border are not the set's to explain.
  final drawn = <TemplateBody>[];
  final statuses = <LifecycleStatus>{};
  for (final d in devices) {
    final shown = switch (d.placement) {
      RailPlacement() || ShelfPlacement() || ZeroUPlacement() => true,
      _ => false,
    };
    if (!shown) continue;
    statuses.add(d.lifecycleStatus);
    if (templates[templateKeyFor(d.templateRef)]?.body case final body?) {
      drawn.add(body);
    }
  }
  final marks =
      {
          for (final b in drawn) effectiveGlyph(b.glyph, b.category),
        }.where((g) => g != DeviceGlyph.none).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  final carriers = planCarriers.toSet().toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  const gutter = 24.0;
  final keyRight = area.left + _typeW + _familyW + 2 * _pairW;
  final regionLeft = keyRight + 32;
  final colW = (area.right - regionLeft - gutter) / 2;
  final blocks = <LegendBlock>[
    symbolsBlock(
      marks: marks,
      carriers: carriers,
      width: colW,
      palette: palette,
    ),
    deviceAnatomyBlock(measurer: measurer, width: colW, palette: palette),
    conventionsBlock(
      statuses: LifecycleStatus.values.where(statuses.contains).toList(),
      hatchedPassive: drawn.any((b) => b.category == kCatPassive),
      tagPill: tagPillSample,
      netLabel: netLabelSample,
      measurer: measurer,
      palette: palette,
    ),
    identifiersBlock(settings: settings, palette: palette),
    notesBlock(
      registries: registries,
      measurer: measurer,
      width: colW,
      abbreviations: info.legendAbbreviations,
      notes: info.legendNotes,
      palette: palette,
    ),
  ];
  // A COLUMN THAT MEETS THE TITLE OR REVISION BLOCK STOPS ABOVE IT.
  final furnitureTop = math.min(
    layout.titleBlockBox.top,
    layout.revisionBlockBox?.top ?? double.infinity,
  );
  double bottomOf(double left) =>
      left + colW > layout.titleBlockBox.left ? furnitureTop - 10 : area.bottom;
  final omittedBlocks = <String>[];
  var column = 0;
  var blockY = area.top;
  for (final block in blocks) {
    var left = regionLeft + column * (colW + gutter);
    if (blockY + block.height > bottomOf(left) && column == 0) {
      column = 1;
      blockY = area.top;
      left = regionLeft + colW + gutter;
    }
    if (blockY + block.height > bottomOf(left)) {
      omittedBlocks.add(block.title);
      continue;
    }
    ops
      ..add(const OpSave())
      ..add(OpTransform(Matrix4.translationValues(left, blockY, 0)))
      ..addAll(block.ops)
      ..add(const OpRestore());
    blockY += block.height + 16;
  }

  final minText = math.min(furniture.minTextSizePt, kLegendPt);
  return LegendSheet(
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
    omittedRows: omitted,
    omittedBlocks: omittedBlocks,
  );
}

/// The hue-is-domain argument, as it prints.
const List<String> kLegendHueNote = <String>[_hueNote1, _hueNote2];

const String _hueNote1 =
    'Colour marks the signal domain, not the cable type: no palette stays '
    'distinguishable to colour-blind readers past about eight hues.';
const String _hueNote2 =
    'Dash, weight, mark and tag carry the type, so every type below still '
    'reads in greyscale (AC-054).';

/// One sample: the line at the family's own dash and weight, then its
/// mark and tag, all in [argb].
List<DiagramOp> _sample(
  SignalStyle style,
  double x,
  double y,
  int argb,
  TextMeasurer measurer,
  TextStyleSpec Function(double, int, [TextAnchor]) text,
) {
  final ops = <DiagramOp>[
    OpLine(
      DPt(x, y),
      DPt(x + _swatchW, y),
      Stroke(argb: argb, widthPt: style.widthPt, dash: style.dash),
    ),
  ];
  var tagX = x + _swatchW + 6;
  if (familyGlyphFor(style.glyph) case final glyph?) {
    ops.add(
      familyGlyphOp(
        glyph,
        DPt(tagX, y),
        kLegendPt,
        argb,
        hollowWidthPt: 0.5,
        hollowScalesWithGeometry: false,
      ),
    );
    tagX += familyGlyphAdvance(kLegendPt);
  }
  ops.add(OpText(style.tag, DPt(tagX, y), text(kLegendPt, argb)));
  return ops;
}
