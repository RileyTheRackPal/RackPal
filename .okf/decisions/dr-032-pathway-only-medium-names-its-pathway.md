---
type: Design Ruling
title: DR-032 — A pathway-only medium creates a Pathway named for where it goes
description: CR-109 says such a medium creates a Pathway and never a Link, but not what it is called, and Pathway.name is required. The name is a description built from the room and the medium as typed, never PW-LR-1, because that is the allocated series DR-026 refused one field over.
tags: [ruling, m3, pathways, conduit, naming, cr-109, dr-032]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-032
canon_section: "11.31"
status: built
---

Settled by the user on 2026-08-09. `Living Room: 1x ENT` produces a `Pathway`
named **`Living Room ENT`**, with `kind` at its `conduit` default and
`designator` null.

# What it fills in

CR-109 rules that a medium with `isPathwayOnly` creates a `Pathway`, *"never a
`Link` and never a `Port`"*. It does not say what the pathway is **called**, and
`Pathway.name` is required. This supplies that.

**The count is real and is not a quantity field.** `2x ENT` is two smurf tubes,
and a `Pathway` has no quantity: two runs are two entities, exactly as two Cat6
drops are two `Link`s. Above one, the names carry a 1-based index
(`Living Room ENT 1`, `Living Room ENT 2`).

*This ruling's own first draft said "one `Pathway` per item"* and was written
from a worked example whose count was one. It was corrected before any code read
it, and the wrong phrasing is quoted in canon rather than replaced silently,
which is the discipline
[DR-028](/decisions/dr-028-keystone-cell-is-the-front-nose.md) applied to its own
withdrawn figure.

# Why a description and not `PW-LR-1`, which is the whole ruling

`PW-LR-1` matches docs/07 §4's wireframe, sorts, and looks like every other short
identifier in the product. **It is the thing
[DR-026](/decisions/dr-026-two-interim-m3-answers.md) §11.25.1 refused.** That
ruling made `Pathway.designator` hand-entered with *"no allocator and no
series"*, because manual is the reversible direction. A name minted `PW-LR-1` at
creation time would be that series, wearing the one field DR-026 deliberately
left alone.

A description cannot be mistaken for an identifier, so the two facts stay two
facts.

**The rejected alternative is naming it after the medium alone** (`ENT`), which
is simpler and is honest that nobody has named it. It fails on the Pull Sheet:
two conduits to two rooms would print the identical `PATH` cell, and telling one
run's route from another's is that column's entire job.

# Three surfaces, one meaning

§11.31.5 binds the drop-line DSL, the matrix column and the CSV importer alike:
**one medium must not mean two things depending on which box a person typed it
into.** The drop line shipped at `b093062` and the matrix column at `2618272`;
the importer does not exist yet (docs/07 §5).

That clause is what forced [DR-035](/decisions/dr-035-a-created-pathway-records-its-medium-and-room.md),
which found that this ruling had not said what ELSE the act records, and that a
matrix cell, which is a count, could not find its own pathways without it.

# What it does not rule

It does not make a pathway required for anything. It does not set
`containsLineVoltage`, which nobody has stated by typing a medium. It does not
touch the Σ drop count, whose exclusion docs/07 §4.2 already states. And it does
not settle whether the Plan view **owns** pathway creation rather than merely
offering it.

# Scope

No scope change: CR-109 is implemented rather than amended. It **is** a behaviour
change to a shipped gesture (a drop line reading `Office: 1x ENT` made a `Link`
before and makes a `Pathway` after) and nothing had shipped to a user, so no
document carries the old shape.

# Citations

[1] canonical-decisions.md §11.31 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/structure/drop_line_planner.dart`, the
    partition before the outlet block
[3] `packages/rackmate_core/lib/src/structure/matrix_plan.dart`,
    `_planPathwayCell`
[4] docs/07 §5.2's worked CSV row, *"the last row's `isPathwayOnly` media creates
    a `Pathway`, not a drop"*
