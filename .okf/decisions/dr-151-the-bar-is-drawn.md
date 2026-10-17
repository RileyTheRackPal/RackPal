---
type: Design Ruling
title: DR-151 — The bar is drawn, the uncalibrated sheet says so itself, and a placeholder reached a deliverable
description: >-
  PLAN-H/1 printed "PLAN SCALED TO FIT - SEE BAR" on T1.01 with no bar on the
  page, and the gate that exists for unbuilt copy scans the app packages and
  cannot see a sheet string in core. The brief's plan for the uncalibrated case
  routes through PLN-001, which is a finding the person holding the print does not
  have, so the sheet says NOT TO SCALE - PLAN NOT CALIBRATED itself. The bar is
  alternating segments with the ends labelled, and its length is never refused for
  scale.
tags: [ruling, plan-view, pdf-export, scale, gates, copy, g4, dr-151, dr-149, plan-h]
timestamp: 2026-09-09T00:00:00Z
ruling_id: DR-151
canon_section: "11.150"
status: built
---

Settled by the user on 2026-09-09 at `PLAN-H/4`'s census.

# A placeholder reached a client deliverable

`PLAN-H/1` shipped `kPlanSheetScaleNote = 'PLAN SCALED TO FIT · SEE BAR'` on
`T1.01`, and there was no bar. It was written as a forward pointer to the next
chapter and it printed as an instruction to a reader.

`unbuilt_copy_accuracy_test.dart` exists for exactly this failure and its own
header says so: *"the app's honest-absence copy is a factual claim about this
codebase, so it is tested against this codebase."* **It scans `rackpal_ui` and
`apps/rackpal`**; a sheet string lives in `rackpal_core` and is invisible to it.

Fifth instance in this epic of
[a gate's scope being part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md),
and **the first where the missed surface is printed**. In-app copy is wrong until
somebody clicks away; a sheet is wrong in a folder on a job site. Nothing
referenced the constant either, so removing it broke no test.

# PLN-001 does not reach the person holding the sheet

`#643`: *"an uncalibrated underlay gets no scale bar at all, not a bar with a
guessed figure on it. G4, and `PLN-001` is what tells the user why."*

`PLN-001` is a **finding**. It lands in the validation drawer and, at M6, on
`T0.02 Exceptions and Acknowledgements`. **The person holding the printed `T1.01`
has neither**, and `SheetRole` has four values today, none of them `T0.02`. The
half of the brief that is right is that no bar may be drawn; the half that does
not work is who explains it.

Ruled: the sheet says it itself.

> `NOT TO SCALE · PLAN NOT CALIBRATED`

`NOT TO SCALE` is the part that matters to that reader, because it names the one
thing they must not do with the page, and the plan still locates every drop: pins
and callouts work uncalibrated, which is docs/15 §1's first job.

**The full `PLN-001` sentence was the closest call.**
[DR-146](dr-146-uncalibrated-states-what-it-costs.md) §11.145.6 put that sentence
in core precisely so surfaces cannot drift, so reusing it was the consistent move.
But **its count is a designer's number**: `39 pins carry no measurable position`
tells the person at the desk what a calibration would buy, and the installer
holding the print can already find all thirty-nine.

# Alternating segments, ends labelled

Four equal divisions, filled and hollow alternating, `0` at the left and the round
total at the right.

**The alternation is the feature and not the decoration**: a plain rule can be read
only at its full length, a divided one at a quarter or a half. It survives
greyscale by construction, being black and paper rather than two greys, which is
the property AC-054's print and PAL-1 gate everywhere else.

# Never refused for scale

A ladder of round values in `ProjectSettings.displayUnits` (CR-097), largest that
fits a quarter of the drawing width. **When none fits, the smallest is taken
anyway**: a bar longer than its budget is still true, and a bar refused for being
awkward is a sheet with no bar on a plan that has a scale. The only refusal is the
uncalibrated one.

**A tie goes to the larger bar**, and the relative epsilon that allows it is not a
fudge: the drawn length is a double all the way down, a bar that exactly fills its
budget lands at `250.00000000000003`, and the budget is an aesthetic limit whose
last ulp nobody decided.

# What it does not rule

Not a north arrow, which has no field on `PlanUnderlay` to read. Not the per-plan
device schedule. Not the bar's type size as a final figure, which `PLAN-J`'s print
settles along with the callout's. And **not a gate for sheet copy**: the absence is
recorded and priced at nothing, because the honest scope of a new gate is a
question for whoever has met the failure twice rather than once.
