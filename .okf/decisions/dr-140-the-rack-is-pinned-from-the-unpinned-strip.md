---
type: Design Ruling
title: DR-140 — The rack is pinned from the unpinned strip, because nothing in PLAN-E pinned it at all
description: The rack carries a PlanPin, docs/15 calls it not optional, PLN-003 fires without it, and no gesture in any of PLAN-E's five chapters put one there. Each chapter was coherent; the set had a hole visible only from outside all of them. The strip lists every unpinned carrier, so its count means everything the plan still owes.
tags: [ruling, plan-view, pins, decomposition, dr-140, plan-e, pln-003]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-140
canon_section: "11.139"
status: built
---

Settled by the user on 2026-09-08, on a hole found by
[checking the decomposition](/practices/check-a-decomposition-for-holes.md)
before any code was written.

# The model was ready and nobody could press the button

docs/15 §3.4 lists three pin carriers and marks the rack's *"**Not optional to
the design.** A home run is measured *from the rack*. Without the rack pinned,
no length on that plan is derivable at all"*. `PLN-003` exists to say so, and
the epic's exit criterion requires *"the rack plus every drop of a real
rough-in"* to carry a pin.

`Rack.planPin` shipped at PLAN-C. `SetPlanPinCommand` has accepted
`PinCarrier.rack` just as long. **The only missing piece was somebody able to
press it**: docs/15 §6's gesture table has four rows, and the palette places a
**device**, the drop table pins an **outlet**, the strip listed **devices**, and
pan/zoom/marquee select nothing new.

> Each of PLAN-E's five chapters is coherent on its own. The **set** had a hole,
> and it was visible only from outside any one of them.

This is [ask what produces each task's input](/practices/ask-what-produces-each-tasks-input.md)
again, after M4's five tasks that built a port grid and never created a port.

# Why it is a hard block rather than a polish item

A plan whose rack is unpinned yields no `planLowerBound` **anywhere**. So
`PLAN-G` derives nothing, `PLAN-H`'s `T1.01` prints callouts with no lengths
behind them, and `PLAN-J`'s drill hands a stranger a printed sheet missing the
one measurement it promised. It was ruled at once rather than noted.

# The ruling, and the two declined

**The strip lists every unpinned CARRIER, not only devices**: off-rack devices,
outlets and racks alike. Dragging a row out of it onto the plan pins that row,
which is the gesture the strip already implies and which `SetPlanPinCommand`
already performs.

| Declined | Why |
|---|---|
| A dedicated *"Place rack"* control | Most discoverable for the first pin, the one that unlocks every length. But docs/15 §6 says in terms that there is **no fourth region and no plan-specific palette**, and a control existing to place one kind of thing is a second mechanism for a job the strip is shaped for |
| Drag it out of the location tree | Reuses a region that exists and shows the hierarchy a rack belongs to. But CR-112 makes that tree **read-only**, and turning a read-only panel into a drag source changes its character for one case |

**The strip is the right home because of what it makes the count mean.**
`PLAN-E/4`'s brief says the strip *"is the difference between a plan that is
trusted and a plan that is 80% complete without saying so"*. A strip omitting
the rack **is** that 80%-complete plan: the one absent pin that costs every
length would be the one thing the count could not see.

# The hazard this creates on purpose

The count is now a count of **carriers**, not of devices, and the two differ on
any document with an unpinned rack. **A strip built from `doc.devices` alone
passes every test whose fixture has no rack.** `PLAN-E/4` must assert on a
document where the two answers differ, which is that chapter's own warning about
the status bar that read *"0 pathways"* the keystroke after somebody made one.

`PLN-002` and `PLN-003` do not merge. They stay separate advisories with
separate remedies; the strip is a surface, not a rule, and may show what two
rules report without collapsing them.

# Not ruled

Whether a rack row is visually distinguished from a device row, and how: UI/UX,
and the user's. The strip's ordering. Whether a rack may be pinned on more than
one underlay, which every carrier already answers by holding exactly one
`PlanPin`.
