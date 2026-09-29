---
type: Practice
title: An uncalled helper can be evidence, and deleting a caller can orphan its callee
description: >-
  #945 triaged the public declarations nothing calls. Most were leftovers, but two were the only
  trace of a rule nobody was following, and deleting one caller orphaned a function the triage had
  not listed. Read each before deleting it, and run the census until it finds nothing new.
tags: [practice, dead-code, refactoring, census, cr-045, dr-201]
timestamp: 2026-09-29T00:00:00Z
---

A census of code nothing calls produces a list that looks like one finding. It is several, and the
dangerous ones look exactly like the harmless ones.

# Evidence, not clutter

`allocateStructureDesignator` had no caller. Its doc comment said a Structure's designator must go
through the format engine "rather than a second `'STR-$n'` concatenation". Beside it, both "create
one" offers wrote `designator: 'STR-1'`: the helper existed to obey CR-045, and the code that should
have called it broke CR-045 instead. `resolveDesignatorCollision` had no caller either, and it was
the only reader of a Project Settings row, so the row governed nothing (DR-201).

**Deleting either on sight would have erased the evidence and kept the defect.** Before deleting an
uncalled helper, read what it was for, and look for the place that should be calling it.

# Test-only is three findings

A function only tests call is either a handle on live logic (keep it, `@visibleForTesting`), logic
of its own that nothing runs (delete it with its tests), or a feature nobody wired (keep it, file
the question). And a test being pruned can hold an assertion about something live: the test of the
deleted `offersBackup` held the only assertion on `backupOf`, which the session calls.

# Run it to a fixpoint

Deleting `pickAndImportFloorplan` orphaned `importFloorplanFrom`, its only caller's callee, which the
first census could not list because it still had a caller. The commit claimed another class called
it; nobody had checked. **Re-run the census after every deletion batch, until it lists only what was
kept on purpose.**

# Related

- [Assert the artifact, not the mechanism](assert-the-artifact-not-the-mechanism.md): a helper's
  tests prove the helper, not that anything uses it.
