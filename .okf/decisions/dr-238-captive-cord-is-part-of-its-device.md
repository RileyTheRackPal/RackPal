---
type: Design Ruling
title: DR-238 · A captive cord is part of its device, and T6.30 does not list it
description: >-
  Captive cords leave T6.30's jumpers-and-power-cords table and its bought-by-the-piece count together,
  known by deriving them from an inlet-role power.ac_branch port. They stay power cords elsewhere.
tags: [ruling, power-cord, captive, t6-30, bom, dr-238, dr-233]
timestamp: 2026-10-06T00:00:00Z
ruling_id: DR-238
canon_section: "11.237"
status: built
---

Settled by the user on 2026-10-06 for `#1002`: remove captive cords on T6.30.

# What was ruled

- **Out of T6.30's table and its count together**, which are one count read twice.
- **Still a power cord** for the Pull Sheet, the outlet map and the Schedule's hidden-cords count
  ([DR-233](/decisions/dr-233-iec-or-nema-cord-is-a-power-cord.md)).
- **Derived, not authored**: an inlet-role `power.ac_branch` port, which is all 13 seeded captive inlets.
- **Counted, not hidden** ([G4](/invariants/g4-unknowns-are-counted.md)).

Canon §11.237 holds the full text.

Built at `8a82bdb9`; docs/12 §4.48 holds the evidence.
