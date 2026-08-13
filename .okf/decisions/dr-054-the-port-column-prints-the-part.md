---
type: Design Ruling
title: DR-054 — The PORT column prints the number on the part
description: >-
  A rendering change rather than an allocation change, because Port.designator is
  stored and changing allocation would leave one document holding two conventions.
  Also: the task's own vocabulary was re-assigned underneath it by a later ruling.
tags: [ruling, schedule, designators, dr-040, dr-046, cr-042, dr-054]
timestamp: 2026-08-13T00:30:00Z
ruling_id: DR-054
canon_section: "11.53"
status: ruled
---

Settled by the user on 2026-08-13, closing board #667. It **discharges an open
item [DR-040](dr-040-a-drop-lands-on-a-panel-port.md) named** rather than
superseding anything.

# The task's title is wrong, and a later ruling made it worse

#667 is filed as *"`RACK TERM` and `RACK LBL` name one hole two ways"*. **There is
no `rackTerm` column**: `ScheduleColumnId` has `port` and `term`. And
[DR-046](dr-046-rack-end-is-its-own-termination.md) has since given "rack term" a
specific, entirely different meaning, the rack-end termination type.

So a reader picking the task up today looks at the termination columns, finds them
correct, and is lost. The two columns that describe one hole are **`PORT` and
`RACK LBL`**.

This is [re-read a task against canon](/practices/re-read-a-task-against-canon.md)
in a sharper form than that practice records. There, tasks were stale because a
ruling answered their question. Here **the task's own vocabulary was re-assigned
underneath it**, so the words still parse and point somewhere else.

# What each column prints

| Column | Renders | Source |
|---|---|---|
| `RACK LBL` | `1A-PP-101` | `panelPositionToken` → `PortDef.label`, the silkscreen |
| `PORT` | `J04` | `Port.designator`, from `portDesignatorFormat` = `J{PORT_SEQ:2}` |

`PORT_SEQ` counts the **front** jacks a drop never touches, so on a
three-up/three-down fixture the hole labelled `01` is designated `J04`. One sheet,
two numbers, one position, and a tech on a ladder has to know which is which.

# The ruling, and why reuse is the argument

`PORT` renders the position token. `panelPositionToken` is reused rather than a
second rule written, and **the reuse is the whole case: it already falls back to
the designator when a template authors no label.** So the change is uniform rather
than special-cased. A panel port prints `01`; an ordinary device port still prints
`J09` exactly as now; `farPort` gets it for free through the same `portCell`.

# The deeper fix was available and is refused on a cost its own comment omits

`bind_endpoint_command.dart` names the alternative: teach designator **allocation**
to honour an authored label, *"which is its own ruling and touches the connect
gesture's output for every device in the catalog."*

That undersells it. **`Port.designator` is stored project state**, unique within a
device (CR-042). Changing allocation changes what **new** ports get and leaves
every already-materialised port carrying what it was given, so **one document would
hold `J04` on ports bound last week and `01` on ports bound today**, with no
migration able to reconcile them without rewriting identifiers other entities
reference.

**A rendering rule has no such tail.** That asymmetry, not the size of the diff, is
why the cheap fix is also the right one here.

# What it costs, stated rather than glossed

The allocated designator now appears on **no sheet**. `Port.designator` is visible
only in the app.

That is the right side of the trade because it identifies a `Port` **to the
software and not to a person on a ladder**: CR-044's own worked example is
`1A-A12`, a position number, and nothing an installer holds is silkscreened `J04`.
It is written down because the next person asking *"where did the port designator
go"* deserves an answer rather than a surprise.

# Discharge, not supersession

DR-040 §11.39.8 is a *"what this does not fix, stated so nobody reads it as
fixed"* clause. Answering it leaves DR-040 intact, exactly as §11.30 discharged
DR-020 §11.19.4, so there is **no §12 entry**. A reader of §11.39.8 follows the
pointer here rather than inferring an amendment.

**It is not #679**, which is the `TERM` column meaning the field end on a sheet
whose editor now distinguishes both ends, and which DR-027 parks on M6.

# Citations

[1] `docs/canonical-decisions.md` §11.53
[2] `packages/rackmate_core/lib/src/commands/bind_endpoint_command.dart`
[3] `packages/rackmate_core/lib/src/derived/schedule.dart`, `portCell`
