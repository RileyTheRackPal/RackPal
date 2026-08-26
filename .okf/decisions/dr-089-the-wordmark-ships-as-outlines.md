---
type: Design Ruling
title: DR-089 — The wordmark is Nasalization, shipped as outlines
description: >-
  A font licence decides an implementation. Typodermic's EULA forbids embedding
  the face in an application and forbids inclusion in anything GPL-shaped, so
  the wordmark ships as one merged path that DiagramPath.fromSvg reads once and
  both backends replay. Placing it on the board found that RJ-017's five
  accepted hardening items were decomposed into nothing.
tags: [ruling, branding, wordmark, identity, licensing, rj-017, ac-058, cr-086, cr-117, dr-089, gpl]
timestamp: 2026-08-25T00:00:00Z
ruling_id: DR-089
canon_section: "11.88"
status: built
---

# DR-089 · The wordmark ships as outlines

The letterforms are **Nasalization** (Raymond Larabie, Typodermic Fonts Inc.), chosen
after a from-scratch alternative was drawn and rejected. Worm-adjacent by design:
extended monoline proportions and a crossbarless A by default.

**Not a scope amendment.** RJ-017 already accepted the wordmark into hardening under
AC-058/D9; §10.12(f) already named the mascot. What this adds is a decision, a board
row (`#768` / `#769`) and an implementation.

## The licence forbids the obvious implementation

| Clause | Effect |
|---|---|
| 2.2 | Logos are named as permitted finished materials, no volume limit |
| Definitions | Permitted fixed artwork is **not** `Font Software` and **not** a Derivative Work |
| 4.3 | No font file may be embedded in an application, so **no `.otf` in the tree** |
| 4.5 | Fixed artwork must not let a recipient compose new text, so **one merged path**, never seven letters |
| 4.6 | No inclusion in Publicly Available Software |

**4.6 is the one that would have cost a release.** The GPLv3 option under consideration
is Publicly Available Software by 4.6's own definition. Bundling the face would have
closed it silently. Shipping outlines does not, because 4.6 reaches `Font Software` and
the definitions section puts permitted artwork outside that term by name. The catalog is
already GPLv3/CC0 under [DR-036](dr-036-public-gplv3-cc0-catalog.md); the application
licence is still open, and this ruling deliberately does not narrow it.

**4.7, the AI clause, is recorded and not resolved.** It names glyph outlines and
rendered visual elements; its last paragraph permits ordinary use of AI-carrying
software that supplies nothing to a model. The reading is the Licensee's.

## It lands on machinery that already exists

CR-086 and docs/08 §8.3 (*"There is no drawSvgPath"*) mean the wordmark is a `d` string
parsed once by `DiagramPath.fromSvg` and replayed by both backends. No new dependency,
no font loading, no second parse site.

**And it is the argument `device_glyph_art.dart` already records**: a signal glyph
shipped as a codepoint measured near zero in `PdfFontMeasurer` while the screen fell
back to a system face, and `NET-NEN006` printed over a net name. Both backends emitted
identical ops, so every gate passed. The licence and that field bug point the same way.

## The lockup

RACK over MATE, stacked and ruled. One line measures 8.95:1 and is a banner.

MATE is 262 upem units wider, so RACK is tracked **+70/1000 em**, solved against **ink**
rather than advances, because advances carry side bearings and flushing on them measures
as flush without looking it. Residual zero.

Nominal box 2999 × 1486, cap height 675, overshoot 12 units each way, integers throughout
so the geometry is byte stable in CR-117's sense. Rule dropped below a 20 px cap, measured:
at a 13 pt cap it prints as a smudge.

**Every glyph is a single contour** because the face's counters are open, so nonzero and
even-odd agree and the backends cannot diverge on fill rule. Gated, because a later
addition that closes a counter would break it in one backend only.

## What it found

Placing this on the board surfaced that **RJ-017 accepted five items into hardening and
neither `M8-0` nor `M9-0` produced a task for any of them**, both being Done. See
docs/12 §4.14. The trademark search is the one with an external gate: RJ-017 places it
before any certificate or domain is bought, so it is cheap now and expensive the moment
M8-A reaches for a code-signing certificate. See
[check a decomposition for holes](/practices/check-a-decomposition-for-holes.md).

## Still open

The **application icon** (Riley, per §10.12(f), blocked on assets, and needing a reduced
mark because a character face at 16 px is mud), the **window and document icons**, the
**trademark search**, and the **console palette**, which is DR-090.
