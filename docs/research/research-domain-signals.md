I'll research this systematically. Let me load the web tools first.Good baseline. Now the control, distributed audio, and audio-over-IP families.Now control buses, coax/RF distribution, power, and documentation conventions.A few more gaps: RS-232 details, RF distribution, DALI/KNX/Lutron, and larger accessible palettes.# A/V + Low-Voltage Signal & Cable Taxonomy for RackMate

Research report for the wiring-plan data model. Verified specifics are cited; source list at the end.

---

## 0. The Two Findings That Should Drive the Data Model

Before the taxonomy, two structural conclusions that emerged from the research and that will cost a rewrite if missed:

### 0.1 Physical links and logical signals are different layers

A single physical cable can carry multiple logical signals **in opposite directions simultaneously**, and a single logical signal can traverse multiple physical cables.

- **HDMI eARC**: one cable, video flows source→display, audio flows display→source (AVR). One physical link, two logical signals, opposite directions.
- **HDBaseT 5Play**: one Cat6a cable carrying video + audio + 100 Mbps Ethernet + IR + RS-232 + 100 W DC power.
- **Dante / AES67 / AVB / NDI / SDVoE**: an audio or video connection between two devices that has *no dedicated cable at all*, it rides the network. Physically, each endpoint has one Cat6 run to a switch. Logically, there are N audio channels between endpoint A and endpoint B.

**Model implication:** `PhysicalLink` (port ↔ port, has media/length/designator) and `LogicalSignal` (endpoint ↔ endpoint, has direction/channel count/type) must be separate entities, with logical signals *bound to* a physical path (possibly multi-hop through a switch or matrix). The diagram renderer then offers two views: physical (what an installer pulls and terminates) and logical (what the system does). A schedule/PDF needs both.

### 0.2 RJ45 is a connector, not a signal

This is the single highest-value validation in the whole tool. An RJ45 jack may be:

| RJ45 carries | Legal to patch into a switch? |
|---|---|
| Ethernet / IP | Yes |
| HDBaseT | **No: will not work; PoH may damage gear** |
| Dante / AES67 (is Ethernet) | Yes, with VLAN/QoS caveats |
| DMX-over-Cat / RS-485 on Cat | No |
| Analog audio on Cat (balun) | No |
| Cresnet-over-Cat | No |
| Proprietary control link (Lutron, Control4) | No |

HDBaseT explicitly uses *"conductors, cable, and connectors as used in Ethernet networks, but not otherwise exchangeable."* The `Port` type therefore needs `connector` and `signalFamily` as **independent orthogonal fields**, never a single enum, plus a `carriedProtocols` list.

---

## 1. Master Family Table

Direction key: **→** unidirectional source→sink · **↔** bidirectional · **BUS** multi-drop shared medium · **MD** multi-drop via passive splitters
Topology: **P2P** point-to-point · **MD** multi-drop · **STAR** switched/hub

| # | Family | Connector(s) | Media | Dir | Topology | Typical max run | Key gotcha for a wiring plan |
|---|---|---|---|---|---|---|---|
| **VIDEO / AV DIGITAL** |
| 1 | HDMI 2.0 (18 Gbps) | HDMI-A (also C/D) | 19-cond. bonded; AOC | → + ARC ↔ | P2P | Passive ~7.5 m @18G; active copper ~7.6 m; AOC 15–90 m | HDCP handshake, EDID; AOC is **direction-locked** (Source/Display marked ends) |
| 2 | HDMI 2.1 (48 Gbps) | HDMI-A | Ultra High Speed / AOC | → + eARC ↔ | P2P | Passive **3–4.5 m** (3 m often cited as theoretical limit); active copper ~7.6 m; AOC 15–90 m+ | Passive length collapses vs 2.0: a 25 ft "HDMI" run that worked at 4K60 will fail at 4K120. eARC audio is a *return* on the same cable |
| 3 | DisplayPort 1.4 / 2.1 | DP, mini-DP | DP cable | → (+AUX ↔) | P2P (MST daisy-chain) | DP40/DP54 passive **2 m**; DP80 passive **1.2 m**; DP80LL active 3 m | Brutally short. Rare in rack CI except source PCs. MST daisy-chain is a real topology |
| 4 | SDI (HD/3G/6G/12G) | BNC 75 Ω | RG6/RG59-class coax (Belden 1694A, 4855R) | → | P2P (+ loop-through) | 3G ~100 m; 6G ~80 m; 12G **~45–50 m** | Impedance is 75 Ω: 50 Ω BNC looks identical and fails. 12G needs purpose-built coax |
| 5 | HDBaseT (5Play) | RJ45 | Cat5e/6/6a **solid, shielded preferred** | → video, ↔ ctrl/eth | P2P | 4K to **100 m on Cat6a**; 1080p 100 m on Cat5e | **NOT Ethernet.** Carries up to 100 W PoH (based on 802.3at, modified, 4-pair). Never patch to a switch |
| 6 | USB-C / DP-Alt | USB-C | USB-C w/ marked bandwidth | → video, ↔ data, ↔ power | P2P | ~1–2 m passive for full BW | Cable capability is invisible; PD wattage negotiation matters for BYOD/huddle |
| 7 | AV-over-IP (SDVoE, JPEG XS, NDI, H.264) | RJ45 / SFP+ | Cat6a or fiber | logical → over ↔ | STAR | Per network | Bandwidth class matters: 1 G compressed vs **10 G SDVoE**. Needs IGMP snooping + querier, jumbo frames. Draw as logical, not point-to-point |
| **ANALOG VIDEO / RF** |
| 8 | Composite | RCA (yellow) | RG59 75 Ω | → | P2P | ~100 m RG59 | Legacy; identical connector to analog audio and S/PDIF, label discipline required |
| 9 | Component YPbPr | 3× RCA or 3× BNC | 3× 75 Ω coax | → | P2P | ~30 m practical | **3 ports = 1 logical connection.** Needs a port-group concept |
| 10 | VGA / RGBHV | HD15, or 5× BNC | Coax bundle | → (+DDC ↔) | P2P | ~15 m before softening | 5-BNC breakout = 5-port group |
| 11 | S-Video | mini-DIN 4 | Y/C shielded | → | P2P | ~15 m | Rare, still in legacy retrofits |
| 12 | RF / CATV distribution | F-type | **RG6** (RG59 legacy) | → downstream, ↔ if DOCSIS | **MD** via splitters/taps | RG6 ~150 m; RG59 ~100 m | Splitters impose loss (2-way ≈ 3.5 dB); **loss budget is the design**. Directional taps for trunk runs. Amplifiers are directional and can block return path |
| 13 | Satellite / SWM | F-type | RG6 (swept to 3 GHz) | ↔ (receiver requests) | MD, **power-passing** | Per multiswitch spec | **Exactly one splitter port passes DC (marked red)** back to the LNB/multiswitch. Wire a normal splitter and the dish never powers. SWM has a hard tuner-count budget (SWM8 = 8, SWM16 = 16) |
| 14 | OTA antenna | F-type | RG6 | → | MD | RG6 ~150 m | Often diplexed with satellite; needs preamp power injection |
| **ANALOG AUDIO** |
| 15 | Line, unbalanced | RCA, 3.5 mm TRS | Shielded pair | → | P2P | **~6 m** before hum/loss | Ground loops. Nominal −10 dBV |
| 16 | Line, balanced | XLR3 (M/F), TRS 1/4" | Shielded twisted pair | → | P2P | 100 m+ | **Gender is load-bearing**: XLR male = output, female = input, by convention. +4 dBu |
| 17 | Phono / turntable | RCA + separate ground lug | Low-capacitance shielded | → | P2P | ~1.5 m | Needs RIAA preamp; **separate ground wire is a real conductor to schedule** |
| 18 | Mic level | XLR3-F on device | STP, may carry 48 V phantom | → | P2P | 100 m+ | Phantom power flag on the port |
| 19 | Speaker level, low-Z | Binding post, banana, Phoenix/Euroblock, SpeakON | 16/2–12/2, 16/4 | → | P2P (or parallel) | Gauge/length table; 14 AWG ~15 m for 8 Ω | **Polarity (+/−) is a schedulable attribute.** Parallel speakers change amp load impedance, needs validation. 4-conductor for single-run bi-amp or for a stereo pair to one location |
| 20 | Speaker, constant-voltage 70 V / 100 V / 25 V | Euroblock, screw terminal | 16/2 or 18/2 | → | **MD (multi-tap bus)** | Hundreds of feet with negligible loss | Each speaker has a **transformer tap** (typ. 2.5 / 5 / 10 / 15 / 20 W). Sum of taps must be ≤ amp rating (design ~20 % headroom). Tap value is a per-connection property, not a per-device one |
| 21 | Subwoofer / LFE | RCA, XLR | Shielded coax | → | P2P (or Y-split) | ~10 m | Often Y-split to two subs: one output, two sinks |
| 22 | Headphone | 1/4" TRS, 3.5 mm |: | → | P2P | short | Rarely in rack plans; include for completeness |
| **DIGITAL AUDIO** |
| 23 | S/PDIF coax | RCA **75 Ω** | 75 Ω coax (RG59) | → | P2P | ~10 m | Physically identical to analog RCA; **impedance differs**. Wiring a plain analog interconnect causes intermittent dropouts |
| 24 | TOSLINK / optical S/PDIF | JIS F05 (EIAJ) | POF or glass | → | P2P | POF ~5–10 m; glass 30 m+ | Bend radius; cannot carry lossless multichannel (no DTS-HD MA/TrueHD), a real design constraint |
| 25 | AES/EBU (AES3) | XLR3 **110 Ω**, or BNC 75 Ω (AES3id) | 110 Ω STP | → | P2P | 100 m | 110 Ω cable, *not* mic cable, despite identical XLR. Carries 2 channels per link |
| 26 | Dante / AES67 / AVB | RJ45, SFP | Cat5e+/fiber | ↔ logical, → per flow | **STAR** | Per network | Rides the LAN. Dante uses **PTPv1**; AES67 uses **PTPv2 (IEEE 1588-2008)**. Dante latency down to 150 µs; AES67 fixed 2–3 ms. Needs QoS/DSCP and ideally a dedicated VLAN. AVB additionally requires **AVB/TSN-capable switches**: not just any managed switch |
| **CONTROL** |
| 27 | IR emitter (flasher) | 3.5 mm mono **or** stereo; bare-wire | 2-cond. | → | P2P from a port; blocks are MD | ~15 m | **Pinout variance is a genuine field hazard.** Xantech/Niles receivers: Tip = signal, Ring = GND, Sleeve = +12 V. Emitters: Tip = IR in, Sleeve = GND. Plugging an emitter into a *receiver* jack destroys the emitter and can damage the PSU. Model must carry a `pinoutVariant` |
| 28 | IR receiver | 3.5 mm stereo | 3-cond. (signal/GND/+12 V) | → to block | Multiple receivers → connecting block | ~60 m | Receivers are powered; emitters are not |
| 29 | RS-232 | DB9 (also 3.5 mm TRS, Phoenix, RJ45-serial) | Shielded multi-cond. | ↔ | **P2P only** | ~15 m @19.2 kbps; ~15 m @9600 typical | **Straight vs null-modem is determined by DTE/DCE role of both ends.** DTE↔DTE needs crossover (2↔3, 4↔6, 7↔8, 5→5). Gender + role + baud/parity/stop must all be on the port |
| 30 | RS-485 | Phoenix/Euroblock, DB9, RJ45 | 120 Ω twisted pair | ↔ half-duplex (or 4-wire full) | **BUS** | 1200 m | **32 unit loads** classic limit; termination 120 Ω at *both* ends only; daisy-chain, no stars |
| 31 | DMX512-A | **XLR5** (XLR3 non-compliant but common) | 120 Ω DMX cable (or 100 Ω Cat) | → unidirectional over RS-485 | **BUS** | 1200 m | Max **32 unit loads** per universe; 512 channels/universe; terminator plug (120 Ω) at far end; universe number is an attribute |
| 32 | Contact closure / relay / GPIO | Phoenix, screw, 3.5 mm | 2-cond. 18–22 AWG | → (or sense ←) | P2P | long | NO vs NC; dry vs wet; current/voltage rating; a *sense* input vs a *drive* output are opposite directions |
| 33 | 12 V trigger | **3.5 mm mono** (tip = +12 V, sleeve = 0 V) | 2-cond. | → | P2P (sometimes daisy) | moderate | **Current budget: typically 100 mA max per output.** Cascading multiple amp triggers off one AVR output exceeds it. Must be a mono cable, a stereo plug shorts ring to sleeve |
| 34 | Cresnet | 4-pin Phoenix | 18 AWG red/blk power pair + 22 AWG blu/wht data pair | ↔ | **BUS** (daisy or home-run) | ~3000 ft / 915 m per run, **but power-limited**: 18 AWG @20 W ⇒ **333 ft** | Two independent limits: data length *and* 24 V power budget. HP Cresnet uses 12 AWG for longer runs. Needs a load-sum validator |
| 35 | Lutron QS / HomeWorks link | RJ45 or terminal | Lutron-spec cable | ↔ | **BUS**, topology-free | **2000 ft / 610 m** using 12 AWG | Topology-free (daisy, T-tap, star all legal), a rare exception to bus rules. Device-count limits per link |
| 36 | DALI / DALI-2 | 2-wire, any terminal | 2-cond., mains-rated, **polarity-free** | ↔ | **BUS**, topology-free | **~300 m** per line (cross-section dependent) | **64 devices max per line**; polarity-free (no wiring error possible); star/tree/line/mixed all legal. Beyond 64, gateway to another line |
| 37 | KNX | KNX bus terminal (red/black) | KNX TP1 bus cable | ↔ | **BUS** (line/tree, no ring) | 1000 m per line; 700 m PSU→device | Line/area topology with couplers; 64 devices/line segment |
| **NETWORK** |
| 38 | Ethernet copper | RJ45 (jack = J, plug = P) | Cat5e / Cat6 / Cat6a UTP or F/UTP | ↔ | **STAR** | **100 m channel** (90 m horizontal + 10 m patch) | Access vs trunk vs uplink is a *logical* port role, not physical. VLAN membership belongs on the port |
| 39 | PoE | RJ45 | Cat5e+ | → power, ↔ data | STAR | 100 m | See PoE table below. Budget is per-switch, not per-port |
| 40 | Fiber / SFP | LC, SC, ST; SFP/SFP+/SFP28 cage | OM3/OM4 MMF, OS2 SMF | ↔ | P2P (STAR at switch) | MMF ~300–400 m @10 G; SMF 10–40 km | Transceiver type, wavelength, and *pair polarity* (TX↔RX crossover) all matter. A/B polarity is the fiber analogue of null-modem |
| **POWER** |
| 41 | Branch circuit inlet | NEMA 5-15P (15 A) / 5-20P (20 A) / L5-30P / L14-30P | SO cord / conduit | → | P2P to circuit |: | Circuit identity + breaker size + phase must be schedulable |
| 42 | IEC device power | **C13/C14** (10 A IEC, 15 A NA, 250 V) · **C19/C20** (16 A IEC, up to 20 A NA) | Rated cordage | → | P2P | short | Odd number = female connector on the cord; next even = male inlet on the equipment. C13→C14 is the standard rack pigtail |
| 43 | PDU outlet | NEMA 5-15R/5-20R, C13, C19 |: | → | 1 outlet : 1 device |: | Attributes: **switched / unswitched / sequenced (with sequence step + delay) / UPS-backed / surge-only / metered**. This is the power schedule |

---

## 2. PoE Classes: Verified Table

Needed for a per-switch power-budget validator.

| Standard | Type | Classes | PSE max output | PD max draw | Pairs |
|---|---|---|---|---|---|
| 802.3af (PoE) | Type 1 | 0–3 | 15.4 W | 12.95 W | 2 |
| 802.3at (PoE+) | Type 2 | 4 | 30 W | 25.5 W | 2 |
| 802.3bt (PoE++) | **Type 3** | 5, 6 | **60 W** | **51 W** (Cl.5 ≈ 40 W, Cl.6 ≈ 51 W) | **4** |
| 802.3bt (PoE++) | **Type 4** | 7, 8 | **90 W** | **71–73 W** (Cl.7 ≈ 62 W, Cl.8 ≈ 73 W) | **4** |
| PoH (HDBaseT) |, |, | **up to 100 W** |: | **4** |

PoH is *based on* 802.3at but modified for 4-pair 100 W delivery; it is **not** interoperable with standard PoE PSEs. Treat as its own family.

**Validator:** Σ(PD class draw on switch) ≤ switch PoE budget (which is almost always less than ports × max class). Flag when a Type-4 PD is plugged into a Type-2 PSE.

---

## 3. Directionality Conventions in AV Documentation

Verified conventions to implement:

1. **Signal flows left → right.** Sources on the left, destinations on the right. Follows reading order. Vertical stacking by system (video block, audio block, control block).
2. **Arrowheads at the sink end.** A line with no arrowhead reads as bidirectional or as a bus. Double-headed arrows for ↔.
3. **Colour by signal domain** is already conventional in the trade: blue = video, red = audio, green = control, orange = network. RackMate should stay *near* this convention rather than inventing a fresh one, installers read these drawings. (See §5, I keep the hue families but shift to CVD-safe specific values.)
4. **Line style** distinguishes classes within a domain.
5. **Reference designators** per ASME Y14.44 / IEEE 315 practice:
   - **J** = fixed connector (jack), i.e. a port on a device
   - **P** = movable connector (plug), i.e. a cable end
   - **W** = cable / wire harness, i.e. a run
   This maps cleanly onto RackMate: `Port.designator = J###`, `Cable.designator = W###`, cable ends implicitly `P###`. Adopt it; it makes the schedule legible to anyone who's read a schematic.
6. **Buses drawn as a thick trunk with perpendicular stubs**, not as N point-to-point lines; this is the board-schematic idiom the user asked for and it is exactly right for RS-485, DMX, Cresnet, DALI, 70 V speaker lines, and RF distribution.
7. **Orthogonal routing with jump-overs** (arc hops) at crossings, dots at genuine junctions. The dot-vs-hop distinction is the single most important schematic legibility rule.
8. **Off-page / off-rack connectors** as pennant/flag symbols with a matching tag; this is precisely how the **Structure device** should render: a bank of flags, each tagged with its home-run destination (e.g. `LR-TV-1`, `MBR-KEY`).
9. **AVIXA** publishes a standardized architectural symbol set for AV, video and control (floor plan / RCP). Worth aligning icon vocabulary with it for exportability, though it is plan-view rather than schematic-view.

---

## 4. What a `Port` Abstraction Must Carry

Synthesised from every row above. Fields marked ⚠ are the ones that, if omitted, make a whole family unrepresentable.

```
Port {
  id: UUID
  deviceId: UUID
  label: string              // silkscreen text, "HDMI OUT 3"
  designator: string         // "J14" — ASME Y14.44

  // ── Identity: THREE orthogonal axes, never one enum ⚠
  connector: ConnectorType   // HDMI-A | BNC | RJ45 | XLR3 | F | RCA | Euroblock | C14 ...
  signalFamily: SignalFamily // hdmi21 | hdbaset | ethernet | dante | rs232 ...
  carriedProtocols: [Proto]  // ⚠ for RJ45 disambiguation & multi-service links

  // ── Direction & topology
  direction: source | sink | bidirectional | busNode | passive
  returnChannel?: {           // ⚠ eARC / ARC — opposite-direction signal on same port
    signalFamily, direction, enabled
  }
  topology: p2p | multidrop | star
  maxConnections: int         // 1 for P2P; N for bus/splitter

  // ── Physical
  gender: male | female | genderless | jack | plug   // ⚠ XLR, DB9, IEC, SpeakON
  face: front | rear
  position: { ruOffset, xOffsetMm }                  // for the rack elevation
  pinoutVariant?: string      // ⚠ IR 3.5mm: "xantech-stereo" | "mono-tip-sleeve"

  // ── Electrical
  impedanceOhms?: 75 | 110 | 120 | 100 | 50          // ⚠ S/PDIF vs RCA, AES vs mic, BNC
  level?: mic | line-unbal | line-bal | phono | speaker | instrument
  phantomPower?: bool
  polarity?: positive | negative | none               // ⚠ speaker +/−
  nominalVoltage?: number                             // 70 | 100 | 25 for CV audio

  // ── Grouping ⚠ (component video, balanced stereo, 5-BNC RGBHV, speaker pairs)
  groupId?: UUID
  groupRole?: string          // "Y" | "Pb" | "Pr" | "L" | "R" | "+" | "−" | "H" | "V"
  channelIndex?: int

  // ── Network
  poe?: { role: pse | pd | none, standard: af|at|bt|poh,
          type: 1..4, class: 0..8, watts: number }
  linkSpeedMbps?: 100 | 1000 | 2500 | 10000
  portRole?: access | trunk | uplink | mirror
  vlans?: [int]
  sfpFormFactor?: SFP | SFP+ | SFP28
  fiberMode?: OM3 | OM4 | OS2
  wavelengthNm?: number

  // ── Bus membership ⚠ (RS-485, DMX, DALI, KNX, Cresnet, 70V, RF)
  bus?: { segmentId: UUID, address?: int|string,
          universe?: int,            // DMX
          unitLoads?: number,        // RS-485/DMX budget
          isTerminator?: bool,
          tapWatts?: number }        // ⚠ 70V/100V transformer tap

  // ── Serial
  serial?: { role: DTE | DCE, baud, dataBits, parity, stopBits, flowControl }

  // ── Power
  power?: {
    role: inlet | outlet
    receptacle: NEMA_5-15R | NEMA_5-20R | C13 | C19 | ...
    volts, phase, maxAmps
    outletMode?: switched | unswitched | sequenced | alwaysOn
    sequenceStep?: int, sequenceDelayMs?: int
    backing?: ups | surge | none
    drawWatts?: number          // on inlets, for the load calc
    circuitId?: string          // ⚠ which branch circuit / breaker
  }

  notes: string
}
```

And the link:

```
PhysicalLink {
  id, designator: "W042"
  fromPortId, toPortId
  signalFamily                 // may be narrower than either port's capability
  media: Cat6a-F/UTP | RG6 | 14/2 | HDMI-AOC | OM4-LC-duplex | ...
  lengthFt?, plenum?: bool
  crossover?: straight | null-modem | A/B-polarity   // ⚠ RS-232, fiber
  path?: [waypointIds]         // for orthogonal routing
}

LogicalSignal {                // ⚠ the AV-over-IP / Dante / eARC layer
  id, type, channelCount
  fromEndpointPortId, toEndpointPortId
  transportLinkIds: [UUID]     // the physical hops it rides
  vlan?, multicastGroup?, latencyMs?
}
```

### Validation rules this schema enables

| Rule | Severity |
|---|---|
| HDBaseT port patched to an Ethernet switch port | **error** |
| source→source or sink→sink | **error** |
| Connector mismatch without a declared adapter/balun | **error** |
| IR emitter into an IR-receiver jack | **error** (damages hardware) |
| Impedance mismatch (S/PDIF into 50 Ω BNC; AES3 on mic cable) | warn |
| Passive HDMI 2.1 run > 4.5 m at 48 Gbps | warn |
| 12G-SDI coax run > 45 m | warn |
| Ethernet channel > 100 m | **error** |
| DTE↔DTE RS-232 without `crossover: null-modem` | warn |
| RS-485/DMX segment > 32 unit loads, or missing terminator | warn |
| DMX segment > 512 channels in one universe | **error** |
| DALI line > 64 devices, or > 300 m | **error** |
| Σ PD class draw > switch PoE budget | **error** |
| Cresnet run: both length limit *and* 24 V power-drop limit (18 AWG @ 20 W ⇒ 333 ft) | warn |
| Σ 70 V taps > amp rating (or > 80 % of it) | warn |
| Parallel low-Z speakers drop amp load below rated min impedance | **error** |
| Satellite splitter with no DC-passing port toward the LNB | **error** |
| RF cascade loss budget exceeded | warn |
| 12 V trigger fan-out > 100 mA | warn |
| Σ outlet draw > PDU rating, or > 80 % continuous-load derate | warn |
| Dante endpoints with no network path between them | **error** |
| AVB endpoints traversing a non-AVB/TSN switch | **error** |

---

## 5. Colour Scheme: CVD-Safe, Print-Safe, Greyscale-Survivable

### 5.1 The core argument: colour encodes *domain*, not *type*

There are ~43 signal types above. **No palette is CVD-safe past 8–9 categories**: the Okabe-Ito authors deliberately stopped at eight for exactly this reason. Trying to give each cable type its own hue guarantees an unreadable drawing.

So: **colour carries the 7-way domain**, and **dash pattern + a text tag carry the specific type**. Three independent encodings, degrading gracefully:

| Encoding | Survives CVD | Survives greyscale | Survives fax/photocopy |
|---|---|---|---|
| Hue | ✅ (if chosen well) | ❌ | ❌ |
| Dash pattern | ✅ | ✅ | ✅ |
| Text tag on the run | ✅ | ✅ | ✅ |

### 5.2 Palette: Okabe-Ito, mapped to trade convention

Okabe-Ito was built by running candidate colours through CVD simulators and verifying distinctness under **protanopia, deuteranopia, and tritanopia**. It is the right base. I've mapped it to the existing AV convention (blue=video, red/warm=audio, green=control… ) so it reads correctly to installers, with one deliberate swap: network takes green, control takes purple, because network is now the larger and more "infrastructural" category in modern racks.

| Domain | Hex | Okabe-Ito name | Dash pattern | Tag prefix | Rel. luminance |
|---|---|---|---|---|---|
| **Digital video** (HDMI, DP, SDI, HDBaseT, AVoIP) | `#0072B2` | Blue | solid | `HD`,`SDI`,`HBT` | 0.151 |
| **Analog video & RF** (composite, YPbPr, VGA, coax, sat, OTA) | `#56B4E9` | Sky Blue | long dash `12,4` | `CVBS`,`RF`,`SAT` | 0.401 |
| **Analog audio** (line, XLR, speaker, sub, phono) | `#E69F00` | Orange | dash `6,3` | `AUD`,`SPK`,`SUB` | 0.416 |
| **Digital audio** (S/PDIF, TOSLINK, AES3, Dante) | `#D55E00` | Vermillion | dash-dot `6,3,1,3` | `SPD`,`OPT`,`AES`,`DNT` | 0.222 |
| **Network** (Ethernet, PoE, fiber) | `#009E73` | Bluish Green | solid, 1.5× weight | `NET`,`PoE`,`FIB` | 0.257 |
| **Control** (IR, RS-232/485, contact, trigger, Cresnet, DALI, KNX, DMX) | `#CC79A7` | Reddish Purple | dot `1,3` | `IR`,`232`,`485`,`DMX` | 0.293 |
| **Power** (AC, IEC, PDU) | `#000000` | Black | dash-dot-dot, 2× weight | `PWR` | 0.000 |
| **Structure / home-run** (unassigned rough-in) | `#999999` | (grey, added) | dash `6,3`, thin | `STR` | 0.319 |
| *Selection / highlight only* | `#F0E442` | Yellow |, |, | 0.744 |

Yellow is reserved for interactive highlight, never for a cable, at 0.744 luminance it is illegible as a thin line on white paper.

### 5.3 Honest caveat on greyscale: verify, don't assume

Several sources claim Okabe-Ito has "distinct luminance values so the palette works even in grayscale." **Computing WCAG relative luminance shows this is overstated.** Two collision pairs:

- Sky Blue `#56B4E9` (0.401) vs Orange `#E69F00` (0.416), **1.5 % apart, indistinguishable in greyscale**
- Vermillion (0.222) / Green (0.257) / Purple (0.293), a crowded 0.07 band

This is *exactly* why the dash + tag layers are mandatory rather than decorative. Note the collisions were placed deliberately: the sky-blue/orange pair is analog-video vs analog-audio, which get maximally different dash patterns (long-dash vs short-dash) and unmistakable tags. Never rely on hue alone in the PDF export.

**Recommend: ship a "greyscale-safe" export toggle** that drops hue entirely and renders domain purely via dash + weight + tag. It will be the setting every installer who prints on the office laser printer actually uses.

### 5.4 Additional legibility measures

- **Tag pills** on every run at both ends and at any page break: `W042 · HDMI · 25ft`. This is the schematic idiom and it is the encoding that never fails.
- **Line weight as a third channel**: power 2×, network/trunk 1.5×, signal 1×, control 0.75×.
- **Bus trunks** rendered as thick lines with perpendicular stubs and junction dots, visually distinct from P2P at a glance regardless of colour.
- Minimum stroke **0.5 pt** at print scale; dash periods ≥ 1.5 mm or they blur to solid at 300 dpi.
- Consider a **texture/marker glyph** at the midpoint of each run (▲ video, ● audio, ■ network…) as a fourth channel for the most degraded reproduction cases.

---

## 6. Notes on the Structure Device

Given the taxonomy, the Structure device is best modelled as a **device with only sink/source-agnostic `passive` ports**, each carrying:

- `homeRunLabel` (e.g. `LR-TV-1`, `MBR-KEY-2`, `ATTIC-AP-3`)
- `media` (Cat6, RG6, 16/2, 14/4, conduit)
- `terminationPoint` (patch panel port, F-barrel, punchdown, unterminated)
- `roomOrZone`
- `signalFamily`, often **unassigned at rough-in**, which is the interesting case: a Cat6 home run may end up carrying Ethernet, HDBaseT, or nothing. The model should permit `signalFamily: undetermined` and let the connection assign it, then validate retroactively.

Render it as a bank of off-page connector flags on the left edge, the schematic convention for signals entering from elsewhere. That also makes it visually obvious in the PDF which home runs are **unused**, which is a genuinely valuable deliverable for the installer.

Also worth noting: RF splitters, baluns, patch panels, and IR connecting blocks are **passive infrastructure devices** that appear in the wiring plan but may or may not consume RU. The device model should allow `ruHeight: 0` / `mountLocation: not-in-rack` so a splitter in the attic can still be a node in the netlist.

---

## Sources

**Video / AV digital**
- [HDBaseT, Wikipedia](https://en.wikipedia.org/wiki/HDBaseT) · [HDBaseT Technology (hdbaset.org)](https://hdbaset.org/hdbaset-technology/) · [HDBaseT 5Play key elements, CIE Group](https://cie-group.com/how-to-av/videos-and-blogs/hdbaset-5play-key-elements-explained) · [HDBaseT wiring guidance, HDANYWHERE](https://support.hdanywhere.com/2012/11/hdbaset-wiring-guidance/)
- [Max length for passive HDMI 2.1](https://www.hdmiusbcable.com/what-is-the-maximum-length-for-a-passive-hdmi-2-1-cable/) · [Active vs passive HDMI: ARC, eARC & direction, ICTAlly](https://ictally.com/resources/blog/active-vs-passive-hdmi-cables-arc-earc-explained) · [Fiber optic HDMI cables explained](https://network-switch.com/blogs/networking/fiber-optic-hdmi-cables-explained) · [How active HDMI cables work, Cable Matters](https://www.cablematters.com/Blog/HDMI/how-do-active-hdmi-cables-work)
- [VESA DP 2.1a active cable spec](https://vesa.org/press/vesa-to-update-displayport-2-1-with-new-active-cable-specification-for-up-to-3x-longer-dp80-cables/) · [DisplayPort 2.1 UHBR cable issue, Tom's Hardware](https://www.tomshardware.com/monitors/displayport-21-has-a-serious-issue-with-uhbr-certified-cables-perhaps-thats-why-nvidia-opted-to-stick-with-dp14-on-the-rtx-40-series) · [Understanding DisplayPort 2.1, Plugable](https://kb.plugable.com/docking-stations-and-video/understanding-displayport-21)
- [SDI cable length limits, Thomson Visuals](https://thomsonvisuals.com/blogs/thomsons-tech-tips/sdi-cable-length-limits-how-far-can-you-actually-run) · [Belden recommended transmission distance chart (PDF)](https://www.anixter.com/content/dam/Suppliers/Belden/Brochures/Recommended_Transmission_Distance_Chart.pdf) · [Belden 1694A, Blue Jeans Cable](https://www.bluejeanscable.com/catalog/SDI-94S-12F-BB-W.htm)

**RF / satellite**
- [DIRECTV SWM/DECA/MRV installation guide, Solid Signal](https://www.solidsignal.com/directv-installation-equipment-guide-swm-deca-and-mrv) · [8-way SWM power-passing splitter](https://satellitesale.net/products/directv-at-t-8-way-swm-power-passing-splitter) · [SWM16 multiswitch, WeaKnees](https://www.weaknees.com/swm-directv-large-installations.php)

**Audio**
- [Constant-voltage audio distribution systems, Rane Note (PDF)](https://www.ranecommercial.com/legacy/pdf/ranenotes/Constant_Voltage_Audio_Distribution_Systems.pdf) · [Guide to constant voltage systems, Harman](https://help.harmanpro.com/guide-to-constant-voltage-systems) · [25V/70V/100V speaker systems, Lowell (PDF)](https://www.lowellmfg.com/wp-content/uploads/What-is-a-25V-70V-or-100V-Speaker-System.pdf) · [Understanding 70V/100V tappings, CIE Group](https://cie-group.com/how-to-av/videos-and-blogs/tappings) · [High voltage (70/100V) audio, Elliott Sound](https://sound-au.com/articles/line-amps.html)
- [Dante vs AES67, AVRelated](https://blog.avrelated.com/dante-vs-aes67-simplifying-audio-over-ip-technologies/) · [AES67, Wikipedia](https://en.wikipedia.org/wiki/AES67) · [Comparing AVB, Dante, AES50, AES67](https://www.londonelectricals.co.uk/post/comparing-audio-distribution-protocols-avb-dante-aes50-and-aes67) · [QoS across QLAN, Dante and AES67, Q-SYS](https://support.qsys.com/en_US/awareness/awareness-|-quality-of-service-settings-across-qlan-dante-and-aes67) · [Other networked audio, Q-SYS Help](https://q-syshelp.qsc.com/q-sys_8.2/Content/Networking/Other_Networked_Audio.htm)

**Control**
- [Xantech IR connecting block install instructions (PDF)](https://www.fullcompass.com/common/files/14981-Manual.pdf) · [Xantech ML25K install instructions (PDF)](https://corebrands-resources.s3.amazonaws.com/products/Xantech-Discontinued-Manuals/578_ML25K.pdf) · [3.5mm IR cable pinouts, Crestron group](https://groups.io/g/crestron/topic/35761850)
- [DB-9 serial pinouts: DCE-DTE, gender, null modems, Grid Connect](https://gridconnect.zendesk.com/hc/en-us/articles/115008733428-DB-9-Serial-Pinouts-DCE-DTE-Gender-and-Null-Modems-with-RS232) · [RS232 null modem cable pinout DB9-DB9, AggSoft](https://www.aggsoft.com/rs232-pinout-cable/nullmodem-db9-to-db9.htm) · [RS-232 DB9 pinout reference, SCADA Protocols](https://scadaprotocols.com/rs-232-db9-pinout/)
- [DMX512, Wikipedia](https://en.wikipedia.org/wiki/DMX512) · [Isolated RS-485 in DMX512 lighting, Analog Devices](https://www.analog.com/en/resources/analog-dialogue/articles/isolated-rs-485-in-dmx512-lighting.html) · [Isolated RS-485 transceivers support DMX512, TI (PDF)](https://www.ti.com/lit/pdf/slyt425)
- [Cresnet wiring and connectors, Crestron docs](https://docs.crestron.com/en-us/9272/Content/Topics/Cresnet-Wiring.htm) · [Crestron wiring guidelines](https://docs.crestron.com/en-us/7389/Content/Topics/Installation/Wiring%20Guidelines.htm) · [Crestron power requirements](https://docs.crestron.com/en-us/9292/Content/Topics/Power-Considerations.htm)
- [DALI wiring & topology, IEC 62386](https://www.knxhub.com/dali-wiring-installation-topology/) · [DALI lighting control protocol](https://www.knxhub.com/dali-lighting-control-protocol-and-future-explained/) · [Lutron residential & commercial system rules (PDF)](https://assets.lutron.com/a/documents/369821_lutron_residential_and_commerical_system_rules.pdf) · [Using DALI ballasts in HomeWorks QS (PDF)](https://assets.lutron.com/a/documents/using_dali_in_hwqs.pdf)

**Network / power**
- [Overview of 802.3bt, Ethernet Alliance (PDF)](https://ethernetalliance.org/wp-content/uploads/2018/04/WP_EA_Overview8023bt_FINAL.pdf) · [Understanding the IEEE 802.3bt PoE standard, Skyworks (PDF)](https://www.skyworksinc.com/-/media/SkyWorks/SL/documents/public/white-papers/understanding-the-ieee-8023bt-poe-standard.pdf) · [Type 3 and Type 4 are here, Fluke Networks](https://www.flukenetworks.com/blog/cabling-chronicles/type-3-and-type-4-are-here) · [Demystifying PoE terminology, AMG Systems](https://blog.midches.com/blog/demystifying-power-over-ethernet-poe-terminology-ieee-802.3af-802.3at-and-802.3bt-type-3-and-type-4) · [PoE standards overview, Microchip](https://developerhelp.microchip.com/xwiki/bin/view/applications/ethernet/poe/standards/)
- [IEC connector chart C13/C14/C15/C19/C20, Cable Leader](https://www.cableleader.com/blog/post/iec-power-connector-chart) · [IEC 60320 reference chart, World Cord Sets](https://shop.worldcordsets.com/shop/reference-materials/iec-60320-reference-chart) · [IEC power connectors: amp ratings & selection](https://network-switch.com/blogs/networking/iec-power-connectors-guide-2026) · [Power cord types: IEC vs NEMA, C13 vs C19, rack selection guide](https://www.zion-communication.com/Power-Cord-Types-2026-Explained-IEC-vs-NEMA-C13-vs-C19-Data-Center-Rack-Selection-Guide-id48659665.html)
- [12V trigger switches, Elliott Sound Project 156](https://sound-au.com/project156.htm) · [12 volt trigger overview and setup, MSB Technology](https://msbtechnology.com/support/12-volt-trigger/)

**Documentation conventions & colour**
- [AV & control architectural drawing symbols, AVIXA](https://www.avixa.org/standards/audio-video-and-control-architectural-drawing-symbols) · [AV signal flow diagrams: complete guide](https://kennyavsolution.com/av-signal-flow-diagrams-guide/) · [What is an AV signal flow diagram?](https://gwendpots.substack.com/p/what-is-an-av-signal-flow-diagram)
- [Okabe-Ito palette guide, Vizcept](https://vizcept.com/blog/okabe-ito-palette-guide) · [Okabe-Ito hex codes complete reference](https://conceptviz.app/blog/okabe-ito-palette-hex-codes-complete-reference) · [Color palette, Siegal Lab NYU](https://siegal.bio.nyu.edu/color-palette/) · [Paul Tol's colour schemes (SRON)](https://personal.sron.nl/~pault/) · [Paul Tol's colour schemes, khroma/CRAN](https://cran.r-project.org/web/packages/khroma/vignettes/tol.html)