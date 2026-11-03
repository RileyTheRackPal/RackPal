---
type: Gate
title: The pipeline, and what a green run does not prove
description: >-
  azure-pipelines.yml is definition 1 on Azure DevOps and it runs. It ran first on
  2026-08-27 and passed first try, which is what mutation-testing every gate script
  locally buys. The service can report a failure: it has gone red on this definition
  for environmental reasons, and the macOS definition's first run failed test cases
  that all reached the Tests tab. What has not happened is a failing test on this
  definition. The gate set and figures below are run 1's unless a note says otherwise.
tags: [gate, ci, azure-devops, pipeline, non-vacuity, dr-017, m0, m8]
timestamp: 2026-11-03T00:00:00Z
status: live
---

# The pipeline, and what a green run does not prove

Board `#567`. `azure-pipelines.yml` is registered as **definition 1, `RackPal CI
(Windows)`**, on `https://{org}.visualstudio.com`, project `RackMate` (the
Azure DevOps project keeps that name by ruling: DR-096 §11.95.9; the organisation is
named on each machine rather than here, by [DR-257](../decisions/dr-257-one-pseudonymous-identity.md)).

## It ran, and the first run is the interesting one

The file carried the sentence *"NO AZURE DEVOPS RUN HAS EVER EXECUTED IT"* for three and a
half weeks. Because that sentence stood unedited, the gap was cheap to find rather than
being something a reader had to infer.

Build **20260827.1**, against `main` at `078c0f6`: **passed first try**, all 24 steps,
22m01s, zero fixes. Six named unknowns became measurements in one run: the YAML schema was
accepted unmodified, the pinned Flutter archive resolved, `windows-2022` still builds
desktop Windows, and wall clock is 22 minutes rather than an estimate.

**A pipeline of that size (541 lines on run 1; it has grown since) passing on attempt one is not luck.** Every gate script had been
mutation-tested on a developer machine first: deliberately broken, observed to fail, then
restored. The cost was paid before the run, which is why the run was boring.

Build **20260827.2** then took the branches run 1 could not, hitting both caches (Flutter
install 104s to 7s) and running against a non-`main` branch.

## What it defended on run 1, and what has been added since

The table is **run 1's, kept as record** (2026-08-27). It is not the current gate set: read
that from the `Gate:` and `Test:` steps in `azure-pipelines.yml`, and the floors from
`$SuiteFloors` in `tools/ci/run_suite.ps1`.

| Gate | Evidence from run 1 |
|---|---|
| Analyzer ratchet | 0 errors, 0 warnings, **173 infos, exactly the pin** |
| Formatter (DR-017) | clean |
| PAL-1, palette parity, registry parity | pass |
| JUnit converter self-test | pass, and it runs **before** the suites |
| The suites that existed then | **5,609 cases, 0 failed, 0 errored, 0 skipped** |
| Non-vacuity floors | every suite **"exactly at it"** |
| Windows release output | passes over what the build actually produced |

**"Exactly at it" on every floor is the number worth keeping.** Zero slack means the
next deleted test fails the gate on the next run, rather than accumulating until somebody
goes looking, which is what `#764` had to do after finding 3,247 tests of slack.

**Gates the definition runs now that run 1 did not**, each with its own page:

* [Milestone completeness](milestone-completeness.md), roadmap section 8.9 as a check.
* [Rule review pack](rule-review-pack.md) grouping.
* [Glyph coverage](glyph-coverage.md), after a step that installs hash-pinned Python
  dependencies.
* [AC-051 pair coverage](ac-051-pair-coverage.md), as a named step.
* [Identity](identity.md), the DR-258 gate: every reachable commit is the DR-257 identity at +0000.

Two more steps are not gates but belong to the run: the `rackpal_pdfium` suite, and the
timed budgets in `rackpal_core`, run one at a time.

## What it deliberately does not defend

* **Pixel goldens.** There are none (the byte and text goldens DR-253 means by the word run in the ordinary suites), and standing them up inside a CI task would produce a corpus
  blessed by nobody. There is deliberately no `--exclude-tags golden` either, so the first
  golden anybody writes runs in the ordinary suites rather than being silently skipped.
* **"The app opens the four starter projects."** Not runnable headless without an
  `integration_test` target. What *is* checked is one step short and labelled as such: the
  four starters were packaged into the bundle and are byte-intact there.
* **Anything but Windows.** A green Linux job would say nothing about a Windows desktop
  application, and several suites are Windows-specific by design. **macOS is covered by
  [a second definition](the-macos-pipeline.md) since DR-255**, optional and not blocking,
  so this definition is still Windows only.

## The blind spot that matters, and how it closed

**CLOSED ON 2026-10-18, AND NOT BY THIS DEFINITION.** The paragraphs below were true when
written. The service has since gone red on this definition for environmental reasons
(builds 195 and 207, recorded in CLAUDE.md), and build 481, the first run of
[the macOS pipeline](the-macos-pipeline.md), failed 23 test cases: all 23 reached the Tests
tab with their messages, and `PublishTestResults` failed its step on them. The converter and
the publish task are the same files in both definitions, so the reporter's red path is now
observed. What has still never happened is a failing TEST on definition 1.

**As written on 2026-08-27 (history, no longer true): nothing had ever gone red on the
service.** Every gate script was mutation-tested *locally*, but no Azure DevOps run had ever
failed, so the service-side reporting path was exercised in the green direction only.

Green over a broken reporter and green over a healthy one look identical from here. This is
the same shape as the non-vacuity problem the floors exist to solve, one level up: a run
that reports nothing wrong is not evidence that it could. Until a genuine failure is
observed on the service, **a green Tests tab is a weaker claim than it looks**.

## PR validation, and the thing this section got wrong twice

The `pr:` block in the YAML is **ignored** for an Azure Repos Git repository; PR triggers
come from a branch policy. That policy exists (Build validation on `main`, blocking,
policy id 1) and is **exercised**: build `20260828.1` fired on PR !1 and built
`refs/pull/1/merge`, the **merge commit** rather than either branch, which is the good
part. What went green is what landed, not a prediction of it.

**A direct push to `main` is REFUSED**, and this section said the opposite twice:

```
$ git push origin <branch>:main
! [remote rejected] (TF402455: Pushes to this branch are not permitted;
                     you must use a pull request)
```

The claim was that the policy *"gates PR completion only"* and that a direct push
*"still lands and is gated after the fact"*. In Azure Repos a **blocking** policy
protects the branch itself, so one policy does both jobs and `trigger:` is not
covering a hole. **The error is kept here rather than quietly replaced**: it was written
confidently, repeated in three files, and survived because nobody tried the push it
described. See [a confident paragraph is a
tell](/practices/a-confident-paragraph-is-a-tell.md).
