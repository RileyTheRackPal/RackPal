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
timestamp: 2026-10-07T00:00:00Z
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

**Deprecation**: this section describes the RackMate lockup as DR-089 shipped it. DR-096
re-spelled it at `1650f0fb` and DR-117 §11.116.1 settled the result; see
[Since](#since-the-rename) below for the mark that ships now. Kept because the ink-flush
reasoning is why PAL was *not* tracked to match.

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

## Since the rename

DR-096 §11.95.4 made the letterforms an outside art dependency: nobody working in this
tree can cut a new letter, because the tool that cuts them is the font and the font may
not be here. RackPal arrived as paths at `1650f0fb`.

PAL is 812 units **narrower** than RACK by ink, so the old solve would need +406/1000 em
and PAL would read as three initials. So RACK sets the measure **untracked**, the rule
matches RACK, PAL sits flush left, and Riley (544 × 675, even-odd, a separate path) takes
the row-2 slot 268 units clear of the L. Box **2788 × 1486**; overshoot is now 12 **above
only**, because the M that overshot the baseline is gone. **DR-117 §11.116.1 settled both
review questions as drawn** (2026-09-03), after the mark went in front of a test group.

The reference pages are claude.ai artifacts, revised 2026-10-07 and drawn from the
`brand.dart` bytes: [Wordmark](https://claude.ai/artifact/DcHQGd3EUkLbo5pdRo65zS) (forms,
anatomy, true-size and icon ladders; it absorbed the older "Mark at Size" page),
[Colour](https://claude.ai/artifact/JRjXir27Kh52L8NDaQUttf) and
[Type](https://claude.ai/artifact/S4j8rvE8ujjuQwVgShBSTe).

## Still open

- **The mark is drawn nowhere.** `rackPalLockupPath` and `rackPalRileyPath` have no
  caller outside `brand_test.dart`, measured 2026-10-07. "Shipped" here means shipped in
  the code, not on any screen or sheet.
- **The application icon is still Flutter's.** `app_icon.ico` is the stock logo, last
  touched 2026-08-26. Riley is the intended icon (§10.12(f)) and below about 48 px the mark
  *is* Riley; no icon art exists.
- The **window and document icons**, behind the same art.
- **Final Riley art**, which DR-117 expects to replace `_rileyD` and nothing else.

The trademark search cleared before the rename (DR-096 §11.95.7). The console palette is
[DR-090](dr-090-hue-is-never-the-only-cue.md).
