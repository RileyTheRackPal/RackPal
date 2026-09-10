---
type: Practice
title: A guard the model makes unreachable is not defence in depth
description: >-
  A redundant condition written out of habit survives being deleted, because no
  test can reach it. It is not free: it is a branch every later reader has to
  reason about, and it makes the mutation score of the file it sits in a lie.
  Delete it and name the invariant that made it unreachable.
tags: [practice, testing, mutation, invariants, plan-h]
timestamp: 2026-09-09T00:00:00Z
---

`PLAN-H/4`'s scale bar refuses an uncalibrated plan:

```dart
final nmPerPixel = underlay.scale?.nanometresPerPixel;
if (nmPerPixel == null || nmPerPixel <= 0) return null;
```

The second arm was written out of habit and **survived being deleted**.
`PlanScale.nanometresPerPixel` already returns null when the two picked points
coincide and when the typed distance is not positive, so a non-positive factor is
not a state the model can produce.

# Why a survivor here is a finding and not a shrug

The obvious reading of a surviving mutation is that a test is missing. **The
useful reading is to ask whether the branch is reachable at all**, because those
two conclusions lead opposite ways: one adds a case, the other deletes a line.

A guard the model makes unreachable costs three things:

- **It cannot be covered.** Any honest mutation score for that file is a lie by
  exactly one branch, and a reader chasing the gap wastes the time twice.
- **It makes a reader doubt the invariant.** A `<= 0` check beside a null check
  implies somebody has seen a zero. Nobody has, and now the next person writing
  against `PlanScale` has to go and find out.
- **It survives the invariant.** If `nanometresPerPixel` were ever loosened, the
  guard would silently start catching something and no test would notice the
  change of meaning.

# The rule

**When a mutation survives, ask "is this reachable?" before "what test is
missing?"** Trace the value back to whatever produces it. If the producer already
excludes the state, delete the guard and **name the invariant in its place**, so
the reasoning that made it safe is what the next reader meets.

The comment that replaces it is doing the guard's real job:

> AND THERE IS NO `<= 0` ARM, WHICH A MUTATION HAD TO ESTABLISH. One was written
> here out of habit and SURVIVED being deleted, because `PlanScale` already
> refuses a non-positive span and a non-positive distance.

# The opposite case, so this is not read as a licence

Two mutations in the same chapter **did not build**, and those are the shape worth
keeping: the uncalibrated return and the sheet's `if (bar != null)` are enforced by
the type system, so deleting them is a compile error rather than a silent pass.
See
[a mutation that does not build measures nothing](a-mutation-that-does-not-build-measures-nothing.md)
for why that verdict needs reading carefully: it measures nothing about the
TESTS, and it can still be a strong fact about the CODE.
