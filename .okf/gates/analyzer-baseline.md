---
type: CI Gate
title: The analyzer info ratchet
description: Errors and warnings gate at zero; info-level issues gate at an exact pinned integer that may only move with a written justification.
tags: [gate, ci, analyzer]
timestamp: 2026-07-28T00:00:00Z
resource: tools/ci/analyze_gate.ps1
status: enforced
---

`pwsh -File tools/ci/analyze_gate.ps1` must report **0 errors, 0 warnings, and
exactly the pinned info count** (194 as of `a984add`).

# Why a number and not `--fatal-infos`

`very_good_analysis` reports ~195 infos on this tree, so `--fatal-infos` would
make `main` permanently red on the first push, and a permanently red main is
worse than no CI. Clearing them and then switching to `--fatal-infos` is the
destination; the pin is what stops the number moving the wrong way in the
meantime, after it went 203 → 395 during the salvage with nothing watching.

# It scans tests, not just `lib/`

This surprises people. A lint in a new test file fails the gate exactly as a lint
in `lib/` does. In practice most accidental drift comes from tests:
`cascade_invocations`, `avoid_escaping_inner_quotes`,
`no_leading_underscores_for_local_identifiers`, and
`use_late_for_private_fields_and_variables` on a nullable-only-for-deferred-init
field.

# Raising the pin

Permitted, but it requires **saying why in the commit message**. To lower it after
fixing infos: `pwsh -File tools/ci/analyze_gate.ps1 -UpdateBaseline`.

# The hazard when work runs in parallel

The baseline is **one integer in one file**. Two branches that each raise it
independently do not produce a merge conflict, they produce a merged number that
is silently wrong. When parallel agents or branches are in flight, the rule is
that **nobody raises it**; if one genuinely must, it goes second and alone.

# Citations

[1] `tools/ci/analyze_info_baseline.txt`, the pin, with its own rationale header
[2] `tools/ci/analyze_gate.ps1`
