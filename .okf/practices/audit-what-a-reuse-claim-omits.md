---
type: Playbook
title: Audit what a reuse claim OMITS, not whether its named pieces are coupled
description: An estimate justified by "X, Y and Z already exist" fails at the pieces it never listed. PLAN-E/1 checked the five named pieces and four reused verbatim; the work was in three nobody had named, and the one flagged as the risk deleted itself.
tags: [practice, estimation, spike, reuse, plan-view, plan-e, measurement]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

An estimate that says *"this is small because the machinery already exists"*
carries a **list**. The instinct is to audit the list: take each named piece
and ask whether it is more coupled than a read suggested. That audit is the
cheap half, and it is not where the estimate breaks.

# The measurement

The feasibility study sized the Plan editor at 2-3 weeks and called it *"the
one most likely to be wrong in the optimistic direction. It is smaller than
M1's canvas work only because the viewport, selection, hit-test, drag-preview
and command machinery already exist; if any of those turn out to be coupled to
rack or schematic semantics more tightly than a read suggests, that row grows
first."*

`PLAN-E/1` stood a third canvas up out of shipped parts and drove it.

| Named piece | Result |
|---|---|
| Viewport | reused verbatim |
| Selection | reused verbatim |
| Hit-test | reused verbatim |
| Command machinery | reused verbatim |
| Drag preview | **coupled, and the row SHRANK** |

**Auditing the list would have cleared the row.** Four of five were exactly as
claimed, and the fifth was coupled in a way that removes work rather than
adding it: `DragPreviewController` speaks in rack units and a pin has no U, no
face and no occupancy rule to be refused by, so the plan canvas needs no drag
preview at all.

# Where the work actually was

Three pieces the study never mentioned:

* **A render object.** Neither shipped one accepts a bare display list; one
  wants a rack id and device children, the other a schematic paint plan. The
  spike wrote a third copy of the same forty lines, and so will the real
  screen.
* **An image resolver.** `FlutterImageResolver` is a typedef with no
  implementation anywhere in the tree, because nothing yet emits an `OpImage`.
* **A scene builder.** There is no `buildPlanScene`, so the spike faked its
  scene inline.

None of the three is exotic. All three are invisible to the question *"is the
viewport coupled?"*, because that question can only return an answer about the
viewport.

# The shape

**A list of reusable pieces is a claim about what is present. An estimate is a
claim about what is needed.** Checking the first against the tree does not
check the second, and the gap between them is the part of the estimate nobody
inspected, because there is nothing in the sentence to inspect.

So invert it. Do not walk the list. **Build the smallest thing that does the
job and let the compiler enumerate the gap**: every line the spike has to
declare for itself is, by construction, a piece that did not come free. The
finding is then a diff rather than an opinion, and it includes the pieces
nobody thought to name.

This is [census-before-building](census-before-building.md) applied to
capability rather than data, and it fails the same way: a query can only be
wrong about the thing it asked about.

# The corollary about spikes

A spike is only evidence if what it could not do is recorded as loudly as what
it could. `PLAN-E/1`'s six cases pass, and one deliberate mutation **survived**
them: dropping the paint offset out of the spike's render object leaves every
case green, which is `b560a50`'s shipped defect reproduced on the first
attempt. **That survival is the more useful half of the run**, and a spike
reported only as "it worked" would have thrown it away.

See also [two-documents-agreeing-is-not-verification](two-documents-agreeing-is-not-verification.md):
the study's list and the design document agreed about the shared machinery, and
neither had assembled it.
