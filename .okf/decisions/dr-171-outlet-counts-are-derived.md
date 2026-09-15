---
type: Design Ruling
title: DR-171 · Outlet counts are derived, never stored
description: >-
  Board #558 was ruled on 2026-08-03 and never reached canon, while the chip
  strip, PWR-003 and its remedy summed two authored PowerProfile integers.
  Provided is now the outlet ports, consumed is read per device from the cords
  drawn, and the stored fields are gone from the model and every file format.
tags: [ruling, power, outlets, pwr-003, g4, file-format, migration, dr-171]
timestamp: 2026-09-14T00:00:00Z
ruling_id: DR-171
canon_section: "11.170"
status: built
---

Ruled by the user on 2026-08-03 (the meaning of the counts) and on
2026-09-14 (the stored fields, the unwired case and the chip). Built as `#558`.

# A ruled board item that canon never heard of

docs/06 §3.3 has said since M0 that both counts are read-only and counted from
ports. The code read two authored integers, six of the 51 seed templates stated
them against their own ports, and the board item carried RULED for six weeks
with nothing in canon and an open question in its own text: what a rack reads
before anyone draws a cord.

# Measured before ruled

- Provided agreed with outlet ports on all 35 templates that stated it.
- Across the four starters, five racks and 27 links, no conductor landed on a
  power inlet, so a connection-only count would read `outlets 0/N` on every one.
- `LinkClass.powerCord` is never derived (`#908`), so the ruling's "the data is
  already present" was false. A power connection is a conductor on an
  inlet-role power port.

# What was ruled

- **Provided** is the template's outlet-role `power.*` ports: capacity.
- **Consumed**, per device: the cords drawn to its inlets where any are; none
  where only a PoE powered-device run is drawn; otherwise one per inlet port,
  counted from ports and said so. Per device because the user's company draws
  cords for PDU-fed gear and not for everything, so racks mix the two.
- **Unknown** only for a template that does not resolve or has no ports at all.
- **The stored fields are deleted.** `.rmpj` goes to 6, `.rmdx` and `.rmda` to
  3, and each strips both keys, re-hashing a template only where its stored hash
  attested the body as stored, so tamper evidence survives the migration.
- **The chip says the split on hover only**, not with a tilde or a dimmed figure.

# What building it found

- An empty port list would have read as a measured zero, the confident
  `outlets 0/0` G4 exists to stop; it is unknown.
- The rollups now move under the `wires` epoch, since drawing a cord changes
  them.
- The `.rmdx` v1-to-v2 step decoded its body to recompute the hash, which is
  only right while it is the last step. With v2-to-v3 behind it, every step now
  hashes its own raw output.

# Where it lives

- `packages/rackpal_core/lib/src/derived/device_outlets.dart`: the resolution.
- `packages/rackpal_core/lib/src/persistence/outlet_key_retirement.dart`: the
  strip and re-hash all three formats share.
- `derived/totals.dart`, `validation/rules_power.dart`,
  `commands/add_outlets.dart`: the three readers.

Related: [G4](/invariants/g4-unknowns-are-counted.md) ·
[CR-117](/invariants/cr-117-byte-exactness.md)
