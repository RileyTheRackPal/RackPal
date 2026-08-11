---
type: Design Ruling
title: DR-039 — A drop lands on a panel port, and the rack label is allocated
description: >-
  M3's exit criterion wants forty-six of sixty drops landed at a rack. The product
  could only make the fourteen kind, sixty times, and three of the four tokens in
  the shipped rack-label preset had no reachable source. Found by census before the
  drill rather than by stopwatch after it.
tags: [ruling, structure, m3, ac-018, labels, endpoints, census, dr-039]
timestamp: 2026-08-11T12:00:00Z
ruling_id: DR-039
canon_section: "11.38"
status: ruled
---

Settled by the user on 2026-08-11, from a census taken before M3-G's stopwatch.

# The instruction that produced it

Board #163 reads *"run the drill EARLY, on a rough build ... a drill run on a rough
build finds them while the design can still move"*. Read as a procedure that is a
person and a clock. Read as an instruction it is **find the reasons it cannot pass
while they are still cheap**, and three of them were reachable from a grep.

# What the census found

M3's criterion wants sixty drops of which **forty-six land at a rack** and fourteen
stay open. The product could only make the second kind.

| Absence | Evidence |
|---|---|
| Nothing allocates a `rackLabel` | `allocateOutletRackLabel` has four callers, all in its own test file |
| Nothing binds a far end | `drop_build.dart:159` never passes `rackEnd`; every drop is `OpenEndpoint('not yet landed')` |
| `BindEndpoint` was never written | zero `.dart` files, though canon §2186, `docs/01` §535 and `docs/02` §663 all cite it |
| `{FLOOR}` and `{SPACE}` have no editor | one occurrence across the whole UI and app, in a comment saying so |
| `{PANEL}` has no source field | it is in the token set and in the shipped preset, and nothing in the model answers it |

**Three of the four tokens in `{FLOOR}{SPACE}-{PANEL}{PORT:2}` were unreachable.**
The preset could not have rendered on any document this product has written, and
would still not have rendered if the binding alone had been built. That is the
finding that would have cost the *second* drill run rather than the first.

# The ruling

1. **A landed far end is a `PortEndpoint` on a patch panel device.** `BindEndpoint`
   materialises the port inside `apply()`, as [DR-011](/decisions/dr-011-connect-gesture.md).1
   already rules for the connect gesture. `derivePortId` is a pure UUIDv5 over
   `(deviceId, portKey)`, so no panel needs pre-materialised ports.
2. **The gesture is `@panel=` on the drop line.** Ten modifiers cover forty-six
   drops, which keeps the drill near its measured 5.82 keystrokes rather than
   adding forty-six typed cells to a fifteen-minute clock.
3. **The rack label is allocated, never typed**, through the one format engine, on
   the field label's precedent. A typed string is governed by no pattern.
4. **The drop lands on the REAR port.** The catalog archetype's own description
   says why: rear ports are 110 punchdown, and modelling both faces as RJ45 is
   the error that makes the Termination Schedule wrong on the column the trim
   tech needs.

# Two sub-decisions, and why neither invented a field

**`{PANEL}` is the panel device's designator.** `1A-A12` is a TIA-606 example, not
a specification, and it names no source. The model has one identifier for a panel
because **the model has no `Panel` entity**: `schedule.dart` already says so, calling
a patch panel *"a `DeviceInstance` like any other"*. So the default preset renders
`1A-PP-101`. A `panelLetter` field added to reproduce the example would be inventing
a fact nobody stated in order to match a rendering, which is
[DR-028](/decisions/dr-028-keystone-cell-is-the-front-nose.md) §11.27.2's error with
the provenance running the other way.

**A bind that cannot render a label still binds.** The endpoint and the label are two
facts and [G4](/invariants/g4-unknowns-are-counted.md) forbids fusing them. A panel
whose location carries no floor number produces a bound `PortEndpoint` and an absent
`rackLabel`, with a sentence naming the field to fill. Refusing the bind would let an
unrelated missing token undo a physical fact somebody stated.

# What it does not settle

**`LNK-020` stays M5's.** Its canonical text is literally *"14 links have unbound
endpoints"* and after this it can finally say something true, but the rule catalogue
is M5's and building one rule early buys nothing.

**Unbinding is not ruled.** The command gets a `revert` because every command does;
a deliberate "this was punched into the wrong port" gesture is not specified here.

**The front jacks are untouched.** This lands a drop on the rear and says nothing
about patching the front to a switch, which is the schematic's job.

# Why it is a decomposition gap and not a scope change

Nothing enters or leaves v1. This is the criterion's *existing* clauses being made
reachable, which is a build, on the precedent of #591 and #587 in this same
milestone: a capability the corpus promised, that no task owned, found by
[censusing before pricing](/practices/census-before-building.md). The cost is fair
to record anyway, since four tasks arriving at an exit criterion have the same
effect on a calendar as a growth would.
