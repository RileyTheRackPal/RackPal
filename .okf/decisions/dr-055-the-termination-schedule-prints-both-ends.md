---
type: Design Ruling
title: DR-055 — The Termination Schedule prints both ends, because it already prints both ends of everything else
description: >-
  Filed as "the sheet and the editor disagree about what TERM means". The census
  found something larger: the rack termination reached no printed output at all,
  on the one sheet that is filtered, sorted and grouped by rack.
tags: [ruling, m3, m6, sheets, termination, g4, dr-027, dr-046, dr-055]
timestamp: 2026-08-13T00:00:00Z
ruling_id: DR-055
canon_section: "11.54"
status: ruled
---

Settled by the user on 2026-08-13, closing board #679 and answering the
inconsistency [DR-046](/decisions/dr-046-rack-end-is-its-own-termination.md)
§11.45.5 **filed rather than hid**. It discharges that clause and supersedes
nothing.

# The task understated its own finding

#679 reads *"the sheet and the editor now disagree about what `TERM` means"*.
True, and the smaller half.

**`StructureOrigin.terminationRack` reaches no printed output anywhere.** Its
only consumer in the tree is the editor's own column. `rackmate_export` contains
not one reference to any schedule column, and the derived schedule layer names
the field end alone.

And it is missing from the one sheet built around the rack: `buildScheduleView`
drops every row where `!row.landsInRack` for this preset, sorts
`rackThenPanelThenPort`, and groups by rack. **The Termination Schedule is a
rack-side work order that cannot state the rack-side termination**, which is a
sharper defect than a column with a stale name.

See [census the field, not the name](/practices/census-before-building.md): the
task named a symptom, and printing the field over the whole export layer named
the disease.

# The argument was already on the sheet, about its other columns

docs/08 §3.3's twelve columns print **both ends of every other fact**:

| Fact | Rack end | Field end |
|---|---|---|
| Identity | `RACK LABEL` | `FIELD LABEL` |
| Location | `RACK / RU / FACE` | `FAR END` |
| Port | `PORT` | `FAR PORT` |
| Termination | *(nothing)* | `TERM` |

**Termination is the only per-end fact the sheet collapses into one column**, and
§3.3's rule-weight grouping files it in the *spec* block beside `MEDIA`, as
though it were a property of the cable rather than of an end.

DR-046 ruled that exact collapse wrong **in the model**, where one field served
two columns and a speaker run with a phoenix at the panel was inexpressible. The
sheet carried the same collapse and nobody had carried the argument across. That
is the shape DR-053 named: **a rule already argued for one entity is evidence
about its neighbours.**

# The ruling

`TERM` becomes **`FIELD TERM`**, and **`RACK TERM`** joins it. Thirteen columns.

`FIELD TERM` keeps the existing chain including its
`PlaceEndpoint.intendedTermination` fallback. **`RACK TERM` has no fallback**,
because DR-046's whole content is that nothing infers one end from the other.

## The width arithmetic, from the sheet's own rule

690 pt, ANSI A landscape, fully allocated. §3.4 already names the donor order for
a column that has to fit: *"width is taken from `CONDUCTOR / NOTES` first, then
`MEDIA`"*. Both are used and nothing else moves.

| Column | Was | Now |
|---|---|---|
| `MEDIA` | 56 | **42** |
| `TERM` | 52 | retired |
| `FIELD TERM` | | **44** |
| `RACK TERM` | | **44** |
| `CONDUCTOR / NOTES` | 66 | **44** |
| **Σ** | **690** | **690** |

## An unknown end never inherits the other one

[G4](/invariants/g4-unknowns-are-counted.md) in the place it is cheapest to get
wrong. A run terminated at the plate and not yet at the panel prints its field
type and `—` beside it. Copying the field value across would reproduce **on
paper**, where it is hardest to correct, the defect DR-046 removed from the
model.

# Two alternatives refused, with reasons

**One cell carrying both ends** (`T568B › 110 A03`) keeps twelve columns and
needs no arithmetic. It fails on the measurement: 52 pt at `RackMono` 7 does not
hold two tokens, `F BARREL › F BARREL` overruns, and the header would have to
teach a reading order.

**`TERM` meaning the rack end** costs one line and no layout, and **reverses the
defect rather than resolving it**: the field end would then print nowhere, which
is today's complaint with the ends exchanged.

# The two-visit objection, put and overruled

A field end is terminated at trim-out and a rack end at rack build, weeks apart
and sometimes by different people. That is a real argument for two documents and
it was put to the user explicitly. **One sheet was ruled.** The sheet is the
cable's record and already serves both readers for labels, locations and ports;
a second sheet is a new `SheetRole` under DR-049 and buys nothing this one cannot
carry.

Recorded because the objection is sound and was **overruled on trade grounds
rather than missed**, which is the same instrument that corrected two of three
recommendations in DR-048.

# Who builds it

§11.26.4 splits it: *"the derivation is the load-bearing half and it stays in
M3"*, meaning sorted rows, subtotals and G4's counts. **A column set carrying
`header` and `widthPt` is presentation**, so the constant and the page are
**M6's under DR-027**. Board #693.

**The derivation was already done before this was asked**: both fields exist,
both round-trip, and the editor populates both. And **nothing renders this sheet
today**, so there is no printed page to re-lay and no drift to fear while the
constant waits.

# Citations

[1] canonical-decisions.md §11.54 (`docs/canonical-decisions.md`)
[2] docs/08-pdf-export.md §3.3, edited to match rather than pointered
[3] `packages/rackmate_core/lib/src/derived/schedule.dart`,
    `kTerminationScheduleColumns` and `_terminationOf`
[4] [DR-046](/decisions/dr-046-rack-end-is-its-own-termination.md), the ruling
    this discharges a clause of
