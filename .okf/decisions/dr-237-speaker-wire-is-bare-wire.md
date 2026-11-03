---
type: Design Ruling
title: DR-237 · Speaker wire is bare wire
description: >-
  A binding post or a 2-pole Euroblock mates with every bare-wire termination, so CON-001 stops springing
  back on every amplifier-to-speaker run. Screw terminals and pigtails list them back: mating is symmetric.
tags: [ruling, connector, con-001, speaker, binding-post, catalogue, dr-237]
timestamp: 2026-10-06T00:00:00Z
ruling_id: DR-237
canon_section: "11.236"
status: built
---

Settled by the user on 2026-10-06 for `#1010`, on a trade fact: bare wire is typical for most speakers, on
spring terminals, and combination banana posts appear mostly on floorstanding and bookshelf speakers.

# What was ruled

- **Binding posts and 2-pole Euroblocks** mate with banana (posts only) and every bare-wire termination.
- **Screw terminals and pigtails list them back**, since mating is symmetric. A first default that they
  stay unknown was refused by `connector_mating_test` and corrected in canon before it was built.
- **The Euroblock is the implementer's reading**, included because the census found the same false
  positive on the commercial amplifiers; recorded as such.

See [trade knowledge beats workflow reasoning](/practices/trade-knowledge-beats-workflow-reasoning.md).

Canon §11.236 holds the full text.

Built at `d9f4efd6`; docs/12 §4.48 holds the evidence.

# What this does not rule

- **Refreshing saved projects' registries.** A document embeds its registries (DR-010), so a project
  saved before the fix keeps the old list, as with every earlier catalogue correction.
