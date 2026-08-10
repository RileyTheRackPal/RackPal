---
type: Design Ruling
title: DR-035 — A created Pathway records the medium it is and the room it serves
description: >-
  DR-032 ruled what such a pathway is called and was silent on what else the act
  records. The forcing case is a broken control: a matrix cell is a count, so it
  must find the pathways in this room of this medium, and a DR-032 pathway
  recorded neither.
tags: [ruling, m3, pathways, conduit, orientation, g4, dr-035]
timestamp: 2026-08-10T00:00:00Z
ruling_id: DR-035
canon_section: "11.34"
status: built
---

Settled by the user on 2026-08-10. An entry surface creating a `Pathway` from a
pathway-only medium sets, in addition to
[DR-032](/decisions/dr-032-pathway-only-medium-names-its-pathway.md)'s name:

1. **`pathwayMedia`** to the resolved `MediaTypeId`;
2. **`fromLocationId`** to the room the line or cell named. `toLocationId`
   **stays null**, which is UNKNOWN and not empty
   ([G4](/invariants/g4-unknowns-are-counted.md), CR-114).

# The forcing case is a broken control, not tidiness

docs/07 §4.2's matrix cell is a **count**: type `3` into `[Living Room × EMT]`
and the cell must then read `3`, and typing `1` must remove two. Reading it back
means finding *"the pathways in this room, of this medium"*, and a `Pathway`
created under DR-032 recorded **neither**.

A cell that accepts a number and always reads back `0` is not a partially built
feature. It is a control that lies, and it would have shipped the tinted column
§4.2 draws while making it unusable.

This is why the ruling came before the code. DR-032 §11.31.6 lists what that
ruling does not settle and mentions neither field; the silence was invisible
while only one surface created pathways.

# `from` is the room, and the orientation is being set for the first time

`Pathway.fromLocationId` and `Pathway.toLocationId` shipped at M0 with **no
reader that established an order**. The only writer is `RemoveLocationCommand`
clearing both during [DR-021](/decisions/dr-021-location-delete-cascades.md)'s
cascade, which treats them symmetrically. So the question was genuinely open.

docs/08 §3.2 reads every schedule row **`FROM — ROOM`** then **`TO — RACK`**, and
`ScheduleEntry.roomId` already relies on it. Room is the *from* end throughout
the product, so this is the existing convention rather than a new one.

**The rejected alternative is the installer's own phrasing**, *"conduit runs
from the panel to the bedroom"*, which is how a person describes pulling it and
is a perfectly good sentence. It loses on cost: the same physical run would read
`FROM = room` on its cable rows and `TO = room` on its pathway, one table apart,
so *"which end is the wall"* would have two answers in one editor.

# Both surfaces produce the same entity

DR-032 §11.31.5 holds that *"one medium must not mean two things depending on
which box a person typed it into"*. The drop line had already shipped without
these fields, so it is **retrofitted in the same change**: two surfaces agreeing
on the name and disagreeing on the medium would satisfy the letter of DR-032 and
break its point.

# `+ Add pathway` sets neither, and that is not an inconsistency

The `[ Pathways ]` tab's button has no room and no medium to record, because
somebody pressed a button on a list rather than naming either. Inventing them
there is the failure DR-032 §11.31.2 already refused one field over. Nothing is
made required: a pathway with no medium and no room is legal, is what the button
produces, and prints the unknown dash in both columns.

# Scope

No scope change: CR-109 and DR-032 are implemented rather than amended. It is a
behaviour change to a shipped gesture on §11.31.7's terms, and the four starters
were **checked rather than assumed**: none types a conduit through a drop line,
so all four regenerate byte-identical.

# Citations

[1] canonical-decisions.md §11.34 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/commands/pathway_commands.dart`,
    `AddPathwayCommand.fromLocationId`
[3] `packages/rackmate_core/lib/src/structure/matrix_plan.dart`,
    `_planPathwayCell`
[4] Built at `2618272`
