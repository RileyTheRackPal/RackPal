---
type: Design Ruling
title: DR-046 — The rack end is its own termination, and nothing infers it
description: >-
  Reported as "the rack termination shouldn't be automatically set by the field
  termination". It was worse: there was only one field, and both columns read it,
  so a speaker run with a phoenix at the panel was inexpressible.
tags: [ruling, m3, structure, termination, g4, dr-027, dr-043, dr-046]
timestamp: 2026-08-12T12:00:00Z
ruling_id: DR-046
canon_section: "11.45"
status: ruled
---

Settled by the user on 2026-08-12: *"the rack termination shouldn't be
automatically set by the field termination ... 90% of the time we'll have the
same termination on both ends for a CAT6, but a speaker run might have a phoenix
connector on the rack side, but binding posts on the other."*

# It was worse than automatic: there was only one field

`StructureOrigin.terminationField` is documented as *"how the WALL-PLATE end is
finished"*. `FIELD TERM` read it. **`RACK TERM` read it too**, by way of
`_terminationOf`. Two columns, one value, since M3-C.

The speaker run above was therefore not awkward to express, it was
**inexpressible**. And the column most people saw showed the other end's data,
because `RACK TERM` was a **default** column and `FIELD TERM` was **optional**.

`StructureOrigin` gains `terminationRack`, beside `terminationField` and
symmetrical with the `fieldLabel` / `rackLabel` pair that class already held.

# The 90% is the argument AGAINST a default

The user's own figure is that nine Cat6 runs in ten match at both ends.
**Defaulting on that basis re-creates the exact defect being removed**: a schedule
cannot then distinguish a value somebody stated from one the product copied. See
[G4](/invariants/g4-unknowns-are-counted.md).

**The convenience is a gesture instead.** `Rack term: same as field` on the batch
bar fills the column on the selected visible rows. It writes real values because a
person asked, it is one undo entry, and it **skips rows whose field end is
unknown** rather than copying *"nobody has said"* into a second column, which
would make the two agree for the wrong reason.

# A second colon on the drop line

`2x 16/4:binding post:euroblock`. Field first, rack second, and **one colon still
means the field end alone**, so every line written under
[DR-043](dr-043-field-termination-entry-paths.md) parses unchanged.

One vocabulary for both ends: a termination is a termination, and the end it is on
is which colon it followed. A bad rack token refuses the whole line with its own
caret.

# What is deliberately unchanged

**The printed Termination Schedule.** `ScheduleColumnId.term` still resolves to the
field end. That sheet is **M6's under DR-027**, and a twelve-column landscape sheet
gaining a thirteenth is a sheet change, which is exactly the class of work §11.26
moved out of M3. Filed as board #679. The editor is correct and the sheet is
unchanged, which is a **stated** inconsistency rather than a hidden one.

**`OutletDrop` gains no rack termination.** A template says what a recipe pulls and
how it lands in the room; what it lands on at the panel depends on which panel,
which is a fact about a job rather than about a recipe.

# Scope

**No scope change to roadmap §2.** One nullable field, one grammar production, one
column moved from optional to default, one gesture. `kSchemaVersion` does not
move: the key is omitted when null, and it is null on every home run ever written
because the field did not exist.

# Citations

[1] canonical-decisions.md §11.45 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.26 (DR-027), §11.42 (DR-043)
[3] `packages/rackmate_core/lib/src/model/structure_body.dart`
[4] `packages/rackmate_core/test/structure/drop_line_termination_test.dart`
