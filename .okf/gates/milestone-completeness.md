---
type: CI Gate
title: Milestone completeness
description: No milestone before the current one may hold an exit clause that is neither discharged nor parked on a named later milestone by a ruling. Roadmap section 8.9 as a check.
tags: [gate, ci, milestone, exit-criterion, dr-095]
timestamp: 2026-09-15T00:00:00Z
resource: tools/milestone_gate.py
status: enforced
---

`python tools/milestone_gate.py` reads `docs/12-milestone-board.md` and exits 1 when any milestone
before the current one holds an exit clause that is neither `DEMONSTRATED` nor `CONFIRMED` nor
parked. [DR-095](/decisions/dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md) is the
rule; board `#780` built it.

# What it reads

- docs/12 section 1's table, in its own order. The current milestone is the first row whose status is
  not `CRITERION MET` or `CLOSED`, and every row above it is checked.
- Each checked milestone's own section, and in it the first table with a `Clause` column and a `Mark`
  column.
- Each row's leading mark. A row that is not discharged must read `parked on <milestone> by DR-nnn`,
  the destination must come later in section 1 and the ruling must have a heading in canon. A row whose
  Clause cell says `not an exit clause` is counted and skipped.

# Why it tests itself first

It passed the day it was written, over a board normalised to pass it, which proves nothing alone. So
it runs twelve planted cases before it reads the real files and refuses to report if any is wrong.

# What it does not do

- **It does not judge whether a mark is true.** That is a person reading evidence, and it is what the
  normalisation was.
- **It reads the leading word only.** `DEMONSTRATED: at the channel, not with a screen reader` passes;
  whether a qualifier is a negotiation is a reader's question.
- **It does not read section 1's counts or weakest-mark column**, which are prose.
