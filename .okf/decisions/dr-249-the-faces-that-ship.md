---
type: Design Ruling
title: DR-249 · CR-080 is amended to the faces that ship, Jost for text and Space Mono for RackMono, and RackCond is retired
description: >-
  From #1061. The bundle had been Jost and Space Mono since 0545090 with no amendment, so CR-080's
  IBM Plex stayed binding over a tree that contradicted it. Ratified as built; RackCond retired; no
  fallback face, the glyph-coverage gate holding the codepoints instead.
tags: [ruling, fonts, typography, cr-080, jost, space-mono, glyph-coverage, dr-249, dr-089]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-249
canon_section: "11.248"
status: built
---

Settled by the user on 2026-10-17 for `#1061`, a finding of that day's sync audit. It ratifies what
already shipped, which is why its status is `built` on the day it was ruled.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| The faces | User, on the recommendation | Jost (Regular, Medium) for text; Space Mono (Regular, Bold) for `RackMono`. Bundled twice, SIL OFL only, no system font, as CR-080 had it |
| `RackCond` | User, on the recommendation | Retired. Schedules set in Jost |
| Fallback | Carried in the chosen option | None ships; `tools/glyph_coverage_check.py` holds the codepoints the product emits |

# A comment is not an amendment

`apps/rackpal/pubspec.yaml` said in so many words that Jost *"supersedes CR-080's font pick"*, and
canon §11.6 noticed the drift and declined to rule on it. Neither moved CR-080, so for months the
ruling said one face, the tree held another, and every derived document that described the fonts
followed the ruling. A sentence in code that claims to supersede a ruling is a request for one.

# The arguments were re-checked, not inherited

CR-080's case for Plex had three legs, and each was measured against the shipped TTFs:

* **Telling `0` from `O`** holds only in the mono face. Space Mono's zero has three contours, a
  marked zero; Jost's `0` and `O` both have two and differ by width alone. Identifiers belong in
  `RackMono`, which is where docs/08 §10.1 already puts `CABLE ID`.
* **A condensed cut** is gone, and the option offering its retirement overstated the evidence: M6's
  machine clauses pass without one, while the physical prints (AC-054) have not been run. The print is
  where a too-tight column would show, and that would be new evidence for a new ruling.
* **Greek coverage** holds by different codepoints: Jost has `U+03A9`, Space Mono `U+2126`.

# Related

* [DR-089](dr-089-the-wordmark-ships-as-outlines.md), the wordmark, which is outlines and untouched here.
* [DR-090](dr-090-hue-is-never-the-only-cue.md), whose audit added Jost Medium.
