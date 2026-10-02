---
type: Design Ruling
title: DR-220 · T6.20 lists a home run open at either end, in room bands, and says which end
description: >-
  The Unused Home Runs sheet lists every home run with an OpenEndpoint at the rack or the room, on
  ANSI A landscape in room bands, cable-ID order, with an OPEN column naming the open end.
tags: [ruling, unused-home-runs, t6-20, auto-sheet, m6-e, dr-220]
timestamp: 2026-10-02T00:00:00Z
ruling_id: DR-220
canon_section: "11.219"
status: ruled
---

Settled by the user on 2026-10-02, building M6-E1 (`#332`).

# What was ruled

- **A home run is listed when either end is an `OpenEndpoint`**: the rack end, the field end, or
  both. A home run is a `Link` carrying a `StructureOrigin`. This widens canon §4.3's *"unbound rack
  end"*, over the recommended rack-end-only option.
- **ANSI A landscape, one band per room, rows in cable-ID order**, ten columns: `CABLE ID`, `OPEN`,
  `RACK LBL`, `FIELD LBL`, `OUTLET`, `FIELD END`, `MEDIA`, `LEN`, `PATHWAY`, `ROUGH-IN`.
- **`OPEN` reads `RACK`, `ROOM` or `BOTH`**, so which end is open is stated, never inferred.
- **Decided without a question**: the sheet sits before `T6.30`; pages are `T6.20` to `T6.29`, then
  from `T6.60` ahead of the equipment list's own overflow.

# Why

The corpus defined the sheet three ways. docs/01's *"terminated with no device on it"* was refused on
a measurement: Whole House draws no patch cords, so it would have printed all 27 of its runs as
unused. The user gave no reason for widening to the room end; what it adds is a run landed at the
rack and left as a coil at the room.

# What it does not rule

A rack end recorded as a `PlaceEndpoint` is not open, and no command writes one. A run with no
`StructureOrigin` is a schedule row, not a row here.
