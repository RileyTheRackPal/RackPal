#!/usr/bin/env python3
"""The legend under deuteranopia and protanopia simulation (AC-054, M6-J1).

M6's exit criterion asks for the legend "verified under deuteranopia and
protanopia simulation". This is that verification in a form that can be
re-run, because a clause's evidence has to survive the person who first
looked at it (roadmap section 8.9).

    python tools/legend_cvd_check.py      # exits 0 clean, 1 on any violation

WHAT IT CHECKS. PAL-1 asks what survives greyscale. This asks what survives
the two common red-green deficiencies, with PAL-1's OWN remedy: every pair
of families in different domains whose SIMULATED lightness falls inside
PAL-1's 0.10 band must still differ in dash class, or in weight by PAL-1's
1.4 ratio. Glyph is NOT
counted, although the legend prints one: every cross-domain pair has
different domain glyphs, so counting it would make the check pass
vacuously, which is the failure this corpus keeps finding in its own gates.

WHICH FAMILIES. All of them, not requirement 4's ten. `legendCableTypes`
prints the ten named types and then every other family in use, so any
family can reach a legend; Whole House's prints Fibre OS2.

ONE SOURCE. Hues, families, effective dashes and weights come from
`pal1_check.py`, which the `palette parity` gate already holds to the seeded
registries, and the PAL-1 verdict comes from `rackpal_core` through
`pal1_check.core()` (SFE-A2), with each domain's SIMULATED luminance sent in
place of the one its hue would give. This file adds only the simulation.
It used to import the dash-class rule and the 1.4 ratio from the Python,
which made it a third reader of a rule SFE-A2 exists to keep in one place.

THE SIMULATION. Machado, Oliveira and Fernandes (2009), severity 1.0,
applied in linear RGB. The test on the simulated colour is PAL-1's OWN: WCAG
relative luminance, the 0.10 band, the same rescue. A first draft used a
CIE76 delta-E line of 25 borrowed from DR-090 section 11.89.5, which
measured status CHIPS against domain hues on screen; that is a different
question, and its line flagged pairs whose difference was mostly the very
lightness PAL-1 already counts as enough. Recorded so the borrowing is not
repeated: a threshold holds in the domain it was measured in.

WHY THIS CAN FAIL WHERE PAL-1 PASSES. A dichromat keeps lightness, and PAL-1
already proves the palette survives losing hue entirely. What the
simulation adds is that the deficiency SHIFTS lightness (protanopia darkens
reds: digital audio 0.22 to 0.16), which can carry a pair into the band.

TWO SCOPES, BOTH PRINTED. Requirement 4's ten named types, which every
legend carries (`kRequirement4Types`, parsed from `legend_sheet.dart` so
the legend and this check cannot name different families), and all
families. The exit code is the ALL-FAMILIES verdict: a pair that fails is
reported, never waived, because an allowlist is how a real collision gets
waived (pal1_check.py's header).

NOT A GATE, AND IT EXITS 1 TODAY. The first run (2026-10-07) passed the ten
named types and found 14 pairs among the other families: every one still
differs by domain glyph and tag, which every legend row and drawn wire
carry, so M6's legend clause was marked demonstrated on the user's ruling,
and whether PAL-1 should also hold here is board #1031's question. If that
is ruled yes and the families restyled, this joins run_local.ps1.
"""
import re
import sys

import pal1_check as pal1

MACHADO = {
    'deuteranopia': ((0.367322, 0.860646, -0.227968),
                     (0.280085, 0.672501, 0.047413),
                     (-0.011820, 0.042940, 0.968881)),
    'protanopia': ((0.152286, 1.052583, -0.204868),
                   (0.114503, 0.786281, 0.099216),
                   (-0.003882, -0.048116, 1.051998)),
}


def _linear(hex_str):
    h = hex_str.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out


def _simulate(hex_str, matrix):
    rgb = _linear(hex_str)
    return [min(1.0, max(0.0, sum(row[j] * rgb[j] for j in range(3))))
            for row in matrix]


def simulated_luminance(hex_str, matrix):
    r = _simulate(hex_str, matrix)
    return 0.2126 * r[0] + 0.7152 * r[1] + 0.0722 * r[2]


def named_families():
    """Requirement 4's families as the legend names them, from the Dart."""
    src = (pal1.ROOT / 'packages/rackpal_core/lib/src/draw/sheet/'
           'legend_sheet.dart').read_text(encoding='utf8')
    start = src.index('kRequirement4Types = <NamedCableType>[')
    block = src[start:src.index('];', start)]
    ids = set(re.findall(r"SignalFamilyId\('([^']+)'\)", block))
    if len(ids) < 10:
        raise SystemExit('could not read kRequirement4Types: %r' % ids)
    return ids


def check(scopes):
    """{(scope, deficiency): (in-band pairs, [failures])}, in one core call.

    One call rather than four, because each is a `dart run`. Only the
    cross-domain violations are this file's question: the within-domain and
    period limbs do not depend on lightness, so a simulation cannot move them.
    """
    palettes = {}
    for label, families in scopes:
        for name, matrix in MACHADO.items():
            lum = {d: simulated_luminance(h, matrix)
                   for d, h in pal1.DOMAIN_HUE.items()}
            palettes['%s|%s' % (label, name)] = pal1.palette(families, lum)
    answer = pal1.core(palettes)['palettes']
    out = {}
    for key, verdict in answer.items():
        failures = [
            '%s and %s: simulated dL %.3f, both dash class %s, '
            'weight ratio %.2f' % (v['familyIds'][0], v['familyIds'][1],
                                   v['deltaL'], v['dashClass'],
                                   v['weightRatio'])
            for v in verdict['violations'] if v['kind'] == 'cross']
        out[tuple(key.split('|'))] = (verdict['inBandPairs'], failures)
    return out


def main():
    named = named_families()
    scopes = (
        ('requirement 4, on every legend',
         [f for f in pal1.FAMILIES if f[0] in named]),
        ('all families', pal1.FAMILIES),
    )
    verdict = 0
    results = check(scopes)
    for label, families in scopes:
        print('%s: %d families' % (label, len(families)))
        for name in MACHADO:
            in_band, failures = results[(label, name)]
            print('  %s: %d in-band cross-domain pairs, %d not rescued'
                  % (name, in_band, len(failures)))
            for f in failures:
                print('    ' + f)
            if failures and families is pal1.FAMILIES:
                verdict = 1
    print('PASS' if verdict == 0 else
          'FAIL - pairs above share dash class and weight and fall inside '
          "PAL-1's band once the deficiency shifts their lightness. Each still "
          'differs by domain glyph and tag. Board #1031.')
    return verdict


if __name__ == '__main__':
    sys.exit(main())
