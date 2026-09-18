---
type: Design Ruling
title: DR-184 · A floorplan turns in quarter turns, saved on the plan
description: >-
  The Plan view could not rotate a floorplan, and the PDF lifter carried a page's /Rotate down the
  tree and never read it, so one PDF imported upright when rendered and sideways when lifted. A plan
  now carries rotationQuarterTurns, 0 to 3 clockwise, which the screen and T1.01 both follow, and a
  lifted page takes its turn from /Rotate. Stored coordinates never turn.
tags: [ruling, plan, canvas, pdf, import, rotation, dr-184, dr-144, dr-138, cr-086, cr-001]
timestamp: 2026-09-18T00:00:00Z
ruling_id: DR-184
canon_section: "11.183"
status: ruled
---

Ruled by the user on 2026-09-18 on board `#911`.

# The report, and the defect behind it

*"The floorplan view, for example, doesn't allow the rotation of floorplans."*

**Measured first.** `PlanUnderlay` carried no orientation, and `buildPlanScene` maps one image pixel
to one scene unit with nothing between them. That much was the report.

**The PDF lifter was the part nobody had reported.** `_inherited` in `pdf_page_lift.dart` copies
`/Rotate` from a parent page node alongside `/MediaBox` and `/Resources`, and then nothing reads it:
`LiftedPdfPage` has no field that could hold a turn, and the page picker previews the lifted bytes
as they stand. pdfium applies `/Rotate` before rendering. So a landscape sheet stored portrait with
`/Rotate 90`, which is how scanners and some plotters write one, **imported upright when rendered and
sideways when lifted**, and the importer prefers lifting.

# What was ruled

- **Quarter turns, saved on the plan.** `rotationQuarterTurns`, an integer 0 to 3, clockwise as the
  plan is seen, on `SheetItem.rotationQuarterTurns`'s precedent. The screen and the printed sheet both
  follow it (CR-086 is why there is no other option: one display list feeds both, and the bundle has
  no concept for CR-086 yet).
- Declined: **a free angle**, which resamples line art that
  [DR-137](/decisions/dr-137-a-floorplan-is-line-art.md) rules is what a plan is, leaves empty
  corners on the sheet and puts trigonometry through every pin. And **a view-only turn**, which would
  let the screen and the paper disagree.
- **The buttons live on the open plan's rail row**, beside `Calibrate…` and `Remove…`, which is the
  host [DR-144](/decisions/dr-144-a-calibration-carries-its-unit.md) §11.143.4 ruled for a property of
  a plan. **The keys are `Ctrl+Shift+Plus` and `Ctrl+Shift+Minus`**, which is what Acrobat and Bluebeam
  use, so the people who open these drawings every day already know them.
- **The view turns about the canvas centre and keeps its zoom.** Somebody zoomed into one room is
  still looking at that room.

# The implementation clauses

**A stored coordinate never turns.** Pins, calibration points and room outlines stay in image pixels
and the turn is an exact integer map applied where a pixel meets the scene. That makes the failure
of an older build the cheapest one available: it drops the field and shows the plan unturned with
every pin still on its drop. The reader version does not move.

**The file omits 0**, so no existing document changes a byte, and refuses anything outside 0 to 3
rather than normalising it.

**A lifted page takes its turn from `/Rotate`**, and the lifted bytes stay exactly what the PDF
embeds ([DR-138](/decisions/dr-138-lift-the-page-not-re-draw-it.md)). A `/Rotate` that is not a
multiple of 90 refuses the lift, and the page goes to the renderer like any other refusal.

# The menu error, recorded because it was chosen

The first question offered *"the Plan editor's toolbar"* as the buttons' host. **There is no such
toolbar**: docs/15 §6 rules three regions and *"no fourth region"*. The answer arrived in Acrobat's
vocabulary rather than this product's, and a borrowed convention brought its borrowed furniture with
it. It was caught before a widget was written, because the plan editor was read before the buttons
were, and the host went back to the user as its own question.

# What this does not rule

A north arrow, which still has no field. Mirroring. A free angle, which is declined rather than
deferred.
