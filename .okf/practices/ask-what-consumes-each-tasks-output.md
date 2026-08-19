---
type: Practice
title: Ask what consumes each task's output, or build a save nothing reads
description: M4-D built a template save, gated it, tested it and shipped it, and no surface in the tree read what it wrote. Seventeen issues and fourteen green gates could not see it.
tags: [practice, decomposition, planning, m4-d, m4-s, dr-077]
timestamp: 2026-08-19T00:00:00Z
status: adopted
---

The sibling of
[ask what produces each task's input](ask-what-produces-each-tasks-input.md),
pointing the other way, and it is the harder of the two to see: a task
whose output nothing consumes still passes every test it was given,
because the test is written against the output.

# The evidence

M4-D shipped `SaveTemplateToProjectCommand`. It writes a `TemplateBody`
into `RackDocument.templates`, it round-trips through the file byte for
byte, it has an undo entry, and it was covered by tests in two packages.

Nothing read it. The palette was built from `buildSeedCatalog()`, so a
template authored in the Device Builder existed in the project and could
never reach a rack. **M4's exit criterion clause 2 was unperformable**,
and it belonged to none of that milestone's nineteen issues.

The comment at the top of the file that wired the save said, from the day
it shipped:

> A template authored here is therefore placeable immediately and travels
> with the file.

# Why the gates could not help

Every test asked "did the save write what it was given". That is a
question about the producer, and it was answered correctly. The question
nobody asked was "who reads this key", and the tree's answer was: two
call sites that resolve snapshots for devices ALREADY placed, and nothing
else.

**A grep for the writer finds the writer.** What finds this is a grep for
the READER, per key, per field, per file: `doc.templates` had readers, so
the map looked consumed; the specific keys the builder wrote had none.

# The check, at decomposition time

For every task that produces something durable, name the task that reads
it. If the answer is "a later milestone", that is fine and must be
written down. If the answer is a surface, name the surface. If nobody can
name one, the milestone's criterion probably cannot be met, and the
cheapest moment to discover that is before the first commit.

Both questions are asked of the same task and neither implies the other.
A decomposition can be complete on inputs and complete on outputs and
still leave a criterion unreachable, because they are different ends.

# What it cost, and what it did not

Four days, and no rework: the machinery was right and the fix was one
widget reading the document instead of a constant (DR-077
[a template authored here reaches the rack](/decisions/dr-077-a-template-authored-here-reaches-the-rack.md)).
The expensive version of this failure is the one where the consumer needs
a different shape from the one the producer shipped.

It is related to
[a modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md),
which is the same absence one layer down: there, a field nothing writes;
here, a write nothing reads.
