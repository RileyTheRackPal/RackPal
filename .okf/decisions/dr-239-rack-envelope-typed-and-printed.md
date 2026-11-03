---
type: Design Ruling
title: DR-239 · A rack's envelope is typed in the rack inspector and printed on its elevation
description: >-
  An Enclosure section below Form factor writes the rack's overall size, own weight, doors and their
  clearances; rail clearance (inside the door) and door clearance (swing space) are distinct, in the
  trade's own words; the elevation prints one envelope line with that face's door.
tags: [ruling, rack, envelope, inspector, elevation, clearance, dr-239, dr-188]
timestamp: 2026-10-06T00:00:00Z
ruling_id: DR-239
canon_section: "11.238"
status: built
---

Settled by the user on 2026-10-06 for `#923`, the writer
[DR-188](/decisions/dr-188-cad-lite-and-dxf-opens-v1-3.md) found missing.

# What was ruled

- **An Enclosure section** below Form factor, in mm and kg; a clearance is disabled without its door.
- **Two clearances per door**, in the user's words: *rail clearance* is the depth inside the door, *door
  clearance* the swing space in front of it. `frontRailClearance` and `rearRailClearance` are added; the
  rear one is the implementer's extension, for symmetry.
- **The elevation prints one line**: the size and that face's door, unknowns as a dash
  ([G4](/invariants/g4-unknowns-are-counted.md)). Own weight left the line by measurement: with it, the
  worst case was 331.5 pt against a 327 pt column.

See [trade knowledge beats workflow reasoning](/practices/trade-knowledge-beats-workflow-reasoning.md):
the question offered "depth inside" or "swing space", and the answer was both, with their trade names.

Canon §11.238 holds the full text.

Built at `10ade4d9`, `ae8d1a2a`, `5a994927` and `b598dd33`; docs/12 §4.49 holds the evidence.
