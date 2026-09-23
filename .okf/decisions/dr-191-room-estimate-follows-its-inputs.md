---
type: Design Ruling
title: DR-191 · A room's plan estimate follows its inputs, and says why when it cannot
description: >-
  The plan-derived run length is re-derived by every transaction, inside the same undo entry, by a consequence the controller installs itself; a plan figure that stops deriving is cleared; a typed one is never touched; a blank one names the missing input.
tags: [ruling, plan, length, g4, consequence, dr-191, dr-050, dr-187]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-191
canon_section: "11.190"
status: ruled
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

- **Every transaction re-derives** each room the plan may fill (empty, or the plan's own earlier
  figure), through `DocumentController.addConsequence`, so one undo takes back an edit and the figure
  it moved.
- **A plan figure that stops deriving is cleared** (G4: a computed number whose inputs are gone is a
  guess). A typed figure is never touched in either direction (DR-050 §11.49.3).
- **The hook is installed by the controller**, on every construction path. DR-187's freeze is
  registered by the Schematic view and does nothing until that view is opened; a fact about the
  document must not depend on which tab somebody visited.
- **A blank figure names what is missing**, including the multi-floor case that only typing can fix.

# How it was found

Writing the user guide. The derivation was right and the TRIGGER was wrong: it ran only when an
outline was drawn, so the natural order computed nothing.
[A figure computed at a gesture is an order the user has to know](/practices/a-derived-figure-computed-at-a-gesture-is-order-dependent.md)
records the shape.
