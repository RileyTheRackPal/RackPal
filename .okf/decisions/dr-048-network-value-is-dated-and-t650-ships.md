---
type: Design Ruling
title: DR-048 — A network value is a dated as-built fact, and T6.50 ships in v1
description: >-
  The field has been modelled since M0 with no writer anywhere, not even a test
  fixture, while a reserved sheet id made it read as nearly shipped. G4 handles
  unknown and has no mechanism for stale, which is the failure this data has.
tags: [ruling, network, sheets, g4, m6, dr-005, dr-048, reachability]
timestamp: 2026-08-12T21:00:00Z
ruling_id: DR-048
canon_section: "11.47"
status: ruled
---

Settled by the user on 2026-08-12, from a request for static IP settings on the
sheets: *"when a service tech looks at a rack, the first thing they usually want
to do is connect to the problem system."*

# The field had no writer anywhere, not even a test fixture

`NetworkConfig{hostname, ip, subnet, gw, mac, vlans[], portRole}` has sat on
`Port` since M0, is encoded and decoded by `json_codec.dart`, and byte-round-trips.
`DeviceInstance.macAddressPrimary` sits in the same condition beside
`serialNumber`, `assetTag`, `firmwareVersion` and `installedAt`.

```
grep -rn "network\s*=\|network:" --include=*.dart .
→ json_codec.dart:1361:  network: decodeNullableObject(
```

**One hit, and it is the decoder.** The only way a `NetworkConfig` has ever
existed in this product is a hand-edited `.rmpj`. It is the seventh instance of
[a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
and the pure case: every earlier one had at least a fixture.

# A reserved sheet id was the most authoritative-looking statement about it

`sheet_def.dart`'s `kReservedNcsIds` reserves **`T6.50` for "the v1.1 Network/IP
Schedule"**, citing docs/08 §2.2. So a reader found a modelled field, a working
codec and a reserved sheet number, and concluded the work was mostly done.

**Roadmap §2 carried no row for it in any release.** `grep -in network
docs/09-roadmap.md` returns nothing. A ruling that defers something and a scope
list that carries it are two different artifacts, and this had the first and never
the second, which is
[two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
wearing a sheet id: **a reserved identifier is evidence of intent doing duty as
evidence of existence.**

# G4 handles unknown and has no mechanism for stale

This is the clause worth carrying to other work.
[G4](/invariants/g4-unknowns-are-counted.md) is complete about *unknown*: null,
absent key, counted, never estimated. It says nothing about **a value that was
true and is not**, because a stale value is not null, is not counted, and prints
in the same typeface as a fact.

That failure is worse here than in most places, because the reader is a tech at a
rack at the end of a day and a confidently wrong address costs twenty minutes of
disproving it. So `NetworkConfig` gains **`verifiedOn: DateTime?`** and an
undated value renders as **unverified** rather than as fact.

**A document-level "as of" date was refused.** The real case is four devices
re-addressed last week and thirty untouched; one date per project cannot tell them
apart and would launder the stale thirty into the fresh four's credibility.

# The management address is a device fact

The user's constraint settled it: *"switches will have static IPs marked out by
devices themselves."* A managed switch has one management address and forty-eight
ports, so an address hung off a port is filed under an arbitrary one of them.

`DeviceInstance` gains `network: NetworkConfig?`. `Port.network` is unchanged and
keeps the per-port facts. The **existing type is reused rather than a scalar
added**, because an address without its subnet and gateway is not usable by the
tech it exists to serve. `kSchemaVersion` does not move: the whole key is absent
when null, which is [CR-117](/invariants/cr-117-byte-exactness.md)'s
additive-optional case, and `macAddressPrimary`'s `putIfNotNull` is the pattern
copied.

# What changed against the recommendation, and why

Two of the three recommendations were overruled and the reasons are the user's
trade knowledge rather than the corpus:

* **The sheet ships in v1, in M6**, not v1.1. Supersedes DR-005 §11.5.3 for
  `T6.50` alone; `T6.40` Power Schedule does not move, because `NetworkConfig` is
  in the format today and the power data is not.
* **The address launches a browser**, behind a confirmation showing the URL. The
  objection was that the drawing machine is not on the rack's network. In this
  trade it frequently is: a project copy lives at the client's home, and UniFi
  with Teleport, OvrC, Eero Insight, Nice Management Cloud and BlueBolt put a tech
  on that network routinely.

# The defect this exposed in its own codec

`_encodeNetworkConfig` opens `final json = <String, Object?>{'vlans': n.vlans};`,
so `vlans` is written **unconditionally** and an untouched list encodes as
`"vlans": []`. Under CR-114 that claims *measured zero* where the fact is *nobody
said*, and it is the `designatorLocked` anti-pattern
[CR-117](/invariants/cr-117-byte-exactness.md) warns is copied by proximity.

It has never mattered because nothing ever constructed one. It becomes the common
case on a device-level record, so it is fixed with this work rather than filed:
filing it means shipping the defect and the fix in that order.

# Scope

v1 grows by three items: `DeviceInstance.network`, `NetworkConfig.verifiedOn`, and
the `T6.50` sheet, `AUTO` iff at least one device carries a network value. The set
becomes **twelve slots, nine `ON` and three `AUTO`**, a count stated in six places
across four documents and edited in all six. M6 grows within its `M`. M4 is
untouched: this is instance data, and no template gains a field.

**Not ruled**: whether an address is validated as well-formed or checked for
collisions. Both are DRC rules with an AC-051 fixture pair each and belong to M5,
on `LEN-002`'s precedent of a rule shipping a milestone after the field it reads.

# Citations

[1] `docs/canonical-decisions.md` §11.47, §12.20
[2] `packages/rackmate_core/lib/src/model/port.dart`, `NetworkConfig`
[3] `packages/rackmate_core/lib/src/draw/sheet/sheet_def.dart`, `kReservedNcsIds`
[4] `docs/12-milestone-board.md` §5.5
