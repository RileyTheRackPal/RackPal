---
type: Design Ruling
title: DR-247 · Wireless distance is checked as advisory with its source shown, and lighting delivers a load schedule and an engraving schedule
description: >-
  The user's answers to LIGHT-0's census. DR-246's "no range check" is amended: Lutron publishes
  straight-line distance rules and Control4 designs ZigBee to a rule of thumb, so distance is an advisory
  check that names its source and grade, editable per protocol, counting other-sheet devices as unchecked.
  v1.4 lighting delivers a load schedule and a keypad engraving schedule.
tags: [ruling, wireless, zigbee, clearconnect, distance, lighting, load-schedule, engraving, vantage, dr-247, dr-246, g4]
timestamp: 2026-10-09T00:00:00Z
ruling_id: DR-247
canon_section: "11.246"
status: ruled
---

Settled by the user on 2026-10-09, answering the five questions of
`docs/research/research-domain-lighting.md` §9 (`#1041`).

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Wireless distance | User, on the recommendation | Advisory, straight line, source and grade named, editable per protocol; a device on another plan sheet is unchecked, never passed |
| Lutron's 6 ft separation | User | Left unruled; noted on Epic #1040 for the epic's start |
| Where a processor lives | Trade fact | Depends on the job: panel, rack or LV enclosure; Caseta has no panel |
| Lighting deliverables | User | A load schedule and a keypad engraving schedule, contents unruled |
| Vantage enclosures | Trade fact | One main and six secondary, 28 modules per controller |

# The trap this ruling records

**DR-246 refused a range check on a reason the domain did not support.** "Distance ignores walls" is
true of propagation and irrelevant to a manufacturer whose design rule *is* a distance. The census found
it by reading Lutron's spec; the user then supplied Control4's rule of thumb from practice. A ruling's
reason is a claim about the domain, and a census is where it gets tested.

# What a check cannot see

A plan is two-dimensional per sheet and the model holds no floor heights, so a keypad upstairs and a
ZAP downstairs have no computable distance. Those devices are counted as unchecked (G4), never passed.

# Citations

[1] `docs/canonical-decisions.md` §11.246, §12.56
[2] `docs/research/research-domain-lighting.md` §2.3, §2.4, §10
[3] [DR-246](dr-246-wireless-networks-and-centralized-lighting.md), whose §11.245.7 this amends
