---
type: Design Ruling
title: "DR-124 · An IR emitter output carries two conductors, and the catalogue had no way to say so"
description: >-
  An IR emitter output carries two conductors: a dual-head flasher is one plug with two heads, and 3+ needs another port or an expansion block. `seed-devices.md` had said `2` since M0 and `catalog_ports.dart`'s `p()` had no `maxConnections` parameter, so all 727 seed ports took `1` by construction and tier-1 `TOP-003` refused the second head with no escape. Found by the M5-H2 review; the AC-051 pair could not see it because its fixtures author their own ports
tags: [ruling, dr-124, canon-11-123]
timestamp: 2026-09-05T00:00:00Z
ruling_id: DR-124
canon_section: "11.123"
status: built
---

**Generated from canon §11.123 on 2026-10-12** (board `#1055`), because the bundle had no
concept for this ruling. Every line below is canon's own text or docs/10's summary; read
the canon section for the reasoning, which this page does not restate.

# How it was settled

**Found by the user on 2026-09-05, during the M5-H2 domain review**, and

# In one line (docs/10)

**An IR emitter output carries two conductors**: a dual-head flasher is one plug with two heads, and 3+ needs another port or an expansion block. `seed-devices.md` had said `2` since M0 and `catalog_ports.dart`'s `p()` had **no `maxConnections` parameter**, so all 727 seed ports took `1` by construction and tier-1 `TOP-003` refused the second head with no escape. Found by the M5-H2 review; the AC-051 pair could not see it because its fixtures author their own ports

# Its clauses, as canon heads them

| Clause | Heading |
|---|---|
| §11.123.1 | THE TRADE FACT. |
| §11.123.2 | THE DESIGN DOCUMENT WAS RIGHT AND HAD BEEN SINCE M0. |
| §11.123.3 | THE RULE IS NOT AT FAULT AND IS NOT CHANGED. |
| §11.123.4 | THE THIRD INSTANCE OF DR-119'S PATTERN, AND THE WORST OF THE |
| §11.123.5 | THE AC-051 PAIR COULD NOT HAVE FOUND IT, AND THAT IS THE |
| §11.123.6 | WHAT THIS SAYS ABOUT M5-H. |

# Citations

[1] `docs/canonical-decisions.md` §11.123
