---
type: Design Ruling
title: DR-128 — The remedy prompt, and three rules that told you to do things the product could not do
description: >-
  DR-125 called this "one feature, three-quarters built". Censused, `InlineAdapter`
  had no writer but the JSON decoder, so `CON-001`'s promise that "declaring the
  adapter clears it" named an action nobody could take. CR-015's test splits the
  chips: `CON-001` declares a VALUE, `SIG-002` mints a DEVICE. `Finding` gains a
  remedy because `PWR-003` is a panel row and had no surface at all. Building it
  found two more producers missing and a copy that dropped a field.
tags: [ruling, validation, drc, remedy, con-001, sig-002, pwr-003, cr-015, ac-043, catalog, m5, dr-125, dr-126, dr-127]
timestamp: 2026-09-06T00:00:00Z
ruling_id: DR-128
canon_section: "11.127"
status: built
---

# DR-128 · Offering the remedy is what separates a rule engine from a nag

Board `#837` (M5-J), authorised by
[DR-127](dr-127-the-review-s-unpriced-findings-enter-m5.md). Settled by the user
2026-09-05 in three answers, then corrected by them twice on trade facts.

## The finding: the ticket's estimate was wrong in both directions

DR-125 §11.124.4 grouped `SIG-002`, `CON-001` and `PWR-003` as *"one feature,
three-quarters built"*, from `insert_receiver.dart` existing. Censused:

**`InlineAdapter` is modelled, round-trips through the codec, and is read by
`_adapterSatisfies` to clear two rules. Its only writer was
`_decodeInlineAdapter`.** So `CON-001`'s catalogue summary, *"Satisfied by data:
declaring the adapter clears it"*, **described an action no user could take**.
See [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).

**Nor were they one feature.** `SpringBackRemedy` lives on a chip; `PWR-003` is a
row in the issues panel; `Finding` had no remedy field. Two had a surface and the
third had nowhere to put one.

## Ruled

| Rule | Remedy | CR-015's test |
|---|---|---|
| `CON-001` | Declares an `InlineAdapter` VALUE, both connectors prefilled from the failing pins | Nobody pulls two cables to a barrel |
| `SIG-002` | Mints a converter DEVICE from the two pins | A family mismatch is answered by electronics |
| `PWR-003` | `Finding` gains a remedy; adds `P04`, or ASKS when the rack has no power | Built once: `CODE-002` wants it too |

**The converter is minted, not shipped**: a seeded archetype cannot have the right
ports in general, since the families it bridges vary per use. **`P04` IS shipped**,
because a 6-outlet strip is the same object on every job.

## What the trade corrected

The first answer for `PWR-003` was the 0U PDU, **chosen by an agent listing what
the catalogue happened to hold**. The user returned what was missing: a small
passive strip on a shelf, fed from a PDU outlet so the gear on it can be
power-cycled remotely (BlueBOLT, OvrC), and *"commonly just set on a shelf"*. Six
outlets cites the basic WattBox strip their company most often installs, which is
AC-052 in the form the rule wants. CR-061 moves 49 to 50.

**`seed-devices.md` §3.10 was stale**: P3 rules the count lives in exactly one
place, and that place read 48 against a catalogue shipping 49, while thirteen code
sites had it right. A single source of truth that nothing gates is a single source
of staleness.

## What building it found

- **`ShelfPlacement` had no producer either.** Nothing a person did put a device on
  a shelf, which is where the strip goes. Built as AC-043's auto-pack, which that
  ruling KEEPS, so no amendment. The richer shelf model is `#844`, parked as a
  MAYBE under M9.
- **`evaluateDocument` rebuilds a `Finding` field by field, twice**, and neither
  copy carried `remedy`. **DR-125 §11.124.2's defect repeating inside its own
  milestone.** Replaced with `Finding.withSeverity`.
- **The ruling claimed two chip buttons before they existed.** §11.127.6 said the
  enum gains two members while both chips carried empty remedy lists. **Dart's
  exhaustive switch caught it**, not diligence.
- **Three ghost ids in the AC-051 corpus**: `conn.xlr3_f`, `video.hdmi`,
  `audio.analog_bal`. Every case passed on them.

## The habit that found all of it

Every test asserts **the rule going quiet** or **the finding clearing**, never that
a field was set. Two versions of the `PWR-003` remedy added a device, returned
`Done`, and moved nothing:
[assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).

**Three canaries fired, each having written its instructions to whoever tripped
it**: `connect_rules_test.dart` on `acceptedFamilies`, `placement_rules_test.dart`
on `TOP-005` (*"gate it and correct the note on ConnectRule.hostResolves"*), and
this ruling's own "not vacuous" guard, which caught a fixture naming a connector
that does not exist.
