---
type: Design Ruling
title: DR-211 · The cover's rack strip, and passives leave the equipment list
description: >-
  T0.00's rack strip shows VA and BTU/hr, RU per face, and an active-equipment count, capped with a
  named row. Passives (the whole Passive & Mechanical category) leave T6.30's equipment table for its
  materials section, and the seed catalog states their power as zero.
tags: [ruling, cover, t0-00, t6-30, catalog, m6-a, m6-f, dr-211]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-211
canon_section: "11.210"
status: ruled
---

Settled by the user on 2026-10-01, building M6-A2 (`#313`).

# What was ruled

- **Power is VA and BTU/hr**, as each elevation's load gutter prints; **RU is per face**,
  `F 31 · R 19`; **a strip too long is capped** with a row naming the rest and a notice.
- **In the user's words: "Leave out passives from an equipment list, but note them on the BOM."**
  The cover counts active equipment. Passive is the catalog's whole `Passive & Mechanical`
  category. T6.30's equipment table drops them and its materials section lists them by type:
  M6-F6, `#970`.
- **The seed catalog states a passive's power as 0 W / 0 VA**, and the starters regenerate.

# Why

Measured before building: Whole House's power read `≥ 2490 VA (10 unknown)`, and five of the ten
were steel panels with an empty `PowerProfile`. A blank drawing nothing is a measured zero, which
[G4](/invariants/g4-unknowns-are-counted.md) permits; inferring it from a category in the rollup
would not be. Applying the passive ruling to T6.30 as well keeps the cover's count and T6.30's rows
in agreement.

Follows [DR-210](/decisions/dr-210-cover-index-right-title-block-editable.md).
