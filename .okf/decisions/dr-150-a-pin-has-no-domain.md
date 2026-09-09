---
type: Design Ruling
title: DR-150 — A pin has no domain, so a callout has no colour, and the screening turns PAL-1's open obligation into arithmetic
description: >-
  PLAN-H/3's brief asks callouts to reuse the schematic's tag pill and take the
  signal domain's colour. Neither exists: no pin carrier resolves a domain, and the
  pill is private to rackpal_ui which rackpal_export may never import. Ruled one
  uniform opaque black callout printing the carrier's own designator, never
  dropped, and PAL-1's open obligation over a non-white background is discharged by
  a number the gate recomputes from the screening constant.
tags: [ruling, plan-view, pdf-export, callouts, pal-1, gates, layering, dr-150, dr-149, cr-078, plan-h]
timestamp: 2026-09-09T00:00:00Z
ruling_id: DR-150
canon_section: "11.149"
status: ruled
---

Settled by the user on 2026-09-09 at `PLAN-H/3`'s census.

# The brief asked for two things that do not exist

`#642`: *"callouts carry the device designator and reuse the schematic's tag-pill
geometry and the signal domain's colour (CR-078: colour lives on the DOMAIN, never
the family)."*

**A pin carries no domain.** `Rack` holds nothing about signal, `Outlet` holds a
designation and a grade and no `SignalFamilyId` at all, and an off-rack device
spans several: a television is video **and** network. `plan_scene.dart` recorded
exactly this at `PLAN-E/2`, **one chapter after the brief was filed**. AC-054
prints the sheet greyscale in any case, so a hue chosen here reaches the person the
sheet is for as a grey.

**And the pill is in the wrong package.** `_PillSizer` is private to
`rackpal_ui/src/canvas/schematic/wire_trace.dart`, and `rackpal_export` may never
import `rackpal_ui`: the debt
[package layering](/invariants/package-layering.md) has recorded since 2026-07-28
as *"a violation in waiting"*. This chapter does not move a thousand-line file to
borrow ninety of them; it takes the **reasoning** and cites it at each site. See
[a brief expires](/practices/a-brief-expires.md).

# One uniform callout, opaque, black

A white-filled stadium, a black hairline outline, black text, masking whatever is
beneath it.

**The knock-out is not a contrast device.** Black on the darkest sample the
screening can leave is 11.5:1, so luminance was never the risk. **Dense line work
is, and it fails by pattern**: a dimension string crossing a designator is
unreadable at any ratio. Masking is what a callout bubble is for in drafting.
Carrier kind stays in the marker shape, where
[DR-140](dr-140-the-rack-is-pinned-from-the-unpinned-strip.md) already put the
rack-is-not-a-device distinction.

# It prints the carrier's own designator

`RK-1`, `WP-1`, `TV-1`. The exit criterion asks for *"the designator its Pull Sheet
row prints"*, and **a pinned outlet has several such rows**, because a row is a
`Link` and a drop can carry three cables. A cable designator is not a function of a
pin and would put three callouts on one dot.

A carrier whose designator is blank gets its marker and no pill:
[G4](/invariants/g4-unknowns-are-counted.md), because an empty pill is a white box
that says nothing.

# PAL-1's open obligation, discharged by arithmetic

`tools/pal1_check.py` carried `CALLOUT_OVER_UNDERLAY_IS_CHECKED_AT = 'PLAN-H/3'`
from `PLAN-A/5`, recording that the underlay's exclusion does **not** cover callout
glyphs against *"the first background in the corpus"*.

**It is decidable because the screening is a constant** ([DR-149](dr-149-the-plan-sheet-and-the-export-path.md)):

> callout over the screened underlay: black on 192 (ink retained 250 per-mille) is 11.54:1, floor 4.5:1

**Proven not vacuous by mutation**: 540 per-mille passes, 560 fails at 4.30:1, 700
fails at 2.48:1. The break-even is 550 and the shipped value carries a 2.2× margin.

**The gate parses the constant and never copies it**, on `registry_parity.py`'s
precedent for a Python gate reading Dart source. A second copy of a moving number
is a liability this corpus has swept five times, and a screening value in two
places would go stale the first time `PLAN-J`'s print moves it.

**canon §14.1 is why it is a number and not an eye.** PAL-1 shipped collisions
three times because the rule was *"checked by inspection"* and read at the domain
level rather than over rendered values.

# A ring of offsets, then a leader, and a callout is never dropped

Preferred offset; a fixed ring when that box overlaps one already placed; a leader
once it has moved, because having moved is exactly what *"cannot sit within its own
pin's clearance"* means. Deterministic, because `planPinsFor` already orders pins
totally.

**Twenty coincident drops all place clear and crowding starts at twenty-four**,
measured rather than argued. Past that the pill is drawn overlapping and the export
raises a notice naming how many: an absent callout is a drop the stranger cannot
find, an overlapping one is a drop they can read twice.

# What it does not rule

Not the leader's arrowhead, which the drawing does without. Not a north arrow,
which has no field to read. Not the scale bar or the per-plan schedule. Not whether
`wire_trace.dart` moves to core, which stays M6's and stays recorded. And not the
callout's type size as a final figure: it is a starting value and `PLAN-J`'s print
drill settles what is read at arm's length.
