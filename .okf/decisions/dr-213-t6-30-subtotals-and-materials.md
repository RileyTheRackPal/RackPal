---
type: Design Ruling
title: DR-213 · T6.30's subtotals stay whole-rack, and the materials are one list
description: >-
  With passives off T6.30's equipment rows, a rack's subtotal still counts them and says so, and
  the passives are one MATERIALS list at the end with quantity, make and model, and a WHERE split.
tags: [ruling, t6-30, materials, m6-f, dr-213]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-213
canon_section: "11.212"
status: ruled
---

Settled by the user on 2026-10-01, building M6-F6 (`#970`), on the recommended option both times.

# What was ruled

- **A rack's subtotal is the whole rack**, passives included, and the line says
  `26 DEVICES + 5 PASSIVES (SEE MATERIALS)`; it then equals the cover's strip and the elevation
  gutter.
- **One MATERIALS list at the end**: a row per item and lifecycle status, quantity, make and model,
  and `WHERE` (`RK-1 × 3, RK-2 × 1`). M6-F's later rollups join it.
- **The bijection is restated**: every device is one equipment row or one unit of one materials
  row.

# Why

Summing only the visible rows would give a rack two weights in one set. A job-wide list is how an
order is read, and the cable rollups are job-wide too.

Follows [DR-211](/decisions/dr-211-cover-rack-strip-and-passives.md).
