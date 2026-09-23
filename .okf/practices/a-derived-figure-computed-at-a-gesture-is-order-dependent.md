---
type: Practice
title: A figure computed at a gesture is an order the user has to know
description: >-
  A room's run length is worked out only when its outline is closed or
  reshaped, and only if three other facts already hold. Outline first and
  nothing is computed; supply the missing fact later and nothing recomputes.
  Found by writing a user guide, not by any test.
tags: [practice, derivation, ux, user-guide, dr-050, dr-168, len-a]
timestamp: 2026-09-23T00:00:00Z
status: adopted
---

`roomEstimateFor` is a pure derivation, and a pure derivation reads as
"always current". **It is not called like one.** Its only callers are the two
places `plan_canvas_screen.dart` commits an outline (close and reshape), and
it returns null unless, AT THAT MOMENT:

- the underlay is calibrated;
- a run to the room lands in a rack;
- that rack is pinned on the same underlay as the outline.

So the obvious order (import, calibrate, outline the rooms, then go and place
the equipment) computes nothing, and pinning the rack afterwards does not
fill the field. Every test passes, because every test sets the prerequisites
up first. The user meets a blank field and no reason.

# Why nothing caught it

**The derivation is correct and the TRIGGER is the defect.** Tests assert
what the function returns for a document; nothing asks when the function is
run. A test suite written by the author of the order will always supply the
order.

**It surfaced while writing the user guide**, because a guide has to state a
sequence, and stating one forces the question "what if they do it the other
way round". That is a cheap review for any derived value stored at a gesture:
write the paragraph that tells a stranger what to do first.

# What to do

- **For every value a gesture stores from a derivation, list the inputs and
  ask which of them can arrive later.** Each one that can is either a
  recompute trigger or a sentence in the guide.
- **Say the order where the person is**, not only in docs: a helper line that
  reads "no rack pinned on this plan" is worth more than a correct figure that
  silently never appears.
- **A typed value that must never be overwritten** (DR-050 §11.49.3) is a
  good reason to compute at a gesture rather than continuously. It is not a
  reason to compute only at that gesture.

# Related

* [A modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md):
  the same failure one layer out, a value with no producer at all.
* [Count the data before you believe a derivation](a-census-beats-a-plausible-derivation.md).
