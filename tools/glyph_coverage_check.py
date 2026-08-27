"""Every non-ASCII character a Dart string literal can draw must exist in BOTH
bundled weights.

DR-090 §11.89.8. The defect this exists to prevent has already shipped twice.

`device_glyph_art.dart`'s header records the first: a signal glyph shipped as a
codepoint, `PdfFontMeasurer` returned a near-zero advance because Jost had no
such glyph, the screen's `TextPainter` fell back to a system face and drew it
full width, and `NET-NEN006` printed over a net name. The second is quieter and
was found by rendering a specimen in August 2026: Jost 3.710 has none of U+2192,
U+2194, U+2032 or U+2033, two live schedule cells emit the first onto printed
sheets T6.10 and T6.11, and an absent codepoint maps to `.notdef` which draws as
NOTHING rather than as a visible box.

Both failures share a shape worth naming: **both backends emitted identical ops
and only the font behind one of them differed**, so every op-level gate passed.
Nothing in the display list can see this. It has to be checked against the font
binary, which is what this does.

WHAT IT COVERS: non-ASCII characters appearing in Dart string literals under
`packages/*/lib` and `apps/*/lib`, checked against the intersection of the
bundled weights' cmaps. The intersection, not the union, because a caller
choosing `w500` gets Medium and must not lose a glyph by doing so.

WHAT IT DOES NOT COVER, stated because a gate whose blind spot is undocumented
gets trusted past its evidence:

  * strings composed at runtime from parts, or read from a document. A user who
    names a rack `Sala de máquinas` is outside this and always will be;
  * the catalog's JSON and the seeded registries, which are data rather than
    literals;
  * anything drawn by `rackpal_ui` widgets using a system font rather than the
    bundled family, which after DR-090 §11.89.8 should be nothing, but this
    gate cannot tell the difference.

It is therefore a floor, not a proof.
"""
import pathlib
import re
import sys

from fontTools.ttLib import TTFont

# The whole point of this gate is to name codepoints, and a Windows console
# defaults to cp1252, which cannot encode most of them. Without this the gate
# CRASHES on exactly the failure it exists to report.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / 'apps' / 'rackpal' / 'assets' / 'fonts'
WEIGHTS = ['Jost-Regular.ttf', 'Jost-Medium.ttf']

# Emitted by live code onto printed sheets. Listed explicitly so that if the
# literal scan below ever stops matching anything, this gate still fails rather
# than passing vacuously on an empty set.
REQUIRED = {0x2192: 'passthrough arrow, schedules T6.10/T6.11',
            0x2194: 'bidirectional',
            0x2032: 'feet', 0x2033: 'inches',
            0x2014: 'G4 unknown, the em dash', 0x00B7: 'separator',
            0x2211: 'the structure matrix sum header'}

# THE ONE EXEMPT SET, AND WHY IT IS SAFE TO HAVE ONE.
#
# These codepoints never reach a font. They are `SignalDomainDef.glyph` and
# `DeviceGlyph` REGISTRY DATA, and both are drawn as geometry by
# `family_glyph.dart` and `device_glyph_art.dart`, whose advance is COMPUTED
# from the type size so that measurer and emitter cannot disagree. That is the
# fix those files exist to be; requiring them in the font would be requiring a
# font for something deliberately taken out of the font's hands.
#
# This project's own practice is that a test's exemption list is where the bug
# lives, so the mitigation is that this list is CLOSED and reasoned, anything
# absent from it fails, and a codepoint that migrates from data into a widget
# label will fail the moment it appears in a `rackpal_ui` literal.
PATH_BACKED = {
    0x25A0, 0x25A1,          # net, native / transported
    0x25B3,                  # video.digital, transported
    0x25BC, 0x25BD,          # video.analog
    0x25C6, 0x25C7,          # audio.digital
    0x25CF, 0x25D0,          # audio.analog
    0x2605, 0x2606,          # str
    0x271A, 0x2733,          # ctl
    0x2B21, 0x2B22,          # pwr
}

# EMPTY, AND THE STORY OF HOW IT EMPTIED IS THE REASON IT STAYS HERE.
#
# It held U+03A3 GREEK CAPITAL SIGMA, the structure matrix's sum header,
# recorded as the one character this project would not add: a letterform has
# a design where a triangle has only a construction, so a sigma drawn into
# someone else's face is the one addition that could not be checked by
# measurement. The alternative was changing on-screen copy, which is not a
# build step's call. Both were true and both were the wrong question.
#
# THE HEADER WAS THE WRONG CHARACTER. Unicode separates the LETTER U+03A3
# from the N-ARY SUMMATION operator U+2211, a column that adds a row up wants
# the operator, and the two look alike in most faces, which is why the
# substitution survived. Jost carries U+2211 and not U+03A3, so the correct
# character is also the one that renders: no glyph drawn, no copy changed,
# no exemption needed.
#
# The set is kept rather than deleted because the next entry proposed for it
# should have to argue past this one: a missing glyph may be a missing
# character rather than a missing design.
UNDRAWN: set[int] = set()

# A scan that finds nothing must be a failure, not a pass. This floor is well
# under the count at the time of writing and exists only to catch the regex
# silently breaking.
MIN_LITERALS = 2000

_BLOCK = re.compile(r'/\*.*?\*/', re.S)
_LINE = re.compile(r'^\s*//.*$', re.M)
_TRAILING = re.compile(r'(?<![:/])//(?![/*]).*$', re.M)
_LITERAL = re.compile(
    r"'''(?:[^\\]|\\.)*?'''"
    r'|"""(?:[^\\]|\\.)*?"""'
    r"|'(?:[^'\\\n]|\\.)*'"
    r'|"(?:[^"\\\n]|\\.)*"', re.S)


def strip_comments(src):
    src = _BLOCK.sub('', src)
    src = _LINE.sub('', src)
    return _TRAILING.sub('', src)


def main():
    covered = None
    for name in WEIGHTS:
        path = FONTS / name
        if not path.exists():
            print(f'FAIL: {name} is not bundled')
            return 1
        cmap = set(TTFont(path).getBestCmap())
        covered = cmap if covered is None else (covered & cmap)

    failures = []
    for cp, why in sorted(REQUIRED.items()):
        if cp not in covered:
            failures.append(f'  U+{cp:04X} ({why}) is missing from a bundled '
                            'weight')

    literals = 0
    found = {}
    roots = list((ROOT / 'packages').glob('*/lib')) + \
        list((ROOT / 'apps').glob('*/lib'))
    for base in roots:
        for f in base.rglob('*.dart'):
            src = strip_comments(f.read_text(encoding='utf-8'))
            for m in _LITERAL.finditer(src):
                literals += 1
                for ch in m.group(0):
                    if ord(ch) > 127:
                        found.setdefault(ord(ch), set()).add(
                            str(f.relative_to(ROOT)))

    if literals < MIN_LITERALS:
        failures.append(f'  only {literals} string literals scanned, under the '
                        f'floor of {MIN_LITERALS}: the scan is broken, not the '
                        'sources')

    for cp in sorted(found):
        if cp not in covered and cp not in PATH_BACKED | UNDRAWN:
            where = sorted(found[cp])[:3]
            failures.append(f'  U+{cp:04X} {chr(cp)!r} is drawn but not in both '
                            f'weights: {", ".join(where)}')

    exempt = len(found.keys() & PATH_BACKED)
    print(f'glyph coverage: {literals} literals, {len(found)} distinct '
          f'non-ASCII codepoints, {len(covered)} in both weights, '
          f'{exempt} path-backed, {len(found.keys() & UNDRAWN)} on fallback')
    if failures:
        print('FAIL')
        print('\n'.join(failures))
        return 1
    print('ok')
    return 0


if __name__ == '__main__':
    sys.exit(main())
