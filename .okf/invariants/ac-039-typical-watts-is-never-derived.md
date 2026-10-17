---
type: Invariant
title: AC-039, typicalWatts is never derived from nameplateWatts
description: A device's typical draw is something a person authored or it is unknown. No code path fills it from the nameplate, and BTU/hr and apparent VA are not synthesised from the wrong input either. The fabricated number was the worst thing the original design did.
tags: [invariant, power, thermal, g4, cr-114, ac-039, rj-005]
timestamp: 2026-10-17T00:00:00Z
ruling_id: AC-039
status: enforced
---

**`typicalWatts` is authored or null.** It is never computed from
`nameplateWatts`, and the figures that depend on it are not manufactured from a
neighbouring field when it is missing.

# Why the ruling exists

The original design defaulted `typicalWatts` to half of the nameplate rating,
derived BTU/hr from that guess, and then painted the results amber and red and let
them block a PDF. The critique's point was not the cost of the rollups but the trust:
the first time the app says "14.2 A of 16.0 A" and a clamp meter reads 6 A, the user
stops believing every number in the product. AC-039's *reasoning* is accepted in
full and became [G4](g4-unknowns-are-counted.md); its proposed *remedy* (cut the
rollups to two) was rejected as RJ-005. This page is the narrow, field-level
instance of G4: two different quantities that look related and are not.

`nameplateWatts` is a UL thermal rating, an **input** figure and an advisory second
line. `typicalWatts` is what the device draws and the number circuit loading uses.
They differ by a factor nobody can state without measuring the device.

# What it forbids

| Temptation | Why it is wrong |
|---|---|
| Default `typicalWatts` to a fraction of nameplate when blank | A guess enters the model looking like a measurement, and circuit loading reads it |
| Derive BTU/hr from nameplate when typical is missing | An installer sizes a fan against a number invented from a label |
| Derive apparent VA from typical watts when VA is missing | That assumes a power factor nobody authored |
| Treat a blank as zero | Zero is a measurement; see [G4](g4-unknowns-are-counted.md) |

BTU/hr is `btuPerHourOverride ?? wattsToBtuPerHour(typicalWatts)`, and **null** when
typical watts is null. Totals report how many devices contributed no figure rather
than summing as if they were zero.

# What enforces it

The rule is held in three places, because the temptation arrives in three places:

- **The derivation.** `device_loads_test.dart` has a group titled for this ruling:
  a device with a large `nameplateWatts` and no `typicalWatts` has an unknown BTU/hr
  and unknown typical watts, and a device with only `apparentVA` also has an
  unknown BTU/hr.
- **The rollup.** `totals_test.dart` asserts a template with typical watts and no
  apparent VA yields unknown VA and one counted unknown, the ruling's rejected
  behaviour restated as a test.
- **The authoring surface.** The device builder is where a person types a nameplate
  figure, so it is where a helpful default would be written.
  `device_builder_screen_test.dart` types a nameplate value, saves, and asserts the
  saved template's `typicalWatts` is null.

# What it does not cover

- **A person can still type a wrong typical figure.** The invariant is that the
  software never invents one, not that the number is right. Provenance for seeded
  catalogue figures is a separate rule (AC-052).
- **No test sweeps the seeded catalogue** for a typical figure that happens to equal
  a function of its nameplate. A catalogue author who computed one by hand would not
  be caught.
- **Output capacity is not a draw.** A UPS's or PDU's delivery rating is a different
  field and is deliberately absent from the load resolution, since adding it would
  count the downstream load twice.
- **It does not decide how an estimate is shown.** The ruling's other clauses
  (estimates visually distinct, nothing computed blocks anything) have their own
  homes.

# Citations

[1] `docs/canonical-decisions.md` AC-039, RJ-005, CR-114
[2] `packages/rackpal_core/lib/src/derived/device_loads.dart`, its header
[3] `packages/rackpal_core/lib/src/model/template.dart`, the `typicalWatts` field comment
[4] `packages/rackpal_core/test/derived/device_loads_test.dart`
[5] `packages/rackpal_core/test/derived/totals_test.dart`
[6] `packages/rackpal_ui/test/builder/device_builder_screen_test.dart`
