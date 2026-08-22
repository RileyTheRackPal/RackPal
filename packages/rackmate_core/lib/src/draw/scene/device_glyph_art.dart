// The seventeen device marks, as geometry. DR-059 (canon §11.58), placed
// by DR-083 (§11.82), board #694 / #752.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE IS `family_glyph.dart` APPLIED TO A SECOND CHANNEL
// ═════════════════════════════════════════════════════════════════════
// Read that file's header first. It exists because the SIGNAL glyph was
// a codepoint: Jost carries none of those characters, so
// `PdfFontMeasurer` returned a near-zero advance while the screen's
// `TextPainter` fell back to a system font and drew it full width.
// Measured short, drawn wide, and the field saw `NET-NEN006` printed
// over a net name. Every gate missed it because both backends emitted
// IDENTICAL ops and only the font behind one differed.
//
// So the device mark is a PATH from the first line of code, and this
// file reuses that fix rather than its style:
//
//   * width is COMPUTED by [deviceGlyphAdvance] from the type size
//     alone, and the emitter and any measurer read that one function;
//   * ONE op per mark whatever the shape, so a downstream op-KIND
//     assertion never depends on which mark a device happens to carry;
//   * no backend can substitute a face for a path.
//
// ═════════════════════════════════════════════════════════════════════
// EIGHTEEN VALUES, NOT SEVENTEEN, AND THE EIGHTEENTH DRAWS NOTHING
// ═════════════════════════════════════════════════════════════════════
// `DeviceGlyph.none` is a value an author CHOSE and it means "no mark".
// It is not the same as `TemplateBody.glyph` being null, which means the
// category default applies. So [deviceGlyphOp] answers `null` for
// `none`, and a caller emits nothing: zero ops, not an empty path.
//
// ═════════════════════════════════════════════════════════════════════
// WHERE THE SET IS MOST LIKELY TO FAIL, NAMED SO #757 KNOWS WHERE TO LOOK
// ═════════════════════════════════════════════════════════════════════
// DR-059 capped the set at seventeen because "the mark draws 1U tall on
// a greyscale photocopy". DR-083 then placed it INLINE, at cap height on
// the designator line, which is about 8 pt of drawing at the shipped
// 11 pt designator. Seventeen silhouettes at 8 pt is the ambitious part
// of this feature, and no assertion in this package can measure it.
//
// These are the neighbourhoods to check on the printed sheet, in the
// order they are most likely to collide. They are recorded here rather
// than discovered, because "look at all seventeen" is not a test:
//
//   1. THE ROUND FAMILY — [DeviceGlyph.camera] (two concentric circles),
//      [DeviceGlyph.control] (a square holding a circle) and
//      [DeviceGlyph.power] (a circle with a bar). Three marks whose
//      outermost stroke is a curve.
//   2. THE BOX FAMILY — [DeviceGlyph.matrix] (box + plus),
//      [DeviceGlyph.switcher] (box + cross) and
//      [DeviceGlyph.processor] (box in box). Identical outlines that
//      differ only in what is inside them.
//   3. FILL IS THE ONLY DIFFERENCE between [DeviceGlyph.amplifier] and
//      [DeviceGlyph.source]: both are a right-pointing triangle, hollow
//      and solid. That is `family_glyph`'s own tier convention reused,
//      and it is the pair a photocopy is most likely to flatten.
//   4. [DeviceGlyph.blank] is a solid rectangle and [DeviceGlyph.shelf]
//      is a bracket; on a HATCHED passive body both sit on DR-083's
//      knocked-out panel, which is the only place the mark is drawn over
//      ink rather than over the body fill.
//
// A failure in any of those is a reason to redraw the mark, never to
// widen the set: the cap is DR-059's ruling and the whole argument for
// seventeen is that forty is unreadable at this size.
import 'dart:math' as math;

import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/path.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/model/device_glyph.dart';

/// The mark's drawn box, as a multiple of the type size.
///
/// A CAP HEIGHT, not an em, for `family_glyph.dart`'s reason: the mark
/// sits on a text line beside the designator at the same size, and a
/// symbol drawn to the full em towers over the letters beside it. 0.72
/// is the ordinary cap-height ratio for a geometric sans, and sharing
/// the constant's VALUE with the family glyph is deliberate so the two
/// channels read at one weight when a reader meets both.
const double kDeviceGlyphCapFactor = 0.72;

/// The gap after the mark before the designator begins, as a multiple of
/// the type size.
///
/// Part of [deviceGlyphAdvance] rather than added at the call site, so
/// one function answers "how far right does the text start" and there is
/// no second place to forget it.
const double kDeviceGlyphBearingFactor = 0.22;

/// How far the text after the mark is pushed right, at [sizePt].
///
/// THE EMITTER AND THE MEASURER BOTH READ THIS, which is the property
/// that makes geometry safe where a codepoint was not.
double deviceGlyphAdvance(double sizePt) =>
    sizePt * (kDeviceGlyphCapFactor + kDeviceGlyphBearingFactor);

/// ONE op drawing [glyph] at [sizePt], its box centred vertically on
/// [leftMid] and starting at its x. `null` when the mark is
/// [DeviceGlyph.none], which draws nothing at all.
///
/// ONE OP WHATEVER THE SHAPE. Several marks are two or three disjoint
/// figures (a display is a screen, a stem and a base) and they ride in
/// one [DiagramPath] as separate subpaths rather than as separate ops,
/// so a device's op count never depends on which mark it carries.
DiagramOp? deviceGlyphOp(
  DeviceGlyph glyph,
  DPt leftMid,
  double sizePt,
  int argb, {
  required double strokeWidthPt,
}) {
  if (glyph == DeviceGlyph.none) return null;
  final r = sizePt * kDeviceGlyphCapFactor / 2;
  final cx = leftMid.x + r;
  final cy = leftMid.y;
  final commands = _commandsFor(glyph, cx: cx, cy: cy, r: r);
  final path = DiagramPath(commands);
  return _filled.contains(glyph)
      ? OpPath(path, fill: Fill(argb))
      : OpPath(
          path,
          stroke: Stroke(argb: argb, widthPt: strokeWidthPt),
        );
}

/// The two marks drawn solid rather than as an outline.
///
/// [DeviceGlyph.blank] because a blank panel IS a filled face, and
/// [DeviceGlyph.source] because it is a play mark and because fill is
/// the only thing separating it from [DeviceGlyph.amplifier]'s hollow
/// triangle. See the header's third legibility note.
const Set<DeviceGlyph> _filled = {DeviceGlyph.blank, DeviceGlyph.source};

/// The shape in device coordinates, centred on `(cx, cy)` inside a box
/// of half-side [r].
///
/// **Y GROWS DOWNWARD**, the sheet's convention, so a shape's "top" sits
/// at the SMALLER y.
///
/// A `switch` over the enum with no default case, so an eighteenth
/// `DeviceGlyph` fails to compile here rather than landing silently in a
/// fallback. That is `family_glyph.dart`'s rule and the reason its own
/// mapping is walked by a test rather than transcribed.
List<PathCommand> _commandsFor(
  DeviceGlyph glyph, {
  required double cx,
  required double cy,
  required double r,
}) => switch (glyph) {
  // Answered before the switch; repeated so the enum stays exhaustive.
  DeviceGlyph.none => const <PathCommand>[],

  // A crossbar: the box plus a full plus. Rows crossing columns is what
  // a matrix IS, and it is the one mark whose picture is its wiring.
  DeviceGlyph.matrix => <PathCommand>[
    ..._box(cx, cy, r),
    ..._line(cx, cy - r, cx, cy + r),
    ..._line(cx - r, cy, cx + r, cy),
  ],

  // One in, three out. Drawn as a real fan rather than a box, because
  // distribution is the only mark in the video/RF neighbourhood that can
  // afford to be open and it buys separation from `switcher`.
  DeviceGlyph.distribution => <PathCommand>[
    ..._line(cx - r, cy, cx, cy),
    ..._line(cx, cy, cx + r, cy - r),
    ..._line(cx, cy, cx + r, cy),
    ..._line(cx, cy, cx + r, cy + r),
  ],

  // Many in, many out, switched: the box plus a cross. Deliberately the
  // same outline as `matrix` with a rotated interior, because the two
  // are the same class of box and a reader who confuses them has lost
  // very little. See the header's second legibility note.
  DeviceGlyph.switcher => <PathCommand>[
    ..._box(cx, cy, r),
    ..._line(cx - r, cy - r, cx + r, cy + r),
    ..._line(cx + r, cy - r, cx - r, cy + r),
  ],

  // A link across a distance: two small boxes joined by a run. The gap
  // is the point, so the end boxes are a third of the height and the
  // line between them carries most of the width.
  DeviceGlyph.extender => <PathCommand>[
    ..._rect(cx - r, cy - r / 2, cx - r / 2, cy + r / 2),
    ..._line(cx - r / 2, cy, cx + r / 2, cy),
    ..._rect(cx + r / 2, cy - r / 2, cx + r, cy + r / 2),
  ],

  // The triangle, pointing right: the schematic's own amplifier mark,
  // hollow. Solid is `source`.
  DeviceGlyph.amplifier => <PathCommand>[
    MoveTo(cx - r, cy - r),
    LineTo(cx + r, cy),
    LineTo(cx - r, cy + r),
    const ClosePath(),
  ],

  // A processing block: a box holding a box. Two concentric squares
  // rather than a filled core, because a solid centre at 8 pt closes up
  // into `blank`.
  DeviceGlyph.processor => <PathCommand>[
    ..._box(cx, cy, r),
    ..._box(cx, cy, r / 2),
  ],

  // A play mark. Filled, which is the ONLY thing separating it from
  // `amplifier` (header note 3).
  DeviceGlyph.source => <PathCommand>[
    MoveTo(cx - r, cy - r),
    LineTo(cx + r, cy),
    LineTo(cx - r, cy + r),
    const ClosePath(),
  ],

  // A row of jacks: a shallow box with four ticks. Shallow because a
  // patch panel is the flattest thing in a rack and the proportion is
  // most of the recognition.
  DeviceGlyph.patchPanel => <PathCommand>[
    ..._rect(cx - r, cy - r / 2, cx + r, cy + r / 2),
    ..._line(cx - r / 2, cy - r / 2, cx - r / 2, cy + r / 2),
    ..._line(cx, cy - r / 2, cx, cy + r / 2),
    ..._line(cx + r / 2, cy - r / 2, cx + r / 2, cy + r / 2),
  ],

  // The power mark: a ring broken by a bar through its top. The bar runs
  // from above the ring to its centre so the break reads at 8 pt, where
  // a true IEC gap in the stroke would close up.
  DeviceGlyph.power => <PathCommand>[
    ..._circle(cx, cy + r / 6, r * 5 / 6),
    ..._line(cx, cy - r, cx, cy),
  ],

  // A cell: a body, a terminal nub on the right, and one divider. The
  // nub is what says "battery" rather than "box", so it is drawn even
  // though it is the smallest feature here.
  DeviceGlyph.battery => <PathCommand>[
    ..._rect(cx - r, cy - r / 2, cx + r * 2 / 3, cy + r / 2),
    ..._rect(cx + r * 2 / 3, cy - r / 4, cx + r, cy + r / 4),
    ..._line(cx, cy - r / 2, cx, cy + r / 2),
  ],

  // A filled face. The one mark with no interior detail, and the only
  // one that is legible purely as a mass.
  DeviceGlyph.blank => _rect(cx - r, cy - r / 2, cx + r, cy + r / 2),

  // A ledge: a deck with two legs turning down. Read as a bracket seen
  // from the front, which is what a rack shelf is.
  DeviceGlyph.shelf => <PathCommand>[
    ..._line(cx - r, cy - r / 3, cx + r, cy - r / 3),
    ..._line(cx - r, cy - r / 3, cx - r, cy + r / 2),
    ..._line(cx + r, cy - r / 3, cx + r, cy + r / 2),
  ],

  // A rectangle on a stand: screen, stem, base. The stem is what stops
  // it reading as `processor`'s outer box.
  DeviceGlyph.display => <PathCommand>[
    ..._rect(cx - r, cy - r, cx + r, cy + r / 4),
    ..._line(cx, cy + r / 4, cx, cy + r * 2 / 3),
    ..._line(cx - r / 2, cy + r, cx + r / 2, cy + r),
  ],

  // A cone, opening right: the driver seen from the side. Six points
  // rather than a circle, because every round mark in this set is
  // already crowded (header note 1).
  DeviceGlyph.speaker => <PathCommand>[
    MoveTo(cx - r, cy - r / 2),
    LineTo(cx - r / 4, cy - r / 2),
    LineTo(cx + r, cy - r),
    LineTo(cx + r, cy + r),
    LineTo(cx - r / 4, cy + r / 2),
    LineTo(cx - r, cy + r / 2),
    const ClosePath(),
  ],

  // A lens: two concentric rings. The inner ring is half the outer, the
  // widest gap two circles can hold at this size.
  DeviceGlyph.camera => <PathCommand>[
    ..._circle(cx, cy, r),
    ..._circle(cx, cy, r / 2),
  ],

  // Radiating arcs over a mast. The arcs are half-circles opening
  // downward rather than the usual quarter-arcs, because a quarter arc
  // at 8 pt is three pixels of curve and reads as a dash.
  DeviceGlyph.antenna => <PathCommand>[
    ..._line(cx, cy + r, cx, cy),
    ..._arcOver(cx, cy, r / 2),
    ..._arcOver(cx, cy, r),
  ],

  // A knob on a plate: a box holding a ring. Distinguished from `camera`
  // by its square outline and from `processor` by its round interior,
  // which is the pair the header's first note asks a printed sheet
  // about.
  DeviceGlyph.control => <PathCommand>[
    ..._box(cx, cy, r),
    ..._circle(cx, cy, r / 2),
  ],
};

/// A square centred on `(cx, cy)` with half-side [r].
List<PathCommand> _box(double cx, double cy, double r) =>
    _rect(cx - r, cy - r, cx + r, cy + r);

/// An axis-aligned rectangle from `(l, t)` to `(rt, b)`.
List<PathCommand> _rect(double l, double t, double rt, double b) =>
    <PathCommand>[
      MoveTo(l, t),
      LineTo(rt, t),
      LineTo(rt, b),
      LineTo(l, b),
      const ClosePath(),
    ];

/// One straight segment as its own subpath.
List<PathCommand> _line(double x1, double y1, double x2, double y2) =>
    <PathCommand>[MoveTo(x1, y1), LineTo(x2, y2)];

/// The cubic Bézier constant for a quarter circle, `4/3 · tan(π/8)`.
///
/// Named rather than inlined because it appears four times per circle
/// and a reader who has not met it reads `0.5523` as a magic number.
const double _kappa = 0.5522847498307936;

/// A full circle as four cubics.
///
/// FOUR CUBICS RATHER THAN [OpCircle], for `family_glyph.dart`'s reason:
/// a mark that is sometimes a circle op and sometimes a path op would
/// make every downstream op-kind assertion depend on which mark a device
/// carries.
List<PathCommand> _circle(double cx, double cy, double r) {
  final k = r * _kappa;
  return <PathCommand>[
    MoveTo(cx, cy - r),
    CubicTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy),
    CubicTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r),
    CubicTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy),
    CubicTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r),
    const ClosePath(),
  ];
}

/// The upper half of a circle of radius [r] about `(cx, cy)`, drawn left
/// to right. Open, so it strokes as an arc rather than a lens.
List<PathCommand> _arcOver(double cx, double cy, double r) {
  final k = r * _kappa;
  return <PathCommand>[
    MoveTo(cx - r, cy),
    CubicTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r),
    CubicTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy),
  ];
}

/// The stroke width a mark is drawn at, at [sizePt].
///
/// A RATIO RATHER THAN A CONSTANT, so the mark keeps its weight when the
/// PDF exporter inflates rack text through `RackTypeScale` to clear the
/// 6.0 pt print floor. A fixed hairline would go spindly on the sheet
/// exactly where it has to survive a photocopy.
double deviceGlyphStrokeWidth(double sizePt) =>
    math.max(0.5, sizePt * kDeviceGlyphCapFactor * 0.12);
