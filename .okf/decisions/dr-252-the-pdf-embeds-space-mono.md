---
type: Design Ruling
title: DR-252 · The PDF embeds Space Mono, and identifier columns print in it
description: >-
  From #1099. The export embedded Jost Regular only, so no printed identifier carried Space Mono's
  marked zero and CR-080's label-transcription argument was met on no sheet. The PDF now embeds Space
  Mono for the columns docs/08 sets in RackMono. Built as MONO-A, #1104.
tags: [ruling, fonts, pdf, export, cr-080, space-mono, identifiers, dr-252, dr-249, ac-054]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-252
canon_section: "11.251"
status: ruled
---

Settled by the user on 2026-10-17 for `#1099`, the question [DR-249](dr-249-the-faces-that-ship.md)
left open.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| The print face for identifiers | User, on the recommendation | Space Mono is embedded and docs/08 §10.1's `RackMono` columns print in it |

Not taken: one face with the risk recorded; embedding Jost Medium as well.

# The design said mono and the exporter said one face

docs/08 §10.1 had set `CABLE ID` in `RackMono` for months, and the bundle carried Space Mono, and
nothing printed in it: the export registers a single `FontRef`. A spec table is the design. What a
sheet prints is whatever the exporter loads, and only reading the exporter tells you which.

# Priced before it was asked

The `pdf` package subsets every embedded face, so the cost is the glyphs used, measured at build, not
the 99 KB file. The export's font map already takes several faces. The work is the identifier columns
among the sheet builders that read `kSheetFont`, and re-baselining whatever depends on measured widths.
