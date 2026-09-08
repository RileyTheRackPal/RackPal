---
type: Practice
title: A null collaborator in a test is a configuration, and it may be one nobody ships
description: >-
  Optional constructor parameters make "null is a supported mode" true and make it
  easy for every test to exercise a configuration the app never mounts. The plan
  canvas passed marquee: null in every case and shipped a dead gesture.
tags: [practice, testing, widget-tests, optional-parameters, plan-view]
timestamp: 2026-09-08T00:00:00Z
---

`PlanCanvasScreen` takes four optional collaborators: `arm`, `marquee`,
`calibrate` and `onRefuse`. Each is documented as *"null is a supported mode"*,
and each really is. Every case in `plan_canvas_screen_test.dart` passed null for
`marquee`, because those cases were written before the band existed.

**`PlanEditorScreen` passes one. It is the only thing that mounts the canvas in
the product.**

So the canvas's own arm-mode cases exercised a configuration the app never uses,
and the configuration the app does use had a gesture that could not fire: the
band was armed by every press, `commitDrag` asked `marquee.isActive`, and the
armed-pin branch below it was unreachable. DR-141's whole fast path was dead with
a green suite.

# What to check

**When a widget takes an optional collaborator, ask what the app passes.** If
every test passes null and the app passes an instance, the tests describe a
product nobody ships. The fix is not to delete the null cases, which are honest
about a supported mode, but to add at least one case per collaborator in the
configuration the app actually mounts.

**The pairing is where the hole lives, not either file.** The canvas file tests
gestures and has no reason to build a band; the editor file tests layout and has
no reason to arm a drop. Both are coherent. What nothing covered was the canvas's
gestures *with* the editor's collaborators, which is the only combination that
ships. This is [check a decomposition for holes](check-a-decomposition-for-holes.md)
applied to a pair of test files instead of a set of chapters.

# The related smell

A new optional parameter added to a widget that already has tests is the moment
this appears: the old cases keep compiling, keep passing, and quietly stop
describing the product. Adding the parameter is the moment to ask which existing
case should start supplying it.

See also [a modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md),
which is the same failure with the surface and the model swapped, and
[assert the artifact not the mechanism](assert-the-artifact-not-the-mechanism.md).
