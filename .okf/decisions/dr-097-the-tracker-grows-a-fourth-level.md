---
type: Design Ruling
title: DR-097 — The tracker grows a fourth level, and an epic's state follows its criterion
description: >-
  Saga to Epic to Story to Chapter, where a Saga is a release band so that moving
  an Epic between Sagas is the visible act of an §8.3 amendment. An Epic is Done
  when its exit criterion is met, not when its children run out. Written because
  the board had three met milestones sitting in the same column as one nobody had
  touched, and the cause was one level down.
tags: [ruling, process, board, tracker, azure-devops, dr-097, dr-095, dr-096, m0, m1, m3, m4]
timestamp: 2026-08-28T00:00:00Z
ruling_id: DR-097
canon_section: "11.96"
status: ruled
---

# DR-097 · The tracker grows a fourth level, and an epic's state follows its criterion

Board `#786`, `#787`, `#788`. Settled by the user 2026-08-28. Not a §8.3 amendment on
[DR-096](dr-096-the-product-is-rackpal.md)'s reasoning: nothing moves between scope bands,
only the shape of the container changes.

## The shape

| Level | Holds | Was |
|---|---|---|
| **Saga** | A release band: v1, v1.1, v1.2, v2 | did not exist |
| **Epic** | A milestone, or a ruling-born body of scope | Epic |
| **Story** | What a milestone decomposes into | `Issue` |
| **Chapter** | The unit of work a Story decomposes into | `Task` |

## A Saga is a release band, which is what stops it being decoration

A fourth level meaning "bigger than an epic" is a taller filing cabinet. This one carries
roadmap §2's scope list, the one list §8.3 governs, so **moving an Epic between Sagas is
the visible act of an amendment** that already had to cost a ruling ID. It also gives the
four scope epics that were impersonating milestones (macOS, the Store, the Plan view, the
community catalog) a level that does not imply an exit criterion.

## The price is a type change on every item, and it is paid knowingly

Azure DevOps lets an inherited process restyle, extend and disable a system work item
type. **It does not let one be renamed.** `Story` and `Chapter` are therefore new custom
types and all 759 items convert into them. Renaming only the backlog *tabs* was rejected
because the cards would still read `Issue`; adopting the Agile process was rejected
because it buys four levels at the price of Microsoft's vocabulary.

## An epic's state follows §8.1, and the drift that proved it needs saying

§8.1 already rules that the exit criterion is the unit of truth. The board was not reading
it. Measured 2026-08-27 against `docs/12`'s marks of the same day:

| Epic | `docs/12` | The board |
|---|---|---|
| M0 | `CRITERION MET`, 8 of 8 | `To Do`, 3 of 10 |
| M1 | `CRITERION MET`, 8 of 8 | `To Do`, 1 of 10 |
| M3 | `CRITERION MET`, 4 of 5, fifth parked | `To Do`, 17 of 18 |
| M4 | `IN PROGRESS` | `To Do` |

**The root cause was one level down**, and it is the transferable part. The clause-tracking
Stories were never closed when their clauses were discharged: `docs/12` had marked M0
clause 1 `DEMONSTRATED` since M0 closed, and the Story tracking it was still open. Worse,
`#32` and `#65` were closed the day before this ruling **and their Chapters `#508` and
`#514` were left open**, reproducing the drift inside the act of paying it down.

So: an Epic is `Done` when its criterion is met. Children still open then are re-parented
to whoever will deliver them. `#66`, M1's goal clause *"and it ships to real users"*, is
the worked example: `docs/12` marks it `NOT BUILT`, it was the one M1 row that did not
close, and it moved to M8 because M8 owns the installer.

## No work item may have no parent

Twenty-three items sat at the root, in no rollup and on no backlog, two of them Chapters
parented to nothing at all. **`#96`, `#97` and `#98` are post-M2 reviews and M2 closed on
2026-08-01**: three milestones overdue, and invisible the whole time, because an item with
no parent appears nowhere.

## The sweep that reached inside its own exclusion list

Measured over all 759 items: **694 carried `rackmate-sync`, exactly one carried
`rackpal-sync`**, against a convention `CLAUDE.md` already documented. The tag is an
identifier and is swept; titles quoting the old name are records and are not.

The sharper finding is the over-reach. [DR-096](dr-096-the-product-is-rackpal.md) §11.95.9
rules that the rename *"does not rename the Azure DevOps project, the repository or the
board's area path"*. `CLAUDE.md` nonetheless said all three were `RackPal`, so the sweep
edited a line inside its own ruling's list of exclusions, and every `az` command built
from that file failed with `TF200016`. **An exclusion list that is never turned into a
check is a comment.** See [a rule you invent must be checked against the good
cases](/practices/a-rule-you-invent-must-be-checked-against-the-good-cases.md).

## It ran, and what it found beats what it moved

746 items converted, 0 failed. The board holds **4 Sagas, 20 Epics, 218 Stories and 524
Chapters**, with **zero hierarchy violations and zero parentless items**, both re-derived
from a fresh query rather than read off the conversion log.

**The fourth level immediately found fourteen faults the third had been hiding**: four
Chapters sitting directly under an Epic, and ten Stories parented to another Story. All
pre-existing. A three-level board tolerates `Task`-under-`Epic` and `Issue`-under-`Issue`
in silence because **nothing in it can express that a level was skipped**. Adding a level
added no rules; it made an existing rule checkable, which is
[DR-095](dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md)'s argument arriving
in a different subsystem.

The sharpest was `#574`: DR-027's **parked** AC-018 PRINTS clause, the worked example
DR-095 uses to justify parking at all, sitting as a Chapter under M6 instead of beside
every other clause tracker.

`#779` turned out to be a **duplicate identifier**, titled `M4-K1` when `#226` already is,
on an unrelated subject. The title is left alone as a record and the collision noted on the
item, rather than renumbering a Done item and destroying the evidence that board IDs get
assigned by hand.

## Three platform facts, each of which cost a round trip

* **A project's process cannot be changed over the REST API.** `PATCH _apis/projects/{id}`
  with `capabilities.processTemplate` returns 400. Isolated rather than assumed: the same
  PATCH carrying only a `description` returns 202, so endpoint and credentials are fine and
  the capability is simply not exposed. Four clicks in the web UI are the only manual step
  in the whole migration.
* **The process API returns 200 while doing nothing.** Renaming a derived work item type,
  and renaming a state, both returned 200 with nothing changed. **A success code from this
  API is not evidence that anything happened**, which is what the non-vacuity floors say
  about a green test run. Every step was re-read rather than trusted.
* **A custom type is born with the state `To do`; the system types use `To Do`.** ADO will
  not rename a state, and refuses `To Do` as a duplicate while `To do` exists. The only
  route is delete-then-add, in that order. Caught before the migration; had it not been,
  766 items would have landed in a vocabulary matching no document in this corpus.

## What it does not rule

Not the project, repository or area path, which §11.95.9 settled and this only stops
`CLAUDE.md` contradicting. Not any exit criterion or scope band's contents. Not the Kanban
columns or swimlanes, which are a reversible team setting and not worth a ruling ID.
