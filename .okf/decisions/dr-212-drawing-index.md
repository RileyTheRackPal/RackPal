---
type: Design Ruling
title: DR-212 · The drawing index, both numbers, flat, ranges collapsed, sub-columns on overflow
description: >-
  T0.00's index lists every resolved sheet in set order with its set position and NCS id, collapses
  a multi-page schedule to one row, and flows into up to three sub-columns before it reports an
  omission.
tags: [ruling, cover, t0-00, index, m6-a, dr-212]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-212
canon_section: "11.211"
status: built
---

Settled by the user on 2026-10-01, building M6-A3 (`#314`), on the recommended option four times.

# What was ruled

- **Both numbers per row**, `4  T2.01`, as every title block prints both.
- **Flat, in set order**; the NCS ids already group by series.
- **A multi-page schedule is one row**, with its page count.
- **Overflow flows into two, then three sub-columns**; beyond that the export still completes and
  a notice names what the index omits.

# Why

The reserved column holds about forty rows; a ten-rack job reaches about thirty-seven sheets once M6
is complete, so overflow was priced as real. A continuation index sheet would make the set's sheet
count depend on the index's own size.

Follows [DR-210](/decisions/dr-210-cover-index-right-title-block-editable.md), which reserved the
column.
