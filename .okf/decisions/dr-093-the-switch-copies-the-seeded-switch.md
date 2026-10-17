---
type: Design Ruling
title: DR-093 — The Switch generator copies the seeded switch, including its silences
description: >-
  The specification for the Switch ports generator was already in the repository
  and it is not docs/06 §4.3's one-line sentence: it is catalog_network.dart's
  N01. Censusing it answered four questions the sentence could not, and the most
  valuable answer was which two PoE fields N01 declines to write.
tags: [ruling, device-builder, archetype, switch, poe, sfp, m4-i, dr-093, g4, census]
timestamp: 2026-08-26T00:00:00Z
ruling_id: DR-093
canon_section: "11.92"
status: built
---

# DR-093 · The generator copies the seeded switch, including its silences

Board `#221` (M4-I2). [DR-092](dr-092-the-archetype-emits-the-port-4-3-could-not.md)
§11.91.8 left these open by name.

## The specification was already in the repository

§4.3's whole statement of this generator is one line: *"N access ports + M uplinks, PoE
standard and per-port class, SFP form factor, management port, redundant PSU"*.

`catalog_network.dart`'s **N01** is a 48-port PoE switch with four SFP28 uplinks, an
out-of-band management port, a front-panel console and two PSU inlets, authored at M0 and
reviewed since. Every field the generator writes is a field N01 writes, in N01's bank.

## The finding is what N01 does NOT write

N01's PoE ports carry `role: pse` and `standard: btType3` and **nothing else**.

* **`type` is a second spelling of `standard`.** The IEEE type number maps 1:1 onto the
  four standards. Two fields holding one fact disagree the first time somebody edits one,
  and nothing in the model says which wins.
* **`watts` is a per-device budget, and N01 proves it on its own row.** 802.3bt Type 3's
  PSE maximum is 60 W. N01 declares `standard: btType3` **and** `poeBudget: 740` across 48
  ports, which is **15.4 W each**: 802.3af's figure, on a switch that supports Type 3.
  Both are true and they are about different things.

A generator writing 60 into every port offers a rollup 2,880 W of PoE on a device whose
nameplate is 900. That is [DR-079](dr-079-a-listing-is-not-a-material.md)'s **false pass**,
in the direction that does not announce itself, and the seed had already declined to make
it.

`class` is the one PoE value the dialog asks for, because a switch may support a lower
class than its standard permits. Left blank it is an absent key
([G4](/invariants/g4-unknowns-are-counted.md)).

## Three more answers the sentence could not give

**The console port exists and is on the FRONT.** N01 carries two management ports:
`OOB MGMT` on RJ45 at the rear and `CONSOLE` on a DE9 at the front, which is where a
technician with a laptop reaches for it. Two independent checkboxes, because many switches
have one and not the other; both land in one `Management` bank, and a bank spanning two
faces is ordinary (CR-055: a bank is presentation).

**The cage sets its own label and its own rate.** SFP is 1 Gb/s, SFP+ is 10 and SFP28 is
25 by definition of the form factor, and N01 writes `linkSpeedMbps: 25000` beside its
SFP28 cages. **This is not the `watts` case**: a cage's rate is what the cage IS, where a
port's wattage is what the supply can spare. Access speed is a control defaulting to
N01's 1000.

**Redundant PSU is a second inlet and is greyed without a first.** One inlet is `AC IN`;
two are `PSU A` and `PSU B`, which M4-H's `{A}` token expands to. The checkbox carries its
reason beside it, because a disabled control with no explanation reads as broken.

## The labels are the silkscreen and not the bank

Access ports read `01` … `48`, bare, which is what is printed between the jacks. Uplinks
read `SFP28 1`, unpadded, because four is a list of names rather than a column a schedule
sorts on. The four bank labels are **named, not derived**: `deriveBankName` answers "LAN
Ports" for the access bank and "DAC Ports" for the uplinks, two spellings of Ethernet that
say nothing about which bank is which.

## Two things the writing turned up

`PoeSpec` and `PortPowerSpec` are **mutable**, so the decorator constructs one per port. A
captured instance would be shared by all forty-eight, and editing one port's class in the
grid would silently edit the bank. Both have a test.

`switchSfpLabel` was deleted before it shipped: `portSfpLabel` already prints those three
strings for the grid's SFP column.

## Citations

[1] `packages/rackmate_core/lib/src/catalog/catalog_network.dart`: N01
[2] `packages/rackmate_core/lib/src/builder/archetypes.dart`
[3] [census the field, not the name](/practices/census-before-building.md)
