---
type: Design Ruling
title: DR-050 — Plan geometry fills the room estimate that already exists, and it buys cable
description: >-
  The census corrected the question before it corrected the answer. DR-020 forbids
  a BOUND from summing, not an estimate, and the room estimate has been summing
  since M2-B. So the ruling adds no tier at all.
tags: [ruling, length, footage, plan-view, g4, dr-020, dr-046, dr-050]
timestamp: 2026-08-12T22:30:00Z
ruling_id: DR-050
canon_section: "11.49"
status: ruled
---

Settled by the user on 2026-08-12, from a request for Specifi-styled wire-run
length estimation off plan vertices and ceiling heights.

# The census corrected the question, not just the answer

The request was first put to the user against the claim that
[DR-020](/decisions/dr-020-no-predicted-routes.md) §11.19.2(2) forbids an estimate
from entering the footage rollup. **It forbids a BOUND.** Those are different
objects and the difference is the whole ruling.

| Source | Reachable? | Sums into a purchase? |
|---|---|---|
| `cut` | yes | **yes** |
| `outletNominal` | yes | **yes** |
| `roomEstimate` (`Location.estimatedRunLengthFromRack`) | **yes** | **yes** |
| `planLowerBound` | not built | **no**, DR-020 |

`cable_footage.dart`'s `_isQuantity` returns `true` for `roomEstimate` today and
says why: *"AC-024's own example is an ESTIMATED total plus waste, so an estimate
is a quantity here. `estimatedCount` is what keeps the figure's standing
visible."*

**So the shipped position was never that estimates may not buy cable.** It is that
they may, and that the count of them is reported beside the total. A framing built
on the opposite reached the user as an option list, and the census is what caught
it. Same shape as
[re-read a task against canon](/practices/re-read-a-task-against-canon.md), one
level out: the thing re-read was my own question.

# Therefore no new tier

`ScheduleLengthSource` gains nothing. Plan geometry becomes a **better way to
populate a field that already exists, is already written, and already sums.**

A fourth tier would buy a provenance distinction, and the user's ground is that
the distinction does not pay: *"it's used to estimate quotes, with a healthy
margin for error ... in most A/V companies, wire is a consumable."* **Machinery
for a distinction nobody acts on gets read as significant by the next person.**

# A computed value is marked as computed, and that is DR-046 honoured

When geometry proposes the figure, the field records that it was **proposed rather
than typed**. [DR-046](dr-046-rack-end-is-its-own-termination.md) ruled that
nothing may copy a field termination into the rack termination, because a schedule
that fills the second column can no longer tell a stated value from an assumed one.

**What differs is the cost of being wrong, and that is why the answers differ.**

| | Termination | Length |
|---|---|---|
| Kind of fact | discrete part | continuous estimate |
| A wrong value | orders a keystone jack for an F barrel | is absorbed by a margin the user sets |
| So the default is | nothing infers it | geometry may fill it, marked |

**A rule applied without that test would have forbidden this feature on the
strength of a precedent about a different kind of fact.** The marker is one
nullable field, and it exists so a later reader asking *"did somebody measure this
room or did the software guess"* has an answer.

# DR-020 is not weakened

`planLowerBound` remains forbidden from the rollup. The route is still
**discovered rather than designed**; the route polyline, `routingFactor` and
`slackAllowance` are still deleted and still not to be re-argued from. Framing
decides the path and framing is not knowable when the plan is drawn.

**A room's dimensions are not a route.** What this adds is a way to compute a
*room-level* figure from measured geometry instead of from recollection, into a
tier that already existed for room-level figures. **A per-drop figure derived from
a drawn path remains forbidden.**

# Citations

[1] `docs/canonical-decisions.md` §11.49
[2] `packages/rackmate_core/lib/src/derived/cable_footage.dart`, `_isQuantity`
[3] `packages/rackmate_core/lib/src/derived/schedule.dart`, `ScheduleLengthSource`
