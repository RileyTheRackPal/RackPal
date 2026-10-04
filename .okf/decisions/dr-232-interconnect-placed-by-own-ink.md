---
type: Design Ruling
title: DR-232 · A drawn interconnect sheet reserves its own ink, and islands sit side by side
description: >-
  The drawn interconnect rendering places devices by their own stub-and-pill ink, not net-label room, and
  wraps island devices side by side to fit the paper; locked devices' columns hold. Amends DR-225 §11.224.4.
tags: [ruling, amendment, interconnect, layout, legibility, m6, dr-232, dr-225]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-232
canon_section: "11.231"
status: built
---

Settled by the user on 2026-10-04, building `#998`.

# What was ruled

- **Placed by its own ink**: a device's body plus the stubs and pills its own ends draw; the label
  rendering keeps its label reservation, so the two no longer share a layout (§12.49).
- **Islands wrap**: when no wire runs between two drawn devices, they are arranged in rows and columns to
  print largest. Whole House's PP-1 and LIU-1 sit side by side.
- **A lock holds**: a column with a locked device keeps its layout; islands wrap only when none is locked.

# Measured first

Two devices with 344 units of body spanned 604; height bound the fit at 0.679 (about 5.3 pt). Removing the
label reservation alone reached about 7.5 pt but let a pill touch the device above.

# Not taken

The gap fix alone, which clears the floor and leaves the page mostly empty.

Canon §11.231 holds the full text.
