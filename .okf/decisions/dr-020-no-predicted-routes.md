---
type: Design Ruling
title: "DR-020 · A plan may not predict a route; the length column's job is the as-built tally"
description: >-
  A plan may not predict a route; the length column's job is the as-built tally. The first ruling whose evidence is the trade rather than the corpus. Structure (LVLs, concrete beams, purlins) forces runs into a crawlspace instead of an attic and is not knowable from a floorplan, so `docs/15` §4's design-time route polyline is void one commit after it was written, along with `routingFactor` and `slackAllowance`. The plan contributes `planLowerBound` only: italic, prefixed `≥`, never summed into the footage rollup. Its value is the asymmetry, a bound can prove a length violation and can never prove compliance. v1 gains three items: `Link.spliceCount: int?` (null unknown, `0` confirmed none), the generic `LEN-002` reading a maximum off the media registry (canon §11.19.7: the field is `maxRunLengthPassive`, it is not new, and M3-C/6 seeded it), and the as-built tally surface in M3. The catalogue becomes 28 (8 + 6 + 14), superseding §12.6(b) on the number only; AC-051's gate applies to 28 pairs. `PathwayKind` gaining `attic`/`crawlspace` is left open for M3
tags: [ruling, dr-020, canon-11-19]
timestamp: 2026-08-04T00:00:00Z
ruling_id: DR-020
canon_section: "11.19"
status: ruled
---

**Generated from canon §11.19 on 2026-10-12** (board `#1055`), because the bundle had no
concept for this ruling. Every line below is canon's own text or docs/10's summary; read
the canon section for the reasoning, which this page does not restate.

# How it was settled

**Ruled 2026-08-04.** A **scope amendment under roadmap §8.3** and the first ruling in this record

# In one line (docs/10)

**A plan may not predict a route; the length column's job is the as-built tally**. **The first ruling whose evidence is the trade rather than the corpus.** Structure (LVLs, concrete beams, purlins) forces runs into a crawlspace instead of an attic and is not knowable from a floorplan, so `docs/15` §4's design-time **route polyline is void one commit after it was written**, along with `routingFactor` and `slackAllowance`. The plan contributes **`planLowerBound`** only: italic, prefixed `≥`, never summed into the footage rollup. Its value is the asymmetry, a bound can **prove** a length violation and can never prove compliance. v1 gains three items: `Link.spliceCount: int?` (null unknown, `0` confirmed none), the generic **`LEN-002`** reading a maximum off the media registry (canon §11.19.7: the field is `maxRunLengthPassive`, it is not new, and M3-C/6 seeded it), and the **as-built tally surface in M3**. **The catalogue becomes 28** (8 + 6 + 14), superseding §12.6(b) on the number only; AC-051's gate applies to 28 pairs. `PathwayKind` gaining `attic`/`crawlspace` is left open for M3

# Its clauses, as canon heads them

| Clause | Heading |
|---|---|
| §11.19.1 | What the trade said, and why it overturns §4's first draft. |
| §11.19.2 | The ruling, five parts. |
| §11.19.3 | Why most of this was already built, which is why it is cheap. |
| §11.19.4 | What it does not rule. |
| §11.19.5 | Scope. |
| §11.19.6 | Landed. |
| §11.19.7 | The registry field is not new, and this is the census rather than a decision. |

# Citations

[1] `docs/canonical-decisions.md` §11.19
