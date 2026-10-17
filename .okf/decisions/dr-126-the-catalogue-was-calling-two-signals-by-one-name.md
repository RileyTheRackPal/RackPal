---
type: Design Ruling
title: DR-126 — DIR-003 was reading a field that lied, not the wrong field
description: >-
  DR-125 held the IR pairing question for a decision on a census that was a row
  short. Eleven device-side `IR IN` ports carried `ctl.ir_receiver` with the
  same direction, connector and pinout as a block's powered RX jack, so no
  re-keying of the predicate could separate the hazard from the everyday case.
  The damage is a two-conductor TS plug bridging ring to sleeve on a jack that
  supplies +12 V, so the discriminating fact is whether the jack is POWERED.
  `ctl.ir_direct` ships; the predicate is unchanged. Implementing it found the
  second field in two days that no producer could write.
tags: [ruling, validation, drc, dir-003, sig-002, signal-family, catalog, ir, pal-1, m5, dr-124, dr-125]
timestamp: 2026-09-05T00:00:00Z
ruling_id: DR-126
canon_section: "11.125"
status: built
amended_by: [DR-221]
---

# DR-126 · The catalogue was calling two signals by one name

Board `#305` (M5-H2). Settled by the user 2026-09-05, mid-review, as the
disposition of the one finding [DR-125](dr-125-the-review-s-twelve-findings.md)
explicitly held back.

## The finding: the ruling that raised it framed it wrongly

DR-125 §11.124.3 says `DIR-003`'s predicate *"matches families only"* and that
*"the data to discriminate exists and the rule ignores all of it"*, over a
three-row census. **The census was a row short.**

| Port | Family | Dir | Connector | Pinout |
|---|---|---|---|---|
| `C02.emitter.N` | `ctl.ir_emitter` | source | TS | `mono-tip-sleeve` |
| `C02.ir.rx.N` | `ctl.ir_receiver` | sink | TRS | `xantech-stereo` |
| `V01.ir.in`, and ten more | `ctl.ir_receiver` | sink | TRS | `xantech-stereo` |

Rows two and three are identical on **every field any rule reads**. Row two is
the hazard; row three is a matrix, an AVR, a cable box or a TV, which is where
an emitter head goes. The fix DR-125 imagined was unavailable.

## The mechanism was in the registry the whole time

`seed_registries.dart` states it beside the family definitions: receivers are
tip = signal, ring = +12 V, sleeve = GND; emitters are tip = IR in, sleeve =
GND. (The registry had ring and sleeve reversed until
[DR-221](dr-221-t5-01-pinout-tables.md) corrected it; the mechanism below holds
either way.) **A two-conductor TS plug entering a three-conductor jack bridges ring to
sleeve.** The damage happens because the jack SUPPLIES power, not because the
far device is called a receiver.

## Ruled

`ctl.ir_direct` ships for the passive device input; eleven sites move to it;
`ctl.ir_receiver` narrows to the powered receiver-eye circuit.
**`_irEmitterIntoReceiver` is not touched.** A rule reported as keyed on the
wrong field was reading a field that lied, and DR-125 would have had us edit the
one thing that was already right.

The block's `IR IN` is assumed powered, on the user's trade answer that it
varies by unit and none is self-powered: an emitter output has current for two
diodes, which is [DR-124](dr-124-an-ir-emitter-output-carries-two-conductors.md)
arriving from the other direction. The conservative side is chosen because
`DIR-003` springs back with `[ Connect anyway ]` (CR-017): a false hesitation
costs a click, the opposite error costs an emitter.

## What implementing it found

**Silencing `DIR-003` alone would have bought a different sentence and nothing
else.** With the eleven re-familied, the everyday connection still sprang back,
now as `SIG-002: does not accept ctl.ir_emitter`. `acceptsFamily` is
`signalFamily == family || acceptedFamilies.contains(family)`, and
`catalog_ports.dart`'s `p()` **had no parameter for the second limb**, so all
727 seeded ports carried an empty list by construction. `SIG-002` refuses every
cross-family pairing in the shipped catalogue; nobody noticed because almost
every seeded connection is same-family, and DR-126 created the first that is
not.

**That is the second field in two days found unauthorable by construction**,
after DR-124's `maxConnections`, in the same builder, on the same evidence: a
rule firing on a correct connection. With `RCK-003`'s discarded severity
(DR-125) the shape is three for three this milestone: a field the model has, the
documents describe, and no producer ever writes. See
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).

A canary caught it. `connect_rules_test.dart` asserted *"NOT ONE seed catalog
port declares acceptedFamilies"* and warned that a failure would mean the
catalog had started declaring. It fired, and was widened to a named set rather
than deleted.

## Evidence

- `ir_family_split_test.dart` sweeps the SHIPPED catalogue, not a fixture,
  because DR-125 §11.124.5 records that the complete 28/28 AC-051 corpus saw
  none of these: a pair proves a rule fires, not that it fires correctly, and a
  fixture that authors its own ports cannot see a mis-familied one.
- It reads **both** `buildSeedCatalog()` and `buildSeedRoleVariants()`. The
  eighteenth port is on `V06:receiver`, which `insert_receiver.dart` places as
  the `SIG-001` remedy, so it is the one IR port the product creates on a user's
  behalf, and a base-catalogue sweep misses it in silence.
- PAL-1: `1.5,9` at 0.75x, the emitter's own dot at three times the gap.
  **3,928 candidates run through the gate in full, 1,209 survived**; the choice
  among them was made by eye afterwards. All three palette gates pass at 57
  families over 415 in-band cross-domain pairs.
- **A gap in the gate, recorded not fixed**: its within-domain limb compares the
  exact `(dash, weight)` tuple, so `1.5,3,1.5,3` passes against `1.5,3` while
  rendering as the identical line. Repetitions were excluded by hand.
