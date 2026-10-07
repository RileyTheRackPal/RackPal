#!/usr/bin/env python3
"""PAL-1 conformance check for the RackPal signal palette.

Reference implementation of the pairwise greyscale-legibility test that
docs/catalog/seed-devices.md section 4.2 requires. It is written in Python so it can run
before any Dart exists; it must be ported to `pal1_conformance_test.dart` in
`rackpal_core` at M0 and kept as the authority thereafter.

WHY THIS FILE EXISTS. PAL-1 was asserted "verified clear" three times against a palette
that in fact contained fourteen collisions, including S/PDIF against RS-232 and the two
IR families -- three of the ten cable types the brief names by hand. Each assertion was
made by reading a table of eight domain rows rather than enumerating the 385 in-band
family pairs actually drawn. A rule that is checked by inspection is not checked.

    python tools/pal1_check.py          # exits 0 clean, 1 on any violation

PAL-1 (rendered-value form). Every shipped SignalFamilyDef renders as the triple
(L, dashClass, weight), where L is the WCAG relative luminance of its EFFECTIVE hue,
dashClass is the class of its EFFECTIVE dash pattern, and weight is its EFFECTIVE line
weight -- effective meaning after any per-family override, not the domain base value.
For every pair of families in DIFFERENT domains with |L1 - L2| < 0.10, at least one must
hold: (a) their dash classes differ, or (b) their weights differ by a factor >= 1.4.
Families within one domain are exempt from (a)/(b) -- they share a hue by construction and
the legend prints them adjacently -- but must still differ in dash, weight, or glyph.

The within-domain limb is a domain-equality check, never an allowlist of waived pairs.
An allowlist is how a real collision gets waived.
"""
import itertools
import pathlib
import re
import sys

#: Repo root, for the one source file this gate parses.
ROOT = pathlib.Path(__file__).resolve().parent.parent

# --------------------------------------------------------------------------- colour

def luminance(hex_str):
    """WCAG 2.x relative luminance of an sRGB hex colour."""
    h = hex_str.lstrip('#')
    channels = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    def linearise(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (linearise(c) for c in channels)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

# --------------------------------------------------------------------------- dash

def mark_class(pt):
    """A single mark is a dot, a short or a long."""
    if pt < 2.5:
        return 'dot'
    if pt < 9.0:
        return 'short'
    return 'long'

def dash_class(pattern):
    """Class of a dash pattern: the sequence of its mark classes, up to rotation.

    Marks are the even indices; odd indices are gaps and carry no class. Rotation
    equivalence matters because `1.5,3,4,3` and `4,3,1.5,3` render as the same rhythm.
    """
    if pattern == 'solid':
        return ('solid',)
    nums = [float(x) for x in pattern.split(',')]
    marks = tuple(mark_class(m) for m in nums[0::2])
    return min(tuple(marks[i:] + marks[:i]) for i in range(len(marks)))

def dash_period(pattern):
    """Total period in points. Must be >= 4.5 pt or the dash blurs to solid at 300 dpi."""
    if pattern == 'solid':
        return None
    return sum(float(x) for x in pattern.split(','))

# --------------------------------------------------------------------------- registry

#: Domain light-theme hues. Okabe-Ito, chosen for colour-vision-deficiency safety.
#: Hue is never a channel on its own -- it dies in greyscale, which is what PAL-1 guards.
DOMAIN_HUE = {
    'video.digital': '#0072B2',
    'video.analog':  '#56B4E9',
    'audio.analog':  '#E69F00',
    'audio.digital': '#D55E00',
    'net':           '#009E73',
    'ctl':           '#CC79A7',
    'pwr':           '#000000',
    'str':           '#999999',
}

#: (id, domain, effective dash pattern, effective weight multiplier)
#: Must match docs/catalog/seed-devices.md sections 4.3 and 4.4 exactly.
FAMILIES = [
    ('video.hdmi.1_4',        'video.digital', 'solid',                0.75),
    ('video.hdmi.2_0',        'video.digital', 'solid',                1.00),
    ('video.hdmi.2_1',        'video.digital', 'solid',                1.25),
    ('video.displayport',     'video.digital', '18,4',                 1.00),
    ('video.sdi',             'video.digital', '10,3',                 1.00),
    ('video.hdbaset',         'video.digital', '14,4',                 1.25),
    ('video.usbc_dpalt',      'video.digital', '6,2',                  1.00),
    ('video.avoip',           'video.digital', '14,4,2,4',             1.00),

    ('video.composite',       'video.analog',  '1.5,3',                1.00),
    ('video.component',       'video.analog',  '12,4,3,4',             1.00),
    ('video.vga',             'video.analog',  '12,4,3,4,3,4',         1.00),
    ('video.svideo',          'video.analog',  '9,4',                  1.00),
    ('rf.catv',               'video.analog',  '12,4',                 1.50),
    ('rf.satellite',          'video.analog',  '12,4,3,4',             1.50),
    ('rf.ota',                'video.analog',  '16,4',                 1.00),
    ('rf.modulated',          'video.analog',  '12,4',                 1.00),

    ('audio.line_unbal',      'audio.analog',  '6,3',                  1.00),
    ('audio.line_bal',        'audio.analog',  'solid',                1.00),
    ('audio.mic',             'audio.analog',  '4,3',                  1.00),
    ('audio.phono',           'audio.analog',  '4,3,1.5,3',            1.00),
    ('audio.speaker_lowz',    'audio.analog',  '6,3',                  2.00),
    ('audio.speaker_cv',      'audio.analog',  '10,3,2,3',             2.00),
    ('audio.sub',             'audio.analog',  '8,3',                  1.25),
    ('audio.headphone',       'audio.analog',  '3,3',                  0.75),

    ('audio.spdif_coax',      'audio.digital', '12,4,3,4',             1.00),
    ('audio.spdif_optical',   'audio.digital', '2,3',                  1.25),
    ('audio.aes3',            'audio.digital', '12,4,10,4',            1.00),
    ('audio.aes3id',          'audio.digital', '10,3,1,3,1,3',         1.00),
    ('audio.dante',           'audio.digital', '6,3,1,3',              1.50),
    ('audio.aes67',           'audio.digital', '6,3,1,3,1,3',          1.50),
    ('audio.avb',             'audio.digital', '8,3,1,3',              1.50),

    ('net.ethernet',          'net',           'solid',                1.50),
    ('net.poe',               'net',           'solid',                2.00),
    ('net.poh',               'net',           '14,4',                 2.00),
    ('net.fiber_mm',          'net',           '16,4',                 1.50),
    ('net.fiber_sm',          'net',           '16,4,3,4',             1.50),
    ('net.dac',               'net',           '8,3',                  1.50),

    ('ctl.ir_emitter',        'ctl',           '1.5,3',                0.75),
    ('ctl.ir_receiver',       'ctl',           '4,3,1.5,3',            0.75),
    ('ctl.ir_direct',         'ctl',           '1.5,9',                0.75),
    ('ctl.rs232',             'ctl',           '6,3,1.5,3',            0.75),
    ('ctl.rs485',             'ctl',           '6,3',                  1.00),
    ('ctl.dmx512',            'ctl',           '8,3,1.5,3',            1.00),
    ('ctl.contact',           'ctl',           '1.5,3,4,3',            0.75),
    ('ctl.trigger12v',        'ctl',           '4,3',                  0.75),
    ('ctl.cresnet',           'ctl',           '10,3,1.5,3',           1.00),
    ('ctl.lutron_qs',         'ctl',           '10,3',                 1.00),
    ('ctl.dali',              'ctl',           '5,3,1.5,3',            1.00),
    ('ctl.knx',               'ctl',           '7,3,1.5,3',            1.00),
    ('ctl.vantage',           'ctl',           '9,3,1.5,3',            1.00),

    ('power.ac_branch',       'pwr',           '8,3,1.5,3,1.5,3',      2.00),
    ('power.ac_iec',          'pwr',           '8,3,1.5,3',            2.00),
    ('power.ac_hardwired',    'pwr',           '12,3,1.5,3',           2.00),
    ('power.dc_low',          'pwr',           '6,3,1.5,3',            1.50),
    ('power.bonding',         'pwr',           '4,3',                  1.50),

    ('structure.undetermined','str',           '6,3,3,3',              0.75),
    ('structure.pathway',     'str',           '1.5,3,1.5,9',          0.75),
]

BAND = 0.10          # luminance band inside which two families are confusable
WEIGHT_RATIO = 1.4   # weight separation that rescues a shared dash class
PERIOD_FLOOR = 4.5   # pt; below this a dash blurs to solid at 300 dpi

#: The ten cable types the brief names by hand. A collision involving any of these is
#: not a style nit -- it is requirement 4 failing its own acceptance test.
REQUIREMENT_4 = {
    'audio.line_unbal': 'Analog RCA', 'video.hdmi.2_0': 'HDMI', 'net.ethernet': 'Network',
    'ctl.ir_emitter': 'IR', 'ctl.ir_receiver': 'IR', 'ctl.ir_direct': 'IR',
    'ctl.rs232': 'RS-232',
    'rf.catv': 'RG6', 'audio.spdif_coax': 'S/PDIF', 'audio.spdif_optical': 'TOSLINK',
    'audio.speaker_lowz': 'Speaker level', 'power.ac_iec': 'Power',
}

# ------------------------------------------------------------------ exclusions

#: THINGS THIS SCRIPT DRAWS NO CONCLUSION ABOUT, AND WHY, listed rather than
#: left implicit (PLAN-A/5, DR-029 section 11.28.6).
#:
#: PAL-1 is a rule about SIGNAL FAMILIES: every one renders as
#: (luminance, dash class, weight), and the check is pairwise over that
#: triple. The Plan view's floorplan underlay is drawn by the same canvas
#: through the same display list and is NOT one of those. It is an
#: arbitrary raster supplied by an architect, so it injects greyscale
#: values the palette does not control, and a check that folded them in
#: would report a different verdict for every project. A silently averaged
#: underlay is worse than a skipped one, because the skip is visible and
#: the average is not.
#:
#: The exclusion is CHECKED rather than merely commented: `check_exclusions`
#: fails the gate if any of these ids ever appears in FAMILIES, so the day
#: somebody decides an underlay IS a family, this stops rather than quietly
#: agreeing.
NOT_A_SIGNAL_FAMILY = {
    'plan.underlay':
        'an architect-supplied raster, not a rendered signal (docs/15 section 7)',
    'brand.logo':
        "DR-030's integrator logo, art rather than a signal (docs/08 row 17)",
}

#: WHAT IS *NOT* EXCLUDED, AND IS NOW CHECKED HERE (PLAN-H/3, DR-150
#: section 11.149.4).
#:
#: docs/15 section 7 and feasibility section 3.5 add an obligation the
#: underlay's exclusion does not cover: a callout glyph must stay legible
#: against a NON-WHITE background. Every PAL-1 pair to date is drawn on
#: white, so this is the first background in the corpus. This constant read
#: `CALLOUT_OVER_UNDERLAY_IS_CHECKED_AT = 'PLAN-H/3'` until that chapter
#: arrived; the check below is what it was pointing at.
#:
#: IT IS DECIDABLE BECAUSE THE SCREENING IS A CONSTANT. A callout is black
#: on an opaque white pill (DR-150 section 11.149.2), and the worst case is
#: its outline and any glyph read against the DARKEST sample the screening
#: can leave: pure architect ink, lightened to `kUnderlayInkRetained`. That
#: is one number, so the obligation is arithmetic rather than an eye.
#:
#: canon section 14.1 IS WHY IT IS ARITHMETIC. PAL-1 shipped collisions
#: three times because the rule was "checked by inspection" and read at the
#: domain level rather than over rendered values. A legibility claim about
#: a printed sheet, asserted by looking at one, is the same mistake in a
#: new place.
CALLOUT_INK = 0x000000
"""The callout's outline and text (`SheetPalette.text`, opaque black)."""

CALLOUT_MIN_CONTRAST = 4.5
"""WCAG AA for text. The margin at the shipped screening is 2.6x."""

#: Where the screening constant lives. PARSED RATHER THAN COPIED: a second
#: copy of a moving number is a liability this corpus has swept five times,
#: and `registry_parity.py` already sets the precedent for a Python gate
#: reading Dart source rather than restating it.
SCREEN_CONST_REL = 'packages/rackpal_export/lib/src/draw/plan_image.dart'
SCREEN_CONST_RE = re.compile(
    r'const\s+Permille\s+kUnderlayInkRetained\s*=\s*Permille\(\s*(\d+)\s*\)')


def underlay_ink_retained():
    """Per-mille of the architect's ink that survives the screening pass."""
    path = ROOT / SCREEN_CONST_REL
    m = SCREEN_CONST_RE.search(path.read_text(encoding='utf-8'))
    if m is None:
        raise SystemExit(
            'pal1_check: could not find kUnderlayInkRetained in %s. The '
            'callout-legibility check reads the screening constant from '
            'source on purpose; if it moved, point this at the new home '
            'rather than restating the number here.' % SCREEN_CONST_REL)
    return int(m.group(1))


def contrast(a, b):
    """WCAG contrast ratio between two greyscale 0-255 samples."""
    la, lb = luminance('%02x%02x%02x' % (a, a, a)), luminance(
        '%02x%02x%02x' % (b, b, b))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def check_callout_over_underlay():
    """Failures for the callout against the worst screened sample."""
    keep = underlay_ink_retained()
    # The screening: value + (255 - value) * (1 - keep), integer, truncating
    # the INK. Pure black is the darkest thing an architect's page holds, so
    # it is the worst case by construction.
    darkest = 255 - (255 * keep) // 1000
    ink = CALLOUT_INK & 0xFF
    ratio = contrast(ink, darkest)
    if ratio < CALLOUT_MIN_CONTRAST:
        return [
            'CALLOUT: black on the darkest screened sample (%d, from '
            'kUnderlayInkRetained = %d) is %.2f:1, below the %.1f:1 floor. '
            'Lower the screening constant or change the callout treatment.'
            % (darkest, keep, ratio, CALLOUT_MIN_CONTRAST)
        ], keep, darkest, ratio
    return [], keep, darkest, ratio

def check_exclusions():
    """Ids that are excluded AND present. Any result is a contradiction."""
    return sorted({f[0] for f in FAMILIES} & set(NOT_A_SIGNAL_FAMILY))

# --------------------------------------------------------------------------- checks

def check():
    lum = {d: luminance(h) for d, h in DOMAIN_HUE.items()}
    failures = []

    # (a)/(b): cross-domain pairs inside the luminance band
    for a, b in itertools.combinations(FAMILIES, 2):
        if a[1] == b[1]:
            continue
        delta = abs(lum[a[1]] - lum[b[1]])
        if delta >= BAND:
            continue
        if dash_class(a[2]) != dash_class(b[2]):
            continue
        ratio = max(a[3], b[3]) / min(a[3], b[3])
        if ratio >= WEIGHT_RATIO:
            continue
        named = [REQUIREMENT_4[f[0]] for f in (a, b) if f[0] in REQUIREMENT_4]
        failures.append(
            'PAL-1(a/b): %s and %s share dash class %s at weight ratio %.3f, dL=%.4f%s'
            % (a[0], b[0], '/'.join(dash_class(a[2])), ratio, delta,
               '  [requirement 4: %s]' % ', '.join(named) if named else ''))

    # within-domain: must differ in dash or weight (glyph is per-domain, so it cannot help)
    seen = {}
    for fid, dom, dash, wt in FAMILIES:
        key = (dom, dash, wt)
        if key in seen:
            failures.append('PAL-1(within): %s and %s render identically in %s (%s, %.2fx)'
                            % (seen[key], fid, dom, dash, wt))
        seen[key] = fid

    # period floor
    for fid, _dom, dash, _wt in FAMILIES:
        p = dash_period(dash)
        if p is not None and p < PERIOD_FLOOR:
            failures.append('PERIOD: %s has period %.2f pt, below the %.1f pt floor'
                            % (fid, p, PERIOD_FLOOR))

    return failures, lum

# ------------------------------------------------------------------ verdict dump

#: The eight families canon section 14.3 moved, at their values BEFORE it moved
#: them. Run through the rules above they reproduce the collisions that section
#: fixed, so a dump over them records this file's verdicts in the FAILING
#: direction, which the shipped palette never exercises.
SECTION_14_3_BEFORE = {
    'audio.spdif_optical':    ('2,3',      1.00),
    'structure.pathway':      ('2,6',      0.75),
    'structure.undetermined': ('4,4',      0.75),
    'video.hdmi.1_4':         ('solid',    1.00),
    'video.composite':        ('12,4',     1.00),
    'audio.line_bal':         ('10,3',     1.00),
    'audio.spdif_coax':       ('6,3,1,3',  1.00),
    'audio.aes3':             ('10,3,1,3', 1.00),
}

#: The control domain's dash before the period floor corrected it to `1.5,3`
#: (section 14.4): a 4.0 pt period, the one shipped value the floor refused.
PERIOD_FLOOR_BEFORE = {'ctl.ir_emitter': ('1,3', 0.75)}


def verdicts(families):
    """Every verdict the rules above reach over [families], limb by limb.

    SFE-A1's differential test (DR-122 section 11.121.4) compares the Dart
    port with this, pair by pair. It records each LIMB rather than only the
    conclusion, because the shipped palette passes, so a conclusion-only
    record would hold nothing but "no" and could not tell a port that
    agrees from one that never fails.
    """
    global FAMILIES
    saved = FAMILIES
    FAMILIES = families
    try:
        failures, lum = check()
    finally:
        FAMILIES = saved
    pairs = []
    for a, b in itertools.combinations(families, 2):
        if a[1] == b[1]:
            continue
        in_band = abs(lum[a[1]] - lum[b[1]]) < BAND
        same = dash_class(a[2]) == dash_class(b[2])
        rescued = max(a[3], b[3]) / min(a[3], b[3]) >= WEIGHT_RATIO
        pairs.append([a[0], b[0], in_band, same, rescued,
                      in_band and same and not rescued])
    return {
        'families': [[f[0], f[1], DOMAIN_HUE[f[1]], f[2], f[3]]
                     for f in families],
        'triples': {f[0]: {'L': luminance(DOMAIN_HUE[f[1]]),
                           'class': '/'.join(dash_class(f[2])),
                           'period': dash_period(f[2])}
                    for f in families},
        'pairs': pairs,
        'failures': failures,
    }


def dump_verdicts():
    """`--dump-verdicts`: SFE-A1's fixture, on stdout as JSON."""
    import json

    def moved(before):
        return [(f[0], f[1]) + before.get(f[0], (f[2], f[3]))
                for f in FAMILIES]

    out = {
        'shipped': verdicts(FAMILIES),
        'section_14_3_before': verdicts(moved(SECTION_14_3_BEFORE)),
        'period_floor_before': verdicts(moved(PERIOD_FLOOR_BEFORE)),
    }
    # One row per line: indented JSON put each of 4,161 booleans on its own
    # line and made the fixture 460 KB for no reader's benefit.
    text = json.dumps(out, indent=1, sort_keys=True)
    text = re.sub(r'\[\s+([^\[\]{}]*?)\s+\]',
                  lambda m: '[' + re.sub(r',\s+', ', ', m.group(1)) + ']', text)
    # LF, explicitly. Text-mode stdout on Windows writes CRLF, and a fixture
    # under test/fixtures/ may hold no CR (gitattributes_byte_exactness_test).
    sys.stdout.reconfigure(newline='\n')
    sys.stdout.write(text)
    sys.stdout.write('\n')
    return 0


def main():
    if '--dump-verdicts' in sys.argv[1:]:
        return dump_verdicts()
    failures, lum = check()
    pairs = sum(1 for a, b in itertools.combinations(FAMILIES, 2)
                if a[1] != b[1] and abs(lum[a[1]] - lum[b[1]]) < BAND)
    print('PAL-1 conformance: %d families, %d in-band cross-domain pairs checked'
          % (len(FAMILIES), pairs))
    contradictions = check_exclusions()
    if contradictions:
        print('FAIL - excluded id(s) present in FAMILIES: %s'
              % ', '.join(contradictions))
        print('  Either it is a signal family or it is not. See '
              'NOT_A_SIGNAL_FAMILY.')
        return 1
    # Printed so the skip is VISIBLE in a CI log. A check nobody can see
    # declining to check something is indistinguishable from one that
    # checked it and passed.
    print('  excluded (not signal families): %s'
          % ', '.join(sorted(NOT_A_SIGNAL_FAMILY)))
    callout_failures, keep, darkest, ratio = check_callout_over_underlay()
    print('  callout over the screened underlay: black on %d (ink retained '
          '%d per-mille) is %.2f:1, floor %.1f:1'
          % (darkest, keep, ratio, CALLOUT_MIN_CONTRAST))
    failures = failures + callout_failures
    if not failures:
        print('PASS - no collisions.')
        return 0
    print('FAIL - %d violation(s):' % len(failures))
    for f in failures:
        print('  ' + f)
    return 1

if __name__ == '__main__':
    sys.exit(main())
