---
type: Design Ruling
title: DR-157 — A rack height with no side is incoherent, and placement says so instead of quietly putting the device somewhere else
description: >-
  An authored device with a rack height and no mounting side placed successfully
  and went off-rack, so nothing appeared where the user was looking. Placement now
  refuses it by name, and the device builder derives the side as the height is
  typed. The distinguishing fact is the HEIGHT, which keeps AC-031's eighteen
  field templates landing where they always did.
tags: [ruling, placement, device-builder, occupancy, dr-157, ac-031, ac-049, plan-j]
timestamp: 2026-09-12T00:00:00Z
ruling_id: DR-157
canon_section: "11.156"
status: built
amended_by: [DR-203]
---

Settled by the user on 2026-09-12, closing `#869`. Reported while running the
`PLAN-J` demo: *"I can't seem to actually see rack devices as I populate a rack.
They act as though they are present, but don't appear to do anything."*

# Two surfaces disagreed about one fact

Devices the user had **authored** failed; seeded catalog devices worked, and that
asymmetry is what made it findable.

A probe built the exact body the device builder permits, `{frontU: 2, side:
none}`, and ran `buildPlaceFromCatalogCommand` against a rack. The result is
`CatalogPlacementReady` carrying an **`OffRackPlacement`**. The placement
succeeds, reports success, and puts the device somewhere nobody is looking.
Nothing is drawn in the rack because nothing is in the rack.

The builder's save gate requires `frontU > 0` or `zeroUVertical` or `notInRack`,
and **never consults `side`**. `buildPlaceFromCatalogCommand` requires `side !=
OccupancySide.none` and **checks it before it ever looks at the height**. `side`
defaults to `none`, so a body the builder calls complete is one placement routes
off-rack.

# The distinguishing fact is the height, not the side

`frontU > 0` or `rearU > 0`, with `side == none` and a `mountMethod` other than
`notInRack`, is an incoherent occupancy rather than a field device. Placement
refuses it and the reason names the height and the field to change.

That reading is what keeps AC-031's eighteen shipped field templates landing
exactly where they always did: they are `{front: 0, rear: 0, side: none}`, and a
body with no rack height at all is a field device by construction. `notInRack`
remains the explicit escape hatch at any height, because *"this does not go in a
rack"* is a coherent answer.

It is also the guard beside it catching up. `catalog_placement.dart` already
refused `deviceH <= 0` and its comment says why in terms this ruling adopts: the
device *"is never painted, cannot be clicked, cannot be selection-chromed, and
landed on the REAR face while the user was looking at the front. A reported
success for a device that does not exist on screen is the worst possible outcome
of the three."* The `side == none` path produced the same outcome and slipped past
that guard by returning before it.

# The builder derives the side as the height is typed

Chosen by the user from three options.

**A SAVE GATE WAS TRIED FIRST AND WAS WRONG.** Requiring a side before `Save`
lights broke the existing case asserting AC-049's *"three required fields (name,
RU height, designator prefix) then ports, then done"*, and **that case was right**:
a fourth interaction is precisely the stall AC-049 exists to prevent. The attempt
is recorded in the ruling because the reasoning is what stops somebody trying it
again.

Typing a front height **is** saying the device mounts on the front, so the answer
is to read it rather than ask for it a second time. It only ever fills a blank: a
person who has chosen a side keeps it whatever they type afterwards, and one who
has said `notInRack` is not contradicted. The write rides in the field edit's own
transaction, so a height and the side it implies are one undo entry, which is what
it is to the person who typed it.

The rejected third option was to leave the builder alone and let the refusal be
the whole remedy. Refused because it leaves a template that can be authored,
saved, and taken by no rack, with the person finding out at placement time rather
than at the moment they could fix it.

# Not a regression, and the check was worth running

The disagreement predates DR-156 and nothing in that work is involved. It was
found while auditing DR-156's sweep against this report, and the audit did find
three real defects of its own. They are not these.
