---
type: Design Ruling
title: DR-088 — State management is constructor injection and hand-rolled Listenables
description: >-
  ADR-011 accepted Riverpod and nobody ever built it. Five milestones later the
  package is in no pubspec, so the ruling ratifies what exists and gates the
  dependency table that let a document describe a layer that was never written.
tags: [ruling, architecture, state-management, adr-011, cr-119, ac-016, dr-026, dr-088, gate]
timestamp: 2026-08-25T00:00:00Z
ruling_id: DR-088
canon_section: "11.87"
status: built
---

Settled by the user on 2026-08-25 (board `#764`), in answer to the plain question
*"what state management are we using and why"*. **A ratification, not a change of
direction**: no line of shipped code moves, nothing enters or leaves roadmap §2,
and it is a ruling only because it supersedes **ADR-011** and four Part 1–3 sites
that describe a layer nobody built.

# It was never rejected, it was never reached

ADR-011 accepted **Riverpod 3.x** and `docs/03` §4 spent a numbered section on the
provider layer. At **v0.4.63**, five milestones later:

| | |
|---|---|
| `riverpod` in any Dart file, pubspec or lockfile | **0** |
| `ProviderScope` in any Dart file | **0** |
| tracked files mentioning it at all | **7, every one of them prose** |

Three of the seven are under `docs/research/`, which is working papers the plan
documents supersede, so the correction sweep stopped at four files.

**The `VERIFY:` marker is the transferable finding.** ADR-011 carried
`VERIFY: Riverpod 3 API surface BEFORE THE PROVIDER LAYER IS WRITTEN`. That
condition is still perfectly true, because the layer was never written. **A
precondition attached to work that does not happen never fires.** This is why the
remedy is a gate over a claim rather than a better-worded marker, and it
generalises past this ruling: any `VERIFY:` in this corpus conditioned on future
work is inert until that work starts.

# What is actually built

| Layer | Mechanism |
|---|---|
| core (zero Flutter, gated) | `SimpleNotifier<T>`, a 34-line pure-Dart `ValueNotifier`; `DocEpochs` holds **seven** |
| core, mutation | `DocumentController.run` / `.transact`, the single gate |
| app, re-broadcast | `DocumentSession extends ChangeNotifier` |
| ui, ephemeral | nine `ChangeNotifier` controllers, consumed by painters as plain `Listenable`s |
| DI | **constructor injection of one `AppServices`**; no `InheritedWidget` exists anywhere |

Each of Riverpod's four claimed benefits turned out to be supplied already:
scoped lifetime by CR-119 making the count one (a scope of one is a variable) plus
the `GlobalKey<AppShellState>` minted in `main`; DI by a single constructor
parameter a test can just construct; **cheap chrome read-models by `DocEpochs`
holding seven counters instead of one revision number**, which is `select()`
performed in the model rather than the view; and ecosystem stability, which was
only ever an argument about *which* dependency, never that one was needed.

**Ratified rather than merely observed**, because the built shape is the
reversible direction. That is
[DR-026](dr-026-two-interim-m3-answers.md)'s test applied to architecture: adding
a container to a tree that passes one object down is mechanical, and removing one
several hundred widgets read from is not.

# The second finding, which is the one that produced a gate

`docs/03` §10.1 is titled **"The full table"** and had never been full:

* **eight** packages named there and installed nowhere (`flutter_riverpod`,
  `printing`, `desktop_drop`, `logging`, `intl`, `flutter_localizations`,
  `integration_test`, `benchmark_harness`);
* **two** installed and named nowhere: `screen_retriever ^0.2.0` and
  `fake_async ^1.3.3`.

**`screen_retriever` settles the argument.** Its twenty-line pubspec
justification *cites "§10.1's `window_manager` row"* by name. Somebody read a row
out of the table, added a package on the strength of it, and did not add the row.
Care was not the missing ingredient: **nothing could fail**, because a dependency
table is prose no gate reads. That is the identical mechanism the M5 decomposition
audit found on the board the same week, one document over.

So the table gains a **Status** column and a
[two-direction gate](/gates/dependency-table-parity.md). Four rows carry
`planned (unscheduled)` because `docs/09` names no milestone for them anywhere,
and a plausible invented one would have been the confident wrong value
[G4](/invariants/g4-unknowns-are-counted.md) exists to refuse.

**An exemption list was put and declined**, being both the cheapest shape and a
repeat of a failure already written down here:
[a test's exemption list is where the bug lives](/practices/a-tests-exemption-list-is-where-the-bug-lives.md).

# What it does not rule

Only `flutter_riverpod` is ruled **rejected**. The other seven absent rows are
**recorded rather than adjudicated**: each is a separate decision with its own
evidence, several owned by M6 and M7, and bundling them into one ruling made from
inside an M5 window is how a ruling becomes unciteable.

It does not settle tabs (v1.2) or multi-window, and does not weaken **CR-119**:
when tabs are designed the per-document scope question reopens on its own
evidence. It does not touch ADR-011's surviving clauses, which are most of it:
`DocumentController` as the single mutation gate, `@internal` setters (AC-013),
the three-tier epoch-driven derived pipeline, `lodLevel` in every scene-builder
signature, and the rejection of `ChangeNotifier`-on-the-document.
