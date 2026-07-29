---
type: Design Ruling
title: DR-001 — net labels by default
description: Every Link renders as a pair of net labels, not a drawn wire. Deletes channel routing, the crossing sweep, hop arcs and junction staggering from v1.
tags: [ruling, schematic, m2, dr-001]
timestamp: 2026-07-28T12:00:00Z
ruling_id: DR-001
canon_section: "11.1"
status: built
---

Every `Link` renders **by default** as a pair of net labels — a short stub off
each pin carrying the generated net name — **not** as a drawn wire. Drawn wires
are a transient mode (Alt-hover, focus) and the export's interconnect sheets.

Canon §11.1 states this is **"not to be re-argued in any document"**. It reverses
the record's own recommendation.

# What it deletes from v1

This is the single largest scope reduction in the corpus. It removes:

1. interval-graph channel routing
2. the crossing sweep
3. hop arcs
4. junction staggering

The roadmap prices those at **4–5 weeks and the three hardest correctness
problems in the corpus**.

# Why it keeps being load-bearing

An implementer working from the Sugiyama algorithm rather than from the ruling
will build edge routing, because that is what the algorithm's literature assumes
comes next. M2-C's brief carried this warning explicitly and the implementation
stopped at phases 0–3 as a result.

**If you find yourself implementing edge routing, stop and re-read §11.1.**

# What it moves rather than removes

The cost does not vanish, it changes shape: net labels are **text**, and text is
the dominant commit-path term. The roadmap is explicit — two net labels per Link
puts ~300 additional text runs on a 150-connection project on top of the ~10,000
the cache must be sized for. That is why M2-G exists and why the text cache is
keyed on `(text, styleId, quantisedScale)` rather than a raw double.

M2-C's perf test therefore records its symbol-layer op count but deliberately does
**not** claim the exit criterion's label-layer clause — that is still owed by
M2-D, and the recorded count is the baseline it should be stated as a delta
against.

# Built, and what it cost

M2-D shipped the render (`e13fa68`) and M2-E the canvas and domain filter
(`219c0bf`). The measured delta against M2-C's symbol-only baseline:

| | ops | best of 15 |
|---|---|---|
| M2-C, symbols only | 4155 | 3.052 ms |
| M2-D, with net labels | **6555** (+57.8%) | 4.05 ms |

The label layer alone is 2400 ops / 0.79 ms — about 19% of the frame, against
a 16.67 ms budget. Roughly 4x headroom.

The op order is **grouped by domain**, one contiguous run each, registered as
`DiagramScene` fragments. That is load-bearing rather than tidy: it is what
lets M2-E's filter replay seven domains unchanged and rebuild only the eighth,
asserted with `identical` op-for-op.

# Citations

[1] canonical-decisions.md §11.1 (`docs/canonical-decisions.md`)
[2] `docs/05-schematic-editor.md`
[3] `packages/rackmate_core/lib/src/draw/scene/sugiyama.dart` — phases 0–3 only
