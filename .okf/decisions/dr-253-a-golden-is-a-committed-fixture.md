---
type: Design Ruling
title: DR-253 · "Goldens pass" means the byte and text goldens, a committed fixture compared exactly
description: >-
  From #1102. Roadmap section 4's green rule never defined a golden, so with no pixel goldens in the
  tree the limb read as vacuous for every milestone. A golden is a committed fixture compared exactly;
  the limb is checkable and met by the four byte and text goldens that exist.
tags: [ruling, goldens, testing, roadmap, green-rule, dr-253, dr-095]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-253
canon_section: "11.252"
status: built
---

Settled by the user on 2026-10-17 for `#1102`. It defines a word; the goldens it counts already
exist, which is why its status is `built` on the day it was ruled.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| What a golden is | User, on the recommendation | A committed fixture compared exactly: exported bytes, display-list text, generated reference text |

Not taken: pixel or display-list goldens per docs/11 §2's budget; dropping the limb.

# A rule nobody can fail is not a rule

With the word undefined and no pixel golden in the tree, *"goldens pass"* was read as vacuous for every
milestone: it could not be satisfied and it could not be failed, so it gated nothing. Four tests were
already doing the job the word describes (`byte_roundtrip_test`, the schematic fixture and its perf
test, `keymap_reference_golden_test`), each regenerated deliberately with `UPDATE_GOLDENS=1`. The ruling
counts them. A definition that makes an existing check count is cheaper than a harness that has to be
built before the rule means anything.
