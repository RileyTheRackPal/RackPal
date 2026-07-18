I'll research this properly. Let me load the web tools and run a broad fan-out.# Professional Rack Wiring Documentation — Research Report

Scope: what integrators actually produce, so RackMate's PDF is something an installer will accept as a work instruction.

---

## 1. The Wiring / Cable Schedule (a.k.a. cable schedule, pull sheet, cable run list, wire schedule)

### 1.1 Terminology distinction (matters for UI naming)
| Term | What it really is | Audience |
|---|---|---|
| **Cable schedule / wire schedule** | Master table of every cable: ID, endpoints, spec. The design-time artifact. | Designer, PM, installer |
| **Pull sheet / cable pull schedule** | Rough-in subset: what to pull, from where to where, length, pathway. Usually *before* termination. Often lacks port-level detail. | Pull crew |
| **Cable run list** | Same data, run-ordered rather than ID-ordered. | Field |
| **Wire checklist** | Schedule + a tick-box status column, used as the field signoff sheet. D-Tools ships this as a distinct report. | Installer/QA |

RackMate should generate **one data table** and offer these as *filtered views/sort orders*, not separate data models.

### 1.2 Column set actually used in practice

Composite from EPC/industrial cable schedules, TIA-568 pull-schedule templates, and D-Tools' Wire Connections / Wire Checklist reports:

**Identity**
- `Cable ID` / `Wire ID` (unique, matches the physical label)
- `Bundle / Group ID` (optional — groups cables sharing a pathway or outlet)
- `Drawing ref` (sheet + detail where this cable appears; industrial schedules call it "single-line diagram reference")
- `Revision / added-in-rev`

**From endpoint**
- `From Device` (reference designator + manufacturer-model)
- `From Device ID` (D-Tools calls this Component ID)
- `From Location` (rack ID + RU, or room)
- `From Port / Terminal` (port label, e.g. `OUT 3`)
- `From Connector type` (HDMI-A, RJ45, F, XLR-M, Phoenix 3.5mm, IEC C13…)
- `From Termination` (field vs factory; T568A/B; LC/SC/MPO; solder/crimp/IDC/punch)

**To endpoint** — mirror of the above.

**Cable spec**
- `Signal Type` (HDMI, Network, RCA analog, IR, RS-232, RG6, S/PDIF, TOSLINK, speaker level, power…)
- `Cable Type / Part No.` (manufacturer + model, or generic spec: Cat6A F/UTP, 14/2 speaker, RG6 quad-shield)
- `Cores × gauge / CSA`
- `Shield / armour`, `Jacket rating` (CL3, CMP/plenum, riser CMR, LSZH)
- `Voltage / class`

**Physical**
- `Length` — note practice distinguishes *calculated* vs *cut* length, and industrial convention adds ~10% spare. As-built conductor length ≠ plan distance.
- `Path / Route` (tray, conduit ID, J-hook, floor/ceiling, direct-bury)
- `Pathway ID` / `Conduit ID`
- `Drum / reel number` (industrial; irrelevant for CI)

**Status & test**
- `Status` — Planned → Pulled → Dressed → Terminated → Tested → Issued
- `Test result` (Pass/Fail + headroom dB for copper certification; dB loss for fiber)
- `Test cert ID` (links to the Fluke/certifier report file)
- `Tested by / date`

**Other**
- `Notes / Remarks`
- `Fire rating`, `Hazardous area class` (industrial only — skip for CI)

### 1.3 Minimum viable column set for RackMate v1
`Cable ID | Signal Type | From Device | From Port | To Device | To Port | Cable Spec | Length | Path | Notes` — plus optional `Status` and `Test` columns toggled on for the field/as-built variant. That's the sweet spot: everything above it is EPC-industrial noise; everything below it is unusable in the field.

Sources: [Pathnovo cable schedule template](https://pathnovo.com/resources/templates/cable-schedule) · [InstruNexus cable schedule checklist](https://instrunexus.com/cable-schedule-check-list/) · [D-Tools Wire Connections report](https://support.d-tools.com/35_SI_2017_Documentation/User_Guide/05_Reports/1_Standard_Reports/Wire_Connections) · [D-Tools Wire Checklist](https://support.d-tools.com/38_SIX/User_Guide/05_Reports/01_Stock_Standard_Reports/Wire_Checklist) · [RMIT cable schedule](https://www.dlsweb.rmit.edu.au/Toolbox/electrotech/toolbox1204/resources/04diagrams/03electrical/07schedule.htm)

---

## 2. Cable Labelling & Identification Standards

### 2.1 ANSI/TIA-606 (Administration Standard for Telecommunications Infrastructure)

Current: **606-C** (July 2017); **606-D** exists. Voluntary, but universally cited in commercial specs.

**Four classes of administration** — scale-driven, they determine *which identifiers are mandatory*:

| Class | Applies to | Required identifiers |
|---|---|---|
| 1 | Premises served by a single equipment room | TS identifier, horizontal link, TMGB, TGB |
| 2 | Single building / tenant with multiple telecom spaces | Class 1 + building backbone cable, backbone pair/fiber, firestop location; *may* add pathway IDs |
| 3 | Campus (multiple buildings + OSP) | Class 2 + building identifier, campus backbone cable, campus backbone pair/fiber |
| 4 | Multi-campus / multi-site | Class 3 + campus/site identifier |

**Exact identifier syntax** (verbatim notation from the 606-A text as reproduced in Anixter's Standards Reference Guide — carried forward in 606-C):

```
fs                        Telecommunications Space (TS)
fs-an                     Horizontal link
fs-TMGB                   Telecom Main Grounding Busbar
fs-TGB                    Telecom Grounding Busbar
fs1/fs2-n                 Building backbone cable
fs1/fs2-n.d               Building backbone pair or optical fiber
f-FSLn(h)                 Firestop location
[b1-fs1]/[b2-fs2]-n       Campus backbone cable
[b1-fs1]/[b2-fs2]-n/d     Campus backbone pair or optical fiber
b                         Building
c                         Campus or site
```

Field definitions:
- `f` = numeric character(s) identifying the **floor** occupied by the TS
- `s` = alpha character(s) uniquely identifying the **space** on floor `f`
- `a` = one or two alpha characters identifying a **patch panel** (or group of panels with sequential ports, or an IDC block)
- `n` (horizontal) = **two to four numeric** characters designating the **port**
- `n` (backbone) = one or two alphanumeric identifying a single cable between `fs1` and `fs2`
- `d` = two to four numeric identifying a single **copper pair or optical fiber**
- `h` = one numeric character = firestop **hour rating**

So a horizontal link is literally `<floor><space>-<panel><port>` → e.g. `2A-A12`.

**Suggested alphanumeric element codes** (606 non-mandatory, but widely adopted):
`BCxxx` bonding conductor · `BCDxxx` backbone conduit · `Cxxx` cable · `CBxxx` backbone cable · `CDxxx` conduit · `CTxxx` cable tray · `ECxxx` equipment bonding conductor · `EFxxx` entrance facility · `ERxxx` equipment room · `Fxxx` fiber · `GBxxx` grounding busbar · `GCxxx` grounding conductor · `HHxxx` handhole · `ICxxx` intermediate cross-connect · `Jxxx` jack · `MCxxx` main cross-connect · `MHxxx` manhole · `PBxxx` pull box · `Sxxx` splice · `SExxx` service entrance · `SLxxx` sleeve · `TCxxx` telecom closet · `TGBxxx` telecom grounding busbar · `TMGB` · `WAxxx` work area

Worked examples from the standard: `J0001` (information outlet jack) · `D306` (work area) · `3A-C17-005` (closet 3A, column C, row 17, block position 005).

**Critically: "The actual format is not mandated by the standard. However, the chosen format must be consistent and provide a unique identifier number for each system element."** → RackMate should ship an *identifier format engine* (template string with tokens), not a hardcoded scheme.

**What must be labelled:** pathways, work area outlets, patch panels, racks and cabinets, ports, grounding busbars, cabling, firestop locations, telecommunications spaces, data center room grid.

**Placement rules:**
- All cables and pathways labelled **on both ends**
- Station connections may be labelled on the **faceplate**
- Labels **printed or mechanically generated** — handwritten is non-compliant
- Legible, permanent, durable; must not smear or fall off
- Labels must **match the records** (database/schedule) — i.e. the drawing, the schedule and the physical label are one dataset

**Colour conventions** (606-C recommends, does not mandate — may be colour labels or colour bands):

| Termination type | Colour | Pantone |
|---|---|---|
| Demarcation point / central office connection | Orange | 150C |
| Network connection (user side of CO) | Green | 353C |
| Common equipment (PBX, LAN, mainframe, mux) | Purple | 264C |
| Key system | Red | 184C |
| First-level backbone (Cabling Subsystem 3) | White | — |
| Second-level backbone (Cabling Subsystem 2) | Gray | 422C |
| Campus backbone (inter-building) | Brown | 465C |
| Horizontal (Cabling Subsystem 1) | Blue | 291C |
| Miscellaneous (alarms, security, energy mgmt) | Yellow | 101C |

Sources: [Cabling Install — 606-C requirements](https://www.cablinginstall.com/cable/article/14035166/tia-606-c-standard-requirements-for-cable-plant-administration) · [Anixter 606-A reference guide (PDF, exact syntax)](https://web.anixter.com/AXECOM/AXEDocLib.nsf/(UnID)/4D3AF1C46F90C8CE86256F8800792BF9/$file/ANSI-TIA-EIA-606-A.pdf) · [Brady 606-C](https://www.bradyid.com/resources/tia-606-c-cable-labeling-standards) · [TIA FOTC 606-D](https://www.tiafotc.org/tia-standards-update/tia-606-d/)

### 2.2 AVIXA F501.01:2015 — Cable Labeling for Audiovisual Systems

The AV-specific counterpart, and closer to what RackMate produces:
- Label placed **within two inches of the connector**
- **Printed self-laminating** label
- Masking tape, insulation tape, and handwritten permanent-marker labels **shall not** be used
- The label indicates **where the cable is/should be connected**
- Format examples given: `Input A` (a projector's VGA input) and, for an output, `VDA2 Out 3 to PROJ Input A` — i.e. **the AV convention labels by destination, not by an abstract cable number**
- **Power cabling** supplied as part of the AV system (in racks, desks, lecterns) shall also be labelled per the standard
- Multi-core/harness labelling defers to project documentation

Field practice (NCSU AV standard, representative): labels 1–3″ from the end, **all facing the same direction inside the rack**; format = `PORT IDENTIFIER + DEVICE NAME`, e.g. `OUT 1 Laptop`. Do *not* label network switch connections (rely on cable colour, label only the incoming feed); do not label cable type (redundant).

**A widely used AV block-numbering scheme:** first two digits identify the equipment, last two the port. A 16×16 matrix becomes `2301–2316` (inputs) and `2401–2416` (outputs); a 10-port switch becomes `XX01–XX10`. This **reserves IDs for unpopulated I/O** so future additions don't break the scheme. This is a strong default for RackMate's auto-ID generator.

Sources: [AVIXA F501.01](https://www.avixa.org/standards/cable-labeling-for-audiovisual-systems) · [NCSU AV Cable Labeling Standards](https://ncsu.service-now.com/kb_view.do?sys_kb_id=2a3b37e683dd2a54a35714326daad335) · [21st Century AV — labelling an AV rack](https://21stcenturyav.com/what-is-the-best-way-to-label-an-av-rack/)

### 2.3 Real-world commercial identifier practice (worth copying)

University of Colorado Denver Div 27 05 53 spec — a good model of a *fully resolved* 606 implementation:

```
Q20-1A-PRK01     Bldg Q20, Telecom Room 1A, Pathway(P) Rack(RK) #01
P28-1A-TGB01     Bldg P28, TR 1A, Telecom(T) Grounding Bar(GB) #01
Q20-1A-1FPL1     Bldg Q20, TR 1A, in rack #1, fiber panel 1
Q20-2A-5CPLA.05  Bldg Q20, TR 2A, term area 5, Copper Panel A, port 05
L10-1A-1A45      horizontal UTP originating Bldg L10, TR 1A, Rack 1, Panel A, Port 45
TV-3B-WA37       horizontal UTP, Bldg TV, TR 3B, Wall-mounted Panel A, Port 37
L28-1A/P28-1A,FSM1   backbone singlemode fiber between two TRs, index 1
P26-1A/Q20-GD,CUT1   backbone copper UTP between two TRs, index 1
NC-2F-2FMM01     horizontal multimode fiber, Bldg NC, TR 2F
```

Structure: `<location prefix> - <3-letter element acronym per 606> <index>`. Wall-mounted gear uses `W` where rack-mounted gear uses the rack index number. Note the **shorthand rule**: cable names are a shortened form of the port name so cable label ≠ termination label.

Source: [CU Anschutz 27 05 53 Identification for Communication Systems (PDF)](https://www.cuanschutz.edu/docs/librariesprovider260/design-and-construction/guidelines-and-standards/division-27/270553---identification-for-communication-systems.pdf?sfvrsn=5d9577ba_2)

### 2.4 How residential CI diverges from commercial

**There is no residential labelling standard.** TIA-606 assumes floors, telecom rooms, and patch panels; a house has one rack and rooms with names. Residential practice therefore:

1. **Names by room, not by floor/space code.** `LR-TV-2`, `OF-1`, `BR3-N-1`, `AP-HALL-1`, `CAM-DRIVE-1`.
2. **Multiple drops in a room** get suffixed by wall direction or by left-to-right sequence: `Bedroom 1A / 1B / 1C`, or `-N/-S/-E/-W`.
3. **Encodes signal type in the ID**, which 606 does not (606 puts it in the record, not the identifier).
4. **Colour-codes by service, not by 606 termination class.** Common residential jacket/label scheme: Blue = Data, White = Phone, Yellow = IR/HVAC control, Green = HVAC, Black = Coax/CATV, Grey = Alarm, Red = Fire.
5. **Labels twice per end** — two labels 2–4 ft apart on each end, so a label survives trimming/re-termination.
6. **The master record is a spreadsheet left in the equipment closet**, not a database.

Documented residential schemes:

**Scheme A — `TT-RRR-D-P`** (type–room–direction–port):
- `TT`: AC access control, CM camera, DO door operator, DR door strike, DS door sensor, ET ethernet, HD HD video, KP keypad, MS motion sensor, SH shades, SP speaker, TP telephone, TS thermostat, TV television, WO window operator, WS window sensor
- `RRR`: BA1–BA3, BR1–BR3, DIN, ENT, FAM, GAR, HAL, KIT, LIV, MED, OUT, PAT, SUN
- `D`: N/S/E/W/C, or compound NW/NE/EN/ES/SE/SW/WS/WN; for audio: FL/FC/FR/SL/SR/RL/RR
- `P`: port number (omitted when unnecessary)
- Examples: `DS-FAM-ES`, `ET-FAM-W-11`, `SP-FAM-SL`, `WS-SUN-E`

**Scheme B — `TT-LL-RRR-F-#-P`** adds a level digit: `MO-2-BRM-N-1` = media outlet, 2nd floor, master bedroom, north wall, device 1.

**Scheme C — `Area-Type-Run`**: `B-5-1` = Barn, Cat5, run 1; `B-22-2` = Barn, 22/4 security, run 2. Simplest, and the one that survives a house with unnamed rooms during rough-in.

Sources: [Quadomated wire naming convention](https://www.quadomated.com/technology/automation/home-automation-wire-naming-convention/) · [CocoonTech prewire naming convention thread](https://cocoontech.com/threads/prewire-naming-convention.17232/) · [Data Wire Solutions room-by-room guide](https://datawiresolutions.com/blog/how-to-wire-home-for-ethernet-room-by-room)

**Design implication for RackMate:** ship **all three schemes as templates** in a token-based identifier builder (`{type}-{room}-{dir}-{seq}`, `{area}-{type}-{run}`, `{floor}{space}-{panel}{port}`), let the user define room codes and type codes, and store **two IDs per drop**: the *field/outlet label* and the *rack/panel-port label*. The schedule must print both — that's the single most common on-site failure point.

---

## 3. Structured Wiring / Low-Voltage Rough-In — directly informs the "Structure" device

### 3.1 What the standard says: ANSI/TIA-570-D (Residential Telecommunications Infrastructure Standard)

Published July 2018 by TR-42.2. Covers single- and multi-dwelling units.

**Topology:** star / **home run**. Every outlet runs back unbroken to a central **Distribution Device (DD)** — no daisy-chaining. This is the architectural fact the Structure device models.

**Grades** — minimum media *per cabled outlet location* and at the DD:

| Grade | Balanced twisted-pair | Coax (75Ω) | Fiber |
|---|---|---|---|
| Grade 1 | 1 × Cat6A or higher | 1 | optional |
| Grade 2 | 2 × Cat6A or higher | 2 | optional (2-fiber) |
| Grade 3 | 2 × Cat6 or higher | 1 | **required** (2-fiber) |

**So the canonical residential bundle is Grade 2: 2 × Cat6/6A + 2 × RG6.** That is the default bundle RackMate should seed.

**Outlet quantity guidance** (per TIA-570, restated in Leviton's installer guide):
- Minimum one Ethernet outlet location in the kitchen, each bedroom, the family/great room, and the den/study
- Sufficient outlets along any unbroken wall space ≥ 12 ft
- No point along the floor line in any wall space more than 25 ft from an outlet

Sources: [TIA FOTC 570-D](https://www.tiafotc.org/tia-standards-update/tia-570-d/) · [trueCABLE 570-D explained](https://www.truecable.com/blogs/cable-academy/life-easier-ansi-tia-570-d-residential-communications-cable-best-practices-explained) · [TIA-570-D grade summary](https://github.com/totallyradnetworks/ANSI/blob/master/TIA%20570-D%20Residential%20Telecom%20Infa.md)

### 3.2 The Structured Media Panel / SMC

The **Structured Media Center (SMC)** (Leviton's trademark; generically "structured media panel," "distribution device," "media enclosure," "can") is a recessed in-wall enclosure — commonly 14″, 21″, 28″, 42″ — that consolidates every home run and hosts snap-in modules: patch panels, coax splitters/amps, telephone bridges, small switches, ONT/modem, power.

Key facts that shape the data model:
- The SMC is a **termination and consolidation point**, not a rack. It has module bays, not RUs.
- In higher-end CI jobs the SMC is *replaced or supplemented by* a real rack — the home runs then land on **rack-mounted patch panels**. This is RackMate's primary case.
- Sizing is driven by drop count, so a drop count total is a genuinely useful derived output.
- Low-voltage rough-in is deliberately routed in **separate stud bays from AC**, and the pull happens at framing stage; final termination and test happen after drywall. Hence **status tracking** (`Pulled` → `Terminated` → `Tested`) is meaningful, not decorative.

Sources: [Leviton Basic Residential Installer Guide (PDF)](https://leviton.com/content/dam/leviton/network-solutions/product_documents/brochure/Leviton-Basic-Residential-Installer-Guide.pdf) · [Leviton Structured Media Centers](https://leviton.com/products/residential/networking/structured-media-centers)

### 3.3 How arriving home runs are represented on a rack drawing

Three conventions, all in use:

1. **As a patch panel port map.** The dominant method. Each home run terminates on a numbered patch-panel port; the drawing shows the panel in the rack elevation, and a **port-to-drop schedule** maps `Panel A / Port 12 → BR3-N-1 (Bedroom 3, north wall, drop 1)`. TIA-606's horizontal link identifier `fs-an` *is* this mapping expressed as a string.

2. **As an off-rack source block on the signal-flow / riser drawing**, labelled "Structured Cabling — Field," "Home Runs," or "Building Infrastructure," with a bus of numbered leads entering the rack. On architectural drawings, J-STD-710 supplies a **"Demarcation for All Services"** symbol (Communications category) for exactly this.

3. **Via callout-tag shape.** J-STD-710 explicitly sanctions using tag *shape* to distinguish run types: *"the circular shape may be used to communicate 'home run' cables and the square shape may be used to communicate locally-run cables."* The rule must be documented in the legend/schedule and applied consistently across the whole set.

**Design implication:** the Structure device should be a first-class pseudo-device whose "ports" are **drops**, each carrying: `Drop ID`, `Room/Area`, `Outlet designation`, `Wall/direction`, `Media type`, `Bundle ID`, `Terminating panel + port`, `Status`, `Test result`. Drops should be creatable in **bundles** (one outlet = 2×Cat6 + 2×RG6 as an atomic add), because that's how they're specified, pulled, and priced. Render it in the wiring plan as a bordered "field/infrastructure" block outside the rack boundary — matching convention 2 — while the individual drops resolve onto real patch-panel ports inside the rack (convention 1).

---

## 4. Rack Elevation Drawings

### 4.1 What the sheet is
A **2D scaled elevation** of the rack showing equipment organisation by RU position. **Front and rear elevations are drawn separately, side by side on the same sheet** — the rear elevation is what makes the drawing useful for wiring, because that's where the connectors are.

### 4.2 Annotations carried

**On the rack frame:**
- **RU ruler** down one or both sides — numbered rack-unit scale, conventionally **1 at the bottom counting up** (matches how EIA-310 rack rails are punched and how techs count). Some shops number top-down; the tool should make this a project setting.
- **Rack ID / designator** (`RK-1`, `AV-01`, `Rack A`) — must match the ID used in the cable schedule's location column
- **Overall rack dimensions** (H × W × D) placed beneath the rack symbol, to define the enclosure/closet space required
- Depth ruler-bar (for rear/depth clearance checks)

**Per device:**
- Reference designator / equipment ID (the tag used on the signal-flow diagram and in the schedule)
- Device name and function
- Manufacturer and model number
- RU height and starting RU position
- Status flag: **new / existing / future** (standard AV symbol convention — future gear reserves RU space)
- Weight, and running weight total
- Power draw / current

**Sheet-level:**
- Title block, revision block, drawing scale
- Legend (symbols, status hatching, colour key)
- Accompanying auto-generated reports: **rack BOM** (racks, mounts, accessories), **overall dimensions**, and **AC current + ventilation totals** (CFM required vs breaker capacity)

### 4.3 Title block contents (standard construction-document practice)
Project name & address · Client/owner · Design firm / integrator name, address, contact, licence number · Sheet title · Sheet number · Discipline · Scale (or "NTS") · Issue date · Drawn by / Checked by / Approved by · Project number · Seal/stamp area · North arrow (plans only) · File reference.

J-STD-710 notes the **legend may be placed within the title block area** or in a separate rectangle in the drawing area, and that **any sheet lacking the legend must carry a note stating where the legend is shown** — a concrete, easy rule for RackMate's multi-page export.

### 4.4 Revision block
Columns: `Rev # | Date | Description | By`. Revisions accumulate downward; the current revision also appears in the title block. AVIXA D401.01 §6.1 makes a formal change record mandatory: *"A formal record of all project documentation and changes shall be maintained,"* and authority to make changes must be agreed at the first project meeting.

### 4.5 Sheet numbering — U.S. National CAD Standard (Uniform Drawing System)
Format: **`[Discipline][SheetType][Sequence]`** — 1–2 char discipline, 1 digit type, 2 digit sequence.

Discipline designators: G General · H Hazmat · V Survey · B Geotechnical · C Civil · L Landscape · S Structural · A Architectural · I Interiors · Q Equipment · F Fire Protection · P Plumbing · D Process · M Mechanical · E Electrical · W Distributed Energy · **T Telecommunications** · R Resource · X Other · Z Contractor/Shop Drawings · O Operations

Sheet type designators: **0** General (symbol legend, abbreviations, general notes) · **1** Plans · **2** Elevations · **3** Sections · **4** Large-scale drawings · **5** Details · **6** Schedules and Diagrams · 7–8 user-defined · 9 3D/isometric/photos

**This gives RackMate a defensible, free sheet-numbering scheme:**
`T0.01` legend/abbreviations · `T2.01` rack elevations front · `T2.02` rack elevations rear · `T6.01` signal flow/interconnect · `T6.02` wiring schedule · `T6.03` structure/drop schedule · `T6.04` BOM. Sequence numbers need not be contiguous — leave gaps for future sheets.

Sources: [Archtoolbox — construction document sheet numbers](https://www.archtoolbox.com/construction-document-sheet-numbers/) · [NCS v5 UDS sheet ID (PDF)](https://www.nationalcadstandard.org/ncs5/pdfs/ncs5_uds1.pdf) · [Symbol Logic rack elevations](https://www.symbollogic.com/drawings/rackelevations/) · [SmartDraw rack diagrams](https://www.smartdraw.com/rack-diagram/) · [Graphical Networks rack diagram guide](https://graphicalnetworks.com/blog-rack-diagrams-your-ultimate-guide/)

---

## 5. Signal Flow / Line Diagram Conventions (requirement #5 — schematic inspiration)

Established conventions, all directly implementable:

- **Left-to-right flow.** Sources on the left, destinations on the right. Follows reading order.
- **Devices as labelled rectangular blocks.** System-level diagrams show blocks without internal detail; **detailed** diagrams show every input, output, processing stage, and format conversion, with **port stubs on the block edges** — this is the "port pinout" look the requirement asks for.
- **Every device, signal path and connection point labelled**, including model numbers, and **the signal format annotated on each connection**.
- **Reference designators** on every block, matching the rack elevation and the schedule. This is the "netlist" binding: one designator, three documents.
- **Direction arrows** on every line.
- **Avoid crossing lines; where unavoidable, use bridge/hop symbols** to mark non-connections. (Orthogonal routing + hops is exactly the electronics-schematic idiom.)
- **Colour by signal type**, held constant across every document in the set. The de facto AV convention is **blue = video, red = audio, green = control, orange = network**. Note this *conflicts* with TIA-606's termination-class colours — RackMate should treat signal-type colour and 606 termination colour as **two separate, independently assignable colour dimensions**, and print the active key in the legend.
- **Three diagram levels** worth supporting as export filters: **System-level** (client-facing), **Detailed** (installer-facing), **Control signal flow** (RS-232 / IP control / IR / relay only).

Sources: [Kenny AV — signal flow diagrams guide](https://kennyavsolution.com/av-signal-flow-diagrams-guide/) · [avsyncstudio — signal flow + rack + wiring integration](https://avsyncstudio.wordpress.com/2026/02/27/how-signal-flow-diagrams-integrate-with-rack-and-wiring-diagrams/)

---

## 6. Symbols Standard: ANSI J-STD-710 (CEA/CEDIA-2039), January 2015

Joint CEA + CEDIA + InfoComm standard, developed by the CEA/CEDIA R10WG7 Residential Systems Documentation Working Group. **Free from the CEDIA resource library**, with downloadable `.dwg`, Visio `.vss`, and raster symbol files. This is *the* residential-CI drawing symbols standard, and AVIXA D401.01 normatively points to it.

**What it mandates:**

**Geometry** (at original drawing scale):
- A symbol is a circle, square, or distinctive shape; **all distinctive shapes must fit inside a 3/8″ (10 mm) circle**
- Circle diameter **0.35″ (9 mm)**; square **0.25″ × 0.25″ (6.35 mm)**
- **All line weights 0.014″ (0.35 mm / 1 pt)**
- Attribute text minimum **3/32″ (2.5 mm)**

**Eight categories**, mapped to MasterFormat:
| # | Category | MasterFormat |
|---|---|---|
| 1 | Audio–Video Systems | 27 41 00 |
| 2 | Communications | 27 00 00 |
| 3 | Electronic Safety and Security | 28 00 00 |
| 4 | HVAC / AIRCON | 23 00 00, 23 09 00 |
| 5 | Control | 25 00 00, 27 00 00, 28 00 00 |
| 6 | Vacuum Cleaning Systems | 11 24 19 |
| 7 | Furnishings (**includes Rack or Head End**) | 12 00 00, 27 00 00 |
| 8 | Electrical | 26 00 00 |

**Four optional text attributes** positioned around/inside the symbol:
- `M` = Mounting Type
- `T` = Primary Technology (key description)
- `T2` = Secondary Technology
- `X` = **Legend or Schedule Reference** — alphanumeric linking symbol → schedule row

Example: a loudspeaker with `C` (ceiling) / `LR` (LR bar speaker) / `P` (powered) / `A3` (see schedule A3).

**Mounting abbreviations:** C ceiling · D desk/table · F flush · FL floor · G ground · H hidden · M mullion · O outdoor · P pedestal · **RK rack** · R roof · REC recessed · S surface · W wall.
Elevation may be folded into the attribute: `W18`, `W18AFF`, `W60OC`, `W84U` — where AFF = above finished floor, OC = on centre, U = underside edge. ISO variants use mm: `W300`, `W1800`, `W2100U`.

**Callout tags** — rectangle 0.6″ × 0.38″, circle 0.6″ dia, hexagon 0.6″ × 0.52″; three identifiers (Primary/Secondary/Tertiary); connected to the symbol by a straight or curved leader ending in a closed arrow or circle. **Tag shape may encode run type (home-run vs local) provided the rule is documented in the legend and applied consistently across the entire drawing set.**

**Legend — must include:** legend reference number, image of each symbol used in the set, and a description. May additionally include symbols-with-attributes, repeated symbols with different reference numbers, equipment type, and scaling information.

**Schedule — must be:** table format, with a heading and **a minimum of three columns**. The standard's own sample Floor Plan Device Schedule uses `Area Name | Reference | Item (Manufacturer/Model) | Item Description`. Schedules may be separate documents or grouped in a General Schedules section.

**Symbol stretching:** certain symbols may be stretched to real dimensions — **"Rack or Head End" is explicitly on the stretchable list**, alongside displays, projection screens, PV arrays, etc. The standard's own example legend row: `84" x 24" x 24" Rack (2134mm x 610mm x 610mm)`, Tech1 = `AV`, Tech2 = `24X`, X-Legend = `RK84`.

Sources: [ANSI J-STD-710 full text (PDF)](https://s3.us-east-1.amazonaws.com/fonteva-customer-media/00Df2000001A4QdEAK/mzhFwHOl_sPWGrIHx_ANSI_J_STD_710_FINAL_2_pdf_pdf) · [ANSI preview](https://webstore.ansi.org/preview-pages/ANSI/preview_ANSI+J-STD-710-2015.pdf) · [AVIXA press release](https://www.avixa.org/about-us/press-room/2015/04/08/cea-cedia-infocomm-release-joint-architectural-drawing-symbols-standard)

---

## 7. AVIXA D401.01 — Documentation Requirements for Audiovisual Systems

**The single most directly applicable standard to this project.** ANSI/AVIXA D401.01:2023 (formerly INFOCOMM 2M-2010). It defines *the minimum documentation set*, tiered by project complexity — which is effectively a spec for RackMate's PDF export.

**Project classification** by additive point score across: geographic spread, number of sites, budget, technical complexity, number of rooms/room types, number of other trades, subcontract/union labour, number of key stakeholders, risk factors, resources required, project schedule urgency.
→ **Simple = 11–15 pts · Moderate = 16–21 pts · Complex = 22+ pts**

**Simple project — required documentation (9 items):**
1. **Scope of Work** — description or functional narrative + performance verification test metrics
2. **Bill of Materials** — all system components; may include description, serial number, TCP/IP and MAC information, warranty details
3. **Architectural Locational Information** — device locations + infrastructure requirements; *"If architectural drawings are used, device symbols (see J-STD-710...) should be included"*; notes should include mounting height, back boxes, structural mounting details; **scaled drawings preferred but not required**
4. **Architectural References and Details** — elevational, isometric or other views with key dimensions
5. **System Interconnection Information** — *"typically a drawing... that includes detailed information on how each component in the system is connected. This may include part numbers, cable type, cable labels, detailed network information..."* ← **this is RackMate's wiring plan + schedule, named by the standard**
6. **Equipment Mounting Information** — *"the location and placement of equipment inside of any equipment rack (See AVIXA F502.01:2018...)... should include part numbers and detailed rack or location identification"* ← **this is the rack elevation**
7. **System Performance Verification** — per ANSI/INFOCOMM 10:2013
8. **As Built Documentation** — corrections to reflect final installed condition; *"considered essential by owners for all future service and maintenance"*
9. **Closeout Requirements List**

Plus, at every level: **Responsibility Assignment Matrix** (RACI) and **Project File Record** (document registry with author, due dates, completion dates, recipients, links).

**Moderate adds three — note item 1 is literally a spec for a drawing-set front matter:**
1. **Detailed Project Information** — *"These drawings begin the drawing package and should include a **cover page, drawing index, schedule of responsible parties, symbol key, abbreviations, and any general or specific project notes**. A cover page should include identification information for the project team, construction team, architect, owner, and other related trades."*
2. **Individual Device Details** — installation specifics, **custom pin configurations**, plate/panel details; must be cross-referenced from the architectural and interconnection drawings
3. **Cable Pathway Information** — pathways and cables between components/endpoints; supporting infrastructure, direct point-to-point connections, cable type

**Complex adds four:** Project Schedule · Architectural Section Information · Display Information (viewing arcs/angles per V202.01) · Audio Coverage Information (per A102.01).

**Conformance** requires: a completed RAM, a completed Project File Record, and receipt of all documentation elements for the project's class.

Source: [AVIXA D401.01 technical review draft (PDF, full text)](https://cdn.avixa.org/production/docs/default-source/default-document-library/d401.01_tech_review.pdf?sfvrsn=79289167_1%2FD401.01_Tech_Review.pdf) · [AVIXA published standards](https://www.avixa.org/standards/current-standards)

### Related AVIXA standards worth citing in the app
- **F501.01:2015** Cable Labeling for Audiovisual Systems (§2.2 above)
- **F502.01:2018** Rack Building for AV Systems — rack assembly, equipment mounting, **cable management incl. planning, lacing, location, and separation of signal and power cables**, final cleaning/labelling/finishing. *"Planning for the use of this Standard should begin during the project design phase."*
- **F502.02:2020 (R2023)** Rack Design for AV Systems — minimum rack planning and design requirements incl. required **process inputs and outputs**: rack selection, thermal management, power system design, earthing/bonding. Design inputs explicitly include system design documentation, rack location/environment, and **entry/connection method for site cabling** ← the Structure device's justification, in a standard.
- **D402.02:2013 (R2024)** AV Systems Performance Verification (formerly INFOCOMM 10:2013)

Sources: [AVIXA F502.01 release](https://warmup.avixa.org/about-us/press-room/2018/09/19/avixa-releases-rack-building-standard-for-audiovisual-systems) · [AVIXA F502.02](https://www.avixa.org/standards/rack-design-for-av-systems)

---

## 8. The CI Deliverable Set — and what RackMate's PDF should emit, in order

### 8.1 Full professional deliverable set
Cover sheet · Drawing index · Symbol legend + abbreviations + general notes · Floor plans & reflected ceiling plans (device locations) · Architectural elevations/sections · **Rack elevations (front + rear)** · **Signal flow / line diagram** · Wiring & riser drawings · Plate/panel details & pin configurations · **Cable/wiring schedule** · **Equipment list / BOM** · Manufacturer datasheets & cut sheets · **Network/IP schedule** · **Power schedule** · Product substitution documentation · Revision notes · Performance verification report · As-builts & closeout package.

### 8.2 Recommended RackMate PDF export — order and scope

**v1 — ship these, in this order:**

| # | Sheet | NCS no. | Content | Backing |
|---|---|---|---|---|
| 1 | **Cover sheet** | `T0.00` | Project name/address, client, integrator + contact, date, revision, sheet index | D401.01 "Detailed Project Information" |
| 2 | **Legend & notes** | `T0.01` | Signal-type colour key, connector/symbol key, abbreviations, general notes, ID-format explanation | J-STD-710 §3.6.1; D401.01 |
| 3 | **Rack elevation — front** | `T2.01` | RU ruler, device blocks, designator + name + model + RU span, status, dimensions, running weight/power totals | D401.01 "Equipment Mounting Information"; F502.01/.02 |
| 4 | **Rack elevation — rear** | `T2.02` | Same frame, rear faces, connector fields visible | Universal practice |
| 5 | **Wiring plan / interconnect diagram** | `T6.01` | Orthogonal traces, port stubs, colour by signal type, arrows, hops, reference designators | D401.01 "System Interconnection Information" |
| 6 | **Wiring schedule** | `T6.02` | The §1.3 column set, sorted by Cable ID | D401.01; TIA-606 records requirement |
| 7 | **Structure / home-run drop schedule** | `T6.03` | Drop ID, room, outlet, media, bundle, → panel/port, status | TIA-570-D; TIA-606 `fs-an` |
| 8 | **Equipment list / BOM** | `T6.04` | Qty, designator, manufacturer, model, description, RU, rack/location | D401.01 "Bill of Materials" |

**v1.1 / v2:**

| # | Sheet | NCS no. | Content |
|---|---|---|---|
| 9 | Network / IP schedule | `T6.05` | Device, designator, hostname, IP, subnet, MAC, VLAN, switch + port, PoE class |
| 10 | Power schedule | `T6.06` | Device, designator, plug type, V, A/W draw, PDU + outlet, circuit, running total vs breaker |
| 11 | Plate/panel details & pinouts | `T5.01` | Custom pin configurations, connector plate layouts |
| 12 | Field pull sheet | — | Wiring schedule filtered to rough-in fields + blank status/test columns |

**Ordering rationale:** general → plans/elevations → diagrams → schedules, which is exactly the NCS sheet-type ordering (0 general, 2 elevations, 6 schedules & diagrams) and matches how submittal packages are assembled (cover → index → BOM → diagrams → elevations → details → revisions).

**One hard rule to enforce in export:** every sheet that omits the legend must carry a note stating which sheet carries it (J-STD-710 §3.6.1). Cheap to implement, immediately signals competence.

Sources: [XTEN-AV submittal package guide](https://xtenav.com/blog/av-submittal-package-guide/) · [Data Projections — the AV design process](https://www.dataprojections.com/About/Insights/what-is-the-av-design-process/) · [AutomationForum IP address schedule](https://automationforum.co/ip-address-schedule/)

---

## 9. Concrete design implications for RackMate

1. **One dataset, many views.** Diagram, rack elevation, and schedule must be projections of the same graph. TIA-606's core requirement is that labels **match the records**; D401.01's as-built requirement means every view must regenerate from one source. Never store the schedule separately from the connection graph.

2. **Identifier format engine, not hardcoded IDs.** 606 explicitly declines to mandate a format but requires consistency and uniqueness. Ship a token template (`{floor}{space}-{panel}{port}`, `{type}-{room}-{dir}-{seq}`, `{area}-{type}-{run}`, `{devIdx}{portIdx}`) with the three residential schemes and the 606 commercial scheme as presets. Validate uniqueness project-wide.

3. **Two IDs per connection endpoint.** The field/outlet label and the rack/panel-port label. Print both. This is where jobs go wrong.

4. **Reserve-ID / block-numbering support.** The `2301–2316` / `2401–2416` matrix convention requires allocating IDs to *unpopulated* ports so future adds don't renumber. Model ports as first-class entities with IDs whether or not they're connected.

5. **Two independent colour dimensions.** Signal-type colour (blue video / red audio / green control / orange network, plus your RCA/IR/RS-232/coax/SPDIF/TOSLINK/speaker/power types) *and* optional TIA-606 termination-class colour. Both print into the legend.

6. **Bundles are the residential unit of work.** "Add outlet: Grade 2" should create 2 × Cat6A + 2 × RG6 as one bundle with one outlet designation and four drop IDs. Support Grade 1/2/3 presets from TIA-570-D.

7. **Status is real, not decorative.** Planned → Pulled → Dressed → Terminated → Tested → Issued, plus test result and cert reference. It's what turns the design PDF into the as-built PDF, which D401.01 calls essential.

8. **Front and rear are separate elevations of the same rack object.** Devices need a `depth`/`face` notion and rear connector fields; the rear elevation is the one installers actually use.

9. **RU ruler direction is a project setting** (bottom-up default), and rack dimensions print beneath the elevation.

10. **The Structure device maps to a real standard.** It is the TIA-570-D **Distribution Device** / demarcation point. Render it as a bordered field-infrastructure block outside the rack, with drops resolving onto in-rack patch panel ports. J-STD-710 gives you both a "Demarcation for All Services" symbol and an explicit sanctioned convention for distinguishing home-run from local runs by tag shape.

11. **Free, citable standards to lean on:** J-STD-710 (free from CEDIA, with CAD/Visio symbol files you can trace for iconography) and the D401.01 draft. Being able to state "conforms to J-STD-710 symbol geometry and AVIXA D401.01 minimum documentation" is a genuine commercial differentiator against generic diagramming tools.