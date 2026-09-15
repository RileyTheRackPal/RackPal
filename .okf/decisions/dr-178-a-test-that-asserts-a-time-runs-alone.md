---
type: Design Ruling
title: DR-178 · A test that asserts a time runs in its own gate step, one test at a time
description: >-
  A docs-only commit once failed the core suite when a stopwatch budget read three times slower under
  suite load. The user ruled that every assertion on a stopwatch reading leaves the package suites for
  one gate step of its own, run one test at a time, while counts and digests stay where they are.
tags: [ruling, ci, gates, performance, dr-076, dr-178]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-178
canon_section: "11.177"
status: built
---

Ruled by the user on 2026-09-15 on board `#843`.

# A false red on a commit that could not have caused it

On 2026-09-05 a commit touching three markdown files failed `schematic_perf_test.dart`: the
text-bound case read 20.877 ms against a 16.67 ms frame, and 6.355 ms when run alone. The file asserts
operation counts, which are deterministic, beside stopwatch readings, which are not.

# What was measured

- 184 builds since that day, two failures, both the machine rather than this test.
- Alone today the 300-link cases take about 5 ms and an edit about 0.5 ms against the frame.
- Two files carry the `perf` tag and only `schematic_perf_test.dart` asserts a time, in five
  `lessThan` checks. The tag filters nothing, so a timed case competes with its own suite.

# What was ruled

- **Stopwatch assertions run in one gate step of their own**, one test at a time, locally and in the
  pipeline.
- **Counts, digests and shapes stay in their suites**, so M2-C's op-count record keeps running.
- **No budget changes.** DR-076 §11.75.4 still binds an edit to one frame.
- Refused: closing on the evidence, re-timing once before failing, and a ratio against a reference
  workload.

It does not protect the timed step from another program on the same machine.

# What building it found

- The two one-frame budgets asserted op counts and the stopwatch in one helper, so each became two
  tests; the file went from 15 tests to 17, five of them timed.
- A timed test re-asserts the precondition its number depends on, because the shape tests now run in
  a different step.
- `paint_budget_test.dart` carried the tag and asserted no time, so it lost the tag.
- Only core is split: a `perf` tag anywhere else still runs in its own suite, never in none.
- Proved by breaking each half: a 0.001 ms frame failed 3 timed tests and no untimed one; an op count off by one failed 2 untimed tests and no timed one.

# Where it lives

- `packages/rackpal_core/test/scene/schematic_perf_test.dart`: the five timed tests.
- `tools/ci/run_suite.ps1`: `-Tests all|untimed|timed`.
- `tools/ci/run_local.ps1` and `azure-pipelines.yml`: the core suite untimed, then the timed step.
