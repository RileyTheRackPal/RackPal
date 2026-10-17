---
type: Design Ruling
title: DR-164 — A device is put into a 0U channel from the channel's own row
description: >-
  Nothing in the product could put a device in a 0U channel. The parameter that
  would have done it had zero call sites, and the gap was recorded one ruling
  earlier as handled by a surface that refuses. The channel row now has an Add
  device control, and a mutation proved the ruling's own reasoning wrong on the
  way.
tags: [ruling, zero-u, inspector, ac-044, dr-163, dr-164, reachability, m5]
timestamp: 2026-09-13T00:00:00Z
ruling_id: DR-164
canon_section: "11.163"
status: built
---

Settled by the user on 2026-09-13, from their own report against `#876`'s work:
*"the rack inspector list doesn't actually show a 0U device at all"*.

# The producer nothing in the product had

`buildPlaceFromCatalogCommand` takes a `ZeroUTarget? zeroU` and the branch
behind it is complete: it builds the `ZeroUPlacement`, runs `evaluatePlacement`
and returns `PLC-003`'s refusal by name. **`ZeroUTarget` has one definition,
one mention in a comment, and zero call sites.** The only reachable writer of a
`ZeroUPlacement` in the product was `planSetZeroUPosition`, which MOVES one that
already exists.

So `#876` shipped a list, a remove that refuses while occupied, and a move
between channels, over a set nothing could ever add to. The three starters that
show a PDU get it from the authoring tool writing the placement directly, which
is why it looked alive to everything that tested it.

# The gap was recorded, and recorded as handled

§11.162.5 said placing into a channel *"is `catalog_placement.dart`'s"* and that
AC-044's *"created"* is *"satisfied by the palette"*. The file it names refuses
exactly that, with *"Add it from the rack inspector (AC-044)."*

**Each surface deferred to the other.** That is
[a deferral that names a path which refuses](/practices/each-surface-deferred-to-the-other.md),
and the reason it survived review is that a deferral reads as a decision: it is
not a TODO, carries no board id, and names a real function in a real file.

# What the ruling decided rather than leaving to the code

**An `Add device…` control on the channel's own row**, against a drag from the
palette onto the rendered bar. The bar is `#883` and does not exist, so that
gesture would put the only producer behind the one AC-044 clause already left
unbuilt: [the two-clause trap](/practices/two-clauses-that-depend-on-each-other.md)
a second time, inside the same feature.

**The occupant lands at the channel start**, not at a first free offset. A 0U
occupant has no extent anywhere in the format, so there is no overlap and "free"
has no meaning.

**The picker reads the document**, not the seed catalog, because an authored 0U
template is in the document and in no catalog.

# And a mutation proved the ruling's own reasoning wrong

§11.163.4 was drafted saying the new occupant is not selected because selecting
it would swap the inspector to a device panel. **It would not**:
`_inspectorTarget` moves on canvas gestures and never on `_selection.apply`. The
case defending that clause asserted the panel stayed and **passed with the
mutation applied**.

The decision survived with a better reason. `_finalizeCatalogPlacement` requests
canvas focus and selects in one breath, and pairing those aims the keyboard at a
device the elevation never draws, where `Delete` removes an unwired device with
no confirmation. The case now asserts that instead, and the mutation kills it.

# Related

* [DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) is what this
  completes and what it corrects.
* [Assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) is what the
  rewritten case obeys, and the house rule the first draft broke.
* [A mutation that does not build measures
  nothing](/practices/a-mutation-that-does-not-build-measures-nothing.md) is
  the neighbouring habit: there the mutation measured nothing, here it measured
  the ruling.
