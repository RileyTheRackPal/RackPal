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

## What it does not rule

Not the project, repository or area path, which §11.95.9 settled and this only stops
`CLAUDE.md` contradicting. Not any exit criterion or scope band's contents. Not the Kanban
columns or swimlanes, which are a reversible team setting and not worth a ruling ID.
