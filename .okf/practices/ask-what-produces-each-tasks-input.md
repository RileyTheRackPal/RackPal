---
type: Practice
title: Ask what produces each task's input, or ship a view of nothing
description: M4-E's five tasks built a grid, its columns, its packs, its validation dots and its footer, and not one of them created a port. The app's only entry point opens a blank template.
tags: [practice, decomposition, planning, m4-e]
timestamp: 2026-08-15T00:00:00Z
status: adopted
---

A decomposition that covers a feature's OUTPUT completely can still have
no producer for its INPUT, and the gap is invisible in a task list
because every task reads as necessary and none reads as insufficient.

# The evidence

M4-E decomposed cleanly into five tasks:

```
#203  the virtualised grid with sticky collapsible bank headers
#204  the core columns
#205  the seven column packs and their auto-reveal
#206  live validation dots in the row gutter
#207  the always-visible footer readout
```

**Not one of them creates a port.** Quick Add is M4-G (`#178`),
archetype generators are M4-I, paste is M4-I3, and the application's only
entry point (`Project ▸ New device template…`) opens a BLANK template. So
as written, the milestone task delivers a beautifully virtualised,
fully columned, live-validated view of an empty list, and every one of
its five acceptance checks passes.

**Deleting was missing too**, and from all five. A grid you can add to
and not remove from is one nobody can correct a mis-click in.

# The check

For each task in a decomposition, name the thing it acts on and then name
**which task produces that thing**. If the answer is "a later milestone",
one of two things is true and they need different fixes:

* The work is genuinely blocked, and the decomposition should say so
  rather than looking complete.
* A **slow path** belongs with the surface, so the surface can be used
  and tested before the fast path lands. That is what M4-E did: one
  `+ Add port` button producing one blank row, undoable, perhaps fifteen
  lines including the command. Quick Add is still M4-G's, and the code
  says so in a comment rather than pretending otherwise.

The slow path is not scope creep. A surface whose input arrives two
milestones later cannot be demonstrated, which puts it straight into the
gap between "checklist-ticked" and "done" that roadmap §8.1 exists to
close.

# The tell

Look for a task list where every verb is *display*, *format*, *validate*
or *summarise*. Those all take an argument. Something has to make it.

# Citations

[1] `packages/rackpal_ui/lib/src/builder/port_grid.dart`
[2] [check a decomposition for holes](check-a-decomposition-for-holes.md)
[3] [a modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md)
