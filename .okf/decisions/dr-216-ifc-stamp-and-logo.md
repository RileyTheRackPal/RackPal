---
type: Design Ruling
title: DR-216 · Export for construction is its own command, the stamp is on every sheet, and the logo sits top-right
description: >-
  File ▸ Export for construction… requests the stamp for one export; the stamp prints on every sheet
  above the revision block when no error is open; the logo sits top-right in the title block.
tags: [ruling, sheet-furniture, ifc, logo, m6-g, dr-216]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-216
canon_section: "11.215"
status: ruled
---

Settled by the user on 2026-10-01, building M6-G5 (`#346`) and M6-G6 (`#590`), on the recommended
option three times.

# What was ruled

- **`File ▸ Export for construction…`** beside Export PDF: stamps every sheet with zero open errors,
  otherwise exports unstamped and says why. Remembers nothing.
- **The stamp is on every sheet, above the revision block**; on ANSI A, a full-width band above the
  strip (decided without a question).
- **The logo sits at the top right of the identity band**, about 100 by 45 pt, set in Sheet set.
- The revision block's `issued` flag parks with G3 on `#658`.

# Why

Sheets travel separately on a site. A saved setting would stamp later exports by default. A box
outside the title block would take drawing space on every sheet.

Follows [DR-215](/decisions/dr-215-zones-and-history-park.md).
