---
type: Playbook
title: Twelve fix commits that touched neither cause
description: The salvage post-mortem — why a failure that survives repeated fixes is a signal to stop fixing and start diagnosing, and what shape of fix actually holds.
tags: [practice, debugging, post-mortem]
timestamp: 2026-07-28T12:00:00Z
status: adopted
---

A previous schematic canvas failed and received **twelve consecutive fix
commits**. None of them touched either cause. The post-mortem is kept because
the shape recurs.

# What was actually wrong

1. **The document never reached the canvas.** `main.dart` passed a hardcoded
   `DiagramScene(fragments: {}, rackId: '')`. On an empty scene the code
   **manufactured a fake symbol** with dummy `Pin1`/`Pout1` ports; the other
   branch skipped keys prefixed `rack-`, a prefix matching nothing real. **No
   code path could render an actual device.**
2. **The background fill ignored its paint offset** and painted over the
   toolbar, while symbols *did* get offset, which is why one box appeared to
   float.

And nothing helped, because:

3. **`updateRenderObject` was a no-op.** Every setter was guarded with
   `identical()` against a `final List` that was mutated in place, so no
   `setState` could ever mark it needing paint.

The third is why the first two survived twelve attempts: **the surface could not
change, so no fix could be observed to work or fail.**

# The lesson

**When a fix does not move the symptom, stop fixing.** A second failed fix is
evidence about the *model*, not about the fix. Twelve is a system that cannot
be debugged by editing it, find the thing that makes feedback impossible
first.

Ask specifically: *is there any path by which my change could be observed?* A
repaint that cannot be triggered, a test that cannot fail, a gate that passes
when its input is missing, all the same class.

# The shape of fix that held

The replacement did not add a guard. **It removed the parameter.**
`SchematicCanvasScreen` takes only a measurer and a controller; there is no
`scene` and no `document` argument, so the empty-scene failure has no channel to
travel through. `buildSchematicScene` runs inside the screen.

**Prefer making a failure unrepresentable over guarding against it.** A guard is
a thing that can be removed by someone who does not know why it is there.

# And write the test that would have caught it

All three failures were widget-testable and none had a test. Each now has a
named regression test, including one for the paint offset, which
`isRepaintBoundary` makes unreachable from a widget test, so the composition was
extracted specifically so it could be tested at a non-zero offset.

**If a bug was not reachable by any existing test, the fix is not complete until
the shape of test that would have reached it exists.**

# Citations

[1] `docs/m1-implementation-log.md`, commit `c5669a9`
[2] `packages/rackpal_ui/lib/src/canvas/render_rack_canvas.dart` (the pattern that was correct all along
[3] `packages/rackpal_ui/test/canvas/schematic/`) the three regression tests
