---
type: Design Ruling
title: DR-148 — The rasteriser is deferred a second time, and the debt is wired into the exit criterion
description: >-
  DR-145 booked a review of the vendored-pdfium deferral for PLAN-H because T1.01
  would be the first thing needing an underlay RENDERED rather than STORED. That
  reason does not survive the census: a PDF page is lifted to PNG or JPEG at
  import, so T1.01 renders a stored raster and is not blocked. The review was held
  anyway; the deferral stands a second time, and the new trigger is PLAN-J's drill
  bound to the CAD plot, so the epic cannot close until the rasteriser exists.
tags: [ruling, plan-view, pdf-import, deferral, exit-criterion, dr-148, dr-145, dr-029, plan-h]
timestamp: 2026-09-09T00:00:00Z
ruling_id: DR-148
canon_section: "11.147"
status: ruled
---

Settled by the user on 2026-09-09 at `PLAN-H`'s census.
[DR-145](dr-145-the-second-plan-set-is-all-vector.md) §11.144.5 named `PLAN-H` as
the review point for a vendored pdfium, on the ground that *"a deferral with a
fired trigger and no review date is how a debt stops being visible."*

# The stated reason does not survive the census

DR-145 chose `PLAN-H` because *"`T1.01` is the first thing in this product that
needs an underlay **rendered** rather than **stored**, so the chapter that builds
it is the first one whose own work is blocked by the absence."*

**`T1.01` is not blocked.** `PlanUnderlay.format` is `png | jpeg` by construction
and has been since `PLAN-C`; a PDF page is **lifted** to one of those at import
([DR-138](dr-138-lift-the-page-not-re-draw-it.md)) and the member written to the
container is a raster. So what `T1.01` renders is a stored PNG or JPEG, which
`DiagramCanvas.drawImage` and `PdfImage` have both handled since `PLAN-A`.

**The rasteriser is an IMPORT gap and not a RENDER gap**, and it belongs beside the
importer rather than beside the sheet.

# The review was held anyway

Skipping a scheduled review because its stated reason turned out to be wrong is a
deferral with no review date, arrived at from the other side. What changed is the
answer's shape rather than its timing.

# The deferral stands, and the second one is said out loud

Nothing displaces `PLAN-H`, `PLAN-I` or `PLAN-J`. The route is unchanged and is
still not `pdfrx`: a direct FFI binding over a **vendored** pdfium, per CR-100.

**Two deferrals with one trigger between them is the shape a permanent omission
takes when nobody counts**, so the record says "second".

# The new trigger is the exit criterion

`PLAN-J`'s drill is bound to **the CAD plot**, DR-145's three-page all-vector set,
rather than to whichever of the two real sets happens to import. **The epic cannot
close until the rasteriser exists.**

That is a stronger instrument than a review point: a review can be held and
deferred again, and an exit criterion cannot be met by deciding to meet it later.

**AND IT ADDS NO SCOPE.** The criterion already says *"an architect's floorplan PDF
is imported **without leaving the app**"*. A plot from CAD is one, it is the form a
drawing office produces without doing anything to it, and this product refuses it.
**The criterion has been unmeetable on that input since the day it was written**,
and nobody had noticed because the only set anybody had tried was the JPEG one.

# The drill's own risk, recorded rather than discovered

Put to the user with the deferral: `PLAN-J` run on the JPEG set would **pass**, the
exit criterion would read as discharged, and half of the real PDF inputs this
product has met would remain unimportable. A green drill would be evidence about
callouts and legibility that a later reader takes as evidence about import
coverage.

Binding the drill to the harder input removes that reading rather than annotating
it. DR-145 §11.144.4's *"half the ordinary path is bought"* stops being a note and
becomes a gate.

# What it does not rule

Not the resolution a rasterisation uses, which DR-145 §11.144.7 left open and which
is still owed by whoever builds it. Not the page picker's behaviour when every page
is refused. Not `PLAN-H`'s content, which is unaffected in every chapter. And not a
licence question: CR-100 governs the mechanism and
[DR-036](dr-036-public-gplv3-cc0-catalog.md)'s census covers the tree as it stands,
so a vendored pdfium reopens that census when it lands and not before.
