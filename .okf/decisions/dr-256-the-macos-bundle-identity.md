---
type: Design Ruling
title: DR-256 · The macOS app is com.rackpal.rackpal, named RackPal.app, unsandboxed with the hardened runtime
description: >-
  From D1 (#453, #454). Flutter's macOS template defaults to com.example, App Sandbox on, and a
  lowercase bundle. The user chose the identifier Windows already implies, no sandbox with the
  hardened runtime, and the Mac-conventional RackPal.app, each on the recommendation.
tags: [ruling, macos, bundle-identifier, sandbox, hardened-runtime, anonymity, d1, dr-256, dr-009, dr-254]
timestamp: 2026-10-18T00:00:00Z
ruling_id: DR-256
canon_section: "11.255"
status: ruled
---

Settled by the user on 2026-10-18, opening D1 of `docs/13-macos-debt-register.md` under
[DR-009](dr-009-macos-in-v1.md).

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Bundle identifier | User, on the recommendation | `com.rackpal.rackpal`, matching Windows' `Runner.rc` (`com.rackpal`); names no person ([DR-254](dr-254-the-store-is-parked-anonymity-is-a-constraint.md)) |
| Sandbox | User, on the recommendation | Off, with the hardened runtime notarisation needs; files by plain path, recents survive relaunch |
| Bundle name | User, on the recommendation | `RackPal.app`, so the menu bar reads "RackPal" |

Not taken: `com.rackpal.app` or a personal domain; the App Sandbox (security-scoped bookmarks, a
container, a library-validation exception); `rackpal.app`.

# An identifier is effectively permanent

macOS keys a bundle's preferences, privacy permissions and sandbox container on its identifier, so the
template's `com.example` is not a placeholder that can be fixed at release: changing it later orphans
whatever early users accumulated. The copyright line carries the same org (`Copyright © 2026 com.rackpal`),
which is why the anonymity constraint reaches it too.

# Related

* [DR-255](dr-255-macos-ci-is-an-optional-pr-check.md), the macOS job that builds the bundle.
* [DR-254](dr-254-the-store-is-parked-anonymity-is-a-constraint.md), the anonymity constraint and the route that needs no App Store.
