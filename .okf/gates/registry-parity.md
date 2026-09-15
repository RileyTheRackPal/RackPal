---
type: CI Gate
title: Registry parity — the code agrees with the palette authority
description: Checks the seeded Dart registry against tools/pal1_check.py on hue, dash and weight, and against seed-devices.md section 4.4 on each family's name, connector, tag, direction and topology (DR-175).
tags: [gate, ci, palette, registries]
timestamp: 2026-07-28T00:00:00Z
resource: tools/registry_parity.py
status: enforced
---

`python tools/registry_parity.py`. Added by
[DR-010](/decisions/dr-010-seeded-registries.md), one of the fourteen gates
`run_local.ps1 -SkipBuild` runs.

**An ordinal was what this line used to carry, and it rotted.** It read *"13th
gate"*, which was true on the day DR-010 appended it and false as soon as DR-017
inserted the formatter ahead of it. A gate's position in a list is not a fact
about the gate. Count the `Invoke-Gate` calls if the number matters.

# The pair it completes

`tools/pal1_check.py` is the **single authority** for the palette.

- `palette_parity.py` proves the **docs** agree with the authority.
- `registry_parity.py` proves the **code** does.

Both exist because doc-vs-authority drift, in `palette_parity.py`'s own words,
*"shipped four times"*: a table of dash and weight values drifts out of step, a
reader implements from the stale table, and the palette re-collides.

# What it compares

Domain id set · domain hue · family id set · family domain · **effective** dash ·
**effective** weight.

"Effective" matters: PAL-1 is stated over post-override values, so the gate
applies the same `override ?? domain` fallback the Dart does. A gate reading
`dashOverride` directly would pass a seed whose families all render alike.

# It cannot pass vacuously

Verified by mutation, not by reading: it exits **1** on a missing seed file and on
a parse error, and it catches a **single hex digit** of hue drift. A gate that
silently passes when its input disappears is worse than no gate.

# The descriptive half, since DR-175

**It used to be blind to it, on purpose**, because `pal1_check.py` carries no
`displayName`, `shortTag`, `defaultConnector`, `defaultDirection` or
`defaultTopology`. Those fields were pinned only by the starter goldens, and a
golden failure reads as *"regenerate the asset"*, which launders a typo into the
shipped starters. `#81` recorded that as open work.

**Now the seed is held to the family table in `docs/catalog/seed-devices.md`
§4.4**, which tabulates every one of those fields for all 57 families. Name,
connector and tag match exactly once markdown emphasis and code marks are
removed; a Dir or Topo cell is read by its leading symbol or word; a cell that is
only a dash states nothing and is skipped. The id sets must match both ways.
**Neither file is the authority for this half**: a drift is fixed in whichever of
the two is wrong, and the failure says not to regenerate the starters.

Verified by mutation on copies before it landed: a changed tag, connector,
direction or name, a removed row, an unreadable Dir cell and a missing §4.4
heading each exit **1**; a name wrapped in bold still passes.

# Its blind spot, stated

The **glyph**, which the seed does not store per family (DR-010 §11.10.3), and
every `SignalFamilyDef` field §4.4 does not tabulate, such as typical media and
run lengths.

# Citations

[1] `tools/registry_parity.py`
[2] `tools/pal1_check.py`, the authority
[3] `packages/rackmate_core/lib/src/catalog/seed_registries.dart`
