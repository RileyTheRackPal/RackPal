---
type: Design Ruling
title: DR-186 · Ctrl+L locks a rack device's position, and pins a schematic symbol where it stands
description: >-
  Placement.locked had no writer and only compaction read it, so every other gesture moved a locked
  device; the schematic layout read SheetItem.pinned and nothing wrote one. Ctrl+L, an inspector
  checkbox and a padlock badge now lock a rack device against moving and against a bottom-trimmed
  shrink, and the schematic's Ctrl+L pins a symbol where the layout put it.
tags: [ruling, rack, schematic, lock, pin, keymap, dr-186, cr-034, cr-068, cr-073]
timestamp: 2026-09-18T00:00:00Z
ruling_id: DR-186
canon_section: "11.185"
status: ruled
---

Ruled by the user on 2026-09-18 on board `#913`.

# Two flags nobody could set

- **`Placement.locked`** (CR-034) has been in the format since M0. Its only writer is the decoder
  and its only reader is compaction, so a drag, a nudge, a width change and a rack shrink trimmed from
  the bottom all moved a locked device. docs/12 §3.3 has said so since M1.
- **`SheetItem.pinned`** (CR-068) is what the schematic layout reads to leave a symbol alone. Nothing
  wrote one, and no document held the one schematic `Sheet` CR-073 says every project has.

# What was ruled

- **A lock refuses moving**, and a shrink trimmed from the bottom while a locked device would shift.
  **It does not refuse a delete**: the spec says *"lock position"*, and a lock that must be undone
  before a delete is a lock people leave off.
- **`Ctrl+L`, a `Locked` checkbox in the device inspector, and a 🔒 badge** that is editing chrome and
  does not print.
- **The schematic's `Ctrl+L` pins a symbol where it stands, now**, under the same label, with a 📌
  badge. The first pin creates the one schematic `Sheet`.

# Two options I described wrongly

The schematic option was offered as doing *"nothing visible"* until symbols could be dragged. The
layout already honours pins, so it freezes a symbol today, and the user chose past my description. A
second option described Alt-drop push as built; it is not. Neither error changed a decision, and both
are recorded because the rule that an offered option must name a surface that exists has a mirror: an
option has to be priced truly in both directions, and one that undersells itself gets declined for a
reason that is not true.

# What this does not rule

Dragging or nudging a schematic symbol, which is the soft-glue task. The two designator locks.
