---
type: Design Ruling
title: DR-205 · The Staging Bin ships, as a strip under the canvas
description: >-
  CR-032 ruled the Staging Bin into v1 and nothing built it. Found when DR-204's shelf deletion
  needed it as a default. A strip under the rack canvas; in by deleting a shelf, a release off the
  rack, U, and Shrink Rack; out by a return chip or a drag. Every way keeps the device's wiring.
tags: [ruling, rack-editor, staging-bin, cr-032, cr-031, dr-205]
timestamp: 2026-09-30T00:00:00Z
ruling_id: DR-205
canon_section: "11.204"
status: ruled
---

Settled by the user on 2026-09-30. Not a scope amendment: CR-032 already rules the bin into v1
with its return affordance. It had been specified in docs/04 and never built.

# What was ruled

- **A strip under the rack canvas**, shown only while it holds something (docs/04 §1's sketch).
- **In**: deleting a shelf, a release off the rack (the user added that a device dragged off must
  keep its wiring), the `U` key, Shrink Rack's option 2.
- **Out**: a return chip to the last rack position or shelf (a new `lastHostDeviceId` makes the
  second possible), or a drag onto a rack or shelf.
- `U` is the rack's first bare letter, allowed by canon §1.10 (c) because the schematic does not
  bind it bare.
- **Shrink Rack (§11.204.6)**: option 2 is preselected when compaction cannot fit everyone (docs/04
  §4.1 rule 2 as written), and option 1's partial form stages its leftovers. A locked casualty
  refuses the bin and restores option 3 as the default.

# How it was found

The author offered "Move hosts to Staging Bin" as the recommended default for deleting a shelf,
and the bin did not exist: `StagedPlacement` had no producer, no list and no way back, and Shrink
Rack showed its bin option disabled for that reason. The option was corrected in the next question,
and the user chose to build the bin rather than work around it.

# What the gates refused while it was built

- **A shelf move with no loop check.** Moving a device onto a shelf can close a loop (a shelf set
  on a shelf that sits on it), which a newly minted device never can. The first draft asked only
  whether the host was a container. `placement_rules_test.dart`'s writer scan named the new file,
  and both move planners now refuse a loop under TOP-005 through `shelfMoveWouldLoop`.
- **CR-032's `↩`.** The product font has no bold `↩`, so the glyph-coverage gate refused it. The
  chip reads `Return to RK-1 U21`, CR-032's words without the arrow.
