---
type: Design Ruling
title: DR-235 · A declared adapter is named on the cable bar, listed on T6.30, noted on the schedule and marked on the drawing
description: >-
  Link.inlineAdapters had a writer and no reader a person could see. The cable bar gains Model and
  Remove, T6.30 an in-line adapters table, the schedule a note, and both renderings a lozenge.
tags: [ruling, adapter, inline-adapter, bom, t6-30, cable-bar, schematic, dr-235, dr-128]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-235
canon_section: "11.234"
status: ruled
---

Settled by the user on 2026-10-04, building `#1001`.

# What was ruled

- **Kept whole**: DR-128 §11.127.2's promise that an adapter reaches the BOM, over deleting the sentence
  that pointed at a missing inspector.
- **The cable bar names it**: each adapter by its connectors, with Model and Remove, one undo step each.
- **T6.30 lists it**: one row per connector pair and model; an unstated model is its own row, counted
  ([G4](/invariants/g4-unknowns-are-counted.md)).
- **The schedule notes it**, on [DR-231](/decisions/dr-231-crossover-hosts-and-polarity-reversed.md)'s
  machinery, for whoever terminates the cable.
- **A lozenge on both renderings**: each pennant of the label pair, and a drawn wire's midpoint.

# Why it was more than a sentence

The ticket was one line of dead copy. Measuring found the ruling behind it unkept: no reader of
`inlineAdapters` outside two rules and the codec. See
[copy outlives the route it names](/practices/copy-outlives-the-route-it-names.md).

Canon §11.234 holds the full text.
