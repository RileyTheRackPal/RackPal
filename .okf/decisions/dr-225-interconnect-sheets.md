---
type: Design Ruling
title: DR-225 · The interconnect sheets, one per domain, its own devices, and a fallback measured at 6 pt
description: >-
  T6.01 on is one sheet per SignalDomainId (at most eight), drawing only that domain's devices with
  locks kept; drawn falls back to net labels at docs/08's 6 pt floor, with a note box on the sheet.
tags: [ruling, export, interconnect, schematic, drawn, m6-d, dr-225]
timestamp: 2026-10-03T00:00:00Z
ruling_id: DR-225
canon_section: "11.224"
status: built
amended_by: [DR-232]
---

Settled by the user on 2026-10-03, opening M6-D (`#326`), on the recommended option four times.

# What was ruled

- **One sheet per `SignalDomainId`, at most eight, `T6.01` on**, in docs/05 §11.2's figure order.
  A domain with no link on a drawn pin prints no sheet.
- **A sheet draws only the devices its domain's links touch.** A locked device keeps its
  `SheetItem.position`; the rest are laid out around it.
- **`drawn` falls back to net labels at docs/08 §6.2's 6 pt floor**, measured on the fitted sheet,
  and only when the label sheet meets it (an implementer's clause: otherwise the swap buys nothing).
  No link count is invented.
- **A bank the sheet wires prints expanded** (§11.224.7, ruled the same day). A collapsed bank's
  vector pin carries only its first port, so the other members' cables were drawn nowhere.
- **The fallback prints a ruled note box** in the drawing area's upper left, and raises a notice.
- `ExportSpec.wireRender` waits for M6-I's dialog; the legend keys the tag pill and net-label stub
  in the same change (`#984`, by [DR-208](dr-208-legend-explains-what-the-set-prints.md)).

# Why

The Story named six sheets for eight domains, and a two-domain sheet is not
[DR-001](dr-001-net-labels-by-default.md)'s "exactly one" filter, so it would not have been drawn.
The on-screen solo draws every symbol, which on paper is the all-devices sheet CR-074 deleted. And
the threshold the ruling asked for had no number anywhere: the router's own header says it has no
link-count branch on purpose. Each gap would otherwise have been decided by whoever typed the code.

# Built

M6-D landed it on 2026-10-03 on branch `m6d-interconnect`: the partition in `9b611fb0`, the drawn
sheet in `16e1d1f3`, the fallback and its note in `a37adc64`, the legend rows in `3c30b7e2` and the
DR-004 guard in `c40509d5`. Whole House prints `T6.01` RF and `T6.02` Network.

**THE FALLBACK ALMOST NEVER FIRES, AND THAT WAS MEASURED.** Drawn and net labels share one layout and
one type size and differ only in ink reach: Whole House Network 5.18 pt drawn, 5.39 labels; the test
fixture within 0.25 pt, labels worse on two of three. The implementer's clause is what stops a swap
that buys nothing. What actually makes a sheet small is the layout's global node gap, sized for the
busiest comb on the sheet, which is not this ruling's to fix.

# Related

* [DR-001](dr-001-net-labels-by-default.md) - the render-mode table this applies at export.
* [DR-224](dr-224-export-notices-readable.md) - why the fallback's export notice is readable at all.
