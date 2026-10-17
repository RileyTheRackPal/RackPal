---
type: Decision
title: DR-061 — The port grid's selection is a row range and a focused column, and the tick box is that selection
description: docs/06 §4.6 describes the selection two incompatible ways and no M4-F task built either; a 2D cell rectangle would have been consulted by one of the table's fourteen operations.
tags: [m4-f, grid, selection, ux, decomposition-gap]
timestamp: 2026-08-15T00:00:00Z
ruling_id: DR-061
canon_section: "11.60"
status: ruled
---

The Device Builder port grid's selection is:

```text
selection := a contiguous run of rows, plus the rows Ctrl+click has added or removed
column    := whichever cell holds focus
```

Click selects. `Shift`+click extends from the anchor. `Ctrl`+click toggles one row.
The gutter checkbox toggles the same row in the same set. `Delete` acts on it,
unchanged from M4-E.

# The question, which was a word with no referent

docs/06 §4.6 tabulates the grid's editing operations and describes the thing they
all act on twice, incompatibly:

| Row | What it implies the selection is |
|---|---|
| `Fill down` | *"copies the top cell of the selection to every cell below it"*: a column of cells, with a top |
| `Multi-row edit` | *"select N rows, edit any cell"*: a set of rows |

A cell range and a row set are different objects. Building either one satisfies
half the table.

# The census: there was no selection at all

`port_grid.dart:175` holds `_ticked`, a `Set<String>` of port keys fed by a gutter
checkbox and read by exactly one thing, the delete button. No anchor, no focused
cell, no range, no painting of one.

**None of M4-F's five tasks built one.** Each was written from its own operation's
risk, and the selection was never in dispute, so it was never written down. See
[check a decomposition for holes](/practices/check-a-decomposition-for-holes.md),
whose input form this is, for the sixth time in this repository.

# Why not a 2D rectangle, which is what Excel does

The premise is real and stated in the corpus: docs/06 §4 says *"integrators live
in Excel"* and that every ergonomic they already know has to work. So the
rectangle was priced against §4.6's own table rather than against that sentence:

| What the operation needs | §4.6 rows |
|---|---|
| Whole rows, no column | `Multi-row edit`, `Duplicate`, `Delete`, `Reorder`, `Renumber…`, `Move to bank…`, `Copy / paste`, `Sort`, `Mirror bank` |
| Rows, and it **names its own columns** | `Fill series` (the label), `Change type…` (connector and family), `Find & replace` (a scope the dialog picks) |
| Rows, and **one** column from elsewhere | `Fill down` |
| One cell | `Edit cell` |

**A rectangle would be consulted by one row of fourteen, and that one wants a
single column rather than a range.** The three operations that look column-shaped
each carry their column in their own definition, so a selection cannot tell them
anything they do not already know.

The cost avoided is not notional: a selection painting layer, a keyboard model
crossing collapsed bands and sticky headers, and a partial-row TSV paste whose
meaning nobody has decided. That is [measure the control before choosing
it](/practices/measure-the-control-before-choosing-it.md) answered the wrong way.

**The Excel premise is honoured where it is load-bearing**, which is `Copy /
paste`: M4-F3's test is a whole bank copied out and pasted back, byte-compared on
the resulting `TemplateBody`. Whole rows are what round-trips.

# The tick box IS the selection

Two alternatives, both rejected on one ground. Keeping ticks and selection as
separate sets puts two highlight states on one row and makes every operation carry
a question about which set it reads: that gets reported as a bug rather than as
confusion. Deleting the tick boxes removes the grid's only affordance discoverable
without a modifier key.

Subsuming costs nothing and preserves something. A tick set is already
non-contiguous, so `Ctrl`+click needs no new state, and **M4-E's delete tests keep
their meaning exactly**, because the set they act on is the same set renamed.

# What it does not decide

The selection is a view concept. Nothing here reaches `TemplateBody`, the codec or
`kSchemaVersion`, so [CR-117](/invariants/cr-117-byte-exactness.md) is untouched.

It says nothing about the Structure editor's table, which has the same unanswered
question and no ruling. When that surface grows one, this is the precedent to argue
from and not a rule it already obeys.

# Citations

[1] canonical-decisions.md §11.60 (DR-061)
[2] docs/06 §4.6, the fourteen-row table this was measured against
[3] Board `#177`, and `#695`, the task this ruling created
[4] `packages/rackmate_ui/lib/src/builder/port_grid.dart:175`
