---
type: Playbook
title: A field added beside a documented one inherits nothing
description: >-
  A new field declared next to an existing one reads as though it shares that
  field's contract, because the comment explaining the contract is directly
  above it. It does not. The reader inherits the reasoning and the code
  inherits nothing, so the line that enforces the contract has to be written
  again by hand, and the place it is missing looks exactly like the place it
  is present.
tags: [practice, process, state, modes, plan-view, len-a, dr-050, dr-144]
timestamp: 2026-09-11T00:00:00Z
status: adopted
---

# The instance

`PlanEditorScreen` holds one calibration controller for every plan, and the
field says why in its own doc:

> A pick describes a distance on ONE raster and cannot outlive a switch to
> another; `_openPlan` cancels it for exactly that reason.

`LEN-A/4` added the outline controller **on the next line**, with no doc, for
identically the same reason: an outline is vertices in one raster's pixel
space. `_openPlan` was not extended.

So two corners placed on one plan survived a switch to another, and a third
click closed a shape whose first two vertices were measured on a different
picture. **Nothing refused it**, because vertices are integers and every raster
has those, and there is no assertion anywhere that a shape's corners were all
taken from the plan it is stored against.

It was found at `LEN-A/8`, by adding a FOURTH controller to the same line and
asking what the third one did about the switch.

# Why the shape is hard to see

The comment is right there. Reading the two declarations together, the second
one looks covered: the sentence explaining the invariant is four lines above
it and applies word for word. **The reader inherits the reasoning and the code
inherits nothing.**

That is the opposite of the usual undocumented-field problem. An
undocumented field beside an undocumented field prompts a question; an
undocumented field beside a well-documented one prompts none, because the
answer appears to be on screen.

# The check

When you add a field beside one that carries a contract in its doc, **find
every site that enforces that contract and ask whether yours belongs there
too.** Not "does the reasoning apply", which is the easy half and was obvious
in this case, but "which lines make it true".

Cheapest form: grep the neighbour's name. `_calibrate` appears in `_openPlan`,
in `dispose`, in `_beginOutline` and in the canvas wiring; the new field
appeared in three of the four, and the missing one was the defect.

And when the new field really does share the contract, **say so in its own
doc**, so the next field added below it inherits a visible rule rather than an
adjacent one.
