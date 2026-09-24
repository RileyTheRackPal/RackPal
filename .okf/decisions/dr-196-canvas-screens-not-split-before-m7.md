---
type: Design Ruling
title: DR-196 · The two canvas screens are not split before M7 (#98's verdict)
description: >-
  The refactor story closes with wire_trace.dart moved to core and three candidates declined. The two canvas State classes, about 5,000 lines each, wait for M7, whose keyboard and screen-reader work goes through both.
tags: [ruling, refactor, canvas, dr-196]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-196
canon_section: "11.195"
status: ruled
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was measured

| File | Lines | Code | Comment | The class |
|---|---|---|---|---|
| `rack_canvas_screen.dart` | 6,092 | 2,775 | 2,988 | one `State`, 5,187 lines, 123 members, largest method 173 lines of code |
| `schematic_canvas_screen.dart` | 5,784 | 2,715 | 2,806 | one `State`, 4,872 lines, 102 members |

No method is bloated; the classes are. That is a structure problem, and the fix is a structural one
(gesture families as mixins), priced at several days touching every gesture.

# What was ruled

`wire_trace.dart` moved to core, which `#98` always said was not a judgement call and which M6 needs
([package layering](/invariants/package-layering.md)). `json_codec.dart` stays as it is under
CR-117's byte gate. The two screens are **not split now**: M6 is export-side and touches neither, and
M7 goes through both, which is when a split starts paying. A Story parked on M7 carries the question.
