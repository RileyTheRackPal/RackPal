---
type: Design Ruling
title: DR-027 — M3 owes the Pull Sheet's rows and its sort; M6 owns every rendered sheet
description: M3's exit criterion demanded exporting a Pull Sheet that the exporter has no role for. The seam is that M3 owes the derivation as tested core output and M6 owes the sheet; this amends an exit criterion, which is why it is a ruling.
tags: [ruling, m3, m6, exit-criteria, scope, dr-027]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-027
canon_section: "11.26"
status: ruled
---

Settled by the user on 2026-08-09, ratifying the seam board #155 proposed:
*"M6 is where sheets are going to be rendered and I'd like to work those issues
out all at once."*

# The tension

`SheetRole` has three values, `rackElevationFront`, `rackElevationRear` and
`equipmentList`. **There is no Pull Sheet and no Termination Schedule in the
exporter at all.** M3's exit criterion nonetheless says a rough-in *"exports a
Pull Sheet sorted by room and pathway with per-room footage subtotals and initial
boxes"*. One of the two had to give.

# The ruling

| Owner | What |
|---|---|
| **M3** | The **derivation**: the rows, the sort by room then pathway, and the per-room footage subtotals, **as tested output of `rackmate_core`** |
| **M6** | The **sheet**: the `SheetRole`, the layout, the initial boxes and the page |

# It amends an exit criterion, which is why it is a ruling and not a note

Roadmap §8.1 makes the exit criterion the unit of truth, so moving a clause
across a milestone boundary is an amendment under §8.3. **M3's clause 3 is
amended**: M3 demonstrates the rows, the sort and the subtotals; M6 demonstrates
the export.

M3 cannot discharge a clause about a sheet it does not own, and reading the
clause loosely enough to call it met would be precisely the checklist-ticking
§8.1 refuses. M6's criterion needs no addition: *"all four starter projects
export a complete set"* already contains the sheet.

**It tidies a second clause rather than creating one.** Board #574 already parks
AC-018's PRINTS clause on M6 for the identical reason. One seam, two clauses,
now stated once instead of discovered twice.

# What M3 still owes, so this is not read as a deferral

The derivation is the load-bearing half: sorted rows, per-room subtotals, and
the unknown counts G4 requires of every rollup. A milestone that shipped an
unordered, untotalled data structure would hand M6 the design work along with
the rendering, and the seam would have become an excuse.

**Demonstrated at M3-D/4** (`pull_sheet_clause_test.dart`, `59ea14a`). The
finding there is worth carrying: every part of clause 3 already had passing
tests and **none of them had ever been pointed at the same document**. Three
unit tests over three fixtures demonstrate three mechanisms; the clause is a
compound claim about one rough-in. That file also pins `SheetRole` to its three
values, so the seam fails loudly if a `pullSheet` role ever appears.

# Downstream

[DR-029](/decisions/dr-029-plan-view-in-v1.md) leans on this the same day: M6
becomes *the milestone where sheets become real*, so everything owing it a sheet
must precede it. That is the argument for sequencing the Plan view before M6.

# Scope

**A milestone-boundary amendment; no change to roadmap §2's contents.** Nothing
leaves v1 and nothing joins it. One clause moves from M3's criterion to M6's.
**M3-D/4 is unblocked.**

# Citations

[1] canonical-decisions.md §11.26 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/draw/sheet/sheet_def.dart`, the three roles
    and the scope note naming the other nine as M6
[3] `packages/rackmate_core/test/derived/pull_sheet_clause_test.dart`
[4] docs/12-milestone-board.md §5.2, the M3-D/4 close
