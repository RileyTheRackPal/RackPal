---
type: Practice
title: A string no test names is a string nobody has read
description: Before trusting a message that already ships, grep the test tree for it. A user-facing string that no test asserts in either direction has never been reviewed rendered, and the branch that produces it has never been reached on purpose.
tags: [testing, ux, copy, census, gates]
timestamp: 2026-08-30T00:00:00Z
status: adopted
---

**A passing suite says nothing about a branch it never enters.** The gap this
practice closes is narrower and nastier than "untested code": it is code that
runs constantly, in front of the user, on the everyday path, and that no
assertion has ever looked at.

# The instance that named it

`#242`, DR-103. Every pointer-down on a palette row arms a drag (AC-016 #23, no
gesture-outcome branch). The pointer-up reached `_commitOrNoopPaletteDrag`, found
the phase was not `dragging`, and announced:

> Released outside the rack — HDMI Matrix 4x4 was not placed. The Staging Bin is
> not in this build.

**For a gesture nobody made.** A single click on a palette row did this, which
docs/04 §3.1 step 1 defines as *"a click still means 'show details'"*. So did the
second half of every double-click, landing **after** the placement and
overwriting *"Placed MTX-1 at RK-1 U1, front."*

`DragPreviewPhase.armed`'s own doc comment said what the code should have done:
*"below the 4px slop — might still just be a click/double-click"*. The
information was in the tree, one file away, in a comment written by whoever added
the phase.

**A grep for the message found no test asserting it anywhere in the repository,
in either direction.** Not a positive case saying a released drag reports it, not
a negative case saying a click does not. That is how it survived a milestone with
fifteen green gates and a fourteen-case palette suite beside it.

It was found only because it was **eating something else**: DR-103 §11.102.4's
copy announcement, which a new test was asserting and which kept coming back
empty.

# The rule

* **Before trusting a shipped message, grep the test tree for it.** Zero hits is
  a finding, not a gap in coverage: it means the branch has never been reached on
  purpose and nobody has read the sentence in place.
* **Assert both directions when you fix one.** The case that must keep saying it
  is as load-bearing as the case that must stop. A fix asserted one way widens
  into deleting the message.
* **Mutation-check the guard.** Revert the fix and confirm the new cases die and
  the preserved case survives. Two of three failing and one passing is the shape
  that proves the fix is narrow.
* **A comment on the enum is evidence.** `DragPreviewPhase.armed` documented the
  correct behaviour years of commits before anything honoured it. When a
  behaviour disagrees with a doc comment beside it, one of the two is a defect
  and the comment is usually the older, more considered one.

# Where it sits

This is the sibling of
[print the output before claiming copy is done](print-the-output-before-claiming-copy-is-done.md),
which is about a sentence a test **does** assert being wrong. This one is about a
sentence no test mentions at all, which is worse: there is no green assertion to
mislead you, and no red one to help.

It is also [census the field, not the name](census-before-building.md) turned on
the test tree rather than on the source: the question is not *"is this code
covered"* but *"has anybody ever named this string"*.
