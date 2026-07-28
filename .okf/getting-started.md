---
type: Orientation
title: How RackMate makes decisions
description: The ruling to spec to implementation to test chain that structures this codebase, and how to use it.
tags: [orientation, process]
timestamp: 2026-07-28T00:00:00Z
---

RackMate is unusual in one way that matters more than its domain: **every
non-obvious decision is a numbered ruling**, and each ruling traces to a spec
section, an implementing file, and a test that proves it.

That chain is what this bundle indexes.

# The identifier families

| Prefix | Meaning | Lives in |
|---|---|---|
| `DR-nnn` | Design Ruling — settles a question the corpus could not answer. Requires a user decision. | `docs/canonical-decisions.md` §11 |
| `CR-nnn` | Corpus Ruling — reconciles two sources that disagree. | `docs/canonical-decisions.md` |
| `AC-nnn` | Acceptance Criterion. | the roadmap and specs |
| `G-n` | A global principle, e.g. [G4](/invariants/g4-unknowns-are-counted.md). | throughout |
| `RJ-nnn` | Rejected critique — kept so the argument is not re-run. | `docs/canonical-decisions.md` §3 |

# The rule that generates the rest

**Moving scope between v1 / v1.1 / v1.2 / v2 is an amendment, not a doc edit
(§8.3).** It needs a new ruling ID. That is why
[DR-009](/decisions/dr-009-macos-in-v1.md) and
[DR-010](/decisions/dr-010-seeded-registries.md) exist rather than someone quietly
editing a sentence.

The corollary is the useful part: **if you are about to change what a document
asserts, you are probably making a ruling.** Stop and record it.

# Reading a contradiction

The corpus contains real disagreements — sources written at different times
against a model that did not yet exist. The convention is to **flag them in code,
in place**, never resolve them silently:

- `seed_registries.dart`'s header records six such disagreements
- `schedule.dart` records four fields `docs/08` §3 names that the model lacks

A comment saying "these two sources disagree, I took this one, because" is worth
more than a clean-looking file that picked one at random.

# Where evidence lives

`docs/12-milestone-board.md` is an **audit**, not a plan. Its value is the
per-clause record: who performed a check, when, under what conditions, and what
remains unproven. It is deliberately not duplicated — not into this bundle, not
into the tracker. One authority, linked from everywhere else.

# Start with

* [DR-008](/decisions/dr-008-wiring-model.md) - the wiring model, and the class-reading rule every consumer needs.
* [CR-117](/invariants/cr-117-byte-exactness.md) - the byte property that has decided four separate design questions.
* [G4](/invariants/g4-unknowns-are-counted.md) - unknowns are counted, never guessed.
* [Package layering](/invariants/package-layering.md) - what may import what, and why it keeps deciding things.
