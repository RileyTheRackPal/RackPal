# Domain Reference

This document is the source of truth for the physical, electrical and documentary facts about A/V racks that RackPal encodes. It exists so that a developer with no custom-integration (CI) background can implement the model, the validation rules and the export sheets correctly without guessing, every constant here is either fixed by a published standard, fixed by a canonical ruling (`CR-nnn` / `AC-nnn` / `RJ-nnn`) in the decision record, or explicitly marked `VERIFY:` as a figure that has not been confirmed against a primary source. Where this document and any raw working paper in [docs/research/](research/) disagree, the canonical decision record wins and this document restates it; where this document and the code disagree, this document is the bug report.

**Related:** [Data model](02-data-model.md) turns these facts into types. [Seed catalog](catalog/seed-devices.md) instantiates them. [Testing and quality](11-testing-and-quality.md) lists which of them are asserted by a unit test.

---

## 1. Reading rules

| Convention | Meaning |
|---|---|
| **[std]** | Fixed by a published standard. Not negotiable, not a preference, not a default. |
| **[trade]** | Trade consensus with no standard behind it. Ships as an advisory or a default, never as an error (G3, G4). |
| **VERIFY:** | Figure taken from a secondary source and not yet confirmed against a datasheet or the standard text. Must be resolved before the value ships in `assets/catalog/`. |
| `CR-nnn` etc. | The ruling in the canonical decision record that governs the statement. Cite it in code comments and commit messages. |

This document is the project glossary: the canonical home for every trade term. Canonical Dart/JSON/UI names are ruled in canon §4.

Two standing prohibitions apply to everything below. **Never fabricate a number**: an unknown physical fact is `null`, renders as `—`, and every rollup reports how many unknowns it contains (G4, CR-114). **Never let a domain heuristic block a deliverable**: trade guidance produces findings, and findings never gate bytes (G3, CR-022).

---

## 2. Rack physical geometry

### 2.1 The standards

EIA-310-D (US, inches), IEC 60297-3-100 (metric) and DIN 41494 are the harmonised expression of one standard. RackPal targets EIA-310-D semantics and stores metric integers.

| Quantity | Inches | Millimetres | Nanometres (stored) | Note |
|---|---|---|---|---|
| **1 rack unit (U)** | 1.750 | **44.45** | `44_450_000` | Exact, definitional **[std]** |
| Panel / faceplate width | 19.000 | **482.6** | `482_600_000` | The "19-inch" name is the *panel* width, not the rack width **[std]** |
| Chassis width (connector field) | ~17.0 | **432** | `432_000_000` | Default `TemplateBody.chassisWidth`; AC-032 |
| Rail-to-rail hole centres | 18.312 | **465.1** | `465_100_000` | Nominal; sources quote 18.28–18.34 in as tolerance |
| Clear opening between rail faces | 17.75 | 450.85 | — | Often quoted as a 450 mm minimum |
| Mounting post width (each) | 0.625 | 15.88 | — | — |
| Inter-panel clearance | **1/32** | **0.79375** | `793_750` | See §2.2; this is why `Len` is nanometres |

### 2.2 1U is 44.45 mm exactly, and panel height is not `n × 1.75`

**Ruling: `kRackUnit = Len(44_450_000)` (CR-001, CR-002; spelling per canon §5.2).** A raw design document asserted "1U = 44.45 mm = 444 tenths-mm, exact, no rounding anywhere in the vertical axis". That statement is arithmetically false: 44.45 mm is 444.5 tenths. The error loses 0.05 mm per U and **2.25 mm across a 45U rack**, which is visible on a dimensioned print. CR-002 deleted the claim; CR-001 replaced the unit. *Rejected alternative: hundredths-of-a-millimetre, which is exact for 1U but not for the 1/32-in clearance (79.375 hundredths).*

A rack-mount panel is **1/32 in (0.79375 mm) shorter than its nominal U height** so that adjacent units clear each other **[std]**:

```text
panelHeight(n) = n × 44.45 mm − 0.79375 mm
              = Len(n × 44_450_000 − 793_750)

1U →  43.65625 mm      2U →  88.10625 mm
3U → 132.55625 mm      4U → 177.00625 mm
```

Store height as an **integer U count**. Derive the drawn height only in the scene builder, only for dimensioned output. Two unit tests are written before any other code (CR-001, §7.2.1): exact 1/32-in clearance, and **zero accumulated error across a 45U stack**.

Do not attempt the inverse, a real panel measured at 3.44 in is still a 2U panel. Measured height never infers U.

### 2.3 Vertical hole pattern

Hole centre spacing repeats **0.500 / 0.625 / 0.625 in** (12.70 / 15.88 / 15.88 mm), summing to 1.750 in **[std]**. Within a U, holes sit at **0.25, 0.875 and 1.50 in** (6.35, 22.23, 38.10 mm) from the U boundary. **The U boundary falls at the midpoint of the 0.5-in gap**: in the middle of the narrow web between two holes, never at a hole centre.

```text
        ── U boundary (midpoint of the tight pair)
   ○  ← 1.50 in   outer hole      ┐
                                  │
   ○  ← 0.875 in  centre hole     │  one rack unit, 44.45 mm
                                  │
   ○  ← 0.25 in   outer hole      ┘
        ── U boundary
```

Consequences for the elevation renderer: division lines are drawn through the tight 0.5-in pair, a 1U device's ears land on the two outer holes, and the centre hole is normally unused by 1U gear and used by 2U-and-taller gear.

### 2.4 Rail types

`RailType { tapped10_32, tapped12_24, squareCageNut, roundClearance, m6 }` (CR-037). Rail type drives hole rendering and the hardware line in the Equipment List and Materials sheet. **It never gates placement**: a device that does not fit the hardware is a purchasing problem, not a geometric one.

| Value | Where it is found |
|---|---|
| `tapped10_32` | The de-facto pro A/V default (Middle Atlantic RRF rackrail) |
| `tapped12_24` | Older telecom and several Middle Atlantic wall racks |
| `squareCageNut` | IT and data-centre racks; cage nut snaps into a square hole |
| `roundClearance` | Unthreaded, used with clip nuts |
| `m6` | Metric equivalent of the tapped case |

### 2.5 Widths other than 19 inch, and half-rack

| Format | Panel width | Status |
|---|---|---|
| Standard | 19 in / 482.6 mm | EIA-310-D **[std]** |
| **Half-rack** | 9.5 / 10 / 10.4 / 10.5 in | **No standard exists**: sources state this explicitly |
| 10-inch | ~254 mm | SOHO cabinets; U pitch unchanged |
| 23-inch | 584 mm | Telecom / broadcast |
| ETSI | 535 mm external | European telecom |

Half-rack width is genuinely unstandardised, so it is **not** modelled as "0.5 rack width". `RailPlacement` carries `startTwelfth ∈ 0..11` and `spanTwelfths ∈ 1..12`; two half-rack devices sharing 1U are `{0,6}` and `{6,6}`. **Ruling: twelfths ship in the file format, and the v1 editor exposes exactly three positions** via a `Width position` dropdown: `Full (0,12) | Left half (0,6) | Right half (6,6)` (CR-030). *Rejected alternative: free lateral dragging, deferred to v1.2, retrofitting a lateral axis into `Placement` is a migration touching every device, so the field ships now (G5).* A half-rack device placed alone is allowed and files an advisory naming the ear kit.

### 2.6 Form factors, common RU heights and depths

`heightU ∈ [1, 60]`, asserted as a load invariant, with an advisory above 50 (CR-038). *Rejected alternatives: 58 (products exist above it) and unbounded (no performance envelope).*

| Form factor | Typical RU | Typical depth | Notes |
|---|---|---|---|
| Small wall box / hinged | 4–8U | 12–18 in | Closet or utility room |
| Wall swing-gate (open frame) | **12U, 20U** | 12 or 18 in | Front frame swings out 90° for rear access |
| Wall swing / pivot cabinet | 6–18U | 17–26 in | e.g. 12U at 17 in deep |
| Floor enclosure (A/V) | **18, 21, 27, 35, 40, 44U** | 20 or 25 in | The residential CI mainstream |
| Floor enclosure, deep / gangable | 24, 37, 40, 44U | usable 25.75 / 30.75 in | Note *usable* vs *overall* |
| Open-frame 4-post | 24–44U | ~31.5 in | `usableDepth` is `null` on 2-post |
| Data-centre standard | **42U** | 36 in (914 mm) | 600 mm external width |
| Credenza / furniture | ~4–12U per bay | varies | Thermally the worst case |

`Rack.usableDepth` is `Len?`, **nullable, because a 2-post frame has no meaningful usable depth** (AC-050/A1.3). Vendors use "usable" and "overall" inconsistently; store usable explicitly and label it in the UI.

Weight capacities are the binding constraint in residential work far more often than RU: a floor enclosure may be rated 2,500 lb while a 12U swing-gate wall rack is rated **100 lb** and a pivoting wall cabinet **150 lb**. A wall rack holding a UPS and an amplifier hits its weight limit long before it runs out of rack units. VERIFY: individual vendor capacity figures before they are seeded into `assets/catalog/`; every numeric field needs a citation in `assets/catalog/sources.md` (AC-052).

---

## 3. Occupancy: what consumes a rack unit and what does not

**Occupancy is a property of the mount, not of the object class.** A 1U blank panel and a rear-mounted lace bar are both "rack accessories" and they consume completely different things.

**Ruling: `OccupancySide { front, rear, both, zeroUVertical, none }`, with depth and weight as siblings on `TemplateBody`, not folded into the occupancy struct** (CR-036). *Rejected alternative: an `Occupancy` struct owning depth and weight, which implies those vary with mounting; they do not.*

```dart
// TemplateBody, abridged — see 02-data-model.md
final int frontU;              // RU consumed on the front rails
final int rearU;               // RU consumed on the rear rails
final OccupancySide side;
final Len? bodyDepth;          // chassis depth
final Len? connectorProjection;// derived from the deepest rear connector, AC-022
final Len chassisWidth;        // default 432 mm, AC-032
final Mass? weight;            // null means unknown, never estimated
final Mass? maxUnsupportedMass;// AC-028
```

| Occupant | `frontU` | `rearU` | `side` |
|---|---|---|---|
| 1U blank panel | 1 | 0 | `front` |
| 2U patch panel | 2 | 2 | `both` |
| Rear-mounted L lace bar | 0 | 1 | `rear` |
| Vertical (0U) PDU | 0 | 0 | `zeroUVertical` |
| Field device (speaker, display, AP) | 0 | 0 | `none` |

**Front and rear capacity are independent**, and answering "how many U do I have left?" requires both. Front-RU consumers include blank panels, vent panels (a 4U vent is ~64% open area), fan panels (which also draw power), shelves, drawers, patch panels, horizontal cable managers, rackmount PDUs, power conditioners and sequencers, UPSs and their battery packs. Zero-U occupants include vertical PDUs (24–60 outlets, versus 6–16 on a 1U horizontal), vertical lacer strips, side-mount brackets and rear-rail trays.

Patch-panel height is **a per-template field and is never derived from port count**: 24-port panels ship as both 1U and 2U depending on vendor, and 48-port panels ship as 2U with high-density 1U variants.

### 3.1 Shelves

A large fraction of residential CI gear has no rack ears at all, streaming boxes, set-top boxes, control processors, wireless mic receivers, small amplifiers, power supplies. These are shelf-hosted, and the relationship is **child→parent only** (CR-029): `ShelfPlacement{hostDeviceId, order: FracIndex, lateralOffset: Len?, locked}`. *Rejected alternative: a parent-owned `hosts[]` array, which is both a second source of truth and positional identity.* `shelf.hosts` is a derived view sorted by `order`.

Rules the model encodes: a shelf consumes its own RU and **hosted devices consume zero additional RU**; hosted weight sums against the shelf's capacity (real shelves are rated 25–50 lb, which two set-top boxes and a wall wart reach quickly); hosted depth is checked against usable shelf depth (10-in shelves are shallower than many STBs); and hosted ports participate fully in the netlist, the schedule and the front/rear split. v1 auto-packs left to right; free lateral positioning is v1.1 (AC-043).

### 3.2 Depth is an interval, not a boolean

**Ruling: depth occupancy is an interval on the depth axis per `(RU, face)`** (AC-022). Checking front and rear occupancy independently lets a 16-in-deep amplifier at U19–U21 front and an 8-in rear tray at U20 rear both pass while physically fighting for the same air. This is *the* failure mode in shallow racks, which is most residential racks.

```text
RCK-012 (error): frontDepth + rearDepth + 50 mm cable allowance > usableDepth
                 for any overlapping RU range
```

`connectorProjection` is **derived from the deepest connector type actually present on the device's rear panel**, not from a flat `depth + 75 mm` (AC-022). A moulded HDMI with a bend needs 100–125 mm and a compression-F on RG6 about 100 mm, both under-reported by 75 mm. VERIFY: the per-connector projection table before it seeds the catalog.

### 3.3 Reversed chassis

`RailPlacement.chassisRotation: normal | reversed` (AC-023, CR-031). Reversing a chassis so its rear panel faces out is standard practice in credenza racks and 2-post frames. **A port's effective face is `templateFace XOR reversed`.** The rear-panel view groups by *access side*, not by template face, and the elevation draws a ↺ badge.

---

## 4. The constraints integrators actually track

Five rollups per rack, all derived, none stored (CR-115). Every one reports its unknown count.

### 4.1 Weight

```text
rackWeight     = Σ device.weight    where weight != null
unknownCount   = count(device.weight == null)
```

`RCK-003 warning: Σ weight > rack capacity` (advisory at 85%). It is a **warning, never an error**: a found over-specification must be documentable (G2, CR-020). `RCK-003b warning: wall-mount rack over 80% of capacity`, because wall racks are the documented failure mode (CR-021).

Centre of gravity is `RCK-004 advisory at 55%, default off for wall and credenza form factors` (CR-020, AC-034/m19). Heavy items belong at the bottom, a UPS installed at the top of a tall rack is a documented cause of forward lean **[trade]**.

`RCK-013 warning: DEVICE (34 lb) mounted on front ears only; requires rear support or a shelf` fires when `weight > maxUnsupportedMass`, which defaults to ~7 kg (15 lb) for `mountMethod: rackEars` (AC-028). The support hardware is added to the materials list. VERIFY: the 7 kg default against manufacturer install manuals.

### 4.2 Power

**Circuit loading is computed in VA on `typicalWatts` × a per-category diversity factor**, with nameplate as an advisory second line (AC-020, CR-056). *Rejected alternative: an error computed on nameplate with `isContinuousLoad` defaulting true, which makes a normal residential theatre rack permanently over-limit.*

```text
deviceVA   = typicalWatts × diversityFactor ÷ (powerFactor / 1000)
circuitVA  = Σ deviceVA over the circuit
circuitA   = circuitVA ÷ Circuit.volts

NEC 210.19(A)(1)  [std]: a load running ≥ 3 hours is continuous; the OCPD
must be rated ≥ 125% of it — equivalently, continuous load ≤ 80% of rating.
   15 A circuit → 12 A continuous
   20 A circuit → 16 A continuous
```

**WHAT RACKPAL COMPUTES IS A PLANNING ESTIMATE, AND IT IS NOT THE CODE RULE ABOVE** (DR-079 §11.78.4). The statement of 210.19(A)(1) is accurate; the arithmetic this product performs is a different thing, and the gap is worth stating rather than leaving a reader to assume it closed:

| The code rule | What this product does |
|---|---|
| Classifies each load as continuous (≥ 3 hours) or not | **Classifies nothing.** No field on any entity records it |
| Applies demand factors from Art. 220 | **Applies none** |
| Sizes the OCPD and the conductor against the result | Sums `typicalWatts × diversity` in **VA** and compares it to 80% of the breaker |

So `PWR-001` names the circuit to look at first. **It does not assert compliance, and a person sizing a service still does a load calculation.** It is a warning rather than an error for exactly this reason (CR-020), and `derived/totals.dart` refuses to invent a power factor to reach VA from watts rather than fabricating an input it was not given (AC-039). The three together are one position: this product estimates, says so, and declines to make up what it was not told.

`PowerProfile` carries `nameplateWatts`, `typicalWatts`, `apparentVA`, `powerFactor` (permille) and `poeBudgetWatts`, all `int?` (CR-056). **`typicalWatts` never defaults to a fraction of nameplate**: a silent 50%-of-nameplate estimate is prohibited (G4, AC-039). Default diversity factors: amplifiers 350‰, switches 1000‰, UPS 1000‰; configurable per project.

Power factor is not decorative. A linear-supply amplifier at PF 0.65 under-reports current by 35% under a naive `watts ÷ 120`, which is exactly how a system that "calculated fine" trips a breaker.

`Circuit.volts` is authoritative downstream of a circuit; `PowerProfile.nominalVolts` is the device's *rated* input, used only for a compatibility check; `Rack.lineVoltage` is deleted in favour of `ProjectSettings.defaultLineVolts` (CR-039). **Circuit membership is derived by walking power Links** (device inlet → PDU outlet → PDU inlet → circuit); `Port.circuitId` survives only where the rack meets the building (CR-028).

Outlet balance matters as much as amperage, running out of PDU outlets is as common as running out of RU. `PWR-006 warning: device with power draw and no outlet assignment` (CR-021).

### 4.3 Heat

**Ruling: one constant, `kBtuPerWattHour = 3.412142`, defined once in `rackpal_core/units/thermal.dart`** (CR-005). *Rejected alternatives: 3.41214 and 3.412, which appeared in three different design documents.*

```text
btuPerHour = watts × 3.412142            // derived, NEVER stored
```

`TemplateBody.btuPerHourOverride` exists only for the rare manufacturer figure that disagrees with the arithmetic. Every watt consumed in the room becomes a watt of heat in the room. Sanity anchors: a residential A/V rack is typically 300 W – 2 kW ≈ 1,000–6,800 BTU/hr; a 7 kW rack is ≈ 24,000 BTU/hr.

### 4.4 Airflow and adjacency

All **[trade]**, therefore all advisory and several default-off:

- A 1U spacer or vent panel between amplifiers and other high-heat gear.
- Heat-sensitive gear low, where intake air is cool.
- Vent or fan panels above heat sources to assist convection, **but this is backwards in a sealed fan-cooled enclosure**, where blanks are used instead to force air through the intended path. `RCK-007 advisory: heat source with no vent above` is therefore gated on `Rack.formFactor` and on whether a fan panel is present (CR-021, AC-034/m20).
- Reserve 15–25% spare RU. `RCK-008 advisory, default off`, a planning opinion, not a fact (CR-020).

### 4.5 Depth clearance

`RCK-005 warning: device depth > usable depth`, **a warning that never blocks the drop** (CR-020). Blocking the drop while permitting the same state to be reached by editing the rack's depth is incoherent. Add 50–100 mm behind the deepest device for connectors and bend radius; HDMI and stiff coax are the worst offenders. Depth targets of 18–22 in residential and 24–30 in commercial are **[trade]** hints, not validation thresholds.

---

## 5. Signals: three orthogonal axes, never one enum

**This is the single most expensive mistake available in this domain.** RJ45 is a *connector*. Cat6a is a *medium*. Ethernet, HDBaseT, Dante and Cresnet are *signal families* that share both. HDBaseT deliberately reuses Ethernet conductors, cable and connectors **and is not interchangeable with them**: patching an HDBaseT output into a switch does not work, and its 100 W PoH can damage the switch. That check is the highest-value validation in the product and it is only expressible because the axes are separate (§6.1 of the decision record).

So there are four registries (CR-058, CR-078):

| Registry | Answers | User-extensible in v1? |
|---|---|---|
| `SignalDomainDef` | Colour, dash, weight, glyph for this class of signal | No: 8 fixed entries |
| `SignalFamilyDef` | What the signal *is*, what it requires, what it may mate with | **By clone only** (DR-122; was catalog-updated, RJ-012) |
| `ConnectorTypeDef` | What plugs into what, and whether gender applies | Aliases only |
| `MediaTypeDef` | What cable is pulled, how long it may be, what jacket | **Yes**: CSV import creates them (RJ-009) |

`Port.connector` and `Port.signalFamily` are two independent fields; `Link.media` is a third. **`Port.carriedProtocols` was named here as a third axis until DR-134 §11.133 deleted it**, on the measurement that it was a second copy of two facts the model already carried: eARC over HDMI is `PortDef.returnChannel`, and Dante over RJ45 is the port's own signal family plus a device tag. **`Service.signalFamily` is what a wire's colour resolves from: never `Link`** (CR-009). `Link.dominantSignalFamily` is derived and never serialized.

**A `Link` carries `List<Service>`** (CR-010, AC-021). One Cat5e to a TV location routinely carries an IR emitter run on one pair, a 12 V trigger on another and RS-232 on a third. *Rejected alternative: one cable, one service, which forces three Links on one physical cable, three pull rows and three lengths to keep in sync.*

```text
Link      { id, designator W###, class, media, jacket, gauge, shielded, plenum,
            routedLength, cutLength, terminatedLength, roughInStatus, test,
            pathwayId, structureOrigin?, breakouts[], conductors[], services[] }
Service   { id, signalFamily, netId, conductorRoles[], label }
Conductor { role, from: Endpoint, to: Endpoint, pairNumber, colorCode, polarity }
Endpoint  = PortEndpoint | PlaceEndpoint | OpenEndpoint
```

### 5.1 Colour encodes domain, not type

There are ~50 signal families and **no categorical palette is colour-vision-deficiency-safe past 8–9 categories**: the Okabe–Ito authors stopped at eight for exactly that reason, having verified their set under protanopia, deuteranopia and tritanopia. A hue per cable type produces an unreadable drawing, and it fails hardest for the ~8% of male installers with a CVD who are the audience.

**Ruling: four independent encoding channels; hue is never one of them alone** (AC-054, CR-078):

| Channel | Encodes | Survives CVD | Survives greyscale | Survives photocopy |
|---|---|---|---|---|
| Hue | domain (8) | yes | no | no |
| Dash pattern | type within domain | yes | yes | yes |
| Line weight | domain tier (0.75×–2.0×) | yes | yes | yes |
| Glyph + tag pill | exact family | yes | yes | yes |

The **tag pill** (`W042 · HDMI · 25 ft`, carried at both ends of every run) is the encoding that never fails and is mandatory, not decorative. It survives the default rendering, which is **net labels**: every `Link` is two labelled stubs, one at each pin, with no polyline between them; drawn wires appear on domain filter, `Alt`-hover or focus (DR-001). Full rendering detail is in [the visual language](05-schematic-editor.md#66-rendering-constants-stated-once).

#### The eight domains

| `id` | Display | Light hex | Base dash (pt) | Weight | Glyph (native / transported) | Rel. lum. |
|---|---|---|---|---|---|---|
| `video.digital` | Digital Video | `#0072B2` | solid | 1.00× | ▲ / △ | 0.1525 |
| `video.analog` | Analog Video & RF | `#56B4E9` | `12,4` | 1.00× | ▼ / ▽ | 0.4050 |
| `audio.analog` | Analog Audio | `#E69F00` | `6,3` | 1.00× | ● / ◐ / ○ | 0.4162 |
| `audio.digital` | Digital Audio | `#D55E00` | `6,3,1,3` | 1.00× | ◆ / ◇ | 0.2215 |
| `net` | Network | `#009E73` | solid | 1.50× | ■ / □ | 0.2569 |
| `ctl` | Control | `#CC79A7` | `1.5,3` | 0.75× | ✚ / ✳ | 0.2930 |
| `pwr` | Power | `#000000` | `8,3,1.5,3,1.5,3` | 2.00× | ⬢ / ⬡ / ⏚ | 0.0000 |
| `str` | Structure | `#999999` | `6,3,3,3` | 0.75× | ★ / ☆ | 0.3185 |

Yellow `#F0E442` is reserved for selection and focus and **is never a cable** (PAL-2). The claim that Okabe–Ito survives greyscale is **false** and is not repeated: sky blue (0.4050) and orange (0.4162) are 1.1% apart, and vermillion/green/purple share a 0.07 band. The collisions are placed deliberately and separated on the other three channels, which is promoted to a checkable rule:

> **PAL-1 (rendered-value form).** Every shipped `SignalFamilyDef` renders as the triple **(L, dashClass, weight)**, where **L** is the WCAG relative luminance of its **effective** hue, **dashClass** is the class of its **effective** dash pattern, and **weight** is its **effective** line weight — *effective* meaning after any per-family override, not the domain base value. For every pair of families in **different** domains with **|L₁ − L₂| < 0.10**, at least one must hold: **(a)** their dash classes differ, **or** **(b)** their weights differ by a factor **≥ 1.4**. Families within one domain are exempt from (a)/(b) — they share a hue by construction and the legend prints them adjacently — but must still differ in dash, weight, or glyph.

The within-domain limb is a **domain-equality check, never an allowlist of waived pairs**. An allowlist is how a real collision gets waived.

PAL-1 is enforced by [`tools/pal1_check.py`](../tools/pal1_check.py), which enumerates every in-band cross-domain family pair actually drawn; it is ported to `pal1_conformance_test.dart` in `rackpal_core` at M0 and that check is the authority thereafter (canon §14). Where this document and that file disagree, **the file wins and this document is the bug report**. PAL-1 is never established by reading the eight domain rows above: the domain table states base values, while PAL-1 is a statement about the ~55 shipped families' *effective* values, and a check performed against the eight rows passed three times over a palette carrying fourteen collisions. The dash-period floor is **≥ 4.5 pt** (1.5875 mm).

---

## 6. The signal family reference

Direction key: **→** unidirectional source→sink · **↔** bidirectional · **BUS** multi-drop shared medium · **MD** multi-drop via passive splitters · **⤳** logical flow riding a network. Topology: **P2P** · **MD** · **STAR**.

This is the authored content of `assets/catalog/registries.json`. It is data that ships, not illustration.

### 6.1 Digital video: `#0072B2`

| `id` | Display | Connector | Dir | Topo | Tag | Typical max length | Note |
|---|---|---|---|---|---|---|---|
| `video.hdmi.1_4` | HDMI 1.4 | `conn.hdmi_a` | → | P2P | `HD14` | ~15 m passive | Legacy |
| `video.hdmi.2_0` | HDMI 2.0 (18 Gbps) | `conn.hdmi_a` | → (+ARC ↔) | P2P | `HD20` | **~7.5 m** passive | HDCP + EDID handshake |
| `video.hdmi.2_1` | HDMI 2.1 (48 Gbps) | `conn.hdmi_a` | → (+eARC ↔) | P2P | `HD21` | **3–4.5 m** passive | See §7.2 |
| `video.displayport` | DisplayPort 1.4 / 2.1 | `conn.dp` | → (+AUX ↔) | P2P / MST | `DP` | **DP80 1.2 m** passive | Brutally short; MST daisy-chain is real |
| `video.sdi` | SDI (HD/3G/6G/12G) | `conn.bnc75` | → | P2P (+loop) | `SDI` | 3G ~100 m; **12G ~45–50 m** | 75 Ω; a 50 Ω BNC looks identical and fails |
| `video.hdbaset` | **HDBaseT (5Play)** | `conn.rj45` | → video, ↔ ctl | P2P | `HBT` | **100 m on Cat6a at 4K** | See §7.1 |
| `video.usbc_dpalt` | USB-C DP Alt Mode | `conn.usb_c` | ↔ | P2P | `UCV` | ~1–2 m at full BW | Cable capability is invisible |
| `video.avoip` | AV-over-IP (SDVoE / JPEG XS / NDI) | `conn.rj45` | ⤳ | STAR | `AVIP` | per network | Draw as logical, not P2P; needs IGMP snooping + querier |

`LEN-001` exists precisely because a 25 ft HDMI run that worked at 4K60 fails at 4K120.

### 6.2 Analog video and RF: `#56B4E9`

| `id` | Display | Connector | Dir | Topo | Tag | Note |
|---|---|---|---|---|---|---|
| `video.composite` | Composite (CVBS) | `conn.rca75` | → | P2P | `CVBS` | Same connector as analog audio and S/PDIF, label discipline required |
| `video.component` | Component YPbPr | `conn.rca75` | → | P2P, 3-port set | `YPBPR` | `PortSetDef` kind `componentVideo`, `atomicConnect: true`, three ports, one gesture, one Link, three conductors |
| `video.vga` | VGA / RGBHV | `conn.hd15` | → (+DDC ↔) | P2P | `VGA` | 5-BNC breakout is a 5-port set |
| `video.svideo` | S-Video | `conn.mini_din4` | → | P2P | `SVID` | Legacy retrofit only |
| `rf.catv` | RF / CATV distribution | `conn.f_type` | → (↔ DOCSIS) | **MD** | `RF` | Splitter loss is the design; a 2-way splitter is ≈3.5 dB. Cascade rule is v1.2 |
| `rf.satellite` | Satellite / SWM | `conn.f_type` | ↔ | **MD, power-passing** | `SAT` | See §7.6 |
| `rf.ota` | OTA antenna | `conn.f_type` | → | MD | `OTA` | Often diplexed with satellite; preamp needs power injection |
| `rf.modulated` | RF modulated channel | `conn.f_type` | → | MD | `RFM` | — |

### 6.3 Analog audio: `#E69F00`

| `id` | Display | Connector | Dir | Topo | Tag | Wt | Note |
|---|---|---|---|---|---|---|---|
| `audio.line_unbal` | **Line level, unbalanced (RCA)** | `conn.rca` | → | P2P | `AUD` | 1.00× | ~6 m before hum/loss; −10 dBV nominal |
| `audio.line_bal` | Line level, balanced | `conn.xlr3` | → | P2P | `AUDB` | 1.00× | 100 m+; +4 dBu; **gender is load-bearing** |
| `audio.mic` | Mic level | `conn.xlr3` | → | P2P | `MIC` | 1.00× | May carry 48 V phantom: a port flag |
| `audio.phono` | Phono / turntable | `conn.rca` | → | P2P | `PHNO` | 1.00× | The separate ground is a real `Conductor` on the schedule, not a footnote |
| `audio.speaker_lowz` | **Speaker level, low-Z** | `conn.binding_post` | → | P2P / parallel | `SPK` | **2.00×** | Polarity is schedulable; `impedanceOhms` on the terminal feeds `ELE-004` |
| `audio.speaker_cv` | Speaker, constant-voltage 70/100/25 V | `conn.euroblock_2` | → | **BUS (multi-tap)** | `70V` | **2.00×** | See §7.3 |
| `audio.sub` | Subwoofer / LFE | `conn.rca` | → | P2P (or Y-split) | `SUB` | 1.25× | One output, sometimes two sinks |
| `audio.headphone` | Headphone | `conn.6_35mm_trs` | → | P2P | `HP` | 0.75× | Completeness |

The requirement's "Analog RCA" and "speaker level" share one orange and are separated by a **2× stroke weight** plus ● vs ◐, the most legible mono discriminator available.

### 6.4 Digital audio: `#D55E00`

| `id` | Display | Connector | Dir | Topo | Tag | Note |
|---|---|---|---|---|---|---|
| `audio.spdif_coax` | **S/PDIF, coaxial** | `conn.rca75` | → | P2P | `SPD` | `nominalImpedanceOhms: 75`; physically identical to `audio.line_unbal`, see §7.7 |
| `audio.spdif_optical` | **TOSLINK** | `conn.jis_f05` | → | P2P | `OPT` | POF ~5–10 m, glass 30 m+. **Cannot carry lossless multichannel**: no DTS-HD MA, no TrueHD |
| `audio.aes3` | AES/EBU (AES3) | `conn.xlr3` | → | P2P | `AES` | **110 Ω STP, not mic cable**, despite the identical XLR. 2 channels per link |
| `audio.aes3id` | AES3id | `conn.bnc75` | → | P2P | `AES75` | 75 Ω variant |
| `audio.dante` | Dante | `conn.rj45` | ⤳ | STAR | `DNT` | **PTPv1**; latency to 150 µs; needs QoS/DSCP, ideally a dedicated VLAN |
| `audio.aes67` | AES67 | `conn.rj45` | ⤳ | STAR | `A67` | **PTPv2 (IEEE 1588-2008)**; fixed 2–3 ms |
| `audio.avb` | AVB / Milan | `conn.rj45` | ↔ | STAR (**TSN switches only**) | `AVB` | `requiresTsnPath: true`; not any managed switch |

### 6.5 Network: `#009E73`

| `id` | Display | Connector | Dir | Topo | Tag | Note |
|---|---|---|---|---|---|---|
| `net.ethernet` | **Ethernet (copper)** | `conn.rj45` | ↔ | STAR | `NET` | **100 m channel = 90 m horizontal + 10 m patch [std].** Over it is an *error*, not a warning, one of the few hard numbers in the trade |
| `net.poe` | PoE / PoE+ / PoE++ | `conn.rj45` | → power, ↔ data | STAR | `PoE` | See §7.5 |
| `net.poh` | PoH (HDBaseT power) | `conn.rj45` | → | P2P | `PoH` | Own family, own glyph: not a flag on PoE |
| `net.fiber_mm` | Fibre multimode (OM3/OM4) | `conn.lc_duplex` | ↔ | P2P / STAR | `FIB` | ~300–400 m at 10 G; A/B polarity is `Link.crossover` |
| `net.fiber_sm` | Fibre singlemode (OS2) | `conn.lc_duplex` | ↔ | P2P / STAR | `FIBS` | 10–40 km |
| `net.dac` | Direct-attach copper | `conn.sfp_cage` | ↔ | P2P | `DAC` | — |

### 6.6 Control: `#CC79A7`

| `id` | Display | Connector | Dir | Topo | Tag | Shipped limits |
|---|---|---|---|---|---|---|
| `ctl.ir_emitter` | **IR emitter (flasher)** | `conn.3_5mm_ts` | → | P2P | `IR` | ~15 m; see §7.4 |
| `ctl.ir_receiver` | IR receiver (powered eye) | `conn.3_5mm_trs` | → to block | MD | `IRRX` | ~60 m; the POWERED receiver-eye circuit only: a block's RX jacks, its `IR IN`, the eye pigtail (DR-126) |
| `ctl.ir_direct` | IR direct (device input) | `conn.3_5mm_ts` | ← from emitter | P2P | `IRD` | ~15 m; the passive jack on a matrix, AVR, source or TV that an emitter lead lands on. Not powered, so `DIR-003` does not fire on it (DR-126) |
| `ctl.rs232` | **RS-232** | `conn.de9` | ↔ | **P2P only** | `232` | ~15 m at 9600–19200; see §7.8 |
| `ctl.rs485` | RS-485 | `conn.euroblock_3` | ↔ half-duplex | **BUS** | `485` | **32 unit loads**, 120 Ω at *both* ends only, 1200 m |
| `ctl.dmx512` | DMX512-A | `conn.xlr5` | → over RS-485 | **BUS** | `DMX` | 32 unit loads, **512 channels/universe**, terminator at the far end, `busUniverse` on the port |
| `ctl.contact` | Contact closure / relay / GPIO | `conn.euroblock_2` | → drive or ← sense | P2P | `CC` | NO vs NC; dry vs wet; a sense input and a drive output are opposite directions |
| `ctl.trigger12v` | 12 V trigger | `conn.3_5mm_ts` | → | P2P | `TRG` | **`maxCurrentMa: 100`**; requires a *mono* plug, a stereo plug shorts ring to sleeve |
| `ctl.cresnet` | Cresnet | `conn.phoenix_4` | ↔ | **BUS**, topology-free | `CN` | Two independent limits: ~915 m data *and* 18 AWG at 20 W ⇒ **333 ft** power drop. `BUS-005` emits two findings |
| `ctl.lutron_qs` | Lutron QS / HomeWorks link | `conn.rj45` | ↔ | **BUS**, topology-free | `QS` | 2000 ft on 12 AWG |
| `ctl.dali` | DALI / DALI-2 | `conn.screw_terminal` | ↔ | **BUS**, topology-free | `DALI` | **64 devices per line**, ~300 m, polarity-free, a wiring error is inexpressible |
| `ctl.knx` | KNX TP1 | `conn.knx_terminal` | ↔ | **BUS** (line/tree) | `KNX` | 64 devices per line segment, 1000 m per line |
| `ctl.vantage` | Vantage station bus (Legrand) | `conn.hardwired` | ↔ | **BUS** (line / tree) | `VTG` | Two-wire station bus; a family of its own so it is not drawn as an unnamed two-wire run |

**`topologyFree` is a registry field, not a hard-coded suppression array** (AC-030). It ships set on `ctl.cresnet`, `ctl.lutron_qs`, `ctl.dali` and `ctl.knx`. A star-wired Cresnet run is Crestron's own recommended residential approach; a rule that fires on every correctly wired Crestron job for the life of the product is worse than no rule.

### 6.7 Power: `#000000`

| `id` | Display | Connector | Dir | Tag | Note |
|---|---|---|---|---|---|
| `power.ac_branch` | **AC branch circuit** | `conn.nema_5_15p` | → | `PWR` | Circuit identity, breaker size and phase are all schedulable |
| `power.ac_iec` | IEC device power | `conn.iec_c14` | → | `IEC` | **Odd IEC number = female connector on the cord; next even = male inlet on the equipment.** C13→C14 is the standard rack pigtail |
| `power.ac_hardwired` | Hardwired AC | `conn.hardwired` | → | `HW` | — |
| `power.dc_low` | Low-voltage DC (12/24 V) | `conn.barrel_dc` | → | `DC` | — |
| `power.bonding` | Bonding / grounding conductor | `conn.ground_lug` | ↔ | `GND` | Exists so a bonding conductor is *drawable*. Busbar entity and conductor sizing are v1.2 (RJ-010) |

**Inlet and outlet are not directions**: they are `sink`/`source` on a `power.*` family plus `PortPowerSpec.role: inlet | outlet` (CR-058, CR-060). Links on `power.*` originating at a PDU outlet auto-classify as `LinkClass.powerCord` and are excluded from the pull sheet by default, appearing instead as an **outlet map** on the power schedule (AC-026).

PDU outlet attributes that matter: switched / unswitched / sequenced (with step and delay) / UPS-backed / surge-only / metered. `SEQ-001 warning: amplifier on sequencer step 1 of 4 — amplifiers should be last on and first off` (AC-033); a reversed sequence thumps and blows drivers.

### 6.8 Structure: `#999999`

| `id` | Display | Connector | Tag | Note |
|---|---|---|---|---|
| `structure.undetermined` | Undetermined home run | `conn.unterminated` | `STR` | **Legal and deliberate.** A Cat6 home run at rough-in may end up carrying Ethernet, HDBaseT, or nothing. It schedules, prints, gets a `W` number and both labels; the DRC validates **retroactively** once a `Service` assigns a real family |
| `structure.pathway` | Pathway only (conduit / pull string) | — | `PATH` | Pairs with `MediaTypeDef.isPathwayOnly`. Creates a `Pathway`, never a Link and never a Port. Appears on the pull sheet, you still pull the smurf tube and it still costs money, and never in the netlist (CR-109) |

### 6.9 Media types

Full table in `assets/catalog/registries.json`; the load-bearing rows:

| `id` | Display | Cond / pairs | AWG | Ω | Max channel | Primary support |
|---|---|---|---|---|---|---|
| `media.cat5e` | Cat5e UTP | 8 / 4 | 24 | 100 | 100 m | `net.ethernet`, `video.hdbaset` (1080p), `ctl.*` on spare pairs |
| `media.cat6` · `media.cat6_futp` | Cat6 UTP · F/UTP | 8 / 4 | 23 | 100 | 100 m | `net.ethernet`, `video.hdbaset` (shielded preferred) |
| `media.cat6a_futp` | **Cat6a F/UTP** | 8 / 4 | 23 | 100 | 100 m | 10 G Ethernet, 4K HDBaseT, Dante |
| `media.rg6` · `media.rg6_quad` | **RG6** · quad-shield | 1 coax | 18 | 75 | ~150 m | `rf.catv`, `rf.ota` · `rf.satellite` (swept to 3 GHz) |
| `media.rg59` · `media.rg11` | RG59 · RG11 | 1 coax | 20 · 14 | 75 | ~100 m · ~300 m | `video.composite`, `audio.spdif_coax` · CATV trunk |
| `media.coax_video_75` | Precision 75 Ω video coax | 1 coax | 20 | 75 | 12G ~45 m | `video.sdi`, `video.component` |
| `media.mic_stp` | Mic / line STP | 2 + shield | 22 | — | 100 m+ | `audio.mic`, `audio.line_bal` |
| `media.aes_110` · `media.dmx_120` | 110 Ω AES/DMX · 120 Ω DMX/RS-485 | 2 + shield | 22 | 110 · 120 | 100 m · 1200 m | `audio.aes3` · `ctl.dmx512`, `ctl.rs485` |
| `media.16_2` · `16_4` · `14_2` · `14_4` · `12_2` | Speaker cable | 2 or 4 | 16 / 14 / 12 | — | gauge/length table; 14 AWG ≈ 15 m at 8 Ω | `audio.speaker_lowz` |
| `media.18_2_cv` | 18/2 constant-voltage | 2 | 18 | — | hundreds of feet | `audio.speaker_cv` |
| `media.22_2` · `media.22_4` | Control cable | 2 / 4 | 22 | — | long | `ctl.contact`, `ctl.trigger12v`, `ctl.ir_emitter` |
| `media.cresnet_18_22` | Cresnet | 4 / 2 | 18 + 22 | — | 915 m data · **333 ft at 20 W** | `ctl.cresnet` |
| `media.hdmi_passive` · `_active` · `_aoc` | HDMI passive · active copper · AOC | 19 bonded / hybrid | — | — | 2.1: 3–4.5 m · ~7.6 m · 15–90 m+ | `video.hdmi.*`: **active and AOC are direction-locked** |
| `media.om3` · `om4` · `os2` | Fibre | 2 strands | — | — | ~300–400 m at 10 G · 10–40 km | `net.fiber_mm` · `net.fiber_sm` |
| `media.conduit_emt` · `conduit_ent` · `pull_string` | EMT · ENT (smurf) · pull string | — | — | — | — | **`isPathwayOnly: true`** |

`JacketListing` carries **only NEC/UL listings**, 28 values across the five articles this product's media touch: communications `CM`/`CMG`/`CMR`/`CMP`/`CMX` (Art. 800/805), Class 2 and 3 `CL2`/`CL3` with their `R`/`P`/`X` variants (725), power-limited fire alarm `FPL`/`FPLR`/`FPLP` (760), optical fibre `OFN`/`OFC` with their `G`/`R`/`P` variants (770) and coax `CATV`/`CATVR`/`CATVP`/`CATVX` (820). **LSZH is not among them and never was a listing**; it is `Link.lowSmokeZeroHalogen`, an independent fact about the jacket compound, and direct burial is `Link.directBurialRated`, an application (DR-079 §11.78.1). NEC's substitution hierarchy is data (`jacket_substitution.dart`), so `CMP` satisfies a riser requirement and a listing from another article answers **unknown rather than false**.

None of it is decorative:

```text
CODE-001 (warning) [std NEC 725.136]: a Class 2/3 conductor shares a
                                       pathway with line-voltage circuits
CODE-002 (warning) [std NEC 800.154]: Pathway.kind == plenumSpace and the
                                       jacket's LISTING is not plenum-rated
                                       for its own NEC article
```

Both are acknowledgeable like every other rule (CR-019), an inspector's judgement outranks ours, **but the finding must exist**, because these are two of the very few checks in the product that protect the user from a code citation and a red-tagged job (AC-027).

**Both are WARNINGS that name what to verify, and neither asserts a violation** (DR-079 §11.78.3). A code citation is a claim about somebody's licence, and these two are held to a higher standard than the other twenty-six. NEC 725.136 runs to a substantial list of permitted arrangements and separations, and this product models none of the facts that would distinguish them, so a blanket error fires hardest on the commercial rows where the arrangement is most likely deliberate. NEC 300.22(C) permits ordinary cable in a plenum inside metal raceway, and **this product models no raceway**, so `CODE-002` cannot see the exception it would be citing. Each names its article, names the exception it cannot see, and says what to check. **This costs nothing that was ever enforced**: G2 and G3 already guarantee that no finding at any severity blocks a deliverable or gates the bytes.

**`CODE-002` reads a LISTING, never a material.** Its predicate named `lszh` until DR-079 §11.78.1, and LSZH is a jacket compound characteristic rather than a UL listing: it says nothing about the flame spread and smoke development testing a plenum listing rests on. The rule therefore produced a **false pass**, telling somebody an unlisted cable was fine in a plenum. It now resolves the cable's listing against its own NEC article through the substitution hierarchy, and a listing from another article, or none at all, is **unknown and skips** rather than failing (G4).

---

## 7. The tricky cases

These are the facts that a developer will get wrong by reasonable inference. Each one is why some field exists.

### 7.1 HDBaseT over RJ45 is not Ethernet

HDBaseT uses "conductors, cable, and connectors as used in Ethernet networks, but not otherwise exchangeable." Patching an HDBaseT output into a switch does not work, and its PoH, up to 100 W over four pairs, can damage the switch. In the registry: `video.hdbaset.topologyFree = false`, and **`acceptedFamilies` deliberately excludes `net.ethernet`**. That is what makes `SIG-001` fire. PoH is *based on* 802.3at but modified, and is **not** interoperable with a standard PoE PSE, which is why it is `net.poh` with its own glyph rather than a flag on `net.poe`.

### 7.2 ARC / eARC direction

One HDMI cable, video flowing source→display and audio flowing display→source (to the AVR). That is one physical `Link` with two `Service`s in opposite directions, the case `Link.services` exists for. On the port it is `Port.returnChannel{signalFamily, direction, enabled}`. HDMI 2.1 passive length collapses to **3–4.5 m** where 2.0 reaches ~7.5 m; DisplayPort DP80 passive is **1.2 m**. Active copper and AOC cables are **direction-locked** with marked source and display ends, installing one backwards produces no picture and no error message.

### 7.3 Constant-voltage (70 V / 100 V / 25 V) distributed audio

A multi-drop bus, not point-to-point. Each speaker carries a **transformer tap**, typically 2.5 / 5 / 10 / 15 / 20 W, and the sum of taps must not exceed the amplifier rating (design to ~20% headroom) **[trade]**. The critical modelling fact: **`Port.tapWatts` is per installation, not per device**, because the tap is a setting on the transformer, not a property of the speaker model. Long runs on 18/2 with negligible loss are normal, which is the whole point of the topology.

### 7.4 IR pinout variance is a hardware-destroying hazard

Xantech/Niles-style **receivers** are tip = signal, ring = GND, sleeve = +12 V. **Emitters** are tip = IR in, sleeve = GND. Plugging an emitter into a receiver jack destroys the emitter and can damage the supply. This is why `ctl.ir_emitter` and `ctl.ir_receiver` are separate families, and why **`PortDef.pinoutVariant` is mandatory on every 3.5 mm IR port**. It is a safety-adjacent field, so a template with an uncited value does not ship (AC-052).

### 7.5 PoE budgets

| Standard | Type | Classes | PSE max | PD max | Pairs |
|---|---|---|---|---|---|
| 802.3af (PoE) | 1 | 0–3 | 15.4 W | 12.95 W | 2 |
| 802.3at (PoE+) | 2 | 4 | 30 W | 25.5 W | 2 |
| 802.3bt (PoE++) | **3** | 5, 6 | **60 W** | ~40 W / ~51 W | **4** |
| 802.3bt (PoE++) | **4** | 7, 8 | **90 W** | ~62 W / ~73 W | **4** |
| PoH (HDBaseT) | — | — | **up to 100 W** | — | **4** |

Shipped as `PoeSpec{role, standard, type, class, watts}`. `NET-001` checks `Σ(PD class draw) ≤ PowerProfile.poeBudgetWatts`, **a switch's budget is almost always well below ports × max class**, and flags a Type-4 PD on a Type-2 PSE.

### 7.6 Satellite DC pass-through

`rf.satellite` carries `requiresPowerPassingPort: true`. **Exactly one splitter port passes DC back toward the LNB or multiswitch.** Wire a normal splitter and the dish never powers, a total system failure that looks like a bad receiver. SWM systems additionally have a hard tuner-count budget (SWM8 = 8, SWM16 = 16). VERIFY: SWM tuner budgets against current DIRECTV documentation before seeding.

### 7.7 S/PDIF coax is not an RCA interconnect

`audio.spdif_coax` sets `nominalImpedanceOhms: 75` and is **physically indistinguishable from `audio.line_unbal` at the connector**. Wiring a plain analog interconnect causes intermittent dropouts rather than an outright failure, which is why it is hard to diagnose in the field and why the impedance warning exists. The same trap in a different costume: AES3 is 110 Ω STP, not mic cable, despite the identical XLR.

### 7.8 RS-232 straight vs null-modem

Straight versus crossover is determined by the **DTE/DCE role of both ends**, not by connector or gender. DTE↔DTE needs a crossover (2↔3, 4↔6, 7↔8, 5→5). The role is carried in `SerialSpec.role` and surfaces as `Link.crossover`. `ctl.rs232` is **P2P only**: there is no legal multi-drop RS-232. The fibre analogue is A/B pair polarity, stored as `Link.crossover: fiberPolarityAB`.

### 7.9 Audio-over-IP has no dedicated cable

Dante, AES67, AVB, NDI and SDVoE connections between two devices have **no cable of their own**: physically each endpoint has one Cat6 run to a switch, while logically there are N channels between endpoint A and endpoint B. In v1 these are modelled as `Service`s on the real physical Links and the netlist resolves through the switch; the full flow layer (`SignalRoute`) is v2 and returns **with** a Dante view or not at all (CR-008, AC-036). *Rejected alternative: shipping a third entity layer in v1 with no editor for it, dead weight.*

Two checks that look drag-time and are not: "Dante endpoints with no network path" and "AVB traverses a non-TSN switch" are **post-hoc findings**, because the link being drawn may be the one that completes the path (CR-017).

### 7.10 Parallel speakers change the amplifier's load

`audio.speaker_lowz` carries `impedanceOhms` on the terminal so `ELE-004` (parallel speakers below the amplifier's minimum load) can evaluate. This rule can only fire because the Field Devices catalog exists (AC-031), the objects it operates on are speakers, which are not in the rack.

Polarity is a **derived property of the port pairing** (`PortDef.polarity`), not a free-text conductor role, so the typo is not expressible; `ELE-003` is a warning, not an error (AC-030). *Rejected alternative: deriving polarity from user-typed `Conductor.role` strings, which on a 16/4 across eight zones fires on typos roughly 100× more often than on real errors.*

---

## 8. Structured wiring

### 8.1 The standard

**ANSI/TIA-570-D** (2018) governs residential telecommunications infrastructure **[std]**. Residential CI is the primary market and fronts the UI; commercial capability is present and never fronts it (DR-002). Its architectural fact is the topology: **star / home run**: every outlet runs back unbroken to a central Distribution Device (DD). No daisy-chaining. That is precisely what the Structure device models.

Grades specify minimum media per cabled outlet location:

| Grade | Balanced twisted pair | Coax (75 Ω) | Fibre |
|---|---|---|---|
| 1 | 1 × Cat6A or higher | 1 | optional |
| 2 | 2 × Cat6A or higher | 2 | optional (2-fibre) |
| 3 | 2 × Cat6 or higher | 1 | **required** (2-fibre) |

The canonical residential outlet is Grade 2: **2 × Cat6/6A + 2 × RG6**.

**Ruling: user-defined `OutletTemplate` is first-class; grades are a standards tag, not an axis** (CR-108, confirmed by DR-002; AC-034/m23). Seeded templates: TV location · AP · Keypad · Ceiling speaker pair · Camera · Data-only, *plus* Grade 1/2/3. `StructureGrade` as an enum is deleted; `Outlet.tia570Grade: String?` survives for specs that cite it. *Rejected alternative: grades as the primary specification axis, essentially no CI integrator speaks in grades.*

### 8.2 The distribution device and the rack

Residential home runs terminate either in a **structured media enclosure** (14/21/28/42-in recessed cans, module bays rather than RUs) or, in higher-end CI work, directly on **rack-mounted patch panels**. The latter is RackPal's primary case. In commercial work the analogue is the MDF/IDF and the building's horizontal cabling.

Low-voltage rough-in is deliberately routed in separate stud bays from AC, and the pull happens at framing while termination and test happen after drywall. **That is why `roughInStatus` is meaningful rather than decorative**: `planned → pulled → dressed → terminated → tested` (CR-065). `Link.designatorLocked` auto-sets at `roughInStatus >= pulled`, once sixty cables are physically labelled, an accidental renumber is a day of relabelling (CR-034, AC-034/m22).

### 8.3 One home run is one Link

**Ruling: `StructureDrop` is deleted; a home run *is* a `Link`** (CR-107, AC-019). Its field end is a `PlaceEndpoint`, and it carries `Link.structureOrigin{structureBodyId, outletId, fieldLabel, rackLabel, wall?, mountHeightAff?, terminationField}`. *Rejected alternative: `StructureDrop` alongside `Link`, which gives one physical cable two rows, two lengths and two test results, guaranteed to diverge within a week of real use.* One cable, one row, one length, one certificate, one status.

`Outlet` (renamed from `StructureBundle`) is **one wall plate or one ceiling location**: the atom of creation, specification and pricing (CR-016). `Pathway` absorbs "bundle/snake" and `conduitId` and is purely organisational, carrying `kind: conduit | jhook | tray | plenumSpace | riser | directBury | exterior` and `containsLineVoltage: bool`. The word "bundle" survives only as UI copy for `Pathway`. **`Outlet.roughInStatus`** is the **minimum** of member statuses, derived, not serialized, an outlet is as complete as its least-complete run (CR-111, CR-115).

An unbound endpoint is legal and expected: `Endpoint = PortEndpoint | PlaceEndpoint | OpenEndpoint` plus `LifecycleStatus.designIntent` (AC-018). **A Cat6 to a projector shelf that does not exist yet still schedules, prints, gets a `W` number and gets a label**: that is the state of every job in February when drywall goes up in three weeks. `LNK-020 advisory: 14 links have unbound endpoints` is a checklist, not an error.

### 8.4 Length

There is no floor plan and the schematic is explicitly not to scale, so lengths have no geometric source. **`Location.estimatedRunLengthFromRack: Len?`**: one number per room, entered once, applied to every home run in that room with a per-link override (AC-024). Ninety seconds of input turns 62 null lengths into 62 usable estimates. Estimates render in italic everywhere and are tagged in the schedule so nobody bills off them. Three length fields, three columns: `routedLength` (estimate), `cutLength` (what to pull), `terminatedLength` (as-built). `LEN-*` rules emit `advisory: length unknown, cannot verify` when the length is null rather than silently passing (G4).

---

## 9. Documentation conventions

### 9.1 ANSI/TIA-606: labelling and administration

**606-C** (2017); 606-D exists. Voluntary but universally cited in commercial specifications **[std]**. Four administration classes scale with the premises: Class 1 (single equipment room) through Class 4 (multi-campus). The horizontal-link identifier is literally `<floor><space>-<panel><port>`:

```text
fs                  Telecommunications Space
fs-an               Horizontal link              → "1A-A12"
fs-TMGB / fs-TGB    Grounding busbars
fs1/fs2-n           Building backbone cable
f-FSLn(h)           Firestop location, h = hour rating
```

**The standard explicitly does not mandate a format**: it requires that the chosen format be consistent and produce a unique identifier for every element. That is why RackPal ships a **format engine** rather than a hard-coded scheme (CR-045): one grammar, one registry, one parser in `rackpal_core/idformat/`, shared by five call sites (device, port, link, outlet field label, outlet rack label). Every designator is evaluated once at creation and **stored** (CR-048); nothing is recomputed at render time.

606 placement rules that the product must not contradict: cables and pathways are labelled **on both ends**; labels are printed or mechanically generated (handwritten is non-compliant); and **labels must match the records**: the drawing, the schedule and the physical label are one dataset. That last requirement is the reason the diagram, the elevation and the schedule are three projections of one graph and the schedule is never stored separately.

606-C also recommends termination-class colours (orange = demarcation, green = network connection, purple = common equipment, blue = horizontal, and so on). **These conflict with signal-domain colour and are a separate, independently assignable dimension.** v1 ships signal-domain colour only; 606 termination colour is not modelled.

### 9.2 Residential practice diverges

There is **no residential labelling standard**. 606 assumes floors, telecom rooms and patch panels; a house has one rack and rooms with names. Residential practice names by room (`LR-TV-1`, `BR3-N-1`, `CAM-DRIVE-1`), suffixes multiple drops by wall direction or sequence, encodes signal type in the identifier (which 606 puts in the record, not the identifier), and labels twice per end so a label survives re-termination.

**Ruling: two labels per home run, both generated, both editable, and both always print, on every cable** (CR-044, AC-025, AC-047):

| Field | Default format | Preset |
|---|---|---|
| `StructureOrigin.fieldLabel` (required) | `{ROOM_ABBR}-{SERVICE}-{SEQ}` → `LR-TV-1` | Residential CI |
| `StructureOrigin.rackLabel` (optional) | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` → `1A-A12` | TIA-606 Class 2 |

`fieldLabel` uniqueness is **project-wide across all Structure instances**: labels get printed on physical cable and must not collide across panels (CR-113). The dual-label insight was originally applied only to structure drops; AC-025 extends it to every cable, because it is the single most common on-site failure point.

### 9.3 Designator conventions

Per ASME Y14.44 / IEEE 315 schematic practice **[std]**, adopted wholesale because it makes the schedule legible to anyone who has read a schematic:

| Prefix | Meaning | In RackPal |
|---|---|---|
| **J** | Fixed connector (jack) | `Port.designator` = `J{PORT_SEQ:2}` → `J01`, unique within the device (CR-042) |
| **P** | Movable connector (plug) | A cable end: implicit, not stored; the convention is referenced on the legend |
| **W** | Cable / wire harness | `Link.designator` = `W{SEQ:3}` → `W042` (CR-008) |

Devices are `{TYPE_PREFIX}{SEP}{SEQ}` → `MTX-1`, `AMP-12` (CR-041). Nets are `N{SEQ:3}`; `Net.name` is generated, editable and **never load-bearing**: membership is the foreign key `Service.netId`, never a name (CR-011, CR-049).

The AVIXA block-numbering convention (a 16×16 matrix becoming `2301–2316` inputs and `2401–2416` outputs) reserves identifiers for unpopulated I/O so future additions do not renumber. This is why ports are first-class with allocated identifiers whether or not they are connected.

### 9.4 ANSI/AVIXA F501.01: cable labelling for AV

Label within two inches of the connector; printed self-laminating; masking tape, insulation tape and handwritten marker **shall not** be used; the label indicates where the cable is or should be connected. **The AV convention labels by destination, not by an abstract cable number**: `VDA2 Out 3 to PROJ Input A` rather than `W042` alone. Power cabling supplied as part of the AV system is also labelled per the standard. Field practice adds: labels 1–3 in from the end, all facing the same direction inside the rack **[trade]**.

### 9.5 ANSI J-STD-710: symbols

The joint CEA/CEDIA/InfoComm residential-CI drawing symbols standard (2015), free from the CEDIA resource library, normatively referenced by AVIXA D401.01 **[std]**. Geometry at original drawing scale: distinctive shapes fit inside a 3/8-in (10 mm) circle; circle diameter 0.35 in (9 mm); square 0.25 in (6.35 mm); **all line weights 0.014 in (0.35 mm / 1 pt)**; attribute text minimum 3/32 in (2.5 mm). Four optional text attributes surround the symbol: `M` mounting type, `T`/`T2` primary and secondary technology, and `X`, the legend or schedule reference that links symbol to schedule row.

Two provisions RackPal uses directly. The standard sanctions **tag shape encoding run type** (circular for home runs, square for locally-run cables) provided the rule is documented in the legend and applied consistently across the whole set. And "Rack or Head End" is explicitly on the stretchable-symbol list, so drawing a rack at true proportion is conformant.

### 9.6 ANSI/AVIXA D401.01: the documentation set

The most directly applicable standard to this product: it defines the *minimum documentation set*, tiered by project complexity (Simple 11–15 points, Moderate 16–21, Complex 22+). Three of its nine Simple-project items are named RackPal outputs:

| D401.01 item | RackPal artifact |
|---|---|
| **System Interconnection Information**: "detailed information on how each component in the system is connected… part numbers, cable type, cable labels" | The Interconnect sheets (`T6.01…`) + the Pull Sheet + the Termination Schedule |
| **Equipment Mounting Information**: "the location and placement of equipment inside of any equipment rack… part numbers and detailed rack or location identification" | Front and rear rack elevations |
| **Bill of Materials** | Equipment List and Materials (`T6.30`): **no pricing** (AC-055) |

Moderate projects add Detailed Project Information, which is literally a specification for drawing-set front matter: cover page, drawing index, schedule of responsible parties, symbol key, abbreviations and general notes. Related AVIXA standards worth citing in-app: **F502.01** Rack Building and **F502.02** Rack Design, the latter names "entry/connection method for site cabling" as a required design input, which is the Structure device's justification in a standard.

### 9.7 The wiring schedule

**Ruling: one derivation, two presets** (AC-025). *Rejected alternative: a single "wiring schedule", which is organised for the person drawing it rather than the person holding the cable.*

| | **Pull Sheet** | **Termination Schedule** |
|---|---|---|
| Orientation | portrait | landscape |
| Default sort | **room, then pathway**: the order the tech walks the house | **rack, then panel, then port** |
| Rows | field cables only | all cables landing in the rack |
| Extra columns | footage subtotals per room, jacket colour (see below), `Pulled ☐ Terminated ☐ Tested ☐ Init ___` | T568A/B, punch position, polarity, conductor colour per role, pinout notes |

**Jacket colour is two facts, and the column prints both.** `Link.jacketColorId`
names the convention entry the run FOLLOWS, what it is, which is what the
keystone matches. `Link.jacketColorPulledId` is set only when the cable actually
in the wall is a different colour (they ran out of blue; a prewire mistake). Null
is the normal case. Both index the one named vocabulary in
`ProjectSettings.jacketColorConventions`, so one legend explains the whole sheet.

An exception therefore renders as **two tokens, never one**: `BLU→YEL`, or
`BLU · CONTROL — PULLED YEL` where the row has width for it. Never silently
yellow, never silently blue: *documentation of imperfections beats no
documentation at all*. The four states the column distinguishes are `—`
(nobody has said), `BLU` (normal), `BLU→YEL` (exception), and `—→YEL` (a jacket
observed at prewire on a run whose purpose nobody has recorded, kept, because
refusing it would discard an observed physical fact and promoting it to the
convention side would guess the run's purpose, G4).

The keystone column, when it exists, follows the CONVENTION alone and never the
pull. The keystone is chosen weeks later out of the same box as every other
control drop's and is routinely correct while the cable is not.
`derived/jacket_color_resolution.dart` is the single definition of all of this;
nothing stores a resolved answer (CR-107).

Both carry, **on both ends**: location (`RK-1 / U14 / rear`; `Great Room / TV wall / WP-1`) and **both labels**. `Conductor.colorCode` prints. A multi-service cable prints one row with a services sub-line, which is exactly what the trim tech needs and cannot get anywhere else:

```text
W044 | Cat5e | 62 ft | LR-TV | IR (pr 3, wht/brn) · 12VTRG (pr 4, brn) · RS232 (pr 1–2)
```

**`Link.class: fieldCable | jumper | powerCord | internal`**, auto-classified on creation and user-overridable; the schedule **excludes jumpers and power cords by default** (AC-026). 110 rows of factory patch cords in a 180-row schedule makes the 70 rows describing real pulls indistinguishable from noise, and nobody labels a patch cord with a `W` number. Jumpers roll up into the materials list by media, length and colour.

### 9.8 Rack elevation sheet anatomy

Front and rear elevations are drawn **separately, side by side on the same sheet**. The rear is the one installers actually use, because that is where the connectors are.

```text
┌─ RK-1 · Great Room ────────────────┐
│ 12 ┤ ┌──────────────────────────┐  │   Per device:
│ 11 ┤ │ MTX-1  8×8 HDMI Matrix   │  │     designator · name · model
│ 10 ┤ └──────────────────────────┘  │     RU span · lifecycle status
│  9 ┤ ┌──────────────────────────┐  │     weight · power draw
│  8 ┤ │ AMP-1  8-ch Amplifier    │  │
│  7 ┤ └──────────────────────────┘  │   Per rack:
│  6 ┤ ┌──────────────────────────┐  │     RU ruler, 1 at the bottom
│  5 ┤ │ SW-1   24-port PoE       │  │     designator matching the schedule
│  4 ┤ └──────────────────────────┘  │     H × W × D beneath the frame
│ …                                  │     running weight / power totals
└────────────────────────────────────┘
```

`ruIndex` is **1-based, bottom origin, always** (CR-025), the stored value equals the printed value under default numbering, which deletes an entire class of off-by-one between the elevation and the schedule. It is asserted at load. Numbering *direction* is `Rack.ruNumbering`, per-rack with a project default, because a retrofit rack may be labelled top-down by the previous integrator (CR-026). **Numbering is display-only and never affects `ruIndex`.** Likewise `Rack.mirrorRearElevation` is per-rack, default true, and a `NOT MIRRORED` chip appears in the rack header when it is off, a drawing must never lie about itself (CR-035).

`LifecycleStatus { existing, new, future, removed, designIntent }` is the status flag on the elevation; future gear reserves RU. It is a single field, not a layer system (CR-064; layers are v2).

### 9.9 Sheet numbering and the deliverable set

US National CAD Standard / Uniform Drawing System: `[Discipline][SheetType][Sequence]`, where **T = Telecommunications**, type **0** = general, **2** = elevations, **6** = schedules and diagrams **[std]**. **Ruling: `ProjectSettings.sheetNumbering: ncs | simple`, default `simple`**, because the NCS regex is overkill for a four-page residential set (CR-066, AC-034/m17).

The v1 sheet set, full detail in [PDF export](08-pdf-export.md) §2.2, which is the source this table restates. Canon §7.2.7's eight-item list is a summary, not a ceiling; `T0.00`, `T6.20` and `T5.01` are v1 (canon §4.3, CR-073, DR-005).

| Sheet | Content | Default |
|---|---|---|
| `T0.00` **Cover & Drawing Index** | Project identification and the index of every sheet in the set | ON |
| `T0.01` **Symbol Legend** | One row per named cable type, in colour and greyscale side by side | ON |
| `T0.02` **Exceptions & Acknowledgements** | Every open finding and every acknowledgement with reason, author, date | ON |
| `T2.01` **Rack Elevation: Front** | §9.8 | ON, one per `Rack` |
| `T2.02` **Rack Elevation: Rear** | §9.8. The rear panel *prints* in v1; the interactive Rear Panel view is v1.1 (CR-071) | ON, one per `Rack` |
| `T6.01…` **Interconnect** | One sheet per domain partition of the single schematic `Sheet` (CR-073). Signal flow, left to right, colour by domain. Devices repeat across sheets, identified by `designator`. Zero cross-sheet connections by construction | ON |
| `T6.10` **Pull Sheet** | §9.7 | ON |
| `T6.11` **Termination Schedule** | §9.7 | ON |
| `T6.20` **Unused Home Runs** | Every home run with an open end, at the rack or at the room, in room bands, saying which end (DR-220). This row read *"terminated at the DD with no device on it"*, a different sheet, until that ruling | AUTO (iff ≥ 1 exists) |
| `T6.30` **Equipment List and Materials** | Includes the cable footage rollup by media with waste factor. No pricing | ON |
| `T5.01` **Plate, Panel & Pinout Details** | Per-plate and per-panel detail where a connector's pinout is non-standard | AUTO (iff a non-standard pinout exists) |

Partition at export is not multi-sheet authoring; multi-sheet authoring is never built (DR-004). Exactly one schematic `Sheet` exists per project and the exporter filters it by domain to emit `T6.01…`.

The set is a **client deliverable and is drafted as one** (DR-005): drawing border, zone references, title block, revision block, revision clouds driven from `RevisionEntry`, the `ISSUED FOR CONSTRUCTION` stamp, and `simple`/`ncs` sheet numbering. Sheet furniture is orthogonal to wire idiom, the schematic's reader is technical (GC, electrician, low-voltage sub, technically-literate homeowner), so the sheet is polished fully and the wires stay net labels (DR-001).

J-STD-710 requires that any sheet omitting the legend carry a note stating where the legend is shown. **The exporter auto-fills `SYMBOL LEGEND: SEE SHEET T0.01`; it is not an invariant and it does not gate export** (CR-023). Likewise `ISSUED FOR CONSTRUCTION` is gated on zero open errors but **never gates bytes** (CR-022, G3). *Rejected alternative: `blockExportOnErrors`, deleted, not deferred; no setting, no equivalent.*

Full professional CI deliverable sets also contain floor plans, reflected ceiling plans, riser drawings, plate and panel details, network/IP schedules, power schedules, datasheets, performance verification reports and as-builts. Most are out of scope for v1; see [Roadmap](09-roadmap.md).

---

## 10. Deliberately not modelled

| Fact | Ruling |
|---|---|
| Cable dressing, service loops as geometry, lacing | Out of the brief: the plan ignores cable dressing, and it is right to (§7.6) |
| 3D, thermal simulation | Out of the brief (§7.6) |
| Floor plans (the **Plan view**) | **Not v1; v1.1, unconditionally.** DR-018 moved it out of §7.6's cable-dressing row, which had only ever argued cable dressing; DR-019 rules the container as plain JSON with no binary member and zip with one, so nothing migrates and roadmap §2.2's additive criterion is satisfied on its own terms (canon §11.17, §11.18, §12.11, §12.12). Design: [Plan view](15-plan-view.md) |
| Grounding and bonding beyond a drawable conductor | Minimum viable version only: an F-type ground block template, `power.bonding`, `Rack.groundBarPresent`. Full commercial bonding detail is v1.2 (RJ-010, AC-034/m21) |
| Bays (grouped adjacent racks) | Cut from v1, **not reserved**. Returns as `Bay{id, name, order, rackIds}`, a pure addition (CR-033) |
| RF cascade loss budget | Per-device insertion loss ships as data (a 2-way splitter ≈ 3.5 dB); the cascade rule is v1.2 |
| TIA-606 termination-class colour | Not modelled in v1; it is a second, independent colour dimension |
| Device images | Cut: a scope trap, ~1 MB per template, and an image-decode import surface (AC-057) |
| Pricing, suppliers, purchase orders | Cut from v1. `Money`, `cost`, `supplier`, `purchaseOrder` are deleted names (AC-055) |

---

## 11. References

### Standards

> **EVERY CITATION BELOW CARRIES A RETRIEVED-ON DATE, AND THE DATE IS THE POINT** (DR-079 §11.78.5).
> These standards are paywalled, so this corpus can state which revision it was written against and
> cannot state which revision is current. G4 handles unknown and has no mechanism for **stale**,
> which is the same gap DR-051 built the retrieved-on date for when it ruled that device
> documentation is referenced and never embedded: a link rots silently.
>
> **A REVISION NUMBER IS NEVER ASSERTED FROM MEMORY HERE.** A wrong revision in a normative document
> is worse than a dated one, because the dated one announces what it does not know. Where a later
> revision is known to exist it is named beside the one this corpus used, and where it is not, the
> date is the whole claim.
>
> **The architectural facts taken from these standards are revision-independent**: TIA-570-D's star /
> home-run topology and its Distribution Device, which the Structure device models, are not going to
> change in a revision, and the corpus's use of them was never a version claim.
>
> **TIA-607 (bonding and grounding) is cited NOWHERE in this corpus**, because bonding and grounding
> are not modelled at all. Recorded here so the absence reads as a scope boundary rather than an
> oversight.

- ANSI/EIA-310-D, Cabinets, Racks, Panels and Associated Equipment. IEC 60297-3-100 and DIN 41494 are the harmonised metric expressions.
- ANSI/TIA-606-C (2017), Administration Standard for Telecommunications Infrastructure. **606-D is known to exist and this corpus was written against 606-C.** *Retrieved 2026-08-19.* <https://www.tiafotc.org/tia-standards-update/tia-606-d/>
- ANSI/TIA-570-D (2018), Residential Telecommunications Infrastructure Standard. **A later revision may exist and has not been obtained**; the facts this corpus takes from it are architectural and revision-independent. *Retrieved 2026-08-19.* <https://www.tiafotc.org/tia-standards-update/tia-570-d/>
- ANSI J-STD-710 (2015), Audio, Video and Control Architectural Drawing Symbols Method. <https://webstore.ansi.org/preview-pages/ANSI/preview_ANSI+J-STD-710-2015.pdf>
- ANSI/AVIXA D401.01:2023, Documentation Requirements for Audiovisual Systems. <https://cdn.avixa.org/production/docs/default-source/default-document-library/d401.01_tech_review.pdf>
- ANSI/AVIXA F501.01:2015, Cable Labeling for Audiovisual Systems. <https://www.avixa.org/standards/cable-labeling-for-audiovisual-systems>
- ANSI/AVIXA F502.01:2018 Rack Building · F502.02:2020 Rack Design. <https://www.avixa.org/standards/rack-design-for-av-systems>
- NEC 210.19(A)(1) continuous load · NEC 725.136 Class 2/3 separation · NEC 800.154 plenum · NEC 300.22(C) wiring in plenums. **All four are cited informatively**: this product estimates and warns, and asserts compliance with none of them (DR-079).
- US National CAD Standard v5, Uniform Drawing System, sheet identification. <https://www.nationalcadstandard.org/ncs5/pdfs/ncs5_uds1.pdf>
- IEEE 802.3af / 802.3at / 802.3bt, Power over Ethernet. <https://ethernetalliance.org/wp-content/uploads/2018/04/WP_EA_Overview8023bt_FINAL.pdf>
- ASME Y14.44 / IEEE 315, reference designator prefixes.

### Rack geometry and hardware

- 19-inch rack, <https://en.wikipedia.org/wiki/19-inch_rack>
- EIA-310-D explained, <https://navepoint.com/blog/what-is-eia310d/> · <https://www.racksolutions.com/news/data-center-optimization/eia-310-definition/>
- Rack rail hole spacing, <https://www.audiorax.com/rack-rail-hole-spacing-explained>
- Global rack standards compared, <https://www.getek.com/understanding-global-rack-standards-ansi-eia-rs-310-d-iec-60297-2-and-din-41494-explained/>
- Half-rack has no standard, <https://cpcases.com/products/19-inch-racks/half-racks>
- Vertical vs horizontal PDUs, <https://www.enconnex.com/vertical-pdus-vs-horizontal-pdus/>

### Signals

- HDBaseT, <https://hdbaset.org/hdbaset-technology/> · <https://en.wikipedia.org/wiki/HDBaseT>
- Passive HDMI 2.1 length (<https://www.hdmiusbcable.com/what-is-the-maximum-length-for-a-passive-hdmi-2-1-cable/> · ARC/eARC and direction-locked cables) <https://ictally.com/resources/blog/active-vs-passive-hdmi-cables-arc-earc-explained>
- DisplayPort 2.1 active cable spec, <https://vesa.org/press/vesa-to-update-displayport-2-1-with-new-active-cable-specification-for-up-to-3x-longer-dp80-cables/>
- SDI length limits, <https://thomsonvisuals.com/blogs/thomsons-tech-tips/sdi-cable-length-limits-how-far-can-you-actually-run> · Belden transmission distance chart (PDF), <https://www.anixter.com/content/dam/Suppliers/Belden/Brochures/Recommended_Transmission_Distance_Chart.pdf>
- Constant-voltage distribution, Rane Note (PDF) <https://www.ranecommercial.com/legacy/pdf/ranenotes/Constant_Voltage_Audio_Distribution_Systems.pdf> · <https://help.harmanpro.com/guide-to-constant-voltage-systems>
- Dante vs AES67, <https://en.wikipedia.org/wiki/AES67> · <https://blog.avrelated.com/dante-vs-aes67-simplifying-audio-over-ip-technologies/>
- IR 3.5 mm pinouts, Xantech install instructions (PDF) <https://www.fullcompass.com/common/files/14981-Manual.pdf>
- RS-232 DTE/DCE, gender and null modems, <https://gridconnect.zendesk.com/hc/en-us/articles/115008733428-DB-9-Serial-Pinouts-DCE-DTE-Gender-and-Null-Modems-with-RS232>
- DMX512, <https://en.wikipedia.org/wiki/DMX512> · Cresnet wiring, <https://docs.crestron.com/en-us/9272/Content/Topics/Cresnet-Wiring.htm> · DALI topology, <https://www.knxhub.com/dali-wiring-installation-topology/> · Lutron system rules (PDF), <https://assets.lutron.com/a/documents/369821_lutron_residential_and_commerical_system_rules.pdf>
- PoE Type 3/4, <https://www.flukenetworks.com/blog/cabling-chronicles/type-3-and-type-4-are-here>
- IEC 60320 connector chart, <https://shop.worldcordsets.com/shop/reference-materials/iec-60320-reference-chart>
- Satellite SWM power-passing, <https://www.solidsignal.com/directv-installation-equipment-guide-swm-deca-and-mrv>

### Colour and legibility

- Okabe–Ito palette, <https://siegal.bio.nyu.edu/color-palette/> · <https://vizcept.com/blog/okabe-ito-palette-guide>
- Paul Tol's colour schemes, <https://personal.sron.nl/~pault/>

### Documentation practice

- TIA-606-C requirements, <https://www.cablinginstall.com/cable/article/14035166/tia-606-c-standard-requirements-for-cable-plant-administration> · 606-A identifier syntax, Anixter reference guide (PDF), <https://web.anixter.com/AXECOM/AXEDocLib.nsf/(UnID)/4D3AF1C46F90C8CE86256F8800792BF9/$file/ANSI-TIA-EIA-606-A.pdf>
- A fully resolved 606 implementation, CU Anschutz Div 27 05 53 (PDF) <https://www.cuanschutz.edu/docs/librariesprovider260/design-and-construction/guidelines-and-standards/division-27/270553---identification-for-communication-systems.pdf>
- AV signal flow diagram conventions, <https://kennyavsolution.com/av-signal-flow-diagrams-guide/>
- Construction document sheet numbers, <https://www.archtoolbox.com/construction-document-sheet-numbers/>
- Leviton Basic Residential Installer Guide (PDF), <https://leviton.com/content/dam/leviton/network-solutions/product_documents/brochure/Leviton-Basic-Residential-Installer-Guide.pdf>

### Internal

- `docs/canonical-decisions.md`, the normative decision record. Every `CR-nnn` / `AC-nnn` / `RJ-nnn` cited above resolves there.
- [docs/research/](research/), the raw working papers. Non-normative; superseded wherever they disagree with the record.
