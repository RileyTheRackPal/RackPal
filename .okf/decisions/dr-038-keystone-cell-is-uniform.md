---
type: Design Ruling
title: DR-038 — The keystone cell is uniform across strap widths, measured
description: >-
  DR-007 forbade any dimensioned plate rendering until somebody put a caliper on
  a real 3-port and a real 6-port strap. Somebody did. The cells are identical,
  and the corpus records the measurement as the authority rather than the tidier
  argument that agrees with it.
tags: [ruling, keystone, m3, dr-007, dr-028, measurement, dr-038]
timestamp: 2026-08-10T18:00:00Z
ruling_id: DR-038
canon_section: "11.37"
status: built
---

Settled by the user on 2026-08-10, with a caliper.

# What was open, and for how long

[DR-007](/decisions/dr-007-keystone-geometry-in-m3.md) §11.7.8 change 3, written
2026-07-28, recorded that whether a cell on a 2-wide strap matches a cell on a
1-wide strap was **not answerable from the product photographs**, and attached a
prohibition to it: no dimensioned rendering until a real 3-port and a real 6-port
had been measured, *"because a uniform-cell assumption that turns out false is
wrong on every plate drawing at once"*.

DR-028 supplied the cell size (14.5 × 16 mm, the front nose) and went out of its
way to say it had **not** answered this, warning that a reader taking one cell
size as licence to assume uniformity had made exactly the forbidden inference.

# The finding

**The cells are identical across strap widths.** Every cell on every strap is the
14.5 × 16 mm nose, 1-wide and 2-wide alike. A strap is a grid of uniform cells
with no width-dependent term in it.

# Why the measurement is recorded as the authority

The user also offered a reason: *"all cells are required to fit the 14.5x16mm
nose of a keystone insert anyway, so them being identical makes sense."* The
argument is sound and it is **not what settles this**.

It establishes a **lower** bound. A cell must be at least nose-sized or the part
does not go in. It says nothing about an upper one, and a 1-wide strap whose
openings were deliberately roomier would satisfy the argument completely while
breaking every uniform-cell drawing. The caliper closes the gap the reasoning
leaves open, which is precisely why §11.7.8 asked for a caliper and not for an
argument.

This is [DR-028](/decisions/dr-028-keystone-cell-is-the-front-nose.md) §11.27.2's
own lesson arriving one ruling later. That entry records a figure being wrongly
elevated over an earlier one because it had been *"stated deliberately"*, and
concludes that **provenance outranks deliberateness**. Here the provenance is a
physical part and a measuring tool, so the corpus leads with that rather than
with the tidier sentence.

# What it unblocks

The prohibition was on *any* dimensioned rendering, which reaches past M3:

- the **M3 strap editor** may draw a plate to scale rather than schematically;
- **`T5.01 Plate, Panel & Pinout Details`**, which stays at M6 under DR-007
  §11.7.7, inherits a settled geometry instead of discovering an open
  measurement late;
- DR-028 §11.27.4's explicit reservation is discharged.

# What it does not settle

**Change 2 stands untouched.** The cell grid is centred in the plate opening, not
anchored to an edge, and a 1- or 2-port strap does not fill its vertical span.
Uniform cells make the grid's *internal* geometry trivial; where that grid sits
inside a Decora opening is a different measurement. The ~33.3 × 66.7 mm opening
figure remains an unruled *"about"* carried inside an arithmetic check, and
§11.27.2 is the reason nobody should quietly promote it.

# The reusable part

DR-007 is now three-for-three on
[a physical reference beating a careful reading](/practices/two-documents-agreeing-is-not-verification.md):
the single-post keystone, the separate cover plate, and now this. It is the first
of the three where the reference settled a question the corpus had **correctly
identified as unanswerable** rather than one it had answered wrongly.

**Naming an open measurement is what made it cheap.** The question was written
down, scoped to two named parts, and assigned a tool. Discharging it cost one
person a minute.
