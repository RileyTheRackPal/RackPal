---
type: Design Ruling
title: DR-131 — The switchable device is the SPEAKER, and the catalogue already knew it
description: >-
  The question went to the user as a switchable AMPLIFIER and the premise was
  wrong: amps are rarely switchable and one that does both has separate
  outputs. Speakers carry the taps and the Low-Z/CV switch, and `A05` already
  modelled exactly that. One control on the speaker answers both halves of the
  finding, and the bypass moves the RESOLVED family rather than one rule's
  verdict.
tags: [ruling, validation, drc, ele-006, sig-002, speakers, constant-voltage, producer-gap, m5, dr-125, dr-128, dr-132]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-131
canon_section: "11.130"
status: built
---

# DR-131 · Two rules disagreeing with one physical switch

Board `#838` (M5-K), authorised by
[DR-127](dr-127-the-review-s-unpriced-findings-enter-m5.md). Settled by the user
2026-09-06 on the M5-H2 review's fifth finding: *"`maxTapWatts` exists on the
model; a tap SELECTOR and CV-to-Low-Z switching do not."*

## A producer with no consumer, which was a new shape

Eight producer gaps preceded this one and every one was a field nothing could
write. `maxTapWatts` is the reverse and is no better off: **authorable in the
device builder, declared on zero of 727 seeded ports, and read by nothing
anywhere.** A person could type a tap wattage and it participated in not one
calculation. `catalog_field.dart` even named the gap, calling `F08` *"the only
field source of a tapWatts selector"*, a selector that was never built.

## The correction that relocated the problem

The question was put as a switchable AMPLIFIER. The user's answer:
*"Amplifiers are very rarely switchable, and if they support both Low-Z and CV,
they almost always have separate outputs instead of a switch. Speakers are the
only CV devices that I've seen with taps/switches for Low-Z/CV in person."*

**And the catalogue already agreed, which nobody had checked.** `A05`, the only
rack-side CV source, declares `cv.a` and `cv.b` as `audio.speaker_cv` bus nodes
at `nominalVoltage: 70` and **has no low-Z output at all**. The amp side needed
nothing; the model had been right for a reason nobody had written down.

**Third trade correction this milestone**, after the passive power strip and the
shelf, all three the same shape: reasoning from what the model could express
rather than from what an installer touches. See
[trade-knowledge-beats-workflow-reasoning](../practices/trade-knowledge-beats-workflow-reasoning.md).

## And the field already existed, one grep away

DR-131 was drafted ruling the pair onto `DeviceInstance`, and the fields were
written there before the collision surfaced. **`Port.tapWatts` already existed**,
documented as *"70/100 V transformer tap: per INSTALLATION, not per template"* and
written by nothing at all. The census that priced this ruling **grepped
`maxTapWatts` and never grepped `tapWatts`**, which is
[census-the-field-not-the-name](../practices/a-modelled-field-is-not-a-reachable-one.md)
for the fifth recorded time.

## Ruled: the bypass moves the FAMILY, not one rule's verdict

`ELE-006` was patched first, to ignore the pairing when the source is bypassed,
and **the gate returned `SIG-002` within a minute**: the sink's `acceptedFamilies`
never listed `audio.speaker_cv` and the source still called itself constant
voltage.

**Two rules disagreeing with one physical switch is the signal that the fact
belongs upstream of both.** It lands in `resolvePortSignalFamily`, where `#233`'s
port-fact resolver already lives, and **neither rule needed changing**. One way
only: a low-Z port is never bypassed into constant voltage, because there is no
transformer to switch back in and inventing one would be fabricating hardware.

## What it surfaced that was nobody's ticket

Both `_oneOf` and `SIG-002`'s acceptance check read `def.signalFamily`, the RAW
TEMPLATE value, rather than `ConnectTarget.signalFamily`. So **every port-family
correction `#233` lets a person make on an instance has been invisible to every
tier-2 rule** since that resolver was built. The bypass is only what made it
visible.

## The tap value is typed, not picked

A fixed ladder was declined on evidence: Episode ships 7.5/15/30/60/Bypass,
Beale Street ranges from 1/1.9/3.8/7.5/15/Bypass to that same scheme, and `F08`'s
own catalogue description hard-coded a third set that matched neither. A
per-template list was declined for a workflow reason worth recording: the tap is
**set once at install and not touched**, and a discrepancy is caught against the
sheets on site.

The sum rule that consumes it is
[DR-132](dr-132-ele-005-restored-a-rule-that-already-had-an-id.md).
