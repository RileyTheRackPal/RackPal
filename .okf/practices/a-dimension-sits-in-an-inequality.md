---
type: Playbook
title: A dimension sits in an inequality with another dimension; check it before you draw
description: >-
  A gang pitch arrived as 22 mm against a 33.34 mm opening, which is two holes
  overlapping by 11.34 mm. The check costs one line and no tools, and it caught a
  real reading that was answering a question nobody had asked.
tags: [practice, measurement, geometry, verification, dr-007, dr-041]
timestamp: 2026-08-11T00:00:00Z
status: adopted
---

**Before drawing with a set of physical figures, write down the inequalities they
have to satisfy and check each one.** They are free, they need no tools, and a
number that violates one is wrong before anybody renders a pixel.

# The case that produced this

M3-H needed five figures to draw a wall plate. Four were measured. The fifth,
the centre-to-centre gang pitch, came back as **22 mm** against an opening
already measured at **33.34 mm** wide.

Two openings 33.34 mm wide whose centres are 22 mm apart **overlap by 11.34 mm**.
That is not a two-gang plate; it is one wide hole. The check is one sentence:

> A pitch cannot be smaller than the thing it separates.

# The reading was real, and that is the interesting part

The 22 mm was not a typo or a bad measurement. It was the **vertical cell pitch**
inside a strap, which is a figure the work also needed and did not have. What
recovered it was the user asking *"are we speaking vertically or horizontally?"*,
which exposed that the request had never named an axis.

**A plate has three distinct centre-to-centre distances** (gang to gang, cell to
cell across, cell to cell down) and they differ by a factor of three. A request
for "the pitch" is ambiguous between all of them, and the answer arrives looking
exactly like the answer to the question that was meant.

So the practice has two halves:

1. **Name the axis in the request.** "Centre to centre" is not a specification.
2. **Check the inequality in the answer.** It catches the ambiguity the request
   failed to prevent.

# What this adds to the two rules already in the corpus

[DR-007](/decisions/dr-007-keystone-geometry-in-m3.md) §11.7.9 established that **a physical
reference beats a careful reading of a description**, twice over. DR-038 added
that **a measurement beats a sound argument that only establishes a bound**.

This is the third: **arithmetic beats a physical reading that was answering a
different question**. A caliper reading is not self-labelling. The instrument was
right, the hand was right, and the number still could not be used, because
nothing about it said which distance it was.

# The second instance, and it is a different shape

[DR-042](/decisions/dr-042-plate-outline-measured.md) added the plate outline and
promoted the gang pitch. Neither could be checked against a single inequality,
because both were new. What checked them was an **invariant across a family**:
with an N-gang plate at `2.75 + (N-1) × 1.8125` in and a uniform pitch, the edge
margin comes out 18.255 mm for *every* N.

That holds only if both figures are right and it drifts with `N` if either is
wrong, so it is evidence about the **pair** rather than a restatement of one of
them. **Where a single figure has an inequality, a set of figures has an
invariant.** Look for the quantity that should not change, and vary the thing it
is indexed on.

# Make it a test, not a habit

`plate_geometry_test.dart` carries the five inequalities as a case:

```
gangPitch          >  openingWidth
cellPitchX + cellWidth  <= openingWidth
2*cellPitchY + cellHeight <= openingHeight
cellWidth  <= cellPitchX
cellHeight <= cellPitchY
openingWidth  < plateWidth1Gang
openingHeight < plateHeight
```

plus the family invariant, over N = 1..4:

```
(plateWidthFor(N) - (openingWidth + gangPitch*(N-1))) / 2  ==  18.255 mm
```

A habit is something one person remembers. These fail loudly the next time
somebody edits a constant, which is the only version of this that survives.

# Citations

[1] canonical-decisions.md §11.40 ([DR-041](/decisions/dr-041-plate-opening-and-cell-pitches.md))
[2] `packages/rackpal_core/lib/src/draw/scene/plate_geometry.dart`
[3] `packages/rackpal_core/test/scene/plate_geometry_test.dart`
