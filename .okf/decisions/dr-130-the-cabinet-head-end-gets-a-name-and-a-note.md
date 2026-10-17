---
type: Design Ruling
title: DR-130 — The cabinet head end gets a name and a note, and the note had no producer either
description: >-
  DR-125 priced the cabinet head end against "expressible as
  `OffRackPlacement` with a `mountNote`, but crude". The crude option was not
  available: nothing a person could reach had ever written that field. Ruled a
  named place with a note rather than a container, on the ground that what a
  common case needs first is to be sayable, and geometry reaches no surface
  without a drawing nobody has drawn.
tags: [ruling, placement, cabinet, off-rack, mount-note, producer-gap, schedule, m5, dr-125, dr-128, ac-043]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-130
canon_section: "11.129"
status: built
---

# DR-130 · A common case needs to be sayable before it needs geometry

Board `#839` (M5-L), authorised by
[DR-127](dr-127-the-review-s-unpriced-findings-enter-m5.md). Settled by the user
2026-09-06 on the M5-H2 review's eleventh finding: a cabinet head end is **the
COMMON residential case rather than an edge**.

## The finding's own fallback did not exist

DR-125 dispositioned this as *"expressible as `OffRackPlacement` with a
`mountNote`, but crude"*. Censused before pricing, and the crude option was not
available either. `mountNote` was modelled, serialized, round-tripped and read
back, and **written by nothing a person could reach**. The single occurrence in
`commands/` carries it across a location clear so it is not destroyed, which is a
preserver rather than a producer. No widget rendered it, no schedule printed it.

Its only writers were the starter generator's, which is why four seeded devices
carry sentences like *"Ceiling mount, rear of room"* that no user could type.
**Eighth field this milestone with no producer**, and the first found by
censusing a ruling's own escape hatch rather than by a rule firing on a
connection that is correct. See
[a-modelled-field-is-not-a-reachable-one](../practices/a-modelled-field-is-not-a-reachable-one.md).

## Ruled: a named place, with a note. Not a container

No cabinet entity, no shelf geometry, no RU grid, no elevation. Three larger
readings were offered and declined, and the second is the one worth naming: a
first-class container reusing DR-128's `ShelfPlacement` **collides head-on with
`#844`**, which parked exactly that under M9 six commits earlier. Building it
here would have unparked it by accident.

**THE SMALLEST OPTION IS NOT THE TIMID ONE.** What a common case needs first is
to be SAYABLE: a device in the AV closet on the top shelf should print that way
on the schedule and in the PDF rather than appearing as a device with no
location. A note reaches every one of those surfaces. **Geometry reaches none of
them without a drawing nobody has drawn**, which is `#844`'s own argument.

## No rule was added, and that is G4

`PLC-001` asks whether a rail position fits inside a rack. A cabinet has neither,
so the rule is unevaluatable and silent. Making it fire would be **fabricating a
rack**, which CR-114 forbids in the same breath as estimating an unknown. The
count stays at 28 under CR-021 and AC-040.

Whether a cabinet's outlets, watts and BTU should roll up as a rack's do is
**left open and filed**, because the honest version needs the container this
ruling declined.

## Built in three layers, because the milestone kept shipping one and describing two

The writer, then the schedule, then the control. The last carries the correction
`#847` bought: seven of its eight tests mount the inspector panel themselves,
which is exactly how `DrcPanel` passes its own suite while nothing in the product
mounts it. **The eighth mounts the screen and asserts the screen hands over the
callback**, which is the one assertion a panel test cannot make about itself.
