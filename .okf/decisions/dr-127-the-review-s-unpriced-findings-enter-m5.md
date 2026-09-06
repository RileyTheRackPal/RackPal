---
type: Design Ruling
title: DR-127 — A §8.3 amendment, because "unpriced" is not a state a milestone can close over
description: >-
  DR-125 disposed of twelve review findings and left four as "unpriced". That word
  agrees a finding is real and says nothing about who builds it, so the review's own
  consequences were sitting outside any scope list. Five items enter M5, none of
  them a new rule. The estimate is deliberately NOT amended.
tags: [ruling, process, scope, amendment, m5, roadmap, dr-125, dr-126, section-8-3]
timestamp: 2026-09-05T00:00:00Z
ruling_id: DR-127
canon_section: "11.126"
status: ruled
---

# DR-127 · Unpriced is not a state a milestone can close over

Board `#305` (M5-H2). Settled by the user 2026-09-05: *"might as well finish them
out while they're fresh."*

## Why an amendment and not a disposition

[DR-125](dr-125-the-review-s-twelve-findings.md) priced eight of its twelve
findings and marked four **unpriced**. Unpriced agrees the finding is real and says
nothing about who builds it, so those four sat outside roadmap §2, which §8.3 makes
the one scope list. **This is the amendment, in its own commit, with its own ruling
id**, which is what §8.3 requires.

| Board | What |
|---|---|
| `#837` M5-J | The remedy prompt generalises to `SIG-002`, `CON-001`, `PWR-003` |
| `#838` M5-K | `ELE-006`: a tap selector, and CV-to-Low-Z switching |
| `#839` M5-L | `PLC-001`: a cabinet head end, the COMMON residential case |
| `#840` M5-M | `CODE-002` wants more than a row in a panel |
| `#842`/`#841` M5-N | Census `p()`'s parameters against `PortDef`'s fields |

**The fifth is [DR-126](dr-126-the-catalogue-was-calling-two-signals-by-one-name.md)'s,
not the reviewer's**, and it is the only one of the six that could have been
scheduled BEFORE the review rather than after it.

## No rule is added

The catalogue stays at 28. CR-021 and AC-040 are untouched, and M5-H1's pack told
the reviewer in writing that *"whether there should be MORE checks"* was not being
asked. **Every item changes what an EXISTING rule offers or how it reads**, which
is the difference between answering the review and reopening the rule set.

## The cost note, recorded rather than glossed

The amendment rests on M5's buildable work being finished. **That was measured
before the day's findings and is no longer quite true**: DR-126 alone added a
signal family, a builder parameter and a test file.

**The ESTIMATE is not amended**, because an estimate is not scope and changing it
here would confuse the two. What is recorded is that M5-H2 produced buildable work
at a rate no decomposition predicted, four rulings in two days, so **M5's remaining
cost should be re-measured before M6 opens**, which §8.9 makes a live question
rather than a tidy one, since M6 opens only over a predecessor whose clauses are
discharged or parked.

**The sign-off is not blocked on any of this.** `#305` and `#306` close on the
REVIEW, a human act, and a clause is discharged by evidence rather than by an empty
backlog (§8.1).
