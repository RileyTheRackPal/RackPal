---
type: Design Ruling
title: DR-217 · The logo imports from PNG, JPEG, PDF or SVG, is stored as a raster, and is previewed where it is set
description: >-
  Four import formats for the title-block logo; PDF and SVG render once at import to a PNG sized
  for the logo box at 600 dpi; Sheet set shows a thumbnail with Replace and Remove.
tags: [ruling, sheet-furniture, logo, import, m6-g, dr-217]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-217
canon_section: "11.216"
status: ruled
---

Settled by the user on 2026-10-01, building M6-G6 (`#590`).

# What was ruled

- **PNG, JPEG, PDF and SVG**, the user's choice over the recommended three.
- **Stored as a raster** so `ProjectLogo` mirrors `PlanUnderlay`: PNG and JPEG verbatim, flattened
  only over alpha; PDF (first page) and SVG rendered once at import, 834 x 375 px at most, which is
  the 100 x 45 pt box at 600 dpi.
- **A thumbnail with Replace and Remove** in Sheet set's Title block section.
- **A cell spanning the title block's upper band**, 65 pt, the logo fitted into 100 x 45 pt in it,
  refining DR-216: the identity band alone is 26 to 49 pt tall. Upper lines get 280 pt, not 388.
- **The ANSI A strip prints no logo**: it is already full, and the firm's text line stays.

# Why

SVG was priced at days on a wrong premise. The `pdf` package already draws SVG as a PDF and pdfium
already rasterises PDF, so SVG costs one conversion and no dependency. The thumbnail is where a logo
the partial SVG support cannot draw, or a bad flatten, is seen before it prints.

# Related

- [DR-030, the logo ships in v1](dr-030-integrator-logo-in-v1.md)
- [DR-216, the IFC stamp and the logo](dr-216-ifc-stamp-and-logo.md)
