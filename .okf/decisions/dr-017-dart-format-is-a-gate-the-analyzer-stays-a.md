---
type: Design Ruling
title: "DR-017 · `dart format` is a gate; the analyzer stays a ratchet"
description: >-
  `dart format` is a gate; the analyzer stays a ratchet. Process, not product; no scope change. Gate 1b in `azure-pipelines.yml` and `run_local.ps1`, so the local count is fourteen. Infos stay pinned in `analyze_info_baseline.txt` (173) rather than `--fatal-infos`, because formatting has one correct answer and style infos do not. docs/11 §7 amended; §9 clause 1 is now the fourteen-gate run. Board #566
tags: [ruling, dr-017, canon-11-16]
timestamp: 2026-08-03T00:00:00Z
ruling_id: DR-017
canon_section: "11.16"
status: ruled
---

**Generated from canon §11.16 on 2026-10-12** (board `#1055`), because the bundle had no
concept for this ruling. Every line below is canon's own text or docs/10's summary; read
the canon section for the reasoning, which this page does not restate.

# How it was settled

**Ruled 2026-08-03.** The first `DR` that is about **process rather than product**. It is numbered

# In one line (docs/10)

**`dart format` is a gate; the analyzer stays a ratchet**. **Process, not product; no scope change.** Gate 1b in `azure-pipelines.yml` and `run_local.ps1`, so the local count is **fourteen**. Infos stay pinned in `analyze_info_baseline.txt` (**173**) rather than `--fatal-infos`, because formatting has one correct answer and style infos do not. docs/11 §7 amended; §9 clause 1 is now the fourteen-gate run. Board #566

# Its clauses, as canon heads them

| Clause | Heading |
|---|---|
| §11.16.1 | What was asked. |
| §11.16.2 | The ruling: both, split by gate. |
| §11.16.3 | Why the two halves differ, since they were documented as one. |
| §11.16.4 | What it does not rule. |
| §11.16.5 | Scope. |
| §11.16.6 | What it cost, and the general lesson. |
| §11.16.7 | Landed. |

# Citations

[1] `docs/canonical-decisions.md` §11.16
