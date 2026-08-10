---
type: Playbook
title: Check a decomposition for holes before working it, by asking what feeds each task
description: A breakdown that exists can still be missing its middle; the test is whether task N's output is task N+1's input, and filling the gap is not a scope change.
tags: [practice, process, tasks, scope]
timestamp: 2026-08-10T00:00:00Z
status: adopted
---

**Before working an in-progress issue, walk its tasks in order and ask, for each
one, what produces its input.** A decomposition that reads well top to bottom can
still have nothing connecting two adjacent items.

# Why, with the evidence

On 2026-08-10 M3-F (CSV import) was picked up mid-issue. Its board looked
healthy: four tasks, one Done, three To Do, each with a written description
carrying its constraints exactly as
[decompose before building](decompose-before-building.md) asks.

* **M3-F/1** shipped `matchCsvHeader`, a table answering *"which column is this
  header"*.
* **M3-F/2** is the manual assign step for every unmapped column.
* **M3-F/3** is the import-over-existing confirm, which states counts.
* **M3-F/4** is the file dialog's missing file-type filter.

**Nothing in the repository read a CSV file.** `git ls-files | grep -i csv`
returned the header table, its test, and an unrelated PowerShell script. There
was no reader, no shape detection, no row model, no `unknown` passthrough, no
location or outlet or pathway resolution, no dedup, no preview grid and no
import `Command`. M3-F/2 could not show a mapping sheet for headers nothing had
read; M3-F/3 could not confirm counts nothing computed.

The breakdown was not lazy. It was written from the FEATURE's risks, which is
where the roadmap put them: the named hazard was synonym-table scope growth, so
every task addresses a way the feature could go wrong. **None of them addresses
how the feature works at all**, because that part was never in dispute and so was
never written down.

# The test

For each task, name the artifact it consumes and the task that produces it. A
task whose input has no producer is the hole. This costs a few minutes and is
worth doing at pick-up time rather than at build time, because the hole is
cheapest to file before anything depends on where it lands.

The failure mode it catches is specific: **breakdowns derived from a risk
register are complete about risk and silent about mechanism.** Ask what the
happy path is made of.

# Filling it is a decomposition gap, not a scope change

Roadmap §8.3 makes scope changes amendments with a new ruling ID. That is not
what this is, and conflating them costs a ruling nobody needed.

The distinction, applied here: docs/07 §5 already promised the reader and both
shapes, roadmap §2 (the one scope list) already carried *"CSV import with synonym
mapping"*, and RJ-004 had already rejected cutting it. **No task was ever cut for
the missing work; one was never written.** So the fix is new tasks under the
existing issue, citing the sections that already promised them.

Canon states the same test at §11.24.7 for #587: *"docs/07 §4.1 already promises
the capability and §4's wireframe already draws it; no task was ever cut for it,
so #587 is a decomposition gap rather than an amendment."* This is the second
occurrence, which is what moved it from an observation to a practice.

**The converse is the part that keeps it honest.** While filing the gap, Export
CSV looked like it belonged in the same batch: docs/07 §5.3's closing line
promises the round trip. It was filed as RULING NEEDED instead, because roadmap
§2 does not name it and docs/07 is derived, priority-3. A promise living in
exactly one derived document is a scope question for the user, not a hole to
quietly fill. **The same audit produces both answers, and the scope list is what
tells them apart.**

# Citations

[1] Canon §11.24.7 (DR-025), the #587 precedent
[2] Roadmap §8.3, §2
[3] Board #88, tasks #159 through #162, #651 through #653
[4] `packages/rackmate_core/lib/src/structure/csv_header_map.dart`
