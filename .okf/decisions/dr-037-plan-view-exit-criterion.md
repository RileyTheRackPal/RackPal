---
type: Design Ruling
title: DR-037 — The Plan view's exit criterion, and the four questions decomposition had to answer first
description: >-
  DR-029 left the epic's contents and its exit criterion to decomposition. The
  criterion is a stranger finding every drop from a printed set. Three of the
  four decisions came out of reading code that contradicted the design: a field
  two rulings spend and nothing built, an alpha path nobody had named, and a
  switch left exhaustive on purpose so this day would break the build.
tags: [ruling, plan-view, exit-criterion, decomposition, g4, cr-117, dr-037]
timestamp: 2026-08-10T12:00:00Z
ruling_id: DR-037
canon_section: "11.36"
status: ruled
---

Settled by the user on 2026-08-10, discharging board #589 (`PLAN-0`).
[DR-029](/decisions/dr-029-plan-view-in-v1.md) §11.28.10 left the epic's
**contents and its exit criterion** to decomposition rather than to the ruling,
and §11.28.8 required [DR-026](/decisions/dr-026-two-interim-m3-answers.md)'s two
provisional M3 positions to be re-read here.

# The criterion, and the one clause that carries it

> An architect's floorplan PDF is imported **without leaving the app**,
> calibrated from one known dimension, and the rack plus every drop of a real
> rough-in carries a pin. The project exports a sheet set whose `T1.01` places a
> callout for every pinned drop, each printing the designator its Pull Sheet row
> prints. **A person who has never seen the building is handed the printed
> `T1.01` and the printed Pull Sheet, and locates every drop without asking a
> question.** The set is printed on a real greyscale laser at ANSI B and every
> callout stays legible over the screened underlay (AC-054).
> `write(read(bytes)) == bytes` holds on the zip path across a write, a reopen
> and a second write, and a project with **no** underlay writes bytes identical
> to what the plain-JSON path writes today.

**The stranger clause is the criterion and the rest is scaffolding.** DR-018's
motivation is that the designer marks device locations as coloured dots in a
notes application and *"work is inevitably done incorrectly against them"*. A dot
in Notes is perfectly legible **to the person who drew it**; that is exactly why
it fails. Every other clause is checkable by a machine or by the author, and an
author cannot test legibility to somebody else.

# Three findings, none of them inferable from the design

**`Location.riseAllowance` does not exist.** DR-020 §11.19.2(1) and docs/15 §4.1
both spend it, and a grep over every `.dart` file returns zero occurrences. It is
added by this ruling. **Third instance of the shape**, after
`MediaTypeDef.maxLength` (canon §11.19.7, which was `maxRunLengthPassive` all
along) and `unknown` on `Placement` (§11.18.1). See
[two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md).

**`PdfImage(..., alpha: true)` writes an `/SMask`.** docs/08 row 9 forbids alpha
*"absolutely, with no exception"* and is written about `ExtGState`. Read out of
`pdf-3.13.0/lib/src/pdf/obj/image.dart`: a PNG underlay carrying an alpha channel
emits an alpha path into the document **without anybody calling
`setGraphicState`**. The rule's coverage was narrower than its wording, and the
first feature that could have broken it found out.

**`cable_footage.dart`'s `_isQuantity` was already waiting for this day.** Its
header records that the switch was left exhaustive with no default arm so that
*"the day it is added this file stops compiling and somebody decides, rather than
a bound silently joining a purchase."* It is the one place in this tree where a
future decision was booby-trapped into the build, and it worked.

# The four decisions

**Screening runs in the export backend, not at import.** §11.28.11 said
*"pre-composited at import, the way palette tints already are"*, and a palette
tint is composited at **definition** time, so that reading stores a washed-out
image and falsifies docs/15 §7. The prohibition it protected is met more
completely in the export path, and a screening percentage that lives in code can
be changed without re-importing every underlay in every user's project file.

**`planLowerBound` ranks below `roomEstimate`.** Because a bound is excluded from
the footage rollup, ranking it higher makes **the number an integrator orders
cable from degrade in proportion to how much of the job has been planned**. The
rank costs the bound nothing: `LEN-001` and `LEN-002` read it regardless of which
tier printed, so [DR-020](/decisions/dr-020-no-predicted-routes.md)'s asymmetry
survives intact. A plan proves a violation and never proves compliance.

**A multi-page PDF gets a page picker.** The electrical sheet is not page 1 of an
architectural set. First-page-only reinstates the manual conversion step DR-029
spent 2–3 weeks buying out, on the ordinary path rather than the exceptional one.

**The physical clause is the stranger walkthrough**, as a clause of the criterion
and not a follow-up.

# DR-026's two positions, confirmed

Both, and neither for the reason that made them provisional.

**`Pathway.designator` stays hand-entered.** A floorplan does speak to the
question and it speaks *for* manual entry: the plan is the **consumer** of a
designator, not a source of one, because the route is discovered rather than
designed.

**`Outlet.nominalRunLength`'s tier stands**, and DR-026's open half is answered:
a floorplan supersedes **none** of the four tiers.

# What it does not rule

Not the rasteriser, which `PLAN-D/1` picks against the tree. **It has since
picked PDFIUM** (2026-09-07): docs/13 D9 already contemplates vendoring pdfium
per platform for M8's preview, so the two become one vendoring problem paid once,
and `Windows.Data.Pdf` has no macOS answer at all. That is a note about what
happened next, not a widening of this ruling, which still does not rule it. Not
the rasterisation resolution, which `PLAN-D/3` settles with a measurement against
AC-006 and which is **still open**, blocked on a real architectural page rather
than on effort. Not the integrator's logo, which is
[DR-030](/decisions/dr-030-integrator-logo-in-v1.md)'s and lands in M6. Not
mobile: this ships to a desk and not to a technician on site.

**No cost is re-estimated.** DR-029's `L` at 9–13 weeks stands. A decomposition
that quietly re-priced the epic it was decomposing would be a scope amendment
wearing a task's clothes (roadmap §8.3).
