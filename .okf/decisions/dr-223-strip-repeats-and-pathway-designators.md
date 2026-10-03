---
type: Design Ruling
title: DR-223 · The compact strip drops its repeats, and PATHWAY asks for designators
description: >-
  The ANSI A title strip stops repeating the sheet title and number and steps a too-wide row to 7 pt;
  PATHWAY keeps 36 pt and a pathway with no designator is named in an export notice.
tags: [ruling, title-block, pull-sheet, pathway, m6-l, dr-223]
timestamp: 2026-10-03T00:00:00Z
ruling_id: DR-223
canon_section: "11.222"
status: ruled
---

Settled by the user on 2026-10-03, building M6-L (`#982`), on the recommended options.

# What was ruled

- **The compact strip drops two repeats**: the sheet title on row 2 and `SHEET i/n` on row 3, both
  printed elsewhere on the strip. A row still too wide prints at 7 pt instead of 7.5.
- **PATHWAY keeps 36 pt.** A pathway printed with no designator is named in an export notice that
  says where to give it one; the starters get designators.

# Why

Measured with the real font: row 3 overflowed the 510 pt portrait strip on every starter, and every
starter pathway name (49 to 86 pt) overflowed a column designed for a designator.

# Related

* [DR-222](dr-222-schedules-blocks-of-five.md) - the schedules this fits.
