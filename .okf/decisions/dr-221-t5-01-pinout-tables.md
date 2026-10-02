---
type: Design Ruling
title: DR-221 · T5.01 prints pinout tables; a receiver jack is ring +12 V; a port records its terminal order
description: >-
  T5.01 is pinout tables triggered by non-mono IR variants, wiring-standard exceptions, null-modem
  cables and non-standard terminal orders; the receiver pinout is corrected; PortDef gains terminal roles.
tags: [ruling, pinout, t5-01, auto-sheet, ir, euroblock, m6-e, dr-221]
timestamp: 2026-10-02T00:00:00Z
ruling_id: DR-221
canon_section: "11.220"
status: ruled
---

Settled by the user on 2026-10-02, building M6-E2 (`#333`, `#974` to `#976`).

# What was ruled

- **Pinout tables only**, one section per kind. Plate drawings to scale were not taken.
- **Mono tip-sleeve is the IR standard**: an IR port on a placed device with any other variant
  (`xantech-stereo`) turns the sheet on. Only Home Theatre's six receiver jacks fire today.
- **A receiver jack is tip IR, ring +12 V, sleeve GND.** The registry, canon, docs/01,
  seed-devices.md and three code comments had ring and sleeve reversed; all corrected. The damage
  mechanism (a TS plug bridging ring to sleeve) is unchanged.
- **Null-modem stays in the trigger**; nothing can set it yet, filed as `#973`.
- **The euroblock role map is modelled now**, over the recommended v1.1 park: an ordered
  terminal-role list on `PortDef`, absent when unknown, typed in a `TERMINALS` column. Standards
  are declared for `ctl.cresnet` (`24 Y Z G`) and `ctl.rs232` (`TX RX G`) only; audio was judged
  too variable by manufacturer.

# Why

A pin map is the one place a person with a screwdriver reads the order, so it was put to the user
rather than printed from a code comment. A trigger with no data behind it (the role map) had to be
built, parked or dropped; the user chose built.

# Related

* [DR-220](dr-220-t6-20-unused-home-runs.md) - T6.20, the other AUTO sheet of M6-E.
* [DR-126](dr-126-the-catalogue-was-calling-two-signals-by-one-name.md) - the IR families and the mechanism.
