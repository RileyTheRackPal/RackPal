---
type: Design Ruling
title: DR-051 — Documentation is referenced and never embedded
description: >-
  Four grounds, and the one that makes it never rather than later is the one the
  request did not raise. The library limit could be engineered around; copyright
  cannot be, at any date, by any amount of work.
tags: [ruling, documentation, provenance, licensing, dr-015, dr-036, dr-051]
timestamp: 2026-08-12T23:00:00Z
ruling_id: DR-051
canon_section: "11.50"
status: ruled
---

Settled by the user on 2026-08-12, from a request for embedded manuals and spec
sheets: *"who wants to frantically try to use their Google-Fu to find
documentation for some obscure device that's locked behind a dealer portal."* The
user raised file size; three other grounds bind harder.

# Four grounds, ranked by how hard they bind

**1. The exporter structurally cannot do it.** docs/08 §2.2, written long before
this was asked: *"the `pdf` package writes documents, it does not import pages."*
A capability limit of the only PDF library in the tree, so embedding is impossible
rather than expensive.

**2. [DR-015](dr-015-extension-family.md) §11.15.4 already refused the container.**
`.rmda` is one JSON file and not a zip, because the zip existed only to carry
binary members, images are cut, and a zip buys **zip-slip protection, entry-count
limits, uncompressed-size limits and image-decode bounds** as new surface with
nothing on the other side. Embedding documents reopens every one and **adds parsing
untrusted PDFs from the internet**.

**3. The arithmetic, which is worse than the concern that raised it.** A whole
document is ~870 kB of uncompressed JSON. One mid-range AVR manual is 8 to 40 MB,
and base64 in JSON adds a third. A forty-device house carries a payload **one to
two orders of magnitude larger than the drawing it decorates**, and it destroys the
diffability that [CR-117](/invariants/cr-117-byte-exactness.md), DR-039's document
diff and any future sync all depend on.

**4. The ground the request did not raise, and it is the one that ends it.**
Manufacturer manuals are **copyrighted**. Redistributing them inside a file emailed
to clients is redistribution, at scale, by a product whose users are professionals.
**The dealer portal the request complains about exists precisely to control that.**
A CC0 catalog ([DR-036](dr-036-public-gplv3-cc0-catalog.md) §11.35.3) cannot carry
them, and §11.35.4's output exception does not reach content the project never had
the right to embed.

# Why it is never rather than v2

A deferral implies a release in which the objections lapse. **Grounds 1 to 3 could
all be engineered around** given enough time: a different PDF library, a container,
compression. **Ground 4 cannot be, at any date, by any amount of work.** So it
takes DR-004's shape: not v1, not v1.1, not v1.2, not v2.

# What ships instead, and why the date is the point

A reference block on `TemplateBody`: **URL, document title, revision, and a
retrieved-on date.** No file. It prints on `T5.01` and in the equipment list, and
it reuses CR-061's provenance machinery and `assets/catalog/sources.md`, which
already do this shape for catalog data.

**The date is DR-048's mechanism reused deliberately.**
[DR-048](dr-048-network-value-is-dated-and-t650-ships.md) §11.47.3 added
`verifiedOn` because **[G4](/invariants/g4-unknowns-are-counted.md) handles unknown
and has no mechanism for stale.** A link has exactly that failure: it rots
silently, and a rotted link with a retrieval date at least tells a tech how old the
claim is.

**An embedded file has the same failure and cannot be dated out of it.** A manual
embedded in 2026 documents firmware 1.2; the device ships 3.0 in 2028.
Authoritative-looking and wrong, which is the failure mode this project spends the
most effort refusing.

# The correction this ruling made to its own supersession

The first draft of §12.21 asserted that roadmap §2.4 carried the datasheet
appendix and that v2 therefore shrinks by a line. **It never carried one**;
`grep -in datasheet docs/09-roadmap.md` returns nothing. The v2 promise lived in
two derived documents plus DR-005's bullet.

That is the **third** time in three days that a v-number in a derived document was
mistaken for a scope-list entry, and it is the same error DR-048 §11.47.5 found
from the opposite direction. See
[two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md).

# Citations

[1] `docs/canonical-decisions.md` §11.50, §12.21
[2] `docs/08-pdf-export.md` §2.2
