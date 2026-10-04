---
type: Design Ruling
title: DR-231 · A cable's crossover is set on the schematic and in the table, and polarity reversed joins it
description: >-
  Link.crossover gets a schematic cable bar and a Structured Wiring CROSSOVER column; every choice on
  every cable; CrossoverKind gains polarityReversed, noted on the schedule and listed on T5.01.
tags: [ruling, amendment, cable, crossover, null-modem, t5-01, dr-231, dr-221]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-231
canon_section: "11.230"
status: ruled
---

Settled by the user on 2026-10-04, closing `#973`. A §8.3 amendment: the model gains a value.

# What was ruled

- **Two hosts**: a cable bar on the schematic (the first per-cable control there) and a CROSSOVER column
  in the Structured Wiring table. The table alone lists only home runs, so it could never reach a
  serial cable inside the rack.
- **Every choice on every cable**, against the recommendation to filter by family, on the user's trade
  reason: cables are deliberately crossed on more families than assumed, a sub wired out of phase
  being the example.
- **`polarityReversed` is added**: a speaker pair wired + to − is neither null-modem nor fibre A→B. The
  schedule notes it and T5.01 lists it under a note that the swap is deliberate.

# Not taken

- The table alone; the schematic alone; family-filtered choices; recording out-of-phase in notes.

Canon §11.230 holds the full text.
