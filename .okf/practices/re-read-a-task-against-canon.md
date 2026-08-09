---
type: Playbook
title: Re-read a task against canon before pricing it
description: A task written before a ruling can be asking a question that is already answered. Two of M3-D's four tasks were, both by rulings dated after the tasks were written, and one of them was briefly re-adjudicated from scratch before the existing ruling was found.
tags: [practice, process, rulings, planning, m3]
timestamp: 2026-08-09T00:00:00Z
status: adopted
---

A board task is a **snapshot of what was unknown on the day it was written**.
Canon moves faster than the board. Before opening a task, re-read its question
against `docs/canonical-decisions.md` §11 — especially any task whose text asks
for a decision rather than for code.

# Two instances in one issue, which is what makes it a practice

**M3-D/2 (#153)** asked to *"ratify or overrule"* `Outlet.nominalRunLength` as a
length source *"before anything reads it"*.
[DR-026 §11.25.2](/decisions/dr-026-two-interim-m3-answers.md) had already
ratified it, provisionally, and found that the deadline had passed long before:
the tier shipped at M2-B and the corpus's own fixture depends on it. The ruling
says in terms that the task *"must not be picked up and priced as preventive"*
and that M3-D/2 is unblocked by it.

**M3-D/4 (#155)** asked to *"decide the seam"* between M3's exit criterion and
the exporter's `SheetRole`.
[DR-027 §11.26.2](/decisions/dr-027-m3-owes-rows-m6-owns-sheets.md) had ratified
exactly the seam the task proposed.

Both rulings are dated **2026-08-09**, after both tasks were written. Neither
task was wrong and neither was empty — what remained each time was the build half
plus the work of recording the ruling where it would be read.

# The failure it prevents, which is not the obvious one

The obvious cost is re-deciding something already decided. That happened: M3-D/2
was briefly worked as an open question, and a fresh justification was drafted for
a conclusion canon already held. The answer matched, so nothing shipped wrong.

**The real cost is the one that does not announce itself: pricing.** A task that
reads *"ratify or overrule before anything reads it"* looks preventive, and
preventive work gets scheduled early and estimated generously. The same task
re-read against canon is a mechanical retrofit with a documentation edit attached.

# Why the ruling was missed, and the countermeasure

DR-026 **reasoned from a doc comment that did not cite it back**. §11.25.2's
evidence is `ScheduleLengthSource.outletNominal`'s own *"a DELIBERATE addition,
stated here rather than buried"*, so the first place any implementer looks was
the one place the answer was not.

> When a ruling reasons FROM a piece of code, put the citation ON that code.

The pointer is what makes a ruling findable from where somebody is standing.
Canon §12 already tracks derived-document edits that are owed; this is the same
obligation pointed at source. Both the enum and docs/08's two derived sentences
now carry it.

# The shape

Related to [census before building](/practices/census-before-building.md) and to
the same failure it names: **a value that is never compared against anything
cannot be wrong.** A task and a ruling that are never read side by side agree or
disagree silently. The check costs one grep of §11 for the task's own nouns.

Do it at **decomposition and again at pickup**, because the gap this practice
covers opens between those two moments.
