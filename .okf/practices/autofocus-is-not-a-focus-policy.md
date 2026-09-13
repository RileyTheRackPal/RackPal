---
type: Practice
title: autofocus answers for a widget that is alone, and every widget is alone in its own test
description: >-
  The Plan canvas never called requestFocus and relied on autofocus:true. That
  wins only while nothing else has claimed focus, which is true in its own test
  file and false after one click anywhere else, so Esc had never worked on that
  surface since the day it was bound.
tags: [practice, testing, widget-tests, focus, keyboard, plan-view]
timestamp: 2026-09-13T00:00:00Z
---

`PlanCanvasScreen` wrapped its canvas in `Focus(focusNode: _canvasFocus,
autofocus: true, ...)` with a `Shortcuts` above it, and called
`requestFocus()` **nowhere**. `RackCanvasScreen`, the surface it was modelled
on, calls it in **eight** places.

`autofocus` fires once, when the node first enters a scope with nothing else
focused. In `plan_canvas_screen_test.dart` that is always: the canvas is the
entire tree. In the product it is true exactly until somebody clicks the rail,
the strip, a dialog or another tab, after which the canvas can never get focus
back, and `Shortcuts` sits ABOVE the focus node.

**So `Esc` had never worked on that surface.** `planCancel` was the scope's only
binding, shipped at `PLAN-E/5`, has its own passing cases, and could not fire.
Nobody noticed because the passing cases all autofocus.

# What to check

**A keyboard binding proved in a file where its widget is the whole tree is not
proved.** The question is not "does the handler run" but "can this node hold
focus in the tree it actually ships in". Mount it next to something else
focusable and press the key.

**If a surface takes pointer input and a keyboard binding, it needs an explicit
`requestFocus` on the pointer path.** `autofocus` is an opening position, not a
policy. The tell is a canvas or a panel with a `FocusNode` field whose only
mention is the widget constructor.

**Write the case so it FAILS without the fix.** The one here mounts a sibling
with `autofocus: true` of its own, asserts the sibling has focus, clicks the
canvas, and asserts the key lands. Reverting the `requestFocus` turns it red,
which is the check that separates a test of the fix from a test of the harness.

# The neighbouring finding, which is NOT the same thing

Writing the app-level test for this surfaced something else and it is filed
rather than folded in: **no pointer gesture reaches the Plan tab at the app
mounting at all**, so even the focus fix cannot be demonstrated there. That is
`#882`, it is unexplained, and the two must not be conflated: this one is
understood and fixed, that one is measured and open.

# Related

* [A widget test that reaches a control by finding it never tests the path to
  it](drive-the-keyboard-not-the-finder.md) is the same family: there the test
  teleports past the route, here it starts in a tree where the route is free.
* [A surface tested alone has never met its
  host](a-surface-tested-alone-has-no-host.md) is the structural version, from
  `#877`, one ticket earlier.
* [A null collaborator in a test is a
  configuration](a-null-collaborator-in-a-test-is-a-configuration.md) is the
  third: a property that holds in the harness and in nothing that ships.
