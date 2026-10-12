---
type: Practice
title: A claim about the code is grepped before it enters a ruling
description: Two rulings were written on premises a grep would have overturned. In this corpus a plausible argument survives review on its own coherence, so any sentence saying what the code does or cannot do is checked against the file, and the file and line are cited.
tags: [practice, rulings, corpus, measurement, dr-017, dr-018, dr-019]
timestamp: 2026-10-12T00:00:00Z
status: adopted
---

Before a ruling, a cost or a scope argument says that this codebase does or does
not do something, **read the file**. Two rulings rested on premises one grep would
have overturned.

# The two cases

- **DR-018 §11.17.4** said that leaving the plan raster carrier out of v1 would
  cost a format migration, so G5 applied and it was owed in M3. It would not have:
  `looksLikeZip` already returns a typed error, `minReaderVersion` signals that a
  file is too new, and an absent key is how the format says "not present". The
  real gap was smaller and different: `Placement` had no `unknown` passthrough
  while `Port`, `SheetItem`, `EntityMeta` and the root envelope all did, so an older
  build silently dropped later placement fields on save. DR-019 corrected it, and
  canon §11.18.5 records the lesson.
- **DR-017 §11.16.6** shows the same failure from the other side: a premise that
  moved while its decision sat open (88 unformatted files became 124).

# Why it keeps happening here

This corpus reasons well enough that an argument sounds right, and sounding right is
what gets it past review. A wrong premise does not produce a bug that a test catches.
It produces a binding ruling and weeks of scope.

# The rule

A sentence of the form *"omitting X costs a migration"*, *"X is not supported"* or
*"the format cannot express Y"* gets a grep before it gets written down, and the
ruling cites the file and line so the next reader can re-check it cheaply. The same
discipline for numbers is [a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md),
and for fields, [a census beats a plausible derivation](a-census-beats-a-plausible-derivation.md).

# Citations

[1] `docs/canonical-decisions.md` §11.17.4, §11.18.5 (DR-018, DR-019), §11.16.6 (DR-017)
