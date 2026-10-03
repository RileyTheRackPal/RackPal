---
type: Design Ruling
title: DR-222 · The schedules number in blocks of five, and print their fixed columns
description: >-
  The Pull Sheet is T6.10 to T6.14 and the Termination Schedule moves from T6.11 to T6.15 to T6.19,
  then the shared overflow pool; both print docs/08's fixed columns, optional ones waiting for M6-I.
tags: [ruling, pull-sheet, termination-schedule, numbering, m6-k, dr-222]
timestamp: 2026-10-02T00:00:00Z
ruling_id: DR-222
canon_section: "11.221"
status: ruled
---

Settled by the user on 2026-10-02, opening M6-K (`#977`).

# What was ruled

- **Blocks of five**: Pull Sheet `T6.10` to `T6.14`, Termination Schedule `T6.15` to `T6.19`
  (moved from `T6.11`), then the shared overflow pool from `T6.60`, drawn in set order.
- **Fixed columns only**: docs/08 §3.2's ten and §3.3's thirteen (with DR-055's FIELD TERM and
  RACK TERM). The §3.4 optional columns come with M6-I's export dialog.

# Why

At 42 rows a page any job over 42 drops needs a second Pull Sheet page, and `T6.11` already belonged
to the Termination Schedule: a collision the corpus carried from the start and nobody had paginated.
Optional columns turned on by data would choose for the user before the dialog that lets them choose
exists.

# Related

* [DR-220](dr-220-t6-20-unused-home-runs.md) - the overflow pool this generalises.
