---
type: CI Gate
title: Registry parity — the code agrees with the palette authority
description: Checks the seeded Dart registry against tools/pal1_check.py on hue, dash and weight. Gates the numeric half of the palette; deliberately blind to the descriptive half.
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

# Its blind spot, stated

It is deliberately blind to `displayName`, `shortTag`, `defaultConnector`,
`defaultDirection`, `defaultTopology` and `glyph`, because `pal1_check.py`, the
authority, carries none of those.

**Those fields are pinned only by the starter goldens**, and a golden failure
reads as *"regenerate the asset"*, which is what a developer would do, laundering
a typo into the shipped starters. The numeric half of the palette is gated; the
descriptive half has a tripwire whose signal invites the wrong fix. Recorded as
open work rather than left as a surprise.

# Citations

[1] `tools/registry_parity.py`
[2] `tools/pal1_check.py`, the authority
[3] `packages/rackmate_core/lib/src/catalog/seed_registries.dart`
