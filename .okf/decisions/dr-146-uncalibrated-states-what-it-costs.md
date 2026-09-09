---
type: Design Ruling
title: DR-146 — An uncalibrated plan states what it costs, and the count is one population in both directions
description: >-
  PLAN-F/3's census found its lead clause already built, its second clause true but
  proven only by a fixture's default, and a count with no reader: pinnedCarrierCount
  shipped one chapter earlier naming the underlay row as its caller, and the row
  printed a bare "Not calibrated". The row now prints PLN-001's own sentence, over
  the same population in both directions, and the field is replaced rather than kept.
tags: [ruling, plan-view, calibration, g4, copy, testing, dr-146, dr-144, plan-f]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-146
canon_section: "11.145"
status: ruled
---

Settled by the user on 2026-09-08 at `PLAN-F/3`'s census, before a line of the
chapter was written. It is the last of
[DR-144](dr-144-a-calibration-carries-its-unit.md) §11.143.7's three chapters, and
its three clauses came back in three different states.

# One clause was already built

*"`scale == null` means uncalibrated and never acquires a guessed value."*
Censused by site: `PlanUnderlay.scale` is nullable and documented, `isCalibrated`
reads `scale?.isUsable`, the encoder writes no key at all, the decoder has no
fallback, `SetPlanScaleCommand.scale` is non-nullable so no gesture can write
"unknown", and the derivation gates on `isCalibrated` rather than on presence.
Six sites, no substitution, and the absent key and null read-back are already
asserted. `PLAN-C/5` and `PLAN-F/1` discharged it between them.

# One was true and proven by accident

*"Pins place, and no length derives, and neither fact is blocked by the other."*
Nothing in `lib/` gates a pin on a scale, so the direction holds. **And not one
test said so.** Every plan fixture in `rackpal_ui` is built without a `PlanScale`,
so every pin gesture the suite ran was already a pin on an uncalibrated plan and
passed for a reason nobody had named, while the mirror direction, a pin on a plan
that IS calibrated, was exercised nowhere in the package. See
[a fixture's default is not a proof](/practices/a-fixture-default-is-not-a-proof.md).

# And one was a count with no reader

`PlanMeasurability.pinnedCarrierCount` shipped at `PLAN-F/2` carrying a doc
comment that named its own intended caller: *"a surface that had only the first
would report a fully pinned plan as empty."* **Zero call sites in `lib/`.** That
surface is the underlay row, and the row printed a bare `Not calibrated`, so a
plan carrying thirty-nine stranded pins read exactly like a plan with none.

This is the fourth of the shape in four chapters, and the smallest:
[DR-140](dr-140-the-rack-is-pinned-from-the-unpinned-strip.md) found a model with
no gesture, [DR-143](dr-143-the-importer-had-no-caller.md) an importer with no
caller, [DR-144](dr-144-a-calibration-carries-its-unit.md) a derivation API with
neither, and this one a *count* nothing reads. See
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).

# Ruled: the row names what is stranded, in one population

> Not calibrated · 39 pins carry no measurable position

The words are docs/15 §9's own `PLN-001` sentence, so that the row and the
advisory `PLAN-I` will file say one thing rather than two.
[G4](/invariants/g4-unknowns-are-counted.md) is why the line exists: a rollup
reports its unknown count rather than the flattering total, and an uncalibrated
plan's unknown count is every drop standing on it. A plan with nothing stranded
says only the state, because the count is the cost.

**The population is the half that was actually being decided.** The alternative
counted the rack as well, which is what the old field held and what a person
counts on screen. It fails across the two states rather than in either one:
thirty-nine stranded becomes `Calibrated · 39 measurable` under the chosen
reading, and **forty becomes thirty-nine** under the other. A number that drops by
one at the moment of a calibration reads as a pin the calibration ate. The rack is
the datum on both sides and belongs in neither count.

So `subjectPinCount` **replaces** `pinnedCarrierCount` rather than joining it,
because keeping an unread field beside a read one, one chapter after a census
found it unread, is this epic's own recurring defect preserved on purpose. And
`measurableCount` becomes a derived getter: stored, it sat beside the two flags
that decide it, and a constructor could be handed a count its own flags forbid.

# Ruled: the sentence lives in core, and the proof is a gesture

`PLN-001` is a validation rule and rules live in `rackpal_core`; the underlay row
lives in `rackpal_ui`. A sentence written on the surface would have to be copied
into core when `PLAN-I` files the finding, and a copied sentence disagrees with
its original the first time somebody edits one of them. So it is written once,
beside the count it reports.

**And both directions are asserted through the shipped gestures.** A case that
runs `SetPlanPinCommand` against a document proves the command, and the command
was never where a gate would be added: a gate is a disabled strip row, a refused
drop or a `Calibrate first` chip, and none of those is visible to a test that
talks to the model. Two mutations on the drag confirm it, one per direction.

# What this does not rule

Not `PLN-001`'s severity, its band or its behaviour as an advisory, which stay
`PLAN-I`'s under DR-144 §11.143.8: this chapter supplies the state and the
sentence and files no finding. **Not a document-level rollup**, which `PLAN-I` can
assemble from the per-underlay derivation it already has; building one now, for a
rule that does not exist, would be committing this epic's recurring defect on
purpose. And not the reading a stored-but-unusable scale produces, where the state
line says `Not calibrated` while the action still says `Recalibrate…`: both halves
are ruled, they are deliberate, and the combination is reachable only from a file
this product cannot write.
