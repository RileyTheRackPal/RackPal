---
type: Design Ruling
title: DR-028 — The keystone occupant cell is the FRONT NOSE, 14.5 mm × 16 mm
description: Supplies the figure DR-007 left open and #167 refuses to infer. Its first draft was wrong and overruled a figure that was right, which is the part worth keeping: an unruled figure with provenance outranks a ruled figure without one.
tags: [ruling, m3, keystone, geometry, units, provenance, dr-028]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-028
canon_section: "11.27"
status: ruled
---

Settled by the user on 2026-08-09, and **corrected by the user the same day**.
The correction is kept in full because what it caught is worth more than the
figure.

# The figure

A cell is **14.5 mm wide by 16 mm tall**, and it is the **front nose** of the
keystone: the visible bezel face, not the body, the latch, or the depth behind
the plate.

**The nose is the only dimension this product needs**, and DR-007 §11.7.9 B is
why: *"the cell renders from the front, and the front hides the differences."* A
keystone is drawn face-on in a plate elevation, where a punchdown jack and an
inline coupler are the same object, a coloured bezel with a connector opening.
Nothing in v1 draws a plate in section.

# The first draft was wrong, and it overruled a figure that was right

It recorded **15 × 16** from *"standard for 110 Keystones is 16mm tall, but width
can vary. 15mm is right in the middle of the range"*, treated the width as a
deliberate choice at the centre of a range, and on that basis **superseded
DR-007 §11.7.8's parenthetical** *"a standard keystone is about 14.5 × 16.0 mm"*.

The user then corrected their own figure: *"the front nose of each keystone is
14.5 mm wide by 16 mm tall. My own research was incorrect."*

**That supersession is withdrawn.** §11.7.8's number was right, was arrived at
independently, and now corroborates rather than conflicts.

## The lesson this record exists to keep

A figure carried as an unruled *"about"* inside an arithmetic check survived
contact with reality; a figure elevated to a ruling did not. The supersession was
written on the reasoning that *"this ruling's is the one to build from, because
it is the one a person stated deliberately"*, and **deliberateness turned out to
be the wrong test**. The earlier number had a source; the later one had a
recollection.

> An unruled figure with provenance outranks a ruled figure without one.

The corpus should not have been edited to agree with the newer of two numbers
merely because it was newer.

# What this does NOT settle

**DR-007 §11.7.8's change 3 remains open**: whether a cell on a 2-wide strap is
the same size as a cell on a 1-wide strap. That is a question about two parts,
not about one figure, and DR-007 requires it be *measured rather than inferred*
**before any dimensioned rendering**, because a uniform-cell assumption that
turns out false is wrong on every plate drawing at once. **A reader who takes
this ruling as licence to assume uniformity has made exactly the inference
§11.7.8 forbids.**

Manufacturer drawings committed on 2026-08-09 (`e8cc9fc`) supply a Hubbell
keystone *opening* of 14.605 × 17.17 mm citing NEMA WD60S2. The opening is not
the nose and both numbers are right: the widths agree to 0.1 mm, which is side
clearance, and the opening is 1.17 mm taller, which is where the latch tab
lives. A renderer needs both, and **only the nose has been ruled.**

# Stored as `Len` in nanometres (CR-001)

14.5 mm is `14_500_000` nm; 16 mm is `16_000_000` nm.

**A half-millimetre is why the unit is nanometres**, and this is the first place
in the corpus where that pays visibly rather than in principle. `14.5` is exact
as an integer count of nanometres and is a binary fraction as a count of
millimetres, so no `double` is needed anywhere between the ruling and the
rendered plate.

# One cell size is the entire geometry

DR-007 §11.7.2 makes **every occupant 1 × 1**, a speaker binding post included,
so a strap is a grid of equal cells and the only questions left are plate sizes,
orientation and which cells are filled. Had occupants stayed multi-cell, this
ruling would have owed a size per occupant kind and would have got one of them
wrong.

# Scope

**No scope change.** DR-007 already placed keystone geometry in M3; this supplies
one figure it left open. **M3-H/2 is unblocked.**

# Citations

[1] canonical-decisions.md §11.27 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.7.8 and §11.7.9 B (DR-007)
[3] `docs/reference/keystone/technical drawings/`, vendor sheets committed at
    `e8cc9fc`
