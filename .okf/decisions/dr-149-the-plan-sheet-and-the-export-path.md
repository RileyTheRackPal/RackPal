---
type: Design Ruling
title: DR-149 — The plan sheet's place in the set, how light it prints, and the export path that could not reach an underlay
description: >-
  PLAN-H/1's census found that ExportRequest carried no container members, so the
  exporter structurally could not reach an underlay and PdfImageResolver had zero
  production call sites from PLAN-A onward. A second exhaustive switch, this one by
  definite assignment, forces the slot to land with a sheet behind it. T1.01 sits
  after T0.02 and before the elevations, and the underlay prints at 25% with a
  laser rather than the ruling as the evidence.
tags: [ruling, plan-view, pdf-export, sheets, screening, gates, dr-149, dr-029, dr-037, plan-h]
timestamp: 2026-09-09T00:00:00Z
ruling_id: DR-149
canon_section: "11.148"
status: built
---

Settled by the user on 2026-09-09 at `PLAN-H/1`'s census. Two presentation calls
the corpus had deliberately left open, and one finding upstream of every chapter in
`PLAN-H`.

# The export path could not reach an underlay

`ExportRequest` carried `documentJson`, `fontBytes`, `fileName` and `issuedAt`. The
bytes live in `DocumentSession.members`, written by `adopt` and read by the Plan
editor, and `export_controller.dart` never passed them.

| Piece | State before `PLAN-H` |
|---|---|
| `DiagramCanvas.drawImage`, `ImageRef` | built at `PLAN-A` |
| `PdfDiagramCanvas.drawImage` | built at `PLAN-A` |
| `PdfImageResolver` | a typedef with **zero production call sites** |
| `ExportRequest.members` | **did not exist** |

**This is `PLAN-E/1`'s finding one package over.** That chapter found nothing
supplied a `FlutterImageResolver` and wrote `plan_image_cache.dart`, whose header
says *"a typedef with no implementation is a seam, not a feature."* The export
backend had been in the same state since `PLAN-A` and nothing noticed, because no
sheet asked for an image. `T1.01` is the first caller, and the screen's answer is
the model rather than a design question: load once, resolve synchronously, cache
per member. See
[a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md)
and [census before building](/practices/census-before-building.md).

# And three more exhaustive switches fired

[DR-147](dr-147-the-datum-is-the-runs-own-rack.md) met the deliberate one in
`cable_footage.dart` a day earlier. Adding `SheetRole.devicePlan` stopped the build
in three more places, none of them designed as a trap: `build_document.dart`'s
`switch (sheet.role)` assigning a definitely-assigned `final DiagramScene`,
`page_sizes.dart`'s switch expression over `SheetSize`, and two role canaries in
the suite.

**The first forces the chapter's shape.** `#640` reads as though the enum value
could land alone; it cannot, and a `case` drawing a frame over white paper would be
the *"title block over white paper"* docs/15 §7 already names as indistinguishable
from a plan with no drops on it. So the slot, the resolver, the screening and the
sheet land together, and `#641` keeps the evidence rather than the pass.

# T1.01 sits after T0.02 and before the elevations

Cover, Symbol Legend, Exceptions, **plans**, rack elevations, interconnect,
schedules, details.

**The order was a choice and not a consequence**, which is why it was put to the
user: docs/08 §2.2's table is not numeric, `T5.01` sitting last at `n+5`. The ground
is the job rather than the number: **a reader orients in the building before they
open a rack**, and it agrees with the NCS convention that puts `T1` plans ahead of
`T2` elevations.

*Last, beside `T5.01`* was refused despite a real argument (both are `AUTO`, and a
set whose page count moves in the middle is harder to collate). *Immediately before
the Pull Sheet* was the closest call: it couples the locator to the deliverable it
serves, and the set is ordered by drawing type rather than by errand.

# The underlay prints at 25%

One named constant in the export backend, so changing it is a one-line edit and
never a re-import, which is docs/15 §7's own reason for putting the pass there.

**25% and not 18%**, the legend chip's tint, because a chip is a swatch behind a
single rule and an architect's floorplan is line art whose walls, doors and
dimension strings must survive. **25% and not 40%**, because the callout has to win:
AC-054 requires every callout legible over the screened underlay, and PAL-1's own
exclusion block records this as *"the only new legibility question this palette has
met"*.

**THE HONEST HALF IS THAT NO NUMBER CHOSEN HERE IS EVIDENCE.** AC-054 sets the
standard as a print on a real greyscale laser at ANSI B,
[DR-148](dr-148-the-rasteriser-is-deferred-a-second-time.md)'s drill is where that
happens, and this ruling names it as the confirmation point. Moving the value
afterwards is expected rather than a defect.

# What it does not rule

Not the callout pill's geometry or colour, which is `PLAN-H/3`'s and which CR-078
already constrains to the signal **domain**. Not the leader-line rule, the scale bar
or the per-plan schedule. Not whether several underlays order by `PlanUnderlay.order`
or by location name: `order` is a `FracIndex` the user controls and every other
per-entity sheet sorts on it, so it is taken rather than decided.
