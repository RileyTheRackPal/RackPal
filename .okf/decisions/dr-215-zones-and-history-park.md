---
type: Design Ruling
title: DR-215 · Zones on drawing sheets only, from the lower right; revision entries and clouds park on project history
description: >-
  The 0.22 in zone band goes on drawing sheets only and runs from the lower right, so folded ANSI
  C/D sheets show the markings; M6-G3's entry writer and M6-G4's clouds park on project history.
tags: [ruling, sheet-furniture, zones, revisions, m6-g, dr-215]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-215
canon_section: "11.214"
status: built
---

Settled by the user on 2026-10-01, opening M6-G (`#341`).

# What was ruled

- **Zone band and grid on drawing sheets only**: elevations, plans, interconnect. Cover, legend,
  T0.02 and T6.30 keep the thin inset.
- **Zones run from the lower right**, in the user's words so ANSI C/D sheets *"fold out from a binder
  but display the ASME markings when folded"*. docs/08 §5.1's `VERIFY` is answered by ruling.
- **G3's entry writer parks on HIST/3 (`#658`), G4's clouds on HIST/5 (`#660`)**: both need project
  history; §5.3 forbids hand-entered revisions.

# Why

A zone names a place on a drawing and a table has none; a full band would cost every table about
20 pt. Parking under §8.9 keeps M6 closable without inventing a revision source history would later
contradict.
