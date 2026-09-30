---
type: Practice
title: A closure built in build forgets, and a test that holds it still cannot see that
description: >-
  DR-077 fixed a second Save minting a second template by having the save closure remember the id.
  The shell built that closure inside build, so every save's rebuild made a fresh one that had
  forgotten, and the fix's own tests held one closure still. Give remembered state an owner that
  lives as long as the memory, and test it through the thing that rebuilds.
tags: [practice, flutter, state, testing, dr-077, dr-202]
timestamp: 2026-09-29T00:00:00Z
---

# What happened

DR-077 §11.76.3 found that a new template's second Save minted `tpl.foo_2`, and fixed it: the
closure `buildDeviceBuilderActions` returns remembers the id its first call minted. Five tests
proved it, each by building the closure once and calling it twice.

That was right while the builder was a dialog, which built its wiring once per opening. `#778`
(2026-08-26) made the builder a view, and the shell then called `buildDeviceBuilderActions` inside
`build`. A save is a document change, a document change rebuilds the shell, and the rebuilt
closure started with no id. So from `#778` to `#950` the product did exactly what the ruling
forbade, behind five green tests (DR-202). Nobody touched the closure; its host changed under it.

# The practice

**A value a closure captures lives as long as the closure, and a closure built in `build` lives one
frame.** When state has to outlive a rebuild, give it an owner whose lifetime is the lifetime the
state means: here, one authoring session, so the shell keeps the wiring and clears it where a
session starts or ends.

**A test that constructs the object once cannot see its caller reconstructing it.** The unit test
states the rule; only a test that drives the real host, pressing the real button across the real
rebuild, proves the product obeys it. Write that one first, and watch it go red.

Related: [assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md),
and [a blanket rebuild hides a missing subscription](/practices/a-blanket-rebuild-hides-a-missing-subscription.md),
the same rebuild seen from the other side.
