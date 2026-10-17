---
type: Design Ruling
title: DR-083 — The mark rides the designator line, and it wins over a hatch
description: >-
  Where the device glyph goes, what happens where it lands on a hatch, and the
  correction that DR-059's M4-K sequencing no longer describes the tree. The
  placement reuses a fix rather than a style.
tags: [ruling, m4, m4-r, elevation, glyph, cr-078, dr-059, dr-080, dr-083]
timestamp: 2026-08-21T00:00:00Z
ruling_id: DR-083
canon_section: "11.82"
status: built
---

Settled by the user on 2026-08-21 (board `#694`, `#751`), at M4-R's pick-up and
**before any artwork**, on three things the census found that
[DR-059](dr-059-the-device-glyph-ships.md) does not answer.

**A decomposition ruling, not a §8.3 amendment.** Nothing enters or leaves scope.

# The mark rides the designator line

It draws at cap height on the designator's line, and the text shifts right by a
**computed advance**. Three reasons, and the first is that this is not new:

- **`family_glyph.dart` already does exactly this, and exists because the
  alternative failed in the field.** One op whatever the glyph, an advance
  computed from the type size, and the emitter and the measurer reading the same
  function so they cannot disagree. It was written after Jost's missing
  codepoints made the signal glyph measure short and draw wide, putting
  `NET-NEN006` over a net name. **Reusing its shape is reusing a fix.**
- **It rides the one line that always draws.** `device_layer.dart`'s header
  records a shipped blackout where guarding the designator suppressed the whole
  label branch for every 1U device at 1:10 or smaller. A mark on that line
  inherits its survival.
- **It cannot collide** with the top-right badge, or with the name and type,
  which a 1U body drops first.

**The rejected alternative is recorded**: a larger mark on the right, vertically
centred, is the better picture and reads across a rack at a glance. It was
declined because at 1U it must dodge a 9 pt badge, which means a new drop tier in
the function whose drop tiers have already gone wrong once. **The better picture
is not worth a second blackout.**

# Where the mark meets a hatch, the mark wins

The collision is real and nothing had named it: `kCategoryDefaultGlyph` maps
`kCatPassive` to `DeviceGlyph.blank`, and `scene_builder.dart:344` hatches
exactly `kCatPassive`. **The devices defaulting to the `blank` mark are precisely
the ones covered in 45° lines.**

Order is hatch, then a padded backing rect in the **resolved** body fill, then the
mark. **One extra op**, on passive bodies only: the ruling's first text said
"two" and counted the mark, which draws on every device regardless.

**Suppressing the mark was the tempting answer and it is wrong.** A blank is
already identified by its hatch, so the mark is redundant, and redundancy is
DR-059's own argument. But `hatchPassive` is on by default, so suppression makes
`blank` and `shelf` draw nothing at all: two of seventeen ruled values become
unreachable, which is
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
**re-created inside the fix for it.**

# DR-059's sequencing no longer describes the tree

§11.58.7 says the artwork is *"sequenced with M4-K (`#182`), which owns the three
live previews and is the first surface a device glyph appears on at all"*.
`draw/scene/panel_layer.dart` **does not exist**, M4-K is not started, and
[DR-080](dr-080-the-accent-reaches-the-elevation.md) has made `device_layer.dart`
the first surface. **`#694` is not blocked on `#182`.**

§11.58 is left as written, on DR-080's own precedent. This is the second time in
three days that a sentence in DR-059 has not survived contact with the tree, which
is [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md)
pointing at **sequencing** rather than at cost. The two failures share a cause: a
ruling written from the corpus, about a part of the tree nobody re-read.
