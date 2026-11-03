---
type: Design Ruling
title: DR-021 — deleting a Location cascades the subtree and clears every reference
description: The location tree had four commands owed and no delete semantics at all. The subtree goes, every one of nine references is cleared to null rather than left dangling, and the count is computed once before anything moves.
tags: [ruling, m3, delete, undo, locations, tree, dr-021]
timestamp: 2026-08-06T00:00:00Z
ruling_id: DR-021
canon_section: "11.20"
status: built
amended_by: [DR-185]
---

Settled by the user on 2026-08-06, before board #144 wrote a line of the four
commands the tree has never had.

# Why a delete needed a ruling and the other three did not

Add, rename and reparent each have one obvious meaning. Delete has three, and
the corpus picks none of them: `docs/02` §4.2 gives `Location` its `parentId`
and `docs/07` §2 says rooms are not owned by the Structure editor, but no
document in the corpus says what removing a node costs.

The tree is also the one entity where the omission compounds. `parentId` makes
the damage recursive (CR-047), and **nine fields across seven entities point at
a location from outside the tree**.

# The census, which is part of the ruling

| Carrier | Field |
|---|---|
| `Rack` | `locationId` |
| `DeviceInstance` | `locationId` |
| `OffRackPlacement` | `locationId` (immutable) |
| `Outlet` | `locationId` |
| `StructureBody` | `distributionDeviceLocationId` |
| `Circuit` | `locationId` |
| `Pathway` | `fromLocationId` |
| `Pathway` | `toLocationId` |
| `PlaceEndpoint` | `locationId` (immutable) |

A case-sensitive grep for `locationId` returns seven of the nine. It misses
both of `Pathway`'s, because they are spelled `fromLocationId` and
`toLocationId`. **The question this ruling answers was asked with seven and
answered against nine**, which is
[census before building](/practices/census-before-building.md) paying out on a
small question: the field, printed over the corpus, disagreed with the name it
was expected to have.

# The ruling

**The subtree goes**, in one undoable command. Deleting a node deletes every
descendant.

**Every reference is cleared to null**, never left dangling. Null is
[G4](/invariants/g4-unknowns-are-counted.md)'s unknown and is what the
derivations already read: a drop whose room is cleared prints under the Pull
Sheet's own `NO ROOM RECORDED` band rather than vanishing from the deliverable
or acquiring an invented room.

**The count is computed once**, before anything moves, and the command consumes
it: [DR-013](/decisions/dr-013-delete-cascades.md) §11.13.2's shape for
DR-013's reason.

**Undo restores all of it with the same ids**, and one step further than
DR-013 needed to go. `OffRackPlacement` and `PlaceEndpoint` are immutable, so
clearing them means constructing replacements, and `revert` must put the
ORIGINAL objects back rather than reconstruct equal ones.
[CR-117](/invariants/cr-117-byte-exactness.md) is the property that says so.

**A reparent refuses a cycle**, walking child to parent with a visited set and
a sentence naming both nodes, exactly as `TOP-005` walks a shelf chain.

# The two options that were rejected

**Promote the children** onto the deleted node's parent. Cheap, and it destroys
nothing. It was rejected because it leaves every surviving room carrying a
breadcrumb nobody edited it to have, and a vocabulary whose addresses change
without an edit is the failure `docs/00` opens with: *"the plan says Study, the
homeowner says Office, the label says Room 3, and nobody wins"*. That failure is
the reason the location tree exists.

**Leave the ids dangling.** Cheaper still, and it is even defensible on G4
grounds, since every derivation already reads an unresolvable location as
unknown. It was rejected because a file reopened next month cannot tell a
dangling id from data loss. CR-017's *"the document may not lie"* is precisely
about a file asserting a thing that is not there.

**Refusal** was not re-argued. DR-013 §11.13.3 settled it: CR-017 reserves
refusal for the five tier-1 topology rules, whose escape `docs/02` §5 gives as
*"None. There is nothing to escape to."* Wanting a room gone is not that.

The cycle refusal is not an exception to that. A cycle is not a design the user
disagrees with, it is a tree that is not a tree, and every derivation over it
(roots, the path to a node, the breadcrumb, the Pull Sheet's own room order) is
non-terminating rather than wrong.

# What it deliberately does not do

**It deletes no `Link`, `Outlet`, `Pathway` or drop.** A cable pulled to a wall
is a fact about the building and survives the room being renamed out of
existence, which is the argument `RemoveStructureCommand` already makes about an
outlet surviving the panel it feeds. DR-013's cascade stops at this boundary and
is not authority to cross it.

It also does not rule where a location may be deleted from. The panel is board
#145's question.

# Built at `b23007d` (board #84), and what building it found

`derived/location_tree.dart` reads the shape, `derived/location_removal.dart`
computes the cost, `commands/location_commands.dart` writes it, and
`rackmate_ui/src/project/` is the panel. ~100 tests.

**Two carriers were found by censusing the field rather than grepping its
name**, and they are the reason this concept carries a table. See above.

**The delete reaches further than DR-013 had to, and the difference is
immutability.** Everything DR-013 removed was a whole entity it could hand
back on revert. Two of the nine carriers here are immutable value objects,
so clearing them CONSTRUCTS replacements, and revert has to restore the
originals rather than rebuild equal ones. The byte comparison is what
states that: a rebuilt `Conductor` compares equal to the one it replaced
and encodes identically only if every field came back, so a field-by-field
walk would miss the one nobody thought of.

**The panel's own delete dialog says "lose their room", never "be
deleted".** §11.20.6 deletes no rack, cable, outlet or pathway, and a
confirmation implying otherwise describes a cascade this ruling refuses to
perform, so a user would cancel a safe delete out of a fear the product
invented.

# Citations

[1] canonical-decisions.md §11.20 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/derived/connect_rules.dart`, `_shelfChainFault`,
    the cycle walk §11.20.5 reuses
[3] `packages/rackmate_core/lib/src/derived/device_removal.dart`, the plan shape
    §11.20.3 reuses
[4] `packages/rackmate_core/lib/src/derived/schedule.dart`, `kUngroupedTitle`

# Amended by DR-185

**The census is ten across eight now.** [DR-185](/decisions/dr-185-a-plan-page-says-its-name-and-its-floor.md)
gave `PlanUnderlay.locationId` its first writer, and a plan showing a deleted floor is cleared and
restored on exactly these terms (canon §12.37). The nine above were right when counted: the tenth
field existed and could not be set.
