---
type: Design Ruling
title: DR-029 — The Plan view ships in v1, before M6, with PDF rasterisation
description: The first scope amendment that makes v1 larger rather than smaller. Supersedes DR-018 point by point, and sequences the feature before M6 because M6's criterion would otherwise have to be demonstrated twice.
tags: [ruling, scope, plan-view, v1, sequencing, dr-029]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-029
canon_section: "11.28"
status: ruled
---

Settled by the user on 2026-08-09. A scope amendment under roadmap §8.3, and
**the first one that makes v1 larger** rather than smaller or merely rearranged.
The user's reason: *"development has been exceptionally fast and I feel like it's
an important feature to have."*

# The ruling

The Plan view leaves roadmap §2.2 and joins §2.1. It is **v1**, it is sequenced
to be **finished before M6**, it ships **with PDF rasterisation**, and it gets
**its own board epic rather than a milestone number**.

# What it supersedes, listed one by one so nothing is left half-true

| DR-018 said | Now |
|---|---|
| The Plan view is **v1.1** | **Superseded.** It is v1. |
| Placement is **conditional** on the underlay carrier shipping | **Moot.** DR-019 answered the carrier. |
| *"Nothing is added to v1 by this ruling"* | **Superseded.** This ruling adds it. |
| *"This does not enter §12.7's totals"* | **Superseded.** §12.7 is re-costed. |
| *"Nothing is scheduled. No board item."* | **Superseded.** An epic exists. |
| Reevaluation **by condition, not by date** | **Discharged.** This is its outcome. |
| *"The Plan view does not displace M3"* | **Reaffirmed, unchanged.** No M3 task is cut. |

# Before M6 is structural, not a preference

The feature includes *"a plan sheet in the set"*, and M6's exit criterion is that
**all four starter projects export a complete set**. A Plan view landing
afterwards would have M6 declared met over a sheet set about to gain a sheet, so
**M6's criterion would have to be re-demonstrated**.

The same seam is already carrying weight in that direction:
[DR-027](/decisions/dr-027-m3-owes-rows-m6-owns-sheets.md) put the Pull Sheet's
rendering in M6 the same day, and #574 parks AC-018's PRINTS clause there. **M6
is the milestone where sheets become real**, and everything owing it a sheet must
precede it.

# An epic, not a milestone number

Renumbering M6→M7→M8→M9→M10 would rewrite every `M6-A1`-shaped task title,
docs/12 §5.3–§5.8's headers, §12.7's table, and dozens of canon and roadmap
references including AC-058's print matrix. The board already carries **two
non-numbered v1 epics** (DR-009's macOS, and the Store), so the precedent is the
project's own. The sequencing is a stated dependency, not a number.

# PDF rasterisation is a deliberate purchase of 2–3 weeks

Floor plans arrive from architects as PDF, and a raster-only import would put a
conversion step on the **ordinary** path rather than the exceptional one.
DR-018's own levels: 5–7 weeks minimum viable, 7–10 raster-only, **9–13 with PDF
rasterisation on both platforms**. The last is chosen.

`docs/13` gains an entry, and DR-018 predicted this exact one. The likely
rasteriser is **pdfium**, which the debt register already discusses at D9 for a
different reason, so the two should be costed together rather than twice.
Incidentally corroborated while committing the DR-007 drawings: those PDFs are
vector with text converted to outlines and `pypdfium2` is what renders them.

# `DiagramCanvas` gains a `drawImage` op in v1

This is the ruling that does it, and RJ-017's §12 row is amended to say so.

**One consequence NOT ruled here.** RJ-017 rejected the integrator's logo partly
because a raster asset *"reopens the container question"*. DR-019 answered the
container and this ruling ships raster handling, so **that ground is gone and the
logo would now be cheap**, but RJ-017 is not reversed by a ruling that never
considered it, and anyone who wants it should ask directly rather than collect it
as a side effect. They did, the next day:
[DR-030](/decisions/dr-030-integrator-logo-in-v1.md).

# What does not change

**G4 is untouched.** A plan yields a measured horizontal distance and **never a
route**; [DR-020](/decisions/dr-020-no-predicted-routes.md)'s *"the route is
discovered, not designed"* stands in full. A plan-derived length remains an
estimate under AC-024 unless a human marks it measured, and AC-024's per-room
number remains the source that ships. **Mobile editing stays v2** (AC-056), so
shipping this does not by itself put a plan in a technician's hands on site.

# Cost

**§12.7 re-costed: 44–67 becomes 53–80 weeks**, and M1, M4 and the Plan view are
the three `L` items where §12.7 named two. The weeks are the auditable number.

# Citations

[1] canonical-decisions.md §11.28 (`docs/canonical-decisions.md`)
[2] docs/15-plan-view.md, the design
[3] `docs/research/feasibility-plan-view.md`, the costing
[4] docs/13-macos-debt-register.md, D9 and the rasteriser entry
