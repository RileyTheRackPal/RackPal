---
type: Practice
title: A non-nullable field with a default has already answered before anybody asked
description: >-
  G4 governs nullable fields, where silence is a countable unknown. A
  non-nullable enum with a constructor default has no silence: writing nothing
  is a positive claim, made once, by whoever chose the default.
tags: [practice, g4, model, invariants, m4-i, honesty]
timestamp: 2026-08-26T00:00:00Z
status: adopted
---

[G4](/invariants/g4-unknowns-are-counted.md) is stated over nullable fields: *null is
unknown, never estimated*, an unknown serialises as an absent key, and every rollup counts
its unknowns rather than fabricating a total. That rule is load-bearing and it is complete
for the fields it covers.

**It does not cover a non-nullable field with a default**, and there is no silence in one
to protect.

# The instance

`PortDef.gender` is a `Gender` defaulting to `Gender.genderless`. The Matrix generator
shipped writing every companion field it knew and leaving `gender` alone, which reads as
restraint and is not: it asserts that an **IEC C14 appliance inlet has no gender**, while

* `conn.iec_c14`'s own registry entry declares `genderApplies: true`, and
* all thirteen C14 inlets in the seeded catalog write `Gender.male`, because a C14 carries
  the pins and the C13 on the cord carries the sockets.

Nothing failed. No validation dot fires on `genderless`, because it is a legal value; the
codec round-trips it; the grid renders it. A field that is wrong and valid has no
mechanism to announce itself.

It was found by censusing the seed **before writing the next generator**, one task later,
which is the only reason it was found at all.

# The check

For every field a producer leaves alone, ask which of three states it lands in:

| Shape | Leaving it alone means |
|---|---|
| `T?` with no default | unknown, counted, G4's case |
| `T` with a default that means "unset" (`''`, `0` where zero is not measured) | usually unknown, and worth a comment saying so |
| **`T` with a default that is a real value** | **a claim** |

The third is the one to hunt. An enum is the commonest carrier because a default has to be
*some* member, and the member chosen usually reads as neutral (`genderless`, `none`,
`unspecified`) while behaving as an assertion.

# What it does not license

Filling one in because it is probably right. The C14 qualifies because its answer is
**definitional and already written thirteen times in the seed**: it was read off the
corpus, not reasoned to. A generator that guessed would be doing the thing
[G4](/invariants/g4-unknowns-are-counted.md) exists to forbid, one field over.

The parser path was left alone for exactly that reason. `1 c14 in` through Quick Add still
writes a genderless C14, because closing it needs a per-connector table of definitional
genders that no registry field carries, and inventing one inside a generator task would be
a model change nobody ruled.

# Citations

[1] `packages/rackpal_core/lib/src/builder/archetypes.dart`: `_acInlet`
[2] [DR-092](/decisions/dr-092-the-archetype-emits-the-port-4-3-could-not.md)
[3] [a modelled field is not a reachable one](a-modelled-field-is-not-a-reachable-one.md), the sibling shape one layer up
[4] [census the field, not the name](census-before-building.md)
