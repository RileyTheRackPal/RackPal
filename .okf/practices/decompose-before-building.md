---
type: Playbook
title: Decompose a milestone before building it, and put the traps in the task
description: The first task of a new milestone is its own breakdown — and each task's description carries constraints, because that text is what survives a lost session.
tags: [practice, process, tasks]
timestamp: 2026-07-28T00:00:00Z
status: adopted
---

**The first task of any new milestone is creating that milestone's tasks.**
Decompose before building; put the breakdown on the board.

# Why, with the evidence

On 2026-07-28 the session driving M2 died mid-flight. The work was recoverable,
and the reason was M2's task breakdown, written as the first act on the
milestone.

The tasks still held:

- *"a previous Sugiyama implementation was deleted in `c5669a9`, do not restore
  it from history"*, with the two specific defects it carried
- *"read a link's class through `effectiveLinkClassOf`, never `Link.linkClass`"*
- [DR-001](/decisions/dr-001-net-labels-by-default.md)'s scope reduction, do not
  build channel routing

**None of that existed anywhere else.** Not in the code, not in the commit
history, not in the docs. It lived in the task descriptions, and two later agents
consumed it directly and avoided all three traps. An undecomposed epic is a
milestone whose knowledge lives only in whoever is currently holding it.

# The rule that makes it work

**A task's description carries its constraints and traps, not just its title.**
A title-only breakdown would not have survived, "M2-C: Sugiyama layout" tells a
fresh context nothing about the broken implementation sitting in git history that
looks exactly like a gift.

Worth including in a task description:

- what NOT to do, and why the tempting thing is wrong
- rulings that bind the task, by ID
- the specific defect a previous attempt shipped
- which gate will catch a mistake, and which will not

# Shape

On starting `Mx`, create `Mx-0: decompose Mx into tasks` as its first child, then
the `Mx-A…` tasks. Mirror to the board; evidence stays in `docs/12` and is linked,
never copied.

# Citations

[1] `docs/12-milestone-board.md`
[2] The M2 breakdown, M2-A … M2-H
