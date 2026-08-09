---
type: Design Ruling
title: DR-026 — Two M3 answers taken as interim positions, because the Plan view may move them
description: Answers boards #157 and #153 together. A pathway designator is hand-entered because manual is the reversible direction; and Outlet.nominalRunLength is ratified as implemented, because the deadline to rule on it had already passed.
tags: [ruling, m3, pathways, lengths, reversibility, dr-026]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-026
canon_section: "11.25"
status: ruled
---

Settled by the user on 2026-08-09. Both halves are settled **for
reversibility** rather than permanently, because a floorplan speaks to both and
[DR-029](/decisions/dr-029-plan-view-in-v1.md) has since brought the Plan view
into v1.

# Half one: `Pathway.designator` exists and is hand-entered

The user's reason: *"once a trunk line is established in the home, it would be
nice to know exactly where it is relative to the plans."*

That is **[DR-020](/decisions/dr-020-no-predicted-routes.md)'s own distinction
applied to pathways**. The route is discovered, not designed, so a trunk already
established is an as-built fact; a generated designator would be the voided
design-time polyline in a shorter form.

`String? designator`, null unknown, **no allocator and no series**, unique where
set on CR-113's `rackLabel` precedent.

**Manual is the reversible direction and generated is not.** A nullable
hand-entered string can later gain an allocator; an allocated series cannot
become manual without abandoning the uniqueness it assumed. `Pathway.name` is
**not** overloaded to carry it, even though its doc comment shows `"B03"`,
because every other entity carries a name and an identifier separately: a trunk
called *"attic run to the garage"* and one called `PW-LR-1` are two facts.

# Half two: `Outlet.nominalRunLength` is ratified AS IMPLEMENTED, provisionally

Board #153 says to rule *"before anything reads it"*. **That deadline has
passed**, and the ruling is explicit that the task must not be picked up and
priced as preventive:

- `ScheduleLengthSource` already ships four tiers, `cut | outletNominal |
  roomEstimate | none`, and the second one's own doc comment declares itself
  *"a DELIBERATE addition, stated here rather than buried"*.
- `OutletField.nominalRunLength` is Command-backed.
- `whole_house` populates it on **all seventeen** outlets while setting
  `cutLength` on **none**, so the corpus's own fixture depends on it.

The tier stands as written: more specific than the room estimate, less
authoritative than a cut length, printed as an estimate and never as a
measurement.

**It is provisional and the Plan view is the named trigger.** Whether a
floorplan supersedes any of the four tiers is open. Note in advance that
[DR-020](/decisions/dr-020-no-predicted-routes.md) §11.19.2(2) forbids a
plan-derived bound entering the footage rollup as a quantity, so the tier that
eventually arrives will **not** behave like the three that are there.

# What this ruling cost when it was missed

The ruling reasoned FROM `ScheduleLengthSource`'s doc comment, and that comment
carried **no pointer back to it**. So the first place a reader would look for
the answer was the one place it was not, and M3-D/2 was briefly re-adjudicated
from scratch before the existing ruling was found. The citation now sits on the
enum and in docs/08's two derived sentences. See
[re-read a task against canon](/practices/re-read-a-task-against-canon.md).

# Scope

**No scope change to roadmap §2.** #157 gains a nullable field and no series;
#153 ratifies behaviour that already ships. Neither adds a milestone item.
**M3-E/2 and M3-D/2 are unblocked.**

# Citations

[1] canonical-decisions.md §11.25 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/derived/schedule.dart`,
    `ScheduleLengthSource.outletNominal`
[3] `apps/rackmate/assets/starters/whole_house.rmpj`, seventeen outlets with a
    nominal and no cut length
