---
type: Playbook
title: A gate's scope is part of its claim, so read its scan and not its name
description: >-
  The reachability gate caught an unreachable callback one chapter and missed an
  entire unreachable feature the next. It scans function-typed fields on *Actions
  records in one package; the importer was free functions in another. Both facts
  are in the gate's source and neither is in its name.
tags: [practice, gates, reachability, census, plan-e, plan-g]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

A green gate is a claim about **what it scanned**. Every gate has a scope, the
scope is narrower than the name, and the difference is where defects live.

# The instance

At `PLAN-E/3`, [callbacks-have-callers](/gates/callbacks-have-callers.md) refused
a finished callback because nothing supplied it, and it was right; that became
[its own practice](a-gate-can-move-a-chapter-boundary.md).

One chapter later, `PLAN-E/5`'s census found that **the entire floorplan importer
has no caller**: six functions and a dialog, all built, all tested, reachable
from nothing, so `AddPlanUnderlayCommand` had no producer and no project could
contain a floorplan. The board was green throughout.

The gate could not have fired. It scans:

- **function-typed fields on `*Actions` records** — the importer is free
  functions;
- inside **`packages/rackpal_ui/lib`** — the importer is in `apps/rackpal/lib`.

Two independent misses, and the file is called `plan_import_actions.dart`, which
reads like something that gate covers.

# The shape

**"We have a gate for that" is not a finding; it is a hypothesis about scope.**
The failure is not that the gate is bad. It is that a gate's *name* is a summary
written for the case it was built for, and a reader one chapter later applies it
to a case it never saw.

This is [a-ticket-is-a-hypothesis-not-a-diagnosis](a-ticket-is-a-hypothesis-not-a-diagnosis.md)
pointed at the tooling instead of at a brief.

# And a third instance, where the gate is a compile error

`PLAN-G` found the same shape in the most trusted mechanism this repository has.
`cable_footage.dart`'s `_isQuantity` is an exhaustive `switch` with no default arm,
left that way on purpose so that *"the day it is added this file stops compiling and
somebody decides, rather than a bound silently joining a purchase."* **It worked**,
seventeen months after the comment was written: adding
`ScheduleLengthSource.planLowerBound` stopped the build in exactly one place.

**In exactly one place.** `schedule.dart`'s `_footageOf` builds the sheet footer's
`Σ 11 runs · 601 ft · 3 estimated` by reading a `Len?` and never asking where the
number came from, so a plan-derived floor would have joined that total with nothing
to stop it. `PLAN-G`'s own ticket said *"the footage rollup"*, singular, on the
strength of the trap's reputation.

**A gate that stops the build is still a gate with a scan**, and the scan here is one
function's argument type. The rule below is unchanged; what this adds is that being a
compile error buys certainty about the site it guards and says nothing whatsoever
about the site beside it.

# The rule

**Before relying on a gate to have covered something, read its scan.** Two
questions, both answerable in under a minute from the gate's own source:

1. **What does it match?** A regex over a class shape, a type predicate, a
   filename convention. Anything expressed differently is invisible, however
   similar it looks.
2. **Where does it look?** Almost every gate in this repo names a root. A gate in
   one package says nothing at all about another.

And when you actually need the answer, **census by call site rather than by
gate**: for each public entry point a chapter claims to have built, grep for its
name across `lib/` and subtract its own file. It is one command per symbol,
it produces a number rather than a feeling, and it is what found this. See
[census-before-building](census-before-building.md) and
[ask-what-consumes-each-tasks-output](ask-what-consumes-each-tasks-output.md),
which ask the same question earlier and cheaper.

**A count of zero is the finding.** Write it down as a number, in a table, per
symbol, so the next reader can re-run it instead of trusting it.
