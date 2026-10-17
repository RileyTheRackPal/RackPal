---
type: Design Ruling
title: DR-080 — The accent colour reaches the elevation, and the text colour follows it
description: >-
  A colour control shipped at M4-D and no renderer ever read the value. DR-059
  deferred the fix and priced it wrongly in both halves; the real cost was the
  one it never named, that device_layer draws four dark text ops over the fill
  and one shipped swatch is pure black.
tags: [ruling, m4, m4-r, m4-k, elevation, cr-078, accessibility, dr-059, dr-080]
timestamp: 2026-08-21T00:00:00Z
ruling_id: DR-080
canon_section: "11.79"
status: built
---

Settled by the user on 2026-08-21 (board `#747`, `#748`), on the question
[DR-059](dr-059-the-device-glyph-ships.md) §11.58.8 deferred in its own last
paragraph. **A roadmap §8.3 amendment**, narrow: no milestone moves and
`kSchemaVersion` does not advance, because the key is already written and
already read back.

# A control that changes nothing, shipped four months ago

`TemplateBody.accentColor` and `DeviceOverrides.accentColor` are declared,
round-trip through the codec, carry a `_safe` change-class rule, and have an
editor: `device_builder_screen.dart:958` offers **eight fixed Okabe-Ito hues and
a Clear**, a fixed set rather than a wheel so no unchecked hue could reach the
greyscale gate. `draw/scene/device_layer.dart:134` computes
`Fill(palette.deviceFill)` **unconditionally**.

So the user picks a colour and nothing on screen or on paper ever shows it:
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
with the unusual twist that the *writer* exists and the *reader* does not.

# DR-059 priced it, and both halves were wrong

| The claim | What the tree says |
|---|---|
| *"regenerates four starters' goldens"* | `accentColor` occurs **0 times** in all four starters and **0 times** in `catalog/`. No golden moves |
| *"must clear PAL-1"* | `tools/pal1_check.py` enumerates `SignalFamilyDef` pairs and has **no device concept**. PAL-1 is not implicated |

Third instance of
[a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md),
and the first where the over-priced thing was a ruling of this project's own.
**§11.58 is left as written**: it is the record of what was believed that day.

# The cost that is real, and that nobody had named

`device_layer.dart` fills the body and draws **four text ops over it**, all dark
inks chosen against a near-white `deviceFill`. **One of the eight swatches is
`Rgb(0x00, 0x00, 0x00)`.** Black text on a black device. The hazard is not the
hue; it is that the fill and the ink over it were chosen by different parties a
year apart and nothing made them meet.

So the label colours come from the resolved fill's **WCAG relative luminance**,
and `pal1_check.py`'s own `luminance()` is the authority the Dart must agree
with. One definition of contrast, not two.

# Two costs accepted in writing

The user was shown both and took them, which is what makes them decisions.

- **The elevation's text palette becomes data-dependent**, where
  `RackStyle.deviceDesignator` is one value today and every consumer assumes it.
- **Ink coverage on a real laser.** M6's criterion is a physical ANSI B print
  signed off by a person, and a 42U rack of saturated bodies is a toner load
  nothing has measured. **`M6-J` (`#357`) is told to look**, which is the
  difference between an accepted cost and an ambush.

# The one hard constraint: it cannot ship first

[CR-078](/invariants/four-encoding-channels.md)'s *"hue is never used alone"* is
satisfied **vacuously** today, because every device is the same fill and no two
differ by hue at all. The instant accents render they differ by hue and nothing
else, until DR-059's seventeen marks exist.

**So the fill must not ship before M4-R's artwork (`#694`).** They are one
deliverable in two tasks. That is what makes `#694`'s decomposition urgent
rather than tidy, and it is why a milestone that read as fully adjudicated was
not.
