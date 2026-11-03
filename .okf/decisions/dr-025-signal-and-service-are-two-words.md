---
type: Design Ruling
title: DR-025 — `@service=` names the label, `@signal=` names the family; they are two words
description: A structured run's signal family was unreachable by any gesture, and the corpus pointed two ways about which word sets it. One word cannot carry both facts without switching off the product's highest-value validation.
tags: [ruling, m3, labels, validation, dsl, dr-025]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-025
canon_section: "11.24"
status: built
---

Settled by the user on 2026-08-09, answering the question board #587 raised
while M3-C/3 closed.

# The finding that forced it

A structured run's `Service.signalFamily` is `structure.undetermined` **forever,
and no gesture in the product can change it**. `buildAddHomeRunCommand` hardcodes
it, nothing writes it afterwards, and docs/07 §4's own wireframe draws a SERVICE
column of values (`HDBaseT`, `Ethernet`, `CATV`, `Speaker`, `Keypad`) that no
gesture can produce.

The starting value is right and is not what the ruling touches: at rough-in a
Cat6 is just a Cat6, and docs/07 §4.1 calls `undetermined` *"a first-class,
encouraged state"*. What was missing is the second half of that same sentence,
*"the DRC validates RETROACTIVELY when a `Service` later assigns a real family"*.
**There was no later.**

# Two words, because they are two facts

`@service=` is unchanged and [DR-023](/decisions/dr-023-service-fallback-chain.md)
stands entirely. A new **`@signal=`** names the signal family.

The corpus pointed both ways, which is why this needed a ruling rather than an
implementation choice: docs/07 §5.1's import table maps a `service` column to
`SignalFamilyId`, while DR-023 resolves `@service=` through an `OutletTemplate`
by tag then by name, making its value a template handle.

## The user's evidence is what decides it

> We often have situations where we use one AVoIP system for most areas, but use
> a simple HDBT transmitter/receiver pair for say, running from an AVR to a
> projector.

`video.avoip` and `video.hdbaset` are separate shipped families with the same
domain, the same connector and the same Cat6 in the wall. So one house has runs
that are **the same label and different families**, and three AVoIP drops to a
TV, a projector and a display that are **the same family and different labels**.
One word is wrong in one direction on every job that mixes the two, which the
user reports is the ordinary case.

## The decisive form: a naming decision must not switch off a safety check

`seed_registries.dart` on `video.hdbaset`, quoted rather than paraphrased:

> `acceptedFamilies` deliberately EXCLUDES `net.ethernet` — patching an HDBaseT
> output into a switch does not work and its 100 W PoH can damage the switch.
> That check (`SIG-001`) is the highest-value validation in the product and is
> only expressible because this is its own family.

If `{SERVICE}` set the family, choosing a **label** would decide whether SIG-001
fires. A label is a naming decision stored once at creation; a family is an
electrical fact the DRC reads. Letting the first drive the second is how a rule
stops meaning anything.

# Resolution, and why an unresolved value refuses

`@signal=` resolves against `registries.signalFamilies` by `shortTag`, then the
id's tail, then `displayName`: `resolveMediaToken`'s widest-last shape, so
`@signal=hbt`, `@signal=hdbaset` and `@signal=avoip` all land. The word is
`signal` because docs/07 §5.1 already lists it as an accepted CSV header, so the
DSL and the importer share one word rather than acquiring a third.

**An unresolved value REFUSES and never creates a family**, which is the opposite
of RJ-012's rule for media. Already ruled: docs/07 §3 says media types are
user-extensible in v1 while *"signal families and connector types remain
catalog-updated"*. A family invented from a typo has no domain, no colour, no
dash and no `acceptedFamilies`, so the DRC and the palette both cannot reason
about the run.

# One implementation fact the task must not miss

**The family is stored TWICE.** `buildAddHomeRunCommand` writes
`Service.signalFamily` and `Net.signalFamily`. Only the first is consumed today,
and docs/05 §5 is explicit that colour resolves from `Service.signalFamily`
*"never from the `Link`"*. A command that sets one and not the other leaves the
file carrying two answers to one question in the one place nothing would notice,
which is CR-107's failure in miniature. **Both are written or neither is.**

# What it does not settle

A CSV `Use` column feeds the label chain and **never** the family: real pull
lists put `TV`, `Data`, `Camera`, `Speaker` there, which name templates. The
accepted cost is that importing a list whose `Use` column says `HDBaseT` leaves
those runs undetermined; the alternative is a spreadsheet word silently setting
the fact SIG-001 reads. **docs/07 §5.1's table is owed the edit** and it is the
only derived-document change this ruling forces.

# Scope

No scope change to roadmap §2. docs/07 §4.1 already promises the capability, so
#587 is a **decomposition gap rather than an amendment**. **M3-F is unblocked**:
#159 could not be written while a contractor's `Use` column had two possible
targets.

# BUILT 2026-08-13, and what building it taught

Three deliverables, in order: the Command (`fad66c0`), the `@signal=` modifier
(`cae0a1e`) and the SERVICE picker (`e95f57b`). §11.24.6 held: one command writes
both fields, and one undo restores both.

**The control was chosen by measurement, and the measurement contradicted the
obvious answer.** A `DropdownButton` was the natural fit because three choice
columns already use one. Its menu inherits its **button's** width; SERVICE is 76
points, the 55 labels average 22 characters and reach 45, and a throwaway harness
put the menu at **116 points wide with every row clamped to 84**. So
`AUD·Speaker level, low-Z` and `AUD·Speaker, constant-voltage 70 / 100 / 25 V`
both render `AUD·Speaker…`. The enum-backed columns keep their dropdown because
`PULLED` and `RJ45` fit, and that asymmetry is a core predicate rather than a
taste. See
[measure the control before choosing it](/practices/measure-the-control-before-choosing-it.md).

**A filter box is not the text box this ruling refused.** It narrows and never
commits, and it matches on the tokens `@signal=` already accepts, so `hbt` finds
HDBaseT and the product does not acquire a second vocabulary for one fact.
Filtering is SUBSTRING where resolution is EXACT, which is two questions rather
than a disagreement.

**Making the column editable would have introduced a crash, and closing it found
a missing gate.** `DropdownButton` asserts exactly one item matches its value,
and `typeCell` prints a bare id when a `Service` names a family the registries
lack. The enum columns cannot reach this because the enum IS their menu. Chasing
whether that state was reachable found that **a `PortDef` carries two registry
references and only the connector half was gated**: `registry_parity.py` compares
the seeded registry against `pal1_check.py` and never looks at the catalog, and
this is a third thing rather than a corner of its stated blind spots.
`catalog_ports.dart` builds `SignalFamilyId(family)` from a raw string and
`AtomicConnectCommand` carries it onto both the `Service` and the `Net` with
nothing in between to object. Measured: 48 parts name 34 families and all 34
resolve, **a fact about that catalog on that date rather than an invariant**.
`ee3cfe7` makes it one.

**The `Use` column deferral now has a named cost the user has confirmed.** Signal
families being catalog-updated (RJ-012) means expanding the trade's vocabulary is
a catalog change and never a user action. `CTL·Lutron QS / HomeWorks link` already
ships; Legrand Vantage does not, and that is a catalog task rather than a picker
one.

# Citations

[1] canonical-decisions.md §11.24 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/catalog/seed_registries.dart`, the
    `acceptedFamilies` comment on `video.hdbaset`
[3] docs/07-structure-device.md §4.1 and §5.1
[4] [DR-023, the `{SERVICE}` fallback chain](/decisions/dr-023-service-fallback-chain.md)
