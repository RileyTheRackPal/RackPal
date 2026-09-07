---
type: Design Ruling
title: DR-135 — M5 closes, the Plan view opens over it, and the minor stops being a milestone number
description: >-
  M5's three clauses were discharged; what was outstanding was the re-measurement
  DR-127 demanded before a successor could open, and it found nothing left. The
  successor is the Plan view, not M6. That epic was deliberately given no
  milestone number, so the version scheme had no digit to read off it, and the
  user ruled it takes `0.6`. The minor now means the epic's position in the
  plan's order.
tags: [ruling, process, milestone, versioning, plan-view, m5, m6, dr-029, dr-127, dr-017]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-135
canon_section: "11.134"
status: ruled
---

# DR-135 · A milestone closes on a measurement, and the successor exposed a hole in the version scheme

Settled by the user on 2026-09-07. Three acts, one decision: M5 closes, its
successor opens, and the successor is the first epic on this board the version
scheme could not name.

## M5 closes on a measurement, not on an emptied backlog

All three clauses were already discharged. What was outstanding was a sentence
DR-127 §11.126.4 left behind: **M5's remaining cost should be re-measured before
its successor opens rather than after.** That sentence existed because DR-127
had itself amended M5's scope with five items on the day of the domain review,
four of them unbuilt. **A clause discharged is not a backlog emptied**, which is
[a stated cost is a hypothesis](../practices/a-stated-cost-is-a-hypothesis.md)
wearing a milestone's clothes: DR-127 took its amendment on the ground that M5's
buildable work was finished, and that had stopped being true by the time the
sentence was written.

**This ruling is that measurement.** Twenty Stories under epic 23, all `Done`;
61 `Done` Chapters beneath them; none open, none re-parented. `#845`, the second
sign-off pass, is not outstanding M5 work: it was re-parented to M9 because it
can only be performed against a product a team has used, which docs/12 §5.4.11.3
argued before anybody needed the answer.

**The remaining cost is zero, and that is a measurement rather than a shrug.**
The distinction matters because the alternative reading, *nothing is left because
nobody has filed anything*, is how a milestone closes over work it never counted.

## The successor is the Plan view, and the request named M6

DR-029 §11.28.4 and roadmap §4 sequence the Plan view **between** M5 and M6:
M6's criterion is that all four starters export a *complete* sheet set, and a
plan sheet arriving afterwards would make that criterion run twice. docs/12 §5.4
says the same thing in the section a person closing M5 would be reading.

The request that opened this work still said *"M6 needs to be opened, and M6-A
started"*, and self-corrected before anything was built. **Recorded because the
sequencing lives in three documents and was still nearly missed**, which is
evidence the note earns its place rather than a reprimand.

## The hole the epic exposed in the version scheme

docs/14 §14.0 defines the version minor as *"the milestone epic under
development"* and spells the rule `M2 ⇒ 2, M3 ⇒ 3`. **The Plan view is an epic
with no milestone number**, and DR-029 §11.28.4 withheld one on purpose. So the
scheme admitted no answer for the epic now under development: there is no digit
to read off a name that has none.

**The user ruled that the Plan view takes `0.6`.** The minor therefore means the
epic's **position in the plan's order**, not the digit inside a milestone's name.

| Epic | Band |
|---|---|
| M5 Validation | `0.5` |
| The Plan view | `0.6` |
| M6 Full sheet set | `0.7` |
| M7 Platform and access | `0.8` |
| M8 Release engineering | `0.9` |
| M9 Beta hardening | `0.10` |

The cost is named rather than discovered one bump at a time: from `0.7` onwards a
reader who learned the shortcut `Mn ⇒ n` is wrong by one for the rest of v1.

## Why this renumbering is cheap and DR-029's was not

The two questions look identical and are not. DR-029 refused to renumber M6 to
M10 for this same epic; DR-135 renumbers the band for it without hesitating.

**The difference is entirely in what carries the number.** A milestone number is
duplicated into hundreds of `M6-A1`-shaped task titles, docs/12 §5.3 to §5.8's
headers, §12.7's cost table and dozens of canon references, none of which any
tool can rewrite safely. A version minor lives in **six files with one gate over
them**, `version_parity_test.dart`, which fails the build the moment one is
missed.

**Renumbering costs whatever the number has been duplicated into.** The same
decision is therefore right in one place and wrong in the other, and neither
answer is evidence for the other. It is the repository's standing rule about
duplicated numbers read from the far end: the usual lesson is that a second copy
of a moving number goes stale, and the corollary here is that a number with
exactly one gated copy set and no prose copies is a number you are still free to
change.

## What it does not rule

**No milestone is renumbered.** `M6` is still `M6` on the board, in every task
title and in every document; DR-029 §11.28.4 stands. It does not re-price the
Plan view, whose `L` at 9 to 13 weeks is DR-029's and which §11.36.7 already
refused to re-estimate at decomposition. It moves no scope between release bands,
so it is **not a §8.3 amendment**; it is a process ruling in DR-017's class. It
does not touch the major, which stays `0` until a public release. And **opening
an epic discharges nothing**: all seven of the Plan view's clauses remain
`NOT BUILT` or `UNPERFORMED`.

See [DR-029, the Plan view ships in v1](dr-029-plan-view-in-v1.md),
[DR-127, unpriced is not a state a milestone can close over](dr-127-the-review-s-unpriced-findings-enter-m5.md)
and [decompose before building](../practices/decompose-before-building.md).
