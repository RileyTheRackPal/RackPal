---
type: Design Ruling
title: DR-045 — The field-crimped RJ45 plug, and an outlet that needs no plate
description: >-
  A Cat6 run that ends in a plug rather than a jack, because a keystone plus a
  patch cable is two extra connections on an AVoIP link. And the outlet that
  follows from it, which is finished and has no plate, and which the product had
  been calling unfinished since M3-H.
tags: [ruling, m3, structure, termination, g4, dr-007, dr-044, dr-045]
timestamp: 2026-08-12T00:00:00Z
ruling_id: DR-045
canon_section: "11.44"
status: ruled
---

Settled by the user on 2026-08-12, from two installation facts rather than from
the model: *"some instances (AVOIP/HDBT transceivers, namely) recommend not using
keystones/patch cables for reliability reasons, and most AP locations ... are on
low voltage boxes, but feature no plate/strap due to the AP mounting directly to
the box."*

# `TerminationType.rj45Plug`, printing `RJ45 PLUG`

A Cat6 run crimped into a male RJ45 plug and pushed straight into the device.

**It is not `keystone` and it is not `punchdown`**: both of those are a jack, and
the point of this termination is that there is no jack. Nor is it
`fieldConnector`, which names no connector and would leave the Termination
Schedule saying nothing to somebody deciding between a crimper and a punchdown
tool.

**The reason is reliability rather than tidiness.** A keystone plus a patch cable
puts two extra mated connections on a link carrying uncompressed video, and AVoIP
and HDBaseT vendors recommend a continuous run for exactly that.

# Zero cells, and this time it was asked

The plug goes into the device, so nothing sits in a keystone cell. It joins
`euroblock`, `unterminated` and `fieldConnector` in DR-007 §11.7.2.1's *"nothing
is on the plate"* row.

**[DR-044](dr-044-templates-carry-terminations.md) §11.43.4 is why it was asked.**
M3-H put `euroblock` at one cell silently, on an inference nobody wrote down, and
it took a seeding exercise to surface it. The same guess was available here and
was not taken.

> A termination's cell count is now a question this project asks out loud every
> time the enum grows.

# The AP template changes; TV location does not

`outlet.ap` moves from `punchdown` to `rj45Plug`: one Cat6 to an access point that
**mounts directly to the box**, so the run ends in a plug and the box needs no
plate at all.

**`TV location` deliberately does not change.** The user said *"some instances"*
recommend it, and a template asserting a plug for every TV in every job would put
a claim in a record nobody made. That is
[DR-024](dr-024-board-151-is-a-field-and-a-picker.md) §11.23.2's refusal and
DR-044's correction of it read together: a termination is a recipe fact, and
*"this recipe sometimes does X"* is not one. The drop line's `:rj45 plug` covers
the exception.

# An outlet that needs no plate, and the sentence that hid it

An AP box with one `rj45Plug` drop is **finished**: no gangs, no strap, no cover
plate, nothing missing.

**The product could not say that.** The Outlets tab read *"This outlet has no
gangs yet. Add one, or press Arrange…"*, which is the **undecided** sentence, so
a correctly-finished AP box read as unfinished work from M3-H until now. That is
DR-007 §11.7.4's blank-insert-versus-empty-cell distinction one level up and got
wrong the same way: *nobody has said* and *somebody said no plate* are different
facts, and the surface collapsed them.

**Three states, not two:**

| State | What it means |
|---|---|
| no drops land here yet | nothing to say. Not plateless, just empty |
| drops land here, **every one known to terminate off-plate** | **needs no plate.** Settled |
| drops needing cells, **or a termination nobody recorded** | a plate is missing, or nobody can say |

**An unknown termination falls in the third row and never the second.** "Needs no
plate" asserted over a drop nobody has terminated is a guess, and it is the guess
that would make a materials sheet omit a part somebody has to buy (G4).

# Derived, never stored

`PlateFill` already computed every input, and `isSettled` has returned true for a
plateless outlet since M3-H. **The derivation was correct and only the copy was
wrong.** A stored `hasPlate` flag would be the second copy of one physical fact
that CR-107 deleted `StructureDrop` over, and it would go stale the first time
somebody changed a drop's termination.

# What it does NOT settle

Asked how many cells a plug occupies, the user answered *"zero, but the plate is a
separate question"*: some off-plate runs still come through a **pass-through or
brush plate**, which occupies no strap cell and **is a purchasable line item**.

That is a third object and this ruling does not model it. §11.7.8 change 1 already
separates a strap from a cover plate; a pass-through plate is a plate with **no
strap behind it**, which `PlateFill.coverPlateGangs` structurally cannot express,
because that getter returns `gangs.length` and a plateless outlet has zero gangs
by construction. **Filed, not smuggled in.**

# Scope

**No scope change to roadmap §2.** One enum value, one seeded template, one
derived getter, one corrected sentence. `kSchemaVersion` does not move: enum
values serialize by name, so no document in existence contains this one.

# Citations

[1] canonical-decisions.md §11.44 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §11.7.2.1, §11.7.4 (DR-007), §11.43.4 (DR-044)
[3] `packages/rackmate_core/lib/src/derived/plate_fill.dart`
