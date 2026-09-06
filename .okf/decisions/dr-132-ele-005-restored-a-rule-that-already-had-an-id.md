---
type: Design Ruling
title: DR-132 — A section 8.3 amendment restoring ELE-005, which already had an id, a severity and a threshold
description: >-
  The user chose a rule over a rollup because an overloaded 70 V line clips the
  amplifier and clipped square waves destroy tweeters, which is AC-040's own
  "protects the user from real money" test. It is a CUT rule rather than a new
  one: the research corpus already specified `ELE-005` with the same severity
  and the same 80% threshold, and `ELE-007` was taken by something else.
tags: [ruling, amendment, ac-040, cr-021, validation, drc, ele-005, constant-voltage, g4, m5, dr-131]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-132
canon_section: "11.131"
status: ruled
---

# DR-132 · The catalogue goes to 29, and a duplicate was two greps away

Board `#838` (M5-K), amending AC-040. Settled by the user 2026-09-06, choosing a
rule over a rollup: *"I feel like having a warning for that is important to
prevent blowing speakers out."*

## The reason is the one AC-040 itself used

That cut kept `RCK-012`, `CODE-001` and `CODE-002` because they *"protect the
user from real money"*. **Overload a 70 V line and the amplifier clips, and
clipped square waves are what destroy tweeters**, so the loss is not a protection
circuit doing its job, it is a van full of replacement drivers. Same test, met.

## It is not a new rule, and I nearly minted a duplicate

The plan of record was to add `ELE-007`. Two greps before writing it found that
`docs/research/design-data-model.md` line 1136 already specifies:

> `ELE-005` **warning**: Σ of 70 V/100 V `tapWatts` on a net > 80% of the amp
> channel rating.

**Every parameter matches what was about to be invented**: the severity the user
asked for, the 80% threshold `PWR-001` independently sets as this repository's
load-headroom convention, and the aggregate. `ELE-007` was **also already taken**,
by a satellite-splitter DC-passing rule in the same document, so minting it would
have put two different rules behind one id in one corpus.

Second time in two days that reading before writing stopped a duplicate:
[DR-131](dr-131-the-switchable-device-is-the-speaker.md) found `Port.tapWatts` the
same way, by colliding with it.

## The amendment is narrow and says what it does not do

AC-040's enumeration governs and listed 28. `ELE-005` is added, making **29**.
**`ELE-004` stays cut**: parallel low-Z impedance is a different calculation over
a different aggregate, nobody has asked for it, and restoring a neighbour because
it is adjacent is how a cut list unravels.

## The sum is over KNOWN taps and never over estimated ones

G4/CR-114. A speaker whose tap nobody recorded still draws from the amplifier, so
it is not zero, and it must not be guessed either. The rule fires **only when the
known taps alone cross 80%**, the one case that is certain, and the message
carries the unknown count so the figure reads as a **floor**.

That asymmetry is the honest direction: a net whose recorded taps sit under the
line while four are blank has not been cleared, it has been **incompletely
measured**.

## Both halves of the sum were dead fields

`PortDef.bus.maxTapWatts` was declared on zero of 727 seeded ports because `p()`
had no `bus` parameter; `Port.tapWatts` was written by nothing at all. **The rule
is the consumer both have been waiting for since M0**, and `bus` leaving `#841`'s
census list is the first time a field left it because a rule NEEDED it rather
than because a rule fired wrongly without it.

## What the tests caught that the AC-051 pair could not

DR-125 §11.124.5: *"a pair proves a rule fires, not that it fires correctly."*

- **The amplifier was reported as a speaker nobody had measured.** Its own port
  has no tap, so it landed in the unknown list.
- **The first near-miss fired**, summing 220 against a 200 W budget. It is now on
  the boundary exactly, which also catches a `<=` written as `<`.
