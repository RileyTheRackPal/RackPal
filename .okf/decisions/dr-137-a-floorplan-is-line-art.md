---
type: Design Ruling
title: DR-137 — Underlay members are deflated, because a floorplan is line art
description: Measured against the first real plan set this project was ever given. PLAN-B stored binary members uncompressed behind four reasons; two are false, one argued for nothing, and the survivor is answered by an exposure that already existed. Separately, the set is 60 dpi raster with zero vector content, so PLAN-D/3's resolution trade is a lookup rather than a trade.
tags: [ruling, persistence, container, compression, plan-view, dr-137, dr-019, cr-117, plan-d]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-137
canon_section: "11.136"
status: ruled
---

Settled by the user on 2026-09-07, on measurements taken against an 18-sheet
residential permit set, ARCH D (36 x 24 inches), supplied that day and described
as representative of what this trade is usually given.

# What PLAN-B decided, and which half of it was measured

`container.dart` stored binary members uncompressed and gave four reasons.

| The reason as written | What measuring found |
|---|---|
| *"already compressed; deflating it again buys ~nothing"* | **False.** All 18 pages deflate, 7.0% to 34.3%, mean **16.0%**. The **floor plans deflate BEST**, at 34.3% |
| *"costs real time at level 9"* | **False. 6.2 ms** on the sheet a user actually imports; ~230 ms for all 18 at once, on a save already in `Isolate.run` |
| *"the bytes appear VERBATIM, so CR-117 does not depend on the deflate implementation"* | **True, and the only survivor.** Answered below |
| *"opens in any zip tool with the architect's page inside"* | **Argued for nothing.** Every zip tool inflates a deflated entry |

The surviving objection is answered by an exposure that **already exists**:
`document.json` has been deflated in this same container since PLAN-B, so a
dependency bump that moved the deflate stream already broke the round trip. This
widens a surface rather than opening one, and `container_identity_test.dart`
fails loudly on the day it moves.

# The generalisation, which is the part that travels

*"Already-compressed rasters do not deflate"* is a true statement about
**photographs** and a false one about **line art on white**, and this product
receives line art on white. The rule was imported from the domain where it holds
into the domain where it does not, and read as self-evident in both. Written up
as [a borrowed rule is not re-checked](/practices/a-borrowed-rule-is-not-re-checked.md).

# What it cost, measured in the container rather than in zlib

| `whole_house.rmpj` plus | STORE | DEFLATE | Saved |
|---|---|---|---|
| A-2.1, the sheet a user imports | 331,776 | **234,165** | **97,611** |
| all 18 sheets | 9,769,984 | **8,235,004** | **1,534,980** |

**And a plan makes the file SMALLER.** 745,646 bytes of plain JSON becomes
**234,165** as a container, a **69% drop**, because the underlay flips the format
and the JSON then deflates 16.3x. This inverts docs/15 §2, which rejected base64
on an estimate and admitted the zip path's real number had never been taken.

# The second finding: resolution is a bound, not a trade

Every page of the set is a single full-page JPEG. **Zero fonts and zero vector
content in the entire file**, 2160 x 1440 px on a 36 x 24 inch sheet, which is
**60 dpi**. `PLAN-D/3` framed rasterisation resolution as a three-way trade
between legibility, AC-006's budget and PDF cost. For a raster-backed source
there is no trade: 96 dpi costs 1.8x the bytes, 150 dpi 4.0x, 300 dpi **12.9x**,
and every one gains **zero** information.

**The rule is a bound: never rasterise above the source's own effective
resolution.** For a vector PDF `PLAN-D/3`'s trade is real and stands.

**And 60 dpi is enough**, settled by looking rather than by asserting. At 1:1 the
room names, dimension strings, window callouts and stair counts are all legible;
15 px per foot makes one pixel **0.8 real inches**, and an installer needs the
wall rather than the inch.

# What it does not rule

**It does not settle PDF rasterisation**, which still needs pdfium vendored, the
Dart wrapper's licence and build behaviour established, and a page picker built.
`PLAN-D/3` stays open for exactly that.

**It does not adopt the shortcut the file makes visible.** Because every page
here is one full-page image, the JPEG could be extracted without rasterising at
all, losslessly. A vector PDF breaks it and
[DR-029](/decisions/dr-029-plan-view-in-v1.md) bought PDF import generally, so it
is at most an optimisation with pdfium behind it.

**It does not generalise from one plan set to all of them.** n is one, the user
reports it representative, and that is trade knowledge rather than a census.
Nothing here depends on the generalisation holding: deflate is safe on a member
that will not compress, since it simply does not; the resolution rule is a bound
rather than a number; and the container-size finding is a property of the format.

# The plan set is not in the repository

It carries a licensed engineer's seal and licence number, the firm's name, the
builder's mark and a redaction covering the address and nothing else.
[DR-036](/decisions/dr-036-public-gplv3-cc0-catalog.md)'s public release
publishes **every commit ever made** rather than the current tree, so committing
it today and deleting it tomorrow ships it anyway. `.gitignore` refuses
`docs/reference/*.pdf` at the top level only, leaving `keystone/`'s seven
manufacturer drawings tracked. The measurements are the artifact, and docs/12
§5.9.5.1 carries the method so anybody can re-derive them against their own sheet.

# Citations

[1] canonical-decisions.md §11.136 (`docs/canonical-decisions.md`)
[2] docs/12-milestone-board.md §5.9.5, the measurements and the method
[3] `packages/rackpal_core/lib/src/persistence/container.dart`, the header
