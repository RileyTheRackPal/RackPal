---
type: Practice
title: A press is not a gesture, so nothing a press does may outlive a cancel
description: >-
  Selecting on the press is the conventional shape for direct manipulation, and it leaked a selection
  past a cancelled gesture. Three of the symbol drag's four defects were press/cancel boundary
  errors, and each one was found by a test rather than by review.
tags: [practice, gestures, canvas, dr-187, cr-086]
timestamp: 2026-09-22T00:00:00Z
status: active
---

# The shape

A pointer press is an OFFER. It becomes a gesture only when something terminal arrives, and there are
two terminals, not one: a commit and a cancel. Every editor tutorial shows the first. The defects
live in the second.

Building the schematic's symbol drag (`#918`, [DR-187](/decisions/dr-187-the-schematic-holds-its-layout.md)
§11.186.4) produced four defects. **Three were at that boundary**, and all three were found by
running tests rather than by reading the code:

| What the press did too early | What the cancel then could not undo |
|---|---|
| Selected the symbol | A press whose canvas is unmounted under it is CANCELLED. The selection survived a gesture the product says did not happen, and pressing `F` then drew four wires for a device nothing had picked. |
| Armed the ghost outline | A dashed rectangle flashed over the symbol on every ordinary selection click, because a press that is still only a press already looked like a move. |
| Ran `setState` on the way out | The cancel arrives inside `finalizeTree`, where the framework is locked and `setState` throws outright. |

The fourth was unrelated and is worth its own line: the grab point was read from a field that
`onHover` feeds, and **a touch never hovers**, so the gesture worked on a mouse and refused silently
on a touchscreen.

# What to do

- **Move every visible or recorded effect to the terminal.** The drop selects; the drop writes. The
  press may arm private state and nothing else.
- **Write the cancel path first, and assume it can arrive during an unmount.** A cancel is not a
  rarer commit: it arrives from teardown, from the framework, from a second pointer. Clearing a
  field is always safe there; asking for a rebuild is not.
- **Ask what the press reads.** A field fed by hover does not exist for touch or stylus. Pass the
  event's own coordinates instead of looking up the last ones.
- **Keep a case for the gesture you are stealing from.** A press on a symbol body used to arm a
  marquee and select on release; selecting is far commoner than moving, so the suite spends two of
  its ten cases proving the click survived. A gesture that gains a move and loses a click is a bad
  trade nobody asked for.

# Related

- [Assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md): the
  case that caught the leaked selection asserts on wires DRAWN, which is why it could catch a defect
  in a gesture written years after it.
- [An older test is a specification](/practices/an-older-test-is-a-specification.md): the same suite,
  the same week, the same lesson from the other direction.
