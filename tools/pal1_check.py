#!/usr/bin/env python3
"""PAL-1 conformance check for the RackPal signal palette.

The pairwise greyscale-legibility gate that docs/catalog/seed-devices.md section 4.2
requires. It was written in Python so it could run before any Dart existed, and its
header said it "must be ported to `pal1_conformance_test.dart` in `rackpal_core` at M0".
That port never happened, and the gate was this file alone for the whole project.

THIS FILE OWNS THE DATA AND NO LONGER OWNS THE RULES (SFE-A2, DR-122 section
11.121.4). A person can now clone a family and pick its dash and weight, and a family
that does not exist when CI runs cannot be CI-gated, so the editor has to run PAL-1
itself. The arithmetic therefore lives in `packages/rackpal_core/lib/src/draw/pal1.dart`,
and this gate SENDS its table to `packages/rackpal_core/tool/pal1_verdicts.dart` and
prints what comes back. One implementation, read by the gate and the editor alike:
two is how a printed sheet and a CI check come to disagree. `FAMILIES` and
`DOMAIN_HUE` stay here because palette_parity.py and registry_parity.py hold the docs
and the Dart seed to them.

The port was held to this file's own verdicts before its copy of the rules was
deleted: `rackpal_core/test/draw/pal1_test.dart` compares every family's triple and
every cross-domain pair, limb by limb, with a dump this file printed at SFE-A1. Every
run also sends two PLANTED palettes that are known to collide (`PLANTED` below) and
fails unless the core reports them, so a green run is evidence that the core was
asked and could have said no.

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
import json
import pathlib
import re
import shutil
import subprocess
import sys

#: Repo root, for the source files this gate parses and the package it runs.
ROOT = pathlib.Path(__file__).resolve().parent.parent

#: Where the rules live now, and the tool that answers for them.
CORE = ROOT / 'packages' / 'rackpal_core'
TOOL = 'tool/pal1_verdicts.dart'

# ------------------------------------------------------------------- the core

def permille_dash(pattern):
    """`6,3,1.5,3` in points -> `[6000, 3000, 1500, 3000]`; `solid` -> `[]`.

    Marshalling, not a rule: the registry stores permille (CR-079) and the
    core reads what the registry stores.
    """
    if pattern == 'solid':
        return []
    return [round(float(x) * 1000) for x in pattern.split(',')]


def palette(families, luminance=None):
    """One palette of a request: [families] as (id, domain, dash, weight).

    [luminance], a {domain: L} map, replaces the luminance the core would
    compute from the hue. legend_cvd_check.py uses it to ask PAL-1's
    question of a SIMULATED lightness.
    """
    out = {
        'hues': {d: DOMAIN_HUE[d] for d in sorted({f[1] for f in families})},
        'families': [[f[0], f[1], permille_dash(f[2]), round(f[3] * 1000)]
                     for f in families],
    }
    if luminance is not None:
        out['luminance'] = luminance
    return out


def core(palettes, contrast=()):
    """Ask `rackpal_core` for PAL-1's verdicts on each of [palettes].

    Exits 1, loudly, if the tool cannot be run or does not answer. A gate
    that reads "no violations" out of a crash is the failure this
    repository has met more than once, so nothing here defaults to clean.
    """
    dart = shutil.which('dart')
    if dart is None:
        raise SystemExit('pal1_check: `dart` is not on PATH. PAL-1 is computed '
                         'by rackpal_core now (SFE-A2); this gate cannot pass '
                         'without asking it.')
    request = json.dumps({'palettes': palettes,
                          'contrast': [list(p) for p in contrast]})
    run = subprocess.run([dart, 'run', TOOL], cwd=CORE, input=request,
                         capture_output=True, text=True, encoding='utf-8')
    body = run.stdout[run.stdout.find('{'):] if '{' in run.stdout else ''
    if run.returncode != 0 or not body:
        raise SystemExit('pal1_check: %s exited %d with no verdict.\n%s\n%s'
                         % (TOOL, run.returncode, run.stdout, run.stderr))
    return json.loads(body)


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

#: The band (0.10), the weight ratio (1.4) and the period floor (4.5 pt) are
#: NOT restated here. They live beside the rules in pal1.dart and come back
#: with every answer under `constants`, which is what this file prints.

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


def grey(v):
    """An opaque 0xAARRGGBB grey of 0-255 value [v], as the core takes it."""
    return 0xFF000000 | (v << 16) | (v << 8) | v


def callout_samples():
    """(ink retained, darkest screened sample, callout ink), all 0-255 greys.

    The screening: value + (255 - value) * (1 - keep), integer, truncating
    the INK. Pure black is the darkest thing an architect's page holds, so
    it is the worst case by construction.
    """
    keep = underlay_ink_retained()
    return keep, 255 - (255 * keep) // 1000, CALLOUT_INK & 0xFF


def check_callout_over_underlay(ratio, keep, darkest):
    """Failures for the callout at [ratio], the core's WCAG contrast."""
    if ratio < CALLOUT_MIN_CONTRAST:
        return ['CALLOUT: black on the darkest screened sample (%d, from '
                'kUnderlayInkRetained = %d) is %.2f:1, below the %.1f:1 floor. '
                'Lower the screening constant or change the callout treatment.'
                % (darkest, keep, ratio, CALLOUT_MIN_CONTRAST)]
    return []

def check_exclusions():
    """Ids that are excluded AND present. Any result is a contradiction."""
    return sorted({f[0] for f in FAMILIES} & set(NOT_A_SIGNAL_FAMILY))

# ---------------------------------------------------------------- planted palettes

#: The eight families canon section 14.3 moved, at their values BEFORE it moved
#: them, and the control domain's dash before section 14.4's floor corrected it
#: to `1.5,3`. Both are palettes KNOWN to fail, and every run sends them beside
#: the real one: if the core reports nothing on them, this gate has not been
#: shown to be reading anything, and it fails rather than passing on silence.
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
PERIOD_FLOOR_BEFORE = {'ctl.ir_emitter': ('1,3', 0.75)}

#: Each planted palette, and the violation kinds the core must report on it.
PLANTED = {
    'planted: section 14.3 before': (SECTION_14_3_BEFORE, {'cross', 'within'}),
    'planted: section 14.4 before': (PERIOD_FLOOR_BEFORE, {'period'}),
}


def moved(before):
    """FAMILIES with the rows in [before] put back to their old values."""
    return [(f[0], f[1]) + before.get(f[0], (f[2], f[3])) for f in FAMILIES]

# --------------------------------------------------------------------------- checks

def describe(v, by_id, constants):
    """One violation from the core, worded as this gate has always printed it."""
    ids = v['familyIds']
    if v['kind'] == 'cross':
        named = [REQUIREMENT_4[i] for i in ids if i in REQUIREMENT_4]
        return ('PAL-1(a/b): %s and %s share dash class %s at weight ratio %.3f, '
                'dL=%.4f%s' % (ids[0], ids[1], v['dashClass'], v['weightRatio'],
                               v['deltaL'], '  [requirement 4: %s]'
                               % ', '.join(named) if named else ''))
    if v['kind'] == 'within':
        a = by_id[ids[1]]
        return ('PAL-1(within): %s and %s render identically in %s (%s, %.2fx)'
                % (ids[0], ids[1], a[1], a[2], a[3]))
    return ('PERIOD: %s has period %.2f pt, below the %.1f pt floor'
            % (ids[0], v['periodPermille'] / 1000,
               constants['periodFloorPermille'] / 1000))


def main():
    contradictions = check_exclusions()
    keep, darkest, ink = callout_samples()
    palettes = {'shipped': palette(FAMILIES)}
    for name, (before, _) in PLANTED.items():
        palettes[name] = palette(moved(before))
    answer = core(palettes, contrast=[(grey(ink), grey(darkest))])
    shipped = answer['palettes']['shipped']
    print('PAL-1 conformance: %d families, %d in-band cross-domain pairs checked'
          % (shipped['families'], shipped['inBandPairs']))
    print('  rules: packages/rackpal_core/lib/src/draw/pal1.dart, through %s' % TOOL)

    # The planted palettes first: a core that cannot fail them cannot be trusted
    # to pass the real one.
    for name, (_, kinds) in PLANTED.items():
        got = {v['kind'] for v in answer['palettes'][name]['violations']}
        print('  %s: core reported %d violation(s), kinds %s'
              % (name, len(answer['palettes'][name]['violations']),
                 ', '.join(sorted(got)) or 'none'))
        if not kinds <= got:
            print('FAIL - the core did not report %s on a palette known to '
                  'collide. The gate has not been shown to read anything.'
                  % ', '.join(sorted(kinds - got)))
            return 1

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
    ratio = answer['contrast'][0]
    print('  callout over the screened underlay: black on %d (ink retained '
          '%d per-mille) is %.2f:1, floor %.1f:1'
          % (darkest, keep, ratio, CALLOUT_MIN_CONTRAST))
    by_id = {f[0]: f for f in FAMILIES}
    failures = [describe(v, by_id, answer['constants'])
                for v in shipped['violations']]
    failures += check_callout_over_underlay(ratio, keep, darkest)
    if not failures:
        print('PASS - no collisions.')
        return 0
    print('FAIL - %d violation(s):' % len(failures))
    for f in failures:
        print('  ' + f)
    return 1

if __name__ == '__main__':
    sys.exit(main())
