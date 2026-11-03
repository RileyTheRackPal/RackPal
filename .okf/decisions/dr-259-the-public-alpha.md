---
type: Design Ruling
title: DR-259 · RackPal goes public as an alpha, source under plain AGPL, issues only, and a Windows preview
description: >-
  From REL-0 (#1288). Four things a pre-release audit found only a ruling could settle: DR-189 forbade
  a public push before counsel review, 73 vendor files sat in history, the identity gate and the DCO
  collide, and DR-254 parks distribution. Each answered on the recommendation.
tags: [ruling, release, licence, agpl, anonymity, history-rewrite, contributions, preview, rel-0, dr-259, dr-189, dr-036, dr-254, dr-258]
timestamp: 2026-11-03T00:00:00Z
ruling_id: DR-259
canon_section: "11.258"
status: ruled
---

Settled by the user on 2026-11-03, from `#1288`. It amends
[DR-189](dr-189-agplv3-and-the-cc0-vendor-door.md) on timing, defers a clause of
[DR-036](dr-036-public-gplv3-cc0-catalog.md), and leaves
[DR-254](dr-254-the-store-is-parked-anonymity-is-a-constraint.md) standing (canon §12.62).

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Licence | User, on the recommendation | Public now under plain `AGPL-3.0-or-later`; the exception's counsel review moves to before v1.0, and the draft moves to `docs/proposed-output-exception.md`, marked not in force |
| Vendor files | User, on the recommendation | Removed from every commit by a second history rewrite, before GitHub was ever public; GitHub gets a newly created repository |
| Contributions | User, on the recommendation | Issues only, no pull requests; DR-036's DCO waits, and [DR-258](dr-258-the-identity-gate.md) is unchanged |
| Binaries | User, on the recommendation | A self-signed Windows portable zip as a pre-release, which is not DR-254's distribution route; no macOS build |

# The audit that found them

Five agents read the README and user guide against the code, the derived corpus against the scripts,
the OKF, the repository's public readiness, and every markdown link. Alongside: every object reachable
from `main` scanned for secrets (none, and the live service token's value nowhere), the metadata of
every committed image and PDF (no location or camera data; one set's EXIF named a copyright holder,
which is how the vendor files were found to be someone else's), and the full local gate with the
release build (green).

# Why a newly created GitHub repository

A force-push leaves the replaced commits retrievable by hash on the host until it collects them, so
the photographs would have stayed one URL away. A repository that has never held them cannot serve
them.

# Related

* [DR-257](dr-257-one-pseudonymous-identity.md), the tooling the second rewrite reused.
* [DR-007](dr-007-keystone-geometry-in-m3.md), whose reference material the vendor files were.
