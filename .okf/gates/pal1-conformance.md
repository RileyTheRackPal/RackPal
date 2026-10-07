---
type: CI Gate
title: PAL-1 conformance, the palette survives greyscale
description: Every pair of shipped signal families in different domains, inside a 0.10 luminance band, must differ in dash class or by a 1.4 weight ratio; plus within-domain uniqueness and a 4.5 pt dash period floor. The data is Python's, the arithmetic is rackpal_core's since SFE-A2.
tags: [gate, ci, palette, pal-1, dr-122, dr-243]
timestamp: 2026-10-07T00:00:00Z
resource: tools/pal1_check.py
status: enforced
---

`python tools/pal1_check.py`, canon §14. The gate with the worst history in the
repository: PAL-1 was asserted *"verified clear"* three times against a palette
holding fourteen collisions, each time by reading a table of eight domain rows
instead of enumerating the family pairs actually drawn. **A rule checked by
inspection is not checked**, and this gate is what replaced the inspection.

# Who owns what, since SFE-A2

| Part | Lives in | Why there |
|---|---|---|
| The palette DATA (`FAMILIES`, `DOMAIN_HUE`, `REQUIREMENT_4`) | `tools/pal1_check.py` | [Registry parity](/gates/registry-parity.md) holds the Dart seed to it, and `palette_parity.py` holds the docs to it |
| The RULES (band, dash class, weight ratio, within-domain, period floor) | `packages/rackpal_core/lib/src/draw/pal1.dart` | DR-122 §11.121.4: a cloned family does not exist when CI runs, so the editor must run PAL-1 itself, and two copies of a legibility rule is how a sheet and a check come to disagree |
| The bridge | `packages/rackpal_core/tool/pal1_verdicts.dart` | The Python sends its table as JSON on stdin and prints the core's verdicts |

The header of the Python said from M0 that it *"must be ported to rackpal_core"*.
**It never was until SFE-A**, and `contrast.dart` carried a paragraph lamenting that
the port did not exist. The port was held to the Python before its rules were
deleted: `pal1_test.dart` compares every triple and every cross-domain pair, limb
by limb, against a dump the Python printed at `a4926a2d`, over the shipped palette
AND two palettes known to fail. The shipped palette passes, so a comparison over it
alone could only show the port agreeing that nothing ever fails.

# What makes a green run mean something

Every run also sends two **planted** palettes: canon §14.3's eight families at their
pre-correction values, and §14.4's pre-floor control dash. The gate fails unless the
core reports cross-domain and within-domain violations on the first and a period
violation on the second. **Drilled when built**: setting the core's band to 0 failed
the gate on the planted palette with *"the gate has not been shown to read
anything"*, and putting `audio.spdif_coax` back to `6,3,1,3` in `FAMILIES` reproduced
exactly §14.3's six S/PDIF collisions.

# Who else reads it

`tools/legend_cvd_check.py` (M6-J1, not a gate) asks PAL-1's question of the
lightness a colour-vision deficiency leaves. It sends each domain's SIMULATED
luminance through `pal1_check.core()`, which `Pal1Entry`'s optional `luminance`
accepts. It used to import the Python's `dash_class` and `WEIGHT_RATIO`; its output
was byte-identical before and after the move.

The clone editor (SFE-C2) will read `pal1Headroom`, over the menu
[DR-243](/decisions/dr-243-a-clone-picks-one-dash-per-class.md) chose.

# Blind spots

- **The within-domain limb ignores the glyph.** §14.1 lets a glyph separate two
  families in one domain, and DR-181 made per-family glyphs real. The port kept the
  Python's stricter (domain, dash, weight) reading; a clone cannot choose its glyph,
  so this is the reading an editor can act on.
- **Per-project hue overrides are not seen.** `ProjectSettings.familyColorOverrides`
  (AC-054) changes a family's effective hue in one document; the gate checks the
  shipped palette at the light theme's hues.
- **It needs Dart now.** The pipeline's palette block once said it *"needs no Dart and
  no dependencies"*; it always sat after `flutter pub get`, and now it depends on it.
