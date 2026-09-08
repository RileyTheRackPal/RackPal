---
type: Design Ruling
title: DR-139 — One marquee, built once and adopted on all three canvases
description: docs/15 promised the Plan editor a marquee "identical to the other two canvases" and neither of the other two has one. CR-102 ruled the gesture and nothing implements it. Found by censusing the mechanism rather than the word, and built once rather than three times, in its own Chapter rather than folded into the row it grew.
tags: [ruling, selection, gesture, canvas, plan-view, dr-139, cr-102, plan-e]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-139
canon_section: "11.138"
status: ruled
---

Settled by the user on 2026-09-07, on a finding from `PLAN-E/1`'s
[reuse census](/practices/audit-what-a-reuse-claim-omits.md).

# The promise, and what was behind it

docs/15 §6's gesture table gives the Plan editor *"Pan, zoom, marquee-select |
Identical to the other two canvases"*.

Pan and zoom are exactly that, and the spike verified it by driving both through
the same `CanvasIntentDetector` the rack and schematic screens use.
**Marquee-select is not, because neither of the other two canvases has one.**
[CR-102](/invariants/) is normative, rules it left-drag in every view, and
specifies the CAD window/cross convention: left to right selects fully contained
with a solid band, right to left selects intersecting with a dashed band.
Nothing implements any of it.

# The census looked past the word, and the word was not enough

Grepping `marquee` returns comments and nothing else, each saying the gesture is
deferred. A reader could fairly conclude the machinery was present and merely
unbound.

**The finding is one layer down: every `SelectMode` call in `lib/` passes exactly
one id.** `SelectionController` holds a `Set<Uuid>`, supports `add` and
`subtract`, and is written throughout against a multi-selection. `add` and
`subtract` are reachable only by Ctrl+click, and no gesture in this product has
ever put more than one thing into that set at once.

> **A multi-selection nothing can multi-select is invisible to a census by
> name**, because the type is present, correct and tested.

This is the fourth entry in the corpus's running list of a design document and a
ruling agreeing with each other without either having read the model, and the
first where the disagreement is about a **capability** rather than a field. The
earlier three were names that resolved to nothing; this is a name that resolves
to something never used. See
[two-documents-agreeing-is-not-verification](/practices/two-documents-agreeing-is-not-verification.md)
and [census-before-building](/practices/census-before-building.md).

# The ruling, and the two options declined

| Declined | Why |
|---|---|
| Build it on the plan only | The plan is where it pays most, the 60-drop rough-in being the design case. That is an argument for building it FIRST, not for building it ONLY, and it would make the docs/15 sentence false in the other direction |
| Ship without it, correct docs/15 | Keeps `PLAN-E/2` at its estimate and costs sixty Ctrl+clicks to select a plan's worth of pins: the same failure AC-048's bulk-entry bar and the as-built tally surface already exist to refuse at the other end of the job |

**CR-102's entire content is that the gesture is uniform across views.** It
exists because two design documents specified different buttons, and it settled
that by ruling one. Discharging it three separate times, months apart, is how a
uniformity ruling stops being one: the second implementation copies the first
and the third copies whichever it read. The cost of building it once is paid at
the moment the ruling is easiest to satisfy, which is before any of the three
has one.

# Not a scope amendment, and its own Chapter

Roadmap §2 is the scope list and marquee is not a line on it: it is behaviour
inside editors already scoped, designed and ruled. Nothing moves between release
bands. **What this ruling does is assign never-built work to a named chapter**,
which is an ordinary act rather than the amendment roadmap §8.3 governs.

It is Chapter `#848` (`PLAN-E/6`) and deliberately **not** part of `PLAN-E/2`.
That chapter is "place, drag and select pins" and was estimated as that;
cross-canvas work touching two shipped surfaces carries regression risk that has
nothing to do with pins. Folding it in would be exactly the invisible growth
`PLAN-E/1` exists to expose.

**The risk was stated before the choice was made**, and is recorded rather than
softened: this is the option that touches the most shipped code. The judgement
is that a marquee expressed against `CanvasIntentHandler` is small, because the
spike showed that interface carries a complete drag in scene space with no rack
or schematic term in it, and the hard part is the window/cross discrimination,
which is one comparison on drag direction.

# What it does not rule

**Not the band's appearance** beyond CR-102's own solid/dashed distinction: line
weight, colour and whether the band dims what it will catch are UI/UX and are
the user's, unasked here. **Not gesture parity generally.** **Not the Plan
view's own gesture set**, which docs/15 §6 governs and `PLAN-E/2` builds.

# The test that matters

A band catching two devices must produce a selection of **two**. This
repository's own history says why to write it that way round: a status bar's
pathway count read 0 the keystroke after somebody made a pathway, and its own
test pinned the wrong number on a two-pathway document. Assert on a document
where "fully contained" and "intersecting" give different answers, or the
window/cross rule is untested.
