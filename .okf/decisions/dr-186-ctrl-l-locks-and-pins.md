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
status: built
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

# Built

`#913` landed it on 2026-09-18 in `2bbe532a`: the two commands, the refusals, `Ctrl+L` on both canvases, the
inspector checkbox, the padlock and the pin badge, with eighteen core cases and twelve through the
real screens. Three mutations, three kills.

**THE `sheet` EPOCH NOW HOLDS THE SCHEMATIC LAYOUT, AND THE REASON WAS MEASURED AFTER IT WAS
CLAIMED.** It was wired to the structure handler, which re-lays the sheet out from scratch. The
claim was that a pin would therefore shift the pinned symbol's neighbours. **It does not**: probed on
the scene fixture, pinning a symbol where it already stands moves nothing, because a fixed node is
handed the answer the layout was going to give it, and that is a test now. Pinning it 24 by 8 grid
units away moves all five of the others, which is the state a DRAG creates, and dragging is the
soft-glue task. The hold is a guard for that and for the floorplan edits that bump the same epoch,
not a fix for a defect anybody met.

**THE WIDTH TEST FIXTURE CARRIED `locked: true`** and had since it was written, because the field was
free while nothing read it. Every plan in that file refused on the first run of the new rule, which is
[a defaulted enum has already answered](/practices/a-defaulted-enum-has-already-answered.md) wearing
a boolean: a value chosen when it meant nothing becomes a decision the day it means something.

# Two options I described wrongly

The schematic option was offered as doing *"nothing visible"* until symbols could be dragged. The
layout already honours pins, so it freezes a symbol today, and the user chose past my description. A
second option described Alt-drop push as built; it is not. Neither error changed a decision, and both
are recorded because the rule that an offered option must name a surface that exists has a mirror: an
option has to be priced truly in both directions, and one that undersells itself gets declined for a
reason that is not true.

# What this does not rule

Dragging or nudging a schematic symbol, which is the soft-glue task. The two designator locks.
