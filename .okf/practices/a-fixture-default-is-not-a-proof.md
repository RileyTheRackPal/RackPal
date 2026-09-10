---
type: Playbook
title: A property proven by a fixture's default is not proven
description: >-
  Every plan fixture in rackpal_ui is built without a scale, so every pin gesture the
  suite ran was already the interesting case and passed for a reason nobody had named,
  while the mirror state was exercised nowhere. Ask which fixture field carries the
  property, then write the case that sets it the other way.
tags: [practice, testing, fixtures, verification, dr-146, plan-f]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

**A property that holds because a fixture's default happens to be the interesting
case is a property nobody would notice losing.** The suite is green, the behaviour
is real, and nothing in the file says the behaviour is what is being protected.

`PLAN-F/3` had to prove that *"pins place, and no length derives, and neither fact
is blocked by the other"* (docs/15 §5). Nothing in `lib/` gated a pin on a scale,
so the property held. **And every plan fixture in `rackpal_ui` is built without a
`PlanScale`**, which means:

* every pin gesture in the package was already a pin on an uncalibrated plan, so
  the first direction was exercised constantly and asserted nowhere;
* **the mirror direction was exercised nowhere at all.** A pin placed on a plan
  that IS calibrated appeared in no case in the package, because no fixture could
  produce one.

The two failures are different and both matter. The first leaves a property
protected by luck: a case whose name is about layout is what would go red, and the
person fixing it would edit the fixture. The second leaves a whole state untested,
and it is the state a later chapter will spend its time in.

# The check

For each property of the form "X does not block Y", ask **which fixture field
carries it**, and whether any fixture in the package sets that field the other
way. If none does, the property has never been tested, however many cases pass
through it.

Then write both cases through the **shipped gesture** rather than the model. A
gate would be added on a surface (a disabled row, a refused drop, a chip saying
"calibrate first"), and none of those is visible to a case that talks to the
document. `PLAN-F/3` confirmed that with one mutation per direction on the drag
handler: each kills exactly the case written for it, which is also what tells a
pair of cases apart from one case run twice.

# Why this is not the same as "assert the artifact"

[Assert the artifact, not the mechanism](assert-the-artifact-not-the-mechanism.md)
is about WHAT a passing case looks at. This is about **which states the fixture
can reach at all**, and a suite can obey the first perfectly while never leaving
one corner of the state space.
[Measure at the size the criterion will meet](measure-at-the-size-the-criterion-will-meet.md)
is the same idea for magnitudes: there the fixture was comfortable, here it is
one-sided.

# And again at PLAN-H/4, on a number rather than a flag

Every case in `plan_scale_bar_test.dart` used one calibration, 100 ft over
1000 px. A mutation replacing `PlanScale.nanometresPerPixel` with the literal
value that fixture happens to produce **passed all of them**: nothing in the file
could tell a bar that READS the scale from one with the scale baked in.

The first instance of this practice was a fixture default that was *absent* (no
`PlanScale` at all, so every pin gesture was already the interesting case). This
one is a fixture value that is *present and uniform*, which is harder to see,
because the field is set and looks deliberate.

**The check is the same and generalises to both**: ask which fixture field carries
the property, then write the case that sets it to a DIFFERENT value rather than to
none. A second calibration at ten times the pixels per foot kills the mutation.
