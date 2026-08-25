# Device Builder

The Device Builder is the authoring surface for a `DeviceTemplate`, the library object that owns a device's physical facts and its port list, and from which every placed `DeviceInstance` inherits. It exists because requirement 2 demands it and because a seeded catalog can only ever cover archetypes; the real device in the integrator's hand is never quite the archetype. This document covers the ordinary builder and the template library only. The **Structure device** has a fundamentally different entry axis (room × media × quantity, not port-by-port) and its own editor, see [Structure device](07-structure-device.md).

---

## 1. The governing ruling: three required fields

The single most consequential decision about this screen is **AC-049**. The critique's diagnosis is accepted in full: the port grid was never the barrier. The barrier was twelve physical fields and six power fields standing in front of it, most of which the user does not know and half of which are absent from the spec sheet they are holding. The result was a guess (which violates G4) or a stall.

> **Ruling (AC-049): three required fields — `displayName`, RU height, `typePrefix` — then ports, then done.** Everything else is optional with a visible `unknown` state that the app degrades honestly around (CR-114). A template saved with three fields is **not** "incomplete"; it is a template.

*Rejected alternative:* the original seven-section form with three required sections (identity, physical, and a category enum). It gated the product's output behind data entry the user could not perform.

Consequences that follow mechanically:

| Consequence | Ruling |
|---|---|
| `null` means unknown everywhere. No `Extent`, no `Known`/`Unknown` wrapper. | CR-114 |
| `typicalWatts` **never** defaults to 50% of `nameplateWatts`. A fabricated number that reaches a circuit-loading calculation is worse than a blank. | AC-039, G4 |
| `connectorProjection` is **derived from the deepest rear connector footprint**, never `bodyDepth + 75 mm`. | AC-032, CR-036 |
| Every rollup that consumes a template field reports its unknown count, *"Total weight 148 lb · 3 devices have no weight"*. | CR-114, G4 |
| The `Draft` flag survives **only** for templates saved with zero ports and no category. | AC-049 |

The device builder ships in v1 and M4 keeps its position (DR-003). This is settled; it is no longer an open question, and "move M4 after M6" is no longer an available schedule lever.

---

## 2. Shell layout

A full-window editor, not a modal, a modal cannot host a 68-row virtualised grid. Three persistent panes.

```
┌─ Device Builder ── HDMI Matrix 16×16 ──────────────── v3 ─ [Save] [Save & Close] ─┐
│ ┌──────────────┬───────────────────────────────────────┬───────────────────────┐ │
│ │ ● Identity   │  ┌ Quick Add ─────────────────────┐   │  ▾ Rack strip         │ │
│ │ ● Physical   │  │ ⌨ 16 hdbt out "HDBT OUT {n:2}" │   │  ┌───────────────┐    │ │
│ │ ○ Power      │  │                      [ Add ▸ ] │   │  │▪ MTX-1  ▪▪▪▪▪ │ 4U │ │
│ │ ● PORTS  68  │  └────────────────────────────────┘   │  └───────────────┘    │ │
│ │ ○ Panel AUTO │  [Matrix I/O…] [Switch ports…] [Paste]│                       │ │
│ │ ○ Appearance │  ┌──────────────────────────────────┐ │  ▾ Symbol             │ │
│ │ ○ Notes      │  │ ▾ HDMI Inputs            16 ports│ │  ┌────────────┐       │ │
│ │──────────────│  │ ⠿☐ Label  Desig Conn Sig Dir Side│ │  │MTX-1       │       │ │
│ │ BANKS        │  │ ⠿☐ HDMI…1  J01  hdmi hdmi20 i  R │ │  ├16⊳ HDMI  ⊲16┤      │ │
│ │  HDMI Inputs │  │ ⠿☐ HDMI…2  J02  hdmi hdmi20 i  R │ │  │ 1⊳ LAN     │       │ │
│ │  HDBT Outputs│  │ ▾ HDBT Outputs           16 ports│ │  └────────────┘       │ │
│ │  Mirror Out  │  │ ⠿☐ HDBT…1  J17  rj45 hdbt  o  R  │ │                       │ │
│ │  Control     │  └──────────────────────────────────┘ │  ▾ Rear panel  71%    │ │
│ │  Power       │  68 ports · 5 banks · Rear 67 / Front 1│ ┌───────────────┐     │ │
│ └──────────────┴───────────────────────────────────────┴───────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────┘
   left rail 200 px          centre (flex)                right dock 340 px
```

The left rail carries the section list plus the **bank tree**, which becomes the primary navigation once you are in the Ports section. The right dock swaps to a **batch inspector** when more than one grid row is selected.

**What M4-J1 built, and the two decisions the drawing above does not make.** The tree is mounted **on every section, not only on Ports**: a bank count is a fact about the template in the way the section list is, and a rail that grew and shrank as a person moved down the sections would move the tile under their cursor. Clicking a bank therefore **switches to Ports and jumps to that band**, so the tree is never navigation into a section a person is not in. It **jumps and hides nothing**: filtering the grid to one bank was the alternative and was declined, because every §4.6 operation acts on a selection measured against the full declared order, so `Fill down`, `Renumber…` and `Duplicate` would begin reasoning about rows the person cannot see. The grid already has two ways of not showing a row, band collapse and a sort badge, and both announce themselves in the header. **A declared bank with no ports has no band**, so it is a tree row with `0 ports` that navigates nowhere, and it is exactly the bank `Ctrl+M` was waiting for.

**The tree lists bands, not `BankDef`s, and it is in the grid's order.** It reads through `movableBanks`, the same function `Ctrl+M` offers destinations from, so it reproduces `buildPortTable`'s first-appearance banding rather than sorting by `BankDef.order`. **`BankDef.order` has no reader anywhere in the tree** (docs/12 §5.3.17): making the tree its first would put the navigation out of step with the surface it navigates. `Not in a bank` and a `bankKey` naming no `BankDef` are rows too, because a person looking for the loose ports is looking for a band; neither carries a menu, because neither is a bank.

The builder owns its **own undo stack**, scoped to the template being edited and discarded on close-without-save (CR-106). It is the same `Command`/`UndoStack` machinery as the document, generic over an aggregate, nobody builds a second mechanism. Library operations (delete a template, import, set favourite) are *not* undoable and are therefore individually confirmable or trivially reversible.

---

## 3. The metadata form

Sections in rail order. Only section 1's three starred fields block `Save`.

| # | Section | Required |
|---|---|---|
| 1 | Identity & Classification | `displayName`★, `heightU`★ (= `frontU`), `typePrefix`★ |
| 2 | Physical & Mounting | no |
| 3 | Power & Thermal | no |
| 4 | **Ports (I/O)** | no: blank panels legitimately have zero |
| 5 | Panel Layout | no: auto, see §5 |
| 6 | Appearance | no |
| 7 | Notes & Publish | no |

### 3.1 Identity

| Field | Type | Notes |
|---|---|---|
| `displayName` ★ | text | "HDMI Matrix 16×16" |
| `manufacturer` | text | **Pre-filled with the literal `Generic` (DR-056, §11.55).** `Generic` is the trade's standard token for *unspecified / by others* in a manufacturer column, so it is not a fabricated value under G4 but the industry's own spelling of what `—` means. The whole seeded catalog is `Generic` too, and confirmed decision 2 rules out a SKU library. Consequence, stated rather than hidden: the unknown rollup reports **zero** devices missing a manufacturer, because the field holds a value (§11.55.5). |
| `model` | text | **NOT defaulted; left blank (DR-056 §11.55.5).** No trade convention was offered for a model string and an invented one would be the fabrication the manufacturer default is careful not to be, so an untouched `model` prints `—` and counts as unknown. |
| `category` | enum | **`kCatalogCategoryOrder`, which is the source of truth and carries NINE**: Video Distribution & Switching · Audio · Network & Cabling Infrastructure · Control · Sources · RF / Coax · Power · Passive & Mechanical · Field Devices. The eight-item list this row used to spell abbreviated three of those and dropped `Field Devices` altogether; the builder reads the constant the palette groups by, because a second list is how the two come to disagree about what a device is (DR-059 §11.58.6). Optional (AC-049). |
| `typePrefix` ★ | text, 2–4 chars | `MTX`, `AMP`, `SW`, `PP`, `UPS`. Seeds the device designator format `{TYPE_PREFIX}{SEP}{SEQ}` → `MTX-1` (CR-041, CR-045). Auto-suggested from category when one is chosen. |
| `tags` | chip input | `hdbaset`, `4k60`, `poe`, `residential` |
| `templateId` | UUID, read-only | Stable across every version. |
| `version` | **`int`**, read-only | Monotonic. **Not semver**: CR-050. |

*Rejected alternative (CR-050):* `version: {major, minor, patch}` computed from the diff. A semver whose components are computed adds a vocabulary without adding a capability, and `TemplateRef` cannot hold one. The **change class** (safe / additive / breaking) is still computed from the diff and displayed prominently; it is simply not encoded in the number.

### 3.2 Physical & mounting

Occupancy is a struct, never a scalar (CR-036): `frontU`, `rearU`, `side`, `mountMethod`, `widthClass`, `nominalSpanTwelfths`. A 2U patch panel is `{front: 2, rear: 2}`; a rear lacing bar is `{front: 0, rear: 1}`; a 0U PDU is `{0, 0, side: zeroUVertical}`. Half-rack width is `widthClass: half` plus `nominalSpanTwelfths` (CR-030), never "0.5 rack width", because 9.5 / 10 / 10.4 / 10.5 in all ship.

All lengths are `Len` (int64 nanometres, CR-001) and all masses `Mass` (int64 micrograms, CR-003). Serialized names carry the unit: `depthNm`, `weightUg`, `chassisWidth`. `chassisWidth` defaults to **432 mm** for `widthClass: full`, not 482.6 mm, 482.6 is the *panel* width including ears, and flowing connectors across it draws jacks out past the rails on the very view that gets taped inside the rack door (AC-032). `maxUnsupportedMass` defaults to ~7 kg for `rackEars` and feeds `RCK-013` (AC-028).

Depth and weight are **optional, with a visible `unknown` state**: the fields are `Len? bodyDepth` and `Mass? weight`, and an untouched field stays unknown rather than acquiring a default. Unknown **serializes as an absent key, never an explicit `null`**: the codec omits it, and an absent key reads back as unknown. This is AC-049's three-required-fields promise made concrete: nothing here blocks `Save`, and every rollup that consumes these fields reports its unknown count instead of fabricating a number (CR-114, G4).

### 3.3 Power & thermal

`PowerProfile` fields are all nullable `int` and all optional: `nameplateWatts`, `typicalWatts`, `standbyWatts`, `nominalVolts`, `apparentVA`, `powerFactor` (permille), `poeBudgetWatts`, `btuPerHourOverride`, `outletsProvided`, `outletsConsumed`, `isContinuousLoad`, `inletPlug`.

Three things the form does **not** do:

1. It does not derive `typicalWatts`. The field sits blank with the hint *"typical draw is usually 30–70% of nameplate"* and stays blank until a human types a sourced number (AC-039).
2. It does not store heat. BTU/h is derived as `typicalWatts × kBtuPerWattHour` where the constant is `3.412142`, defined once in `rackmate_core/units/thermal.dart` (CR-005). `btuPerHourOverride` exists only for the rare manufacturer figure that disagrees with the arithmetic.
3. It does not compute circuit loading in watts. Loading is computed in **VA**, because a linear-supply amplifier at PF 0.65 under-reports current by 35% on exactly the gear where it matters (CR-056, AC-020).

`outletsProvided` and `outletsConsumed` are read-only, counted from ports whose family is `power.*` with `PortPowerSpec.role` of `outlet` / `inlet`. External power bricks count: a 4×4 matrix with a 12 V barrel jack still eats a PDU outlet.

### 3.4 Appearance

`accentColor` and a **`glyph`** from a built-in set of **17 marks plus `none`**, both defaulting from category (DR-059, §11.58).

**The glyph is ruled in rather than assumed in, and the reason is CR-078's.** This section named it from M0 and no ruling did, so it was put to the user as a scope question and ruled to ship. The argument that carried it is not decoration: *"hue is never used alone"*, because hue dies in greyscale and on a photocopy, and the elevation is the sheet that gets taped inside the rack door. A census found `accentColor` authored on **0 of the 48 seeded templates** and read by **no renderer** (`draw/scene/device_layer.dart` fills every device with `palette.deviceFill`), so shipping it alone would have been hue alone on the worst sheet for it.

**THE ACCENT NOW REACHES THAT SHEET TOO, AND THE TWO SHIP TOGETHER (DR-080, §11.79).** `accentColor` resolves to the device **body fill**, instance override first, then the template body, then `palette.deviceFill` when both are absent. The designator, name, type and badge take their colour from the **resolved fill's WCAG relative luminance** rather than from `RackStyle`, because one of the eight shipped swatches is pure black and `device_layer.dart` draws all four text ops over the fill. DR-059's price for this was measured and was wrong in both halves: no starter and no seed carries the key, so **no golden moves**, and `pal1_check.py` has no device concept to clear. **It must not ship before the 17 marks** (`#694`): until they exist, two accented devices differ by hue and nothing else, which is the one thing CR-078 forbids.

**It is drawn as geometry, never as a codepoint** (§11.58.4). `draw/scene/family_glyph.dart` exists because the signal glyph once was one: Jost carries none of those characters, so the PDF measurer returned a near-zero advance while the screen fell back to a system font and drew it full width, and the field saw a family token printed over a net name.

**The value set is capped at 17 by legibility, not by taste**: the mark draws 1U tall on a greyscale photocopy, so silhouettes group by what a box *is* and several catalog ids share one. Defaults key off `kCatalogCategoryOrder`, the palette's own **nine** categories, which is the same list §3.1 abbreviates to eight; that constant is the source of truth and this table is not a second one.

**M4-D ships the enum, the field, the codec and the defaults; the 17 vector marks and their renderers are M4-K's**, where a glyph can be judged against a rendered panel (§11.58.7).

**No device images.** `frontImage` and `rearImage` are cut from v1 (AC-057): they resolve nothing the output needs, add an image-decode import surface, and add ~1 MB per template.

---

## 4. The I/O editor

This is the product, and the design premise is binding: **the I/O editor is a spreadsheet, not a form.** Integrators live in Excel. Every ergonomic they already know (fill-down, multi-select, TSV paste, Tab/Enter navigation) works. Any interaction costing one click per port is a design failure.

### 4.1 Quick Add: docked, never modal

```
┌─ Quick Add ─────────────────────────────────────────────────────────────────┐
│ ⌨  16 hdbt out "HDBT OUT {n:2}" @HDBT Outputs                    [ Add ▸ ]  │
│ ⇅  Qty[16] Connector[conn.rj45 ▾] Family[video.hdbaset ▾] Dir[Out ▾]        │
│    Face[Rear ▾]  Label[HDBT OUT {n:2}]  Bank[+ HDBT Outputs ▾]              │
└─────────────────────────────────────────────────────────────────────────────┘
```

Focus lands here on entering the section and **returns here after every add**, so consecutive banks are pure typing. Two modes on one control, bound bidirectionally: **command mode** (a permissive mini-DSL with inline autocomplete) and **field mode** (the same parameters as discrete controls, for discoverability). Typing in command mode updates the fields live, which is how the DSL teaches itself, and the autocomplete is not optional, because the discoverability argument is void without it (AC-050 / A2.4).

Grammar, everything but qty and connector is optional and order-insensitive:

```text
<qty> <connector|alias> [<family|alias>] [in|out|bi|bus|pass] [front|rear|both]
      ["<label pattern>"] [@<bank>] [poe:at] [z:75] [dte] [tap:10w]
```

Aliases resolve aggressively **against the registry** (CR-058): `ConnectorTypeDef.aliases` and `SignalFamilyDef.aliases` hold the bare trade names, while the canonical IDs stay namespaced `lower.dotted.snake`. So `hdmi` → `conn.hdmi_a` + `video.hdmi.2_0`; `rj45` → `conn.rj45` + `net.ethernet`; `hdbt` → `conn.rj45` + `video.hdbaset`, *a different family on the same connector, which is the entire point of keeping connector, family and direction orthogonal*. `spdif` → `conn.rca` + `audio.spdif_coax` + impedance 75.

*Rejected alternative (CR-058):* flat bare names as the canonical vocabulary. The DSL gets its ergonomics from the aliases; the file format gets its namespacing and forward compatibility from the IDs. `ac-inlet` as a *signal family* is re-authored throughout as **`power.ac_iec`** + `PortPowerSpec.role: inlet` (CR-058, CR-060). **Inlet and outlet are not directions**: they are `sink`/`source` on a `power.*` family plus a role.

| Typed | Result |
|---|---|
| `16 hdmi in` | 16 × `conn.hdmi_a` / `video.hdmi.2_0` / sink / rear, `HDMI IN 1…16`, bank auto-named "HDMI Inputs" |
| `16 euro2 out "ZONE {n@2} {L,R}"` | ZONE 1 L, ZONE 1 R, ZONE 2 L … ZONE 8 R: a whole 16-channel amp bank |
| `24 rj45 poe:at @Ports "{n:2}"` | 01…24, PSE, 802.3at |
| `24 rj45 pass both "{n:2}"` | 48 ports: 24 front + 24 rear, auto-paired as a passthrough panel |
| `1 c14 in` | AC inlet: `conn.iec_c14` / `power.ac_iec` / sink, `PortPowerSpec.role: inlet` |

### 4.2 Label pattern language

| Token | Expands to | Example |
|---|---|---|
| `{n}` | sequential int from `start`, step `step` | 1, 2, 3 |
| `{n:2}` | zero-padded | 01, 02, 03 |
| `{n@k}` | increments every *k* rows | k=2 → 1,1,2,2,3,3 |
| `{A}` | alpha sequence | A, B, C … AA |
| `{L,R}` / `{a,b,c}` | cycling literal set | L, R, L, R · Y, Pb, Pr |
| `{rev}` | descending | 16, 15, 14 |

Parse errors are *designed*, not thrown: the offending span is underlined in the input with a one-line explanation and a suggested repair chip (AC-050 / A2.4). If `@bank` is omitted the bank name is derived as `"{family alias, else shortTag} {direction plural}"` and collisions take a numeric suffix. Renaming a bank never touches port labels.

> **Corrected by DR-060 §11.59.10(a).** This sentence used to say *"{family display name}"*, which yields **"HDMI 2.0 (18 Gbps) Inputs"** against the **"HDMI Inputs"** that §4.1's own example table and §2's layout sketch both show. The prose was the illustration and the examples were the specification.

### 4.3 Archetype generators

Three buttons above Quick Add that emit whole topologies:

- **Matrix I/O…**: *N* inputs × *M* outputs, connector per side, with checkboxes for the usual companions: mirrored outputs, per-output audio de-embed, per-output IR, control (LAN + RS-232), AC inlet. Emits 4–7 banks in one action.
- **Switch ports…**: *N* access ports + *M* uplinks, PoE standard and per-port class, SFP form factor, management port, redundant PSU.
- **Paste from spreadsheet**: TSV/CSV with a column-mapping sheet, sharing the engine with the Structure CSV import.

### 4.4 Banks and port sets: two concepts, two names

CR-055 resolves a live name collision, and both concepts ship in v1.

| Concept | Type | What it groups | Drives |
|---|---|---|---|
| **Bank** | `BankDef{key, label, abbr, symbolSide, collapseInSymbol, order}`, joined by `PortDef.bankKey` | **Presentation** | symbol edges, brackets, symbol collapse, auto panel layout |
| **Port set** | `PortSetDef`, joined by `PortDef.setKey` + `setRole` | **Electrical** | Y/Pb/Pr, L/R, +/−, `atomicConnect`, and the conductor roles of CR-010 |

**`SetKind` ships three of its four values, and DR-086 §11.85.4 says which is held back.** `stereoPair`, `speakerPair` and `componentVideo` are offered; **`balancedPair` is not offered for new authoring and the enum value stays**. Its one use in the seeded catalog is A04's `bal`, *"Balanced input pair"*, whose two ports carry roles `L` and `R`: as authored it means a stereo pair that happens to be balanced, which `PortDef.balanced` already records on each port. The thing its NAME suggests, the two legs of one balanced line, is `balanced` plus `Polarity` on the terminal, and AC-030 exists so that a polarity inversion is inexpressible rather than expressible-and-wrong. A template that already carries the kind keeps it, decodes it, and sees it offered while that set is the one being edited.

**A set below two members is a notice, not an error** (DR-086 §11.85.6). `Group as set…` cannot mint one, but `Delete` on a member can leave one and a hand-edited `.rmdx` can arrive with one, and below two members the `atomicConnect` gesture is undefined. Removing the last member does **not** remove the set: an empty set is not a dangling reference, it is an empty one, and it is what a person is about to put two ports back into.


*Rejected alternative:* `PortGroupDef` / `PortGroup` as one name for both. It is banned ([canon §4.7](canonical-decisions.md#47-banned-names)); "group" meant an electrical grouping in the data model and a presentation grouping in the schematic spec, which is two concepts wearing one word.

### 4.5 The port table

A virtualised data grid, rows grouped by bank under sticky collapsible headers. Core columns are always visible; column *packs* are toggled from `⚙ Columns` and **auto-revealed** when the current bank's dominant family calls for them (opening any switch template shows the Network pack, remembered per category).

| Col | Editor | Notes |
|---|---|---|
| `⠿` | drag handle | Reorder **within a bank** (DR-064). The `Bank` column is how a port moves to another bank, and every refusal names it: the bands are pinned sticky headers over per-band lists, and dragging across would cost the header a person forty rows in is reading |
| `☐` | checkbox | Multi-select |
| `Key` | text | `PortDef.key`: stable, author-assigned, **the migration join** (CR-051). Auto-derived from the first label, editable, shown greyed until touched |
| `Label` | text | The silkscreen text |
| `Designator` | text | `J01`: unique **within the device** (CR-042). Auto-assigned sequentially per ASME Y14.44; auto until manually edited, then pinned (italic → roman) |
| `Connector` | combo | `ConnectorTypeId`, grouped picker with footprint preview |
| `Family` | combo | `SignalFamilyId`, filtered to families legal on that connector, plus "Other…" |
| `Dir` | segmented | **Five values**: `i o b n p` = source · sink · bidirectional · **busNode** · **passive** (CR-060) |
| `Face` | segmented | Front / Rear |
| `Set` | combo | `PortDef.setKey`. **Offers the sets that exist and mints none**, exactly as `Bank` does (DR-078 §11.77.2's shape): making one is `Ctrl+G` `Group as set…` in §4.6, and it is made FROM rows rather than beside them (DR-086 §11.85.2) |
| `Role` | combo | `PortDef.setRole`, a **closed** list opened by the row's set's `SetKind`: stereo `L`/`R`, speaker `+`/`-`, component `Y`/`Pb`/`Pr`, plus blank (DR-086 §11.85.3). No `Other` row. **Blank and disabled on a row in no set.** Free text was rejected because `planAtomicConnect` compares roles by string equality, so `+`, `plus` and `POS` would be three roles and a typed one warns against every seeded amplifier |
| `Notes` | text | |

*Rejected alternative (CR-060):* the catalog's four-letter `i/o/b/p` notation, where `p` collapsed `busNode` and `passive` into one letter. The distinction is load-bearing for `DIR-002`, `BUS-001`, `BUS-002` and the multi-drop stub glyph, so the notation gains a letter and every catalog entry using `p` is re-audited.

| Pack | Columns |
|---|---|
| Electrical | Impedance Ω · Level · Phantom · Polarity · Nominal V |
| Network | PoE role · PoE std · Type · Class · Watts · Link speed · VLANs · SFP form factor · Fibre mode · λ |
| Serial | DTE/DCE · Baud · Data · Parity · Stop · Flow |
| Bus | Segment · Address · Universe · Unit loads · Terminator · Tap W |
| Power | Role · Receptacle · Volts · Max A · Outlet mode · Seq step · Seq delay · Circuit |
| Passthrough | Paired port |
| Advanced | Max connections · Topology · **Gender** · Pinout variant · Return channel · `renamedFrom` |

`Gender` has **three** values, `male | female | genderless`, and the column is only enabled when `ConnectorTypeDef.genderApplies` is true (CR-059). *Rejected alternative:* the five-value enum with `jack` and `plug`, which contained two synonym pairs and silently broke `CON-002`: the rule "both ends male or both ends female" never fired for `jack` + `jack`.

**What M4-E actually built, and where this table was an illustration rather than a specification.** Censused field by field against `PortDef` (docs/12 §5.3.5), **nine columns above have no model field to write to** and are not built: `VLANs`, `Segment`, `Address`, `Universe`, `Receptacle`, `Outlet mode`, `Seq step`, `Seq delay`, `Circuit`. Each needs a model field first, which is a data-model decision rather than a grid task. In the other direction the model carries **eight fields this table names nowhere**; six of them now sit in the pack that already draws their neighbours (`balanced` and `maxCurrentMa` in Electrical, `bus.protocol` and `bus.addressable` in Bus, `power.drawWatts` in Power, `conductorCount` in Advanced), while `channelIndex` waits for port sets (M4-J2) and `carriedProtocols`/`acceptedFamilies` wait for a multi-select cell.

Two column shapes also changed under measurement. `Dir` is a dropdown spelling all five values out rather than a segmented control of letters, because a column too narrow to tell `Bus node` from `Passive` re-introduces in the editor exactly what CR-060 removed from the catalog. `Set` and its role are **two columns**, not a combo with a role attached, because the second control had nowhere to sit in one cell; DR-086 §11.85.7 keeps that split and makes the second one a closed picker over the first one's `SetKind`. And `Family` is not filtered by connector: no field in the model records which families are legal on which connector, so the picker offers every family grouped by domain and a filter box, which is the SERVICE column's control (DR-025 §11.24.5) rather than a second one.

**The three that were waiting now have a ruling, and it is a cell rather than a rule (DR-081, §11.80).** `channelIndex` becomes an integer cell on the port-set surface, where it says which conductor of a `PortSetDef` a port is and is meaningless without one. `carriedProtocols` and `acceptedFamilies` get a **multi-select cell over the seeded signal families**, and **the cell shape is the deliverable rather than the two columns**: the grid has single-value cells and nothing else, so a list-valued column is a shape it has never had, and building it once keyed and testable is what makes the next list-valued field a reuse rather than a copy. **Nothing reads `acceptedFamilies` at connect time in v1.** Whether a connect springs back is a validation rule; AC-051 forbids a rule shipping without a known-bad fixture and a known-good near-miss, and that pair is M5's to write. Both lists are non-nullable and default to empty, so an empty list reads as *this port states no constraint*, every seeded port and every file on disk keeps the behaviour it has, and DR-012's arithmetic is undisturbed.

### 4.6 Editing operations

| Op | Binding | Behaviour |
|---|---|---|
| Edit cell | click, or type over selection | Enter commits + moves down; Tab commits + moves right; Esc reverts |
| **Fill down** | `Ctrl+D` | Copies the top cell of the selection to every cell below it |
| **Fill series** | `Ctrl+Shift+D` | Counts down the selection from the top cell (DR-062). **There is no stored label pattern to re-apply**, so the sequence is inferred: the **last** run of digits becomes the counter, `HDMI 2.0 IN 1` → `HDMI 2.0 IN 2`. `LABEL`, `DESIG` and `NOTES` only |
| **Multi-row edit** | select N rows, edit any cell | Applies to every selected row; the right dock becomes the batch inspector. **Mixed values read `Mixed (N values)` and NOT `—`** (DR-063): the dash is G4's unknown and a disagreement is a different fact. Left untouched unless explicitly set. **`LABEL` and `DESIG` edit one row only**, because one label across eight rows mints eight colliding keys; `Ctrl+Shift+D` is the gesture for a column of labels |
| **Duplicate** | `Ctrl+J` | Clones the selection below, labels auto-incremented past the highest existing index. **"Past the highest existing index" is a claim about the TEMPLATE, not the selection**: cloning `HDMI IN 1`-`4` in a bank already running to 12 gives 13-16, counted per series (prefix and suffix, never the digit width, so `IN 1` and `IN 01` are one series). Clones land after the LAST selected row and the selection follows them, because duplicate-then-retype is the gesture. A clone drops `renamedFrom` and `designatorHint`: both are the source's identity rather than its data, and two ports pinning one designator is the duplicate the live validation flags. Refuses under a sort, which mints `order` |
| Delete | `Del` | Undoable on the builder's stack; warns if the port is in a passthrough pair |
| **Reorder** | drag, or `Alt+↑/↓` | `PortDef.order` is a `FracIndex` (CR-027), a reorder is one field write on one row, not a renumber of the bank. **The whole selection travels as a block**, keeping its own order and landing contiguous (DR-064), so N rows moved is N writes and no others. **The band edge is a wall in both gestures**: `Alt+↑` on a band's top row refuses and names the `Bank` column, because crossing would have to rewrite `bankKey` and an arrow key must not retype a port |
| **Renumber…** | `Ctrl+R` | Re-applies a label pattern to the selection in current display order, through §4.2's own engine and **never a second parser**. A dialog with the pattern, a `Start` and a `Step`, showing the designed parse errors and their repair chips where the person is typing, over a per-row preview. `Start` is not optional decoration: `{n}` counts from 1, so renumbering rows 9-16 to `IN 9`-`IN 16` is otherwise unexpressible. **Does NOT refuse under a sort** (unlike `Duplicate`), because display order is what §4.6 asks for; the dialog says which order it is about. Labels only, never keys |
| **Find & replace** | `Ctrl+H` | Scoped to labels, keys, designators or notes; regex opt-in, so the default is literal and `HDMI (1)` is characters. **The KEY scope is the dangerous one and gets a per-row impact list** (DR-078 §11.77.3): `PortDef.key` is the migration join (CR-051), a key published when the builder opened may have another project's cables resolving through it, and undo cannot reach those. A published row says so and its rename records the alias; a rename that would collide, or empty a key, is marked and skipped rather than thrown. An emptied designator or note writes `null`, which is G4's unknown and not a blank |
| **Change type…** | `Ctrl+T` | Bulk connector and family change with an impact preview, and **the preview is the deliverable**. `direction` and `topology` are never written: both are non-nullable with defaults, so the model cannot tell a value somebody chose from one that came from a default, and cascading the new family's would overwrite deliberate values uncountably (DR-060). The preview NAMES each row that keeps a direction or topology the new family would not have chosen. Picking a family pre-fills the connector picker from its `defaultConnector`, visibly and reversibly, so retyping an HDMI bank to Ethernet does not leave Ethernet on an HDMI Type A. Runs no rules and does not pretend to. **`Ctrl+T` shadows macOS's `TransposeCharactersIntent`, deliberately** (DR-078 §11.77.1, docs/13 §3.6) |
| **Group as set…** | `Ctrl+G` | Makes a `PortSetDef` out of **two or more** selected rows and writes `setKey` and `setRole` on every one, in one transaction. **A set is made FROM rows, never beside them** (DR-086 §11.85.2): the alternatives, a `SETS` tree in the rail and a `New set…` entry in the `Set` column, both separate declaring a set from filling it, and the seeded catalog is the evidence for what that costs (`port_set_integrity_test`: 90 references, **72 dangling**, 7 sets referenced by nothing, 7 `atomicConnect` sets under two members). Below two members the `atomicConnect` gesture is undefined, so the gesture cannot mint one. **Roles are assigned in DECLARED order** from the kind's closed list and **run out into blank rather than cycling**, and the impact list names every row it left blank and every row leaving another set. The dialog is also where `atomicConnect` is set, which had an editor nowhere (DR-086 §11.85.5). **Refuses under a sort**: it writes no `order` but it READS one, and under a badge the person is looking at a different order from the one the roles will follow |
| **Ungroup** | `Ctrl+Shift+G` | Takes the selection out of whatever port sets it is in, and **removes every set left with no members**. It is the ONLY thing in the product that removes a `PortSetDef`, and `Delete` on the last member deliberately is not (DR-086 §11.85.6 and §11.85.8): deleting a port is somebody editing hardware and a set waiting for its second member back is the right outcome, while ungrouping is somebody saying these ports are not a set. No dialog and no preview, on `Remove (ports stay)`'s argument: it removes a grouping, touches no value anybody typed, and one `Ctrl+Z` puts it back. **The only reused trigger in this scope**, because the two acts are inverses a person expects to be spelled that way |
| **Move to bank…** | `Ctrl+M` | Moves the selection to the END of another bank's band, contiguously, keeping its own relative order. **A move writes `bankKey` AND `order`**: §4.5 bands by first appearance over the declared order, so writing the key alone splits the destination into two bands with other rows between them. At the head was rejected because it would renumber every automatic designator in the band. **Offers the banks that exist and mints none** (DR-078 §11.77.2): creating one is `BankDef` CRUD and is the bank tree's (§2), and a template with nowhere to go refuses with a sentence naming the tree's `+`. `Not in a bank` is a destination in both directions. Refuses under a sort |
| Copy / paste | `Ctrl+C` / `Ctrl+V` | TSV round-trips to Excel and back. **A header row leads the clipboard** so what lands in Excel is a sheet, and a paste drops a first line whose every cell is a column header. The connector writes its trade alias (`RJ45`) and the family its display name, both of which the existing resolvers read back, so it is readable and lossless at once. **An unknown is an EMPTY cell, never `—`.** **A paste does not create ports**: it refuses and says by how many, as the drop table's does |
| Sort | click header | **View-only by default**, shown with a badge. `Commit sort order` is a separate explicit action with a confirm (AC-058/D5), because sorting is destructive to symbol pin order. Three states per header: ascending, descending, then back to the declared order. **Within each bank's band**, and **an unknown sorts last in both directions** (DR-065): a blank is not the smallest value, it is the absence of one. A column sorts by what its cell shows, so `CONNECTOR` sorts by `HDMI Type A` and not by `conn.hdmi_a`; numbers are the exception, because their spelling is not their order. **Reorder is disabled while a sort is showing**, in both gestures |
| **Mirror bank** | bank context menu, `⋯` on a tree row **and** on the grid's band header | Duplicates a bank with direction flipped and the label prefix swapped IN↔OUT, the output side of a matrix in one click. **This row is an illustration and DR-085 (§11.84) is the specification**: `source` and `sink` flip while `bidirectional`, `busNode` and `passive` copy through unchanged and the preview names every row it left alone (CR-060 gives five directions and only two are opposites); the IN↔OUT swap applies where those words occur and otherwise the person names the bank, because `uniqueBankName` derives a label from the signal family so a real bank is `HDMI` or `HDBaseT` and has nothing to swap, and these labels are silkscreen text that reaches the panel drawing and the schedule; and the duplicated ports take NEW keys derived from the new bank key through Quick Add's own generator, so nothing writes a `renamedFrom` and CR-051's join is untouched. It does not pair the two banks: a matrix's mirrored output is a second output, not a passthrough. **The menu is mounted twice and built once**: §4.6 never said whose menu it is, so `bankMenuItems` hangs off the tree row, where CRUD belongs because a bank with no ports still has to be reachable, and off the band header, where the cursor already is when a person decides a bank is misnamed. Only a bank with a `BankDef` behind it gets one. Beside it in the same menu: **Rename…**, which writes `label` and `abbr` and never the key `PortDef.bankKey` points at, and **Remove**, which takes the heading and **not the ports** (CR-055: a bank is presentation) and lands them in `Not in a bank`, undoable and therefore unconfirmed |

**Setting a field from the dock** (M4-F11). The right dock's batch inspector reads AND writes: it draws the same controls the grid draws, over the same columns, and a field the selection disagrees on shows `Mixed (N values)` and **holds no value until it is touched**. That is §4.6's "left untouched unless explicitly set" made structural rather than remembered: a menu in that state holds `null` and fires only from a pick, and a text box seeds empty and compares its commit against that seed. Two consequences are deliberate and stated rather than discovered: from a MIXED control there is no way to express "set them all to unknown", which is available per row in the grid; and `LABEL` and `DESIG` have no control on the dock at all, because DR-063 keeps them to one row.

**What "the selection" is (DR-061).** The table above describes it two ways, a column of cells with a top and a set of rows, and it is the second: **a contiguous run of rows plus whatever `Ctrl`+click has added or removed, and a column taken from whichever cell holds focus.** Click selects, `Shift`+click extends, `Ctrl`+click toggles, and the gutter checkbox toggles the same row in the same set, so the tick box M4-E ships **is** the selection rather than a second thing beside it. Not a 2D cell rectangle: of the fourteen rows above, nine want whole rows, three name their own columns, one wants a single column, and one is a single cell, so a rectangle would be read by `Fill down` alone.

Reorder is semantic: it drives symbol pin order and panel auto-layout. Because `order` is a `FracIndex`, dragging one row rewrites one row. It also **renumbers the automatic designators** of that port and everything below it, and that is the point rather than a side effect: `PORT_SEQ` is the rank in the declared order, `J{PORT_SEQ:2}` renders from it, and a silkscreen follows the physical order of the jacks. A `designatorHint` the author pinned survives untouched.

**Passthrough pairing.** With `isPassthrough` on, the grid gains the `Paired port` column and a **Pair front↔rear by order** action, and both write `TemplateBody.passthroughPairs: [{frontKey, rearKey, sameNet}]`, which now exists in `.rmdx` (CR-057). A passthrough template whose pairs are missing is a **load warning, not an error**. Paired ports share a net, so a trace resolves `Living Room jack → PP-1 F12 → PP-1 R12 → SW-1 P04` as one logical path.

**Live validation** puts a severity dot in the row gutter, duplicate designator in-template, passthrough port with no pair, an RCA carrying `audio.spdif_coax` without impedance 75, an IR 3.5 mm port with no `pinoutVariant`. None of it blocks saving. `pinoutVariant` is safety-adjacent and must therefore carry a cited source before the template ships in the catalog (AC-052).

**Footer readout**, one line, always visible:

```text
68 ports · 5 banks · 32 HDMI · 17 RJ45 (PoE+ ×16, 130 W) · 1 C14 · Rear 67 / Front 1 · Panel fill R: 71%
```

---

## 5. Panel layout: the canonical ruling

The question "is the visual panel-layout feature in v1?" was answered three different ways across the corpus, and CR-071 splits it into three separate answers.

> **Ruling (CR-071, part 1 — authoring):** ports are authored **in the grid**. Panel geometry is **auto-laid-out from connector footprints**. Manual nudging ships in v1 as an **optional hidden toggle, pre-populated from the auto-layout**. The proposition *"you build a device by drawing its rear panel"* is **rejected as the authoring model.**

*Rejected alternative:* the rear-panel canvas as the device builder's primary output surface. It is precisely the "click 16 times" failure the brief exists to eliminate, multiplied, a 48-port patch panel would need 48 placements. Ports connect by **identity**, not position; the netlist, the schedule and the PDF are all complete without a single coordinate.

Auto-layout ships anyway, because the geometry is free. Every `ConnectorTypeDef` carries a real footprint, and **a CI test asserts that every connector referenced by a shipped template has a footprint entry** (AC-050 / A2.2), the earlier table had 13 entries for a catalog using ~35 connectors, so the "zero-authoring correct rear panel" claim was false as written and is now enforced rather than asserted.

**Pitch is a refinement and not a prerequisite (DR-057, §11.56).** 20 of the 49 shipped connectors carry a `pitch`: 14 transcribed from docs/catalog/seed-devices.md §5.2 and 6 inherited from a connector sharing the same physical shell. The other 29 have none and will not acquire an invented one, because a pitch is not derivable, `conn.binding_post` states 20 mm against a 24 mm pair footprint since ¾ in is the centre spacing binding posts are built on. **Step 2 below therefore falls back to the footprint**, which is what CR-071 rules the layout flows from in the first place, so auto-layout runs on every template rather than on the 14 of 45 an earlier reading of this pseudocode priced it at.

```text
Algorithm — panel_layer.dart
  1. banks in BankDef.order; within a bank, ports in PortDef.order
  2. flow left → right, advancing by
        ConnectorTypeDef.pitch ?? (footprintWidth + gutter)   ← DR-057 §11.56.4
     skipping connectors §5.1 gives no cutout (hardwired,
     ground lug, unterminated): they occupy no panel width
  3. wrap to a new row when chassisWidth is exhausted      ← 432 mm, NOT 482.6 (AC-032)
  4. distribute rows vertically within (heightU × 44.45 mm − 0.79 mm)
  5. pin power inlets far right; network/control far left; signal banks centred
  6. centre the whole field on the 482.6 mm panel
```

The two other parts of CR-071, for completeness and to keep the boundary clear: the rear panel **prints** in v1 as sheet `T2.02 Rack Elevation — Rear`, drawn by the same scene builder; the standalone interactive **Rear Panel view** (`Ctrl+3`, leaders, tag pills, egress heat map) is **v1.1**. See [Schematic editor](05-schematic-editor.md) and [PDF export](08-pdf-export.md).

The override is a `☐ Customize panel layout` toggle revealing a canvas seeded from the auto-layout, so the interaction is *nudging*, not *placing*: 1 mm snap, arrow-key nudge, align/distribute, `Reset to auto`. **Non-negotiable:** a template with no layout data is not incomplete. The section shows a green `AUTO` badge and is skippable forever.

---

## 6. Live preview

Three stacked, individually collapsible previews in the right dock, all updating on every keystroke.

1. **Rack elevation strip**: 19 in at true aspect, height `heightU × 44 450 000 nm` exactly (CR-001, CR-002), front/rear toggle, face colour + glyph + name + a `{TYPE_PREFIX}-1` placeholder designator. This is literally what prints.
2. **Schematic symbol**: auto-generated in the KiCad/Q-SYS idiom: a rectangle with the designator top-left, name centred, model in small type below, pin stubs grouped by bank. Default sides are inputs left, outputs right, control top, power bottom, each overridable via `BankDef.symbolSide`. Pin **shape** encodes connector class; pin **colour** encodes **domain**, taken from `SignalDomainDef`, colour lives on the domain, not the family (CR-078). Banks over 8 ports render **collapsed to a vector pin with a count badge** by default, which is what keeps a 48-port switch legible.
3. **Rear panel render**: the auto-layout output drawn to scale with a panel-fill percentage.

Both the symbol and the panel are produced by real scene builders (`symbol_layer.dart`, `panel_layer.dart`), not preview-only widgets, a symbol that cannot print is not a symbol (CR-086).

---

## 7. Template lifecycle

### 7.1 Library, categorise, tag, search, favourite

Storage is the app catalog directory (seeded, read-only) plus the user library directory (writable), plus per-project embedded snapshots. The `signature` field and the cryptographic provenance chain are **cut from v1** (AC-042); `contentHash` survives because it is three lines and it is what makes the embedded-snapshot argument true. **Library packs are no longer cut with them**: DR-015 §11.15.3 separates the two halves AC-042 argued as one, renames the pack `.rmda`, and makes it a single JSON file rather than a zip. It is ruled, not built, and it is what makes "multiple device libraries loaded into the palette and filtered as needed" expressible at all.

- **Browser:** grid or list, the rack elevation strip as the card thumbnail. Sidebar: category tree, then filter chips, RU height, mount method, "has HDMI", "has PoE", "is passthrough", "container", "used in this project", "drafts".
- **Search:** fuzzy over name, manufacturer, model, tags, description **and port signal families**. Typing `hdbaset` surfaces every template with an HDBaseT port even when the word is absent from its name; typing `16x16` matches the model string.
- **Favourites:** star toggle; favourites pin to the top of the browser and to the palette.
- **Smart folders:** `Recently used` and `Used in this project` are always first and satisfy most lookups.

The palette in the browser is the **same widget** used to insert devices everywhere, one palette, one insert command, placement decided by the drop target (CR-104). Dropping on a rack yields a `RailPlacement`; dropping on the schematic, or inserting with no rack focused, yields a `StagedPlacement` plus a `SheetItem`.

**The plain in-project case is built and is not the browser** (DR-077 §11.76, M4-S). The palette lists what the **document** can place: the newest version of every template in `RackDocument.templates`, which is the seeded archetypes a project is created with plus everything saved here since. A template authored in the builder is filed into its own category with a badge and repeated in a `This project` group pinned above the nine categories; a search shows it once, badged. A template saved with no category lands in a trailing `Uncategorised` group, because §3's metadata form does not require one. None of that is the browser, the smart folders or the favourites above, which need the library directory service (M4-N) and are M4-O's.

The v1 template count is stated in exactly one place, the summary table in [Seed devices](catalog/seed-devices.md#310-catalog-summary-and-what-is-deliberately-not-in-it), and in no prose anywhere (CR-061).

### 7.2 Versioning

Templates are immutable versioned records. Editing a published template does not mutate it; it forks `version + 1` in the library. `templateId` is stable, every version stays resolvable, and the snapshot key is `"$templateId@$version"` (CR-050). **A second `Save` in one builder session is such an edit** and forks accordingly (DR-077 §11.76.3): it does not mint a second template, the id is not re-derived when the display name changes, and the devices already placed keep resolving the version they were placed from. **The palette offers the newest version of an id**, because placing means placing the template as it stands. The change class is computed from the diff and shown prominently before save:

| Class | Examples |
|---|---|
| **Safe** | rename, description, tags, colour, glyph, weight, depth, wattage, panel coordinates, port **label** changes, port **reordering** |
| **Additive** | new port, new bank, new column data on existing ports, a new clearance requirement |
| **Breaking** | port **deleted**; direction reversed; connector or family retyped incompatibly; `isPassthrough` toggled; `frontU` changed; passthrough pairing altered |

### 7.3 Duplicate, fork, import, export

- **Duplicate**: new `templateId`, `version 1`, name + " copy", `derivedFrom` recorded. Offered directly from every catalog card as `Duplicate & edit`; this is the intended path for building on the archetypes.
- **Seeded templates are read-only.** Editing one silently performs Duplicate → edit the copy with a one-line notice. The consequence that no document previously surfaced is now handled: a fork records `derivedFrom{templateId, version}`, and when the catalog later revises the source the fork shows a **passive badge**, *"Based on catalog 'HDMI Matrix 8×8' v1, the catalog version has since been corrected (v3). Compare…"*. No action is forced (CR-062).
- **Export / import**: single **`.rmdx`**, plain UTF-8 JSON, LF, 2-space indent, keys sorted. Templates are inert data with no executable content, and the import dialog says so. `.rmdx` obeys the same unit regime as `.rmpj`: `depthNm`, `weightUg`, `xNm`, **no floating-point millimetres** (CR-063), because the template file is part of the persisted model and there is no second unit regime. Every import path enforces JSON depth and size limits (AC-058 / D8).
- **Hash mismatch is a warning plus a badge on the affected devices, never a load failure** (AC-042). *Rejected alternative:* I-8's hard load error, refusing to open a project because a snapshot was hand-edited is a data-loss event dressed as a safety feature.

```json
{
  "schemaVersion": 1,
  "kind": "device-template",
  "templateId": "0f3a…",
  "version": 3,
  "contentHash": "sha256:…",
  "derivedFrom": { "templateId": "…", "version": 1 },
  "identity": { "displayName": "HDMI Matrix 16x16", "manufacturer": "Generic",
                "typePrefix": "MTX", "tags": ["hdbaset", "4k60"] },
  "physical": { "frontU": 4, "rearU": 4, "side": "both", "mountMethod": "rackEars",
                "widthClass": "full", "depthNm": 330000000, "weightUg": 7300000000,
                "chassisWidth": 432000000, "isPassthrough": false },
  "power":    { "nameplateWatts": 90 },
  "banks": [ { "key": "hdmi-in", "label": "HDMI Inputs", "abbr": "IN",
               "symbolSide": "left", "collapseInSymbol": true, "order": "a0" } ],
  "ports": [ { "key": "hdmi-in-01", "renamedFrom": [], "bankKey": "hdmi-in", "order": "a0",
               "label": "HDMI IN 01", "designatorHint": "J01",
               "connector": "conn.hdmi_a", "signalFamily": "video.hdmi.2_0",
               "direction": "sink", "face": "rear", "gender": "female",
               "topology": "p2p", "maxConnections": 1 } ],
  "passthroughPairs": []
}
```

Note what is **not** in the file: no `portId` UUID, no semver object, no `frontImage`, no `signature`, no `xMm`. The `identity.` / `physical.` / `power.` sections are a **file layout only**; the codec flattens them onto `TemplateBody` (CR-053).

Note also what is **absent rather than null**: `typicalWatts` and `apparentVA` are unknown on this template and are therefore omitted entirely. The codec never writes an explicit `null` for an unknown value, and an absent key reads back as unknown (CR-114, G4).

`submittedBy` is absent above for the same reason and by the same rule: this template has never been submitted to the community catalog. On one that has, it reads `"submittedBy": {"handle": "riley", "userId": 12345}` and nothing else changes. See §7.4.

### 7.4 Submitting a device to the community catalog

**v1.1, DR-033, and conditional**: canon §11.32.7 holds the surface behind a release posture that is not yet ruled. **The `submittedBy` field itself is v1** and ships ahead of the surface, because `TemplateBody` has no `unknown` passthrough and a v1 build that re-saved a v1.1 file would drop the credit silently.

**Where it goes.** A second repository holds the community library as one `.rmdx` per device. **Not** `packages/rackmate_core/lib/src/catalog/`, which is Dart and stays Dart: DR-002 binds the seeded catalog to generic archetypes and AC-052 requires cited provenance for it, so a real manufacturer and model cannot land there. Canon §10.9 permits real SKUs on user-authored templates and refuses them in the seed, and this is that boundary made into two repositories.

**The gesture.** A `Submit to community catalog` action in the editor's toolbar opens a **review sheet** before anything leaves the machine. The sheet shows three things: the exact JSON to be proposed, the citation, and the sign-in state. Submission is deliberate and reviewable, which matters because the failure this prevents is a template carrying a client's name in `description` becoming public. *Rejected alternative:* a prompt in the save-or-close flow. It submits more devices and it asks everyone every time, which trains the dismissal reflex and makes the accidental publication above routine rather than rare.

**Signing in.** GitHub, by **OAuth authorization code with PKCE**, loopback redirect on `127.0.0.1` at an ephemeral port. **No credential is embedded in the binary**, because a native application cannot hold one: it ships in the application's code by definition, and GitHub's secret scanning revokes GitHub tokens found in public repositories. PKCE is preferred over the device flow on GitHub's own guidance, the device flow having no redirect URI and being usable to impersonate an application in a phishing attack. The app calls GitHub directly; there is no broker service. Canon §11.32.2.

**The citation is a photograph of the ports**, satisfied by either an image or a URL to a manufacturer image, and it **blocks submit**. A photograph of the actual rear panel is a primary source where a product page is a secondary one that outlives the product by about a year. **Evidence never enters the `.rmdx`** (AC-057): an image is committed to the contributor's own fork under an evidence path, using the supported contents API, and renders in the pull request diff. GitHub has no documented API for attaching an image to a pull request body, so the undocumented upload endpoint is not used.

**`submittedBy` is a credit, not a signature.** The application **never reads it**. It authenticates nothing, anybody may type anything into it, and the only place the claim is tested is the pull request, where GitHub has already established who is speaking. AC-042 stays as it was: no signatures, no `provenance` or `derivedFrom` chains beyond the fork join §7.3 already describes. Handle and numeric user id are **two fields because they are two facts**: a GitHub login is renameable and a freed login is claimable by somebody else, so a handle alone can come to credit the wrong person with nothing in the file having changed.

### 7.5 Installing and updating the community library

**v1.1, DR-034**, under the same precondition. The library arrives as **one `.rmda` per release tag**, attached as a release asset and fetched over HTTPS. Nothing is cloned: Flutter desktop has no git, and `.rmda` is already the ruled archive format (DR-015 §11.15.3) whose codec, library directory service and palette filter M4 owes regardless.

**The installer bundles a snapshot**, so a first launch with no connectivity still has a library. The first-run experience then shows a **dismissible card** offering the newer release, with the device count and download size; declining costs nothing and being offline costs nothing. The application ships less often than the catalog does, so the bundled tag is nearly always behind and the card and the update notice are the same mechanism.

**The update check is `releases/latest`, unauthenticated, at most once per 24 hours on launch**, and the notice is **non-modal**. Nobody opening a rack drawing wants a dialog about a parts library. Updating is always a user action and the installed tag is recorded.

**Two boundaries.** The community library is a **separate library**, filterable in the palette (DR-015 §11.15.5), and is **never merged into the seed**: the four starters and every golden resolve out of the seed only, because a golden that resolves a template out of a fetched library depends on a release tag and has stopped being a golden. A test asserts it. And **a download is an import**: AC-058/D8's JSON depth and size limits apply, `contentHash` is verified before install, and a failed fetch leaves the previous library in place. The network is not a more trusted input than the disk.

**This is not an application updater** (RJ-014). No code is fetched and nothing is executed; templates are inert data, as §7.3 already says. The binary still changes only by installer.

---

## 8. Editing a template that is already placed

### 8.1 v1 is copy-on-place

Every `DeviceInstance` holds a `TemplateRef{templateId, version, contentHash}` that **always** resolves to an embedded `TemplateSnapshot` in `RackDocument.templates`, keyed `"$templateId@$version"`. A `.rmpj` file is therefore self-contained: the recipient does not need your library.

> **Ruling (AC-041): v1 is copy-on-place.** Editing a library template does not touch placed instances. v1 shows a passive "based on an older catalog template" badge and offers **Fork to a new template**. The full **Update Manager** — opt-in migration, safe/additive/breaking grouping, per-cable remapping — is **v1.2**.

*Rejected alternative:* shipping the Update Manager in v1. The semver classifier, the two-column diff, the per-cable remap ranking and the conflicts-with-local-edits merge together constitute a package manager, and v1 does not need one. Nothing about the format changes when it lands, which is what makes deferring it free (G5).

### 8.2 The three doors

Right-clicking a placed device offers exactly three edit paths (CR-054), each with a scope badge shown while editing.

| Door | Effect | Badge |
|---|---|---|
| **Edit this device only** | Writes typed `DeviceOverrides`; template untouched | Amber: *"Editing MTX-1 only. 3 other devices use this template and will not change."* |
| **Edit the template** | Forks `version + 1` in the library; placed instances untouched until opted in | Blue: *"Editing template 'HDMI Matrix 16×16'. Used by 4 devices."* |
| **Fork to a new template** | New `templateId`, seeded from snapshot + overrides, this instance rebinds, overrides cleared, `derivedFrom` recorded | Green: *"MTX-1 will use a new independent template."* |

*Rejected alternative:* a fourth verb, **Detach instance** (`templateRef → null`). It is **deleted**: it produces a device with no lineage, and door 3 covers the case with better provenance. `DeviceInstance.localTemplate` and `PlacedDevice.snapshot` are deleted with it: snapshots live in exactly one store.

Overrides are **typed nullable classes**, not dotted-path maps (CR-053, AC-012), and `PortOverrides` lives on the `Port`, never in a device-keyed map, a device-keyed map of port overrides re-introduces the composite-key identity the model bans.

### 8.3 Propagation and the migration join

When migration does run (v1.2, or v1's fork-and-reseed), the join key is **`PortDef.key` plus `renamedFrom`** (CR-051):

```text
for each PortDef in the new version:
    match old PortDef where key == new.key
       or old.key ∈ new.renamedFrom          ← what a UUID cannot express
old ports with no match and NO conductors  → drop silently
old ports with no match and conductors     → Port.orphaned = true    ← never delete
```

*Rejected alternative (CR-051):* `portId` UUIDs as the join. A UUID cannot express *"this port was renamed from that one"*, which is the exact case the mechanism exists for, and it destroys the plain-JSON diffability that is a stated product differentiator.

> **Ruling (CR-052): orphan, never delete.** The per-cable choices are `[ Remap ▾ ]` and `[ Keep as orphan ]`. **`[ Del ]` is removed and never ships.** A user who wants a cable gone deletes it through the normal delete path, with its normal confirm and its normal undo entry. Presenting destructive and non-destructive options as equal-weight one-click siblings during routine maintenance is how tools lose data.

Three identities stay distinct and are never conflated: `Port.id` (UUID, graph identity, what a `Conductor` references) · `PortDef.key` (template identity, the migration join) · `Port.designator` / `userLabel` (human identity, what prints). See [Data model](02-data-model.md).

---

## 9. Worked example: a 16×16 HDBaseT matrix

The M4 exit criterion is that a user who has seen the tool once authors this template **from scratch in under three minutes**. The target device: 4U, 16 HDMI inputs, 16 HDBaseT outputs on RJ45, 16 mirrored HDMI outputs, 16 IR emitter outputs, LAN, RS-232, IR in, C14 inlet, **68 ports across 6 banks**.

### 9.1 The DSL path: 13 steps

| # | Action | Keys / clicks | Ports |
|---|---|---|---|
| 1 | `File ▸ New template` | `Ctrl+Shift+N` | 0 |
| 2 | Type the name | `HDMI Matrix 16x16` | 0 |
| 3 | Tab to RU height, type | `Tab` `4` | 0 |
| 4 | Tab to prefix: pre-filled `MTX`, accept | `Tab` | 0 |
| 5 | Jump to Ports (all required fields now satisfied) | `Ctrl+Enter` | 0 |
| 6 | `16 hdmi in "HDMI IN {n:2}"` | `Enter` | 16 |
| 7 | `16 hdbt out "HDBT OUT {n:2}"` | `Enter` | 32 |
| 8 | `16 hdmi out "MIRROR {n:2}" @Mirror Outputs` | `Enter` | 48 |
| 9 | `16 ir35 out "IR OUT {n:2}"` | `Enter` | 64 |
| 10 | `1 rj45 in "LAN" @Control` | `Enter` | 65 |
| 11 | `1 de9 bi "RS-232" @Control` | `Enter` | 66 |
| 12 | `1 ir35 in "IR IN" @Control` | `Enter` | 67 |
| 13 | `1 c14 in` then save | `Enter` `Ctrl+S` | 68 |

**13 steps, ~120 keystrokes, zero mouse clicks, no dialog.** Banks 1–5 are auto-named from family + direction; bank 6 is named by `@Control` on first use. Designators `J01…J68` are auto-assigned per ASME Y14.44. Panel layout is `AUTO`. Power, weight and depth are left blank and render `—` downstream with an accurate unknown count in every rollup.

### 9.2 The archetype path: 7 steps

| # | Action | Emits |
|---|---|---|
| 1 | `Ctrl+Shift+N`, type `HDMI Matrix 16x16`, `Tab` `4` `Tab`, `Ctrl+Enter` | — |
| 2 | Click **Matrix I/O…** | dialog |
| 3 | Inputs `16`, connector `hdmi` | — |
| 4 | Outputs `16`, connector `hdbt` | — |
| 5 | Tick ☑ Mirrored outputs · ☑ Per-output IR · ☑ Control (LAN + RS-232) · ☑ AC inlet | — |
| 6 | `[ Generate ]` | **68 ports, 6 banks** |
| 7 | `Ctrl+S` | saved |

**7 steps.** Step 6 does the work of steps 6–13 above.

### 9.3 What the speed goal is measured against

| Design | Interactions to reach 68 ports |
|---|---|
| One dialog per port, 8 fields each | ~544 field edits + 68 dialog dismissals |
| Grid only, no Quick Add, no generators | 68 rows × ~5 cells with fill-down ≈ 90 edits |
| **RackMate, DSL path** | **13** |
| **RackMate, archetype path** | **7** |

Two invariants make the numbers real rather than a demo. First, **focus never leaves Quick Add** during steps 6–13, no reach for the mouse, no modal dismissal. Second, **nothing in the metadata form was touched after step 4**, because AC-049 removed it from the critical path; the same template, with the same 68 ports, is a complete and placeable template whether or not anyone ever fills in its weight.

---

## 10. Related decisions and cross-references

| Topic | Where |
|---|---|
| `TemplateBody`, `PortDef`, `Port`, `DeviceOverrides` in full | [Data model](02-data-model.md) |
| Connector, family, media and domain registries; aliases; the media-type editor | [Domain](01-domain.md) |
| Symbol rendering, bank collapse, vector pins | [Schematic editor](05-schematic-editor.md) |
| Inserting and placing a template; the palette; the Staging Bin | [Rack editor](04-rack-editor.md) |
| The Structure device's separate editor | [Structure device](07-structure-device.md) |
| Rear-panel printing, `T2.02`, equipment list | [PDF export](08-pdf-export.md) |
| M4 sizing and exit criterion | [Roadmap](09-roadmap.md) |
| Every ruling cited above | [Canonical decisions](canonical-decisions.md), normative; [10-decisions](10-decisions.md) is the short-form ADR summary of it |
| Footprint CI assertion, DSL parse-error fixtures, catalog provenance | [Testing and quality](11-testing-and-quality.md) |

Two extensibility paths ship with the builder and one does not. The **media-type editor** and **connector aliases** ship, because users hit them, the Structure CSV import already creates media types, and that is correct (AC-050 / A2.1). A **general registry authoring UI** does not ship (RJ-012): it is a database admin tool wearing a product's clothes. The claim that users can author **validation rules** is withdrawn from every document (AC-011); rules are Dart functions in a registry keyed by `ruleId`.
