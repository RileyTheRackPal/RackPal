---
type: Decision
title: DR-060 — Quick Add resolves family-first, and the two registries answer independently
description: The Quick Add DSL's alias table was empty on all 55 signal families. Aliases join the existing resolver's chain at its head, and a named connector beats a family's default.
tags: [m4-g, registries, dsl, catalog, g4, cr-058]
timestamp: 2026-08-15T00:00:00Z
status: built
---

A Quick Add token yields a **pair**, and each half is resolved by its own
registry:

```text
family    := aliases → shortTag → id tail → displayName      (may be UNKNOWN)
connector := ConnectorTypeDef.aliases → id tail              (may be UNKNOWN)
            ELSE family.defaultConnector, when the family resolved
direction := family.defaultDirection, unless the command states one
```

The family half is `resolveSignalFamilyToken` widened by one step. The connector
half is new.

# What the question was, and what the census found

CR-058 rules that bare trade names become registry aliases and that the Quick
Add DSL resolves against them, holding them on both `ConnectorTypeDef.aliases`
and `SignalFamilyDef.aliases`. It offers `hdbt` and `rj45` as proof the design
works: *"a different family on the same connector, which is the entire point of
keeping connector, family and direction orthogonal."*

Measured against the tree:

| | Finding |
|---|---|
| `ConnectorTypeDef.aliases` | **Populated**, 22 entries |
| `SignalFamilyDef.aliases` | **55 families, zero aliases**, behind a `_family()` helper that did not accept the parameter |
| canon §6.3's alias table | Lists **connector aliases only**; §6.4 lists none |

So the orthogonality claim was **unresolvable by anything in the codebase**:
both tokens were aliases on `conn.rj45` and nothing anywhere mapped either to a
family. See [a modelled field is not a reachable
one](/practices/a-modelled-field-is-not-a-reachable-one.md).

# Why the family is resolved first

The dependency already runs one way. `SignalFamilyDef` carries
`defaultConnector`, `defaultDirection` and `defaultTopology`, populated for all
55 since M0, so a family determines a connector. **A connector determines
nothing**: `conn.rj45` is worn by `net.ethernet`, `video.hdbaset`, `net.poe`,
`ctl.rs485` and more, and asking it which was meant is asking a question it does
not hold the answer to.

# Why the two halves are separate, which `c13` decided

A single first-hit chain was the first draft. A rack PDU has **C13 outlets and a
C14 inlet**, both `power.ac_iec`, because CR-058 makes inlet and outlet a
`PortPowerSpec.role` rather than families of their own. Under one chain, `c13`
resolves family-first and takes that family's `defaultConnector`, which is
`conn.iec_c14`, so **every outlet on every power strip in the catalog would be
authored with the wrong connector**, silently, on the panel drawing an
electrician builds from.

Resolving the halves separately gives `c13` → `power.ac_iec` + `conn.iec_c13`.
The general statement: **a family knows a DEFAULT connector, and a default loses
to a named one.**

# Unknown is a real answer, in a parser

`xlr` matches a connector and no family, because an XLR3 carries
`audio.line_bal`, `audio.mic`, `audio.aes3` or `ctl.dmx512` and the token does
not say which. The port is created with the family blank rather than with a
guess: [G4](/invariants/g4-unknowns-are-counted.md) arriving in a parser.

`euro2` is the counter-case and was settled by the user against the agent's
recommendation: a 2-pole euroblock is overwhelmingly low-Z in these racks, so it
resolves to `audio.speaker_lowz`. **A default is legitimate where the trade HAS
a default and never where it merely has a most-common guess.** See [trade
objections are questions](/practices/trade-knowledge-beats-workflow-reasoning.md).

# Two things this changed that nobody was looking at

* **`hdbt` left the connector table** because it never named a connector.
  **`rj45` stayed**, and the reason is measured rather than tidy:
  `portConnectorShortLabel` prints `aliases.first.toUpperCase()` in the port
  grid's CONN column, so deleting it would have turned every `RJ45` cell into a
  display name.
* **Seeding family aliases improved a shipped surface.**
  `structure_table.dart` spreads `...family.aliases` into the M3 signal picker's
  search key, which had been searching an empty list since M0.

# What it costs on disk

Nothing structural. `_encodeSignalFamilyDef` writes `aliases` unconditionally,
so `"aliases":[]` was already on all 55 families in every document; seeding
changes values and never the key set, `kSchemaVersion` does not move and
[CR-117](/invariants/cr-117-byte-exactness.md) is untouched. The four starters
are regenerated and each grew by **exactly 579 bytes**, which is the cheapest
available proof that nothing else moved.

# Citations

[1] canonical-decisions.md §11.59 (DR-060), all ten clauses
[2] `packages/rackmate_core/lib/src/structure/drop_line_planner.dart` — the
    shared resolver, whose own docstring named this ruling as the precondition
    for widening it
[3] `packages/rackmate_core/lib/src/catalog/seed_registries.dart`
[4] `packages/rackmate_core/test/catalog/signal_family_alias_test.dart`
[5] Commits `0d60b80`, `a16bc73`, `06cf577`, `3947192`
