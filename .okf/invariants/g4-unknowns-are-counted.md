---
type: Invariant
title: G4 — an unknown is counted and shown, never guessed
description: Where a value cannot be determined, the system reports that it cannot, rather than substituting a plausible default.
tags: [invariant, g4, correctness]
timestamp: 2026-08-09T00:00:00Z
ruling_id: G4
status: enforced
---

When something cannot be determined, **say so and count it**. Do not substitute a
default that looks like an answer.

This is the most frequently load-bearing rule in the codebase, because the
tempting failure is always silent.

# Worked examples

**A link's class.** `effectiveLinkClassOf` returns `null` for undetermined.
Defaulting to `fieldCable` asserts a pull nobody established; defaulting to
`jumper` hides a real one from the Pull Sheet an installer works from. Both are
worse than a count of links whose class could not be determined. See
[DR-008](/decisions/dr-008-wiring-model.md).

**Schedule rows.** Undetermined-class links are excluded from *neither* preset.
They land in a trailing `CLASS NOT DETERMINED` band, are counted, and are kept
out of room footage subtotals so an unestablished run's length cannot join one.

**Rollups.** `totals.dart`'s `Rollup.unknownCount` is the precedent: a subtotal
with no known contributor is `null`, **not `0`**. Zero is a claim; null is not.

**The cable takeoff, where the claim is money.** `derived/cable_footage.dart`
(M3-D/3) is the sharpest case yet, because `0` there does not read as *"we
measured nothing"* but as **"buy none"**. A room whose lengths simply have not
been entered must not print as if it needed no cable, so a media type with no
known contributor is null and so is its waste figure: ten percent of *"we do not
know"* is not a number. The same file shows the rule's second half working, the
part that is about what may be COUNTED rather than what may be shown: only
`fieldCable` reaches a purchase quantity, and jumpers, power cords, internal
links and **undetermined-class runs** are each excluded and counted by reason.
The undetermined exclusion is the one that looks like an omission and is the most
G4 of the four.

**Connector footprints.** Both dimensions null means no footprint has been
authored, never estimated. A shipped catalog template must not reference such a
connector, and CI asserts it.

**An uncalibrated plan, where the unknown is a whole surface.** A plan with no
scale derives no length, and the underlay row printed a bare `Not calibrated`, so
a plan carrying thirty-nine stranded pins read exactly like a plan with none. That
is this rule's flattering half: a state reported without the count of what it
costs. The row now prints `PLN-001`'s own sentence,
`Not calibrated · 39 pins carry no measurable position`, and it is the same
population the calibrated line reports, so the number does not move when the
calibration lands ([DR-146](/decisions/dr-146-uncalibrated-states-what-it-costs.md)).
**The scale itself stays null and never acquires a default**: a guessed factor
does not degrade a length, it produces a confident one that is wrong by an order
of magnitude on a drawing an installer trusts.

**A plan floor is excluded from every footage total and COUNTED in each one**
([DR-147](/decisions/dr-147-the-datum-is-the-runs-own-rack.md)). A bound cannot be
summed into "how much Cat6 to order", so the row sits in `unknownCount` exactly as a
lengthless row does and `boundCount` says how much of that ignorance has a floor under
it. The alternative that was refused is instructive: excluding it *silently* is also
"correct" arithmetic, and it makes the sheet's `Σ` shrink as more of the job gets
planned with nothing on the page explaining the shrinkage. **Counting the exclusion is
the whole rule; performing it is the easy half.**

**And the floor never becomes an estimate.** `lengthIsEstimated` is false for it,
because that flag is what the footer's `N estimated` counts, and one count cannot
carry two claims: a guess and a measured floor fail differently.

**Registry ids.** An id that resolves to nothing degrades to `unknown(rawId)`:
round-trips, renders grey with the raw id as its tag, never throws. M2-B's
`unresolvedSignalFamilyCount` equalling its row count was this rule *working*,
and the standing alarm that surfaced
[DR-010](/decisions/dr-010-seeded-registries.md).

# The test shape that enforces it

A mutation that replaces `null` with a plausible default must fail a named test.
In practice that means asserting the **count**, not just the rendered value,
because a defaulted value looks perfectly reasonable in isolation. The assertions
that catch it are of the form "this was counted as unknown", not "this printed
correctly".

# Citations

[1] `packages/rackmate_core/lib/src/derived/totals.dart`
[2] `packages/rackmate_core/lib/src/derived/schedule.dart`
[3] `packages/rackmate_core/lib/src/derived/link_class.dart`
[4] `packages/rackmate_core/lib/src/derived/cable_footage.dart`
