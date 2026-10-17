---
type: Design Ruling
title: DR-147 — The bound measures from the run's own rack, and the two rollups it must not enter are two
description: >-
  PLAN-G's census found two of its four briefs describing a tree that had changed
  underneath them: LEN-001 and LEN-002 already ship and never read the tier ladder,
  and there are TWO footage rollups where the booby-trapped switch guards one. The
  datum is the rack the run lands in, the floor enters neither sigma and is counted
  in both, a floor and a guess get two flags, and the rules read the floor only
  where it proves something. A later ruling that appeared to abolish the tier is
  scoped instead.
tags: [ruling, plan-view, length, schedule, rollup, validation, gates, dr-147, dr-020, dr-037, dr-050, plan-g]
timestamp: 2026-09-08T00:00:00Z
ruling_id: DR-147
canon_section: "11.146"
status: ruled
---

Settled by the user on 2026-09-08 at `PLAN-G`'s census, before a line of the chapter
was written. `PLAN-G` is four Chapters decomposed on 2026-08-10, and the census found
that half of them describe a tree that has moved since.

# Two briefs had expired

**`LEN-001` and `LEN-002` already ship.** `#639` says *"M5 owns the rules; this task
owns the input and the seam. Do not build the rules here."* It was written before M5
built them. They have been in `validation/rules_cable.dart` since M5-E.

**And they never read the tier ladder.** `knownLengthOf` is
`terminatedLength ?? cutLength`, so docs/15 §4.1's *"`LEN-001` and `LEN-002` read the
bound regardless of which tier printed"* describes a ladder those two functions have
never consumed. The seam the brief asked to be documented did not exist in the
direction the sentence implies. See
[a brief expires](/practices/a-brief-expires.md).

# There are two footage rollups and the trap guards one

`cable_footage.dart`'s `_isQuantity` is the one place in this tree where a future
decision was written into the build: an exhaustive switch with no default arm, so
*"the day it is added this file stops compiling and somebody decides, rather than a
bound silently joining a purchase."* **It worked**, seventeen months after it was
written down.

**And `schedule.dart`'s `_footageOf` is not behind it.** That function reads a `Len?`
and never asks where the number came from, and it builds `ScheduleView.footage` and
`ScheduleGroup.footage`, which is docs/08 §3.8's `Σ 11 runs · 601 ft · 3 estimated`
footer. `#638` names *"the footage rollup"*, singular. Another instance of
[a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md),
and the first where the gate is a compile error rather than a CI step.

# The datum is the rack the run lands in

[DR-144](dr-144-a-calibration-carries-its-unit.md) §11.143.3 left *"which rack when
two are pinned"* to this chapter. The bound is the straight line from the pin on the
rack **this link lands in** to the pin on this run's subject, and **no bound derives
at all** when that rack carries no pin, even when another rack stands pinned on the
same underlay.

*Nearest pinned rack* and *first pinned rack* were both refused. Each yields a bound
more often and a **wrong** one on any job with a head end and a satellite rack, which
is the ordinary shape of this work. A distance to a rack the cable does not go to is
not a weaker floor; it is another run's number wearing this one's authority, which is
[G4](/invariants/g4-unknowns-are-counted.md)'s failure in the one place a reader
cannot see it happening.

**The rule pays for itself twice.** "Exactly one end in a rack" is the whole gate, and
a jumper (both ends in one rack) and a sub-feed (ends in two) fail it without being
named. `plan_measurability.dart` already holds the other half: racks are the datum and
not the subject.

# The floor enters neither sigma and is counted in both

`Σ 11 runs · 601 ft · 3 estimated · 2 bound`. A `Σ` holding one floor and ten totals
is neither a floor nor a total. *Summed like an estimate* would give the sheet footer
and the materials page two different answers for one document; *excluded silently*
would make the footer shrink as more of the job got planned with nothing saying why,
which is exactly the reason `Rollup.unknownCount` exists.

**A bound row is still an unknown to the takeoff, and that is not a demotion.** The
question that rollup answers is how much cable to order, and a floor answers it not at
all. `boundCount` says how much of the ignorance has a floor under it. `runCount` and
`unknownLengthCount` do not move.

# A floor and a guess are two claims and get two flags

`lengthIsEstimated` stays **false** for a bound; `lengthIsBound` carries the `≥` and
the exclusion; the renderer italicises on either. A footer reading `5 estimated` on a
document holding three guesses and two measured floors is wrong about the one thing
that footer exists to say.

**The `≥` is in the string and the italic is not**, and the asymmetry is deliberate:
italic is a style a renderer applies and a plain-text export loses, while `41` and
`≥ 41` are different claims and the first is a number an installer cuts to. It is
composed in `ScheduleEntry.lengthCell` and never in the shared `scheduleLengthCell`,
which three round-tripping columns read.

# The rules read the floor only where it proves something

An unmeasured run whose floor **already exceeds** the limit is a proven violation with
its own message; a floor **under** the limit still emits *"length unknown, cannot
verify"*. That is
[DR-020](dr-020-no-predicted-routes.md) §11.19.2(2)'s asymmetry as executable code: a plan can prove a length violation and can never prove compliance.

Feeding the floor into `knownLengthOf` was refused. That function answers *"the length
this run is known to be"*, and a floor admitted there would pass a run under the limit,
turning the one statement a plan may honestly make into the one it may not.

**docs/02 §5.3's catalogue had already ruled this for `LEN-002` and not for
`LEN-001`.** Its `LEN-002` row reads *"fed by `cutLength`/`terminatedLength` when
known, and by a `planLowerBound` when that alone already exceeds the limit"*; the
`LEN-001` row says nothing of the kind. One shared predicate now serves both, and the
`LEN-001` row is corrected to match.

# And a later ruling that appeared to abolish the tier

[DR-050](dr-050-plan-geometry-fills-the-room-estimate.md) §11.49.2, dated **two days after**
DR-037 ruled the rank and two days after `PLAN-G` was decomposed, says in terms:
*"THEREFORE NO NEW TIER, AND THIS IS THE RULING. `ScheduleLengthSource` gains
nothing."* Neither ruling lists the other in canon §12.

Ruled scoped: DR-050 answers whether a figure derived from **room vertices** earns a
tier, and it does not. It does not reach the pin-to-pin floor. Its own §11.49.4
preserves `planLowerBound` by name, its §11.49.1 table lists the value as *"not
built"* rather than removed, and its stated objection is to a **provenance**
distinction between figures that all sum. A floor is not that: it is excluded from
every `Σ`, prefixed, and ranked below the estimate it can never replace. The
distinction it buys is behavioural.

**DR-050's own two items remain unbuilt and are nobody's**: no `Location` ceiling
height, no computed-versus-typed marker, no vertex gesture. That is why nothing in the
tree had ever made the two rulings disagree out loud.

# What it does not rule

Not a bound between two underlays. A carrier holds exactly one `PlanPin`
([DR-142](dr-142-what-the-unpinned-strip-lists.md)), so a rack pinned on `Level 1` can
never be the datum for a drop on `Level 2`, and a two-storey job yields bounds only on
the rack's floor; `PlanMeasurability` already reports that per underlay as
`noRackPinned`. Not `PLN-003`'s severity or band, which stay `PLAN-I`'s. Not the
as-built tally, which DR-020 put outside this feature. And not whether the Pull Sheet's
printed footer carries the bound count, which is `PLAN-H`'s sheet.
