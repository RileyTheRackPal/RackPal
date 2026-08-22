---
type: Practice
title: A stated cost is a hypothesis until it is measured
description: Three times a number written into a ruling or an issue decided what got built, and three times measuring it changed the answer. The cost that justifies a deferral is the least likely to have been measured, because deferring is what excused measuring it.
tags: [practice, estimation, corpus, measurement, dr-057, dr-076, dr-080]
timestamp: 2026-08-21T00:00:00Z
status: adopted
---

This corpus is unusually good at recording **why**. It is not reliably good at
recording **how much**, and the two are written in the same voice by the same
author in the same paragraph. A reader trusts the second because the first
earned it.

# Three instances, and they are not the same mistake twice

| | The stated cost | What measuring found |
|---|---|---|
| [DR-057](/decisions/dr-057-pitch-is-a-refinement-not-a-prerequisite.md) | Sparse `pitch` cuts auto-layout to 14 of 45 templates | The price came from a derived document's **pseudocode**. Every ruling says layout flows from footprints. **The cut was never real** |
| [DR-076](/decisions/dr-076-the-schematic-rebuilds-what-changed.md) (`#702`) | AC-008's eight per-domain sub-pictures are the fix | Symbols alone are ~75 ms of a ~96 ms build and are **domain-independent**, so a perfect eight-way split cannot touch them. The issue's own prescription was the smaller half |
| [DR-080](/decisions/dr-080-the-accent-reaches-the-elevation.md) | Wiring `accentColor` regenerates four goldens and must clear PAL-1 | `accentColor` occurs **0 times** in the starters and **0 times** in `catalog/`, so no golden moves; and `pal1_check.py` has **no device concept** to clear. Both halves wrong |

# The rule

**Before acting on a number a document states, run the thing that produces it.**
A grep, a count, a best-of-N timing. It is minutes, and it is the difference
between a decision and a repetition.

This applies *hardest* to numbers written in this repository, not least: an
external spec is read sceptically by default, while a figure in our own canon
arrives pre-trusted because the argument beside it is good.

# The tell, and it is the useful half

**The cost that justifies a deferral is the one least likely to have been
measured, because deferring is precisely what excused measuring it.** DR-059
deferred `accentColor` on a price nobody had run, and the price stood unchallenged
for as long as the deferral did. So the numbers to distrust first are not the ones
in the work you are doing: they are the ones in the paragraph explaining why some
other work is not being done.

# What this is not

It is not
[re-read a task against canon before pricing it](re-read-a-task-against-canon.md),
which is about a task asking a question a later ruling already answered. Here the
citation is current and correct and the **quantity attached to it** is wrong.

It is also not licence to re-litigate. DR-080 corrects the number and
**leaves §11.58 as written**, because a ruling is the record of what was believed
on the day and editing that falsifies it. Record the measurement in the new
ruling; leave the old one standing.
