---
type: Practice
title: A test that asserts an absence must name the day it comes due
description: This codebase deliberately tests that unbuilt things are not offered. Such a test is a liability unless its comment says which task will make it fail, because otherwise it silently keeps passing while the feature is built beside it.
tags: [testing, unbuilt-copy, bookkeeping, house-style]
timestamp: 2026-08-10T00:00:00Z
status: proven
---

RackPal tests **absences** on purpose. `shell_tabs_test.dart` asserts no tab
fabricates a control that does nothing; `unbuilt_copy_accuracy_test.dart` asserts
no copy names a capability the build lacks; the Structure editor asserts its
button bar does not draw `[Group into pathway]`.

These are good tests. They are also the only class of test that **passes more
easily as it becomes wrong**: an assertion that `X` is absent goes on passing
right up until somebody builds `X`, and then it fails in a place that looks like
a regression rather than like a milestone.

# The rule

**Every absence assertion carries a comment naming the task that will retire
it.** Not "this is not built yet", *which item builds it*.

# It was tested, three times in one task

M3-E/1 (#156) built the `[ Pathways ]` tab and §4.2's `EMT` column, and three
existing assertions came due at once:

| Assertion | What its comment said |
|---|---|
| `structure_editor_screen_test`'s unbuilt-control list | *"`Matrix` LEFT THIS LIST AT M3-C/3 … the day one is built the test says the others still are not"* |
| `structure_matrix_test`, seed columns | *"§4.2 draws nine and the ninth creates a `Pathway`, which nothing in this build does (#156)"* |
| its UI twin, the grid's opening columns | the same, from the widget side |

All three failed on the commit that earned it, each named the reason, and each
was corrected in one line with the old assertion quoted in place. **Total cost:
about five minutes.** The counterfactual is the expensive one: a test asserting
`hasLength(8)` with no reason attached, failing a year later, read as a
regression, and "fixed" by putting the column back in the excluded list.

# Why quoting the old assertion matters

Each correction keeps a sentence saying what it *used to* assert and why that was
right at the time. Without it the next reader sees a test asserting nine columns
and has no way to know the eight was ever deliberate, which is the same failure
[assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md)
collects from the other direction: a test whose intent is unrecoverable from its
own text.

# The neighbouring failure this does not catch

An absence assertion that comes due is cheap. A **presence** assertion that
quietly stops covering what it names is not, and no comment saves you from it.
That is [diagnose before fixing](/practices/diagnose-before-fixing.md)'s
territory, and M3-E/1 found one of those too: `StructureTable.pathwayCount`
counted only pathways with drops through them, and its test asserted
`pathwayCount, 1` on a two-pathway document, a defect pinned as intended
behaviour, invisible until DR-032 made the drop-less pathway the ordinary case.
