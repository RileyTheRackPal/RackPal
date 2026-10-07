---
type: Design Ruling
title: DR-240 · The ground bar note prints on both elevations, and the note band holds six lines
description: >-
  m21's Ground bar present checkbox had a writer and no reader. Ticked, both elevations print one note
  telling the installer to bond it; the note band grows from five lines to six, measured to move one
  rack height's ratio and no starter.
tags: [ruling, rack, elevation, grounding, notes, dr-240, m21]
timestamp: 2026-10-06T00:00:00Z
ruling_id: DR-240
canon_section: "11.239"
status: built
---

Settled by the user on 2026-10-06 for `#1016`, found while building
[DR-239](/decisions/dr-239-rack-envelope-typed-and-printed.md).

# What was ruled

- **Both faces.** The bar is a rack fact, as the envelope is, and the person bonding it reads the rear
  sheet. Front-only was offered at zero layout cost and refused for that reason.
- **Six lines in the note band**, 56 pt to 66 pt, still a constant. Measured before it was offered: of empty
  racks 1 U to 60 U and every starter rack, only an empty 56 U changes ratio (1:8 to 1:10).
- **The words**: `RACK GROUND BAR PRESENT. BOND TO BUILDING GROUND PER LOCAL CODE.`, 288.5 pt of a 327 pt
  column. No gauge and no code section; sizing is v1.2 (RJ-010).
- **Unticked prints nothing**: `false` is also the default, so a "no ground bar" line would print a default
  as a finding. The implementer's reading, stated, in the spirit of
  [G4](/invariants/g4-unknowns-are-counted.md).

# Why it is worth a ruling

A full band turns a one-line feature into a layout decision, and the band's height is what the drawing
scale is chosen against. So every option was offered with its measured cost on it: the ratio that moves,
and the width of each wording through the real font.

Canon §11.239 holds the full text.

Built at `78239478` (the band) and `5fa04853` (the note); docs/12 §4.50 holds the evidence. The render that
confirmed it also showed the band's text touching the drawing frame on every elevation, filed as `#1020`.
