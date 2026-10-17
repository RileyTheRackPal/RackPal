---
type: Design Ruling
title: DR-204 · A device can be set on a shelf, and it is drawn there
description: >-
  Nothing in the rack editor could put a device on a shelf, and a device that was on one was never
  drawn. Drag onto a shelf and an inspector picker; any device may sit on a shelf; a new optional
  shelf width, because chassis width is always a 432 mm default; hosts drawn and selectable; drag
  along reorders, onto another shelf moves, elsewhere deletes; deleting a shelf asks; the shelf
  shows its load against capacity.
tags: [ruling, rack-editor, shelves, ac-043, cr-029, g4, dr-204]
timestamp: 2026-09-30T00:00:00Z
ruling_id: DR-204
canon_section: "11.203"
status: built
---

Settled by the user on 2026-09-30 across two rounds of questions. Where the user overruled or went
past a recommendation, the ruling says whose choice each clause is.

# What was ruled

- **Both a drag onto a shelf and an inspector picker** (the user's choice over drag alone).
- **Any device may sit on a shelf**, on the user's trade knowledge: an AVR rack kit is a separate,
  device-specific product and often does not exist, so the template gets no vote. A rack-ear device
  set on a shelf is allowed, and the status line says so.
- **`shelfWidth`, a new optional length**, blank meaning unknown. A known width draws at true scale;
  an unknown one draws hollow. `chassisWidth` is not reused: it is a 432 mm default on every template.
- **Hosts are drawn and selectable**, packed by `order`.
- **Dragging a host** (§11.203.9, reconciled with DR-205): along its shelf reorders, onto another
  shelf moves, onto free rails mounts it (the AVR case), off the rack sends it to the Staging Bin
  with its wiring, and anywhere else on the rack removes it, announced on the ghost first.
- **Deleting a shelf asks**, defaulting to moving its hosts to the Staging Bin.
- **The shelf header shows its load** against capacity, never blocking.
- **A loaded shelf is labelled in its header only** (§11.203.10), and its hosts' port chips show on
  hover or selection, after the user's screenshot showed both colliding with the hosts' labels.

AC-043's cuts (free lateral position, `Alt`-drag, the third focus level, overhang warnings) and
`#844`'s richer model (stacking, sub-1U heights, orientation) stay deferred.

# How it was found, and a question put twice

A census before any question found no producer of `ShelfPlacement`, no renderer, a delete path that
stranded hosts, and no known shelf width anywhere. The author had first offered "an unrecorded width
gets a hollow slot" on the premise that widths came from `chassisWidth`; the user chose it, the
premise was false, and the question was put again with that said. See
[census before building](/practices/census-before-building.md).
