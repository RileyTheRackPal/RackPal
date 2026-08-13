---
type: Design Ruling
title: DR-049 — The tabular exports ship in v1, and the label sheet is not a sheet
description: >-
  CSV out, labels out, and no vendor exporter. The load-bearing clause is that a
  page of adhesive labels cannot be a slot in a client deliverable, and the
  refusals are refusals rather than deferrals because neither can be demonstrated.
tags: [ruling, export, csv, labels, m6, dr-005, dr-027, dr-049]
timestamp: 2026-08-12T22:00:00Z
ruling_id: DR-049
canon_section: "11.48"
status: ruled
---

Settled by the user on 2026-08-12, from a request for label exporting: *"seems
like a very cheap add; all the data's there."* Taken with the D-Tools and XTEN-AV
request, because the two are one object: rows out of data that already exists.

# It discharges a task that was filed as a question

Board #653, `M3-F/7: Export CSV and the round trip - RULING NEEDED, deferred`. It
was filed rather than built because docs/07 §5.3 promises the round trip, **roadmap
§2 does not name it**, and docs/07 is derived. *A promise living in exactly one
derived document is a scope question, not a hole to fill quietly.* See
[check a decomposition for holes](/practices/check-a-decomposition-for-holes.md),
which filed it that way and named this as the converse case that keeps the practice
honest.

**The reader stack already exists**: `csv_reader.dart`, `csv_mapping.dart`,
`csv_import_plan.dart`, `csv_import_apply.dart`, `csv_row_resolve.dart` and the
dialog. Only the writer is missing, and the round trip becomes a **property**
(`import(export(doc))` reproduces the rows) rather than a phrase nothing asserts.

# The label sheet is not a slot in the sheet set

This is the clause that took the thinking, and it follows from DR-005: **the sheet
set is a client deliverable.** A page of adhesive labels is a shop artifact.

Putting it in the set means either handing a homeowner a sheet of labels, or
inventing a per-sheet suppression rule for client exports. **The second is a
mechanism built to hide a mistake made by the first.** So it is a separate export
action with its own dialog, `SheetRole` gains nothing, and
[DR-048](dr-048-network-value-is-dated-and-t650-ships.md)'s twelve-slot arithmetic
stands untouched.

# The enum has two values and neither is Letter

`SheetSize` is `ansiBPortrait` (11 × 17) and `ansiALandscape` (11 × 8.5). **The
sheet machinery physically cannot emit an Avery-style page**, so this is an enum
change and not a layout change.

It is **the same enum `D14` already owes A4/A3 on** (board #453): docs/08:509
requires a non-US platform locale to substitute A4/A3 and `SheetSize` has neither,
so a Windows machine in a metric locale has that problem today. The two are done
together or the second is done twice.

# Two refusals, and they are refusals rather than deferrals

**No printer drivers.** Brother P-touch, Dymo Rhino and Epson LabelWorks each
speak a different dialect. An export nobody has run on the hardware scores
`VACUOUS` under docs/12 §0's legend, and this project already carries **two
unexecuted print matrices** (AC-058 `D11` and `D13`). Adding a third is how the
first two stay unexecuted for ever. A CSV covers them: every label program imports
one.

**No D-Tools or XTEN-AV exporter.** D-Tools SI needs a licensed seat and XTEN-AV's
API sits behind a commercial agreement, so **an exporter for a format nobody here
can open cannot be demonstrated**. It is also a positioning claim: docs/00 §4.2
prices this product against AVSnap and Stardraw and **explicitly not against
D-Tools**, and board #91 already warns that changing what the corpus asserts about
positioning is an amendment rather than a doc edit.

# The seam that moved the writer

**The CSV writer is M6's, not M3's**, on [DR-027](dr-027-m3-owes-rows-m6-owns-sheets.md)'s
seam: M3 owes derivations, M6 owns outputs, and a CSV file is an output. Applying
an existing seam a second time is consistency rather than a new judgement, and it
keeps a milestone one human act from closing from growing on its way out.

# Citations

[1] `docs/canonical-decisions.md` §11.48
[2] `packages/rackmate_core/lib/src/draw/sheet/sheet_def.dart`, `SheetSize`
[3] Board #653, #91, #453
