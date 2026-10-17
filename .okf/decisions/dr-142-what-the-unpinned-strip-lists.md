---
type: Design Ruling
title: DR-142 — What the unpinned strip lists, and the two location fields a device already had
description: >-
  docs/15 §6 gives the strip as "everything in this plan's location that could
  carry a pin and does not". Every clause hid a decision. Unpinned is no pin at
  all; an underlay with no location has no filter; a carrier with no location is
  a count. And asking which of a device's two location fields is the room found a
  writer that sets one of them.
tags: [ruling, plan-view, pins, unpinned-strip, g4, dr-142, dr-140, plan-e, cr-114]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-142
canon_section: "11.141"
status: built
---

Ruled at `PLAN-E/4`'s decomposition.
[DR-140](dr-140-the-rack-is-pinned-from-the-unpinned-strip.md) settled what the
strip is **for** and left what it **contains** to this chapter.

# The sentence, and how much it was hiding

docs/15 §6: *"a strip along the bottom lists everything in this plan's location
that could carry a pin and does not, with a count."*

The chapter's own brief warns about **the count that counts the wrong thing**,
citing the status bar that read `0 pathways` the keystroke after somebody made
one. DR-140 then supplied a second instance on purpose: a strip built from
`doc.devices` gets the number wrong on any document with an unpinned rack.

**Reading the model turned up three more, and one of them is already shipped.**
The warning was right about the class and had no way to name the members.

# Three definitions

**Unpinned is no pin AT ALL**, never "no pin on this underlay". A carrier holds
one `planPin` and a `PlanPin` names its plan, so a row listed as unpinned here
while it is pinned on `Level 1` would **move that pin** when dragged out, as the
answer to a gesture that presented itself as adding something. The per-underlay
reading is available only because the model cannot express it.

**An underlay with no `locationId` has no filter**, so a site plan lists every
unpinned carrier. The model says a plan with no location is ordinary: *"a site
plan depicts no room."* Listing nothing would report **zero** on a plan with
nothing pinned, which is the 80%-complete plan from the other direction; matching
its null against a carrier's null is the unknown-equals-unknown join
[G4](/invariants/g4-unknowns-are-counted.md) forbids.

**A carrier whose own location is unknown is a count, not a row.** `CR-114`
applied exactly: a row invites pinning a second-floor speaker onto `Level 1` and
calling it placed, and silence is `0 pathways` again. So the query carries
`unlocatedCount` and a surface showing rows shows that number.

# The defect this found

`DeviceInstance.locationId` and `OffRackPlacement.locationId` are **different
fields holding the same value**. The model says so: `AddStructureCommand` writes
both, `RemoveLocationCommand` clears both, and *"clearing one would leave the
document disagreeing with itself."*

**`buildPlaceOnPlanCommand` writes one of them.** It hands `AddDeviceCommand` an
`OffRackPlacement` carrying the underlay's location, and `AddDeviceCommand.apply`
builds its `DeviceInstance` with no `locationId`, because it has never had that
parameter.

> Every device dropped on a plan since `PLAN-E/2` has a placement saying
> `Level 1` and an instance saying nothing, and `equipment_list.dart` reads the
> instance. **The Equipment List prints no room for a plan-dropped device**, with
> no later repair available: `locationId` is deliberately not a `DeviceField`, so
> no editing gesture can set it.

Fixed in `AddDeviceCommand` rather than at the call site: when the placement names
a room, the instance is built with the same room, derived from the command's own
field, so the next caller cannot forget what this one did.

**The strip is why it was found.** A surface that filters carriers by room has to
choose which of two fields is the room, and asking that is what exposed a writer
that sets one. See
[verify-codebase-claims-by-reading](/practices/verify-codebase-claims-by-reading.md):
nothing failed, and no test was going to.

# Deferred, with a default rather than a blank

The strip's **order** and whether a rack row is drawn differently are the user's
(§11.139.6, still open). What ships is rack, then outlets, then devices, each band
by designator: `pinsOnUnderlay`'s existing total order, with the rack leading
because `PLN-003` makes its absence cost every length on the plan. One comparator,
one place.

# Not ruled

The strip's appearance, height or collapse. `PLN-002` and `PLN-003` stay separate
advisories with separate remedies: **the strip is a surface, not a rule.**
