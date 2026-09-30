---
type: Design Ruling
title: DR-209 · The front matter gets a Sheet set dialog, and the legend's notes are its first section
description: >-
  T0.01's abbreviations and general notes are edited as rows in a new File ▸ Sheet set… dialog,
  which M6-A1's title block and cover fields join later. Absent means seeded; a list, even an empty
  one, prints exactly.
tags: [ruling, legend, t0-01, m6-b, dr-209, ui]
timestamp: 2026-09-30T00:00:00Z
ruling_id: DR-209
canon_section: "11.208"
status: ruled
---

Settled by the user on 2026-09-30, building M6-B6 (`#969`), on the recommended option both times.

# What was ruled

- **A `Sheet set…` dialog on the File menu, beside `Export PDF…`**, for what the set's front matter
  prints. It opens with one section, the legend's abbreviations and general notes; the title block
  and cover fields (M6-A1) join it, not Project settings.
- **Rows with add and remove**, one per abbreviation (two fields) and one per note, not a free-text
  box per list.
- **The data**: `ProjectInfo.legendAbbreviations` and `ProjectInfo.legendNotes`. Absent means the
  seed; a list, including an empty one, prints exactly; `Restore defaults` returns to absent; a row
  left wholly blank is not saved. Tag prefixes stay derived from the registries.

# Why

Nothing in any `lib/` writes `ProjectInfo`, so the title block every sheet prints needs an editor
whichever way this went, and the Project settings dialog is a single scroll of modelling defaults.
Rows parse nothing, so there is no malformed line to explain. Absent-means-seeded keeps a file from
freezing today's seed into itself (G4, [CR-117](/invariants/cr-117-byte-exactness.md)).

Follows [DR-208](/decisions/dr-208-legend-explains-what-the-set-prints.md), which left the surface
open.
