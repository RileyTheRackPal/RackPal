---
type: Design Ruling
title: DR-050 — Plan geometry fills the room estimate that already exists, and it buys cable
description: >-
  Room dimensions drawn on the plan fill Location.estimatedRunLengthFromRack, a
  field that already exists, already ranks below outletNominal and already sums.
  No new ScheduleLengthSource tier. A marker records that the software proposed
  the figure rather than a person. Built as LEN-A, where a census found the
  ruling had priced a tree that was not there: the vertices it assumed existed
  never did, and the field it fills had no editor anywhere since M3-D.
tags: [ruling, plan-view, estimating, schedule, len-a, dr-050, dr-020, dr-147, g4, ac-024]
timestamp: 2026-09-11T00:00:00Z
ruling_id: DR-050
canon_section: "11.49"
status: ruled
---

Settled by the user on 2026-08-12. Built as `LEN-A`, 2026-09-10 to 2026-09-11.

# No new tier, because the census corrected the question first

The request was put against the claim that DR-020 forbids an estimate from
entering the footage rollup. **It forbids a BOUND**, which is not the same
object, and the difference is the whole ruling: `cable_footage.dart`'s
`_isQuantity` returns true for `roomEstimate` today and says why in its own
comment.

So plan geometry becomes a **better way to populate a field that already
exists**. `ScheduleLengthSource` gains nothing. A fourth tier would buy a
provenance distinction the user's own ground says does not pay: wire is a
consumable quoted with margin.

# The ruling assumed a tree that was not there

§11.49.5 says the work lands with the Plan view *"which is where the
vertices and the calibration live"*. The calibration lived there. A census
found **no polygon, no outline and no room geometry of any kind**.

Six items rather than two, and the one nobody had noticed is not geometry:
`estimatedRunLengthFromRack` had **no editor anywhere** since M3-D, so
AC-024's one number per room was the only one of its three a person could
not type. See
[a brief expires](/practices/a-brief-expires.md).

# The figure, and the datum

**The farthest corner of a closed polygon plus `riseAllowance`.** Every
term measured, nothing invented, and it over-estimates, which is the safe
direction for a consumable.

**The datum is the rack this room's runs land in.** DR-147 ruled that the
BOUND measures from *"the rack this link lands in"*; a room estimate has no
single run, so that answer does not transfer verbatim. It transfers in
substance because of where the field is READ:
`estimatedRunLengthFromRack` is consumed per run in the schedule's length
ladder, so nothing reads the estimate until a run exists and a run names
its own rack. The estimate and the bound now measure from one rack by one
rule.

> The objection put against this was that quoting happens before the runs
> are drawn. It was wrong: a schedule row IS a run and the schedule is the
> quote basis. Recorded because the reasoning is what a later reader needs.

# A refusal that would have bought zero wire

A room served by two head ends takes the LARGER figure rather than
refusing. Drafted as a refusal and reversed after measuring one: the
length ladder falls through to `none`, and `_isQuantity` is false for it,
so **a refused estimate means every run in that room buys zero wire in the
takeoff**. Against a trade that quotes several hundred feet over actual, a
silent zero is the worst available direction of error.

**No margin is folded in.** DR-020 killed `routingFactor` and
`slackAllowance` and they stay deleted; the estimator's conservatism is
the estimator's.

# Computed is marked as computed, and never replaces a person

One nullable field, an enum rather than a `bool?` so the third state is
named: **absent means nobody recorded it**, which is every document written
before this work. The auto-fill may fill an empty field and replace the
software's own earlier guess; it may not replace a person, and an
unrecorded origin counts as a person's (G4).

Closing an outline writes the shape and the figure in ONE transaction,
because it is one act to whoever drew it.

# What this cost that nobody had priced

Two defects in command machinery, both filed rather than fixed in flight
because each repair changes the `Command` protocol every command
implements: a refused command still lands on the undo stack and undoing it
throws, and every second-act undo label is unreachable because the
transaction reads the label before `apply`.

And one of this epic's own gates failed to fail: a case asserting the
derivation had no production caller stayed green when the caller landed in
another package. See
[a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md).

**Related:** [DR-147](dr-147-the-datum-is-the-runs-own-rack.md) ·
[DR-144](dr-144-a-calibration-carries-its-unit.md) ·
[DR-154](dr-154-the-plan-advisories.md) ·
[DR-029](dr-029-plan-view-in-v1.md)
