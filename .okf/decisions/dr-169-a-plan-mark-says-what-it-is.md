---
type: Design Ruling
title: DR-169 — A plan mark is sized in screen points, coloured by domain, and says which one it is
description: >-
  Three complaints after drawing rooms in the product. Two were measured
  before they were ruled: a marker sized against the plan rather than the
  screen, and a canvas that never framed itself. The third needed a census
  to answer, and the census refused the obvious derivation.
tags: [ruling, plan-view, marks, cr-078, pal-1, g4, dr-169, m6]
timestamp: 2026-09-14T00:00:00Z
ruling_id: DR-169
canon_section: "11.168"
status: ruled
---

Settled by the user on 2026-09-13, built as `#896` and its six chapters.

# Measured before ruled, because "massive" is a number

`kPlanMarkerRadiusFraction` sized a marker at 1/110 of the underlay's longer
side, in SCENE units, which are image pixels. On a 3300-unit architectural
sheet that is a **60-point mark at 1:1**, with its hit box to match, and four
times that at 400%.

**And the plan canvas never called `fitToContent`**, where the rack editor and
the schematic both do, so a plan opened at 100% anchored to its top-left corner.
Both facts were measured on the day, not inferred from the complaint.

# What was ruled

- **The mark is a constant size in SCREEN POINTS** at every zoom, which is what
  `kOutlineCloseRadiusPt` already argues for. The proportional rule is retired
  rather than re-tuned: a smaller fraction keeps the property that caused the
  complaint.
- **A plan opens FITTED**, with a `Fit` control to return to.
- **Colour encodes the primary signal domain**, which is CR-078's rule rather
  than a new one.
- **The domain is AUTHORED, never derived.**
- **The mark carries the domain's GLYPH**, which is what survives the print.
- **The designator is a HOVER**, not a label beside every mark.
- **The rack mark is unchanged**: it is the datum, not a ninth domain.

# The census that refused the derivation

Reading a device's domain off its ports is the obvious implementation and it
does not work. Of the 51 seeded templates, **13 have ports in exactly one
domain**. Excluding `pwr`, `ctl` and `str`, which sit on nearly everything, it
rises to 26 and **nine then have none at all**, a control keypad among them. A
television reads as `(video.digital, audio.analog, net)`.

A set of port domains answers *what can be plugged into this*. It does not
answer *what is it*, and G4 forbids estimating it.

**The outlet half is the interesting one**, because there the derivation nearly
works: a drop's `service` IS a signal family, and five of the nine shipped
recipes resolve to a single domain. The one that breaks it is the most common
outlet in the trade. `TV location` is two Cat6 and two RG6, so it reads as
`net` and `video.analog` at once, and deriving would have coloured `Data only`
while leaving the flagship recipe grey.

# The glyph is not decoration

`plan_sheet.dart` SPLICES the plan scene, so every mark on screen is a mark on
`T1.01`, and the Installer preset exports greyscale. Canon §14 records that the
eight domain hues **collide in greyscale by design**, three of them inside one
luminance band. PAL-3 resolves that for a LINE with its dash class and line
weight. **A filled dot has neither**, so the mark carries the domain's own
glyph and the sheet stays legible without a second rule.

# Related

* [Copy outlives the route it
  names](/practices/copy-outlives-the-route-it-names.md): the same discipline
  one artifact over, and DR-168's chapter.
* [A census beats a plausible
  derivation](/practices/a-census-beats-a-plausible-derivation.md), written
  from this ruling.
