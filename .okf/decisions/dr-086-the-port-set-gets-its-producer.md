---
type: Design Ruling
title: DR-086 — The port set gets its producer, and the role column stops being free text
description: >-
  A set is made from a selection and never from an empty heading, because the
  seeded catalog already paid for the other arrangement. The role column becomes
  a closed list, for a mechanical reason rather than a tidy one.
tags: [ruling, m4, m4-j, port-sets, atomic-connect, cr-055, ac-030, dr-078, dr-082, dr-086]
timestamp: 2026-08-25T00:00:00Z
ruling_id: DR-086
canon_section: "11.85"
status: built
---

Settled by the user on 2026-08-25 (board `#181`, `#224`, `#761`), at M4-J2's
pick-up and **before any code**. A decomposition ruling: CR-055 already puts port
sets in v1 and
[DR-085](dr-085-mirror-bank-and-the-missing-producers.md) §11.84.6 hands
`PortSetDef`'s producer to M4-J2 by name.

# The field is unreachable in both directions

DR-085's census found the reader shipped and the producer missing. This one adds
the other half:

| | |
|---|---|
| `PortSetDef` | **no producer** outside the seeded catalog, under a live `SET` dropdown |
| `PortSetDef.kind` | **no reader** outside the codec: not `resolvePortSet`, not `planAtomicConnect`, not any drawing, schedule or rule |

Seventeen seeded declarations write `kind`, the codec round-trips it, and no
decision anywhere in the product consults it. Clause 2 gives it its first reader.

# A set is made from a selection, never from an empty heading

`Group as set…` (`Ctrl+G`) over **two or more** ticked rows writes the
`PortSetDef` **and** `setKey`/`setRole` on every member, in one transaction.

A `SETS` tree beside M4-J1's `BANKS` and a `New set…` entry in the `SET` dropdown
were both put and both declined. **They separate declaring a set from filling it,
and the seeded catalog is the evidence for what that costs.**
`port_set_integrity_test.dart` records the shipped catalog failing its own gate:
90 `setKey` references with **72 dangling**, 16 sets declared and **7 referenced
by nothing**, and **7 `atomicConnect` sets with fewer than two members**. Below
two members the AC-053 gesture is undefined and degrades to a one-conductor link
with no error. A product that can mint a one-member set has to warn about a state
it created; making it inexpressible is cheaper.

It **refuses under a sort**. It writes no `order`; it READS one, because roles are
assigned in **declared** order, which is `resolvePortSet`'s stated contract.

# The role list is closed, and SetKind opens it

`stereoPair` → `L`, `R`. `speakerPair` → `+`, `-`. `componentVideo` → `Y`, `Pb`,
`Pr`. No `Other` row, on
[DR-082](dr-082-parity-and-flowcontrol-are-closed-sets.md)'s rule.

**The reason is mechanical rather than tidy.** `planAtomicConnect` pairs members
by declared position and reports a `RoleMismatch` **by string equality**, and
`atomic_connect.dart`'s own header says that exposure *"opens the moment M4 lets a
user author a template"*. With free text, `+`, `plus`, `POS` and `Pos` are four
roles, and whoever types `Pos` gets a mismatch warning against every seeded
amplifier. AC-030 exists so a polarity inversion is **inexpressible**; a column
that spells `+` four ways is the opposite.

**Spelled exactly as the seed spells them**: `L` (8), `R` (8), `+` (9), `-` (9)
across 35 member ports. ASCII hyphen, and the picker must not improve on it. A
blank role stays legal and stays offered, because `PortSetMember.role` is nullable
and *"the position carries the meaning"*; roles **run out into blank rather than
cycling**, since cycling would give two members one role.

# balancedPair is not offered, and the value stays

Its one seeded use is A04's `bal`, *"Balanced input pair"*, roles `L` and `R`. As
authored it means *a stereo pair that happens to be balanced*, which
`PortDef.balanced` already records. The thing the name suggests is `balanced` plus
`Polarity` on the terminal.

Removing the value moves seeded bytes and breaks CR-117 for nothing, so the picker
simply omits it, **and includes it while the set carrying it is the one being
edited**: a value no menu offers must not be silently retyped by opening a dialog.

# Two things that had no home before

`atomicConnect` gets its **first editor**, a switch in the same dialog, defaulted
on. DR-011.2 made it load-bearing and `planAtomicConnect` reads it before any rule
runs.

**A set below two members is a notice, not an error**, on the passthrough
notice's precedent. The gesture cannot mint one; `Delete` on a member can leave
one. Removing the last member does **not** remove the set: an empty set is not a
dangling reference, and it is what somebody is about to refill.

# Ungroup, found while building and ratified after

**Built before it was ruled, which is the wrong order.** The clause was written
from the code rather than the code from the clause; it was put to the user with
the build in front of them (2026-08-25) and kept.


§11.85.2 through §11.85.7 left a hole, and it is where the sets a person no
longer wants go. **The capability was already there and only the cleanup was
missing**: the `SET` column lists `null` first, so setting both members of a pair
to the dash already takes them out and leaves the `PortSetDef` behind with no
members and no way to remove it. That is the *"declared, referenced by nothing"*
row of `port_set_integrity_test`'s own failure table, arriving in an authored
template instead of the seed.

`Ctrl+Shift+G` clears `setKey`/`setRole` on the selection **and removes every set
it leaves empty**. It is the only thing that removes a `PortSetDef`, and the rule
that DELETING the last member does not remove the set stands beside it unchanged:
deleting a port is somebody editing hardware, and ungrouping is somebody saying
these ports are not a set.

# Built 2026-08-25

All four clauses plus the one above ship (`#224`, `52e8916`). The role picker
closed, `atomicConnect` got its first editor anywhere, and a set below two
members became a notice on the `SET` column.

**Two defects the widget cases caught before anyone opened the dialog**: the kind
dropdown overflowed by 0.65 points on its longest row and painted the striped
bar, and a stale refusal stayed on screen after the condition producing it had
gone away.

# What it does not rule

It does not touch passthrough pairing (M4-J3). It gives `SetKind` a job in the
BUILDER and nowhere downstream. And it puts no set on the schematic symbol or in
the panel layout, both of which are banks' work (CR-055).
