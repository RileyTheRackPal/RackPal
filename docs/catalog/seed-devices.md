# Seed Device Catalog

This document is the authoring specification and the shipping content for RackPal's seeded
template library: the generic archetypes that ship in v1 (per CR-061; the counts are in §3.10 and
nowhere else), the compact port notation the catalog is authored in, the four registries those templates
reference (signal domain, signal family, connector type, media type, reproduced from canon §6
verbatim because that section *is* the shipping data), and the `.rmdev` seed file format with one
fully worked example. It exists because the catalog is not decoration, three of the product's
most valuable validation rules cannot fire against an empty library (AC-031), the rack rollups are
blank without real weights and wattages, and the difference between a demo of the product and a
shape library is whether the numbers in these tables are true.

**Related:** [Overview](../00-overview.md) · [Domain](../01-domain.md) ·
[Data model](../02-data-model.md) · [Architecture](../03-architecture.md) ·
[Rack editor](../04-rack-editor.md) · [Schematic editor](../05-schematic-editor.md) ·
[Device builder](../06-device-builder.md) · [Structure device](../07-structure-device.md) ·
[PDF export](../08-pdf-export.md) · [Roadmap](../09-roadmap.md) ·
[Decisions](../10-decisions.md) · [Testing and quality](../11-testing-and-quality.md)

> **Provenance warning, and it is binding.** Every numeric field printed in §3 is an *authoring
> target*, not a shipped value. Per AC-052 a template ships only when every numeric field it
> carries has a cited source (manufacturer datasheet, published standard, or measured) recorded
> in `assets/catalog/sources.md`, and a template whose **safety-adjacent** fields —
> `pinoutVariant`, `impedanceOhms`, `poeBudgetWatts`, `maxUnsupportedMass`,
> `maxRunLengthPassive`, PoE class watts — are uncited **does not ship at all**. The tables below
> are what the author fills the citation form against.

---

## Contents

| § | Section |
|---|---|
| 1 | [Catalog design principles](#1-catalog-design-principles) |
| 2 | [The compact port notation](#2-the-compact-port-notation) |
| 3 | [The catalog](#3-the-catalog) |
| 4 | [Signal domain and signal family registries](#4-signal-domain-and-signal-family-registries) |
| 5 | [Connector and media type registries](#5-connector-and-media-type-registries) |
| 6 | [The `.rmdev` seed file format](#6-the-rmdev-seed-file-format) |
| 7 | [Acceptance criteria and CI assertions](#7-acceptance-criteria-and-ci-assertions) |

---

## 1. Catalog design principles

Twelve principles. Each one is a decision that was made against a named alternative, and each is
traceable to a ruling. Where a principle looks arbitrary it is one of the governing frame's five
principles (G1–G5) applied mechanically.

The catalog covers the common case; the device builder covers the long tail and ships in v1
(DR-003). Neither substitutes for the other.

### P1: Generic archetypes, never real SKUs

Every template is `manufacturer: "Generic"` with a descriptive `model` string
(`MTX-8x8-HDBT`, `AMP-16CH`, `SW-24-POE`). No brand appears in shipped data, no logo ships, and
no template claims to represent a specific product.

*Rejected alternative:* a real-SKU catalog, which is a trademark-clearance and
catalog-maintenance obligation before it is a product feature (§10.9 is explicitly unresolved on
whether it ever happens). The archetype approach also fails gracefully, a user who needs the
exact SKU forks the archetype in the Device Builder in about ninety seconds, and CR-062 makes
that fork keep learning from catalog corrections.

### P2: The catalog exists so the rules have objects to operate on

`ELE-004` (parallel low-Z below the amplifier's minimum load), `ELE-005` (70 V tap sum versus
amplifier rating) and `ELE-006` (constant-voltage speaker on a low-Z output) are three of the
highest-value checks in the product and **none of them can fire unless a speaker exists**, because
`impedanceOhms` lives on the speaker terminal and `tapWatts` lives on the installed transformer
(AC-031). The same argument produced the ISP gateway (present in every North American residential
rack and absent from every draft of this catalog), the F-type ground block (AC-034/m21) and the
IR receiver eye (the destructive-pinout hazard has two ends and only one of them was modelled).

The archetype mix is chosen **residential CI first** (DR-002), those three inclusions are
residential-driven, and commercial capability is carried without ever fronting the picker.

This is why the shipping split is rack-side and field-side archetypes rather than rack-side only;
the counts are in §3.10.

### P3: the template count lives in exactly one place

CR-061 settles a four-way contradiction (58 / 62 / ~40 / "~30–50"). The resolution is not a number
in this paragraph; it is that the count is stated in **exactly one place, the summary table in
§3.10**, and **no prose in any document, including this one, states a template count**. The gate
for shipping a template is AC-052 provenance, not a target: if a template cannot be cited it is cut
and the number in §3.10 goes down.

### P4: Parametric families, and what "parametric" is allowed to vary

A parametric template ships once and presents preset sizes in the picker. The parameter may vary:

| May vary | Example | May **not** vary |
|---|---|---|
| U height | Blank Panel 1U/2U/3U | Signal family of any port |
| Port **count** in a bank | Patch Panel 12/24/48 | Connector type |
| Occupancy side, where the product line genuinely spans it | PDU 1U horizontal / 0U vertical | Direction, except by the `role` parameter below |
| Capacity scalars (VA, PoE budget, channel count) that move together with the count | UPS 1000/1500/3000 VA | `pinoutVariant` |
| **Endpoint role** on an extender kit sold as one part number | HDBaseT Extender TX/RX; AVoIP Endpoint ENC/DEC | anything else |
| **Control bus** on a field device whose bus is a wiring choice | Keypad Cresnet / Lutron QS / Vantage (`F13`, `F19`) | anything else |

The `role` parameter is used **exactly twice** (V06, V07) and both uses are extender halves that
share every physical fact and differ only in port direction.

**The `bus` parameter is DR-121's amendment and is used on the two keypads.** It varies what the
row above forbids, a port's signal family and its connector, and the argument is that this
catalogue is generic: `F13` is not a part number, it is "a keypad", so which bus it speaks is a
wiring choice on one archetype rather than a different product. Before the amendment a keypad
carried every bus it might speak as a separate port, which said the device had three bus
connections when it has one. *Rejected alternative:* four separate
templates, which spends four of thirty rack-side slots on two products.

**A parametric variant is not a template.** RU height is never derived from port count, a 24-port
patch panel ships as both 1U and 2U in the real world and the height is an authored field, not a
computation.

### P5: Every template populates every rollup, or says `unknown` out loud

The always-visible chip strip is **RU, weight, power in VA, outlets** (AC-039). A template that
leaves `weight` null contributes nothing to the weight rollup *and the rollup reports its unknown
count*; it does not silently assume. Per G4 and RJ-007, `typicalWatts` **never** defaults to a
fraction of `nameplateWatts`; a fabricated number that looks authoritative is worse than a dash,
because the failure mode is a user who stops trusting every number in the product.

Consequently every rack-side template in §3 carries, at minimum: `frontU`/`rearU`/`side`,
`mountMethod`, `widthClass`, `bodyDepth`, `weight`, `nameplateWatts`, `typicalWatts`, and, where
the device is heavy enough to matter, `maxUnsupportedMass` (AC-028).

### P6: Power is authored in VA and permille power factor, not in watts alone

`PowerProfile` carries `nameplateWatts`, `typicalWatts`, `standbyWatts`, `nominalVolts`,
`apparentVA` and `powerFactor` (permille), CR-056. Circuit loading is computed in **VA** with a
per-category diversity factor (amplifiers default 350‰); nameplate becomes an advisory second
line (AC-020). Every amplifier and every UPS in this catalog therefore carries a real
`powerFactor`, because a linear-supply amplifier at PF 0.65 under-reports current by 35% under a
naive `watts / 120`, which is precisely how a rack that "calculated fine" trips a breaker.

`btuPerHour` is **derived**, never stored, from `typicalWatts × kBtuPerWattHour` where
`kBtuPerWattHour = 3.412142` (CR-005); `btuPerHourOverride` exists only for the rare manufacturer
figure that disagrees with the arithmetic.

### P7: Three orthogonal axes on every port, and never one enum

`Port.connector` and `Port.signalFamily` are independent fields, and `Link.media` is a third
(canon §6.1). **`Port.carriedProtocols` was a third such field until DR-134 §11.133 deleted it**,
and nothing in this document's argument rests on it: the checkable claim below is about the
family, which is the field the rule reads. RJ45 is a **connector**; Cat6a is a **medium**; Ethernet,
HDBaseT, Dante and Cresnet are **signal families** that share both. Every catalog entry that puts
HDBaseT on an RJ45 is therefore expressing something the model can check: `SIG-001` (HDBaseT
output patched into an Ethernet switch port) is the single highest-value validation in the
product, it is only expressible because the axes are separate, and it is only *reachable* because
this catalog ships a matrix with `video.hdbaset` on `conn.rj45` next to a switch with
`net.ethernet` on `conn.rj45`.

### P8: Realistic I/O, including the ports nobody enjoys modelling

The domain-realism review is taken as binding where it says a device's I/O was modelled
unrealistically. Concretely, and each of these is present in §3:

| Realism requirement | Where it lands | Ruling |
|---|---|---|
| A matrix has HDBaseT **and** mirrored HDMI outputs, de-embedded audio, per-output IR, IR in, LAN, RS-232 and an IEC inlet, not four ports | V01 | AC-031 |
| An external power brick still consumes a PDU outlet; a DC barrel inlet is a real port | V03, V05, C02 | AC-031 |
| The AVR's phono ground lug is a real conductor that appears on the schedule | A02 | AC-034/m21 |
| Receiver and emitter 3.5 mm jacks are **not** interchangeable and every one carries `pinoutVariant` | C02, V01, all IR | AC-052 |
| Exactly one RF splitter output passes DC toward the source | R01, R02 | canon §6.4 |
| A 24-port patch panel eats **rear** RU and its rear ports are 110 punchdown, not RJ45 | N03 | CR-057 |
| Redundant PSUs are two inlets, and each consumes an outlet | N01/48-port, S02 | AC-020 |
| A 3U UPS at 42 kg instantly blows a wall-rack rating and needs rear support | P03 | AC-028 |
| Speakers carry `impedanceOhms`; CV speakers carry a `tapWatts` **selector**, because the tap is a property of the installation, not of the model | F04–F08 | canon §6.4 |
| A power sequencer's outlets carry `seq` step and delay so `SEQ-001` can fire | P02 | AC-033 |

### P9: Banks are presentation; port sets are electrical; they are two concepts

`BankDef` (`key, label, abbr, symbolSide, collapseInSymbol, order`) drives symbol edge assignment,
brackets, collapse, and the auto panel layout. `PortSetDef` drives Y/Pb/Pr, L/R, +/−, and
`atomicConnect` (CR-055). Every catalog entry declares banks; entries with stereo pairs, speaker
polarity pairs or component video additionally declare port sets, because the v1 multi-conductor
**gesture** covers `atomicConnect` sets only (AC-053, RJ-016).

*Rejected alternative:* one `PortGroupDef` doing both jobs, which has no field for `symbolSide`
and no way to say "these three ports connect as one gesture".

### P10: Zero-authoring rear panels, and the CI test that makes the claim true

Auto panel layout flows connectors within `TemplateBody.chassisWidth`, default **432 mm** for
`widthClass: full`, *not* 482.6 mm, which is the panel width including ears and would draw jacks
out past the rails on the view that gets taped inside the rack door (AC-032). Every
`ConnectorTypeDef` referenced by a shipped template must have a footprint entry, asserted in CI
(AC-050/A2.2). `connectorProjection` is **derived from the deepest rear connector actually on the
panel**, never `bodyDepth + 75 mm`, a moulded HDMI plug with a bend is 100–125 mm.

### P11: Seeded templates are read-only, and the fork keeps learning

Editing a seeded template silently performs duplicate-then-edit. The fork records
`derivedFrom{templateId, version}`, and when the catalog later corrects the source the fork shows
a passive badge, *"Based on catalog 'HDMI/HDBaseT Matrix 8×8' v1, the catalog version has since
been corrected (v3). Compare…"* (CR-062). No action is forced, no update is applied, nothing
blocks. v1 binding is **copy-on-place**: the snapshot is embedded at placement and the Update
Manager itself is v1.2 (AC-041).

### P12: Namespaced IDs are canonical; trade names are aliases

Registry IDs are `lower.dotted.snake` and reverse-hierarchical, `video.hdmi.2_1`, `conn.rj45`,
`media.cat6a_futp` (CR-058, N3). The bare trade names the notation in §2 is typed in (`hdmi`,
`hdbt`, `rj45`, `xlr`, `spdif`, `toslink`, `euro3`, `bp`, `db9`) live in
`ConnectorTypeDef.aliases` / `SignalFamilyDef.aliases` and are what the Quick Add DSL resolves
against. `ac-inlet`, used as a signal family in one draft, is re-authored throughout as
`power.ac_iec` + `PortPowerSpec.role: inlet`; **inlet and outlet are not directions** (CR-060).

Two naming consequences that bite the catalog specifically:

1. The multi-zone streaming source is `STRM`, not `STR`, `STR` is the Structure device's system
   prefix and a CI test asserts no catalog template collides with a system prefix (CR-043).
2. `Gender` is `male | female | genderless` only. `jack` and `plug` are deleted; a jack is a
   female panel connector and a plug is male, and `ConnectorTypeDef.genderApplies` decides whether
   `CON-002` evaluates at all (CR-059).

---

## 2. The compact port notation

The catalog in §3 is authored in a one-line-per-bank notation. It is not decorative shorthand: it
is the **same grammar the Device Builder's Quick Add field parses**, so a catalog entry can be
pasted into the builder and produce the identical bank, and the seed-file generator reads these
lines to emit `.rmdev`. A round-trip test asserts that.

### 2.1 Grammar

```text
port-spec   := qty "x" SP head [ "-" dir ] [ "(" face ")" ]
                        [ SP label ] [ SP "@" bank ] [ SP "[" mods "]" ]

qty         := INTEGER ≥ 1
head        := alias | connector-id "/" family-id
dir         := "IN" | "OUT" | "BI" | "BUS" | "PAS"
face        := "rear" | "front" | "both"
label       := '"' label-pattern '"'
bank        := IDENT | '"' free text '"'
mods        := mod ( "," SP? mod )*
```

Everything except `qty` and `head` is optional. Omissions take documented defaults; nothing is
inferred silently from a heuristic.

| Element | Default when omitted | Notes |
|---|---|---|
| `dir` | the alias's `defaultDirection` from `SignalFamilyDef` | `hdmi` defaults `IN`; `hdbt` defaults `OUT`; `c14` defaults `IN` |
| `face` | `rear` | `front` and `both` are always written explicitly |
| `label` | the alias's display tag plus the direction word plus `{n}` when `qty > 1` | e.g. `8x HDMI-IN` labels `HDMI IN 1`…`HDMI IN 8` |
| `bank` | auto-named `"{family display name} {direction plural}"`, "HDMI Inputs", "Speaker Outputs" | colliding names get a numeric suffix; renaming a bank never touches port labels |
| `mods` | none | every modifier is a typed field on `PortDef`, never a free-text note |

### 2.2 Direction: five values, five letters

CR-060 is load-bearing here and it fixed a real defect: an earlier catalog notation used `p` for
both "passive" and "bus node", collapsing two enum values that `DIR-002`, `BUS-001`, `BUS-002` and
the multi-drop stub glyph all read.

| Written | `PortDirection` | Letter | Means |
|---|---|---|---|
| `IN` | `sink` | `i` | Signal enters the device |
| `OUT` | `source` | `o` | Signal leaves the device |
| `BI` | `bidirectional` | `b` | Genuinely two-way (Ethernet, RS-232, USB) |
| `BUS` | `busNode` | `n` | A node on a shared multi-drop medium (Cresnet, DMX thru, RS-485, CV speaker tap) |
| `PAS` | `passive` | `p` | No active circuit: a splitter leg, a patch-panel jack, a ground lug |

`BUS` versus `PAS` is the distinction that lets an RF splitter output (`PAS`, one physical tee)
and a Cresnet drop (`BUS`, a unit load against a 32-load budget) behave differently under the same
"more than one thing connects here" question.

**Power is never a direction.** `1x C14-IN` is `signalFamily: power.ac_iec`,
`direction: sink`, `PortPowerSpec.role: inlet`. `8x 5-15R-OUT` is `power.ac_branch`,
`direction: source`, `role: outlet`. There is no `ac-inlet` family (CR-058, CR-060).

### 2.3 Aliases: the head token

The head resolves through `ConnectorTypeDef.aliases` and `SignalFamilyDef.aliases` to a
`(connector, signalFamily)` pair. **Resolution is aggressive and it is the whole point of the
three-axis split**: `rj45` and `hdbt` resolve to the same connector and different families:

| Alias | Connector | Signal family | Also sets |
|---|---|---|---|
| `hdmi` | `conn.hdmi_a` | `video.hdmi.2_0` | — |
| `hdmi21` | `conn.hdmi_a` | `video.hdmi.2_1` | — |
| `hdbt` | `conn.rj45` | `video.hdbaset` | `topologyFree: false`; `acceptedFamilies` **excludes** `net.ethernet` |
| `avoip` | `conn.rj45` | `video.avoip` | — |
| `rj45` | `conn.rj45` | `net.ethernet` | — |
| `sfp+` | `conn.sfp_cage` | `net.ethernet` | `sfp: sfpPlus`, `linkSpeedMbps: 10000` |
| `lc` | `conn.lc_duplex` | `net.fiber_sm` | `fiberMode: singlemode` |
| `rca` | `conn.rca` | `audio.line_unbal` | — |
| `spdif` | `conn.rca75` | `audio.spdif_coax` | `impedanceOhms: 75` |
| `toslink` | `conn.jis_f05` | `audio.spdif_optical` | — |
| `xlr` | `conn.xlr3` | `audio.line_bal` | `balanced: true`; gender from direction (`OUT` ⇒ male, `IN` ⇒ female) |
| `aes` | `conn.xlr3` | `audio.aes3` | `impedanceOhms: 110` |
| `euro2` `euro3` `euro5` | `conn.euroblock_2/_3/_5` | `audio.line_bal` (3/5) · `audio.speaker_lowz` (2) | — |
| `bp` | `conn.binding_post` | `audio.speaker_lowz` | — |
| `cv` | `conn.euroblock_2` | `audio.speaker_cv` | `nominalVoltage: 70` |
| `dante` | `conn.rj45` | `audio.dante` | — |
| `ir` | `conn.3_5mm_ts` | `ctl.ir_emitter` | `pinoutVariant` **required** |
| `irrx` | `conn.3_5mm_trs` | `ctl.ir_receiver` | `pinoutVariant` **required** |
| `ird` | `conn.3_5mm_ts` | `ctl.ir_direct` | `pinoutVariant` **required** |
| `232` / `db9` | `conn.de9` | `ctl.rs232` | `SerialSpec.role` required |
| `485` | `conn.euroblock_3` | `ctl.rs485` | — |
| `dmx` | `conn.xlr5` | `ctl.dmx512` | — |
| `cresnet` | `conn.phoenix_4` | `ctl.cresnet` | `topologyFree: true` |
| `cc` | `conn.euroblock_2` | `ctl.contact` | — |
| `trg` | `conn.3_5mm_ts` | `ctl.trigger12v` | `maxCurrentMa: 100`; **mono plug**: a stereo plug shorts ring to sleeve |
| `f` | `conn.f_type` | `rf.catv` | `impedanceOhms: 75` |
| `sat` | `conn.f_type` | `rf.satellite` | — |
| `ota` | `conn.f_type` | `rf.ota` | — |
| `c13` `c14` `c19` `c20` | `conn.iec_c13/_c14/_c19/_c20` | `power.ac_iec` | `role` from direction |
| `5-15p` `5-15r` `5-20p` `5-20r` `l5-30p` | `conn.nema_*` | `power.ac_branch` | `role` from direction |
| `dc` | `conn.barrel_dc` | `power.dc_low` | `nominalVoltage: 12` |
| `gnd` | `conn.ground_lug` | `power.bonding` | — |
| `110` | `conn.punchdown_110` | `net.ethernet` | patch-panel rear |

The explicit form `conn.rj45/audio.dante` is always available and is what the generator emits when
an alias would be ambiguous. Aliases exist for typing speed; **the file never stores one**.

### 2.4 Label patterns and auto-numbering

The label pattern is the silkscreen text. It is expanded once, at bank creation, across the `qty`
rows in order.

| Token | Expands to | `qty = 8` example |
|---|---|---|
| `{n}` | sequential integer from `start`, step `step` | `1 2 3 4 5 6 7 8` |
| `{n:2}` | zero-padded to width 2 | `01 02 … 08` |
| `{n@k}` | increments every *k* rows | `k=2` ⇒ `1 1 2 2 3 3 4 4` |
| `{rev}` | descending | `8 7 6 5 4 3 2 1` |
| `{A}` | alpha sequence, rolling to `AA` | `A B C D E F G H` |
| `{L,R}` | cycling literal set, period = set size | `L R L R L R L R` |
| `{a,b,c}@p` | cycling set with an **explicit period** | `{+,−}@1` ⇒ `+ − + − …` |
| literal text | passes through | `HDBT OUT {n}` |

`start` and `step` default to 1 and 1 and are exposed as numeric fields beside the pattern in the
builder.

**The explicit period is not optional syntax sugar.** AC-050/A2.5 found that the original grammar
could not express its own catalog: the AVR's speaker bank needs two cycling sets advancing at
different rates simultaneously, seven channel names each taken for two consecutive rows, against
a `+`/`−` polarity alternating every row. Written correctly:

```text
14x BP-OUT "{FL,FR,C,SL,SR,SBL,SBR}@2 {+,−}@1"   @"Speaker Outputs"
```

which expands to `FL +`, `FL −`, `FR +`, `FR −`, … `SBR +`, `SBR −`. Without `@p` the two sets
both advance per row and the bank is wrong from row two.

### 2.5 Designator auto-numbering

Labels are silkscreen; **designators are identity** and they are not the same thing.

- `PortDef.designatorHint` in the template is a **seed only** (CR-042).
- `Port.designator` is allocated at instantiation from `ProjectSettings.portDesignatorFormat`,
  default `J{PORT_SEQ:2}` ⇒ `J01`, `J02`, …, **unique within the device**, not project-wide.
- Allocation order is template port order, which is `PortDef.order` (a `FracIndex`, CR-027), which
  is the order the banks and rows appear in the notation. Reordering rows in the builder is
  therefore semantic: it moves designators, symbol pin order, and panel auto-layout together.
- A port is always cited as `MTX-1:J09`, so project-wide port uniqueness buys nothing. The AV
  block scheme `{DEV_BLOCK}{PORT_SEQ:2}` ⇒ `2301` ships as a preset for commercial work.
- Every designator is **evaluated once at creation and stored** (CR-048). Nothing is recomputed at
  render time; changing a scheme offers a renumber with a diff and never touches a locked ID.

### 2.6 Modifiers

Each modifier writes one typed field on `PortDef` or one of its sub-records. There is no
free-text modifier; a value that has no field is a spec bug, not a note.

| Modifier | Field written | Notes |
|---|---|---|
| `[z75]` `[z110]` `[z120]` | `impedanceOhms` | **Safety-adjacent**: must be cited. RCA carrying `audio.spdif_coax` without `z75` is a live builder warning |
| `[Ω8]` `[Ω4]` | `impedanceOhms` on a speaker terminal | Feeds `ELE-004` |
| `[pin:NAME]` | `pinoutVariant` | **Mandatory on every 3.5 mm IR port.** Values: `xantech-stereo` (tip signal / ring GND / sleeve +12 V), `mono-tip-sleeve` (tip IR / sleeve GND) |
| `[poe:STD/ROLE]` | `PoeSpec{standard, role}` | `af` `at` `bt-t3` `bt-t4`; `pse` or `pd`. Adds `/cN` for class |
| `[poh:pse]` `[poh:pd]` | `PoeSpec` on `net.poh` | HDBaseT power, **not** interoperable with a standard PoE PSE |
| `[budget:N]` | `PowerProfile.poeBudgetWatts` (device-level) | `NET-001` depends on it; safety-adjacent |
| `[dte]` `[dce]` | `SerialSpec.role` | Straight versus null-modem is determined by *both* ends' roles and surfaces as `Link.crossover` |
| `[dcpass]` | `requiresPowerPassingPort` satisfied on this port | Exactly one splitter output; wire the wrong one and the LNB never powers |
| `[tap:2.5\|5\|10\|15\|20]` | `Port.tapWatts` **selector list** | The chosen tap is per installation, not per device |
| `[pol:+]` `[pol:−]` | `Polarity` on the terminal | On the terminal so a typo is inexpressible (AC-030) |
| `[set:KEY/ROLE]` | `PortDef.setKey`, `setRole` | Declares membership of a `PortSetDef` |
| `[atomic]` | `PortSetDef.atomicConnect: true` | Three ports, one gesture, one Link with three conductors |
| `[pair:1:1]` | `PassthroughPairDef{frontKey, rearKey, sameNet}` | Written by the "Pair front↔rear by order" action; a passthrough template with missing pairs is a **load warning**, not an error (CR-057) |
| `[seq:N/Dms]` | `PortPowerSpec.sequenceStep`, `sequenceDelayMs` | Feeds `SEQ-001` |
| `[ups]` `[surge]` `[unswitched]` | `PortPowerSpec.outletMode` / `backing` | Distinguishes battery-backed from surge-only outlets |
| `[loop]` | `PortDef.notes` is *not* used. **Set `carriedProtocols` passthrough intent until DR-134 deleted that field**; a loop-out's family already says what it carries | A loop-out is a real port with a real link |
| `[arc]` `[earc]` | `ReturnChannel` | The only place `→ (+ARC ↔)` in canon §6.4 becomes model state |
| `[1G]` `[10G]` `[25G]` | `linkSpeedMbps` | |
| `[sfp]` `[sfp+]` `[sfp28]` | `SfpFormFactor` | |
| `[om3]` `[om4]` `[os2]` | `fiberMode`, `wavelengthNm` | A/B pair polarity is `Link.crossover: fiberPolarityAB`, not a port field |
| `[term]` | `requiresTermination` acknowledged on this node | RS-485 and DMX: 120 Ω at *both* ends only |
| `[phantom]` | `phantomPowerCapable` | |
| `[bal]` | `balanced: true` | Implied by `xlr` and `euro3`; written where the alias does not imply it |
| `[gnd]` | `signalFamily: power.bonding` | The AVR phono ground lug: a real conductor on the schedule |

### 2.7 Worked reading of one line

```text
8x HDBT-OUT(rear) "HDBT OUT {n}" @"HDBaseT Outputs" [poh:pse]
```

reads as: eight ports; connector `conn.rj45`; signal family `video.hdbaset`;
`direction: source`; `face: rear`; labels `HDBT OUT 1`…`HDBT OUT 8`; designators allocated
`J09`…`J16` if this is the second bank on a device whose first bank held eight ports; bank
`HDBaseT Outputs` with `symbolSide: right`; `PoeSpec{standard: poh, role: pse}` on each port,
which is what lets `NET-001` flag a Type-4 PD on a Type-2 PSE and what lets `SIG-001` refuse
this port's link into a `net.ethernet` switch port with a spring-back reason chip and a
`[ Connect anyway ]` (CR-017, *the gesture may hesitate; the document may not lie*).

---

## 3. The catalog

### 3.0 How to read the entries

Each category opens with a summary table and then gives one block per template: a header line and
the port list in the §2 notation.

**Header line format:**

```text
Vnn · Display Name — `TYPE_PREFIX` · occupancy · depth class · weight · nameplate/typical W · PF
```

**Depth class** is a *display bucket*, derived at render time from
`bodyDepth + connectorProjection`. It is not a stored field, the stored fields are `bodyDepth`
and `connectorProjection`, both `Len`, both in nanometres in the file (CR-001, CR-063).

| Class | `bodyDepth + connectorProjection` | Typical home |
|---|---|---|
| `shallow` | ≤ 250 mm | Wall boxes, 12–14 in credenza racks |
| `standard` | 250–400 mm | Most residential gear |
| `deep` | 400–550 mm | Amplifiers, UPS, NAS |
| `extraDeep` | > 550 mm | Server-class; needs a 4-post enclosure |
| `none` | — | `mountMethod: notInRack`, field devices carry no rack depth |

**Occupancy** is written `{frontU, rearU, side}` (CR-036, a struct, never a scalar). `side` is
`front | rear | both | zeroUVertical | none`. `hosted` means `mountMethod: hosted` (it lives on a
shelf and consumes the shelf's capacity, not rail holes); `notInRack` means occupancy zero and no
rack depth at all.

**Weight** is displayed in kg; the file stores `weightUg` in micrograms (CR-003). **`maxUnsup`**
is `maxUnsupportedMass`, the mass above which front-ear mounting alone is insufficient and
`RCK-013` warns (AC-028); it defaults to 7 kg for `mountMethod: rackEars`.

**PF** is `powerFactor` in permille. Switch-mode supplies are ~950‰; linear-supply amplifiers are
~650‰ and that difference is why circuit loading is computed in VA (CR-056, AC-020).

---

### 3.1 Video Distribution & Switching: 7

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PF | Ports |
|---|---|---|---|---|---|---|---|---|
| V01 | HDMI/HDBaseT Matrix 8×8 | `MTX` | `{3,3,both}` | standard | 7.3 kg | 90 / 55 | 950 | 44 |
| V02 | HDMI Matrix 4×4 | `MTX` | `{1,1,both}` | standard | 5.4 kg | 30 / 18 | 950 | 20 |
| V03 | HDMI Matrix 16×16 | `MTX` | `{4,4,both}` | deep | 14.1 kg | 180 / 110 | 950 | 52 |
| V04 | HDMI Distribution Amplifier 1×N *(param 1×4, 1×8)* | `DA` | `{1,1,both}` | shallow | 2.3 kg | 25 / 15 | 900 | 10 |
| V05 | Presentation Switcher / Scaler 4×1 | `SCL` | `{1,1,both}` | shallow | 3.6 kg | 45 / 28 | 950 | 12 |
| V06 | HDBaseT Extender *(param role: TX, RX)* | `TX` / `RX` | hosted / `notInRack` | shallow / none | 0.55 kg | 12 / 8 · 0 / 0 | 900 | 7 / 6 |
| V07 | AVoIP Endpoint *(param role: ENC, DEC)* | `ENC` / `DEC` | hosted | shallow | 0.7 kg | 12 / 9 | — | 8 / 6 |

---

**V01 · HDMI/HDBaseT Matrix 8×8**: `MTX` · `{3, 3, both}` · standard (330 mm + 68 mm) ·
7.3 kg · 90 / 55 W · PF 950 · `maxUnsup` 7 kg

This is the flagship entry and the worked example in §6. It is also the reason `SIG-001` is
reachable: it puts `video.hdbaset` on `conn.rj45` in the same project as a switch that puts
`net.ethernet` on `conn.rj45`.

```text
8x HDMI-IN            "HDMI IN {n}"          @"HDMI Inputs"
8x HDBT-OUT           "HDBT OUT {n}"         @"HDBaseT Outputs"        [poh:pse]
8x HDMI-OUT           "HDMI OUT {n}"         @"Mirrored HDMI Outputs"
8x EURO3-OUT          "AUD OUT {n}"          @"Zone Audio"             [bal]
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
8x IR-OUT             "IR OUT {n}"           @Control                  [pin:mono-tip-sleeve]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x C14-IN             "AC IN"                @Power
```

> The mirrored HDMI outputs are not padding. A real 8×8 with HDBaseT distribution mirrors every
> zone to a local HDMI jack for the rack-adjacent display and for commissioning, and an integrator
> who cannot draw that connection will not believe the rest of the catalog. Per AC-031 the
> de-embedded zone audio, the eight IR outputs and the single IR input are equally
> non-negotiable — a matrix modelled as 8 in + 8 out is a shape, not a device.

**V02 · HDMI Matrix 4×4**: `MTX` · `{1, 1, both}` · standard (280 mm + 62 mm) · 5.4 kg ·
30 / 18 W · PF 950

```text
4x HDMI-IN            "HDMI IN {n}"          @"HDMI Inputs"
4x HDMI-OUT           "HDMI OUT {n}"         @"HDMI Outputs"
4x SPDIF-OUT          "AUDIO OUT {n}"        @"De-embedded Audio"      [z75]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x DC-IN              "12V DC IN"            @Power
```

> ⚠ External power brick. Its `DC-IN` inlet counts one outlet until a cord says otherwise
> (DR-171) — a wall wart still eats a PDU
> outlet, and the outlet rollup in the chip strip is wrong if the template pretends otherwise.

**V03 · HDMI Matrix 16×16**: `MTX` · `{4, 4, both}` · deep (430 mm + 72 mm) · 14.1 kg ·
180 / 110 W · PF 950 · `maxUnsup` 7 kg · `requiresClearanceAboveU: 1`

```text
16x HDMI-IN           "HDMI IN {n:2}"        @"HDMI Inputs"
16x HDMI-OUT          "HDMI OUT {n:2}"       @"HDMI Outputs"
16x EURO3-OUT         "AUD OUT {n:2}"        @"De-embedded Audio"      [bal]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x C14-IN             "AC IN"                @Power
```

**V04 · HDMI Distribution Amplifier 1×N**: `DA` · `{1, 1, both}` · shallow (180 mm + 60 mm) ·
2.3 kg · 25 / 15 W · PF 900 · *parametric: `outputs ∈ {4, 8}`*

```text
1x HDMI-IN            "HDMI IN"              @Input
8x HDMI-OUT           "HDMI OUT {n}"         @Outputs
1x DC-IN              "12V DC IN"            @Power
```

**V05 · Presentation Switcher / Scaler 4×1**: `SCL` · `{1, 1, both}` · shallow (230 mm + 66 mm) ·
3.6 kg · 45 / 28 W · PF 950

The commercial-room entry. It is the only rack-side template carrying `video.usbc_dpalt` and the
only one with a front-face service port, which exercises `face: front` in the auto panel layout.

```text
3x HDMI-IN            "HDMI IN {n}"          @"Video Inputs"
1x USBC-IN            "USB-C IN"             @"Video Inputs"
1x HDMI-OUT           "HDMI OUT"             @"Video Outputs"
1x HDBT-OUT           "HDBT OUT"             @"Video Outputs"          [poh:pse]
1x RCA-IN             "AUDIO IN"             @Audio
1x EURO5-OUT          "AUDIO OUT"            @Audio                    [bal]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x USBA-BI(front)     "SERVICE"              @Control
1x C14-IN             "AC IN"                @Power
```

**V06 · HDBaseT Extender**: `TX` / `RX` · *parametric `role ∈ {transmitter, receiver}`*

One template, two roles, per P4. An extender is sold as one kit part number and the halves share
every physical fact; two templates would spend two of thirty rack-side slots on one product.
*Rejected alternative:* separate `TX` and `RX` templates.

`role: transmitter`, `TX` · hosted, `hostedHeightU: 1`, half-width · shallow (110 mm + 55 mm) ·
0.55 kg · 12 / 8 W · PF 900

```text
1x HDMI-IN            "HDMI IN"              @Video
1x HDMI-OUT           "HDMI LOOP OUT"        @Video                    [loop]
1x HDBT-OUT           "HDBT OUT"             @Video                    [poh:pse]
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x IR-OUT             "IR OUT"               @Control                  [pin:mono-tip-sleeve]
1x conn.3_5mm_trs/ctl.rs232-BI  "RS-232"     @Control                  [dte]
1x DC-IN              "12V DC IN"            @Power
```

`role: receiver`, `RX` · `notInRack` · none · 0.55 kg · 0 / 0 W (PoH-powered)

```text
1x HDBT-IN            "HDBT IN"              @Video                    [poh:pd]
1x HDMI-OUT           "HDMI OUT"             @Video
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x IR-OUT             "IR OUT"               @Control                  [pin:mono-tip-sleeve]
1x conn.3_5mm_trs/ctl.rs232-BI  "RS-232"     @Control                  [dte]
1x DC-IN              "12V DC IN (opt)"      @Power
```

> The receiver draws 0 W from the rack and consumes no outlet once its run is drawn (DR-171) — its
> power comes down the
> `net.poh` conductor from the transmitter. That is a genuinely different power topology from
> everything else in the catalog and the power rollup has to get it right, which is why `net.poh`
> is its own family with its own glyph rather than a flag on `net.poe`.

**V07 · AVoIP Endpoint**: `ENC` / `DEC` · *parametric `role ∈ {encoder, decoder}`* · hosted,
half-width · shallow (125 mm + 55 mm) · 0.7 kg · 12 / 9 W (802.3af PD)

```text
# role: encoder — ENC
1x HDMI-IN            "HDMI IN"              @Video
1x HDMI-OUT           "HDMI LOOP OUT"        @Video                    [loop]
1x AVOIP-BI           "NETWORK"              @Network                  [poe:af/pd/c3]
1x RCA-IN             "ANALOG IN"            @Audio
1x RCA-OUT            "ANALOG OUT"           @Audio
1x IR-OUT             "IR OUT"               @Control                  [pin:mono-tip-sleeve]
1x conn.3_5mm_trs/ctl.rs232-BI  "RS-232"     @Control                  [dte]
1x DC-IN              "12V DC IN (opt)"      @Power

# role: decoder — DEC
1x AVOIP-BI           "NETWORK"              @Network                  [poe:af/pd/c3]
1x HDMI-OUT           "HDMI OUT"             @Video
1x RCA-OUT            "ANALOG OUT"           @Audio
1x IR-OUT             "IR OUT"               @Control                  [pin:mono-tip-sleeve]
1x conn.3_5mm_trs/ctl.rs232-BI  "RS-232"     @Control                  [dte]
1x DC-IN              "12V DC IN (opt)"      @Power
```

---

### 3.2 Audio: 6

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PF | Ports |
|---|---|---|---|---|---|---|---|---|
| A01 | Multi-Zone Amplifier, N-channel *(param 8, 16)* | `AMP` | `{2,2,both}` / `{3,3,both}` | deep | 10.0 / 17.2 kg | 400 / 180 · 800 / 340 | 650 | 24 / 32 |
| A02 | AV Receiver, 7.2-channel | `AVR` | hosted, `hostedHeightU: 4` | deep | 11.8 kg | 750 / 280 | 680 | 47 |
| A03 | DSP Audio Processor, 8×8 + Dante | `DSP` | `{1,1,both}` | standard | 4.1 kg | 60 / 35 | 950 | 34 |
| A04 | Stereo Power Amplifier, 2×200 W | `AMP` | `{2,2,both}` | deep | 15.4 kg | 900 / 380 | 650 | 9 |
| A05 | 70 V/100 V Commercial Amplifier, 2×250 W | `AMP` | `{2,2,both}` | deep | 12.7 kg | 700 / 300 | 650 | 8 |
| A06 | Multi-Zone Streaming Source, 4-stream | `STRM` | `{1,1,both}` | standard | 3.2 kg | 35 / 20 | 950 | 17 |

Every amplifier in this category carries `powerFactor: 650` and
`requiresClearanceAboveU: 1`. Between them they populate the loading arithmetic that AC-020
rescued: the five-device theatre stack in the domain-realism review (16-ch amp + stereo amp + AVR
+ 24-port switch + matrix) totals 2 990 W nameplate (24.9 A on 120 V, 55% over a 20 A circuit's
continuous limit) and is a perfectly ordinary rack. Computed the canonical way, in VA with a
350‰ diversity factor on amplifiers, it lands where the trade knows it lands, `PWR-001` is a
**warning** with a printed acknowledgement, and nothing blocks the PDF (CR-022, G3).

---

**A01 · Multi-Zone Amplifier, N-channel**: `AMP` · *parametric `channels ∈ {8, 16}`* ·
`{2,2,both}` (8-ch) / `{3,3,both}` (16-ch) · deep (380 mm + 95 mm) · 10.0 / 17.2 kg ·
400 / 180 W · 800 / 340 W · PF 650 · `maxUnsup` 7 kg · `requiresClearanceAboveU: 1`

The 16-channel variant shown. `nameplateWatts` is the UL thermal rating that assumes every channel
driven to clipping into rated loads simultaneously; `typicalWatts` is the number circuit loading
uses, and per RJ-007 and G4 it is **authored and cited**, never derived as a fraction of
nameplate.

```text
16x RCA-IN            "SRC {n@2} {L,R}"      @"Source Inputs"          [set:src{n@2}/{L,R}]
16x EURO2-OUT         "ZONE {n@2} {+,−}@1"   @"Zone Speaker Outputs"   [Ω8, set:zone{n@2}/{+,−}@1, atomic]
2x RCA-OUT            "SUB OUT {n}"          @"Sub Outputs"
8x IRRX-IN            "ZONE {n} IR"          @Control                  [pin:xantech-stereo]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x TRG-IN             "TRIGGER IN"           @Control
1x TRG-OUT            "TRIGGER OUT"          @Control
1x 5-20P-IN           "AC (captive cord)"    @Power
```

> The 20 A plug on the 16-channel variant is deliberate and it is a design constraint the drawing
> must carry: a `conn.nema_5_20p` cannot be landed in a 5-15R PDU outlet, so the outlet map on the
> power schedule has to reject the pairing rather than silently draw it.
>
> The zone outputs declare a `PortSetDef` per zone with `atomicConnect` — a stereo speaker pair on
> one 16/4 pull is one gesture, one `Link`, four `Conductor`s, and polarity lives on the terminal
> so an inverted-polarity typo is inexpressible (AC-030, AC-053, RJ-016).

**A02 · AV Receiver, 7.2-channel**: `AVR` · hosted, `hostedHeightU: 4` · deep (380 mm + 110 mm) ·
11.8 kg · 750 / 280 W · PF 680

The densest template in the catalog at 47 ports, and it is the one that proves the compact
notation. It is also where the phono ground lug lives, a real `power.bonding` conductor that
appears on the schedule, not a footnote (AC-034/m21).

```text
7x HDMI21-IN          "HDMI IN {n}"          @"HDMI Inputs"
1x HDMI-IN(front)     "HDMI FRONT"           @"HDMI Inputs"
1x HDMI21-OUT         "HDMI OUT MAIN"        @"HDMI Outputs"           [earc]
2x HDMI-OUT           "HDMI OUT ZONE {n}"    @"HDMI Outputs"
2x TOSLINK-IN         "OPTICAL IN {n}"       @"Digital Audio In"
2x SPDIF-IN           "COAX IN {n}"          @"Digital Audio In"       [z75]
8x RCA-IN             "ANALOG IN {n@2} {L,R}" @"Analog Audio In"       [set:an{n@2}/{L,R}]
2x conn.rca/audio.phono-IN  "PHONO {L,R}"    @"Analog Audio In"        [set:phono/{L,R}]
1x GND-PAS            "PHONO GND"            @"Analog Audio In"        [gnd]
14x BP-OUT            "{FL,FR,C,SL,SR,SBL,SBR}@2 {+,−}@1"  @"Speaker Outputs"  [Ω8, set:spk{n@2}/{+,−}@1, atomic]
2x conn.rca/audio.sub-OUT  "SUB PRE OUT {n}" @"Speaker Outputs"
1x OTA-IN             "FM ANTENNA"           @Tuner
1x RJ45-BI            "LAN"                  @Control
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
2x TRG-OUT            "TRIGGER OUT {n}"      @Control
1x 232-BI             "RS-232"               @Control                  [dte]
1x USBA-BI(front)     "USB"                  @Control
1x conn.6_35mm_trs/audio.headphone-OUT(front)  "PHONES"  @Control
1x 5-15P-IN           "AC (captive cord)"    @Power
```

**A03 · DSP Audio Processor, 8×8 + Dante**: `DSP` · `{1,1,both}` · standard (300 mm + 70 mm) ·
4.1 kg · 60 / 35 W · PF 950

The commercial-audio anchor. It is the only rack-side template carrying `audio.dante` and
`audio.aes3`, which makes the AES/EBU-versus-mic-cable distinction reachable: both are XLR3, and
`audio.aes3` is 110 Ω STP where `audio.mic` is not, the identical connector is exactly why the
impedance field is safety-adjacent and must be cited.

```text
8x EURO3-IN           "IN {n}"               @"Analog Inputs"          [bal, phantom]
8x EURO3-OUT          "OUT {n}"              @"Analog Outputs"         [bal]
2x AES-IN             "AES IN {n}"           @"Digital Audio"          [z110]
2x AES-OUT            "AES OUT {n}"          @"Digital Audio"          [z110]
1x DANTE-BI           "DANTE PRI"            @"Audio Network"
1x DANTE-BI           "DANTE SEC"            @"Audio Network"
1x RJ45-BI            "CONTROL LAN"          @Control
1x 232-BI             "RS-232"               @Control                  [dte]
8x CC-BI              "GPIO {n}"             @Control
1x conn.usb_c/net.ethernet-BI(front)  "CONFIG"  @Control
1x C14-IN             "AC IN"                @Power
```

> Dante uses **PTPv1** and AES67 **PTPv2 (IEEE 1588-2008)**; both want QoS/DSCP and ideally a
> dedicated VLAN. Those facts live on `SignalFamilyDef`, not on this template — the template just
> has to name the right family so the finding can reach it.

**A04 · Stereo Power Amplifier, 2×200 W**: `AMP` · `{2,2,both}` · deep (430 mm + 90 mm) ·
15.4 kg · 900 / 380 W · PF 650 · `maxUnsup` 7 kg · `requiresClearanceAboveU: 1`

At 15.4 kg on front ears only this template fires `RCK-013` the moment it is placed without a
shelf or rear support, which is the check that makes an integrator believe the tool has been in a
rack (AC-028).

```text
2x XLR-IN             "BAL IN {L,R}"         @Inputs                   [bal, set:bal/{L,R}]
2x RCA-IN             "UNBAL IN {L,R}"       @Inputs                   [set:unbal/{L,R}]
4x BP-OUT             "{L,R}@2 {+,−}@1"      @"Speaker Outputs"        [Ω4, set:spk{n@2}/{+,−}@1, atomic]
1x TRG-IN             "TRIGGER IN"           @Control
1x 5-20P-IN           "AC (captive cord)"    @Power
```

**A05 · 70 V/100 V Commercial Amplifier, 2×250 W**: `AMP` · `{2,2,both}` · deep (400 mm + 88 mm) ·
12.7 kg · 700 / 300 W · PF 650 · `maxUnsup` 7 kg · `requiresClearanceAboveU: 1`

The only rack-side source of `audio.speaker_cv`, and therefore the only way `ELE-005` (sum of taps
on a run versus the amplifier's rated output) and `ELE-006` (a CV speaker on a low-Z output) can
ever fire. The CV outputs are `BUS`, not `OUT`: a constant-voltage run is a multi-tap bus, and
that is a `PortDirection`, not a note.

```text
2x EURO3-IN           "IN {A}"               @"Line Inputs"            [bal]
2x EURO3-OUT          "LINK OUT {A}"         @"Link Thru"              [bal, loop]
2x CV-BUS             "70V OUT {A}"          @"CV Speaker Outputs"
1x CC-IN              "MUTE / PRIORITY"      @Control
1x RJ45-BI            "MONITORING"           @Control
1x 5-20P-IN           "AC (captive cord)"    @Power
```

**A06 · Multi-Zone Streaming Source, 4-stream**: `STRM` · `{1,1,both}` · standard (280 mm + 62 mm)
· 3.2 kg · 35 / 20 W · PF 950

`STRM`, not `STR`, `STR` is the Structure device's system prefix and CR-043 resolves the
collision here, with a CI assertion that no catalog `typePrefix` collides with a system prefix.

```text
8x RCA-OUT            "STREAM {n@2} {L,R}"   @"Analog Outputs"         [set:st{n@2}/{L,R}]
4x SPDIF-OUT          "DIGITAL OUT {n}"      @"Digital Outputs"        [z75]
2x RCA-IN             "AUX IN {L,R}"         @"Aux Input"              [set:aux/{L,R}]
1x RJ45-BI            "LAN"                  @Control
1x USBA-BI(front)     "USB"                  @Control
1x C14-IN             "AC IN"                @Power
```

---

### 3.3 Network & Cabling Infrastructure: 4

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PoE budget | Ports |
|---|---|---|---|---|---|---|---|---|
| N01 | PoE Switch, N-port *(param 8, 24, 48)* | `SW` | `{1,1,both}` | standard / deep | 2.7 / 5.0 / 7.7 kg | 150/60 · 450/190 · 900/380 | 130 / 370 / 740 W | 11 / 30 / 54 |
| N02 | Router / Firewall | `FW` | `{1,1,both}` | standard | 4.1 kg | 120 / 55 | — | 14 |
| N03 | Patch Panel, N-port *(param 12, 24, 48)* | `PP` | `{1,0,front}` / `{2,0,front}` | shallow | 0.9–2.3 kg | 0 / 0 | — | 24 / 48 / 96 |
| N04 | Fibre Enclosure / LIU, 24-fibre | `LIU` | `{1,1,both}` | shallow | 2.7 kg | 0 / 0 | — | 36 |

---

**N01 · PoE Switch, N-port**: `SW` · *parametric `ports ∈ {8, 24, 48}`* · `{1,1,both}` ·
standard–deep · 2.7 / 5.0 / 7.7 kg · PF 950 · 48-port variant: `requiresClearanceAboveU: 1`

`poeBudgetWatts` is **safety-adjacent and must be cited** (AC-052) because `NET-001` reads it
directly: a switch's budget is almost always well below `ports × max class`, and the check is
Σ(PD class draw) ≤ budget, plus a Type-4 PD on a Type-2 PSE. The 48-port variant shown.

```text
48x RJ45-BI           "{n:2}"                @"Access Ports"           [poe:bt-t3/pse, 1G, budget:740]
4x SFP28-BI           "SFP28 {n}"            @Uplinks                  [sfp28, 25G]
1x RJ45-BI            "OOB MGMT"             @Management
1x 232-BI(front)      "CONSOLE"              @Management               [dce]
2x C14-IN             "PSU {A,B}"            @Power
```

Variant deltas: the 8-port ships `[poe:at/pse, 1G, budget:130]` with `2x SFP-BI` uplinks and a
single `conn.usb_c` console; the 24-port ships `[poe:at/pse, 1G, budget:370]` with `4x SFP+-BI`.

> Two inlets means two outlets until the cords are drawn (DR-171). Redundant PSUs are two cords and
> two outlets, and a rack
> whose outlet rollup does not know that runs out of PDU on install day.

**N02 · Router / Firewall**: `FW` · `{1,1,both}` · standard (330 mm + 60 mm) · 4.1 kg ·
120 / 55 W · PF 950

```text
2x RJ45-BI            "WAN {n}"              @WAN                      [1G]
8x RJ45-BI            "LAN {n}"              @LAN                      [1G]
2x SFP+-BI            "SFP+ {n}"             @Fibre                    [sfp+, 10G]
1x RJ45-BI            "MGMT"                 @Management
1x 232-BI(front)      "CONSOLE"              @Management               [dce]
1x C14-IN             "AC IN"                @Power
```

**N03 · Patch Panel, N-port**: `PP` · *parametric `ports ∈ {12, 24, 48}`, `heightU ∈ {1, 2}`* ·
`{1,0,front}` or `{2,0,front}` · shallow · 0.9 / 1.4 / 2.3 kg · 0 W · `isPassthrough: true`

```text
24x RJ45-PAS(front)   "{n:2}"                @"Front Jacks"
24x 110-PAS(rear)     "{n:2}"                @"Rear Punchdown"         [pair:1:1]
```

> ⚠ **RU height is an authored field, never derived from port count.** A 24-port panel ships as
> both 1U and 2U in the real world, so `heightU` is a second, independent parameter.
>
> The rear ports are `conn.punchdown_110`, not RJ45 — modelling both faces as RJ45 is the error
> that makes the Termination Schedule wrong on the one column (punch position, T568A/B, conductor
> colour) the trim tech actually needs (AC-025).
>
> `passthroughPairs` is a real array in `.rmdev` (CR-057) with `sameNet: true`, which is what makes
> a trace resolve `Living Room jack → PP-1:F12 → PP-1:R12 → SW-1:J04` as one logical path. A
> passthrough template whose pairs are missing is a **load warning**, not an error.
>
> Patch cords between this panel and a switch auto-classify as `LinkClass.jumper` and are excluded
> from the Pull Sheet by default (AC-026). Nobody schedules patch cords; 110 rows of "6 in Cat6
> patch, blue" buries the 70 rows that describe cable somebody has to pull.

**N04 · Fibre Enclosure / LIU, 24-fibre**: `LIU` · `{1,1,both}` · shallow (240 mm + 55 mm) ·
2.7 kg · 0 W · `isPassthrough: true`

```text
12x LC-PAS(front)     "LC {n:2}"             @"Front Adapters"         [os2]
24x conn.unterminated/net.fiber_sm-PAS(rear)  "SPL {n:2}"  @"Rear Splice Tray"  [os2]
```

---

### 3.4 Control: 3

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PF | Ports |
|---|---|---|---|---|---|---|---|---|
| C01 | Control Processor | `CTL` | `{1,1,both}` | standard | 3.2 kg | 60 / 30 | 950 | 32 |
| C02 | IR Distribution Block | `IRB` | `{1,1,both}` | shallow | 0.9 kg | 12 / 6 | 900 | 22 |
| C03 | RS-232 / IP Gateway, 8-port | `SER` | `{1,1,both}` | shallow | 2.3 kg | 30 / 15 | 950 | 11 |

---

**C01 · Control Processor**: `CTL` · `{1,1,both}` · standard (280 mm + 68 mm) · 3.2 kg ·
60 / 30 W · PF 950

This template carries eight of the ten `ctl.*` families the product ships and is what makes
requirement 4's "IR" and "RS-232" reachable without a second control device.

```text
2x RJ45-BI            "LAN {n}"              @Network
8x conn.euroblock_3/ctl.rs232-BI  "COM {n}"  @Serial                   [dte]
8x IR-OUT             "IR/SERIAL {n}"        @"IR Outputs"             [pin:mono-tip-sleeve]
8x CC-IN              "DIGITAL IN {n}"       @"Digital Inputs"
4x conn.euroblock_3/ctl.contact-OUT  "RELAY {n}"  @Relays
1x CRESNET-BUS        "CRESNET"              @"Control Bus"
1x USBA-BI(front)     "SETUP"                @Control
1x C14-IN             "AC IN"                @Power
```

> `ctl.cresnet` ships with `topologyFree: true` (AC-030). Crestron explicitly supports Cresnet in
> daisy-chain, star **and** home-run topology, and star from a Cresnet supply is the recommended
> residential approach — a star-topology warning that fires on every correctly wired Crestron job
> for the life of the product is worse than no rule. `topologyFree` is a **registry field**, not a
> hard-coded suppression array, so a user can extend it to a proprietary bus.
>
> Cresnet has **two** independent limits — data length (~915 m) and 24 V power drop (18 AWG at
> 20 W ⇒ 333 ft) — which is why `BUS-005` emits two findings, not one.

**C02 · IR Distribution Block**: `IRB` · `{1,1,both}` · shallow (140 mm + 55 mm) · 0.9 kg ·
12 / 6 W · PF 900

```text
1x IRRX-IN            "IR IN (from processor)"  @Source                [pin:xantech-stereo]
4x IRRX-IN            "IR RX {n}"            @"Receiver Inputs"        [pin:xantech-stereo]
16x IR-OUT            "EMITTER {n:2}"        @"Emitter Outputs"        [pin:mono-tip-sleeve]
1x DC-IN              "12V DC IN"            @Power
```

> ⚠ **The pinout hazard is real and destructive, and this template is where it is modelled.**
> Xantech/Niles **receivers** are tip = signal, ring = GND, sleeve = +12 V; **emitters** are
> tip = IR in, sleeve = GND. Plugging an emitter into a receiver jack destroys the emitter and can
> damage the supply. `ctl.ir_emitter` and `ctl.ir_receiver` are therefore separate families with
> separate glyph tags, `PortDef.pinoutVariant` is **mandatory on every 3.5 mm IR port in the
> catalog**, and because it is safety-adjacent a template with an uncited value **does not ship**
> (AC-052). The 3.5 mm connector is physically identical on both, so the model is the only place
> this can be caught.

**C03 · RS-232 / IP Gateway, 8-port**: `SER` · `{1,1,both}` · shallow (230 mm + 62 mm) · 2.3 kg ·
30 / 15 W · PF 950

```text
8x 232-BI             "COM {n}"              @"Serial Ports"           [dte]
1x RJ45-BI            "LAN"                  @Network
1x RJ45-BI            "MGMT"                 @Network
1x C14-IN             "AC IN"                @Power
```

> `ctl.rs232` is **P2P only** — it is the one control family with no multi-drop story. Straight
> versus null-modem is determined by the DTE/DCE role of *both* ends, carried in
> `SerialSpec.role`, and surfaces on the drawing as `Link.crossover`. Two `[dte]` ends wired
> straight is the classic dead-serial-port call, and it is checkable only because the role is a
> field on both ports rather than a note on the cable.

---

### 3.5 Sources: 2

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PF | Ports |
|---|---|---|---|---|---|---|---|---|
| S01 | Cable / Satellite Set-Top Box | `STB` | hosted, `hostedHeightU: 1` | standard | 1.4 kg | 35 / 22 | 900 | 10 |
| S02 | Media Server / NAS | `NAS` | `{2,2,both}` | extraDeep | 13.6 kg | 350 / 160 | 950 | 9 |

---

**S01 · Cable / Satellite Set-Top Box**: `STB` · hosted, `hostedHeightU: 1` · standard
(250 mm + 70 mm) · 1.4 kg · 35 / 22 W · PF 900

The archetype every other consumer source forks from. A streaming player, a UHD disc player and a
game console are each a sixty-second Device Builder job from this template using **Mirror bank**
and a couple of row deletions, which is the tradeoff P3 makes deliberately: fewer, denser,
better-cited templates beat a longer list of near-duplicates.

```text
1x F-IN               "RF IN"                @RF                       [z75]
1x F-PAS              "RF OUT (loop)"        @RF                       [z75, loop]
1x HDMI-OUT           "HDMI OUT"             @Video
2x RCA-OUT            "AUDIO OUT {L,R}"      @Audio                    [set:an/{L,R}]
1x SPDIF-OUT          "COAX DIGITAL"         @Audio                    [z75]
1x TOSLINK-OUT        "OPTICAL"              @Audio
1x RJ45-BI            "LAN"                  @Control
1x USBA-BI            "USB"                  @Control
1x IRRX-IN            "IR IN"                @Control                  [pin:xantech-stereo]
1x 5-15P-IN           "AC (captive cord)"    @Power
```

**S02 · Media Server / NAS**: `NAS` · `{2,2,both}` · extraDeep (560 mm + 80 mm) · 13.6 kg ·
350 / 160 W · PF 950 · `maxUnsup` 7 kg

The only `extraDeep` template in the catalog, and it exists partly to exercise `RCK-012`: front
device depth + rear device depth + a 50 mm cable allowance against the rack's `usableDepth`, over
overlapping RU ranges. Front and rear occupancy are **intervals on the depth axis per (RU, face)**,
not independent booleans, a 560 mm NAS at U18–U19 front and a rear-rail power tray at U19 are
trying to occupy the same air, and the rear door does not close (AC-022).

```text
2x RJ45-BI            "LAN {n}"              @Network                  [1G]
2x SFP+-BI            "SFP+ {n}"             @Network                  [sfp+, 10G]
1x HDMI-OUT           "HDMI"                 @Console
2x USBA-BI            "USB {n}"              @Console
2x C14-IN             "PSU {A,B}"            @Power
```

---

### 3.6 RF / Coax: 2

| ID | Template | Prefix | Occupancy | Depth | Weight | W (name/typ) | PF | Ports |
|---|---|---|---|---|---|---|---|---|
| R01 | RF Splitter Panel, 8-way | `SPL` | `{1,1,both}` | shallow | 0.9 kg | 0 / 0 *(passive)* | — | 9 |
| R02 | Satellite Multiswitch, SWM-16 | `SWM` | `{1,1,both}` | shallow | 2.3 kg | 30 / 22 | 900 | 22 |

RG6 is a **medium**, not a signal, that is the entire point of the three-axis split, so these
two templates are where `rf.catv`, `rf.satellite` and `rf.ota` get objects, and the legend row for
RG6 shows all three families rather than a single meaningless "RG6" swatch (canon §6.6).

---

**R01 · RF Splitter Panel, 8-way**: `SPL` · `{1,1,both}` · shallow (120 mm + 50 mm) · 0.9 kg ·
**0 W, passive** · no power inlet

```text
1x F-PAS              "IN"                   @Input                    [z75]
8x F-PAS              "OUT {n}"              @Outputs                  [z75]
                                                # port 1 additionally: [dcpass]
```

> Loss budget is the design: an 8-way splitter is ≈ −11 dB per port and a 2-way is ≈ −3.5 dB.
> `rf.catv` carries per-device insertion loss so a cascade budget is computable; the cascade rule
> itself is v1.2, but the **data ships in v1** (G5 — cut features, never foundations).
>
> Exactly **one** output is `[dcpass]`. `rf.satellite` carries `requiresPowerPassingPort: true`,
> and wiring a normal splitter leg to the dish means the LNB never powers — a fault that looks
> like a dead receiver and costs a truck roll.
>
> All ports are `PAS` (`passive`), not `OUT`. A splitter leg is a physical tee, not a driven
> output, and `DIR-002` reads the difference.

**R02 · Satellite Multiswitch, SWM-16**: `SWM` · `{1,1,both}` · shallow (230 mm + 55 mm) ·
2.3 kg · 30 / 22 W · PF 900

```text
4x SAT-IN             "SAT IN {n}"           @"LNB Inputs"             [z75, dcpass]
1x OTA-IN             "OTA IN"               @"LNB Inputs"             [z75]
16x SAT-PAS           "SWM OUT {n:2}"        @"Receiver Outputs"       [z75, dcpass]
1x conn.f_type/power.dc_low-IN  "POWER INSERT"  @Power
1x 5-15P-IN           "PSU (captive cord)"   @Power
```

> ⚠ Hard budget: 16 tuners across all 16 outputs, not 16 receivers. That is a count rule
> (`BUS-*` family, v1.2 with its fixture pair), and the template carries `maxDevicesPerSegment` so
> the rule has a number to read when it lands.

---

### 3.7 Power: 3

| ID | Template | Prefix | Occupancy | Depth | Weight | Own draw | Circuit | Ports |
|---|---|---|---|---|---|---|---|---|
| P01 | Rack PDU, N-outlet *(param 1U-8, 2U-16, 0U-24)* | `PDU` | `{1,1,both}` / `{2,2,both}` / `{0,0,zeroUVertical}` | shallow | 3.2 / 5.4 / 6.4 kg | 5 / 8 / 10 W | 20 / 20 / 30 A | 10 / 18 / 26 |
| P02 | Power Conditioner / Sequencer, 2U, 16-outlet | `SEQ` | `{2,2,both}` | standard | 8.2 kg | 12 W | 20 A | 22 |
| P03 | UPS, N VA *(param 1000, 1500, 3000)* | `UPS` | `{1,1,both}` / `{2,2,both}` / `{3,3,both}` | deep | 13.6 / 21.8 / 41.7 kg | — | 15 / 15 / 30 A | 9 / 11 / 14 |

---

**P01 · Rack PDU, N-outlet**: `PDU` · *parametric `{heightU, outlets} ∈ {(1,8), (2,16), (0,24)}`* ·
shallow · 3.2 / 5.4 / 6.4 kg · 5 / 8 / 10 W own draw · PF 1000

The 0U vertical variant shown. Its outlet ports are what the chip strip's outlet count reads
(DR-171), and its own inlet counts one, because it plugs into the wall.

```text
1x L5-30P-IN          "AC IN (captive cord)" @Inlet
20x C13-OUT           "C13 {n:2}"            @Outlets                  [unswitched]
4x C19-OUT            "C19 {n}"              @Outlets                  [unswitched]
1x RJ45-BI            "MGMT"                 @Management
1x conn.hardwired/power.bonding-PAS  "GROUND LUG"  @Bonding            [gnd]
```

> `{frontU: 0, rearU: 0, side: zeroUVertical}` — the vertical PDU occupies a `ZeroUChannel`, not
> rail holes, and delivers 24 outlets where a 1U horizontal delivers 8. That is the single best
> RU-saving move available in a dense rack, and it is why 0U occupants are created and edited from
> the inspector in v1 (channel, start U, span) with the drag-into-gutter interaction deferred to
> v1.1 (AC-044).
>
> `power.ac_branch` versus `power.ac_iec` is a real distinction: IEC odd numbers are the female
> connector on the cord and the next even number the male inlet on the equipment, so C13→C14 is
> the standard rack pigtail. Links originating at a PDU outlet auto-classify as
> `LinkClass.powerCord`, are excluded from the Pull Sheet, and appear instead as an **outlet map**
> on the power schedule (AC-026).

**P02 · Power Conditioner / Sequencer, 2U, 16-outlet**: `SEQ` · `{2,2,both}` · standard
(300 mm + 65 mm) · 8.2 kg · 12 W · PF 1000 · 20 A / 120 V

```text
1x 5-20P-IN           "AC IN (captive cord)" @Inlet
4x 5-15R-OUT          "STEP 1 OUT {n}"       @"Sequenced Outlets"      [seq:1/0ms, unswitched]
4x 5-15R-OUT          "STEP 2 OUT {n}"       @"Sequenced Outlets"      [seq:2/1000ms, unswitched]
4x 5-15R-OUT          "STEP 3 OUT {n}"       @"Sequenced Outlets"      [seq:3/2000ms, unswitched]
4x 5-15R-OUT          "STEP 4 OUT {n}"       @"Sequenced Outlets"      [seq:4/3000ms, unswitched]
1x CC-IN              "REMOTE ON"            @Control
1x TRG-IN             "TRIGGER IN"           @Control
1x TRG-OUT            "TRIGGER OUT"          @Control
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dte]
```

> The step and delay fields are not decoration: `SEQ-001` is a **warning** when an amplifier lands
> on step 1 of 4, because amplifiers must be **last on and first off** and a reversed sequence
> thumps and blows drivers (AC-033). Modelling `sequenceStep` without shipping the rule — which is
> what every draft did — is data with no consequence.
>
> `ctl.trigger12v` requires a **mono** plug (a stereo plug shorts ring to sleeve) and carries
> `maxCurrentMa: 100`, which is what turns a fan-out to four amplifier trigger inputs into a
> finding rather than an intermittent no-power call.

**P03 · UPS, N VA**: `UPS` · *parametric `VA ∈ {1000, 1500, 3000}`* · `{1,1,both}` /
`{2,2,both}` / `{3,3,both}` · deep · 13.6 / 21.8 / **41.7 kg** · `maxUnsup` 7 kg ·
`apparentVA` 1000 / 1500 / 3000, `nameplateWatts` 900 / 1350 / 2700

The 3000 VA variant shown.

```text
1x L5-30P-IN          "AC IN (captive cord)" @Inlet
6x C13-OUT            "C13 OUT {n}"          @Outlets                  [ups]
2x C19-OUT            "C19 OUT {n}"          @Outlets                  [ups]
2x 5-20R-OUT          "5-20R OUT {n}"        @Outlets                  [ups]
1x RJ45-BI            "NETWORK CARD"         @Management
1x conn.usb_c/net.ethernet-BI  "USB"         @Management
1x 232-BI             "RS-232"               @Management               [dce]
1x conn.hardwired/power.dc_low-BI  "BATTERY EXPANSION"  @Power
```

> **A 41.7 kg device instantly blows a 45 kg wall-rack rating.** This template is the reason
> `Rack.weightCapacity`, the centre-of-gravity advisory and `RCK-013` exist, and it is the one
> entry in the catalog most likely to be dragged into a 12U wall box by a new user on day one.
> Placement guidance is `placeLow: true` in the template tags; it is a **hint the inspector
> shows**, never a placement refusal — G3, a heuristic may never hold a user's deliverable
> hostage.
>
> **UPS capacity is checked VA against VA, never W against W.** The 3000 VA / 2700 W split is not
> cosmetic: a rack of linear-supply amplifiers at PF 650 draws far more VA than its watt total
> suggests, and a UPS sized on watts will not start them (CR-056).
>
> `[ups]` versus `[surge]` on the outlet is load-bearing — the 1000 VA and 1500 VA variants carry
> both kinds, and an integrator needs the drawing to say which outlets survive an outage.

**P04 · Rack Power Strip, 6-outlet, shelf**: `PS` · shelf-mounted, no rail holes · 45 mm ·
0.7 kg · six outlet ports and one inlet, no wattage of its own

```text
1x 5-15P-IN           "AC IN (captive cord)"  @Inlet
6x 5-15R-OUT          "OUT {n}"               @Outlets
```

> **THE CHEAPEST FIX FOR `PWR-003` WAS THE ONE THING THIS CATALOG COULD NOT DRAW** (DR-128
> §11.127.8). Every other template that provides outlets is distribution gear: a 24-outlet PDU, a
> 16-outlet sequencer, a 10-outlet UPS. The trade's ordinary answer to "two more things to plug in
> than places to plug them" is none of those.
>
> **Provenance for the 6.** From the user, 2026-09-05: *"6 outlets is standard on the most basic
> Wattbox power strip, which is easily the most common my company installs."* The row stays generic
> per §10.9, so this is a `Rack Power Strip` and not a WattBox; the brand records where the number
> came from, which is AC-052 in the form the rule actually wants.
>
> **Why it is on a shelf and not a rail.** *"These small power strips are commonly just set on a
> shelf in the rack."* So `mountMethod: shelf` and no `frontU`: the U it sits in belongs to the
> shelf, which is its own template. Claiming rail holes would put a device on the elevation that no
> installer screws in.
>
> **It closes a shortfall by FIVE, not six**, because it eats an outlet to give six. That
> arithmetic needed no change to `PWR-003`: one inlet and N outlet ports is the shape all four power
> templates already use, and since DR-171 the rule reads those ports.
>
> **No wattage, and that is a fact rather than an omission.** A passive strip draws nothing, so
> `PowerProfile` states nothing, since its outlets are its ports (G4/CR-114, AC-039, DR-171). What it is
> usually plugged INTO is a PDU or sequencer outlet, so the gear on it can be power-cycled
> remotely (BlueBOLT, OvrC); that is a fact about the job and lives on the cable, not here.

---

### 3.8 Passive & Mechanical: 3

| ID | Template | Prefix | Occupancy | Depth | Weight | Ports | Notes |
|---|---|---|---|---|---|---|---|
| X01 | Blank Panel, N U *(param 1, 2, 3)* | `BLK` | `{N, 0, front}` | shallow | 0.45 kg/U | 0 | — |
| X02 | Vent Panel, N U, 64% open *(param 1, 2)* | `VNT` | `{N, 0, front}` | shallow | 0.45 kg/U | 0 | — |
| X03 | Rack Shelf, N U, vented *(param 1, 2)* | `SHF` | `{N, 0, front}` | standard | 1.4 / 2.3 kg | 0 | **container** |

All three are `mountMethod: rackEars`, `power: {}` (no `PowerProfile` at all, not zero watts,
*absent*, which is what makes the rollup's unknown count honest), and all three are parametric on
U height per P4.

**X03 · Rack Shelf** additionally carries the container fields:

| Field | 1U | 2U |
|---|---|---|
| `isContainer` | `true` | `true` |
| `containerWeightCapacity` | 15.9 kg | 22.7 kg |
| `containerUsableDepth` | 264 mm | 375 mm |
| `containerUsableWidth` | 432 mm | 432 mm |
| `containerVented` | `true` | `true` |

> Containment direction is **child → parent** (CR-029): a hosted device names its host, the host
> does not carry a list. Lateral position on a shelf is genuine user intent and is stored as
> `ShelfPlacement.order: FracIndex` — an ordinal, not a screen coordinate (CR-006) — with v1
> **auto-packing left to right** and free lateral positioning deferred to v1.1 (AC-043).
>
> The shelf is what makes A02 (the 4U hosted AVR) and S01 (the hosted set-top box) placeable, and
> it is what `RCK-013` proposes when a 15.4 kg amplifier is hung on front ears alone.

> **The fan panel is deliberately not in the 30.** AC-034/m20 gates the "fill gaps with vents"
> heuristic on `Rack.formFactor` **and on whether a fan panel is present** — in a sealed
> fan-cooled enclosure you want blanks, because vents create a recirculation short-circuit. That
> gate reads a rack-level property, and a 1U three-fan panel with a C14 inlet and a thermostat
> probe is a five-minute Device Builder job. It is the first entry in the v1.1 catalog pack (§3.10).

---

### 3.9 Field Devices: 20

Every entry in this category is `mountMethod: notInRack`, `occupancy {0, 0, none}`, no rack depth,
no thermal class, and is authored through the **stripped builder form**: identity, ports,
location. Per AC-049 the builder's three required fields are name, RU height and designator
prefix; for a field device RU height is fixed at zero and the form does not ask.

This category exists because of AC-031, and the argument is worth restating in one line: **there
was nothing to plug the other end into.** A 16-channel amplifier with sixteen speaker outputs and
no speaker anywhere in the library is a demo that dead-ends on the first drag, and `ELE-004`,
`ELE-005` and `ELE-006`, three of the most valuable rules in the product, could never fire,
because `impedanceOhms` lives on the speaker terminal and `tapWatts` on the installed transformer.

| ID | Template | Prefix | Weight | W (name/typ) | Ports | Why it is in the 18 |
|---|---|---|---|---|---|---|
| F01 | Display (flat panel) | `DISP` | 18.1 kg | 200 / 120 | 9 | The far end of every HDBaseT run |
| F02 | Projector | `PROJ` | 7.3 kg | 400 / 280 | 8 | Long HDMI/HDBaseT runs; trigger source |
| F03 | Projection Screen, motorised | `SCRN` | 22.7 kg | 180 / 90 | 3 | It has a 12 V trigger **and** a power feed |
| F04 | In-Ceiling Speaker Pair | `SPK` | 2.7 kg | — | 4 | `ELE-004`; the 16/4 atomic-connect case |
| F05 | In-Wall Speaker | `SPK` | 3.2 kg | — | 2 | `ELE-004` |
| F06 | Subwoofer, powered | `SUB` | 22.7 kg | 500 / 150 | 4 | Line **and** power at the same location |
| F07 | Outdoor / Landscape Speaker | `SPK` | 1.8 kg | — | 2 | Direct-burial jacket; `CODE-*` reach |
| F08 | 70 V Pendant Speaker | `SPK` | 2.3 kg | — | 2 | `ELE-005`, `ELE-006`; `tapWatts` selector |
| F09 | IP Camera | `CAM` | 0.7 kg | 12 / 8 | 3 | PoE PD; `NET-001` budget arithmetic |
| F10 | NVR | `NVR` | 6.8 kg | 120 / 65 | 6 | Camera aggregation; often rack-adjacent |
| F11 | Wireless Access Point | `AP` | 0.9 kg | 30 / 18 | 2 | PoE+ PD; the ceiling Cat6 home run |
| F12 | Touchpanel | `TP` | 1.4 kg | 25 / 15 | 3 | PoE PD **or** 24 V Cresnet |
| F13 | Keypad | `KP` | 0.2 kg | 3 / 2 | 2 | Cresnet bus node; 22/4 home run |
| F14 | Volume Control | `VC` | 0.3 kg | — | 4 | In-line on a speaker run, passive, two pairs |
| F15 | IR Receiver Eye | `IRR` | 0.05 kg | — | 1 | The other end of the C02 pinout hazard |
| F16 | ISP Gateway / ONT | `ONT` | 1.1 kg | 25 / 15 | 5 | Present in every North American residential rack |
| F17 | OTA Antenna | `ANT` | 3.6 kg | — | 1 | `rf.ota`; the F-type ground path |
| F18 | F-Type Ground Block | `GB` | 0.1 kg | — | 3 | Code item and a real lightning liability |
| F19 | Keypad, load-controlling | `KP` | 0.2 kg | — | 4 | Wired to its load, so its box carries line voltage as well as the bus (DR-120) |

---

**F01 · Display (flat panel)**: `DISP` · 18.1 kg · 200 / 120 W · PF 950

```text
4x HDMI21-IN          "HDMI {n}"             @Video                    [arc]
1x TOSLINK-OUT        "OPTICAL OUT"          @Audio
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dce]
1x IRRX-IN            "IR"                   @Control                  [pin:xantech-stereo]
1x 5-15P-IN           "AC (captive cord)"    @Power
```

> `[arc]` on HDMI 1 sets `ReturnChannel.arc` — eARC on an HDMI 2.1 input is the only mechanism in
> the model for audio travelling *up* a link whose `defaultDirection` is source→sink, and the
> drawing has to show that or the AVR wiring is wrong.
>
> The display is also `[dce]` on RS-232 where the control processor's COM ports are `[dte]`. That
> pairing is correct and produces a straight cable; two `[dte]` ends produce `Link.crossover:
> nullModem` and a null-modem adapter on the Equipment List.

**F02 · Projector**: `PROJ` · 7.3 kg · 400 / 280 W · PF 950

```text
2x HDMI21-IN          "HDMI {n}"             @Video
1x HDBT-IN            "HDBT IN"              @Video                    [poh:pd]
1x RJ45-BI            "LAN"                  @Control
1x 232-BI             "RS-232"               @Control                  [dce]
1x TRG-OUT            "SCREEN TRIGGER"       @Control
1x IRRX-IN            "IR"                   @Control                  [pin:xantech-stereo]
1x 5-15P-IN           "AC (captive cord)"    @Power
```

**F03 · Projection Screen, motorised**: `SCRN` · 22.7 kg · 180 / 90 W · PF 900

```text
1x TRG-IN             "12V TRIGGER IN"       @Control
1x CC-IN              "DRY CONTACT / RS-232 KIT"  @Control
1x conn.hardwired/power.ac_branch-IN  "AC (hardwired)"  @Power
```

> The screen is in the 18 because integrators forget it takes **both** a trigger and a line-voltage
> feed, and the feed is hardwired rather than corded. `power.ac_hardwired` on a field device is
> also the one place `CODE-001` (Class 2/3 conductor sharing a pathway with line voltage,
> NEC 725.136) becomes reachable in a residential project, because the trigger and the screen's
> power very often go up the same wall.

**F04 · In-Ceiling Speaker Pair**: `SPK` · 2.7 kg · passive · `impedanceOhms: 8`

```text
4x conn.screw_terminal/audio.speaker_lowz-PAS  "{L,R}@2 {+,−}@1"  @Terminals  [Ω8, set:spk{n@2}/{+,−}@1, atomic]
```

> One ceiling location, one 16/4 pull, four conductors, **one gesture**. This is the canonical
> `atomicConnect` case the v1 multi-conductor decision exists for (AC-053, RJ-016), and it is why
> hand-authoring an arbitrary conductor map could be deferred to v1.1 without the model losing
> anything.
>
> `impedanceOhms: 8` on the terminal is what `ELE-004` sums when four pairs land in parallel on one
> amplifier channel and the load drops below the amplifier's minimum. It is safety-adjacent, so an
> uncited value blocks the template from shipping.
>
> Per AC-034/m24 the outlet template drives which location fields apply. A ceiling speaker pair is
> `mountSurface: ceiling` and is **never** asked for a wall compass direction or a height AFF.

**F05 · In-Wall Speaker**: `SPK` · 3.2 kg · passive · `impedanceOhms: 8`

```text
2x conn.screw_terminal/audio.speaker_lowz-PAS  "{+,−}@1"  @Terminals  [Ω8, set:spk/{+,−}@1, atomic]
```

**F06 · Subwoofer, powered**: `SUB` · 22.7 kg · 500 / 150 W · PF 650

```text
1x conn.rca/audio.sub-IN  "LFE IN"           @Audio
1x conn.rca/audio.sub-OUT "LFE THRU"         @Audio                    [loop]
1x TRG-IN             "12V TRIGGER IN"       @Control
1x 5-15P-IN           "AC (captive cord)"    @Power
```

> A powered subwoofer needs a signal run **and** a receptacle at the same location. That pairing is
> a takeoff line item — the electrician has to be told — and it only appears on the drawing if the
> template models both ports.

**F07 · Outdoor / Landscape Speaker**: `SPK` · 1.8 kg · passive · `impedanceOhms: 8`

```text
2x conn.unterminated/audio.speaker_lowz-PAS  "{+,−}@1"  @Pigtail  [Ω8, set:spk/{+,−}@1, atomic]
```

> Runs to this device default to a `directBurial` jacket. `JacketRating` is
> `cl2 | cl3 | cmr | cmp | lszh | directBurial` and it is not decorative — it is one of the very
> few fields in the product that protects the user from a code citation.

**F08 · 70 V Pendant Speaker**: `SPK` · 2.3 kg · passive · `tapWatts` selector

```text
2x conn.unterminated/audio.speaker_cv-BUS  "{+,−}@1"  @Pigtail  [tap:2.5|5|10|15|20, set:tap/{+,−}@1, atomic]
```

> **`tapWatts` is per installation, not per device.** The tap is a setting on the transformer that
> the installer selects on the ladder, so it lives on `Port.tapWatts` (instance) and the template
> ships the *selector list* (2.5 / 5 / 10 / 15 / 20 W). `ELE-005` sums the selected taps on a run
> against A05's rated output; `ELE-006` fires when this device lands on a low-Z output. Neither is
> expressible without this template, and both are v1.2 with their fixture pairs (AC-051).
>
> Direction is `BUS`, not `PAS` — a constant-voltage run is a multi-tap bus and every speaker on it
> is a node.

**F09 · IP Camera**: `CAM` · 0.7 kg · 12 / 8 W

```text
1x RJ45-BI            "LAN"                  @Network                  [poe:af/pd/c3, 1G]
1x conn.euroblock_2/ctl.contact-BI  "ALARM I/O"  @Control
1x DC-IN              "12V DC IN (opt)"      @Power
```

**F10 · NVR**: `NVR` · 6.8 kg · 120 / 65 W · PF 950

```text
8x RJ45-BI            "PoE CAM {n}"          @Network                  [poe:at/pse, budget:120]
1x RJ45-BI            "LAN"                  @Network                  [1G]
1x HDMI-OUT           "HDMI"                 @Console
2x USBA-BI            "USB {n}"              @Console
1x C14-IN             "AC IN"                @Power
```

**F11 · Wireless Access Point**: `AP` · 0.9 kg · 30 / 18 W

```text
1x RJ45-BI            "LAN / PoE"            @Network                  [poe:at/pd/c4, 1G]
1x DC-IN              "48V DC IN (opt)"      @Power
```

> The AP and the camera together are what make `NET-001` meaningful: eight class-4 PDs against a
> switch whose `poeBudgetWatts` is 130 W is over budget, and a budget is almost always well below
> `ports × max class`.

**F12 · Touchpanel**: `TP` · 1.4 kg · 25 / 15 W

```text
1x RJ45-BI            "LAN / PoE"            @Network                  [poe:af/pd/c3, 1G]
1x CRESNET-BUS        "CRESNET (24V)"        @"Control Bus"
1x DC-IN              "24V DC IN (opt)"      @Power
```

**F13 · Keypad**: `KP` · 0.2 kg · 3 / 2 W

```text
1x CRESNET-BUS        "CRESNET"              @"Control Bus"
1x conn.rj45/ctl.lutron_qs-BUS  "QS LINK (alt)"  @"Control Bus"
```

> `ctl.cresnet` and `ctl.lutron_qs` both ship `topologyFree: true`. Lutron QS is 2000 ft on 12 AWG
> and topology-free; Cresnet is limited twice over (data length and 24 V drop), which `BUS-005`
> reports as two findings.

**F14 · Volume Control**: `VC` · 0.3 kg · passive, in-line on a speaker run

```text
2x conn.screw_terminal/audio.speaker_lowz-PAS  "IN {+,−}@1"   @Input   [set:in/{+,−}@1, atomic]
2x conn.screw_terminal/audio.speaker_lowz-PAS  "OUT {+,−}@1"  @Output  [set:out/{+,−}@1, atomic]
```

> An in-line volume control is a **`DeviceInstance`, not an `InlineAdapter`** (CR-015). The test is
> simple and it is the one that matters on site: an installer pulls two separate cables to this
> device, so it is a device. `InlineAdapter` is reserved for a passive adapter with no independent
> cable on either side.

**F15 · IR Receiver Eye**: `IRR` · 0.05 kg · passive, powered from the block

```text
1x IRRX-OUT           "PIGTAIL TO BLOCK"     @Pigtail                  [pin:xantech-stereo]
```

> The other half of C02's destructive-pinout hazard. Tip = signal, ring = GND, **sleeve = +12 V**.
> Because the eye and an emitter share the identical 3.5 mm connector, `pinoutVariant` is the only
> thing standing between the drawing and a dead emitter, and it is cited on both ends or neither
> ships.

**F16 · ISP Gateway / ONT**: `ONT` · 1.1 kg · 25 / 15 W · PF 900

```text
1x F-IN               "COAX / DOCSIS"        @WAN                      [z75]
1x conn.sc/net.fiber_sm-IN  "FIBRE / GPON"   @WAN                      [os2]
2x RJ45-BI            "LAN {n}"              @LAN                      [1G]
1x conn.rj45/ctl.rs232-PAS  "TEL {n}"        @Voice
1x DC-IN              "12V DC IN"            @Power
```

> The single most conspicuous omission in every earlier draft of this catalog. It is physically
> present in essentially every North American residential rack, it is the device the whole network
> hangs off, and it is furnished by someone else — which is exactly why the drawing has to show it
> rather than assume it.

**F17 · OTA Antenna**: `ANT` · 3.6 kg · passive

```text
1x OTA-PAS            "FEED"                 @Feed                     [z75]
```

**F18 · F-Type Ground Block**: `GB` · 0.1 kg · passive

**F19 · Keypad, load-controlling**: `KP` · 0.2 kg · bus + hardwired AC in

```text
2x F-PAS              "LINE / LOAD"          @Coax                     [z75]
1x GND-PAS            "BONDING LUG"          @Bonding                  [gnd]
```

> The minimum viable grounding story, per AC-034/m21: this template, the `power.bonding` signal
> family, and `Rack.groundBarPresent` feeding a note on the elevation. A coax ground block is a
> code item and an actual lightning-damage liability, and it costs the catalog one three-port
> template. The full commercial bonding-and-grounding detail sheet with conductor sizing is
> deferred to v1.2 (RJ-010) — deferred, not omitted, and the family ships in v1 so a bonding
> conductor is **drawable** today.

---

### 3.10 Catalog summary, and what is deliberately not in it

| Category | Count |
|---|---|
| Video Distribution & Switching | 7 |
| Audio | 6 |
| Network & Cabling Infrastructure | 4 |
| Control | 3 |
| Sources | 2 |
| RF / Coax | 2 |
| Power | 4 |
| Passive & Mechanical | 3 |
| **Rack-side subtotal** | **31** |
| Field Devices | 20 |
| **Total shipped templates** | **51** |

**THIS TABLE WAS STALE, AND P3 ABOVE IS WHY THAT MATTERS.** P3 rules that the count lives in
"exactly one place, the summary table in §3.10", and that no prose anywhere states one. It said
**48 / 18 field** until 2026-09-05, against a catalogue that had shipped 49 since DR-120 added `F19`
on 2026-09-04. So the one place the number was allowed to live was the one place it was wrong,
while thirteen sites in code and tests carried 49 correctly. **A single source of truth that nothing
gates is a single source of staleness**; `seed_catalog_test.dart` asserts this table's category
counts row by row, which is what caught it here, so the gate exists and the table simply had not
been read against it.

Now 50: `F19` (DR-120) and `P04` (DR-128 §11.127.8), the 6-outlet shelf strip that `PWR-003`'s
remedy inserts.

**Eleven templates carry a build-time parameter** (V04, V06, V07, A01, N01, N03, P01, P03, X01,
X02, X03) which is what lets the catalog cover roughly seventy distinct configurations without
seventy authoring-and-citation jobs.

**Deliberately not in the rack-side set, with the reason.** These are rulings, not omissions. Each is a
v1.1 catalog-pack candidate, and each is cheap in the Device Builder precisely because the
archetype it forks from already ships.

| Not shipped | Why | Fork from |
|---|---|---|
| Fan Panel 1U, 3-fan | AC-034/m20's heuristic reads a rack-level property; the panel itself is five minutes of builder work | X02 |
| Rack Drawer 2U, Lacing Bar, Brush Pass-Through | Zero-port mechanical; the lacing bar's rear-rail-only occupancy is worth shipping in v1.1 to exercise `{0, 1, rear}` | X01 |
| Relay / I-O Module | C01 already carries relays and digital inputs; a dedicated module adds no reachable rule | C01 |
| DMX / Lighting Gateway | `ctl.dmx512` has no v1 rule (the DMX universe and unit-load checks are v1.2 with their fixture pairs) | C03 |
| Cresnet Bus Power Supply | `BUS-005` is v1.2; C01 and F12/F13 already give `ctl.cresnet` both ends | C01 |
| Surround Preamp / Processor | A02 and A03 between them cover every family it would introduce | A02 |
| UHD Disc Player, Streaming Media Player, Network Tuner | Near-duplicates of S01; **Mirror bank** plus two row deletions | S01 |
| RF Distribution Amplifier, RF Modulator | R01 and R02 cover `rf.catv` multi-drop and `rf.satellite` DC-pass; the cascade-loss rule is v1.2 | R02 |
| 10G Aggregation Switch | N01's 48-port variant and N02 cover SFP+ and SFP28 | N01 |
| Wall plate, floor box, structured media enclosure | These are **`Outlet`s**, not devices (CR-016); they belong to the Structure device, not the template library | — |
| Doorbell station, gate operator | Real, but no shipped rule reaches them and neither is in AC-031's normative 18 | F09 |

The last two rows matter more than their length suggests. A wall plate is an `Outlet` (one wall
plate, one ceiling location, the atom of creation, specification and pricing) and modelling it as
a `DeviceTemplate` would rebuild the Structure device badly inside the catalog. See
[Structure device](../07-structure-device.md).

---

## 4. Signal domain and signal family registries

**This section is data that ships.** It is the authored content of
`assets/catalog/registries.json`, embedded into every `.rackpal` as the subset the document
references (CR-090's self-describing-file argument). It is reproduced here verbatim from canon §6
because it is not illustrative; it is the file.

### 4.1 Why there are four registries and not one enum

The single most expensive mistake available in this domain is one enum. RJ45 is a **connector**;
Cat6a is a **medium**; Ethernet, HDBaseT, Dante and Cresnet are **signal families** that share
both. HDBaseT explicitly reuses Ethernet conductors, cable and connectors *and is not
interchangeable with them*, patching an HDBaseT output into a switch does not work and its 100 W
PoH can damage the switch. That single check is the highest-value validation in the product, and
it is only expressible because the axes are separate.

| Registry | Answers | User-extensible in v1? |
|---|---|---|
| `SignalDomainDef` | What colour, dash, weight and glyph does this class of signal draw in? | No: 8 fixed entries |
| `SignalFamilyDef` | What *is* this signal, what does it require, what may it mate with? | **By clone only** (DR-122; was catalog-updated, RJ-012) |
| `ConnectorTypeDef` | What plugs into what, and does gender apply? | Aliases only (CR-058) |
| `MediaTypeDef` | What cable is pulled, how long may it be, what jacket? | **Yes**: the CSV import creates them (RJ-009) |

`Port.connector` and `Port.signalFamily` are two independent fields (`carriedProtocols` was a third until DR-134 §11.133).
`Link.media` is a fourth. `Service.signalFamily` is what a wire's colour resolves from, never
`Link` (CR-009).

### 4.2 The four encoding channels

There are ~50 signal families below. **No categorical palette is colour-vision-deficiency-safe
past 8–9 categories**: the Okabe–Ito authors stopped at eight for exactly that reason. Assigning
a hue per cable type does not produce a colour-coded drawing; it produces an unreadable one, and
it fails hardest for the ~8% of male installers with a CVD who are the exact audience. So hue is
never a channel on its own:

| Channel | Encodes | Survives CVD | Survives greyscale | Survives photocopy/fax |
|---|---|---|---|---|
| **Hue** | domain (8) | yes (Okabe–Ito) | no | no |
| **Dash pattern** | type-within-domain | yes | yes | yes |
| **Line weight** | domain tier (0.75× – 2.0×) | yes | yes | yes |
| **Glyph + tag pill** | exact family | yes | yes | yes |

The tag pill (`W042 · HDMI · 25 ft`, drawn at both ends of every run) is the encoding that never
fails, and it is mandatory, not decorative.

Three palette rules are checkable, not aspirational:

> **PAL-1 (rendered-value form).** Every shipped `SignalFamilyDef` renders as the triple
> *(L, dashClass, weight)*, where **L** is the WCAG relative luminance of its **effective** hue,
> **dashClass** is the class of its effective dash pattern per the mechanical definition below, and
> **weight** is its effective line-weight multiplier — *effective* meaning **after** any
> `colorOverride`, `dashOverride` or weight override declared in the signal-family registry, not
> the domain base value.
>
> For **every pair of families belonging to different `SignalDomainDef`s** whose luminances satisfy
> **|L₁ − L₂| < 0.10**, at least one of the following must hold: **(a)** their dash classes differ,
> **or** **(b)** their weight multipliers differ by a factor **≥ 1.4**.
>
> Families **within one domain** are exempt from (a)/(b) — they share a hue by construction, the
> legend prints them adjacently, and the tag pill disambiguates them — but any two families in one
> domain must still differ in **dash pattern, weight, or glyph**.

> **PAL-2** — Yellow `#F0E442` is reserved for selection and focus and is never a cable. At
> L 0.744 it is illegible as a thin line on white paper.

> **PAL-3** — The screen theme never affects the export. Export palette is
> `ExportSpec.palette: colour | greyscale | cmyk`, default `colour`, default `greyscale` in the
> Installer preset, never inherited from the UI theme (CR-077).

**Dash class.** Classify each mark in one period as **dot** (< 2.5 pt), **short** (2.5–8.9 pt) or
**long** (≥ 9 pt); the class is that sequence of mark classes, compared **up to rotation**.
`solid` is its own class. Worked: `2,3` → `(dot)` · `1.5,3` → `(dot)` · `6,3` → `(short)` ·
`6,3,3,3` → `(short,short)` · `12,4` → `(long)` · `6,3,1,3` → `(short,dot)` ·
`1.5,3,4,3` → `(dot,short)` = `(short,dot)` by rotation · `1.5,3,1.5,9` → `(dot,dot)` ·
`8,3,1.5,3,1.5,3` → `(short,dot,dot)`.

**PAL-1 is verified by `tools/pal1_check.py`, and by nothing else.** That file enumerates all 385
in-band cross-domain pairs over the 55 shipped families and exits non-zero on any violation; it is
the authority, and §§4.3–4.5 below are a projection of it. It must be ported to
`pal1_conformance_test.dart` in `rackpal_core` at M0 (§7 criterion 4) and remain the authority
after the port.

The rule is not checkable by reading a table of domain rows, and the attempt is what produced the
defect. PAL-1 was signed off as clear **three times** against a palette that in fact held
**fourteen** collisions, six of them involving types requirement 4 names by hand, because each
sign-off read §4.3's eight domain base weights instead of the family values actually drawn. A
family-level `dashOverride` or weight override is invisible at the domain level by construction,
so the method could not have found them. A rule checked by inspection is not checked. Do not
re-add a prose assertion that a sweep was performed; cite the file and its exit status.

The within-domain exemption is a domain-equality check in the test, **never an allowlist of
pairs**: an allowlist is how a real collision gets waived.

**Units and storage.** Dash patterns are in points (1/72 in), stored as `List<int>` of
permille-points so the file stays integral, `6,3` is `[6000, 3000]` and `1.5,3` is
`[1500, 3000]` (CR-079). Line weight is `Permille`; `1000` = 1× = the base signal weight. Minimum
print stroke is 0.5 pt and no stroke is ever emitted at 0. Every shipped dash period is ≥ 4.5 pt
(1.5875 mm), above the floor below which a dash blurs to solid at 300 dpi. Dash patterns matter on
paper even though **net labels are the default render** (DR-001): drawn wires appear on a domain
filter, `Alt`-hover or focus, and the exported interconnect sheets `T6.01…` are drawn by
construction because a domain partition *is* a domain filter.

**The glyph channel.** A glyph is drawn at the midpoint of each run and in the legend. **Shape
encodes domain; fill encodes tier within the domain**: filled = the domain's native carrier,
hollow = the transported / extended / networked variant. The glyph is deliberately *not* the
per-family discriminator (there is no set of 50 shapes legible at 6 pt); the tag pill is.

### 4.3 `SignalDomainDef`: the eight shipped entries

`SignalDomainDef{id, displayName, tagPrefix, color, colorDark, dashPattern, lineWeightPermille,
glyph, glyphAlt}`.

| `id` | Display name | Light hex | Dark hex | Base dash (pt) | Weight | Glyph (native / transported) | Rel. lum. |
|---|---|---|---|---|---|---|---|
| `video.digital` | Digital Video | `#0072B2` | `#4DA6DD` | solid | 1.00× | ▲ / △ | 0.1525 |
| `video.analog` | Analog Video & RF | `#56B4E9` | `#8ACFF5` | `12,4` | 1.00× | ▼ / ▽ | 0.4050 |
| `audio.analog` | Analog Audio | `#E69F00` | `#F0B443` | `6,3` | 1.00× | ● / ◐ / ○ | 0.4162 |
| `audio.digital` | Digital Audio | `#D55E00` | `#F07A33` | `6,3,1,3` | 1.00× | ◆ / ◇ | 0.2215 |
| `net` | Network | `#009E73` | `#2FC79A` | solid | 1.50× | ■ / □ | 0.2569 |
| `ctl` | Control | `#CC79A7` | `#E29CC3` | `1.5,3` | 0.75× | ✚ / ✳ | 0.2930 |
| `pwr` | Power | `#000000` | `#E8E8E8` *(inverted: black is invisible on dark)* | `8,3,1.5,3,1.5,3` | 2.00× | ⬢ / ⬡ / ⏚ | 0.0000 |
| `str` | Structure | `#999999` | `#A8A8A8` | `6,3,3,3` | 0.75× | ★ / ☆ | 0.3185 |
| *(reserved)* | Selection / focus | `#F0E442` | `#F5E76B` | — | — | — | 0.744 |

Dash patterns, weights, glyphs and tags are **identical across themes**. Only hue moves, and the
theme is a UI preference never persisted in the document.

The **Rel. lum.** column is the WCAG relative luminance computed from the light hex in the same
row. These are the authoritative figures and they are recomputed from the shipped hexes by
`tools/pal1_check.py`; where any other document publishes a different value, `video.analog` as
`0.401` is the recurring one, that document is wrong.

`str`'s base dash is `6,3,3,3` (class `(short,short)`, period 15 pt). It was authored `4,4`, which
fails PAL-1 identically to the `6,3` it was chosen over, `4,4` and `6,3` are both `(short)` and
1.00×/0.75× is a ratio of 1.33, and the "an even dash is unambiguous against a 2:1 dash" reasoning
is retracted, because §4.2's dash class is computed from mark lengths, not from the mark-to-gap
ratio. `(short,short)` is the only two-mark class no other shipped family occupies, which is why
`6,3,3,3` clears its in-band partners on dash class alone. That is a result of
`tools/pal1_check.py`, not of reading this table.

### 4.4 `SignalFamilyDef`: the shipped signal families

`SignalFamilyDef{id, displayName, shortTag, domain, defaultConnector, defaultDirection,
defaultTopology, typicalMedia[], acceptedFamilies[], adaptableTo[], maxRunLengthPassive,
maxRunLengthActive, nominalImpedanceOhms, maxUnitLoads, maxDevicesPerSegment, requiresTermination,
carriesPower, topologyFree, aliases[], colorOverride?, dashOverride?, glyphOverride?}`.

**Colour is inherited from the domain** (CR-078) and the hex is printed here as the *effective*
value so this table is self-contained. `dashOverride` is the type-within-domain channel required
by AC-054 and is what makes each of the brief's ten named types individually identifiable.
`ProjectSettings.familyColorOverrides` lets a user override any hue in v1.

Direction key: **→** unidirectional source→sink · **↔** bidirectional · **BUS** multi-drop shared
medium · **⤳** logical flow riding a network. Topology: **P2P** · **MD** multi-drop · **STAR**.

#### Digital video: `#0072B2`, glyph ▲ native / △ transported

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `video.hdmi.1_4` | HDMI 1.4 | `conn.hdmi_a` | → | P2P | solid | 0.75× | `HD14` | ▲ |
| `video.hdmi.2_0` | HDMI 2.0 (18 Gbps) | `conn.hdmi_a` | → (+ARC ↔) | P2P | solid | 1.00× | `HD20` | ▲ |
| `video.hdmi.2_1` | HDMI 2.1 (48 Gbps) | `conn.hdmi_a` | → (+eARC ↔) | P2P | solid | 1.25× | `HD21` | ▲ |
| `video.displayport` | DisplayPort 1.4 / 2.1 | `conn.dp` | → (+AUX ↔) | P2P / MST | `18,4` | 1.00× | `DP` | ▲ |
| `video.sdi` | SDI (HD / 3G / 6G / 12G) | `conn.bnc75` | → | P2P (+loop) | `10,3` | 1.00× | `SDI` | ▲ |
| `video.hdbaset` | **HDBaseT (5Play)** | `conn.rj45` | → video, ↔ ctl | P2P | `14,4` | 1.25× | `HBT` | △ |
| `video.usbc_dpalt` | USB-C DP Alt Mode | `conn.usb_c` | ↔ | P2P | `6,2` | 1.00× | `UCV` | ▲ |
| `video.avoip` | AV-over-IP (SDVoE / JPEG XS / NDI) | `conn.rj45` | ⤳ | STAR | `14,4,2,4` | 1.00× | `AVIP` | △ |

Key data: HDMI 2.1 passive collapses to **3–4.5 m** where 2.0 reaches ~7.5 m, a 25 ft run that
worked at 4K60 fails at 4K120, and `LEN-001` exists for exactly this. DisplayPort DP80 passive is
**1.2 m**. 12G-SDI is **~45–50 m**. HDBaseT reaches **100 m on Cat6a** at 4K and carries up to
100 W PoH; `topologyFree = false`, `acceptedFamilies` deliberately **excludes** `net.ethernet`,
and this is what makes `SIG-001` fire.

The three HDMI generations all stay **solid** (solid is the native carrier of the digital-video
domain and HDMI is what that domain is for) and separate on weight alone, as a bandwidth
progression: **1.4 at 0.75×, 2.0 at 1.00×, 2.1 at 1.25×**. HDMI 1.4 was authored at 1.00×, which
made it byte-identical to `video.hdmi.2_0` on all four channels and failed PAL-1's within-domain
limb; 0.75× also reads correctly as "the slow one". Note that 0.75×/1.00× is a ratio of 1.33 and
so would *not* clear the cross-domain limb; it does not have to, because the within-domain limb
requires only that dash, weight or glyph differ.

#### Analog video & RF: `#56B4E9`, glyph ▼ baseband / ▽ broadband

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `video.composite` | Composite (CVBS) | `conn.rca75` | → | P2P | `1.5,3` | 1.00× | `CVBS` | ▼ |
| `video.component` | Component YPbPr | `conn.rca75` | → | P2P (3-port set) | `12,4,3,4` | 1.00× | `YPBPR` | ▼ |
| `video.vga` | VGA / RGBHV | `conn.hd15` | → (+DDC ↔) | P2P | `12,4,3,4,3,4` | 1.00× | `VGA` | ▼ |
| `video.svideo` | S-Video | `conn.mini_din4` | → | P2P | `9,4` | 1.00× | `SVID` | ▼ |
| `rf.catv` | RF / CATV distribution | `conn.f_type` | → (↔ DOCSIS) | **MD** | `12,4` | 1.50× | `RF` | ▽ |
| `rf.satellite` | Satellite / SWM | `conn.f_type` | ↔ | **MD, power-passing** | `12,4,3,4` | 1.50× | `SAT` | ▽ |
| `rf.ota` | OTA antenna | `conn.f_type` | → | MD | `16,4` | 1.00× | `OTA` | ▽ |
| `rf.modulated` | RF modulated channel | `conn.f_type` | → | MD | `12,4` | 1.00× | `RFM` | ▽ |

`video.component` declares a `PortSetDef` of kind `componentVideo` with `atomicConnect: true`,
three ports, one gesture, one Link with three conductors (AC-053). `rf.satellite` carries
`requiresPowerPassingPort: true`: exactly one splitter port passes DC back to the LNB, and wiring
a normal splitter means the dish never powers. `rf.catv` carries per-device insertion loss so a
cascade budget is computable (a 2-way splitter is ≈ 3.5 dB); the cascade rule itself is v1.2.

`video.composite`'s dash is `1.5,3` (class `(dot)`), not the `12,4` domain base it was authored
with. At `12,4` 1.00× it was one of four `video.analog` families sharing class `(long)` with
`audio.line_bal` at `10,3` 1.00× across a ΔL of 0.0112, the analog-video and analog-audio hues
are 0.4050 and 0.4162, which is about as deep inside the 0.10 band as two domains can be. Moving
composite to a fine dot is also the honest reading: it is the lowest-bandwidth video signal in the
registry.

#### Analog audio: `#E69F00`, glyph ● line / ◐ speaker low-Z / ○ constant-voltage

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `audio.line_unbal` | **Line level, unbalanced (RCA)** | `conn.rca` | → | P2P | `6,3` | 1.00× | `AUD` | ● |
| `audio.line_bal` | Line level, balanced | `conn.xlr3` | → | P2P | solid | 1.00× | `AUDB` | ● |
| `audio.mic` | Mic level | `conn.xlr3` | → | P2P | `4,3` | 1.00× | `MIC` | ● |
| `audio.phono` | Phono / turntable | `conn.rca` | → | P2P | `4,3,1.5,3` | 1.00× | `PHNO` | ● |
| `audio.speaker_lowz` | **Speaker level, low-Z** | `conn.binding_post` | → | P2P / parallel | `6,3` | **2.00×** | `SPK` | ◐ |
| `audio.speaker_cv` | Speaker, constant-voltage 70 / 100 / 25 V | `conn.euroblock_2` | → | **BUS (multi-tap)** | `10,3,2,3` | **2.00×** | `70V` | ○ |
| `audio.sub` | Subwoofer / LFE | `conn.rca` | → | P2P (or Y-split) | `8,3` | 1.25× | `SUB` | ● |
| `audio.headphone` | Headphone | `conn.6_35mm_trs` | → | P2P | `3,3` | 0.75× | `HP` | ● |

This is where the brief's "Analog RCA" and "speaker level" would have collided on one orange, and
they do not: `AUD` is a 1.00× short dash with a filled circle; `SPK` is a **2.00×** stroke with a
half-filled circle. In greyscale that is a 2× weight difference, which is the most legible
discriminator available.

`audio.line_bal` sets `balanced: true`; **gender is load-bearing** on XLR (male = output, female
= input) and `genderApplies` is true. `audio.phono` requires a separate ground conductor, which is
a real `Conductor` on the schedule, not a footnote. `audio.speaker_lowz` carries `impedanceOhms`
on the terminal so `ELE-004` can evaluate. `audio.speaker_cv` carries `Port.tapWatts` **per
installation, not per device** (2.5 / 5 / 10 / 15 / 20 W), because the tap is a setting on the
transformer, not a property of the speaker model.

`audio.line_bal` draws **solid**, not the `10,3` it was authored with. `10,3` is class `(long)`,
and it collided simultaneously with four `video.analog` families (`video.composite`,
`video.svideo`, `rf.ota` and `rf.modulated`) all at ΔL 0.0112 and all at 1.00×, so neither PAL-1
limb rescued any of the four. Solid is unoccupied in `audio.analog`, and a balanced line is the
domain's cleanest carrier, so the override reads as meaning rather than as evasion. This is the
one place a `dashOverride` reaches for `solid` inside a dashed domain.

#### Digital audio: `#D55E00`, glyph ◆ electrical / ◇ optical or networked

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `audio.spdif_coax` | **S/PDIF, coaxial (75 Ω)** | `conn.rca75` | → | P2P | `12,4,3,4` | 1.00× | `SPD` | ◆ |
| `audio.spdif_optical` | **TOSLINK (optical S/PDIF)** | `conn.jis_f05` | → | P2P | `2,3` | **1.25×** | `OPT` | ◇ |
| `audio.aes3` | AES/EBU (AES3, 110 Ω) | `conn.xlr3` | → | P2P | `12,4,10,4` | 1.00× | `AES` | ◆ |
| `audio.aes3id` | AES3id (75 Ω BNC) | `conn.bnc75` | → | P2P | `10,3,1,3,1,3` | 1.00× | `AES75` | ◆ |
| `audio.dante` | Dante | `conn.rj45` | ⤳ | STAR | `6,3,1,3` | 1.50× | `DNT` | ◇ |
| `audio.aes67` | AES67 | `conn.rj45` | ⤳ | STAR | `6,3,1,3,1,3` | 1.50× | `A67` | ◇ |
| `audio.avb` | AVB / Milan | `conn.rj45` | ↔ | STAR (**TSN switches only**) | `8,3,1,3` | 1.50× | `AVB` | ◇ |

The brief's "S/PDIF" and "TOSLINK" would have collided on one vermillion, and they do not: within
the digital-audio domain the pair separates on **dash class, weight and glyph**: a `12,4,3,4`
long-short at 1.00× with a filled diamond versus a fine `2,3` dot at 1.25× with a hollow diamond.
TOSLINK's weight was raised from 1.00× because at 1.00× it collided with `ctl.ir_emitter` on every
non-hue channel (ΔL 0.0715, both fine-dot class, weight ratio only 1.33×) which fails PAL-1 in
greyscale. At 1.25× the ratio is 1.67 and the pair passes. This is also where the
distinction carries real consequence, TOSLINK cannot carry lossless multichannel (no DTS-HD MA,
no TrueHD), which is a design constraint, not trivia.

`audio.spdif_coax` sets `nominalImpedanceOhms: 75` and is physically indistinguishable from
`audio.line_unbal` at the connector: wiring a plain analog interconnect causes intermittent
dropouts, which is why the impedance warning exists. `audio.aes3` sets `110`, 110 Ω STP, *not*
mic cable, despite the identical XLR. Dante uses **PTPv1**, AES67 **PTPv2 (IEEE 1588-2008)**; both
need QoS/DSCP and ideally a dedicated VLAN. `audio.avb` sets `requiresTsnPath: true`, and per
CR-017 the "AVB traverses a non-TSN switch" check is a **post-hoc finding**, not a drag-time
refusal, because the link being drawn may be the one that completes the path.

**Two dashes in this domain were re-authored, and one of them is a requirement-4 type.**
`audio.spdif_coax` moved from `6,3,1,3` to `12,4,3,4` and `audio.aes3` from `10,3,1,3` to
`12,4,10,4`. `audio.digital` sits at L 0.2215, which puts it inside the 0.10 band against
`ctl` (0.2930), `video.digital` (0.1525) *and* `net` (0.2569) at once; it is the most crowded hue
in the palette, and a dash-dot pattern is the most crowded class. At `6,3,1,3`, class
`(short,dot)`, S/PDIF collided with **six** `ctl` families (`ctl.rs232`, `ctl.dmx512`,
`ctl.dali`, `ctl.knx`, `ctl.contact` and `ctl.ir_receiver`) none of which the weight limb
rescued, since 1.00× against 0.75× is a ratio of 1.33. At `10,3,1,3`, class `(long,dot)`, AES3
collided with `ctl.cresnet` and `video.avoip`. The replacements take `(long,short)` and
`(long,long)`, and both keep the domain's 1.00× base weight. Do not "restore" the dash-dot
patterns for family resemblance: the resemblance is what broke them.

#### Network: `#009E73`, glyph ■ copper / □ fibre or non-Ethernet

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `net.ethernet` | **Ethernet (copper)** | `conn.rj45` | ↔ | STAR | solid | 1.50× | `NET` | ■ |
| `net.poe` | PoE / PoE+ / PoE++ | `conn.rj45` | → power, ↔ data | STAR | solid | 2.00× | `PoE` | ■ |
| `net.poh` | PoH (HDBaseT power) | `conn.rj45` | → | P2P | `14,4` | 2.00× | `PoH` | □ |
| `net.fiber_mm` | Fibre, multimode (OM3 / OM4) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4` | 1.50× | `FIB` | □ |
| `net.fiber_sm` | Fibre, singlemode (OS2) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4,3,4` | 1.50× | `FIBS` | □ |
| `net.dac` | Direct-attach copper (SFP+) | `conn.sfp_cage` | ↔ | P2P | `8,3` | 1.50× | `DAC` | □ |

`maxChannelLength` is **100 m** for copper Ethernet (90 m horizontal + 10 m patch) and it is an
error above it, not a warning; this is one of the few hard numbers in the trade. PoE, as shipped
data on `PoeSpec{role, standard, type, class, watts}`:

| Standard | Type | Classes | PSE max | PD max | Pairs |
|---|---|---|---|---|---|
| 802.3af (PoE) | 1 | 0–3 | 15.4 W | 12.95 W | 2 |
| 802.3at (PoE+) | 2 | 4 | 30 W | 25.5 W | 2 |
| 802.3bt (PoE++) | **3** | 5, 6 | **60 W** | ~40 W / ~51 W | **4** |
| 802.3bt (PoE++) | **4** | 7, 8 | **90 W** | ~62 W / ~73 W | **4** |
| PoH (HDBaseT) | — | — | **up to 100 W** | — | **4** |

PoH is *based on* 802.3at and modified for 4-pair 100 W delivery. It is **not** interoperable with
a standard PoE PSE, which is why it is its own family with its own glyph rather than a flag on
`net.poe`. `NET-001` checks Σ(PD class draw) ≤ `PowerProfile.poeBudgetWatts` and flags a Type-4 PD
on a Type-2 PSE. Fibre carries `fiberMode` and `wavelengthNm`, and **A/B pair polarity** is the
fibre analogue of null-modem: it is `Link.crossover: fiberPolarityAB`.

#### Control: `#CC79A7`, glyph ✚ point-to-point / ✳ multi-drop bus

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `ctl.ir_emitter` | **IR emitter (flasher)** | `conn.3_5mm_ts` | → | P2P | `1.5,3` | 0.75× | `IR` | ✚ |
| `ctl.ir_receiver` | IR receiver (powered eye) | `conn.3_5mm_trs` | → to block | MD | `4,3,1.5,3` | 0.75× | `IRRX` | ✚ |
| `ctl.ir_direct` | IR direct (device input) | `conn.3_5mm_ts` | ← from emitter | P2P | `1.5,9` | 0.75× | `IRD` | ✚ |
| `ctl.rs232` | **RS-232** | `conn.de9` | ↔ | **P2P only** | `6,3,1.5,3` | 0.75× | `232` | ✚ |
| `ctl.rs485` | RS-485 | `conn.euroblock_3` | ↔ half-duplex | **BUS** | `6,3` | 1.00× | `485` | ✳ |
| `ctl.dmx512` | DMX512-A | `conn.xlr5` | → over RS-485 | **BUS** | `8,3,1.5,3` | 1.00× | `DMX` | ✳ |
| `ctl.contact` | Contact closure / relay / GPIO | `conn.euroblock_2` | → drive or ← sense | P2P | `1.5,3,4,3` | 0.75× | `CC` | ✚ |
| `ctl.trigger12v` | 12 V trigger | `conn.3_5mm_ts` | → | P2P | `4,3` | 0.75× | `TRG` | ✚ |
| `ctl.cresnet` | Cresnet | `conn.phoenix_4` | ↔ | **BUS**, topology-free | `10,3,1.5,3` | 1.00× | `CN` | ✳ |
| `ctl.lutron_qs` | Lutron QS / HomeWorks link | `conn.rj45` | ↔ | **BUS**, topology-free | `10,3` | 1.00× | `QS` | ✳ |
| `ctl.dali` | DALI / DALI-2 | `conn.screw_terminal` | ↔ | **BUS**, topology-free | `5,3,1.5,3` | 1.00× | `DALI` | ✳ |
| `ctl.knx` | KNX TP1 | `conn.knx_terminal` | ↔ | **BUS** (line / tree) | `7,3,1.5,3` | 1.00× | `KNX` | ✳ |
| `ctl.vantage` | Vantage station bus (Legrand) | `conn.hardwired` | ↔ | **BUS** (line / tree) | `9,3,1.5,3` | 1.00× | `VTG` | ✳ |

`topologyFree: true` ships set on `ctl.cresnet`, `ctl.lutron_qs`, `ctl.dali` and `ctl.knx`. This is
a **registry field, not a hard-coded suppression array** (AC-030).

Shipped limits: RS-485 **32 unit loads**, 120 Ω termination at *both* ends only, 1200 m. DMX512-A
32 unit loads, 512 channels per universe, terminator at the far end, `busUniverse` on the port.
DALI **64 devices per line**, ~300 m, polarity-free (a wiring error is inexpressible). KNX 64
devices per line segment, 1000 m per line. Cresnet has **two independent limits**, data length
(~915 m) *and* 24 V power drop (18 AWG at 20 W ⇒ **333 ft**), which is why `BUS-005` emits two
findings, not one. Lutron QS is 2000 ft on 12 AWG and topology-free.

`ctl.ir_emitter` and `ctl.ir_receiver` are separate families because the pinout hazard is real and
destructive: Xantech/Niles **receivers** are tip = signal, ring = GND, sleeve = +12 V;
**emitters** are tip = IR in, sleeve = GND. Plugging an emitter into a receiver jack destroys the
emitter and can damage the supply. `PortDef.pinoutVariant` is mandatory on every 3.5 mm IR port
and is a **safety-adjacent field**, so a template with an uncited value does not ship (AC-052).
`ctl.trigger12v` requires a **mono** plug, a stereo plug shorts ring to sleeve, and carries
`maxCurrentMa: 100`, which is what makes fan-out to four amplifier triggers a finding.
`ctl.rs232` is P2P only; straight versus null-modem is determined by the DTE/DCE role of *both*
ends, carried in `SerialSpec.role`, and surfaces as `Link.crossover`.

#### Power: `#000000` (light) / `#E8E8E8` (dark, inverted), glyph ⬢ AC / ⬡ DC / ⏚ bonding

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `power.ac_branch` | **AC branch circuit** | `conn.nema_5_15p` | → | P2P to circuit | `8,3,1.5,3,1.5,3` | 2.00× | `PWR` | ⬢ |
| `power.ac_iec` | IEC device power (C13/C14, C19/C20) | `conn.iec_c14` | → | P2P | `8,3,1.5,3` | 2.00× | `IEC` | ⬢ |
| `power.ac_hardwired` | Hardwired AC | `conn.hardwired` | → | P2P | `12,3,1.5,3` | 2.00× | `HW` | ⬢ |
| `power.dc_low` | Low-voltage DC (12 / 24 V supply) | `conn.barrel_dc` | → | P2P | `6,3,1.5,3` | 1.50× | `DC` | ⬡ |
| `power.bonding` | Bonding / grounding conductor | `conn.ground_lug` | ↔ | STAR to busbar | `4,3` | 1.50× | `GND` | ⏚ |

`power.ac_120` and `ac-inlet` are both re-authored to `power.ac_branch` / `power.ac_iec` with
`PortPowerSpec.role: inlet | outlet` (CR-058, CR-060). **Inlet and outlet are not directions**:
they are `sink` / `source` on a `power.*` family plus a role. IEC odd numbers are the female
connector on the cord and the next even number the male inlet on the equipment; C13→C14 is the
standard rack pigtail. Circuit loading is computed in **VA** using `typicalWatts` × a per-category
diversity factor (amplifiers 350‰ by default), with nameplate as an advisory second line
(AC-020, CR-056).

`power.bonding` exists so a bonding conductor is *drawable* and therefore appears on the drawing;
the full busbar entity and conductor sizing are v1.2 (RJ-010). Links on `power.*` originating at a
PDU outlet auto-classify as `LinkClass.powerCord` and are excluded from the pull sheet by default,
appearing instead as an **outlet map** on the power schedule (AC-026).

#### Structure: `#999999`, glyph ★ home run / ☆ pathway

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `structure.undetermined` | Undetermined home run | `conn.unterminated` | passive | P2P | `6,3,3,3` | 0.75× | `STR` | ★ |
| `structure.pathway` | Pathway only (conduit / pull string) | — | passive | — | `1.5,3,1.5,9` | 0.75× | `PATH` | ☆ |

`structure.undetermined` is the interesting case and it is deliberate: a Cat6 home run at rough-in
may end up carrying Ethernet, HDBaseT, or nothing. The family is legal, it schedules, it prints,
it gets a `W` number and both labels, and the DRC validates **retroactively** once a `Service`
assigns a real family. Its `6,3,3,3` dash is the `str` domain base, not an override; it moved from
`4,4` because at 0.75× that value failed both PAL-1 limbs against five families inside `str`'s
0.10 band (L 0.2185–0.4185). `structure.pathway` pairs with `MediaTypeDef.isPathwayOnly`, it creates a
`Pathway`, never a Link and never a Port, appears on the pull sheet (you still pull the smurf tube
and it still costs money) and never appears in the netlist (CR-109).

`structure.pathway`'s dash is a **double dot** (`1.5,3,1.5,9`, period 15 pt), not the single `2,6`
dot it was authored with: at 0.75× against `ctl.ir_emitter`'s `1.5,3` at 0.75× (ΔL 0.0255, same
fine-dot class, weight ratio 1.00) it violated PAL-1. A double dot reads correctly as "a route,
not a conductor" and is unique in the shipped set.

**None of the re-authored values in §4.3 and §4.4 were arrived at by reading these tables.** Every
one of them, and the claim that the shipped set is now clear, is the output of
`tools/pal1_check.py`, which enumerates all 385 in-band cross-domain pairs over all 55 families.
Any change to a dash, weight or hex in this section is a change to that file's `FAMILIES` list and
must be made in both places, in the same commit, with the check run.

### 4.5 Requirement 4 coverage audit

Requirement 4 names ten cable types and demands the plan be colour-coded by them. AC-054 resolved
it as: **hue = domain; dash + weight + glyph + tag = type; the legend prints one row per named
type in colour and greyscale side by side.**

| Named in requirement 4 | Canonical family (or media) | Effective hue | Dash | Wt | Glyph | Tag |
|---|---|---|---|---|---|---|
| **Analog RCA** | `audio.line_unbal` | `#E69F00` | `6,3` | 1.00× | ● | `AUD` |
| **HDMI** | `video.hdmi.2_0` / `2_1` / `1_4` | `#0072B2` | solid | 1.00× / 1.25× / **0.75×** | ▲ | `HD20` `HD21` `HD14` |
| **Network** | `net.ethernet` (+ `net.poe`) | `#009E73` | solid | 1.50× / 2.00× | ■ | `NET` `PoE` |
| **IR** | `ctl.ir_emitter` (+ `ctl.ir_receiver`, `ctl.ir_direct`) | `#CC79A7` | `1.5,3` / `4,3,1.5,3` / `1.5,9` | 0.75× | ✚ | `IR` `IRRX` `IRD` |
| **RS-232** | `ctl.rs232` | `#CC79A7` | `6,3,1.5,3` | 0.75× | ✚ | `232` |
| **RG6** | `media.rg6` carrying `rf.catv` / `rf.satellite` / `rf.ota` | `#56B4E9` | `12,4` / `12,4,3,4` / `16,4` | 1.50× / 1.50× / 1.00× | ▽ | `RF` `SAT` `OTA` |
| **S/PDIF** | `audio.spdif_coax` | `#D55E00` | `12,4,3,4` | 1.00× | ◆ | `SPD` |
| **TOSLINK** | `audio.spdif_optical` | `#D55E00` | `2,3` | **1.25×** | ◇ | `OPT` |
| **Speaker level** | `audio.speaker_lowz` (+ `audio.speaker_cv`) | `#E69F00` | `6,3` / `10,3,2,3` | **2.00×** | ◐ / ○ | `SPK` `70V` |
| **Power** | `power.ac_branch` / `power.ac_iec` | `#000000` | `8,3,1.5,3,1.5,3` / `8,3,1.5,3` | 2.00× | ⬢ | `PWR` `IEC` |
| *"etc."* | 37 further families across the same 8 domains | — | — | — | — | — |

RG6 is correctly a **medium**, not a signal, that is the point of the three-axis split, so it is
colour-coded by what it carries. The legend row for RG6 shows all three of its families, which is
more informative than a single "RG6" swatch would have been.

**Two rows of this audit carry corrected values, and the correction is the point.** S/PDIF now
draws `12,4,3,4`, not `6,3,1,3`; HDMI 1.4 now draws at 0.75×, not 1.00×. The old values had been
signed off as clear three separate times. They were not: at `6,3,1,3` S/PDIF was illegible in
greyscale against six `ctl` families including **RS-232 and IR receive, two more of the ten types
this very table exists to certify**, and HDMI 1.4 was byte-identical to HDMI 2.0. Each sign-off
had been performed by reading §4.3's eight domain rows, which cannot see a family-level override
and therefore cannot see any of these collisions.

So this audit is no longer the evidence. `tools/pal1_check.py` is: it carries the ten named types
as a `REQUIREMENT_4` map and labels every violation that touches one, so a regression against a
brief-named type reports as a requirement-4 failure rather than a style nit. The table above is a
human-readable projection of that file and is correct only insofar as it matches it. Run the check
before trusting either.

**Every one of the ten is reachable from the shipped catalog**, which is the property that makes
this audit meaningful rather than theoretical:

| Type | Shipped port that produces it |
|---|---|
| Analog RCA | V02, A01, A02, A06, S01, F06 |
| HDMI | V01–V05, A02, S01, S02, F01, F02 |
| Network | N01–N04, and every device with a LAN port |
| IR | C01, C02, V01, A01, F15 |
| RS-232 | C01, C03, V01, F01, F02 |
| RG6 (as `rf.*`) | R01, R02, S01, F16, F17, F18 |
| S/PDIF | V02, A02, A06, S01 |
| TOSLINK | A02, S01, F01 |
| Speaker level | A01, A04, A05, F04–F08, F14 |
| Power | P01–P04 and every AC inlet in the catalog |

---

## 5. Connector and media type registries

### 5.1 `ConnectorTypeDef`

`ConnectorTypeDef{id, displayName, genderApplies, contacts, matesWith[], footprint, glyph,
aliases[]}`. `genderApplies` decides whether `CON-002` (both ends the same gender) evaluates and
whether the symbol glyph's fill encodes gender, which is what the schematic idiom actually wanted
when it limited gender encoding to XLR, IEC, DE-9, SpeakON and fibre (CR-059). Gender values are
`male | female | genderless` only; `jack` and `plug` are deleted.

The **glyph** column describes the pin marker drawn at the end of a symbol stub. It is the
connector-class channel, distinct from the domain glyph of §4.3 which is drawn at the run's
midpoint. Where `genderApplies` is true, **filled = female (a panel jack), hollow = male (a panel
plug or inlet)**.

| id | Display | Gender applies | Contacts | Schematic glyph |
|---|---|---|---|---|
| `conn.hdmi_a` · `conn.hdmi_c` · `conn.hdmi_d` | HDMI Type A / C / D | no | 19 | Flattened trapezoid, wider top edge, long axis across the stub; C and D at 0.75× and 0.6× scale |
| `conn.dp` · `conn.mini_dp` | DisplayPort / Mini DisplayPort | no | 20 | Rectangle with one chamfered corner (upper-left), long axis across the stub |
| `conn.usb_c` | USB-C | no | 24 | Stadium (fully rounded ends), 2:1 aspect |
| `conn.bnc75` · `conn.bnc50` | BNC 75 Ω / BNC 50 Ω | **yes** | 1 | Circle with two short bayonet ticks at 3 and 9 o'clock; 50 Ω adds a bar across the centre |
| `conn.f_type` | F-type | **yes** | 1 | Circle with a centre dot on a short stem: the exposed centre conductor |
| `conn.rca` · `conn.rca75` | RCA / RCA 75 Ω | **yes** | 1 | Concentric double circle; `rca75` adds a 75 tick outside the ring at 4 o'clock |
| `conn.hd15` | HD-15 (VGA) | **yes** | 15 | D-shell outline (trapezoid, one long parallel side), three pin rows implied by three dots |
| `conn.mini_din4` | Mini-DIN 4 (S-Video) | **yes** | 4 | Circle with a flat key notch at 12 o'clock and four small dots |
| `conn.3_5mm_ts` · `conn.3_5mm_trs` | 3.5 mm mono / stereo | no | 2 / 3 | Barrel with one ring band (TS) or two (TRS), **the band count is the pinout channel and is why an IR emitter and an IR eye look different on the sheet** |
| `conn.6_35mm_trs` | 1/4 in TRS | no | 3 | As `3_5mm_trs` at 1.4× scale |
| `conn.xlr3` · `conn.xlr5` | XLR3 / XLR5 | **yes** | 3 / 5 | Circle with a latch tab at 12 o'clock and 3 or 5 dots in a triangle/pentagon; **fill encodes gender** |
| `conn.jis_f05` | JIS F05 (TOSLINK / EIAJ optical) | no | — | Square with a shuttered door glyph, a small horizontal bar across the upper third |
| `conn.rj45` | RJ45 (8P8C) | **yes** | 8 | Rectangle with a downward latch tab on the lower edge and eight tick contacts on the upper edge |
| `conn.lc_duplex` · `conn.sc` · `conn.st` | LC duplex / SC / ST | **yes** | — | LC: two small squares side by side; SC: one square with a keyed notch; ST: circle with a bayonet slot |
| `conn.sfp_cage` | SFP / SFP+ / SFP28 cage | no | — | Open-ended rectangle (three sides drawn), a cage, not a connector |
| `conn.de9` | DE-9 (commonly mis-called DB9) | **yes** | 9 | D-shell outline with two dot rows (5 over 4); **fill encodes gender** |
| `conn.euroblock_2` · `_3` · `_5` | Euroblock / Phoenix 2, 3, 5-pole | **yes** | 2 / 3 / 5 | N adjacent squares with a screw-slot diagonal in each |
| `conn.phoenix_4` | 4-pin Phoenix (Cresnet) | **yes** | 4 | Four adjacent squares, outer two shaded (24 V pair), inner two clear (data pair) |
| `conn.screw_terminal` · `conn.knx_terminal` | Screw terminal / KNX bus terminal | no | 2 | Two small squares with screw slots; KNX adds a `+`/`−` polarity mark |
| `conn.binding_post` · `conn.banana` | Binding post / banana | **yes** | 1 | Binding post: circle with a hex nut outline. Banana: elongated pill with a mid-bulge |
| `conn.speakon_nl4` | SpeakON NL4 | **yes** | 4 | Circle with a quarter-turn arrow arc and four dots |
| `conn.punchdown_110` · `conn.keystone` | 110 punchdown / keystone | no | 8 | 110: comb of four short vertical bars over a base line. Keystone: rectangle with one trapezoidal snap ear |
| `conn.iec_c13` · `_c14` · `_c19` · `_c20` | IEC 60320 C13 / C14 / C19 / C20 | **yes** | 3 | Chamfered rectangle (upper corners cut) with three pin dots; C19/C20 at 1.3× and rotated 90° |
| `conn.nema_5_15p` · `_5_15r` · `_5_20p` · `_5_20r` · `conn.nema_l5_30p` | NEMA plugs and receptacles | **yes** | 3 | Two parallel slots over a round ground hole; 5-20 rotates the neutral slot to T-shape; L5-30 draws three curved locking slots |
| `conn.barrel_dc` | DC barrel | **yes** | 2 | Concentric circle with a solid centre pin |
| `conn.hardwired` · `conn.ground_lug` · `conn.unterminated` | Hardwired / ground lug / unterminated | no | — | Hardwired: three short parallel leads into a bracket. Ground lug: the ⏚ earth glyph. Unterminated: a plain open half-circle cap, deliberately drawn as "nothing yet" |

Aliases (`hdmi`, `hdbt`, `rj45`, `xlr`, `spdif`, `toslink`, `euro3`, `bp`, `db9` → `conn.de9`)
live in `ConnectorTypeDef.aliases` and are what the notation in §2 resolves against (CR-058).
**A CI test asserts every `ConnectorTypeDef` referenced by a shipped template has a footprint
entry**: the "zero-authoring correct rear panel" claim is false without it (AC-050/A2.2).

### 5.2 Connector footprints

The auto panel layout needs a real footprint per connector, flowed within
`TemplateBody.chassisWidth` (432 mm default, not 482.6 mm, AC-032), centred on the panel. Power
inlets pin to the far right, network and control to the far left, signal banks centre.

| Connector | Footprint (mm) | Pitch (mm) | Projection (mm, plug + bend) |
|---|---|---|---|
| `conn.hdmi_a` | 15.1 × 5.6 | 19 | 100–125 |
| `conn.rj45` | 15.0 × 13.0 | 17 | 50 |
| `conn.rca` / `conn.rca75` | ⌀ 8.4 | 11 | 45 |
| `conn.xlr3` | ⌀ 24.0 | 27 | 75 |
| `conn.f_type` | ⌀ 9.5 | 13 | 100 |
| `conn.bnc75` | ⌀ 10.0 | 14 | 70 |
| `conn.de9` | 31.0 × 13.0 | 34 | 65 |
| `conn.3_5mm_trs` | ⌀ 7.0 | 10 | 40 |
| `conn.iec_c14` | 27.0 × 20.0 | 30 | 60 |
| `conn.nema_5_15r` | 34.0 × 27.0 | 38 | 65 |
| `conn.euroblock_3` (3.5 mm pitch) | 12.5 × 10.0 | 15 | 35 |
| `conn.binding_post` (pair) | ⌀ 12 × 2 | 20 | 40 |
| `conn.lc_duplex` | 12.5 × 9.0 | 14 | 45 |

`connectorProjection` on a template is **derived from the deepest rear connector actually present**
and never from `bodyDepth + 75 mm`. A rack full of HDMI is 100–125 mm of plug and bend; a rack
full of Cat6a boots is 50 mm. The difference is whether the rear door closes, which is `RCK-012`.

### 5.3 `MediaTypeDef`: the shipped cable types

`MediaTypeDef{id, displayName, shortTag, conductorCount, pairCount, gaugeAwg, impedanceOhms,
shielded, availableJackets[], maxChannelLength, minBendRadius, outerDiameter, supports[],
isPathwayOnly, aliases[]}`. **User-extensible in v1**: an unmatched media value in a Structure CSV
import is not rejected; it is created as a new user media type with a confirmation chip (RJ-009),
which is the difference between an import that works and one that throws.

| id | Display | Tag | Cond / pairs | AWG | Ω | Shielded | Max channel | Supports (primary) |
|---|---|---|---|---|---|---|---|---|
| `media.cat5e` | Cat5e UTP | `C5E` | 8 / 4 | 24 | 100 | no | 100 m | `net.ethernet`, `video.hdbaset` (1080p), `ctl.*` on spare pairs |
| `media.cat6` | Cat6 UTP | `C6` | 8 / 4 | 23 | 100 | no | 100 m | `net.ethernet`, `video.hdbaset` |
| `media.cat6_futp` | Cat6 F/UTP | `C6S` | 8 / 4 | 23 | 100 | **yes** | 100 m | as above; preferred for HDBaseT |
| `media.cat6a_futp` | **Cat6a F/UTP** | `C6A` | 8 / 4 | 23 | 100 | **yes** | 100 m | `net.ethernet` 10G, `video.hdbaset` 4K, `audio.dante` |
| `media.rg6` | **RG6** | `RG6` | 1 coax | 18 | 75 | yes | ~150 m | `rf.catv`, `rf.ota`, `rf.modulated` |
| `media.rg6_quad` | RG6 quad-shield | `RG6Q` | 1 coax | 18 | 75 | yes | ~150 m | `rf.satellite` (swept to 3 GHz), `rf.catv` |
| `media.rg59` | RG59 | `RG59` | 1 coax | 20 | 75 | yes | ~100 m | `video.composite`, `audio.spdif_coax` |
| `media.rg11` | RG11 | `RG11` | 1 coax | 14 | 75 | yes | ~300 m | `rf.catv` trunk |
| `media.coax_video_75` | Precision 75 Ω video coax (1694A class) | `V75` | 1 coax | 20 | 75 | yes | 12G ~45 m | `video.sdi`, `video.component` |
| `media.mic_stp` | Mic / line shielded twisted pair | `STP2` | 2 + shield | 22 | — | yes | 100 m+ | `audio.mic`, `audio.line_bal` |
| `media.aes_110` | 110 Ω AES/DMX cable | `Z110` | 2 + shield | 22 | 110 | yes | 100 m | `audio.aes3`, `ctl.dmx512` |
| `media.dmx_120` | 120 Ω DMX / RS-485 cable | `Z120` | 2 + shield | 22 | 120 | yes | 1200 m | `ctl.dmx512`, `ctl.rs485` |
| `media.16_2` | 16/2 speaker | `16/2` | 2 | 16 | — | no | gauge/length table | `audio.speaker_lowz` |
| `media.16_4` | 16/4 speaker | `16/4` | 4 | 16 | — | no | — | `audio.speaker_lowz` (stereo or bi-amp on one pull) |
| `media.14_2` · `media.14_4` | 14/2 · 14/4 speaker | `14/2` `14/4` | 2 / 4 | 14 | — | no | ~15 m at 8 Ω | `audio.speaker_lowz` |
| `media.12_2` | 12/2 speaker | `12/2` | 2 | 12 | — | no | — | `audio.speaker_lowz` long runs |
| `media.18_2_cv` | 18/2 constant-voltage | `18/2` | 2 | 18 | — | no | hundreds of feet | `audio.speaker_cv` |
| `media.22_2` · `media.22_4` | 22/2 · 22/4 control | `22/2` `22/4` | 2 / 4 | 22 | — | optional | long | `ctl.contact`, `ctl.trigger12v`, `ctl.ir_emitter` |
| `media.cresnet_18_22` | Cresnet (18 AWG power + 22 AWG data) | `CN` | 4 / 2 | 18 + 22 | — | yes | 915 m data · **333 ft at 20 W** | `ctl.cresnet` |
| `media.knx_tp1` | KNX TP1 bus cable | `KNX` | 2 (+2) | 22 | — | yes | 1000 m | `ctl.knx` |
| `media.dali_2c` | DALI 2-conductor (mains-rated) | `DALI` | 2 | 18 | — | no | ~300 m | `ctl.dali` |
| `media.hdmi_passive` | HDMI, passive | `HDMI` | 19 bonded | — | — | yes | 2.1: 3–4.5 m · 2.0: ~7.5 m | `video.hdmi.*` |
| `media.hdmi_active` | HDMI, active copper | `HDMIA` | 19 bonded | — | — | yes | ~7.6 m | `video.hdmi.*`: **direction-locked** |
| `media.hdmi_aoc` | HDMI, active optical (AOC) | `AOC` | hybrid | — | — | — | 15–90 m+ | `video.hdmi.*`, **direction-locked, source/display ends marked** |
| `media.dp_cable` | DisplayPort cable | `DP` | — | — | — | yes | DP80 passive 1.2 m | `video.displayport` |
| `media.usbc_cable` | USB-C cable | `USBC` | — | — | — | yes | ~1–2 m at full BW | `video.usbc_dpalt` |
| `media.om3` · `media.om4` | Fibre OM3 · OM4 multimode | `OM3` `OM4` | 2 strands | — | — | — | ~300–400 m at 10 G | `net.fiber_mm` |
| `media.os2` | Fibre OS2 singlemode | `OS2` | 2 strands | — | — | — | 10–40 km | `net.fiber_sm` |
| `media.pof_toslink` | Plastic optical fibre (TOSLINK) | `POF` | 1 | — | — | — | ~5–10 m (glass 30 m+) | `audio.spdif_optical` |
| `media.so_cord` | SO / SJ power cord | `SO` | 3 | 14–12 | — | no | — | `power.ac_branch` |
| `media.iec_cordage` | IEC rated cordage | `IEC` | 3 | 18–14 | — | no | short | `power.ac_iec` |
| `media.bonding_6awg` | Bonding conductor | `GND` | 1 | 6 | — | no | — | `power.bonding` |
| `media.conduit_emt` · `media.conduit_ent` | EMT conduit · ENT (smurf tube) | `EMT` `ENT` | — | — | — | — | — | **`isPathwayOnly: true`** |
| `media.pull_string` | Pull string | `PULL` | — | — | — | — | — | **`isPathwayOnly: true`** |

`JacketRating` is `cl2 | cl3 | cmr | cmp | lszh | directBurial`. It is not decorative: `CODE-002`
is an error when `Pathway.kind == plenumSpace` and the jacket is not `cmp` or `lszh` (NEC 800.154),
and `CODE-001` is an error when a Class 2/3 conductor shares a pathway with line voltage
(NEC 725.136). Both are acknowledgeable like every other rule (CR-019), an inspector's judgement
outranks ours, but **the finding must exist**, because these are two of the very few checks in the
whole product that protect the user from a code citation and a red-tagged job (AC-027).

### 5.4 Media defaults per template port

Media is a property of the `Link`, not of the `PortDef`, a port does not know what cable will be
pulled to it. But the seed catalog does carry a **suggestion** per bank, used to pre-fill
`Link.media` when a connection is drawn, and it is a suggestion the user can always override:

| Bank kind (shipped example) | Suggested `Link.media` |
|---|---|
| HDMI in/out at ≤ 3 m within a rack | `media.hdmi_passive` |
| HDMI out to a field device | `media.hdmi_aoc` |
| HDBaseT out (V01, V05) | `media.cat6a_futp` |
| Ethernet access port (N01) | `media.cat6` |
| SFP+ / SFP28 uplink (N01, N02, S02) | `media.om4` |
| Speaker out, stereo zone (A01) | `media.16_4` |
| Speaker out, single channel (A04) | `media.14_2` |
| CV speaker out (A05) | `media.18_2_cv` |
| IR emitter out (C01, C02) | `media.22_2` |
| Contact / trigger (C01, P02) | `media.22_2` |
| RS-232 (C01, C03) | `media.mic_stp` |
| Cresnet (C01, F12, F13) | `media.cresnet_18_22` |
| F-type (R01, R02, F16–F18) | `media.rg6`: `media.rg6_quad` when the family is `rf.satellite` |
| IEC / NEMA power | `media.iec_cordage` / `media.so_cord` |

---

## 6. The `.rmdev` seed file format

### 6.1 Shape and rules

A seed template is one `.rmdev` file: **plain, pretty-printed, key-sorted UTF-8 JSON with LF line
endings and 2-space indent**. It is the unit people email each other and paste into forum posts,
and git-diffability is a stated differentiator (CR-091, §4.6).

The file is an **envelope plus a `TemplateBody`**, mirroring `TemplateSnapshot{templateId,
version, contentHash, body, capturedAt}`. *Rejected alternative:* the nested
`identity` / `physical` / `power` / `thermal` grouping of the original device-builder draft, which
invented a second shape for the same data and forced every codec to know both.

Eight rules govern the file and each one is a ruling, not a style preference:

| # | Rule | Ruling |
|---|---|---|
| 1 | **No `double` anywhere.** `depthNm`, `weightUg`, `xNm`, integers in nanometres and micrograms. There is no second unit regime for templates | CR-001, CR-003, CR-063 |
| 2 | `version` is a **monotonic `int`**, not semver. The snapshot key is `"$templateId@$version"` | CR-050 |
| 3 | `PortDef.key` is a **stable, author-assigned `PortKey`** and is *the* template-migration join. `renamedFrom` carries what a UUID cannot express. There is no `portId` | CR-051 |
| 4 | `order` is a `FracIndex` everywhere it appears, on `ports`, `banks`, and every ordered child. Never an `int` index | CR-027 |
| 5 | `unknown: {}` is present on every persisted object, preserved and re-emitted verbatim, so a v1 reader round-trips a v2 file byte-for-byte | §4.4 forward-compat |
| 6 | **Null means unknown**, everywhere. There is no `Extent`, no `Known`/`Unknown` wrapper, and no silent estimate. A rollup reports its unknown count | CR-114, G4 |
| 7 | No `frontImage`, no `rearImage`, no `Money`, no `cost`, no `supplier`, no `signature`, no `provenance` chain. `contentHash` survives; the cryptographic apparatus does not | AC-057, AC-055, AC-042 |
| 8 | `passthroughPairs` is a real array in the file. A passthrough template with missing pairs is a **load warning**, not an error | CR-057 |

`contentHash` mismatch on load is a **warning plus a badge**, never a load failure (AC-042).

### 6.2 Field reference

| Key | Type | Notes |
|---|---|---|
| `schemaVersion` / `minReaderVersion` | `int` × 2 | The two-number envelope; a reader refuses only when `minReaderVersion` exceeds it |
| `kind` | `"device-template"` | |
| `templateId` | UUIDv7 | Stable across every version of this template |
| `version` | `int` | Monotonic. `1` for a freshly seeded template |
| `contentHash` | `"sha256:…"` | Over the canonical serialization of `body` |
| `derivedFrom` | `{templateId, version}?` | Set on a fork; drives CR-062's passive "the catalog has since been corrected" badge |
| `body.category` | `String` | One of the nine §3 category slugs |
| `body.typePrefix` | `String?` | Seeds the device designator format. Asserted not to collide with a system prefix (CR-043) |
| `body.frontU` / `rearU` / `side` | `int`, `int`, enum | The occupancy struct, never a scalar (CR-036) |
| `body.mountMethod` | enum | `rackEars\|shelf\|zeroU\|sideMount\|rearRail\|furniture\|hosted\|notInRack` |
| `body.widthClass` / `nominalSpanTwelfths` | enum / `int` | Half-rack is twelfths, not a fraction (CR-030) |
| `body.chassisWidthNm` | `Len` | **432 mm default for full width, not 482.6 mm** (AC-032) |
| `body.bodyDepthNm` / `connectorProjectionNm` | `Len` / `Len?` | Projection **derived from the deepest rear connector** (AC-022) |
| `body.weightUg` / `maxUnsupportedMassUg` | `Mass` / `Mass?` | Defaults ~7 kg for `rackEars` (AC-028) |
| `body.power` | `PowerProfile` | `typicalWatts` is **never** derived from `nameplateWatts` (RJ-007, G4) |
| `body.banks[]` | `BankDef` | Presentation grouping: symbol edge, brackets, collapse (CR-055) |
| `body.portSets[]` | `PortSetDef` | Electrical grouping: L/R, +/−, Y/Pb/Pr, `atomicConnect` (CR-055) |
| `body.ports[]` | `PortDef` | Three orthogonal axes per port; see §6.3 |
| `body.passthroughPairs[]` | `{frontKey, rearKey, sameNet}` | Empty on non-passthrough templates (CR-057) |
| `body.panelGraphics[]` | `PanelGraphic` | Silkscreen text and rules only; no bitmaps |

### 6.3 Worked example: V01, the HDMI/HDBaseT Matrix 8×8

Abridged only where a bank repeats: where a comment reads *"ports N–M differ only in `key`,
`label`, `designatorHint` and `order`"*, every other field on those ports is byte-identical to the
one shown. The generator expands the §2 notation into exactly this.

```json
{
  "$schema": "https://rackpal.app/schema/device/1.json",
  "contentHash": "sha256:7b1f…",
  "createdAt": "2026-07-18T10:00:00Z",
  "derivedFrom": null,
  "kind": "device-template",
  "minReaderVersion": 1,
  "modifiedAt": "2026-07-18T10:00:00Z",
  "schemaVersion": 1,
  "templateId": "0192f3a7-6c40-7d21-9b55-2f9a1c0e4d31",
  "unknown": {},
  "version": 1,

  "body": {
    "accentColor": "#0072B2",
    "alternateMountMethods": ["shelf"],
    "bodyDepthNm": 330000000,
    "category": "video-distribution",
    "chassisWidthNm": 432000000,
    "connectorProjectionNm": 68000000,
    "customPanelWidthNm": null,
    "description": "Generic 8-input, 8-output HDMI matrix with mirrored HDBaseT zone outputs, de-embedded balanced zone audio, per-output IR, LAN and RS-232 control.",
    "displayName": "HDMI/HDBaseT Matrix 8x8",
    "frontU": 3,
    "isContainer": false,
    "isPassthrough": false,
    "manufacturer": "Generic",
    "maxUnsupportedMassUg": 7000000000,
    "model": "MTX-8x8-HDBT",
    "mountMethod": "rackEars",
    "nominalSpanTwelfths": 12,
    "passthroughPairs": [],
    "rearU": 3,
    "requiresClearanceAboveU": 0,
    "requiresClearanceBelowU": 0,
    "side": "both",
    "tags": ["hdbaset", "4k60", "matrix", "residential", "commercial"],
    "thermalClass": "convection",
    "typePrefix": "MTX",
    "unknown": {},
    "weightUg": 7300000000,
    "widthClass": "full",

    "power": {
      "apparentVA": 58,
      "btuPerHourOverride": null,
      "inletPlug": "iecC14",
      "isContinuousLoad": true,
      "nameplateWatts": 90,
      "nominalVolts": 120,
      "poeBudgetWatts": null,
      "powerFactor": 950,
      "standbyWatts": 8,
      "typicalWatts": 55,
      "unknown": {}
    },

    "banks": [
      { "abbr": "IN",   "collapseInSymbol": true,  "key": "hdmi-in",   "label": "HDMI Inputs",            "order": "a0", "symbolSide": "left",   "unknown": {} },
      { "abbr": "HBT",  "collapseInSymbol": true,  "key": "hdbt-out",  "label": "HDBaseT Outputs",        "order": "a1", "symbolSide": "right",  "unknown": {} },
      { "abbr": "OUT",  "collapseInSymbol": true,  "key": "hdmi-out",  "label": "Mirrored HDMI Outputs",  "order": "a2", "symbolSide": "right",  "unknown": {} },
      { "abbr": "AUD",  "collapseInSymbol": true,  "key": "aud-out",   "label": "Zone Audio",             "order": "a3", "symbolSide": "right",  "unknown": {} },
      { "abbr": "CTL",  "collapseInSymbol": false, "key": "control",   "label": "Control",                "order": "a4", "symbolSide": "top",    "unknown": {} },
      { "abbr": "PWR",  "collapseInSymbol": false, "key": "power",     "label": "Power",                  "order": "a5", "symbolSide": "bottom", "unknown": {} }
    ],

    "portSets": [],

    "ports": [
      {
        "acceptedFamilies": ["video.hdmi.1_4", "video.hdmi.2_0", "video.hdmi.2_1"],
        "balanced": null,
        "bankKey": "hdmi-in",
        "channelIndex": null,
        "conductorCount": 19,
        "connector": "conn.hdmi_a",
        "designatorHint": "J01",
        "direction": "sink",
        "face": "rear",
        "gender": "genderless",
        "impedanceOhms": null,
        "key": "hdmi.in.1",
        "label": "HDMI IN 1",
        "maxConnections": 1,
        "notes": null,
        "order": "a0",
        "pinoutVariant": null,
        "renamedFrom": [],
        "returnChannel": null,
        "setKey": null,
        "setRole": null,
        "signalFamily": "video.hdmi.2_0",
        "topology": "p2p",
        "unknown": {}
      },
      // ports hdmi.in.2 … hdmi.in.8 differ only in key, label, designatorHint and order

      {
        "acceptedFamilies": ["video.hdbaset"],
        "bankKey": "hdbt-out",
        "conductorCount": 8,
        "connector": "conn.rj45",
        "designatorHint": "J09",
        "direction": "source",
        "face": "rear",
        "gender": "female",
        "key": "hdbt.out.1",
        "label": "HDBT OUT 1",
        "linkSpeedMbps": 100,
        "maxConnections": 1,
        "order": "b0",
        "poe": { "class": null, "role": "pse", "standard": "poh", "type": null, "watts": 100, "unknown": {} },
        "renamedFrom": [],
        "signalFamily": "video.hdbaset",
        "topology": "p2p",
        "unknown": {}
      },
      // ports hdbt.out.2 … hdbt.out.8 differ only in key, label, designatorHint and order

      {
        "acceptedFamilies": ["video.hdmi.1_4", "video.hdmi.2_0", "video.hdmi.2_1"],
        "bankKey": "hdmi-out",
        "conductorCount": 19,
        "connector": "conn.hdmi_a",
        "designatorHint": "J17",
        "direction": "source",
        "face": "rear",
        "gender": "genderless",
        "key": "hdmi.out.1",
        "label": "HDMI OUT 1",
        "maxConnections": 1,
        "order": "c0",
        "renamedFrom": [],
        "signalFamily": "video.hdmi.2_0",
        "topology": "p2p",
        "unknown": {}
      },
      // ports hdmi.out.2 … hdmi.out.8 differ only in key, label, designatorHint and order

      {
        "acceptedFamilies": ["audio.line_bal", "audio.line_unbal"],
        "balanced": true,
        "bankKey": "aud-out",
        "conductorCount": 3,
        "connector": "conn.euroblock_3",
        "designatorHint": "J25",
        "direction": "source",
        "face": "rear",
        "gender": "male",
        "impedanceOhms": null,
        "key": "aud.out.1",
        "label": "AUD OUT 1",
        "level": "line",
        "maxConnections": 1,
        "order": "d0",
        "renamedFrom": [],
        "signalFamily": "audio.line_bal",
        "topology": "p2p",
        "unknown": {}
      },
      // ports aud.out.2 … aud.out.8 differ only in key, label, designatorHint and order

      {
        "acceptedFamilies": ["ctl.ir_receiver"],
        "bankKey": "control",
        "conductorCount": 3,
        "connector": "conn.3_5mm_trs",
        "designatorHint": "J33",
        "direction": "sink",
        "face": "rear",
        "gender": "female",
        "key": "ir.in",
        "label": "IR IN",
        "maxConnections": 1,
        "nominalVoltage": 12,
        "order": "e0",
        "pinoutVariant": "xantech-stereo",
        "renamedFrom": [],
        "signalFamily": "ctl.ir_receiver",
        "topology": "p2p",
        "unknown": {}
      },
      {
        "acceptedFamilies": ["ctl.ir_emitter"],
        "bankKey": "control",
        "conductorCount": 2,
        "connector": "conn.3_5mm_ts",
        "designatorHint": "J34",
        "direction": "source",
        "face": "rear",
        "gender": "female",
        "key": "ir.out.1",
        "label": "IR OUT 1",
        "maxConnections": 2,
        "maxCurrentMa": 100,
        "order": "e1",
        "pinoutVariant": "mono-tip-sleeve",
        "renamedFrom": [],
        "signalFamily": "ctl.ir_emitter",
        "topology": "p2p",
        "unknown": {}
      },
      // ports ir.out.2 … ir.out.8 differ only in key, label, designatorHint and order

      {
        "acceptedFamilies": ["net.ethernet"],
        "bankKey": "control",
        "conductorCount": 8,
        "connector": "conn.rj45",
        "designatorHint": "J42",
        "direction": "bidirectional",
        "face": "rear",
        "gender": "female",
        "key": "lan",
        "label": "LAN",
        "linkSpeedMbps": 100,
        "maxConnections": 1,
        "order": "e9",
        "poe": null,
        "renamedFrom": [],
        "signalFamily": "net.ethernet",
        "topology": "star",
        "unknown": {}
      },
      {
        "acceptedFamilies": ["ctl.rs232"],
        "bankKey": "control",
        "conductorCount": 3,
        "connector": "conn.de9",
        "designatorHint": "J43",
        "direction": "bidirectional",
        "face": "rear",
        "gender": "female",
        "key": "rs232",
        "label": "RS-232",
        "maxConnections": 1,
        "order": "f0",
        "renamedFrom": [],
        "serial": { "baud": 9600, "data": 8, "flow": "none", "parity": "none", "role": "dte", "stop": 1, "unknown": {} },
        "signalFamily": "ctl.rs232",
        "topology": "p2p",
        "unknown": {}
      },
      {
        "acceptedFamilies": ["power.ac_iec"],
        "bankKey": "power",
        "conductorCount": 3,
        "connector": "conn.iec_c14",
        "designatorHint": "J44",
        "direction": "sink",
        "face": "rear",
        "gender": "male",
        "key": "ac.in",
        "label": "AC IN",
        "maxConnections": 1,
        "nominalVoltage": 120,
        "order": "g0",
        "power": { "backing": null, "outletMode": null, "receptacle": null, "role": "inlet", "sequenceDelayMs": null, "sequenceStep": null, "unknown": {} },
        "renamedFrom": [],
        "signalFamily": "power.ac_iec",
        "topology": "p2p",
        "unknown": {}
      }
    ],

    "panelGraphics": [
      { "kind": "text", "text": "HDMI INPUTS",  "xNm": 40000000,  "yNm": 8000000,  "unknown": {} },
      { "kind": "text", "text": "HDBT OUTPUTS", "xNm": 40000000,  "yNm": 52000000, "unknown": {} }
    ]
  }
}
```

> JSON does not permit comments. The `//` lines above are documentation of an elision in this
> document only; the shipped file contains all 44 port objects. A generator test asserts that
> expanding the §3.1 V01 notation produces exactly this file, and a round-trip test asserts that
> reading and re-emitting it is byte-identical.

### 6.4 What the example demonstrates, field by field

| Observation | Why it is there |
|---|---|
| `connector: "conn.rj45"` with `signalFamily: "video.hdbaset"` on the HBT bank, next to `connector: "conn.rj45"` with `signalFamily: "net.ethernet"` on `lan` | The three-axis split, in one file. `SIG-001` compares families, not connectors, which is the only reason it works |
| `acceptedFamilies` on `hdbt.out.1` lists **only** `video.hdbaset` | `net.ethernet` is deliberately absent. This single omission is what makes the highest-value check in the product fire |
| `poe.standard: "poh"`, `role: "pse"`, `watts: 100` | PoH is not PoE. A standard PoE PSE is not interoperable with it, and 100 W into a switch port is a damaged switch |
| `pinoutVariant` present and non-null on **both** IR ports | Safety-adjacent, so an uncited value blocks the template from shipping (AC-052) |
| `gender: "genderless"` on HDMI, `"female"` on RJ45 and DE-9, `"male"` on the C14 inlet | `ConnectorTypeDef.genderApplies` decides whether `CON-002` evaluates. `jack` and `plug` do not exist (CR-059) |
| `power.role: "inlet"` on a `sink` port | Inlet and outlet are **roles on a `power.*` family**, not directions (CR-060) |
| `power.role: "inlet"` declared on the C14 port | Since DR-171 the chip strip's outlet count reads the ports: an undeclared inlet is an outlet nobody counts |
| `apparentVA: 58` alongside `typicalWatts: 55` and `powerFactor: 950` | Circuit loading is computed in VA. A switch-mode supply at 950‰ is close; an amplifier at 650‰ is not, and that gap is how a rack that "calculated fine" trips a breaker |
| `btuPerHourOverride: null` | Heat is derived, `typicalWatts × 3.412142`, never stored (CR-005) |
| `maxUnsupportedMassUg: 7000000000` with `weightUg: 7300000000` | 7.3 kg against a 7 kg front-ear limit: `RCK-013` warns on this template the moment it is rail-mounted without support (AC-028) |
| `chassisWidthNm: 432000000` | Not 482.6 mm. The auto panel layout flows inside the chassis, not across the ears (AC-032) |
| `connectorProjectionNm: 68000000` | Derived from the deepest rear connector on this panel, a C14 inlet at 60 mm and an HDMI plug at 100 mm would push it further; this template's deepest is the DE-9 shell plus cable bend |
| `key: "hdmi.in.1"`, `renamedFrom: []` | The migration join. A port renamed in v2 carries its old key here, and a removed port with conductors is **orphaned, never deleted**: there is no `[Del]` in the Update Manager (CR-052) |
| `order: "a0"`, `"b0"`, `"e1"` | `FracIndex` strings, so inserting a port between two others never renumbers anything (CR-027) |
| `unknown: {}` on every object | Forward compatibility. A v1 reader preserves and re-emits v2 keys it does not understand |
| No `frontImage`, no `cost`, no `signature` | Cut from v1, and cut means absent from the schema, not null (AC-057, AC-055, AC-042) |

> **VERIFY:** the concrete `FracIndex` string encoding (`"a0"`, `"a1"`, `"b0"` above) is
> illustrative of the base-62 midpoint scheme these libraries conventionally use. The exact
> alphabet and midpoint algorithm are fixed once in `rackmate_core/units/frac_index.dart` and this
> document follows whatever ships there. Nothing else in the format depends on the encoding.

---

## 7. Acceptance criteria and CI assertions

These are named milestone exit criteria, not aspirations. The catalog lands in **M4: the device
builder**, but the registries it depends on land earlier and gate M2.

### 7.1 The nine registry criteria

Reproduced from canon §6.7, which governs.

1. **Provenance.** Every numeric field in every registry entry and every shipped template carries a
   cited source (manufacturer datasheet, published standard, or measured) in
   `assets/catalog/sources.md`. An entry whose safety-adjacent fields, `pinoutVariant`,
   `impedanceOhms`, `poeBudgetWatts`, `maxRunLengthPassive`, `maxUnsupportedMass`, PoE class watts
, are uncited **does not ship** (AC-052).
2. **CVD verification.** The `T0.01` legend sheet is rendered and checked under **protanopia and
   deuteranopia simulation**, and every pair of domains must remain distinguishable (AC-054).
3. **Greyscale verification.** The same legend is printed on a **real greyscale office laser** at
   ANSI B and photocopied once, and every one of the ten requirement-4 types must remain
   identifiable. The entire dash-and-weight argument is predicated on this test, so it is run on
   hardware, not simulated (AC-058/D13).
4. **PAL-1 is a unit test over rendered family values.** For every shipped `SignalFamilyDef`,
   compute *(L of its effective hue, dash class of its effective dash, effective weight)*,
   *effective* meaning **after** any `colorOverride`, `dashOverride` or weight override declared in
   the signal-family registry, not the domain base value. For every pair in **different** domains
   with |ΔL| < 0.10, assert dash classes differ **or** weights differ by ≥ 1.4. Within-domain pairs
   are exempt from that check and must instead differ in dash, weight or glyph; the exemption is a
   domain-equality check, never an allowlist.
5. **Dash floor is a unit test.** Assert every shipped dash period ≥ **4.5** pt (1.5875 mm), 
   4.25 pt is 1.4992 mm and is below the 1.5 mm floor the rule derives from.
6. **Glyph coverage is a unit test.** Assert every glyph in the registry resolves in `RackBody`
   (IBM Plex Sans) or `Noto Sans Symbols 2`. A tofu box in an exported drawing is a defect this
   test exists to prevent.
7. **Referential integrity is a unit test.** Every `defaultConnector` resolves; every
   `typicalMedia` entry resolves; every `MediaTypeDef.supports` entry resolves; every
   `SignalFamilyDef.domain` resolves to one of the eight; every connector referenced by a shipped
   template has a footprint entry (AC-050/A2.2); no two catalog templates share a `typePrefix`
   with a system prefix (CR-043).
8. **DRC fixtures.** Every rule that reads this registry ships with one known-bad design that must
   produce exactly that finding and one known-good near-miss that must not. **No rule ships without
   its pair** (AC-051), and this is also the gate that holds the v1 rule catalogue at 27.
9. **Domain-expert review** of the shipped registry values and of the catalog is a named milestone
   exit criterion, not a code review.

### 7.2 Catalog-specific CI assertions

Added by this document on top of the nine above. Each is cheap and each catches a class of defect
that reaches a drawing.

| # | Assertion | Catches |
|---|---|---|
| C1 | Every `.rmdev` in `assets/catalog/` parses, round-trips byte-identically, and has `schemaVersion == 1` | A hand-edited seed file that no longer loads |
| C2 | The template count in `assets/catalog/` equals the number in the §3.10 summary table of this document, and appears in no prose in any document | Four contradictory counts, which is the state CR-061 resolved |
| C3 | Expanding each §3 notation block reproduces its `.rmdev` exactly | The spec and the data drifting apart |
| C4 | No template's `typePrefix` collides with another template's or with a system prefix (`STR`, `RK`, `W`, `N`, `J`) | CR-043's `STR` / `STRM` collision, generalised |
| C5 | Every `PortDef.key` is unique within its template, and stable across versions of that template | A migration that silently orphans conductors |
| C6 | Every `PortDef.designatorHint` is unique within its template | `Port.designator` collisions at instantiation (I-12, corrected to per-device by CR-042) |
| C7 | Every 3.5 mm port whose family is `ctl.ir_emitter` or `ctl.ir_receiver` has a non-null `pinoutVariant` **and** a citation | The destructive pinout hazard, which is the one catalog defect that damages hardware |
| C8 | Every port whose family is `audio.spdif_coax` has `impedanceOhms == 75`; every `audio.aes3` has `110` | Intermittent dropouts that look like a bad cable |
| C9 | Every `PortSetDef` referenced by a `setKey` exists, and every `atomicConnect` set has ≥ 2 members | A half-declared stereo pair, which makes the connect gesture undefined |
| C10 | Every `isPassthrough` template has a `passthroughPairs` entry for every front port | A patch panel whose trace dead-ends at the panel |
| C11 | Every template with an AC inlet declares it as a `power.*` port with `role: inlet`, and every outlet it provides as `role: outlet` (the counts are read off those ports, DR-171) | The outlet rollup being quietly wrong, which shows up on install day |
| C12 | Every `mountMethod: rackEars` template with `weightUg > maxUnsupportedMassUg` is reachable by an `RCK-013` fixture | A rule with no object to fire on |
| C13 | Every one of requirement 4's ten named types is produced by at least one shipped template port | The §4.5 coverage table becoming aspirational |
| C14 | Every field-device template has `frontU == 0 && rearU == 0 && side == "none" && mountMethod == "notInRack"` and **no** `bodyDepthNm` | A ceiling speaker being asked for a thermal class |
| C15 | No `.rmdev` contains a JSON number with a fractional part | The floating-point millimetres regression (CR-063) |

### 7.3 Fixture obligations this catalog carries

Four of the sample projects are authored as **real `.rackpal` files** and do triple duty as the
golden corpus, the performance fixtures and the screenshot source (AC-052). The catalog owes them
the following, and a sample project that cannot be built from shipped templates alone is a catalog
bug:

| Sample project | Must exercise | Templates involved |
|---|---|---|
| Residential media rack, 12U wall box | The weight-capacity and CG story; a hosted AVR on a shelf; HDBaseT to two displays | A02, X03, V01, V05-role-RX, F01, P01, N01 |
| Whole-home audio, 24U floor rack | Sixteen speaker zones, `atomicConnect` on 16/4, `ELE-004` reachable | A01, F04, F05, F14, P02, P03 |
| Commercial 70 V paging, 18U | `audio.speaker_cv` end to end, tap selection, `ELE-005`/`ELE-006` reachable | A05, A03, F08, C01 |
| Structure-led rough-in, no equipment list yet | `structure.undetermined` home runs with unbound ends; the Pull Sheet before the design exists | Structure device + N03, and **no rack-side device at all** |

The fourth is the one that matters most and it is the one no draft of this catalog could have
supported. It exports a complete Pull Sheet from a project whose equipment list is empty, because
a `Link` endpoint may be a `PlaceEndpoint` ("proj shelf, beam 3") rather than a port
(AC-018, CR-107). The catalog's job there is to stay out of the way.

---

## 8. Open questions this document does not settle

Listed so a reader does not mistake silence for a decision. Each is tracked in canon §10.

Two that used to be listed here are now closed and are recorded as rulings, not questions: **§10.2
is answered: residential CI is the primary market and commercial capability never fronts the UI
(DR-002)**, which sets the archetype mix and points the next catalog pack at STB / keypad / 70 V
rather than DMX / DALI / Dante; and **§10.4 is answered: the device builder ships in v1
(DR-003)**, so the catalog is never asked to stand in for it.

| # | Question | Bearing on the catalog |
|---|---|---|
| §10.5 | Metric or imperial as the shipped default | Display only. Storage is nanometres and micrograms either way (CR-001, CR-003), so this is a `UnitFormatter` default, not a catalog change |
| §10.9 | Generic archetypes forever, or a real-SKU catalog eventually | The single largest open question for this document. `derivedFrom` (CR-062) and `manufacturer`/`model` as free strings keep the door open at zero cost today |
| §10.12 | The small calls with an owner rather than an essay | Includes the exact `FracIndex` encoding flagged VERIFY in §6.4 |

---

**Governing documents.** Where this document conflicts with the canonical decision record, the
record wins and this document is the defect. Where it conflicts with any `design-*.md` working
paper in [docs/research/](../research/), this document wins, those papers are non-normative
rationale.









