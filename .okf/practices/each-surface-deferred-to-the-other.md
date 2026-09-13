---
type: Practice
title: A deferral reads as a decision, so check that the path you defer to accepts
description: >-
  The rack inspector said the palette placed 0U devices. The palette said to use
  the rack inspector. Both sentences were written by somebody who had looked at
  the other file, and between them nothing in the product could place a 0U device
  at all.
tags: [practice, reachability, rulings, deferral, ac-044, dr-164, m5]
timestamp: 2026-09-13T00:00:00Z
---

Canon §11.162.5, written while building `#876`:

> It does not let a person CREATE a 0U occupant from nothing either: placing a
> device into a channel is `catalog_placement.dart`'s, and AC-044's *"created"*
> is satisfied by the palette placing a 0U-capable device, not by a control in
> this panel.

`catalog_placement.dart`, that same day:

> `P01` is a 0U occupant: it mounts in a vertical channel, not rail holes. **Add
> it from the rack inspector** (AC-044).

Each names the other. Neither is wrong about where the work *belongs*. Together
they meant that **nothing in the product could put a device in a 0U channel**,
and the list `#876` built was a view over a set that could never be non-empty.

# Why it survived being written down

**A deferral does not look like a gap.** Compare the two things it could have
been:

- *"TODO: nothing can create a 0U occupant yet."* Reads as debt. Gets a board
  id, or gets grepped by the next census.
- *"Placing into a channel is `catalog_placement.dart`'s."* Reads as
  **architecture**. It names a real file, holding a real function, with a real
  parameter for exactly this. Everything about its shape says somebody checked.

The second is the more careful-sounding sentence and it is the one that hides
the hole. [Flagged is not handled](flagged-is-not-handled.md) is the same shape
one step along: there a risk written in capitals read as a risk already cleared,
here a gap written as architecture reads as a gap already placed.

# What to check

**When you write "X does this, not me", open X and find the line that does it.**
Not the file, not the function name: the call site, or the branch that would run.
In this case the branch existed and its guard was `zeroU != null`, and a census
of that parameter takes one grep and answers in one line: **one definition, one
mention in a comment, zero call sites.**

**A parameter with no caller is the cheapest reachability census there is**, and
it catches what a `Command`-level gate cannot. `#872`'s gate scans for `Command`
classes reachable from the UI; `buildPlaceFromCatalogCommand` produces an
`AddDeviceCommand`, which the rack path reaches, so the gate saw this area as
covered while one of its two entry points had never been called.

**And check the deferral in BOTH directions.** The tell here is not that one
comment was wrong. It is that two comments, in two packages, each pointed at the
other, and reading either one alone was reassuring.

# Related

* [When a ruling has two clauses, check whether one is load-bearing for the
  other](two-clauses-that-depend-on-each-other.md) is the same failure inside a
  single sentence rather than across two files.
* [A surface tested alone has never met its
  host](a-surface-tested-alone-has-no-host.md) is the version where the surface
  exists and nothing mounts it.
* [A gate's output is read as a fact](a-gate-is-read-as-a-fact.md) is why
  `#872`'s empty exemption list did not mean what it looked like it meant.
