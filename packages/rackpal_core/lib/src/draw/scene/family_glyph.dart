// CHANNEL 4a AS GEOMETRY — the domain glyph drawn as a shape rather than
// as a character.
//
// ═════════════════════════════════════════════════════════════════════
// WHY: THE GLYPH MEASURED SHORT AND DREW WIDE, AND THE NAME LANDED ON IT
// ═════════════════════════════════════════════════════════════════════
// `SignalStyle.familyToken` is `'▲ VID·HD20'`, and the pennant places the
// net name at `textLeft + tokenWidth + gap` where `tokenWidth` comes from
// the injected `TextMeasurer`. In the app that measurer is
// `PdfFontMeasurer` over **Jost**, which is a text face and carries none
// of these codepoints — so it returned a near-zero advance. On screen the
// same run went through a `TextPainter`, which FELL BACK to a system font
// and drew the glyph at full width. Measured short, drawn wide, name on
// top of the token. The field saw `NET-NEN006`.
//
// THE ERROR IS THE GLYPH'S REAL WIDTH — A CONSTANT — so no amount of
// padding closes it, which is why em-scaling the inset (`09d7538`) did
// not.
//
// ═════════════════════════════════════════════════════════════════════
// IT IS A CR-081 PARITY BREAK, AND CR-081 IS WHY IT WAS INVISIBLE
// ═════════════════════════════════════════════════════════════════════
// *"Both backends share this one measurer"* is true of the MEASURER and
// says nothing about the FONT FALLBACK behind it. The PDF backend embeds
// the same Jost subset it measures with, so export was self-consistent and
// only the screen lied — which is exactly the class of defect CR-081
// exists to prevent and the reason nothing caught it: every gate compared
// the two backends' ops, and the ops were identical. What differed was
// what a `TextPainter` did with one of them.
//
// ═════════════════════════════════════════════════════════════════════
// GEOMETRY IS THE FIX BECAUSE IT REMOVES THE FONT FROM THE QUESTION
// ═════════════════════════════════════════════════════════════════════
// A shape's width is COMPUTED, by [familyGlyphAdvance], from the type size
// alone. The measurer and the emitter read the same function, so they
// cannot disagree — and no backend can substitute a different face for a
// path. The tag half (`VID·HD20`) stays a measured text run: it is ASCII
// plus `·` (U+00B7, Latin-1), which every text face carries.
//
// ═════════════════════════════════════════════════════════════════════
// THE FALLBACK IS DEFINED, BECAUSE CHANNEL 4a MAY NOT SILENTLY VANISH
// ═════════════════════════════════════════════════════════════════════
// The glyph is REGISTRY DATA — `SignalDomainDef.glyph`, seeded by
// `buildSeedSignalDomains` and authorable by a user once M4 ships — so
// this mapping cannot be exhaustive over all future inputs. A glyph with
// no shape here falls back to THE EXISTING MEASURED TEXT RUN, which is
// correct whenever the font does carry the character and is what the layer
// did before this file existed. Drawing nothing would lose one of the
// three channels that survive a greyscale laser (docs/05 §6.1), which is
// the whole reason four channels exist.
//
// `family_glyph_test.dart` asserts that NO SEEDED DOMAIN reaches the
// fallback. That is the gate that would have caught the defect: before
// this file, every one of the eight did.
//
// ═════════════════════════════════════════════════════════════════════
// EVERY CODEPOINT THE REGISTRIES CARRY, NOT ONLY THE ONES DRAWN TODAY
// ═════════════════════════════════════════════════════════════════════
// Eight domains carry a `glyph` and a `glyphAlt`, and two of them carry a
// THIRD shape in docs/05 §6.2 (`● / ◐ / ○` and `⬢ / ⬡ / ⏚`). All of them
// are mapped here, and [FamilyGlyph.fill] carries the difference docs/05
// §5 states: **fill encodes tier**.
//
// THAT WAS ALREADY THIS FILE'S RULE AND IT PAID (DR-181). The header used
// to say mapping only the halves drawn TODAY "would make this file quietly
// wrong the moment that changes", and the moment arrived: `#82` gave every
// family its own glyph, so the alternates are drawn now. What the rule did
// NOT cover was the third shapes, and the gap was worse than an absence:
// `◐` had been mapped to the hollow circle, which is `○`'s drawing, so the
// day `audio.speaker_cv` took its own glyph a constant-voltage speaker run
// and a low-impedance one would have been the same picture. A near-enough
// mapping is how a channel goes quiet without anything reporting it.
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/spec.dart';

/// The glyph's drawn box, as a multiple of the type size.
///
/// A CAP HEIGHT, not an em. These shapes sit on a text line beside a tag
/// run at the same size, and a symbol drawn to the full em would tower
/// over the letters beside it. 0.72 is the ordinary cap-height ratio for a
/// geometric sans and is what makes `▲ VID` read as one token rather than
/// as a mark and a word.
const double kFamilyGlyphCapFactor = 0.72;

/// The space after the shape before the tag begins, as a multiple of the
/// type size — the geometric equivalent of the `' '` that
/// `SignalStyle.familyToken` puts between glyph and tag.
///
/// It is part of [familyGlyphAdvance] rather than added at the call site,
/// so the one function answers "how far does the tag start from here" and
/// there is no second place to forget it.
const double kFamilyGlyphBearingFactor = 0.22;

/// The shapes the seeded domains name, independent of which codepoint
/// spells them.
///
/// [ground] ARRIVED WITH DR-181 and is the odd one: every other value is a
/// closed outline that is filled or stroked, and this one is a STEM AND
/// THREE BARS, an open figure that can only be stroked. It is `pwr`'s
/// third glyph (`⏚`, U+23DA EARTH GROUND), which `power.bonding` takes,
/// and there is no hexagon variant that says "this conductor is the
/// bond": the trade draws an earth symbol and a reader looks for one.
enum FamilyGlyphShape {
  triangleUp,
  triangleDown,
  circle,
  diamond,
  square,
  cross,
  hexagon,
  star,
  ground,
}

/// docs/05 §5: **fill encodes tier**.
///
/// THREE VALUES SINCE DR-181, AND THE THIRD IS NOT A NICETY. `audio.analog`
/// and `pwr` each carry THREE glyphs (`● / ◐ / ○` and `⬢ / ⬡ / ⏚`), so a
/// boolean fill collapses two of the three into one drawing: `◐` was
/// mapped to the hollow circle, which is `○`'s shape, and the moment
/// `audio.speaker_cv` started drawing its own `○` the two would have been
/// the SAME PICTURE for a low-impedance speaker run and a constant-voltage
/// one. Those are the two lines on a job that must never be confused for
/// each other, which is the whole reason the glyph channel exists.
enum FamilyGlyphFill {
  /// The native tier: solid ink.
  filled,

  /// The middle tier: a half-disc, flat edge vertical. INK, like
  /// [filled], and never outlined; see [familyGlyphOp].
  half,

  /// The transported tier: outline only.
  hollow,
}

/// A resolved glyph: which shape, at which tier.
@immutable
final class FamilyGlyph {
  const FamilyGlyph(this.shape, {required this.fill});

  final FamilyGlyphShape shape;

  /// docs/05 §5: **fill encodes tier**.
  final FamilyGlyphFill fill;

  /// Whether this glyph is solid ink, which is the question every call
  /// site asked before [FamilyGlyphFill] had a third value.
  bool get filled => fill == FamilyGlyphFill.filled;

  @override
  bool operator ==(Object other) =>
      other is FamilyGlyph && other.shape == shape && other.fill == fill;

  @override
  int get hashCode => Object.hash(shape, fill);

  @override
  String toString() => 'FamilyGlyph($shape, fill: ${fill.name})';
}

/// Every codepoint the seeded registries emit: a domain's native and
/// alternate glyphs, and every family's own (DR-181).
///
/// READ VERBATIM OUT OF `seed_registries.dart` on 2026-08-02 and pinned by
/// `family_glyph_test.dart`, which walks `buildSeedSignalDomains()` rather
/// than a transcription — so seeding a ninth domain, or changing a glyph,
/// fails a test rather than silently landing in the fallback. DR-181 gave
/// the FAMILIES glyphs too, and that test walks `buildSeedSignalFamilies()`
/// for the same reason.
///
/// THE BOARD'S NOTE SAID "GEOMETRIC SHAPES"; FIVE OF EIGHT ARE. `▲ ▼ ● ◆ ■`
/// are U+25xx Geometric Shapes, `✚` is Dingbats, `⬢` is Miscellaneous
/// Symbols and Arrows, `★` is Miscellaneous Symbols. It does not change the
/// diagnosis — Jost carries none of the four blocks — but a note that
/// names the wrong block sends the next reader to the wrong place. `⏚` is a
/// sixth block, Miscellaneous Technical, and carries the same diagnosis.
const Map<String, FamilyGlyph> _shapes = <String, FamilyGlyph>{
  // video.digital
  '▲': FamilyGlyph(FamilyGlyphShape.triangleUp, fill: FamilyGlyphFill.filled),
  '△': FamilyGlyph(FamilyGlyphShape.triangleUp, fill: FamilyGlyphFill.hollow),
  // video.analog
  '▼': FamilyGlyph(FamilyGlyphShape.triangleDown, fill: FamilyGlyphFill.filled),
  '▽': FamilyGlyph(FamilyGlyphShape.triangleDown, fill: FamilyGlyphFill.hollow),
  // audio.analog — THREE TIERS AND THEY ARE THREE PICTURES (DR-181).
  // U+25D0 CIRCLE WITH LEFT HALF BLACK read as the hollow circle until
  // `#82`, which was harmless only while nothing drew `○`: the moment
  // `audio.speaker_cv` took its own glyph, a low-impedance speaker run and
  // a constant-voltage one would have been the same drawing. See
  // [FamilyGlyphFill].
  '●': FamilyGlyph(FamilyGlyphShape.circle, fill: FamilyGlyphFill.filled),
  '◐': FamilyGlyph(FamilyGlyphShape.circle, fill: FamilyGlyphFill.half),
  '○': FamilyGlyph(FamilyGlyphShape.circle, fill: FamilyGlyphFill.hollow),
  // audio.digital
  '◆': FamilyGlyph(FamilyGlyphShape.diamond, fill: FamilyGlyphFill.filled),
  '◇': FamilyGlyph(FamilyGlyphShape.diamond, fill: FamilyGlyphFill.hollow),
  // net
  '■': FamilyGlyph(FamilyGlyphShape.square, fill: FamilyGlyphFill.filled),
  '□': FamilyGlyph(FamilyGlyphShape.square, fill: FamilyGlyphFill.hollow),
  // ctl — U+2733 EIGHT SPOKED ASTERISK is not a hollow cross, but it is
  // the cross FAMILY at the transported tier, which is the distinction the
  // channel carries.
  '✚': FamilyGlyph(FamilyGlyphShape.cross, fill: FamilyGlyphFill.filled),
  '✳': FamilyGlyph(FamilyGlyphShape.cross, fill: FamilyGlyphFill.hollow),
  // pwr — the third is an EARTH SYMBOL and not a hexagon variant, because
  // that is what the trade draws for a bond and what a reader looks for.
  '⬢': FamilyGlyph(FamilyGlyphShape.hexagon, fill: FamilyGlyphFill.filled),
  '⬡': FamilyGlyph(FamilyGlyphShape.hexagon, fill: FamilyGlyphFill.hollow),
  '⏚': FamilyGlyph(FamilyGlyphShape.ground, fill: FamilyGlyphFill.hollow),
  // str
  '★': FamilyGlyph(FamilyGlyphShape.star, fill: FamilyGlyphFill.filled),
  '☆': FamilyGlyph(FamilyGlyphShape.star, fill: FamilyGlyphFill.hollow),
};

/// The shape [glyph] draws as, or `null` when nothing here matches — the
/// defined fallback to a measured text run. See the file header.
///
/// Empty is `null`, which is the unresolved-domain case
/// (`SignalStyle.glyph` is `''`) and already falls back to the tag alone.
FamilyGlyph? familyGlyphFor(String glyph) => _shapes[glyph];

/// How far the tag starts from the glyph's left edge, at [sizePt].
///
/// **THE ONE FIGURE BOTH SIDES READ.** The sizer adds it to the tag's
/// measured width to get the token width; the emitter adds it to the token's
/// left edge to place the tag. A second expression of this anywhere is how
/// the two come to disagree again — which is the whole defect.
double familyGlyphAdvance(double sizePt) =>
    sizePt * (kFamilyGlyphCapFactor + kFamilyGlyphBearingFactor);

/// ONE op drawing [glyph] at [sizePt], its box centred vertically on
/// [leftMid] and starting at its x.
///
/// ONE OP, WHATEVER THE SHAPE, so the label layer's cost is a flat +1 per
/// flag and `schematic_perf_test`'s per-flag identity stays a single
/// number. A circle is four cubics rather than an `OpCircle` for the same
/// reason: eight shapes that are eight different op KINDS would make every
/// downstream op-kind assertion depend on which domain a link is in.
///
/// STROKED AT A HAIRLINE WHEN HOLLOW, filled when native — docs/05 §5's
/// "fill encodes tier", and the reason [FamilyGlyph.fill] is carried this
/// far rather than resolved at the mapping.
///
/// THE HALF TIER IS INK, SO IT IS FILLED AND NOT STROKED. Its path is the
/// LEFT HALF-DISC alone, an arc closed by its own diameter, so what a
/// reader sees is a D: solid ink on the left, a straight edge down the
/// middle. **The right half's outline is not drawn**, and that is two
/// constraints rather than a reading of U+25D0. A true `◐` is a full
/// circle whose left half is inked, which needs one subpath filled and
/// another stroked; this op model paints a whole path or nothing, and one
/// op per flag is what `schematic_perf_test`'s per-flag identity is.
///
/// **AND A GLYPH MAY NEVER CARRY BOTH PAINTS.** `net_label_layer_test`'s
/// `_isGlyphPath` tells a glyph from a pennant by exactly that: a pennant
/// is the only path with a fill AND a stroke. A half-disc outlined for
/// crispness would have made every `audio.speaker_lowz` flag read as a
/// pennant to three scene tests, which would have counted the wrong paths
/// and still passed. A half-disc is unmistakable against `●` and `○` at
/// 8 pt without the outline, which is the distinction the channel carries.
///
/// [hollowScalesWithGeometry] is false for a plan mark's glyph, whose line
/// weight is constant on the surface (`#905`, DR-169 §11.168.11). A label
/// layer's glyph scales with its diagram, as it always has, and takes the
/// default.
DiagramOp familyGlyphOp(
  FamilyGlyph glyph,
  DPt leftMid,
  double sizePt,
  int argb, {
  required double hollowWidthPt,
  bool hollowScalesWithGeometry = true,
}) {
  final side = sizePt * kFamilyGlyphCapFactor;
  final r = side / 2;
  final cx = leftMid.x + r;
  final cy = leftMid.y;
  final path = DiagramPath(
    _commandsFor(glyph.shape, glyph.fill, cx: cx, cy: cy, r: r),
  );
  final stroke = Stroke(
    argb: argb,
    widthPt: hollowWidthPt,
    scaleWithGeometry: hollowScalesWithGeometry,
  );
  return switch (glyph.fill) {
    FamilyGlyphFill.filled || FamilyGlyphFill.half => OpPath(
      path,
      fill: Fill(argb),
    ),
    FamilyGlyphFill.hollow => OpPath(path, stroke: stroke),
  };
}

/// The shape in device coordinates, centred on `(cx, cy)` inside a box of
/// half-side [r]. **Y GROWS DOWNWARD** — the sheet's convention, so
/// "triangle up" puts its apex at the SMALLER y.
List<PathCommand> _commandsFor(
  FamilyGlyphShape shape,
  FamilyGlyphFill fill, {
  required double cx,
  required double cy,
  required double r,
}) => switch (shape) {
  FamilyGlyphShape.triangleUp => _polygon(cx: cx, cy: cy, [
    (cx, cy - r),
    (cx + r, cy + r),
    (cx - r, cy + r),
  ]),
  FamilyGlyphShape.triangleDown => _polygon(cx: cx, cy: cy, [
    (cx, cy + r),
    (cx - r, cy - r),
    (cx + r, cy - r),
  ]),
  FamilyGlyphShape.diamond => _polygon(cx: cx, cy: cy, [
    (cx, cy - r),
    (cx + r, cy),
    (cx, cy + r),
    (cx - r, cy),
  ]),
  FamilyGlyphShape.square => _polygon(cx: cx, cy: cy, [
    (cx - r, cy - r),
    (cx + r, cy - r),
    (cx + r, cy + r),
    (cx - r, cy + r),
  ]),
  // A GREEK CROSS: equal arms, thickness a third of the side, which is
  // what keeps it readable at 8 pt against the diamond it shares a
  // silhouette class with.
  FamilyGlyphShape.cross => _polygon(
    cx: cx,
    cy: cy,
    _crossPoints(cx, cy, r, r / 3),
  ),
  // POINTY-TOP, six vertices from -90°. Flat-top would read as a
  // squashed square at this size, and `pwr` is the domain a reader most
  // needs to pick out of a greyscale print.
  FamilyGlyphShape.hexagon => _polygon(
    cx: cx,
    cy: cy,
    _regular(cx, cy, r, 6, -math.pi / 2),
  ),
  // Five points, inner radius at the golden ratio the standard star uses.
  FamilyGlyphShape.star => _polygon(cx: cx, cy: cy, _starPoints(cx, cy, r)),
  // THE ONLY SHAPE WHOSE GEOMETRY DEPENDS ON ITS TIER. The other eight
  // draw one outline and the paint decides what happens to it; a half tier
  // is a DIFFERENT REGION, so the circle answers for its own fill.
  FamilyGlyphShape.circle =>
    fill == FamilyGlyphFill.half
        ? _leftHalfDisc(cx, cy, r)
        : _circle(cx, cy, r),
  // An open figure: a stem and three bars. It is never filled, so it needs
  // no re-centring on ink the way a polygon does; `_ground` centres itself.
  FamilyGlyphShape.ground => _ground(cx, cy, r),
};

/// A closed polygon through [pts], RE-CENTRED ON ITS OWN BOUNDING BOX.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A GLYPH IS CENTRED ON ITS INK, NOT ON THE CIRCLE IT WAS CONSTRUCTED FROM
/// ═══════════════════════════════════════════════════════════════════════
/// Five of the seven polygons here are symmetric about their construction
/// centre and this changes nothing for them. **The star is not**: its top
/// point reaches the full radius while its two bottom vertices stop at
/// `r·cos 36°`, so a star placed by its circumcircle centre sits visibly
/// high on the line beside the tag it belongs to — the one shape a reader
/// would notice, and `str` is on every structure run in the document.
///
/// Recentring is applied to all of them rather than to the star alone, so
/// a shape added later cannot inherit the defect by being constructed the
/// same obvious way.
List<PathCommand> _polygon(
  List<(double, double)> pts, {
  required double cx,
  required double cy,
}) {
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (final (x, y) in pts) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  // The shift that puts the INK's centre on `(cx, cy)`. Zero for every
  // symmetric shape.
  final dx = cx - (minX + maxX) / 2;
  final dy = cy - (minY + maxY) / 2;
  return <PathCommand>[
    for (var i = 0; i < pts.length; i++)
      if (i == 0)
        MoveTo(pts[i].$1 + dx, pts[i].$2 + dy)
      else
        LineTo(pts[i].$1 + dx, pts[i].$2 + dy),
    const ClosePath(),
  ];
}

List<(double, double)> _regular(
  double cx,
  double cy,
  double r,
  int n,
  double startRad,
) => <(double, double)>[
  for (var i = 0; i < n; i++)
    (
      cx + r * math.cos(startRad + i * 2 * math.pi / n),
      cy + r * math.sin(startRad + i * 2 * math.pi / n),
    ),
];

/// The classic five-pointed star: ten vertices alternating outer and
/// inner, the inner radius at `1/φ²` — the ratio a pentagram's self-
/// intersections actually produce, not an eyeballed fraction.
List<(double, double)> _starPoints(double cx, double cy, double r) {
  const inner = 0.381966011250105; // 1 / φ²
  return <(double, double)>[
    for (var i = 0; i < 10; i++)
      () {
        final radius = i.isEven ? r : r * inner;
        final a = -math.pi / 2 + i * math.pi / 5;
        return (cx + radius * math.cos(a), cy + radius * math.sin(a));
      }(),
  ];
}

List<(double, double)> _crossPoints(
  double cx,
  double cy,
  double r,
  double half,
) => <(double, double)>[
  (cx - half, cy - r),
  (cx + half, cy - r),
  (cx + half, cy - half),
  (cx + r, cy - half),
  (cx + r, cy + half),
  (cx + half, cy + half),
  (cx + half, cy + r),
  (cx - half, cy + r),
  (cx - half, cy + half),
  (cx - r, cy + half),
  (cx - r, cy - half),
  (cx - half, cy - half),
];

/// Four cubics, the standard [kappa] circle. `path.dart` supports no
/// elliptical arc and deliberately so (docs/08 §7.3), and this is the
/// construction its own `kappa` constant exists for.
List<PathCommand> _circle(double cx, double cy, double r) {
  final k = r * kappa;
  return <PathCommand>[
    MoveTo(cx, cy - r),
    CubicTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy),
    CubicTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r),
    CubicTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy),
    CubicTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r),
    const ClosePath(),
  ];
}

/// The LEFT half of that circle, closed by its own vertical diameter: two
/// of [_circle]'s four cubics, run top to bottom down the left side, and a
/// straight line back up the middle (DR-181).
///
/// CENTRED ON THE FULL CIRCLE, NOT ON THE HALF. `_polygon` re-centres a
/// shape on its own ink because a star's ink sits high in its
/// circumcircle, and applying that rule here would be wrong for the
/// opposite reason: this glyph's job is to read as a circle with half of
/// it inked, so it must sit exactly where `●` and `○` sit. Recentring it
/// would slide the flat edge off the line the other two share and make
/// `audio.analog`'s three tiers three different positions as well as three
/// different pictures.
List<PathCommand> _leftHalfDisc(double cx, double cy, double r) {
  final k = r * kappa;
  return <PathCommand>[
    MoveTo(cx, cy - r),
    CubicTo(cx - k, cy - r, cx - r, cy - k, cx - r, cy),
    CubicTo(cx - r, cy + k, cx - k, cy + r, cx, cy + r),
    LineTo(cx, cy - r),
    const ClosePath(),
  ];
}

/// The earth symbol: a stem down the middle to three bars of decreasing
/// width (U+23DA), which is what `power.bonding` draws (DR-181).
///
/// PROPORTIONS ARE THE SYMBOL'S OWN, not this file's taste: the bars are
/// the full width, two thirds and one third, evenly spaced across the
/// lower half, and the stem runs from the top of the box to the first bar.
/// It is drawn as FOUR SUBPATHS in one path, so it is still one op, and it
/// is stroked rather than filled because an open figure has no inside.
///
/// THE BOX IS THE SAME `2r` SQUARE every other shape uses, so the tag's
/// start does not move for `pwr`: [familyGlyphAdvance] is computed from
/// the type size alone and knows nothing about which shape follows it.
List<PathCommand> _ground(double cx, double cy, double r) {
  final gap = r / 2;
  return <PathCommand>[
    // The stem, from the top of the box to the widest bar.
    MoveTo(cx, cy - r),
    LineTo(cx, cy),
    // Three bars: full, two thirds, one third.
    MoveTo(cx - r, cy),
    LineTo(cx + r, cy),
    MoveTo(cx - r * 2 / 3, cy + gap),
    LineTo(cx + r * 2 / 3, cy + gap),
    MoveTo(cx - r / 3, cy + 2 * gap),
    LineTo(cx + r / 3, cy + 2 * gap),
  ];
}
