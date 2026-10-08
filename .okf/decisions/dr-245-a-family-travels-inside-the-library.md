---
type: Design Ruling
title: DR-245 · A cloned family travels inside the device library, and arrives without changing what is already drawn
description: >-
  The shelf could not hold a signal family. The user chose to carry families inside .rmda/.rmdx device
  libraries for portability; a library carrying one is written at v4 so an older build refuses it rather
  than silently dropping it. Clones go to My library; arrival follows DR-103's three cases; a PAL-1 clash
  is placed and said; a clone's line can be changed.
tags: [ruling, signal-family, clone, library, rmda, shelf, sfe, dr-245, dr-122, dr-123, dr-103]
timestamp: 2026-10-08T00:00:00Z
ruling_id: DR-245
canon_section: "11.244"
status: ruled
---

Settled by the user on 2026-10-07 and 2026-10-08 for SFE-C4 (board `#832`), which became `#1033` to
`#1036`.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Where a family lives on the shelf | **User, over the recommendation** | Inside `.rmda`/`.rmdx` libraries: *"file portability FAR outweighs"* the blast radius |
| The personal library's name | User | `My library` |
| Same id, different family, on arrival | User | DR-103's rule: the newcomer gets a fresh id and its device's ports follow |
| A PAL-1 clash on arrival | User | Placed, with a notice and a mark until its line changes |
| Fixing a clash | User | *Change line* on clones; never on a shipped family |
| Writing v4 only when a family is present | Implementation | `documentMinReaderVersion`'s precedent: a refusal beats a silent loss |
| "From your libraries" list in Signal families | Implementation | A road into the next project for a clone no device uses |

# The trap this ruling records

**The decoder ignores unknown keys.** An older build reading a library with families would have dropped
them in silence and placed devices whose ports name nothing, which is exactly the portability failure the
user chose this option to prevent. Writing v4 when a family is present turns that into a refusal.

# A promise made without a host, caught after the choice

The PAL-1 clash option was first offered with *"fix its line"*. **Nothing could restyle a family**, and
SFE-B's census allows no construction site but the clone. It was re-asked with prices before any code;
see [DR-244](/decisions/dr-244-a-clone-may-change-its-default-connector.md) for the same mistake one
ruling earlier.

# Citations

- canon §11.244, §12.54; docs/10 DR-245 row
- [DR-243](/decisions/dr-243-a-clone-picks-one-dash-per-class.md),
  [DR-244](/decisions/dr-244-a-clone-may-change-its-default-connector.md)
