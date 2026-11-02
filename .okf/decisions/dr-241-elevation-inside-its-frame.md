---
type: Design Ruling
title: DR-241 · The elevation sits 8 pt inside its frame, and a summary line too long for its column wraps
description: >-
  The elevation's note band, rack drawing and scale bar sit 8 pt inside the drawing area, as every other
  sheet already does; the load summary's NOT DRAWN HERE line, already cut at three-digit counts, wraps
  after its dash onto the band's sixth row. Amends DR-240's five-row summary.
tags: [ruling, elevation, layout, inset, scale-bar, notes, dr-241, dr-240]
timestamp: 2026-10-06T00:00:00Z
ruling_id: DR-241
canon_section: "11.240"
status: built
---

Settled by the user on 2026-10-06 for `#1020`, found by rendering a sheet while building
[DR-240](/decisions/dr-240-ground-bar-note-prints.md).

# What was ruled

- **8 pt all round**, the house standard the legend, cover, exceptions, network and pinout sheets already
  use. The scale bar's zero tick, drawn on the frame line until now, leaves it. Measured: an empty 55 U moves
  1:8 to 1:10; no starter moves.
- **A summary line too long for its column wraps after its dash** onto the next row rather than being cut.
  The summary is at most five lines and the band has six rows, so it always fits. This amends DR-240
  §11.239.2 (canon §12.52).

# Why it is worth a ruling

The fix narrows each column from 327 pt to 319 pt, and measuring that showed the omission line already cut
at 331.7 pt. An inset alone would have cut more of them: a cosmetic fix that clips a count is a factual
defect. See [G4](/invariants/g4-unknowns-are-counted.md) for why a count that is printed has to be whole.

Canon §11.240 holds the full text.

Built at `1902eeef` (the inset) and `3862cd87` (the wrap); docs/12 §4.51 holds the evidence.
