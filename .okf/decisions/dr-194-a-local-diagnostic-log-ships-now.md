---
type: Design Ruling
title: DR-194 · A local diagnostic log ships now, because builds are already in the wild
description: >-
  Release builds reported nothing anywhere, and the privacy-safe storage log had no sink. The local half of M8's crash reporting is pulled forward: a capped local log, fatal errors as type and frames only, a startup-failure dialog, and Help, Open diagnostics folder. M8 keeps the remote half and its exit clause.
tags: [ruling, diagnostics, crash-reporting, privacy, release, dr-194]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-194
canon_section: "11.193"
status: built
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

| Ships now, under Epic `#786` | Stays at M8 |
|---|---|
| A local log file in the data root, capped and rotated, never uploaded | The opt-in remote half |
| Storage events through the existing typed sink | CR-096's redaction policy reconciled as a whole |
| Fatal errors as **type and stack frames, never the message** | Symbol archival |
| A dialog when startup fails | §9.9's exit clause, still M8's to demonstrate |
| `Help ▸ Open diagnostics folder…` | |

# Why the message is excluded

An exception's message is where a file path lands, and a path here is often a client's name or a
site address (§12.4). The frames name the code, not the user's files. That is a floor chosen so the
slice cannot leak, not a design for the reporter M8 owes.

# How it was found

The full-tree review (`#97`) read `main.dart`'s fatal handler, which routes to a sink its own comment
calls a no-op in release, beside a header that reads as though the black window on a startup failure
were fixed. It was caught and shown to nobody. The storage log it would have used was complete,
typed so it cannot accept a `String`, and never installed.
