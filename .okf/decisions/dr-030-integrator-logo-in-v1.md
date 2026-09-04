---
type: Design Ruling
title: DR-030 — The integrator's logo ships in v1, in M6, without its opacity
description: Reverses the one clause RJ-017 rejected. Two of its three grounds had fallen; the third stands and shapes the ruling, so the logo is added beside the text block and never instead of it. The opacity does not come back.
tags: [ruling, m6, branding, pdf, scope, dr-030]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-030
canon_section: "11.29"
status: ruled
---

Settled by the user on 2026-08-09: *"Let's add the logo in; likely during M6. If
it's cheap we may as well."*

# What it reverses, and what it does not

RJ-017 rejected the integrator's logo in the title block on three grounds. Two
have fallen:

- *"It requires a raster asset inside the project, which reopens the container
  question that AC-057 just closed by cutting images."* **Gone**: DR-019 settled
  the container and [DR-029](/decisions/dr-029-plan-view-in-v1.md) builds it.
- *"The logo lands with the v2 zip container, alongside device images."*
  **Arrived early**, for the same reason.

**The third stands and shapes the ruling.** The title block's TEXT integrator
block carries the same information, so the logo is added **beside** it and
**never instead of** it: a photocopy at third generation still carries a licence
number and may not carry a logo.

Everything else RJ-017 accepted is untouched: the icon, the wordmark, the window
and document icons, file-type registration, and the trademark search.

# Cheap as arithmetic, not as an impression

The logo is the **fourth consumer of three things DR-029 already builds**:
DR-019's zip container, the `drawImage` op on `DiagramCanvas`, and raster
embedding in the PDF backend for `T1.01`. It buys none of the three on its own
account.

**So if the Plan view slips out of v1, this slips with it**, and the ruling says
so rather than leaving the dependency implicit.

# The opacity does not come back

docs/08 row 9 forbids alpha *"absolutely, with no exception"* and named the
logo-opacity path as its sole former exception. The logo returns at **full
opacity**, no `ExtGState` is ever emitted, and **a faded logo means a faded PNG**.
An invariant written around this feature's absence survives its return.

# Four derived sentences DR-029 falsified

A ruling that puts a raster on an exported sheet falsifies every claim the export
document makes about being vector-only. DR-029 named the `drawImage` op and
stopped; three of these sat paragraphs apart in one file.

| Sentence | Where | Status |
|---|---|---|
| *"The exported document is therefore 100% vector with no raster path and no alpha path at all"* | docs/08 §6.2 | **False.** `T1.01` prints a screened underlay. |
| *"Images: Not in v1."* | docs/08 backend table row 17 | **False.** Two consumers now. |
| *"There is no logo."* | docs/08 §5 | **False as of this ruling.** |
| *"PDF is not read. The user exports a page to an image first."* | docs/15 §2 | **False.** DR-029 buys that increment. |

# One live question handed to the Plan view epic

docs/15 calls the underlay **screened** and docs/08 row 9 forbids alpha
absolutely. Screening by per-image alpha would emit the first `ExtGState` this
document has ever carried, so **the underlay must be pre-composited at import**
the way palette tints already are at 18% over white. #589 settles it before
`T1.01` renders.

# What it owes and what it does not add

Owed: a model field, a **fit rule** (aspect preserved, never stretched), import
hardening under M4-M4, and a place in the print matrix (AC-058 D13). It lands
beside #343 (M6-G2, the title block).

**It does NOT return device images** (AC-057 cut those on a separate file-size
argument), and it does not make a logo required.

# Scope

**No milestone moves and §12.7 is not re-costed**, recorded as a judgement rather
than a measurement.

# Citations

[1] canonical-decisions.md §11.29 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §12, the amended RJ-017 row
[3] docs/08-pdf-export.md §5 (the title block) and row 9 (the no-alpha rule)
