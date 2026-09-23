---
type: Design Ruling
title: DR-192 · The Schedule shows the waste factor, per cable type
description: >-
  The project's cable waste factor was applied by nothing. The Schedule now renders the takeoff core already computed: each media type's known footage raw and with waste, with its unknown, estimated and bound counts. No row is inflated and there is no grand total with waste.
tags: [ruling, schedule, footage, waste, takeoff, dr-192, ac-024]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-192
canon_section: "11.191"
status: ruled
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

- **The existing takeoff is the one rendered**: `cableFootageOf`, which applied the factor per media
  line and was called by nothing outside its own file.
- **No length is inflated.** The factor applies to the rollup and is never written back to a run,
  so a measured 62 ft still reads 62 ft.
- **No grand total with waste**, because feet of Cat6 plus feet of RG6 is not a quantity anybody
  buys, which is `CableFootage`'s own documented reason.
- The setting's help line now names the Schedule instead of an unprinted pull sheet.

# How it was found

Writing the user guide: a setting whose help line promised a consumer, and a finished derivation with
no caller. Two halves of one feature, each waiting for the other.
