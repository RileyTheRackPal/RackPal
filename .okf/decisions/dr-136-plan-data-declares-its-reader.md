---
type: Design Ruling
title: DR-136 — A document carrying plan data declares a reader that understands plans
description: >-
  DR-019 bought an `unknown` passthrough to stop an older build silently dropping
  plan pins on save. M3-I built it as a reserved container rather than a
  harvester, correctly and with the limitation stated in capitals, so it never
  covered a sibling key like `planPin`. The remedy never reached the hazard and
  nothing noticed until PLAN-C tried to write the test proving it did. The fix
  refuses the write instead: plan-carrying documents stamp a higher
  `minReaderVersion`.
tags: [ruling, persistence, format, versioning, plan-view, dr-019, dr-037, cr-114, cr-117, g5]
timestamp: 2026-09-07T00:00:00Z
ruling_id: DR-136
canon_section: "11.135"
status: built
---

# DR-136 · The remedy and the hazard agreed with each other and not with the problem

Settled by the user on 2026-09-07, on a finding PLAN-C/5 turned up while trying
to write the test its own brief asked for.

## The finding

DR-019 §11.18.1 identified a real forward-compatibility item and described it
precisely: `json_codec.dart` decoded `OffRackPlacement` as exactly `locationId`
and `mountNote`, so a build predating the Plan view, opening a file with plan
pins, **silently drops them on save**. §11.18.2(5) bought the remedy, an
`unknown` map on `Placement` and `Outlet`, and M3-I (`#568`) built it.

**It does not close that hazard, and both implementing files say so in
capitals.** `placement.dart`: *"RESERVED CONTAINER, NOT A HARVESTER. Nothing
collects unrecognised SIBLING keys ... Harvesting siblings would be a different
format and would need its own ruling."* So the bag preserves what a writer
deliberately puts **inside** it, and `planPin` is a sibling key like any other.

**Neither file is wrong.** They implemented a reserved container, said exactly
that, and named the ruling a harvester would need. What went missing is that the
remedy does not reach the hazard, and nothing noticed for a month **because the
field the protection was for did not exist yet**.

## Why this is the costliest shape of a familiar failure

It is [two documents agreeing is not
verification](../practices/two-documents-agreeing-is-not-verification.md) with
the two documents being a ruling and its own implementation. They agreed with
each other. Neither agreed with the hazard, and the only thing that could have
told them apart was a test over a field nobody could write yet.

The corollary worth carrying: **a protection bought for a feature that does not
exist has no way to be wrong until the feature arrives.** The moment to re-check
one is the moment you first need it, not the moment you first cite it.

## The ruling

A document carrying plan data declares a higher `minReaderVersion`, so a build
that does not understand plans opens it **read-only** and cannot overwrite it.
The silent loss becomes a visible refusal.

- `kSchemaVersion` moves to **5**; `kMinReaderVersion` stays at **3**.
- `minReaderVersion` stops being written unconditionally: it is decided from the
  document's **content**.
- Plan data means an underlay or a pin, and nothing else.

## The schema moves for a reason the format's trigger did not have

`json_codec.dart` states its trigger twice: an advance is owed when a change is
not byte-invisible to existing files. **These additions are byte-invisible**, and
that is measured rather than claimed: regenerating the four starters and the five
byte-roundtrip fixtures moves exactly one line each, the schema stamp.

**The stamp needs a NUMBER.** A conditional `minReaderVersion` of 5 written by a
build declaring `kSchemaVersion` 4 would make that build refuse its own file. So
the schema advances because **the format gained a capability
`minReaderVersion` must be able to name**, which is a second limb the trigger did
not have and now does.

One implementation choice keeps that true: the `underlays` map is **omitted when
empty**, unlike the fourteen entity maps beside it. Writing `"underlays": {}`
would add a key to every `.rmpj` in existence on its next save.

## What it costs, named rather than discovered

- Every document re-saved by this build declares schema 5, so a colleague on an
  older build opens it read-only. The standing cost of any advance.
- **A project becomes read-only for older builds the moment somebody drops one
  pin.** Taken deliberately: under DR-006 this is an internal tool whose users
  share files, and a colleague who cannot save is a colleague who asks, while a
  colleague whose save quietly deleted an afternoon of pinning finds out on site.

## What it does not rule

It does **not** make the `unknown` bag a harvester; that stays where
`placement.dart` left it, a different format owing its own ruling. It does not
extend the stamp to `Location.riseAllowance`, which is an ordinary additive
optional field on `tia570Grade`'s precedent: a number somebody can retype is not
a drawing somebody spent an afternoon making.

See [DR-019's container ruling](dr-019-json-or-zip-by-sniff.md),
[CR-117, byte exactness](../invariants/cr-117-byte-exactness.md) and
[a modelled field is not a reachable one](../practices/a-modelled-field-is-not-a-reachable-one.md).
