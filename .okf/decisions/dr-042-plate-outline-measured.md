---
type: Design Ruling
title: DR-042 — The plate outline and the gang pitch, measured
description: >-
  DR-041's last two hedges close one day later. The figures matter less than the
  mechanism: because the gang pitch was deliberately left unruled, a caliper
  reading replaced it with no supersession to write and nothing to withdraw.
tags: [ruling, keystone, m3, geometry, units, measurement, dr-007, dr-041, dr-042]
timestamp: 2026-08-11T12:00:00Z
ruling_id: DR-042
canon_section: "11.41"
status: ruled
---

Settled by the user on 2026-08-11, with a caliper, one day after
[DR-041](dr-041-plate-opening-and-cell-pitches.md) and against the two things
that ruling deliberately declined to claim.

# The two figures

| Figure | Value | Was |
|---|---|---|
| 1-gang plate outline | **2.75 × 4.5 in** (69.85 × 114.3 mm) | §11.40.7's unruled *"about"* |
| Gang pitch, centre to centre | **1.8125 in** (46.0375 mm) | §11.40.4's *"a standard nobody measured"* |

An N-gang plate is `2.75 + (N − 1) × 1.8125` in wide: 2.75, 4.5625, 6.375,
8.1875.

# Nothing is superseded, and that is the point

§11.40.4 left the gang pitch a **stated choice rather than a ruled figure**, on
[DR-028](dr-028-keystone-cell-is-the-front-nose.md) §11.27.2's rule that an
unruled figure with provenance outranks a ruled figure without one. It said in as
many words that this meant *"a later caliper reading wins automatically, with
nothing to withdraw"*.

The reading arrived the next day and that is exactly what happened: **no
supersession entry, no §12 row, no corpus edit reversing an earlier claim.**

Compare §11.27.2, where the same class of figure was elevated to a ruling and had
to be un-elevated within hours, taking a wrongly-superseded parenthetical with
it.

> When a figure is needed before it can be measured, record it where a
> measurement can replace it silently.

A ruled figure has to be overturned. A labelled stated choice is simply
overwritten. **The discipline costs one sentence in a source file; skipping it
costs a retraction inside the normative document.**

# The cross-check is stronger than either measurement

With the outline and the pitch both fixed, the plastic between a plate's edge and
its outermost opening is `(width(N) − (33.34 + 46.0375 × (N − 1))) / 2`, which
evaluates to **18.255 mm for every N**:

| Gang count | Plate width | Edge margin |
|---|---|---|
| 1 | 2.7500 in | 18.255 mm |
| 2 | 4.5625 in | 18.255 mm |
| 3 | 6.3750 in | 18.255 mm |
| 4 | 8.1875 in | 18.255 mm |

**That invariance is not imposed and it is not arithmetic anybody arranged.** It
holds only if the outline formula and the pitch are *both* right, and it drifts
with `N` if either is wrong. It is evidence about the pair rather than a
restatement of one of them, and it lands in `plate_geometry_test.dart` as a case
per [a dimension sits in an inequality](/practices/a-dimension-sits-in-an-inequality.md).

# Exact in integer nanometres, all of them (CR-001)

`69_850_000`, `114_300_000`, `46_037_500`, with margins of `18_255_000` and
`23_810_000`. **All five are exact because the inch is exact**: 2.75 = 11/4,
4.5 = 9/2 and 1.8125 = 29/16, each written through `Len.nmPerInch` rather than
through a millimetre rounding, so no `double` appears between this ruling and a
rendered plate. See [byte exactness](/invariants/cr-117-byte-exactness.md).

# What it unblocks

`plate_geometry.dart` stops being **openings-relative** and draws the plate edge,
so the Outlets tab renders a part rather than a set of holes floating in space.
DR-007 §11.7.8 change 2's *"blank plastic above and below, symmetric about the
centre"* becomes visible rather than implied.

# What remains open, and it is now a short list

The **strap's own plastic** outside the opening, which §11.7.9 B keeps invisible
because the cover plate hides it in every elevation this product draws; and
**anything in depth**, which §11.7.9 C files as a box-fill fact, and box fill is
not v1. Neither blocks a drawing.

**DR-007 §11.7.8's three changes are now fully discharged**, and no figure
anywhere in the keystone geometry is an *"about"*.

# Scope

**No scope change.** Nothing enters or leaves roadmap §2, no milestone moves, and
no earlier ruling is amended. Two open measurements close.

# Citations

[1] canonical-decisions.md §11.41 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.40.4, §11.40.7 (DR-041)
[3] `packages/rackmate_core/lib/src/draw/scene/plate_geometry.dart`
[4] `packages/rackmate_core/test/scene/plate_geometry_test.dart`
