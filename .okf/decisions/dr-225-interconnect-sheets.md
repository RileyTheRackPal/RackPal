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
status: ruled
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
- **The fallback prints a ruled note box** in the drawing area's upper left, and raises a notice.
- `ExportSpec.wireRender` waits for M6-I's dialog; the legend keys the tag pill and net-label stub
  in the same change (`#984`, by [DR-208](dr-208-legend-explains-what-the-set-prints.md)).

# Why

The Story named six sheets for eight domains, and a two-domain sheet is not
[DR-001](dr-001-net-labels-by-default.md)'s "exactly one" filter, so it would not have been drawn.
The on-screen solo draws every symbol, which on paper is the all-devices sheet CR-074 deleted. And
the threshold the ruling asked for had no number anywhere: the router's own header says it has no
link-count branch on purpose. Each gap would otherwise have been decided by whoever typed the code.

# Related

* [DR-001](dr-001-net-labels-by-default.md) - the render-mode table this applies at export.
* [DR-224](dr-224-export-notices-readable.md) - why the fallback's export notice is readable at all.
