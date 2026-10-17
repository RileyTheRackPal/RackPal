---
type: Design Ruling
title: DR-244 · A clone may take any catalog connector as its default, and keeps its parent's direction and topology
description: >-
  DR-122 said a clone inherits its connector while its own ctl.vantage example changes it. Read rather
  than recalled, no validation rule reads a family at all: the builder copies a family's defaults into
  each new port and the rules judge the port. Direction and topology stay locked; the connector may be
  any type the registry holds.
tags: [ruling, signal-family, clone, connector, sfe, dr-244, dr-122, rj-012]
timestamp: 2026-10-07T00:00:00Z
ruling_id: DR-244
canon_section: "11.243"
status: built
---

Settled by the user on 2026-10-07 for SFE-B1 (board `#825`), found while building SFE-A.

# What was ruled

A clone inherits its parent's **domain, direction and topology, locked**. Its **default connector** starts
as the parent's and may be **any connector type the registry holds**. No connector is invented, so the
connector-editor refusal in RJ-012 and DR-122 §11.121.3 stands.

# Why the connector is safe and the other two are not

DR-122 §11.121.1 said the family's defaults *"are read by TOP-003, DIR-001, SIG-002 and CON-001"*. **None
of those reads a family.** They read the port. The builder (`archetypes.dart`, `quick_add.dart`,
`port_type_change.dart`) copies a family's defaults into a port when one is made.

- A wrong default **direction or topology** is copied into every new port and then judged confidently
  and wrongly. RJ-012's objection is real here, through the copy.
- A default **connector** is judged by CON-001 as a real catalog connector against the catalog's own
  `matesWith`. Changing it cannot make a rule wrong.

`acceptedFamilies`, which SFE-B1's ticket listed as inherited, is a port field. A family has none.

# The withdrawn recommendation

The first recommendation, *"a connector the parent already accepts"*, was accepted and then withdrawn
before anything was built, because **it had no host**: no family lists connectors. The nearest proxy, the
connectors the catalog pairs with the parent, gives Cresnet only `conn.phoenix_4` (so Vantage is
unreachable) and gives 23 of 57 families nothing at all. **An option offered for a decision has to
name data that exists**; this one named a concept the model never had, and the check that caught it
was reading the readers of `defaultConnector` before writing the ruling.

# Citations

- canon §11.243, §12.53; docs/10 DR-244 row; docs/09 §2.1's DR-122 paragraph, corrected
- [DR-243](/decisions/dr-243-a-clone-picks-one-dash-per-class.md), the dash and weight menu
