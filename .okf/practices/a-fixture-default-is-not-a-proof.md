---
type: Playbook
title: A property proven by a fixture's default is not proven
description: >-
  Every plan fixture in rackpal_ui is built without a scale, so every pin gesture the
  suite ran was already the interesting case and passed for a reason nobody had named,
  while the mirror state was exercised nowhere. Ask which fixture field carries the
  property, then write the case that sets it the other way.
tags: [practice, testing, fixtures, verification, mutation, dr-146, dr-156, dr-158, plan-f]
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

# And a third time at PLAN-H/5, where the fixture default was a COUNT

`plan_schedule_test.dart` asserted the sort's id tiebreak over two rows sharing
an area and a reference, and deleting the tiebreak entirely **passed**. Dart
sorts a list shorter than about thirty-three by insertion, which happens to
preserve the order the rows arrived in, and longer lists by a dual-pivot
quicksort, which does not. Measured: ten rows survive a comparator that returns
zero, forty do not.

**The fixture field here is the SIZE of the collection**, which is the easiest of
the three to overlook because nobody thinks of it as a field. The same question
answers it: which property of the fixture carries the behaviour, and what would a
case that sets it differently look like. Two rows was a fixture default in
everything but name.

# And a FOURTH, which is a different shape: a fixture too small to tell two rules apart

**DR-156 §11.155.2, 2026-09-12.** A transaction may take its label from its
first child. The case written to pin that had a refused command followed by one
real one, and `#863`'s fix drops the refusal, so by the time the rule ran
`children.first` and `children.last` were **the same object**.

The case passed. It would have passed against the opposite rule. **A mutation
reading `children.last` SURVIVED**, and it was the only one of four that did.

Nothing in the repository distinguished which end of a transaction names it, and
the two-child case is real: the rack canvas stacks a library copy under an add
and is named after the add, so an implementation that picked the wrong end would
have mislabelled a shipping gesture.

**This widens the practice from a fixture's DEFAULT to a fixture's SHAPE.** The
original instance is a field whose default happened to be the interesting case.
This one is a collection whose length made two different rules indistinguishable.
Same root: the fixture decided the outcome, and the code was never asked.

**The check, for a rule that picks one of N:** does the fixture have at least two
candidates, and are they distinguishable in the assertion? A rule about *the
first* needs a case where first and last are different objects, or it is a rule
about *the only*.

# And a FIFTH: a fixture default that removed a WIDGET from the tree

**`#871`, DR-158, 2026-09-12.** A trash icon was added to the device browser's
card and list row, and `device_browser_screen_test.dart` asserted that pressing
it reports the template id. Six cases, all green.

**The same press through the real shell did nothing at all.**

The card's `InkWell` carries `onDoubleTap` **only when `onEdit` is non-null**, and
that is what puts a `DoubleTapGestureRecognizer` in the gesture arena. A
double-tap recogniser holds the arena open for its own timeout, so the inner tap
cannot win until it expires; `pumpAndSettle` returns as soon as no frame is
scheduled, which is immediately, and the press never lands.

**The test file's `_app` helper defaulted `onEdit` to null.** No recogniser, no
arena contention, every press landed. The shipped shell always passes an `onEdit`,
because the browser's primary verb is opening a template, so the arena the tests
exercised was one the product never builds.

**This is the first instance where the fixture default changed the SHAPE OF THE
WIDGET TREE rather than a value in the model.** The three before it are a field's
default, a collection's length and a collection's contents; all of those are data
the code reads. This one is a callback whose nullness decides whether a competing
gesture recogniser exists, which no assertion in the file could have mentioned.

It is also the exact false positive [a control with no
caller](a-modelled-field-is-not-a-reachable-one.md) is about, arriving from the
other side: a control that tests as wired and behaves as unwired.

**The check, for any press on a surface with optional callbacks:** ask which
callbacks the SHIPPED host passes, and pass those. A widget test's helper is a
second configuration of the product, and a configuration nothing ships is a
configuration nothing is learned from. When the press goes through a gesture
arena at all, follow `tap` with a timed `pump` rather than a bare `pumpAndSettle`,
and say why in the helper.
