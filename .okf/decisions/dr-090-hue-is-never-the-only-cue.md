---
type: Design Ruling
title: DR-090 — The console palette, and hue is never the only cue
description: >-
  The application chrome gets a palette. The status ladder was tuned against
  greyscale and deuteranopia and never against the eight domain hues it shares a
  window with; four of five collide and two of those are fixed brand values, so
  the remedy is a rule rather than a repaint.
tags: [ruling, palette, colour, accessibility, status, cr-078, pal-1, ac-054, dr-090, contrast]
timestamp: 2026-10-07T00:00:00Z
ruling_id: DR-090
canon_section: "11.89"
status: built
amended_by: [DR-222]
---

# DR-090 · Hue is never the only cue

Rules the **application chrome**, which had no palette: surfaces, text tiers, controls
and five status indicators. CR-078, the eight domain hues, PAL-1 and the selection
yellow are untouched.

## The status ladder

Critical `#C8102E`, Warning `#E57200`, Caution `#FFD100` are fixed Pantone values (186,
152, 109). Notice `#86BDDA` and Nominal `#C2FFE0` are **derived**, searched jointly so
the worst adjacent gap across greyscale **and** deuteranopia is maximised at once. Worst
gap 0.158 against PAL-1's 0.10 floor.

Optimising one space and checking the other afterwards produced two wrong answers in the
same sitting, including a proposed Notice that fixed a collision with Caution by creating
a new one with Warning.

## The finding

The ladder was never measured against the **eight domain hues it shares a window with**.
CIE76 ΔE, worse of normal and deuteranopic:

| Status | Nearest domain | ΔE |
|---|---|---|
| Critical | `audio.digital` | 39.2 |
| Caution | `audio.analog` | 23.7 |
| Warning | `audio.digital` | 9.5 |
| Notice | `video.analog` | 8.2 |
| Nominal | `pwr` | 6.3 |

**Warning and Caution are fixed and collide on their own**, so re-deriving the two free
colours cannot fix it. Checked before claimed.

## The rule

A status colour may appear anywhere, **provided the marker carries a second cue that
survives the colour being removed**: shape, icon, border, or word. A bare coloured dot
whose only distinguishing property is its hue is not a status marker.

This is PAL-1's own **disjunctive** logic applied one level up, and it discharges against
AC-054 by construction: a marker that survives its colour being deleted passes both a
deuteranopia simulation and a greyscale print. Banning status hue from the canvas was
simpler to gate and was rejected, because it makes the canvas the one surface where a
finding cannot be seen at a glance.

See [assert the artifact not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md)
and [measure at the size the criterion will meet](/practices/measure-at-the-size-the-criterion-will-meet.md).

## Two ways the token set failed as a set

`#64748B`, given as the Secondary Text tier, is **already** `kUnresolvedSignalArgb` in
`signal_style.dart`. It would have carried two unrelated meanings in one window. Found by
grepping the value, not by reasoning about the token. Lightening it to `#8190A4` for AA
fixes both.

**A per-token fix broke the set.** Lightening both lower tiers for AA left Secondary
`#8190A4` and Non-critical `#8390A3` at **dE 0.87**, below the just-noticeable
difference: two tokens, one colour, where the values as given were dE 4.85 apart.
Non-critical is ratified at **`#929EAF`**, dE 5.83. Same shape as the domain
collision one level down: every token satisfied its own constraint and the set
still failed.

## The type

The chrome was never Jost. `ThemeData` carried no `fontFamily`, so the app drew its
**diagram in Jost and its chrome in the platform default** from M1 to M4, and no gate
could see it because both faces render. And 28 sites asked for `w600`/`w700` against a
lone Regular, which Flutter synthesises, worst on a geometric face because the counters
close before the stems thicken. **Jost Medium (500) is bundled**, same v3.710 build,
verified to share outlines and advances with Regular.

The 28 sites still synthesise, now from 500. Retargeting is `#770`. The PDF side was
checked and is unaffected: the `bold: true` call sites are Flutter widgets, not
`FontRef`, so no drawing op requests bold.

## Inactive was one token doing two jobs

`inactiveSurface` `#2D3748` measures 1.22:1 on Card and is invisible **as text** while
being perfectly adequate **as a line**. One token, two jobs, so it splits, with
`inactiveInk` `#586679` for disabled labels. The engraved treatment was measured rather
than assumed: a 1 px lighter edge raises the **rendered** peak from 1.22 to 1.94:1, not
to legibility, because at 13 px the highlight competes for the stem's own pixels.

## Built

The **type** half is built at `bdfcbc9` (`#771`); the 28 synthesising sites were
retargeted to `kConsoleEmphasis` (`w500`) at `#775`, under a gate that reads the weights
`pubspec.yaml` declares per family. The **colour** half is built at `08c69e9` (`#770`),
in `rackpal_core/draw/console_palette.dart` beside `contrast.dart`, and
`console_theme.dart` defines no colour of its own. `RackMono` is Space Mono at `ddea30e`
(`#773`). The rule got a construction rather than a gate: `StatusMarker` has no
constructor that takes a colour without a shape, and Notice's circle is an **outline**
because a filled one is the bare dot this ruling forbids.

Since the ruling, `kConsoleScopeInstance` `#FFC24D` joined the palette (`#230`) as an ink
and border only: a scope is not a severity, so it does not borrow Warning.

**The reference page is a claude.ai artifact**, revised 2026-10-07 against the code:
[Colour](https://claude.ai/artifact/JRjXir27Kh52L8NDaQUttf), with
[Type](https://claude.ai/artifact/S4j8rvE8ujjuQwVgShBSTe) beside it. Its 2026-08-27
version drew Notice **filled**, the one shape this ruling names as forbidden: a proof
sheet for the rule broke the rule, and nothing gates a picture.

## Found by the 2026-10-07 audit, not ruled

- **Device accent swatch 5 is PAL-2's reserved selection yellow `#F0E442`.** PAL-2 bars it
  from cables only, and §11.89.10 leaves accents to `#565`, so no ruling is broken. A
  device body in the colour that means "selected" is a UI question for `#565`'s owner.
- **Fixed at `cf26578f` (`#1029`): the bundled Jost reported "RackMate build"** in its name
  table. `#781` had corrected the generator and never re-run it. Only the name table was
  rewritten, with every other table proven byte-identical. Canon §11.89.8 now records the
  four owed codepoints as built at `2549c63` (`64ba8028`).
- **Fixed at `ba3d14e8` (`#1029`): seven comments said only Jost Regular is bundled.** The
  rewrite kept the half still true: a drawing op reaches one face, and `bold` must stay
  unwired on screen until the PDF loads Medium too.
- **Not fixed, because it is not a note:** docs/03, 05, 08, 11 and canon still specify
  CR-080's IBM Plex. That face change was never ruled (docs/12 §4.6), so the docs are not
  stale against a ruling; the code is ahead of one.
