---
type: Design Ruling
title: DR-254 · The Microsoft Store alpha is parked on M8, anonymity is a distribution constraint, and the route is ruled after it is verified
description: >-
  From #482. The Store path runs through an identity-verified Partner Center account. The user's
  direction (WinGet, a Homebrew cask, GitHub keyless attestations, staying anonymous) is recorded and
  not ruled, because they said it may change and several facts cut against it. Only the parking moves.
tags: [ruling, distribution, msix, store, winget, homebrew, sigstore, anonymity, m8, dr-254, dr-006, dr-179, dr-095]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-254
canon_section: "11.253"
status: ruled
---

Settled by the user on 2026-10-17, answering board `#482`.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| The Store alpha | User, on the recommendation | Epic `#100` parked on M8 (DR-095's sense); `#482` not pursued |
| File-type registration | Follows from the parking | `#171` moves to M8 with the installer it belongs to; DR-179's pre-M8 deadline lapses |
| Anonymity | User, in their words | A distribution constraint *"at least initially"* |
| The route | Not ruled | WinGet, a Homebrew cask and artifact attestations are the intended direction; `DIST-0` (`#1105`) verifies before M8 rules |

Not taken: ruling the new route now; keeping the Store path.

# Record what was decided, not what was mentioned

The user named a direction and said in the same breath that it may not be the one taken. Writing it
down as a ruling would have turned a hope into a spec, and the facts gathered for the question cut
against parts of it: Homebrew stopped supporting casks that fail Gatekeeper on 2026-09-01, and keyless
attestations prove provenance without satisfying SmartScreen or Gatekeeper. So the ruling moves only
what the user actually decided, the Store, and names the facts that have to be verified before the
rest is ruled.

# Related

* [DR-006](dr-006-self-signed-distribution.md), which stands until M8 rules the route.
* [DR-179](dr-179-the-rp-extensions.md), whose file-type deadline lapses with the Store alpha.
* [DR-095](dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md), the meaning of parked.
