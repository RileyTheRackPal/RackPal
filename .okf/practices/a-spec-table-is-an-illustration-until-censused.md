---
type: Practice
title: A specification table is an illustration until you census it against the model
description: Four M4 tasks in a row were written from a derived document's table, and all four found the table was examples. The port grid's named nine columns with no field and missed eight fields with no column.
tags: [practice, corpus, census, data-model, m4-e]
timestamp: 2026-08-15T00:00:00Z
status: adopted
---

`docs/00`–`14` are **priority-3 derived documents**. They argue, they cite
rulings, they record what was rejected, and their tables are written to
make a point rather than to be implemented line by line. Reading one as a
work list is how a task turns into an argument with the model.

# The evidence, four for four

Every M4 task so far was written from a field's or a type's absence, and
every one turned out to be partly a corpus question:

| Task | The table said | The model said |
|---|---|---|
| M4-A | Required fields contradict | A Dart constructor, read as a product rule |
| M4-B | `genderApplies` is missing | A complete transcription, already in canon §6.3 |
| M4-C | §7.2's change-class table is the spec | Examples; the rule had to be derived |
| M4-E | §4.5 lists the pack columns | Nine have no field; eight fields have no column |

M4-E's census is the sharpest. docs/06 §4.5 names `VLANs`, `Segment`,
`Address`, `Universe`, `Receptacle`, `Outlet mode`, `Seq step`,
`Seq delay` and `Circuit`, and **`PortDef` has no field for any of them**.
Building those cells means inventing model fields inside a grid task, or
shipping controls that write nowhere. In the other direction the model
carries `balanced`, `conductorCount`, `maxCurrentMa`, `channelIndex`,
`bus.protocol`, `bus.addressable`, `power.drawWatts`,
`carriedProtocols` and `acceptedFamilies`, and **the table names none of
them**: nine fields that have round-tripped through the codec since M0
with no way to author them.

# The check

Before estimating a task written from a table in `docs/00`–`14`, walk the
table against the model **in both directions** and write the result into
the source file. Both directions matter and they fail differently:

* A **named column with no field** is a decision the task cannot make. It
  belongs to whoever owns the model, and building it anyway is either a
  fabricated field or `a modelled field is not a reachable one` in
  reverse: a control with nothing behind it.
* A **field with no column** is usually the more valuable find, because
  nothing complains about it. It serialises, it round-trips, it appears
  in a diff, and no surface can produce it.

The census belongs in the code rather than in a commit message. M4-E's
sits in a comment above the column enum, so the next person to open that
enum reads why it is not §4.5's list before wondering.

# What this is not

It is not a reason to distrust the corpus. `docs/06` was right about
every ruling it cited and right about the shape of the grid; it was
illustrating a table, and an illustration with nine plausible-sounding
entries is indistinguishable from a specification until somebody checks.
**The normative documents are `canonical-decisions.md` and the rulings in
it.** A table in a derived document is evidence of intent, which is
exactly what `two documents agreeing is not verification` already says
about citations.

# Citations

[1] `packages/rackpal_core/lib/src/builder/port_table.dart`
[2] [census before building](census-before-building.md)
[3] [two documents agreeing is not verification](two-documents-agreeing-is-not-verification.md)
[4] [a modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md)
[5] [re-read a task against canon before pricing it](re-read-a-task-against-canon.md)
