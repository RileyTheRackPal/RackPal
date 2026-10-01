---
type: Design Ruling
title: DR-210 · The cover puts its index on the right, and the title block becomes editable
description: >-
  T0.00's drawing index is a full-height right-hand column; File ▸ Sheet set… gains the title-block
  fields grouped as printed and the cover's scope paragraph; approvedBy prints on the cover; a
  cleared project name is refused.
tags: [ruling, cover, t0-00, title-block, m6-a, dr-210, ui]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-210
canon_section: "11.209"
status: ruled
---

Settled by the user on 2026-10-01, building M6-A1 (`#312`), on the recommended option four times.

# What was ruled

- **The cover's drawing index is a full-height right-hand column**; the project block and scope
  sit left, the rack summary strip runs along the foot.
- **The title-block editor groups fields as the set prints them**: Project, Client and site,
  Integrator, Sign-off, then a Cover section for the scope paragraph, above the Legend section.
- **`approvedBy` prints on the cover**, on a `DRAWN · CHECKED · APPROVED` line.
- **A cleared project name is refused** with a reason; it heads every sheet.
- **Data**: new `ProjectInfo.scopeNarrative`, absent when unwritten; a cleared optional field is
  stored absent, never as an empty string.

# Why

The index is the block that grows: a 40-sheet set needs about forty rows, which only a full-height
column holds. Approval is about the whole set, and the per-sheet title block is a fixed 115 pt. A
silent `Untitled Project` fallback lets a client PDF go out under that title with nobody choosing
it.

Follows [DR-209](/decisions/dr-209-sheet-set-dialog-and-legend-notes.md), which created the dialog.
