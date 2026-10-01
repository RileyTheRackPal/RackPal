---
type: Design Ruling
title: DR-214 · T0.02 leads with the project-wide exceptions, then errors first, and keeps every signed reason
description: >-
  T0.02 prints rule overrides and project-wide mutes first, open findings banded by severity, then
  acknowledged findings in their own section, including those whose finding no longer occurs.
tags: [ruling, t0-02, exceptions, validation, m6-c, dr-214]
timestamp: 2026-10-01T00:00:00Z
ruling_id: DR-214
canon_section: "11.213"
status: ruled
---

Settled by the user on 2026-10-01, building M6-C (`#322`), on the recommended option four times.

# What was ruled

- **Project-wide exceptions first**: rule overrides and `"*"` mutes, with reason, author, date.
- **Open findings banded by severity, errors first**, with severity, rule, locus and message.
- **Acknowledged findings in their own section**, adding reason, author and date.
- **An acknowledgement whose finding no longer occurs still prints**, marked `NO LONGER OCCURS`.
- Decided without a question: continuation on `T0.03` and on; an empty sheet says the checks ran
  and when; every join goes through `acknowledgementFor` (DR-111).

# Why

A silenced rule should be met before the list it no longer contributes to. Errors first puts the
blockers where the person signing off reads first. A signed reason that silently left the
deliverable cannot be told from one deleted to hide it.
