---
type: Practice
title: When a ruling has two clauses, check whether one of them is load-bearing for the other
description: >-
  AC-044 said a 0U occupant is edited from the inspector AND renders as a plain
  bar. Only the first was built at #876, and it could not be reached, because
  nothing that is never drawn can ever be selected.
tags: [practice, rulings, scope, reachability, ac-044, m5]
timestamp: 2026-09-13T00:00:00Z
---

AC-044 reads: *"In v1 a 0U occupant is created and edited from the inspector
(channel, start U, span) and **renders as a plain bar**; there is simply no drag
gesture."*

Two clauses in one sentence, joined by "and", and they look independent. They
are not. **The inspector edits a SELECTED device, and nothing that is never
drawn can be selected.** `scene_builder.dart` reads
`if (placement is! RailPlacement) continue;`, so a 0U occupant is not in the
elevation's scene, is never hit-tested, and cannot be reached by a pointer.

So the fields were built on the device inspector, exactly where the ruling puts
them, against a panel that could never open on that device. It was caught only
because the ticket's author went looking for how a person would select the PDU,
and found one line.

# What to check

**Read a ruling's clauses as a graph, not a list.** Ask of each: what does this
one need in order to be true? A clause naming a SURFACE usually needs a clause
naming a way to GET there, and the second is the one that gets deferred, because
it is the expensive half.

**The tell is a verb that implies a subject you have not built.** "Edited from
the inspector" implies selection. "Reported on the schedule" implies a row.
"Confirmed before it runs" implies a dialog. When the clause supplying the
subject is in the deferred pile, the clause using it is deferred too, whether or
not anybody said so.

**Say so in the ruling, not only in the ticket.** DR-163 §11.162.1 records that
the device inspector was tried and could not be reached, so the next reader does
not conclude it was weighed on its merits and rejected. A ruling that quietly
ends up somewhere else teaches the wrong lesson twice.

# The other direction, which is cheaper

A half-built ruling is also an opportunity: the half that IS built tells you the
shape of the half that is not. Here the inspector work made the missing bar
precise enough to file in one paragraph, with the line number, rather than as
"0U rendering, someday". `#883` exists because `#876` went looking.

# Related

* [A gate's output is read as a fact](a-gate-is-read-as-a-fact.md) is the same
  habit pointed at a tool rather than at a ruling.
* [A brief expires](a-brief-expires.md) is the time-dependent version: there the
  ruling changed under the task, here the ruling was always this shape and only
  half of it landed.
