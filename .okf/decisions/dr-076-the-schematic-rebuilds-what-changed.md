---
type: Decision
title: DR-076 — The schematic rebuilds what changed, and the epochs already say what that is
description: The prescribed remedy was the smaller half; the invalidation model was already in the tree, unread, in every command's touches mask.
tags: [m6, perf, schematic, epochs, determinism, ac-008, dr-011]
timestamp: 2026-08-19T00:00:00Z
status: built
---

The schematic rebuilt the whole document on every edit while its tab was open.
`#702` said a ruling was owed first, because *"which epochs invalidate which
fragments"* is a question DR-011.4 only half answers.

# The prescribed remedy was the smaller half

AC-008 rules that L3a splits into eight per-domain sub-pictures so *"an edit to
one HDMI run rebuilds ~1,200 ops and seven pictures replay untouched"*.

Measured on the 12-pod fixture, 3,600 links, best of five:

| | time |
|---|---|
| cold build | ~96 ms |
| `holdAt`: what a wire edit did before this | ~90 ms |
| `reuseLayout` | ~46 ms |
| `reuseSymbols` | ~20 ms |

**Symbols alone, with zero links, are ~75 ms and 49,860 of the 78,660 ops**, and
they are domain-independent. A perfect eight-way split cannot touch them. AC-008
is retained and **resequenced**, not withdrawn: it is measured after the tiers,
because if the wire tier is already inside a frame then eight sub-pictures buy
nothing and add a second invalidation axis to reason about.

# The model was already in the tree

`DocEpochs` has carried six independent notifiers since M0 (`structure`,
`wires`, `rack`, `meta`, `style`, `sheet`), and its own doc says they exist so
`rackmate_ui` *"can subscribe to exactly the epochs one widget cares about
instead of rebuilding on every commit"*. Every command declares a `touches`
mask. **The schematic collapsed all six into one counter.** The matrix the issue
asked for was mostly written already, per command, and unread.

Three tiers, each keyed on what can move it:

* **layout**: `structure`
* **symbols**: `structure`, `meta`
* **wires and labels**: `wires`

A rename rebuilds symbols and keeps the layout: a designator changes what a
symbol prints, not where anything sits, and re-running layout would move symbols
under the cursor of somebody who just renamed one.

# The budget binds the edit, not the open

A cold build of a twelve-pod job happens once, behind a file load the person is
already waiting through. So the incremental path asserts one frame and the cold
build keeps a ratchet ceiling. **On the 300-link fixture a wires-only rebuild is
0.913 ms against 16.7 ms.** At twelve pods an edit is ~20 ms, still over a
frame, and that case asserts an ORDERING rather than a figure: asserting the
budget there would make a red gate out of work the ruling sequenced later.

This is a narrowing of what the budget was assumed to cover, stated rather than
assumed, because meeting one frame on a cold build means attacking Sugiyama and
the symbol layer inside the determinism guarantees `sugiyama.dart` defends. **No
user has reported open time.**

# What the measuring found that reviewing would not

* **The headline figure is not the common case.** Seven commands declare `wires`
  alone; eight declare `wires | meta`, including every connect, bind and move,
  because materialising a port mints a designator. **Drawing a cable takes the
  ~46 ms path, not the ~20 ms one.** Splitting `meta` finer is a new epoch
  channel and a new ruling.
* **Two figures in the ruling's own first draft were wrong**, and both were mine:
  single runs where the repo measures best-of-N (144 ms for what is 87 ms), and
  a claim that a full rebuild reshuffles the sheet *today* when `holdAt` already
  prevents it. See
  [print the output before claiming copy is done](/practices/print-the-output-before-claiming-copy-is-done.md),
  which is the same failure one register over: asserting a thing rather than
  running it.
* **A test verified by mutation changed what it claims.** With the reuse
  removed, a rename to `MTX-9` moves nothing, and neither does
  `MATRIX-SWITCHER-MAIN-RACK-1`; only a ~180-character designator makes a full
  rebuild demonstrably move the sheet. At realistic names both paths agree, so
  the rename tier is justified by cost rather than by observed churn, and the
  test records that, because the absurd length is the first thing a later reader
  would tidy away.

# The gate is equality, not timing

An incremental rebuild must produce the byte-identical scene a whole rebuild
would, for the same document. A cache that is faster and different does not
announce itself: it ships as a golden diff nobody can read, on a drawing an
installer builds from. CR-012 and `sugiyama.dart`'s determinism rules survive
unchanged.

One staleness is carried and written down rather than hidden: a held layout's
`reversedEdgeIds` and `nonForwardEdgeIds` describe the edges that existed when
it ran, so a link added under a reused tier is in neither. Censused (nothing in
`lib/` reads them, the only callers are two tests), so it costs no drawing
today, and the first consumer to appear would otherwise inherit it silently.
