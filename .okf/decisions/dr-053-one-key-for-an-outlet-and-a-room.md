---
type: Design Ruling
title: DR-053 — The typed line and the CSV agree on what identifies an outlet and a room
description: >-
  Two entry paths disagreeing about whether two things are one thing. The
  argument that settles it was already written forty lines away in the same
  file, about panels, and nobody had applied it to outlets.
tags: [ruling, structure, csv, drop-line, m3, cr-042, dr-053]
timestamp: 2026-08-13T00:00:00Z
ruling_id: DR-053
canon_section: "11.52"
status: ruled
---

Settled by the user on 2026-08-13, closing board #654, which was filed during
M3-F/6 as a defect found while building something else and deliberately not
fixed there.

# A wrong answer, not a missing one

`drop_line_planner.dart`'s `_resolveOutlet` matches an `Outlet` by `designation`
**alone, project-wide**. docs/07 §5.3.2 states the key as
**`(locationId, designation)`**.

`Attic: 2x Cat6 @outlet="WP-1"` on a project with a Living Room `WP-1` hangs the
attic's drops **on the Living Room's plate**, and nothing refuses, because as far
as the planner is concerned the outlet resolved. The drops carry the wrong room on
the Pull Sheet, in the per-room footage subtotals, and in the schematic's room
grouping.

**It is the normal residential case.** docs/07 §5.2's own worked example uses
`WP-1`, `CLG`, `AP-1`, `CAM-1..6`, none room-scoped by construction.

# The argument was already in the file, about something else

Forty lines away, `_resolvePanel` refuses to match a device by NAME, and says why:

> A designator is the identifier printed on the rack and on every schedule
> (CR-042); a device NAME is free text that two panels can share, and a gesture
> that landed on *"whichever Patch Panel matched first"* would put the drop in a
> different rack depending on map order.

**That is about outlets word for word.** `doc.outlets` is a map, its iteration
order is not a fact about the project, and first-match-wins over free text is the
same defect the same file already refuses one function along. The lesson is not
"read the docs": it is that **a rule already argued for one entity is evidence
about its neighbours**, and nobody had carried it across.

# A repeated name is reported and never refused

When the typed room has no such outlet and another room does, the planner creates
the new one **and says which room already carries that name**.

Refusing would be wrong, because two rooms with a `WP-1` is ordinary. Silence
would be wrong for a narrower reason: **a mistyped room name and a genuine second
plate produce the identical outcome**, so the moment the product declines to join
them is the only moment it can say anything useful. A note rather than a refusal,
because G3 forbids a heuristic holding the work hostage.

# Whitespace collapses, it is not stripped

The typed line matched on trim and lower-case; CSV import implements §5.3.1's
case- **and whitespace-**insensitive rule. So `Living  Room` with a double space
created a second room from one path and matched the existing one from the other.
**Two entry paths disagreeing about whether two rooms are one room** is how a Pull
Sheet ends up with two Living Rooms.

Internal runs collapse; whitespace is not stripped outright. `Living  Room`
matches `Living Room`; `LivingRoom` does not. Stripping would catch one more typo
class and would also make two names a person reads as distinct unrepresentable in
one project, which is a larger claim than §5.3.1 makes.

# Nothing migrates

Resolution happens **at gesture time** and no key is stored, so no document
changes, no byte moves, and `kSchemaVersion` does not advance. What changes is
which `Outlet` the next typed line joins.

# Citations

[1] `docs/canonical-decisions.md` §11.52
[2] `packages/rackmate_core/lib/src/structure/drop_line_planner.dart`
[3] `docs/07-structure-device.md` §5.3.1, §5.3.2
