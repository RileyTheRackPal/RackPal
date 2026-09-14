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
- **On paper, a mark is the round end of its callout pill** (§11.168.10, added
  2026-09-14 at `#904`). A relation and not a number: the pill's own type size
  awaits `PLAN-J`'s print, so the mark is derived from the pill and follows it.
- **A mark's line weight is the drafting weight** (§11.168.11, added
  2026-09-14 at `#905`): a drop at the base signal line and a device at twice
  it, constant on paper and on screen, at every zoom and on every scan.

# The printed half, which arrived a day later

`plan_sheet.dart` passed no radius, so a printed mark kept the retired fraction
after the screen had dropped it. Measured on ANSI B landscape, it printed at
6.87 points on a 2000x1500 plan and 5.15 on 1500x2000: the fit binds on the
tighter axis while the fraction read the longer one.

**The chapter that found it was wrong twice**, and both were caught by reading
the code rather than the chapter. It estimated today's mark at about 5.3 points
against a page area the sheet does not use, and it put the fit "immediately
before" the scene build when the fit was computed FROM the scene. The fix fits
first, and `markerRadius` is now required, so a surface that forgets to state
its scale does not compile.

**The outline did not come with the radius**, and became `#905`. It was still
in scene units, so a device's ring and an outlet's outline both printed at the
0.5-point floor on a 6600x5100 scan and a device printed like a drop.

# The line weight, and the corner that caps it

The user chose drafting weights from three drawn side by side: a drop at the
base signal line and a device at twice it, which is 0.7 and 1.4 points on paper
and one and two pixels on screen. **The alternatives lost on arithmetic, not
taste.** Matching the pill's 0.5-point hairline put a drop exactly on the print
floor and a device 0.375 points from it. Freezing today's look at 100% ran the
ring into the corners of the square glyph, which reach 0.813 of the radius and
belong to Network, the commonest drop there is.

**The screen half hid behind a transform layer.** The plan canvas zooms above
its cached picture, so `FlutterDiagramCanvas` decided stroke widths and the 0.5
floor at scale 1 whatever the zoom. Dividing a pixel by the zoom in the caller
would have been floored back to two pixels at 400%. The canvas now takes the
layer's scale as `outerScale`, and the marks use `scaleWithGeometry: false`.

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
