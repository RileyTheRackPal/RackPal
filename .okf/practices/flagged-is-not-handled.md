---
type: Practice
title: Writing UNVERIFIED next to a decision is not the same as pricing it
description: PLAN-D/1 picked pdfium via pdfrx and recorded two unknowns in capitals. Both turned out to be fatal, and the capitals are why nobody checked. An honest flag reads as a risk that has been handled, so it buys the decision the same passage it should have blocked.
tags: [practice, decisions, verification, corpus, dr-138, dr-137, cr-100, plan-d]
timestamp: 2026-09-07T00:00:00Z
status: adopted
---

This corpus is unusually honest about what it does not know. That honesty is
load-bearing and should not be traded away. But an unknown written down is still
an unknown, and there is a failure mode specific to writing it down **well**:
the flag reads as diligence, and diligence reads as safety.

# The instance

`PLAN-D/1` chose pdfium via `pdfrx` and recorded, in capitals, that **two things
were unverified**: the Dart wrapper's licence, and whether its build fetches
pdfium or accepts a vendored one. docs/03 carried `pdfrx` as `planned` for
exactly that reason. Everything about that is correct practice.

Then the chapter closed, the choice entered docs/12, docs/13 and docs/03, and
three later chapters were planned around it.

When `PLAN-D/3` finally checked, **both unknowns came back and one of them was
fatal twice over**:

| | |
|---|---|
| Licence | **Clean.** MIT throughout, compatible with DR-036 |
| The build | **Downloads pdfium at build time on every route.** [CR-100](/decisions/) rules that pdfium is *"vendored into the repo rather than downloaded at build time"* |
| And separately | `pdfrx` 2.x needs Flutter **3.47**; the repo is pinned at **3.44.4**, and the pin is a gate |

**The package chosen to make pdfium's vendoring "one problem paid once" was a
package that cannot accept a vendored binary.** The reasoning that selected it
was sound; it just rested on the half nobody had run.

# Why the capitals made it worse rather than better

A decision with an unexamined assumption gets challenged, because the assumption
is invisible and someone eventually trips over it. **A decision with a
prominently flagged unknown does not get challenged, because the flag looks like
the challenge already happened.** The reader's question, *"has anybody checked
this?"*, is answered by the presence of the note: yes, somebody thought about it
carefully enough to write it in capitals.

So the honest flag did the work of a clearance. It let the choice propagate into
four documents and three chapters' worth of planning, and the cost of the
correction scaled with that spread rather than with the check, which was two web
pages and a `dart --version`.

# The rule

**An unknown that could reverse the decision is a blocker, not a note.** Sort
them at the moment you write them:

* **Could this answer change the choice?** Then it is not an unknown to record,
  it is a check to run before the chapter closes. Both of PLAN-D/1's were this,
  and both were minutes of work.
* **Could it only change the cost?** Record it, with the range.

And when a flagged unknown must survive a chapter, **say what it would do if it
came back wrong**, in the same sentence. *"Unverified: whether the build fetches
pdfium. If it does, CR-100 refuses this package and the choice is void"* is a
note nobody can read as handled.

# The tell

**The flag and the decision were written by the same person in the same
paragraph.** That is the same structure as
[a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md): the argument
beside the claim is good, so the claim arrives pre-trusted. Here the claim is
*"this is unverified"*, which is true, and what gets smuggled through is
*"and that is acceptable"*, which was never argued at all.

# What this is not

It is not an argument for fewer flags. **PLAN-D/1's note is the only reason
`PLAN-D/3` knew what to check**, and a chapter that had silently assumed the
build was fine would have discovered it later and with less to go on. The fix is
to sort them, not to stop writing them.

It is also not
[a borrowed rule is not re-checked](a-borrowed-rule-is-not-re-checked.md).
There, nothing was flagged because nobody noticed there was an assumption. Here
the assumption was named, in capitals, and named is where it stopped.
