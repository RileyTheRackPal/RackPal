---
type: Design Ruling
title: DR-031 — PathwayKind gains attic and crawlspace, discharging DR-020 §11.19.4
description: The enum question DR-020 dated to "when Pathway gets its editor". Both values are in, because what a PathwayKind value carries is a consequence an integrator acts on, and the objection that both are spaces fails on the fact that a Pathway's location fields are endpoints.
tags: [ruling, m3, pathways, enums, dr-031]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-031
canon_section: "11.30"
status: built
---

Settled by the user on 2026-08-09. `PathwayKind` goes from seven values to
**nine**: `conduit | jhook | tray | plenumSpace | riser | directBury | exterior`
gain `attic` and `crawlspace`.

# It was already dated, and this is the date

[DR-020](/decisions/dr-020-no-predicted-routes.md) §11.19.4 left the question
open and said it was *"Owed at M3, when `Pathway` gets its editor"*. That editor
is board #156 (M3-E/1), and **no other item claimed the question**: it was found
by decomposing M3-J, not by anyone looking for it. See
[census before building](/practices/census-before-building.md).

The timing is the reason the question was deferred rather than settled early:
`PathwayKind` **serialises by name**, so the enum has to be complete before any
gesture can write it. Settle it late and some document records `conduit` for a
run its author would have called `attic`.

# The objection, and why it fails

> Both are **spaces**, and the location tree already models spaces (CR-047), so
> adding them here puts one fact in two places.

It is a real objection and it is wrong on a detail of the model.
`Pathway.fromLocationId` and `Pathway.toLocationId` are **ENDPOINTS**. A run from
the rack to a bedroom crosses an attic that is nobody's room, belongs to no
room's subtree, and is neither end of the run, **so a space in the middle has no
field to live in**. `Location` models where a room IS; this models what a cable
PASSES THROUGH.

# What a value carries is a consequence

That is why these two sit beside `plenumSpace` rather than in a taxonomy of
places:

| Value | What it obliges |
|---|---|
| `plenumSpace` | a jacket rating, NEC 800.154, `CODE-002` |
| `attic` | temperature derating, rodent exposure |
| `crawlspace` | moisture, vermin |

**Neither is an error and neither adds a rule.** The v1 rule catalogue stays at
28. G2 requires the document be able to represent the world as found, and in a
retrofit an attic run is the ordinary case, not a mistake to flag.

`ATTIC` and `CRAWLSPACE` print **unabbreviated**, unlike `PLENUM`: that one is
short for a term of art nobody says in full, where these two are already the
words an installer uses.

# Scope

No scope change. One enum, already in v1, and the ruling it discharges
explicitly left the question open rather than answering it.

# Citations

[1] canonical-decisions.md §11.30 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/model/pathway.dart`, `enum PathwayKind`
[3] `packages/rackmate_core/lib/src/derived/structure_table.dart`,
    `pathwayKindLabel`
[4] Built at `303dc2e`; reachable from the `[ Pathways ]` tab at `e3199a1`
