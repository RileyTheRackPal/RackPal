---
type: Design Ruling
title: DR-187 · The schematic holds its layout, and a symbol drags, nudges and pins
description: >-
  Adding a device re-flowed the schematic and moved every symbol on it. The sheet keeps its layout
  now and the positions go in the file, written on the first edit that would re-flow rather than on
  view, which overrules DR-011.4's rejection of a SheetItem per device. A drag or a nudge moves a
  symbol and pins it, and Tidy sheet re-flows the unpinned ones.
tags: [ruling, schematic, layout, sheet-item, keymap, dr-187, dr-011, cr-068, cr-117]
timestamp: 2026-09-18T00:00:00Z
ruling_id: DR-187
canon_section: "11.186"
status: ruled
---

Ruled by the user on 2026-09-18 on board `#914`.

# Three measurements, and the third changed the plan

Probed on `schematic_scene_test.dart`'s fixture:

- **Adding two devices re-flows the sheet** and moves the symbols already on it. The report,
  reproduced.
- **Pinning a symbol where it already stands moves nothing**; pinning it 24 by 8 grid units away
  **moves all five of its neighbours**, because a fixed node stops relaxing.
- **With every existing symbol fixed, a newly added device lands exactly on top of one of them.**
  Freezing the sheet works; placing the newcomer does not come free.

# What was ruled

- **The sheet keeps its layout and the positions are in the file**, which overrules
  [DR-011.4](/decisions/dr-011-connect-gesture.md)'s rejection of a `SheetItem` per device (canon
  §12.38). A session-only freeze was offered and declined: it loses the arrangement when the project
  is reopened.
- **Written on the first edit that would re-flow**, never on view, as its own undo entry. Writing at
  save time was declined because it mutates the document outside a command; writing on first layout
  because it would prompt "save changes?" for a project nobody edited.
- **A stored position is honoured whether or not it is pinned.** Pinned is what `Tidy sheet` spares.
- **A drag or a nudge moves a symbol and pins it** (CR-068), and the arrows nudge whenever no connect
  is in flight, with the keymap row relabelled to carry both meanings.

# What this does not rule

`Tidy sheet`'s host, which is settled when it is built: the schematic's only chrome is its domain
filter bar, and docs/05's context menu is specified and unbuilt. Multi-select drag.
