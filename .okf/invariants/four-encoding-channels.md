---
type: Invariant
title: CR-078 — four encoding channels, and hue is never used alone
description: Hue encodes domain, dash encodes type-within-domain, weight encodes tier, glyph and tag identify the family. One of the four is currently non-functional.
tags: [invariant, palette, cr-078, accessibility]
timestamp: 2026-07-28T12:00:00Z
ruling_id: CR-078
status: partially-enforced
---

Four channels carry signal identity on a schematic. **Hue is never used
alone.**

| Channel | Encodes | Lives on |
|---|---|---|
| **hue** | domain (8, Okabe-Ito) | `SignalDomainDef.color` / `colorDark` |
| **dash** | type-within-domain | `SignalFamilyDef.dashOverride` ?? domain base |
| **weight** | domain tier | `SignalFamilyDef.lineWeightPermilleOverride` ?? domain base |
| **glyph + tag** | the exact family | `SignalDomainDef.glyph` + `SignalFamilyDef.shortTag` |

# Why the redundancy is the point

No categorical palette is CVD-safe past 8–9 categories, and a colour-only
scheme **"fails hardest for the ~8% of male installers with a CVD who are the
exact audience"**. Hue also dies in greyscale and on a photocopy, which is how
these drawings actually reach a job site.

`tools/pal1_check.py` enforces this **after fourteen collisions once shipped**.
Run it; do not reason about legibility by eye. Note its two rules differ:
cross-domain pairs inside a luminance band need a dash-class difference or a
≥1.4 weight ratio, while within a domain it only requires dash **or** weight to
differ.

# Always read the EFFECTIVE value

`effectiveDashPattern(domain)` and `effectiveLineWeightPermille(domain)` apply
the `override ?? domain` fallback. **A renderer that reads `dashOverride`
directly draws a domain's families all alike**, and a gate that checks the raw
field passes it. PAL-1 is stated over post-override values for the same reason.

Two conversions bite: `effectiveDashPattern` returns `[]` for solid while
`Stroke.dash` spells solid `null`; and weight is `0.7 × permille/1000`
**exactly**, not rounded to a display column — PAL-1's limb (b) is a ratio
evaluated on permille, so rounding puts 1.286 on paper where the authority
cleared 1.25.

# THE GLYPH CHANNEL IS CURRENTLY NON-FUNCTIONAL

`docs/05:206`: *"Shape encodes domain; **fill encodes tier** — filled = the
domain's native carrier, hollow = the transported, extended or networked
variant."*

`SignalDomainDef` stores `glyph` and `glyphAlt`. **There is no `tier` field
anywhere**, so nothing can ever select `glyphAlt` — it is seeded, stored,
round-tripped and unreachable. This is true for **all eight domains and all 55
families**, not merely the two whose docs list a third shape.

So `video.hdbaset` (transported) and `video.avoip` (networked) render
identically to native HDMI. One of the four channels carries nothing.

The fix is already named in the corpus: `seed-devices.md` §4.4's field list
includes **`glyphOverride?`**, and its Glyph column already holds the per-family
data. [DR-010](/decisions/dr-010-seeded-registries.md) §11.10.3 added
`shortTag`, `dashOverride` and a weight override — and not this one.

Until then, affected families are **counted** in
`SchematicScene.underGlyphedFamilyIds` and the two worst are pinned by name in a
test, so they are known-wrong rather than silently wrong
([G4](/invariants/g4-unknowns-are-counted.md)).

# Do not couple jacket colour to hue

`Link.jacketColorId` is the sheath that was pulled — a physical fact about a
building. It is not the hue a wire draws in. Coupling them would make a blue
control run and a blue A/V run render identically, and would substitute a shop's
unvalidated reel colours for a CVD-validated palette.
`jacket_colour_is_not_hue_test.dart` is a source gate over four drawing roots.

# Citations

[1] `docs/05-schematic-editor.md` §6.1–6.4
[2] `tools/pal1_check.py` — the authority
[3] `packages/rackmate_core/lib/src/draw/scene/signal_style.dart`
