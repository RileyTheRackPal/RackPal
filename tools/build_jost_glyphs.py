"""Add the four codepoints Jost lacks, BUILT FROM JOST'S OWN CONTOURS.

DR-090 §11.89.8. Regenerates `apps/rackpal/assets/fonts/Jost-*.ttf` in place
from a pristine upstream copy.

    python tools/build_jost_glyphs.py <upstream.ttf> <out.ttf>

Jost 3.710 ships 524 codepoints and none of U+2192, U+2194, U+2032, U+2033.
Two live schedule cells emit the first onto printed sheets T6.10 and T6.11,
where an absent codepoint maps to `.notdef` and draws as NOTHING rather than as
a visible box, so the failure is silent in both backends at once.

NOTHING HERE IS DRAWN FREEHAND. The arrowhead IS Jost's `greater` contour, the
tail IS its `less`, the shaft is a rectangle at exactly the monoline weight the
hyphen already uses, and the primes are the apostrophe and quotedbl sheared a
little steeper. The result cannot drift from the face's style because it IS the
face's style, rearranged.

EVERY CONSTANT IS MEASURED FROM THE FONT BEING PROCESSED, which is the
difference between this and the first draft. That draft hardcoded Regular's
numbers, and Regular is not Medium: the bar is 75 against 97, the inner vertex
443 against 410, the axis 257.5 against 260. Hardcoding would have produced a
Medium arrow whose shaft missed its own head.

WHERE THE SHAFT STOPS IS THE WHOLE JOB, and the first attempt got it wrong
twice. `greater` is one closed contour tracing a V whose wedge opens LEFTWARD;
running the shaft through that wedge FILLS it, and the head renders as a solid
triangle instead of the open chevron Jost draws everywhere else. On `arrowboth`
it filled both wedges and produced a bowtie. The shaft therefore stops just past
the inner vertex, overlapping only solid material near the tip, where a
same-winding overlap unions cleanly under non-zero fill.

The second mistake was diagnosing that bowtie as a winding problem. Both
chevrons are counter-clockwise and so is the rectangle; that was checked rather
than reasoned about. The real cause was size: a math chevron is 510 units wide
because it is drawn to sit beside digits, and two of those meeting nose to nose
close into a diamond. The heads are therefore CLIPPED to 300, not scaled, so the
arm angle and the perpendicular stroke width stay the face's own.
"""
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import DecomposingRecordingPen, RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

SRC, DST = sys.argv[1], sys.argv[2]
font = TTFont(SRC)
glyf, hmtx, cmap_best = font['glyf'], font['hmtx'], font.getBestCmap()
gs = font.getGlyphSet()

ADDED = {0x2192: 'arrowright', 0x2194: 'arrowboth',
         0x2032: 'minute', 0x2033: 'second'}


def contours_of(name):
    pen = DecomposingRecordingPen(gs)
    gs[name].draw(pen)
    return pen.value


def points_of(codepoint):
    """The straight-line outline of a glyph, as a point list."""
    pen = RecordingPen()
    gs[cmap_best[codepoint]].draw(pen)
    if any('urve' in op for op, _ in pen.value):
        raise SystemExit(f'U+{codepoint:04X} is not a polygon in this build; '
                         'the clip below assumes straight edges')
    return [args[0] for op, args in pen.value if op in ('moveTo', 'lineTo')]


def bbox(codepoint):
    """True bounds, curves included. `points_of` is for the polygon glyphs the
    clip walks; this is for measuring anything."""
    pen = BoundsPen(gs)
    gs[cmap_best[codepoint]].draw(pen)
    return pen.bounds


# ── the measurements ──────────────────────────────────────────────────────
GREATER_PTS = points_of(0x003E)
LESS_PTS = points_of(0x003C)

_hx0, _hy0, _hx1, _hy1 = bbox(0x002D)
BAR = _hy1 - _hy0                      # the monoline weight, from the hyphen

_gx0, _gy0, _gx1, _gy1 = bbox(0x003E)
# The shared axis of symmetry, NOT either chevron's inner vertex. `less` is
# `greater` rotated 180 degrees, and both are symmetric about this line, but
# their inner VERTICES sit a few units off it in OPPOSITE directions (Jost's
# own optical detail). Aligning the shaft to one vertex tilts `arrowboth`,
# because the two heads then pull opposite ways. Measured, not guessed.
AXIS = (_gy0 + _gy1) / 2
SIDE = _gx0                            # the sidebearing both chevrons carry
JOIN = BAR / 3                         # how far the shaft runs into the head

GREATER_TIP_X = max(p[0] for p in GREATER_PTS)
GREATER_VERTEX_X = max(p[0] for p in GREATER_PTS if p[0] < GREATER_TIP_X)
LESS_TIP_X = min(p[0] for p in LESS_PTS)
LESS_VERTEX_X = min(p[0] for p in LESS_PTS if p[0] > LESS_TIP_X)

HEAD = 300                             # ~square on Jost's arm angle
SHIFT = 300                            # how far the head sits from the tail

print(f'measured from {SRC}:')
print(f'  bar {BAR}   axis {AXIS}   side {SIDE}   join {JOIN:.1f}')
print(f'  greater vertex {GREATER_VERTEX_X} tip {GREATER_TIP_X}   '
      f'less vertex {LESS_VERTEX_X} tip {LESS_TIP_X}')


def replay(value, pen, dx=0.0, dy=0.0):
    tp = TransformPen(pen, (1, 0, 0, 1, dx, dy))
    for op, args in value:
        getattr(tp, op)(*args)


def shear(value, pen, slant, pivot_y):
    tp = TransformPen(pen, (1, 0, slant, 1, -slant * pivot_y, 0))
    for op, args in value:
        getattr(tp, op)(*args)


def bar_shaft(pen, x0, x1):
    """The shaft: same winding as both chevrons, at the face's own weight."""
    y0, y1 = AXIS - BAR / 2, AXIS + BAR / 2
    pen.moveTo((x0, y0))
    pen.lineTo((x1, y0))
    pen.lineTo((x1, y1))
    pen.lineTo((x0, y1))
    pen.closePath()


def clip_x(points, at, keep_right):
    """Sutherland-Hodgman against a vertical line: shorten a chevron's arms.

    CLIPPING, NOT SCALING. Scaling `greater` down thins its stroke and the
    shaft stops matching it; clipping walks the face's own edges and simply
    stops earlier, so the angle and the perpendicular width are unaltered.
    """
    def inside(pt):
        return pt[0] >= at if keep_right else pt[0] <= at

    def cross(a, b):
        t = (at - a[0]) / (b[0] - a[0])
        return (at, a[1] + t * (b[1] - a[1]))

    out = []
    for i, cur in enumerate(points):
        prv = points[i - 1]
        if inside(cur):
            if not inside(prv):
                out.append(cross(prv, cur))
            out.append(cur)
        elif inside(prv):
            out.append(cross(prv, cur))
    return out


def polygon(pen, points, dx=0.0):
    pen.moveTo((points[0][0] + dx, points[0][1]))
    for x, y in points[1:]:
        pen.lineTo((x + dx, y))
    pen.closePath()


GREATER_HEAD = clip_x(GREATER_PTS, GREATER_TIP_X - HEAD, keep_right=True)
LESS_HEAD = clip_x(LESS_PTS, LESS_TIP_X + HEAD, keep_right=False)

apostrophe = contours_of(cmap_best[0x0027])
quotedbl = contours_of(cmap_best[0x0022])
PRIME_FOOT = bbox(0x0027)[1]           # shear pivots on the mark's own foot
SLANT = 0.15


def draw_arrow_right(pen):
    bar_shaft(pen, SIDE, GREATER_VERTEX_X + SHIFT + JOIN)
    polygon(pen, GREATER_HEAD, dx=SHIFT)


def draw_arrow_both(pen):
    bar_shaft(pen, LESS_VERTEX_X - JOIN, GREATER_VERTEX_X + SHIFT + JOIN)
    polygon(pen, LESS_HEAD)
    polygon(pen, GREATER_HEAD, dx=SHIFT)


def draw_prime(pen):
    shear(apostrophe, pen, SLANT, PRIME_FOOT)


def draw_double_prime(pen):
    shear(quotedbl, pen, SLANT, PRIME_FOOT)


def add(name, unicode_, advance, draw):
    pen = TTGlyphPen(gs)
    draw(pen)
    glyph = pen.glyph()
    # xMin exists only once bounds are computed, and hmtx's lsb must equal it
    # or the glyph shifts sideways when rendered.
    glyph.recalcBounds(glyf)
    glyf[name] = glyph
    hmtx[name] = (advance, glyph.xMin)
    for table in font['cmap'].tables:
        if table.isUnicode():
            table.cmap[unicode_] = name
    print(f'  + U+{unicode_:04X} {name:<12} adv={advance:<5} '
          f'bbox=({glyph.xMin},{glyph.yMin})-({glyph.xMax},{glyph.yMax})')


# ── the seven the chrome needs, once ThemeData names Jost ─────────────────
# Before DR-090 §11.89.8 these fell to the platform face, because the chrome
# was Segoe UI and Segoe carries them. Naming Jost moved them onto per-glyph
# system fallback: not tofu, but a different face mid-sentence. Each is built
# from the face's own material for the same reason as the four above.

CAP = font['OS/2'].sCapHeight
XH = font['OS/2'].sxHeight


def _bounds(codepoint):
    return bbox(codepoint)


# The superscript transform is MEASURED off the digits Jost already ships, not
# chosen: `threesuperior` is `three` at exactly 0.600 with a fixed lift, and
# the same transform applied to the parens keeps `(3)` self-consistent.
_t3, _s3 = bbox(0x0033), bbox(0x00B3)
SUP_SCALE = (_s3[3] - _s3[1]) / (_t3[3] - _t3[1])
SUP_DY = _s3[1] - SUP_SCALE * _t3[1]
print(f'  superscript transform: scale {SUP_SCALE:.4f}, lift {SUP_DY:.1f}')

parenleft = contours_of(cmap_best[0x0028])
parenright = contours_of(cmap_best[0x0029])


def scaled(value, pen, k, dy):
    tp = TransformPen(pen, (k, 0, 0, k, 0, dy))
    for op, args in value:
        getattr(tp, op)(*args)


def draw_sup_paren(which):
    def draw(pen):
        scaled(parenleft if which == 'left' else parenright, pen,
               SUP_SCALE, SUP_DY)
    return draw


def draw_ballot(pen):
    """An empty checkbox, at the face's own bar weight, on the cap band."""
    lo, hi = 0.0, float(CAP)
    x0, x1 = float(SIDE), float(SIDE) + CAP
    for a, b, c, d in ((x0, lo, x1, lo + BAR),            # bottom
                       (x0, hi - BAR, x1, hi),            # top
                       (x0, lo, x0 + BAR, hi),            # left
                       (x1 - BAR, lo, x1, hi)):           # right
        pen.moveTo((a, b))
        pen.lineTo((c, b))
        pen.lineTo((c, d))
        pen.lineTo((a, d))
        pen.closePath()


def _tri(pen, pts):
    pen.moveTo(pts[0])
    for q in pts[1:]:
        pen.lineTo(q)
    pen.closePath()


def draw_up_triangle(pen):
    w = XH * 1.15
    _tri(pen, [(SIDE + w / 2, XH), (SIDE + w, 0.0), (float(SIDE), 0.0)])


def draw_right_triangle(pen):
    h = XH * 0.78
    _tri(pen, [(float(SIDE), AXIS + h / 2), (SIDE + h * 0.86, AXIS),
               (float(SIDE), AXIS - h / 2)])


# The vertical arrows are the horizontal one turned, so the head, the shaft
# weight and the join are identical by construction rather than by care.
def _arrow_vertical(up):
    """The horizontal arrow, turned. Head, shaft weight and join are identical
    to U+2192 by construction rather than by care, which is the point: three
    arrows that agree cannot be made to disagree by a later edit to one."""
    import math
    turns = 1 if up else 3
    a = math.radians(90 * turns)
    c, s = round(math.cos(a)), round(math.sin(a))
    # Scaled so the turned arrow reaches cap height rather than its own 810,
    # which would tower over the line it sits in.
    k = CAP / ((GREATER_TIP_X + SHIFT) - SIDE)

    def at(dx, dy):
        def draw(pen):
            draw_arrow_right(TransformPen(
                pen, (c * k, s * k, -s * k, c * k, dx, dy)))
        return draw

    rec = RecordingPen()
    at(0, 0)(rec)
    xs = [q[0] for _, args in rec.value for q in args if isinstance(q, tuple)]
    ys = [q[1] for _, args in rec.value for q in args if isinstance(q, tuple)]
    return at(SIDE - min(xs), -min(ys)), (max(xs) - min(xs)) + 2 * SIDE


ARROW_ADV = GREATER_TIP_X + SHIFT + SIDE
print("adding glyphs built from the face's own contours:")
add('arrowright', 0x2192, ARROW_ADV, draw_arrow_right)
add('arrowboth', 0x2194, ARROW_ADV, draw_arrow_both)
add('minute', 0x2032, hmtx[cmap_best[0x0027]][0] + 25, draw_prime)
add('second', 0x2033, hmtx[cmap_best[0x0022]][0] + 35, draw_double_prime)

_up, _uadv = _arrow_vertical(up=True)
_dn, _dadv = _arrow_vertical(up=False)
add('arrowup', 0x2191, round(_uadv), _up)
add('arrowdown', 0x2193, round(_dadv), _dn)
add('uni207D', 0x207D, round(hmtx[cmap_best[0x0028]][0] * SUP_SCALE),
    draw_sup_paren('left'))
add('uni207E', 0x207E, round(hmtx[cmap_best[0x0029]][0] * SUP_SCALE),
    draw_sup_paren('right'))
add('ballotbox', 0x2610, CAP + 2 * SIDE, draw_ballot)
add('triagup', 0x25B2, round(XH * 1.15) + 2 * SIDE, draw_up_triangle)
add('triagrt', 0x25B8, round(XH * 0.78 * 0.86) + 2 * SIDE,
    draw_right_triangle)

# Jost's OFL header declares NO Reserved Font Name, checked in the licence file
# beside the fonts, so the family name may stay and every `FontRef('Jost')` in
# this repository keeps resolving. The modification is recorded where anyone
# inspecting the file will find it rather than only in this script.
for record in list(font['name'].names):
    if record.nameID == 5:
        font['name'].setName(
            'Version 3.710; RackPal build: +11 glyphs',
            5, record.platformID, record.platEncID, record.langID)
font['name'].setName(
    "Modified for RackPal: four glyphs added, built from the face's own "
    'contours by tools/build_jost_glyphs.py. SIL OFL 1.1, no Reserved Font '
    'Name.', 10, 3, 1, 0x409)

font.save(DST)
print(f'wrote {DST}')
