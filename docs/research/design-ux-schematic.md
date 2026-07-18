# RackMate — Wiring / Schematic Editor Specification

**Document:** `SPEC-SCHEM-001` · v1 draft · target Flutter desktop (Dart 3.12)
**Scope:** the schematic canvas, its visual language, its interaction model, its layout engine, and its relationship to the other views.

---

## 0. Design thesis (read this first — everything follows from it)

Three commitments, stated up front because the rest of the document is downstream of them.

**0.1 — The schematic is a *derived projection*, not a drawing.** The document stores **connectivity only**: `Connection(uuid, fromPortRef, toPortRef, domain, media, label, layerId, sheetId, routeOverrides?)`. No wire coordinates. No route geometry. Symbol positions are stored (they're user intent) but wire geometry is *always* recomputed. This is the KiCad/Q-SYS model and it is why the tool can never drift out of sync with itself, why the wiring schedule is trivially exact, why the PDF is vector, and why the router is a one-file swap. If you ever find yourself persisting a polyline, you have made an architectural error.

**0.2 — Constraint is the feature.** A typed netlist with enforced rules is the entire wedge against Visio, Lucidchart, and AVSnap. The moment the canvas allows an arbitrary line between two arbitrary points, RackMate is a worse draw.io. **There is no free-line tool. Ever.** Every stroke on the canvas is a `Connection`, a `Bus`, an annotation, or chrome.

**0.3 — The schematic is a navigational aid; the schedule is the truth.** This is the release valve that makes density tractable. Any connection may be rendered as a drawn wire, a net label, or a bus member — three renderings of one identical model object, switchable per-net, losslessly, at any time. When the diagram gets dense, we *degrade the rendering*, never the model. The PDF always ships both.

---

## 1. Visual language

### 1.1 Coordinate system and grid

| Constant | Value | Notes |
|---|---|---|
| Base grid unit `U` | **25 tenths-mm (2.5 mm)** | integer; all schematic geometry is a multiple |
| Pin pitch | **2U (5.0 mm)** | KiCad uses 100 mil ≈ 2.54 mm; 5 mm gives room for AV's long port labels |
| Pin stub length | **2U (5.0 mm)** | |
| Minimum body width | **20U (50 mm)** | |
| Body corner radius | **0** | schematics have square corners; rounded reads as "flowchart" |
| Track pitch (routing gutter) | **2U (5.0 mm)** | |
| Gutter clearance from body | **4U (10 mm)** | |
| Snap grid (default) | **1U** | `Alt` = free (0.1 mm), `Shift` = 4U coarse |

Everything is stored as `int` tenths-of-a-millimetre. No doubles in the model, ever — `173.99999999999997` in a `.rackmate` file is a bug that will surface in cloud-sync conflict resolution three years from now.

**Grid rendering.** Dot grid at 4U (10 mm) in light theme, 15% ink. Line grid is too loud behind orthogonal wires — the wires *are* lines and the grid competes. Below 0.35× zoom the grid is suppressed entirely. Draw it as a single GPU fragment-shader quad (lift the technique from `fl_nodes`' `grid.frag`) — infinite, zoom-independent, zero CPU, no re-baking.

### 1.2 The device symbol

A `DeviceSymbol` is a body rectangle with a header block and pins on its four edges.

```
Body anatomy (top to bottom):
  ┌ header band, height 6U ────────────────────────────┐
  │  REFDES  (3.5 mm cap, bold, left)   [badges, right]│
  │  Name    (2.5 mm, regular, left)    RU / face (2.0)│
  ├ hairline rule ─────────────────────────────────────┤
  │  pin field, height = (maxPinsPerSide + 1) × 2U     │
  └────────────────────────────────────────────────────┘
```

**Header contents, in fixed order:**

- **Reference designator** — `MTX1`, `AMP2`, `SW1`, `AVR1`, `STR`. Auto-assigned on placement from a per-archetype prefix, uniqueness enforced at the model layer. This is P0 and non-negotiable — XTEN-AV's users are on record complaining that they cannot uniquely name devices, and a rack with three identical amps that cannot be distinguished cannot produce a correct cable schedule. Everything keys off this field: labels, schedule rows, callouts, off-sheet tags, PDF cross-references.
- **Instance name** — user-editable free text ("Head End Matrix"). Cosmetic.
- **Right-aligned metadata** — `2RU · U14–U15 · REAR`, plus badges: 📌 pinned placement, ⚠ has DRC warnings, ⛔ has DRC errors, 👁 partially filtered, `A/B/C` unit letter if the symbol is split.

**Edge assignment — the opinionated part.** EE convention is inputs-left / outputs-right, power-top / ground-bottom. That maps to AV as follows, and this mapping is *better* than the naive one because it matches physical cable gravity in a rack:

| Edge | Carries | Rationale |
|---|---|---|
| **Left** | Signal **inputs** (sinks) | reading order; sources feed from the left |
| **Right** | Signal **outputs** (sources) | |
| **Top** | Control + network: RS-232, RS-485, IR, contact closure, LAN, Cresnet, DMX | these are the "nervous system"; they route to a control gutter above the signal plane and never tangle with A/V |
| **Bottom** | **AC power** inlets, and only those | power physically falls to the PDU at the rack bottom; putting it on the bottom edge means the power net is a single clean comb that never crosses a signal wire |
| Either | Bidirectional (eARC-bearing HDMI, USB-C, fiber duplex) | placed on the side matching its **dominant** direction; the return channel renders as a counter-arrow on the same pin |

**Does left/right survive 40 ports?** No — not naively, and pretending otherwise is how you get a 900 mm tall symbol nobody can read. Three escalating mechanisms, applied automatically with manual override:

**(a) Port banks (≤ 16 pins/side).** Contiguous pins are grouped into a labelled bank with a bracket in the margin and a 1U separator gap between banks. A bank has a name (`HDMI IN`, `MIC IN`, `ZONE OUT`), an optional index range, and a fold triangle.

```
    ┌ HDMI IN ┐          ┌ ZONE OUT ┐
 ◈──┤ J01  1  │       │  1  J09 ├──◈
 ◈──┤ J02  2  │       │  2  J10 ├──◈
     …                     …
```

**(b) Unit splitting (17+ pins/side).** The symbol splits into **units** sharing one refdes: `MTX1:A`, `MTX1:B`, `MTX1:C`. This is exactly how KiCad handles a 256-pin FPGA and it is the right answer here. A 16×16 HDMI matrix becomes `:A` (inputs 1–8 / outputs 1–8), `:B` (inputs 9–16 / outputs 9–16), `:C` (control + power + IR). Units may live on **different sheets**. Each unit body shows `MTX1:B` in the header and a small "1 of 3" chip; hovering any unit outlines its siblings. The schedule is unaffected — it's all one device.

  Hard rule: **no symbol edge ever carries more than 16 pins.** At 17 the splitter fires. Override exists but warns.

**(c) Vector pins (bus collapse).** A bank of ≥ 4 homogeneous ports may collapse to a single **vector pin** rendered with a bus-weight stub and a bracketed label: `IN[1..8]`. One wire leaves it — a bus. Members are addressed as `MTX1.IN[3]`. Toggle per bank with `Ctrl+Shift+B` or the bank's fold triangle. Collapsed banks still route individually in the schedule; the collapse is *purely graphical* (KiCad's "bus entries do not establish electrical connections" — the bus is a rendering, the netlist is unchanged).

**Symbol sizing.** Width = `max(20U, textWidth(refdes+name) + 8U, maxLeftLabel + maxRightLabel + 12U)` rounded up to 2U. Height = `6U (header) + (max(leftPins, rightPins) + 1) × 2U`, minimum 16U. Top/bottom pins distribute across the width at 2U pitch, centred.

### 1.3 Port / pin rendering

A pin is three composed elements, outward from the body: **[body edge] — stub — [direction arrow] — [connector glyph]**.

**Direction encoding (on the stub):**

| Direction | Rendering |
|---|---|
| Sink (input) | solid arrowhead **pointing into** the body, at the body edge |
| Source (output) | solid arrowhead **pointing away**, at the stub's outer end |
| Bidirectional | arrowheads at both ends |
| Bidirectional with return channel (eARC) | primary arrow solid; return arrow **hollow**, half-size, opposite direction, offset 0.5U |
| Passive (patch-panel pass-through, splitter, barrel) | no arrow; stub is a plain line |
| Bus node (RS-485, DALI, 70 V tap, RF tap) | short perpendicular tick at the outer end — the classic multi-drop stub |
| Power inlet | arrow into body |
| Power outlet | arrow out of body |

**Connector glyph vocabulary.** Drawn at 2U (5 mm) nominal, on the pin axis, outboard of the arrow. Every glyph must be distinguishable at 8 device pixels and in 1-bit black-and-white. These are line drawings, not icons.

| Connector | Glyph | Mnemonic |
|---|---|---|
| RCA / phono | ◎ concentric circle with centre dot | it *is* a concentric connector |
| BNC | ⊙ circle with two short bayonet ticks at 10 & 4 o'clock | the bayonet lugs |
| F-type | ⬡ hexagon with centre dot | the nut |
| XLR-3 | ○ circle with 3 dots in a triangle | pin count is the point |
| XLR-5 (DMX) | ○ circle with 5 dots | distinguishes DMX at a glance |
| 1/4" TRS | ▬ elongated bar with 2 ring notches (TS = 1 notch) | the plug profile |
| 3.5 mm TRS/TS | same, half length | |
| RJ45 | ⌂ keystone trapezoid, 8 tick marks on the wide edge | the latch + 8 contacts |
| RJ45 carrying **HDBaseT** | same trapezoid, **doubled outline** | ⚠ this must never look like Ethernet |
| HDMI | flat asymmetric trapezoid (one chamfered corner) | the actual shell |
| DisplayPort | rectangle with one chamfered corner, opposite side | |
| USB-C | rounded oblong (stadium) | |
| TOSLINK | ▢ square with an inset chevron (light ray) | optical |
| Euroblock / Phoenix | ▭ rectangle with 2–5 screw-slot ticks on the top | screw terminals, tick count = pole count |
| Binding post | ⊕⊖ two filled circles, `+` above `−` | polarity is visible |
| SpeakON | ○ circle with a keyed notch at 12 o'clock | |
| DB9 | D-shaped shell with 5 dots over 4 dots | |
| IEC C13/C14 | rounded-rect with a flat bottom, 3 pin dots | |
| IEC C19/C20 | same, wider, heavier outline | |
| NEMA 5-15/20R | rect with two parallel slots + a round ground below | 20 A = one slot T-shaped |
| SFP / LC duplex | two small rects side by side | |
| Punchdown / bare | fork/spade outline | structured-wiring rough-in |
| Undetermined (Structure rough-in) | ◇ hollow diamond | "not yet assigned" |

**Gender** is drawn as glyph fill — **filled = female/jack, hollow = male/plug** — but *only* for connector families where gender is load-bearing (XLR, IEC, DB9, SpeakON, fiber). Everywhere else glyphs are filled by default. Overloading the encoding on every connector costs more legibility than it buys.

**Glyph tint** = the domain colour of the port's `signalFamily` (§1.4). So an RJ45 carrying Ethernet is green, an RJ45 carrying HDBaseT is blue *and* double-outlined. The two most dangerous ports in the whole taxonomy are now impossible to confuse.

**Pin labels.** Inside the body, 1.8 mm, 1U inboard of the edge. Two-column layout per side: `J01  HDMI IN 1` on the left (designator then label, left-aligned), `OUT 3  J09` on the right (label then designator, right-aligned). Truncate with `…` at 40% of body width; full text in tooltip and Properties.

Designators follow ASME Y14.44 / IEEE 315: **`J###` = port (fixed connector), `W###` = cable run, `P###` = cable end.** Adopting this makes the drawing legible to anyone who has ever read a schematic, and it makes the schedule self-documenting.

**Level of detail (LOD).** Non-negotiable for performance and legibility:

| Zoom | Rendering |
|---|---|
| ≥ 0.80× | full: glyphs, labels, designators, bank brackets |
| 0.40–0.80× | glyphs + labels, designators suppressed |
| 0.20–0.40× | pin = 3 px coloured tick, no glyph, no label; body header shows refdes only |
| < 0.20× | body = filled block tinted by dominant domain, refdes only if it fits |

### 1.4 Wire rendering

**Colour encodes *domain*, not type.** There are ~43 signal types in the taxonomy. No palette is CVD-safe past 8–9 categories — Okabe–Ito deliberately stopped at eight. Giving each cable type a hue guarantees an unreadable drawing. So: **hue = domain (7 + structure), dash = type-within-domain, tag pill = exact type.** Three independent channels, degrading gracefully.

| Encoding | Survives CVD | Survives greyscale | Survives fax/photocopy |
|---|---|---|---|
| Hue | ✅ | ❌ | ❌ |
| Dash pattern | ✅ | ✅ | ✅ |
| Tag pill text | ✅ | ✅ | ✅ |

#### Palette — light/print theme (canonical; PDF always uses this)

| Domain | Hex | Dash (in U) | Weight | Tag prefixes |
|---|---|---|---|---|
| **Digital video** — HDMI, DP, SDI, HDBaseT, AVoIP | `#0072B2` | solid | 1.0× | `HD` `DP` `SDI` `HBT` `AVIP` |
| **Analog video / RF** — CVBS, YPbPr, VGA, CATV, SAT, OTA | `#56B4E9` | `12,4` long dash | 1.0× | `CVBS` `YPBPR` `RF` `SAT` |
| **Analog audio** — line, XLR, speaker, sub, phono | `#E69F00` | `6,3` dash | 1.0× | `AUD` `SPK` `SUB` `MIC` |
| **Digital audio** — S/PDIF, TOSLINK, AES3, Dante | `#D55E00` | `6,3,1,3` dash-dot | 1.0× | `SPD` `OPT` `AES` `DNT` |
| **Network** — Ethernet, PoE, fiber | `#009E73` | solid | 1.5× | `NET` `PoE` `FIB` |
| **Control** — IR, RS-232/485, contact, trigger, Cresnet, DALI, KNX, DMX | `#CC79A7` | `1,3` dot | 0.75× | `IR` `232` `485` `DMX` `CN` |
| **Power** — AC, IEC, PDU | `#000000` | `8,3,1,3,1,3` dash-dot-dot | 2.0× | `PWR` |
| **Structure** — unassigned home run | `#999999` | `6,3` dash | 0.75× | `STR` |
| *Selection / focus only* | `#F0E442` | — | — | never a cable |

This is Okabe–Ito mapped onto trade convention (blue = video, warm = audio, green = network, purple = control) so installers read it correctly on first sight. Yellow is reserved for interactive highlight and is never a cable — at 0.744 relative luminance it is illegible as a thin line on white paper.

**Honest caveat, and why the dash layer is mandatory rather than decorative.** The claim that Okabe–Ito "works in greyscale" is overstated. Computing WCAG relative luminance shows two collision bands:

- Sky Blue `#56B4E9` (0.401) vs Orange `#E69F00` (0.416) — **1.5% apart, indistinguishable in greyscale**
- Vermillion (0.222) / Green (0.257) / Purple (0.293) — a crowded 0.07 band

The collisions were placed deliberately: sky-blue/orange is analog-video vs analog-audio, which receive maximally different dash patterns (long dash vs short dash) and unmistakable tags. **Never rely on hue alone in export.** Ship a **Greyscale-safe export toggle** that drops hue entirely and renders domain purely via dash + weight + tag. It will be the setting every integrator who prints on the office laser actually uses.

#### Palette — dark theme (screen only)

Power inverts; everything else lightens to clear 4.5:1 against `#12161A`.

| Domain | Dark hex |
|---|---|
| Digital video | `#4DA6DD` |
| Analog video / RF | `#8ACFF5` |
| Analog audio | `#F0B443` |
| Digital audio | `#F07A33` |
| Network | `#2FC79A` |
| Control | `#E29CC3` |
| **Power** | `#E8E8E8` *(inverted — black is invisible)* |
| Structure | `#A8A8A8` |
| Selection | `#F5E76B` |

Dash patterns, weights, and tags are **identical across themes**. Only hue moves. And the switch is view-only: `theme` is a UI preference, never persisted in the document.

#### Line weights

Screen weights are **zoom-independent** (multiply by `1/viewport.scale` when painting inside the transformed canvas). Print weights are absolute.

| Class | Screen (device px) | Print (pt) |
|---|---|---|
| Control (0.75×) | 1.2 | 0.5 |
| Signal (1.0×) | 1.6 | 0.7 |
| Network (1.5×) | 2.4 | 1.0 |
| Power (2.0×) | 3.2 | 1.4 |
| Bus trunk | 4.8 | 2.1 |
| Selection halo | +5 behind, `#F0E442` @ 55% | n/a (selection never prints) |

Minimum print stroke 0.5 pt; dash period ≥ 1.5 mm or it blurs to solid at 300 dpi.

#### Arrowheads, dots, hops

- **Arrowhead at the sink end only.** A line with no arrowhead reads as bidirectional or as a bus. Filled triangle, 1.2U long × 0.8U wide, placed 0.5U before the target pin's arrow so the two don't collide.
- **Bidirectional** = arrowheads both ends. **eARC / ARC** = primary filled arrowhead at the sink, plus a **hollow half-size counter-arrow** at 30% along the run — one physical link, two logical signals, and the drawing must say so.
- **Junction dots** only at genuine multi-drop junctions (splitter, 70 V bus, RS-485 spur, IR block). Radius = 2× local stroke width, minimum 4 device px, filled in the wire colour.
- **Forbid 4-way junctions in the geometry emitter.** A 4-way dot that loses its dot silently becomes a crossover, and vice versa. Always stagger into two T-junctions ≥ 2U apart. This is modern drafting best practice and it costs one line in the emitter.
- **Crossing hops:** semicircular arc, radius 1.2U, always drawn on the **horizontal** segment (consistency matters more than which). **Default ON.** IEEE drafting practice recommends straight crossovers with dot-only disambiguation — but our reader is an AV installer, not a board designer, and hops read as friendly and unambiguous to that audience while removing the "did the dot get lost in the photocopy?" failure entirely. Preference: `Hops: arc / gap / none`. `gap` (break the horizontal, don't arc) is the compromise for users who find arcs fussy.
- **Corner radius** on wire bends: 0.6U fillet. Pure square corners read as harsh at screen resolution; anything larger reads as a flowchart.

#### Tag pills

Every drawn run carries a tag pill at **both ends** (2U outboard of the source pin, 2U inboard of the sink pin) and at any sheet break:

```
 ┤W042│HDMI│25'├
```

Rounded 1U-radius capsule, 1.6 mm text, wire colour as a 0.5 px outline, paper-coloured fill so it knocks out the grid. Content is configurable: `{tag} · {type} · {length}` default; `{tag}` only in dense mode; `{tag} · {sourceRef}:{port} → {sinkRef}:{port}` in verbose. Pills are the encoding that never fails — they survive CVD, greyscale, fax, and a bad phone photo taken in an attic.

Optional **fourth channel** for the worst reproduction cases: a domain marker glyph at the run midpoint (▲ video · ● audio · ■ network · ◆ control · ⬛ power). Off by default; on in the greyscale export profile.

### 1.5 Net labels and off-sheet connectors

Three renderings of the same `Connection`. Switchable per-net, losslessly, at any time.

**Net label (flag).** A directional pennant at the pin, replacing the drawn wire:

```
source end:   J09 ├──⟩ HDMI_GR_TV        sink end:   HDMI_GR_TV ⟨──┤ J03
```

Right-pointing chevron = signal leaving; left-pointing = arriving. Filled in domain colour at 12% with a full-strength outline; text at 2.0 mm in the domain colour. Both flags of a net show the identical string and highlight together on hover.

**Off-sheet connector.** Same pennant, doubled outline, with a sheet/zone reference:

```
J09 ├──⟩⟩ HDMI_GR_TV  ↗3/B4
```

meaning "continues on sheet 3, grid zone B4." The sheet border carries zone letters A–D vertically and numbers 1–8 horizontally (§1.7); every off-sheet flag resolves to an exact zone, and every schedule row carries the zone too. This is authentic drafting practice and it is the single highest-value navigation aid in a multi-sheet set.

**Net names are generated, never typed.** KiCad's acknowledged weakness is that "typos can prevent signals from being connected." In a GUI tool with a device library that failure mode is entirely avoidable. Default template: `{DOMAIN}_{SRC_REFDES}_{SRC_PORT}` → `HDMI_MTX1_OUT3`. Alternate templates: `{ROOM}_{DEVICE}_{N}` (the AVIXA F501-shaped scheme, which makes the on-diagram label match the physical cable label the installer will find — this is the entire point of labelling) or `W{###}`. The template is a project setting; individual nets may be renamed, and rename propagates everywhere in one transaction. Renaming a **room** propagates to every label, schedule row, and callout — directly answering the documented `Study / Office / Room 3` failure that makes as-builts useless.

Enforce Q-SYS's rule: **duplicate source names prohibited, duplicate destination names permitted** (one output → many inputs is legal and common).

**When to draw vs when to label — the argument.**

Draw a wire when the connection is **local and topologically informative**: the reader learns something from seeing the path. Adjacent devices, short spans, the signal spine of the system. A drawn wire answers "what feeds what" *spatially*, which is the only thing a diagram does better than a table.

Label a net when the wire would be **long, cross many others, or leave the sheet**. A wire whose path is so contorted that following it is harder than reading a name has negative information value — it actively costs the reader time and it costs the canvas legibility for every *other* wire. This is not a compromise; above a certain density a labelled net is strictly the better drawing.

Concrete default rule, tunable with live preview:

```
render as drawn wire  iff  layerSpan(c) ≤ K            (K default 3)
                      and  gutterDensity(c) ≤ D        (D default 12 tracks)
                      and  c.renderMode != forceLabel
else render as net label
```

Plus a global three-way toggle in the toolbar — **Draw all / Auto / Label all** — and a per-net override in the context menu and the connections table (`Ctrl+L` on selection). Auto-degraded nets show a small ⟩ badge so the user knows the rule fired and can override. Changing the mode is a normal undoable edit and never touches the model's connectivity.

### 1.6 Buses and bundles

Two distinct concepts. Do not conflate them.

**Bus** — a rendering of ≥ 4 nets that are members of a natural family and run between the same two regions. Drawn as a thick trunk (4.8 px screen / 2.1 pt print) with **45° bus-entry stubs** at each member's departure point and a bracketed label:

```
   MTX1                                             DA1
 OUT[1..8] ├──╲                                 ╱──┤ IN[1..8]
            ╲  ╲═══════════════════════════════╱  ╱
             ╲══╝  HDMI_MTX_OUT[1..8]         ╚══╱
```

Vector syntax `NAME[0..7]` expands to members; group syntax `USB1{DP DM}` yields `USB1.DP`, `USB1.DM`; groups may nest vectors. Bus entries are **purely graphical and establish no connectivity** — membership is carried by net name. This is KiCad's model and it is correct: it means a bus can be formed, dissolved, or re-formed on a different axis without touching a single netlist entry.

**Bundle (snake)** — a *purely organisational* grouping of physical runs that share a conduit or a trunk, for the schedule and the pull sheet. Bundles may contain **mixed domains** (2× HDMI + 1× Cat6 + IR in one conduit is a real AV trunk; Q-SYS's snakes explicitly allow mixed types for exactly this reason). A bundle **does not affect tracing or connectivity** — NetBox states this explicitly about its cable bundles and it is precisely right for RackMate's confirmed "no cable dressing" decision. It gets you 90% of cable-management value for 5% of the complexity.

Rendering: bundle members route on adjacent tracks and are wrapped in a 2U-inset rounded outline at 20% ink with a bundle tag `B03 · 4 runs · 40'`. Collapse a bundle (`Ctrl+Shift+K`) to render it as a single trunk with a fan at each end.

**Hyperedges (one source → many sinks)** — IR emitter buses, speaker daisy-chains, RS-232 loop-through, 1→N distribution amps, RF splitter trees, 70 V taps. Model as one `Net` with one source port and N sink ports. Rendering: a trunk with perpendicular stubs and junction dots — the board-schematic idiom, visually distinct from P2P at a glance regardless of colour. Geometry is improved automatically; **topology changes only on explicit user request.** This split is the stability mechanism (§2.6) and it is the published answer to "why does everything jump when I move one thing."

### 1.7 Sheet, border, and the schematic aesthetic

**Sheet sizes:** ANSI A/B/C/D and ISO A4/A3/A2/A1, landscape default. Sheet size is a per-sheet property; the canvas is infinite but the sheet frame shows what will print, and content outside it is dimmed to 40% with a "3 items outside sheet bounds" chip.

**Border:** 10 mm outer margin, 5 mm frame, zone marks every 40 mm — letters A–D top-to-bottom on both left and right edges, numbers 1–8 left-to-right on both top and bottom. Zones are what off-sheet connectors and schedule rows reference.

**Title block**, bottom-right, 180 × 50 mm, ISO 7200-shaped:

```
┌────────────────────────────────────────────────────────┬───────────────┐
│ PROJECT   Smith Residence — Head End Rack              │  RackMate     │
│ SHEET     2 of 6 · VIDEO                               │  ANSI B       │
├──────────────┬──────────────┬──────────────┬───────────┼───────────────┤
│ DRAWN  J.S.  │ DATE 18JUL26 │ REV  C       │ SCALE NTS │  DRG SR-0247  │
└──────────────┴──────────────┴──────────────┴───────────┴───────────────┘
```

Plus a **legend block** (auto-generated: only the domains actually present on this sheet, with their colour, dash, weight, and prefix) and a **revision table**. Both are auto-populated and both are what make the output look like a document an installer trusts rather than a screenshot.

**Light theme** — paper `#FFFFFF` for print, `#FAFAF7` on screen (pure white is fatiguing for hours of editing and the 3% warm tint reads as "paper"). Ink `#1A1A1A`. Body fill `#FFFFFF` with a `#1A1A1A` 1.2 px outline. Header band `#F0F0EC`. Grid dots `#1A1A1A` @ 15%.

**Dark theme** — canvas `#12161A`, sheet `#1A1F26`, ink `#E6E9EC`, body fill `#232A33`, header band `#2C343E`, grid dots `#E6E9EC` @ 12%. Bodies must stay *lighter* than the canvas — inverting to dark-on-dark makes symbols vanish. The dark theme is for the person editing at 11 pm; the light theme is the deliverable. Export **always** renders the light/print palette regardless of screen theme, with no user-facing option to do otherwise. There is no legitimate reason to hand an installer a black-background schematic.

---

## 2. Canvas interaction

### 2.1 Creating a connection — the full state machine

Both idioms are supported and they share one state machine. The drag threshold decides which sub-mode you're in; releasing over the origin port converts drag → sticky. This is the pen-tool convention and users already have muscle memory for it.

```
                       ┌──────────────────────────────────────────┐
                       │                 IDLE                     │
                       └───┬──────────────────────────────────┬───┘
      pointerDown on port  │                                  │ hover port
                           ▼                                  ▼
                    ┌─────────────┐                    ┌──────────────┐
                    │  ARMED      │                    │  PORT_HOVER  │
                    │ (btn held,  │                    │ (tooltip +   │
                    │  <4px moved)│                    │  glyph pulse)│
                    └──┬───────┬──┘                    └──────────────┘
       move ≥ 4px      │       │  pointerUp (click, no drag)
                       ▼       ▼
              ┌────────────┐  ┌──────────────┐
              │ WIRE_DRAG  │  │ WIRE_STICKY  │
              │ (btn held) │◄─┤ (btn free,   │
              └──┬──────┬──┘  │  band follows│
                 │      │     │  cursor)     │
   pointerUp on  │      │     └──┬────────┬──┘
   ORIGIN port ──┘      │        │        │
   → WIRE_STICKY        │        │        │ Esc / right-click / click empty
                        │        │        └────────────► IDLE  (no model change)
      pointerUp on target        │ click on target
                        ▼        ▼
                 ┌──────────────────────┐
                 │      RESOLVE         │
                 │  classify(src, tgt)  │
                 └──┬────────┬──────┬───┘
             OK     │  WARN  │      │  HARD-INVALID
                    ▼        ▼      ▼
              ┌─────────┐ ┌────────────┐ ┌──────────────────────────┐
              │ COMMIT  │ │ COMMIT +   │ │ REJECT: 120 ms spring    │
              │ (undo   │ │ DRC WARN   │ │ back, target flashes red │
              │  entry) │ │ badge      │ │ ×2, reason chip appears  │
              └────┬────┘ └─────┬──────┘ │ with remedy actions      │
                   │            │        └───────────┬──────────────┘
                   └────────────┴────────────────────┘
                                ▼
                    IDLE, or WIRE_STICKY from the
                    committed sink if Shift is held
                    (chain-draw mode)
```

**Chain-draw.** Holding `Shift` on commit immediately re-arms from the *sink* device's matching output. Wiring `AppleTV → MTX1 IN1`, then `MTX1 OUT1 → DA1 IN`, then `DA1 OUT1 → TV` becomes three clicks with no round-trips to Idle. This is the highest-throughput gesture in the editor and it is worth building first.

**Multi-draw.** With N ports selected in one bank (shift-click or marquee inside the bank), dragging to a target bank creates N connections in **rank order** with a single undo entry — the "wire the 8×8 matrix to the 8 zone amps" gesture. Live preview shows all N rubber bands. This turns a 30-minute task into 3 seconds and it is the demo moment.

**Live feedback during `WIRE_DRAG` / `WIRE_STICKY`:**

1. **The canvas dims.** All non-port content drops to 35% alpha — *baked into `Paint.color`, never an opacity layer*. A `saveLayer` costs ~1 ms and three of them blow a third of the frame budget.
2. **Compatible ports illuminate.** A 3U ring in `#F0E442` with a 900 ms breathing pulse (0.6 → 1.0 alpha). "Compatible" = passes all Class-A rules (§2.2).
3. **Warn-compatible ports** get the same ring in amber `#E69F00`, no pulse.
4. **Incompatible ports** hold at 35% with no ring. Not red — red at 40 simultaneous ports is noise, and absence-of-affordance is the clearer signal.
5. **Rubber band** renders in the source port's domain colour, at the domain's weight and dash, as a live two-bend orthogonal staple (not a straight line — preview what you'll get).
6. **Magnetic snap.** Within 12 screen px of a port, the band's free end locks to that port's glyph centre and the glyph scales to 1.15×. Snap is **type-weighted**: an HDMI band prefers an HDMI port even if an RJ45 port is 3 px nearer. This is the single biggest usability win in the entire editor.
7. **Auto-pan.** Dragging within 40 px of the viewport edge pans at up to 800 px/s, ramped quadratically by proximity.
8. **Hover a *collapsed bank*** during a drag → the bank auto-expands after 400 ms so you can target a specific member.
9. **Status bar** shows the live resolution: `MTX1:J09 HDMI OUT 3 → AVR1:J03 HDMI IN 2 · OK · est. 12'`.

**Cancel.** `Esc`, right-click, or click on empty canvas. All three abort with no model mutation. `Esc` in `WIRE_STICKY` also clears the source selection.

**Invalid target on release — never silently drop.** Spring-back animation (120 ms, `Curves.easeOutBack`), the target port flashes `#D55E00` twice at 90 ms, and an inline chip appears anchored at the target with the reason **and remedies**:

```
 ⛔ HDBaseT output cannot terminate on an Ethernet switch port.
    HDBaseT uses Ethernet cabling but is not interoperable; PoH
    may damage the switch.
    [ Insert HDBaseT receiver ]  [ Pick a different port ]  [ Why? ]
```

Offering the remedy is what separates a rule engine from a nag. The `[Insert …]` action places the correct intermediate device and creates both connections in one undo step.

### 2.2 Validation: hard-invalid vs warn

Two classes, and the split is about **what the model can know**.

**Class A — hard-invalid. Refused at drag time. Cannot exist in the document.** These are physically destructive or definitionally impossible, and the model has complete information:

- source → source, or sink → sink
- HDBaseT port → Ethernet switch port
- IR emitter → IR receiver jack *(destroys the emitter and can damage the PSU)*
- connector mismatch with no declared adapter/balun
- signal port → power port, in either direction
- a second connection on a `maxConnections: 1` port (offer "replace existing?")
- Dante/AES67 endpoints with no network path
- AVB endpoints traversing a non-AVB/TSN switch
- satellite splitter with no DC-passing port toward the LNB

**Class B — spec violation. Created, but rendered as marked and listed in the DRC.** The model may be incomplete (lengths unmeasured, gear unspecified), so refusing would block legitimate in-progress work:

| Rule | Severity |
|---|---|
| Ethernet channel > 100 m | error |
| DMX segment > 512 channels in one universe | error |
| DALI line > 64 devices or > 300 m | error |
| Σ PD class draw > switch PoE budget | error |
| parallel low-Z speakers below amp's min impedance | error |
| passive HDMI 2.1 @ 48 Gbps > 4.5 m | warn |
| 12G-SDI coax > 45 m | warn |
| impedance mismatch (S/PDIF into 50 Ω BNC; AES3 on mic cable) | warn |
| DTE↔DTE RS-232 without `crossover: null-modem` | warn |
| RS-485/DMX segment > 32 unit loads, or no terminator | warn |
| Cresnet: length limit *and* 24 V drop limit (18 AWG @ 20 W ⇒ 333 ft) | warn |
| Σ 70 V taps > 80% of amp rating | warn |
| 12 V trigger fan-out > 100 mA | warn |
| Σ outlet draw > PDU rating or > 80% continuous derate | warn |
| RF cascade loss budget exceeded | warn |
| unconnected port on a placed device | info |
| orphan device (no connections at all) | info |

**Rendering.** Both marks are drawn *over* the wire so the cable type stays readable underneath:

- **Error** — a red `#D55E00` chevron-hatch overlay stroked along the run at 0.5× weight, plus a ⛔ badge at the run midpoint. On a selected error wire the reason renders inline.
- **Warn** — an amber `#E69F00` 0.6 px dotted parallel line offset 1U below the wire, plus a △ badge.
- **Both badges are click targets** → selects the wire and scrolls the DRC panel to the entry.
- **Device-level roll-up:** a device with any marked connection gets a ⚠/⛔ chip in its header, so problems are findable at LOD levels where the wire badge is invisible.

Be honest about the limits in the docs, as KiCad is: **this catches class errors, not intent errors.** ERC cannot detect a correctly-typed connection to the wrong device.

**Adapters as first-class objects.** An RCA↔XLR balun, an HDMI↔HDBaseT extender pair, a null-modem adapter, an F↔BNC barrel — these are `ruHeight: 0`, `mountLocation: not-in-rack` passive devices. They appear in the netlist and the BOM, they resolve Class-A rejections legitimately, and they render as a small inline lozenge on the wire rather than a full symbol. Same treatment for an attic RF splitter or an IR connecting block: real nodes, no rack units.

### 2.3 Selecting, editing, rerouting, deleting

**Selection.**
- Click a wire → select. **Nearest-hit wins**, not first-hit. At a crossing — which is constant in a schematic — first-hit picks arbitrarily and feels broken. Hit tolerance 6 screen px (converted to scene units as `6 / viewport.scale`).
- Hit-test wires with closed-form point-to-segment distance against the cached `routedPoints` polyline. `Path.contains()` only works on closed paths and a stroked polyline is not closed; Flutter exposes no stroke-to-fill API; `PathMetrics` sampling is slower *and* approximate. Do the math.
- Click a symbol body → select device. Click its header → select device. Click a pin → select port (for multi-draw).
- `Shift+click` add · `Alt+click` subtract · `Ctrl+click` on a wire → **select the whole net** (all members of a hyperedge) · double-click a wire → select every wire in its **bundle**.
- Selected wire: `#F0E442` halo at +5 px *behind* the stroke, square handles at both endpoints, diamond handles at each waypoint, hollow diamonds at insertable midpoints.

**Rerouting.**
- **Drag a segment perpendicular** → moves that segment, creating/updating the two bracketing waypoints. This is the Visio/KiCad idiom and users reach for it without being taught.
- **Double-click a segment** → insert a waypoint at the click point, snapped to grid.
- **Drag a waypoint** → move it. **Right-click → Remove**, or drag it onto its neighbour to merge.
- **`Ctrl+Shift+R` or context → Clear Route** → discard all overrides, return to auto. Prominent, always available, and cheap. Users will only pin routes if un-pinning is trivially reversible.
- Waypoints are a **constraint on the router, not an escape from it.** A pinned run still gets nudged, still avoids obstacles, still re-routes when a device moves. A manual drag must *never* freeze a route into a dead polyline — that is how a drawing rots.

**Re-terminating.** Drag an endpoint square handle. Enters the same `WIRE_DRAG` state with full compatible-port illumination. Drop on empty canvas → **revert to the original port**, do not create a loose end. Q-SYS's rule holds: *loose wires are prohibited by the system.* A half-connected cable is not a thing that exists in a rack, and permitting it in the model corrupts every derived report.

**Deleting.** `Del` / `Backspace`. Deleting a device deletes its connections, with a confirm above 5 (`"Delete AVR1 and its 14 connections?"`) — one undo entry. Deleting a bus deletes the *rendering*, not the nets; confirm chip says so explicitly.

**Context menus** (native platform menus, not Material popups):

| Target | Items |
|---|---|
| Wire | Cable Type ▸ · Media ▸ · Reverse Direction · **Convert to Net Label** · Add to Bundle ▸ · Set Length… · Pin Route / Clear Route · Select Net · Trace Signal · Properties · Delete |
| Port | Connect from here · Rename… · Change Type ▸ · Collapse Bank / Expand Bank · Mark Unused · Properties |
| Device | Focus on this · Isolate · Pin Placement / Unpin · Split into Units · Align ▸ · Go to Rack Position · Go to Rear Panel · Duplicate · Properties · Delete |
| Bus | Expand to individual wires · Rename bus… · Add member ▸ · Dissolve |
| Empty | Paste · Add Device ▸ · Add Net Label · Add Text · Fit to Sheet · Sheet Setup… · Re-flow Layout… |

### 2.4 Pan, zoom, fit, marquee

**Do not use `InteractiveViewer`.** It cannot receive scroll-wheel `PointerSignal` events (so zoom-to-cursor — the single most-used desktop diagram interaction — is impossible), it installs its own `ScaleGestureRecognizer` that fights marquee/drag/wire-draw, and its `boundaryMargin` is the wrong model for infinite-canvas-with-fit. Write ~150 lines and own it.

| Gesture | Action |
|---|---|
| Middle-drag | pan (universal, never ambiguous — this is the one that always works) |
| `Space`+drag | pan (Figma-native muscle memory) |
| Bare wheel | **pan vertical** *(preference: CAD users expect zoom — ship the toggle on day one, you will get complaints either way)* |
| `Shift`+wheel | pan horizontal |
| `Ctrl`/`Cmd`+wheel | **zoom at cursor** |
| Trackpad two-finger | pan (`PointerPanZoomUpdateEvent` on macOS, `PointerScrollEvent` on Windows) |
| Trackpad pinch | zoom at focal point |
| Right-drag | marquee (no modifier needed, doesn't collide with pan) |

Zoom uses `scale *= math.exp(-delta * 0.002)` — **multiplicatively symmetric**, so three notches up then three down lands exactly where you started. Linear stepping drifts and users notice. Clamp to `[0.05, 32.0]`.

Note the matrix subtlety: pan deltas arrive in *screen* space and must be **left-multiplied** (`leftTranslate`); the zoom pivot is right-multiplied in *scene* space. Getting this backwards produces pan that accelerates with zoom — the classic hand-rolled-viewport bug.

**Fit commands:** `Ctrl+0` fit sheet · `Ctrl+1` 100% · `Ctrl+9` fit selection · `Ctrl+Shift+0` fit all sheets in a contact-sheet overview.

**Marquee.** Follow the CAD convention users already have muscle memory for: **left-to-right = full containment** (band drawn solid), **right-to-left = intersection** (band drawn dashed). Costs one `if` and reads as polish. `Shift` adds, `Alt` subtracts. Marquee selects devices; hold `W` to marquee wires instead.

**Alignment & distribution** (multi-selection): `Ctrl+Alt+←/→/↑/↓` align left/right/top/bottom · `Ctrl+Alt+H/V` distribute · `Ctrl+Alt+C` centre on the common axis. Alignment respects the 1U grid and pins every affected symbol.

### 2.5 Auto-layout that does not destroy user work

This is where diagram tools lose users' trust permanently, so it gets designed rather than bolted on. Four mechanisms:

**(1) Placement state per symbol.** Every symbol is `auto` or `pinned`. Any manual move sets `pinned = true` and shows a 📌 badge in the header. **Auto-layout never moves a pinned symbol.** Pinned symbols become fixed anchors and obstacles for the layout of everything else. `Ctrl+Shift+U` unpins the selection; the badge is click-to-toggle.

**(2) Scoped invocation.** Four separate commands, escalating:
- `L` — **Tidy selection**: lay out only the selected symbols, treating all others as fixed.
- `Shift+L` — **Tidy sheet**: lay out all `auto` symbols on the current sheet.
- `Ctrl+Shift+L` — **Re-flow sheet**: lay out everything on the sheet, *including pinned*. Confirm dialog.
- `Ctrl+Alt+Shift+L` — **Re-flow document**. Confirm dialog naming the count of pinned symbols that will move.

**(3) Preview-diff — the feature that removes all fear.** Every layout command runs, then shows the result as **ghost symbols at 40% with motion arrows from current to proposed positions**, plus a HUD: `Layout preview · 14 symbols move · crossings 31 → 8 · Enter accept · Esc discard · Tab cycle variants`. Nothing is committed until `Enter`. `Tab` cycles three deterministic variants (compact / spacious / domain-banded). No competitor does this, it costs one extra render pass, and it converts auto-layout from a thing users fear into a thing they invoke constantly.

**(4) Single undo entry.** Any accepted layout is exactly one transaction. `Ctrl+Z` fully restores prior positions including pin flags.

**Additionally:** wire *routing* is always automatic and always recomputed — it is cheap (§3) and it has no user-authored state except explicit waypoints, which are preserved as constraints. There is no such thing as a "stale route." There is only "stale symbol placement," which is signalled by a subtle chip in the toolbar (`Layout is stale · Tidy`) after a structural change, never by moving anything on its own.

### 2.6 Stability

Route instability has two distinct causes and they need different fixes.

**Cause 1 — arbitrary tie-breaking.** Fixed by making the router a **pure deterministic function** of the model with total-order tie-breaks that terminate in stable UUIDs. Every sort key in §3 ends in `.uuid`. libavoid uses insertion timestamps and a fixed neighbour-expansion order (*straight, right, left*); ELK uses model order as a tie-break across cycle-breaking, layering *and* crossing minimisation. Do both.

**Cause 2 — genuine global re-optimisation.** Fixed by separating **topology from geometry**. Geometry recomputes continuously and freely. Topology (which side a wire leaves from, which junctions a hyperedge has, sheet assignment) changes **only on explicit user request**. This is the published answer from the orthogonal-hyperedge literature and it is the reason a well-built router feels calm.

Because of §3's algorithm choice, cause 2 largely evaporates: a monotone greedy sweep means a small input change produces a small output change, by construction. **Do not build incremental-reroute machinery in v1.** A full deterministic recompute is both cheaper than the invalidation bookkeeping and perfectly stable. It is the wrong optimisation and it will cost correctness bugs.

---

## 3. Layout strategy

### 3.1 The structural insight

Rack devices are ordered along one axis at discrete integer RU positions. That is a *gift* and the algorithm should extract it in two places:

1. **As the initial and tie-break ordering within each Sugiyama layer.** Free the layout from arbitrariness *and* make the schematic read roughly top-to-bottom in rack order, so cross-referencing between the elevation and the schematic is near-automatic.
2. **As the reason the routing region has no obstacles.** Once devices are in layers, each inter-layer gutter is an empty vertical channel. Routing through an empty channel is not graph search — it is **interval-graph colouring**, solved optimally in 1971.

The consequence: **RackMate never needs a general orthogonal router.** libavoid measures 2,007 ms on a 305-node/413-edge diagram. The algorithm below is sub-millisecond at N=300 *and* provably optimal in track count, because it exploits structure instead of discarding it.

### 3.2 v1 pipeline

**Input:** `(devices, connections, pinnedPositions, sheetAssignment)`. **Output:** `(symbolPositions, List<Polyline>, junctions, hops, labelAnchors)`.

**Phase 0 — Cycle breaking.** Greedy (Eades et al.) over the directed signal graph, DFS order seeded by rack position then UUID. Reversed edges are flagged and rendered with the arrowhead still at the true sink. AV signal graphs are near-acyclic; the common real cycles are AVR↔display eARC and matrix loop-throughs, both of which should break at the *return* edge — bias the greedy heuristic to prefer reversing edges whose `signalFamily` is a declared `returnChannel`.

**Phase 1 — Layer assignment.** Longest-path layering on the DAG. Constraints:
- The **Structure** device is forced to layer 0, always, rendered as a bank of off-page connector flags on the left edge. This makes it visually obvious in the PDF which home runs are **unused** — a genuinely valuable deliverable in its own right.
- Off-rack destinations (displays, speakers, keypads) are forced to the final layer.
- Pinned symbols are assigned the layer nearest their pinned x.

Longest-path is ~15 lines and sufficient for a rack. Network simplex is v2 (tighter, minimises total weighted edge length, noticeably better on wide fan-outs).

**Phase 2 — Within-layer ordering.** Barycentre sweep with median tie-break, forward and backward until crossings stop decreasing (cap 8 iterations). **Initial order and final tie-break = rack position, then UUID.** Barycentre empirically beats median despite median's provable 3-approximation — run barycentre, break ties with median, break those with rack order.

Port ordering: `FIXED_ORDER` by default (a device's ports are real hardware and you cannot reorder the XLR jacks on an amp to make a drawing prettier). Logical/abstract symbols may opt into `FIXED_SIDE` or `FREE` per bank via a Properties toggle.

**Phase 3 — Coordinate assignment.** Insert dummy nodes for every edge spanning > 1 layer (standard Sugiyama) so that **every edge crosses exactly one gutter**. Then Sugiyama's priority method, 3 iterations, priority = degree. v2 upgrades to Brandes–Köpf (four-pass median alignment + balancing), which is visibly straighter on long chains.

Pinned symbols contribute fixed coordinates and are excluded from the relaxation.

**Phase 4 — Edge routing: left-edge channel routing, per gutter.**

Each inter-layer gutter is an independent channel. Every edge crossing it becomes an **interval** on the y-axis: `I(e) = [min(ySrc, yDst), max(ySrc, yDst)]`. Two edges may share a vertical track iff their intervals are disjoint. Therefore **track assignment ≡ interval-graph colouring**; interval graphs are perfect; greedy-by-left-endpoint achieves the chromatic number *exactly*. Minimum track count = maximum overlap depth. No heuristic gap, no NP-hardness, no search.

```dart
List<Track> assignTracks(List<Edge> edges) {          // one gutter
  edges.sort(byTop.then(byBottom).then(byUuid));      // fully deterministic
  final free = MinHeap<(int availableFrom, int track)>();
  var next = 0;
  for (final e in edges) {
    int k;
    if (free.isNotEmpty && free.peek().availableFrom <= e.interval.top) {
      k = free.removeMin().track;                     // reuse
    } else {
      k = next++;                                     // new track
    }
    e.track = k;
    free.add((e.interval.bottom + MIN_GAP, k));
  }
  return next;   // == channel density == provably optimal
}
```

**Track ordering (this is where crossing reduction actually lives).** Track *indices* are just labels; permuting which x-offset each maps to is always feasible and free. Sort tracks by `(maxSpan desc, minTop, uuid)` — **short jumpers hug the layer, long runs sit outboard.** This matches human drafting intuition exactly and it is one `sort`.

Emit each route as the two-bend staple `[(srcPin), (trackX, srcY), (trackX, dstY), (dstPin)]`, collapsing to a straight line when `srcY == dstY`.

**Phase 5 — Decoration.** Orthogonal Bentley–Ottmann sweep for crossings (`O((N + X) log N)`); junction dots at genuine multi-drop nodes only; 4-way staggering; hop arcs on horizontals.

**Phase 6 — Labels. Do not solve edge-label placement.** ELP is NP-hard and the industrial answer is to *avoid the problem in the layout phase* rather than solve it afterwards. Because tracks are on a known discrete grid, label slots are **collision-free by construction**: reserve 6U at the top and bottom of each gutter as label bands, and anchor each tag pill at the top of its own track. This is a genuine architectural payoff of choosing channel routing.

### 3.3 Complexity

Let N = connections (50–300 typical), D = devices (10–30), T = tracks per gutter (5–15 typical), X = crossings.

| Phase | Cost |
|---|---|
| 0 cycle break | O(D + N) |
| 1 layering | O(D + N) |
| 2 crossing min | O(k · N log N), k ≤ 8 |
| 3 coordinates | O(3 · N) |
| 4 track assignment | **O(N log N)** — sort dominates |
| 5 crossing sweep | O((N + X) log N) |
| 6 labels | O(N) |
| **Total** | **O(N log N + X log N)** — sub-millisecond at N = 300 in Dart |

Full recompute on every edit. No caching of routes, no invalidation logic, no incremental bugs.

### 3.4 v2 upgrades, in priority order

1. **Brandes–Köpf coordinate assignment.** Visibly straighter long chains. ~400 lines.
2. **Nudging pass.** Order shared segments so crossings occur only at bundle entry/exit, never mid-bundle (libavoid's Theorem 3). Because tracks are already discrete, ordering *is* placement — you get this without needing a VPSC solver, which is the hard 80% of libavoid's stage 3.
3. **Network simplex layering.** Tighter than longest-path on wide fan-outs.
4. **Hyperedge geometry improvement.** The shift-segments heuristic: move each segment within its free space toward the side with the most divergent paths, maintaining per-segment divergence counts, horizontal pass then vertical. Topology preserved unless the user explicitly asks for re-topologising.
5. **Free-placement escape hatch.** If a user pins symbols into a configuration that breaks the layered structure, fall back to a **1-bend visibility graph** router for the affected edges only. Node count is O(n) rather than O(n²) and empirically finds routes "with effectively no search" (3–4 A\* steps vs 28–34 for a full OVG). Reimplement in Dart (~700 lines) rather than binding libavoid — the LGPL subprocess dance is not worth it at this scale.
6. **Auto sheet partitioning** (§4.5).

**Keep the router behind `List<Polyline> route(WiringModel)` from day one**, so all of this stays a one-file swap.

---

## 4. Managing density

This is make-or-break. A house with 80–150 cable runs is not unusual, and every mechanism below exists to answer "I can't see anything."

### 4.1 Domain filter bar

A persistent strip below the toolbar: eight chips, each a domain swatch + name + live count.

```
 [◼ Digital Video 34] [◼ Analog Video 6] [◼ Analog Audio 22] [◼ Digital Audio 8]
 [◼ Network 41] [◼ Control 19] [◼ Power 28] [◼ Structure 12]        [All] [None]
```

- **Click** = solo that domain. **Ctrl+click** = toggle. **`1`–`8`** = solo by index. **`` ` ``** = all on.
- Filtered-out wires render at **8% alpha, baked into `Paint.color`** — never an opacity layer.
- Preference: **Ghost** (default) vs **Hide**. Ghost preserves spatial context so you can still see that *something* runs there; Hide is for the final print of a domain-specific sheet.
- Devices with zero visible connections dim to 25% and their pins drop to ticks.
- Filter state is per-view, not persisted in the document — except on a sheet whose `sheetFilter` property is set, where it is the sheet's definition.

Filters are **orthogonal to layers** (§4.2). Both apply.

### 4.2 Layers

User-defined named layers, each with `visible / locked / prints` flags: *Existing*, *Phase 1*, *Phase 2*, *Future*, *Owner-furnished*, *Demo*. A connection and a device each belong to exactly one layer. Layers are a **document** concept and they do persist.

Layer panel: reorderable list, per-row 👁 / 🔒 / 🖨, colour tint override (e.g. *Future* renders at 50% saturation with a `2,2` dash regardless of domain — the standard "not yet installed" drafting convention).

### 4.3 Focus and isolate

- **`F` — Focus.** With a device selected, everything more than *N* hops away dims to 10% and desaturates to greyscale; the focused subgraph keeps full colour and gains a subtle radial vignette. `N` defaults to 1, adjustable with `[` / `]` (1–3), shown in a HUD chip: `Focus: AVR1 · 1 hop · 14 devices, 31 wires`. Press `F` again or `Esc` to exit. This is "show everything connected to this AVR" and it is the mode users will live in.
- **`Shift+F` — Isolate.** Same selection, but non-members are **hidden** and the router re-runs on the subgraph only, producing a clean minimal diagram. Effectively "temporary sheet." `Esc` restores. Isolate + `Ctrl+P` is how you produce a one-device commissioning sheet.
- **`T` — Trace.** With a wire or port selected, highlight the **full signal path through pass-through devices**: patch-panel front→rear ports, matrix input→output where a route is declared, switch port→port on the same VLAN, RF splitter input→outputs, balun in→out. Renders as an animated flowing dash along the path (24 px/s — slow enough to read, fast enough to follow) with a breadcrumb HUD:
  `LR Wallplate → STR:J12 → SW1:P4 → SW1:P22 → HBT-TX1:J01 → …`
  This is NetBox's cable tracing and it is the feature that makes the Structure device pay for itself.
- **`Alt+hover`** — instant transient focus on whatever is under the cursor. No click, no mode, no state. The cheapest possible way to answer "what is this connected to."

### 4.4 Symbol collapse

Any symbol can collapse (`-` key or the header chevron) to a compact block showing only refdes, name, and **vector-pin stubs per bank**. A 48-port patch panel becomes 60 × 30 mm. Collapse state is per-sheet, so the same device can be detailed on the network sheet and collapsed on the video sheet. `Ctrl+Shift+-` collapses everything below a port-count threshold.

### 4.5 Multi-sheet

Sheets are explicit, user-created, and ordered. Each sheet has a name, size, an optional `sheetFilter` (domain set + layer set), and its own layout state.

**The default partition is by domain, not by graph structure**, because that is how AV drawing sets are actually organised and it is what an installer expects to receive:

```
Sheet 1  SYSTEM OVERVIEW   all devices, collapsed, buses only, no individual wires
Sheet 2  VIDEO             digital video + analog video/RF
Sheet 3  AUDIO             analog audio + digital audio
Sheet 4  NETWORK           ethernet, PoE, fiber
Sheet 5  CONTROL           IR, serial, contact, trigger, lighting bus
Sheet 6  POWER             AC distribution, PDU outlet map, sequencing
Sheet 7  STRUCTURE         home-run schedule + Structure device detail
```

A device appears on every sheet where it has a visible port. Its symbol shows only the ports relevant to that sheet (**automatic unit splitting by domain** — this is where mechanism 1.2(b) earns its keep). Every cross-sheet connection renders as paired off-sheet connectors with zone references (§1.5).

**Auto-split proposal** (`Layout → Split to Sheets…`): offers the domain partition above, plus a **graph min-cut** alternative for very large racks, plus **by rack** for multi-rack projects. Shows a preview with per-sheet device/wire counts and the resulting cross-sheet connector count (minimise that number — it is the cost function). Always previewed, always one undo entry.

**Sheet navigator:** thumbnail strip along the bottom, `Ctrl+PgUp/PgDn` to move between sheets, `Ctrl+Shift+0` for a contact-sheet overview of all sheets at once.

### 4.6 The composite density strategy

Applied in this order as a rack grows:

| Connections | Strategy |
|---|---|
| 0–40 | one sheet, draw everything |
| 40–80 | one sheet + collapsed high-port devices + auto net labels above `K=3` layers |
| 80–150 | domain filters become the primary navigation; split to 3–4 sheets |
| 150–300 | full 7-sheet set; buses for parallel runs; overview sheet is collapsed-only |
| 300+ | overview sheet + per-subsystem sheets; the **schedule** is the primary artefact and the diagrams are navigation |

---

## 5. The relationship between views

### 5.1 One document, four projections

They are **four views of one model**, absolutely. "Design the system twice" is the loudest structural complaint in this entire product category and the whole point of RackMate is to not do it.

| View | Shows | Geometry from |
|---|---|---|
| **Rack elevation** | front/rear, devices at true RU, faceplate-accurate outlines | `DevicePlacement{rackU, heightU, face}` — physical truth |
| **Schematic** | logical signal flow, symbols in layers, sources left → sinks right | `SymbolPlacement{sheetId, x, y, pinned}` — *independent*, user intent |
| **Rear panel / patch** | real rear panels stacked in RU order with connectors at true mm positions | derived: rack order + `Port.position{ruOffset, xOffsetMm}` — zero stored geometry |
| **Schedule** | the authoritative connectivity table | fully derived |

### 5.2 What syncs, what does not — and the argument

| Change | Rack | Schematic | Rear | Schedule |
|---|---|---|---|---|
| Rename a device / change refdes | ✅ instant | ✅ instant | ✅ instant | ✅ instant |
| Add / remove / retype a port | ✅ | ✅ | ✅ | ✅ |
| Create / delete / retype a connection | ✅ | ✅ | ✅ | ✅ |
| Change room, layer, label, length | ✅ | ✅ | ✅ | ✅ |
| Selection | ✅ ↔ | ✅ ↔ | ✅ ↔ | ✅ ↔ |
| Filters, focus, isolate | ✅ ↔ | ✅ ↔ | ✅ ↔ | ✅ ↔ |
| **Move a device to a different RU** | ✅ | ⚠️ **does not move the symbol** | ✅ reorders | ✅ |
| **Move a schematic symbol** | ❌ no effect | ✅ | ❌ | ❌ |

**The argument for not linking positions.** They are different axes and conflating them destroys work in both directions.

*Rack position is physical:* thermal management (amps low, heat-generating gear vented), weight distribution (UPS at the bottom), service access (frequently-touched gear at eye height), cable reach. *Schematic position is logical:* signal order, sources left, sinks right, readability.

An AVR sits at U14 for thermal reasons but belongs mid-chain logically. A UPS sits at U1 physically but is a leaf node logically. Slaving one to the other means every thermal decision destroys the reader's mental map of the signal flow, and every readability tweak implies a physical change that isn't real.

Worse, the failure is *silent and unrecoverable*. A user spends twenty minutes arranging a schematic, then reorders three devices in the rack because the installer called about heat — and the schematic scrambles. There is no undo affordance that makes that acceptable. **Auto-layout must never fire as a side effect of an unrelated edit.** This is the same principle as §2.5 and it is the same reason.

**What rack order *does* do:** it seeds and tie-breaks within-layer ordering on **first layout** and on any explicit re-flow (§3.2 phase 2). So a freshly auto-laid-out schematic naturally mirrors rack order top-to-bottom, and when you *want* the schematic to follow the rack, one `Shift+L` gives it to you. When you don't, nothing moves.

**Staleness signalling, not staleness fixing.** After a rack reorder, affected schematic symbols get a subtle 📐 chip in their header and the toolbar shows `Rack order changed · Tidy sheet (⇧L)`. Informative, dismissible, never automatic.

### 5.3 Cross-view navigation

- `Ctrl+Alt+R` — jump to the selection's rack position (switches view, pans, flashes the RU band).
- `Ctrl+Alt+S` — jump to the selection's schematic symbol.
- `Ctrl+Alt+P` — jump to the rear panel.
- `Ctrl+Alt+T` — reveal in the schedule table.
- Selection is **global and persistent** across view switches. Select a wire in the schematic, hit `Ctrl+Alt+P`, and you are looking at the two physical connectors it lands on, both highlighted. This one behaviour does more for the product's felt coherence than any other single thing.
- **Split view:** `Ctrl+\` splits the canvas pane. Any two views side by side, selection-synced, independently zoomed. Schematic + rear panel is the terminating workflow; rack + schematic is the design workflow.

### 5.4 The rear-panel / patch view — design

**Purpose:** this is the *installer's* view. The schematic says what connects to what; the rear panel says **which physical jack to plug into.** It is what gets printed and taped inside the rack door.

**Rendering.** Devices stacked in true RU order (rear = reverse left-right of front). Each device is a true-dimension rectangle: 482.6 mm wide (`4826` tenths-mm exactly), `heightU × 444` tenths-mm tall (EIA-310 1U = 44.45 mm = 444 tenths, exact — no rounding anywhere in the vertical axis). Connectors are drawn at their real `{ruOffset, xOffsetMm}` positions using the same glyph vocabulary as the schematic, but **at true relative scale and true position**, silkscreen labels included.

Connections render as short leaders from each connector into a vertical gutter with a tag pill, plus the destination in plain language:

```
 ┌────────────────────────────────────────────────────────── U14–15 ─┐
 │ MTX1   8×8 HDMI MATRIX                                    ⚡ ⏻     │
 │  ◎ ◎ ◎ ◎ ◎ ◎ ◎ ◎    ⌂ ⌂ ⌂ ⌂ ⌂ ⌂ ⌂ ⌂        ▭9    ⌂    ⊐         │
 │  IN 1 . . . . . 8    OUT 1 . . . . . 8      RS232  LAN  AC        │
 └──┬──────────────────────┬──────────────────────────────┬──────────┘
    │W021 HDMI 6'          │W044 HBT 90'                  │W101 PWR
    ↓ to ATV1:J01          ↓ to RX-GRT (Great Room)       ↓ PDU1:O07
```

**Why this view is worth building:** the rear panel view **is the device builder's output surface.** You build a device by drawing its rear panel — drag connectors from a palette onto a 1U/2U/3U blank, position them, name them, type them. The device you get is simultaneously a schematic symbol (auto-generated from the port list using the §1.2 edge rules), a rack elevation block, and a rear-panel drawing. One authoring gesture, three renderings. That is what makes "build a device faster than searching for one" achievable, which is the documented failure mode of every stencil library in this space.

Also renders: the **front** face (for devices with front-panel I/O — HDMI inputs on an AVR, a front USB on a PC, front-panel controls) and a **cable-egress heat map** overlay showing connector density per RU, which is genuinely useful for spotting a device whose rear panel will be physically unreachable once the rack is full.

---

## 6. Navigation

### 6.1 The connections table

A dockable panel (bottom or right, `Ctrl+4` to toggle), and also a full-screen view (`Ctrl+Shift+4`). It is a real Flutter `DataTable`, not canvas-painted — which means it is **screen-reader navigable for free**, and a properly accessible wiring schedule is better accessibility than any amount of heroic `CustomPainterSemantics` on the canvas.

| Tag | Domain | From | To | Type | Media | Len | Layer | Sheet/Zone | Bundle | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| W021 | ◼ D.Video | ATV1:J01 HDMI OUT | MTX1:J01 HDMI IN 1 | HDMI 2.1 | HDMI-48G | 6′ | Ph1 | 2/B3 | — | ✓ |
| W044 | ◼ D.Video | MTX1:J09 OUT 1 | HBT-GRT:J01 IN | HDBaseT | Cat6a F/UTP | 90′ | Ph1 | 2/C5 | B03 | ⚠ |
| W101 | ◼ Power | PDU1:O07 | MTX1:J20 AC IN | IEC C13 | 16 AWG SJT | 3′ | Ph1 | 6/A2 | — | ✓ |

- **Bidirectional selection sync.** Click a row → the canvas pans/zooms to fit that wire and flashes it 3× at 200 ms. Click a wire → the row scrolls into view and highlights. Multi-select works both ways.
- **Editable in place:** length, label, media, layer, bundle, notes. Type and endpoints are read-only here (structural changes belong on the canvas where the validation feedback lives).
- **Grouping:** by domain / source device / destination device / bundle / layer / sheet / room. Collapsible groups with roll-ups (count, total length, total cost when a BOM exists).
- **Sorting** by any column, with refdes sorting **natural** (`AMP2` before `AMP10`).
- **Bulk edit:** select N rows → set media, layer, bundle, or render mode in one transaction.
- **Export:** CSV, and a label-printer profile (Brady/Dymo/Brother) that emits both-ends labels per run.

### 6.2 Search

`Ctrl+F` opens a search field over a small query language. Bare text searches refdes, name, port label, net name, and notes.

```
domain:hdmi                       from:AVR1              to:*TV*
len:>25                           layer:"Phase 2"        status:error
media:cat6a                       room:"Great Room"      unconnected:true
bundle:B03                        sheet:2                is:label
domain:network AND len:>90        NOT layer:Future
```

Results appear as a ranked list; hovering a result flashes it on canvas; `Enter` jumps to it; `Ctrl+Enter` selects all results. A search may be **saved as a filter** onto the domain bar, or **promoted to a sheet** (creating a sheet whose `sheetFilter` is that query — this is how you produce "all runs over 90 ft" as a printable exception report).

### 6.3 Jump-to and outline

- `Ctrl+G` — **Go to designator.** Type-ahead over every refdes, port designator (`J14`), and cable tag (`W042`). Enter jumps and selects across whichever view is active.
- `Ctrl+P` (as in "go to anything," VS Code convention) — a unified palette over devices, ports, nets, sheets, and commands.
- **Outline panel** — a tree: Sheets → Devices → Banks → Ports → Connections. Selection-synced. This is the keyboard-only navigation path and it should be complete enough that the canvas is optional.
- **Minimap** — bottom-right, 180 × 120, showing the sheet extent, the viewport rect, and wires as 1 px domain-coloured lines. Click to jump, drag to pan. Toggle `Ctrl+M`.
- **DRC panel** (`Ctrl+5`) — a navigable list of every error/warning/info, grouped by severity then rule, each row clicking through to the offending object. Rules can be muted per-project with a required justification note that prints in the PDF appendix. This is what turns validation from an annoyance into a deliverable.

---

## 7. Keyboard shortcuts

macOS: substitute `⌘` for `Ctrl` throughout; `Alt` = `⌥`.

### Files, history, views

| Key | Action |
|---|---|
| `Ctrl+N` / `O` / `S` / `Shift+S` | New / Open / Save / Save As |
| `Ctrl+E` | Export PDF (diagram + schedule) |
| `Ctrl+Shift+E` | Export… (CSV, labels, BOM, greyscale PDF) |
| `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` | Undo / Redo / Redo |
| `Ctrl+1` … `Ctrl+4` | Rack · Schematic · Rear panel · Schedule |
| `Ctrl+\` | Split view |
| `Ctrl+PgUp` / `PgDn` | Previous / next sheet |
| `Ctrl+Shift+0` | All-sheets contact view |

### Navigation & zoom

| Key | Action |
|---|---|
| `Space`+drag · middle-drag | Pan |
| `Ctrl`+wheel · `Ctrl` `+`/`-` | Zoom at cursor / at centre |
| `Ctrl+0` | Fit sheet |
| `Ctrl+9` | Fit selection |
| `Ctrl+Alt+0` | Zoom 100% |
| `Ctrl+F` / `Ctrl+G` / `Ctrl+P` | Search / Go to designator / Command palette |
| `Ctrl+M` | Toggle minimap |
| `Ctrl+5` | DRC panel |
| `Ctrl+Alt+R/S/P/T` | Reveal selection in Rack / Schematic / Rear / Table |

### Selection

| Key | Action |
|---|---|
| `Ctrl+A` / `Ctrl+Shift+A` | Select all / deselect all |
| `Shift+click` / `Alt+click` | Add / subtract |
| `Ctrl+click` wire | Select whole net |
| `dbl-click` wire | Select whole bundle |
| `Tab` / `Shift+Tab` | Next / previous port on the selected device |
| `Ctrl+Tab` | Next device in rack order |
| `Ctrl+I` | Invert selection |
| `Ctrl+Shift+I` | Select all connections of the selected device |
| `Esc` | Cancel current operation / clear selection |

### Drawing & editing

| Key | Action |
|---|---|
| `W` | Begin wire from the selected port (sticky mode) |
| `Shift` during commit | Chain-draw — re-arm from the sink |
| `Ctrl` during draw | Suppress magnetic snap |
| `Alt` during draw | Force straight (single-bend) route |
| `Del` / `Backspace` | Delete selection |
| `Ctrl+D` | Duplicate device (new refdes, no connections) |
| `Ctrl+Shift+D` | Duplicate device **with** its connection pattern |
| `Ctrl+L` | Toggle drawn wire ↔ net label on selection |
| `Ctrl+B` | Create bus from selected wires |
| `Ctrl+Shift+B` | Collapse / expand port bank |
| `Ctrl+K` / `Ctrl+Shift+K` | Add to bundle / collapse bundle |
| `Ctrl+R` | Reverse connection direction |
| `Ctrl+Shift+R` | Clear manual route |
| `Ctrl+Enter` | Properties of selection |
| `Arrows` / `Shift+Arrows` | Nudge 1U / 4U |
| `Alt+Arrows` | Nudge 0.1 mm (free) |

### Layout & alignment

| Key | Action |
|---|---|
| `L` | Tidy selection (preview) |
| `Shift+L` | Tidy sheet (preview) |
| `Ctrl+Shift+L` | Re-flow sheet — includes pinned (confirm) |
| `Ctrl+Alt+Shift+L` | Re-flow document (confirm) |
| `Enter` / `Esc` / `Tab` in preview | Accept / discard / cycle variant |
| `Ctrl+Shift+U` | Unpin selection |
| `Ctrl+Alt+←↑→↓` | Align left / top / right / bottom |
| `Ctrl+Alt+H` / `V` | Distribute horizontally / vertically |

### Density & visibility

| Key | Action |
|---|---|
| `1` … `8` | Solo domain (Digital Video → Structure) |
| `` ` `` | Show all domains |
| `Ctrl+1..8` | Toggle domain |
| `F` / `Shift+F` | Focus / Isolate selection |
| `[` / `]` | Focus radius − / + |
| `T` | Trace signal path |
| `Alt`+hover | Transient focus, no click |
| `-` / `=` | Collapse / expand selected symbol |
| `Ctrl+Shift+H` | Toggle hop rendering |
| `G` | Toggle grid |
| `Ctrl+Shift+G` | Toggle snap |
| `Ctrl+Shift+T` | Cycle tag-pill verbosity |
| `Ctrl+Shift+P` | Toggle print-preview (light palette + sheet frame) |

---

## 8. Wireframes

### 8.1 The schematic screen

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ File  Edit  View  Place  Route  Validate  Window  Help                    RackMate — Smith Residence.rackmate │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ▣ Rack  │ ⚡ SCHEMATIC │ ▤ Rear │ ☰ Schedule       Sheet ▾ [2 · VIDEO ]  ◀ ▶     ⊞ Split   🖨 Preview   ⌕     │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Draw ▾ Auto  │ [◼D.Video 34][◼A.Video 6][◼A.Audio 22][◼D.Audio 8][◼Network 41][◼Control 19][◼Power 28][◼Str 12]│
├───────────────┬──────────────────────────────────────────────────────────────────────┬───────────────────────┤
│ ▾ LIBRARY   ⌕ │  A ┌────────────────────────────────────────────────────────────┐ A  │ ▾ PROPERTIES          │
│  ▾ Sources    │    │ ┌──────────┐          ┌──────────────┐        ┌───────────┐ │    │ ── Connection W044 ── │
│    ▪ Streamer │    │ │ STR      │          │ MTX1         │        │ HBT-GRT   │ │    │ Tag     W044          │
│    ▪ Cable box│  1 │ │ Structure│          │ 8×8 HDMI     │        │ HDBaseT TX│ │ 1  │ Domain  ◼ Digital Vid │
│    ▪ Blu-ray  │    │ │ ⟩LR-TV-1 ├──╮       │ 2RU · U14    │        │ 1RU · U18 │ │    │ Type    HDBaseT       │
│  ▾ Distribute │    │ │ ⟩MBR-KY-2│  │  ╭────┤J01 IN1  OUT1 ├──╮  ╭──┤J01 IN     │ │    │ Media   Cat6a F/UTP ▾ │
│    ▪ HDMI mtx │  B │ │ ⟩ATT-AP-3│  │  │ ╭──┤J02 IN2  OUT2 ├─╮│  │  │           │ │ B  │ Length  90 ft         │
│    ▪ Dist amp │    │ │ ⟩GR-KP-4 │  │  │ │╭─┤J03 IN3  OUT3 ├╮││  │  │  J09 OUT  ├─┼──╮ │ Layer   Phase 1     ▾ │
│    ▪ Extender │    │ └──────────┘  │  │ ││ │J04 IN4  OUT4 ││││  │  └───────────┘ │  │ │ Bundle  B03         ▾ │
│  ▾ Audio      │  2 │               │  │ ││ │J05 IN5  OUT5 │││╰──╯                │ 2│ │ Render  ● Wire ○ Label│
│    ▪ AVR      │    │ ┌──────────┐  │  │ ││ │J06 IN6  OUT6 ││╰────────╮           │  │ │ Route   ○ Auto ● Pinned│
│    ▪ 16ch amp │    │ │ ATV1     │  │  │ ││ │J07 IN7  OUT7 │╰──────╮  │           │  │ │         [Clear route] │
│  ▾ Network    │  C │ │ Streamer │  │  │ ││ │J08 IN8  OUT8 ├────╮  │  │           │ C│ │ ─────────────────────  │
│    ▪ 24p PoE  │    │ │      J01 ├──┼──╯ ││ └──────────────┘    │  │  │           │  │ │ ⚠ Passive length OK;   │
│    ▪ Router   │    │ └──────────┘  │    ││                     │  │  │           │  │ │   Cat6a required at    │
│  ▾ Power      │  3 │               ╰────╯│                     ╰──┼──┼───⟩ AUD_  │ 3│ │   4K/100 m. Verify     │
│    ▪ PDU 8    │    │ ┌──────────┐        │                        │  │    AVR_ZN2│  │ │   shielded terminate.  │
│    ▪ UPS      │    │ │ CBL1     │        │      ╭─ track gutter ──╯  │           │  │ │   [Mute rule…]        │
│  ▾ Passive    │  D │ │ Cable Box│────────╯      │  6 tracks          │           │ D│ ├───────────────────────┤
│    ▪ Patch pnl│    │ │      J01 │               ╰────────────────────╯           │  │ │ ▾ DRC       2⛔ 5⚠ 3ⓘ │
│    ▪ Balun    │    │ └──────────┘   ┌─ Sheet 2 of 6 ── ANSI B ── SR-0247 ──────┐ │  │ │ ⛔ W077 Eth run 118 m │
│    ▪ Splitter │    │                │ Smith Residence — Head End · VIDEO       │ │  │ │ ⛔ SW1 PoE 412/370 W  │
│               │    └────────────────┴──────────────────────────────────────────┴─┘  │ │ ⚠ W044 verify Cat6a   │
│  [+ New device]  1        2        3        4        5        6        7        8    │ │ ⚠ W019 HDMI2.1 5.1 m  │
├───────────────┴──────────────────────────────────────────────────────────────────────┴───────────────────────┤
│ ☰ CONNECTIONS   ⌕ [domain:hdmi from:MTX1                    ]  Group ▾ Source   8 of 170 shown     ⤢ Expand   │
│ ┌────┬─────────┬───────────────────┬────────────────────────┬──────────┬──────────────┬──────┬──────┬───────┐ │
│ │W021│◼D.Video │ ATV1:J01 HDMI OUT │ MTX1:J01 HDMI IN 1     │ HDMI 2.1 │ HDMI-48G     │  6′  │ 2/C3 │  ✓    │ │
│ │W022│◼D.Video │ CBL1:J01 HDMI OUT │ MTX1:J02 HDMI IN 2     │ HDMI 2.0 │ HDMI-18G     │  6′  │ 2/D3 │  ✓    │ │
│ │W044│◼D.Video │ MTX1:J09 OUT 1    │ HBT-GRT:J01 HDBaseT IN │ HDBaseT  │ Cat6a F/UTP  │ 90′  │ 2/C5 │  ⚠    │ │  ← selected
│ │W045│◼D.Video │ MTX1:J10 OUT 2    │ HBT-MBR:J01 HDBaseT IN │ HDBaseT  │ Cat6a F/UTP  │ 72′  │ 2/C6 │  ✓    │ │
│ └────┴─────────┴───────────────────┴────────────────────────┴──────────┴──────────────┴──────┴──────┴───────┘ │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ MTX1:J09 HDMI OUT 1 → HBT-GRT:J01 HDBaseT IN · 90′ Cat6a · W044      Zoom 84%   Grid 2.5mm   Snap ⏹   Ph 1 ▾ │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 A device symbol with 16 ports

`MTX1`, an 8×8 HDMI matrix: 8 inputs left, 8 outputs right, control on top, power on bottom.

```
                                    ▭9 RS-232          ⌂ LAN
                                    J17                J18
                                     ▲                  ▲
                                     │                  │        ← control edge (top)
                                     │                  │           routes to the control
                          ┌──────────┴──────────────────┴──────────┐  gutter, never crosses A/V
                          │  MTX1                        📌  ⚠     │
                          │  8×8 HDMI Matrix — Head End            │
                          │                        2 RU · U14 · REAR│
                          ├────────────────────────────────────────┤
        ┌ HDMI IN ┐       │                                        │       ┌ HDMI OUT ┐
   ◈────►─────────────────┤ J01  IN 1 ‹ATV1›      ‹GreatRm› OUT 1  ├─────────────►────◈
   HDMI                   │                                        │                HDMI
   ◈────►─────────────────┤ J02  IN 2 ‹CBL1›      ‹Master›  OUT 2  ├─────────────►────◈
   ◈────►─────────────────┤ J03  IN 3 ‹BDP1›      ‹Theater› OUT 3  ├─────────────►────◈
   ◈────►─────────────────┤ J04  IN 4 ‹GAME›      ‹Kitchen› OUT 4  ├─────────────►────◈
   ◈────►─────────────────┤ J05  IN 5 ‹CAM›       ‹Patio›   OUT 5  ├─────────────►────◈
   ◈────►─────────────────┤ J06  IN 6 ‹AppleTV2›  ‹Office›  OUT 6  ├─────────────►────◈
   ◈────►─────────────────┤ J07  IN 7 —           ‹Gym›     OUT 7  ├─────────────►────◈
   ◈────►─────────────────┤ J08  IN 8 —           ‹Bar›     OUT 8  ├═════════════►════⌂  ← HBT: doubled
        └─────────┘       │      J01..J08           J09..J16       │       └──────────┘      RJ45 glyph,
      ▲                   └────────────────────┬───────────────────┘                         bus weight
      │                                        │
   sinks · arrowhead points INTO the body      ▼
                                              ⊐ J20  IEC C14 · 100–240 V        ← power edge (bottom)
                                                                                  falls to PDU1:O07
LEGEND FOR THIS SYMBOL
  ◈  connector glyph, tinted by domain      ◎ RCA   ⌂ RJ45   ▭9 DB9   ⊐ IEC C14
  ►  direction arrow on the stub            into body = sink · away = source
  ═  bus / high-weight stroke               HDBaseT, network, power
  ‹› device or room the port is wired to    auto-derived, never typed
  📌 placement pinned   ⚠ has DRC warnings  header badges

AT 17+ PINS ON ONE EDGE THIS SYMBOL AUTO-SPLITS INTO UNITS:
  MTX1:A  inputs  1–8  / outputs 1–8      (sheet 2, VIDEO)
  MTX1:B  inputs  9–16 / outputs 9–16     (sheet 2, VIDEO)
  MTX1:C  RS-232, LAN, IR, AC             (sheets 5 CONTROL and 6 POWER)
  One refdes. One device. One schedule. Three bodies.

COLLAPSED (Ctrl+Shift+B) — the same device, banks folded to vector pins:
                    ┌────────────────────────────┐
        ◈═══════════┤ MTX1   8×8 HDMI            ├═══════════◈
          IN[1..8]  │        2 RU · U14          │  OUT[1..8]
                    └────────────────────────────┘
```

---

## 9. Implementation notes that constrain the design

Called out because ignoring them will force a redesign later.

- **Hybrid rendering.** Device symbols are real widgets under a `MultiChildRenderObjectWidget`; wires, grid, ports, and chrome are painted into the same canvas. Devices get text layout, hover, focus, and **semantics for free** — which matters because a device builder means editable labels everywhere. Lay children out with tight constraints from their *own* model size and `parentUsesSize: false`, so dragging one symbol cannot dirty another's layout.
- **Three-tier layer cache.** Tier 1 = grid + sheet border (invalidate on zoom decade). Tier 2 = settled wires as a `ui.Picture` (invalidate on topology or position commit; during a drag, re-record only the wires attached to the moving symbol and replay the cached Picture for the rest — this is the whole ballgame for drag smoothness). Tier 3 = live overlay, never cached.
- **`saveLayer` is banned in the hot path.** ~1 ms each; three blows a third of the 16.6 ms budget. Dimming for filters and focus **bakes alpha into `Paint.color`**, never an opacity layer. Run `checkerboardOffscreenLayers` and drive it to zero.
- **`TextPainter` caching is mandatory, not an optimisation.** ~200 devices × ~8 labels = 1600 labels at ~0.5 ms cold layout = 0.8 s. Cache keyed on `(text, style, maxWidth)`; **dispose** on eviction (native `ui.Paragraph` behind it); **quantise text scale to a ladder** (0.5/0.75/1.0/1.5/2/3/4) or every zoom frame is a total cache miss and you've built a cache that never hits.
- **Impeller is not yet default on Windows** — budget frame costs against Skia and re-benchmark when it lands; the `saveLayer` and path-stroking numbers will move.
- **Hover must be throttled to one hit-test per frame.** 1000 Hz mice are common and a spatial query per event is pure waste.
- **Start hit-testing brute-force with an AABB reject** (`if (!wire.bounds.inflate(tol).contains(p)) continue` kills ~95% of candidates). At 800 wires × 4 segments that is ~64 µs. Add a uniform spatial hash (~120 lines) only if hover shows in the timeline. R-trees earn their complexity at 10⁵ objects; you have 10³.
- **Undo/redo as a command stack, built before the feature surface grows.** Retrofitting undo is one of the genuinely painful refactors, and every interaction above assumes a clean single-entry transaction boundary.
- **PDF export emits vector geometry, not a rasterised canvas.** Structure the router so it returns an abstract path list that both the screen painter and the `pdf` package's `CustomPaint` consume. Infinitely zoomable diagrams and selectable text in the schedule is a real differentiator for a document handed to an installer in an attic.
- **Palette drag-and-drop uses `Listener`, not `Draggable`/`DragTarget`.** You need the drop point in *scene* coordinates with live RU/port snapping and a proper undo entry; `Draggable` gives you none of those.