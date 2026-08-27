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
// SIXTEEN CODEPOINTS, NOT EIGHT
// ═════════════════════════════════════════════════════════════════════
// Eight domains carry a `glyph`/`glyphAlt` pair and `signal_style.dart`
// draws only the native `glyph` — see its header on why no model field
// selects the tier. The alternates are still registry data a document can
// present, and mapping only the halves that are drawn TODAY would make
// this file quietly wrong the moment that changes. So both are mapped, and
// [FamilyGlyph.filled] carries the difference docs/05 §5 states: **fill
// encodes tier**.
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

/// The eight shapes the seeded domains name, independent of which
/// codepoint spells them.
enum FamilyGlyphShape {
  triangleUp,
  triangleDown,
  circle,
  diamond,
  square,
  cross,
  hexagon,
  star,
}

/// A resolved glyph: which shape, and whether it is the filled (native) or
/// hollow (transported) variant.
@immutable
final class FamilyGlyph {
  const FamilyGlyph(this.shape, {required this.filled});

  final FamilyGlyphShape shape;

  /// docs/05 §5: **fill encodes tier**. Filled is native, hollow is
  /// transported.
  final bool filled;

  @override
  bool operator ==(Object other) =>
      other is FamilyGlyph && other.shape == shape && other.filled == filled;

  @override
  int get hashCode => Object.hash(shape, filled);

  @override
  String toString() => 'FamilyGlyph($shape, filled: $filled)';
}

/// Every codepoint the seeded domains emit, native and alternate.
///
/// READ VERBATIM OUT OF `seed_registries.dart` on 2026-08-02 and pinned by
/// `family_glyph_test.dart`, which walks `buildSeedSignalDomains()` rather
/// than a transcription — so seeding a ninth domain, or changing a glyph,
/// fails a test rather than silently landing in the fallback.
///
/// THE BOARD'S NOTE SAID "GEOMETRIC SHAPES"; FIVE OF EIGHT ARE. `▲ ▼ ● ◆ ■`
/// are U+25xx Geometric Shapes, `✚` is Dingbats, `⬢` is Miscellaneous
/// Symbols and Arrows, `★` is Miscellaneous Symbols. It does not change the
/// diagnosis — Jost carries none of the four blocks — but a note that
/// names the wrong block sends the next reader to the wrong place.
const Map<String, FamilyGlyph> _shapes = <String, FamilyGlyph>{
  // video.digital
  '▲': FamilyGlyph(FamilyGlyphShape.triangleUp, filled: true),
  '△': FamilyGlyph(FamilyGlyphShape.triangleUp, filled: false),
  // video.analog
  '▼': FamilyGlyph(FamilyGlyphShape.triangleDown, filled: true),
  '▽': FamilyGlyph(FamilyGlyphShape.triangleDown, filled: false),
  // audio.analog — the alternate is U+25D0 CIRCLE WITH LEFT HALF BLACK,
  // a HALF-filled disc that this renderer has no third state for. Mapped
  // to the hollow circle, which is the closest honest reading of "not the
  // native tier"; see `signal_style.dart`'s header on the three-shape
  // domains that the model cannot express at all.
  '●': FamilyGlyph(FamilyGlyphShape.circle, filled: true),
  '◐': FamilyGlyph(FamilyGlyphShape.circle, filled: false),
  // audio.digital
  '◆': FamilyGlyph(FamilyGlyphShape.diamond, filled: true),
  '◇': FamilyGlyph(FamilyGlyphShape.diamond, filled: false),
  // net
  '■': FamilyGlyph(FamilyGlyphShape.square, filled: true),
  '□': FamilyGlyph(FamilyGlyphShape.square, filled: false),
  // ctl — U+2733 EIGHT SPOKED ASTERISK is not a hollow cross, but it is
  // the cross FAMILY at the transported tier, which is the distinction the
  // channel carries.
  '✚': FamilyGlyph(FamilyGlyphShape.cross, filled: true),
  '✳': FamilyGlyph(FamilyGlyphShape.cross, filled: false),
  // pwr
  '⬢': FamilyGlyph(FamilyGlyphShape.hexagon, filled: true),
  '⬡': FamilyGlyph(FamilyGlyphShape.hexagon, filled: false),
  // str
  '★': FamilyGlyph(FamilyGlyphShape.star, filled: true),
  '☆': FamilyGlyph(FamilyGlyphShape.star, filled: false),
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
/// "fill encodes tier", and the reason [FamilyGlyph.filled] is carried
/// this far rather than resolved at the mapping.
DiagramOp familyGlyphOp(
  FamilyGlyph glyph,
  DPt leftMid,
  double sizePt,
  int argb, {
  required double hollowWidthPt,
}) {
  final side = sizePt * kFamilyGlyphCapFactor;
  final r = side / 2;
  final cx = leftMid.x + r;
  final cy = leftMid.y;
  final path = DiagramPath(
    _commandsFor(glyph.shape, cx: cx, cy: cy, r: r),
  );
  return OpPath(
    path,
    fill: glyph.filled ? Fill(argb) : null,
    stroke: glyph.filled ? null : Stroke(argb: argb, widthPt: hollowWidthPt),
  );
}

/// The shape in device coordinates, centred on `(cx, cy)` inside a box of
/// half-side [r]. **Y GROWS DOWNWARD** — the sheet's convention, so
/// "triangle up" puts its apex at the SMALLER y.
List<PathCommand> _commandsFor(
  FamilyGlyphShape shape, {
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
  FamilyGlyphShape.circle => _circle(cx, cy, r),
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
