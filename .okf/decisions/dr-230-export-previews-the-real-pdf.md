---
type: Design Ruling
title: DR-230 · Export previews the real PDF, and past 40 sheets it says so without asking
description: >-
  The export preview is the generated PDF rendered by the vendored pdfium, superseding CR-100's screen
  preview; past 40 sheets the count is said in the header and a notice, and 2000 is refused.
tags: [ruling, amendment, export, preview, pdfium, m6, m6-i, dr-230, cr-100]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-230
canon_section: "11.229"
status: ruled
---

Settled by the user on 2026-10-04, opening M6-I (`#351`). Supersedes CR-100's preview clause (§12.48).

# What was ruled

- **The preview is the real file.** Export generates once off the main isolate, then previews those
  bytes page by page through pdfium; Save… writes what was previewed. CR-100's reason for a screen
  preview ("no native dependency") died when DR-153 vendored pdfium. No separate Verify output button.
  Without the binary the preview says so and Save… still works.
- **Past 40 sheets: said, not asked.** The header and a notice say so; 2000 is refused before any page
  is drawn. Measured: about 6 ms a sheet, so 40 sheets is a quarter of a second.
- **Mechanical**: the count is the sheet set's dry run; progress only past 400 ms; Cancel kills the
  isolate and writes nothing.

# Not taken

- CR-100's screen-rendered preview, about twice the price and short an image path for plan sheets.
- No in-app preview; a confirmation prompt past 40 sheets.

Canon §11.229 holds the full text.
