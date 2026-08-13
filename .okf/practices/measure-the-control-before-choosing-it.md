---
type: Playbook
title: Measure the control before choosing it
description: A picker was about to ship as a 55-row dropdown whose every row rendered as an ellipsised stump. The number that settled it was the column width, not the row count, and it took ten minutes in a throwaway harness to find.
tags: [practice, ui, measurement, dr-025, m3]
timestamp: 2026-08-13T00:00:00Z
status: adopted
---

`SERVICE` needed a picker (DR-025 §11.24.5). Three sibling columns already used
a `DropdownButton`, so the obvious move was a fourth. **The obvious move was
wrong, and no amount of reading the code would have said so.**

# What the measurement found

A `DropdownButton`'s menu inherits its **button's** width. `SERVICE` is 76
points. The 55 seeded family labels average 22 characters and reach 45.

A throwaway widget test, written before any of the picker existed, put a
`DropdownButton` in a 76-point box, opened it and printed the geometry:

```
PROBE menu material size = Size(116.0, 256.0)
PROBE item width = 84.0   (every row)
```

**116 points wide, every row's text clamped to 84.** So
`AUD·Speaker level, low-Z` and `AUD·Speaker, constant-voltage 70 / 100 / 25 V`
both render as `AUD·Speaker…`. That is not a picker, it is a lucky dip, and it
would have shipped looking like a reasonable implementation of a ruling.

# Why the sibling columns are not evidence

`ROUGH-IN`, `TEST`, `FIELD TERM` and `RACK TERM` all work fine with the same
widget, and that is the trap: **they work because `PULLED` and `RJ45` fit in 84
points**, which is a property of their labels rather than of the control. Three
columns doing something successfully is not evidence the fourth can, when the
thing that makes it work is the one variable that changed.

The distinction is now a core predicate,
`structureColumnChoicesAreRegistryBacked`, rather than a taste held in a widget:
an enum-backed column has a handful of short fixed labels, and a registry-backed
one has as many rows as the catalog ships, spelled as long as the catalog spells
them.

# The general shape

**A UI decision has numbers in it, and they are usually cheap to get.** Widths,
row counts, label lengths, how a widget sizes a popup. The cost of measuring was
one throwaway test file, deleted the same session. The cost of not measuring
would have been a control that passes every gate, satisfies the ruling as
written, and is unusable.

This is [two documents agreeing is not
verification](/practices/two-documents-agreeing-is-not-verification.md) pointed
at a widget: "the other columns do it this way" is two implementations agreeing,
and neither of them is the measurement.

# It also fixed the question, not just the answer

The measurement is what made the question to the user answerable. The option list
put to them carried the measured numbers rather than an assertion that 55 rows
"felt like a lot", and that is the difference between a preference and a finding.
Compare [re-read a task against
canon](/practices/re-read-a-task-against-canon.md), where the thing needing
re-reading was the question itself.

# The rule

Before choosing a control for a list, know **how many rows, how long the longest
label, and how wide the thing that will show them**. If any of the three is
unknown, measure it in a harness you throw away. A screenshot or a printed
`Size` beats a paragraph of reasoning about what the widget probably does.

# Citations

[1] [DR-025](/decisions/dr-025-signal-and-service-are-two-words.md), the ruling
    whose picker this is
[2] `packages/rackmate_core/lib/src/derived/structure_table.dart`,
    `signalFamilyCellGroups` and `structureColumnChoicesAreRegistryBacked`
[3] `packages/rackmate_ui/lib/src/structure/structure_editor_screen.dart`,
    `_FamilyPicker`
