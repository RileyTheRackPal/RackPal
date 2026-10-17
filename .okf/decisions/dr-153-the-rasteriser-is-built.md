---
type: Design Ruling
title: DR-153 — The rasteriser is built, the deferral ends on trade evidence, and the vector is kept rather than discarded
description: >-
  DR-138, DR-145 and DR-148 each deferred pdfium and each named the same missing
  thing: a population. DR-138 said it in one line, "n is one". The user supplied
  it, so the refused class is ordinary rather than exceptional. A direct FFI
  binding over a vendored pdfium, Windows x64 first; the rule for how many pixels
  lives in core so it can be tested with no binary; 300 dpi of the page's own
  size with a budget that steps down rather than refuses; and a rendered page
  keeps its source PDF while a lifted one does not.
tags: [ruling, plan-view, import, pdf, pdfium, vendoring, cr-100, g4, dr-153, dr-138, dr-145, dr-148, plan-k]
timestamp: 2026-09-10T00:00:00Z
ruling_id: DR-153
canon_section: "11.152"
status: built
---

Settled by the user on 2026-09-09, immediately after `PLAN-H` closed, and built
as `PLAN-K` on 2026-09-10.

# Three deferrals, one trigger, and the thing none of them had

DR-138 §11.137.5 deferred pdfium *"until a PDF needs it"*. DR-145 §11.144.5 kept
the deferral when one did. DR-148 §11.147.2 kept it a second time and wired the
debt into the exit criterion rather than a date.

**All three named the same missing thing.** DR-145: *"nothing here says how the
two classes are distributed across the trade."* DR-138, in one line: *"n is
one."*

The user supplied it. **Raster sets are the more common of the two and vector
plots are by no means uncommon**, and many plans arrive as CAD plots. That is
trade knowledge rather than a census, which is what DR-138 said it was waiting
for, and it settles what both prior rulings parked: the refused class is ordinary
rather than exceptional.

The second reason is about the OUTPUT rather than the input: vector scales better
on a sheet somebody is presented with. That is why the source page is kept, and
it is not by itself an argument for building a passthrough now.

# The mechanism was re-checked, not assumed

`pdfrx` and its siblings obtain pdfium by **downloading it at build time**, which
CR-100 forbids in its own words, and 2.x requires Flutter 3.47 against a repo
pinned at 3.44.4 by a gate. `printing` fetches the same way. Either refusal alone
still ends it.

**A pure-Dart renderer is refused on the file itself.** Costing it is one
measurement from DR-145's own table: the CAD plot carries **39 fonts**.

# What was ruled

- **A direct FFI binding over a vendored pdfium.** Windows x64 now, pinned by
  release tag and by the SHA-256 of both the archive and the DLL, and **placed by
  a person**: the agent cannot fetch it, and under CR-100 that is the point.
- **A leaf package**, `rackpal_pdfium`, so `rackpal_core` keeps zero native
  dependencies and its suite still runs anywhere a Dart SDK does.
- **300 dpi of the page's own size**, which discharges the question DR-145
  §11.144.7 opened. `T1.01` fits the plan into 15.6 x 7.9 in, so ANSI B prints at
  327 dpi effective. The figure **steps down to a pixel budget** rather than a
  large sheet being refused.
- **A rendered page keeps its source PDF and a lifted page does not.** The
  asymmetry is the argument: a lifted page's stored bytes ARE the source, while a
  rendered one has thrown the vector away.
- **Vector passthrough to the exported sheet is not built.** It needs an
  object-graph copier, which would be a second and larger PDF reader than
  `pdf_page_lift.dart`, whose header says it must never become one, and it
  collides with the per-pixel screening. `PLAN-J`'s print decides whether it is
  needed at all.

# What it cost to be honest about

A committed binary has **no integrity check of its own**: a pub dependency has a
lockfile hash and megabytes of opaque bytes in a diff have nothing. The pin plus a
test that recomputes the hash is the compensating control. It cannot tell a good
binary from a malicious one; it tells you nobody swapped it after the day it was
pinned.

See
[a vendored binary needs a control a package brings with it](/practices/a-vendored-binary-needs-its-own-control.md).
