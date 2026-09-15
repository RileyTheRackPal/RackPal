---
type: Design Ruling
title: DR-180 · A project states its wiring standard, and a cable may override it
description: >-
  Nothing in the model could say T568A or T568B, so the corpus stored it in a conductor's pair colour.
  The user ruled a project-wide standard with an optional per-cable override, unknown when unset and
  never an assumed T568B, shown only on four-pair or RJ45 cables.
tags: [ruling, model, schedule, termination, dr-055, dr-180]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-180
canon_section: "11.179"
status: ruled
---

Ruled by the user on 2026-09-15 on board `#80`.

# The last of four missing fields

`#80` listed four fields docs/08 names and the model lacked. DR-010 added the family short tag and
DR-026 settled the pathway designator and the outlet's nominal run length. T568A or T568B was left.

# What was measured

- No field states a wiring standard; the termination type names the jack, not the colour code.
- docs/08 prints `T568B` in its termination examples and turns `T5.01` on for a non-default T568A.
- The corpus's worked example stores `T568B` in `Conductor.colorCode`, whose meaning is the pair colour.
- `ProjectSettings` already holds project-wide defaults of the same kind.

# What was ruled

- **The project states a standard, and a cable may override it.** A cable's standard is its override,
  else the project's, else unknown.
- **Unset is unknown, never T568B**, and both keys are absent when unset (G4).
- **Shown only where it can be true**: a four-pair twisted-pair cable or one with an RJ45 end.
- A known standard prints beside the termination type, and a cable that differs from the project turns
  `T5.01` on when M6 builds it.
- Refused: a field per cable alone, one per end, and not modelling it. A crossover cable stays
  unrepresented.
