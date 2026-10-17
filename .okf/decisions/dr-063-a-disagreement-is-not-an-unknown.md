---
type: Decision
title: DR-063 — A disagreement is not an unknown, and the identity columns are not batch-editable
description: docs/06 §4.6 spells "these rows disagree" the same way the whole product spells "nobody has measured this"; and one label written across eight rows mints eight colliding keys.
tags: [m4-f, grid, batch, g4, cr-114, ux]
timestamp: 2026-08-15T00:00:00Z
ruling_id: DR-063
canon_section: "11.62"
status: built
---

Two corrections to docs/06 §4.6's multi-row row.

# `—` already means something

§4.6: *"mixed values render `—` and are left untouched unless explicitly
set"*. The second half is right and is enforced. The first half spells a
**disagreement** the way the product spells an **unknown**: `kUnknownCell`,
[G4](/invariants/g4-unknowns-are-counted.md), *nobody has measured this*.

Eight ports nobody has measured and eight ports carrying 75 Ω and 110 Ω are
different facts. An installer reading `—` on `IMPEDANCE` concludes the first
while the second is true, on the one surface built specifically for looking at
many rows at once.

**`—` keeps its single meaning. A disagreement reads `Mixed (N values)`.**

CR-114 states the same discipline for a document: a rollup **reports its unknown
count rather than fabricating a total**. This is that rule applied to a column of
N rows instead of to a project.

**An unknown among values is a disagreement**, counted as one of them. Three
ports at 75 Ω and five unmeasured is `Mixed (2 values)`, because calling it
either agreement or unknown fabricates.

# The identity columns are excluded

§4.6 says *"edit any cell, it applies to every selected row"*. `LABEL` and
`DESIG` are where that is almost never the intent and expensive when it is not:

| Column | What one edit across eight rows does |
|---|---|
| `LABEL` | eight ports called `HDMI IN`, and on a port created this session the key follows the label, so `autoPortKey` mints eight colliding keys suffixed `.2`, `.3`, `.4` |
| `DESIG` | eight duplicate designators, which the grid's validation dot then reports on every row |

**The capability is routed, not lost.** `Ctrl+Shift+D` writes a column of labels
and is the gesture designed for it ([DR-062](dr-062-fill-series-infers-its-sequence.md)),
so *"name all sixteen"* has a key that does not collide.

**A confirmation dialog was the rejected third option.** docs/06 §4's binding
premise is that any interaction costing one click per port is a design failure,
and a modal in the middle of the grid whose criterion is measured with a
stopwatch is that failure wearing a safety label.

# What made it implementable

`PortColumnFill` gained a type-erased `read` and `write`. Reading is the safe
direction, because return types are covariant. Writing is not, for the reason
[DR-062](dr-062-fill-series-infers-its-sequence.md) records: parameters are
contravariant, so `PortField<Object?>.set` throws before it is called. The cast
therefore lives **inside the closure**, at the switch arm where `T` is still
known.

Extension types make the failure silent rather than loud, so it is covered by a
test that walks **every** batch column, reads a port and writes the value
straight back, and asserts no command is produced. A column whose read and write
disagreed would fail there rather than in front of a user.

# Citations

[1] canonical-decisions.md §11.62 (DR-063)
[2] docs/06 §4.6's multi-row row, and §2's right dock
[3] `packages/rackmate_core/lib/src/builder/port_batch.dart`
[4] Board `#209`
