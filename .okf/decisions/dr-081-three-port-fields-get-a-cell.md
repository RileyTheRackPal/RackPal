---
type: Design Ruling
title: DR-081 — Three unreachable port fields get a cell, and the rule that would read one is M5's
description: >-
  channelIndex, acceptedFamilies and carriedProtocols round-trip through the
  codec and have never had a writer. All three get a cell; none arms a rule,
  because a rule without its fixture pair is an M5 rule built outside M5.
tags: [ruling, m4, m4-j, m4-j2, port-grid, g4, dr-012, dr-063, m5, dr-081]
timestamp: 2026-08-21T00:00:00Z
ruling_id: DR-081
canon_section: "11.80"
status: ruled
---

Settled by the user on 2026-08-21 (board `#747`, `#749`), on a gap
`port_table.dart:86` recorded at M4-E in its own comment and that no task owned.
**A roadmap §8.3 amendment**: docs/06 §4.5 gains two columns and a cell shape
the grid does not have.

# The gap, in the words of the file that wrote it down

M4-E built seven column packs from the intersection of docs/06 §4.5 and the
model, and named what fell out: `channelIndex` *"belongs with port sets
(M4-J2)"*, and `carriedProtocols`/`acceptedFamilies` *"need a multi-select the
grid has no cell shape for"*.

All three are declared on `PortDef`, all three round-trip, and **not one has ever
had a writer**:
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
which is what that comment already called it.

# The cell shape is the deliverable, not the two columns

The grid has single-value cells and nothing else. A list-valued column is a shape
it has never had, and building it once, keyed and testable like every cell since
M4-F11, is the difference between a pattern the next list-valued field reuses and
a special case that gets copied badly. M4-F11 is the precedent: once the controls
left `port_grid.dart`, the mixed state came out as **one parameter**.

`channelIndex` is an integer cell on the **port-set surface** rather than in the
general grid, because it says which conductor of a `PortSetDef` a port is and is
meaningless without one.

# Authoring only, and that clause is what keeps M5 whole

**Nothing reads `acceptedFamilies` at connect time in v1.** Whether a connect
springs back is a validation rule, and validation is M5: a 28-rule catalogue
behind AC-051, which forbids any rule shipping without a known-bad fixture **and**
a known-good near-miss.

A rule armed here would be an M5 rule built outside M5's registry, without its
pair, which M5 then inherits and cannot count. Roadmap §4 names the pressure to
add *"just one more obvious rule"* as the mechanism by which that milestone
overruns, so this is a gate being defended rather than a scruple.

# DR-012 is not disturbed, and the default is the whole reason

[DR-012](/decisions/dr-012-deferred-gesture-rules.md) deferred three gesture rules
on the arithmetic that these fields are populated on **none of the 727 seed
ports**. **Both lists are non-nullable and default to `[]`**, and an empty list
reads as *this port states no constraint*, so every seed port, every starter and
every file on disk keeps exactly the behaviour it has. **A field gaining a writer
does not re-arm a rule that was never built.**

# An empty list is not null, and the distinction is load-bearing

[G4](/invariants/g4-unknowns-are-counted.md)'s absent-key convention is about
**unknowns**. *"This port constrains nothing"* is a statement, and a port whose
author said nothing is not a port whose author said *anything goes*. The model
already encodes that by making the lists non-nullable, and a multi-select must not
introduce a third state in order to be helpful. This is
[DR-063](/decisions/dr-063-a-disagreement-is-not-an-unknown.md)'s distinction one
field over: a deliberate emptiness is not an unknown either.

[CR-117](/invariants/cr-117-byte-exactness.md) holds because the codec writes no
key for an empty list, which is existing behaviour and not a new rule. The
48-template byte sweep fails first if that changes.
