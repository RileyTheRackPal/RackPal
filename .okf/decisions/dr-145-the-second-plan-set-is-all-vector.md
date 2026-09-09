---
type: Design Ruling
title: DR-145 — The second real plan set is all vector, so DR-138's trigger has fired and the deferral survives it
description: >-
  An AutoCAD plot with zero image XObjects is refused on every page, correctly and
  for the right reason. The two real plan sets this project has seen sit at
  opposite ends of the format space, so the ordinary path forks and the lifter
  covers one fork. pdfium stays deferred, and PLAN-H is where that is re-examined.
tags: [ruling, plan-view, pdf, import, pdfium, measurement, dr-145, dr-138, dr-137, dr-029]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-145
canon_section: "11.144"
status: ruled
---

Settled by the user on 2026-09-08, after the file was put through the shipped
importer rather than read.

[DR-138](dr-138-lift-the-page-not-re-draw-it.md) deferred pdfium *"until a PDF
needs it"* and stated the lifter's cost in terms: a vector PDF falls through to a
refusal and reinstates the manual step DR-029 bought out. **A PDF now needs it.**

# What the file is

A three-page residential plan set, supplied by the user and kept out of the
repository. Read by regex over the raw bytes, the method
[DR-137](dr-137-a-floorplan-is-line-art.md) wrote down so the figures survive
without the fixture:

| | Value |
|---|---|
| Producer | `pdfplot16.hdi`, from **AutoCAD 2022** |
| Pages | **3**, `/MediaBox [0 0 1224 792]`, ANSI B landscape |
| `/XObject` | **0** |
| `/Image`, `/DCTDecode` | **0** |
| `/Font` | **39** |
| Cross-reference | classic table; no `/ObjStm`, no `/XRef` stream |

# The refusal is right for the right reason

All three pages return `draws no image`, and that string sits in `liftPage`
**after** the MediaBox, malformed-box and Resources checks. Reaching it proves the
parser resolved a real AutoCAD classic xref, walked its page tree, read a usable
`/MediaBox` and resolved each page's resource dictionary before finding no image.
A parse failure would have said `PdfCompressedCrossReferenceError`,
`declares no usable MediaBox` or `has no resources`, and it said none of them.

**The synthetic case predicted it exactly.** `pdf_page_lift_test.dart`'s
*"no XObject at all is refused"* asserts the same string the real file produced.
That is worth recording because this corpus carries the opposite experience as a
practice: a parser whose synthetic cases all passed and which refused every page
of the first real file it saw. Here they agree, which makes
[run the real input](/practices/run-the-real-input-before-writing-tests.md) a rule
of thumb rather than a law.

# The two real sets sit at opposite ends

| | 2026-09-07 (DR-137) | 2026-09-08 (this ruling) |
|---|---|---|
| Sheets | 18, ARCH D | 3, ANSI B |
| Content | every page one full-page JPEG, zero vector | zero images, 39 fonts, all vector |
| Origin | an office flattening a drawing at 60 dpi | a plot straight out of AutoCAD |
| The importer | lifts it, losslessly | refuses every page |

What is new is the **population**, not the mechanism: the ordinary path forks,
both forks are ordinary, and the import covers one. **One file is one sample and
the class is not**, so the claim is deliberately narrow: nothing here says how the
two classes are distributed across the trade. See
[a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md).

# What was ruled

**DR-029 is not wrong and its purchase is half-delivered**, which is a different
sentence. Its premise holds: PDFs are the ordinary input, and for a
raster-flattened set the manual step is gone. For a CAD plot it is back, and a
plot from CAD is vector by construction while flattening is an extra act somebody
chose.

**The deferral stands and is re-examined at `PLAN-H`.** Not now, because a
vendored pdfium plus a direct FFI binding is the largest single piece left in the
epic and would displace `PLAN-F` and `PLAN-G`, the chapters that make a plan yield
a length at all. Not never, because a deferral with a fired trigger and no review
date is how a debt stops being visible. `PLAN-H` is structural rather than a guess
at a date: `T1.01` is the first thing in this product that needs an underlay
*rendered* rather than *stored*.

**The route is unchanged and is not `pdfrx`**, which DR-138 refused twice over.
The candidate at review is a direct FFI binding over a **vendored** pdfium, per
CR-100.

**The fixture is a synthetic twin and the file stays out of the repository.**
DR-137 kept the first set out because it carries a sealed licence number; this one
is kept out for a plainer reason, that it is the user's reference material and
nothing about the finding needs the bytes. The regression needs the *signature*,
so the fixture is built to match it.

# Not ruled

The resolution a rasterisation would use when one exists: DR-137's *"never above
the source's own effective resolution"* is a rule for a raster source, and a
vector source has no such ceiling. Whether the page picker should show a grid of
refused pages rather than one sentence when **every** page is refused; this file
has no mixed case to test it with. And whether a pure-Dart renderer for the subset
a CAD plot emits is worth considering, named here only so it is on the record as
**not** costed.
