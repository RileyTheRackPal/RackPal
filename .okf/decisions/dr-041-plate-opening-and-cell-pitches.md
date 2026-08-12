---
type: Design Ruling
title: DR-041 — The plate opening and the two cell pitches, measured
description: >-
  The last four numbers a plate drawing needs. Three were measured, one is a
  standard and is marked as one, and a fifth reading was refuted by arithmetic
  before it reached the code because a pitch cannot be smaller than the opening
  is wide.
tags: [ruling, keystone, m3, geometry, units, measurement, dr-007, dr-028, dr-038, dr-041]
timestamp: 2026-08-11T00:00:00Z
ruling_id: DR-041
canon_section: "11.40"
status: ruled
---

Settled by the user on 2026-08-11, with a caliper, at the point M3-H/2 needed
each figure and the corpus did not contain it.

[DR-038](dr-038-keystone-cell-is-uniform.md) §11.37.4 named exactly what was
still missing: *"The **plate opening** dimensions and the position of the cell
grid within them"*, and warned that the ~33.3 × 66.7 mm figure was an *"about"*
nobody should quietly promote. It is no longer an about.

# The five figures

| Figure | Value | Provenance |
|---|---|---|
| Cell, the front nose | **14.5 × 16 mm** | [DR-028](dr-028-keystone-cell-is-the-front-nose.md), ruled; DR-038 makes it uniform |
| Gang opening | **33.34 × 66.68 mm** | Measured 2026-08-11 |
| Cell pitch, vertical | **22 mm** | Measured 2026-08-11 |
| Cell pitch, horizontal | **15.95 mm** | Measured 2026-08-11, after being derived to 15.947 |
| Gang pitch, horizontal | **1.8125 in = 46.0375 mm** | A STANDARD, not a measurement |

**They check out against each other, which is why they are listed together.**
Three cells at a 22 mm vertical pitch span `2 × 22 + 16 = 60` mm inside a
66.68 mm opening, leaving 3.34 mm above and below. Two cells at a 15.95 mm
horizontal pitch span `15.95 + 14.5 = 30.45` mm inside 33.34, leaving 1.445 mm
either side. **Both centrings fall out of the numbers rather than being imposed
on them**, which is DR-007 §11.7.8 change 2 confirming itself.

# The formula, which is the actual deliverable

For a `W × H` strap in an opening `(Wo, Ho)`, with pitches `(Px, Py)`, cell
`(c, r)`'s centre sits at:

```
((c - (W-1)/2) * Px,  (r - (H-1)/2) * Py)
```

relative to the opening's centre. **No width-dependent term and no
height-dependent term anywhere in it**, which is DR-038's finding written as
code, and it is why a 1-port strap renders with its jack centred rather than at
the top.

# One figure was derived first and measured second

The horizontal pitch was reachable by arithmetic: three equal margins across the
opening give `3m + 2 × 14.5 = 33.34`, so `m = 1.4467` and the pitch is `15.947`.
That derivation was offered as an option and labelled as **exactly the kind of
plausible inference §11.7.8 change 3 forbade on the cell size**. The user
measured instead and got 15.95.

**The derivation being right does not make offering it the right call.** An
even-margin layout is one manufacturing convention among several; a strap with a
wider centre web would have satisfied every stated constraint and broken every
4- and 6-port drawing. Nothing available in advance could distinguish the two.
Agreement after the fact is not evidence that the inference was safe before it.
That is [DR-028](dr-028-keystone-cell-is-the-front-nose.md) §11.27.2's lesson and
DR-038's, arriving a third time.

# The gang pitch is the one nobody measured, and it says so everywhere

1.8125 in is the ganged-device-box spacing, taken on **corroboration rather than
authority**: a 1-gang plate is 2.75 in wide and a 2-gang is 4.5625 in, and the
difference is exactly 1.8125 in, so the standard predicts a plate dimension that
can be checked without trusting the standard.

**It is a stated choice, deliberately NOT a ruled figure.** Leaving it unruled
means a later caliper reading wins automatically, with nothing to withdraw.
Ruling it would set up precisely the supersession-and-retraction that DR-028
exists to prevent.

> **MEASURED by [DR-042](dr-042-plate-outline-measured.md) on 2026-08-11**, one
> day later. **The mechanism worked exactly as designed**: the reading replaced
> this figure with no supersession entry anywhere in the corpus. That is the
> whole return on writing "stated choice" instead of "ruled".

# A wrong reading was refuted by arithmetic before it reached the code

The gang pitch was first given as **22 mm**. That is impossible: an opening is
33.34 mm wide, so two openings 22 mm apart overlap by 11.34 mm. **The check needs
no tools: a pitch cannot be smaller than the opening is wide.**

The reading was real. It was the *vertical cell* pitch, and what recovered it was
the user's own question, *"are we speaking vertically or horizontally?"*, which
exposed that the request had never named an axis.

Two lessons, and the second generalises:

1. **A dimension request must name its axis.** A plate has three distinct
   centre-to-centre distances and they differ by a factor of three.
2. **Every figure above sits in an inequality with at least one other figure**,
   and those inequalities are free. A number that violates one is wrong before
   anybody draws with it. The corpus already held that
   [a physical reference beats a careful reading](/practices/two-documents-agreeing-is-not-verification.md);
   this adds that arithmetic beats a physical reading that was answering a
   different question.

# Stored as `Len` in nanometres (CR-001), and all five are exact

`33_340_000`, `66_680_000`, `22_000_000`, `15_950_000`, and the gang pitch as
`46_037_500` nm, which is 1.8125 in taken through `Len.nmPerInch` rather than
through its 46.04 mm rounding.

**The hundredths of a millimetre are why this is not a `double` problem.** 33.34
and 15.95 are exact integer counts of nanometres and are not binary fractions of
a millimetre. That is [DR-028](dr-028-keystone-cell-is-the-front-nose.md)
§11.27.5's observation arriving with four more instances of itself. See
[byte exactness](/invariants/cr-117-byte-exactness.md) for why the file format
cares that these are integers.

# What it does not settle

| Open | Why it is not needed yet |
|---|---|
| The **plate outline** (~2.75 × 4.5 in for 1-gang) | **MEASURED by [DR-042](dr-042-plate-outline-measured.md)**, and the *"about"* was right: 2.75 × 4.5 in exactly. The editor draws the edge now |
| The **strap's own plastic** outside the opening | Hidden behind the cover plate in every elevation the product draws |
| Anything in **depth** | DR-007 §11.7.9 C: a box-fill fact, and box fill is not v1 |
| Where the opening sits **within** the outline | Falls out of the outline the moment somebody measures it |

# Scope

**No scope change.** DR-007 already placed keystone geometry in M3 and DR-038
already unblocked dimensioned rendering. **M3-H/2 (#167) has no remaining "must
not be inferred" hazard**: every dimension it draws with is now measured, ruled,
or labelled in the geometry source as a standard nobody has checked.

# Citations

[1] canonical-decisions.md §11.40 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.7.8, §11.27, §11.37 (DR-007, DR-028, DR-038)
[3] `packages/rackmate_core/lib/src/draw/scene/plate_geometry.dart`
