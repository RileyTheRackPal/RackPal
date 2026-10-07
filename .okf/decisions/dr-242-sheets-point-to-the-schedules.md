---
type: Design Ruling
title: DR-242 · The sheets say where the cable and port detail is, instead of saying it is not issued
description: >-
  Two notes printed in every export said the set did not carry the cable schedules or the port detail,
  beside the Pull Sheet and Termination Schedule that M6-K made ON in every set. Both now point to those
  sheets. Found by reading every page of every starter for M6's complete-set clause.
tags: [ruling, sheets, notes, equipment-list, rear-elevation, m6, dr-242, dr-222]
timestamp: 2026-10-07T00:00:00Z
ruling_id: DR-242
canon_section: "11.241"
status: ruled
---

Settled by the user on 2026-10-07 for `#1030`, found while demonstrating M6's first exit clause
(`#46`, all four starters export a complete sheet set).

# What was ruled

| Sheet | Printed until now | Now |
|---|---|---|
| `T6.30`, every page | EQUIPMENT AND RACK MATERIALS. CABLE AND POWER SCHEDULES NOT ISSUED IN THIS SET. | EQUIPMENT AND RACK MATERIALS. CABLE SCHEDULES: SEE T6.10 AND T6.15. POWER SCHEDULE NOT ISSUED IN THIS SET. |
| `T2.02` | REAR FACES SHOWN. PORT AND CONNECTION DETAIL NOT ISSUED IN THIS SET. | REAR FACES SHOWN. PORT AND CONNECTION DETAIL: SEE T6.15. |

Narrowing each note to its true half was offered beside it. A pointer was chosen because a note
whose only content is an absence leaves the reader holding a hole, the objection
`rack_load_gutter.dart`'s own `SEE T6.30` cross-reference already makes.

# Why it happened

Both sentences were **true when written**, at M1, before any cable schedule existed, and no ruling
fixed either wording. They went false the day M6-K (`#977`) made `T6.10` and `T6.15` ON, and
`starters_export_test.dart` asserted the false `T6.30` sentence on all four starters. A test that pins
copy outlives the fact the copy described; see
[assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).

# What it leaves open

Presets do not exist yet (docs/08 §2.4). A preset that drops `T6.10` or `T6.15` makes the pointer
false, so **whoever builds presets owes this note a condition**. The rear elevation still draws no
ports; CR-071 keeps the interactive rear panel at v1.1.

# Citations

- canon §11.241; docs/10 DR-242 row
- docs/08 §2.2 (the sheet table: `T6.10`, `T6.15` ON; `T6.40` v1.1)
