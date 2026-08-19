---
type: Decision
title: DR-074 — A drop punched into the wrong port can be moved, and the label follows the hole
description: Two commands, because a move and an unland are two acts with two consequences; the rack label follows the position unless a person typed it; the termination survives both.
tags: [m3, structure, schematic, undo, g4, cr-113, cr-117, ux]
timestamp: 2026-08-19T00:00:00Z
status: built
---

For two milestones the product could record where a cable landed and could
never record that the record was wrong. DR-040 §11.39.6 named the gap in the
words the ruling later quoted back: *"a deliberate 'this was punched into the
wrong port' gesture is not specified here."*
[DR-071](/decisions/dr-071-landing-a-drop-is-a-gesture.md) §11.70.4 and DR-073
§11.72.7 each recorded it as still owed.

# Two commands, not one with a nullable

A MOVE re-lands an end on a different jack in **one command and one undo
entry**, because making a person unland and then re-land costs two steps and
leaves the document momentarily saying something false: that a cable nobody has
moved is lying loose in the rack.

An UNLAND is its own command, on `link_class_commands.dart`'s split and for its
stated reason: folding it in as a nullable target makes the common case carry a
null it never wants and gives the Edit menu **one label for two opposite
actions**.

# The bit, and why it could not be a table row

The rack label is derived from the position (DR-040 §11.39.3), so a move
re-derives it: `1A-PP-101` on a cable now in position 04 is a wrong hole number
on the one column a trim tech works from, which is worse than no label. But the
`RACK LBL` column lets a person type one, CR-113 makes it unique project-wide,
and discarding somebody's own identifier is the loss
[G4](/invariants/g4-unknowns-are-counted.md) refuses.

`StructureOrigin.rackLabelLocked` tells the two apart, **absent when false on
the wire** following `Link.linkClassLocked` and deliberately not
`designatorLocked`, which is written unconditionally and would rewrite every
document on disk ([CR-117](/invariants/cr-117-byte-exactness.md)).

> **AMENDED BY DR-075 (§12.26).** §11.73.2 said the bit is written by the
> `RACK LBL` cell *"and by nothing else"*, which was aimed at the ALLOCATOR and
> caught the CSV importer with it. **An imported rack label locks too**: a
> `rack_label` column is a person choosing an identifier through a different
> door. Everything else in the clause stands.

**It is not a `StructureOriginField` row, and could not be.**
`SetEntityPropertyCommand.revert` calls the same `set` closure `apply` does, so
a row that locked on the way in would re-lock on the way back out and an
assertion would survive its own undo. `SetRackLabelCommand` writes the pair.
This is the second instance of the shape
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
collects from the other side: a write path can be generic and still be the
wrong place for a rule.

**A blank cell clears the lock as well as the label.** A locked null would say
"nobody may ever name this", reachable by the ordinary act of emptying a box and
undoable by no surface at all: the one-way door `ClearLinkClassOverrideCommand`
exists to refuse.

# What must not follow the cable

* **The termination survives both.** `terminationRack` says how the cable END
  is finished, not which hole it sits in, and a run can be punched onto a block
  this project does not model at all. Clearing it would assert the crew undid
  work they may never have touched, which is a fabrication in the direction G4
  forbids.
* **The freed pin stays**, on `ConnectPortsCommand`'s rule. It reads as free
  through `portConductorCount` the moment anyone asks, and that is the whole of
  what "freed" has to mean.

# The surfaces, and the one gesture named to forbid

The ruling left the gestures to the task and they were settled by the user on
2026-08-18 and 2026-08-19:

* A landed row's `LANDS ON` cell gets **the same panel menu** an unlanded one
  gets, meaning MOVE, plus a **`NOT LANDED`** entry on the `CLASS` column's
  `AUTO` precedent. DR-071 §11.70.3's text-only rendering is **spent rather
  than wrong**: it existed because re-landing was unruled.
* Picking the panel a drop is **already on** moves it to that panel's next free
  hole, which is the only way to say "not this hole" from a table where the
  product picks the hole.
* **Dragging a landed pennant** onto a free jack moves that end. It is the only
  surface where a person names the hole the crew actually used.
* **Dragging to empty canvas must not mean unland**, which §11.73.5 names to
  forbid: a stray drag away from silently undoing a termination.

**The hit test had to learn WHICH pennant.** `linkAtPoint` answers with a link
id, and a run landed at both ends draws two pennants carrying the same one, so a
gesture built on that answer moves whichever end the code names first. The two
readings run in opposite directions off one press: a half-landed run's single
pennant means *finish the other end*, a landed run's means *move this one*. One
rule covers both, and it is what keeps the preview honest: **the anchor is the
end this gesture is not writing**.

# What writing the tests found that reading did not

* **A move never exhausts a panel**, because a moving cable frees the hole it
  leaves. The refusal it does hit said *"that drop was not landed"*, which tells
  a person their cable is loose when it is exactly where they left it.
* **`buildBindEndpointCommand` was still saying a move is impossible** four
  commits after it became possible, behind a `contains('already landed')`
  assertion that could not see it. See
  [print the output before claiming copy is done](/practices/print-the-output-before-claiming-copy-is-done.md).
* **Three spellings for one physical state.** `_endOf` prints an
  `OpenEndpoint`'s description straight into the schedule's TO column, and the
  corpus had *"not yet landed"* from the create path and *"Rack end not yet
  terminated"* on 27 open ends in the shipped starters. The two paths code
  controls now share one constant; **documents on disk keep their own words**,
  because the string is persisted and rewriting it would move every file's
  bytes.
