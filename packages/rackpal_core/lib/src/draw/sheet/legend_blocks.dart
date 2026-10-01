// T0.01's blocks 2 to 6 (docs/08 §5.4, M6-B3 `#319`, M6-B4 `#320`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THE SET PRINTS, AND NOTHING ELSE (DR-208 §11.207.1)
// ═══════════════════════════════════════════════════════════════════════
// Each block explains marks a reader can find in the PDF they hold: the
// device marks the set's devices carry, the plan's markers when there is a
// plan, the lifecycle borders the elevations draw, a hatch when a passive
// is in the set, and the RU span label and load gutter every elevation
// has. Net-label stubs, tag pills, junction dots, `— OPEN —` ends and the
// revision cloud join the key in the change that first prints them.
//
// EVERY SAMPLE IS DRAWN BY THE CODE THE SHEETS USE: `deviceGlyphOp`,
// `planMarkerOps`, `lifecycleStroke`, `hatchBand` and `buildDeviceLayer`
// itself for the anatomy example. A legend drawing its own copy of a mark
// is a legend that can come to disagree with the drawing.
//
// EACH BLOCK IS BUILT AT ITS OWN ORIGIN and reports its height, so the
// sheet can flow the blocks into columns and name any that do not fit.
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart'
    show lifecycleLabel;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/device_glyph_art.dart';
import 'package:rackpal_core/src/draw/scene/device_layer.dart';
import 'package:rackpal_core/src/draw/scene/plan_scene.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart' show LodLevel;
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show wrapMeasured;
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/idformat/id_format.dart';
import 'package:rackpal_core/src/idformat/tokens.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// One legend block: its ops at its own origin, and the height it took.
@immutable
final class LegendBlock {
  const LegendBlock(this.title, this.ops, this.height);

  /// The block's heading, for a notice when it does not fit.
  final String title;
  final List<DiagramOp> ops;
  final double height;
}

/// The legend's line height and text size, shared with the key.
const double kLegendBlockLine = 14;
const double kLegendBlockPt = 7.5;
const double kLegendBlockHeadingPt = 10;

TextStyleSpec _text(
  double size,
  int argb, [
  TextAnchor a = TextAnchor.midLeft,
]) => TextStyleSpec(font: kSheetFont, sizePt: size, argb: argb, anchor: a);

/// A heading, and the y the block's first line sits on.
double _heading(List<DiagramOp> ops, String title, SheetPalette palette) {
  ops.add(
    OpText(
      title,
      const DPt(0, kLegendBlockHeadingPt / 2),
      _text(kLegendBlockHeadingPt, palette.text),
    ),
  );
  return kLegendBlockHeadingPt + kLegendBlockLine;
}

// ─── block 2: symbols ───────────────────────────────────────────────────

/// What each device mark is called on the legend.
///
/// EXHAUSTIVE, so a mark added to [DeviceGlyph] does not reach paper
/// until it has a printed name here.
String deviceGlyphLabel(DeviceGlyph glyph) => switch (glyph) {
  DeviceGlyph.none => 'No mark',
  DeviceGlyph.matrix => 'Matrix switch',
  DeviceGlyph.distribution => 'Distribution amplifier',
  DeviceGlyph.switcher => 'Switcher',
  DeviceGlyph.extender => 'Extender',
  DeviceGlyph.amplifier => 'Amplifier',
  DeviceGlyph.processor => 'Processor',
  DeviceGlyph.source => 'Source',
  DeviceGlyph.patchPanel => 'Patch panel',
  DeviceGlyph.power => 'Power',
  DeviceGlyph.battery => 'Battery or UPS',
  DeviceGlyph.blank => 'Blank or vent',
  DeviceGlyph.shelf => 'Shelf',
  DeviceGlyph.display => 'Display',
  DeviceGlyph.speaker => 'Speaker',
  DeviceGlyph.camera => 'Camera',
  DeviceGlyph.antenna => 'Antenna',
  DeviceGlyph.control => 'Control',
};

/// The plan marker's name on the legend.
String planMarkerLabel(PlanPinCarrier carrier) => switch (carrier) {
  PlanPinCarrier.rack => 'Rack, the datum lengths are measured from',
  PlanPinCarrier.outlet => 'Drop (outlet)',
  PlanPinCarrier.device => 'Device',
};

/// Block 2: the device marks in [marks] and the plan markers in
/// [carriers], each drawn by the function its sheet uses.
LegendBlock symbolsBlock({
  required List<DeviceGlyph> marks,
  required List<PlanPinCarrier> carriers,
  required double width,
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[];
  var y = _heading(ops, 'SYMBOLS', palette);
  const markPt = 9.0;
  final colW = width / 2;
  for (var i = 0; i < marks.length; i++) {
    final x = (i % 2) * colW;
    if (i > 0 && i.isEven) y += kLegendBlockLine;
    final op = deviceGlyphOp(
      marks[i],
      DPt(x, y),
      markPt,
      palette.text,
      strokeWidthPt: deviceGlyphStrokeWidth(markPt),
    );
    if (op != null) ops.add(op);
    ops.add(
      OpText(
        deviceGlyphLabel(marks[i]),
        DPt(x + deviceGlyphAdvance(markPt) + 4, y),
        _text(kLegendBlockPt, palette.text),
      ),
    );
  }
  if (marks.isNotEmpty) y += kLegendBlockLine;
  if (carriers.isNotEmpty) {
    const r = 4.5;
    final outline = Stroke(argb: palette.text, widthPt: 0.75);
    final ring = Stroke(
      argb: palette.text,
      widthPt: 0.75 * kPlanDeviceRingFactor,
    );
    for (final carrier in carriers) {
      ops
        ..addAll(
          planMarkerOps(
            carrier: carrier,
            domain: null,
            centre: DPt(r, y),
            r: r,
            outline: outline,
            ring: ring,
            markerWeight: 0.75,
          ),
        )
        ..add(
          OpText(
            planMarkerLabel(carrier),
            DPt(2 * r + 8, y),
            _text(kLegendBlockPt, palette.text),
          ),
        );
      y += kLegendBlockLine;
    }
  }
  return LegendBlock('SYMBOLS', ops, y);
}

// ─── block 3: device block anatomy ──────────────────────────────────────

/// The example device the anatomy block annotates. Invented, and marked
/// so on the sheet: it is a reading aid, not a device in the project.
const String kAnatomyDesignator = 'MTX-1';
const String kAnatomyName = 'House video matrix';
const String kAnatomyType = 'HDMI Matrix 8x8';
const String kAnatomySpan = '2U · 3–4';

/// Block 3: one device block drawn by `buildDeviceLayer` at print
/// treatment, with each of its parts labelled where the layer put it.
LegendBlock deviceAnatomyBlock({
  required TextMeasurer measurer,
  required double width,
  SheetPalette palette = const SheetPalette(),
  RackTypeScale typeScale = const RackTypeScale.identity(),
}) {
  final ops = <DiagramOp>[];
  final top = _heading(ops, 'DEVICE BLOCK', palette);
  final blockW = width * 0.48;
  const blockH = 2 * 22.0;
  final device = DeviceInstance(
    id: const Uuid('legend-anatomy'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('legend.anatomy'),
      version: 1,
      contentHash: 'legend',
    ),
    designator: kAnatomyDesignator,
    name: kAnatomyName,
    placement: const OffRackPlacement(),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      updatedBy: 'legend',
    ),
  );
  final body = TemplateBody(
    manufacturer: 'Example',
    model: 'MX-8',
    displayName: kAnatomyType,
    frontU: 2,
    glyph: DeviceGlyph.matrix,
  );
  final built = buildDeviceLayer(
    device,
    body,
    deviceH: 2,
    width: blockW,
    height: blockH,
    lod: LodLevel.full,
    palette: const RackPalette(),
    measurer: measurer,
    ruSpanLabel: kAnatomySpan,
    lifecycleBorder: true,
    typeScale: typeScale,
  );
  ops
    ..add(const OpSave())
    ..add(OpTransform(Matrix4.translationValues(0, top, 0)))
    ..addAll(built.ops)
    ..add(const OpRestore());

  // LEADERS TO WHERE THE LAYER PUT EACH PART, read off its own ops, so a
  // change to the layer's layout moves the callout with it.
  final labelX = blockW + 16;
  var labelY = top + 4;
  for (final (part, label) in <(String, String)>[
    (kAnatomyDesignator, 'Designator, and its mark'),
    (kAnatomySpan, 'Height, and the RUs it occupies'),
    (kAnatomyName, 'Name'),
    (kAnatomyType, 'Type'),
  ]) {
    final op = built.ops
        .whereType<OpText>()
        .where((t) => t.text == part)
        .firstOrNull;
    if (op == null) continue;
    // FROM THE BLOCK'S RIGHT EDGE, level with the part's middle (the layer
    // anchors text top-left). A leader drawn from the part's own left edge
    // ran across its text and struck it through, which a render showed.
    final partY = top + op.at.y + op.style.sizePt / 2;
    ops
      ..add(
        OpPolyline(
          <DPt>[
            DPt(blockW, partY),
            DPt(blockW + 6, partY),
            DPt(labelX - 3, labelY),
          ],
          Stroke(argb: palette.mutedText, widthPt: 0.3),
        ),
      )
      ..add(
        OpText(label, DPt(labelX, labelY), _text(kLegendBlockPt, palette.text)),
      );
    labelY += kLegendBlockLine;
  }
  final bottom = (top + blockH > labelY ? top + blockH : labelY) + 6;
  ops.add(
    OpText(
      'An example block, not a device in this project.',
      DPt(0, bottom + kLegendBlockPt / 2),
      _text(kLegendBlockPt, palette.mutedText),
    ),
  );
  return LegendBlock('DEVICE BLOCK', ops, bottom + kLegendBlockLine);
}

// ─── block 4: conventions ───────────────────────────────────────────────

/// Block 4: the lifecycle borders in [statuses], a hatch when
/// [hatchedPassive], and the two annotations every elevation carries.
LegendBlock conventionsBlock({
  required List<LifecycleStatus> statuses,
  required bool hatchedPassive,
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[];
  var y = _heading(ops, 'CONVENTIONS', palette);
  const sampleW = 34.0;
  const sampleH = 10.0;
  const rackPalette = RackPalette();
  DBox sample() => DBox.fromLtwh(0, y - sampleH / 2, sampleW, sampleH);
  for (final status in statuses) {
    ops
      ..add(
        OpRect(
          sample(),
          stroke: lifecycleStroke(status, rackPalette.deviceStroke),
        ),
      )
      ..add(
        OpText(
          'Border: ${lifecycleLabel(status)}',
          DPt(sampleW + 8, y),
          _text(kLegendBlockPt, palette.text),
        ),
      );
    y += kLegendBlockLine;
  }
  if (hatchedPassive) {
    final box = sample();
    ops
      ..add(
        OpRect(box, stroke: Stroke(argb: rackPalette.deviceStroke, widthPt: 1)),
      )
      ..addAll(hatchBand(box, rackPalette.deviceType))
      ..add(
        OpText(
          'Hatched: a blank, vent or shelf',
          DPt(sampleW + 8, y),
          _text(kLegendBlockPt, palette.text),
        ),
      );
    y += kLegendBlockLine;
  }
  for (final (sampleText, meaning) in <(String, String)>[
    ('2U · 3–4', 'Height, and the RUs a device occupies'),
    ('176.6 lb', 'Load gutter: weight carried from this RU up'),
  ]) {
    ops
      ..add(
        OpText(sampleText, DPt(0, y), _text(kLegendBlockPt, palette.mutedText)),
      )
      ..add(
        OpText(
          meaning,
          DPt(sampleW + 8, y),
          _text(kLegendBlockPt, palette.text),
        ),
      );
    y += kLegendBlockLine;
  }
  return LegendBlock('CONVENTIONS', ops, y);
}

// ─── block 5: identifiers ───────────────────────────────────────────────

/// What each token means, and the value the worked example uses.
///
/// EVERY TOKEN [IdFormat] RECOGNISES, held to [kIdFormatTokens] by a test,
/// so a token added to the grammar cannot reach a template this block
/// cannot explain.
const Map<String, ({Object value, String meaning})> kIdTokenExamples = {
  'SITE': (value: 'HQ', meaning: 'site'),
  'BUILDING': (value: 'B1', meaning: 'building'),
  'FLOOR': (value: '1', meaning: 'floor'),
  'SPACE': (value: 'A', meaning: 'space on the floor'),
  'TR': (value: 'TR1', meaning: 'telecom room'),
  'ROOM': (value: 'Living Room', meaning: 'room name'),
  'ROOM_ABBR': (value: 'LR', meaning: 'room abbreviation'),
  'AREA': (value: 'N', meaning: 'area'),
  'ZONE': (value: 'Z1', meaning: 'zone'),
  'RACK': (value: 'RK-1', meaning: 'rack designator'),
  'PANEL': (value: 'A', meaning: 'patch panel letter'),
  'PORT': (value: 12, meaning: 'panel port number'),
  'OUTLET': (value: 'WP-3', meaning: 'outlet designator'),
  'PATHWAY': (value: 'T1', meaning: 'pathway designator'),
  'SERVICE': (value: 'TV', meaning: 'service at the outlet'),
  'MEDIA': (value: 'CAT6A', meaning: 'cable media'),
  'DOMAIN': (value: 'NET', meaning: 'signal domain'),
  'TYPE_PREFIX': (value: 'AMP', meaning: 'prefix of the device type'),
  'SEP': (value: '-', meaning: 'separator'),
  'SEQ': (value: 1, meaning: 'sequence number'),
  'DEV_SEQ': (value: 1, meaning: 'device sequence number'),
  'PORT_SEQ': (value: 3, meaning: 'port sequence on the device'),
  'DEV_BLOCK': (value: 1, meaning: 'designator block'),
  'SRC_REFDES': (value: 'AMP-1', meaning: 'source device'),
  'SRC_PORT': (value: 'J01', meaning: 'source port'),
  'DST_REFDES': (value: 'SW-1', meaning: 'destination device'),
  'DST_PORT': (value: 'J12', meaning: 'destination port'),
  'DEVICE': (value: 'AMP-1', meaning: 'device designator'),
  'DIR': (value: 'OUT', meaning: 'direction'),
  'RUN': (value: 1, meaning: 'run number'),
  'N': (value: 1, meaning: 'count'),
};

/// Block 5: the project's active templates, each expanded with a worked
/// example and a line per token.
LegendBlock identifiersBlock({
  required ProjectSettings settings,
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[];
  var y = _heading(ops, 'IDENTIFIERS', palette);
  final samples = <String, Object?>{
    for (final e in kIdTokenExamples.entries) e.key: e.value.value,
    'SEP': settings.designatorSeparator,
  };
  for (final (label, format) in <(String, IdFormat)>[
    ('Device', settings.deviceDesignatorFormat),
    ('Port', settings.portDesignatorFormat),
    ('Cable', settings.linkDesignatorFormat),
    ('Outlet, field end', settings.outletFieldLabelFormat),
    ('Outlet, rack end', settings.outletRackLabelFormat),
  ]) {
    String example;
    try {
      example = format.render(samples);
    } on Exception {
      example = 'cannot be expanded';
    }
    ops
      ..add(OpText(label, DPt(0, y), _text(kLegendBlockPt, palette.text)))
      ..add(
        OpText(
          '${format.pattern}  →  $example',
          DPt(84, y),
          _text(kLegendBlockPt, palette.text),
        ),
      );
    y += kLegendBlockLine;
    for (final token in format.requiredTokens()) {
      final entry = kIdTokenExamples[token];
      final value = token == 'SEP'
          ? settings.designatorSeparator
          : '${entry?.value ?? ''}';
      ops.add(
        OpText(
          '$token = $value, ${entry?.meaning ?? 'not a recognised token'}',
          DPt(96, y),
          _text(kLegendBlockPt, palette.mutedText),
        ),
      );
      y += kLegendBlockLine - 2;
    }
    y += 4;
  }
  return LegendBlock('IDENTIFIERS', ops, y);
}

// ─── block 6: abbreviations and general notes ───────────────────────────

/// The seeded abbreviations: what the sheets themselves print (DR-208
/// §11.207.2). A project that has not edited its list prints these, and
/// follows them as they change (DR-209 §11.208.4).
const List<LegendAbbreviation> kLegendAbbreviations = <LegendAbbreviation>[
  LegendAbbreviation('RU', 'rack unit, 1.75 in'),
  LegendAbbreviation('NTS', 'not to scale'),
  LegendAbbreviation('REV', 'revision'),
  LegendAbbreviation("CHK'D", 'checked by'),
  LegendAbbreviation('DISC', 'discipline'),
  LegendAbbreviation('PROJ', 'project number'),
];

/// The seeded general notes.
const List<String> kLegendGeneralNotes = <String>[
  'Do not scale a sheet marked NTS.',
  'A value shown as — is not known, and was not guessed.',
];

/// The most lines one abbreviation's meaning or one note may take before
/// it is ellipsised. Generous, since the block reports its height and a
/// block too tall for its column is named in an export notice rather than
/// clipped.
const int kLegendNoteMaxLines = 8;

/// Block 6: the abbreviations, the signal-domain prefixes the tags carry
/// (from the project's own registries), and the general notes.
///
/// [abbreviations] and [notes] are the project's own (`ProjectInfo`), and
/// null prints the seed (DR-209 §11.208.4). The tag prefixes follow the
/// author's rows and are never the author's to edit: they are what the
/// registries say the tags mean.
///
/// **EVERYTHING AN AUTHOR TYPES IS MEASURED AND WRAPPED** to [width]. The
/// seed fits on one line each, and a person's note will not;
/// `PdfGraphics.drawString` neither wraps nor clips, so an unmeasured
/// string runs across the next column and off the sheet.
LegendBlock notesBlock({
  required Registries registries,
  required TextMeasurer measurer,
  required double width,
  List<LegendAbbreviation>? abbreviations,
  List<String>? notes,
  SheetPalette palette = const SheetPalette(),
}) {
  final ops = <DiagramOp>[];
  var y = _heading(ops, 'ABBREVIATIONS AND NOTES', palette);
  final domains = registries.signalDomains.values.toList()
    ..sort((a, b) {
      final byTag = a.tagPrefix.compareTo(b.tagPrefix);
      return byTag != 0 ? byTag : a.id.v.compareTo(b.id.v);
    });
  final rows = <LegendAbbreviation>[
    ...(abbreviations ?? kLegendAbbreviations),
    for (final d in domains)
      LegendAbbreviation(d.tagPrefix, '${d.displayName} (a tag prefix)'),
  ];
  final body = _text(kLegendBlockPt, palette.text);
  const step = kLegendBlockLine - 2;
  // THE MEANING COLUMN MOVES RIGHT FOR A LONG ABBREVIATION, and stops at a
  // third of the block: 48 pt is what the seed always used, so a project
  // with only short abbreviations draws exactly as before.
  const double seedX = 48;
  var widest = 0.0;
  for (final r in rows) {
    final w = measurer.measureText(r.abbreviation, body).advanceWidth;
    if (w > widest) widest = w;
  }
  final meaningX = math.min(
    math.max(seedX, widest + 8),
    math.max(seedX, width / 3),
  );
  for (final r in rows) {
    final abbr = fitTextToWidth(
      r.abbreviation.trim(),
      meaningX - 6,
      style: body,
      measurer: measurer,
    );
    final lines = wrapMeasured(
      r.meaning,
      width - meaningX,
      style: body,
      measurer: measurer,
      maxLines: kLegendNoteMaxLines,
    );
    ops.add(OpText(abbr, DPt(0, y), body));
    for (final (i, line) in lines.indexed) {
      ops.add(OpText(line, DPt(meaningX, y + i * step), body));
    }
    y += step * math.max(1, lines.length);
  }
  y += 6;
  final muted = _text(kLegendBlockPt, palette.mutedText);
  for (final note in notes ?? kLegendGeneralNotes) {
    for (final line in wrapMeasured(
      note,
      width,
      style: muted,
      measurer: measurer,
      maxLines: kLegendNoteMaxLines,
    )) {
      ops.add(OpText(line, DPt(0, y), muted));
      y += step;
    }
    // A GAP BETWEEN NOTES, because a wrapped note otherwise runs straight
    // into the next one: the first render read three notes as two.
    y += 3;
  }
  return LegendBlock('ABBREVIATIONS AND NOTES', ops, y);
}
