---
type: Gate
title: Callbacks have callers
description: >-
  Every function-typed member of a *Actions record in rackmate_ui must be invoked
  somewhere in that package. Written after a gesture shipped with a command, an
  implementation, tests for both, and nothing that called it.
tags: [gate, ui, verification, practice, m3-h]
timestamp: 2026-08-12T00:00:00Z
status: adopted
---

`packages/rackmate_ui/test/structure/actions_have_callers_test.dart`.

# What it defends

The surfaces in `rackmate_ui` take their gestures as **callback records**:
`OutletsActions`, `PathwaysActions`, `StructureEditorActions`,
`DropEntryActions`, `OutletTemplateActions`. The package may not depend on the
app, so a record is the seam.

The gate asserts that **every function-typed member of one has a call site** in
`lib/`. On its first run: 18 callbacks, one hole.

# The defect that produced it

`OutletsActions.onRemoveGang` (M3-H/5). `RemoveGangCommand` was built and tested
including undo, the callback was declared, and `buildOutletsActions` implemented
it with a bounds check and a refusal sentence. **No widget invoked it**, so the
only ways to remove a gang were `Ctrl+Z` and a full destructive `Arrange`.

It is the sixth instance of
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
and sits **one layer above where that practice looks**: its check is "grep for
what WRITES the field", and the field had a writer.

# Why nothing else sees it

A declared-and-implemented callback hides **better** than an unreachable field,
because both ends are present and only the middle is missing:

* the analyzer sees nothing unused: the record is constructed with every member
  supplied and then passed to a child widget;
* the app-side implementation has its own tests, and they pass;
* the command has its own tests, including undo, and they pass;
* every reader of the record compiles.

The only absent thing is a widget that says `actions.onRemoveGang(...)`, and **no
Dart type can require one**.

# What it deliberately does NOT flag

**Nested records are passed, not invoked.** `StructureEditorActions.dropEntry` is
a `DropEntryActions` and `.outlets` is an `OutletsActions`; a naive scan reports
both as uncalled. The gate filters on `Function` appearing in the declared type.

That filter is the difference between a gate people trust and one they learn to
ignore: **it would have cried wolf twice on its first run.**

# Its own blind spots, stated

* **It is a grep, not a parser.** A call site inside a comment or a string counts.
  False negatives are acceptable here; a flaky false positive is not.
* **It does not check the app side.** A callback invoked by a widget but wired to
  a no-op in `apps/rackmate` passes. That is a different defect and would want a
  different gate.
* **It only scans `rackmate_ui`.** Records living elsewhere are unguarded.

# It was watched failing

A gate that has only ever been green proves nothing. With the call site removed
it reports `OutletsActions.onRemoveGang` by name, and the anti-vacuity cases
assert that the class regex still matches all five records and that at least 15
callbacks were checked. See
[assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).
