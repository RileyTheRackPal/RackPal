---
type: Design Ruling
title: DR-138 — The page a PDF already contains is lifted, not re-drawn
description: PLAN-D/1 picked pdfium via pdfrx and flagged two unknowns; verifying them refuses the package twice, on CR-100's vendoring rule and on the Flutter pin. The import lifts the embedded image when a page is structurally one full-page image, which for this input class is lossless and therefore better than rasterising, and refuses everything else by name.
tags: [ruling, plan-view, pdf, pdfium, cr-100, dr-138, dr-137, dr-029, plan-d]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-138
canon_section: "11.137"
status: ruled
---

Settled by the user on 2026-09-07, after `PLAN-D/1`'s two recorded unknowns were
finally checked. See
[flagged is not handled](/practices/flagged-is-not-handled.md) for what the
recording did and did not buy.

# The choice did not survive its own unverified list

| | |
|---|---|
| Licence | **Clean.** `pdfrx`, `pdfrx_engine`, `pdfium_dart`, `pdfium_flutter` are all MIT, compatible with DR-036 |
| The build | **Downloads pdfium at build time on every route.** 2.3.0+ via Dart native assets from `bblanchon/pdfium-binaries`; earlier via a CMake download |
| CR-100 | pdfium binaries are *"vendored into the repo rather than downloaded at build time (a network-fetched binary in a signed release is a supply-chain and reproducibility problem, not just a CI problem)"* |
| The pin | `pdfrx` 2.x needs Flutter **3.47 / Dart 3.13**; this repo is pinned at **3.44.4 / 3.12.2**, and the pin is a gate |

**The package chosen to make pdfium's vendoring one problem paid once cannot
accept a vendored binary.** Either refusal alone ends it, and the pin bump would
not have helped, because CR-100 is about where the binary comes from.

# Lifting is not the cheaper option, it is the better one

[DR-137](/decisions/dr-137-a-floorplan-is-line-art.md) §11.136.7 saw that every
page of the real plan set is one full-page image and declined the shortcut as
*"at most an optimisation with a fallback behind it"*. The fallback has since
been priced at **a ruling amendment, a pin bump and a vendored binary**.

And rasterising a page whose only content is a JPEG **decodes that JPEG and
re-encodes the result**: it loses a generation and cannot gain a pixel, which
DR-137 §11.136.4 settled with a measurement. On this input class the pure-Dart
path is not a compromise pending pdfium; **it is the outcome pdfium would be used
to approximate.**

# The detection is a parse, not a heuristic

All 18 pages of the real set normalise to one content stream:

```
q BT N N Td ET Q q N N N N N N cm /imgN Do Q
```

Five rules, all of which must hold:

1. `/Resources /XObject` names **exactly one** object.
2. It is `/Subtype /Image` with `/Filter /DCTDecode`.
3. The content stream shows **exactly one** `Do`, naming it.
4. **No text-showing and no path-painting operator appears anywhere.**
5. The `cm` covers at least 90% of the `MediaBox`.

**Rule 4 is the one that earns its keep**, and it has a test per operator. Rules
1 to 3 all hold on a page that ALSO carries a `VOID` stamp, a revision cloud or a
redaction box, and a lifter that dropped those would hand an installer a
superseded drawing with nothing downstream able to detect it. A wrong refusal
costs one export from a PDF viewer; a wrong acceptance costs somebody a wall.

The 90% tolerance is **measured, not chosen**: the real set places a 2484 pt image
on a 2592 pt sheet, 95.8%, so demanding exact coverage would refuse every page of
the only real file this project has.

# What is refused, and it is refused out loud

A page with vector or text content, more than one image, a filter other than
`DCTDecode`, or a **cross-reference stream**, which is where PDF 1.5 and later may
hide objects the lifter would have to decompress to see. Each has its own error
naming the reason, on `PdfImportNotAvailableError`'s precedent
([DR-029](/decisions/dr-029-plan-view-in-v1.md) §11.28.5): a refusal reading *"not
supported"* would tell somebody the product decided something it has not.

**And a PDF whose every page is refused gets its own error too.** Telling somebody
PDF import is unavailable, about a file this product just parsed eighteen pages
of, would be false.

# A lifted page is not privileged

It re-enters the ordinary import path, so every control `PLAN-D/4` built runs on
it: the content sniff, the declared-size caps before any decode, the
decoded-versus-declared re-check and the alpha flatten. **Exempting it because
"we produced it" would be exempting it because we trusted the stranger who sent
the PDF.**

# What it does not rule, and the honest weakness

**It does not cancel pdfium**, and DR-037 §11.36.2's page picker is unchanged and
built. CR-100's vendoring problem waits unchanged for the first PDF that needs a
real renderer.

**n is one.** A vector PDF from a different office's export preset falls through
to a refusal and reinstates the manual conversion step for that file, which is
the step DR-029 spent 2 to 3 weeks buying out. That is the cost of this ruling
and it is stated rather than hidden; the refusal path exists because the sample
may be unrepresentative.

# Citations

[1] canonical-decisions.md §11.137 (`docs/canonical-decisions.md`)
[2] docs/12-milestone-board.md §5.9.6, the measurements and the defect the real
    file caught before any test existed
[3] `packages/rackpal_core/lib/src/persistence/pdf_page_lift.dart`
