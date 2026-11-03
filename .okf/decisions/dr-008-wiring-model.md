---
type: Design Ruling
title: DR-008 — the three wiring-model questions M2-A could not answer
description: A jumper is a link with both ends in one rack; a hand-set class outranks the classifier; atomicConnect connects what fits and warns.
tags: [ruling, wiring, m2, dr-008]
timestamp: 2026-07-28T00:00:00Z
ruling_id: DR-008
canon_section: "11.8"
status: built
amended_by: [DR-233]
---

Three unrelated questions, ruled together because they arose together during
M2-A and each blocked a specific step. Settled by the user on 2026-07-28.

# The three clauses

| Clause | Rule | Built in |
|---|---|---|
| §11.8.1 | A jumper is a `Link` with **both ends in the same rack**. Nothing else. | `4a48c6f`, `95e0c2b` |
| §11.8.2 | A user-set `linkClass` **survives** a document change that would re-classify it, and the disagreement stays visible. | `25f0240` |
| §11.8.3 | `atomicConnect` on mismatched sets **connects what fits**, leaves the remainder open, and warns. | `735b208` |

# Why §11.8.1 struck two limbs of AC-026

AC-026's prose gestured at factory-assembly media and a length test. Both are
struck:

- **The corpus's own reference jumper fails the factory limb.** `docs/02` shows
  `W002` as `"linkClass": "jumper"` with `"media": "media.cat6"`, bulk box cable.
- **Nothing could evaluate either limb.** `MediaTypeDef` has no factory-assembly
  flag, and a freshly drawn link has all three of AC-024's lengths null, so the
  length test is unevaluable at exactly the moment classification happens.
- **Same-rack is the fact the schedule wants.** A jumper is off the Pull Sheet
  because nobody pulls it through a wall, a claim about where its ends are.

# The bug this shape exists to prevent

Two field ends both resolve to a **null** rack. The obvious implementation
compares the two racks, reports `null == null`, and calls a wall-to-wall home run
a jumper, which silently deletes a real pull from the sheet an installer works
from, on exactly the long expensive runs. Hence the non-null guard in
`linkClassOf`, and the test named `TWO FIELD ENDS DO NOT MAKE A JUMPER`.

# Reading a link's class

There are three functions and only one is right for a consumer.

| Call | Returns | Use |
|---|---|---|
| `Link.linkClass` | the stored value, **inert** unless `linkClassLocked` | persistence only |
| `linkClassOf(doc, link)` | the classifier, **ignores the user's override** | internal |
| `effectiveLinkClassOf(doc, link)` | user's value when locked, classifier otherwise | **this one** |
| `linkClassDisagreementOf(doc, link)` | what the classifier would say when a person said otherwise | surfacing |

`null` means **UNDETERMINED** and must be counted and shown, never defaulted,
see [G4](/invariants/g4-unknowns-are-counted.md). Defaulting to `fieldCable`
asserts a pull nobody established; defaulting to `jumper` hides a real one.

# Storage

`linkClassLocked` is written **only when true** and absent otherwise, so no
existing document's bytes move, see
[CR-117](/invariants/cr-117-byte-exactness.md). It deliberately does *not* copy
`designatorLocked`, which is written unconditionally three lines away in the same
codec function.

# Latent risk, opens at M4

`atomicConnect` pairs by **declared order** because §11.8.3 rules the order, but
`setRole` exists because AC-030 wants a polarity inversion to be *inexpressible*.
Two template authors declaring `+`/`-` in opposite orders would express exactly
that. Every catalog set today declares `+` before `-`, so the exposure is latent
and opens when M4 lets users author templates. The plan **reports** the mismatch
and leaves the wiring alone; re-pairing by role would be code making a ruling.

# Citations

[1] canonical-decisions.md §11.8 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/derived/link_class.dart`
[3] `packages/rackmate_core/lib/src/commands/atomic_connect.dart`
[4] `packages/rackmate_core/test/derived/link_class_test.dart`
