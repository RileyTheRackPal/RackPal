---
type: Design Ruling
title: DR-233 · An IEC or NEMA cord is a power cord, wherever its far end lands
description: >-
  The link classifier produces powerCord at last: a link whose port ends are all power.ac_iec or
  power.ac_branch ports with a role, tested before the rack test. Hardwired AC, low-voltage DC and
  bonding keep the rack test. Amends DR-008 §11.8.1.
tags: [ruling, amendment, link-class, power-cord, pull-sheet, dr-233, dr-008]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-233
canon_section: "11.232"
status: built
---

Settled by the user on 2026-10-04, building `#908`.

# What was ruled

- **A cord is its ports**: every port end is `power.ac_iec` or `power.ac_branch` with a
  `PortPowerSpec.role`, at least one end is such a port, and the other may be a place. Tested before
  [DR-008](/decisions/dr-008-wiring-model.md)'s rack test (§12.50).
- **The other power families keep the rack test**: hardwired AC is an electrician's circuit, low-voltage
  DC is as often pulled 18/2 as a lead, bonding is cut to length. A pulled run stays on the Pull Sheet.
- **Undetermined stays undetermined** ([G4](/invariants/g4-unknowns-are-counted.md)), and a lock still
  wins and can now disagree (DR-008 §11.8.2).

# Why the ticket's shape was not taken

`#908` sketched "any `power.*` port with a role". That hides a 24 V run pulled to a keypad inside the
schedule's hidden-cords count, which is the Pull Sheet asserting a pull did not happen. The user chose the
narrower rule on trade knowledge, and see
[trade knowledge beats workflow reasoning](/practices/trade-knowledge-beats-workflow-reasoning.md).

Canon §11.232 holds the full text.
