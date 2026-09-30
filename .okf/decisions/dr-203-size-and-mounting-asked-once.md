---
type: Design Ruling
title: DR-203 · Size and mounting is asked once, on Identity, and what follows from it is derived
description: >-
  The Device Builder asked for six occupancy fields on two sections, and three of them are
  arithmetic on the other three. How it mounts, front and rear RU and width now sit in one block
  on Identity; Occupies and the span are derived; the rear height follows the front; side-mounted
  and in-furniture gear take no rack units; Passthrough moves to the Ports toolbar.
tags: [ruling, device-builder, occupancy, cr-036, cr-030, ac-049, dr-157, dr-203]
timestamp: 2026-09-30T00:00:00Z
ruling_id: DR-203
canon_section: "11.202"
status: ruled
---

Settled by the user on 2026-09-29, from a mockup, choosing the recommended option each time. One
clause is the user's own trade knowledge rather than an accepted recommendation: side-mounted and
in-furniture gear take no rack units, asked because guessing it would have been the author's
workflow reasoning standing in for the trade's.

# What was ruled

- **One `Size and mounting` block on Identity**: how it mounts, RU height front and rear, width.
- **`Occupies` and `nominalSpanTwelfths` are derived** (`derivedOccupancy`) on every occupancy
  edit, inside that edit's undo entry. DR-157 §11.156.5's "only ever fills a blank" is replaced.
- **The rear height follows the front** until it is typed. 21 of the 25 seeded rack-ear devices
  are the same front and rear.
- **Only rack ears, a shelf and a rear rail take rack units**; every other mount shows no height
  and zeroes it.
- **Save's third fact** (`hasMeantOccupancy`): a rack height front or rear, or a mount that takes
  none. A hosted card and a rear lacing bar can now be saved.
- **Passthrough is a toggle on the Ports toolbar**, beside the pairing it enables.

The model and the file are unchanged; nothing migrates.

# How it was found

The user reported double entry. Three cases were put to them and confirmed; they asked for the rest
to be checked, and the check found three more, none of which the user had hit yet. A test sweeps the
shipped catalog through `derivedOccupancy` and finds no disagreement, which is what makes an
always-on derivation safe to write over a real device.
