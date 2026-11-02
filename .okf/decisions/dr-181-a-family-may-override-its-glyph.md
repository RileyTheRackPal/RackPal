---
type: Design Ruling
title: DR-181 · A signal family may override its domain's glyph
description: >-
  Board #82 said two families drew their domain's shape. Measured, it is 26 of 57, because the
  renderer draws only a domain's native glyph and the family table gives each family its own. The user
  ruled an optional per-family glyph override, seeded on the 26, amending DR-010's three render fields.
tags: [ruling, registries, glyph, greyscale, dr-010, dr-175, dr-181]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-181
canon_section: "11.180"
status: built
---

Ruled by the user on 2026-09-15 on board `#82`.

# Two named, twenty-six measured

The seed's header named `audio.speaker_cv` and `power.bonding` as drawing the wrong shape, because a
domain has two glyph slots and those two domains specify three shapes. Reading the family table
against the renderer found the defect wider: every family whose glyph is not its domain's native one
is drawn with the native one.

# What was measured

- 26 of 57 seeded families, spread across all eight domains.
- DR-010 §11.10.3 gave families exactly three render fields and kept the rest out.
- A document carries its own copy of the registries; the seed reaches new documents and the starters.

# What was ruled

- **`SignalFamilyDef` gains an optional `glyphOverride`**, drawn when set, the domain's native glyph
  otherwise.
- **The seed sets it on the 26**, so a constant-voltage speaker line draws ○ and bonding draws ⏚.
- The renderer gains those two shapes, and `registry_parity.py` checks the glyph column
  ([DR-175](/decisions/dr-175-registry-parity-reads-the-family-table.md)).
- Shape survives a greyscale print, and the families it separates are not interchangeable.
- Refused: the glyph as a domain property only, and deciding it with family authoring (DR-122).
- A project saved before this keeps the registry it was saved with.

# Built

`#82` landed it on 2026-09-16 (``4bfdc6e5``). The field, the seed's 26, the two missing shapes and
the parity gate's glyph column.

**THE ANSWER WAS NEVER A SELECTOR.** The renderer's own header has argued since M2 that no `tier`
field exists and that all three candidate proxies contradict the specification's table: a weight
override makes HDMI 1.4 hollow where all three generations print filled, a dash override makes
S/PDIF coax hollow where it prints filled, and an id-namespace rule is true of one domain. The family
table gives every family a glyph outright, so the fact is authored rather than inferred. A fourth
heuristic would have failed against the same table.

**`◐` HAD BEEN DRAWING AS `○`, AND IT MATTERED ONLY FROM THE DAY THE SEED LANDED.** The geometry
mapped the half-filled circle to the hollow one, with a comment calling it the closest honest reading
of "not the native tier". True, and harmless for exactly as long as nothing drew the hollow circle.
Seeding the 26 without touching the geometry would have made a constant-voltage speaker run and a
low-impedance one the same picture on every sheet. A near-enough mapping is how a channel goes quiet
with nothing reporting it.

**THE COUNT WAS ALREADY BEING REPORTED AND NOBODY HAD READ IT.** The scene has counted every family
whose shape the renderer could not verify since M2, a superset of the 26. A count nothing reads is a
count nobody has.
