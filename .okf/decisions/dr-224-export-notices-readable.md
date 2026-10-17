---
type: Design Ruling
title: DR-224 · An export's notices are read by clicking their count
description: >-
  Export notices were counted on the status line and never shown; the count becomes a link opening a
  dialog that lists them by sheet id, with Copy.
tags: [ruling, export, notices, status-line, m6-m, dr-224]
timestamp: 2026-10-03T00:00:00Z
ruling_id: DR-224
canon_section: "11.223"
status: built
---

Settled by the user on 2026-10-03, opening M6-M (`#983`), on the recommended option.

# What was ruled

- **The notice count on the status line is a link** to an `Export notices` dialog: every notice from
  that export, grouped by sheet id, with Copy and Close. Keyboard-reachable.
- **Notices travel with their status message**; a later message replaces both.
- Not printed on `T0.02`: a client deliverable should not carry the export's housekeeping.

# Why

Every notice the exporter had ever written reached the user as a number. CR-023 made them notices so
they would never gate the bytes, and nothing made them readable.

# Related

* [DR-223](dr-223-strip-repeats-and-pathway-designators.md) - the notice that exposed the gap.
