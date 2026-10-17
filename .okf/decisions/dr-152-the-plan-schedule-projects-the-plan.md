---
type: Design Ruling
title: DR-152 — The plan schedule projects the plan's own derivations, and a cap drafted at 180 rows held 60
description: >-
  PLAN-H/5's brief says the per-plan schedule projects the derivation the
  equipment list already uses, and EquipmentList is one row per DeviceInstance:
  a plan pins three carriers and two of them are not devices, so on a rough-in
  the named source holds a minority of the rows. It projects planPinsFor and
  planPinLabelsFor instead, which makes the reference column literally the string
  the callout prints. Ruled three columns on a drafted cap of "roughly 180 rows",
  measured 60, and amended the same day to four blocks and a cap of 80.
tags: [ruling, plan-view, pdf-export, schedules, derived, cr-107, g4, dr-152, dr-037, plan-h]
timestamp: 2026-09-09T00:00:00Z
ruling_id: DR-152
canon_section: "11.151"
status: built
---

Settled by the user on 2026-09-09 at `PLAN-H/5`'s census, and amended the same
day on a measurement.

# The derivation the brief names holds none of the rows

`#644`: *"It is a PROJECTION of the derivation the equipment list already uses,
not a second table builder."*

**`EquipmentList` is one row per `DeviceInstance`** and its own header says so. A
plan pins three carriers (docs/15 §3.4) and **two of them are not devices**: an
`Outlet` and a `Rack` appear in that derivation nowhere at all. On the rough-in
the exit criterion describes, outlets are most of what is pinned, so the named
source holds a minority of the rows.

Fourth of `PLAN-H`'s five briefs to describe a tree that has since moved, after
`#640`, `#642` and `#643`. See
[a brief expires](/practices/a-brief-expires.md).

**The principle behind the pointer is right and is CR-107's.** Two entities
carrying the same facts *"is guaranteed to diverge within one week of real use:
the drop schedule says 78 ft and the wiring schedule says 90 ft, and nobody knows
which to bill against."* What satisfies it is projecting the derivations the
**plan** already has.

# Ruled by construction: it projects the plan's own derivations

The row subject is a **pinned carrier**, and `PLAN-H/3` already built that set:
`planPinsFor` enumerates it and `planPinLabelsFor` resolves what each one prints.

**The reference column is therefore literally the string the pill prints.** A
reader going from a callout to a row cannot meet two spellings of one designator,
which is the failure a second enumeration produces on the day somebody changes a
fallback. Every other column reads whichever derivation owns that carrier:
`computePlateFill` for an outlet, `EquipmentRow` for a device, the rack's own
height for the rack.

# Every callout resolves, the rack included

A reader who finds `RK-1` on the plan and nothing in the table beneath it has hit
the one dead end this sheet exists to prevent, and the rack is the thing a
stranger needs to find first. It costs one row.

*Drops only* was refused although it is truer to the sheet's name. *A rack row
set apart in its own band* was refused for adding a grouping concept to a table
that has none.

# The cap was drafted at 180 rows and held 60

The clause was ruled **three columns**, and called the overflow past the cap
*"expected never to fire"* on a drafted claim that three columns held *"roughly
180 rows"*.

**It held sixty**, which is DR-037 §11.36.1's own rough-in (AC-048). The
arithmetic multiplied rows-per-block by blocks in the wrong direction, and the
number reached a normative clause without ever being run. The last resort fired
on the sixty-first drop of an ordinary house.

Measured on the real `T1.01` drawing area, 1122 x 567 pt:

| Blocks | Block width | Cap | Plan keeps at 60 rows | DESCRIPTION |
|---|---|---|---|---|
| 3 | 365 pt | 60 rows | 313 pt | 37 characters |
| 4 | 270 pt | 80 rows | 373 pt | 27 characters |

Amended to **four blocks**. The band takes what it needs, so four blocks give the
**plan** more of the sheet at every row count and not less: sixty rows is fifteen
rows down rather than twenty. What narrows is the fields, and those are already
`PLAN-J`'s print to settle.

*Raise the ceiling to 0.55 of the drawing area* would have capped at 72 and
changed nothing at sixty rows or fewer, but past 68 the table takes more than
half the sheet and the plan becomes a strip. *Leave the cap at sixty and correct
only the prose* was refused because a cap standing exactly on the criterion omits
a row from the scenario it was measured against.

**It was found by mutation testing rather than by review.** The number sat in a
ruling, a file header and an export comment, three copies agreeing with each
other, and nothing disagreed until a test was asked to name the row at which the
band starts omitting. See
[a normative number is still a measurement](/practices/a-normative-number-is-still-a-measurement.md).

# What this does not rule

Not the column widths as final figures, which are `PLAN-J`'s print to settle
along with the callout and bar type sizes. Not a per-plan footage or count strip.
Not whether `T6.30`'s equipment list should gain outlet rows, which is a question
about that sheet and is M6's.
