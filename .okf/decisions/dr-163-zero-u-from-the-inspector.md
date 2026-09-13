---
type: Design Ruling
title: DR-163 — A 0U channel is added, removed and occupied from the inspector
description: >-
  AC-044 ruled the inspector surface for 0U into v1 and it was never built: three
  commands with real reverts, three planners with real refusals and a helper
  written for a panel that did not exist. The rack inspector now adds and removes
  channels and lists what is mounted in each. Building it found a sub-1 channel
  and a surface that could not be opened.
tags: [ruling, zero-u, inspector, ac-044, cr-025, dr-163, m5]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-163
canon_section: "11.162"
status: ruled
---

Settled by the user on 2026-09-13, closing `#876`, the last of the eight `#872`
filed.

# The ruling was explicit and half of it was never built

AC-044: *"In v1 a 0U occupant is created and edited from the inspector (channel,
start U, span) and renders as a plain bar; there is simply no drag gesture."*

`zero_u_commands.dart` holds three commands with real reverts, three planners
with real refusals, and `occupantsOfZeroUChannel`, whose own doc says it is
*"Public because the inspector needs to say 'AMP-1 is in this channel' before
offering to delete it"*. **The inspector was anticipated in the code and never
arrived.**

# The form takes the bounds up front, because nothing can edit them

There is no command that changes a channel's extent: add and remove is all there
is, so a wrong one is replaced rather than corrected. A one-click full-height
default would be a claim about the rack that somebody wanting U 1 to U 12 has to
delete and retype. **Two comments in the tree promised otherwise**, and `#876`
makes the *remove* half of each true for the first time.

The surface validates nothing. The planners refuse a duplicate id, an inverted
span, a span that does not fit and a removal while occupied, each with a sentence
naming the rack, the numbers or the device; the panel hands over a `ZeroUResult`
and the screen runs it or prints it.

# A correction, recorded rather than quietly re-aimed

The occupant's channel and start U were ruled onto the DEVICE inspector, because
that is where AC-044 puts them. **They were built there and could not be
reached**: `scene_builder.dart` drops every placement that is not a
`RailPlacement`, so a 0U occupant is never drawn, never hit-tested and never
selectable. AC-044's two clauses depend on each other and only one of them
shipped.

The fields moved under their channel in the rack panel, which `Ctrl+Alt+U`
reaches with nothing selected. Building the plain bar first was refused as a
separate body of work rather than as a bad idea, and is `#883`.

# And the one channel the product could make was out by one

`add_outlets.dart` wrote `startU: 0` citing **CR-025**, which rules *"1-based,
bottom origin"* and calls itself the contradiction that *"will actually hurt"*.
Every starter, every other test, `placement_rules.dart`'s inclusive length and
`rack_shrink.dart`'s normalisation of *"an inverted or sub-1 channel"* disagreed
with it, and `planAddZeroUChannel` refuses `startU < 1`.

**The guard existed and the producer bypassed it**, building the command
directly. A validated planner beside an unvalidated producer protects the callers
it does not have.

# Corrected by DR-164

This ruling said, at §11.162.5, that creating a 0U occupant *"is
`catalog_placement.dart`'s"* and that AC-044's *"created"* is satisfied by the
palette. **The palette refuses a 0U row and tells the reader to use this very
panel.** Each surface deferred to the other and nothing could place at all;
[DR-164](/decisions/dr-164-a-device-goes-into-a-channel.md) builds the control,
and the clause stands as written in canon because what it got wrong is the
point.

# The reason for the rack panel is spent

The occupant's channel and start U moved there because a 0U device **could not
be selected**. [DR-166](/decisions/dr-166-a-zero-u-occupant-has-a-span.md) draws
the bar and makes it selectable, so that reason no longer holds. They stay where
they are, because the rack panel lists occupants under the channel they sit in
and that is how the work is done, but the next reader should know it was
re-decided rather than inherited.

**AND THE FIELDS HAVE SINCE MOVED BACK**, by
[DR-167](/decisions/dr-167-the-occupant-fields-move.md), once `#883` made a 0U
device selectable. What is above is the record of why they were ever anywhere
else.

# Related

* [When a ruling has two clauses, check whether one is load-bearing for the
  other](/practices/two-clauses-that-depend-on-each-other.md) is what the
  correction above produced.
* [A surface tested alone has never met its
  host](/practices/a-surface-tested-alone-has-no-host.md) is the neighbouring
  habit: there the surface existed and nothing mounted it, here it would have
  been mounted on a selection that cannot happen.
