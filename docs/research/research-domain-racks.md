I'll research this thoroughly. Let me load the web tools first.Let me dig into the primary sources and parallel topics.# Rack & Rack-Mount A/V Domain Facts, RackMate

Compiled from standards references and manufacturer data. Numbers marked **[verified]** appear consistently across ≥2 independent sources. Disagreements flagged inline with ⚠.

---

## 1. Core geometry: EIA-310-D / IEC 60297 / DIN 41494

These three are functionally the same standard, harmonized; IEC/DIN express it in mm, EIA in inches. IEC 60297-3-100 is the "basic panel dimensions" part.

| Quantity | Inches | Millimeters | Note |
|---|---|---|---|
| **1 rack unit (U/RU)** | 1.750 | **44.45** | Exact. Definitional. **[verified]** |
| Panel/faceplate width | **19.000** | **482.6** | The "19-inch" name comes from panel width, not rack width **[verified]** |
| Rail-to-rail hole centers (horizontal) | 18.312 (18 ⁵⁄₁₆) | **465.1** | ⚠ see §1.3 |
| Clear opening between rail faces | 17.75 | 450.85 | Minimum opening often quoted as 450 mm |
| Mounting post width (each) | 0.625 | 15.88 | |
| Threaded rail thickness (Middle Atlantic RRF) | 0.125 (1/8") | 3 | |

### 1.1 Panel height is NOT n × 1.75: critical for a layout tool

Equipment panels are **1/32 in (0.031 in / 0.79 mm) shorter** than their nominal U height, to give installation clearance between adjacent units.

**h = 1.750n − 0.031 inches = 44.45n − 0.79 mm** **[verified]**

| U | Nominal (in / mm) | Actual panel (in / mm) |
|---|---|---|
| 1U | 1.750 / 44.45 | **1.719 (1 ²³⁄₃₂) / 43.66** |
| 2U | 3.500 / 88.90 | 3.469 / 88.11 |
| 3U | 5.250 / 133.35 | 5.219 / 132.56 |
| 4U | 7.000 / 177.80 | 6.969 / 177.01 |

**Modeling implication:** store device height as an **integer U count**, and derive drawn height as `44.45n − 0.79` mm only for dimensioned/PDF output. Never store a float height. Real-world panels vary slightly below spec (a "3.50 in" 2U panel may measure 3.44 in), do not use measured height to infer U.

### 1.2 Vertical hole pattern: three holes per U

Center-to-center spacing repeats **0.500 / 0.625 / 0.625 in** (12.70 / 15.88 / 15.88 mm) = 1.750 in **[verified]**.

**Hole positions relative to the U boundary:** holes are centered at **0.25, 0.875, and 1.50 in (6.35, 22.23, 38.10 mm)** from the boundary of the U. The **U boundary falls at the midpoint of the 0.5-in gap**: i.e. in the middle of the narrowest metal web between two holes, *not* at a hole center. **[verified]**

This matters: a rack-position ruler drawn in RackMate should place the U division lines through the tight 0.5-in pair, and a 1U device's two ears land on the outer holes of its U (0.25 and 1.50), with the center hole (0.875) usually unused on 1U gear and used by 2U+ gear.

Note "universal" or "full-hole" rail = every EIA hole present. Some cheap rails omit holes; Middle Atlantic markets "full-hole rackrail" (RRF series) explicitly.

### 1.3 ⚠ Sources disagree: horizontal hole spacing

- Most vendor references and EIA-310 itself: **18.312 in (465.1 mm)** exact.
- Wikipedia gives a **range: 18.28–18.34 in (464.2–465.8 mm)** center-to-center.

Reconciliation: 465.1 mm is nominal; the range reflects manufacturing tolerance in the standard. **Use 465.1 mm nominal.** Not user-facing in RackMate, but relevant if you ever emit dimensioned drawings.

### 1.4 Mounting hole / fastener types

Three rail styles exist; a rack in RackMate should carry a `railType` enum because it constrains what hardware the integrator buys, not what fits geometrically:

1. **Tapped/threaded round holes**: screws thread directly into the rail.
   - **10-32**: the de-facto standard in pro A/V. Middle Atlantic RRF rackrail is "tapped for 10-32 threads." **[verified]**
   - **12-24**: older/telecom and some Middle Atlantic wall racks (e.g. CWR-12-17PD ships "with 12-24 threaded rack rail"). ⚠ Vendor mix; both are current.
   - Downside: threads strip with repeated equipment changes.
2. **Square holes + cage nuts**: dominant in IT/data-center racks. Cage nut = square nut in a spring-steel cage that snaps into the square hole. Replaceable; preferred where gear is swapped often.
3. **Unthreaded round clearance holes**: used with clip nuts.

Common screw sizes across all: **10-32, 12-24, M6**.

**Sources:** [Wikipedia 19-inch rack](https://en.wikipedia.org/wiki/19-inch_rack) · [NavePoint EIA-310-D](https://navepoint.com/blog/what-is-eia310d/) · [RackSolutions EIA-310](https://www.racksolutions.com/news/data-center-optimization/eia-310-definition/) · [AudioRax hole spacing](https://www.audiorax.com/rack-rail-hole-spacing-explained) · [Getek: EIA vs IEC 60297-2 vs DIN 41494](https://www.getek.com/understanding-global-rack-standards-ansi-eia-rs-310-d-iec-60297-2-and-din-41494-explained/) · [Middle Atlantic RRF16 spec sheet (PDF)](https://www.markertek.com/Attachments/Specifications/MiddleAtlantic/RRF16-Specifications.pdf)

---

## 2. Widths other than 19 inch

| Format | Panel width | Status |
|---|---|---|
| Standard | 19 in / 482.6 mm | EIA-310-D |
| **Half-rack** | 9.5 / 10 / 10.4 / 10.5 in | ⚠ **No standard exists.** See below |
| 10-inch rack | ~254 mm | Small networking/SOHO cabinets; same 44.45 mm U |
| 23-inch | 23 in / 584 mm | Telecom/broadcast |
| ETSI | 535 mm external | European telecom |

### ⚠ Half-rack is genuinely unstandardized: design for it

Sources are explicit: *"there is no standard for half-width rack mount equipment, and there is no official 9.5 inch standard width."* Manufacturers ship 9.5, 10, 10.4, and 10.5 in. One source cites ½-rack ear hole centers at 244 mm (9.60 in). Vertical U dimension is unchanged across all widths.

**Modeling implication:** do **not** model half-rack as "0.5 rack width." Model a device as `widthClass: full | half | third | custom_mm` plus an explicit `mountMethod`. In practice half-rack A/V gear (wireless mic receivers, small matrix switchers, media players) is **almost always shelf-mounted or mounted on a half-rack ear kit**, and two half-rack devices sharing 1U is a real, common arrangement RackMate must represent (see §7).

**Sources:** [CP Cases half racks](https://cpcases.com/products/19-inch-racks/half-racks) · [ProCase half-size racks](https://www.procaseshop.com/19-inch-rack/half-size-rack) · [Penn Elcom 9.5" half rack shelves](https://www.penn-elcom.com/us/9-5-half-rack-shelves-r1194-905-series)

---

## 3. Rack form factors in residential & commercial CI

### Typical RU counts by form factor

| Form factor | Typical RU | Typical depth | Notes |
|---|---|---|---|
| Small wall-mount box/hinged | 4–8U | 12–18 in | Closet/utility room |
| Wall-mount **swing gate** (open frame) | **12U or 20U** (Middle Atlantic SGR) | **12 or 18 in** | Front frame swings out 90° for rear access |
| Wall-mount **swing/pivot cabinet** | 6–18U (CWR 12U, EWR 10U) | 17–26 in | CWR-12-17PD: 12U, 17 in depth, 26 in width |
| Floor enclosure (A/V) | **18, 21, 27, 35, 40, 44U** (Middle Atlantic ERK) | 20 or 25 in | |
| Floor enclosure (deeper, gangable) | **24, 37, 40, 44U** (WRK) | usable **25.75 / 30.75 in**, 24.25 in wide | |
| Open-frame 4-post (MRK) | 24–44U | ~31.5 in | |
| Data-center standard | **42U** | 36 in (914 mm); also 800 mm / 1010 mm | 600 mm (24 in) wide external |
| Credenza / furniture rack | ~4–12U per bay | varies | Salamander 1–8 bay; rack rails + vent panels retrofit into furniture |

### Weight capacities (real numbers)

- Middle Atlantic **ERK floor enclosure: 2,500 lb** capacity.
- Middle Atlantic **SGR / 12RS swing gate wall rack: 100 lb** chassis capacity.
- Middle Atlantic **EWR pivoting wall cabinet (10U): up to 150 lb**. ⚠ One source describes it as "17-inch wide"; that is almost certainly a typo for 17-in *deep*, 19-in rail spacing is fixed. Treat with caution.

**Wall-mount weight capacity is the single most binding constraint in residential CI**: a 12U wall rack rated 100 lb will hit its limit long before it runs out of RU if it holds a UPS and an amp. RackMate should surface a `rackWeightCapacityLb` field and warn on exceedance.

### Swing-gate / swing-frame implication for the wiring planner

Swing racks rotate 90° on a hinge. Rear-panel cabling must have **service loop slack** to allow the swing. This is a real integrator concern but is explicitly *out of scope* per your requirement #4 (no cable dressing modeling). Consider it a per-rack boolean flag (`isSwingFrame`, `hingeSide: left|right`) that could later drive a warning, and that affects which side "rear access" comes from in a review view.

**Sources:** [Middle Atlantic SGR-20-18](https://www.customavrack.com/product/478-middle-atlantic-sgr-20-18-wall-mount-rack/) · [Middle Atlantic 12RS](https://www.milestek.com/p-15463-middle-atlantic-12rs-swing-gate-wallmount-blk-milestek-part-50-41006) · [CWR Data Swing Wall Rack](https://www.legrandav.com/products/racks/wall/cwr_data_swing_wall_rack) · [CWR-12-17PD at CDW](https://www.cdw.com/product/middle-atlantic-cwr-series-wall-rack-swing-out-wall-rack/2690626) · [ERK series](https://www.cableorganizer.com/products/middle-atlantic-erk-stand-alone-enclosures-without-rear-door) · [WRK series](https://bgs.cc/wrk-sa-series-rack-37-ru-27d/) · [Salamander Pro Cabinets](https://www.salamanderdesigns.com/commercial/cabinets/)

---

## 4. Non-device rack occupants: RU-consuming vs zero-U

This is the taxonomy RackMate's object model needs. **Occupancy is a property of the mount, not the object class.**

### Consumes front RU (occupies panel space)

| Occupant | Typical RU | Ports? | Notes |
|---|---|---|---|
| **Blank panel** | 1, 2, 3, 4U | none | Solid; blocks air bypass, aesthetics |
| **Vent panel** | 1, 2, 3, 4U (Middle Atlantic VT/VTF/VTB) | none | VT series ≈ **64% open area**; VTF = tight perforation pattern; VTB = light-blocking |
| **Fan panel** | 1–3U | **power inlet** | Active; draws power, adds to load and to noise budget |
| **Rack shelf** (fixed/vented) | 1U, 2U, 3U, 4U | none itself | Carries non-rackmount gear: see §7 |
| **Rack drawer** | 2–4U | none | Storage |
| **Patch panel** | 12-port→1U; 24-port→1U or 2U; 48-port→2U (1U in high-density) | **many, both sides** | ⚠ 24-port ships as both 1U and 2U depending on vendor |
| **Horizontal cable manager** | 1U or 2U | none | Finger duct / D-ring |
| **Rackmount PDU / power strip** | 1U or 2U, 6–16 outlets | **outlets = ports** | |
| **Power conditioner / sequencer** | 1–2U | outlets | Residential CI staple |
| **UPS** | 1U–4U (+ separate battery packs, often 2U each) | outlets + inlet | Heaviest single item, usually |
| **Rack lighting / monitor / drawer KVM** | 1U | | |

### Zero-U / zero-RU (consumes no panel space)

| Occupant | Mount |
|---|---|
| **Vertical (0U) PDU** | Rear vertical channel of the cabinet; **up to 24–60 outlets**, far more than a 1U horizontal PDU's 6–16 |
| **Vertical cable manager / lacer strip** | Middle Atlantic LACE-xx-OP perforated steel strips mount vertically to rackrail brackets |
| **Side-mount / rear-rail brackets, cable trays** | Rear or side |
| **Rack-side power supply / wall-wart shelf** | Rear rail |

### ⚠ Lacing bars: genuinely ambiguous, model it explicitly

Middle Atlantic **LBP-series L-shaped lace bars (LBP-1A / -2A / -4A / -6A, with 1 / 2 / 4 / 6 in offsets)** bolt into **rack rail holes at the rear**. They consume **rear rail holes** but **no front panel space**. Vertical **LACE** perforated strips are truly zero-U.

**Modeling recommendation:** give every rack occupant an occupancy descriptor rather than a single `heightU`:

```
occupancy: {
  frontU: int,        // 0 for zero-U and rear-only items
  rearU: int,         // rear rail holes consumed
  side: front | rear | both | zeroU_vertical,
  depthMm: number,
  weightKg: number
}
```

A 1U blank = `{frontU:1, rearU:0}`. A rear LBP lace bar = `{frontU:0, rearU:1}`. A 0U PDU = `{frontU:0, rearU:0, side:zeroU_vertical}`. A 2U patch panel = `{frontU:2, rearU:2}`. This single change is what lets RackMate correctly answer "how many U do I have left?", which is *different for front and rear*.

**Sources:** [Middle Atlantic VT1 vent panel](https://www.rackmountsolutions.net/middle-atlantic-vt1-1u-steel-rack-vent-panel/) · [VTB-2 (64% open)](https://www.performanceaudio.com/products/middle-atlantic-vtb-2-light-blocking-rack-vent-panel-2u) · [VTF1 tight-pattern](https://www.bhphotovideo.com/c/product/418871-REG/Middle_Atlantic_VTF1_VTF1_1U_Tight_Pattern_Vented.html) · [LBP lace bars at CDW](https://www.cdw.com/product/middle-atlantic-lbp-horizontal-rack-cable-management-lace-bar-l-shaped/794426) · [LACE-23-OP strips](https://matrixsolutionsinc.com/middle-atlantic-products-lace-23-op-rack-accessory-cable-lacing-bar) · [Vertical vs horizontal PDUs (Enconnex)](https://www.enconnex.com/vertical-pdus-vs-horizontal-pdus/) · [Eaton/Tripp Lite PDU buying guide](https://tripplite.eaton.com/products/pdu-buying-guide) · [Tripp Lite 24-port 1U keystone panel](https://tripplite.eaton.com/24-port-1u-rack-mount-unshielded-blank-keystone-multimedia-patch-panel-rj45-ethernet-usb-hdmi-cat5e-cat6~N062024KJSH) vs [24-port 2U](https://tripplite.eaton.com/24-port-2u-rack-mount-unshielded-blank-keystone-multimedia-patch-panel~N062024KJ)

---

## 5. Planning concerns integrators actually track

These are the fields that make RackMate a *tool* rather than a drawing program. Each should be a per-device attribute with a per-rack rollup.

### 5.1 Weight & weight distribution
- Per-device `weightLb/kg`; rack rollup vs `rackCapacity`.
- **Heaviest items at the bottom**: UPS, battery packs, amplifiers. Documented failure mode: a UPS installed at the top of a 42U rack caused the rack to lean forward within days; relocating it to the bottom resolved it.
- Avoid heavy gear on slide rails (cantilever stress).
- Anchor to floor/wall in seismic zones.
- **Useful RackMate feature:** center-of-gravity height indicator + "top-heavy" warning, and a wall-rack "over capacity" hard warning (100 lb limits are easy to blow past).

### 5.2 Power
- Per-device: `watts`, `amps`, `voltage`, `isContinuousLoad`, `plugType`, `outletsProvided`, `outletsConsumed`.
- **NEC continuous-load rule (210.19(A)(1)):** a load running **3 hours or more** is continuous; OCPD must be rated ≥ **125%** of the continuous load, equivalently, **limit continuous load to 80% of circuit rating**.
  - **15 A circuit → 12 A max continuous**
  - **20 A circuit → 16 A max continuous**
- Exception: assemblies listed for 100% operation (rare in CI).
- **RackMate feature:** model **circuits** as a first-class object; assign PDUs/devices to circuits; show per-circuit amps against 12 A / 16 A thresholds. Also track outlet count balance (outlets provided by PDUs vs consumed by devices), running out of outlets is as common as running out of RU.
- Nameplate vs actual: equipment typically draws **30–70% of rated** power. Offer both `nameplateWatts` and `typicalWatts`; do heat math on typical, breaker math on nameplate.

### 5.3 Heat load & ventilation
- **BTU/hr = watts × 3.412** (precisely 3.41214; derived as 3600 s/h ÷ 1055 J/BTU). **[verified]**
- Sanity anchors: 7 kW rack ≈ **24,000 BTU/hr**; 15 kW ≈ **51,000 BTU/hr**. Residential A/V racks are typically **300 W – 2 kW** (≈ 1,000–6,800 BTU/hr).
- Rule of thumb: every watt consumed in the room becomes a watt of heat in the room.
- Cooling regime by density: passive/room-level up to ~10 kW/rack, in-row to ~20 kW, liquid beyond. CI racks are nowhere near this, but a sealed credenza absolutely is thermally limited, hence Salamander's passive louvers + optional active cooling.

### 5.4 Airspace / adjacency rules
Trade guidance (blog-level consensus, not a standard, ⚠ flag as heuristic, not spec):
- Put a **1U spacer/vent panel between amplifiers** and other high-heat gear.
- Don't stack amps, PoE switches, and UPS units adjacent.
- Put **heat-sensitive gear low** (cool intake air); heat rises.
- Place **vent/fan panels above heat sources** to assist natural convection.
- Budget **1U–2U between heat generators** and **1U–2U for cable managers**.
- **Reserve 15–25% spare RU** before finalizing a design.

**RackMate feature:** per-device `requiresClearanceAboveU` / `requiresClearanceBelowU` integers, validated as an occupancy conflict. This is a genuinely differentiating feature, most rack tools don't model it.

### 5.5 Depth clearance
- Track `deviceDepthMm` and `rackUsableDepthMm`. A 20-in-deep device does not fit a 15-in-deep rack.
- **Add 2–4 in (50–100 mm) behind the deepest device** for connectors and cable bend radius. HDMI and stiff coax are the worst offenders.
- Typical depth targets: **18–22 in for residential AVRs**, **24–30 in for commercial gear**. ⚠ Trade-guidance figures, not standardized.
- Note **usable** vs **overall** depth differs (WRK: 25.75 / 30.75 in *usable*).
- Rear-door clearance and door-mounted items eat depth too.

**Sources:** [Server rack weight distribution & safety](https://telecare.com.bd/server-rack-weight-explained-capacity-distribution-safety-guide/) · [NEC 210.19(A)(1)](https://www.electricallicenserenewal.com/Electrical-Continuing-Education-Courses/NEC-Content.php?sectionID=818) · [80% rule explained](https://ecalpro.com/blog/nec-80-percent-rule-explained) · [Schneider: 80% vs 100% rated breakers](https://blog.se.com/datacenter/2014/06/12/clearing-confusion-80-vs-100-rated-circuit-breakers/) · [Server rack heat load / BTU](https://calcengineer.com/hvac/server-rack-heat-load/) · [Intel BTU/hr calculation](https://www.intel.com/content/www/us/en/support/articles/000006784/server-products.html) · [AV rack design best practices](https://xtenav.com/8-best-practices-for-av-rack-design/) · [AV rack units guide](https://xtenav.com/av-rack-units/) · [Audio Advice AV rack practices](https://www.audioadvice.com/blogs/expert-advice/diy-home-theater-av-rack-best-practices)

---

## 6. Front vs rear panel reality: port SIDE is mandatory

**The overwhelming majority of rack A/V I/O is on the rear.** But front-panel I/O is common enough that a side-agnostic model will produce wrong diagrams:

**Rear (default):** HDMI in/out, HDBaseT, analog RCA/XLR, speaker terminals (binding posts / Euroblock / Phoenix), RJ45 network, RS-232 (DE-9 or 3.5 mm / Phoenix), IR emitter & IR input jacks (3.5 mm mono), coax/RG6 F-connectors, S/PDIF coax, TOSLINK optical, IEC C13/C14 power inlets, 12 V trigger (3.5 mm), USB service ports.

**Front (real cases):** front USB (media playback, service/firmware), headphone jack (AVR/preamp), front-panel HDMI input (AVR "front input", camcorder/game input), front SD card slot, front mic input, front-panel controls and displays, front IR receiver window, front reset/setup buttons, front-accessible patch panel ports.

**Both sides:** patch panels are the canonical case, punch-down/trunk termination on the **rear**, RJ-45 patch jacks on the **front**. Some installations deliberately run one panel at the front and one at the rear to shorten patch leads and ease tracing. Feed-through/keystone panels are literally front-and-rear paired ports.

**Modeling requirements:**
- Every port carries `side: front | rear` (and, for a rack, front/rear elevation views).
- Patch panels need **paired ports**: a front port and rear port that are electrically the same net. This is a distinct topology from a normal device and worth a `passthrough: true` flag with a front↔rear port mapping, so the netlist collapses correctly rather than showing a spurious two-hop connection.
- The wiring diagram should default to the **rear elevation** since that's where nearly all connections live, with a front elevation for the physical layout / customer-facing view.
- IR is directional and asymmetric (emitter out vs receiver in), model port `direction: in | out | bidirectional`, which you need anyway for the netlist and for validating "output→input" connections.

**Sources:** [Guide to patch panels](https://hwp24.com/articles/guide_to_patch_panels/) · [Front-to-back patch panels](https://myworldofit.net/?p=9069) · [Patch panel vs keystone jack](https://rackit.com/blogs/news/patch-panel-vs-keystone-jack-when-to-use-each-in-mdfs-and-idfs)

---

## 7. Non-rack-mountable devices: shelves and shared U

A large fraction of residential CI gear has **no rack ears at all**: streaming boxes (Apple TV, Roku), cable/satellite STBs, small network appliances, control processors, wireless mic receivers, Blu-ray players, small amps, power supplies/wall warts. These get **shelf-mounted**.

### Real shelf specs (Middle Atlantic)

| Model | RU | Usable depth | Weight capacity | Notes |
|---|---|---|---|---|
| **UTR1** | 1U | **10 in** | **25 lb** | 16-ga steel; designed for **½- and ⅓-rack gear** and small components; hook-and-loop strips; vent pattern |
| **U1V** | 1U | **10.4 in** | **35 lb** | Vented bottom + sides; 3 adjustable rear brackets stop rearward slide |
| **U2** | 2U | **14.43 in** | **50 lb** | Solid |
| **U2V** | 2U | **14.75 in** | **50 lb** | Vented bottom + sides; 3 rear brackets |

### Multiple devices sharing one shelf: the model

This is a **container relationship**, and it is the right abstraction:

```
Shelf (occupies N U, has depth + weight capacity)
  └── hosts[] : Device (each with own weight, depth, ports, but NO independent U position)
```

Rules RackMate should encode:
- A shelf consumes its own RU; **hosted devices consume zero additional RU**.
- **Sum of hosted device weights ≤ shelf weight capacity** (25/35/50 lb are low, two STBs and a wall wart get there fast).
- **Each hosted device's depth ≤ shelf usable depth** (10 in shelves are shallow; many STBs exceed it).
- Hosted devices should have an optional **lateral position** on the shelf (left/center/right, or an x-offset) so the front elevation renders honestly, two half-rack units side by side on a 1U shelf is the single most common arrangement.
- Hosted devices' **ports still participate fully in the netlist and wiring schedule**, and still carry front/rear side.
- Some devices are **shelf-only** (`mountMethod: shelf`), some are **ear-mount** (`rackEars`), some are **either** (many half-rack units ship with optional rack-ear kits, model as a device property with a default).

**Recommended `mountMethod` enum:** `rackEars | shelf | zeroU | sideMount | rearRail | furniture | hosted`.

**Sources:** [Middle Atlantic UTR1](https://www.rackmountsolutions.net/middle-atlantic-utr1-1u-half-rack-shelf/) · [UTR1 at Sweetwater](https://www.sweetwater.com/store/detail/UTR1--middle-atlantic-products-utr1-1u-utility-rack-shelf) · [U1V](https://www.bhphotovideo.com/c/product/970623-REG/middle_atlantic_u1v_universal_vented_rack.html) · [U2V](https://www.proacousticsusa.com/middle-atlantic-u2v-2u-14-75-deep-vented-rackshelf.html) · [U series datasheet (PDF)](https://datasheet.octopart.com/U2-Middle-Atlantic-Products-datasheet-23708084.pdf)

---

## 8. The "Structure" device: structured wiring entering the rack

Your requirement #6. Real-world grounding for what this pseudo-device represents:

- Residential low-voltage home runs terminate in a **structured media enclosure** (Leviton "Structured Media Center", Legrand/On-Q "structured wiring enclosure") or directly at the rack's patch panels.
- Standard enclosure sizes: **14", 21", 28", 42"** (metal); wireless/ABS variants at 14"×13.7", 28"×13.7", 42"×13.7". Recessed between studs on **16-in centers**, or surface mounted.
- These terminate **home-run wires from wall outlets** and act as the distribution point for **voice, data, and video**, plus, in modern CI, speaker runs, HDMI/HDBaseT runs, IR, RS-232, coax, and camera/PoE runs.
- In commercial CI the analogue is the **MDF/IDF** and the building's horizontal cabling.

**Modeling recommendation:** the Structure device should be a **first-class device with a variable, user-defined port list**, because it *is* just "the building," and every project's building is different. It should support:
- Ports grouped by **destination/room label** (e.g. "Living Room (TV wall", "Bedroom 2) ceiling speaker L"), since the integrator thinks in rooms, not port numbers.
- The same connector-type taxonomy as real devices (RG6, Cat6, 14/2 speaker, IR, fiber).
- A **reference designator** distinct from rack devices (schematic convention: treat it like an off-page connector / edge connector on a board diagram, this maps beautifully onto your requirement #5's electronics-schematic inspiration).
- **Zero RU, zero weight, no rack position**: it lives outside the rack outline in the diagram, typically as a bus/edge terminal at the drawing boundary.
- Possibly **multiple Structure instances** (e.g. "Rough-in (first floor", "Rough-in) exterior/cameras", "Utility feed"), which is more useful than one giant node.

**Sources:** [Leviton metal structured media enclosures](https://leviton.com/products/residential/networking/structured-media-centers/metal-enclosures) · [Leviton 28"/42" spec sheet (PDF)](https://leviton.com/content/dam/leviton/network-solutions/product_documents/product_specification/Leviton-Spec-47605-28x-47605-42x-Metal-Structured-Media-Enclosures.pdf) · [Legrand structured wiring enclosures](https://www.legrand.us/audio-visual/structured-wiring-enclosures/c/lgnd011400)

---

## 9. Summary of source disagreements (⚠)

| Item | Disagreement | Recommendation |
|---|---|---|
| Rail hole horizontal spacing | 18.312 in (465.1 mm) exact vs 18.28–18.34 in range | Use 465.1 mm nominal; range is tolerance |
| Half-rack width | 9.5 / 10 / 10.4 / 10.5 in; sources explicitly state **no standard exists** | Do not hard-code; use `widthClass` + optional custom mm |
| 24-port patch panel height | Ships as both **1U** and **2U** (Eaton/Tripp Lite sells both) | Height must be a per-template field, never derived from port count |
| 48-port patch panel | Normally 2U; high-density 1U exists | Same |
| Rack rail thread | 10-32 (Middle Atlantic RRF, pro A/V default) vs 12-24 (CWR wall racks, older IT) vs square/cage nut | Per-rack enum; don't assume |
| Lacing bar occupancy | LBP L-bars consume rear rail holes; LACE vertical strips are true zero-U; vendors market both as "space-saving" | Model front/rear U separately (§4) |
| Rack depth figures | "Usable" vs "overall" used inconsistently by vendors | Store `usableDepth` explicitly; label it in UI |
| AVR / commercial depth guidance (18–22 in / 24–30 in) | Trade blogs, not a standard | Present as defaults/hints, not validation rules |
| Airspace heuristics (1U between amps, 15–25% spare) | Trade consensus, no standard | Offer as warnings the user can dismiss |
| Middle Atlantic EWR "17 in wide" | Almost certainly a transcription error for 17 in **deep** | Verify against Legrand AV datasheet before seeding catalog |

---

## 10. Condensed data-model takeaways for RackMate

1. **Height is an integer U count.** Render at `44.45n − 0.79` mm. Never store floats.
2. **Occupancy is a struct, not a scalar:** `{frontU, rearU, side, depthMm, weightKg}`. Front and rear capacity are independent.
3. **Ports carry `side` (front/rear) and `direction` (in/out/bidir).** Rear is the default; the wiring view should default to the rear elevation.
4. **Patch panels are pass-through devices** with paired front/rear ports sharing one net.
5. **Shelves are containers.** Hosted devices have zero own-RU, a lateral position, and are validated against shelf weight + depth.
6. **Zero-U is a real mount class**, not a height of 0, vertical PDUs and lacer strips need rear-channel placement, not rail placement.
7. **Circuits are first-class.** Devices → PDU outlets → circuits, validated at 12 A (15 A ckt) / 16 A (20 A ckt) continuous.
8. **Rollups per rack:** total weight vs capacity, CG height, total watts, total BTU/hr (watts × 3.412), outlets used/available, front RU used/free, rear RU used/free, deepest device vs usable depth.
9. **Clearance rules** (`requiresClearanceAboveU`/`BelowU`) are a differentiating validation few tools implement.
10. **Structure device** = zero-RU, off-rack, room-labeled, variable port list, multiple instances allowed; render as a schematic edge/off-page connector.