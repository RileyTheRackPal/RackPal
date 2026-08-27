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
import sys

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
    ('ctl.rs232',             'ctl',           '6,3,1.5,3',            0.75),
    ('ctl.rs485',             'ctl',           '6,3',                  1.00),
    ('ctl.dmx512',            'ctl',           '8,3,1.5,3',            1.00),
    ('ctl.contact',           'ctl',           '1.5,3,4,3',            0.75),
    ('ctl.trigger12v',        'ctl',           '4,3',                  0.75),
    ('ctl.cresnet',           'ctl',           '10,3,1.5,3',           1.00),
    ('ctl.lutron_qs',         'ctl',           '10,3',                 1.00),
    ('ctl.dali',              'ctl',           '5,3,1.5,3',            1.00),
    ('ctl.knx',               'ctl',           '7,3,1.5,3',            1.00),

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
    'ctl.ir_emitter': 'IR', 'ctl.ir_receiver': 'IR', 'ctl.rs232': 'RS-232',
    'rf.catv': 'RG6', 'audio.spdif_coax': 'S/PDIF', 'audio.spdif_optical': 'TOSLINK',
    'audio.speaker_lowz': 'Speaker level', 'power.ac_iec': 'Power',
}

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

def main():
    failures, lum = check()
    pairs = sum(1 for a, b in itertools.combinations(FAMILIES, 2)
                if a[1] != b[1] and abs(lum[a[1]] - lum[b[1]]) < BAND)
    print('PAL-1 conformance: %d families, %d in-band cross-domain pairs checked'
          % (len(FAMILIES), pairs))
    if not failures:
        print('PASS - no collisions.')
        return 0
    print('FAIL - %d violation(s):' % len(failures))
    for f in failures:
        print('  ' + f)
    return 1

if __name__ == '__main__':
    sys.exit(main())
