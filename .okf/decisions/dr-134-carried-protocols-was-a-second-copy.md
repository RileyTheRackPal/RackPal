---
type: Design Ruling
title: DR-134 — `carriedProtocols` is deleted, and DR-081's cell is built for the field that survives
description: >-
  `#846` said protocol search matched nothing and called two reads dead. Both
  were false and checkable in one command. The real case is that the field was a
  second copy of two facts the model already recorded with producers and
  consumers, so it goes, and the multi-select DR-081 ordered is built for
  `acceptedFamilies`, which had gained three connect-time readers and no gesture.
tags: [ruling, amendment, model, persistence, migration, device-builder, reachability, m5, dr-081, dr-105, dr-126, cr-117]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-134
canon_section: "11.133"
status: built
---

# DR-134 · The field was a second copy, and the case for deleting it was wrong

Board `#846`, a §8.3 amendment superseding **DR-081 §11.80.2 in part**. Settled
by the user on 2026-09-07, who chose **building** DR-081's cell over leaving it
owed.

## The case put to the user was wrong in its facts

`#846` reads *"searching the shipped catalogue by protocol matches nothing, and
always has"*, and it was relayed with *"deleting two dead reads and a field is
cheaper and more honest than filling it"*. Both halves are false:

- **Protocol search works.** `dante` finds the seeded DSP twice over, by the
  `audio.dante` family on its `dante.pri` / `dante.sec` ports and by the device's
  own `dante` tag. `template_search_test.dart` has asserted it since M4.
- **Neither read is dead.** Both are widenings of paths that already work through
  `signalFamily`.

**A finding about a FIELD is not a finding about the FEATURE it is part of.**
`#841`'s census asked the right question and answered it right. Reading *nothing
populates this field* as *the feature it feeds is broken* is a different claim
needing a different measurement, and the measurement was sitting in a test file.

## The real case is better, and the spec's own worked example makes it

docs/02 §6.2 uses `carriedProtocols` for exactly two things and the model already
records both, with a producer **and** a consumer:

- **eARC over HDMI** is `PortDef.returnChannel`: a builder column, seed data on
  two catalogue entries, a spring-back rule and a schematic consumer. §6.2's
  example writes the eARC fact **twice on one port**, and only the copy that is
  not this field is read by anything.
- **Dante over RJ45** is a signal family on a dedicated port plus a device tag.

It also had no writer, and cost **737 empty arrays in `apartment.rmpj` alone**,
which is `position`'s defect one field over in the same encoder (DR-105
§11.104.3).

## Two of DR-081's own statements are corrected

- §11.80.5: *"the codec writes no key for an empty list"*. **False, and false
  when written.** `_encodePortDef` writes both list keys unconditionally.
- §11.80.3: *"Nothing reads `acceptedFamilies` at connect time in v1"*. True on
  2026-08-21 and **false since DR-126**. Three call sites read it today.

**The second correction is why the cell is BUILT rather than dropped with the
field.** A value three connect-time call sites read, with no gesture that can
correct it, is the defect this milestone found ten times.

## The schema moves and the reader stamp does not

`kSchemaVersion` goes to **4**, because removing the key changes the bytes of
every file on disk, which is this format's own stated trigger. `kMinReaderVersion`
stays at **3**, the first time the two have diverged: a v3 reader meets the absent
key with `?? const <Object?>[]` and gets `[]`, which is the only value the field
has ever held in any file.

`kRmdxSchemaVersion` goes to **2** as well, its chain being independent, and that
step **recomputes the `contentHash`** because the migration changes the bytes it
covers. The cost is stated: a migrated file verifies against itself and nothing
more. The alternative is a warning that fires on every older file, which a person
learns to click past.

See
[a-modelled-field-is-not-a-reachable-one](../practices/a-modelled-field-is-not-a-reachable-one.md)
and [dr-081-three-port-fields-get-a-cell](dr-081-three-port-fields-get-a-cell.md).
