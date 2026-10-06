---
type: Design Ruling
title: DR-236 · One cable may carry several sets to several devices, added from the cable's own bar
description: >-
  A 16/4 tapped and continued is one cable. CR-014 always allowed it; AC-053 deferred the authoring. The
  cable bar's Add a set to this cable appends; one Pull Sheet row names every far end; every reader of a
  cable's ends reads every conductor. A §8.3 amendment.
tags: [ruling, amendment, breakout, conductor, link, cr-014, ac-053, dr-236, brk-a]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-236
canon_section: "11.235"
status: built
---

Settled by the user on 2026-10-04 for `#1000`. Epic `#1003` (BRK-A) under the v1 Saga holds it.

# What was ruled

- **Sets onto one cable come into v1**; hand-mapping individual conductors stays v1.1 (AC-053, narrowed in
  §12.51).
- **Added from the cable's own bar**: Add a set to this cable arms the set gesture from a device the cable
  reaches and appends, one undo step, tier 1 and DR-234's tier 2 as for any set.
- **One row, every far end named** on the Pull Sheet; a Termination Schedule line per end.
- **Every reader reads every conductor**, as CR-014 always required.
- **Trunk and branch, decided building it** (§11.235.6): the first conductor's route, a branch from a
  junction dot to each further device, the further pairs at a trunk device drawn into it. Where along the
  run a tap sits stays unknown unless stated ([G4](/invariants/g4-unknowns-are-counted.md)).
- **The census corrected the ruling** (§11.235.7): `link_lookup` was never one of the readers.

# What decided the scope

The question looked like "v1 or v1.1". Reading CR-014, the ruling the code cited for its two-ends shortcut,
showed the model had been v1 since the corpus was reconciled and only the gesture was deferred. See
[a wrong ruling ID resolves](/practices/a-wrong-ruling-id-resolves.md) for the family: a citation that
resolves is not a citation that says what the comment claims.

Canon §11.235 holds the full text.
