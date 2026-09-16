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
status: built
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

# Built

`#80` landed it on 2026-09-16 (``1445d547``, ``5ae8180f``). The job's standard is a project setting
with a three-item row where unset is a CHOICE rather than a blank; a cable's override is an optional
`WIRING` column in the Structure editor; and the resolved value prints in the Termination Schedule's
`TERM` cell, behind the termination type and the punch position.

**The predicate takes the DOCUMENT, not the `Link`.** A first draft read the cable alone, so it could
see the media and the two origin terminations and nothing else. The ruling's second qualifier is "one
of its ends is an RJ45 port or plug", and a port's connector is a template join: that draft answers
false, silently, for a run on a shop's own media entry landing on two patch-panel jacks. It looked
cheaper and was a narrower rule wearing the ruling's words.

**A `punchdown` does not qualify a CABLE and does qualify an END**, which is why two sets hold the
same value on purpose. A 66 block carries voice, so a punchdown is no evidence that a cable is
four-pair data; on a cable already known to be data it is a 110 block or a patch panel, where pair
order is exactly what lands.

**The column shows the OVERRIDE, never the resolved value.** A control writes what it shows, so a
column showing the effective standard would let somebody pin a cable to the project's value by
picking what was already on screen, and a later change to the project would pass that cable by with
nothing on screen to say so.

**Not built, and not hidden**: `T5.01` stays M6's and what exists is its trigger. The user asked for
an inspector row beside the column, and there is no cable inspector in the product to put one in.
