---
type: Design Ruling
title: DR-144 — A calibration carries its unit, and the number it reports back is not a length
description: >-
  PlanScale's whole derivation API has zero call sites in lib/ and no command sets
  a scale, so PLAN-F/2's "say N lengths changed" had nothing to count. The count
  becomes measurable pins, producing no Len; a typed distance must carry its unit,
  because a bare 36 is wrong by twelve either way.
tags: [ruling, plan-view, calibration, units, g4, dr-144, dr-141, dr-143, plan-f]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-144
canon_section: "11.143"
status: built
---

Settled by the user on 2026-09-08 at `PLAN-F`'s decomposition, before a line of the
chapter was written.

`PLAN-F` is three chapters over one sentence of docs/15 §5: *"two picked points and
one typed distance"*. The census found the previous two chapters' defect one field
over, and a hole in the chapter split that is only visible from outside any one of
the three.

# The model has no writer and no reader

`PLAN-C/2` built the calibration model, argued its rounding rule out in its own
header, and `PLAN-C/5` serialized it. Censused by call site, in `lib/` only,
excluding the declaring file:

| Built by `PLAN-C` | Call sites in `lib/` |
|---|---|
| `PlanScale.nanometresPerPixel` | **0** |
| `PlanScale.pixelSpan` | **0** |
| `PlanScale.isUsable` | **0** |
| `PlanScale.lengthBetween` | **0** |
| `PlanScale.lengthAlong` | **0** |
| `PlanUnderlay.isCalibrated` | **0** |

**And there is no writer either.** `plan_commands.dart` ships five command classes
covering six acts, none of which sets a scale, so `PlanUnderlay.scale` is null in
every document this product can produce.

This is the third instance in three chapters:
[DR-140](dr-140-the-rack-is-pinned-from-the-unpinned-strip.md) found the rack with
no pinning gesture, [DR-143](dr-143-the-importer-had-no-caller.md) found the
importer with no menu item. **A model is not a reachable field**, and after three
the finding is expected rather than surprising. See
[a-modelled-field-is-not-a-reachable-one](/practices/a-modelled-field-is-not-a-reachable-one.md).

# So the report had nothing to count

`PLAN-F/2`'s brief asks that a recalibrate changing N lengths says N, on
[G4](/invariants/g4-unknowns-are-counted.md)'s principle that every rollup reports
its unknown count.

**At `PLAN-F` there are no derived lengths at all.** `planLowerBound` is not a
`ScheduleLengthSource` value and nothing derives one; docs/15 §6's pin-drag row
already carries the note that its recompute clause is forward-dated to `PLAN-G`. A
report counting schedule rows would print `0` on every calibration in the product,
which is worse than silence: a G4 report whose number is an artifact of what has
not been built yet.

# What was ruled

**The count is of measurable pins, and it produces no `Len`.**

> Calibrated Level 1. 12 pins can now be measured from the rack.

> Calibrated Level 1. No rack is pinned on this plan, so no length derives yet.

Computable today from the scale's usability and whether any rack stands on this
underlay; the same set `PLAN-G` will turn into rows, so the number does not change
meaning when the tier arrives; and the second sentence is actionable in the view it
appears in, because the unpinned strip is along the bottom of the same screen and
the rack is its first row.

**A derivation returning a `Len` per pin would be `planLowerBound` shipped early
under another name**, without the rank, the `>=` prefix, the italic, the rollup
exclusion or `LEN-001`'s reading, which are five decisions DR-037 already took and
`PLAN-G` owns. Which rack is the datum when two are pinned is likewise left to the
chapter that derives the number.

**`Calibrate…` lives on the underlay row.** A calibration is a property of an
underlay, the left rail is the list of underlays, and docs/15 §6 says there is no
fourth region, so a canvas toolbar would be new chrome over a layout ruled eight
days earlier. The action reads `Calibrate…` on an uncalibrated plan and
`Recalibrate…` on a calibrated one.

**A typed distance carries its unit, and a bare number is refused by name.** `36`
is 36 inches or 36 feet, and the two differ by twelve applied to every length the
plan will ever yield. A guessed unit does not degrade a number, it produces a
confident number wrong by an order of magnitude on a drawing an installer trusts.

**It diverges from `parseLengthCell` deliberately.** That parser reads a bare
number as whole feet, because its column is whole feet of cable and refusing
everything else keeps the stored value equal to the displayed one. This field is a
distance on somebody else's drawing whose magnitude is not known in advance. The
two are not candidates for harmonisation, and a pass that unified them would
silently give calibration a default unit. See
[a-borrowed-rule-is-not-re-checked](/practices/a-borrowed-rule-is-not-re-checked.md).

**The pick is a mode on [DR-141](dr-141-one-arm-one-pin.md)'s shape, consumed by
its own second click.** The arm mode outlives each pin by design; a calibration
describes exactly one distance, so staying armed afterwards would offer to
recalibrate the plan immediately, which is not a workflow anybody has. `Esc` grows
a third rung: the pick, then the arm mode, then the selection.

**The writer moves into `PLAN-F/1`.** A dialog that parses a distance and has
nowhere to put it is the no-caller defect pointed the other way, and it could not
be gated green. `PLAN-F/1` takes the parser, the command, the row affordance, the
mode and the dialog; `PLAN-F/2` takes the epoch mask and the count; `PLAN-F/3`
takes uncalibrated as a first-class fact. Not a §8.3 amendment: nothing enters or
leaves roadmap §2 and no chapter is added or removed.

# Not ruled

`PLN-001`'s wording, severity or band, which are `PLAN-I`'s. Whether a calibration
can be cleared back to unknown, since undo covers the mistake a person notices and
docs/15 §5 asks for no clear. The scale bar, which `PLAN-H/4` rules is drawn and
never printed as a ratio. Which rack is the datum when two are pinned on one plan.
And whether the row should show when the calibration was taken or by whom, which
`EntityMeta` carries and no surface asks for.
