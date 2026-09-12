---
type: Design Ruling
title: DR-155 — The Plan view's walkthrough clause is parked on M6, because the Pull Sheet does not print
description: >-
  The Plan view epic's exit criterion names the printed T1.01 and the printed
  Pull Sheet. There is no Pull Sheet in the exporter and never has been, so the
  clause could not have been discharged at any point in the epic's life. Parked
  on M6 under roadmap 8.9, on DR-027's seam, with M6's criterion gaining the
  walkthrough because a demonstration is not an export. The print itself does
  not move.
tags: [ruling, roadmap, exit-criteria, plan-view, pull-sheet, m6, dr-155, dr-027, dr-029, ac-054]
timestamp: 2026-09-11T00:00:00Z
ruling_id: DR-155
canon_section: "11.154"
status: ruled
---

Settled by the user on 2026-09-11, from *"defer 649 to M6"*, after this task
reported that the clause names an artifact the product cannot produce.

# The clause named somebody else's sheet

> A person who has never seen the building is handed the printed `T1.01` and the
> printed Pull Sheet, and locates every drop without asking a question.

`SheetRole` has four values and none is a Pull Sheet. The rows exist only as a
derivation, `SchedulePreset.pullSheet` sorted `roomThenPathway`, rendered on
screen by `ScheduleScreen`; `rackpal_export` never references `ScheduleView`;
and there is no tabular export either, `EXP-A` being DR-049's and unstarted.

**So no drill would have discharged it.** This is not a clause the Plan view
failed to reach.

# DR-027's seam, reaching a second criterion

[DR-027](dr-027-m3-owes-rows-m6-owns-sheets.md) gave M6 the Pull Sheet's
`SheetRole`, layout, initial boxes and page on 2026-08-09, with the reason that
applies here word for word: **a milestone cannot discharge a clause about a
sheet it does not own**, and reading one loosely enough to call it met is the
checklist-ticking roadmap §8.1 refuses.

The Plan view's criterion was written a month after that split and named both
artifacts anyway. That is the ordinary way a criterion goes stale: drafted
against what the product ought to have, while the seam saying otherwise lived
in a different ruling.

# M6 gains a clause, which DR-027 did not have to do

DR-027 found M6's *"all four starter projects export a complete set"* already
contained the sheet. **A walkthrough is a demonstration and not an export**, so
nothing in M6's criterion contains one. Saying so is the difference between a
park and a deletion: a clause moved to a milestone whose criterion does not
mention it is a clause nobody will run.

# The print does not move

`PLAN-J/1` and `PLAN-J/2` keep every physical obligation: a real plan and a real
rough-in, a real greyscale laser at ANSI B, and every callout legible over the
screened underlay (AC-054). The stranger test moves because its second artifact
does not exist, not because it is inconvenient.

**Related:** [DR-027](dr-027-m3-owes-rows-m6-owns-sheets.md) ·
[DR-029](dr-029-plan-view-in-v1.md) ·
[DR-049](dr-049-tabular-exports-and-a-label-that-is-not-a-sheet.md)
