# Research · centralized lighting: panels, modules, processors and wireless links

**Written 2026-10-09 for LIGHT-0 (`#1041`), under DR-246** (canon §11.245), against `main` at
`8afdc525`. Every source was retrieved on 2026-10-09. Unlike the original research pass, this paper
says how each fact was obtained, because the difference matters when a figure becomes a rule:

- **[read]** means the manufacturer's own document was opened and the figure taken from its text.
- **[summary]** means the figure came from a search engine's summary of a page that was not opened
  here. Treat it as `VERIFY:` before it reaches a catalog row or a rule (CR-061).

**The question.** DR-246 created roadmap §2.5, *v1.4: centralized lighting*, as a stub, and named a
census of real panels as the step before any model: *"slot counts, rail lengths, module widths,
where the controller and the switch sit"*. The user's description to test: *"Lutron has a DIN-rail
based system; Vantage uses a 1x4 module panel, with a slot in the bottom for the controller;
Control4 has its own panel with a network switch enclosure & space for various amounts of modules
depending on the panel size."*

**The answer in one line.** All three are confirmed in substance and refined in detail, and all three
share one architecture: a **processor**, **power panels** that come as a *main* kind (room for
control gear) and a *secondary* kind (modules only), **modules** that take a few **line feeds** and
split them into **zones**, a **wired keypad bus**, and one or more **wireless links** with hard
device limits.

---

## 1. The shape the three systems share

| Concept | Lutron HomeWorks QSX | Vantage InFusion | Control4 Panelized |
|---|---|---|---|
| Processor | HQP7 QSX processor | InFusion Controller (IC-24 / IC-36) | A Control4 controller, outside the panel |
| Where the processor sits | A PDx **control** panel's gear compartment, or a low-voltage enclosure (HQ-LV21, L-LV14, L-LV21) | The **main** enclosure (IMPE), behind an opening in the door | Not in the panel at all |
| Panel kinds | **Control** (PD4, PD8) and **satellite** (PD2, PD5, PD9) | **Main** (IMPE) and **secondary** (ISPE) | One kind, 2-slot and 5-slot |
| What a module plugs into | DIN rail rows | Fixed module positions with a factory low-voltage harness | DIN rail slots, each with a terminal block beside it |
| A module's outputs | Zones (4 per DPM) | Loads (8 or 12 per module) | Channels (8 per module) |
| How a module is fed | Line feeds landing on the DPM | Up to four line feeds per module | One or two line feeds per module |
| Wired keypads | QS link | WireLink station bus | RS-485 bus via a bus power supply |
| Wireless | ClearConnect A (sub-GHz), ClearConnect X (2.4 GHz) | RadioLink (900 MHz) | ZigBee |

**The user's "1x4 module panel with a slot in the bottom for the controller"** is Vantage's IMPE-4:
one controller and up to four modules [read]. **The user's "network switch enclosure"** is Control4's
Centralized Lighting Ethernet Switch Kit, a mounting plate that *"segregates the high and low-voltage
sections of the lighting panel"* and carries an Araknis compact switch [read]. It is an accessory,
not part of the panel; the 2013 panel line instead had a switch **module** that took a slot (§4).

---

## 2. Lutron HomeWorks QSX

### 2.1 DIN panels [read: Lutron 3691055f, 2024-02-07]

*"Control panels have a control gear compartment that can house a low-voltage interface or
processor. Satellite panels replace the control gear compartment with a DIN rail row to mount an
additional DPM."* All are **120 V~ feed-through** panels.

| Model | Kind | Holds | Panel H x W x D |
|---|---|---|---|
| PD2-16F-120 | Satellite | 2 DPMs, 1 wire landing board (WLB) | 16 x 15.125 x 4.28 in (407 x 385 x 109 mm) |
| PD4-36F-120 | Control | 4 DPMs, 1 WLB, 1 power supply, 1 LV interface or processor | 36 x 15.125 x 4.28 in |
| PD5-36F-120 | Satellite | 5 DPMs, 1 WLB | 36 x 15.125 x 4.28 in |
| PD8-59F-120 | Control | 8 DPMs, 1 WLB, 1 power supply, 1 LV interface or processor | 59 x 15.125 x 4.28 in (1500 mm tall) |
| PD9-59F-120 | Satellite | 9 DPMs, 1 WLB | 59 x 15.125 x 4.28 in |

The model number encodes it: `PD` + **DPM count** + `-` + **height in inches** + `F` (feed-through) +
voltage. A control panel's gear compartment takes one of: HQP6 or HQP7 processors (and MDU variants),
`QSPS-DH-1-75-H` (24 V power supply), `QSE-IO`, `QSE-CI-DMX`, `QS-WLB`.

**Installation rules the sheet states, each one checkable against a plan:**

- *"Mount the panel so that line-voltage wiring will be at least 6 ft (1.8 m) from audio or
  electronic equipment and wiring."*
- *"Allow at least 12 in (305 mm) of air space at the top, bottom, and front of the cover."*
- *"Limit vertical stacking of PD2 panels to three panels high. Limit vertical stacking of PD4 panels
  to two panels high. Do not vertically stack PD5, PD8, or PD9 panels."*
- Fits a 16 in on-centre stud bay; flush in a 2x4 wall needs the drywall built out (4.34 in behind the
  flange). Mounting hardware rated for 110 lb (50 kg). Passive cooling; 0 to 40 °C.
- *"Use of non-Lutron equipment in the panel voids the warranty."*

### 2.2 DIN power modules (DPMs)

Panels accept `LQSE-2ECO-D`, `LQSE-4A1-D`, `LQSE-4A5-120-D`, `LQSE-4A-120-D`, `LQSE-4T5-120-D`,
`LQSE-4T20-120-D`, `LQSE-4S8-120-D` and `LQSE-4M-120-D` [read: 3691055f]. The leading digit is the
zone count.

- **`LQSE-4A-120-D`, phase adaptive** [read: 3691052c]. Four zones rated **400 W, 250 W, 250 W,
  250 W**: the zones are **not** equal. *"10 A maximum total input current."* *"One load type per
  zone."* Auto-detects leading or trailing edge.
- **`LQSE-4T20-120-D`, 0-10 V / softswitch** [read: 3691278]. *"Four switched outputs, 20 A each"*
  plus four 0-10 V outputs rated 50 mA, source or sink.
- **`LQSE-4S8-120-D`, switching**, 9 DIN modules wide (161.7 mm), motor-rated to 1/3 HP [summary].
- **`LQSE2-1DALUNV-D`, DALI-2**, one bus of up to 64 addressable loads, 9 DIN modules wide [summary].
  It is not on 3691055f's list, so which panels take it is `VERIFY:`.

### 2.3 The processor and its links [read: Lutron 3691127f, 2025-08-06]

*"Each QSX processor has 1 or 2 links"* (`HQP7-1`, `HQP7-2`, plus MDU variants), each configured as a
wired QS link or a ClearConnect A link. Link capacities:

| Link | Capacity |
|---|---|
| HomeWorks QS wired device link | 99 devices / 512 switch legs |
| Same, MDU models | 50 devices / 100 switch legs |
| HomeWorks ClearConnect Type A link | 99 devices / 100 switch legs |

*"Switch legs are the smallest controllable outputs and include dimmed or switched circuits,
HomeWorks Digital or DALI addressable devices."* **A switch leg is the unit a load schedule
counts.** The processor *"mounts in HQ-LV21, L-LV14, L-LV21, or PDx control panel"*: a Lutron job
can have its processor in a low-voltage enclosure apart from every power panel. A ClearConnect A link
is **wired** from the processor to hybrid repeaters, *"1,000 ft (305 m) maximum wire length per run"*,
and the same wiring diagram repeats the radio distances: **30 ft (9 m)** to a device, **60 ft (18 m)**
between repeaters. So the distance rule in §2.4 is HomeWorks' as well as RadioRA 3's.

ClearConnect X devices reach a QSX system through a **Clear Connect Gateway Type X** on the network,
not a processor link; up to 100 devices per gateway [summary], with an older sheet saying 50 (§6).

### 2.4 RadioRA 3, for the wireless rules [read: Lutron support article 000002520]

| Rule | Figure |
|---|---|
| Processors per system | 4 |
| Auxiliary repeaters | 4 per processor, 8 per system |
| ClearConnect X devices | 100 per processor, 200 per system; *"Sunnata companion dimmers/switches do not count"* |
| ClearConnect A devices | 95 per processor, 190 per system |
| CCX range | *"All CCX devices must be located within 75ft (22.9m) of the processor"*; at least 2 within 25 ft; each within 25 ft of two other CCX devices |
| CCA range | *"within 30 ft (9.1m) of the RadioRA 3 processor or Repeater"*; repeaters within 60 ft of the processor or another repeater |

ClearConnect A runs at **431 to 437 MHz** with repeaters; ClearConnect X is **IEEE 802.15.4 at
2.4 GHz**, a mesh [summary: Lutron 048745, Lutron FAQ]. That is the user's pairing exactly: CCA is
Z-Wave-like (sub-GHz), CCX is ZigBee-like (2.4 GHz mesh). **CCX is not documented as Thread**, and a
forum post says it is not; nothing here should say otherwise.

---

## 3. Vantage InFusion

### 3.1 Enclosures [read: Vantage IMPE/ISPE sheet; Legrand IMPE-4-IC24 print page]

*"The InFusion Main Power Enclosure (IMPE) houses the InFusion Controller and two or four separate
control modules. The InFusion Secondary Power Enclosure (ISPE) economically extends the load capacity
... from the Main Power Enclosure."*

| Model | Kind | Holds | H x W x D |
|---|---|---|---|
| IMPE-2-IC24 / IMPE-2-IC36 | Main | 1 controller (24 V or 36 V), up to 2 modules | 35 x 14.5 x 4 in (88.9 x 37 x 10 cm) |
| IMPE-4-IC24 / IMPE-4-IC36 | Main | 1 controller, up to 4 modules | 52 x 14.5 x 4 in (132 x 37 x 10 cm) |
| ISPE-2-IC | Secondary | up to 2 modules | 35 x 14.5 x 4 in |
| ISPE-4-IC | Secondary | up to 4 modules | 52 x 14.5 x 4 in |

- The four-module enclosure: *"32 line feeds with up to 256 amps, over 30K dimmable watts (at 120V)
  71K watts (at 277V)"*; 120 to 277 V~.
- *"IMPE panel door opening provides easy access to the controller LCD."* Modules and controller
  change *"without tools"* on a factory harness, so **positions are fixed**, not a rail.
- Terminal boards are specified per module when ordering, and *"include dedicated screw terminal
  conductors for line feed and load attachment."*
- Stud-bay or surface mount, hinged door.

### 3.2 Modules [summary]

- `SDM12-EM`: 12 forward-phase loads, up to four line feeds, 64 A total.
- `UDM08-EM`: 8 universal loads (forward or reverse phase, per load), 120 to 277 V, up to four line
  feeds.
- `EDIMMOD`: 8 reverse-phase loads, two line feeds, 120 V.
- 288 extra loads from six secondaries is 6 x 4 x 12, which fits SDM12s throughout.

### 3.3 Controller and stations [summary]

- `IC-DIN-II` (InFusion Controller II, DIN): up to 120 WireLink stations and up to 120 RadioLink
  stations. Up to 31 linked controllers per system.
- **RadioLink is 900 MHz** with 25-channel hopping; each `RFE1000` enabler takes up to 60 RadioLink
  stations, two enablers per controller, about 100 ft per enabler. The user's belief recorded in
  DR-246 §11.245 (*"Vantage I believe also uses the 900MhZ frequency band"*) is supported, by a
  retailer and a forum rather than a Vantage document.

---

## 4. Control4 Panelized Lighting

### 4.1 Panels [read: Control4 #101486-B, 2013; SnapAV C4-DIN-PAN-A]

| Model | Modules | Backbox H x W x D | Weight |
|---|---|---|---|
| C4-DIN-2PAN | 2 | 33.5 x 14.3 x 3.8 in (85.1 x 36.2 x 9.5 cm) | 27.35 lb (Control4) or 29 lb (SnapAV) |
| C4-DIN-5PAN | 5 | 63.9 x 14.3 x 3.8 in (162.3 x 36.2 x 9.5 cm) | 49.4 lb (Control4) or 53 lb (SnapAV) |

*"DIN rail mounting for modules allows modules to easily snap on and off."* A *"swivel divider at
the top and bottom effectively separates line-voltage and low-voltage wiring."* *"All modules protrude
through the front cover"* for status LEDs and override buttons. Stud-bay or surface mount.

### 4.2 Modules [read: Control4 #101493-B, 2013, and the current modules page]

Each module sits in a slot **with a terminal block installed beside it**: `C4-DIN-TB-8DIM` for the
dimmer, `C4-DIN-TB-8REL` for the relay, `C4-DIN-TB-PO` for the 0-10 V dimmer, the switch or the bus
power supply.

| Model | Does |
|---|---|
| C4-DIN-8DIM-E | 8-channel dimmer; per channel *"Switch mode, Forward Phase mode, Reverse Phase mode, and Autodetect"* [summary]. 1 or 2 line feeds; 1,920 W per line feed and 3,200 W with two, at 120 V on the V2 sheet [summary] |
| C4-DIN-8REL-E | 8-channel relay, *"high in-rush loads"* |
| C4-DIN-8TV-E | 8-channel 0-10 V dimmer |
| C4-DIN-8ESW-E | 8-port Ethernet switch: *"Distributes an Ethernet connection to seven (7) other Panelized Lighting Devices"* |
| C4-DIN-BPS | Bus power supply for wired keypads on the RS-485 system bus |
| C4-DIN-BEG | Bus Ethernet gateway: RS-485 to Ethernet |

**The switch was a slot.** In the 2013 line the Ethernet switch is a "device module" like any other,
so a 5-slot panel holding a switch has four slots for loads, 32 channels rather than 40. The later
**Ethernet Switch Kit** (`C4-DIN-ESMOUNT-KIT`) moves the switch onto a mounting plate in the panel,
PoE-powered, feeding *"up to five (5) other Control4 Panelized Lighting devices"* [read: SnapAV].

### 4.3 ZigBee

Control4's wireless dimmers and keypads are ZigBee. **No Control4 document was found for a per-mesh
limit.** Dealer forums and a third-party guide cite about **70 devices per mesh** before adding mesh
controllers, with reports of 95 working and of geography mattering more than count [summary, forum
grade]. Not a number a rule can cite.

---

## 5. The wireless protocols, side by side

| Protocol | Band | Topology | Limit | Source grade |
|---|---|---|---|---|
| ClearConnect A | 431 to 437 MHz | Star through repeaters | 95 per RA3 processor; 99 per QSX link | read (RA3, QSX) |
| ClearConnect X | 2.4 GHz, 802.15.4 | Mesh, per gateway | 100 per RA3 processor or gateway | read (RA3), summary (gateway) |
| Vantage RadioLink | 900 MHz | Via RF enablers | 60 per enabler, 120 per controller | summary |
| ZigBee (Control4) | 2.4 GHz | Mesh | about 70 per mesh, guidance only | forum |
| Z-Wave | sub-GHz (908.42 MHz in the US) `VERIFY:` | Mesh, source-routed | `ZW_MAX_NODES 232`, `MAX_REPEATERS 4`; Long Range 1,024 | summary of Silicon Labs API docs |
| Wi-Fi | 2.4 / 5 / 6 GHz | Infrastructure | Per access point, vendor-specific | not researched |

**What this means for DR-246's "count per network against a cited limit":** Lutron and Z-Wave have
citable numbers. Vantage has numbers from secondary sources only. ZigBee has none a rule could cite,
so a ZigBee count would have to be shown and never judged, which is G4 working as intended.
**Distance is different** (§10): the user gave Control4's ZigBee rule of thumb, and DR-247 made
distance an advisory check that names its source.

---

## 6. ⚠ Where sources disagree

| Claim | Disagreement | Read it as |
|---|---|---|
| IMPE-4-IC24 capacity | Legrand's product page: *"houses the 24V InFusion Controller and two separate control modules"* under a title saying 4 Module. The family sheet: up to four | **Four.** The product page is a copy error |
| Secondaries per IMPE | The same Vantage sheet says *"Up to six Secondary Enclosures"* and, a column over, *"up to 5 additional enclosures per controller"* | **Six, per the user** (DR-247 §11.246.5): one main and six secondary, 28 modules per controller. 288 loads (6 x 4 x 12) agrees |
| CCX devices per gateway | 100 (newer Lutron spec) vs 50 (older sheet) [summary] | Probably 100; check the revision |
| CCA devices per RA3 processor | 95 (support article, read) vs *"100 ... including repeaters"* (one-line diagram) [summary] | The same budget counted two ways: 95 plus 1 processor plus 4 repeaters |
| Control4 panel weight | 49.4 lb / 27.35 lb (Control4, 2013) vs 53 / 29 lb (SnapAV) | Likely a revision; neither is a design input |
| Control4 slot math | 5 slots x 8 channels = 40 loads, but the 2013 switch took a slot | 40 needs the later switch kit, or a switch in another panel |
| QSX link power | 1 A per link (Lutron, read) vs 2 A (a distributor) | **1 A**, the manufacturer's |

---

## 7. What RackPal already has, read rather than recalled

- **`Rack` counts RU and nothing else** (`rack.dart`). None of these panels has an RU.
- **`Circuit` already exists**: a branch circuit, *"Panel A / Breaker 14"*, with `breakerAmps`,
  `volts`, `phase`, `dedicated`, flat on the document. A module's line feeds are exactly the thing a
  `Circuit` feeds, so the breaker side of a load schedule may need no new entity.
- **`ctl.lutron_qs`** (`conn.rj45`, BUS, topology-free, 2000 ft on 12 AWG) and **`ctl.vantage`**
  (`conn.hardwired`, BUS, DR-120) already ship, as does RS-485 for Control4's keypad bus.
- **DR-120 §11.119.6 ruled the load-controlling keypad `F19` "supply only, no switched output"** by the
  user's call, with *"the load is drawn as its own run where a sheet needs it."* A band that models
  zones and loads must amend that clause by ID, not drift past it.
- **A rack shelf** (CR-029, AC-043; not DR-123's library shelf) is the nearest existing host to a
  DIN rail: an auto-packing container that places hosted devices along one axis. A rail measured in DIN modules is the same shape on a different unit. The module
  is 17.5 mm nominal `VERIFY:`, but Lutron gives a 9-module DPM as 161.7 mm, about 18 mm each, so
  **store a module's width in millimetres as its sheet states it** rather than deriving it from a
  count. A hypothesis, not a design.

---

## 8. Condensed takeaways for the v1.4 model (hypotheses, not rulings)

1. **A lighting panel is a host with rows or positions, not RU.** Lutron rows are DIN rail; Vantage
   positions are fixed slots; Control4 slots are DIN rail with a terminal block beside each.
2. **Panels come in a main kind and a secondary kind** in two of the three systems, and the
   difference is one compartment: control gear or one more module row.
3. **The processor's home is a choice**, not a fact about the panel: Lutron puts it in a control panel
   or a low-voltage enclosure, Vantage only in the main enclosure, Control4 outside the panel.
4. **A module is fed by one to four line feeds and drives 4 to 12 zones**, and **a zone's rating is
   per zone, not per module** (Lutron's 400/250/250/250 W). A module also has a total ceiling.
5. **The unit a load schedule counts is the zone**, Lutron's *switch leg*, and the processor's link
   limits are counted in them (512 per QS link).
6. **One load type per zone** is a stated rule, and checkable.
7. **Lutron's installation rules are plan-checkable**: 6 ft from AV equipment and wiring, 12 in of air
   above and below and in front, stacking limits by model.
8. **A wireless network has a counted limit per processor, link, enabler or gateway**, and for Lutron
   a **stated straight-line distance rule** (§9, question 1).

---

## 9. Questions for the user

1. **Does Lutron's distance rule reopen DR-246 §11.245.7?** The ruling refused a range check because
   plan positions know no walls, so a distance verdict *"would be an estimate printed as a fact"*.
   **Lutron's own rule is a straight-line distance**: every CCA device within 30 ft of a processor or
   repeater, every CCX device within 75 ft of the processor. Checking that is checking Lutron's rule,
   not estimating propagation. The recommendation stands for ZigBee and Z-Wave, which publish no
   distance rule; for Lutron it may not.
2. **Is the 6 ft line-voltage separation a rule you design to?** It is on Lutron's spec sheet, and the
   Plan view knows where a panel and a rack are.
3. **Where does the processor live on your jobs:** in the power panel, a low-voltage enclosure, or the
   rack? It decides whether a processor is a panel occupant or an ordinary device.
4. **What does your firm hand over:** a load schedule (circuit, zone, load type, watts), a keypad
   engraving schedule, both, or neither? Lutron's tool lists circuit, feed and zone name per load
   [summary; its help host no longer resolves].
5. **Vantage enclosures per controller: five or six?** Vantage's own sheet says both.

---

## 10. The user's answers, 2026-10-09

Recorded as DR-247 (canon §11.246). In order of §9's questions:

1. **Distance.** *"ZigBee does have a rule of thumb that Control4 operates on (the bulk of ZigBee
   installations currently, AFAIK) of 15-20 feet max between devices, and no more than 300 feet from
   the ZAP (ZigBee Access Point)."* Offered the options, the user ruled distance an **advisory** check,
   sources and grades shown, editable per protocol, other-sheet devices counted as unchecked.
2. **The 6 ft separation.** *"Let's leave that one unruled for now; make a note of it for the start of
   the epic."*
3. **Where the processor lives.** It depends on the job: panels are built to hold their own brand's
   controller and centralized jobs aim for that; RadioRA 3 and Sunnata-based HomeWorks jobs put it on a
   rack or in a low-voltage enclosure; Caseta has no panel and lives on a rack, in an enclosure, or
   mounted to the outside of one.
4. **Deliverables.** *"Both ideally, neither typically (partially a documentation issue, partially a
   culture issue. I'd want to have both be deliverables though)."*
5. **Vantage.** *"It's actually 7 panels (One main + six secondary) for a total of 28 modules for one
   controller."*

---

## 11. Sources

Retrieved 2026-10-09.

- Lutron, *120 V~ Feed-Through DIN Panels (and Accessories)*, 3691055f, 2024-02-07.
  <https://assets.lutron.com/a/documents/3691055_eng.pdf> [read]
- Lutron, *HomeWorks QSX Processor*, 3691127f, 2025-08-06.
  <https://assets.lutron.com/a/documents/3691127_eng.pdf> [read]
- Lutron, *LQSE-4A-120-D Phase Adaptive Power Module*, 3691052c.
  <https://assets.lutron.com/a/documents/3691052_eng.pdf> [read]
- Lutron, *LQSE-4T20-120-D 0-10 V-/Softswitch Power Module*, 3691278.
  <https://assets.lutron.com/a/documents/3691278_eng.pdf> [read]
- Lutron, *RadioRA 3 System Overview*, support article 000002520.
  <https://support.lutron.com/us/en/product/radiora3/article/system-design-setup/RadioRA-3-System-Overview> [read]
- Lutron, *Clear Connect Type X best practices*, 048745, and the RA3 product-selection FAQ.
  <https://assets.lutron.com/a/documents/048745.pdf> [summary]
- Lutron, *Clear Connect Gateway Type X*, 3691128. <https://assets.lutron.com/a/documents/3691128_eng.pdf> [summary]
- Lutron, *DALI Power Module LQSE2-1DALUNV-D* (BIMobject listing).
  <https://www.bimobject.com/da/lutronelectronics/product/lutron-homeworks-lqse2-1dalunv-d> [summary]
- Vantage, *InFusion Main and Secondary Power Enclosure* (IMPE-X-IC36/IC24, ISPE-X-IC).
  <https://michaelsforms.eastus2.cloudapp.azure.com/prod_image/Infrastructure_InFusionMainPowerEnclosure.pdf> [read]
- Legrand, *InFusion Main Power Enclosure 24V 4 Module*, print page.
  <https://www.legrand.ca/p/print/VA-IMPE-4-IC24.pdf> [read]
- Vantage dimming modules (SDM12-EM, UDM08-EM, EDIMMOD), retailer and magazine listings.
  <https://techstyle.co.nz/products/vc-sdm12-em> ·
  <https://www.architectmagazine.com/technology/products/infusion-udm08-em-vantage_o> [summary]
- Vantage RadioLink (RFE1000, RK12xE), retailer, forum and Legrand listings.
  <https://store.audiovisualcs.com/index.php/product/vantage-radiolink-enabler-adds-radio-capabilities-to-existing-systems/> ·
  <https://www.legrand.us/lighting-controls-and-systems/vantage-controls/controllers/infusion-controller-ii-din/p/ic-din-ii> [summary]
- Control4, *5-Slot and 2-Slot Panels*, #101486-B, 2013.
  <https://cn.control4.com/docs/product/2-slot-and-5-slot-panels/data-sheet/english/latest> [read]
- Control4, *Panelized Lighting Products*, #101493-B, 2013.
  <https://cn.control4.com/docs/product/panelized-lighting/information-sheet/latest> [read]
- Control4, *Centralized Lighting Modules*. <https://www.control4.com/solutions/products/centralized-lighting-modules> [read]
- Control4, *8-Channel Dimmer* data sheets. <https://cn.control4.com/docs/product/8-channel-dimmer/data-sheet/english/latest> [summary]
- SnapAV, *C4-DIN-PAN-A* and *C4-DIN-ESMOUNT-KIT*.
  <https://www.snapav.com/shop/en/snapav/C4-DIN-PAN-A> ·
  <https://www.snapav.com/shop/en/snapav/c4-din-esmount-kit> [read]
- Silicon Labs, *Z-Wave Transport API*. <https://docs.silabs.com/z-wave/latest/zwave-api/zw-transport-api-h> [summary]
- c4forums, ZigBee mesh threads. <https://www.c4forums.com/forums/topic/41594-expanding-zigbee-mesh/page/2/> [forum]
