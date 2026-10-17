---
type: Design Ruling
title: DR-059 — The device glyph ships, because accentColor alone is hue alone
description: >-
  A glyph promised by one derived sentence and no ruling. Put to the user as a
  scope question with a recommendation to drop it; ruled in, and the census had
  already found the better reason: accentColor is authored on 0 of 48 seeds and
  read by no renderer at all.
tags: [ruling, m4, m4-d, m4-k, scope-amendment, cr-078, accessibility, dr-059]
timestamp: 2026-08-14T00:00:00Z
ruling_id: DR-059
canon_section: "11.58"
status: built
---

Settled by the user on 2026-08-14 while censusing M4-D (board `#175`, `#201`).
**A roadmap §8.3 amendment, not a decomposition gap**, which is why it carries a
ruling ID and its own commit: roadmap §2's device-builder line did not name a
glyph and neither did any ruling.

# The question

docs/06 §3.4 says Appearance carries *"`accentColor` and a glyph from a built-in
icon set, both defaulting from category"*. There is no icon set, no model field
and no ruling. **Every `glyph` in canon is `SignalDomainDef.glyph`**, which is
[CR-078's channel 4a](/invariants/four-encoding-channels.md) on the *schematic*
and identifies a signal family, not a device.

A promise living in exactly one derived, priority-3 sentence is a scope question
for the user, per
[check a decomposition for holes](/practices/check-a-decomposition-for-holes.md).
It was put as one, recommending it be dropped.

# Ruled in, and the census had the better argument

| | Finding |
|---|---|
| `accentColor` authored on **0 of 48** seeded templates | Not merely unread. Unwritten. DR-012's *"the field is empty"* case |
| `accentColor` read by **no renderer** | `draw/scene/device_layer.dart` fills every device with `palette.deviceFill`, one uniform colour |
| So Appearance would have shipped **two controls and no channel reaching paper** | The defect `shell_tabs_test.dart` prevents, arriving through a section rather than a tab |

CR-078 already argues the rest: *"hue is never used alone"*, because no
categorical palette is CVD-safe past 8 or 9 categories and **hue dies in
greyscale and on a photocopy, which is how these drawings reach a job site**. The
elevation is the sheet that argument bites hardest on, being the one taped inside
the rack door. The glyph is that redundancy applied one surface over.

# Geometry, never a codepoint

`draw/scene/family_glyph.dart` exists because the signal glyph once was one.
**Jost carries none of those characters**, so the PDF measurer returned a
near-zero advance while the screen's `TextPainter` fell back to a system font and
drew it at full width. Measured short, drawn wide; the field saw `NET-NEN006`
printed over a net name. Every gate missed it because both backends emitted
identical ops and only the font behind one differed.

# Seventeen marks, capped by legibility

One glyph per shipped archetype would be near 40. **The set is 17 plus `none`**,
because the mark draws 1U tall on a greyscale photocopy and a 40-way silhouette
distinction is not readable at that size:
[measure the control before choosing it](/practices/measure-the-control-before-choosing-it.md)
applied to an icon. Silhouettes group by what a box *is*, so the three HDMI
matrices are one `matrix` and F04 through F08 are one `speaker`. All 48 resolve,
and a gate says so.

Defaults key off **`kCatalogCategoryOrder`**, the palette's own **nine**
categories. docs/06 §3.1's eight-item list abbreviates three of them and drops
`Field Devices`; it is corrected to point at the constant, because a second list
of categories is how the palette and the builder come to disagree about what a
device is.

# Who builds what

**M4-D (`#201`) ships the enum, `TemplateBody.glyph`, the codec, the change class
and the defaults. The 17 vector marks and their renderers are a new issue
sequenced with M4-K (`#182`)**, which owns the three live previews and is the
first surface a device glyph appears on at all.
[DR-057](dr-057-pitch-is-a-refinement-not-a-prerequisite.md) §11.56.7 made the
same split for `pitch`: the artwork is judged against a rendered panel, not
against a table.

# Scope

Roadmap §2 is amended, which is the §8.3 edit this ruling authorises. docs/06
§3.1 and §3.4 are edited to match rather than pointered, so §12 is owed nothing.
`kSchemaVersion` does not advance: the key is written only when the glyph differs
from the category default, so every document on disk still satisfies
[CR-117](/invariants/cr-117-byte-exactness.md).

**`accentColor`'s unreachability is not fixed here** and is filed separately:
making it reach `device_layer.dart` changes the elevation, regenerates four
starters' goldens and must clear PAL-1, none of which belongs in a metadata form.
Another [modelled field that is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).
