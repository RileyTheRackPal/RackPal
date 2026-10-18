---
type: Design Ruling
title: DR-255 · macOS CI is a second pipeline on a hosted image, run as an optional PR check, and it may never block
description: >-
  From D4 (#459, #460) of the macOS debt register. The user has no Mac, so macOS CI runs on a
  Microsoft-hosted image against one free job of 1,800 minutes a month. The user chose a non-blocking
  PR check; a separate definition keeps the blocking Windows policy off the allowance.
tags: [ruling, ci, macos, azure-pipelines, hosted-minutes, d4, dr-255, dr-009, dr-248]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-255
canon_section: "11.254"
status: ruled
---

Settled by the user on 2026-10-17, opening D4 of `docs/13-macos-debt-register.md` under
[DR-009](dr-009-macos-in-v1.md).

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Cadence | User, against the recommendation | An optional PR check, about 480 minutes a month on last month's 22 PR builds |
| Never blocking | Follows from the allowance | The month the minutes ran out, a blocking check would stop every merge |
| A second definition | From the tree | `azure-pipelines-macos.yml`, so definition 1's verdict never depends on hosted minutes |
| The pin | From the tree | Read from `azure-pipelines.yml` with `run_local.ps1`'s patterns ([DR-248](dr-248-fourteen-day-cooldown-and-flutter-3-47-5.md)) |
| Per-platform gates | From the tree | Timed budgets stay Windows-only; the build waits for D1 and D6; the rest runs on both |

Not taken: a nightly run when `main` moved (the recommendation), weekly, manual-only. Every build was not
offered, at about 2,700 minutes, 150% of the allowance.

# Price the cadence before offering it

The allowance is a number anybody can read (`distributedtask/resourceusage`), and so is the build count.
Put side by side they removed one option outright and put a figure on each of the others, which is what
made this a choice between costs rather than between words.

# Related

* [DR-009](dr-009-macos-in-v1.md), which puts macOS in v1 and makes docs/13 a work list.
* [DR-248](dr-248-fourteen-day-cooldown-and-flutter-3-47-5.md), the pin's single home.
* [The pipeline itself](/gates/the-pipeline-itself.md), definition 1.
