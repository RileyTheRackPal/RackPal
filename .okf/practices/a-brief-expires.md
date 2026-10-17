---
type: Practice
title: A brief expires, and the census that checks the tree will not notice
description: >-
  A task written at decomposition describes the tree AND the canon of the day it
  was written. Reading it against the tree catches the first kind of drift and is
  blind to the second: PLAN-G's four briefs went stale three ways in four weeks,
  and the one that mattered was a ruling made two days after the brief.
tags: [practice, process, decomposition, canon, census, plan-g]
timestamp: 2026-09-08T00:00:00Z
---

`docs/12` §1 already says to read a decomposition against the tree before starting,
and the Plan view epic's own preamble repeats it. **That instruction catches one of
the two ways a brief goes stale.**

# The two kinds of drift

**The tree moved.** The brief names a file, a field or a milestone that has since
changed. A census by grep finds this, and this bundle already carries the habits for
it: [census before building](/practices/census-before-building.md),
[ask what produces each task's input](/practices/ask-what-produces-each-tasks-input.md).

**The canon moved.** A ruling landed after the brief was written and changed what the
task is allowed to do. **No amount of reading the tree finds this**, because the tree
is where the ruling has *not* been applied yet. That is the whole reason the ruling is
open work.

# PLAN-G, decomposed 2026-08-10, started 2026-09-08

Three of its four briefs had expired, in three different ways:

| Brief | What it said | What was true |
|---|---|---|
| `#639` | *"M5 owns the rules; do not build the rules here"* | M5 built them at M5-E. The chapter is a change to shipped rules |
| `#639` | *"`LEN-001` reads the bound whichever tier printed"* | Those rules read `terminatedLength ?? cutLength` and have never touched the ladder |
| `#638` | *"the footage rollup"*, singular | Two rollups. The exhaustive-switch trap guards one of them |
| `#603` | *"`planLowerBound`, the fifth tier"* | [DR-050](/decisions/dr-050-plan-geometry-fills-the-room-estimate.md), **two days after the decomposition**, says *"`ScheduleLengthSource` gains nothing"* |

The first three were found by a census against the tree. **The fourth was not, and
could not have been**, because the tier did not exist in the tree either way: an
absence is what both readings predict. It surfaced only when the chapter's brief was
read against the canon, one commit after the tier had already been added.

# The check

**Before starting a chapter, diff the canon against the brief's own date.** Every
ruling settled after a task was written is a candidate to have changed it, and there
are rarely more than a handful. `git log --since=<brief date> -- docs/canonical-decisions.md`
is the whole tool.

**And when two rulings collide, the later one does not automatically win.** DR-050 is
later and more absolute, and it is still scoped, because its own text preserves the
value it appeared to abolish and its stated reason does not reach it.
[Two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md);
two rulings disagreeing is not a supersession either. It is a question for the person
whose rulings they are.

# Why the record gets the note and not just the fix

The collision is written where a reader **meets** it, in DR-050's own §11.49.2, and not
only where it was resolved. A reader who arrives at *"`ScheduleLengthSource` gains
nothing"* through a search has no reason to look three hundred sections further on, and
the corpus's own convention for two sources that disagree is to flag them in place
rather than reconcile them silently.
