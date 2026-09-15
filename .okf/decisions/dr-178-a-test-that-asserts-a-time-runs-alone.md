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
status: ruled
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
