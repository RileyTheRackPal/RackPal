---
type: CI Gate
title: The macOS pipeline, and why it may never block
description: azure-pipelines-macos.yml is definition 2, an optional PR check on a Microsoft-hosted macOS image (DR-255). It runs every Windows gate but the timed budgets and the build, and its first run predicted-then-proved the platform's whole debt, case for case.
tags: [gate, ci, macos, azure-pipelines, hosted-minutes, floors, dr-255, dr-009, dr-153, d4, d5]
timestamp: 2026-10-17T00:00:00Z
resource: azure-pipelines-macos.yml
status: enforced
---

Definition 2, `RackPal CI (macOS)`, on a Microsoft-hosted `macOS-15` image. Ruled by
[DR-255](/decisions/dr-255-macos-ci-is-an-optional-pr-check.md) under
[DR-009](/decisions/dr-009-macos-in-v1.md).

# Why it is optional, and must stay so

The organisation has one free hosted job of 1,800 minutes a month, and a run costs a
measured 27.2 minutes (build 481). Definition 1 is the blocking policy on `main` and runs
on a self-hosted agent that costs nothing, which is why this is a second definition and
not a second job: a blocking macOS check would let a minute counter decide what merges.

# What it runs, and what it does not

Every step of [the pipeline itself](the-pipeline-itself.md) except two:

* **The timed budgets.** Their limits are wall clock calibrated on one machine; on a
  shared VM they would measure the VM.
* **The build and its output gate.** There is no `macos/` runner (docs/13 D1) and no
  `verify_macos_build.ps1` (D6) yet.

The Flutter pin is read from `azure-pipelines.yml`, never restated, and a
`UsePythonVersion` step supplies the `python` every gate calls.

# Its floors differ, and each difference is named

`$SuiteFloorsMacOS` in `tools/ci/run_suite.ps1` holds only the rows that differ from the
Windows table, with the arithmetic: `testOn: 'windows'` cases macOS never registers, and
the pdfium cases that skip there (Story #61, Chapter #468). Those are the repository's
first `skip:`. A check that stayed red for a known reason could not show a new one, so they
skip on macOS and nowhere else.

# Blind spots

* **It is not a release.** Nothing is built, signed or notarised (D8) on macOS.
* **Optional means ignorable.** An optional red check that gets merged over once stops
  being read. Its value is entirely in somebody looking at it.
* **It does not compare across platforms.** `rackpal_export` passing on both says each
  platform agrees with itself; whether the PDF bytes are identical between them is a
  separate, unwritten comparison (docs/13 §4).
