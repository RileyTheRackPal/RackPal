---
type: Design Ruling
title: DR-009 — macOS ships in v1
description: Closes open question §10.10 the other way from its own recommendation, and creates the debt register that §10.10 asked for and never got.
tags: [ruling, platform, macos, dr-009]
timestamp: 2026-07-28T00:00:00Z
ruling_id: DR-009
canon_section: "11.9"
status: scheduled
---

Settled by the user on 2026-07-28. Recorded as an amendment with its own ID
because **§8.3 requires one**: moving anything between v1/v1.1/v1.2/v2 is an
amendment, not a doc edit.

# What it overturns

§10.10 offered (a) Windows only for v1, or (b) Windows and macOS from v1. It
recommended (a) — explicitly *"not a ruling"* — on the strength of a desk survey
it never ran. **Option (b) is taken.**

# The condition §10.10 attached was never kept

Its recommendation carried a discipline: *"nothing in M0–M6 may take a
Windows-only dependency without it being written down as a macOS debt item."*
That sentence appears in **three** documents. **No register was ever created**, so
not one item was ever recorded. `docs/13-macos-debt-register.md` is that register,
compiled by inspection rather than from the estimate.

# The debt is smaller than §10.10 assumed

The seams macOS needs were already built, for other reasons:

| Already paid | Evidence |
|---|---|
| `Platform.isWindows` appears **nowhere** in Dart | one grep hit, a comment explaining the avoidance |
| The platform split is an **injected flag** | `main.dart` → `app_services.dart` → `atomic_writer.dart`, whose comment already reasons about macOS errno tables and 259-vs-4096 path limits |
| `FilePicker` is an `abstract interface class` | the Win32 dialog is one implementation; macOS is a second, not a refactor |
| The metrics font is **bundled** | §10.10's "font availability" cost does not apply to this tree at all |
| `path_provider_windows` has **one** grep-enforced call site | a one-function change |

# What has lead time, and is not code

- **D8** — Apple Developer enrolment, notarisation and stapling. D10's macOS half
  was always binding; it simply had no milestone to attach to.
- **D11** — a second physical print matrix for AC-054. A human act on a real printer.

Start both early *because* they are not code.

# Only D7 is pulled into M2

The keyboard-modifier extraction is the **only register item that gets more
expensive with every commit** — 22 hard-coded `SingleActivator` bindings today
against §10.10's ~40 estimate, and M2-F adds the connection keyboard path. It
also discharges M7's *"no keybinding bound twice in the generated table"* clause
(nothing generates a table) and CR-101's 16 unfixed collisions.

# Genuinely unknown

Whether [CR-117's byte-exactness gate](/invariants/cr-117-byte-exactness.md)
survives a platform change. A platform-dependent float or font metric surfaces
there first. It is the only item that could turn a bounded port into a design
question, and it is cheap to measure once a macOS CI job exists.

# Citations

[1] canonical-decisions.md §11.9 (`docs/canonical-decisions.md`)
[2] docs/13-macos-debt-register.md (`docs/13-macos-debt-register.md`)
[3] Commit `a9c093a`
