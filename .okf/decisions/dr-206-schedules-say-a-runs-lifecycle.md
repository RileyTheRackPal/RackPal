---
type: Design Ruling
title: DR-206 · The schedules say what a run's lifecycle is
description: >-
  ScheduleEntry.lifecycleStatus was read by nothing, so existing, removed and future runs printed
  as new. The Pull Sheet groups rows by lifecycle; T6.11 carries a suffix on CABLE ID instead of
  docs/08's optional column, which would have promoted every retrofit job's schedule to ANSI B.
tags: [ruling, schedule, pull-sheet, termination-schedule, lifecycle, cr-064, cr-065, dr-206]
timestamp: 2026-09-30T00:00:00Z
ruling_id: DR-206
canon_section: "11.205"
status: built
amended_by: [DR-222]
---

Settled by the user on 2026-09-30, resolving `#576`.

# What was ruled

- **The Pull Sheet groups by lifecycle**: TO PULL (`new` and `designIntent`), EXISTING, TO REMOVE,
  FUTURE, each with a header and a count, empty sections not drawn. Chosen over one list with a
  column and over a pull-only list with a count of the rest.
- **T6.11 carries a suffix on `CABLE ID`**: `EX`, `RM`, `FUT`, `DI`, none for `new`, with a key in
  the sheet header when any appears. Zero width, so the sheet stays ANSI A.

# How it was priced

`#576` said a status column would be an unruled scope change. docs/08 §3.4 had already specified an
optional `LIFECYCLE` column; what it had not priced was T6.11, whose thirteen columns fill its
690 pt exactly, so the column promotes the sheet to 11×17 on every job with an existing run. The
corpus had the answer, and the cost was the part missing.

The Pull Sheet question was put as trade knowledge, not as the author's finding: which runs a crew
pulls, verifies or leaves is the user's to say.
